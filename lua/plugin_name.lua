-- Cursor Neovim Integration Plugin
local cursor = {}

---@class Config
---@field leader_key string The leader key for keybindings
---@field cursor_cmd string Path to cursor command
local config = {
  leader_key = "<leader>",
  cursor_cmd = "cursor",
}

---@class CursorModule
local M = {}

---@type Config
M.config = config

---@param args Config?
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})
  M.setup_keybindings()
end

---Get the current context based on mode
---@return string context The context to send to cursor
local function get_context()
  local mode = vim.fn.mode()
  
  if mode == "v" or mode == "V" or mode == "\22" then -- visual mode
    local start_line = vim.fn.getpos("'<")[2]
    local end_line = vim.fn.getpos("'>")[2]
    local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
    return table.concat(lines, "\n")
  else -- normal mode
    local current_line = vim.api.nvim_get_current_line()
    return current_line
  end
end

---Show floating window for user input
M.show_cursor_prompt = function()
  local width = 50
  local height = 3
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  -- Create floating window
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    border = "rounded",
    title = "Cursor Prompt",
    title_pos = "center",
  })
  
  -- Set floating window options
  vim.api.nvim_win_set_option(win, "wrap", false)
  vim.api.nvim_win_set_option(win, "number", false)
  vim.api.nvim_win_set_option(win, "relativenumber", false)
  
  -- Add prompt text and empty line for input
  vim.api.nvim_buf_set_lines(buf, 0, 0, false, {"Enter your prompt for Cursor:", ""})
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  
  -- Position cursor at the beginning of the second line for user input
  vim.api.nvim_win_set_cursor(win, {2, 0})
  
  -- Set up key mappings for the floating window
  local function close_and_send()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    -- Skip the first line (prompt text) and get the actual user input
    local prompt = ""
    if #lines > 1 then
      local user_input = {}
      for i = 2, #lines do
        table.insert(user_input, lines[i])
      end
      prompt = table.concat(user_input, "\n")
    end
    
    vim.api.nvim_win_close(win, true)
    vim.api.nvim_buf_delete(buf, { force = true })
    
    if prompt and prompt ~= "" then
      M.send_to_cursor(prompt)
    end
  end
  
  local function close_without_sending()
    vim.api.nvim_win_close(win, true)
    vim.api.nvim_buf_delete(buf, { force = true })
  end
  
  -- Key mappings
  vim.keymap.set("i", "<CR>", close_and_send, { buffer = buf })
  vim.keymap.set("i", "<Esc>", close_without_sending, { buffer = buf })
  vim.keymap.set("n", "<CR>", close_and_send, { buffer = buf })
  vim.keymap.set("n", "<Esc>", close_without_sending, { buffer = buf })
  
  -- Start in insert mode
  vim.cmd("startinsert")
end

---Send prompt and context to cursor agent
---@param prompt string The user's prompt
M.send_to_cursor = function(prompt)
  local context = get_context()
  local full_prompt = string.format("Context:\n%s\n\nPrompt: %s", context, prompt)
  
  -- Open a new terminal buffer and run cursor agent
  vim.cmd("vsplit")
  local term_buf = vim.api.nvim_create_buf(false, true)
  local term_win = vim.api.nvim_open_win(term_buf, true, {
    relative = "editor",
    row = 0,
    col = math.floor(vim.o.columns / 2),
    width = math.floor(vim.o.columns / 2),
    height = vim.o.lines,
    border = "rounded",
    title = "Cursor Agent",
    title_pos = "center",
  })
  
  -- Start cursor agent with the prompt
  vim.fn.termopen(M.config.cursor_cmd .. " agent " .. vim.fn.shellescape(full_prompt))
  vim.cmd("startinsert")
end

---Open cursor agent in split window
M.open_cursor_agent = function()
  vim.cmd("vsplit")
  local term_buf = vim.api.nvim_create_buf(false, true)
  local term_win = vim.api.nvim_open_win(term_buf, true, {
    relative = "editor",
    row = 0,
    col = math.floor(vim.o.columns / 2),
    width = math.floor(vim.o.columns / 2),
    height = vim.o.lines,
    border = "rounded",
    title = "Cursor Agent",
    title_pos = "center",
  })
  
  -- Start cursor agent
  vim.fn.termopen(M.config.cursor_cmd .. " agent")
  vim.cmd("startinsert")
end

---Set up keybindings
M.setup_keybindings = function()
  vim.keymap.set("n", M.config.leader_key .. "oc", M.show_cursor_prompt, { desc = "Show Cursor prompt with context" })
  vim.keymap.set("v", M.config.leader_key .. "oc", M.show_cursor_prompt, { desc = "Show Cursor prompt with selection" })
  vim.keymap.set("n", M.config.leader_key .. "oC", M.open_cursor_agent, { desc = "Open Cursor agent in split" })
end

return M
