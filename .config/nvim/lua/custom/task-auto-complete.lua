local M = {}

-- Configuration
M.config = {
  timestamp_format = "> Completed: %Y-%m-%d %H:%M",
  completed_headings = { "completed", "done", "finished" },
  daily_notes_folder = "30%-DailyNotes",
  log_heading = "log",
}

-- Check if file is in DailyNotes folder
local function is_daily_notes_file(filepath)
  if not filepath then return false end
  return filepath:match(M.config.daily_notes_folder) ~= nil
end

-- Find completed section (case-insensitive) - works with any heading level
-- Returns: section_start_line, section_end_line (or nil if not found)
local function find_completed_section(lines)
  local start_line = nil
  local end_line = nil
  local heading_line = nil

  for i, line in ipairs(lines) do
    if line:match("^#+") then
      local heading_text = line:lower():gsub("^#+%s*", ""):gsub("%s*$", "")
      for _, keyword in ipairs(M.config.completed_headings) do
        if heading_text == keyword then
          start_line = i
          heading_line = line
          break
        end
      end
      if heading_text == M.config.log_heading and start_line then
        -- Found Log section after Completed, so Completed ends here
        end_line = i - 1
        break
      end
    end
  end

  if start_line and not end_line then
    end_line = #lines
  end

  return start_line, end_line, heading_line
end

-- Find Log section (case-insensitive) - works with any heading level
local function find_log_section(lines)
  for i, line in ipairs(lines) do
    if line:match("^#+") then
      local heading_text = line:lower():gsub("^#+%s*", ""):gsub("%s*$", "")
      if heading_text == M.config.log_heading then
        return i
      end
    end
  end
  return nil
end

-- Find the best position for Completed section
local function find_completed_section_position(lines, filepath)
  local completed_start, completed_end, heading = find_completed_section(lines)
  if completed_start then
    return completed_start, completed_end, false, heading -- Section exists
  end

  -- Need to create section
  local is_daily = is_daily_notes_file(filepath)

  if is_daily then
    -- For DailyNotes: place above Log section
    local log_line = find_log_section(lines)
    if log_line then
      return log_line, log_line - 1, true, nil -- Insert before Log
    end
  end

  -- Default: end of file
  return #lines + 1, #lines, true, nil
end

-- Extract task group (task + nested subtasks)
local function extract_task_group(lines, start_line)
  local task_group = {}
  local base_indent = nil
  local end_line = start_line

  -- Get the checked task line
  local task_line = lines[start_line]
  table.insert(task_group, task_line)

  -- Determine base indentation level
  base_indent = task_line:match("^(%s*)")

  -- Look for nested subtasks
  for i = start_line + 1, #lines do
    local line = lines[i]
    local indent = line:match("^(%s*)")

    -- Check if this line is more indented (subtask) or empty line
    if #indent > #base_indent then
      table.insert(task_group, line)
      end_line = i
    elseif line:match("^%s*$") then
      -- Empty line - include it if it's within the task group
      table.insert(task_group, line)
      end_line = i
    else
      -- Less or equal indent - task group ends
      break
    end
  end

  return task_group, end_line
end

-- Find the nearest heading above a line
local function find_nearest_heading(lines, line_num)
  for i = line_num - 1, 1, -1 do
    local heading = lines[i]:match("^#+%s+(.+)$")
    if heading then
      return heading
    end
  end
  return nil
end

-- Add heading context to the task line
local function add_heading_context(task_line, heading)
  local prefix, text = task_line:match("^(%s*%-%s*%[[xX]%]%s*)(.*)$")
  if prefix and text then
    return prefix .. heading .. " > " .. text
  end
  return task_line
end

-- Add timestamp inline to the task line
local function add_timestamp_inline(task_line)
  local timestamp = os.date(M.config.timestamp_format)
  -- Append timestamp to the end of the task line
  return task_line .. " " .. timestamp
end

-- Check if a line is within the Completed section
local function is_in_completed_section(line_num, completed_start, completed_end)
  if not completed_start or not completed_end then
    return false
  end
  return line_num > completed_start and line_num <= completed_end
end

-- Main function to process checkbox completion
function M.process_checkbox_completion()
  local bufnr = vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)

  -- Only process markdown files
  if not filepath:match("%.md$") then
    return
  end

  -- Get all lines
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Find existing Completed section boundaries
  local completed_start, completed_end, completed_heading = find_completed_section(lines)

  -- Find or create Completed section position
  local completed_pos, completed_end_pos, needs_creation, _ = find_completed_section_position(lines, filepath)

  -- Collect all completed task groups (outside of Completed section)
  local task_groups = {}
  local processed_lines = {}
  local i = 1

  while i <= #lines do
    local line = lines[i]

    -- Skip if in Completed section
    if is_in_completed_section(i, completed_start, completed_end) then
      i = i + 1
      goto continue
    end

    -- Check if this is a completed task with "- [x]" format
    if line:match("^%s*%-%s*%[[xX]%]") and not line:match("> Completed:") then
      -- Extract the entire task group
      local task_group, end_line = extract_task_group(lines, i)

      -- Add heading context and timestamp to first line
      local heading = find_nearest_heading(lines, i)
      if heading then
        task_group[1] = add_heading_context(task_group[1], heading)
      end
      task_group[1] = add_timestamp_inline(task_group[1])

      -- Store task group and mark lines for removal
      table.insert(task_groups, {
        group = task_group,
        start_line = i,
        end_line = end_line
      })

      -- Mark these lines as processed
      for j = i, end_line do
        processed_lines[j] = true
      end

      -- Skip past this task group
      i = end_line + 1
    else
      i = i + 1
    end

    ::continue::
  end

  -- If no completed tasks found, exit
  if #task_groups == 0 then
    return
  end

  -- Create Completed section if needed
  if needs_creation then
    if is_daily_notes_file(filepath) and completed_pos <= #lines then
      -- Insert before Log section (no blank line)
      table.insert(lines, completed_pos, "## Completed")
      completed_pos = completed_pos + 1
    else
      -- Add at end (no blank line)
      table.insert(lines, "## Completed")
      completed_pos = #lines + 1
    end
  else
    -- Move past the heading line
    completed_pos = completed_pos + 1
  end

  -- Collect all non-empty lines from all task groups in reverse order (for insertion)
  local all_tasks = {}
  for _, task_data in ipairs(task_groups) do
    -- Insert task lines in reverse order
    for j = #task_data.group, 1, -1 do
      local task_line = task_data.group[j]
      if task_line:match("^%s*$") == nil then
        table.insert(all_tasks, task_line)
      end
    end
  end

  -- Insert all tasks at the Completed section position
  for _, task_line in ipairs(all_tasks) do
    table.insert(lines, completed_pos, task_line)
  end

  -- Remove original task groups (in reverse order to maintain indices)
  -- Also remove trailing blank lines
  local lines_to_remove = {}
  for _, task_data in ipairs(task_groups) do
    for j = task_data.start_line, task_data.end_line do
      table.insert(lines_to_remove, j)
    end
    -- Check for and remove trailing blank line
    local next_line = task_data.end_line + 1
    if next_line <= #lines and lines[next_line]:match("^%s*$") then
      table.insert(lines_to_remove, next_line)
    end
  end

  -- Sort in reverse order for safe removal
  table.sort(lines_to_remove, function(a, b) return a > b end)

  -- Remove lines
  for _, line_num in ipairs(lines_to_remove) do
    table.remove(lines, line_num)
  end

  -- Update buffer (user will see changes, can save manually)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
end

-- Setup function
function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.config, opts)

  -- Create autocommand for BufWritePost (trigger on file save)
  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = "*.md",
    callback = function()
      M.process_checkbox_completion()
    end,
    desc = "Move completed tasks to Completed section on save",
  })
end

return M
