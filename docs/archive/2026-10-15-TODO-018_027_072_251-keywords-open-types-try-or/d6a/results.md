# D6a Rust の view・将来の形・診断

## 目的と変更

属性を未受理のまま、拡張指定を持つ型表と本体の所属から網羅性・束縛・到達可能性を判定できるようにした。AGENTS.md、共通の関門 K、D6a、design.md の変更表・パッケージ境界・判定と診断、decisions.md の R9・R12・R33〜R35 と G2 の合意、D5 の記録を確認した。

| ファイル | 変更 |
|---|---|
| `src/typeck/patterns.rs` | 公開の `check_match`・`check_binding` に view を追加。探索ごとに同じ参照を保持し、有用性・重なり・覆っている選択肢の探索へ適用。`Shape::Future(BindingId)` と data／record の表示を追加。反例の表示と将来の形の型の集合を各列・記憶・公開の結果に保持 |
| `src/typeck/pattern_ext.rs` | 本体の所属から作った view を match／bind に渡す。E0601/E0607 の副位置と型ごとの help を束縛番号から作る |
| `src/typeck/text.rs` | 将来の形の表示文言を、文言の規約に従いこのモジュールへ置く |
| `src/diag/codes.rs`、`skill/references/diagnostics.md` | 将来の形の help と宣言の副位置の文言を追加。Skill は生成器で更新 |
| `tests/coverage_export.rs` | 全呼び出し元へ明示的に view を渡す。既存の通常出力 2 と閉じた 1 万件を保持し、同じ型・パターンから拡張指定と作者側／外部側の view を持つ独立入力 3 を追加出力 |
| `scripts/check-formal.sh` | 独立入力 `future-corpus.json` も `coverageDiff` で比較し、不一致をスクリプトの失敗へ反映 |
| 02-05・01-12・07-04 | 接続済みの判定と独立入力を反映。属性と通常の交換出力は引き続き未接続である範囲を明記 |
| `decisions.md`、この記録 | R36・R37、関門への回答、診断の対応、検査と申し送り |

`src/`・`tests/`・`skill/` は `crates/benitoite/` の下を指す。parser・標準ライブラリ・Lean の定義と証明は変更していない。ソース由来の `extensible` は false のままであり、通常の書き出しは 8/2/2 を保つ。getter・record 更新・try の合成照合に将来の形は加えていない。

## test-audit の作成時の関門

1. 守る契約は、外部の拡張指定付き data／record の既知の構成子だけでは将来の形を覆わず、変数・`_` は覆うこと、および入れ子でも診断の型の出どころを保持することである。主となる境界は公開の `check_match`・`check_binding` と型検査が返す診断である。
2. 捕まえる退行は、入れ子や束縛への view の渡し忘れ、既知構成子の後の包括的な選択肢を誤って到達不能とすること、覆っている位置を閉じた判定から選ぶこと、反例の型情報の紛失、E0607 の主文の型と将来の形の型の混同である。作者側との対照と予算切れも確かめる。
3. 既存の表・アサーション・期待値は保持し、呼び出しへ空の view と期待する空の型集合を補った。新しい公開 API の表形式のテストを一つ、診断の接続の表形式のテストを一つ加えた。診断は本物の読み込み・名前解決・宣言の型を使い、拡張指定を直接設定した型表で本体を再検査する。API のテストだけでは捕まらない lowering・所属・主文・位置・help の接続を確認する。乱択入力は既存の型・パターンを再利用し、Lean の独立した判定と比較する。
4. テスト専用の公開 API・フラグ・差し込み口は追加していない。属性の本番受理を早めず、既存の宣言表と本体検査を使う。assert の削除、期待値の緩和、ignore の追加はない。

削除したテストと削除候補にしたテストはない。本番の Rust は 161 行追加・43 行削除、テストの Rust は 519 行追加・31 行削除である。削除行は引数・結果の型の拡張と整形に伴う置き換えである。新機能の実装であり、既存の不具合の退行修正ではない。初回のコンパイルでは既存の予算切れの厳密な比較に必要な `Witness` の PartialEq／Debug が不足していたため、比較を緩めず derive を加えた。

## 診断の対応

属性は未受理のため、ソースの既存入力の診断は変わらない。直接型表を作る独立入力で、次の追加の振る舞いを確認した。

| 対象 | 旧 → 新 | 主文・主位置・終了状態 | help と副位置 | 元の誤りの検査 |
|---|---|---|---|---|
| 外部の全既知構成子だけの match | 受理 → E0601 | 主文は既存の文言、主位置は照合する式。静的エラーの終了状態 2 は既存の経路のまま | 反例は data の `<future constructor of TypeName>`／record の `<future shape of TypeName>`。将来の形の型ごとに宣言の副位置と包括的なパターンの help。無効なパターン構文を示す `add_arm` は付けない（R37） | 既存の通常の非網羅の期待値と golden を維持。新しい表で作者／外部・data／record・入れ子を厳密に比較 |
| 外部の単一構成子を分解する bind | 受理 → E0607 | 主文の型は従来の show_type、主位置は左辺のパターン。静的エラーの終了状態 2 は既存の経路のまま | 既存の match の help に、将来の形の型の help と宣言の副位置を追加。外側の型と未来の型の名前を別の引数で扱う | 既存の refutable bind を維持。新しい表で外側の record の型と内側の将来の形の型も比較 |
| 全既知構成子の後の変数／`_` | E0602／E0608 → 受理 | 将来の形を覆う分岐・選択肢は到達可能 | 先行する包括的なパターンが覆う本物の重複は E0602／E0608 のまま | 新しい API の表で受理・重複・覆っている選択肢の位置を厳密に比較 |

新しい help の全文は `add an unguarded variable or '_' pattern to cover future values of '{future_ty}'`、副位置は `this type permits future shapes outside its package` である。置き換えの編集や分岐の本体は生成しない。

## 検査

実行前に内容を報告した。指定に従い `scripts/check.sh`（dry-run を含む）と gc-stress の構成は実行していない。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功。1,159 passed、0 failed、既存 ignored 21。73.28 秒 |
| `cargo test -p benitoite --lib typeck::` | 成功。111 passed、0 failed。13.03 秒。入れ子の診断の表を拡張した後には `--lib future_diagnostics` も 1 passed |
| `cargo test -p benitoite --test golden --test coverage_export --test skill_docs --test spec_examples` | 成功。4 suite 合計 18 passed、0 failed、既存 ignored 1。59.94 秒 |
| `cargo test -p benitoite --test coverage_export -- --include-ignored --nocapture` | 成功。2 passed。通常出力と独立した view 付き入力を生成 |
| `cargo clippy --workspace --all-targets` | 最終ソースで成功、指摘なし |
| `cargo fmt --all --check`、`git diff --check` | 成功 |
| `cargo run -p benitoite --example gen_skill` | 成功。生成物の差は診断リファレンスの 4 行だけ。生成後の skill_docs も上記の検査で成功 |
| `lake build`（`formal/`） | 成功。162 jobs。Lean の変更、新しい axiom／sorry／admit／native_decide はない |
| `bash -n scripts/check-formal.sh` | 成功 |
| `bash scripts/check-formal.sh` | 最終のスクリプトとソースを固定した再実行で成功、終了状態 0。全 Rust 脱糖出力のテスト 15 passed。六入口の全比較・件数・対象外理由・破損入力の拒否が一致 |

初回の `check-formal.sh` は、六入口の手書きの正負入力、新旧の網羅性比較、Rust の全脱糖入力の生成を通過した。しかし実行中に作業者がスクリプトのコメントを編集したため、Bash のファイルの読み込み位置がずれ、生成直後の行で `f: command not found`、終了状態 127 となった。検査の失敗として記録し、最終のスクリプトとソースを固定して全体を再実行した。テスト・件数・時間制限・対象外理由を変更して回避していない。

最終の形式化の検査結果は次のとおりである。ログは `/private/tmp/benitoite-d6a-formal-final.log`、全出力は `target/desugar-diff/run-76864/` と `target/coverage-diff/run-76864/` にある。

| 比較 | 結果 |
|---|---|
| 手順単独の網羅性 2 | 10,020 件一致、mismatched 0、fuelExhausted 0。既存の乱択 10,000 件と境界 20 件を保持 |
| 独立した view 付き網羅性 3 | 10,016 件一致、mismatched 0、fuelExhausted 0。乱択 10,000 件と境界 16 件。作者側 5,041 件、外部側 4,975 件。将来の形の反例 118 件、そのうち入れ子 21 件。予算切れ 0、最大の仕事量 2,714 |
| 脱糖 | golden の対象 346 入力・955 定義、random の 1,000 入力・72,778 定義が一致。対象外 0。元から静的エラーで除く入力 381 件を保持 |
| 宣言表 | 型の要約 72,316 件、不一致 0、非収束 0 |
| プログラム中の網羅性 | 1,346 入力、match 16,405 件・binding 6,033 件、合計 22,438 件一致。対象外・不一致・燃料切れはいずれも 0 |
| 表層型検査 | matched 51,636、outOfScope 19（全件 `unknown primitive`）、q11 1、lazyRestriction 0、preparationFailure 0、mismatched 0。対象外の理由は既存の manifest の全文と一致 |
| 単一入口と全件の照合 | 1,727 入力・73,733 定義・22,438 件の網羅性入力が manifest と一致。手書きの六入口の正負検査 4＋12＋19 テスト、契約 3 件・hole/pipe 6 件・名前付き呼び出し 6 件の破損入力が意図した理由で拒否された |

最終ソースの lib・統合テスト・Clippy・fmt の成功後に形式化検査を再実行し、その間に Rust・入力・スクリプトは変更していない。既存の assert と ignore の一覧、反例の従来の表示、通常の書き出しの版も差分で確認した。

## 計画との差と申し送り

R36 は、通常の出力の版を保ちながら追加の乱択比較を通常の形式化検査から実行する方法の補足である。R37 は、将来の形の表示を無効なパターン構文として勧めないための E0601 の help の補足である。いずれも推す案として記録した。

D6b は通常の出力を 9/3/3 へ切り替え、所属・builtin・view・型表示を揃える。独立した `future-corpus.json` とスクリプトの追加比較の扱いも揃えること。D6c の属性受理からは、今回接続した判定が適用される。標準ライブラリの宣言の文章／JSON の副位置の描画は D7、全実行経路の確認は D8 に残る。コミットと docs/todo/ の変更は行っていない。
