local vopt = vim.opt

-- View Setting
vopt.mouse = 'a'
vopt.nu = true
vopt.rnu = true
vopt.ignorecase = true
vopt.cindent = true
vopt.smartcase = false
vopt.hlsearch = true
vopt.wrap = false
vopt.tabstop = 4
vopt.shiftwidth = 4
vopt.sts = 4
vopt.listchars = { space = ' ', tab = '>-', eol = '$' }
vopt.list = true
vim.api.nvim_set_option('clipboard', 'unnamed')
vopt.tags = './tags; tags;'

vim.api.nvim_create_autocmd({ 'BufEnter' }, {
  pattern = '*.S,*.asm,*.s',
  command = 'set syntax=c',
})

vim.api.nvim_create_autocmd({ 'BufEnter' }, {
  pattern = '*.c,*.h,*.cpp',
  command = 'set ts=8 shiftwidth=8 sts=8',
})

local lua_file_path_group = vim.api.nvim_create_augroup('LuaFilePath', { clear = true })
vim.api.nvim_create_autocmd('FileType', {
  group = lua_file_path_group,
  pattern = 'lua',
  callback = function()
    if not vim.tbl_contains(vim.opt_local.path:get(), '.') then
      vim.opt_local.path:prepend('.')
    end
  end,
})

vim.cmd('set cursorline')
vim.cmd('autocmd FileType c,cpp,sh,bash setlocal noet ci pi sts=0 sw=4 ts=4')
