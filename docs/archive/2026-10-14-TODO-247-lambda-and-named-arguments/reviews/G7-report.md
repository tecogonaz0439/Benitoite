結論: 診断の旧→新の対応表は承認してよい。表は網羅的で、どの付け替えも言語の規則の変更から必然（.diag.json のコード列の変更は types/arity の E0402 → E0453 の 1 件だけ。内容の変更は secf1-effect-confusion・secf1-value-confusion、traits の型表示 3 件、ラムダの表示名の位置、uses_then_bracket の修正案の終端で、どれも記録と一致。.exit の変更なし、#[ignore] の追加やテスト関数の削除なし、削除した assert 3 件は同じ意味の assert に置き換わっている）。

- 中: typeck/consts.rs の eval_call（Ctor・Map/Set.fromList の分岐）と bad_shape（Arg::Named は Some(a.name.span)）。R81 で名前付きに対応したのは absolute・floorDivide・floorModulo だけ。01-02 は一引数を `f(value: e)` とも書けると定めるのに、`const m = Map.fromList(pairs: [...])` は定数の形の誤りになり、W0403（鍵の重複）も出ない見込み（机上の推測）。修正案: 再現テストで確かめ、numeric_argument と同じ扱いを fromList・構成子と定数の形の検査にも入れる。
- 低: testdata/types/arity.diag.json は E0453 に変えて副の位置「function declared here」がなくなった。修正案: 対応表の行に一言書き足す（または E0453 に宣言の位置を副として付ける方が利用者に親切なら、そうする。推す案を選んで書く）。
- 低: testdata/handlers/secf1-*.diag.json の流出の検出が resume(p) に移った。引数の位置で直接拒否する検査は secf1-nested-escape に残り SEC-F1 の保証は保たれるが、検出の場所が制約を解く順序に依存することが明文化されていない。修正案: N33 の後にも同じ位置で検出されるかを確かめる項目を plan.md の N33 の完了条件に書き足す。
- 低: 設計書と実装の食い違い（N31）。パイプと穴の経路で実装済みの E0449 が 02-10 の診断の列挙（E0450〜E0456）にない。01-02 は複数引数の位置指定の通常呼び出しを受理するのか（R78 の暫定差）書いていない。修正案: E0449 を 02-10 に加える。暫定差は設計書でなく改造のディレクトリに記録し、N33 で解消されることを確かめる（n33-final-design.patch に含まれているか確かめる）。
- 低: testdata/types/named-required-pipe.bnt の spec の印が「01-06 関数の型とエフェクト」だが規則は 01-02「パイプ」と「名前付き引数と関数型」。修正案: 印を 01-02 の節へ直す。

問題のなかった観点: R81 の consts.rs の補正、Z7（8 ファイルの SHA-256 一致、件数と Lean の六入口の維持。ただし N29 で生成入力が新形式へ移り、全件テストの件数の assert は旧形式だけを数える。代わりに manifest の厳密な照合がある）、N30 の例と参照解、N31 の形式規則の写し、AGENTS.md の規約。

## 対応

- 診断対応表の承認案: decisions.md の R90 に、G7 の評価にもとづく承認案と設計者の確認待ちを記録した。
- 中・定数と重複鍵: typeck/consts.rs の形の検査・構成子の引数取得・fromList の評価と警告を補正し、typeck/tests.rs に修正前に失敗する退行テストを追加した。直接の構成子への名前指定は仕様の E0456 を維持する（R91）。
- 低・arity の副位置: design.md の対応表と n28/expectation-changes.json に「function declared here」がなくなることを明記し、現行の E0453 の主位置と不足名を維持した（R92）。
- 低・SEC-F1 の位置: plan.md の N33 に、制約の解決順への依存と、二件の resume(p)・nested-escape の引数位置を厳密な golden で再確認する完了条件を加えた。
- 低・設計書との対応: 02-10 にパイプ・穴の E0449 を補い、R78 の暫定差を R92 と N33 の条件で確認した。n31/n33-final-design.patch は一律拒否を既に含み、今回の行の補足へ追従した後も git apply --check が通る。
- 低・spec の印: testdata/types/named-required-pipe.bnt を 01-02「パイプ」「名前付き引数と関数型」へ直し、同じ字句の診断位置をコメントの増分だけ厳密に補正した（R93）。

検査: `cargo test -p benitoite --lib` は 1,153 passed・既存の 21 ignored、`--test named_arguments` は 15 passed、`BENITOITE_GOLDEN_FILTER=types/` と `handlers/` の `--test golden` は各 2 passed。`cargo clippy --all-targets`、`cargo fmt --check`、`git diff --check`、最終設計書 patch の `git apply --check` は成功した。追加した退行テストは修正前の失敗と修正後の成功を確認した。既存の assert の削除・期待値の緩和・ignore の追加はない。本番の Rust は差し引き 6 行増、Rust のテストは 84 行増である。formal/ と docs/todo/ は変更せず、scripts/check.sh・gc-stress は実行せず、コミットしていない。
