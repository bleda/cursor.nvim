# Cursor Neovim Integration

A Neovim plugin that integrates with Cursor CLI to provide AI assistance directly within Neovim.

## Features

- **Floating Window Prompt**: `<leader>oc` opens a floating window for user input
- **Context-Aware**: Automatically includes selected text (visual mode) or current line (normal mode) as context
- **Split Window Agent**: `<leader>oC` opens Cursor agent in a split window
- **Seamless Integration**: Works with Cursor CLI to provide AI assistance

## Installation

### Prerequisites

- Neovim 0.7+
- Cursor CLI installed and available in PATH

### Install Cursor CLI

If you don't have Cursor CLI installed:

```bash
# Install Cursor CLI (if not already installed)
# Visit https://cursor.com/download and install Cursor IDE
# The CLI should be available after installation
```

### Install the Plugin

Using your favorite plugin manager:

```lua
-- Using lazy.nvim
{
  "your-username/cursor.nvim",
  config = function()
    require("plugin_name").setup({
      leader_key = "<leader>", -- default leader key
      cursor_cmd = "cursor",   -- path to cursor command
    })
  end
}
```

## Usage

### Keybindings

- `<leader>oc` - Show floating window prompt with context
  - In normal mode: includes current line as context
  - In visual mode: includes selected text as context
- `<leader>oC` - Open Cursor agent in split window

### Configuration

```lua
require("plugin_name").setup({
  leader_key = "<leader>", -- Your leader key
  cursor_cmd = "cursor",   -- Path to cursor command (default: "cursor")
})
```

## How it Works

1. **Context Detection**: The plugin automatically detects whether you're in normal or visual mode
2. **Floating Window**: When you press `<leader>oc`, a floating window appears for input
3. **Context Inclusion**: Your selected text or current line is automatically included as context
4. **Cursor Integration**: The prompt and context are sent to Cursor agent via CLI
5. **Split Window**: Cursor agent opens in a split window for interaction

## Requirements

- Neovim 0.7+
- Cursor CLI available in PATH
- Terminal support in Neovim

## License

MIT