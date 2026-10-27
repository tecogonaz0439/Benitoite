#!/bin/zsh
scripts/check.sh --level work --base d1d706eaa3a181189b512057a5b3f08c110fe241 --only formal_build,spec_examples,spec_tally
l21r_check_status=$?
echo "L21R_CHECK_EXIT_STATUS=$l21r_check_status"
exit "$l21r_check_status"
