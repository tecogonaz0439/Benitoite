#!/bin/zsh
scripts/check.sh --level work --base d2d9954264daea806db0bf202449938bd1dd0291 --only formal_build,spec_examples,spec_tally
check_result=$?
print -r -- "L18_CHECK_EXIT_STATUS=$check_result"
exit "$check_result"
