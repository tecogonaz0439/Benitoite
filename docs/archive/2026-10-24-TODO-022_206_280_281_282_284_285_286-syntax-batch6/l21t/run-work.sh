#!/bin/zsh
scripts/check.sh --level work --base f6ed14a88c0a4cb6a7ef8305f6837150bf80036d --only formal_build,spec_examples,spec_tally
l21t_check_status=$?
echo "L21T_CHECK_EXIT_STATUS=$l21t_check_status"
exit "$l21t_check_status"
