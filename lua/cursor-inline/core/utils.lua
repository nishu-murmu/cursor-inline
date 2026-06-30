local M = {}

local api = vim.api
local utils = require("cursor-inline.utils")
local state = require("cursor-inline.state")
local highlight = state.highlight

local function get_visual_range()
  local bufnr = utils.get_bufnr()
  local start_mark = api.nvim_buf_get_mark(bufnr, "<")
  local end_mark = api.nvim_buf_get_mark(bufnr, ">")
  return start_mark[1], end_mark[1]
end

local function insert_generated_code(lines)
  local bufnr = utils.get_bufnr()
  if not api.nvim_buf_is_valid(bufnr) then
    return
  end
  local start_row = api.nvim_buf_get_mark(bufnr, "<")[1]
  api.nvim_buf_set_lines(bufnr, start_row - 1, start_row - 1, false, lines)
end

local function highlight_old_code()
  local bufnr = utils.get_bufnr()
  local ns = highlight.old_code.ns
  api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  local sr, er = get_visual_range()
  highlight.old_code.start_row = sr
  highlight.old_code.end_row = er
  api.nvim_set_hl(0, highlight.old_code.hl_group, { bg = "#ea4859", blend = 80 })
  highlight.old_code.id = api.nvim_buf_set_extmark(bufnr, ns, highlight.old_code.start_row - 1, 0, {
    end_row = highlight.old_code.end_row,
    hl_group = highlight.old_code.hl_group,
    hl_eol = true,
  })
end

local function highlight_inserted_code()
  local bufnr = utils.get_bufnr()
  local ns = highlight.new_code.ns
  api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  api.nvim_set_hl(0, highlight.new_code.hl_group, { bg = "#199f5a", blend = 80 })
  highlight.new_code.id = api.nvim_buf_set_extmark(bufnr, ns, highlight.new_code.start_row - 1, 0, {
    end_row = highlight.new_code.end_row,
    hl_group = highlight.new_code.hl_group,
    hl_eol = true,
  })
end

function M.reset_states()
  local bufnr = state.main_bufnr
  if not bufnr then
    return
  end
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
    accept = nil,
  }
  state.bufs = {
    deny = nil,
    accept = nil,
  }
end

function M.api_key_missing_notification()
  ---@diagnostic disable
  vim.notify("The " .. provider.name .. " API key is missing", vim.log.levels.ERROR)
  vim.notify([[
Please enter the API key securely:
On Unix (Linux/macOS):
  1. Add this line in your shell config file:
     export OPENAI_API_KEY="sk-..."
  2. Source the file:
     source .bashrc (or which ever rc file you have)
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
end

function M.on_response_handler(response_code, cb)
  if not response_code then
    vim.schedule(function()
      vim.notify("Failed to parse OpenAI response", vim.log.levels.ERROR)
      vim.cmd("stopinsert")
      cb(true)
    end)
    return
  end
  local lines = vim.split(response_code, "\n", { plain = true })
  vim.schedule(function()
    insert_generated_code(lines)
    highlight_old_code()
    highlight_inserted_code()
    utils.open_helper_commands_ui()
    vim.cmd("stopinsert")
    cb(true)
  end)
end

return M
