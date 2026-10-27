#!/bin/zsh
scripts/check.sh --level work --base 2fd371c49190ab914c05963f83fdd23d833d6e80 --only formal_build,spec_examples,spec_tally
l20_check_status=$?
print -r -- "L20_CHECK_EXIT_STATUS=$l20_check_status"
exit "$l20_check_status"
