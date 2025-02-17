local M = {}
local build_status = "Idle" -- Global variable to track build status
local build_logs = {} -- Store build logs before debugger starts
local build_window = nil -- Track floating window
local build_buffer = nil -- Track floating buffer

-- Function to find the **nearest Cargo.toml** for the current file
function M.find_project_root()
  local current_file = vim.fn.expand("%:p") -- Get full file path
  local current_dir = vim.fn.fnamemodify(current_file, ":h") -- Get directory

  while current_dir ~= "/" do
    if vim.fn.filereadable(current_dir .. "/Cargo.toml") == 1 then
      return current_dir -- Return the nearest valid Cargo.toml location
    end
    current_dir = vim.fn.fnamemodify(current_dir, ":h") -- Move one level up
  end

  return nil -- No Cargo.toml found
end

-- Function to extract the crate name from Cargo.toml
function M.get_package_name(crate_root)
  if not crate_root then
    return nil
  end

  local cargo_toml = crate_root .. "/Cargo.toml"
  for line in io.lines(cargo_toml) do
    local name = line:match('^name%s*=%s*"(.+)"')
    if name then
      return name
    end
  end
  return vim.fn.fnamemodify(crate_root, ":t") -- Fallback to directory name
end

-- Function to get the workspace root if the project is a Cargo workspace
function M.find_workspace_root(crate_root)
  if not crate_root then
    return nil
  end

  local current_dir = crate_root
  while current_dir ~= "/" do
    if vim.fn.filereadable(current_dir .. "/Cargo.toml") == 1 then
      -- Check if this Cargo.toml defines a workspace
      for line in io.lines(current_dir .. "/Cargo.toml") do
        if line:match("%[workspace%]") then
          return current_dir -- Found workspace root
        end
      end
    end
    current_dir = vim.fn.fnamemodify(current_dir, ":h") -- Move up
  end

  return crate_root -- Not in a workspace, return crate root
end

-- Function to get the compiled binary path correctly
function M.get_binary_path(crate_root)
  if not crate_root then
    vim.notify("Rust project root not found", vim.log.levels.ERROR)
    return nil
  end

  local workspace_root = M.find_workspace_root(crate_root)
  local package_name = M.get_package_name(crate_root)
  if not package_name then
    vim.notify("Could not determine crate name!", vim.log.levels.ERROR)
    return nil
  end

  -- Determine where Cargo puts the binary
  local binary_path = workspace_root .. "/target/debug/" .. package_name
  if vim.fn.filereadable(binary_path) == 1 then
    return binary_path
  end

  -- If not found, check `target/debug/deps/` for prefixed binaries
  local deps_path = workspace_root .. "/target/debug/deps/"
  local files = vim.fn.glob(deps_path .. package_name .. "*", false, true)

  if #files > 0 then
    return files[1] -- Return the first matching binary
  end

  vim.notify("Rust binary not found in expected paths: target/debug/ or target/debug/deps/", vim.log.levels.WARN)
  return nil
end

function M.get_build_status()
  return build_status
end

-- Function to create or update the floating window for build logs
local function show_build_logs()
  if not build_buffer or not vim.api.nvim_buf_is_valid(build_buffer) then
    build_buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(build_buffer, "bufhidden", "wipe")
  end

  if not build_window or not vim.api.nvim_win_is_valid(build_window) then
    local width = math.floor(vim.o.columns * 0.7)
    local height = math.floor(vim.o.lines * 0.5)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    build_window = vim.api.nvim_open_win(build_buffer, true, {
      relative = "editor",
      width = width,
      height = height,
      row = row,
      col = col,
      style = "minimal",
      border = "rounded",
    })
  end

  -- Update buffer with new logs
  vim.api.nvim_buf_set_lines(build_buffer, 0, -1, false, build_logs)
end

-- Function to toggle the build logs window
function M.toggle_build_logs()
  if build_window and vim.api.nvim_win_is_valid(build_window) then
    vim.api.nvim_win_close(build_window, true)
    build_window = nil
  else
    show_build_logs()
  end
end

function M.build_and_debug()
  local crate_root = M.find_project_root()
  if not crate_root then
    vim.notify("❌ Cannot find Rust project root!", vim.log.levels.ERROR)
    return
  end

  local workspace_root = M.find_workspace_root(crate_root)
  build_status = "Building..."
  build_logs = { "🔨 Starting build for Rust crate: " .. crate_root }

  local cargo_path = vim.fn.exepath("cargo")
  if cargo_path == "" or cargo_path == nil then
    vim.notify("❌ Cargo not found! Ensure it's installed and in $PATH", vim.log.levels.ERROR)
    return
  end

  local stdout = vim.uv.new_pipe(false)
  local stderr = vim.uv.new_pipe(false)

  if not stdout or not stderr then
    vim.notify("❌ Failed to create pipes!", vim.log.levels.ERROR)
    return
  end

  local handle, err = vim.uv.spawn(cargo_path, {
    args = { "build" },
    cwd = crate_root,
    stdio = { nil, stdout, stderr },
    env = { "PATH=" .. vim.env.PATH },
    detached = false,
  }, function(code, signal)
    stdout:close()
    stderr:close()
    if handle then
      handle:close()
    end

    vim.schedule(function()
      if code == 0 then
        build_status = "Build ✅"
        table.insert(build_logs, "✅ Build completed successfully!")
        M.start_debugger(crate_root, workspace_root)
      else
        build_status = "Build ❌"
        table.insert(build_logs, "❌ Build failed! Code: " .. tostring(code) .. " Signal: " .. tostring(signal))
      end
    end)
  end)

  if not handle then
    vim.notify("❌ Failed to start Cargo build! Error: " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  -- Stream build output in real-time (stored for later)
  vim.uv.read_start(stdout, function(err, data)
    if err then
      vim.schedule(function()
        table.insert(build_logs, "Error: " .. err)
      end)
    end
    if data then
      vim.schedule(function()
        for line in data:gmatch("[^\r\n]+") do
          table.insert(build_logs, line)
        end
      end)
    end
  end)

  vim.uv.read_start(stderr, function(err, data)
    if err then
      vim.schedule(function()
        table.insert(build_logs, "Error: " .. err)
      end)
    end
    if data then
      vim.schedule(function()
        for line in data:gmatch("[^\r\n]+") do
          table.insert(build_logs, line)
        end
      end)
    end
  end)
end

function M.start_debugger(crate_root, workspace_root)
  local binary_path = M.get_binary_path(crate_root)
  if binary_path then
    vim.schedule(function()
      require("dap.repl").append("\n🚀 Launching debugger...\n")
    end)

    require("dap").run({
      name = "Debug Rust Crate",
      type = "codelldb",
      request = "launch",
      program = binary_path,
      cwd = workspace_root,
      stopOnEntry = false,
      runInTerminal = true,
      console = "integratedTerminal",
      initCommands = { "process handle -p true -s false -n false SIGSTOP" },
    })
  else
    vim.notify("Error: Cannot find compiled Rust binary!", vim.log.levels.ERROR)
  end
end

return M
