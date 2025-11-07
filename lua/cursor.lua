-- Cursor Neovim Integration Plugin
local cursor = {}

---@class Config
---@field cursor_cmd string Path to cursor command
---@field contexts table<string, fun(context: table): string|nil> Context extractors
local config = {
  cursor_cmd = "cursor",
  -- Context extractors for placeholders
  contexts = {
    ["@buffer"] = function(ctx) return ctx:buffer() end,
    ["@cursor"] = function(ctx) return ctx:cursor_position() end,
    ["@selection"] = function(ctx) return ctx:visual_selection() end,
    ["@this"] = function(ctx) return ctx:this() end,
  },
}

---@class CursorModule
local M = {}

---@type Config
M.config = config

---@param args Config?
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})
end

---Context object for extracting editor context
---@class Context
local Context = {}
Context.__index = Context

---Create a new context object
---@param start_line number? Optional start line for visual selection
---@param end_line number? Optional end line for visual selection
---@return Context
function Context.new(start_line, end_line)
  local self = setmetatable({}, Context)
  self.start_line = start_line
  self.end_line = end_line
  return self
end

---Get current buffer content with file reference
---@return string
function Context:buffer()
  local file_path = vim.api.nvim_buf_get_name(0)
  local relative_path = vim.fn.fnamemodify(file_path, ":.")
  return string.format("@%s", relative_path)
end

---Get cursor position with file reference
---@return string
function Context:cursor_position()
  local file_path = vim.api.nvim_buf_get_name(0)
  local relative_path = vim.fn.fnamemodify(file_path, ":.")
  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  return string.format("@%s:%d", relative_path, current_line)
end

---Get visual selection with file reference
---@return string|nil
function Context:visual_selection()
  if not self.start_line or not self.end_line then
    return nil
  end
  
  local file_path = vim.api.nvim_buf_get_name(0)
  local relative_path = vim.fn.fnamemodify(file_path, ":.")
  
  if self.start_line == self.end_line then
    return string.format("@%s:%d", relative_path, self.start_line)
  else
    return string.format("@%s:%d-%d", relative_path, self.start_line, self.end_line)
  end
end

---Get "this" - visual selection if available, otherwise cursor position
---@return string
function Context:this()
  local selection = self:visual_selection()
  if selection then
    return selection
  end
  return self:cursor_position()
end

---Render a prompt by replacing placeholders with their context
---@param prompt string The prompt with placeholders
---@return string The rendered prompt
function Context:render(prompt)
  local rendered = prompt
  for placeholder, extractor in pairs(M.config.contexts) do
    local replacement = extractor(self)
    if replacement then
      rendered = rendered:gsub(vim.pesc(placeholder), replacement)
    end
  end
  return rendered
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
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_option(buf, "buftype") == "terminal" then
        local ok, buf_job_id = pcall(vim.api.nvim_buf_get_var, buf, "terminal_job_id")
        if ok and buf_job_id == job_id then
          -- Close the window and delete the buffer
          if vim.api.nvim_win_is_valid(win) then
            pcall(vim.api.nvim_win_close, win, true)
          end
          if vim.api.nvim_buf_is_valid(buf) then
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
          end
          break
        end
      end
    end
  end
end

---Create a right-hand vertical split for the Cursor agent terminal
---@return number term_buf, number term_win
local function open_cursor_agent_split()
  local term_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(term_buf, "bufhidden", "wipe")

  vim.cmd("botright vsplit")
  local term_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(term_win, term_buf)
  vim.api.nvim_set_current_buf(term_buf)
  vim.api.nvim_win_set_option(term_win, "number", false)
  vim.api.nvim_win_set_option(term_win, "relativenumber", false)

  return term_buf, term_win
end

---Completion function for context placeholders
---Must be a global variable for use with vim.ui.input
---@param ArgLead string The text being completed
---@param CmdLine string The entire current input line
---@param CursorPos number The cursor position in the input line
---@return table<string> items A list of filtered completion items
_G.cursor_completion = function(ArgLead, CmdLine, CursorPos)
  local start_idx, end_idx = CmdLine:find("([^%s]+)$")
  local latest_word = start_idx and CmdLine:sub(start_idx, end_idx) or nil

  local items = {}
  for placeholder, _ in pairs(M.config.contexts) do
    if not latest_word then
      local new_cmd = CmdLine .. placeholder
      table.insert(items, new_cmd)
    elseif placeholder:find(latest_word, 1, true) == 1 then
      local new_cmd = CmdLine:sub(1, start_idx - 1) .. placeholder .. CmdLine:sub(end_idx + 1)
      table.insert(items, new_cmd)
    end
  end
  return items
end

---Ask user for input and send to Cursor
---@param default string? Default text to prefill
---@param start_line number? Optional start line for visual selection
---@param end_line number? Optional end line for visual selection
M.ask = function(default, start_line, end_line)
  local context = Context.new(start_line, end_line)
  
  vim.ui.input({
    prompt = "Ask Cursor: ",
    default = default or "",
    completion = "customlist,v:lua.cursor_completion",
  }, function(input)
    if input and input ~= "" then
      M.prompt(input, start_line, end_line)
    end
  end)
end

---Send prompt with context to Cursor (deprecated, use ask instead)
---@param start_line number? Optional start line for visual selection
---@param end_line number? Optional end line for visual selection
M.show_cursor_prompt = function(start_line, end_line)
  M.ask(nil, start_line, end_line)
end

---Send prompt with context to Cursor
---@param prompt string The user's prompt with optional placeholders
---@param start_line number? Optional start line for visual selection
---@param end_line number? Optional end line for visual selection
M.prompt = function(prompt, start_line, end_line)
  local context = Context.new(start_line, end_line)
  local rendered_prompt = context:render(prompt)
  
  -- Check if there's already a Cursor agent window open
  local existing_win = find_cursor_agent_window()
  
  if existing_win then
    -- Reuse existing window
    vim.api.nvim_set_current_win(existing_win)
    local buf = vim.api.nvim_win_get_buf(existing_win)

    -- Send the new prompt to the existing terminal
    vim.api.nvim_chan_send(vim.api.nvim_buf_get_var(buf, "terminal_job_id"), rendered_prompt .. "\n")
    vim.cmd("startinsert")
  else
    local term_buf, term_win = open_cursor_agent_split()
    vim.api.nvim_set_current_win(term_win)

    -- Start cursor agent and exit callback
    local job_id = vim.fn.termopen(M.config.cursor_cmd .. " agent", {
      on_exit = on_cursor_agent_exit
    })

    -- Wait a brief moment for the agent to initialize, then send the prompt
    vim.defer_fn(function()
      if vim.api.nvim_buf_is_valid(term_buf) then
        vim.api.nvim_chan_send(job_id, rendered_prompt .. "\n")
      end
    end, 100)

    -- Auto-focus on window enter: enter insert mode when switching to this window
    vim.api.nvim_create_autocmd("WinEnter", {
      buffer = term_buf,
      callback = function()
        -- Only enter insert mode if the buffer is still a terminal
        if vim.api.nvim_buf_is_valid(term_buf) and vim.api.nvim_buf_get_option(term_buf, "buftype") == "terminal" then
          vim.cmd("startinsert")
        end
      end,
      desc = "Auto-focus cursor agent input on window enter",
    })

    vim.cmd("startinsert")
  end
end

---Send prompt and context to cursor agent (deprecated, use prompt instead)
---@param prompt_text string The user's prompt
---@param start_line number? Optional start line for visual selection
---@param end_line number? Optional end line for visual selection
M.send_to_cursor = function(prompt_text, start_line, end_line)
  M.prompt(prompt_text, start_line, end_line)
end

---Open cursor agent in split window
M.open_cursor_agent = function()
  local existing_win = find_cursor_agent_window()

  if existing_win then
    vim.api.nvim_set_current_win(existing_win)
    vim.cmd("startinsert")
    return
  end

  local term_buf, term_win = open_cursor_agent_split()
  vim.api.nvim_set_current_win(term_win)

  -- Start cursor agent with exit callback
  vim.fn.termopen(M.config.cursor_cmd .. " agent", {
    on_exit = on_cursor_agent_exit
  })

  -- Auto-focus on window enter: enter insert mode when switching to this window
  vim.api.nvim_create_autocmd("WinEnter", {
    buffer = term_buf,
    callback = function()
      -- Only enter insert mode if the buffer is still a terminal
      if vim.api.nvim_buf_is_valid(term_buf) and vim.api.nvim_buf_get_option(term_buf, "buftype") == "terminal" then
        vim.cmd("startinsert")
      end
    end,
    desc = "Auto-focus cursor agent input on window enter",
  })

  vim.cmd("startinsert")
end

---Helper function to get visual selection range
---@return number start_line, number end_line
M.get_visual_selection = function()
  local start_line = vim.fn.line('v')
  local end_line = vim.fn.line('.')
  -- Ensure start_line is always less than end_line
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end
  return start_line, end_line
end

return M
