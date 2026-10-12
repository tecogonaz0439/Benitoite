---
name: archive-and-bundle
description: Benitoite のソースのアーカイブ（git archive の tar.gz と zip）を作るときと、ブランチやタグを git bundle に保存して（必要なら手元から消して）片付けるときに使う。リリースのタグを付けた後のアーカイブ、ブランチの整理の前の控え、消したブランチの戻し方を頼まれたときに使う。
---

# ソースのアーカイブとブランチの bundle

ソースのアーカイブと、ブランチ・タグの控え（git bundle）を作る手順である。出力はどちらも `work/`（git の追跡外）に置く。道具は同じディレクトリの `archive.sh` で、既にある出力のファイルは上書きせず、リモートには何も送らない。

## ソースのアーカイブ

`.claude/skills/archive-and-bundle/archive.sh archive [<コミット>]`（既定は `HEAD`）で、tar.gz と zip を両方作る。

- ファイル名は `Benitoite-<タグ>-<ブランチ>-<短いコミット>.<拡張子>` とする（例: `Benitoite-v0.0.2-san_benito-c273b9f.tar.gz`）。2026-10-09 に設計者が決めた形である。
- タグは、コミットに付いたタグを使う。付いていなければ直近のタグを使う（例: `Benitoite-v0.0.1-san_benito-6143d0e.zip`）。
- 中の最上位のディレクトリは、タグの付いたコミットなら `Benitoite-<版>/`（タグの `v` を除く。例: `Benitoite-0.0.2/`）、ほかは `Benitoite-<短いコミット>/` とする。
- 道具は、中のファイルの数がコミットの木のファイルの数と一致することを確かめる。
- アーカイブに入るのは、コミットした追跡中のファイルだけである。`docs/todo/`（非公開の別のリポジトリ）、`reference/`、`work/`、ビルドの生成物、コミットしていない変更は入らない。作る前に `git status` で、入れたい変更がコミットしてあるかを確かめる。

アーカイブを作るのは、設計者に頼まれたときである（リリースのタグを付けた後など）。作ったら、ファイル名と大きさを報告する。

## ブランチとタグの bundle

ブランチを整理するときは、消す前に bundle に保存する。消すのは設計者の指示があるときだけで、push 済みの `san_benito` とリモートのタグは扱わない。

1. 消す候補を示す。`git branch -vv`、`git tag`、`git worktree list` で、ブランチとタグ、作業ディレクトリが使っているブランチを確かめ、`san_benito` に取り込み済みか（`git merge-base --is-ancestor`）を添えて設計者に示す。記録の文書（`tools/bench/results/`、`docs/archive/` など）が引くコミットを持つブランチは、そのことも示す（消しても bundle から戻せるが、どこにあるかを記憶に残す必要がある）。
2. 保存する。
   - 選んだ参照: `archive.sh bundle <名前> <ブランチやタグ>...`
   - `san_benito` とリリースのタグ（`v0.0.1` など。公開済み）以外のすべて: `archive.sh bundle <名前> --all-except-main`
   出力は `work/Benitoite-<名前>-<日付>.bundle`（例: `Benitoite-branches-and-tags-before-cleanup-2026-10-11.bundle`）。道具は `git bundle verify` に加えて、保存した参照ごとに bundle の中の値が手元の値と一致することを確かめ、一つでも合わなければ何も消さずに止まる。
3. 消す。設計者の指示があれば、同じ呼び出しに `--delete` を付ける（保存と確かめの後に、保存した手元のブランチとタグを消す）。`san_benito`、今のブランチ、リリースのタグ（`v<数字>…`）は消さない。作業ディレクトリが使っているブランチは git が拒むので残る（作業ディレクトリはスキル `clean-build` で先に片付ける）。
4. 記録する。bundle のファイル名、中の参照の数、記録の文書が引くコミットとそのブランチ、戻し方を、記憶（reference の種類）に残す。`work/` は git の追跡外なので、消さないよう記憶に書いておく。

戻し方: `git fetch work/<bundle> 'refs/heads/<名前>:refs/heads/<名前>'`（タグは `refs/tags/<名前>:refs/tags/<名前>`）。中の参照の一覧は `git bundle list-heads work/<bundle>`。

## 注意

- `work/` のアーカイブと bundle は git の追跡外で、このリポジトリの履歴には残らない。消すと戻せないので、`clean-build` などの片付けでも消さない。
- push と、リモートのブランチやタグの削除は、このスキルでは行わない。push は設計者の指示を得てから、スキル `git-workflow` に従って行う。
