#!/bin/zsh
scripts/check.sh --level work --base 56726f2ef44b05d2a3ce32f238aec3c708f0798a
a18a_check_status=$?
printf '\nA18A_CHECK_EXIT_STATUS=%s\n' "$a18a_check_status"
exit "$a18a_check_status"
