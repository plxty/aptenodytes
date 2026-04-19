EAPI="9"
KEYWORDS="amd64"
RDEPEND="sys-apps/systemd"

DESCRIPTION="systemd profile"
SLOT="0"

S="${T}"

src_install() {
  insinto /efi/loader
  doins "${FILESDIR}/loader.conf"

  # split it
  insinto /usr/lib/systemd/network
  local prio=0
  for network in $IGLU_NETWORK; do
    export IFACE="${network%:*}"
    read -ra configs <<< "${network#*:}"
    for cfg in "${configs[@]}"; do
      target="${T}/$(printf %02d $prio)-${IFACE}.network"
      envsubst '${IFACE}' < "${FILESDIR}/${cfg}.network" > "${target}"
      doins "${target}"
      ((++prio))
    done
  done
}

post_install() {
  # /boot?
  bootctl install --esp-path=/efi
}
