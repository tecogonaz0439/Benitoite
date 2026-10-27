#!/bin/zsh
scripts/check.sh --level work --base 045b0a22887cceb1cd866d40d6bbe55d02ef5310 --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally --test '*'
a16a_check_status=$?
printf '\nA16A_CHECK_EXIT_STATUS=%s\n' "$a16a_check_status"
exit "$a16a_check_status"
