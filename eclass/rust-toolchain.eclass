# gentoo/eclass/rust-toolchain.eclass
case ${EAPI} in
	8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ "${ARCH}" != "arm64-macos" ]]; then
  die "unsupported ${ARCH} for this dirty rust"
fi

if [[ -z ${_RUST_TOOLCHAIN_ECLASS} ]]; then
_RUST_TOOLCHAIN_ECLASS=1

: "${RUST_TOOLCHAIN_BASEURL:=https://static.rust-lang.org/dist/}"

rust_abi() {
  echo "aarch64-apple-darwin"
}

# totally copy, license?
rust_arch_uri() {
  if [ -n "$3" ]; then
    echo "${RUST_TOOLCHAIN_BASEURL}${2}-${1}.tar.xz -> ${3}-${1}.tar.xz"
    echo "verify-sig? ( ${RUST_TOOLCHAIN_BASEURL}${2}-${1}.tar.xz.asc -> ${3}-${1}.tar.xz.asc )"
  else
    echo "${RUST_TOOLCHAIN_BASEURL}${2}-${1}.tar.xz"
    echo "verify-sig? ( ${RUST_TOOLCHAIN_BASEURL}${2}-${1}.tar.xz.asc )"
  fi
}

rust_all_arch_uris() {
  rust_arch_uri aarch64-apple-darwin "${1}" "${2}"
}
fi
