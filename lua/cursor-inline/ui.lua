local M = {}

local api = vim.api
local config = require("cursor-inline.config")
local state = require("cursor-inline.state")

local bufnr, win_id
local input_overridden
local spinner_timer = nil
local spinner_timeout = nil

local function override_vim_input()
  if input_overridden then return end
  input_overridden = true
  vim.ui.input = function(opts, on_confirm)
    opts = opts or {}
    local prompt = opts.prompt
    local default = opts.default or ""
    local buf = api.nvim_create_buf(false, true)
    state.bufs.input = buf
    api.nvim_buf_set_lines(buf, 0, -1, false, { default })
    vim.api.nvim_set_option_value("modifiable", true, { buf = buf })

    local win_opts = {
      relative = "cursor",
      row = 0,
      col = 1,
      width = 40,
      height = 1,
      style = "minimal",
      border = "rounded",
      title = prompt,
      title_pos = "left",
    }

    local win = api.nvim_open_win(buf, true, win_opts)

    local function close_input()
      api.nvim_win_close(win, true)
    end

    local function confirm()
      local text = table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
      on_confirm(text ~= "" and text or nil, function(response)
        if(response) then close_input() end 
      end)
    end

    vim.keymap.set("i", "<CR>", confirm, { buffer = buf })
    vim.keymap.set("i", "<Esc>", function()
      api.nvim_win_close(win, true)
      on_confirm(nil, nil)
      close_input()
      vim.cmd("stopinsert")
    end, { buffer = buf })
    vim.cmd("startinsert")
  end
end

function M.open_inline_command()
  if win_id and api.nvim_win_is_valid(win_id) then return end

  bufnr = api.nvim_create_buf(false, true)
  local open_input = config.mappings.open_input or ""
  api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Quick Edit (" .. open_input .. ")" })

  win_id = api.nvim_open_win(bufnr, false, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = 24,
    height = 1,
    style = "minimal",
  })
end

function M.move_inline_command()
  if not (win_id and api.nvim_win_is_valid(win_id)) then return end

  api.nvim_win_set_config(win_id, {
    relative = "cursor",
    row = 1,
    col = 0,
  })
end

function M.close_inline_command()
  if win_id and api.nvim_win_is_valid(win_id) then
    api.nvim_win_close(win_id, true)
  end
  if bufnr and api.nvim_buf_is_valid(bufnr) then
    api.nvim_buf_delete(bufnr, { force = true })
  end
  win_id, bufnr = nil, nil
end

function M.open_post_response_commands(row, lines, width, zindex, existing_bufnr)
  local buf = existing_bufnr or api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, { lines })
  local win = api.nvim_open_win(buf, false, {
    relative = "editor",
    row = row,
    col = vim.o.columns - width,
    width = width,
    height = 1,
    style = "minimal",
    zindex = zindex,
    focusable = false,
    noautocmd = true,
  })
  local ns = api.nvim_create_namespace('')
  api.nvim_win_set_hl_ns(win, ns)
  return win, buf
end

function M.close_post_response_commands(win)
  if win and api.nvim_win_is_valid(win) then
    api.nvim_win_close(win, true)
  end
end

function M.setup()
  override_vim_input()
end

function M.start_spinner()
  local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
  local spinner_index = 1
  local floating_buf = state.bufs.input

  -- Stop existing spinner if running
  if spinner_timer then
    spinner_timer:stop()
    spinner_timer = nil
    if floating_buf ~= nil then
      vim.api.nvim_buf_clear_namespace(floating_buf, -1, 0, -1)
    end
  end

  -- Create and start new spinner timer
  spinner_timer = vim.loop.new_timer()
  if spinner_timer == nil then return end
  spinner_timer:start(0, 100, vim.schedule_wrap(function()
    if not (floating_buf and vim.api.nvim_buf_is_valid(floating_buf)) then
      return
    end
    local line = vim.api.nvim_buf_get_lines(floating_buf, 0, 1, false)[1] or ""
    local first_char_end = vim.str_byteindex(line, "utf-32", 1, false) or 0
    vim.api.nvim_buf_set_text(
      floating_buf,
      0,
      0,
      0,
      first_char_end,
      { spinner_frames[spinner_index] }
    )
    spinner_index = spinner_index % #spinner_frames + 1
  end))

  -- Set up timeout to stop spinner after 60 seconds
  spinner_timeout = vim.loop.new_timer()
  if spinner_timeout then
    spinner_timeout:start(60000, 0, vim.schedule_wrap(function()
      vim.schedule(function()
        vim.notify("Request timed out after 60 seconds", vim.log.levels.WARN)
        M.stop_spinner()
      end)
    end))
  end
end

function M.stop_spinner()
  if spinner_timer then
    spinner_timer:stop()
    spinner_timer = nil
  end
  local floating_buf = state.bufs.input
  if floating_buf ~= nil and vim.api.nvim_buf_is_valid(floating_buf) then
    vim.api.nvim_buf_clear_namespace(floating_buf, -1, 0, -1)
  end
end

return M
