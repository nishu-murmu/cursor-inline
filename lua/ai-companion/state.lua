local api = vim.api

local M = {
  highlight = {
    old_code = {
      start_row = nil,
      end_row = nil,
      hl_group = "OldCode",
      ns = api.nvim_create_namespace("OldCodeHighlight")
    },
    new_code = {
      start_row = nil,
      end_row = nil,
      hl_group = "NewCode",
      ns = api.nvim_create_namespace("NewCodeHighlight")
    }
  },
  selected_text = "",
  main_bufnr = nil,
}
return M
