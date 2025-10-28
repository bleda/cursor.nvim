# Cursor Neovim Integration

A Neovim plugin that integrates with Cursor CLI to provide AI assistance directly within Neovim. Inspired by [opencode.nvim](https://github.com/NickvanDyke/opencode.nvim).

## Features

- **Native Input**: Uses `vim.ui.input` for prompt input (works with your preferred input plugin)
- **Context Placeholders**: Support for `@buffer`, `@cursor`, `@selection`, `@this` placeholders
- **Completion**: Tab completion for context placeholders
- **Smart Window Reuse**: Reuses existing Cursor agent window instead of creating new splits
- **Auto-Close**: Automatically closes the window when Cursor agent process exits
- **No Default Keybindings**: You control your keybindings, no forced defaults
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

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "your-username/cursor.nvim",
  config = function()
    require("cursor").setup()
    
    -- Set up keybindings (example)
    local cursor = require("cursor")
    
    -- <leader>oc - Ask Cursor with input prompt
    vim.keymap.set("n", "<leader>oc", function()
      cursor.ask("@this: ")
    end, { desc = "Ask Cursor" })
    
    vim.keymap.set("x", "<leader>oc", function()
      local start_line, end_line = cursor.get_visual_selection()
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'x', false)
      vim.schedule(function()
        cursor.ask("@this: ", start_line, end_line)
      end)
    end, { desc = "Ask Cursor with selection" })
    
    -- <leader>oC - Open Cursor agent
    vim.keymap.set("n", "<leader>oC", function()
      cursor.open_cursor_agent()
    end, { desc = "Open Cursor Agent" })
  end
}
```

## Usage

With the example keybindings above, you can:

1. **Press `<leader>oc`** in normal mode to open an input prompt with `@this:` prefilled
2. **Select code in visual mode and press `<leader>oc`** to ask about the selection
3. **Press `<leader>oC`** to open the Cursor agent directly

### API Functions

- **`ask(default?, start_line?, end_line?)`** - Open an input prompt to ask Cursor
  - Supports context placeholders (`@buffer`, `@cursor`, `@selection`, `@this`)
  - Tab completion for placeholders
  - Press Enter to send, Esc to cancel

- **`prompt(text, start_line?, end_line?)`** - Send a prompt directly to Cursor
  - Replaces context placeholders in the text
  - Use this for predefined prompts

- **`open_cursor_agent()`** - Open Cursor agent in a split window

- **`get_visual_selection()`** - Get the current visual selection range

### Context Placeholders

| Placeholder | Description |
|-------------|-------------|
| `@buffer` | Current buffer file reference |
| `@cursor` | Current cursor position |
| `@selection` | Visual selection (if any) |
| `@this` | Visual selection if available, otherwise cursor position |

### Custom Keybindings Examples

If you want additional keybindings beyond the defaults:

```lua
local cursor = require("cursor")

-- Alternative keybinding for asking
vim.keymap.set({ "n", "x" }, "<C-a>", function()
  cursor.ask("@this: ")
end, { desc = "Ask Cursor" })

-- Quick add context to Cursor without prompt
vim.keymap.set({ "n", "x" }, "ga", function()
  local start_line, end_line = cursor.get_visual_selection()
  cursor.prompt("@this", start_line, end_line)
end, { desc = "Add to Cursor" })

-- Predefined prompts for common tasks
vim.keymap.set({ "n", "x" }, "<leader>ce", function()
  local start_line, end_line = cursor.get_visual_selection()
  cursor.prompt("Explain @this", start_line, end_line)
end, { desc = "Explain code" })

vim.keymap.set({ "n", "x" }, "<leader>cf", function()
  local start_line, end_line = cursor.get_visual_selection()
  cursor.prompt("Fix @this", start_line, end_line)
end, { desc = "Fix code" })

vim.keymap.set({ "n", "x" }, "<leader>ct", function()
  local start_line, end_line = cursor.get_visual_selection()
  cursor.prompt("Add tests for @this", start_line, end_line)
end, { desc = "Add tests" })
```

### Configuration

You can customize the plugin behavior and add custom context extractors:

```lua
require("cursor").setup({
  cursor_cmd = "cursor",  -- Path to cursor command (default: "cursor")
  
  -- Add custom context extractors (optional)
  contexts = {
    ["@buffer"] = function(ctx) return ctx:buffer() end,
    ["@cursor"] = function(ctx) return ctx:cursor_position() end,
    ["@selection"] = function(ctx) return ctx:visual_selection() end,
    ["@this"] = function(ctx) return ctx:this() end,
    
    -- Example: Add custom placeholder for git branch
    ["@branch"] = function(ctx)
      local branch = vim.fn.system("git branch --show-current"):gsub("\n", "")
      return branch
    end,
  },
})
```

## How it Works

1. **Input Prompt**: When you call `ask()`, uses `vim.ui.input` for a native input experience
2. **Context Placeholders**: Type `@buffer`, `@cursor`, `@selection`, or `@this` in your prompt
3. **Tab Completion**: Press Tab to complete context placeholders
4. **Context Rendering**: Placeholders are replaced with actual file references (e.g., `@file.lua:10-15`)
5. **Smart Window Reuse**: If a Cursor agent window is already open, it reuses that window
6. **Auto-Close**: The window automatically closes when the Cursor agent process exits
7. **Cursor Integration**: The rendered prompt is sent to Cursor agent via CLI

## Requirements

- Neovim 0.7+
- Cursor CLI available in PATH
- Terminal support in Neovim

## License

MIT
