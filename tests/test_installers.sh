#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/home" "$TEST_ROOT/bin" "$TEST_ROOT/project with spaces"
cp -R "$PROJECT_ROOT/script" "$PROJECT_ROOT/nvim" "$PROJECT_ROOT/tests" "$TEST_ROOT/project with spaces/"
FIXTURE="$TEST_ROOT/project with spaces"
rm -f "$FIXTURE/nvim/lazy-lock.json"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
cat > "$TEST_ROOT/bin/curl" <<'STUB'
#!/usr/bin/env bash
printf 'unexpected curl: %s\n' "$*" >> "$INSTALLER_NETWORK_LOG"
exit 19
STUB
chmod +x "$TEST_ROOT/bin/curl"

[[ ! -e "$FIXTURE/script/install-tools-linux.sh" && ! -e "$FIXTURE/script/install-tools-macos.sh" ]] \
    || fail 'obsolete Unix tool installer entrypoints remain'

# Every mode on both OS entrypoints must remain offline and write-free in dry-run mode.
for os in linux macos; do
    for mode in all tools config check; do
        env -u NVIM_APPNAME HOME="$TEST_ROOT/home" XDG_CONFIG_HOME="$TEST_ROOT/config" \
            XDG_DATA_HOME="$TEST_ROOT/data" PATH="$TEST_ROOT/bin:$PATH" \
            INSTALLER_NETWORK_LOG="$TEST_ROOT/network.log" bash "$FIXTURE/script/install-$os.sh" \
            --mode "$mode" --dry-run > "$TEST_ROOT/$os-$mode.log"
    done
done
[[ -z $(ls -A "$TEST_ROOT/home") && ! -e "$TEST_ROOT/config" && ! -e "$TEST_ROOT/data" ]] \
    || fail 'dry run changed HOME/config/data'
[[ ! -e "$TEST_ROOT/network.log" ]] || fail 'dry run attempted network access'

for os in linux macos; do
    grep -q 'Resolve latest stable Neovim' "$TEST_ROOT/$os-all.log" \
        || fail "$os all mode omitted tool provisioning"
    grep -q 'Bootstrap Lazy and run Lazy! sync' "$TEST_ROOT/$os-all.log" \
        || fail "$os all mode omitted config/plugin work"
    grep -q 'Check Neovim >=0.12' "$TEST_ROOT/$os-tools.log" \
        || fail "$os tools mode omitted final tool checks"
    if grep -Eq 'setup_init_file|Sync plugins|Lazy!' "$TEST_ROOT/$os-tools.log"; then
        fail "$os tools mode included config/plugin work"
    fi
    grep -q 'Check Neovim >=0.12' "$TEST_ROOT/$os-config.log" \
        || fail "$os config mode omitted ordered tool checks"
    grep -q 'setup_init_file.sh' "$TEST_ROOT/$os-config.log" \
        || fail "$os config mode omitted setup step"
    grep -q 'Bootstrap Lazy and run Lazy! sync' "$TEST_ROOT/$os-config.log" \
        || fail "$os config mode omitted plugin step"
    if grep -Eq 'apt-get|dnf install|pacman -S|brew install|Resolve latest stable Neovim|Install rustup' \
        "$TEST_ROOT/$os-config.log"; then
        fail "$os config mode included tool installation"
    fi
    grep -q '^Check Neovim >=0.12' "$TEST_ROOT/$os-check.log" \
        || fail "$os check mode omitted tool checks"
    if grep -Eq 'apt-get|dnf install|pacman -S|brew install|setup_init_file|Sync plugins|Lazy!|Resolve latest stable Neovim' \
        "$TEST_ROOT/$os-check.log"; then
        fail "$os check mode included install/config work"
    fi
done

# --help is available on each OS entrypoint and does not require platform support.
for os in linux macos; do
    env -u NVIM_APPNAME HOME="$TEST_ROOT/home" bash "$FIXTURE/script/install-$os.sh" --help \
        > "$TEST_ROOT/$os-help.log"
    grep -q 'all|tools|config|check' "$TEST_ROOT/$os-help.log" || fail "$os help omitted modes"
    grep -q 'bootstraps Lazy, and syncs plugins' "$TEST_ROOT/$os-help.log" \
        || fail "$os help omitted automatic Lazy sync"
done

expect_cli_error() {
    local description=$1 status=0
    shift
    if env -u NVIM_APPNAME HOME="$TEST_ROOT/home" bash "$FIXTURE/script/install-linux.sh" "$@" \
        > "$TEST_ROOT/cli-error.log" 2>&1; then
        status=0
    else
        status=$?
    fi
    [[ $status == 2 ]] || fail "$description should exit with status 2 (got $status)"
}
expect_cli_error 'unknown mode' --mode unknown
expect_cli_error 'empty mode' --mode=
expect_cli_error 'missing mode' --mode
expect_cli_error 'unknown option' --not-an-option
expect_cli_error '--skip-tools conflict' --mode all --skip-tools
expect_cli_error 'conflicting modes' --mode tools --mode check

# Read-only mode uses stub tools to validate versions without creating user files.
cat > "$TEST_ROOT/bin/nvim" <<'STUB'
#!/usr/bin/env bash
if [[ ${1:-} == --version ]]; then
    printf 'check nvim\n' >> "$INSTALL_TEST_LOG"
    printf 'NVIM v%s\n' "${INSTALL_TEST_NVIM_VERSION:-0.12.6}"
    exit 0
fi
printf 'operation %s\n' "$*" >> "$INSTALL_TEST_LOG"
if [[ -n ${INSTALL_TEST_FAIL:-} && "$*" == *"$INSTALL_TEST_FAIL"* ]]; then exit 17; fi
STUB
cat > "$TEST_ROOT/bin/tree-sitter" <<'STUB'
#!/usr/bin/env bash
printf 'check tree-sitter\n' >> "$INSTALL_TEST_LOG"
printf 'tree-sitter 0.26.1\n'
STUB
cat > "$TEST_ROOT/bin/fzf" <<'STUB'
#!/usr/bin/env bash
printf 'check fzf\n' >> "$INSTALL_TEST_LOG"
printf '0.44.1\n'
STUB
cat > "$TEST_ROOT/bin/rust-analyzer" <<'STUB'
#!/usr/bin/env bash
[[ ${RUSTUP_AUTO_INSTALL:-} == 0 ]] || exit 18
printf 'check rust-analyzer\n' >> "$INSTALL_TEST_LOG"
exit 0
STUB
cat > "$TEST_ROOT/bin/rustfmt" <<'STUB'
#!/usr/bin/env bash
[[ ${RUSTUP_AUTO_INSTALL:-} == 0 ]] || exit 18
printf 'check rustfmt\n' >> "$INSTALL_TEST_LOG"
exit 0
STUB
for tool in rustup pyright-langserver fd rg git curl cc node npm; do
    if [[ "$tool" != curl ]]; then printf '#!/usr/bin/env bash\nexit 0\n' > "$TEST_ROOT/bin/$tool"; fi
done
chmod +x "$TEST_ROOT/bin/"*

run_installer() {
    local failure=${1:-}
    shift || true
    env -u NVIM_APPNAME HOME="$TEST_ROOT/home" \
        XDG_CONFIG_HOME="${INSTALL_TEST_XDG_CONFIG:-$TEST_ROOT/config}" \
        XDG_DATA_HOME="${INSTALL_TEST_XDG_DATA:-$TEST_ROOT/data}" PATH="$TEST_ROOT/bin:$PATH" \
        INSTALL_TEST_LOG="$TEST_ROOT/nvim.log" INSTALL_TEST_FAIL="$failure" \
        INSTALLER_NETWORK_LOG="$TEST_ROOT/network.log" \
        INSTALL_TEST_NVIM_VERSION="${INSTALL_TEST_NVIM_VERSION:-0.12.6}" RUSTUP_AUTO_INSTALL=1 \
        bash "$FIXTURE/script/install-linux.sh" "$@"
}

: > "$TEST_ROOT/nvim.log"
run_installer '' --mode check > "$TEST_ROOT/check.log"
[[ $(grep -c '^check ' "$TEST_ROOT/nvim.log") == 5 ]] || fail 'check mode did not run all tool/version probes'
grep -q '^check rust-analyzer$' "$TEST_ROOT/nvim.log" || fail 'rust-analyzer check missing'
grep -q '^check rustfmt$' "$TEST_ROOT/nvim.log" || fail 'rustfmt check missing'
[[ ! -e "$TEST_ROOT/config" && ! -e "$TEST_ROOT/data" && -z $(ls -A "$TEST_ROOT/home") ]] \
    || fail 'check mode changed user files'
[[ ! -e "$TEST_ROOT/network.log" ]] || fail 'check mode attempted network access'

# Config validates tools before linking configuration or starting plugin work.
: > "$TEST_ROOT/nvim.log"
run_installer '' --mode config > "$TEST_ROOT/install.log"
[[ "$TEST_ROOT/config/nvim" -ef "$FIXTURE/nvim" ]] || fail 'configuration not linked'
[[ $(grep -c '^operation ' "$TEST_ROOT/nvim.log") == 5 ]] || fail 'missing plugins/parser/startup/search/compatibility steps'
check_last=$(grep -n '^check ' "$TEST_ROOT/nvim.log" | tail -n 1 | cut -d: -f1)
operation_first=$(grep -n '^operation ' "$TEST_ROOT/nvim.log" | head -n 1 | cut -d: -f1)
[[ $check_last -lt $operation_first ]] || fail 'configuration/plugin work began before checks completed'
grep -q 'operation .*Lazy! sync' "$TEST_ROOT/nvim.log" || fail 'fresh install must sync without lock'
if grep -q 'Lazy! restore' "$TEST_ROOT/nvim.log"; then fail 'installer must never restore based on a local lockfile'; fi
grep -q 'operation .*tests/test_config.lua' "$TEST_ROOT/nvim.log" || fail 'startup check missing'
grep -q 'operation .*tests/test_search.lua' "$TEST_ROOT/nvim.log" || fail 'search check missing'
grep -q 'operation .*tests/test_compat.lua' "$TEST_ROOT/nvim.log" || fail 'compatibility check missing'

# A local lockfile does not change the sync action, including through the legacy alias.
printf '{}\n' > "$FIXTURE/nvim/lazy-lock.json"
: > "$TEST_ROOT/nvim.log"
run_installer '' --skip-tools > "$TEST_ROOT/reinstall.log"
grep -q 'operation .*Lazy! sync' "$TEST_ROOT/nvim.log" || fail 'legacy alias/local lock must still sync'
if grep -q 'Lazy! restore' "$TEST_ROOT/nvim.log"; then fail 'installer must never restore based on a local lockfile'; fi
if grep -Eq 'apt-get|dnf install|pacman -S|brew install|Resolve latest stable Neovim' "$TEST_ROOT/reinstall.log"; then
    fail '--skip-tools alias attempted tool installation'
fi

# A failed prerequisite check prevents configuration changes.
rm -f "$FIXTURE/nvim/lazy-lock.json"
: > "$TEST_ROOT/nvim.log"
if INSTALL_TEST_NVIM_VERSION=0.1.0 INSTALL_TEST_XDG_CONFIG="$TEST_ROOT/failed-config" \
    run_installer '' --mode config > "$TEST_ROOT/tool-failure.log" 2>&1; then
    fail 'config accepted an outdated Neovim'
fi
[[ ! -e "$TEST_ROOT/failed-config/nvim" ]] || fail 'config changed files after a failed tool check'

# Plugin provisioning failures stop before parser/startup checks.
: > "$TEST_ROOT/nvim.log"
if run_installer 'Lazy! sync' --mode config > "$TEST_ROOT/plugins-failure.log" 2>&1; then fail 'plugin failure ignored'; fi
[[ $(grep -c '^operation ' "$TEST_ROOT/nvim.log") == 1 ]] || fail 'continued after plugin failure'

: > "$TEST_ROOT/nvim.log"
if run_installer test_config.lua --mode config > "$TEST_ROOT/failure.log" 2>&1; then fail 'startup failure ignored'; fi
[[ $(grep -c '^operation ' "$TEST_ROOT/nvim.log") == 3 ]] || fail 'continued after failed startup'

# A custom app name must fail before configuration changes.
if env NVIM_APPNAME=other HOME="$TEST_ROOT/home" XDG_CONFIG_HOME="$TEST_ROOT/other-config" \
    bash "$FIXTURE/script/install-linux.sh" --mode config > "$TEST_ROOT/appname.log" 2>&1; then
    fail 'custom app name accepted'
fi
[[ ! -e "$TEST_ROOT/other-config" ]] || fail 'custom app name changed configuration'
printf 'PASS: installer modes, offline dry runs, read-only checks and failure propagation\n'
