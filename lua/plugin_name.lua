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

---Get the current context based on mode or provided range
---@param start_line number? Optional start line for visual selection
---@param end_line number? Optional end line for visual selection
---@return string context The context to send to cursor
local function get_context(start_line, end_line)
  local file_path = vim.api.nvim_buf_get_name(0)
  
  -- Get relative path from current working directory
  local cwd = vim.fn.getcwd()
  local relative_path = vim.fn.fnamemodify(file_path, ":.")
  
  -- If range is provided, use it
  if start_line and end_line and start_line ~= end_line then
    return string.format("@%s:%d-%d", relative_path, start_line, end_line)
  elseif start_line and end_line and start_line == end_line then
    return string.format("@%s:%d", relative_path, start_line)
  else -- normal mode - use current cursor position
    local current_line = vim.api.nvim_win_get_cursor(0)[1]
    return string.format("@%s:%d", relative_path, current_line)
  end
end

---Check if there's already a Cursor agent window open
---@return number|nil win_id The window ID if found, nil otherwise
local function find_cursor_agent_window()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local buf_name = vim.api.nvim_buf_get_name(buf)
    local title = vim.api.nvim_win_get_config(win).title
    
    -- Check if this is a terminal buffer with cursor agent
    if vim.api.nvim_buf_get_option(buf, "buftype") == "terminal" then
      -- Check if the terminal is running cursor agent
      local job_id = vim.api.nvim_buf_get_var(buf, "terminal_job_id")
      if job_id then
        local cmd = vim.fn.jobpid(job_id)
        if cmd and cmd > 0 then
          -- Check if the process is still running and likely cursor agent
          local process_name = vim.fn.system("ps -p " .. cmd .. " -o comm= 2>/dev/null"):gsub("%s+", "")
          if process_name:match("cursor") then
            return win
          end
        end
      end
    end
  end
  return nil
end

---Handle terminal job exit - close the window when Cursor agent exits
---@param job_id number The job ID that exited
---@param exit_code number The exit code
---@param event string The event type
local function on_cursor_agent_exit(job_id, exit_code, event)
  -- Find the window associated with this job
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_buf_get_option(buf, "buftype") == "terminal" then
      local buf_job_id = vim.api.nvim_buf_get_var(buf, "terminal_job_id")
      if buf_job_id == job_id then
        -- Close the window and delete the buffer
        vim.api.nvim_win_close(win, true)
        vim.api.nvim_buf_delete(buf, { force = true })
        break
      end
    end
  end
end

---Show floating window for user input
---@param start_line number? Optional start line for visual selection
---@param end_line number? Optional end line for visual selection
M.show_cursor_prompt = function(start_line, end_line)
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
      M.send_to_cursor(prompt, start_line, end_line)
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
---@param start_line number? Optional start line for visual selection
---@param end_line number? Optional end line for visual selection
M.send_to_cursor = function(prompt, start_line, end_line)
  local context = get_context(start_line, end_line)
  local full_prompt = string.format("%s %s", context, prompt)
  
  -- Check if there's already a Cursor agent window open
  local existing_win = find_cursor_agent_window()
  
  if existing_win then
    -- Reuse existing window
    vim.api.nvim_set_current_win(existing_win)
    local buf = vim.api.nvim_win_get_buf(existing_win)
    
    -- Send the new prompt to the existing terminal
    vim.api.nvim_chan_send(vim.api.nvim_buf_get_var(buf, "terminal_job_id"), full_prompt .. "\r")
    vim.cmd("startinsert")
  else
    -- Open a new terminal buffer and run cursor agent
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
    
    -- Start cursor agent with the prompt and exit callback
    vim.fn.termopen(M.config.cursor_cmd .. " agent " .. vim.fn.shellescape(full_prompt), {
      on_exit = on_cursor_agent_exit
    })
    vim.cmd("startinsert")
  end
end

---Open cursor agent in split window
M.open_cursor_agent = function()
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
  
  -- Start cursor agent with exit callback
  vim.fn.termopen(M.config.cursor_cmd .. " agent", {
    on_exit = on_cursor_agent_exit
  })
  vim.cmd("startinsert")
end

---Set up keybindings
M.setup_keybindings = function()
  vim.keymap.set("n", M.config.leader_key .. "oc", M.show_cursor_prompt, { desc = "Show Cursor prompt with context" })
  vim.keymap.set("v", M.config.leader_key .. "oc", function()
    -- Capture visual selection range while still in visual mode
    local start_line = vim.fn.line('v')
    local end_line = vim.fn.line('.')
    -- Ensure start_line is always less than end_line
    if start_line > end_line then
      start_line, end_line = end_line, start_line
    end
    -- Exit visual mode
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'x', false)
    -- Show prompt with captured range
    vim.schedule(function()
      M.show_cursor_prompt(start_line, end_line)
    end)
  end, { desc = "Show Cursor prompt with selection" })
  vim.keymap.set("n", M.config.leader_key .. "oC", M.open_cursor_agent, { desc = "Open Cursor agent in split" })
end

return M
