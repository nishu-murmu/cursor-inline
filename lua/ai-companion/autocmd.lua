local M = {}
local api = vim.api
local utils = require("ai-companion.utils")
local state = require("ai-companion.state")
local ui = require("ai-companion.ui")

M.setup = function()
  local ns_old_code = state.highlight.old_code.ns
  local ns_new_code = state.highlight.new_code.ns
  api.nvim_create_autocmd("ModeChanged", {
    pattern = "n:[vV\22]",
    callback = function()
      ui.open_inline_command()
    end,
  })

  api.nvim_create_autocmd("ModeChanged", {
    pattern = "[vV\22]:n",
    callback = function()
      ui.close_inline_command()
      local lines = utils.get_visual_selection()
      state.main_bufnr = api.nvim_get_current_buf()
      state.selected_text = table.concat(lines, "\n")
    end,
  })

  api.nvim_create_autocmd("CursorMoved", {
    callback = function()
      if vim.fn.mode():match("[vV\22]") then
        ui.move_inline_command()
      end
    end,
  })

  api.nvim_create_autocmd("BufWritePost", {
    callback = function()
      local bufnr = state.main_bufnr
      local highlight = state.highlight
      if highlight.new_code.start_row and highlight.new_code.end_row then
        api.nvim_set_hl(0, state.highlight.old_code.hl_group, {
          bg = "#ea4859",
          blend = 80
        })
        api.nvim_buf_set_extmark(bufnr, ns_new_code, highlight.new_code.start_row, 0, {
          end_row = highlight.new_code.end_row - 1,
          hl_group = highlight.new_code.hl_group,
          hl_eol = true,
        })
      end
      if highlight.old_code.start_row and highlight.old_code.end_row then
        api.nvim_set_hl(0, state.highlight.new_code.hl_group, {
          bg = "#199f5a",
          blend = 80
        })
        api.nvim_buf_set_extmark(bufnr, ns_old_code, highlight.old_code.start_row, 0, {
          end_row = highlight.old_code.end_row + 1,
          hl_group = highlight.old_code.hl_group,
          hl_eol = true,
        })
      end
    end
  })
end

return M
