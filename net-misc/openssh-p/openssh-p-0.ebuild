EAPI="9"
KEYWORDS="amd64"
RDEPEND="net-misc/openssh" # virtual?
IUSE="server"

DESCRIPTION="openssh profile"
SLOT="0"

inherit systemd

S="${T}"

src_install() {
  # firewall? port?
  insinto "$(systemd_get_systempresetdir)"
  echo "enable sshd.service" > "${T}/00-sshd.preset"
  doins "${T}/00-sshd.preset"
  systemd_enable_service multi-user.target sshd.service
}
