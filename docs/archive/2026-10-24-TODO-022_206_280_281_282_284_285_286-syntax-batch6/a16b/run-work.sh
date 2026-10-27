#!/bin/zsh
scripts/check.sh --level work --base a7a82d12f3ab1e15d88345cb8ba2c7f2392ab4d3
a16b_check_status=$?
printf '\nA16B_CHECK_EXIT_STATUS=%s\n' "$a16b_check_status"
exit "$a16b_check_status"
