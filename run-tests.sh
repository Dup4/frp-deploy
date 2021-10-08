#! /usr/bin/env bash
set -ue
[ -z "${DEBUG:-}" ] || set -x

TOP_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

function get_now_time() {
	if [[ "$(uname)" == "Darwin" ]]; then
		NOW_TIME=$(date)
	else
		# https://unix.stackexchange.com/questions/120484/what-is-a-standard-command-for-printing-a-date-in-rfc-3339-format
		NOW_TIME=$(date --rfc-3339=ns | sed 's/ /T/; s/\(\....\).*\([+-]\)/\1\2/g')
	fi

	echo "${NOW_TIME}"
}

function INFO() {
	echo -e "\033[0;32m$(get_now_time) [INFO]: $*\033[0m"
}

function ERROR() {
	echo -e "\033[0;31m$(get_now_time) [ERROR]: $*\033[0m"
}

unset BACH_ASSERT_DIFF BACH_ASSERT_DIFF_OPTS
PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin

OS_NAME="$(uname)"
if [ -e /etc/os-release ]; then
	# shellcheck disable=SC1091
	. /etc/os-release

	OS_NAME="${OS_NAME}-${ID}-${VERSION_ID}"
fi

case "$OS_NAME" in
Darwin)
	if ! brew list --full-name --versions bash &>/dev/null; then
		brew install bash
	fi
	bash_bin="$(brew --prefix)"/bin/bash
	;;
FreeBSD)
	export PATH="/usr/local/sbin:$PATH"
	export ASSUME_ALWAYS_YES=yes
	pkg_install_pkgs="pkg -vv; pkg update -f; pkg install -y bash vim" # vim provides xxd command
	if ! hash bash || ! hash xxd; then
		if [ "$(id -u)" -gt 0 ] && hash sudo; then
			sudo /bin/sh -c "$pkg_install_pkgs"
		else
			/bin/sh -c "$pkg_install_pkgs"
		fi
	fi
	;;
Linux-alpine-*)
	apk update
	hash bash &>/dev/null || apk add bash
	apk add coreutils diffutils
	apk add xxd # for running `@real xxd` in ./tests/demo-xxd.test.sh
	;;
esac

if [ -z "${bash_bin:-}" ]; then
	bash_bin="$(which bash)"
fi

uname -a
INFO "Bash: $bash_bin"
test -n "$bash_bin"
"$bash_bin" --version

set +e
retval=0

cd "${TOP_DIR}" || exit 1

for file in tests/*_test.sh; do
	INFO "Running $file"

	if grep -E "^[[:blank:]]*BACH_TESTS=.+" "$file"; then
		ERROR "Found defination of BACH_TESTS in $file"
		retval=1
	fi

	if [[ "$file" = */failed-* ]]; then
		! "$bash_bin" -euo pipefail "$file"
	else
		"$bash_bin" -euo pipefail "$file"
	fi || retval=1
done

if [ "$retval" -ne 0 ]; then
	ERROR "Test failed!"
fi

exit "$retval"
