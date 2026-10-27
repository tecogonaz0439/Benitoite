#!/bin/zsh
scripts/check.sh --level work --base 8a59b630f9fdef8d1e1595f7999c6242d167d739 --only formal_build,spec_examples,spec_tally
l20d_check_status=$?
echo "L20D_CHECK_EXIT_STATUS=$l20d_check_status"
exit "$l20d_check_status"
