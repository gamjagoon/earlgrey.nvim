local silent_opt = { noremap = true, silent = true }
local vmap = vim.keymap

-- Key Binding
vmap.set('n', 'cb', '<cmd>bn<bar>bd#<cr><cmd>bp<cr>', silent_opt)

vmap.set('n', '<c-h>', '<c-w>h', silent_opt)
vmap.set('n', '<c-j>', '<c-w>j', silent_opt)
vmap.set('n', '<c-k>', '<c-w>k', silent_opt)
vmap.set('n', '<c-l>', '<c-w>l', silent_opt)
vmap.set('n', 'vs', '<cmd>vsplit<cr>', silent_opt)

vmap.set('n', '<s-h>', '<cmd>bp<cr>', silent_opt)
vmap.set('n', '<s-l>', '<cmd>bn<cr>', silent_opt)

vmap.set({ 'n', 'v' }, '<leader><space>', '<cmd>nohl<cr>', silent_opt)

vmap.set({ 'n', 'v' }, 'p', '"+p', silent_opt)
vmap.set({ 'n', 'v' }, 'y', '"+y', silent_opt)
vmap.set({ 'n', 'v' }, 'P', '"+P', silent_opt)
vmap.set({ 'n', 'v' }, 'Y', '"+Y', silent_opt)

-- init lua
vmap.set('n', '<leader>it', function()
  vim.cmd.edit(vim.fn.fnameescape(vim.fn.stdpath('config') .. '/init.lua'))
end, silent_opt)

-- nvim tree
vim.keymap.set('n', '<space>e', '<cmd>NvimTreeToggle<cr>', {})

-- BUffline
vim.keymap.set('n', '<space>1', '<cmd>BufferLineGoToBuffer 1<cr>', {})
vim.keymap.set('n', '<space>2', '<cmd>BufferLineGoToBuffer 2<cr>', {})
vim.keymap.set('n', '<space>3', '<cmd>BufferLineGoToBuffer 3<cr>', {})
vim.keymap.set('n', '<space>4', '<cmd>BufferLineGoToBuffer 4<cr>', {})
vim.keymap.set('n', '<space>5', '<cmd>BufferLineGoToBuffer 5<cr>', {})
vim.keymap.set('n', '<space>6', '<cmd>BufferLineGoToBuffer 6<cr>', {})
vim.keymap.set('n', '<space>7', '<cmd>BufferLineGoToBuffer 7<cr>', {})
vim.keymap.set('n', '<space>8', '<cmd>BufferLineGoToBuffer 8<cr>', {})
vim.keymap.set('n', '<space>9', '<cmd>BufferLineGoToBuffer 9<cr>', {})

vmap.set('n', '<leader>hx', function()
  if vim.fn.executable('xxd') ~= 1 then
    vim.notify('Hex mode requires xxd to be installed.', vim.log.levels.WARN)
    return
  end

  vim.cmd('HexToggle')
end, vim.tbl_extend('force', silent_opt, { desc = 'Toggle hex view' }))
