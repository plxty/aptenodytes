EAPI="8"

inherit dirty-deeds
eval "$(pkg_overlay)"

if [[ "${ARCH}" == *"-macos" ]]; then
  # @see dev-libs/gnulib/gnulib-2026.01.14.22.26.00.ebuild
  GNULIB_GIT_TAG="2a288c048e2a23ea9cd8cbef9a60aa4ac82bdc3d"

  # fix utf-8-mac:
  SRC_URI="
    https://github.com/fumiyas/libiconv-utf8mac/archive/refs/heads/utf-8-mac-51.200.6.libiconv-${PV}.zip
    https://codeberg.org/gnulib/gnulib/archive/${GNULIB_GIT_TAG}.tar.gz -> gnulib-${GNULIB_GIT_TAG}.tar.gz
  "
  S="${WORKDIR}/libiconv-utf8mac-utf-8-mac-51.200.6.libiconv-${PV}"

  src_prepare() {
    default
  
    # workaround...
    echo > gitsub.sh
    ln -s "${WORKDIR}/gnulib" gnulib

    # no hardcode...
    sed -i -e '/SHELL/d' \
      -e 's/automake-1.17/automake/' \
      -e 's/aclocal-1.17/aclocal/' \
      Makefile.devel
    make -f Makefile.utf8mac autogen
  }
fi
