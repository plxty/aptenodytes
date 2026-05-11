#!/usr/bin/env bash

set -ue

if [[ "$(id -u)" != "0" ]]; then
  echo "run me with sudo"
  exit 0
fi

eval "$(emerge --info | grep PORTAGE_CONFIGROOT)"
EPREFIX="${PORTAGE_CONFIGROOT}"

# sync librime libraries to system squirrel, to librime-p?
cp -v {"${EPREFIX}/usr/lib","/Library/Input Methods/Squirrel.app/Contents/Frameworks"}/librime.1.dylib
rm -v "/Library/Input Methods/Squirrel.app/Contents/Frameworks/rime-plugins/"*
for plugin in "${EPREFIX}/usr/lib/rime-plugins/"*; do
  plugin_name="$(basename "${plugin}")"
  plugin_name="${plugin_name/.bundle/}"
  cp -v "${plugin}" "/Library/Input Methods/Squirrel.app/Contents/Frameworks/rime-plugins/librime-${plugin_name}.dylib"
done
cp -v {"${EPREFIX}/usr/bin","/Library/Input Methods/Squirrel.app/Contents/MacOS"}/rime_deployer
cp -v {"${EPREFIX}/usr/bin","/Library/Input Methods/Squirrel.app/Contents/MacOS"}/rime_dict_manager
