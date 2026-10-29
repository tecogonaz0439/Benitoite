#!/bin/zsh
# 一時の写しの formal を作業用のディレクトリへ反映する（中身が違うファイルだけ）
rsync -rc --exclude .lake --exclude .git <scratch>/c/formal/ <wt>/formal/
