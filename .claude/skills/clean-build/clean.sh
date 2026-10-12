#!/usr/bin/env bash
# ビルドの生成物の大きさを示し、指定されたものを消す（スキル clean-build）。
#
# 使い方:
#   clean.sh                       本体と各作業ディレクトリの生成物の大きさを示すだけ（何も消さない）
#   clean.sh --worktrees           取り込み済みで変更のない作業ディレクトリを、生成物ごと消し、ブランチも消す
#   clean.sh --main <対象,...>     本体の生成物を消す。対象は desugar-diff、target、fuzz、lean、all
#   --force                        cargo・rustc・lake・codex exec の動いている間でも消す（既定では止まる）
#
# macOS の bash 3.2 で動くように書く（連想配列を使わない）。
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
main_branch="san_benito"
do_worktrees=0
main_targets=""
force=0

while [ $# -gt 0 ]; do
    case "$1" in
        --worktrees) do_worktrees=1 ;;
        --main)
            shift
            [ $# -gt 0 ] || { echo "--main needs targets (desugar-diff,target,fuzz,lean,all)" >&2; exit 2; }
            main_targets="$1" ;;
        --force) force=1 ;;
        -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

size_of() {
    if [ -e "$1" ]; then du -sh "$1" 2>/dev/null | cut -f1; else echo "-"; fi
}

# 生成物の置き場所。どれも .gitignore で除いてあり、消しても次のビルドで作り直される。
generated_dirs="target fuzz/target formal/.lake"

report_checkout() {
    local dir="$1" label="$2"
    printf '%s  (%s)\n' "$dir" "$label"
    local d
    for d in $generated_dirs; do
        printf '    %-20s %s\n' "$d" "$(size_of "$dir/$d")"
    done
    if [ -d "$dir/target/desugar-diff" ]; then
        printf '    %-20s %s\n' "target/desugar-diff" "$(size_of "$dir/target/desugar-diff")"
    fi
}

# ビルドや Codex が動いている間に消すと、その作業を壊す。
busy_check() {
    if [ "$force" -eq 1 ]; then return 0; fi
    local found
    # codex は、常駐するアプリのサーバ（codex app-server）でなく、作業を走らせる codex exec だけを見る。
    found="$(pgrep -fl '(^|/)(cargo|rustc|lake)( |$)|codex exec' 2>/dev/null || true)"
    if [ -n "$found" ]; then
        printf '%s\n' "== stop: build or agent processes are running (rerun with --force to ignore):" >&2
        printf '%s\n' "$found" >&2
        exit 3
    fi
}

# git worktree list --porcelain から、本体以外の作業ディレクトリとブランチを「パス<TAB>ブランチ」で出す。
list_worktrees() {
    git -C "$root" worktree list --porcelain | awk -v main="$root" '
        /^worktree / { path = substr($0, 10); branch = "" }
        /^branch /   { branch = substr($0, 8); sub("^refs/heads/", "", branch) }
        /^$/         { if (path != main && path != "") print path "\t" branch; path = "" }
        END          { if (path != main && path != "") print path "\t" branch }'
}

echo "== generated files"
report_checkout "$root" "main, $(git -C "$root" branch --show-current)"
worktrees="$(list_worktrees)"
if [ -n "$worktrees" ]; then
    while IFS="$(printf '\t')" read -r path branch; do
        [ -n "$path" ] || continue
        state="merged"
        if [ -z "$branch" ] || ! git -C "$root" merge-base --is-ancestor "$branch" "$main_branch" 2>/dev/null; then
            state="not merged"
        fi
        if [ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]; then
            state="$state, uncommitted changes"
        fi
        report_checkout "$path" "${branch:-detached}, $state"
    done <<<"$worktrees"
fi
df -h "$root" | tail -1 | awk '{ print "== disk: " $4 " free of " $2 }'

if [ "$do_worktrees" -eq 0 ] && [ -z "$main_targets" ]; then
    exit 0
fi
busy_check

if [ "$do_worktrees" -eq 1 ] && [ -n "$worktrees" ]; then
    echo "== removing merged worktrees"
    while IFS="$(printf '\t')" read -r path branch; do
        [ -n "$path" ] || continue
        if [ -z "$branch" ] || ! git -C "$root" merge-base --is-ancestor "$branch" "$main_branch" 2>/dev/null; then
            echo "   skip $path: ${branch:-detached} is not merged into $main_branch"
            continue
        fi
        if [ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]; then
            echo "   skip $path: uncommitted changes"
            continue
        fi
        # 生成物は追跡していないので、先に消さないと git worktree remove が拒む。
        for d in $generated_dirs; do rm -rf "${path:?}/$d"; done
        git -C "$root" worktree remove "$path"
        git -C "$root" branch -d "$branch" >/dev/null
        echo "   removed $path and branch $branch"
    done <<<"$worktrees"
    git -C "$root" worktree prune
fi

if [ -n "$main_targets" ]; then
    echo "== cleaning the main checkout"
    for t in $(printf '%s' "$main_targets" | tr ',' ' '); do
        case "$t" in
            desugar-diff) rm -rf "$root/target/desugar-diff"; echo "   removed target/desugar-diff" ;;
            target) (cd "$root" && cargo clean -q); echo "   cargo clean" ;;
            fuzz) rm -rf "$root/fuzz/target"; echo "   removed fuzz/target" ;;
            lean) rm -rf "$root/formal/.lake"; echo "   removed formal/.lake" ;;
            all)
                (cd "$root" && cargo clean -q)
                rm -rf "$root/fuzz/target" "$root/formal/.lake"
                echo "   cargo clean, removed fuzz/target and formal/.lake" ;;
            *) echo "unknown target: $t (desugar-diff, target, fuzz, lean, all)" >&2; exit 2 ;;
        esac
    done
fi
df -h "$root" | tail -1 | awk '{ print "== disk: " $4 " free of " $2 }'
