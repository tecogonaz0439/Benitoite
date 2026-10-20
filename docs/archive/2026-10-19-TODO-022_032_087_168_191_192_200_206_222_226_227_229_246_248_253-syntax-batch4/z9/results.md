# Z9 RV5の指摘への文書修正

## 基準と範囲

- 日付・担当: 2026-10-21、Codex。
- 開始HEAD・B_WORK: `98c3572acbaee1dee561547ff812399b3965cb18`（開始時の `git merge-base HEAD san_benito`）。
- 開始時の既存の未追跡ファイル: `reviews/RV5.md`（オーケストレータが置いたレビュー本文）。本文は変更せず、取り込み対象として残した。
- 変更: 同梱Skillと英日の訳、CHANGELOGと英日reference、設計書とformalのMarkdown、Dの要約・計画・判断・集約結果・TODOの引き継ぎ表・RV5対応表。
- Rust・標準ソースの本体、Lean、テストの中身、docs/todoは変更していない。コミットしていない。

## 関係する文書の確認と生成

`cargo run -p benitoite --example gen_skill` は終了0。文法・診断・標準ライブラリの生成物とbundle.rsを再作成したが、生成物の差分はなかった。

一時スクリプト `python3 /private/tmp/z9_audit.py` は終了0。手書きSkill五文書の翻訳元が0.0.10であること、英日で35語の古い記述がないこと、SKILLとcommon-mistakesの36語・終端語の一致を確認した。common-mistakesのキーワードは英日とも同じ36語でblockとrecordを含む。英日referenceとidiomsにはrecordと統計の三欄の説明がある。referenceの全コードブロックと01-12のtextブロックは開始時と一致し、CHANGELOG末尾の英日の新しい導入リンクのアンカーも存在する。許可されたSkill・formal文書を除く `e6247c11` からの実装の差分は空であった。

`git grep "2026-10-19-TODO-"` でD自身を除く公開文書からの参照を確認した。CHANGELOG・英日referenceの3か所だけであり、D/results.mdへ一覧を保存した。docs/design・formalのMarkdownに対して `未実施|未接続|取りまとめ|V1後` とキーワードの数を検索し、今回の接続の未完了を述べる古い記述と、00-03・07-04に残っていた35語の記述を修正した。一般の検査手順の記述は残した。

## 作業末の検査

検査前に種類と5〜15分の見込みを通知した。次の名指し指定を、同じ基準のdry-runで確認してから一度だけ実行した。formalのMarkdownも変えたため、既定のlake buildも一度実行した。

| コマンド | 終了状態 | 外側の時間・結果 |
|---|---|---|
| `scripts/check.sh --level work --base 98c3572acbaee1dee561547ff812399b3965cb18 --only fmt,reference_examples,skill_docs,skill_generated,spec_examples --dry-run` | 0 | 1秒未満。指定した5単位だけを選択 |
| `scripts/check.sh --level work --base 98c3572acbaee1dee561547ff812399b3965cb18 --only fmt,reference_examples,skill_docs,skill_generated,spec_examples` | 0 | 19.437秒。fmt・skill_generated成功、spec_examples 7件・reference_examples 1件・skill_docs 8件成功。失敗・ignored 0 |
| `(cd formal && lake build)` | 0 | 0.405秒。293 jobs成功、sorryによる拒否なし |

作業末の実行はこの一度だけであり、全体のcheck・gc-stress・all-targets・check-formal・性能測定は追加していない。

差分の空白検査は初回の `git diff --check` が終了2（todo-items.md末尾の余分な空行）となった。rtkの出力に理由が出なかったため通常のgitでも確認し、末尾の空行だけを削除した。文書例・同梱物・Leanには変更がないため、成功したworkとlake buildは繰り返さず、差分の空白検査だけを更新し、再実行は終了0（0.01秒未満）となった。

## 計画からのずれと申し送り

- notes/Z9.mdとplanのZ9行が開始時に存在しなかったため、依頼本文に従いR224とplanの検査行を追加した。検査の範囲は依頼どおりである。
- R222・R223に、targetsを行わないこと、性能の直しをdocs/todoのTODO-275（親TODO-028）へ回すこと、CHANGELOGに性能の増減を書かないこと、今後のshortの時期を記録した。TODO-248の費用の測定はTODO-275、TODO-032の数値目標の判定はTODO-262へ引き継ぐ。
- 最終候補で指定されたdiffの範囲は、今回の必須のSkill・formal文書の修正を含むため空にはならない。R225に、元のdiffで許可された文書差分を照合し、それらを除く実装の差分が空であることを別途確認する判断を記録した。
- D/results.mdの最終候補の点検表は結果を空欄にした。候補ID・同梱物・skill_generated・3か所のリンクの付け替え・差分を、保管と集約の後にオーケストレータが確認する。
- RV5本文と[対応表](../reviews/RV5-response.md)を取り込み対象とする。docs/todoの更新、保管、コミット、公開操作はオーケストレータへ渡す。
