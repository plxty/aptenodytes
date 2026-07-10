EAPI="8"

# for escript:
inherit dirty-deeds systemd

# the systemd (and other packages) has been blocked by some deps, so a non-zero
# version here... maybe better way?
eval "$(pkg_profile)"

# TODO: virtual/resolver?
KEYWORDS="amd64"
IUSE="+resolved"
BDEPEND="dev-lang/python"
RDEPEND+=" !sys-apps/systemd-p"
S="${T}"

pkg_pretend() {
	if [[ "${IGLU_ID}" != *"."* ]]; then
		echo "profile should contain domain in IGLU_ID for DNS searching"
		die "set IGLU_ID=${IGLU_ID}.mshome.net if you're not sure, systemd does it"
	fi
}

src_prepare() {
	default

	# split it
	escript gen-network.py networkd networkd

	# make sysctl managed by systemd for now, FIXME: procps-p?
	escript gen-network.py sysctl sysctl

	if use resolved; then
		IGLU_DOMAIN="$(edomain)" envsubst <"${FILESDIR}/resolv.conf" >resolv.conf
	else
		echo "disable systemd-resolved.service" >91-systemd-resolved.preset
	fi
}

src_install() {
	# without /etc/machine-id bootctl will generate a "temporary" kernel,
	# prefixed by `gentoo-` (insteadof `<machine-id>-`), so the loader has a
	# wierd machine-id match to against the "gentoo", which isn't hex.
	insinto /efi/loader
	doins "${FILESDIR}/loader.conf"

	insinto /usr/lib/systemd/network
	doins networkd/*

	insinto /etc/sysctl.d
	if test -e sysctl/*; then
		doins sysctl/*
	fi

	if use resolved; then
		insinto /etc
		doins resolv.conf
	else
		insinto "$(systemd_get_systempresetdir)"
		doins 91-systemd-resolved.preset
	fi
}

pkg_postinst() {
	if ! bootctl is-installed --esp-path=/efi >/dev/null; then
		bootctl install --esp-path=/efi
	fi

	# we're following /efi hierarchy:
	if [[ -d /boot ]]; then
		rmdir /boot
	fi

	if ! use resolved && systemctl is-enabled systemd-resolved.service 2>/dev/null; then
		eqawarn '!resolved, you may need to do "systemctl disable --now systemd-resolved.service" manually'
	fi
}
