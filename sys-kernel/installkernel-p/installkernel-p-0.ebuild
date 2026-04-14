EAPI="9"
KEYWORDS="amd64"
RDEPEND="sys-kernel/installkernel"

DESCRIPTION="self-play with installkernel"
SLOT="0"

S="${T}"

src_install() {
  insinto /etc/kernel/install.d
  doins "${FILESDIR}/uki.conf"

  insinto /etc/kernel/config.d
  doins "${FILESDIR}/localmod.config"

  insinto /etc/kernel
  local root_uuid="$(findmnt / -o UUID -n)"
  echo "root=UUID=${root_uuid} rootflags=subvol=@gentoo" > "${T}/cmdline"
  doins "${T}/cmdline"
}
