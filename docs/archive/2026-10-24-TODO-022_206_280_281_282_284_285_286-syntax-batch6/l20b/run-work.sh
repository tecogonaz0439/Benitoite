#!/bin/zsh
scripts/check.sh --level work --base 6eccf6254d7cc387a44b45df3722482852b72d37 --only formal_build,spec_examples,spec_tally
l20_check_status=$?
print -r -- "L20B_CHECK_EXIT_STATUS=$l20_check_status"
exit "$l20_check_status"
