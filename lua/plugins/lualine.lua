return {
  { "ofseed/copilot-status.nvim" },
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = function(_, opts)
      local dap_rust = require("jeimip.dap_rust") -- Load Rust DAP module

      -- Insert Copilot status in `lualine_x`
      table.insert(opts.sections.lualine_x, {
        "copilot",
        show_running = true,
        symbols = {
          status = {
            enabled = " ",
            disabled = " ",
          },
          spinners = require("copilot-status.spinners").dots,
        },
      })

      -- Insert Rust build status in `lualine_x`
      table.insert(opts.sections.lualine_x, {
        dap_rust.get_build_status, -- Function from dap_rust.lua
        icon = "", -- Bolt icon for visibility
        color = { fg = "#ffcc00", gui = "bold" }, -- Highlight the status
      })
    end,
  },
}
