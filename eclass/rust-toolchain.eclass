if [[ -z ${_RUST_TOOLCHAIN_ECLASS} ]]; then
_RUST_TOOLCHAIN_ECLASS=1

# overlay for adding darwin:
inherit dirty-deeds
eval "$(class_overlay)"

# must reserve it for ebuild
: "${RUST_TOOLCHAIN_BASEURL:=https://static.rust-lang.org/dist/}"

eval __"$(declare -f rust_abi)"
rust_abi() {
  local CTARGET=${1:-${CHOST}}
  case ${CTARGET%%*-} in
    arm64-apple-darwin*) echo aarch64-apple-darwin;;
    *) __rust_abi "${@}";;
  esac
}

eval __"$(declare -f rust_all_arch_uris)"
rust_all_arch_uris() {
  __rust_all_arch_uris "${@}"
  echo "arm64-macos? ( $(rust_arch_uri aarch64-apple-darwin "${1}" "${2}") )"
}
fi
