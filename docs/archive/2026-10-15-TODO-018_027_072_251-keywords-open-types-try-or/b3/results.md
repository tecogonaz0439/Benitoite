# B3 die の表層検査と健全性

## 実装前の確認

開始時の HEAD は `e42a10f854dca5083f2bb837639434191a84cd82`、作業ツリーは clean だった。AGENTS.md、plan.md の B3 と共通の関門 K、design.md「型・エフェクト・書く位置」「脱糖とコード生成」「Lean の定義と証明」、B2 の記録と R49 を確認した。B2 の型規則・型保存の証明を変更せず、checker の受理とその健全性を接続する。

Result/Option の die の結果は成功型 T、効果は入力の効果と Process.Exit の和である。囲む R は制限しない。Result はエラー型 E を対象とする辞書と純粋な String のメソッドを検査し、Option は辞書を要求しない。exit は既存の種類・所属・具体化した型・admits を検査する。説明は hideConts Γ・R=None・非末尾位置の純粋な String とする。所定の外部レビューの完了は、B1/B2 と同様に今回の自己確認から主張しない。

## test-audit の作成時の関門

1. 主となる境界は Lean の `checkExpr` と `checkDef`、`CheckTables.checkProgram` である。受理した型・効果と、拒否した位置・理由を検査する。
2. 捕まえる退行は、die に囲む Result/Option の戻り値を要求すること、Option に辞書を要求すること、入力の効果を落とすこと、誤った辞書・メソッド・exit を受理すること、説明から外側への return/resume を許すこと、説明内の lambda の return を禁じること、die の接続によって実装メソッドの契約名の検査を飛ばすことである。
3. B2 の型付けの独立例は checker を呼ばない。既存の `CheckExamples.lean` へ、同じ有効な準備から一条件ずつ変える表を追加する。既存の裸の try の表は保持する。全プログラムでは、式単独では確認できない実装辞書の解決・メソッドの実名の照合を検査する。
4. 本番の差し込み口・公開 API・フラグは増やさない。新しい補助は実際の checker と全構文の健全性の証明で使う。

新機能の接続であり、不具合修正ではない。独立した負の例は有効な対照から一条件ずつ変え、期待する拒否位置と理由を等式で固定する。既存の assert の削除・比較の緩和・ignore の追加・件数や対象外理由の下方修正はない。

## 変更したファイル

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Surface/Check.lean` | 二つの die の受理、`checkDieShow`・`checkDieExit`・`checkDieMessageR` |
| `formal/Benitoite/Surface/CheckSoundDie.lean` | 辞書・終了操作・説明の検査の健全性と、二規則への接続。新しい補助ファイル |
| `formal/Benitoite/Surface/CheckSoundControl.lean` | 二つの未受理の場合を、正式な受理の健全性へ接続 |
| `formal/Benitoite/Surface/CheckExamples.lean` | 受理・条件ごとの拒否・全プログラム・実装メソッドの契約名の独立例 |
| `docs/design/01-spec/01-12-core-calculus.md`・`07-quality/07-04-formal-semantics.md` | checker の条件と保証の写し、処理系・交換形式への未接続の範囲 |
| `b3/` | 作成時の関門、結果、公理依存の確認用入力と出力 |

`CheckPredicates` の die を必ず抜ける文に数えない判定は B1 で接続済みである。`CheckInduction` は任意の環境・戻り先・状態を量化する既存の強い相互帰納法を使い、任意の説明の子の健全性もそこから導く。`CheckProgramSound` のプログラム全体・信頼表付きの型付け・実装メソッドの名前一致の定理は宣言を変えずにビルドする。Rust・交換形式・六入口の manifest は変更しない。

誤りの経路は入力 0・説明 1 を既存の `SurfaceCheck.walkExpr` と合わせ、Result の辞書を子 2 とする。型付けの成功の証明では、有限の原子集合上の比較を既存の `Input.Sound` の条件で実際の型・効果の等式へ戻す。新しい信頼条件は加えない。

## 診断の変更

利用者向けの診断コード・主文・help・主/副位置・CLI の終了状態は変更しない。Lean の checker の内部の誤りだけが変わる。

| 入力 | 旧 → 新 | 理由と元の検査の維持先 |
|---|---|---|
| 構成子の宣言のない Result/Option の die。説明なし／空文字列の説明あり | `[]: die typing is not supported yet` → `[]: unknown Result success constructor`／`[]: unknown Option success constructor` | B3 で正式に条件を検査するため。同じ四入力を同じ公開入口で拒否し、位置と理由を厳密に比較する |
| 有効な宣言・辞書・exit を持つ die | 一律の未対応の拒否 → T と入力の効果 ∪ Process.Exit を返す | 任意の R・位置・説明を持つ表、入力に A の効果がある対照、実装辞書を持つ全プログラムで確認する |

上表は仕様上の新しい期待値への変更であり、既存の比較を緩めたものではない。構成子・辞書・メソッド・exit・説明の条件ごとの負の例も追加する。裸の try の受理・拒否は変更しない。

## 検査と結果

検査の内容と、六入口の形式化検査が十数分を要する見込みを実行前に報告した。依頼に従い `scripts/check.sh`（dry-run を含む）と gc-stress の構成の検査は実行していない。構文の章・診断の表・標準ライブラリの生成元を変更しないため、Skill の再生成は不要である。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功。1,162 passed、既存の ignored 21、72.03 秒 |
| `cargo test -p benitoite --test spec_examples --test skill_docs` | 成功。15 passed、2 suites |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `formal/` で `lake build` | 成功。163 jobs。追加した検査例を含む |
| `bash scripts/check-formal.sh` | 成功、終了状態 0。coverage_export 2 件・desugar_export 17 件、交換形式の Python 4＋12＋22 検査と六入口の最終照合を含む |
| `formal/` で `lake env lean ../docs/2026-10-15-TODO-018_027_072_251-keywords-open-types-try-or/b3/axioms.lean` | 成功。追加補題と主要定理 14 件は `propext`・`Classical.choice`・`Quot.sound` の範囲のみ。詳細は `axioms.txt` |
| `cargo fmt --all --check` | 成功 |
| `git diff --check` | 成功 |

途中の証明の確認では、任意の説明を持つ `Expr.AtomsIn` の定義を直接簡約できず、証明の elaboration が上限に達した。Option を場合分けして生成された等式を使う小さな補題へ分け、既定の上限で通るようにした。最終の補題に計算量の上限の変更はない。独立例の初回の確認では、準備の構文の字下げと実装メソッドの拒否位置を修正した。網羅性の負の例は、構成子一覧を欠落させると健全性の前提を満たさなくなるため、宣言と一覧の両方へ第三の構成子を加えた有効な入力で拒否を確認する。検査対象の条件や期待する契約を弱めていない。

### 六入口の件数と分類

出力は `target/desugar-diff/run-25275/` と `target/coverage-diff/run-25275/` にある。corpus・型表・網羅性の版は 9/3/3 を保つ。die の新しい受理は Lean の独立した表層入力で確認し、交換の接続は B4 に残す。

| 入口 | 確認した結果 |
|---|---|
| desugarDiff | golden 968 定義＋random 72,778 定義＝73,746 定義が一致。定義の不一致・対象外・除外は全て 0。プログラムは golden matched 349・excluded 386、random matched 1,000・excluded 0 |
| builtinCheck | 対象 1,349 入力、72,468 比較、不一致・非収束 0 |
| coverageDiff | 閉じた境界 20＋random 10,000＝10,020 件と、view 付きの境界 28＋random 10,000＝10,028 件が一致。不一致・燃料切れ 0 |
| coverageProgramDiff | 22,453 件が一致。不一致・対象外・燃料切れ 0 |
| surfaceCheck | 全 1,735 入力の単一入口の結果が固定 manifest と一致。既存の個別の失敗は理由を含めて完全一致 |
| surfaceCheckAll | matched 51,645・outOfScope 19・q11 1。不一致・準備失敗・lazyRestriction 0 |

Rust の脱糖 corpus の書き出しは 557 秒、脱糖の比較は 25 秒、組み込み表の比較は 17 秒、プログラム単位の網羅性の比較は 1 秒、表層の全件検査は 19 秒だった。最終照合は 189 秒で成功した。開始時の二つの manifest は変更せず、1,735 入力・73,746 定義・22,453 網羅性入力の識別子・分類・件数が一致した。既存の対象外と q11 の入力・定義・理由も完全一致し、対象内件数を下げていない。契約の破損 3 件、hole/pipe の破損 6 件、named export の破損 6 件を意図した理由で拒否した。外部の IOErrorKind の view と定数の所属も一致した。ログは `target/b3-check-formal.log` に保持する。

## 計画との差と申し送り

計画からの仕様上のずれはない。条件ごとの健全性と二規則への接続を、新しい `CheckSoundDie.lean` に分けた。型規則・型保存・最終の checker とプログラムの健全性定理の前提・結論は変えていない。新しい axiom・sorry・admit・native_decide は加えていない。

B4 は corpus 10 と六入口への交換の接続を担当する。B10a-3 は標準束縛の識別名から参照を書き出す。R49 の抽象名と標準束縛への名前解決の境界、R48 の所定レビューの引き継ぎは維持する。今回の実装・自己確認を所定レビューの完了と扱わない。コミットと docs/todo/ の変更は行っていない。
