# D2b Declarations とソース照合の checker

## 目的と変更

D2a の任意の view に対する健全性を、表層のソースの match/bind と checker へ接続した。開始時の HEAD は `ce2deb8884ab5e0a54c98b3bae864592ccd8033c`、作業ツリーは clean だった。

実装前に design.md「形式化と受け渡し」、R10、P2 の `ViewExhaustive` の差分案、現在の checker・型保存と D2a の定理を自己確認した。完全な宣言表の存在と view 付き判定の成功を追加条件とし、現在の値についての網羅性を導く。将来の形を現在の値とする仮定や、view が閉じているという健全性の前提は加えない。自己確認を所定の外部レビューや設計者の合意とは扱わない。レビューの順序との差は R28 に記す。

| ファイル | 変更 |
|---|---|
| `Surface/Syntax.lean` | 閉じた既定の Declarations.view、ViewExhaustive と現在の Exhaustive への導出、view に依存しない全宣言の射影 |
| `Surface/Typing.lean`、`Lemmas/Typing.lean`・`BlockSequence.lean` | ソースの match と bind/shadow の追加条件、元のコアへの型保存 |
| `Surface/CheckPatterns.lean` | ソースの判定は D.view、record 更新・try の内部判定は明示的な closedView、追加条件と現在の網羅性の各健全性補題 |
| `Surface/CheckSoundCollections.lean`・`CheckSoundSequence.lean` | checker の成功から ViewExhaustive を作り、表層の型付けへ接続 |
| `Surface/CheckLemmas.lean`・`CheckTablesSound.lean` | view を替えた入力にも宣言の原子集合と構成子の完全性を渡す補題。有限の材料からの input_sound に接続 |
| `Surface/CheckExamples.lean` | 閉じた view と外部 view の独立した checker の評価例 |
| `Surface/Lemmas/Records.lean` | getter がソース条件を通さず、現在のコアの Exhaustive を使う理由のコメント |
| `docs/design/01-spec/01-12-core-calculus.md`、`02-impl/02-05-typechecker.md`、`07-quality/07-04-formal-semantics.md` | 先行モデルの写し、追加条件、合成照合、未接続範囲 |
| `p2/formal.md`、`decisions.md`、この記録 | 実際の定義・言明、R28、検査と申し送り |

上の Lean パスは `formal/Benitoite/` 以下である。Program の本体ごとの view、Exchange の形式、Rust の実装は変えていない。getter は元からコアの照合を直接生成し、view を読む判定器を呼ばないため、新しい判定入口を作らず従来の網羅性証明を保った。CtorsComplete・Inhabits・Exhaustive・C-Match と燃料の契約は変更していない。

## test-audit の作成時の関門

1. 主となる公開境界は Surface.Check の checkExpr/checkBlock である。同じ宣言のソース照合に本体の view が作用し、内部の合成照合は閉じたままである契約を守る。
2. source match/bind で view を落とす退行、内部の record 更新/Result・Option の try に外部の view を誤適用する退行を捕まえる。bind/shadow と、最後の束縛/続きを持つ束縛の両経路を確かめる。
3. 既存の CheckExamples の準備と表形式を拡張する。Release の例は checker が宣言表から view を選ぶ誤りに届かず、旧 checker の例は閉じた view しか持たない。ソースの全列挙の拒否は正確な理由と位置を比較し、包括分岐と内部照合の成功は型とエフェクトも比較する。
4. テスト専用の公開 API・フラグ・差し込み口は加えない。Declarations.withView と証明の補題は本体ごとの指定へ接続するためのものである。

機能の先行接続であり、不具合の修正ではない。既存のテスト・assert・期待値・ignore・対象外理由は変更していない。仕様上の診断変更もない。Rust の本番コードとテストの差分はともに 0 行である。

## 検査

実行前に検査内容と形式化の所要時間を報告した。指定に従い scripts/check.sh（dry-run を含む）と gc-stress の構成は実行しない。最終の検査結果は以下に記す。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功。1,156 passed、0 failed、既存の ignored 21。72.83 秒 |
| `cargo test -p benitoite --test spec_examples --test skill_docs` | 成功。spec_examples 7 件、skill_docs 8 件。文書の最終修正後も再実行して成功 |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check` | 成功 |
| `formal/` で `lake build` | 成功。159 jobs。コメント修正を含む最終ツリーでも再実行して成功。追加した三つの checker の評価例も通過 |
| `lake env lean /private/tmp/benitoite-d2b-axioms.lean` | 成功。新しい射影・追加条件・健全性と既存の checker/型保存の公理依存を確認 |
| `bash scripts/check-formal.sh` | 成功、終了状態 0。coverage_export 2 件、desugar_export 15 件、独立した Python の検査 4＋12 件と六入口の一致を確認 |
| `git diff --check` | 成功 |

`#print axioms` で確認した依存は従来の `propext`・`Classical.choice`・`Quot.sound` の範囲である。八つの宣言の射影の等式は公理に依存しない。新しい axiom・sorry・admit・native_decide は加えていない。既存の評価例に削除行はなく、CheckExamples に準備を含め 55 行・三つの表の例を追加した。Lean の定義・証明は差分で 85 行増、評価例は 55 行増である。

### 六入口の件数と分類

出力は `target/desugar-diff/run-53412/` と `target/coverage-diff/run-53412/` にある。実行ログは前者の `d2b-check-formal.log`、公理依存は `d2b-axioms.log`、最終ビルドは `d2b-final-build.log` に保存した。

| 入口 | 結果 |
|---|---|
| desugarDiff | golden 955＋random 72,778＝73,733 定義が一致。定義の mismatched/outOfScope/excluded は 0。プログラムは golden matched 346・既存の検査エラーによる除外 381、random matched 1,000・除外 0 |
| builtinCheck | 1,346 プログラム、72,316 比較が一致。不一致・非収束 0 |
| coverageDiff | 境界 20＋random 10,000＝10,020 件、および named の独立入力 2 件が一致。不一致・燃料切れ 0 |
| coverageProgramDiff | match 16,405＋binding 6,033＝22,438 件が一致。不一致・対象外・燃料切れ 0 |
| surfaceCheck | 全 1,727 入力を単独入口でも照合。named の独立入力と個別の分類理由も維持 |
| surfaceCheckAll | matched 51,636・outOfScope 19・q11 1（全検査 51,656）。不一致・準備失敗・lazyRestriction は 0 |

最終の check_named.py は全 1,727 入力・73,733 定義・22,438 網羅性項目の識別子・件数・分類を固定 manifest と照合した。幅付き 3 入力・30 定義も一致し、破損入力は契約の改変 3 件、hole/pipe の改変 6 件、named export の改変 6 件を意図した理由で拒否した。corpus・型表・網羅性の版は 8/2/2 のままである。六入口の対象内件数・対象外理由・破損入力の拒否を減らしていない。

## 計画との差と申し送り

実装の範囲と規則に計画との差はない。所定の外部レビューと設計者の合意の完了記録を確認できなかったため、レビューを証明より先に行う順序との差を R28 の推す案に残した。自己確認を承認と扱わず、定義・言明の所定のレビューをオーケストレータへ申し送る。

D2c では Program の関数・実装メソッドの本体ごとの指定と declarationsFor を追加する。Declarations.withView_* は全宣言の射影、Input.Sound.withView は checker の入力の契約、constructors_withView_sound は有限の材料から得る完全性に使える。現在の Program.declarations、Def/ImplDecl.WellTyped、型保存と全プログラムの checker はまだ閉じた既定のままであり、本体ごとの指定への切り替えは行っていない。D3 の六入口の版の更新も先取りしていない。

scripts/check.sh と gc-stress の構成の検査は、依頼どおりオーケストレータが最後に実行する。コミットと docs/todo/ の変更は行っていない。
