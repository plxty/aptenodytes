EAPI="8"
DESCRIPTION="staff the group"
KEYWORDS="arm64-macos"
SLOT="0"

inherit acct-group
ACCT_GROUP_ID="20"

pkg_pretend() {
	if use !prefix-guest; then
		die "it ain't real"
	fi
}
