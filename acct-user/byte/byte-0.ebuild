EAPI="9"
KEYWORDS="amd64"

DESCRIPTION="byte bye bye byte"
SLOT="0"

inherit acct-user

ACCT_USER_ID="1000"
ACCT_USER_ENFORCE_ID="true"
ACCT_USER_SHELL="/usr/bin/bash"
ACCT_USER_HOME="/home/byte"
ACCT_USER_HOME_PERMS="0750"
ACCT_USER_GROUPS=("byte" "wheel" "kvm")

acct-user_add_deps
