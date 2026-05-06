#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAKE_ARGS=(bootstrap)

while [[ $# -gt 0 ]]; do
	case "$1" in
		--no-upgrade)
			MAKE_ARGS+=(DO_UPGRADE=0)
			;;
		--skip-k3s)
			MAKE_ARGS+=(INSTALL_K3S=0)
			;;
		--skip-k9s)
			MAKE_ARGS+=(INSTALL_K9S=0)
			;;
		-h|--help)
			exec make -C "${ROOT_DIR}" help
			;;
		*)
			echo "unknown option: $1" >&2
			exit 1
			;;
	esac
	shift
done

exec make -C "${ROOT_DIR}" "${MAKE_ARGS[@]}"