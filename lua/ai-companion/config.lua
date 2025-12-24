local M = {}

M.mappings = {
  open_input = "<leader>e",
  accept_response = "<leader>y",
  deny_response = "<leader>n",
}

M.provider = {
  name = "openai",
  model = "gpt-4.1-mini",
}

M.setup = function(opts)
  local provider = opts.provider or {}
  local mappings = opts.mappings or {}
  M.provider = vim.tbl_deep_extend("force", M.provider, provider)
  M.mappings = vim.tbl_deep_extend("force", M.mappings, mappings)
end

return M
