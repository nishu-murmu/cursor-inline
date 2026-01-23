local M = {}
local config = require("cursor-inline.config")
local prompts = require("cursor-inline.prompts")
local state = require("cursor-inline.state")
local ui = require("cursor-inline.ui")
local api_key = vim.fn.getenv("CURSOR_INLINE_API_KEY")

---@param input string
---@param on_response function(text string)
local function openai_curl_command(input, on_response)
  local payload = vim.json.encode({
    model = config.provider.model or "gpt-4.1-mini",
    input = {
      { role = "system", content = prompts.system_prompt },
      { role = "user",   content = input },
    },
  })
  local command = {
    "curl",
    "-s",
    "-X",
    "POST",
    "-H",
    "Content-Type: application/json",
    "-H",
    "Authorization: Bearer " .. api_key,
    "-d",
    payload,
    "https://api.openai.com/v1/responses"
  }
  vim.schedule(function()
    ui.start_spinner()
  end)
  vim.system(command, {
    text = true,
  }, function(res)
    vim.schedule(function()
      ui.stop_spinner()
    end)
    local data = vim.json.decode(res.stdout)
    local response_code = data.output and data.output[1] and data.output[1].content and data.output[1].content[1] and
        data.output[1].content[1].text
    if not response_code then
      vim.schedule(function()
        vim.notify("Failed to parse OpenAI response", vim.log.levels.ERROR)
      end)
      return
    end

    vim.schedule(function()
      on_response(response_code)
    end)
  end
  )
end

---@param input string
---@param on_response function(text string)
local function anthropic_curl_command(input, on_response)
  local payload = vim.json.encode({
    model = config.provider.model or "claude-sonnet-4-5",
    max_tokens = "1024",
    messages = {
      { role = "system", content = prompts.system_prompt },
      { role = "user",   content = input },
    },
  })
local command = {
    "curl",
    "-s",
    "-X",
    "POST",
    "-H",
    "x-api-key: " .. api_key,
    "-H",
    "anthropic-version: 2023-06-01",
    "-H",
    "Content-Type: application/json",
    "-d",
    payload,
    "https://api.anthropic.com/v1/messages"
  }
  vim.schedule(function()
    ui.start_spinner()
  end)
  vim.system(command, {
    text = true,
  }, function(res)
    vim.schedule(function()
      ui.stop_spinner()
    end)
    local data = vim.json.decode(res.stdout)
    local response_code = data.content and data.content[1] and data.content[1].text
    if not response_code then
      vim.schedule(function()
        vim.notify("Failed to parse Anthropic response", vim.log.levels.ERROR)
      end)
      return
    end

    vim.schedule(function()
      on_response(response_code)
    end)
  end
  )
end

---@param input string
---@param on_response function(text string)
function M.get_current_provider_response(input, on_response)
  local provider = config.provider.name
  local instruction = input
  local selected_text = state.selected_text
  local prompt_text = instruction .. "\n below is the selected code, \n```" .. selected_text .. "```"
  if provider == "openai" then
    openai_curl_command(prompt_text, on_response)
  end
  if provider == "anthropic" then
    anthropic_curl_command(prompt_text, on_response)
  end
end

return M
