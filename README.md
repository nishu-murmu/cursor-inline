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
- An OpenAI API key with access to the configured model (default: `gpt-4.1-mini`).

## Installation

Use your favorite plugin manager. Examples below assume the repository path is `nishu-murmu/cursor-inline` – adjust if your repo is named differently.

### lazy.nvim

```lua
{
  "nishu-murmu/cursor-inline",
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
    open_input = "<leader>e",
    accept_response = "<leader>y",
    deny_response = "<leader>n",
  },
  provider = {
    name = "openai",
    model = "gpt-4.1-mini",
  },
}
```

## API key handling

On the first request, if no API key is found, the plugin:

- Notifies that the `<provider.name>` API key is missing.
- Prompts you in Neovim for the key.
- Stores the key in a file under your Neovim `stdpath("data")` directory (plain text).

Subsequent requests reuse the stored key. Be aware that this key is stored unencrypted on your machine.

---

## TODOs

- [ ] Integrate multiple AI providers
- [ ] Diff previews for edits
- [ ] Streaming response support

---

## License

MIT
