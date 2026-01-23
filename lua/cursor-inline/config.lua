local M = {}

M.mappings = {
  open_input = "<Space>e",
  accept_response = "<Space>y",
  deny_response = "<Space>n",
  show_inline_hint = true
}

M.provider = {
  name = "openai",
  model = "gpt-4.1-mini",
}

M.setup = function(opts)
  P(opts)
  local provider = opts.provider or {}
  local mappings = opts.mappings or {}
  M.provider = vim.tbl_deep_extend("force", M.provider, provider)
  M.mappings = vim.tbl_deep_extend("force", M.mappings, mappings)
  P(M.mappings)
end

return M
