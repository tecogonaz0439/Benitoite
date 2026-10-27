# R04 の実装結果

2026-10-24。R04 の文書修正と指定検査を完了した。基準 B_WORK は `6703fa4b5d0c9e231952d97038f1fa6da3d15e59`。開始時の HEAD は基準と一致し、ブランチは `mod012/R04`、未コミット差分はなかった。private/ とそこを指すスキルのリンクは読んでいない。git は状態・差分・基準の文書の読み取りだけに使い、変更操作はしていない。

## 変更の範囲

`tools/derive/README.md`、06-09、同梱 Skill、英語リファレンスに、ファイル単位の `uses` がある生成対象への JSON・Property の拒否と、個別の `uses` または型定義ごとの純粋なモデル用モジュールへの移動を案内した。README の管理終了手順を参照する型の移動手順を加え、設定の `source` だけの変更では分離できないことを明記した。生成器 `3.1.0-syntax-batch5`・inventory 3 に現行説明をそろえ、過去版の移行節は保った。旧 manifest の無条件な再利用は案内せず、途中の適用・復旧を更新前に旧道具で終える順序を明記した。

## 実行した検査

コマンドはリポジトリの根で実行した。work は計画の名指しに従う部分選択であり、Rust の実装・テスト・仕様例・生成参照の生成元は変更していない。

| コマンド・入力 | 終了状態 | 外側の時間・結果 |
|---|---:|---|
| `/usr/bin/time -p rtk proxy scripts/check.sh --level work --base 6703fa4b5d0c9e231952d97038f1fa6da3d15e59 --only reference_examples,skill_docs,skill_generated,tests_related --test skill_examples --dry-run` | 0 | 0.02秒。tests_related（skill_examples）・skill_generated・reference_examples・skill_docs の4単位だけを選択 |
| 同指定から `--dry-run` を除いた実行 | 0 | 18.89秒。skill_examples 3件、reference_examples 1件、skill_docs 8件が全て成功、失敗・無視0件。gen_skill による生成参照と bundle の照合も成功 |
| 読み取りの Python による文書の静的点検（初回2回、標準入力） | 1 | 外側の時間は未計測。点検用の正規表現がインラインコード中の型引数・関数型をリンクと誤認した。単一行、次いで複数行のインラインコードを対象外にする修正を点検スクリプトだけに行った |
| `/usr/bin/time -p rtk proxy python3 -B <tmp>/benitoite-r04-doc-check.py` | 0 | 0.12秒。文書4点の相対リンク95件とアンカー、フェンス、既存見出し、末尾空白、公開文書の docs/todo リンクと手元の絶対パスの不在を確認。基準との比較でコードブロックと0.0.10／0.0.11の移行節の不変、現行版表記の一致を確認 |
| `/usr/bin/time -p rtk git diff --check` | 0 | 0.03秒。追跡ファイルの差分の空白検査に成功 |

## 計画との差と申し送り

- R04 の指定範囲に収まり、計画の検査の割り当てからの変更はない。言語の規則、E0908 の登録、Lean の定義・定理・公理は変更していない。担当範囲の未解決の失敗はない。
- Z01a で `docs/ja/skill/SKILL.md` の末尾の derive 説明（現行 inventory 2／生成器3.0.0 の箇所）を英語版へ同期する。事前拒否の対処、既存領域の整理、更新前の旧道具での復旧、新しい preview の確認も訳す。
- Z01a で `docs/ja/reference/benitoite.md` の JSON 変換の derive 説明と「レコードの生成器と縮小器」の保存事項を同期する。過去版の「0.0.10 への移行」の inventory 2／生成器3.0.0 は当時の案内として保つ。日本語訳は R04 では変更していない。
- 独立レビュー・取り込み・R04 後の stage S-R2 は取りまとめ担当である。S-R2 では計画どおり property_library・reference_examples・skill_docs・skill_examples・spec_examples の接続と、R03 の受理入力一致の結果を照合する。R04 はそれらの受け入れを先取りしていない。

## 取りまとめのレビューでの修正

R04 当時の 06-09「derive の生成先と版」（R08R で削除し、対処と旧 manifest の注意を 03-06「外部生成の管理と照合」へ統合）の最初の【決定】は、R02 が 03-06「外部生成の管理と照合」に書いた拒否の決定と重なっていた。取りまとめが、06-09 の側を 03-06 への参照の一文に改めた（文書だけの変更。検査の再実行は要しない）。

一時スクリプトは保存していない。
