EAPI="8"

# @see eclass/rust-toolchain.eclass, uri has been appended.
inherit dirty-deeds
eval "$(pkg_overlay --arch arm64-macos)"

# don't patchelf on darwin:
patchelf() {
	:
}

# remove some un-buildable depends:
RDEPEND="${RDEPEND/sys-apps\/lsb-release/}"
BDEPEND="${BDEPEND/prefix? ( dev-util\/patchelf )/}"
