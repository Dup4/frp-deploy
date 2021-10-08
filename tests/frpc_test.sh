#! /usr/bin/env bash

TOP_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

"${TOP_DIR}/../install.sh" -i frpc -y

if [[ -z "$(which frpc)" ]]; then
	exit 1
fi

"${TOP_DIR}/../uninstall.sh" -i frpc -y

if [[ -z "$(which frpc)" ]]; then
	exit 1
fi

if [[ -d "/etc/frp" ]]; then
	exit 1
fi
