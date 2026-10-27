#!/bin/zsh
scripts/check.sh --level work --base 0aa2bd66829f6a3f1f5c3ec23d7290c4ea13ec64
a17b_check_status=$?
printf '\nA17B_CHECK_EXIT_STATUS=%s\n' "$a17b_check_status"
exit "$a17b_check_status"
