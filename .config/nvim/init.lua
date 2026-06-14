vim.g.sqlite_clib_path = "/usr/lib/aarch64-linux-gnu/libsqlite3.so.0"

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
require("config.markdown-folding")
require("snippets")

-- Auto-move completed tasks to Completed section
require("custom.task-auto-complete").setup()

-- Filter tasks by file-level tags (requires obsidian.nvim)
require("custom.obsidian-task-filter").setup({
  picker = "telescope", -- Uses telescope for better UI
  show_completed = false,
  preview_context = 3,
})
