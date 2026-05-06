SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

BASE_PACKAGES := build-essential cmake git vim curl wget unzip ca-certificates gnupg
KUBECONFIG_SOURCE := /etc/rancher/k3s/k3s.yaml
KUBECONFIG_DEST := $(HOME)/.kube/config
DO_UPGRADE ?= 1
INSTALL_K3S ?= 1
INSTALL_K9S ?= 1

.PHONY: help bootstrap prerequisites base-packages kubectl helm k3s kubeconfig k9s verify

help:
	@printf '%s\n' \
		'Usage:' \
		'  make bootstrap' \
		'  make bootstrap DO_UPGRADE=0 INSTALL_K3S=0 INSTALL_K9S=0' \
		'  make help' \
		'' \
		'Targets:' \
		'  bootstrap      Run the full local setup flow' \
		'  prerequisites  Install base apt packages' \
		'  kubectl        Install kubectl if missing' \
		'  helm           Install helm if missing' \
		'  k3s            Install k3s if missing' \
		'  kubeconfig     Copy the k3s kubeconfig into ~/.kube/config' \
		'  k9s            Install k9s if missing' \
		'  verify         Show cluster status through kubectl'

bootstrap: prerequisites kubectl helm
	if [[ "$(INSTALL_K3S)" == "1" ]]; then
		$(MAKE) k3s kubeconfig
	fi
	if [[ "$(INSTALL_K9S)" == "1" ]]; then
		$(MAKE) k9s
	fi
	$(MAKE) verify
	@echo "bootstrap complete"

prerequisites: base-packages

base-packages:
	if ! command -v apt-get >/dev/null 2>&1; then
		echo "apt-get is required for this setup" >&2
		exit 1
	fi
	sudo -v
	sudo apt-get update -y
	if [[ "$(DO_UPGRADE)" == "1" ]]; then
		sudo apt-get upgrade -y
	fi
	sudo apt-get install -y $(BASE_PACKAGES)

kubectl:
	if command -v kubectl >/dev/null 2>&1; then
		echo "kubectl already installed"
		exit 0
	fi
	version="$$(curl -L -s https://dl.k8s.io/release/stable.txt)"
	url="https://dl.k8s.io/release/$${version}/bin/linux/amd64/kubectl"
	tmpdir="$$(mktemp -d)"
	curl -L -o "$${tmpdir}/kubectl" "$${url}"
	curl -L -o "$${tmpdir}/kubectl.sha256" "$${url}.sha256"
	checksum="$$(tr -d '[:space:]' < "$${tmpdir}/kubectl.sha256")"
	echo "$${checksum}  $${tmpdir}/kubectl" | sha256sum --check --status
	sudo install -o root -g root -m 0755 "$${tmpdir}/kubectl" /usr/local/bin/kubectl
	rm -rf "$${tmpdir}"

helm:
	if command -v helm >/dev/null 2>&1; then
		echo "helm already installed"
		exit 0
	fi
	curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

k3s:
	if command -v k3s >/dev/null 2>&1; then
		echo "k3s already installed"
		exit 0
	fi
	curl -sfL https://get.k3s.io | sh -

kubeconfig:
	for _ in {1..30}; do
		if [[ -f "$(KUBECONFIG_SOURCE)" ]]; then
			break
		fi
		sleep 2
	done
	if [[ ! -f "$(KUBECONFIG_SOURCE)" ]]; then
		echo "k3s kubeconfig not found at $(KUBECONFIG_SOURCE)" >&2
		exit 1
	fi
	mkdir -p "$(HOME)/.kube"
	sudo cp "$(KUBECONFIG_SOURCE)" "$(KUBECONFIG_DEST)"
	sudo chown "$$(id -u):$$(id -g)" "$(KUBECONFIG_DEST)"
	chmod 600 "$(KUBECONFIG_DEST)"

k9s:
	if command -v k9s >/dev/null 2>&1; then
		echo "k9s already installed"
		exit 0
	fi
	curl -sS https://webi.sh/k9s | sh
	if [[ -f "$${HOME}/.config/envman/PATH.env" ]]; then
		# shellcheck disable=SC1090
		source "$${HOME}/.config/envman/PATH.env"
	fi

verify:
	if command -v kubectl >/dev/null 2>&1; then
		export KUBECONFIG="$(KUBECONFIG_DEST)"
		kubectl get nodes || true
	fi