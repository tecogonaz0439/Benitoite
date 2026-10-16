# D6b corpus 9・型表 3・網羅性 3 の出力

## 目的と変更

AGENTS.md、共通の関門 K、D6b、design.md の変更表・パッケージ境界・形式化と受け渡し、R12・R33〜R36、Z2 の確認を読み、通常の Rust の交換出力を 9/3/3 へ接続した。ソースの属性はまだ受理しない。

| ファイル | 変更 |
|---|---|
| `tests/desugar_export.rs`、`tests/desugar_export/{exchange,named,builtins}.rs` | 全出力を 9/3/3 に更新。宣言側の package、解決済み BindingId による builtin、型の表示名と record・extensible の印、本体ごとの view を追加。補充した標準型を含め、dataTypes を dataDecls と同じ宣言順から作る。外部パッケージの IOErrorKind の正の入力と、外部から参照する定数の所属を確認 |
| `tests/coverage_export.rs` | 通常と view 付きの両方を網羅性3で出力。既存の閉じた乱択1万件と view 付き1万件を保持 |
| `tests/desugar_export/{check_named.py,exchange-manifest.json,routing-manifest.json}` | width・named・全件の版の固定値を更新。外部パッケージの正の出力を入口で検査し、IOErrorKind の指定漏れの拒否も確認。既存の件数・対象外理由は維持 |
| `formal/Benitoite/Exchange/{Version,Builtins}.lean`、`formal/CoverageDiff/Main.lean` | builtin の一意性・stdlib 所属と構成子の形、corpus9 の定数内のソース照合・束縛の禁止を検査（R38） |
| `formal/tests/test_extensible_exchange.py` | 既存の表を拡張し、必須情報・型表不足・旧版への新版情報の混入と、Z2の破損入力を検査 |
| 01-12・02-05・07-04、改造の plan・decisions・G2-report | 接続済みの出力と定数の適用範囲を反映し、Z2 の軽1〜4への対応を追記 |
| `scripts/check-formal.sh` | 旧版を通常出力とするコメントだけを現在の状態に合わせた。検査の実行内容は変更していない |

`tests/` は `crates/benitoite/` の下を指す。Rust の本番コード、parser、標準ライブラリの宣言、Lean の型付け規則・定理は変更していない。新しい axiom・sorry・admit・native_decide はない。

## test-audit の作成時の関門

1. 主となる境界は、Rust が書き出した交換ファイルを読む六つの CLI の公開入口である。守る契約は、型と本体の所属から決めた view・型表・版が一致し、旧版の閉じた意味を保つことである。
2. 捕まえる退行は、依存の本体から見た標準型の view の欠落、定数の所属を使用側で上書きすること、二つの型表の順序・集合の不一致、標準型の印の重複・所属や構成子の偽装、定数に隠したソース照合である。
3. 既存の六入口の表を拡張した。新しい Rust の正の入力は実際の依存パッケージの読み込み・名前解決から作り、既存の書き出し経路を使う。手書きの独立入力だけでは、Rust の接続の欠落を捕まえないためである。属性未受理の期間に限り、検査済みの ADT 表に拡張指定を直接設定する。
4. 本番の公開 API・フラグ・差し込み口を加えていない。既存の assert・期待結果・ignore を保持し、版の固定値だけを仕様に従って更新した。削除したテストと削除候補はない。Rust の本番コードは追加0行・削除0行、Rust のテストは追加243行・削除49行である。削除行は版・出力欄の更新と整形による置き換えであり、assert は削除していない。

修正前の Lean の実行ファイルで追加の負の入力を実行し、coverageDiff が builtin の重複・非標準所属を受理すること、corpus を読む入口が未使用の定数内のソース照合を受理することを確認した。修正後は意図した理由で拒否する。退行確認のログは `/private/tmp/d6b-before.log` にある。

## 診断と計画との差

ソースの診断のコード・主文・help・位置・終了状態は変わらない。交換の破損入力は準備の失敗として終了状態2を返す。既存の正負検査は維持した。

R38 は Z2 の軽1・4を実装するための補足である。corpus には構成子表がないため、builtin の一意性と所属は全入口で、構成子の表示名と形は型表を持つ入口と網羅性の単独入口で検査する。型表3に constructorName を追加し、標準型の印を持つ構成子では必須とする。確認の写しの Err は実装済みの Error とした。型付け規則や証明の変更はない。

## 検査

実行前に内容を報告した。指定に従い `scripts/check.sh`（dry-run を含む）と gc-stress の構成は実行していない。結果は下に記す。

初回の `check-formal.sh` は全件の脱糖・宣言表・網羅性・表層型検査と 1,727 入力の個別照合を通ったが、最後の named-corpus.json の検査で必須の package・coverageView の欠落を検出し、終了状態1となった。名前付き関数型用の独立した小さな書き出しにも二欄を明示して修正した。期待結果と既存の assert は変更していない。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功。1,159 passed、0 failed、既存 ignored 21。70.92秒 |
| `cargo test -p benitoite --test coverage_export --test desugar_export --test spec_examples` | 成功。1＋15＋7 passed、0 failed、既存 ignored 2。期待結果と assert は維持 |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし。11.55秒 |
| `cargo fmt --all --check`、`git diff --check` | 成功 |
| `bash scripts/check-formal.sh` | 最終ソースを固定して全体を再実行し、終了状態0。全書き出しの Rust テスト16件、六入口の比較、新旧版の正負入力が成功 |
| `lake build`（`formal/`） | 成功。162 jobs。新しい axiom・sorry・admit・native_decide、定理の変更はない |
| `python3 -I formal/tests/test_extensible_exchange.py` | 最終の版と構成子の検査で22テスト成功。名前・型引数・引数型・record の印・構成子数・表示名欠落も含め、意図した理由の拒否を確認 |

最終の形式化検査のログは `/private/tmp/d6b-formal-final.log`、出力は `target/desugar-diff/d6b-final/` と `target/coverage-diff/d6b-final/` にある。最終の lib・統合テスト・Clippy・fmt の後は、Rust・Lean・検査入力・スクリプトを変更せずに再実行した。

| 六入口の比較 | 結果 |
|---|---|
| coverageDiff | 通常の網羅性3は10,020件、view付きは10,016件一致。不一致・燃料切れ0。閉じた乱択1万件とview付き1万件を保持 |
| desugarDiff | goldenの346入力・955定義、randomの1,000入力・72,778定義が一致。対象外0。元から静的エラーで除く381入力を保持 |
| builtinCheck | 1,346入力、型の要約72,316件。不一致・非収束0 |
| coverageProgramDiff | match 16,405件・binding 6,033件、計22,438件一致。対象外・不一致・燃料切れ0 |
| surfaceCheck・surfaceCheckAll | 単一入口と全件入口の結果が一致。matched 51,636、outOfScope 19（既存のunknown primitive）、q11 1、lazyRestriction・preparationFailure・mismatched 0。対象外の理由も全文一致 |
| 最終の版・件数・破損入力 | 1,727入力・73,733定義・22,438件の網羅性入力が既存manifestと一致。手書きの正負検査4＋12＋22テスト、契約3件・hole/pipe 6件・名前付き呼び出し6件、実際の外部パッケージのIOErrorKindの指定漏れを意図した理由で拒否 |

`routing-manifest.json` の既存1,727件は版8→9だけが変わり、他の値は一致することを構造比較した。`exchange-manifest.json` も版の固定値と新しい正の入力1件を除き、既存の件数・分類・対象外理由は同一である。

## 申し送り

D6c で属性を受理した時点から、今回の通常出力にも宣言の extensible と本体の view が反映される。型表を直接作る独立入力では true も検査する。属性の受理、標準の失敗型への指定と Skill の抽出は今回変更していない。コミットと docs/todo/ の変更は行っていない。
