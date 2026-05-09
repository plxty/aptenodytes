EAPI="8"

# this is an package overlay:
inherit dirty-deeds
eval "$(pkg_overlay)"

if [[ "${ARCH}" == "arm64-macos" ]]; then
  # we're here
  KEYWORDS="${KEYWORDS} ~arm64-macos"

  # follow upstream beta's path:
  SRC_URI="
    $(rust_all_arch_uris "rust-${PV}")
    rust-src? ( ${RUST_TOOLCHAIN_BASEURL%/}/2025-08-07/rust-src-${PV}.tar.xz -> rust-src-${PV}.tar.xz )
  "

  # don't patchelf on darwin:
  patchelf() {
    echo "skipping: patchelf ${*}"
  }

  # remove some un-buildable depends:
  RDEPEND="${RDEPEND/sys-apps\/lsb-release/}"
  BDEPEND="${BDEPEND/prefix? ( dev-util\/patchelf )/}"
fi
