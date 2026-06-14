return {
  "iamcco/markdown-preview.nvim",
  opts = function()
    -- Configure Zen browser path (works across clean installs)
    -- Zen browser installed via Scoop at this location
    local zen_browser = "C:/Users/student/scoop/shims/zen.exe"

    -- Verify zen.exe exists
    if vim.loop.fs_stat(zen_browser) then
      vim.g.mkdp_browser = zen_browser
    else
      -- Fallback to system default if zen.exe not found
      vim.g.mkdp_browser = ""
    end

    -- Optional: Show preview URL for debugging
    vim.g.mkdp_echo_preview_url = 1
  end,
}
