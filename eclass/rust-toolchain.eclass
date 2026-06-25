if [[ -z ${_RUST_TOOLCHAIN_ECLASS} ]]; then
	# overlay for adding darwin:
	inherit dirty-deeds
	eval "$(class_overlay)"

	# only rust-bin calls us, which is guarded by --arch
	rust_abi() {
		local CTARGET=${1:-${CHOST}}
		case ${CTARGET%%*-} in
		arm64-apple-darwin*) echo aarch64-apple-darwin ;;
		*) die "unsupported ${CTARGET}" ;;
		esac
	}

	# this removes many binaries that we don't need to download:
	rust_all_arch_uris() {
		echo "arm64-macos? ( $(rust_arch_uri aarch64-apple-darwin "${1}" "${2}") )"
	}

	_RUST_TOOLCHAIN_ECLASS=1
fi
