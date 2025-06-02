#!/bin/bash

# Copyright Red Hat
# SPDX-License-Identifier: Apache-2.0

# This script contains methods to check and install required tools.

source ./scripts/common.sh

# Usage information about the script
help() {
  bold "\nUsage: tools.sh [options] <yq=VERSION> | <opm=VERSION> | <kustomize=VERSION>  \n"
  echo -e '\nExample: tools.sh -p "bin" kustomize=5.6.0 opm=1.53.0'
  echo -e '
    -h \tDisplays this help.
    -p \tPath to install binary in.
  '
}

# Install kustomize
install_kustomize() {
  local version=$1 os=$2 arch=$3 path=$4
  local installed_version
  if test -s "$path/kustomize"; then
    installed_version=$(kustomize version | tr -d 'v')
    if test "$installed_version" != "$version"; then
      message "Removing kustomize version: $installed_version"
      rm "$path/kustomize"
    fi
  fi
  if ! test -s "$path/kustomize"; then
    process "Downloading kustomize version: $version"
    # TODO: Add multi OS and multi arch download support
    curl -sSfL "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | \
      bash -s -- "$version" "$path" >/dev/null 2>&1
    installed_version=$(kustomize version | tr -d 'v')
    clear
  fi
  success "Installed kustomize version: $installed_version"
}

# Install opm
install_opm() {
  local version=$1 os=$2 arch=$3 path=$4
  local installed_version
  if test -s "$path/opm"; then
    installed_version=$(opm version | awk -F "OpmVersion:" '{split($2,a,","); print a[1]}' | tr -d '"v')
    if test "$installed_version" != "$version"; then
      message "Removing opm version: $installed_version"
      rm "$path/opm"
    fi
  fi
  if ! test -s "$path/opm"; then
    process "Downloading opm version: $version"
    curl -sSfLo "$path/opm" "https://github.com/operator-framework/operator-registry/releases/download/v${version}/${os}-${arch}-opm"
    chmod +x "$path/opm"
    installed_version=$(opm version | awk -F "OpmVersion:" '{split($2,a,","); print a[1]}' | tr -d '"v')
    clear
  fi
  success "Installed opm version: $installed_version"
}

# Install yq
install_yq() {
  local version=$1 os=$2 arch=$3 path=$4
  local installed_version
  if test -s "$path/yq"; then
    installed_version=$(yq -V | awk -F "version" '{split($2,a," "); print a[1]}' | tr -d "v")
    if test "$installed_version" != "$version"; then
      message "Removing yq version: $installed_version"
      rm "$path/yq"
    fi
  fi
  if ! test -s "$path/yq"; then
    process "Downloading yq version: $version"
    curl -sSfLo "$path/yq" "https://github.com/mikefarah/yq/releases/download/v${version}/yq_${os}_${arch}"
    chmod +x "$path/yq"
    installed_version=$(yq -V | awk -F "version" '{split($2,a," "); print a[1]}' | tr -d "v")
    clear
  fi
  success "Installed yq version: $installed_version"
}

# Install binaries
install() {
  local version path os arch binary option argument

  # Being binaries, they're OS and Arch specific
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/amd64/')"

  # Parse arguments
  while getopts ":p:h" option; do
    case "${option}" in
      p) path="$OPTARG" ;;
      h) help; exit 0 ;;
      \?) echo; error "Invalid option: -$OPTARG" >&2; help; exit 2 ;;
      :) echo; error "Option -$OPTARG requires an argument." >&2; help; exit 2 ;;
    esac
  done
  shift $((OPTIND - 1))

  [[ $# -eq 0 || "$1" == "help" ]] && help && exit 0;

  # Install in 'bin' if no path is provided
  [[ -z ${path:-} ]] && path="bin"
  mkdir -p "$path"
  add_path "$path"

  # Install binaries
  header "Installing binaries"

  # Print OS and ARCH
    bold "System:\t\t$os \nArchitecture:\t$arch\n"
    seperator "-" 80

  for argument in "$@"; do
    binary=${argument%"="*}
    version=${argument#*"="}
    case "$binary" in
      yq) install_yq "$version" "$os" "$arch" "$path" ;;
      opm) install_opm "$version" "$os" "$arch" "$path" ;;
      kustomize) install_kustomize "$version" "$os" "$arch" "$path" ;;
      *)  echo; error "Invalid binary name for format: '$(bold "$argument")'"
          question "Format: <binary1=version> <binary2=version>" ;;
    esac
  done
}

install "$@"
