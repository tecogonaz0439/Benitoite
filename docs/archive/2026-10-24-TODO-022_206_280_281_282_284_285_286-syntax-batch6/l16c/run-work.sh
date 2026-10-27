#!/bin/zsh
scripts/check.sh --level work --base 7d7b34c5fb73a06282956043d9f972fbcb3dea57 --only formal_build,spec_examples,spec_tally
check_result=$?
print -r -- "L16C_CHECK_EXIT_STATUS=$check_result"
exit "$check_result"
