#!/bin/zsh
scripts/check.sh --level work --base a7944afaa0d93f8beaebce37f45e242d2c8dadbb --only formal_build,spec_examples,spec_tally
l21v_check_status=$?
echo "L21V_CHECK_EXIT_STATUS=$l21v_check_status"
exit "$l21v_check_status"
