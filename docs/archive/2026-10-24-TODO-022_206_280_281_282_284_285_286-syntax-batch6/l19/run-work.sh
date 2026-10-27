#!/bin/zsh
scripts/check.sh --level work --base f41a35c3116d96862b832032c2d1bcb5efc02b68 --only formal_build,spec_examples,spec_tally
l19_check_status=$?
print -r -- "L19_CHECK_EXIT_STATUS=$l19_check_status"
exit "$l19_check_status"
