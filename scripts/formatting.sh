#!/bin/bash

export LC_ALL=en_US.UTF-8

success() { printf "\u2705  %s\n" "$@"; }

error() { printf "\u274C  %s\n" "$@"; }

message() { printf "\u2757  %s\n" "$@"; }

question() { printf "\u2753  %s\n" "$@"; }

process() { printf "\u23F0  %s\n" "$@"; }

clear() { printf "\e[F\e[K"; }

bold() { tput bold; echo -en "$@"; tput sgr0; }

seperator() { printf "%${2:-$(tput cols)}s\n" "" | tr ' ' "${1:-"-"}"; }

header() {
  printf "\n"
  seperator "=" 80
  tput bold; printf "%s\n" "$@"; tput sgr0
  seperator "-" 80
}

footer() {
  print_seperator "-" 80
  tput bold; printf "%s\n" "$@"; tput sgr0
}
