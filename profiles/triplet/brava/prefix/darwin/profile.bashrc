# https://stackoverflow.com/a/32425874
eval __"$(declare -f die)"

die() {
  # make 05prefix (portage/bin/install-qa-check.d) don't die,
  # we're taking the real world (absolute!)
  if [[ "${1}" == "Aborting due to QA concerns: there are files installed outside the prefix" ]]; then
    return
  fi
  __die "${@}"
}
