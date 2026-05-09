EAPI="8"

inherit dirty-deeds
eval "$(pkg_overlay)"

if [[ "${ARCH}" == *"-macos" ]]; then
  # workaround to use system compiler-rt in darwin, instead of libgcc:
  # @see clang-common
  src_install_text="$(declare -f src_install)"
  eval "${src_install_text//libgcc/platform}"
fi
