#! /bin/bash

# -----------------------------------------------------------------------------
#
# Copyright (c) 2016 Stuart Shelton.
# Copyright (c) 2016 Hewlett Packard Enterprise Co.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# -----------------------------------------------------------------------------

#
# Create a valid debian changelog from git history, noting commits and any tags
# which may exist.
#
# Version numbers start at '1' (or any provided argument) and increment from
# there for each commit.
#

set -u
set -o pipefail

declare debug="${DEBUG:-}"
declare trace="${TRACE:-}"

declare NAME="$( basename "$( readlink -e "${0}" )" )"
declare PKGNAME="${GITLOG2DCL_PKG_NAME:-}"
declare -A committags=()

function die() {
	echo >&2 "FATAL: ${*:-Unknown error}"
	exit 1
} # die

function processdata() {
	local -i num="${1:-1}" ; shift
	local stable="${1:-stable}" ; shift
	local commit="${1:-}" ; shift
	local author="${1:-}" ; shift
	local date="${1:-}" ; shift
	local -a message=( "${@:-}" )

	local line
	local -i rc=1 inserted=0

	# Presence of 'set -u' will cause block to fail if any variables are
	# unset...
	(
		local day month dom time year zone

		#echo "${PKGNAME} (__SEQ__${committags["${commit}"]:+-${committags["${commit}"]}}-${commit}) ${stable}; urgency=low"
		echo "${PKGNAME} (${num}) ${stable}; urgency=low"
		echo
		echo -n "  * commit ${commit}"
		[[ -n "${committags["${commit}"]:-}" ]] && echo -e ", tag '${committags["${commit}"]}'\n" || echo $'\n'
		for line in "${message[@]:-}"; do
			if [[ -n "${line// }" ]]; then
				echo "  * ${line:-}"
				inserted=1
			else
				echo
				inserted=0
			fi
		done
		(( inserted )) && echo

		day="$( cut -d' ' -f 1 <<<"${date}" )"
		month="$( cut -d' ' -f 2 <<<"${date}" )"
		dom="$( cut -d' ' -f 3 <<<"${date}" )"
		time="$( cut -d' ' -f 4 <<<"${date}" )"
		year="$( cut -d' ' -f 5 <<<"${date}" )"
		zone="$( cut -d' ' -f 6 <<<"${date}" )"
		(( ( ${#dom} - 1 ) )) || dom="0${dom}"
		echo " -- ${author}  ${day}, ${dom} ${month} ${year} ${time} ${zone}"
		echo

		true
	)
	rc=${?}

	# When piping the output to a utility which then closes the FD and
	# 'set -o pipefail' is in effect, we get SIGPIPE/rc=141 at this
	# point...
	(( 141 == rc )) && die "Received SIGPIPE"

	(( debug )) && echo >&2 "DEBUG: processdata() returns ${rc}"

	return ${rc}
} # processdata

function processlog() {
	local -i num=${1:-1}

	local tag value commit author date
	local -a message=()

	# We immediately start with a decrement...
	(( num++ ))

	while IFS= read -r line; do
		(( debug )) && echo >&2 "DEBUG: Read line '${line}'"
		case "${line:-}" in
			'commit '*)
				if [[ -n "${commit:-}" ]]; then
					(( debug )) && echo >&2 "DEBUG: Processing entry for commit '${commit}'"

					if ! processdata $(( num-- )) 'stable' "${commit:-}" "${author:-}" "${date:-}" "${message[@]:-}"; then
						echo >&2 "ERROR: Incomplete 'git log' entry or truncated input:"
						echo >&2
						echo >&2 $'\tCurrent state:'
						echo >&2 -e "\tcommit  ${commit:-}"
						echo >&2 -e "\tAuthor: ${author:-}"
						echo >&2 -e "\tDate:   ${date:-}"
						for line in "${message[@]}"; do
							echo >&2 -e "\tText:  '    ${line}'"
						done
						echo >&2
						die "Failed processing commit '${commit:-}'"
					else
						commit=''
						author=''
						date=''
						message=()
					fi
				fi

				value="${line#commit }"
				if [[ -n "${commit:-}" ]]; then
					die "LOGIC ERROR: 'commit' value \"${commit}\" to be overwritten with \"${value}\""
				fi
				commit="${value}"
				;;
			'Merge: '*)
				# FIXME: Ignored for now...
				:
				;;
			'Author: '*)
				value="${line#Author: }"
				if [[ -n "${author:-}" ]]; then
					die "LOGIC ERROR: 'author' value \"${author}\" to be overwritten with \"${value}\""
				fi
				author="${value}"
				;;
			'Date:   '*)
				value="${line#Date:   }"
				if [[ -n "${date:-}" ]]; then
					die "LOGIC ERROR: 'date' value \"${date}\" to be overwritten with \"${value}\""
				fi
				date="${value}"
				;;
			'    '*)
				value="${line#    }"
				message+=( "${value:-}" )
				;;
			'')
				# Blank line
				:
				;;
			*)
				echo >&2 "ERROR: Unknown 'git log' entry:"
				echo >&2 -e "\t'${line:-}'"
				echo >&2
				echo >&2 $'\tCurrent state:'
				echo >&2 -e "\tcommit  ${commit:-}"
				echo >&2 -e "\tAuthor: ${author:-}"
				echo >&2 -e "\tDate:   ${date:-}"
				for line in "${message[@]:-}"; do
					echo >&2 -e "\tText:  '    ${line}'"
				done
				echo >&2
				die "Invalid input"
				;;
		esac
	done < <( git log 2>&1 )

	if [[ -n "${commit:-}" ]]; then
		if ! processdata $(( num-- )) 'stable' "${commit:-}" "${author:-}" "${date:-}" "${message[@]:-}"; then
			echo >&2 "ERROR: Incomplete 'git log' entry:"
			echo >&2
			echo >&2 $'\tCurrent state:'
			echo >&2 -e "\tcommit  ${commit:-}"
			echo >&2 -e "\tAuthor: ${commit:-}"
			echo >&2 -e "\tDate:   ${commit:-}"
			for line in "${message[@]}"; do
				echo >&2 -e "\tText:  '    ${line}'"
			done
			echo >&2
			die "Failed processing commit '${commit:-}'"
		fi
	fi

} # processlog

function main() {
	#local -a args=( "${@:-}" )

	if [[ " ${*:-} " =~ \ -(h|-help)\  ]]; then
		echo "Usage: ${NAME} [initial-version]"
		exit 0
	fi

	git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
		die "${NAME} must be executed from within a git repo"

	[[ -z "${PKGNAME:-}" ]] && PKGNAME="$( git remote show origin -n | grep -o 'Fetch URL: .*$' | cut -d' ' -f 3- | xargs basename | sed 's/\.git$//' )"
	[[ -z "${PKGNAME:-}" ]] && die "Could not determine package name"

	local tag commit line
	local -i num=0
	[[ -n "${1:-}" && "${1}" =~ [0-9]+ ]] && num="${1}"

	(( trace )) && set -o xtrace

	echo >&2 "Generating changelog for pacakge '${PKGNAME}'..."

	if [[ -n "$( git tag )" ]]; then
		echo >&2 "Enumerating tags, please wait..."
	fi
	while read -r tag; do
		if commit="$( git rev-list -n 1 "${tag:-}" 2>/dev/null )"; then
			committags["${commit}"]="${tag}"
		fi
	done < <( git tag 2>&1 )
	echo >&2 "Processing logs, please wait..."

	(( num = ( ( $(
		git log 2>/dev/null | grep -c '^commit [0-9a-f]'
	) - 1 ) + num ) ))
	processlog ${num} | head -n -1

	(( trace )) && set +o xtrace

	return 0
} # main

main "${@:-}"

exit ${?}

# vi: set syntax=sh:
