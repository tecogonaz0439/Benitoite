#!/bin/sh
# 検査自身の終了状態を、計時器と別に残す。
scripts/check.sh --level work --base 92f9ac80f81d2299978d2051ddcdfdeea1843e6d \
  --test spec_examples --test reference_examples --test skill_docs \
  --test skill_examples --test stdlib_doc_examples --test build_info \
  --test cli_process --test package_command --test test_command \
  --test declarations --test golden --test desugar_export
check_status=$?
printf '{"exit":%d}\n' "$check_status" > "$(dirname "$0")/ab-work-check-exit.json"
exit "$check_status"
