local wezterm = require("wezterm")
local act = wezterm.action
local utils = require("utils")
local config = wezterm.config_builder()

config.default_prog = { "/usr/bin/zsh", "--login", "-i" }
config.font = wezterm.font_with_fallback({ "JetBrains Mono NF", "JetBrains Mono" })
config.font_size = 10.0
config.animation_fps = 1
config.harfbuzz_features = { "calt=1", "clig=1", "liga=1" }
config.color_scheme = "Catppuccin Mocha"
config.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }
config.window_decorations = "RESIZE"
config.window_frame = { border_left_width = 0, border_right_width = 0, border_bottom_height = 0, border_top_height = 0 }
config.tab_bar_at_bottom = false
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.tab_max_width = 32
config.inactive_pane_hsb = { saturation = 1, brightness = 1 }
config.front_end = "WebGpu"
config.colors = {
  compose_cursor = "#94e2d5",
  tab_bar = {
    background = "#1e1e2e",
    active_tab = { bg_color = "#585b70", fg_color = "#f5e0dc", intensity = "Bold" },
    inactive_tab = { bg_color = "#181825", fg_color = "#a6adc8" },
    inactive_tab_hover = { bg_color = "#313244", fg_color = "#cdd6f4", italic = true },
    new_tab = { bg_color = "#1e1e2e", fg_color = "#a6adc8" },
    new_tab_hover = { bg_color = "#313244", fg_color = "#cdd6f4", italic = true },
  },
}
config.hyperlink_rules = {
  { regex = "\((\w+://\S+)\)", format = "$1", highlight = 1 },
  { regex = "\[(\w+://\S+)\]", format = "$1", highlight = 1 },
  { regex = "\{(\w+://\S+)\}", format = "$1", highlight = 1 },
  { regex = "<(\w+://\S+)>", format = "$1", highlight = 1 },
  { regex = "[^(]\b(\w+://\S+[)/a-zA-Z0-9-]+)", format = "$1", highlight = 1 },
  { regex = "\b\w+@[\w-]+(\.[\w-]+)+\b", format = "mailto:$0" },
}
table.insert(config.hyperlink_rules, { regex = [[["]?([\w][-\w\d]+)(/)([-\w\d\.]+)["]?]], format = "https://github.com/$1/$3" })

wezterm.on("update-right-status", function(window, pane)
  local name = window:active_key_table()
  if name then name = "TABLE: " .. name elseif window:leader_is_active() then name = "LEADER" end
  window:set_right_status(name or "")
end)

local function get_pane_last_command(id)
  local success, stdout = wezterm.run_child_process({
    "wezterm", "cli", "get-text", "--pane-id", tostring(id), "--start-line", "-5",
  })
  if not success or not stdout then return nil end
  local lines = {}
  for line in stdout:gmatch("[^\r\n]+") do
    if line:match("%S") then table.insert(lines, line) end
  end
  for i = #lines, 1, -1 do
    local cmd = lines[i]:match("[%$#>]%s+(.+)$")
    if cmd then return cmd:gsub("^%s+", ""):sub(1, 40) end
    if not lines[i]:match("^%s*$") and not lines[i]:match("^[>%$#]") then
      return lines[i]:gsub("^%s+", ""):sub(1, 40)
    end
  end
  return nil
end

local function show_move_pane_selector(window, pane, dir)
  local success, stdout = wezterm.run_child_process({
    "wezterm", "cli", "list", "--format", "json",
  })
  if not success then
    window:toast_notification("Failed to list panes")
    return
  end
  local panes = wezterm.json_parse(stdout) or {}
  local choices = {}
  for _, p in ipairs(panes) do
    if p.pane_id ~= pane:pane_id() then
      local _, cwd = utils.split_from_url(p.cwd or "file://")
      local dir_display = utils.convert_home_dir(cwd)
      local size_str = string.format("%dx%d", p.size.cols, p.size.rows)
      local tab_title = p.tab_title or ("Tab " .. p.tab_id)
      local last_cmd = get_pane_last_command(p.pane_id)
      local label
      if last_cmd and last_cmd ~= "" then
        label = string.format("#%d | %s | %s | %s | %s", p.pane_id, tab_title, dir_display, size_str, last_cmd)
      else
        label = string.format("#%d | %s | %s | %s | %s", p.pane_id, tab_title, dir_display, size_str, p.title or "shell")
      end
      table.insert(choices, { id = tostring(p.pane_id), label = label })
    end
  end
  if #choices == 0 then
    window:toast_notification("No other panes available to move")
    return
  end
  table.sort(choices, function(a, b) return tonumber(a.id) < tonumber(b.id) end)
  window:perform_action(
    act.InputSelector({
      title = "Move Pane - Split " .. dir,
      choices = choices,
      fuzzy = true,
      action = wezterm.action_callback(function(_, _, id)
        if not id then return end
        local d = ({ Left = "left", Right = "right", Up = "top", Down = "bottom" })[dir]
        local ok, _, err = wezterm.run_child_process({
          "wezterm", "cli", "split-pane", "--move-pane-id", id, "--" .. d, "--percent", "50",
        })
        if not ok then window:toast_notification("Failed to move pane: " .. (err or "")) end
      end),
    }),
    pane
  )
end

wezterm.on("move-pane-split-left", function(window, pane)
  show_move_pane_selector(window, pane, "Left")
end)
wezterm.on("move-pane-split-down", function(window, pane)
  show_move_pane_selector(window, pane, "Down")
end)
wezterm.on("move-pane-split-up", function(window, pane)
  show_move_pane_selector(window, pane, "Up")
end)
wezterm.on("move-pane-split-right", function(window, pane)
  show_move_pane_selector(window, pane, "Right")
end)

config.leader = { key = "Space", mods = "CTRL", timeout_milliseconds = 4294967295 }
config.keys = {
  { key = "c", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
  { key = "&", mods = "LEADER", action = act.CloseCurrentTab({ confirm = true }) },
  { key = "Tab", mods = "CTRL", action = act.ActivateTabRelative(1) },
  { key = "Tab", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(-1) },
  { key = "\\", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "-", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
  { key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
  { key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
  { key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
  { key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
  { key = "o", mods = "LEADER", action = act.ActivatePaneDirection("Next") },
  { key = "x", mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) },
  { key = "a", mods = "LEADER", action = act.ShowLauncher },
  { key = "t", mods = "LEADER", action = act.ShowTabNavigator },
  { key = "[", mods = "LEADER", action = act.ActivateCopyMode },
  { key = "]", mods = "LEADER", action = act.CopyTo("ClipboardAndPrimarySelection") },
  { key = "f", mods = "LEADER", action = act.TogglePaneZoomState },
  { key = "s", mods = "LEADER", action = act.PaneSelect({ alphabet = "1234567890" }) },
  { key = "r", mods = "LEADER", action = act.ActivateKeyTable({ name = "resize_pane", one_shot = false }) },
  { key = "m", mods = "LEADER", action = act.ActivateKeyTable({ name = "move_pane_direction", one_shot = false }) },
}
config.key_tables = {
  resize_pane = {
    { key = "h", action = act.AdjustPaneSize({ "Left", 3 }) },
    { key = "j", action = act.AdjustPaneSize({ "Down", 3 }) },
    { key = "k", action = act.AdjustPaneSize({ "Up", 3 }) },
    { key = "l", action = act.AdjustPaneSize({ "Right", 3 }) },
    { key = "Escape", action = "PopKeyTable" },
  },
  move_pane_direction = {
    { key = "h", action = act.EmitEvent("move-pane-split-left") },
    { key = "j", action = act.EmitEvent("move-pane-split-down") },
    { key = "k", action = act.EmitEvent("move-pane-split-up") },
    { key = "l", action = act.EmitEvent("move-pane-split-right") },
    { key = "Escape", action = "PopKeyTable" },
  },
}
return config
