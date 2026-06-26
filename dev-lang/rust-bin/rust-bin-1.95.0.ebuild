EAPI="8"

inherit dirty-deeds rust-toolchain

# filter to have only darwin to reduce download size, @see rust-toolchain.eclass
rust_all_arch_uris() {
	echo "arm64-macos? ( $(rust_arch_uri aarch64-apple-darwin "${1}" "${2}") )"
}

# eclass in here is "overrided", with the guard we add :)
eval "$(pkg_overlay --arch arm64-macos)"

# don't patchelf on darwin:
patchelf() {
	:
}

# remove some un-buildable depends:
RDEPEND="${RDEPEND/sys-apps\/lsb-release/}"
BDEPEND="${BDEPEND/prefix? ( dev-util\/patchelf )/}"
