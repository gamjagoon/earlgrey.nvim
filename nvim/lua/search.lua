local fzf = require('fzf-lua')

fzf.setup({
  'fzf-vim',
  keymap = {
    builtin = {
      ['<C-k>'] = 'preview-up',
      ['<C-j>'] = 'preview-down',
    },
  },
  actions = {
    files = {
      ['ctrl-o'] = fzf.actions.file_vsplit,
    },
  },
  files = {
    cmd = 'fd --color=never --type f --type l --exclude .git',
  },
  grep = {
    cmd = 'rg --column --line-number --no-heading --color=always --smart-case -e',
    rg_glob = true,
  },
})

local silent_opt = { noremap = true, silent = true }

-- Search within Neovim's current working directory (:pwd).
vim.keymap.set('n', '<space>ff', function()
  fzf.files({ cwd = vim.fn.getcwd() })
end, silent_opt)
vim.keymap.set('n', '<space>fs', function()
  fzf.grep_cword({ cwd = vim.fn.getcwd() })
end, silent_opt)
vim.keymap.set('n', '<space>fg', function()
  fzf.live_grep({ cwd = vim.fn.getcwd() })
end, silent_opt)
vim.keymap.set('n', '<space>/', function()
  fzf.blines()
end, silent_opt)
vim.keymap.set('n', '<space>rg', function()
  fzf.live_grep({ cwd = vim.fn.getcwd(), search = vim.fn.expand('<cword>') })
end, silent_opt)
