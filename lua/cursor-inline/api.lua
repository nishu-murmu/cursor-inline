local M = {}

local api = vim.api
local config = require("cursor-inline.config")
local state = require("cursor-inline.state")
local utils = require("cursor-inline.utils")
local providers = require("cursor-inline.providers")
local highlight = state.highlight

local function insert_generated_code(lines)
  local bufnr = utils.get_bufnr()
  if not api.nvim_buf_is_valid(bufnr) then
    return
  end
  local start_row = vim.fn.line("'<") - 1
  highlight.new_code.start_row = start_row
  api.nvim_buf_set_lines(bufnr, start_row, start_row, false, lines)
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

---@param input string
---@param callback function(generated boolean)
local function generate_response(input, callback)
  callback("started")
  ---@param response_code string
  providers.get_current_provider_response(input, function(response_code)
    local lines = vim.split(response_code, "\n", { plain = true })
    if #lines ~= 0 then callback("done") end
    table.remove(lines, 1)
    table.remove(lines, #lines)
    vim.schedule(function()
      insert_generated_code(lines)
      highlight_old_code()
      highlight_new_inserted_code()
      if config.mappings.show_inline_hint == true then
        utils.open_helper_commands_ui()
      end
      vim.cmd("stopinsert")
    end)
  end)
end

function M.get_response()
  local provider = config.provider or {}
  local api_key = config.provider.name == "openai" and vim.fn.getenv("OPENAI_API_KEY") or
      provider.name == "anthropic" and vim.fn.getenv("ANTHROPIC_API_KEY")
  local api_key_name = config.provider.name == "openai" and "OPENAI_API_KEY" or
      provider.name == "anthropic" and "ANTHROPIC_API_KEY"
  if api_key == vim.NIL or api_key == "" then
    vim.notify("The " .. provider.name .. " API key is missing", vim.log.levels.ERROR)
    vim.notify(string.format([[
Please enter the API key securely:
On Unix (Linux/macOS):
  1. Add this line in your shell config file:
     export %s="<api-key>"
  2. Source the file:
     source .bashrc (or which ever rc file you have)
  2. Restart your terminal and Neovim.

On Windows (Command Prompt):
  1. Run:
     setx %s "<api-key>"
  2. Restart Command Prompt and Neovim.

On Windows (PowerShell):
  1. Run:
     [System.Environment]::SetEnvironmentVariable("%s", "<api-key>", "User")
  2. Restart PowerShell and Neovim.
    ]], api_key_name, api_key_name, api_key_name))
    return
  end
  ---@param input string
  ---@param opts any
  ---@param close_input function()
  vim.ui.input({ prompt = "Enter prompt:" }, function(input, opts, close_input)
    if input and input ~= "" then
      generate_response(input, function(status)
        if status == "started" then
          api.nvim_buf_set_text(opts.bufnr, 0, 0, 0, 0, { " " })
        end
        if status == "done" then
          close_input()
        end
      end)
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
