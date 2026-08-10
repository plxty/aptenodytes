if [[ -z ${_DIRTY_DEEDS_ECLASS:-} ]]; then
	case "${EAPI}" in
	"7" | "8" | "9") ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
	esac

	guse() {
		# use in global-scope...
		for flag in $USE; do
			if [[ "${1}" == "${flag}" ]]; then
				return 0
			fi
		done
		# the USE is deduced from profile, not packages, so safe:
		return 1
	}

	pkg_profile() {
		local single=false
		while [[ "${1:-}" != "" ]]; do
			case "${1}" in
			"--single")
				# means the package isn't relies on other...
				single=true
				shift 1
				;;
			esac
		done

		echo 'SLOT="ridgeni"'
		echo DESCRIPTION="${CATEGORY}/${PN}:${SLOT}"
		if ! "${single}"; then
			echo "RDEPEND+=' >${CATEGORY}/${P}'"
		fi
	}

	escript() {
		local script_dir="${PORTAGE_CONFIGROOT}/var/db/repos/aptenodytes/scripts"
		local exe="${1}"
		shift 1

		"${script_dir}/${exe}" "${@}" || die
	}

	edomain() {
		echo "${IGLU_ID}" | awk -F. -v OFS=. '{$1=""; print substr($0,2)}'
	}

	userinsinto() {
		export __E_USERINSDESTTREE="${1}"
	}

	userdoins() {
		local users=()
		for flag in $USE; do
			if [[ "${flag}" != "iglu_lives_"* ]]; then
				continue
			fi

			local username="${flag#iglu_lives_}"
			local groupname="${username}" homedest=

			# for prefix, ensures "${EPREFIX}/home" exists:
			if use prefix; then
				username="${PORTAGE_USERNAME}"
				groupname="${PORTAGE_GRPNAME}"
				homedest="/home"
				if [[ ! -e "${EPREFIX}${homedest}" ]]; then
					die "please symlink the ${EPREFIX}${homedest} directory to your home"
				fi
			else
				homedest="$(getent passwd "${username}" | cut -d: -f6)"
			fi

			users+=("${username}"$'\n'"${groupname}"$'\n'"${homedest}")
		done

		for user in "${users[@]}"; do
			IFS=$'\n' read -d'' -r username groupname homedest <<<"$user"
			local target="${homedest}/${__E_USERINSDESTTREE}"

			# dodir first to try to fix the intermediat directories permissions...
			diropts --owner "${username}" --group "${groupname}"
			dodir "$(dirname "${target}")"
			insopts --owner "${username}" --group "${groupname}"
			insinto "${target}"
			doins "${@}"

			diropts
			insopts
		done
	}

	# copy of systemd_enable_service, add ability with template:
	systemd_enable_service_template() {
		debug-print-function ${FUNCNAME} "$@"

		[[ ${#} -eq 3 ]] || die "Synopsis: systemd_enable_service_template target service template"

		local target=${1}
		local service=${2}
		local template=${3}
		local ud=$(_systemd_unprefix systemd_get_systemunitdir)
		local destname=${service##*/}

		dodir "${ud}"/"${target}".wants &&
			dosym ../"${template}" "${ud}"/"${target}".wants/"${destname}"
	}

	dirty-deeds_src_prepare() {
		# prepare the overrided files:
		if [[ ! -e "${FILESDIR}.override" ]]; then
			ln -s "$(realpath "${FILESDIR}" || die).override" "${FILESDIR}.override"
		fi
	}

	_DIRTY_DEEDS_ECLASS=1
fi

# MUST outisde:
EXPORT_FUNCTIONS src_prepare
