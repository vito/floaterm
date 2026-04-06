local M = {
  ns = vim.api.nvim_create_namespace "Floaterm",
  terminals = nil,
  bar_redraw_timeout = 10000,
  prev_win_focussed = 0,

  config = {
    border = false,
    autoinsert = true,
    size = { h = 60, w = 70 },

    -- { row , col } or fn() returning the table
    position = nil,

    -- must be functions
    mappings = { sidebar = nil, term = nil },
    terminals = {
      { name = "Terminal" },
    },

    -- Auto-update terminal names based on foreground process (Linux only)
    auto_name = true,
    auto_name_interval = 2000,
  },
}

return M
