EAPI="9"

inherit dirty-deeds
eval "$(pkg_profile)"

KEYWORDS="amd64"
RDEPEND+=" !sys-kernel/installkernel-p"
S="${T}"

src_prepare() {
	default

	echo "root=PARTUUID=$(findmnt / -o PARTUUID -n) rootflags=subvol=@gentoo rw" \
		>cmdline
}

src_install() {
	# real localmod?
	insinto /etc/kernel/config.d
	doins "${FILESDIR}/0000-localmod.config"

	# /usr/lib/kernel?
	insinto /etc/kernel
	doins cmdline
}
