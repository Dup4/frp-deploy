#! /usr/bin/env bash

TOP_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

"${TOP_DIR}/../install.sh" -i frps

"${TOP_DIR}/../uninstall.sh" -i frps
