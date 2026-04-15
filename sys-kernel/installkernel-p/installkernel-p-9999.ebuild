EAPI="9"
KEYWORDS="amd64"
RDEPEND="sys-kernel/installkernel"

DESCRIPTION="self-play with installkernel (plus bootloader)"
SLOT="0"

inherit git-r3

EGIT_REPO_URI="https://codeberg.org/ranguli/gentoo-popcorn-kernel.git"
EGIT_BRANCH="main"

src_install() {
  insinto /etc/kernel/install.d
  doins "${FILESDIR}/uki.conf"

  insinto /etc/kernel/config.d
  doins "${FILESDIR}/0000-localmod.config"

  for snippet in 0001-no-parallel-port \
    0004-no-android \
    0005-no-firewire \
    0008-no-fujitsu \
    0009-no-nvidia-gpu \
    0010-no-xen \
    0011-no-pci-sound-devices \
    0012-no-amateur-radio \
    0014-no-vmware \
    0015-no-nfc \
    0016-no-old-partition-types \
    0017-no-pci-media \
    0018-no-toshiba-hardware \
    0020-no-acer \
    0022-no-samsung \
    0023-no-canbus \
    0024-no-afs-rxrpc \
    0025-no-ceph \
    0027-no-coda \
    0029-no-jfs \
    0030-no-reiserfs \
    0031-no-gfs \
    0032-no-ocfs2 \
    0034-no-f2fs \
    0035-no-nilfs2 \
    0036-no-zonefs \
    0042-no-infiniband \
    0048-no-intersil-wlan \
    0051-no-ralink-wlan \
    0052-no-microchip-wlan \
    0053-no-quantenna-wlan \
    0054-no-redpine-wlan \
    0057-no-zydas-wlan \
    0060-no-realtek-wlan \
    0061-no-gnss-gps \
    0062-no-apple-hardware \
    0063-no-gameport \
    0067-no-chrome-hardware \
    0068-no-old-odd-joysticks \
    0073-no-lenovo-yoga \
    0074-no-lg-laptop \
    0078-no-microsoft-surface \
    0084-only-sata-ahci \
    0086-no-huawei \
    0088-native-cpu
  do
    doins "${S}/${snippet}/etc/kernel/config.d/${snippet}.config"
  done

  # into profile?
  if [[ -f "${FILESDIR}/0000-${IGLU_ID}.config" ]]; then
    doins "${FILESDIR}/0000-${IGLU_ID}.config"
  fi

  insinto /etc/kernel
  echo "root=UUID=$(findmnt / -o UUID -n) rootflags=subvol=@gentoo" > "${T}/cmdline"
  doins "${T}/cmdline"
}

post_install() {
  # fstab? sys-apps/systemd-p?
  bootctl install --esp-path=/efi
}
