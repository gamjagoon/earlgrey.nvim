<#
.SYNOPSIS
Installs Windows tools, installs the Neovim configuration, or checks prerequisites.
.DESCRIPTION
Native Windows x64. The default All mode installs tools and the configuration.
Config uses existing tools without installing them; Tools installs prerequisites;
Check performs read-only prerequisite checks. Existing configuration is moved to
a timestamped backup. The copied configuration does not require symlink
privileges or this checkout to remain in place. Rerun after updating the repo.
.PARAMETER Mode
All (default), Tools, Config, or Check.
.PARAMETER InstallTools
Compatibility alias for the default All mode.
.EXAMPLE
powershell -ExecutionPolicy Bypass -File script/install-windows.ps1
.EXAMPLE
powershell -ExecutionPolicy Bypass -File script/install-windows.ps1 -Mode Config
.EXAMPLE
powershell -ExecutionPolicy Bypass -File script/install-windows.ps1 -Mode Check
.EXAMPLE
powershell -ExecutionPolicy Bypass -File script/install-windows.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('All', 'Tools', 'Config', 'Check')]
    [string]$Mode = 'All',
    [switch]$Help,
    [Parameter(DontShow)]
    [switch]$InstallTools
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
if ($Help) { Get-Help $PSCommandPath -Detailed; return }
if ($InstallTools -and $Mode -ne 'All') { throw '-InstallTools is a compatibility alias for -Mode All and cannot be combined with another mode.' }
$script:InstallerPSCmdlet = $PSCmdlet

function Invoke-InstallerShouldProcess([string]$Target, [string]$Action) {
    return $script:InstallerPSCmdlet.ShouldProcess($Target, $Action)
}

$script:WingetPackages = @(
    'Neovim.Neovim', 'Git.Git', 'cURL.cURL', 'sharkdp.fd',
    'BurntSushi.ripgrep.MSVC', 'junegunn.fzf', 'tree-sitter.tree-sitter-cli',
    'OpenJS.NodeJS.LTS', 'MartinStorsjo.LLVM-MinGW.UCRT', 'Rustlang.Rustup'
)
$script:RequiredTools = @(
    @{ Command = 'nvim.exe'; Minimum = '0.12.0'; Url = 'https://github.com/neovim/neovim/releases/latest' }
    @{ Command = 'git.exe'; Minimum = ''; Url = 'https://git-scm.com/downloads/win' }
    @{ Command = 'curl.exe'; Minimum = ''; Url = 'https://curl.se/windows/' }
    @{ Command = 'fd.exe'; Minimum = ''; Url = 'https://github.com/sharkdp/fd/releases/latest' }
    @{ Command = 'rg.exe'; Minimum = ''; Url = 'https://github.com/BurntSushi/ripgrep/releases/latest' }
    @{ Command = 'fzf.exe'; Minimum = '0.52.1'; Url = 'https://github.com/junegunn/fzf/releases/latest' }
    @{ Command = 'tree-sitter.exe'; Minimum = '0.26.1'; Url = 'https://github.com/tree-sitter/tree-sitter/releases/latest' }
    @{ Command = 'node.exe'; Minimum = ''; Url = 'https://nodejs.org/en/download' }
    @{ Command = 'npm.cmd'; Minimum = ''; Url = 'https://nodejs.org/en/download' }
    @{ Command = 'cargo.exe'; Minimum = ''; Url = 'https://rustup.rs/' }
    @{ Command = 'rustc.exe'; Minimum = ''; Url = 'https://rustup.rs/' }
    @{ Command = 'rustup.exe'; Minimum = ''; Url = 'https://rustup.rs/' }
    @{ Command = 'rust-analyzer.exe'; Minimum = ''; Url = 'https://rustup.rs/' }
    @{ Command = 'rustfmt.exe'; Minimum = ''; Url = 'https://rustup.rs/' }
    @{ Command = 'pyright-langserver.cmd'; Minimum = ''; Url = 'https://github.com/microsoft/pyright/blob/main/docs/installation.md' }
)
$script:RustToolchain = 'stable-x86_64-pc-windows-gnullvm'

function Assert-WindowsPlatform {
    if (-not $WhatIfPreference -and $env:OS -ne 'Windows_NT') {
        if ($Mode -eq 'Tools') { throw 'Run this installer in native Windows PowerShell. For WSL use install-linux.sh --mode tools.' }
        if ($Mode -eq 'Check') { throw 'Run this checker in native Windows PowerShell. For WSL use install-linux.sh.' }
        throw 'Run this installer in native Windows PowerShell. For WSL use install-linux.sh.'
    }
}

function Show-ToolLinks {
    Write-Host 'Install Windows x64 tools using this script in Tools mode or use these official pages:'
    foreach ($tool in $script:RequiredTools) { Write-Host ('  {0}: {1}' -f $tool.Command, $tool.Url) }
    Write-Host '  LLVM-MinGW UCRT x64: https://github.com/mstorsjo/llvm-mingw/releases'
    Write-Host ('  Rust host: {0}' -f $script:RustToolchain)
    Write-Host 'Setup instructions: docs/windows-setup.md'
}

function Invoke-ReadOnlyToolCheck {
    Show-ToolLinks
    if ($WhatIfPreference) { return }
    $failures = @()
    . (Join-Path $PSScriptRoot 'windows-compiler.ps1')
    try { $null = Get-WindowsCompiler } catch { $failures += [string]$_ }

    $originalRustAutoInstall = [Environment]::GetEnvironmentVariable('RUSTUP_AUTO_INSTALL', 'Process')
    try {
        # Rustup shims can install a missing toolchain when invoked. Keep the
        # original checker guard for probes and restore the caller's setting.
        [Environment]::SetEnvironmentVariable('RUSTUP_AUTO_INSTALL', '0', 'Process')
        foreach ($tool in $script:RequiredTools) {
            $command = $tool.Command
            if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
                $failures += "$command is missing. Install: $($tool.Url)"
                continue
            }
            # Validate Rustup proxies through rustup run, while the auto-install
            # guard is active, so a missing toolchain never triggers bootstrap.
            if ($command -in @('cargo.exe', 'rustc.exe', 'rustup.exe', 'rust-analyzer.exe', 'rustfmt.exe')) { continue }
            if ($command -eq 'pyright-langserver.cmd') { continue }
            try {
                $output = (& $command --version 2>&1) -join ' '
                if ($LASTEXITCODE -ne 0) { throw "exit code $LASTEXITCODE; $output" }
                if ($tool.Minimum -and ($output -notmatch '(\d+\.\d+\.\d+)' -or [version]$Matches[1] -lt [version]$tool.Minimum)) {
                    throw "requires >= $($tool.Minimum); found: $output"
                }
            } catch { $failures += "$command is not usable: $_. Install/update: $($tool.Url)" }
        }
        $rustupVersion = (& rustup.exe --version 2>&1) -join ' '
        if ($LASTEXITCODE -ne 0) { throw "rustup.exe is not usable: $rustupVersion" }
        $active = (& rustup.exe show active-toolchain 2>&1) -join ' '
        if ($LASTEXITCODE -ne 0 -or $active -notmatch '^stable-x86_64-pc-windows-gnullvm(?:\s|$)') { throw 'Select stable-x86_64-pc-windows-gnullvm for this process.' }
        $hostInfo = (& rustup.exe run $script:RustToolchain rustc -vV 2>&1) -join "`n"
        if ($LASTEXITCODE -ne 0 -or $hostInfo -notmatch '(?m)^host: x86_64-pc-windows-gnullvm\s*$') { throw 'Rust host must be x86_64-pc-windows-gnullvm.' }
        foreach ($rustTool in @('cargo', 'rust-analyzer', 'rustfmt')) {
            $output = (& rustup.exe run $script:RustToolchain $rustTool --version 2>&1) -join ' '
            if ($LASTEXITCODE -ne 0) { throw "$rustTool is not usable: $output" }
        }
    } catch {
        $failures += "$_ Install/update Rust: https://rustup.rs/"
    } finally {
        [Environment]::SetEnvironmentVariable('RUSTUP_AUTO_INSTALL', $originalRustAutoInstall, 'Process')
    }
    if ($failures.Count -gt 0) { throw (($failures -join [Environment]::NewLine) + [Environment]::NewLine + 'Follow docs/windows-setup.md, then rerun this checker.') }
    Write-Host 'Required commands passed. Parser installation verifies compilation with LLVM-MinGW.'
}

function Invoke-Tool([string]$Command, [string[]]$Arguments) {
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Command failed with exit code $LASTEXITCODE" }
}

function Update-ToolPath {
    $parts = @(
        [Environment]::ExpandEnvironmentVariables([Environment]::GetEnvironmentVariable('Path', 'Machine') + ''),
        [Environment]::ExpandEnvironmentVariables([Environment]::GetEnvironmentVariable('Path', 'User') + ''),
        $env:PATH
    )
    if ($env:LLVM_MINGW_ROOT) { $parts = @((Join-Path $env:LLVM_MINGW_ROOT 'bin')) + $parts }
    $cargoHome = $env:CARGO_HOME
    if (-not $cargoHome) { $cargoHome = [Environment]::GetEnvironmentVariable('CARGO_HOME', 'User') }
    if (-not $cargoHome) { $cargoHome = [Environment]::GetEnvironmentVariable('CARGO_HOME', 'Machine') }
    if ($cargoHome) { $parts += (Join-Path $cargoHome 'bin') }
    elseif ($env:USERPROFILE) { $parts += (Join-Path $env:USERPROFILE '.cargo\bin') }
    if ($env:APPDATA) { $parts += (Join-Path $env:APPDATA 'npm') }
    if ($env:LOCALAPPDATA) { $parts += (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links') }
    if ($env:ProgramFiles) { $parts += (Join-Path $env:ProgramFiles 'WinGet\Links') }
    $seen = @{}
    $paths = @()
    foreach ($part in $parts) {
        foreach ($entry in ($part -split ';')) {
            if ($entry -and -not $seen.ContainsKey($entry)) { $seen[$entry] = $true; $paths += $entry }
        }
    }
    $env:PATH = $paths -join ';'
}

function Initialize-CompilerEnvironment {
    . (Join-Path $PSScriptRoot 'windows-compiler.ps1')
    Initialize-WindowsCompiler
}

function Invoke-InstallTools {
    if ($WhatIfPreference) {
        foreach ($id in $script:WingetPackages) {
            [void](Invoke-InstallerShouldProcess $id 'winget install --exact --source winget (accepts agreements)')
        }
        [void](Invoke-InstallerShouldProcess 'Current process' 'Refresh PATH and initialize LLVM-MinGW UCRT')
        [void](Invoke-InstallerShouldProcess $script:RustToolchain 'Install using rustup with rustfmt, rust-analyzer, rust-mingw; preserve existing default')
        [void](Invoke-InstallerShouldProcess 'Pyright and prerequisites' 'Install via npm and run tool checks')
        return
    }
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw 'winget.exe is missing. Install/update Microsoft App Installer: https://aka.ms/getwinget'
    }

    # Refresh stale shells before deciding whether Rustup is genuinely absent.
    if (-not (Invoke-InstallerShouldProcess 'Current process' 'Refresh PATH before detecting existing Rustup')) { return }
    Update-ToolPath
    foreach ($id in $script:WingetPackages) {
        if ($id -eq 'Rustlang.Rustup' -and (Get-Command rustup.exe -ErrorAction SilentlyContinue)) {
            # Re-running rustup-init with --default-* would overwrite an existing default.
            Invoke-Tool 'rustup.exe' @('--version')
            Write-Host 'Using existing Rustup; its global default host/toolchain will be retained.'
            continue
        }
        if ($id -eq 'Rustlang.Rustup') {
            $rustupHome = $env:RUSTUP_HOME
            if (-not $rustupHome) { $rustupHome = [Environment]::GetEnvironmentVariable('RUSTUP_HOME', 'User') }
            if (-not $rustupHome) { $rustupHome = [Environment]::GetEnvironmentVariable('RUSTUP_HOME', 'Machine') }
            if (-not $rustupHome -and $env:USERPROFILE) { $rustupHome = Join-Path $env:USERPROFILE '.rustup' }
            if ($rustupHome -and (Test-Path -LiteralPath (Join-Path $rustupHome 'settings.toml') -PathType Leaf)) {
                throw 'Existing Rustup settings were found but rustup.exe is unavailable after PATH refresh. Restore its Cargo bin/PATH before rerunning; existing defaults will not be overwritten.'
            }
        }
        if (-not (Invoke-InstallerShouldProcess $id 'Install or upgrade with winget')) { return }
        $arguments = @('install', '--id', $id, '--exact', '--source', 'winget', '--architecture', 'x64',
            '--silent', '--disable-interactivity', '--accept-package-agreements', '--accept-source-agreements')
        if ($id -eq 'Rustlang.Rustup') {
            # Avoid rustup-init's default MSVC host and Visual Studio bootstrap prompt.
            $arguments += @('--override', '-y --default-host x86_64-pc-windows-gnullvm --default-toolchain stable --profile minimal')
        }
        & winget.exe @arguments
        $code = $LASTEXITCODE
        $unsignedCode = [long]$code -band 4294967295L
        if ($code -eq -1978334967 -or $code -eq -1978334966) {
            throw "winget requires a Windows restart for $id (exit $code). Restart Windows and rerun."
        }
        if ($code -ne 0 -and $unsignedCode -ne 2316632107L -and $unsignedCode -ne 2316632161L) {
            throw "winget failed for $id with exit code $code"
        }
    }

    if (-not (Invoke-InstallerShouldProcess 'Current process' 'Refresh PATH and select LLVM-MinGW')) { return }
    Update-ToolPath
    Initialize-CompilerEnvironment
    if (-not (Invoke-InstallerShouldProcess $script:RustToolchain 'Install Rust tools without changing an existing default')) { return }
    Invoke-Tool 'rustup.exe' @('toolchain', 'install', $script:RustToolchain, '--profile', 'minimal',
        '--component', 'rust-analyzer', '--component', 'rustfmt', '--component', 'rust-mingw')
    if (-not (Invoke-InstallerShouldProcess 'Pyright' 'Install with npm')) { return }
    Invoke-Tool 'npm.cmd' @('install', '--global', 'pyright')
    $npmPrefix = & npm.cmd prefix --global
    if ($LASTEXITCODE -ne 0) { throw "npm prefix failed with exit code $LASTEXITCODE" }
    if ($npmPrefix) { $env:PATH = ([string]($npmPrefix | Select-Object -Last 1)) + ';' + $env:PATH }
    if (Invoke-InstallerShouldProcess 'Windows prerequisites' 'Verify installed tools and GNU LLVM host') {
        Invoke-ReadOnlyToolCheck
    }
    Write-Host 'Tool setup completed: LLVM-MinGW UCRT and Rust gnullvm; existing Rust defaults are retained.'
}

function Invoke-Nvim([string[]]$Arguments) {
    & nvim.exe @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Neovim failed with exit code $LASTEXITCODE" }
}

function Backup-Path([string]$Path) {
    if (Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue) {
        $backup = $Path + '.backup.' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
        Move-Item -LiteralPath $Path -Destination $backup
        Write-Host "Backed up $Path to $backup"
    }
}

function Invoke-InstallConfig([switch]$PrerequisitesChecked) {
    if ($env:NVIM_APPNAME -and $env:NVIM_APPNAME -ne 'nvim') { throw 'Unset NVIM_APPNAME before installing this configuration.' }
    $project = Split-Path -Parent $PSScriptRoot
    $sourceConfig = Join-Path $project 'nvim'
    if (-not (Test-Path -LiteralPath (Join-Path $sourceConfig 'init.lua'))) { throw "Missing configuration: $sourceConfig" }
    $localData = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { '[LOCALAPPDATA]' }
    $configBase = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { $localData }
    $config = Join-Path $configBase 'nvim'
    $data = if ($env:XDG_DATA_HOME) { Join-Path $env:XDG_DATA_HOME 'nvim-data' } else { Join-Path $localData 'nvim-data' }

    if (-not $PrerequisitesChecked) {
        Initialize-CompilerEnvironment
        Invoke-ReadOnlyToolCheck
    }
    if (Invoke-InstallerShouldProcess $config 'Back up existing config and copy repository configuration') {
        $sourceFull = [IO.Path]::GetFullPath($sourceConfig).Replace('/', '\').TrimEnd('\')
        $configFull = [IO.Path]::GetFullPath($config).Replace('/', '\').TrimEnd('\')
        if ($sourceFull -eq $configFull -or $sourceFull.StartsWith($configFull + '\', [StringComparison]::OrdinalIgnoreCase) -or
            $configFull.StartsWith($sourceFull + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw 'The repository nvim directory is the installation target; move the repository before installing.'
        }
        if (Test-Path -LiteralPath (Join-Path $data 'site\pack\packer')) {
            $dataFull = [IO.Path]::GetFullPath($data).Replace('/', '\').TrimEnd('\')
            if ($sourceFull.StartsWith($dataFull + '\', [StringComparison]::OrdinalIgnoreCase)) {
                throw 'The repository is inside legacy data that must be backed up; move the checkout before installing.'
            }
            Backup-Path $data
        }
        $savedLock = $null
        $installedLock = Join-Path $config 'lazy-lock.json'
        if (Test-Path -LiteralPath $installedLock -PathType Leaf) { $savedLock = [IO.File]::ReadAllText($installedLock) }
        Backup-Path $config
        New-Item -ItemType Directory -Force -Path $configBase | Out-Null
        Copy-Item -LiteralPath $sourceConfig -Destination $config -Recurse
        if ($null -ne $savedLock -and -not (Test-Path -LiteralPath (Join-Path $config 'lazy-lock.json'))) {
            [IO.File]::WriteAllText((Join-Path $config 'lazy-lock.json'), $savedLock, (New-Object System.Text.UTF8Encoding($false)))
        }
        Write-Host "Copied configuration to $config"
    }
    if (Invoke-InstallerShouldProcess 'Neovim plugins and Markdown parsers' 'Install or restore and verify') {
        # Run from the checkout so Lua test paths remain portable even with spaces.
        Push-Location -LiteralPath $project
        try {
            # Bootstrap Lazy without loading UI modules that need uninstalled plugins.
            $bootstrap = "lua vim.go.loadplugins = true; vim.opt.rtp:prepend(vim.fn.stdpath('config')); require('plugins')"
            $pluginAction = if (Test-Path -LiteralPath (Join-Path $config 'lazy-lock.json') -PathType Leaf) { 'restore' } else { 'sync' }
            Invoke-Nvim @('--headless', '-u', 'NONE', ('+' + $bootstrap), ('+Lazy! ' + $pluginAction), "+lua if vim.v.errmsg ~= '' then vim.cmd('cquit 1') end", '+qa!')
            Invoke-Nvim @('--headless', "+lua require('nvim-treesitter').install({'markdown', 'markdown_inline'}):wait(300000)", '+qa!')
            Invoke-Nvim @('--headless', '+luafile tests/test_config.lua', '+qa!')
            Invoke-Nvim @('--headless', '+luafile tests/test_search.lua', '+qa!')
            Invoke-Nvim @('--headless', '+luafile tests/test_compat.lua', '+qa!')
        } finally { Pop-Location }
        Write-Host 'Installation and startup checks completed. Run nvim to start.'
    }
}

function Show-WhatIfPlan {
    Show-ToolLinks
    if ($Mode -in @('All', 'Tools')) {
        foreach ($id in $script:WingetPackages) { [void](Invoke-InstallerShouldProcess $id 'winget install --exact --source winget (accepts agreements)') }
        [void](Invoke-InstallerShouldProcess 'Current process' 'Refresh PATH and initialize LLVM-MinGW UCRT')
        [void](Invoke-InstallerShouldProcess $script:RustToolchain 'Install using rustup with rustfmt, rust-analyzer, rust-mingw; preserve existing default')
        [void](Invoke-InstallerShouldProcess 'Pyright and prerequisites' 'Install via npm and run tool checks')
    }
    if ($Mode -in @('All', 'Config')) {
        [void](Invoke-InstallerShouldProcess 'LLVM-MinGW UCRT' 'Initialize compiler environment for parser builds')
        [void](Invoke-InstallerShouldProcess 'Windows prerequisites' 'Run read-only tool checks')
        [void](Invoke-InstallerShouldProcess 'Neovim config and data' 'Back up legacy data/config and copy repository configuration')
        [void](Invoke-InstallerShouldProcess 'Neovim plugins and Markdown parsers' 'Install or restore and verify')
    }
    if ($Mode -eq 'Check') { Write-Host 'Check mode is read-only; no environment variables or files are changed.' }
}

Assert-WindowsPlatform
if ($WhatIfPreference) { Show-WhatIfPlan; return }
if ($Mode -eq 'Check') {
    Invoke-ReadOnlyToolCheck
    return
}
if ($Mode -eq 'Tools') {
    Invoke-InstallTools
    return
}
if ($Mode -eq 'Config') {
    Invoke-InstallConfig
    return
}

Invoke-InstallTools
Invoke-InstallConfig -PrerequisitesChecked
