local M = {}

local api = vim.api
local state = require("cursor-inline.state")
local providers = require("cursor-inline.core.providers")
local core_utils = require("cursor-inline.core.utils")
local utils = require("cursor-inline.utils")

function M.get_response()
  ---@diagnostic disable
  vim.ui.input({ prompt = "Enter prompt:" }, function(input, cb)
    if input and input ~= "" then
      providers.get_current_provider_response(input, function(response_code)
        core_utils.on_response_handler(response_code, function(value)
          cb(value)
        end)
      end)
    end
  end)
end

function M.accept_api_response()
  local new_sr, new_er = utils.get_code_region("old_code")
  local bufnr = state.main_bufnr
  if new_sr and new_er and bufnr then
    api.nvim_buf_set_lines(bufnr, new_sr, new_er, false, {})
  end
  utils.close_helper_commands_ui()
  core_utils.reset_states()
end

function M.reject_api_response()
  local new_sr, new_er = utils.get_code_region("new_code")
  local bufnr = state.main_bufnr
  if new_sr and new_er and bufnr then
    api.nvim_buf_set_lines(bufnr, new_sr, new_er, false, {})
  end
  utils.close_helper_commands_ui()
  core_utils.reset_states()
end

return M
