local config = require("cursor-inline.config")
local ui = require("cursor-inline.ui")
local base = require("cursor-inline.base")
local autocmd = require("cursor-inline.autocmd")

local M = {}

function M.setup(opts)
	config.setup(opts or {})
	ui.setup()
	autocmd.setup()
	base.setup()
end

return M
