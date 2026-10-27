local M = {}

function M.select_provider(environment)
  if not environment.wsl or environment.clipboard ~= nil then
    return nil
  end

  local executable = environment.exepath('win32yank.exe')
  if executable == '' or environment.is_executable(executable) ~= 1 then
    return nil
  end

  if not environment.probe(executable) then
    return nil
  end

  return 'win32yank'
end

function M.setup()
  local function probe(executable)
    local ok, process = pcall(vim.system, { executable, '--help' }, { text = true })
    if not ok then
      return false
    end

    local waited, result = pcall(process.wait, process, 1000)
    return waited and result ~= nil and result.code == 0
  end

  local provider = M.select_provider({
    wsl = vim.fn.has('wsl') == 1,
    clipboard = vim.g.clipboard,
    exepath = vim.fn.exepath,
    is_executable = vim.fn.executable,
    probe = probe,
  })

  if provider then
    vim.g.clipboard = provider
  end
end

return M
