EAPI="8"

inherit dirty-deeds
eval "$(pkg_overlay)"

if [[ "${ARCH}" == *"-macos" ]]; then
	# the src_prepare contains an outdated src path, we workaround it with a fake file:
	eval __"$(declare -f src_prepare)"
	src_prepare() {
		mkdir -p src/_cffi_src/openssl/src
		touch src/_cffi_src/openssl/src/osrandom_engine.c
		__src_prepare
	}
fi
