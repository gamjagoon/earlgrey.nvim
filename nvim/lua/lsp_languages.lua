-- Language defaults are session defaults. Use :LspEnable/:LspDisable to change
-- them until Neovim exits, or edit `enabled` here to change startup behavior.
return {
  c = { server = 'clangd', client = 'clangd', executable = 'clangd', enabled = true },
  cpp = { server = 'clangd', client = 'clangd', executable = 'clangd', enabled = true },
  rust = { server = 'rust-analyzer', client = 'rust-analyzer', executable = 'rust-analyzer', enabled = true, rustaceanvim = true },
  python = { server = 'pyright', client = 'pyright', executable = 'pyright-langserver', enabled = true },
  shell = { server = 'bashls', client = 'bashls', executable = 'bash-language-server', enabled = true },
  makefile = { server = 'autotools_ls', client = 'autotools_ls', executable = 'autotools-language-server', enabled = true },
}
