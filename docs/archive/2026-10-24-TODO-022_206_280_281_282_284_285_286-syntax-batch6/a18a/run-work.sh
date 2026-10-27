#!/bin/zsh
scripts/check.sh --level work --base d7edb402458ce5d8d223f9fee02d476c178a389f
a18a_check_status=$?
printf '\nA18A_CHECK_EXIT_STATUS=%s\n' "$a18a_check_status"
exit "$a18a_check_status"
