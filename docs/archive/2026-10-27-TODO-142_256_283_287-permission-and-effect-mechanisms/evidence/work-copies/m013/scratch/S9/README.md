# S9 の調査・集計・静的な確認の記録

2026-10-27。基準は `san_benito` の `04c78e527e6c23c0be8a9dbce26f23d685a5e04d`。`private/` とそこを指すリンクは読んでいない。書いた対象は改造の `study/language-rules.md`・`study/user-effect-scopes.md` と、このディレクトリの下だけである。gitの状態を変える操作、Cargoのビルド/テスト、検査スクリプト、Lean、LLMの評価は実行していない。

| 記録 | 内容 |
|---|---|
| `baseline.json` | 開始時のブランチ・HEAD・空の作業ツリー、開始版3597b310から設計書/Rust/Lean/検査スクリプトへ差がないこと |
| `ip-research.md` | RFC 3986/5952/4291/4632のURL・確認日・使った事実、旧ScopeとHTTPのソース行、IP/CIDRの提案・未確認、Checked.Scopeの件数 |
| `q9-notes.md` | 現行仕様・Rust/Leanのソース行、三案と初期の調査所見。最終本文では(a)を制限し、Q8方式へ具体化した |
| `q9-lean-inventory.py`・`.json`・`.md` | 固定した版のgit grep、宣言ごとの集計、入力SHA-256と方法・限界 |
| `q9-lean-*.grep.txt` | 検索語ごとのgit grepの生結果 |
| `time-budget.json` | B6/C1の内訳・旧表との差・予約番号、Q9三案の増分。いずれも実測ではない |
| `review-language.md` | 独立レビューと修正後の再読。R1〜R5は解消済み |
| `review-q9.md` | 制限した(a)と(b)/(c)、件数・費用・未確認の独立レビュー |
| `update_language.py` | 最初のlanguage-rulesの更新を行ったスクリプト。以後のレビュー修正は本文へ直接反映したので再実行用ではない |
| `check_documents.py`・`document-check.json` | 最終文書のハッシュ、局所リンクの存在、コードフェンス、問い表Q9のみ、決定表13件、絶対パス/todoリンク、git差分の空白と変更範囲の静的な照合 |

Q9の集計は再実行して同じ693宣言・502定理・94定理ファイルを得た。コメント・文字列・自身の宣言名を除く直接の参照であり、Leanの依存解析でも変更確定数でもない。S8の306定理とは語と対象が違うので足さない。

## レビューへの対応

| 指摘 | 反映 |
|---|---|
| language R1:現行名 | host_word/host_pattern、ScopeError.InvalidPattern/InvalidTargetへ修正し、成功/OutsideScopeへの変化を記した |
| language R2:数値ホスト名 | 四要素のIP候補とそれ以外の既存ホスト名を分離。Scopeと新RequestInの受理集合の差を明記し、wildcardの例を修正した |
| language R3:証明境界 | 解析済みの族・バイト列/数値・prefix区間までをLeanの対象とし、文字列parser/formatterの新規証明は入れない前提へ統一した |
| language R4/R5:決定と参照 | Q14の再判断を求める文を計画レビューの対象へ変更。06-03:28とip-research.mdへの参照へ修正した |
| q9:対象位置 | 宣言表/署名から捕捉引数列まで位置を保ち、認定位置だけR→Sへ移す。辞書の前置と他の引数の潜在効果を分けた |
| q9:異Tの原子 | 同名異Tの複数原子も、節のSを決める際は複数としてTopにする |
| q9:操作値と代入 | 16の設計の入口と別にVal.op・Val.substTyAt・操作の捕捉・OpDecl.Scopedの4点を優先点検先へ追加した |
| q9:見込みの確度 | 「少なくとも」を除き、すべて工程からの未実測の幅として記した |

未確認を解消したとはしていない。Rust/Leanの新実装、文字列parserのRFCとの一致、32ビット構成、正確な定理変更数、各作業と検査の実時間、由来表示の完全性は本文末尾へ残した。静的な照合スクリプトは処理系のテストではない。
