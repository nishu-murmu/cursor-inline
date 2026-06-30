local M = {}

local ui = require("cursor-inline.ui")
local api = require("cursor-inline.core.api")
local config = require("cursor-inline.config")

local function open_input_callback()
	if config.mappings.accept_response == true then
		ui.close_inline_command()
	end
	api.get_response()
end

function M.setup()
	local keymaps = {
		{ "v", config.mappings.open_input, open_input_callback, "Opening the input prompt." },
		{ "n", config.mappings.deny_response, api.reject_api_response, "Declining the API response." },
		{ "n", config.mappings.accept_response, api.accept_api_response, "Accepting the API response." },
	}

	for _, map in ipairs(keymaps) do
		vim.keymap.set(map[1], map[2], map[3], { desc = map[4] })
	end
end

return M
