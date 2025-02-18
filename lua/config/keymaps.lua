-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local dap = require("dap")
local dapui = require("dapui")
local dap_rust = require("jeimip.dap_rust")

local keymap = vim.keymap.set
local opts = { noremap = true, silent = true, desc = "DAP" }

-- 🌟 General DAP commands
-- keymap("n", "<F5>", dap.continue, { desc = "Start/Continue Debugging" }) -- Start debugging / continue execution
keymap("n", "<F9>", dap.toggle_breakpoint, { desc = "Toggle Breakpoint" }) -- Set or remove a breakpoint
keymap("n", "<F10>", dap.step_over, { desc = "Step Over" }) -- Step over a function call
keymap("n", "<F11>", dap.step_into, { desc = "Step Into" }) -- Step into a function call
keymap("n", "<F12>", dap.step_out, { desc = "Step Out" }) -- Step out of a function
keymap("n", "<leader>db", dap.run_to_cursor, { desc = "Run to Cursor" }) -- Run until the cursor location
keymap("n", "<leader>dx", function()
  local crate_path = dap_rust.find_project_root()
  local binary_path = dap_rust.get_binary_path(crate_path)

  if binary_path then
    -- Extract just the binary name to kill process
    local binary_name = binary_path:match("([^/]+)$")

    vim.notify("🚫 Terminating Debugging & Killing Process: " .. binary_name, vim.log.levels.WARN)

    -- Terminate the debugging session
    dap.terminate()

    -- Ensure DAP disconnects and UI closes
    vim.defer_fn(function()
      dap.disconnect()
      dapui.close()
    end, 100)

    -- Kill the debugged binary process
    vim.fn.jobstart("pkill -9 -f " .. binary_name, { detach = true })
  else
    vim.notify("⚠️ Could not determine binary path!", vim.log.levels.ERROR)
  end
end, { noremap = true, silent = true, desc = "Terminate Debugging & Kill Process" })

-- 🎯 Breakpoints with conditions & log messages
keymap("n", "<leader>dB", function()
  dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
end, { desc = "Set Breakpoint with Condition" })
keymap("n", "<leader>dl", function()
  dap.set_breakpoint(nil, nil, vim.fn.input("Log message: "))
end, { desc = "Set Logpoint" })
keymap("n", "<leader>dL", dap.clear_breakpoints, { desc = "Clear All Breakpoints" }) -- Remove all breakpoints

-- 🖥 Debug UI controls
keymap("n", "<leader>du", dapui.toggle, { desc = "Toggle Debug UI" })
keymap("n", "<leader>do", dapui.open, { desc = "Open Debug UI" })
keymap("n", "<leader>dc", dapui.close, { desc = "Close Debug UI" })
keymap("n", "<leader>Bl", function()
  dap_rust.toggle_build_logs()
end, { noremap = true, silent = true, desc = "Toggle Build Logs" })

-- 📜 Inspect variables & call stack
keymap("n", "<leader>dh", function()
  require("dap.ui.widgets").hover()
end, { desc = "Hover Variables" }) -- View variable under cursor
keymap("n", "<leader>df", function()
  require("dap.ui.widgets").centered_float(require("dap.ui.widgets").frames)
end, { desc = "View Stack Frames" }) -- Show call stack
keymap("n", "<leader>ds", function()
  require("dap.ui.widgets").centered_float(require("dap.ui.widgets").scopes)
end, { desc = "View Scopes" }) -- Show all variables

-- 📝 Debug Console & REPL
keymap("n", "<leader>dr", dap.repl.open, { desc = "Open REPL Console" })
keymap("n", "<leader>dp", function()
  dap.repl.run_last()
end, { desc = "Run Last Debug Command" })

-- ⏭ Restart Debugging
keymap("n", "<leader>dR", dap.restart, { desc = "Restart Debugging" })
