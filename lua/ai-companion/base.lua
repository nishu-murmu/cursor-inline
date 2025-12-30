local M = {}

local ui = require("ai-companion.ui")
local core_api = require("ai-companion.api")
local config = require("ai-companion.config")

local function open_input_callback()
  ui.close_inline_command()
  core_api.get_response()
end

function M.setup()
  local keymaps = {
    { "v", config.mappings.open_input, open_input_callback, "Opening the input prompt." },
    { "n", config.mappings.deny_response, core_api.reject_api_response, "Declining the API response." },
    { "n", config.mappings.accept_response, core_api.accept_api_response, "Accepting the API response." },
  }

  for _, map in ipairs(keymaps) do
    vim.keymap.set(map[1], map[2], map[3], { desc = map[4] })
  end
end

return M
