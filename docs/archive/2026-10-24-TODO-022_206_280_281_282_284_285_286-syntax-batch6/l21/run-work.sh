#!/bin/zsh
scripts/check.sh --level work --base 8b48e75a43c90069b7c44e6e073182b45ed2413b --only formal_build,spec_examples,spec_tally
l21_check_status=$?
echo "L21_CHECK_EXIT_STATUS=$l21_check_status"
exit "$l21_check_status"
