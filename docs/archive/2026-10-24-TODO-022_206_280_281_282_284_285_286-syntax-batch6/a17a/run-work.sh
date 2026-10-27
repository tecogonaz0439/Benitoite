#!/bin/zsh
scripts/check.sh --level work --base ef4319f89aab95f6ebc3a0e346da64066e204e59
a17a_check_status=$?
printf '\nA17A_CHECK_EXIT_STATUS=%s\n' "$a17a_check_status"
exit "$a17a_check_status"
