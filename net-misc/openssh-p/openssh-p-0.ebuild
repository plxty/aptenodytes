EAPI="8" # systemd.eclass requires...
DESCRIPTION="openssh profile"
KEYWORDS="amd64"
SLOT="0"

inherit systemd

RDEPEND="net-misc/openssh" # virtual?
IUSE="server"
S="${T}"

src_install() {
  # firewall? port?
  insinto "$(systemd_get_systempresetdir)"
  echo "enable sshd.service" > "${T}/00-sshd.preset"
  doins "${T}/00-sshd.preset"
  systemd_enable_service multi-user.target sshd.service
}
