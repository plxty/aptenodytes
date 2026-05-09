EAPI="8"

inherit dirty-deeds
eval "$(pkg_overlay)"

if [[ "${ARCH}" == "arm64-macos" ]]; then
  # break pulling the libcxx, we're not in bootstrap, we build it from gcc:
  BDEPEND="${BDEPEND/kernel_Darwin?/!kernel_Darwin?}"
fi
