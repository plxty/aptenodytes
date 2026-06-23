EAPI="9"
DESCRIPTION="systemd profile"
KEYWORDS="amd64"
SLOT="0"

BDEPEND="dev-lang/python"
RDEPEND="sys-apps/systemd"
S="${T}"

# for escript:
inherit dirty-deeds

pkg_pretend() {
	if [[ "${IGLU_ID}" != *"."* ]]; then
		echo "profile should contain domain in IGLU_ID for DNS searching"
		die "set IGLU_ID=${IGLU_ID}.mshome.net if you're not sure, systemd does it"
	fi
}

src_install() {
	# without /etc/machine-id bootctl will generate a "temporary" kernel,
	# prefixed by `gentoo-` (insteadof `<machine-id>-`), so the loader has a
	# wierd machine-id match to against the "gentoo", which isn't hex.
	insinto /efi/loader
	doins "${FILESDIR}/loader.conf"

	# split it
	insinto /usr/lib/systemd/network
	escript gen-network.py networkd networkd
	doins networkd/*

	# make sysctl managed by systemd for now, FIXME: procps-p?
	insinto /etc/sysctl.d
	escript gen-network.py sysctl sysctl
	if test -e sysctl/*; then
		doins sysctl/*
	fi

	insinto /etc
	IGLU_DOMAIN="$(echo "${IGLU_ID}" | awk -F. -v OFS=. '{$1=""; print substr($0,2)}')" \
		envsubst '${IGLU_DOMAIN}' <"${FILESDIR}/resolv.conf" >"${T}/resolv.conf"
	doins "${T}/resolv.conf"
}

pkg_preinst() {
	if grep -q Generated /etc/resolv.conf; then
		rm -v /etc/resolv.conf
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
}
