local M = {}
local api = vim.api
local state = require("cursor-inline.state")
local config = require("cursor-inline.config")
local ui = require("cursor-inline.ui")
local highlight = state.highlight

function M.get_visual_selection()
  local bufnr = 0
  local mode = vim.fn.visualmode()
  local start = api.nvim_buf_get_mark(bufnr, "<")
  local finish = api.nvim_buf_get_mark(bufnr, ">")
  local start_row, start_col = start[1], start[2]
  local end_row, end_col = finish[1], finish[2]
  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  local lines = api.nvim_buf_get_lines(
    bufnr,
    start_row - 1,
    end_row,
    false
  )
  if #lines == 0 then
    return {}
  end
  if mode == "v" then
    lines[1] = string.sub(lines[1], start_col + 1)
    lines[#lines] = string.sub(lines[#lines], 1, end_col + 1)
  elseif mode == "V" then
    return lines
  elseif mode == "\22" then
    for i, line in ipairs(lines) do
      lines[i] = string.sub(line, start_col + 1, end_col + 1)
    end
  end
  return lines
end

function M.get_bufnr()
  return state.main_bufnr or api.nvim_get_current_buf()
end


function M.get_code_region(type_)
  local ns = highlight[type_].ns
  local id = highlight[type_].id
  if not id or not ns then return end
  local mark = api.nvim_buf_get_extmark_by_id(0, ns, id, { details = true })
  if not mark or vim.tbl_isempty(mark) then return end
  local sr, _, details = unpack(mark)
  if not sr or not details or not details.end_row then return end
  return sr, details.end_row
end

function M.open_helper_commands_ui()
  local _, old_er = M.get_code_region("old_code")
  local accept_text = config.mappings.accept_response or ""
  local decline_text = config.mappings.deny_response or ""
  local accept_response = "Accept Edit (" .. accept_text .. ")"
  local decline_response = "Decline Edit (" .. decline_text .. ")"
  if old_er then
    -- Close existing windows first
    M.close_helper_commands_ui()
    -- Create new windows
    state.wins.accept, state.bufs.accept = ui.open_post_response_commands(old_er, accept_response, 48, 10)
    state.wins.deny, state.bufs.deny = ui.open_post_response_commands(old_er, decline_response, 24, 20)
  end
end

function M.close_helper_commands_ui()
  if state.wins.accept ~= nil then
    ui.close_post_response_commands(state.wins.accept)
    state.wins.accept = nil
  end
  if state.wins.deny ~= nil then
    ui.close_post_response_commands(state.wins.deny)
    state.wins.deny = nil
  end
  if state.bufs.accept ~= nil and api.nvim_buf_is_valid(state.bufs.accept) then
    api.nvim_buf_delete(state.bufs.accept, { force = true })
    state.bufs.accept = nil
  end
  if state.bufs.deny ~= nil and api.nvim_buf_is_valid(state.bufs.deny) then
    api.nvim_buf_delete(state.bufs.deny, { force = true })
    state.bufs.deny = nil
  end
end

return M
