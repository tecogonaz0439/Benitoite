#!/bin/zsh
scripts/check.sh --level work --base 9d18f7d233dbea603fcb6f1ea3ebbcf1c45d0e66 --only formal_build,spec_examples,spec_tally
check_result=$?
print -r -- "L16B2_CHECK_EXIT_STATUS=$check_result"
exit "$check_result"
