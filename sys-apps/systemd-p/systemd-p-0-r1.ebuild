EAPI="9"
DESCRIPTION="systemd profile"
KEYWORDS="amd64"
SLOT="0"

RDEPEND="sys-apps/systemd"
S="${T}"

pkg_pretend() {
  if [[ "${IGLU_DOMAIN}" == "" ]]; then
    echo "profile should contain IGLU_DOMAIN for DNS searching"
    die "set to mshome.net if you're not sure, as what systemd does"
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

  insinto /etc
  envsubst '${IGLU_DOMAIN}' < "${FILESDIR}/resolv.conf" > "${T}/resolv.conf"
  doins "${T}/resolv.conf"
}

pkg_preinst() {
  if grep -q Generated /etc/resolv.conf; then
    rm -v /etc/resolv.conf
  fi
}

pkg_postinst() {
  if ! bootctl is-installed --esp-path=/efi > /dev/null; then
    bootctl install --esp-path=/efi
  fi

  # we're following /efi hierarchy:
  if [[ -d /boot ]]; then
    rmdir /boot
  fi
}
