EAPI="9"
DESCRIPTION="systemd profile"
KEYWORDS="amd64"
SLOT="0"

RDEPEND="sys-apps/systemd"
S="${T}"

src_install() {
  # without /etc/machine-id bootctl will generate a "temporary" kernel,
  # prefixed by `gentoo-` (insteadof `<machine-id>-`), so the loader has a
  # wierd machine-id match to against the "gentoo", which isn't hex.
  insinto /efi/loader
  doins "${FILESDIR}/loader.conf"

  # split it
  insinto /usr/lib/systemd/network
  local prio=0
  for network in $IGLU_NETWORK; do
    export IFACE="${network%:*}"
    read -ra configs <<< "${network#*:}"
    for cfg in "${configs[@]}"; do
      local target="${T}/$(printf %02d $prio)-${IFACE}.network"
      envsubst '${IFACE}' < "${FILESDIR}/${cfg}.network" > "${target}"
      doins "${target}"
      ((++prio))
    done
  done
}

pkg_postinst() {
  bootctl install --esp-path=/efi
  if [[ -d /boot ]]; then
    rmdir /boot
  fi
}
