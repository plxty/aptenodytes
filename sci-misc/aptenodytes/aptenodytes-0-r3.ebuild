# https://projects.gentoo.org/pms/latest/pms.html
EAPI="8"
DESCRIPTION="noot-noot, this is a boot"
KEYWORDS="amd64 arm64-macos"
SLOT="0"

# eclasses, if any
# inherit ?

# package build
BDEPEND="!prefix? ( sys-fs/genfstab )"

# we need a clang for darwin platforms, in bootstrap stage:
# and ensures package patches, kernel configs, etc. etc. are ready
RDEPEND="
	sys-apps/portage:ridgeni
	arm64-macos? ( llvm-core/clang )
	!prefix? ( sys-kernel/installkernel:ridgeni )
"
S="${T}"

src_prepare() {
	default

	{
		echo "# sci-misc/aptenodytes"
		echo "LANG=zh_CN.UTF-8"
		echo "LANGUAGE=zh_CN:en_US"
	} >02locale

	if use prefix-guest; then
		return
	fi

	{
		echo "en_US.UTF-8 UTF-8"
		echo "en_US ISO-8859-1"
		echo "zh_CN.GB18030 GB18030"
		echo "zh_CN.GBK GBK"
		echo "zh_CN.UTF-8 UTF-8"
		echo "zh_CN GB2312"
	} >locale.gen

	if use prefix; then
		return
	fi

	echo "${IGLU_ID}" | awk -F. '{print $1}' >hostname
	genfstab -t PARTUUID / >fstab
}

src_install() {
	# eselect locale? darwin don't support it...
	insinto /etc/env.d
	doins 02locale

	# we use libiconv for non-glibc, so no need to proceed:
	if use prefix-guest; then
		return
	fi

	# /usr/share/i18n/SUPPORTED
	insinto /etc
	doins locale.gen
	dosym ../usr/share/zoneinfo/Asia/Shanghai /etc/localtime

	if use prefix; then
		return
	fi

	# non-prefix here:
	insinto /etc
	doins hostname fstab
}

pkg_preinst() {
	if use prefix; then # including prefix-guest
		return
	fi

	if [[ -L /etc/localtime && "$(realpath /etc/localtime)" == "/usr/share/zoneinfo/Factory" ]]; then
		unlink /etc/localtime
	fi
}

pkg_postinst() {
	if use prefix-guest; then
		return
	fi

	locale-gen

	if use prefix; then
		return
	fi

	# silence of mount:
	touch /run/systemd/systemd-units-load
}
