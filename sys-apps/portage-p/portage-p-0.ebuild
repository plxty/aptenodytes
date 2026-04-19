EAPI="9"
KEYWORDS="amd64"
RDEPEND="
  sys-apps/portage
  dev-vcs/git
"

DESCRIPTION="portage profile"
SLOT="0"

# source-less
S="${T}"

src_install() {
  # mostly portage things
  keepdir /etc/portage/make.conf

  # make fallbacks?
  insinto /etc/portage/binrepos.conf
  envsubst '${GENTOO_BINHOST}' < "${FILESDIR}/gentoobinhost.conf" > "${T}/gentoobinhost.conf"
  doins "${T}/gentoobinhost.conf"

  insinto /etc/portage/repos.conf
  doins "${FILESDIR}/gentoo.conf"

  # organize?
  insinto /etc/portage/patches/app-editors/helix
  doins "${FILESDIR}/0000-helix.patch"
}

pkg_preinst() {
  # suppress warnings
  if [[ -f /etc/portage/make.conf ]]; then
    rm -v /etc/portage/make.conf
  fi
}
