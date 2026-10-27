local lsp_capabilities = require('blink.cmp').get_lsp_capabilities()
vim.lsp.config('*', { capabilities = lsp_capabilities })

local languages = require('lsp_languages')
local lsp_state = require('lsp_state')
local servers = {}

for language, config in pairs(languages) do
  local server = servers[config.server]
  if server and server.enabled ~= config.enabled then
    error(('LSP aliases for %s must use the same startup default'):format(config.server))
  end
  if not server then
    servers[config.server] = {
      enabled = config.enabled,
      client = config.client,
      executable = config.executable,
      rustaceanvim = config.rustaceanvim == true,
      languages = {},
    }
  end
  table.insert(servers[config.server].languages, language)
end

-- Keep Pyright's Windows .cmd launcher compatible with Neovim's process API.
local compat = require('compat')
vim.lsp.config('pyright', { cmd = compat.pyright_command() })
vim.lsp.config('bashls', { cmd = compat.bashls_command() })

local function rust_buffers()
  local buffers = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if
      vim.api.nvim_buf_is_loaded(bufnr)
      and vim.bo[bufnr].filetype == 'rust'
      and vim.bo[bufnr].buftype == ''
    then
      table.insert(buffers, bufnr)
    end
  end
  return buffers
end

local start_rust
start_rust = function(bufnr)
  if not lsp_state.can_start_rust(bufnr) then
    return
  end
  for _, client in ipairs(vim.lsp.get_clients({ name = 'rust-analyzer', bufnr = bufnr })) do
    if not client:is_stopped() then
      return
    end
  end

  -- Capture the lifecycle generation before rustaceanvim's asynchronous Cargo
  -- root lookup. A late callback from an earlier enable cycle must not attach.
  local generation = lsp_state.generation('rust-analyzer')
  local server = require('rustaceanvim.config.internal').server
  local original_on_init, original_on_attach, original_on_exit =
    server.on_init, server.on_attach, server.on_exit
  server.on_init = function(client, ...)
    if not lsp_state.is_generation_current('rust-analyzer', generation) then
      client:stop()
      return
    end
    if original_on_init then
      return original_on_init(client, ...)
    end
  end
  server.on_attach = function(client, attach_bufnr, ...)
    if not lsp_state.is_generation_current('rust-analyzer', generation) then
      client:stop()
      return
    end
    if original_on_attach then
      return original_on_attach(client, attach_bufnr, ...)
    end
  end

  server.on_exit = function(...)
    -- A rapid disable/enable can encounter the previous process before its
    -- shutdown completes. Retry once it exits, using the current generation.
    if
      lsp_state.is_enabled('rust-analyzer')
      and lsp_state.generation('rust-analyzer') ~= generation
    then
      vim.schedule(function()
        for _, rust_buf in ipairs(rust_buffers()) do
          start_rust(rust_buf)
        end
      end)
    end
    if original_on_exit then
      return original_on_exit(...)
    end
  end

  local ok, err = pcall(require('rustaceanvim.lsp').start, bufnr)
  server.on_init, server.on_attach, server.on_exit =
    original_on_init, original_on_attach, original_on_exit
  if not ok then
    vim.notify('Could not start rust-analyzer: ' .. tostring(err), vim.log.levels.ERROR)
  end
end

local function set_enabled(server_name, enabled)
  local config = servers[server_name]
  if not config then
    return false
  end

  if config.rustaceanvim then
    lsp_state.set_enabled(server_name, enabled)
    if enabled then
      for _, bufnr in ipairs(rust_buffers()) do
        start_rust(bufnr)
      end
    else
      for _, client in ipairs(vim.lsp.get_clients({ name = config.client })) do
        client:stop()
      end
    end
  else
    vim.lsp.enable(server_name, enabled)
    lsp_state.set_enabled(server_name, enabled)
  end
  return true
end

local function is_enabled(server_name)
  local config = servers[server_name]
  if not config then
    return false
  end
  if config.rustaceanvim then
    return lsp_state.is_enabled(server_name)
  end
  return vim.lsp.is_enabled(server_name)
end

for server_name, config in pairs(servers) do
  if config.rustaceanvim then
    lsp_state.set_enabled(server_name, config.enabled)
    if config.enabled then
      -- rustaceanvim owns the Rust client and commands; use its start API while
      -- routing automatic and manual starts through this lifecycle manager.
      for _, bufnr in ipairs(rust_buffers()) do
        start_rust(bufnr)
      end
    end
  else
    vim.lsp.enable(server_name, config.enabled)
  end
end

vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('UserRustLspLifecycle', {}),
  pattern = 'rust',
  callback = function(ev)
    start_rust(ev.buf)
  end,
})

local function language_names()
  local names = vim.tbl_keys(languages)
  table.sort(names)
  return names
end

local function complete_language(arg_lead)
  local prefix = string.lower(arg_lead or '')
  return vim.tbl_filter(function(name)
    return vim.startswith(name, prefix)
  end, language_names())
end

local function resolve_language(args, command, allow_empty)
  if #args == 0 and allow_empty then
    return nil
  end
  if #args ~= 1 then
    vim.notify(
      ('Usage: :%s %s'):format(command, allow_empty and '[language]' or '{language}'),
      vim.log.levels.ERROR
    )
    return nil
  end
  local language = string.lower(args[1])
  local config = languages[language]
  if not config then
    vim.notify(
      ('Unknown language %q. Choose: %s'):format(args[1], table.concat(language_names(), ', ')),
      vim.log.levels.ERROR
    )
    return nil
  end
  return language, config
end

local function active_clients(config)
  return vim.lsp.get_clients({ name = config.client })
end

local function describe_language(language)
  local language_config = languages[language]
  local server = servers[language_config.server]
  local enabled = is_enabled(language_config.server)
  local present = vim.fn.executable(server.executable) == 1
  local active = #active_clients(server)
  local state = enabled and 'enabled' or 'disabled'
  local detail = ('%s: %s (%s)'):format(language, state, language_config.server)
  if not present then
    detail = detail .. '; missing ' .. server.executable
  end
  if active > 0 then
    detail = detail .. ('; %d client(s) active'):format(active)
  end
  return detail
end

local function set_language_command(command, action)
  vim.api.nvim_create_user_command(command, function(opts)
    local language, config = resolve_language(opts.fargs, command, false)
    if not language then
      return
    end
    local enabled = is_enabled(config.server)
    if action == 'toggle' then
      enabled = not enabled
    end
    if action == 'enable' then
      enabled = true
    end
    if action == 'disable' then
      enabled = false
    end
    set_enabled(config.server, enabled)
    vim.notify(describe_language(language), vim.log.levels.INFO, { title = 'LSP' })
  end, {
    nargs = '*',
    complete = function(arg_lead)
      return complete_language(arg_lead)
    end,
    desc = ('Enable, disable, or toggle the %s language server for this session'):format(action),
  })
end

set_language_command('LspEnable', 'enable')
set_language_command('LspDisable', 'disable')
set_language_command('LspToggle', 'toggle')

vim.api.nvim_create_user_command('LspStatus', function(opts)
  if #opts.fargs > 1 then
    resolve_language(opts.fargs, 'LspStatus', true)
    return
  end
  local lines = {}
  if #opts.fargs == 1 then
    local language = resolve_language(opts.fargs, 'LspStatus', true)
    if not language then
      return
    end
    table.insert(lines, describe_language(language))
  else
    for _, name in ipairs(language_names()) do
      table.insert(lines, describe_language(name))
    end
  end
  vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO, { title = 'LSP status' })
end, {
  nargs = '*',
  complete = function(arg_lead)
    return complete_language(arg_lead)
  end,
  desc = 'Show LSP status for a language or all configured languages',
})

local M = {}
M.is_enabled = function(language)
  local config = languages[language]
  return config ~= nil and is_enabled(config.server)
end
M.start_rust = start_rust

vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(ev)
    -- Enable completion triggered by <c-x><c-o>
    vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'
    local opts = { buffer = ev.buf, noremap = true, silent = true }
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
    vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, opts)
    vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, opts)
    vim.keymap.set({ 'n', 'v' }, '<space>ca', vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)

    if vim.bo[ev.buf].filetype == 'rust' then
      vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
      local function rust_map(lhs, command)
        vim.keymap.set('n', lhs, function()
          vim.cmd.RustLsp(command)
        end, opts)
      end
      rust_map('<space>ca', 'codeAction')
      rust_map('<space>cd', 'renderDiagnostic')
      rust_map('<space>dr', 'renderDiagnostic')
      rust_map('<space>ce', 'explainError')
      rust_map('<space>de', 'explainError')
      rust_map('K', { 'hover', 'actions' })
      vim.keymap.set('n', '<space>rl', ':RustLsp ', opts)
    end
  end,
})

-- LSP Diagnostics Options Setup
local sign = function(opts)
  vim.fn.sign_define(opts.name, {
    texthl = opts.name,
    text = opts.text,
    numhl = '',
  })
end

sign({ name = 'DiagnosticSignError', text = 'E' })
sign({ name = 'DiagnosticSignWarn', text = '' })
sign({ name = 'DiagnosticSignHint', text = 'H' })
sign({ name = 'DiagnosticSignInfo', text = '' })

vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  update_in_insert = true,
  underline = true,
  severity_sort = false,
  float = {
    border = 'rounded',
    source = 'always',
    header = '',
    prefix = '',
  },
})

vim.cmd([[
set signcolumn=yes
autocmd CursorHold * lua vim.diagnostic.open_float(nil, { focusable = false })
]])

return M
