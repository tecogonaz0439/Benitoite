# B2 die の型規則と性質 1

## 実装前の確認

開始時の HEAD は `46ebab0b1dd5b7ecde8d5e0059ca9e9b478b3f78`、作業ツリーは clean だった。B1 の二構文・脱糖・Scoped・AtomsIn と、design.md「型・エフェクト・書く位置」「Lean の定義と証明」、R3・R8・R14〜R16・R48 を確認した。今回の B2 の実装指示に従って型規則と証明を接続する。所定の外部レビューの完了を、この実装者の自己確認からは主張しない。

Result/Option の die の結果は成功型 T、効果は入力の効果と Process.Exit の和とし、囲む R を制限しない。説明は C・hideConts Γ・R=None・非末尾位置で純粋な String とする。辞書とメソッドは既存の宣言表の一引数の純粋な String の契約を検査し、exit は組み込み表の種類・所属エフェクト・具体化後の型を検査する。識別名の標準束縛との対応は R49 に記す。既存の Return の規則と最終定理の前提・結論を変えない。

## test-audit の作成時の関門

1. 主となる境界は Lean の HasType と HasType.desugar である。die の型・効果・任意の R、説明の純粋性と境界、辞書と終了操作の契約を確かめる。
2. 捕まえる退行は、die に囲む Result/Option の戻り値を要求すること、Option に Show を要求すること、説明から外側へ return/resume を許すこと、内側の lambda の return を禁じること、入力や説明の移動で型を失うことである。
3. B1 の独立例は構文の脱糖と未受理の checker を検査するが、型規則の導出と型保存を確かめない。既存の Examples の独立例へ今回の型付けの例を加える。checker の成功・条件ごとの拒否は B3 の境界に残し、同じ準備を Rust に重ねない。
4. 本番の差し込み口・公開 API・フラグを増やさない。補題は実際の型保存の証明で使用する。

未接続の型規則の追加であり、不具合修正の退行テストではない。既存の assert・期待値・ignore・件数・対象外理由を変えない。利用者向けの診断変更はない。

## 変更したファイル

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Surface/Typing.lean` | `DieShowOk`・`DieExitOk` と `E_TryResultDie`・`E_TryOptionDie` |
| `formal/Benitoite/Surface/Lemmas/ReturnTry.lean` | R=None の計算の戻り先の変更、説明の環境の移動、失敗側と Result/Option の型保存 |
| `formal/Benitoite/Surface/Lemmas/Typing.lean` | 二場合を全構文の型保存へ接続。既存の Return の証明は変更しない |
| `formal/Benitoite/Surface/Lemmas/Scoped.lean`・`Invariants.lean` | 説明と辞書を含む型・エフェクト変数の範囲保存と結果型の不変条件 |
| `formal/Benitoite/Surface/Examples.lean` | 型付けと型保存の独立例。任意の R、Option の辞書不要、説明の自由変数、lambda の独立の境界、直接 return・外側の resume の拒否、Show のないエラーの従来の伝播 |
| `docs/design/01-spec/01-12-core-calculus.md`・`07-quality/07-04-formal-semantics.md` | 二規則・検査条件・型保存の写しと未接続の範囲 |
| `decisions.md`・`b2/` | R49、作成時の関門、作業結果、公理依存の確認用入力と出力 |

処理系の Rust、checker の受理、Exchange、標準ライブラリ、診断、六入口の入力一覧と版は変更していない。`ShiftClean`・`SubstClean` はコアの型と置換についての全場合の補題であり、コアの構文・型・置換を変えないため変更を要しない。`Extensions*` と Program の証明も、更新した全構文の型保存・範囲保存を使い、そのままビルドできる。最終の `desugar_typed`・`surface_effect_soundness` と checker の健全性の宣言は変更していない。Lean の実装・補助証明は 291 行追加、独立例とその準備は 271 行追加、削除はともに 0 行である。

## 検査と結果

検査の内容と、六入口の検査が十数分を要する見込みを実行前に報告した。依頼に従い `scripts/check.sh`（dry-run を含む）と gc-stress は実行していない。構文の章・診断・標準ライブラリの生成元は変更していないため、Skill の再生成は不要である。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功。1,162 passed、既存の ignored 21、74.54 秒 |
| `cargo test -p benitoite --test spec_examples --test skill_docs` | 成功。15 passed、2 suites |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check` | 成功 |
| `formal/` で `lake build` | 成功。162 jobs。追加した独立例を含む |
| `bash scripts/check-formal.sh` | 成功、終了状態 0。coverage_export 2 件・desugar_export 17 件、交換形式の Python 4＋12＋22 検査と六入口の最終照合を含む |
| `formal/` で `lake env lean ../docs/2026-10-15-TODO-018_027_072_251-keywords-open-types-try-or/b2/axioms.lean` | 成功。主要定理・追加補題の 12 件は `propext`・`Classical.choice`・`Quot.sound` の範囲のみ。詳細は `axioms.txt` |
| `git diff --check` | 成功 |

最初の補題のビルドでは、固定された帰納型の添字での構造再帰と、任意の説明の Option を場合分けした後の再帰呼び出しで停止性を示せなかった。前者はストアと戻り先の等式を明示した一般の補題とし、後者は場合分けの前に子の型保存を導いて修正した。Option を含む脱糖の式を補助の等式で展開してから型付けを組み立てる。独立例の初回のビルドでは、宣言の簡約・範囲の Decidable の合成・逆転する場合の列挙の不足を修正した。いずれも規則・定理・期待する契約を弱めていない。新しい axiom・sorry・admit・native_decide はない。

### 六入口の件数と分類

出力は `target/desugar-diff/run-21644/` と `target/coverage-diff/run-21644/` にある。corpus・型表・網羅性の版は 9/3/3 のままであり、B2 の die の独立例は Lean の Examples で確認する。checker と交換形式は die の受理をまだ持たない。

| 入口 | 確認した結果 |
|---|---|
| desugarDiff | golden 968 定義＋random 72,778 定義＝73,746 定義が一致。定義の不一致・対象外・除外は全て 0。プログラムは golden matched 349・excluded 386、random matched 1,000・excluded 0 |
| builtinCheck | 対象 1,349 入力、72,468 比較、不一致・非収束 0 |
| coverageDiff | 閉じた境界 20＋random 10,000＝10,020 件と、view 付きの境界 28＋random 10,000＝10,028 件が一致。不一致・燃料切れ 0 |
| coverageProgramDiff | 22,453 件が一致。不一致・対象外・燃料切れ 0 |
| surfaceCheck | 全 1,735 入力の単一入口の結果が固定 manifest と一致。既存の個別の失敗は理由を含めて完全一致 |
| surfaceCheckAll | matched 51,645・outOfScope 19・q11 1。不一致・準備失敗・lazyRestriction 0 |

Rust の書き出しは 562 秒、脱糖の比較は 25 秒、プログラム単位の網羅性の比較は 1 秒、表層の全件検査は 19 秒だった。交換形式の Python の 4＋12＋22 検査も成功した。最終照合は 191 秒で成功した。開始時の二つの manifest を一切変更せず、1,735 入力・73,746 定義・22,453 網羅性入力の識別子・分類・件数を照合した。対象外と q11 の全入力・定義・理由も完全一致し、対象内件数を下げていない。契約の破損 3 件、hole/pipe の破損 6 件、named export の破損 6 件を意図した理由で拒否した。外部の IOErrorKind の view と定数の所属も一致した。検査ログは `target/desugar-diff/run-21644/b2-check-formal.log` に保持する。

## 計画との差と申し送り

R49 に、抽象的な識別名と標準束縛の名前解決の境界を補足した。実際の辞書の型とメソッドの宣言、終了操作の種類・型・効果を検査する範囲はこの作業で実装した。所定の外部レビューの完了は確認しておらず、B1 の R48 とともにオーケストレータへ引き継ぐ。実装者の自己確認と Lean のビルドを、所定レビューの完了と扱わない。

B3 は現在の checker の明示的な拒否を、二規則の条件を検査する正式な受理と健全性に置き換える。説明は hideConts Γ・R=None・非末尾位置の純粋な String とし、die に囲む R の一致を要求しない。辞書の対象型・メソッドの戻り型と効果・exit の条件を一つずつ壊した入力も確認する。B4 は corpus 10 と六入口、B10a-3 は標準束縛の識別名の書き出しを接続する。説明の直接の try 全般の構文の拒否と、評価順・報告の実行の観測は後続の担当に残る。コミットと docs/todo/ の変更は行っていない。`scripts/check.sh` と gc-stress は依頼どおりオーケストレータへ引き継ぐ。
