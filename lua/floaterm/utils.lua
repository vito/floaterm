local M = {}
local api = vim.api
local map = vim.keymap.set
local state = require "floaterm.state"
local volt_redraw = require("volt").redraw
local shell = vim.o.shell

M.convert_buf2term = function(cmd)
  if cmd then
    cmd = type(cmd) == "function" and cmd() or cmd
    cmd = { shell, "-c", cmd .. "; " .. shell }
  else
    cmd = { shell }
  end
  vim.fn.jobstart(cmd, { term = true })
end

M.new_term = function(opts)
  local defaults = {
    buf = api.nvim_create_buf(false, true),
    time = os.date "%H:%M",
    name = "Terminal",
  }

  return vim.tbl_extend("force", defaults, opts or {})
end

M.add_keymap = function(key, buf)
  map("n", tostring(key), function()
    M.switch_buf(buf)
  end, { buffer = state.sidebuf })
end

M.gen_term_bufs = function()
  for i, _ in ipairs(state.terminals) do
    state.terminals[i] = vim.tbl_extend("force", M.new_term(), state.terminals[i])
    local buf = state.terminals[i].buf
    M.add_keymap(i, buf)
  end
end

M.set_termwin_hl = function()
  if state.config.border then
    vim.wo[state.win].winhl = "Normal:normal,floatborder:comment"
  else
    vim.wo[state.win].winhl = "Normal:exdarkbg,floatBorder:exdarkborder"
  end
end

M.switch_buf = function(buf)
  state.buf = buf

  volt_redraw(state.sidebuf, "bufs")
  volt_redraw(state.barbuf, "bar")

  if not api.nvim_win_is_valid(state.win) then
    state.win = api.nvim_open_win(state.buf, true, state.term_win_opts)
    M.set_termwin_hl()
  end

  api.nvim_set_current_win(state.win)
  api.nvim_set_current_buf(buf)

  local details = vim.tbl_filter(function(x)
    return x.buf == buf
  end, state.terminals)

  if vim.bo[buf].buftype ~= "terminal" then
    vim.bo[buf].ft = "Floaterm"
    M.convert_buf2term(details[1].cmd)
    volt_redraw(state.barbuf, "bar")

    map({ "t", "n" }, "<C-h>", function()
      require("floaterm.api").switch_wins()
    end, { buffer = state.buf })

    map({ "n", "t" }, "<C-j>", function()
      require("floaterm.api").cycle_term_bufs "next"
    end, { buffer = state.buf })

    map({ "n", "t" }, "<C-k>", function()
      require("floaterm.api").cycle_term_bufs "prev"
    end, { buffer = state.buf })

    require("volt").mappings {
      bufs = { state.buf, state.sidebuf, state.barbuf },
      after_close = function()
        M.close_timers()
        state.volt_set = false
        state.terminals = nil
        state.buf = nil
        state.sidebuf = nil
        state.barbuf = nil
        api.nvim_del_augroup_by_name "FloatermAu"
      end,
    }

    if state.config.mappings.term then
      state.config.mappings.term(state.buf)
    end
  end

  if state.config.autoinsert then
    vim.cmd.startinsert()
  end
end

M.get_term_by_key = function(tocompare, name)
  name = name or "buf"

  for i, v in ipairs(state.terminals or {}) do
    if tocompare == v[name] then
      return { i, v }
    end
  end
end

M.get_buf_on_cursor = function()
  local row = vim.api.nvim_win_get_cursor(0)[1]

  if not state.terminals[row] then
    vim.notify("place cursor on the terminal name", vim.log.levels.WARN)
    return
  end

  return row
end

M.close_timers = function()
  state.bar_redraw_timer:stop()
  state.bar_redraw_timer:close()
  state.bar_redraw_timer = nil

  if state.name_update_timer then
    state.name_update_timer:stop()
    state.name_update_timer:close()
    state.name_update_timer = nil
  end
end

--- Get the foreground command running in a terminal buffer.
--- Returns the command name (e.g. "vim", "make") or nil.
--- Linux only: reads /proc/{pid}/stat for the foreground process group.
M.get_foreground_cmd = function(buf)
  if not api.nvim_buf_is_valid(buf) then return nil end
  if vim.bo[buf].buftype ~= "terminal" then return nil end

  local bufname = api.nvim_buf_get_name(buf)
  local pid = bufname:match("//(%d+):")
  if not pid then return nil end

  local f = io.open("/proc/" .. pid .. "/stat")
  if not f then return nil end
  local stat = f:read("*a")
  f:close()

  -- Field 8 of /proc/{pid}/stat is tpgid (foreground process group ID)
  -- Fields: pid (comm) state ppid pgrp session tty_nr tpgid ...
  -- Use %b() to skip comm which may contain spaces
  local tpgid = stat:match("^%d+ %b() %S+ %S+ %S+ %S+ %S+ (%S+)")
  if not tpgid or tonumber(tpgid) <= 0 then return nil end

  local h = io.popen("ps -p " .. tpgid .. " -o comm= 2>/dev/null")
  if not h then return nil end
  local cmd = h:read("*a")
  h:close()

  cmd = cmd and cmd:gsub("%s+$", "")
  if cmd == "" then return nil end
  return cmd
end

--- Poll all terminals and update names based on foreground process.
--- Returns true if any name changed.
M.update_terminal_names = function()
  if not state.terminals then return false end

  local changed = false
  for _, term in ipairs(state.terminals) do
    if not term.manual_name then
      local cmd = M.get_foreground_cmd(term.buf)
      if cmd and cmd ~= term.name then
        term.name = cmd
        changed = true
      end
    end
  end
  return changed
end

return M
