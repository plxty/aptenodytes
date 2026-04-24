EAPI="8"
DESCRIPTION="portage profile"
KEYWORDS="amd64 arm64-macos"
SLOT="0"

RDEPEND="
  sys-apps/portage
  app-portage/getuto
  dev-vcs/git
"
S="${T}"

src_install() {
  # mostly portage things
  keepdir /etc/portage/make.conf

  # make fallbacks?
  insinto /etc/portage/binrepos.conf
  envsubst '${GENTOO_BINHOST}' < "${FILESDIR}/gentoobinhost.conf" > "${T}/gentoobinhost.conf"
  doins "${T}/gentoobinhost.conf"

  # /usr/share/portage/config/repos.conf?
  insinto /etc/portage/repos.conf
  local repos_gentoo="gentoo"
  if use prefix-guest; then
    # https://github.com/gentoo/prefix/tree/master/scripts/rsync-generation
    repos_gentoo="gentoo_prefix"
  fi
  envsubst '${EPREFIX}' < "${FILESDIR}/${repos_gentoo}.conf" > "${T}/${repos_gentoo}.conf"
  envsubst '${EPREFIX}' < "${FILESDIR}/aptenodytes.conf" > "${T}/aptenodytes.conf"
  doins "${T}/${repos_gentoo}.conf" "${T}/aptenodytes.conf"

  # organize?
  insinto /etc/portage/patches/app-editors/helix
  doins "${FILESDIR}/0000-helix.patch"

  if use prefix; then
    insinto /etc/portage/patches/app-portage/getuto
    doins "${FILESDIR}/0000-getuto-prefix.patch"
  fi

  if use prefix-guest; then
    insinto /etc/portage/patches/sys-apps/portage
    doins "${FILESDIR}/0000-portage-prefix.patch"

    insinto /etc/portage/patches/net-libs/nodejs
    doins "${FILESDIR}/0000-nodejs-darwin.patch"
  fi
}

pkg_preinst() {
  # suppress warnings
  if [[ -f /etc/portage/make.conf ]]; then
    rm -v /etc/portage/make.conf
  fi
}
