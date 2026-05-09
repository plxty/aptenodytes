if [[ -z ${_RUST_TOOLCHAIN_ECLASS} ]]; then
_RUST_TOOLCHAIN_ECLASS=1

inherit dirty-deeds
eval "$(class_overlay)"

# workaround for darwin prefix:
if [[ "${ARCH}" == "arm64-macos" ]]; then
  rust_abi() {
    echo "aarch64-apple-darwin"
  }

  rust_all_arch_uris() {
    rust_arch_uri aarch64-apple-darwin "${1}" "${2}"
  }
fi
fi
