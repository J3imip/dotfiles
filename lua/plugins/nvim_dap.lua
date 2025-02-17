return {
  "mfussenegger/nvim-dap",
  dependencies = {
    "rcarriga/nvim-dap-ui",
    "theHamsta/nvim-dap-virtual-text",
    {
      "jay-babu/mason-nvim-dap.nvim",
      dependencies = "williamboman/mason.nvim",
      config = function()
        require("mason-nvim-dap").setup({
          ensure_installed = { "codelldb" }, -- Install codelldb for Rust debugging
          automatic_setup = true,
        })
      end,
    },
    "nvim-neotest/nvim-nio",
  },
  config = function()
    local dap = require("dap")
    local dapui = require("dapui")
    local dap_rust = require("jeimip.dap_rust") -- Import the separate Rust DAP config

    -- Configure codelldb for Rust debugging
    dap.adapters.codelldb = {
      type = "server",
      port = "${port}",
      executable = {
        command = vim.fn.stdpath("data") .. "/mason/bin/codelldb",
        args = { "--port", "${port}" },
      },
    }

    -- **Register dap.configurations.rust** (Fixes "No configuration found" error)
    dap.configurations.rust = {
      {
        name = "Launch Rust Crate",
        type = "codelldb",
        request = "launch",
        program = function()
          local crate_root = dap_rust.find_project_root()
          return dap_rust.get_binary_path(crate_root)
        end,
        cwd = function()
          local project_path = dap_rust.find_project_root() or vim.fn.getcwd()
          return dap_rust.find_workspace_root(project_path)
        end,
        stopOnEntry = false,
        runInTerminal = true, -- ✅ Run in an external terminal to keep Actix alive
        console = "integratedTerminal",
        initCommands = { "process handle -p true -s false -n false SIGSTOP" }, -- Ignore SIGSTOP
        args = {}, -- Pass CLI arguments if needed
        env = { RUST_BACKTRACE = "1" }, -- Enable backtrace for debugging
        stdio = { nil, nil, nil }, -- ✅ Forward stdio to prevent Actix shutdown
      },
    }

    -- Bind <F5> to automatically build & debug
    vim.keymap.set("n", "<F5>", function()
      dap_rust.build_and_debug()
    end, { noremap = true, silent = true, desc = "Build & Debug Rust" })

    -- Ensure DAP UI stays open
    dapui.setup()
    dap.listeners.after.event_initialized["dapui_config"] = function()
      vim.schedule(function()
        dapui.open()
      end)
    end
    dap.listeners.before.event_terminated["dapui_config"] = function()
      vim.schedule(function()
        dapui.close()
      end)
    end
    dap.listeners.before.event_exited["dapui_config"] = function()
      vim.schedule(function()
        dapui.close()
      end)
    end
  end,
}
