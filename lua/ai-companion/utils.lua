local M = {}
local api = vim.api
local state = require("ai-companion.state")
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

function M.store_api_key(key)
  local path = vim.fn.stdpath("data") .. "openai_api_key.txt"
  vim.fn.writefile({ key }, path)
end

function M.get_api_key()
  local path = vim.fn.stdpath("data") .. "openai_api_key.txt"
  if vim.fn.filereadable(path) == 1 then
    return vim.fn.readfile(path)[1]
  end
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

return M
