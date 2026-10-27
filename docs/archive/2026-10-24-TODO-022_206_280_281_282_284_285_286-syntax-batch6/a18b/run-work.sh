#!/bin/zsh
scripts/check.sh --level work --base d82c182642fd7adbfa4a06c78b424a00f32d6fe8 --only spec_examples,spec_tally,reference_examples,skill_docs,skill_generated,tests_related --test skill_examples --test stdlib_doc_examples
a18b_check_status=$?
printf '\nA18B_CHECK_EXIT_STATUS=%s\n' "$a18b_check_status"
exit "$a18b_check_status"
