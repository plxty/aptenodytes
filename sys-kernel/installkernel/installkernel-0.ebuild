EAPI="9"

inherit dirty-deeds
eval "$(pkg_profile)"

KEYWORDS="amd64"
S="${T}"

src_install() {
	# real localmod?
	insinto /etc/kernel/config.d
	doins "${FILESDIR}/0000-localmod.config"

	# /usr/lib/kernel?
	insinto /etc/kernel
	echo "root=PARTUUID=$(findmnt / -o PARTUUID -n) rootflags=subvol=@gentoo rw" \
		>"${T}/cmdline"
	doins "${T}/cmdline"
}
