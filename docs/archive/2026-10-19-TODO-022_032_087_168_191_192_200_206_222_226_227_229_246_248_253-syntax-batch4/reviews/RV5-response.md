# RV5の指摘への対応（Z9）

2026-10-21、RV5の中3件・軽5件を文書・記録・同梱Skillと英日の訳へ反映した。レビュー本文は [RV5.md](RV5.md) に保ち、この作業で変更していない。処理系のRust・標準ソースの本体、Lean、テストの中身、docs/todoは変更していない。検査の結果と時間は [z9/results.md](../z9/results.md) に記す。

| 指摘 | 対応 | 修正先・判断 |
|---|---|---|
| 中1 Skillのblockと訳 | 英日SKILLを36語とし、blockの予約とrecordを小文字の名前にも使える規則を明記した。日本語common-mistakesにblock・end blockとrecordの例外を反映した。手書き五文書の翻訳元0.0.10、36語の一覧、終端語を英日で照合した。生成物はgen_skillで再作成し、差分なし | crates/benitoite/skill/SKILL.md、docs/ja/skill/SKILL.md・references/common-mistakes.md。新しいテストやテストの変更は加えず、今回の文書照合として実施 |
| 中2 Lean先行段の古い記述 | Integerの全域でotherを残さない現規則と、check-formal全体の2回目（76ed2d5e、終了0）の完了を反映した。最後の1,789入力・73,836定義・Coverage 22,482件と六入口の一致を記した。docs/design・formalのMarkdownをgrepし、現在の接続を未実施とする文を除いた。追加で見つけたキーワード35語の古い記述も36語へ更新 | 01-12、07-04、formal/README.md、formal/tests/batch4-exchange/README.md、00-03。一般のLean先行手順の説明は保持 |
| 中3 targetsを行わない判断と行き先 | 設計者の判断をR222・R223として記録し、planのRV5・性能targets・性能の段の行を更新した。166点・55目標は未測定とし、TODO-248の三種類の費用の測定はdocs/todoのTODO-275、TODO-032の数値目標の判定はdocs/todoのTODO-262へ渡す。直しはTODO-275（親TODO-028）で他言語の処理系を参考に行う。測定入力の保管先と完全なSHA-256を残した | decisions.md、plan.md、results.md、README.md、todo-items.md。docs/todoへのリンク・編集なし |
| 軽1 保管時のリンク | git grepで公開文書からDへの参照を確認し、CHANGELOG・英日referenceの3か所を一覧にした。リンクは現在のまま保ち、保管時の付け替えと確認をオーケストレータへ渡す | results.md「保管のときに付け替える公開文書のリンク」 |
| 軽2 CHANGELOGの文章 | 0.0.10の節を一つの文に一つのことを書く形にし、名前にコードの書式を使った。Logを四つの箇条へ分け、開発の段取りの文を除いた。英日の導入の手順と保証の範囲の案内を末尾へ追加した。既存の例外・移行条件は保持し、性能の増減は書いていない | CHANGELOG.md。R223 |
| 軽3 recordとWASM統計 | recordを小文字の名前にも使える規則と、runtime_compilationsのnormal/adapter・test_declaration_compilationsの意味を追記した。実行用Componentの共有表への追加成功数と、静的宣言照合でコンパイルを試みた回数を区別した | CHANGELOG、docs/reference・docs/ja/reference、英日Skillのidioms.md |
| 軽4 集約記録の正確さ | python_syntaxがcompareのPythonも検査すること、Z8の成功でその単位を更新し以後Pythonが変わっていないことへ引用理由を修正した。測定記録35ファイルはQ1の取り込みd37792d6とした。bridge-shared-8の判定不能と、合格とは扱わないことを記した | results.md「性能」「仕上げ検査の引用の対象と理由（Q2）」 |
| 軽5 完了時の要約と最終候補の確認 | READMEの状態を実装・検査の結果と未測定のtargetsの要約へ置き換えた。RV5のTODOの引き継ぎ表をtodo-items末尾へ写し、Z9の修正とR222の行き先を反映した。最終候補のcommit・Skill producer・skill_generated・保管前リンクの消失・指定diffの確認表を追加し、結果は空欄にした | README.md、todo-items.md、results.md「最終の候補での確認」。同じ範囲のSkill・formal文書を直すため指定diff全体は空にならない点をR225に記録し、許可された文書差分の照合と実装差分が空であることの確認を分けた |

R224はZ9行がなかった計画に依頼の検査を追加する判断である。作業末の指定workと、formalのMarkdown変更に伴うlake buildの結果はz9/results.mdを正とする。指定workは5単位すべて成功し、spec_examples 7件・reference_examples 1件・skill_docs 8件は失敗・ignored 0であった。lake buildも293 jobs成功した。最終候補の再確認、保管、docs/todoの更新、コミットと公開操作はオーケストレータへ引き渡す。
