EAPI="9"
DESCRIPTION="byte the user"
KEYWORDS="amd64 arm64-macos"
SLOT="0"

# for prefix, this is just a placeholder, won't actually do the things
inherit acct-user
if prefix; then
  ACCT_USER_ID="${PORTAGE_INST_UID}"
  ACCT_USER_GROUPS=("${PORTAGE_GRPNAME}")
else
  ACCT_USER_ID="1000"
  ACCT_USER_SHELL="/usr/bin/bash"
  ACCT_USER_HOME="/home/byte"
  ACCT_USER_GROUPS=("byte" "wheel" "kvm")
fi
ACCT_USER_ENFORCE_ID="true"
ACCT_USER_HOME_PERMS="0750"
acct-user_add_deps
