EAPI="8"
DESCRIPTION="portage profile"
KEYWORDS="amd64 arm64-macos"
SLOT="0"

inherit dirty-deeds

RDEPEND="
  sys-apps/portage
  dev-vcs/git
  app-portage/gemato
"
S="${T}"

# @see https://github.com/gentoo/portage/tree/prefix
# @see https://github.com/gentoo/prefix/tree/master/scripts/rsync-generation
if guse prefix-guest; then
	REPOS_GENTOO="gentoo_prefix"
else
	REPOS_GENTOO="gentoo"
fi

src_prepare() {
	default

	envsubst <"${FILESDIR}/${REPOS_GENTOO}.conf" >${REPOS_GENTOO}.conf
	envsubst <"${FILESDIR}/aptenodytes.conf" >aptenodytes.conf
	if [[ "${GENTOO_BINHOST:-}" != "" ]]; then
		# to use gentoo.conf to override the system preset:
		envsubst <"${FILESDIR}/gentoobinhost.conf" >gentoobinhost.conf
	fi
}

src_install() {
	keepdir /etc/portage/make.conf

	# /usr/share/portage/config/repos.conf?
	insinto /etc/portage/repos.conf
	doins "${REPOS_GENTOO}.conf" aptenodytes.conf

	if [[ -e gentoobinhost.conf ]]; then
		insinto /etc/portage/binrepos.conf
		newins gentoobinhost.conf gentoo.conf
	fi
}

pkg_preinst() {
	# suppress warnings
	if [[ -f "${EPREFIX}/etc/portage/make.conf" ]]; then
		rm -v "${EPREFIX}/etc/portage/make.conf"
	fi
}
