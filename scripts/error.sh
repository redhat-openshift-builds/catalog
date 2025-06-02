#!/bin/bash

trap ERR ERR; ERR() {
  local code=$?
  local command=$BASH_COMMAND
  local func file line level

  echo -e "\nExit status $(bold "$code") for command: $(bold "$command")"

  for i in "${!FUNCNAME[@]}"; do
    if [[ $i == 0 ]]; then continue; fi
    func=${FUNCNAME[$i]}
    file=${BASH_SOURCE[$i]}
    line=${BASH_LINENO[$i - 1]}

    if (( i == ${#FUNCNAME[@]} - 1 )); then
      level='└─'
      func="<$func>"
    else
      level='├─'
    fi

    echo " $level $(bold "$func") ($file:$line)";
  done

  exit 1
} >&2
