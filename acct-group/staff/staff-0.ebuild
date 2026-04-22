EAPI="8"
DESCRIPTION="staff the group"
KEYWORDS="arm64-macos"
SLOT="0"

if use !prefix-guest; then
  die "it ain't real"
fi

inherit acct-group
ACCT_GROUP_ID="${PORTAGE_INST_GID}"
ACCT_GROUP_ENFORCE_ID="true"
