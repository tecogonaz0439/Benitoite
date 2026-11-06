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
