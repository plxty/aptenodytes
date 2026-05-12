EAPI="8"

inherit dirty-deeds
eval "$(pkg_overlay)"

# fixing x11 includes in darwin, we use librime's hardcoded:
PATCHES+=("${FILESDIR}/${PN}-x11-keysym.patch")

# adding more related dependencies...
eval __"$(declare -f src_prepare)"
src_prepare() {
  __src_prepare "${@}"
  {
    echo "include_directories(thirdparty/x11)"
    echo "target_link_libraries(lua glog opencc)"
  } >> CMakeLists.txt
}
