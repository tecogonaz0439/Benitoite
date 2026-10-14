#!/usr/bin/env bash
# ソースのアーカイブ（tar.gz と zip）と、ブランチ・タグの git bundle を work/ に作る（スキル archive-and-bundle）。
#
# 使い方:
#   archive.sh archive [<コミット>]
#       コミット（既定は HEAD）から work/Benitoite-<タグ>-<ブランチ>-<短いコミット>.tar.gz と .zip を作る。
#       タグはコミットに付いたタグ、なければ直近のタグ。中の最上位のディレクトリは、タグの付いたコミットなら
#       Benitoite-<版>/（タグの v を除く）、ほかは Benitoite-<短いコミット>/。
#   archive.sh bundle <名前> <参照>... [--delete]
#       参照（ブランチ名・タグ名・refs/... の形）を work/Benitoite-<名前>-<日付>.bundle に保存し、確かめる。
#       --delete を付けると、確かめた後に、保存した手元のブランチとタグを消す（今のブランチ、san_benito、
#       リリースのタグ v<数字>... は消さない）。
#   archive.sh bundle <名前> --all-except-main [--delete]
#       san_benito とリリースのタグ（v<数字>...）以外のすべての手元のブランチとタグを保存する。
#
# 既にある出力のファイルは上書きしない。リモートには何も送らない。macOS の bash 3.2 で動くように書く。
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
out="$root/work"
main_branch="san_benito"
mkdir -p "$out"

die() { echo "$*" >&2; exit 2; }

refuse_existing() {
    [ ! -e "$1" ] || die "already exists, not overwritten: $1"
}

cmd_archive() {
    local commit="${1:-HEAD}" short tag exact branch prefix base
    short="$(git -C "$root" rev-parse --short "$commit^{commit}")" || die "not a commit: $commit"
    if exact="$(git -C "$root" describe --tags --exact-match "$commit" 2>/dev/null)"; then
        tag="$exact"
        prefix="Benitoite-${tag#v}/"
    else
        tag="$(git -C "$root" describe --tags --abbrev=0 "$commit" 2>/dev/null)" || die "no tag before $commit"
        prefix="Benitoite-$short/"
    fi
    # ブランチは、公開するブランチがコミットを含むならその名前、次に今のブランチ、どちらでもなければコミットを含むブランチの最初のもの。
    # 作業用のブランチ（`mod/V2` など）の上で作っても、リリースのコミットには公開するブランチの名前を付けるためである。
    # 名前の `/` はファイル名に使えないので `-` に替える。
    if git -C "$root" merge-base --is-ancestor "$commit" "$main_branch" 2>/dev/null; then
        branch="$main_branch"
    else
        branch="$(git -C "$root" branch --show-current)"
    fi
    if [ -z "$branch" ] || ! git -C "$root" merge-base --is-ancestor "$commit" "$branch" 2>/dev/null; then
        branch="$(git -C "$root" branch --contains "$commit" --format='%(refname:short)' | head -1)"
    fi
    [ -n "$branch" ] || die "no branch contains $commit"
    branch="${branch//\//-}"
    base="$out/Benitoite-$tag-$branch-$short"
    refuse_existing "$base.tar.gz"
    refuse_existing "$base.zip"
    git -C "$root" archive --format=tar.gz --prefix="$prefix" -o "$base.tar.gz" "$commit"
    git -C "$root" archive --format=zip --prefix="$prefix" -o "$base.zip" "$commit"
    # 中のファイルの数が、コミットの木のファイルの数と一致することを確かめる。
    local expected tar_count zip_count
    expected="$(git -C "$root" ls-tree -r --name-only "$commit" | wc -l | tr -d ' ')"
    tar_count="$(tar tzf "$base.tar.gz" | grep -v '/$' | wc -l | tr -d ' ')"
    zip_count="$(unzip -Z1 "$base.zip" | grep -v '/$' | wc -l | tr -d ' ')"
    echo "== archive of $commit ($short), tag $tag, branch $branch, prefix $prefix"
    ls -l "$base.tar.gz" "$base.zip"
    echo "   files: tree $expected, tar.gz $tar_count, zip $zip_count"
    [ "$expected" = "$tar_count" ] && [ "$expected" = "$zip_count" ] || die "file counts differ"
}

cmd_bundle() {
    local name="${1:-}"
    [ -n "$name" ] || die "bundle needs a name"
    shift
    local delete=0 refs="" r
    while [ $# -gt 0 ]; do
        case "$1" in
            --delete) delete=1 ;;
            --all-except-main)
                refs="$refs $(git -C "$root" for-each-ref --format='%(refname)' refs/heads refs/tags | grep -v "^refs/heads/$main_branch\$" | grep -v '^refs/tags/v[0-9]' | tr '\n' ' ')" ;;
            *)
                # 短い名前を、ブランチかタグの完全な名前にする。
                if git -C "$root" show-ref --verify -q "refs/heads/$1"; then refs="$refs refs/heads/$1"
                elif git -C "$root" show-ref --verify -q "refs/tags/$1"; then refs="$refs refs/tags/$1"
                elif git -C "$root" show-ref --verify -q "$1"; then refs="$refs $1"
                else die "no such branch or tag: $1"
                fi ;;
        esac
        shift
    done
    [ -n "${refs// /}" ] || die "no refs to bundle"
    local file="$out/Benitoite-$name-$(date +%Y-%m-%d).bundle"
    refuse_existing "$file"
    # shellcheck disable=SC2086
    git -C "$root" bundle create "$file" $refs
    git -C "$root" bundle verify "$file" >/dev/null
    echo "== bundle $file"
    ls -l "$file"
    # 保存した参照ごとに、bundle の中の値が手元の値と一致することを確かめる。
    local heads missing=0
    heads="$(git -C "$root" bundle list-heads "$file")"
    for r in $refs; do
        if printf '%s\n' "$heads" | grep -qx "$(git -C "$root" rev-parse "$r") $r"; then
            echo "   saved $r"
        else
            echo "   NOT saved $r" >&2
            missing=1
        fi
    done
    [ "$missing" -eq 0 ] || die "some refs are not in the bundle; nothing deleted"
    echo "   restore: git fetch $file '<ref>:<ref>'  (e.g. 'refs/heads/NAME:refs/heads/NAME')"
    if [ "$delete" -eq 1 ]; then
        local current
        current="$(git -C "$root" branch --show-current)"
        for r in $refs; do
            case "$r" in
                "refs/heads/$main_branch"|"refs/heads/$current")
                    echo "   kept $r (main or current branch)" ;;
                refs/heads/*)
                    # 作業ディレクトリが使っているブランチは消せない（git が拒む）ので、その旨を示して残す。
                    git -C "$root" branch -D "${r#refs/heads/}" >/dev/null 2>&1 && echo "   deleted $r" || echo "   kept $r (in use by a worktree?)" ;;
                refs/tags/v[0-9]*)
                    echo "   kept $r (release tag)" ;;
                refs/tags/*)
                    git -C "$root" tag -d "${r#refs/tags/}" >/dev/null && echo "   deleted $r" ;;
                *) echo "   kept $r" ;;
            esac
        done
    fi
}

case "${1:-}" in
    archive) shift; cmd_archive "$@" ;;
    bundle) shift; cmd_bundle "$@" ;;
    -h|--help|"") sed -n '2,17p' "$0" ;;
    *) die "unknown command: $1 (archive, bundle)" ;;
esac
