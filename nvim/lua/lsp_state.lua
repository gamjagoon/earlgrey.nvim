local languages = require('lsp_languages')
local M = { enabled = {}, generations = {} }

for _, config in pairs(languages) do
  local current = M.enabled[config.server]
  if current ~= nil and current ~= config.enabled then
    error(('LSP aliases for %s must use the same startup default'):format(config.server))
  end
  M.enabled[config.server] = config.enabled
  M.generations[config.server] = M.generations[config.server] or 0
end

function M.is_enabled(server)
  return M.enabled[server] == true
end

function M.set_enabled(server, enabled)
  enabled = enabled == true
  if M.enabled[server] ~= enabled then
    M.generations[server] = (M.generations[server] or 0) + 1
  end
  M.enabled[server] = enabled
end

function M.generation(server)
  return M.generations[server] or 0
end

function M.is_generation_current(server, generation)
  return M.is_enabled(server) and M.generation(server) == generation
end

function M.can_start_rust(bufnr)
  if not M.is_enabled('rust-analyzer') then
    return false
  end
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= '' then
    return false
  end
  local path = vim.api.nvim_buf_get_name(bufnr)
  if not require('rustaceanvim.os').is_valid_file_path(path) then
    return false
  end
  return vim.fn.executable('rust-analyzer') == 1
end

return M
