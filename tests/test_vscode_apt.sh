#!/usr/bin/env bash
# Unit tests for add_apt_repo and install_vscode in setup.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

PASS_COUNT=0
FAIL_COUNT=0

assert_eq() {
    local actual="$1" expected="$2" msg="$3"
    if [ "$actual" = "$expected" ]; then
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "FAIL: $msg"
        echo "  expected: $expected"
        echo "  actual:   $actual"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

assert_file_exists() {
    local path="$1" msg="$2"
    if [ -f "$path" ]; then
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "FAIL: $msg (missing file: $path)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

assert_file_not_exists() {
    local path="$1" msg="$2"
    if [ ! -e "$path" ]; then
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "FAIL: $msg (unexpected file: $path)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# Load functions from setup.sh without running main
# (Requires main "$@" to be guarded in setup.sh)
# shellcheck source=../setup.sh
source "$REPO_ROOT/setup.sh"
SUDO_ALIVE_PID=""
trap 'rm -rf "$TEST_ROOT"' EXIT

# --- Mocks ---
MOCK_APT_UPDATE_FAIL=false
INSTALLED_PACKAGES=()

rewrite_path() {
    local arg="$1"
    arg="${arg#/}"
    if [[ "$1" == /etc/* ]] || [[ "$1" == /usr/* ]]; then
        echo "${TEST_ROOT}/${arg}"
    elif [[ "$1" == Dir::Etc::sourcelist=* ]]; then
        local p="${1#Dir::Etc::sourcelist=}"
        echo "Dir::Etc::sourcelist=${TEST_ROOT}/${p#/}"
    else
        echo "$1"
    fi
}

sudo() {
    local args=()
    for a in "$@"; do
        args+=("$(rewrite_path "$a")")
    done
    if [ "${args[0]}" = "apt-get" ]; then
        if [ "$MOCK_APT_UPDATE_FAIL" = true ]; then
            return 1
        fi
        return 0
    fi
    "${args[@]}"
}

run_quiet() {
    "$@"
}

curl() {
    local out=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -o) out="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    printf '%s\n' "-----BEGIN PGP PUBLIC KEY BLOCK-----" "mockkey" "-----END PGP PUBLIC KEY BLOCK-----" > "$out"
}

gpg() {
    cat
}

apt_install() {
    INSTALLED_PACKAGES+=("$*")
}

reset_test_fs() {
    rm -rf "${TEST_ROOT}/etc" "${TEST_ROOT}/usr"
    mkdir -p "${TEST_ROOT}/etc/apt/sources.list.d" "${TEST_ROOT}/etc/apt/keyrings" "${TEST_ROOT}/usr/share/keyrings"
    MOCK_APT_UPDATE_FAIL=false
    INSTALLED_PACKAGES=()
}

# --- Test 1: Legacy add_apt_repo (3 args) ---
reset_test_fs
add_apt_repo "https://example.com/key.gpg" "legacy-tool" "deb [arch=amd64 signed-by=/etc/apt/keyrings/legacy-tool.gpg] https://example.com/apt stable main"
assert_file_exists "${TEST_ROOT}/etc/apt/keyrings/legacy-tool.gpg" "legacy keyring created"
assert_file_exists "${TEST_ROOT}/etc/apt/sources.list.d/legacy-tool.list" "legacy .list created"
assert_file_not_exists "${TEST_ROOT}/etc/apt/sources.list.d/legacy-tool.sources" "legacy should not create .sources"

# --- Test 2: DEB822 add_apt_repo (4 args with custom keyring) ---
reset_test_fs
deb822_spec=$'Types: deb\nURIs: https://example.com/repo\nSuites: stable\nComponents: main\nSigned-By: /usr/share/keyrings/custom.gpg'
add_apt_repo "https://example.com/key.asc" "custom-tool" "$deb822_spec" "/usr/share/keyrings/custom.gpg"
assert_file_exists "${TEST_ROOT}/usr/share/keyrings/custom.gpg" "custom keyring created"
assert_file_exists "${TEST_ROOT}/etc/apt/sources.list.d/custom-tool.sources" "DEB822 .sources created"
assert_file_not_exists "${TEST_ROOT}/etc/apt/sources.list.d/custom-tool.list" "DEB822 should not create .list"
assert_eq "$(cat "${TEST_ROOT}/etc/apt/sources.list.d/custom-tool.sources")" "$deb822_spec" "DEB822 content matches"

# --- Test 3: add_apt_repo rollback on apt-get update failure ---
reset_test_fs
MOCK_APT_UPDATE_FAIL=true
if add_apt_repo "https://example.com/key.asc" "fail-tool" "$deb822_spec" "/usr/share/keyrings/fail.gpg"; then
    echo "FAIL: expected add_apt_repo to fail when apt-get update fails"
    FAIL_COUNT=$((FAIL_COUNT + 1))
else
    PASS_COUNT=$((PASS_COUNT + 1))
fi
assert_file_not_exists "${TEST_ROOT}/usr/share/keyrings/fail.gpg" "failed keyring rolled back"
assert_file_not_exists "${TEST_ROOT}/etc/apt/sources.list.d/fail-tool.sources" "failed .sources rolled back"

# --- Test 4: install_vscode uses DEB822, /usr/share/keyrings/microsoft.gpg, and cleans legacy files ---
reset_test_fs
touch "${TEST_ROOT}/etc/apt/sources.list.d/vscode.list" "${TEST_ROOT}/etc/apt/keyrings/vscode.gpg"
install_vscode
assert_file_not_exists "${TEST_ROOT}/etc/apt/sources.list.d/vscode.list" "legacy vscode.list removed"
assert_file_not_exists "${TEST_ROOT}/etc/apt/keyrings/vscode.gpg" "legacy vscode.gpg removed"
assert_file_exists "${TEST_ROOT}/usr/share/keyrings/microsoft.gpg" "microsoft.gpg created"
assert_file_exists "${TEST_ROOT}/etc/apt/sources.list.d/vscode.sources" "vscode.sources created"

expected_vscode_sources=$'Types: deb\nURIs: https://packages.microsoft.com/repos/code\nSuites: stable\nComponents: main\nArchitectures: amd64,arm64,armhf\nSigned-By: /usr/share/keyrings/microsoft.gpg'
assert_eq "$(cat "${TEST_ROOT}/etc/apt/sources.list.d/vscode.sources")" "$expected_vscode_sources" "vscode.sources matches official docs"
assert_eq "${INSTALLED_PACKAGES[*]}" "code" "install_vscode installs code"

echo "Passed: $PASS_COUNT, Failed: $FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
