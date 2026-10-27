#!/bin/zsh
scripts/check.sh --level work --base 2ca69c26cf7397bb5da9e113d19a2f1b6905986d --only formal_build,spec_examples,spec_tally
check_exit=$?
print -r -- "L16B_CHECK_EXIT_STATUS=$check_exit"
exit "$check_exit"
