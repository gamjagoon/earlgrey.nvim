-- Run after normal startup. This exercises native enable/disable against a
-- real subprocess and rustaceanvim's async start/stop path with the same mock.
-- nvim --headless -c 'autocmd VimEnter * ++once luafile tests/test_lsp.lua'
local function assert_true(value, message)
  if not value then error(message, 2) end
end

local function write(path, content)
  local file = assert(io.open(path, 'w'))
  file:write(content)
  file:close()
end

local function read(path)
  local file = io.open(path, 'r')
  if not file then return '' end
  local content = file:read('*a')
  file:close()
  return content
end

local function wait_for(predicate, message)
  if not vim.wait(8000, predicate, 20) then
    error(message .. '\nclients=' .. vim.inspect(vim.lsp.get_clients()) .. '\n'
      .. vim.api.nvim_exec2('messages', { output = true }).output)
  end
end

local function new_named_buffer(path, filetype)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(buf, path)
  vim.api.nvim_set_current_buf(buf)
  vim.cmd('setfiletype ' .. filetype)
  return buf
end

local function client_for(name, bufnr)
  return vim.lsp.get_clients({ name = name, bufnr = bufnr })[1]
end

local function check()
  assert_true(vim.fn.executable('node') == 1, 'Node.js is required for the mock LSP process')
  assert_true(vim.fn.executable('cargo') == 1, 'Cargo is required for the Rust start lifecycle check')

  local source = debug.getinfo(1, 'S').source:sub(2)
  local test_dir = vim.fn.fnamemodify(source, ':p:h')
  local mock = vim.fs.joinpath(test_dir, 'fixtures', 'mock_lsp_server.js')
  local temp_root = vim.fn.tempname()
  local c_root = vim.fs.joinpath(temp_root, 'c-project')
  local rust_root = vim.fs.joinpath(temp_root, 'rust-project')
  vim.fn.mkdir(c_root, 'p')
  vim.fn.mkdir(vim.fs.joinpath(rust_root, 'src'), 'p')
  local c_file = vim.fs.joinpath(c_root, 'main.c')
  local rust_file = vim.fs.joinpath(rust_root, 'src', 'main.rs')
  local rust_manifest = vim.fs.joinpath(rust_root, 'Cargo.toml')
  local c_log = vim.fs.joinpath(temp_root, 'clangd.log')
  local rust_log = vim.fs.joinpath(temp_root, 'rust-analyzer.log')
  write(c_file, 'int main(void) { return 0; }\n')
  write(rust_file, 'fn main() {}\n')
  write(rust_manifest, '[package]\nname = "lsp_mock"\nversion = "0.1.0"\nedition = "2021"\n')

  local original_buffer = vim.api.nvim_get_current_buf()
  local test_buffers = {}
  local old_system = vim.system
  local old_executable = vim.fn.executable
  local ok, err = xpcall(function()
    -- C and C++ share one native server config. The mock stands in for clangd
    -- while the native vim.lsp.enable API starts and stops its client.
    vim.cmd('LspDisable cpp')
    vim.lsp.config('clangd', {
      cmd = { 'node', mock, c_log },
      root_dir = function(_, on_dir) on_dir(c_root) end,
    })
    local c_buf = new_named_buffer(c_file, 'c')
    test_buffers[#test_buffers + 1] = c_buf
    vim.cmd('LspEnable c')
    wait_for(function()
      local client = client_for('clangd', c_buf)
      return client and client.initialized
    end, ('native clangd config did not attach to an existing C buffer (ft=%s, enabled=%s, config=%s, log=%s)')
      :format(vim.bo[c_buf].filetype, tostring(vim.lsp.is_enabled('clangd')),
        vim.inspect(vim.lsp.config.clangd), read(c_log)))
    assert_true(read(c_log):find('initialize', 1, true), 'mock clangd did not receive initialize')
    vim.cmd('LspDisable cpp')
    wait_for(function() return client_for('clangd', c_buf) == nil end,
      'disabling the C++ alias did not stop the shared clangd client')
    vim.cmd('LspToggle cpp')
    wait_for(function()
      local client = client_for('clangd', c_buf)
      return client and client.initialized
    end, 'toggling C++ did not reattach the shared clangd client')
    vim.cmd('LspDisable c')
    wait_for(function() return client_for('clangd', c_buf) == nil end,
      'disabling C did not stop the shared clangd client')

    -- Delay Cargo's root callback, disable Rust before it returns, and ensure
    -- the resulting late client is stopped by rustaceanvim's init/attach gate.
    vim.cmd('LspDisable rust')
    require('rustaceanvim.config.internal').server.cmd = { 'node', mock, rust_log }
    local rust_buf = new_named_buffer(rust_file, 'rust')
    test_buffers[#test_buffers + 1] = rust_buf
    local metadata_started = false
    local metadata_finished = false
    vim.system = function(command, opts, callback)
      local is_metadata = callback and command[1] == 'cargo' and command[2] == 'metadata'
      if not is_metadata then return old_system(command, opts, callback) end
      metadata_started = true
      return old_system(command, opts, function(result)
        metadata_finished = true
        vim.defer_fn(function() callback(result) end, 350)
      end)
    end
    old_executable = vim.fn.executable
    vim.fn.executable = function(name)
      if name == 'rust-analyzer' then return 1 end
      return old_executable(name)
    end
    vim.cmd('LspEnable rust')
    vim.cmd('LspDisable rust')
    wait_for(function() return metadata_started and metadata_finished end,
      'Cargo root discovery did not reach the delayed callback')
    vim.system = old_system
    wait_for(function()
      return read(rust_log):find('initialize', 1, true) ~= nil
        and #vim.lsp.get_clients({ name = 'rust-analyzer' }) == 0
    end, 'late rust-analyzer client remained alive after disable')
    assert_true(not require('lsp').is_enabled('rust'), 'Rust remained enabled after pending start cancellation')

    -- A fresh enabled Rust client retains rustaceanvim's buffer-local command,
    -- which must send an actual code-action request through the attached client.
    vim.system = old_system
    vim.cmd('LspEnable rust')
    wait_for(function()
      local client = client_for('rust-analyzer', rust_buf)
      return client and client.initialized
    end, 'enabled rustaceanvim client did not attach')
    -- Restart immediately while the previous process is still shutting down.
    -- A stopping client must not suppress a replacement start.
    local first_rust_client = client_for('rust-analyzer', rust_buf).id
    vim.cmd('LspDisable rust')
    vim.cmd('LspEnable rust')
    wait_for(function()
      local client = client_for('rust-analyzer', rust_buf)
      return client and client.initialized and not client:is_stopped()
        and client.id ~= first_rust_client
    end, 'immediate Rust disable/enable did not start a replacement client')

    assert_true(vim.api.nvim_buf_get_commands(rust_buf, {}).RustLsp,
      'rustaceanvim did not create its buffer-local RustLsp command')
    local old_select = vim.ui.select
    vim.ui.select = function(items, _, callback) callback(items[1], 1) end
    vim.api.nvim_buf_call(rust_buf, function() vim.cmd('RustLsp codeAction') end)
    wait_for(function() return read(rust_log):find('textDocument/codeAction', 1, true) ~= nil end,
      'RustLsp codeAction did not issue a request through the mock client')
    vim.ui.select = old_select
    vim.cmd('LspDisable rust')
    wait_for(function() return #vim.lsp.get_clients({ name = 'rust-analyzer' }) == 0 end,
      'Rust disable did not stop the rustaceanvim client')

    -- A failed executable launch must remain retryable in the same session.
    local rust_config = require('rustaceanvim.config.internal').server
    rust_config.cmd = { vim.fs.joinpath(temp_root, 'missing-rust-analyzer') }
    local failed_attempt = false
    local old_notify = vim.notify
    vim.notify = function(message, ...)
      if message:find('missing-rust-analyzer', 1, true) then failed_attempt = true end
      return old_notify(message, ...)
    end
    vim.cmd('LspEnable rust')
    wait_for(function() return failed_attempt end, 'missing executable did not reach launch validation')
    vim.notify = old_notify
    rust_config.cmd = { 'node', mock, rust_log }
    vim.cmd('LspEnable rust')
    wait_for(function()
      local client = client_for('rust-analyzer', rust_buf)
      return client and client.initialized and not client:is_stopped()
    end, 'Rust enable did not retry after a failed start')
    vim.cmd('LspDisable rust')
    wait_for(function() return #vim.lsp.get_clients({ name = 'rust-analyzer' }) == 0 end,
      'retried Rust client did not stop')

  end, debug.traceback)

  vim.system, vim.fn.executable = old_system, old_executable
  for _, client in ipairs(vim.lsp.get_clients()) do
    if client.name == 'clangd' or client.name == 'rust-analyzer' then client:stop() end
  end
  for _, buf in ipairs(test_buffers) do
    if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
  end
  if vim.api.nvim_buf_is_valid(original_buffer) then vim.api.nvim_set_current_buf(original_buffer) end
  vim.fn.delete(temp_root, 'rf')
  assert_true(ok, err)
  print('PASS: native clangd alias lifecycle and rustaceanvim pending-start cancellation, restart, failed-start retry, and RustLsp request')
end

local ok, err = xpcall(check, debug.traceback)
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd('cquit 1')
else
  vim.cmd('qa!')
end
