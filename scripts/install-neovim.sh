#!/usr/bin/env bash
# Install the reviewed upstream Linux release, not a moving Arch package/nightly.
set -euo pipefail

fail() { printf 'Neovim install: %s\n' "$*" >&2; exit 1; }
[[ $# == 0 ]] || fail 'usage: bash scripts/install-neovim.sh (installs under $HOME/.local)'
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
version=$(<"$repo/.neovim-version")
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail 'invalid stable version in .neovim-version'
[[ $(uname -s) == Linux ]] || fail 'this installer supports Linux only; install the pinned version with your OS package manager'
case $(uname -m) in
    x86_64) arch=x86_64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) fail 'unsupported architecture (expected x86_64 or aarch64)' ;;
esac
archive="nvim-linux-$arch.tar.gz"
checksum=''
while read -r digest name extra; do
    if [[ $name == "$archive" ]]; then
        [[ -z $checksum && -z $extra && $digest =~ ^[0-9a-f]{64}$ ]] || fail 'invalid or duplicate checksum'
        checksum=$digest
    fi
done < "$repo/neovim-sha256.txt"
[[ -n $checksum ]] || fail "missing checksum for $archive"

prefix="$HOME/.local"
target="$prefix/opt/nvim-v$version-linux-$arch"
link="$prefix/bin/nvim"
# Never clobber a manually installed executable/directory. Existing symlinks can
# switch versions, but their old targets are retained for explicit rollback.
[[ ! -e $link || -L $link ]] || fail "refusing to replace non-symlink $link"
check_version() {
    [[ -x $1/bin/nvim ]] || fail "missing executable in $1"
    local output
    output=$("$1/bin/nvim" --version) || fail "cannot execute $1/bin/nvim"
    [[ ${output%%$'\n'*} == "NVIM v$version" ]] || fail "binary does not report pinned version $version"
}

if [[ -e $target || -L $target ]]; then
    [[ -f $target/.release-sha256 && $(<"$target/.release-sha256") == "$checksum" ]] \
        || fail "unverified existing target $target; inspect/remove it explicitly before retrying"
    check_version "$target"
else
    for tool in curl sha256sum tar; do
        command -v "$tool" >/dev/null || fail "required tool is missing: $tool"
    done
    install -d -- "$prefix/opt"
    staging=$(mktemp -d "$prefix/opt/.nvim-install.XXXXXXXX")
    trap 'rm -rf -- "$staging"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    curl --proto '=https' --tlsv1.2 --fail --silent --show-error --location --retry 3 \
        "https://github.com/neovim/neovim/releases/download/v$version/$archive" \
        --output "$staging/$archive"
    (cd -- "$staging" && printf '%s  %s\n' "$checksum" "$archive" | sha256sum --check --status) \
        || fail "checksum verification failed for $archive"
    tar -xzf "$staging/$archive" -C "$staging"
    extracted="$staging/nvim-linux-$arch"
    check_version "$extracted"
    printf '%s\n' "$checksum" > "$extracted/.release-sha256"
    mv -T -- "$extracted" "$target"
fi
install -d -- "$prefix/bin"
ln -sfn -- "$target/bin/nvim" "$link"
printf 'Pinned Neovim %s: %s -> %s/bin/nvim\n' "$version" "$link" "$target"
