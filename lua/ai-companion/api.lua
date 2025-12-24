local M = {}

local api = vim.api
local prompts = require("ai-companion.prompts")
local config = require("ai-companion.config")
local state = require("ai-companion.state")
local highlight = state.highlight

local function insert_generated_code(lines)
  local bufnr = state.main_bufnr or api.nvim_get_current_buf()
  if api.nvim_buf_is_valid(bufnr) then
    local start_row = vim.fn.line("'<") - 1
    highlight.new_code.start_row = start_row
    api.nvim_buf_set_lines(bufnr, start_row, start_row, false, lines)
  end
end

local function get_visual_range()
  local bufnr = state.main_bufnr or api.nvim_get_current_buf()
  local start = vim.api.nvim_buf_get_mark(bufnr, "<")
  local finish = vim.api.nvim_buf_get_mark(bufnr, ">")
  local sr = start[1] - 1
  local er = finish[1] - 1
  return sr, er
end

local function highlight_old_code()
  local bufnr = state.main_bufnr or api.nvim_get_current_buf()
  local ns = state.highlight.old_code.ns
  api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  highlight.old_code.start_row, highlight.old_code.end_row = get_visual_range()
  api.nvim_set_hl(0, state.highlight.old_code.hl_group, {
    bg = "#ea4859",
    blend = 80
  })
  api.nvim_buf_set_extmark(bufnr, ns, highlight.old_code.start_row, 0, {
    end_row = highlight.old_code.end_row + 1,
    hl_group = highlight.old_code.hl_group,
    hl_eol = true,
  })
end

local function skip_old_code()

end

local function highlight_new_inserted_code()
  local bufnr = state.main_bufnr or api.nvim_get_current_buf()
  local ns = state.highlight.new_code.ns
  highlight.new_code.end_row = vim.api.nvim_buf_get_mark(bufnr, "<")[1]
  local start_row = highlight.new_code.start_row
  api.nvim_set_hl(0, state.highlight.new_code.hl_group, {
    bg = "#199f5a",
    blend = 80
  })
  api.nvim_buf_set_extmark(bufnr, ns, start_row, 0, {
    end_row = highlight.new_code.end_row - 1,
    hl_group = highlight.new_code.hl_group,
    hl_eol = true,
  })
end

function M.get_response(input)
  local instruction = input
  local selected_text = state.selected_text
  local prompt_text = instruction .. "\n below is the selected code, \n```" .. selected_text .. "```"
  local provider = config.provider or {}
  local api_key = os.getenv("OPENAI_API_KEY")
  if not api_key or api_key == "" then
    vim.notify("The " .. provider.name .. "API key is missing", vim.log.levels.ERROR)
    vim.ui.input({ prompt = "Enter " .. provider.name .. " API key:" }, function(key)
      if key and key ~= "" then
        vim.env.OPENAI_API_KEY = key
        M.get_response(instruction)
      end
    end)
    return
  end

  local model = provider.model or "gpt-4.1-mini"

  local payload = vim.json.encode({
    model = model,
    input = {
      {
        role = "system",
        content = prompts.system_prompt,
      },
      {
        role = "user",
        content = prompt_text,
      },
    },
  })

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
    "https://api.openai.com/v1/responses",
  }, {
    text = true,
  }, function(res)
    local data = vim.json.decode(res.stdout)
    local response_code = data.output[1].content[1].text
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
    end)
  end)
end

return M
