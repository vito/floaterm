local M = {}
local api = vim.api
local get_hl = require("volt.utils").get_hl

M.apply = function()
  local bg = get_hl("ExDarkBg").bg or get_hl("Normal").bg
  local fg = get_hl("ExRed").fg or get_hl("Comment").fg

  api.nvim_set_hl(0, "FloatSpecialBorder", { bg = bg, fg = fg })
end

M.setup = function()
  if M._did_setup then
    return
  end

  M._did_setup = true

  local group = api.nvim_create_augroup("FloatermTheme", { clear = true })
  local refresh = vim.schedule_wrap(function()
    M.apply()
  end)

  api.nvim_create_autocmd("User", {
    group = group,
    pattern = "VoltHighlightsUpdated",
    callback = refresh,
  })

  api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = refresh,
  })

  api.nvim_create_autocmd("OptionSet", {
    group = group,
    pattern = "background",
    callback = refresh,
  })
end

return M
