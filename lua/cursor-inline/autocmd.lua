local M = {}
local api = vim.api
local utils = require("cursor-inline.utils")
local config = require("cursor-inline.config")
local state = require("cursor-inline.state")
local ui = require("cursor-inline.ui")

M.setup = function()
	local ns_old_code = state.highlight.old_code.ns
	local ns_new_code = state.highlight.new_code.ns
	api.nvim_create_autocmd("ModeChanged", {
		pattern = "n:[vV\22]",
		callback = function()
			if config.mappings.show_inline_hint == true then
				ui.open_inline_command()
			end
		end,
	})

	api.nvim_create_autocmd("ModeChanged", {
		pattern = "[vV\22]:n",
		callback = function()
			if config.mappings.show_inline_hint == true then
				ui.close_inline_command()
			end
			local lines = utils.get_visual_selection()
			state.main_bufnr = api.nvim_get_current_buf()
			state.selected_text = table.concat(lines, "\n")
		end,
	})

	api.nvim_create_autocmd("CursorMoved", {
		callback = function()
			if vim.fn.mode():match("n") then
				local old_sr, old_er = utils.get_code_region("old_code")
				local new_sr, new_er = utils.get_code_region("new_code")
				if old_er == nil and old_sr == nil then
					return
				end
				local cursor_pos = api.nvim_win_get_cursor(0)[1]
				if old_sr == cursor_pos then
					vim.schedule(function()
						api.nvim_win_set_cursor(0, { old_er + 1, 0 })
					end)
				end
				if old_er == cursor_pos then
					vim.schedule(function()
						api.nvim_win_set_cursor(0, { old_sr - 1, 0 })
					end)
				end

				-- Update helper visibility based on cursor position
				local in_new_code = cursor_pos >= new_sr + 1 and cursor_pos <= new_er + 1
				local helpers_visible = state.wins.accept ~= nil or state.wins.deny ~= nil

				if in_new_code and not helpers_visible then
					vim.schedule(function()
						utils.open_helper_commands_ui()
					end)
				elseif not in_new_code and helpers_visible then
					vim.schedule(function()
						utils.close_helper_commands_ui()
					end)
				end
			end
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
					blend = 80,
				})
				api.nvim_buf_set_extmark(bufnr or 0, ns_new_code, highlight.new_code.start_row, 0, {
					end_row = highlight.new_code.end_row - 1,
					hl_group = highlight.new_code.hl_group,
					hl_eol = true,
				})
			end
			if highlight.old_code.start_row and highlight.old_code.end_row then
				api.nvim_set_hl(0, state.highlight.new_code.hl_group, {
					bg = "#199f5a",
					blend = 80,
				})
				api.nvim_buf_set_extmark(bufnr or 0, ns_old_code, highlight.old_code.start_row, 0, {
					end_row = highlight.old_code.end_row + 1,
					hl_group = highlight.old_code.hl_group,
					hl_eol = true,
				})
			end
		end,
	})
end

return M
