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
| L70.42 | 処理系の試験の書き出しの候補（版16/8、一時領域 `<tmp>/rust-candidates/`）と固定入力の候補61ファイル（`<tmp>/fixture-candidates/`）は未適用。旧版の書き出しの基準（1,792入力、1,373書き出し、外部除外30入力・区間の外部型12定義）は記録済み | 適用・試験・全コーパスの書き出しで2〜3時間（全コーパスの書き出しだけで約25分） |
| L70.44 | 削除の台本 `deletion.py` と計画 `deletion-plan.json`（146モジュール・42コマンド）、F09 の照合の台本 `f09.py` は Codex の担当が準備した。未適用・未検証 | 2〜3時間 |
| L70.45 | 01-12・07-04 の写しの候補の断片（一時領域 `<tmp>/spec-candidates/`）と、形式化のモジュールの表の下書き `modules-for-spec.md` がある。群 F1 の見出しの直しも未了 | 1〜2時間 |

一時領域 `<tmp>/`（245 MB）は改造の外にあり、永久保管の場所ではない。次の担当が使うまで残す必要がある。

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

## 二人目の Claude の担当の区間（結合の後。2026-11-07 11:24〜）

基準は結合の版 `dc22b231a7f9f75089434c80d06e7f14f70a8eab`（HEAD と一致を確認）。git の書き込み、`scripts/check.sh`・`scripts/check-formal.sh` の全体の実行はしていない。サブエージェントは起動していない。`<tmp2>` はこの担当の一時領域、`<tmp>` は群 G の前の担当の一時領域、`<tmp42>` は L70.42 の一時領域を表す。

### 時刻

| 区間 | 開始 | 終了 | 結果 |
|---|---|---|---|
| 結合直後の既定ビルド | 11:26:09 | 11:40:12 | 終了1。失敗は `PredicateSimulationTraces`（名前 `Program` の解決）と `PredicateGeneratedNames`（パターン）の2モジュールと、その下流 |
| 1. 案 (a)：実行できる形に戻す | 11:42 | 11:48:31 | 既定ビルド終了0。7入口のリンクを含む |
| 2. 実入口の契約への追随 | 11:47 | 12:18:42 | 既定ビルド終了0 |
| 3. 準備の失敗の確認・固定入力の候補の適用 | 11:50 | 12:35 | 下の表 |
| 4. L70.44 削除の適用 | 12:23:43 | 12:39 | 既定ビルド終了0（12:23:50〜12:34:35、2,322ジョブ）、F09 の三条件 |
| 6. 判断2（成功値の名前の写し） | 12:40 | 12:50 | 既定ビルド終了0、比較器の前後一致 |
| 5. 07-04 の写し | 12:45 | 12:50 | 下記。残りは「残る写し」 |
| 7. L70.42 の申し送り | 11:48 | 11:50 | 下記 |
| 8. 作業末の検査 | 12:51 | 13:00 | 下の「作業末の検査」 |

### 1. 規範の checker を実行できる形に戻す（案 (a)）

- `Check.BuiltinSource.predicates` に、構成した表とその構成の等号（`table := PredicateProjection.Table.builtins data rows`、`built : table = … := by rfl`）を持たせた。`.standard` と同じ形である。
- `.resolved` には欄を足していない。等号は元の構成元の表 `base.builtins` を参照するが、帰納型の構成子はその型の関数を参照できないためである。代わりに `predicateOverlay` から `noncomputable` を除いた。重ねる操作が読む内部行の署名と応答（`Row.signature`・`Row.delta`）は実行コードを持つことを確認用入力で確かめた（`isNoncomputable` が偽）。
- `BuiltinSource.builtins` と `Check.Input.B` は実行コードを持つ。7入口の実行ファイルはリンクした。
- 場合分けの追随は次の7ファイルである。`.predicates`・`.standard` の欄を受けて `subst built` で書き換える（証明の本文は同じ補題）。`CheckPreparation`・`CheckOpenArgumentLeaves`・`PredicateGeneratedNames`・`PredicateSimulationStateOperations`・`PredicateSimulationResponseSteps`・`PredicateSimulationActiveProviders`・`PredicateSimulationLookup`。
- `PredicateSimulationTraces` の `Program` は、群 G の import の追加で表層の `Surface.Program` を指すようになっていたので、`Refinement.Program` と書いた（3箇所。意味は同じ）。
- 01-12「篩を含む表層の検査と受理」の `Check.BuiltinSource` の段落と、07-04 の `Surface.CheckOpen` の段落を今の状態（三つの構成元が表を持つ・重ねた表を返す・検査器と実入口の準備は実行できる）に合わせた。

### 2. 実入口の契約への追随

- `Exchange.Observe` の受理の入力は、群 D が足した欄 `openRules` を既定値で持つよう、欄の名前で構成した（規則のない入力も同じ既定値。群 D の実入口と同じ）。
- `Exchange.CheckInput.Parts` に、検査器の表が交換した組込みの表であることの欄（`table`・`custom`）を足した。新しい定理 `prepare_entry` は、準備が成功した入力では、実入口の準備 `CheckPreparation.prepare` がどの本体も入力ごとそのまま返し、準備後の入力も健全であることを示す。群 D の実入口の健全性（`checkProgramAccepted_sound`）の前提 `(CheckPreparation.prepare q p).input.Sound` はこれで供給できる。
- 7入口のソースは、`CheckTables.checkProgram` の中で準備を通るので変えていない。

### 3. 準備の失敗の確認

固定入力の候補（一時領域 `<tmp>/fixture-candidates/tests/`）を `formal/tests` へ当てた。52ファイルのうち L70.42 が変えていた3ファイル（`test_batch2_exchange.py`・`test_batch3_exchange.py`・`interval_vm_compare.py`）は三方向で照らし、衝突した2箇所は作業木の側（L70.42 の版）を採った。続いて次を直した。

| ファイル | 変更 | 理由 |
|---|---|---|
| `test_range_exchange.py` | `Scope.ScopeError` を data（標準と同じ6構成子・要約）で置き、不透明型 `102:[]` と公開名の行を除いた。`Http.RequestCheckError` の要約を、欄が全て導出できる値に改めた | 取りまとめの判断（data の側が正しい）。標準の宣言（`Scope.bnt`）と同じ |
| `test_range_exchange.py` | 組込みの参照の範囲の差し替え2箇所を `{"fixed": …}` の形にした。効果の上限の拒否の期待の文言を篩付きの検査器の文言にした。区間の版の試験に、`test_interval_exchange.py` と同じ燃料の初期値を与えた | 候補が版16の形に直していなかった。旧の版の比較を版16の単独の照合に置き換えたとき、深さの停止で `matched` が偽になっていた |
| `test_range_rejections.py` | 独立入力の ScopeError を data として標準の宣言へ対応させる | 上と同じ |
| `test_range_sources.py` | 候補の欄を除く代わりに空にする | 版16では `candidates` は必須の欄である |

結果:

| 対象 | 結果 |
|---|---|
| `test_range_exchange.py`（9試験） | 終了0。ScopeError を直す前は、準備の失敗で3試験が落ちていた |
| 拒否の独立入力（`test_range_rejections.py --freeze` の入力を `surfaceCheckAll` で検査） | 準備の失敗0（以前は16）。一致18・不一致8（不一致は期待した拒否の8件） |
| 範囲の実ソース（`test_range_sources.py`、L70.42 の新しい書き出し） | 最初の事例 `host-one` の `surfaceCheck` が準備の失敗で止まる（下の F-REG の表の1行目） |
| ほかの固定入力の試験 | width 1・named 27・extensible 54・try 10・batch2 4・batch3 33・batch4 18 の失敗、batch5 は終了0。準備の失敗は、意図して壊した入力（extensible の12件、named の `%eq`）だけである。失敗の多くは Lean の入口の文言の期待（旧の検査器の理由の文、`unsupported exchange field: refs` などの拒否の文言）で、batch3・batch4 には一致の件数の差（不一致4）もある。取りまとめの全比較（F-REG）で扱う |

`Scope.checkPathIn` の18入力（range 2・rejections 16）の準備の失敗は消えた。

### 4. L70.44 削除の適用と F09 の三条件

- `deletion.py` で計画を作り直した。前回の計画と同じ（146モジュール・42コマンド・残す旧 Release 74・旧 Surface の構文3）。`--apply` で適用し、根の `Benitoite.lean` から削除したモジュールの import 118行を除き、`--verify-applied` は成功した。既定ビルドは終了0。
- 削除したモジュールを参照する台本・試験はなかった（`scripts/`・`tools/`・`formal/tests` を grep）。
- F09 の照合（`f09.py`）は、既定環境と7入口の宣言グラフ（[graph.lean](graph.lean)。今の Lean で書けない `mod.startsWith` の部分適用を直した写しを `<tmp2>/f09/` で使った）で行った。(1) 削除後の閉包: 既定 import に削除したモジュールはなく、旧 Surface は構文の3モジュール、旧 Release は74モジュール。(2) 逆戻り: 既定環境と7入口のどれも0件。(3) 残す旧 Release: 31・19・24 に分かれ、全てが [modules-for-spec.md](modules-for-spec.md) の表にある。記録は [f09.json](f09.json)。
  - `f09.py` は、等式・場合分けの自動生成の補題（`eq_N`・`eq_def`・`_sparseCasesOn_N.else_eq`）について、読み込んだ環境ごとに所属と依存が変わる差を許すよう改めた（入口ごとに318〜446件。それ以外の宣言の差は従来どおり誤り）。
- 7入口の依存の照合（`entries_closure.py`）も削除の後に再実行し、`pass: true`（(a)〜(d) と入口のソースの違反0）。
- `admit` の名前（TODO-294）: `formal/` の `.lean` に単語 `admit` は0件。

### 5. 07-04 の写し

- 「01-12 との対応」の「以下の既存の表は Release などの対応である」の前に、既定 import に残す旧 Release・旧 Surface のモジュールの表（篩付きの表層と区間の接続、埋め込みの定義域31、共有の定義とその依存19、全宣言の依存24、区間の入力の構文3）を置いた。内容は modules-for-spec.md と同じで、`Exchange.CanonicalNames` の行に Result の構成子の入れ替えと読者を足した。
- 「道具と置き場所」と「交換の形式の版」の版の段落を、corpus 16・sidecar 8 だけを受ける今の状態にした（旧版の読み分けの記述を除いた）。成功値の名前の入れ替えを「交換の形式の版」に書いた。

残る写し（この区間で終えられなかったもの。取りまとめの判断を求める）:

| 箇所 | 内容 |
|---|---|
| 01-12「Scope の局所解析の状態と規則の表」〜「Scope の局所解析の接続定理」（2726〜2910行付近） | 削除した旧 Surface の `ScopeState`・`ScopeLower`・`ScopeAccept`・`ScopeSound`・`CheckAccept`・`DesugarRange`・`ScopeOccurrence` を正とする【決定】。篩付きの `Surface.ScopeState`・`ScopeRules`・`ScopeSound` などへ改めるか除く |
| 01-12 の 186・192・247・534・535・545・1067・2670・2722 行付近 | 削除した旧 Release・旧 Surface のファイルを根拠に挙げる文 |
| 07-04「証明する性質」の冒頭（44〜64行） | 旧 `Release/Theorems.lean`・旧 `Surface/Theorems.lean` などを性質の証明の場所とする記述。新判断だけを規範とする文へ改める |
| 07-04 の 696・698・724・726・846・1079・1129 行付近と「以下の既存の表」の旧ファイルの行（1391〜1432行付近） | 削除したファイルの名前 |
| 01-12「本章の位置付け」、07-04「目的と範囲」 | 新判断だけを規範とする位置付けの文 |
| `formal/README.md` | 段階 A（`Core/`）・段階 C（旧 `Surface/`）・旧 `Release` の削除したファイルの行と、旧主定理の `#print axioms` の一覧 |

### 6. 判断2（成功値の名前の写し）

- 交換の境界の一か所で写す形にした。`Exchange.exchangeJson`（コーパス・型表・stdlib・プログラムの網羅性の文書の検査の入口）は、検査した文書の構成子の名前の欄で `Ok`↔`Result.Ok`・`Error`↔`Result.Error` を入れ替えて返す（`CanonicalNames.resultJson`）。区間の交換の読者も同じ写しを通して読む。独立の網羅性の文書は自身の宣言だけを読むので写さない。
  - 写す欄の決め方は、既存の `CanonicalNames.json` の文脈の判定を使い、構成子の欄だけを写す設定（`constructorsOnly`）を足した。primitive・効果・型の名前は写さない。
  - 写しは入れ替えなので、二度写すと元に戻る。処理系の書き出しと Lean の結果は、同じ写しをした両辺で比べる。
- `Exchange.Observe.acceptInput` の成功値の名前を `Result.Ok` にした。受理の規則の健全性（`acceptInput_sound`・`acceptInput_tableSound`）は `ScopeState.models "Result.Ok"` についての主張になり、実例の表の δ の成功値と同じ名前を読む。`ObserveExamples` の二つの適用例を合わせた。
- 一致の確認（L70.42 の新しい書き出し `<tmp42>/new/desugar/`、写しの前後の実行ファイルを比べた。台本 `<tmp2>/okcmp.sh`）: path-in・request-in・named-declarations・generated-record-property・manifest の5コーパスで desugarDiff・builtinCheck・surfaceCheckAll・coverageProgramDiff（ある2件）、区間の interval-manifest-corpus・reader-corpus・point の analyze と eval。終了状態は全て前後で同じ。報告は surfaceCheckAll の経過時間の欄を除いてバイト単位で同じ。固定入力の試験の失敗の件数も前後で同じ。

### 7. L70.42 のレビューの申し送り

- `CanonicalNames.ofInputs` の読者は `Exchange.CheckInput.prepareParts`（照合用の表）にある。
- `sidecarVersion` の名残の引数を除き（`def sidecarVersion : Nat := 8`）、呼出し4箇所と例2件を合わせた。旧版の分岐（`version >= 9` の条件）を `SurfaceCheck/Main.lean`・`SurfaceCheck/Batch.lean`・`BuiltinCheck/Main.lean` から除いた（読者は版16だけを受ける）。
- 旧版の読み方を述べるコメントを `Exchange/Observe.lean`（冒頭）・`Exchange/CheckInput.lean`（2箇所）・`DesugarDiff/Main.lean` から除くか、今の性質で書き直した。

### 止めずに進めた変更（この区間）

| 理由・反例 | 選んだ案 | 退けた案 | 範囲のない場合の系 |
|---|---|---|---|
| 結合で `.predicates` の表（標準表の構成）が非計算的になり、checker 全体が実行コードを失った | `.predicates` に構成した表と構成の等号を持たせる（`.standard` と同じ）。`.resolved` は等号を書けないので欄を足さず、計算できる `predicateOverlay` から `noncomputable` を除く | `.resolved` にも表を持たせる（構成子の型が自身の関数を参照するので書けない）、検査器が読む欄だけを別に取り出す案 (b) | 規則・`Input.Sound` は変えない。`.predicates T rows` と書いた箇所は既定値で同じ表を得る |
| 群 D の `AcceptInput` に欄 `openRules` が加わり、交換の受理の入力が構成できなくなった | 欄の名前で構成し、`openRules` は群 D の既定値（実入口と同じ） | 規則のない入力では空の列にする（実入口と違う受理になる） | 開いた範囲の規則は宣言の型が保持する範囲だけを読む |
| 区間の交換の読者は範囲の変数の位置を検査せず、宣言のない範囲の変数を持つ入力を受理していた（候補の試験 `v16-rvar`） | 区間の交換の全体を `validateRanges 0` で検査し、範囲の変数を拒否する。区間の定義は範囲パラメータを宣言しないので保守的な側 | 受理のまま期待を変える | 新しい書き出しの区間の交換（12文書）と区間の固定入力に範囲の変数はない（数えた） |
| 交換の Result の構成子の名前 `Ok` が実例の表の `Result.Ok` と違い、受理の規則の健全性が空の主張だった | 交換の文書の検査の入口で構成子の名前を入れ替える（上の 6） | 変換の各所（約25箇所）で名前を写し、書き戻しの各所で逆に写す案 | 入れ替えは全単射で、比較は両辺に同じ写しをするので一致の判定は変わらない |
| 群 D の実入口の健全性は準備後の入力の健全性を前提にする | `Parts` に独自の表の事実を足し、`prepare_entry` で準備が恒等で健全であることを示す | 交換の入口ごとに準備の展開を書く | 準備は独自の表では恒等である（`CheckPreparation.prepare_custom`） |

### F-REG への申し送り（この区間の追加）

| 対象 | 入力の形・確認点 | 処置 |
|---|---|---|
| 標準表との一致の判定による準備の失敗 | 初めの集計（名前を写す前の組込みの名前で数え、少なくとも35入力・「19名」）は誤りだった。訂正した件数と原因は下の「取りまとめの判断の後の区間」の表にある | 同上 |
| 固定入力の試験の文言と件数 | 上の 3 の表の失敗。篩付きの検査器の拒否の理由の文と、旧の期待の文が違う。batch3・batch4 に一致の件数の差 | F-REG の全比較で数える |

### 作業末の検査

| 検査 | 結果 |
|---|---|
| 既定ビルド（共有ロック下。最後の Lean の変更の後） | 終了0（2,323ジョブ。根に `Exchange.RefinedExamples` を足した後） |
| 公理監査（[verify_g2.py](verify_g2.py) が作る、群 G が足した16・変えた48モジュールの全宣言。private・生成宣言を含む。入口の根は `main` が衝突するので根ごとに9入力。共有ロック下、12:54:24〜12:56:09） | 9,981宣言。公理なし4,849・`propext` 2,093・`propext, Quot.sound` 315・`propext, Classical.choice, Quot.sound` 2,724。`sorryAx` と新しい公理は0。最大常駐 2.23 GB（ライブラリの入力）。生の出力9ファイルは計2.2 MB、連結の SHA-256 `36c783d8b30200dab69710c66f6c08a4daf8aaa33352b60941ec8291da945afa` |
| 照合（`verify_g2.py`） | 成功。足した16モジュールは全て既定 import に入る。足した・変えたモジュールに `sorry` と `axiom` はない。処理系の本体（`crates/benitoite/src/`）の変更は0。記録は [verification-g2.json](verification-g2.json) |
| `cargo test -p benitoite --test desugar_export --test coverage_export` | 終了0（網羅性 3通過・1無視、脱糖 49通過・1無視） |
| `python3 -B -m unittest scripts.check.test_policy` | 終了0 |

`verify.py` は群 G の開始時の一時領域の入力の写しに依るので、結合の後の状態には使えない。`verify_g2.py` が git の版（開始版・群 G の途中の保存・結合の版）から対象を作り直す。照合の途中で、群 G が足した `Exchange.RefinedExamples` が既定 import になかったことが分かり、根に足した。

### 計画からのずれ

- 削除したモジュールの写しの直し（上の「残る写し」）を終えていない。
- 11:55頃、試験の確認の途中で、対象を指定した `lake -d formal build intervalDiff` を共有ロックなしで誤って起動し、約2分後に停止の道具で止めた。残った処理はなく、その後の既定ビルドは共有ロック下で終了0であった。

## 取りまとめの判断の後の区間（ed2ab04d から。2026-11-07 13:05〜）

基準は取りまとめのコミット `ed2ab04d`。git の書き込み、`scripts/check.sh`・`scripts/check-formal.sh` の全体の実行はしていない。サブエージェントは起動していない。この区間では Lean のソースを変えていない。

### 記録の絶対パス

results.md・spec-copies.md・prepare-surface.md・signature-probe.lean の一時領域の絶対パスを `<tmp>`（群 G の前の担当の一時領域）・`<tmp2>`（この担当の一時領域）・`<tmp42>`（L70.42 の一時領域）に改めた。`l70/g42/results.md` の冒頭の `<tmp>` の定義の行は、群 G の受け持ちの外（`g/` 以外）なので変えていない。

### 1. 標準表との一致の判定で断った入力の分類

前の区間の集計（少なくとも35入力、「結果型の篩の19名」）は誤りだった。処理系の書き出しの組込みの名前（`Benitoite.Network.Http.sendIn` など）を、照合の前の名前の写しの後の名前（`Http.sendIn`）と照らしていなかったためである。L70.42 の新しい書き出しの全ての組込みの表（48文書・1,455入力）に表層の一括検査の実行ファイルを当てて数え直した（台本 `<tmp2>/prep/run2.sh`。準備の段の理由を報告から読んだ）。

| 結果 | 入力の数 |
|---|---:|
| 準備の段で断った（標準表との一致の判定） | 1,454 |
| 組の誤りで評価できない（`scope-tables`。合成の表で stdlib を持たない） | 1 |
| 準備を通った | 0 |

原因の名前ごとの入力の数（一つの入力が複数の原因を持つ）:

| 原因 | 名前 | 入力の数 | 内容 |
|---|---|---:|---|
| `Http.sendIn` | `Http.sendIn` | 1,454 | 成功値の `Http.Response` を、処理系は record の data、標準表は不透明型で持つ |
| 結果型の篩 | `List.append`・`List.head`・`List.tail`・`Map.fromList`・`Map.toList`・`Set.fromList`・`Set.toList`（7名） | 23 | 標準表の結果型だけが篩を持つ |
| 鍵の型パラメータの等値の印 | `Map.contains`・`Map.empty`・`Map.get`・`Map.keys`・`Map.remove`・`Map.set`・`Map.size`・`Map.values`・`Set.add`・`Set.contains`・`Set.difference`・`Set.intersection`・`Set.remove`・`Set.size`・`Set.union`（15名） | 11 | 鍵の型パラメータの制約を、処理系は等値と鍵の両方の印、標準表は鍵の印だけで書く。型・効果の欄は一致する |
| `Scope.ScopeError.At` | `Scope.checkPathIn` | 9 | 標準表の `Scope.ScopeError` だけが構成子 `At` を持ち、構成子の数が違うので data の名前を写せない |

組み合わせは、`Http.sendIn` だけ1,420、`Http.sendIn` と結果型の篩14、`Http.sendIn` と `At` 9、`Http.sendIn` と鍵の印と篩9、`Http.sendIn` と鍵の印2である。取りまとめの判断に挙げた「19名」は誤りで、篩の差は7名、ほかの15名は鍵の型パラメータの印の差である（確認用入力 `<tmp2>/probe/sendin.lean` で、15名は型パラメータの欄を標準表の値に置き換えると一致し、7名は結果型が違うことを確かめた）。鍵の印の差は取りまとめの判断に挙げていない原因なので、照合も標準表も変えず、分類だけを足した（下の「取りまとめに判断を求める点」）。

分類の表は `formal/tests/test_range_sources.py` の `STANDARD_GAPS`・`preparation_gaps` に置き、ほかの試験も同じ表を読む。

- `test_range_sources.py`: 表層の検査を、準備の段で断った・一致・不一致に分けて `summary.json` の `surfaceCheck` に残し、最初の準備の失敗で止めない。不一致があれば最後に失敗する。新しい書き出しの範囲の実ソースでは、17事例全てを準備の段で断った（原因は `Http.sendIn` 17、うち `At` 3）。一致・不一致は0。終了0。
- `test_range_budget_sources.py`: 同じ分類にした。2事例とも準備の段で断った。終了0。
- `test_batch3_exchange.py --rust-dir`・`test_batch5_exchange.py --rust-dir`: 処理系の書き出しを読む表層の検査を同じ分類にした。どちらも終了0（全入力を `Http.sendIn` で断った）。
- `crates/benitoite/tests/desugar_export/check_named.py`（`check-formal.sh` の固定記録の照合）と `test_batch2_exchange.py` の書き出しの照合は、最初の表層の検査の準備の失敗で止まる。分類の形には直していない（下の「取りまとめに判断を求める点」）。

### F-REG への申し送り（R30・R50 で0件にする義務）

| 原因 | 断った入力（1,455のうち） | 0件にする担当 |
|---|---:|---|
| `Http.sendIn`（`Http.Response` の表現） | 1,454 | R50 |
| 結果型の篩（7名） | 23 | R 段の処理系の篩の書き出し（取りまとめが担当を決める） |
| 鍵の型パラメータの等値の印（15名） | 11 | 未定（取りまとめの判断点） |
| `Scope.ScopeError.At`（`Scope.checkPathIn`） | 9 | R30 |

ほかの原因の準備の失敗は0件である。

### 2. 削除したモジュールの記述の直し

| 箇所 | 処置 |
|---|---|
| 01-12「Scope の局所解析の状態と規則の表」〜「Scope の局所解析の接続定理」の5節 | 見出しは保ち（処理系のコメントが「Scope の必須の判定の受理と拒否の理由」を引く）、本文を篩付きの `Surface.ScopeRules`・`ScopeSound`・`ScopeState`・`ScopeLower`・`ScopeAccept`・`CheckAccept` が今示す定義と定理だけで書き直した（約190行を約50行に）。規則の表の詳細は既存の「篩を含む表層の検査と受理」に写してあるので重ねない |
| 01-12「Logの通常宣言とハンドラの具体例」 | 対応物がないので節を除いた（見出しの参照は改造の記録だけで、処理系・道具・試験にはない） |
| 01-12「Resultの法則と二引数辞書の具体例」 | 削除した `Surface.Monad2Examples` の段落を除き、`Library.ResultLaws` の記述を残した |
| 01-12 の根拠の文（効果の被覆・V-Prim・網羅性の拡張・表層の型付けの範囲・継続の対象の伝播・範囲の正規化） | 削除したファイルと定理を引く文を除いた。`CoverageExtension` は篩付きの `Release/Refinement/CoverageExtension.lean` に改めた |

残っているもの（この区間で終えられなかった）:

| 箇所 | 内容 |
|---|---|
| 01-12「構築器の分類と環境の対応」〜「構築器の局所宣言と捕捉」の5節（約155行） | 旧 Release の構築器の補題と旧 Surface の構築器（`Surface.Builders`・`BuilderLower`・`BuilderFree`・`Lemmas.Builder*`・`Check`）を正とする。篩付きの表層の構築器の形式化との対応を一つずつ確かめて書き直す必要がある |
| 07-04「目的と範囲」の段階の記述と「篩型は初回リリース版に含めない」、「証明する性質」の冒頭と旧 Release の主定理の【決定】（44〜64行付近） | 同じ名前の篩付きの定理（`Refinement.MainTheorems` の `step_target_sound`・`reachable_target_sound`、`Refinement.SurfaceMain` の `surface_target_sound`）はあるが、前提と結論の形が違う（範囲の環境 σ など）。段落ごとに今の言明へ書き直す必要がある |
| 07-04 の 696・698・724・726・846・1079・1129 行付近と「以下の既存の表」の旧ファイルの行 | 削除したファイルの名前 |
| `formal/README.md` | 段階 A（`Core/`）・段階 C（旧 `Surface/`）・旧 `Release` の削除したファイルの行と、旧主定理の `#print axioms` の一覧 |

### 3. 固定入力の試験

| 試験 | 前 | 後 | 処置 |
|---|---:|---:|---|
| width | 1 | 0 | 符号なしの負号の拒否の理由を `operator has no primitive` にした |
| try | 10 | 0 | 終了の契約の偽りの拒否の理由と位置を新しい検査器のものにした（どれも拒否のまま） |
| batch2 | 4 | 1 | 拒否の理由3件を合わせた。残る1件は受理への変化（下） |
| batch3 | 33 | 0 | 候補の型パラメータの種類の誤り（下）を直した。旧の版の拒否の試験は、版より先に旧の構築器の欄で断るので、構築器を除いた入力で確かめる形にした |
| batch4 | 18 | 0 | 候補の型パラメータの種類を直し、拒否の理由・位置を合わせた。旧の参照の欄は文書の根でなく入力の中に置いた（根の未知の欄を先に断るため） |
| batch5 | 0 | 0 | 書き出しの照合の、L70.42 が除いた補助（`explicit_top_ranges`）の呼出しを除いた |
| named | 27 | 10 | 拒否の理由・位置を合わせ、候補が欠いていた `tparamKinds` を足した。演算子の偽りは準備の段の拒否（終了2）になった。残る10件は下の取得関数の差 |
| extensible | 54 | 1 | 候補の誤り（option の `variances` が数、`dataTypes` の `constructors` の欠け）を直し、網羅しない照合の拒否の理由と、構成子名の欠けの拒否の文言を合わせた。残る1件は下の取得関数の差 |
| range（`test_range_exchange.py`） | — | 0 | 前の区間で直した |

期待を変えたのは、変更前も変更後も拒否する入力で、新しい検査器の拒否の理由がその入力の誤りに当たるものに限った。終了状態は、named の演算子の組込みの引数名の偽りの1件だけが、検査器の拒否（終了1）から準備の段の標準表との照合の拒否（終了2）に変わり、ほかは同じである（RV-L70.g 軽5。[results-claude.md](results-claude.md) の「RV-L70.g の処置」）。

候補の誤り: batch3・batch4 の `fn:220`〜`223` の不一致（前の区間で4件）は、候補が型構成子に適用する型パラメータ（`tapp` の頭）と `Functor2`・`Applicative2`・`Monad2` の引数の種類を `value` と書いていたためだった。処理系の書き出しと同じく `{"constructor": {"arity": 2}}` にした（台本 `<tmp2>/fix_kinds.py`。各7箇所。`manifest.json` の指紋を更新）。直した後は一致した。

残る失敗（分類した原因だけ）:

| 試験 | 件数 | 原因 |
|---|---:|---|
| named（`test_six_entries`・`test_effect_order_and_membership`・`test_comparison_preserves_names_and_source_positions`） | 10 | 取得関数の結果型の篩。篩付きの脱糖は取得関数 `Pair.left` の結果型に欄の関係の篩を付ける（群 K2 の `accessorRet`）が、交換の核（処理系の書き出しと同じ形）は付けない。脱糖の比較が `definition.header.ret` で一件ずれ、件数を数える試験が落ちる。処理系の新しい書き出しでも同じ差が出る（generated-record-property の取得関数5件） |
| extensible（`test_closed_current_input_is_accepted_by_all_entries`） | 1 | 同上（named の入力を読む） |
| batch2（`test_clause_metadata_and_scope`） | 1 | 拒否から受理への変化。節の辞書の証拠の番号 `constraint` を 1（節の辞書は一つ）にした入力を、旧の検査器は `clause dictionary scope mismatch` で断り、篩付きの検査器は受理する。`ClauseScope.slot` の `dictCount - 1 - i` が自然数の引き算で 0 に切り詰まり、番号 1 が番号 0 と同じ位置を指すため、脱糖した項は正しい入力と同じになる。検査器は位置の辞書の型だけを照らし、番号が節の辞書の数より小さいことを確かめない。期待は変えていない |

範囲の予算の試験・既知の差の試験・区間の交換の試験（固定入力だけ）は終了0。

### 作業末の検査

| 検査 | 結果 |
|---|---|
| 既定ビルド（共有ロック下） | 終了0（2,323ジョブ）。この区間で Lean のソースは変えていない |
| 公理監査（`verify_g2.py`。足した16・変えた48モジュールの全9,981宣言） | `sorryAx` と新しい公理は0。前の区間と同じ件数 |
| 照合（`verify_g2.py`） | 成功 |
| `cargo test -p benitoite --test desugar_export --test coverage_export` | 終了0 |
| `python3 -B -m unittest scripts.check.test_policy` | 終了0 |

### 取りまとめに判断を求める点

1. 新しい書き出しの1,455入力のうち、評価できた1,454入力の全てが準備の段で断られる（`Http.sendIn`）。R50 までは、交換の表層の検査の比較（F-REG の surfaceCheck・surfaceCheckAll）に中身がない。
2. 新しく見つけた原因「鍵の型パラメータの等値の印」（15名・11入力）をどの単位で0件にするか。
3. 取得関数の結果型の篩（群 K2）による脱糖の比較の差。処理系の書き出しの全ての取得関数に出るので、F-REG の desugarDiff の不一致になる。どの単位で揃えるか。
4. 節の辞書の証拠の番号の範囲を検査器で確かめるか（今は受理。脱糖の結果は正しい入力と同じ）。
5. `check_named.py` と `test_batch2_exchange.py` の書き出しの照合を、準備の失敗で止まらない分類の形に直すか。
6. 01-12 の構築器の5節、07-04「証明する性質」と「目的と範囲」、07-04 の旧ファイルの名前、`formal/README.md` の書き直しを、どの単位で行うか（上の「残っているもの」）。

## 三人目の Claude の担当の区間とそれ以後

三人目の Claude の担当の区間（7523c6fb から）、その続き（f7de1668 から）、RV-L70.g の処置の記録は [results-claude.md](results-claude.md) に分けた。
