local M = {}

local api = vim.api
local prompts = require("ai-companion.prompts")
local ui = require("ai-companion.ui")
local config = require("ai-companion.config")
local state = require("ai-companion.state")
local utils = require("ai-companion.utils")
local highlight = state.highlight

local function insert_generated_code(lines)
  local bufnr = utils.get_bufnr()
  if not api.nvim_buf_is_valid(bufnr) then return end
  local start_row = vim.fn.line("'<") - 1
  highlight.new_code.start_row = start_row
  api.nvim_buf_set_lines(bufnr, start_row, start_row, false, lines)
end

local function get_visual_range()
  local bufnr = utils.get_bufnr()
  local start_row = api.nvim_buf_get_mark(bufnr, "<")[1]
  local end_row = api.nvim_buf_get_mark(bufnr, ">")[1]
  return start_row - 1, end_row - 1
end

local function highlight_old_code()
  local bufnr = utils.get_bufnr()
  local ns = highlight.old_code.ns
  api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  highlight.old_code.start_row, highlight.old_code.end_row = get_visual_range()
  api.nvim_set_hl(0, highlight.old_code.hl_group, { bg = "#ea4859", blend = 80 })
  highlight.old_code.id = api.nvim_buf_set_extmark(bufnr, ns, highlight.old_code.start_row, 0, {
    end_row = highlight.old_code.end_row + 1,
    hl_group = highlight.old_code.hl_group,
    hl_eol = true,
  })
  api.nvim_buf_set_lines(bufnr, highlight.old_code.end_row + 1, highlight.old_code.end_row + 1, false, { "" })
end

local function highlight_new_inserted_code()
  local bufnr = utils.get_bufnr()
  local ns = highlight.new_code.ns
  highlight.new_code.end_row = api.nvim_buf_get_mark(bufnr, "<")[1]
  local start_row = highlight.new_code.start_row
  api.nvim_set_hl(0, highlight.new_code.hl_group, { bg = "#199f5a", blend = 80 })
  highlight.new_code.id = api.nvim_buf_set_extmark(bufnr, ns, start_row, 0, {
    end_row = highlight.new_code.end_row - 1,
    hl_group = highlight.new_code.hl_group,
    hl_eol = true,
  })
end

local function reset_states()
  local bufnr = state.main_bufnr
  if not bufnr then return end
  local new_ns = highlight.new_code.ns
  local old_ns = highlight.old_code.ns
  api.nvim_buf_clear_namespace(bufnr, new_ns, 0, -1)
  api.nvim_buf_clear_namespace(bufnr, old_ns, 0, -1)
  highlight.new_code.start_row, highlight.new_code.end_row, highlight.new_code.id = nil, nil, nil
  highlight.old_code.start_row, highlight.old_code.end_row, highlight.old_code.id = nil, nil, nil
  highlight.new_code.ns = api.nvim_create_namespace("NewCodeHighlight")
  highlight.old_code.ns = api.nvim_create_namespace("OldCodeHighlight")
  vim.cmd.stopinsert()
end

local function open_helper_commands_ui()
  local _, old_er = M.get_old_code_region()
  local accept_text = config.mappings.accept_response or ""
  local decline_text = config.mappings.deny_response or ""
  local accept_response = "Accept Edit (" .. accept_text .. ")"
  local decline_response = "Decline Edit (" .. decline_text .. ")"
  if old_er then
    state.wins.accept = ui.open_post_response_commands(old_er, accept_response, 48, 10)
    state.wins.deny = ui.open_post_response_commands(old_er, decline_response, 24, 20)
  end
end

local function get_payload(input)
  local instruction = input
  local selected_text = state.selected_text
  local prompt_text = instruction .. "\n below is the selected code, \n```" .. selected_text .. "```"
  local model = config.provider.model or "gpt-4.1-mini"
  local payload = vim.json.encode({
    model = model,
    input = {
      { role = "system", content = prompts.system_prompt },
      { role = "user", content = prompt_text },
    },
  })
  return payload
end

local function run_curl_command(payload, api_key, url)
  vim.system({
    "curl",
    "-s",
    "-X",
    "POST",
    "-H",
    "Content-Type: application/json",
    "-H",
    "Authorization: Bearer " .. api_key,
    "-d",
    payload,
    url
  }, {
    text = true,
  }, function(res)
    local data = vim.json.decode(res.stdout)
    local response_code = data.output and data.output[1] and data.output[1].content and data.output[1].content[1] and
        data.output[1].content[1].text
    if not response_code then
      vim.schedule(function()
        vim.notify("Failed to parse OpenAI response", vim.log.levels.ERROR)
      end)
      return
    end
    local lines = vim.split(response_code, "\n", { plain = true })
    table.remove(lines, 1)
    table.remove(lines, #lines)
    vim.schedule(function()
      insert_generated_code(lines)
      highlight_new_inserted_code()
      highlight_old_code()
      open_helper_commands_ui()
    end)
  end)
end

function M.get_response()
  vim.ui.input({ prompt = "Enter prompt:" }, function(input)
    if input and input ~= "" then
      local payload = get_payload(input)
      local provider = config.provider or {}
      local api_key = utils.get_api_key()
      if not api_key or api_key == "" then
        vim.notify("The " .. provider.name .. "API key is missing", vim.log.levels.ERROR)
        vim.ui.input({ prompt = "Enter " .. provider.name .. " API key:" }, function(key)
          if key and key ~= "" then
            utils.store_api_key(key)
            M.get_response()
          end
        end)
        return
      end
      run_curl_command(payload, api_key, "https://api.openai.com/v1/responses")
    end
  end)
end

function M.accept_api_response()
  local new_sr, new_er = M.get_old_code_region()
  local bufnr = state.main_bufnr
  if new_sr and new_er and bufnr then
    api.nvim_buf_set_lines(bufnr, new_sr, new_er, false, {})
  end
  if state.wins.accept then api.nvim_win_close(state.wins.accept, true) end
  if state.wins.deny then api.nvim_win_close(state.wins.deny, true) end
  reset_states()
end

function M.reject_api_response()
  local new_sr, new_er = M.get_new_code_region()
  local bufnr = state.main_bufnr
  if new_sr and new_er and bufnr then
    api.nvim_buf_set_lines(bufnr, new_sr, new_er, false, {})
  end
  if state.wins.accept then api.nvim_win_close(state.wins.accept, true) end
  if state.wins.deny then api.nvim_win_close(state.wins.deny, true) end
  reset_states()
end

function M.get_old_code_region()
  return utils.get_code_region("old_code")
end

function M.get_new_code_region()
  return utils.get_code_region("new_code")
end

return M
