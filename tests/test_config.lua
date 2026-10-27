-- Run after loading this configuration and restoring its locked plugins.
local original_buffer = vim.api.nvim_get_current_buf()
local test_buffers = {}

local function new_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  test_buffers[#test_buffers + 1] = buf
  vim.api.nvim_set_current_buf(buf)
  return buf
end

local function check()
  assert(vim.v.errmsg == '', 'startup error: ' .. vim.v.errmsg)
  assert(vim.o.clipboard == 'unnamedplus', 'unnamed operations must use the system clipboard')
  local plugins = require('lazy.core.config').plugins
  assert(not plugins['packer.nvim'], 'Packer must not be loaded')
  assert(plugins.evergarden and plugins.evergarden._.loaded, 'theme was not loaded')
  assert(plugins['fzf-lua'], 'missing search provider')
  for _, name in ipairs({ 'telescope.nvim', 'telescope-live-grep-args.nvim', 'telescope-fzf-native.nvim' }) do
    assert(not plugins[name], 'removed search plugin remains: ' .. name)
  end
  assert(not plugins['leap.nvim'], 'Leap must not be loaded')
  for _, mode in ipairs({ 'n', 'x', 'o' }) do
    assert(vim.fn.maparg(' s', mode) == '', 'Leap mapping remains in ' .. mode)
  end
  assert(vim.fn.maparg(' S', 'n') == '', 'Leap window mapping remains')
  assert(vim.lsp.config.pyright.capabilities.textDocument.completion.completionItem.snippetSupport,
    'completion capabilities were not applied')
  local lsp = require('lsp')
  local language_defaults = require('lsp_languages')
  for _, language in ipairs({ 'c', 'cpp', 'rust', 'python', 'shell', 'makefile' }) do
    assert(language_defaults[language] and language_defaults[language].enabled,
      'missing enabled LSP default for ' .. language)
    assert(lsp.is_enabled(language), language .. ' LSP should be enabled by default')
  end
  assert(language_defaults.c.server == language_defaults.cpp.server,
    'C and C++ must share the clangd server')
  local user_commands = vim.api.nvim_get_commands({})
  for _, command in ipairs({ 'LspEnable', 'LspDisable', 'LspToggle', 'LspStatus' }) do
    assert(user_commands[command], 'missing :' .. command .. ' command')
  end

  -- C and C++ are aliases for one server; language controls last for this session.
  vim.cmd('LspDisable c')
  assert(not lsp.is_enabled('cpp'), 'disabling C must disable the shared clangd server')
  vim.cmd('LspEnable cpp')
  assert(lsp.is_enabled('c'), 'enabling C++ must enable the shared clangd server')
  vim.cmd('LspToggle shell')
  assert(not lsp.is_enabled('shell'), 'LspToggle did not disable bashls')
  vim.cmd('LspToggle shell')
  assert(lsp.is_enabled('shell'), 'LspToggle did not enable bashls')
  local saved_notify, notices = vim.notify, {}
  vim.notify = function(message) notices[#notices + 1] = tostring(message) end
  vim.cmd('LspStatus')
  assert(notices[#notices]:find('makefile', 1, true), 'no-argument status should list all languages')
  local notice_count = #notices
  vim.cmd('LspStatus unknown')
  assert(#notices == notice_count + 1 and notices[#notices]:find('Unknown language', 1, true),
    'invalid status language should report an error instead of listing all languages')
  vim.cmd('LspEnable')
  assert(#notices == notice_count + 2 and notices[#notices]:find('Usage', 1, true),
    'no-argument enable should show usage')
  vim.notify = saved_notify
  for _, name in ipairs({ 'nvim-cmp', 'cmp-buffer', 'cmp-path', 'cmp-cmdline', 'cmp-nvim-lsp', 'cmp-calc', 'cmp_luasnip' }) do
    assert(not plugins[name], 'legacy completion plugin remains: ' .. name)
  end
  assert(plugins['blink.cmp'] and plugins['blink.cmp']._.loaded, 'Blink was not loaded')

  -- Exercise the real completion menu and LuaSnip expansion through Blink.
  local snippet_buf = new_buffer()
  vim.bo.buftype = ''
  vim.bo.filetype = 'text'
  vim.api.nvim_buf_set_lines(snippet_buf, 0, -1, false, { 'date ' })
  vim.api.nvim_win_set_cursor(0, { 1, 4 })
  local blink = require('blink.cmp')
  blink.show({ providers = { 'snippets' } })
  assert(vim.wait(5000, blink.is_menu_visible, 20), 'Blink snippet menu did not open')
  local date_index
  for index, item in ipairs(blink.get_items()) do
    if item.label == 'date' then date_index = index end
  end
  assert(date_index, 'date snippet is missing from Blink completions')
  blink.accept({ index = date_index })
  local today = os.date('%Y-%m-%d')
  assert(vim.wait(2000, function()
    return vim.api.nvim_buf_get_lines(snippet_buf, 0, 1, false)[1] == today .. ' '
  end, 20), 'Blink did not expand the date snippet')
  blink.hide()
  assert(vim.wait(1000, function() return not blink.is_visible() end, 20), 'Blink menu did not close')

  local markdown_buf = new_buffer()
  vim.bo.buftype = ''
  vim.api.nvim_buf_set_name(markdown_buf, vim.fn.tempname() .. '-plugin-check.md')
  vim.api.nvim_buf_set_lines(markdown_buf, 0, -1, false, {
    '# Markdown heading', '', '- **Markdown** item', '', '```text', 'code block', '```', '', 'cursor here',
  })
  vim.api.nvim_win_set_cursor(0, { 9, 0 })
  vim.bo.filetype = 'markdown'
  assert(vim.treesitter.language.add('markdown_inline'), 'markdown_inline parser unavailable')
  local parser = vim.treesitter.get_parser(markdown_buf, 'markdown')
  assert(#parser:parse() > 0, 'Markdown parser produced no syntax tree')

  assert(vim.o.laststatus == 3, 'global statusline is not enabled')
  local statusline = require('lualine').statusline(true)
  assert(statusline and statusline:find('plugin-check.md', 1, true), 'lualine did not render the filename')

  local commands = {}
  vim.api.nvim_create_user_command('RustLsp', function(opts)
    commands[#commands + 1] = opts.args
  end, { nargs = '+', force = true })

  local function attach(filetype)
    local buf = new_buffer()
    -- Test attachment routing without invoking Rust's FileType server startup.
    vim.cmd('noautocmd setlocal filetype=' .. filetype)
    vim.api.nvim_exec_autocmds('LspAttach', { buffer = buf, group = 'UserLspConfig' })
    return buf
  end

  local function mapping(buf, lhs)
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, 'n')) do
      if map.lhs == lhs then
        return map
      end
    end
  end

  for _ = 1, 2 do
    local buf = attach('rust')
    for lhs, expected in pairs({
      [' ca'] = 'codeAction', [' cd'] = 'renderDiagnostic', [' dr'] = 'renderDiagnostic',
      [' ce'] = 'explainError', [' de'] = 'explainError', ['K'] = 'hover actions',
    }) do
      local map = assert(mapping(buf, lhs), 'missing Rust mapping: ' .. lhs)
      map.callback()
      assert(commands[#commands] == expected, 'incorrect Rust command for ' .. lhs)
    end
  end
  local python_buf = attach('python')
  assert(mapping(python_buf, ' ca').callback == vim.lsp.buf.code_action,
    'non-Rust code action was overridden')
  assert(not mapping(python_buf, ' dr'), 'Rust mapping leaked into Python')
  assert(vim.fn.maparg(' dr', 'n') == '', 'Rust mapping leaked globally')
  -- Native Markdown ftplugin cleanup can leave a suppressed E31 in v:errmsg
  -- when lazy.nvim replays FileType. Check reported errors, without clearing it.
  local messages = vim.api.nvim_exec2('messages', { output = true }).output
  assert(not messages:find('Error ', 1, true) and not messages:find('stack traceback:', 1, true),
    'reported runtime error: ' .. messages)
  print('PASS: startup, Blink snippet acceptance, Markdown parsing, lualine and per-buffer Rust commands')
end

local ok, err = xpcall(check, debug.traceback)
if vim.api.nvim_buf_is_valid(original_buffer) then
  vim.api.nvim_set_current_buf(original_buffer)
end
for _, buf in ipairs(test_buffers) do
  if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
end
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd('cquit 1')
end
