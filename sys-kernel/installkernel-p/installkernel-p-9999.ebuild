EAPI="9"
KEYWORDS="amd64"
RDEPEND="sys-kernel/installkernel"
IUSE="hyper-v"

DESCRIPTION="installkernel profile"
SLOT="0"

src_install() {
  insinto /etc/kernel/install.d
  doins "${FILESDIR}/uki.conf"

  # real localmod?
  insinto /etc/kernel/config.d
  doins "${FILESDIR}/0000-localmod.config"
  if use hyper-v; then
    doins "${FILESDIR}/0000-hyper-v.config"
  fi

  insinto /etc/kernel
  echo "root=PARTUUID=$(findmnt / -o PARTUUID -n) rootflags=subvol=@gentoo" > "${T}/cmdline"
  doins "${T}/cmdline"
}
