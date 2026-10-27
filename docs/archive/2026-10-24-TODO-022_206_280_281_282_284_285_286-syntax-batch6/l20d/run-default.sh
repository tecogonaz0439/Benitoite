#!/bin/zsh
cd formal || exit
lake build
l20d_default_status=$?
echo "L20D_DEFAULT_EXIT_STATUS=$l20d_default_status"
exit "$l20d_default_status"
