if vim.g.loaded_cursor_inline then
  return
end

vim.g.loaded_cursor_inline = true

local ok, cursor_inline = pcall(require, "cursor-inline")
if not ok then
  return
end

cursor_inline.setup()
