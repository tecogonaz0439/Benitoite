#!/bin/zsh
scripts/check.sh --level work --base 060eee90a4a43b2b88b780546ee96954291aeb56 --only formal_build,spec_examples,spec_tally
l21u_check_status=$?
echo "L21U_CHECK_EXIT_STATUS=$l21u_check_status"
exit "$l21u_check_status"
