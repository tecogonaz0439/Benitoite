#!/bin/zsh
cd formal || exit
lake build
l21_default_status=$?
echo "L21_DEFAULT_EXIT_STATUS=$l21_default_status"
exit "$l21_default_status"
