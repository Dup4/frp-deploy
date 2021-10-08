#! /usr/bin/env bash

TOP_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

if [[ ! -f "${TOP_DIR}/../bach.sh" ]]; then
	wget https://raw.githubusercontent.com/bach-sh/bach/master/bach.sh -O "${TOP_DIR}/../bach.sh"
fi

# shellcheck disable=SC1091
source "${TOP_DIR}/../bach.sh"

@mock $EUID === "0"

test-frpc() {
	"${TOP_DIR}/../install.sh" -i frpc
	@assert-success

	"${TOP_DIR}/../uninstall.sh" -i frpc
	@assert-success
}

test-frps() {
	"${TOP_DIR}/../install.sh" -i frps
	@assert-success

	"${TOP_DIR}/../uninstall.sh" -i frps
	@assert-success
}
