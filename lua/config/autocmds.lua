-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local dap_rust = require("jeimip.dap_rust")

local function kill_debug_process()
  local crate_path = dap_rust.find_project_root()
  local binary_path = dap_rust.get_binary_path(crate_path)

  if binary_path then
    local binary_name = binary_path:match("([^/]+)$") -- Extract only the binary name
    vim.notify("🚫 Killing debug process before exiting: " .. binary_name, vim.log.levels.WARN)
    vim.fn.jobstart("pkill -9 -f " .. binary_name, { detach = true }) -- Kill process
  end
end

-- Hook into Neovim exit event
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    kill_debug_process()
  end,
})
