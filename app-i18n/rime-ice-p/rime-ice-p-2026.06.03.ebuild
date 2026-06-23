EAPI="8"
DESCRIPTION="rime-ice profile"
KEYWORDS="arm64-macos amd64"
SLOT="0"

AP="${P/-p/}"
APN="${PN/-p/}"
SRC_URI="https://github.com/iDvel/rime-ice/releases/download/${PV}/full.zip -> ${AP}.zip"
PATCHES=("${FILESDIR}/${APN}-double-pinyin-abc.patch")

inherit dirty-deeds

# FIXME: many lua scripts failed, many newer lua version is needed?
IUSE="iglu_lives_byte"
RDEPEND="
  app-i18n/librime
  app-i18n/librime-lua
  iglu_lives_byte? ( acct-user/byte )
"
S="${WORKDIR}"

src_prepare() {
	default

	# don't touch installation and user:
	rm -v {installation,user}.yaml
}

src_install() {
	# other platforms?
	userinsinto "Library/Rime"

	# rime_deployer?
	userdoins -r cn_dicts en_dicts lua opencc
	userdoins ./*.yaml ./*.txt
}
