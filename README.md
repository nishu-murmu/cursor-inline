<p align="center">
  <h1>Cursor-Inline</h1>
</p>

Cursor-style inline AI editing for Neovim. Select code, describe the change, and get an inline, highlighted edit you can accept or reject—similar to Cursor’s inline workflow.

https://github.com/user-attachments/assets/55e2a362-19bf-4813-a734-ca28a9916b16


## Features

- Inline popup for AI edits, triggered from visual selection.
- One-key accept or reject for generated inline edits.

## Requirements

- Neovim with support for `vim.system` (0.10+ is recommended).
- `curl` available in your `PATH`.
- An OpenAI API key with access to the configured model (default: `gpt-5.4-mini`).


### Providers Available
1. [OpenAI](https://platform.openai.com/docs/api-reference/authentication)
2. [Anthropic](https://platform.claude.com/docs/en/api/overview)

## Installation

Use your favorite plugin manager. Examples below assume the repository path is `nishu-murmu/cursor-inline` – adjust if your repo is named differently.

### lazy.nvim

```lua
{
  "nishu-murmu/cursor-inline",
  event = "BufReadPost",
  config = function()
    require("cursor-inline").setup()
  end,
}
```

### packer.nvim

```lua
use({
  "nishu-murmu/cursor-inline",
  config = function()
    require("cursor-inline").setup()
  end,
})
```

### vim-plug

```vim
Plug 'nishu-murmu/cursor-inline'
```

Then, somewhere in your Neovim config:

```lua
require("cursor-inline").setup()
```

## Configuration

You can customize key mappings and the OpenAI model/provider via `setup`.

Default configuration from `lua/cursor-inline/config.lua`:

```lua
{
  mappings = {
    open_input = "<Space>e",
    accept_response = "<Space>y",
    deny_response = "<Space>n",
  },
  provider = {
    name = "openai",
    model = "gpt-5.4-mini",
  },
}
```

---

## TODOs

- [x] Integrate multiple AI providers
- [x] Adding spinner animations
- [ ] Diff previews for edits
- [ ] Streaming response support

---

## License

MIT
