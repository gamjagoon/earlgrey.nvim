# Run in a fresh PowerShell session. External tools are mocked; no installation occurs.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$project = Split-Path -Parent $PSScriptRoot
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('nvim fixture ' + [guid]::NewGuid().ToString('N'))
$root = Join-Path ([IO.Path]::GetTempPath()) ('nvim install test ' + [guid]::NewGuid().ToString('N'))
$savedEnv = @{}
foreach ($name in @('OS', 'LOCALAPPDATA', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'NVIM_APPNAME', 'PATH', 'RUSTUP_AUTO_INSTALL', 'CC', 'CXX', 'INCLUDE', 'LIB')) {
    $savedEnv[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
$global:NvimInstallTestCalls = New-Object 'System.Collections.Generic.List[string]'
$global:NvimInstallTestFailure = ''
$global:NvimToolTestCalls = 0
$global:NvimRustTestFailure = $false
$global:NvimVersionTestOld = ''
$global:NvimCompilerInitCalls = 0
$global:NvimCompilerCheckCalls = 0
function global:nvim.exe {
    if ($args -contains '--version') {
        $global:NvimToolTestCalls++
        if ($global:NvimVersionTestOld -eq 'nvim') { 'NVIM v0.11.0' } else { 'NVIM v0.12.0' }
        $global:LASTEXITCODE = 0
        return
    }
    [void]$global:NvimInstallTestCalls.Add(($args -join ' '))
    $global:LASTEXITCODE = 0
    if ($global:NvimInstallTestFailure -and ($args -join ' ').Contains($global:NvimInstallTestFailure)) {
        $global:LASTEXITCODE = 17
    }
}
function global:tree-sitter.exe { $global:NvimToolTestCalls++; $global:LASTEXITCODE = 0; if ($global:NvimVersionTestOld -eq 'tree-sitter') { 'tree-sitter 0.26.0' } else { 'tree-sitter 0.26.1' } }
function global:fzf.exe { $global:NvimToolTestCalls++; $global:LASTEXITCODE = 0; if ($global:NvimVersionTestOld -eq 'fzf') { '0.52.0' } else { '0.52.1' } }
function global:rust-analyzer.exe {
    if ($env:RUSTUP_AUTO_INSTALL -ne '0') { throw 'Rust toolchain auto-install was not disabled' }
    $global:NvimToolTestCalls++; $global:LASTEXITCODE = 0
    if ($global:NvimRustTestFailure) { $global:LASTEXITCODE = 1 }
}
function global:rustfmt.exe {
    if ($env:RUSTUP_AUTO_INSTALL -ne '0') { throw 'Rust toolchain auto-install was not disabled' }
    $global:NvimToolTestCalls++; $global:LASTEXITCODE = 0
}
function global:pyright-langserver.cmd { $global:NvimToolTestCalls++; $global:LASTEXITCODE = 0 }
function global:git.exe { $global:NvimToolTestCalls++; $global:LASTEXITCODE = 0 }
function global:curl.exe { $global:NvimToolTestCalls++; $global:LASTEXITCODE = 0 }
function global:fd.exe { $global:NvimToolTestCalls++; $global:LASTEXITCODE = 0 }
function global:rg.exe { $global:NvimToolTestCalls++; $global:LASTEXITCODE = 0 }
function global:cargo.exe { $global:LASTEXITCODE = 0 }
function global:rustc.exe { $global:LASTEXITCODE = 0; 'host: x86_64-pc-windows-gnullvm' }
function global:rustup.exe {
    $global:LASTEXITCODE = 0
    $global:NvimToolTestCalls++
    if ($args -contains 'run' -and $global:NvimRustTestFailure -and $args -contains 'rust-analyzer') { $global:LASTEXITCODE = 1 }
    elseif ($args -contains 'run' -and $args -contains 'rustc' -and $args -contains '-vV') { 'host: x86_64-pc-windows-gnullvm' }
    elseif ($args -contains 'run') { 'mock rust tool 1.0.0' }
    elseif ($args -contains 'show') { 'stable-x86_64-pc-windows-gnullvm (environment override)' }
    elseif ($args -contains '--version') { 'rustup 1.28.0' }
}
function global:node.exe { $global:NvimToolTestCalls++; $global:LASTEXITCODE = 0; 'v24.0.0' }
function global:npm.cmd { $global:NvimToolTestCalls++; $global:LASTEXITCODE = 0; '11.0.0' }
try {
    $env:OS = 'Windows_NT'
    $env:LOCALAPPDATA = Join-Path $root 'local data'
    $env:XDG_CONFIG_HOME = Join-Path $root 'config root'
    $env:XDG_DATA_HOME = Join-Path $root 'data root'
    $env:NVIM_APPNAME = $null
    $env:RUSTUP_AUTO_INSTALL = '1'
    $env:INCLUDE = $null
    $env:LIB = $null
    New-Item -ItemType Directory -Force -Path (Join-Path $fixtureRoot 'script') | Out-Null
    Copy-Item (Join-Path $project 'script/install-windows.ps1') (Join-Path $fixtureRoot 'script/install-windows.ps1')
    $helper = 'function Get-WindowsCompiler { $global:NvimCompilerCheckCalls++; return @{ CC="mock-clang"; CXX="mock-clang++" } }; function Initialize-WindowsCompiler { $global:NvimCompilerInitCalls++; $env:CC="mock-clang"; $env:CXX="mock-clang++"; $env:RUSTUP_TOOLCHAIN="stable-x86_64-pc-windows-gnullvm" }'
    Set-Content (Join-Path $fixtureRoot 'script/windows-compiler.ps1') $helper
    $installer = Join-Path $fixtureRoot 'script/install-windows.ps1'
    & $installer -WhatIf
    foreach ($mode in @('All', 'Tools', 'Config', 'Check')) { & $installer -Mode $mode -WhatIf }
    & $installer -InstallTools -WhatIf
    if (Test-Path -LiteralPath $root) { throw 'WhatIf changed the filesystem' }
    if ($global:NvimToolTestCalls -ne 0) { throw 'WhatIf executed a tool' }
    if ($env:PATH -ne $savedEnv['PATH']) { throw 'WhatIf changed PATH' }
    if ($global:NvimCompilerInitCalls -ne 0 -or $global:NvimCompilerCheckCalls -ne 0) { throw 'WhatIf initialized or checked a compiler' }

    # Check works without a source config and leaves compiler selection alone.
    $env:CC = 'preserve-cc'
    $env:CXX = 'preserve-cxx'
    $env:RUSTUP_TOOLCHAIN = 'preserve-toolchain'
    $global:NvimCompilerInitCalls = 0
    $global:NvimInstallTestCalls.Clear()
    & $installer -Mode Check
    if ($global:NvimCompilerInitCalls -ne 0) { throw 'Check mode initialized compiler environment' }
    if ($env:CC -ne 'preserve-cc' -or $env:CXX -ne 'preserve-cxx' -or $env:RUSTUP_TOOLCHAIN -ne 'preserve-toolchain') { throw 'Check mode changed compiler environment' }
    if ($env:RUSTUP_AUTO_INSTALL -ne '1') { throw 'Check mode did not restore Rustup auto-install setting' }
    if ($global:NvimInstallTestCalls -match '\+Lazy|test_config.lua|test_search.lua') { throw 'Check mode ran config installation commands' }

    $global:NvimRustTestFailure = $true
    $rejected = $false
    try { & $installer -Mode Check } catch {
        $rejected = $_.ToString().Contains('https://rustup.rs/') -and $_.ToString().Contains('docs/windows-setup.md')
    }
    if (-not $rejected -or (Test-Path -LiteralPath $root)) { throw ('Unusable Rust tool did not fail before filesystem changes with manual guidance; calls: ' + ($global:NvimInstallTestCalls -join ' || ')) }
    if ($env:RUSTUP_AUTO_INSTALL -ne '1') { throw 'Rustup environment was not restored after failed checks' }
    $global:NvimRustTestFailure = $false
    foreach ($oldTool in @('nvim', 'tree-sitter', 'fzf')) {
        $global:NvimVersionTestOld = $oldTool
        $rejected = $false
        try { & $installer -Mode Check } catch { $rejected = $_.ToString().Contains('requires >=') }
        if (-not $rejected -or (Test-Path -LiteralPath $root)) { throw "Outdated $oldTool was not rejected before filesystem changes" }
    }
    $global:NvimVersionTestOld = ''
    $fixtureProject = Join-Path $root 'fixture checkout'
    New-Item -ItemType Directory -Force -Path (Join-Path $fixtureProject 'script'), (Join-Path $fixtureProject 'nvim') | Out-Null
    Copy-Item -LiteralPath $installer -Destination (Join-Path $fixtureProject 'script/install-windows.ps1')
    Copy-Item -LiteralPath (Join-Path $fixtureRoot 'script/windows-compiler.ps1') -Destination (Join-Path $fixtureProject 'script/windows-compiler.ps1')
    Set-Content -LiteralPath (Join-Path $fixtureProject 'nvim/init.lua') -Value '-- fixture'
    $installer = Join-Path $fixtureProject 'script/install-windows.ps1'
    $global:NvimInstallTestCalls.Clear()
    $config = Join-Path $env:XDG_CONFIG_HOME 'nvim'
    $data = Join-Path $env:XDG_DATA_HOME 'nvim-data'
    New-Item -ItemType Directory -Force -Path $config, (Join-Path $data 'site/pack/packer') | Out-Null
    Set-Content -LiteralPath (Join-Path $config 'sentinel') -Value 'old config'
    Set-Content -LiteralPath (Join-Path $data 'sentinel') -Value 'old data'
    & $installer -Mode Config
    if ($env:RUSTUP_AUTO_INSTALL -ne '1') { throw 'Rustup environment was not restored after successful checks' }
    if (-not (Test-Path -LiteralPath (Join-Path $config 'init.lua'))) { throw 'Configuration was not copied' }
    $configBackups = @(Get-ChildItem -LiteralPath $env:XDG_CONFIG_HOME -Filter 'nvim.backup.*')
    $dataBackups = @(Get-ChildItem -LiteralPath $env:XDG_DATA_HOME -Filter 'nvim-data.backup.*')
    if ($configBackups.Count -ne 1 -or -not (Test-Path -LiteralPath (Join-Path $configBackups[0].FullName 'sentinel'))) {
        throw 'Configuration backup lost its sentinel'
    }
    if ($dataBackups.Count -ne 1 -or -not (Test-Path -LiteralPath (Join-Path $dataBackups[0].FullName 'sentinel'))) {
        throw 'Packer data backup lost its sentinel'
    }
    if ($global:NvimInstallTestCalls.Count -ne 5) { throw 'Missing plugins/parser/startup/search/compatibility invocations' }
    if (-not ($global:NvimInstallTestCalls -match '\+Lazy! sync')) { throw 'Fresh configuration did not sync plugins' }
    if (-not ($global:NvimInstallTestCalls -match '-u NONE')) { throw 'Plugin bootstrap loaded full init' }
    if (-not ($global:NvimInstallTestCalls -match 'vim.go.loadplugins = true')) { throw 'Bootstrap disabled Lazy loading' }
    if (-not ($global:NvimInstallTestCalls -match 'cquit 1')) { throw 'Bootstrap errors must fail installation' }
    if (-not ($global:NvimInstallTestCalls -match 'test_compat.lua')) { throw 'Compatibility check missing' }
    $localLock = '{"local-plugin":{"commit":"local-revision"}}'
    [IO.File]::WriteAllText((Join-Path $config 'lazy-lock.json'), $localLock)
    $global:NvimInstallTestCalls.Clear()
    & $installer -Mode Config
    if (-not ($global:NvimInstallTestCalls -match '\+Lazy! restore')) { throw 'Existing local lock was not restored' }
    if ([IO.File]::ReadAllText((Join-Path $config 'lazy-lock.json')) -ne $localLock) { throw 'Local lock was lost during reinstall' }
    $global:NvimInstallTestCalls.Clear()
    $global:NvimInstallTestFailure = 'test_config.lua'
    $rejected = $false
    try { & $installer -Mode Config } catch { $rejected = $true }
    if (-not $rejected) { throw 'Startup failure was ignored' }
    if ($global:NvimInstallTestCalls -match 'test_search.lua') { throw 'Continued after failed startup' }

    # Backing up legacy data must not move the checkout containing the installer.
    $global:NvimInstallTestFailure = ''
    $env:XDG_DATA_HOME = Join-Path $root 'nested data'
    $env:XDG_CONFIG_HOME = Join-Path $root 'nested config'
    $nestedData = Join-Path $env:XDG_DATA_HOME 'nvim-data'
    $nestedProject = Join-Path $nestedData 'checkout'
    New-Item -ItemType Directory -Force -Path (Join-Path $nestedData 'site/pack/packer'),
        (Join-Path $nestedProject 'script'), (Join-Path $nestedProject 'nvim') | Out-Null
    Copy-Item -LiteralPath $installer -Destination (Join-Path $nestedProject 'script/install-windows.ps1')
    Copy-Item -LiteralPath (Join-Path $fixtureRoot 'script/windows-compiler.ps1') -Destination (Join-Path $nestedProject 'script/windows-compiler.ps1')
    Set-Content -LiteralPath (Join-Path $nestedProject 'nvim/init.lua') -Value '-- fixture'
    $rejected = $false
    try { & (Join-Path $nestedProject 'script/install-windows.ps1') -Mode Config } catch { $rejected = $true }
    if (-not $rejected -or -not (Test-Path -LiteralPath (Join-Path $nestedProject 'nvim/init.lua')) -or
        (Test-Path -LiteralPath $env:XDG_CONFIG_HOME)) { throw 'Nested checkout was not safely rejected' }
    if ($env:PATH -ne $savedEnv['PATH']) { throw 'Installer changed PATH' }
    Write-Output 'PASS: Windows modes, read-only checks, WhatIf, spaced paths, copied config/backups and failure propagation (mock tools)'
} finally {
    foreach ($name in $savedEnv.Keys) { [Environment]::SetEnvironmentVariable($name, $savedEnv[$name], 'Process') }
    foreach ($name in @('nvim.exe', 'tree-sitter.exe', 'fzf.exe', 'rust-analyzer.exe', 'rustfmt.exe', 'pyright-langserver.cmd',
        'git.exe', 'curl.exe', 'fd.exe', 'rg.exe', 'cargo.exe', 'rustc.exe', 'rustup.exe', 'node.exe', 'npm.cmd')) {
        Remove-Item -LiteralPath ('Function:\' + $name) -ErrorAction SilentlyContinue
    }
    Remove-Variable NvimInstallTestCalls, NvimInstallTestFailure, NvimToolTestCalls, NvimRustTestFailure, NvimVersionTestOld, NvimCompilerInitCalls, NvimCompilerCheckCalls -Scope Global -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item $fixtureRoot -Recurse -Force }
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
