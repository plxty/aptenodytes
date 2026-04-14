EAPI="9"
KEYWORDS="amd64"
RDEPEND="
  sys-apps/portage
  dev-vcs/git
"

DESCRIPTION="self-play with portage"
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
}

pkg_preinst() {
  # suppress warnings
  if [[ -f /etc/portage/make.conf ]]; then
    rm -v /etc/portage/make.conf
  fi

  if grep -q catalyst /etc/portage/binrepos.conf/gentoobinhost.conf; then
    rm -v /etc/portage/binrepos.conf/gentoobinhost.conf
  fi

  # maybe useless?
  if ! grep -q aptenodytes /etc/portage/repos.conf/gentoo.conf; then
    rm -v /etc/portage/repos.conf/gentoo.conf
  fi

  # stage-0 cleanup
  if [[ -f /etc/portage/repos.conf/aptenodytes.conf ]]; then
    rm -v /etc/portage/repos.conf/aptenodytes.conf
  fi
}
