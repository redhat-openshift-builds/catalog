#!/bin/bash

shopt -so errexit
shopt -so errtrace
shopt -so nounset
shopt -so pipefail
shopt -s extglob

source ./scripts/formatting.sh
source ./scripts/error.sh

# Check arguments
check_arguments() {
  local required=$1
  local args=("${@:2}")
  local length=${#args[@]}
  if [ "$length" -lt "$required" ]; then
    echo "Requires $required arguments, but $length arguments provided for function '${FUNCNAME[1]}'."
    exit 1
  fi
  for arg in "${args[@]}"; do
    if [[ -z "$arg" ]]; then
      echo "Arguments cannot be null or empty for function '${FUNCNAME[1]}'."
      exit 1
    fi
  done
}

# Check file and exit if doesn't exists
check_file() {
  local file=$1 return=$2
  if ! test -e "$file"; then
    echo "Could not find file: $file" >&2
    return "$return"
  fi
}

# Add path to PATH variable
add_path() {
  check_arguments 1 "$@"
  local path=$1
  if [[ ":$PATH:" != *":$path:"* ]]; then
    export PATH="$path:$PATH"
  fi
}

# Check if a command is installed
command_exists () {
  command -v "$1" >/dev/null 2>&1
}
