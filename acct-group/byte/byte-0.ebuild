EAPI="8"
DESCRIPTION="byte the group"
KEYWORDS="amd64"
SLOT="0"

inherit acct-group
if use prefix; then
  ACCT_GROUP_ID="${PORTAGE_INST_GID}"
else
  ACCT_GROUP_ID="1000"
fi
ACCT_GROUP_ENFORCE_ID="true"
