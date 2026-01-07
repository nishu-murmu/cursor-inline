local M = {}

local api = vim.api
local prompts = require("cursor-inline.prompts")
local config = require("cursor-inline.config")
local state = require("cursor-inline.state")
local utils = require("cursor-inline.utils")
local highlight = state.highlight
local function insert_generated_code(lines)
  local bufnr = utils.get_bufnr()
  if api.nvim_buf_is_valid(bufnr) then
    local start_row = vim.fn.line("'<") - 1
    highlight.new_code.start_row = start_row
    api.nvim_buf_set_lines(bufnr, start_row, start_row, false, lines)
  end
end


local function get_visual_range()
  local bufnr = 0
  local start_mark = api.nvim_buf_get_mark(bufnr, "<")
  local end_mark = api.nvim_buf_get_mark(bufnr, ">")
  local start_row, start_bufnr = start_mark[1], start_mark[2]
  local end_row = end_mark[1]
  if start_bufnr ~= bufnr then return nil, nil end
  return start_row - 1, end_row - 1
end

local function highlight_old_code()
  local bufnr = utils.get_bufnr()
  local ns = highlight.old_code.ns
  api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  local sr, er = get_visual_range()
  highlight.old_code.start_row = sr
  highlight.old_code.end_row = er
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
  highlight.new_code.id = api.nvim_buf_set_extmark(bufnr, ns, start_row or 0, 0, {
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
  state.wins = {
    deny = nil,
    accept = nil
  }
  state.bufs = {
    deny = nil,
    accept = nil
  }
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
      { role = "user",   content = prompt_text },
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
      highlight_old_code()
      highlight_new_inserted_code()
      utils.open_helper_commands_ui()
      vim.cmd("stopinsert")
    end)
  end)
end
function M.get_response()
  local provider = config.provider or {}
  local api_key = vim.fn.getenv("OPENAI_API_KEY")
  if not api_key or api_key == "" then
    vim.notify("The " .. provider.name .. " API key is missing", vim.log.levels.ERROR)
    vim.notify([[
Please enter the API key securely:
On Unix (Linux/macOS):
  1. Add this line in your shell config file:
     export OPENAI_API_KEY="sk-..."
  2. Restart your terminal and Neovim.

On Windows (Command Prompt):
  1. Run:
     setx OPENAI_API_KEY "sk-..."
  2. Restart Command Prompt and Neovim.

On Windows (PowerShell):
  1. Run:
     [System.Environment]::SetEnvironmentVariable("OPENAI_API_KEY", "sk-...", "User")
  2. Restart PowerShell and Neovim.
    ]])
    return
  end
  vim.ui.input({ prompt = "Enter prompt:" }, function(input)
    if input and input ~= "" then
      local payload = get_payload(input)
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
  utils.close_helper_commands_ui()
  reset_states()
end

function M.reject_api_response()
  local new_sr, new_er = M.get_new_code_region()
  local bufnr = state.main_bufnr
  if new_sr and new_er and bufnr then
    api.nvim_buf_set_lines(bufnr, new_sr, new_er, false, {})
  end
  utils.close_helper_commands_ui()
  reset_states()
end

function M.get_old_code_region()
  return utils.get_code_region("old_code")
end

function M.get_new_code_region()
  return utils.get_code_region("new_code")
end

return M
