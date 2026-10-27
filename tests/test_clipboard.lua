local clipboard = require('clipboard')

local saved = {
  has = vim.fn.has,
  exepath = vim.fn.exepath,
  executable = vim.fn.executable,
  system = vim.system,
  configured = vim.g.clipboard,
}

local function choose(overrides)
  local environment = {
    wsl = true,
    clipboard = nil,
    exepath = function() return '/fake/win32yank.exe' end,
    is_executable = function() return 1 end,
    probe = function() return true end,
  }
  for key, value in pairs(overrides or {}) do
    environment[key] = value
  end
  return clipboard.select_provider(environment)
end

assert(choose({}) == 'win32yank', 'WSL should prefer a working win32yank provider')
assert(choose({ wayland_display = 'wayland-0' }) == 'win32yank',
  'WSL should avoid wl-copy selection when Wayland is also advertised')
assert(choose({ wsl = false }) == nil, 'native systems should keep automatic provider selection')
assert(choose({ clipboard = 'custom-provider' }) == nil,
  'an explicit clipboard provider must be preserved')
assert(choose({ clipboard = false }) == nil,
  'an explicit builtin-provider opt-in must be preserved')
assert(choose({ exepath = function() return '' end }) == nil,
  'missing win32yank must leave automatic provider selection intact')
assert(choose({ is_executable = function() return 0 end }) == nil,
  'non-executable win32yank must not be selected')
assert(choose({ probe = function() return false end }) == nil,
  'unusable WSL interop must leave automatic provider selection intact')

local probe_called = false
local missing_provider = clipboard.select_provider({
  wsl = true,
  clipboard = nil,
  exepath = function() return '' end,
  is_executable = function() return 1 end,
  probe = function() probe_called = true; return true end,
})
assert(missing_provider == nil and not probe_called, 'missing provider must not be probed')

local function run_setup(wsl, configured, probe_code)
  local called = false
  vim.fn.has = function(feature)
    if feature == 'wsl' then return wsl and 1 or 0 end
    return saved.has(feature)
  end
  vim.fn.exepath = function(name)
    if name == 'win32yank.exe' then return '/fake/win32yank.exe' end
    return ''
  end
  vim.fn.executable = function(path)
    if path == '/fake/win32yank.exe' then return 1 end
    return 0
  end
  vim.system = function(command, options)
    called = true
    assert(vim.deep_equal(command, { '/fake/win32yank.exe', '--help' }), 'probe must not access clipboard data')
    assert(options.text, 'probe output should be treated as text')
    return {
      wait = function(_, timeout)
        assert(timeout == 1000, 'interop probe must be bounded to one second')
        return { code = probe_code }
      end,
    }
  end
  vim.g.clipboard = configured
  clipboard.setup()
  local selected = vim.g.clipboard
  vim.fn.has, vim.fn.exepath, vim.fn.executable, vim.system =
    saved.has, saved.exepath, saved.executable, saved.system
  vim.g.clipboard = saved.configured
  return selected, called
end

local selected, setup_probed = run_setup(true, nil, 0)
assert(selected == 'win32yank' and setup_probed, 'setup must choose a working WSL provider')
selected, setup_probed = run_setup(true, nil, 1)
assert(selected == nil and setup_probed, 'failed interop must preserve automatic provider selection')
selected, setup_probed = run_setup(true, 'custom-provider', 0)
assert(selected == 'custom-provider' and not setup_probed, 'setup must preserve explicit provider configuration')
selected, setup_probed = run_setup(false, nil, 0)
assert(selected == nil and not setup_probed, 'setup must leave native provider selection unchanged')

print('PASS: WSL win32yank selection and safe fallbacks')
