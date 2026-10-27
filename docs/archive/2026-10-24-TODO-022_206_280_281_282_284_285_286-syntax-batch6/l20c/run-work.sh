#!/bin/zsh
scripts/check.sh --level work --base 335caabf3b08b98ae7f8c3c7311f1c116ae28072 --only formal_build,spec_examples,spec_tally
l20c_check_status=$?
print -r -- "L20C_CHECK_EXIT_STATUS=$l20c_check_status"
exit "$l20c_check_status"
