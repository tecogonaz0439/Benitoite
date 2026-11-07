# 群 G の実装結果

基準は `d9cf242d97ac3b93c439177da0e67a625a87f626`、ブランチは `m014/l70.g` である。開始時に HEAD とブランチの一致を読み取りで確認した。git の状態は変えていない。

## 単位の時刻

時刻は JST、所要は待ちを含む外側の時間である。能動時間と待ち時間は分離していない。資料読みの開始時刻は未採取であり、最初の明示採取は2026-11-07 04:44:45である。

| 単位 | 開始 | 終了 | 判定 |
|---|---|---|---|
| 起動条件・入力形成・実行可能性の先行確認（Codex） | 2026-11-07 04:44:45 | 2026-11-07 06:03 | Codex の利用の上限で停止 |
| L70.40a | 2026-11-07 05:06:24 | 2026-11-07 05:36:26 | 局所完了。新版51文書の読込で後続の読者も確認。群末の既定ビルドで最終判定する |
| L70.40b | 接続中（先行調査 2026-11-07 04:50:08） | — | 未完。Claude の区間で `Exchange.Observe` の符号化だけを新しい表層へ移した |
| 実行コードの基盤（Claude。L70.41 の前提） | 2026-11-07 06:14 | 2026-11-07 07:11 | 規範の checker・脱糖が実行コードを持つ（「止めずに進めた変更」） |
| L70.41 | 未開始 | — | 未完 |
| L70.42 | 未開始 | — | 未完 |
| L70.43 | 2026-11-07 04:53:06 | 2026-11-07 05:36:08 | 局所完了。最終の依存の照合は群末に行う。依存の順序に従い、交換の構文が揃うまで調査と独立補助を準備した |
| L70.44 | 未開始 | — | 未完 |
| L70.45 | 未開始 | — | 未完 |

## 交換の証明書の鍵

契約は [exchange-contract.md](exchange-contract.md) に定める。処理系が書き出すソース・署名・宣言の順序だけから決める。規則の木と中間の型・効果を交換の入力に要求しない。

## F-REG への申し送り

| 対象 | 入力の形・確認点 | 処置 |
|---|---|---|
| 整数の値域 | 旧 checker が受理した `Integer8(128)` 等の値域外の AST を新 checker は断る見込みである。処理系の正常な書き出しに同じ形があるかを全入力で確認する | 入力を省かず、新しい除外を足さない |
| 推論の燃料 | 深く入れ子になった式・ブロック、handler の節の効果と結果型を反復して求める形では、`4 * 節数 + 4` の燃料の十分性が未証明である | unknown を記録し、成功扱いせず、燃料切れか証明の会計かを分ける。入力を省かない |

## 止めずに進めた変更

| 理由・反例 | 選んだ案 | 退けた案 | 範囲のない場合の系 |
|---|---|---|---|
| 論理の証明書の位置と番号の契約が未指定であった | ソースと宣言の順序から決まる既存の推論の問い合わせの位置と番号を使い、重複する交換の鍵は拒否する | 書き出し側が規則の案内や中間型・効果を書いて位置を定める案 | 証明書が空の入力では既存の自動候補と再検査をそのまま使う。型付け・Step の規則は変えない |
| 検査の表の構成元 `BuiltinSource.builtins` は、標準の構成元の表（応答の欄が非計算的）を返すために非計算的であり、それを読む規範の checker 全体（`Check.Input.B` 経由）が実行コードを持たない | `.standard` の構成子に、構成した表とその構成の等号（`table = StandardModel.builtins program`。既定値と `by rfl` の自動の証明）を持たせ、`builtins` は持っている表を返す。`Check.Input.B` から `noncomputable` を除く。規範の checker・受理の関数がそのまま実行コードを持つ | 規範の checker の計算部分を台本で写した実行用の複製（13モジュール、約30万バイト）と元の関数との等号の証明（大きな相互再帰の定義上の等号の照合が heartbeat の上限に達した）。未証明の `implemented_by` | `.standard P` と書いた既存の箇所は既定値で同じ表を得る（`CheckOpenStandardExamples` の一件。その定義を `noncomputable` にした）。`.custom`・`.unrestrictedRanges` は変わらない。型付け・Step の規則・`Input.Sound` は変えない |
| 部分適用の脱糖の `holeLam` は、結果型と効果が外側の文脈から移した型かを古典論理の `if` で選ぶので、脱糖全体が実行コードを持たない | 値の改名で変わらないことの有限判定 `Ty.renameFixed`・`Eff.renameFixed`（篩の述語は構造の等号 `predEq` で比べる。効果の原子の所属の関数は改名で変わらない）を新しいモジュール `ValueRenamingFixed` に置き、選択の条件との同値 `shiftImage_pair_iff` を証明した。`Desugar.lean` に計算用の `holeLamDecide` と `@[csimp]` の等号 `holeLam_eq_decide` を足した | 脱糖の計算部分の複製と等号の証明。型の等号の判定を仮定する案 | `holeLam` の定義と性質1の証明は変えない。コンパイラだけが同値の判定を使う。篩のない型では判定は常に真となり、非依存のラムダを選ぶ |
| Codex の担当が、`Check.Input.Sound` の許容判定の契約 `AdmitsSound` を有限支持の下の `AdmitsSoundOn` へ弱めていた（CheckArguments・CheckInput・CheckOpenArguments・CheckMaterials）。既定ビルドの例3件（CheckDeclarationExamples・CheckExamples・CheckOpenAcceptanceExamples）が通らなかった | 4ファイルを基準版の内容へ戻した（`Check.Input.B` の `noncomputable` を除く一語だけを残す）。交換の表を検査の表に使う構成（「取りまとめに判断を求める点」の案 A）では、表の許容の命題が判定の真偽そのものなので、強い `AdmitsSound` が定義から成り立つ | 弱めた契約を残して例3件を直す案。群 D の再開10が同じ `Input.Sound` に内部行の支持を足すので、衝突が増える | 基準版と同じ |

## 入力形成の準備で確認した接点

- 交換のHeaderと組込みの署名には型パラメータの種類を加え、Rustが保持する `ParamKind` の実値を出す。高カインドの宣言をvalueで埋めない。型クラスの引数の種類も `TraitDef.param_kind` の実値を使う。
- 現行Rustの `AdtDef` は変性の情報を持たず、dataの型引数は不変の一致で検査する。新しい交換では全パラメータをinvariantとし、新機能の制約・公開境界は空とする。共変の判定を新しく実装しない。
- 完成表の標準名と交換の内部IDの対応は、dataの所属・実構成子名と、組込みの不透明型の公開名の表で明示する。値のStringを改名しない。
- 旧SurfaceのCallsに置かれていた、型付けに依存しない欄の並べ替えの補題二つを、新Surfaceの `FieldPlacement` へ移植した。外部の二つの読者を同じ新Surfaceの構文関数へ替えた。
- `FormationTypes` は交換の型・Failの内部を含む効果を構造再帰で形成し、有限支持の証拠も返す。既存の partial Convert の本文に証明の前提を足さない。
- （Claude の区間で撤回）Codex の担当が置いた `CheckCompleteTable`（完成表の型付けの射影）は、表の構成元の判断（末尾の判断点 (B)）が決まるまで作業木から外した。局所検査の記録は一時領域へ移した。

## 担当の義務

未完の各義務は下の結果と証拠で一行ずつ判定する。F-REG 全比較・作業末の work・独立レビュー・取り込み・受け入れは取りまとめの担当であり、この群の局所検査を代用にしない。

## 検査

最大常駐量は未取得（計画上の非採取）である。既定ビルド・全環境の公理監査・verify は作業末に各一度実行する。

## 計画との差と取りまとめへの判断点

末尾の「残りの作業と、取りまとめに判断を求める点」に記す。

## 先行確認の補足

- 初期の生成済み `.olean` は、ソースにない `CheckPreparation` の宣言を含んでいた。初回の局所のコード生成試行と依存一覧は、基準版の証拠として採用しない。固定ソースを既定ビルドし、以後の局所検査はその結果を使う。
- 最初の Rust の基準採取は出力先をリポジトリ外へ指定し、既存の出力先の検査で終了101となった。条件を変えず、作業木の生成物のディレクトリを出力先にして再実行した。初回は `rust-baseline.json` に、再実行は `rust-baseline-retry.json` に分ける。
- AGENTS.md の担当分担に従い、交換構文と Convert、入力形成と実入口、区間と削除を別担当に渡した。全担当で単独 Lean の同時実行を一つに制限し、親が順番を調整する。既定ビルド中の入力固定の連絡が行き違い、区間担当が既にビルドした既存3モジュールを一時変更した。開始母集団の書き出しの前に元の内容へ戻し、書き出し後に変更を適用する。

## 旧版の書き出しの基準

指定された二つのRust試験をignoredのコーパス生成も含めて実行し、終了0であった。coverage側は4試験、desugar側は49試験である。外側の時間は1477.325秒（24分37秒）であり、主コーパスの書き出し自体は1462.346秒である。

| 対象 | 件数・大きさ | 記録 |
|---|---|---|
| 脱糖側の全生成JSON | 263ファイル、2,693,127,889バイト | old-desugar-summary.json。全一覧は一時領域、指紋を同記録へ保存 |
| 脱糖の主コーパス | 1,792入力、1,373書き出し、0範囲外、419検査上の除外 | 同上のmain_corpus |
| 外部関数によるプログラム全体の除外 | 30入力、理由 external function | baseline-exclusions.json |
| 主コーパスの区間交換の外部型による除外 | 4入力の12定義、理由 externalType | baseline-exclusions.json。合成のmanifest用の独立入力やsummaryへの重複を合算しない |
| 独立した網羅性の生成JSON | 3ファイル、60,687,255バイト、20,058 cases | old-coverage-summary.json |

最初の全JSON一括読みの集計は管理中の実行セッションへのCtrl-Cで中断し、終了130を確認した。入力を省かず、stream_json.pyで根の配列を一要素ずつ読む形へ替えた。既存の小さい8ファイルについて標準jsonデコーダとの一致を確かめ、全件の集計を終えた。Python構文確認の初回はOSの既定キャッシュ先が書き込み禁止で失敗したため、一時領域のキャッシュ先を指定して成功を確認した。

## Claude の担当の区間（Codex の続き）

Codex の担当は2026-11-07 04:44:45（最初の明示採取）から06:03（ログの最後の書き込み。利用の上限で停止）までである。Claude の担当は06:14に依頼文を読み始めた。以下はこの区間の記録であり、git の状態は変えていない。`scripts/check.sh` は実行していない。

### 途中の成果の照合

開始時の作業木は、L70.40a（交換の構文・Convert）と L70.43（区間の接続）が局所の検査を通った状態で、L70.40b・.41・.42・.44・.45 は未着手又は準備中であった。06:16〜06:28に既定ビルドを共有ロックの下で実行し、終了1であった（11:50）。失敗は次の10箇所である。

| 箇所 | 原因 |
|---|---|
| `Exchange.ObserveExamples`・`Exchange.CheckInput` | 旧 Surface の型と新しい Convert の出力の不一致（L70.40b の未移植） |
| `DesugarDiff.Main`・`CoverageDiff.Main`・`CoverageProgramDiff.Main`・`BuiltinCheck.Main` | 入口が旧の型を読む（L70.41 の未切替） |
| `CheckDeclarationExamples`・`CheckExamples`・`CheckOpenAcceptanceExamples` | Codex の担当が `Input.Sound` の許容の契約を弱めたため（下の表で基準版へ戻した） |
| `intervalDiff` の実行ファイルのリンク | 生成物の不整合。149個の `.olean` が、その `.trace` より後に別の手段で上書きされており（パッケージの接頭辞のない初期化の名前を持つ）、Lake が最新と判断したまま、新しくコンパイルした C の目的ファイルから未定義の記号を参照した |

生成物の不整合は、上書きされた149個の `.olean` と、それを読んでコンパイルした C の目的ファイルの両方に及んでいた。`.trace` を移して一部を作り直す方法（06:36〜06:52の3回）では、別の目的ファイルが未定義の記号を参照し続けた。06:53に作業木の `formal/.lake/build` を同じ場所の `build.stale-g` へ改名し（4.2 GB。消していない）、生成物なしから既定ビルドをやり直した。ソースは変えていない。

### この区間の変更

- 規範の checker・受理・脱糖を実行コードにした（「止めずに進めた変更」の表の上の2行）。Codex の担当が準備した、checker の計算部分の台本による複製（`CheckNative*` の15モジュールと生成器）と完成表の射影（`CheckCompleteTable`）は、等号の証明が成り立たず読者もないので作業木から除いた（一時領域へ移した）。7入口は規範の関数を直接呼べる。
- Codex の担当の `AdmitsSoundOn` への変更を基準版へ戻した（同表の3行目）。
- 新しいモジュール `Release.Refinement.ValueRenamingFixed` を足した。`Surface.Desugar` が import するので既定ビルドに入る。根の `Benitoite.lean` への追加は、群 G の他の新しいモジュールと合わせて L70.41 で行う。
- `BuiltinSource.standard` の欄の追加に合わせ、`CheckOpenArgumentLeaves` の `.standard` の場合分け4箇所を、持っている表を構成の等号で置き換える形へ直した（証明の本文は同じ補題を使う）。
- L70.40b の一部: `Exchange.Observe` の拒否の理由・入口の誤り・予算の上限の符号化を新しい表層の型へ移した。必須の判定の受理の入力（`acceptInput`）は、新しい表層に規則がないので旧の入力を作ったまま残した（上限の値だけを新しい型から写す）。`Exchange.ObserveExamples` を版16の交換へ直し、旧版の交換を版の誤りで断る対照に替えた。

### 局所検査

| 対象 | 結果 |
|---|---|
| `ValueRenamingFixed` | `lake env lean -M 12288`、終了0・警告0 |
| `Surface.Desugar` | 同、終了0・警告0。確認用入力で `desugarExpr` と `holeLam` を `#eval` で実行でき、篩のない型で非依存のラムダを返した |
| 生成物なしからの既定ビルド（06:53:06〜07:11:06、外側17分60秒、共有ロック下） | 終了1。失敗は L70.40b・.41 の未移植の5箇所だけである（`Exchange.CheckInput`・`DesugarDiff.Main`・`CoverageDiff.Main`・`CoverageProgramDiff.Main`・`BuiltinCheck.Main`）。例3件・`ObserveExamples`・`CheckOpenArgumentLeaves`・`intervalDiff` のリンクは通った |
| 実行コードの確認（[computable-probe.lean](computable-probe.lean)） | 入口が呼ぶ `CheckAccept.checkProgramAccepted`・`acceptDef`・`acceptMethod`、`CheckDeclarations.checkDef`・`checkImpl`、`CheckTables.checkProgram`、`Check.Input.B`、`desugarDef`・`desugarImpl`・`desugarProgram` は非計算的でない。`holeLam` は非計算的のまま（コンパイラは `holeLamDecide` を使う） |

最大常駐量は未取得（計画上の非採取）である。公理監査と verify は、群の作業末に行うので、この区間では実行していない。

### 残りの作業と、取りまとめに判断を求める点

群 G はこの区間でも完了していない。完了した単位はなく、L70.40a と L70.43 は局所の検査まで、L70.40b は入力の層の一部（`Exchange.Observe` の符号化の移植）だけである。L70.41・.42・.44・.45 は未着手である（Codex の担当の準備物は下に記す）。単位ごとの残りを次に示す。見込みは能動時間の目安であり、検査の待ちを含まない。

| 単位 | 残り | 見込み |
|---|---|---|
| L70.40b | (1) `Exchange.CheckInput.prepare` を新しい `CheckTables.Materials`・`Check.Input`（`.custom` の表）・`CheckAccept.AcceptInput` を作る形に書き直す。(2) 必須の判定の受理の規則（旧 `Surface.ScopeState` の `checkRule`・`projectRule`・`widenRule`・`pathCheck`・`requestCheck` と `Surface.ScopeSound.productionRules`・`productionRules_sound`）は、新しい表層（`Refinement.Val`）に移植されていない。新しい `ScopeState` は225行で、規則の構成と健全性を持たない。`Exchange.Observe` の `acceptInput` は旧の受理の入力を作ったまま残した。(3) `Release.CoverageShow` を新しい網羅性の反例（`Refinement.CoverageWitness`）の表示へ移す。(4) `Exchange.Builtins` の残り（Codex の担当が `mkBuiltins` まで移した）と `CheckTables`・`CheckTablesSound` の削除 | (2) を除き2〜4時間。(2) は旧の約2,000行（規則と健全性）の移植で、群 G の見込みに含まれていない |
| L70.41 | 7入口を新しい checker・受理・網羅性・脱糖へ切り替え、依存の書き出しで旧判断を読まないことを確かめる。規範の関数が実行コードを持つようになったので、入口は規範の関数を直接呼べる（Codex の担当の実行用の複製は不要になった）。`q.Sound` の供給（下の判断点(B)） | 2〜4時間 |
| L70.42 | 処理系の試験の書き出しの候補（版16/8、一時領域 `/private/tmp/benitoite-l70-g/rust-candidates/`）と固定入力の候補61ファイル（`/private/tmp/benitoite-l70-g/fixture-candidates/`）は未適用。旧版の書き出しの基準（1,792入力、1,373書き出し、外部除外30入力・区間の外部型12定義）は記録済み | 適用・試験・全コーパスの書き出しで2〜3時間（全コーパスの書き出しだけで約25分） |
| L70.44 | 削除の台本 `deletion.py` と計画 `deletion-plan.json`（146モジュール・42コマンド）、F09 の照合の台本 `f09.py` は Codex の担当が準備した。未適用・未検証 | 2〜3時間 |
| L70.45 | 01-12・07-04 の写しの候補の断片（一時領域 `/private/tmp/benitoite-l70-g/spec-candidates/`）と、形式化のモジュールの表の下書き `modules-for-spec.md` がある。群 F1 の見出しの直しも未了 | 1〜2時間 |

一時領域 `/private/tmp/benitoite-l70-g/`（245 MB）は改造の外にあり、永久保管の場所ではない。次の担当が使うまで残す必要がある。

判断を求める点:

- (A) 必須の判定の受理の規則の移植（上の L70.40b の (2)）を群 G に含めるか。含めない場合、新しい入口は旧の規則のない受理（`noRules`）と同じく、範囲の判定を要求する本体を断るので、F-REG で旧と結果が変わる。
- (B) checker の入力の表の構成元。依頼文は `.custom (complete …)`（完成表）に揃えるか `.standard` との接続の補題を置くことを求める。完成表を使うには、交換の data・構成子・不透明型の内部名（`data:199` など）を標準の名前（`Option` など）へ写す必要があり、Codex の担当の `Exchange.CanonicalNames` は全1,879入力で写しを作れることを確かめた段階である（`canonical-corpus.json`）。もう一つの案（案 A）は、旧の入口と同じく交換した組込みの表（`Exchange.mkBuiltins`）を `.custom` で使い、その表と完成表の型付けの七欄の一致（`Builtins.TypingFieldsEq`）を前提にした接続の補題を置くものである。案 A は F-REG を旧と同じ表で比べられるが、一致の前提は builtinCheck の比較と名前の写しに依存する。この区間では案 A を前提に `AdmitsSoundOn` を戻した。案 B を選ぶなら、その戻しを見直す必要がある。
- (C) 規範の checker と脱糖を実行コードにした二つの変更（`BuiltinSource` の構成子と `holeLam` の `@[csimp]`）を認めるか。群 D の再開10が同じ `CheckBuiltinSource`・`Desugar` を変えた場合、結合の追随で衝突しうる。
- (D) 群 G を続ける担当と分け方。残りは上の表で9〜16時間（(A) の移植を除く）であり、L70.40b〜.41 と L70.42 は別の作業木で並行できる。

## 途中の報告（L70.41 まで。2026-11-07 08:25）

取りまとめの判断（2026-11-07。受理の規則の移植を群 G に含める、表は案 A、実行コードの二つの変更を認める、L70.42 は別の作業木）を受け、基準を `eb4f0ef9` として続けた。L70.40b・.41 を四つの担当に分けた。各担当の記録は次のとおりである。

| 担当 | 時刻（JST） | 記録 | 結果 |
|---|---|---|---|
| 受理の規則（L70.40b） | 07:17〜07:35 | [scope-rules.md](scope-rules.md) | 旧の規則と `productionRules`・健全性を新しい表層の `Surface.ScopeRules`・`Surface.ScopeSound` へ移した。`Exchange.Observe.acceptInput` は新しい `AcceptInput` を返す |
| 入力形成と表層の検査の入口（L70.40b・.41） | 07:17〜08:12 | [prepare-surface.md](prepare-surface.md) | `Exchange.CheckInput.prepare` を新しい表層へ移し、`prepare_sound` で準備の成功だけから `Check.Input.Sound` の全欄を示した。有限の表どうしの一致の判定 `Exchange.BuiltinAgreement.standardCheck` と健全性。`SurfaceCheck` の入口を新しい checker へ切り替えた |
| 網羅性の表示と4入口（L70.40b・.41） | 07:17〜07:27 | [coverage-entries.md](coverage-entries.md) | `Release.Refinement.CoverageShow` を置き、desugarDiff・builtinCheck・coverageDiff・coverageProgramDiff を新しい判断へ切り替えた |
| 7入口の依存の照合（L70.41） | 08:10〜08:20 | [entries-closure.md](entries-closure.md)・[entries-closure.json](entries-closure.json)・[entries_closure.py](entries_closure.py) | 下記 |

既定ビルドは、担当 prepare-surface の最後の実行（共有ロック下、2,337ジョブ）で終了0であった。照合の前後の `lake build --no-build` も終了0である。

### 7入口の依存の照合

各入口の `main` から定数の型と値の閉包を辿った（`partial` の実体・`csimp` の置き換え先を含む）。旧 Surface は区間解析の入力の構文（`Surface.Syntax`・`FormatSpec`）だけ、旧 Release は残す74モジュールの22だけ、`Core` は0である。旧の完全名の一覧に当たったのは `Release.Const` と `Release.Ty.lazy` の2名（延べ11件）で、どちらも残すモジュールの共有の構文であり、判断や主定理ではない。L00a.06a の対照表は新しい表層がこの構文を共有すると定めているので、違反としない（台本は厳しい基準のまま `pass: false` を出す。基準を改めるかは取りまとめの判断点とする）。L70.44 の削除の後に同じ台本を再実行する。

### 止めずに進めた変更（L70.41 までの追加）

| 理由・反例 | 選んだ案 | 退けた案 | 範囲のない場合の系 |
|---|---|---|---|
| 案 A では検査の表は交換した組込みの表であり、完成表との一致を前提に置かない（取りまとめの判断） | 交換の名前のうち標準表の合成済みの名前について、署名の欄を構造で比べる有限の判定 `standardCheck` と、その成功から名前ごとの一致を与える `standardCheck_sound`・`agrees_complete`・`prepare_agrees` を置き、判定が偽の入力は `prepare` が断る。名前は写さない | 一致を前提に置く案。`CanonicalNames` による標準名への写し | 範囲・篩のない署名でも同じ構造の比較である |
| 表の署名と効果の原子が `prepare` の原子の一覧にない入力では、`Check.Input.Sound` の有限支持が成り立たない | 署名を支持の証拠つきで変換し（`Exchange.CheckSupport`）、一覧にない原子を持つ入力は断る | 支持を仮定する案 | 原子の一覧は旧と同じ集め方である |

担当ごとの残りの変更（受理の規則の解析の表の食い違いを Top にすること、証明の上限の既定値など）は各記録の表にある。

### F-REG への申し送り（追加）

| 対象 | 入力の形・確認点 | 処置 |
|---|---|---|
| 一致の判定による拒否 | data・不透明型・効果の名前を写さないので、`Option`・`Result` を返す組込み、範囲付きの型、効果の名前が標準と違う組込みを使う入力では `standardCheck` が偽になり、準備の失敗になる見込みである。新版の固定入力の候補では range 2・rejections 16 が準備の失敗になった | 件数と名前を F-REG で数える。入力を省かない |
| 受理の規則の解析の表 | 処理系の `patterns`・`hosts` の表と形式化した解析が食い違う項目は Top として扱う | 該当する入力の有無を F-REG で数える |

### 取りまとめに判断を求める点（L70.41 まで）

1. 一致の判定による拒否の範囲。名前を写さない案 A のままでは、標準の data・不透明型を署名に持つ合成済みの組込みを呼ぶ入力の多くが準備の失敗になる見込みである。拒否をやめて判定の結果を記録するだけにするなら、`Exchange.CheckInput` の `prepareParts` の一か所を変えれば済む。
2. 受理の規則の成功値の名前。交換は `"Ok"`、新しい実例の表の δ は `Result.Ok` を使うので、`ok := "Ok"` での検査の規則の健全性は空の主張になる。名前をどこで結ぶか。
3. 依存の照合の基準。残すモジュールの共有の構文（`Release.Const` など）を照合の対象から除くか。

L70.44・.45 は L70.42 の取り込みの後に行う。

## L70.44 の予行（作業木の外の写し。2026-11-07 09:5x〜10:20）

L70.44 の削除は L70.42 の取り込みの後に作業木へ適用する。その前に、作業木の `formal/` と改造の文書を scratchpad へ写し（`.lake`・`.git` を除く）、写しの上で予行した。作業木のソースは変えていない。

| 段 | 結果 |
|---|---|
| 削除の計画の作り直し（`deletion.py`、写しの上） | 146モジュールを削除、42コマンドを除く、残す旧 Release 74・旧 Surface の構文3 |
| 適用（`deletion.py --apply`、写しの上） | 終了0。削除したモジュールを import するのは根の `Benitoite.lean` だけで、その118行を除いた |
| 写しの既定ビルド（生成物なし、共有ロック下、10:01:18〜10:18:05、外側16分46秒） | 終了0（2,178ジョブ。7入口の実行ファイルのリンクを含む） |
| F09 (1) 削除後の閉包 | 写しのソースに旧 Surface は構文の3モジュールだけ、`Core` は0。旧 Release は74モジュール |
| 7入口の依存の照合（`entries_closure.py`、写しの上、外側1分59秒） | (a)〜(c) は違反0、(d) は共有の構文 `Release.Const`・`Release.Ty.lazy` の延べ11件（削除の前と同じ）。判断・主定理の名前は0 |
| `admit` の名前（TODO-294） | 写しの `.lean` に単語 `admit` は0件 |

作業木への適用は、L70.42 の取り込みの後に `deletion.py`（計画の作り直し）→ `deletion.py --apply` → 根の `Benitoite.lean` の削除したモジュールの import の除去 → `deletion.py --verify-applied` → 既定ビルドの順に行う。F09 (2) の逆戻りの照合（新主定理・新しい表層の閉包）と (3) の 07-04 の形式化のモジュールの表の改訂、`retained-release.md` の今の状態での作り直しは、適用の後に行う。

## 取りまとめの第2の判断への処置（2026-11-07 10:21〜10:47）

### 1. 標準表との照合での名前の写し

`Exchange.CheckInput.prepareParts` は、`CanonicalNames.ofInputs` で同じ入力の宣言から決まる標準の名前への写しを作り、交換の組込みの表と入力を写した JSON から照合用の表（`canonicalSig`・`canonicalNames`）を作って `BuiltinAgreement.standardCheck` にかける。検査器の表は写さない交換の表（案 A）のままである。写した後も署名の欄が合わない入力は従来どおり準備の段で断る。`Prepared`・`Parts` に照合用の名前と署名の欄を足し、`prepare_agrees` は照合用の表について述べる（検査器の表と照合用の表の対応は名前の写しであり、定理は述べない）。`CanonicalNames.ofInputs` はこれで本番の読者を持つ。

比べる欄と比べない欄:

| 欄 | 扱い | 理由 |
|---|---|---|
| 署名の `tparams`・`neffs`・`names`・`params`・`ret`・`eff`・`kind`・`opEff`・`rkinds`・`shape` | 比べる（`shapeCheck`。型と効果は有限の原子の一覧で構造比較） | 有限に比べられる |
| 署名の `admits` | 比べない | 型パラメータの制約の命題（`Prop`）で、等号を判定できない |
| 表の `sat`・`admitsR`・`ioResponse`・`releaseResponse`・`externalResponse` | 比べない | 命題の欄であり、等号を判定できない |
| 表の `delta` | 比べない | 標準表の算法は非計算的な定義を含み、有限に比べられない |
| 表の `effects`・`effKind`・`valKind`・`isResource`・`refGet`・`refSet`・`valContent` | 比べない（この区間では足していない） | 標準の値は非計算的な表 `signatureBase`（`ModelTargets.builtins` の上書き）の欄であり、計算できる別の定義を切り出す補題が要る。R50（F-CONN）の照合へ送る |

### 2. 成功値の名前

未了。交換は Result の構成子を `"Ok"`・`"Error"` と書く（`Version.lean` の検査もこの名前を要求する）。Convert で `Result.Ok` へ写すには、構成子の名前が現れる全ての位置（パターン・構成子の呼出し・data の宣言・組込みの data の材料）を同じ写しで変え、交換へ書き戻す経路（脱糖の比較の `fromComp`・`fromPattern`、区間の JSON）で逆に写す必要がある。書き戻しの比較は処理系の書き出し（`"Ok"`）と照らすので、片方だけを写すと desugarDiff と intervalDiff の一致が崩れる。この区間の残りの容量では、書き戻しの全経路の照合まで終えられないので着手していない。受理の規則の健全性は、`productionRules_sound` が `ok ≠ "Result.Error"` の任意の名前で成り立つ形のままであり、`ok := "Ok"` では中身のない主張である。

### 3. 照合の基準

`entries_closure.py` は、残すモジュールの共有の構文 `Benitoite.Release.Const`・`Benitoite.Release.Ty.lazy` を旧の名前の集合から外す（判断・旧主定理・旧表層の主定理の名前でないことを台本の中で確かめる）。外した一覧は結果の `excluded_shared_syntax` に記す。再実行の結果は (a)〜(d) すべて0、`pass: true` であった（`entries-closure.json`、28,326 バイト）。

### 準備の失敗の件数

| 入力（新版の固定入力の候補。一時領域 `fixture-candidates/`） | 結果 |
|---|---|
| test_range_exchange | 準備の失敗2（写しの前と同じ） |
| test_range_rejections | 準備の失敗16（同） |
| test_width_exchange、named・batch2・batch5・extensible | 準備の失敗0。全件が検査まで進んだ |
| batch4 | 準備の失敗0。不一致4（`fn:220`〜`223`。型構成子に適用する型パラメータの種類を候補が `value` と書いているためと見られる。準備の失敗ではない） |

名前の写しで消えない失敗の理由は全件、`Scope.checkPathIn`・`File.writeTextIn`・`Http.checkRequestIn`（rejections では加えて `Http.widenRequestIn`）の署名の不一致である。例: 候補の `Scope.checkPathIn` の結果型は `Result[opaque "101:[]"（範囲変数0）, opaque "102:[]"]` であり、交換は範囲付きの型を不透明型と範囲の組で書く。標準表の行は範囲付きの型の構成子で書くので、名前を写しても型の構成子が違う。候補は Codex の担当が旧版の固定入力から作ったものであり、処理系の新版の書き出し（L70.42）がこの型をどう書くかで件数が変わる。既存コーパスは旧版なので、L70.42 の取り込みの前には読めず、件数を数えていない。

### 既定ビルド

`Validation.lean` の例の `Prepared` の欄を新しい欄に合わせた後、既定ビルドは終了0（共有ロック下、差分のみ3秒。直前の全体のビルドは失敗の箇所以外を作り直していた）。

## 後段への申し送り（追加）

| 担当・時期 | 申し送り |
|---|---|
| R50（F-CONN） | 交換の7入口が保証するのは「交換した組込みの表の下での checker の健全性」である（`prepare_sound`）。主定理の前提 `q.B = complete …` はこの経路では得られない。完成表との接続は R50 が受け持つ。`prepare_agrees` は、名前を写した照合用の表の署名の欄が完成表と一致することだけを述べ、検査器の表との対応、命題の欄、`effects`・`effKind`・`valKind`・`isResource`・`refGet`・`refSet`・`valContent` の一致は述べない |
| 取りまとめ（成功値の名前） | 上の「2. 成功値の名前」の写しを、書き戻しの経路の逆写しとともに一つの単位として行う |
| F-REG | 準備の失敗の件数と理由を、L70.42 の新版の書き出しで数え直す。範囲付きの型の書き方が交換と標準表で違う組込み（上の4名）が主な対象である |

## 取りまとめの第3の判断の1（照合の側で範囲付きの型の書き方を揃える。2026-11-07 10:48〜10:51）

照合用の表の型は、検査器が読む型と同じ変換（`formedMaterials`、交換の型を新しい表層の型へ写す変換）を通っている。写した型と標準表の行を確認用入力 [signature-probe.lean](signature-probe.lean) で並べると、範囲付きの型は双方とも不透明型と範囲の組（`.opaque "Scope.PathIn" (.rvar 0)`）であり、不一致の原因は型の構成子でなく、不透明型の名前の写しが一部しか効いていないことだった。交換の `opaqueNames` は公開名を処理系の書き出しの完全名（`Benitoite.IOError.IOError` など）でなく接頭辞のない名前（`IOError`・`Http.RequestIn`）で書く入力があり、`CanonicalNames` の有限表がそれを引けなかった。

`CanonicalNames.ofInputs` の不透明型の写しを、完全名・接頭辞を除いた名前・標準表の名前のどれで書かれても有限表の同じ行を引く形にした（標準表の行は変えない）。既定ビルドは終了0。

| 入力（新版の固定入力の候補） | 写しを揃える前 | 揃えた後 |
|---|---|---|
| test_range_exchange | 準備の失敗2（4名の署名） | 準備の失敗2（`Scope.checkPathIn` だけ） |
| test_range_rejections | 準備の失敗16（4名） | 準備の失敗16（`Scope.checkPathIn` だけ） |
| test_width・named・batch2・batch5・extensible | 準備の失敗0 | 準備の失敗0（matched 17・7・29・6、width は終了0） |
| batch4 | 不一致4 | 不一致4（準備の失敗ではない。前の節のとおり） |

揃えた後も合わない署名は `Scope.checkPathIn` の1名で、件数は上の18入力である。例: 交換の結果型は `Result[Scope.PathIn(範囲変数0), opaque "102:[]"]`（`opaqueNames` は `102:[]` を `Scope.ScopeError` と書く）であり、標準表の行は `Result[Scope.PathIn(範囲変数0), data "Scope.ScopeError"]` である。処理系は `Scope.ScopeError` を組込みの不透明型として書き出し、標準表は data 型として持つ。型の構成子が違うので名前の写しでは揃わない。照合の結果を変えず、記録に残す（F-REG の申し送りの対象）。

## 待機中の準備（2026-11-07 10:55）

`Scope.ScopeError` の不一致は、取りまとめの判断で書き出しの側（L70.42 の追補）で直す。照合の側に写しは足していない。L70.42 の結合の後に、`Scope.checkPathIn` の準備の失敗（新版の固定入力の候補の18入力）が消えることを確かめる。判断2の写す位置と書き戻しの経路の一覧を [ok-name-inventory.md](ok-name-inventory.md) に置いた（まだ変えていない）。
