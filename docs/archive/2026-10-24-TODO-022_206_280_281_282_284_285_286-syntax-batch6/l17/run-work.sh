#!/bin/zsh
scripts/check.sh --level work --base 5b491e3f549b505b58ece01f8953bbca8642b45f --only formal_build,spec_examples,spec_tally
check_result=$?
print -r -- "L17_CHECK_EXIT_STATUS=$check_result"
exit "$check_result"
