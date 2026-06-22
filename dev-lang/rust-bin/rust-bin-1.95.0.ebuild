EAPI="8"

# [aptenodytes] pin_until_stable=1
inherit dirty-deeds
eval "$(pkg_overlay)"

# @see eclass/rust-toolchain.eclass, uri has been appended.
KEYWORDS="${KEYWORDS} ~arm64-macos"

if [[ "${ARCH}" == "arm64-macos" ]]; then
  # don't patchelf on darwin:
  patchelf() {
    :
  }

  # remove some un-buildable depends:
  RDEPEND="${RDEPEND/sys-apps\/lsb-release/}"
  BDEPEND="${BDEPEND/prefix? ( dev-util\/patchelf )/}"
fi
