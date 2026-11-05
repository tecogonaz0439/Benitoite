# L70 の詳細化の記録（下書き）

2026-11-06。計画担当が [detail.md](detail.md) と [tables.md](tables.md) を作成した記録である。実装・独立レビュー・段末の受け入れの記録ではない。

## 基準と操作

| 項目 | 値 |
|---|---|
| ブランチ | `m014/l70-plan`（取りまとめが作成済み。切替・作成・コミットをしていない） |
| B_WORK | `3bf88a9c208af7b09b487efd2b598d74c0f09f27` |
| 変えたもの | 本書・detail.md・tables.md と、短い試行の入力3件（counts-trial.lean・shapes-trial.lean・axioms-trial.lean）を本ディレクトリに置いた。`formal/`・処理系・設計書・plan・レビューの記録は変えていない。`formal/.lake` は既定ビルドの出力で更新された |
| git | 読み取り（`git log` で `R/FiniteStepPreservation.lean` の出どころを確認）だけ。書き込みの操作はしていない |
| `scripts/check.sh` | 実行していない |

## 実行したコマンドと結果

| コマンド | 終了 | 外側の時間・資源 | 用途 |
|---|---|---|---|
| `formal/` で `/usr/bin/lockf -t 3600 <tmp>/lean-build.lock lake build`（対象を指定しない既定ビルド） | 0 | 8分42秒（user 1301秒）。1330 jobs。写した `.lake` が最新の取り込みより古く、再ビルドを含む | 試行の前に成果物を現行ソースへ揃える |
| `lake env lean -M 12288 <tmp>/counts.lean`（[counts-trial.lean](counts-trial.lean) と同じ内容） | 0 | 1秒程度、最大常駐量は約1.86 GB（`/usr/bin/time -l` の値。補助値であり正式な RSS ではない） | 構成子の数（detail.md 第2.1節） |
| `lake env lean -M 12288 <tmp>/shapes.lean`（初回） | 1 | 1秒程度 | 旧の `B.Allows` に当たる `Builtins.Allows` が新判断に無いことで失敗 |
| 同（`Eff.Allows σ B.effKind` へ直した後。[shapes-trial.lean](shapes-trial.lean)） | 0 | 1秒程度 | 主定理の言明の形、`State.Final`、合成表の当て方、R10・R9(a) の篩の形 |
| `lake env lean -M 12288 <tmp>/ax.lean`（[axioms-trial.lean](axioms-trial.lean)） | 0 | 1秒程度 | `StateTyE.step_preserved`・`steps_preserved` の公理依存（propext・Classical.choice・Quot.sound）と署名 |

試行の入力の SHA-256 は次である。

| ファイル | SHA-256 |
|---|---|
| counts-trial.lean | `35766b9bb7fc2125af7ec8ca78252adaefe02690eb30600e0eedcbbdf2d387f5` |
| shapes-trial.lean | `f9d3709cc2f356c5cfbd55475e23ceca303551a3c386878c45c040fcd1e1561c` |
| axioms-trial.lean | `bf88707e85725333071d09a962edd076235bf0b5a7d7a2600358b8396a38d4e6` |

大きな具体値を作る評価はしていない。試行は宣言の型検査と構成子の数の読み出しだけである。

## 計画からのずれと申し送り

- L60 の「旧主定理と新しい葉の対応」は保存の行に `StateTyE.step_preserved` を挙げていないが、L40 群 E（2026-11-04）が置いたこの定理は全76遷移の `StateTyE` の保存を既に閉じている。detail.md の C01 として差し引き、群 B を小さくした。義務 O038・O058 の判定の根拠が変わるので、取りまとめが plan の O038・O058 の行と L40 の判定を照合することを勧める。
- L70 の枠の内の積上げ（41時間35分〜72時間25分）が plan の上端62時間を超える。detail.md 第7.3節 J70-6 として挙げた。
- 所要時間（能動時間）の実績は、本下書きでは記録していない。外側の時間はおよそ2時間半であり、能動時間と待ち（既定ビルドの8分42秒を含む）を分離していない。

## 再開1: RV-L70-plan と J70-1〜6 の反映（2026-11-06）

取りまとめの依頼により、[RV-L70-plan](../reviews/RV-L70-plan.md)（条件付き可、重4・中2・情報1）の所見と、設計者の J70-1〜6 の決定（本体の作業木の plan「計画の変更と取りまとめへの確認点」と README「設計者の決定」の2026-11-06の項。本 worktree の plan・README は変えていない）を detail.md・tables.md に反映した。処置の範囲は指摘の箇所に限った。Lean・cargo・`scripts/check.sh` は実行していない。git の書き込みはしていない。

### 処置の一覧

| 所見・決定 | 処置した場所と内容 |
|---|---|
| 重1 | detail.md F03 を (1) 旧宣言の移送（`Program.HasData`、8欄に逆向きの条件 `consClosed` と変性の宣言の一致 `dataInfoOld` を加えた `Program.Extends`）と (2) 追加宣言を検査した後の全体の合成（`Program.Additions`・`Program.compose`、供給元は性質1）に分けた。網羅性・arity・変性・型の宣言・`MetadataScoped`・`EffectsOk` の読み方の照合と完全署名を群 A の完了条件にした（L70.05a、第4.1節）。第2.3節の母集団と L70.17 を改めた |
| 重2 | F03 (3) に `StandardModel.Completion`・`completion_core` の契約を置いた。合成済みの名前は C06、仮定側は区分ごとの欄（δ80・IO47・通常資源の状態16・形式化の外7）で受け、区分を混ぜない。群 A の L70.05b で固定し、L70.18・.19、第8.4節の R40・R50 の行、tables.md の「L60-仮定150」に反映した。形式化の外の7名を呼ぶプログラムへの系の扱いを J70-8 として問う |
| 重3 | L70.03 の棚卸しに7入口から判断を読む経路（`CheckAccept.checkProgramAccepted`・`Check.checkDef`・`CheckAccept.acceptDef`、`Exchange.CheckInput.prepare`、`Exchange.Builtins`、`CheckTables`、`CoverageShow`、`Exchange.Observe`、区間の交換の層）を加え、移植・継承・削除に分ける（互換専用の層は置かない）。第2.5節に受理の母集団、F06 に「型付けと受理の両結論」と `noRules` を実入口に使わない条件を加えた。L70.31b（受理）と L70.40b（入力形成の層）を足し、L70.41 は群 E の新しい入口を読むことを条件にした |
| 重4 | 第8.3節の Rust 開始の条件を、新しい版で書き出し直した所定の全コーパスで全比較が成功し、不一致・未処置の失敗・未承認の入力省略と除外の追加が無いこと、旧外部除外の実数と理由を R50 の両理由0件と区別して保存したこと、結果が最終の定義・交換器・書き出し・入力・manifest・設定と対応することに改めた |
| 中1 | detail.md 第2.9節に新しい関数の完全署名の表（`Refinement.check`・`CheckError`・生成判定関数・`Scope.pathMatches`・`hostMatches`・`String.charactersIn`・Float の分類）を置き、L70.02 を表と Lean の定義の対応だけにした。設計者の選択が残る欄を J70-9〜J70-11 に分けた |
| 中2 | J70-5 の決定で処置した。F09 に削除の範囲と三つの完了条件（削除後の閉包、逆戻りの照合、残す旧 Release の一覧と役割）を書き、L70.03・.44 に割り当てた |
| 情報1 | 処置なし（C01 と L70.09 を維持） |
| J70-1 | F08・第2.6節・第8.2節を、新しい版だけを置き、処理系の書き出しを改めて既存コーパスを書き出し直す形に改めた。L70.08 は旧版を版の誤りで断る reader、L70.42 は互換 reader に代えて処理系の試験の側の書き出しの改め（W-R）にした。C05 は reader に使わない |
| J70-2〜J70-4 | 推す案のまま。第7.3節に決定として記した |
| J70-5 | F09・L70.44・第7.4節に削除の範囲を書いた。tables.md の O042・O159・L20-J5・plan-1103・L60-群D を直した |
| J70-6 | 枠を改めず、第8.1節の一群と群 A・B の通常の結果報告で外挿すると記した |

### 件数の変化

| 項目 | 初版 | 再開1 |
|---|---|---|
| 作業単位 | 49 | 52（L70.05 を .05a・.05b、L70.40 を .40a・.40b に分け、L70.31b を足した） |
| 申し送り | 78 | 78（受け持つ単位と完了の判定を5行で直した。行は増減なし） |
| 義務 | 59（技術49・記録3・共通6・他段1） | 59（分類は同じ。O042・O086・O121・O159 の判定を直した） |
| 分岐する判断 | 6（J70-1〜6） | 6件は決定済み。新しく5件（J70-7〜J70-11） |

### 見込みの変化

| 区分 | 初版 | 再開1 |
|---|---|---|
| 枠の内 | 41時間35分〜72時間25分 | 46時間50分〜80時間40分（中心63時間45分）。枠の上端62時間を18時間40分超える |
| 枠の外：U02 の6件と Q2 | 4時間45分〜9時間 | 同じ |
| 枠の外：J50-1 | 1時間〜2時間 | 同じ |
| 枠の外：J70-1・J70-5 の増分 | — | 1時間30分〜3時間 |
| 計 | 47時間20分〜83時間25分 | 54時間5分〜94時間40分（中心74時間22分） |

枠の内の増分（5時間15分〜8時間15分）は、重1・重2の収集の契約（.05b の新設、.17・.18・.19 の拡大）、重3の受理と入力形成の層（.03 の拡大、.31b・.40b の新設）、区間の交換の層の移植（.43 の拡大）で、中1の処置で L70.02 が15〜30分減った分を差し引いた。J70-6 の決定により枠は今は改めない。

### plan の文の改め方の案（J70-1・J70-5・重4）

plan の文は取りまとめが改める。次は案である。

| 場所 | 現在の文（要旨） | 改める文の案 |
|---|---|---|
| 段の表の L70 の行の「接続とレビューの完了条件」 | 既定 build/公理依存と既存コーパス全比較 F-REG を通して Rust 開始を許可 | 既定 build/公理依存と、新しい版で書き出し直した既存コーパスの全比較 F-REG の成功（不一致・未処置の失敗・未承認の入力省略と除外の追加なし）を通して Rust 開始を諮る。旧 Surface と旧主定理を削除し、旧 Release の判断は埋め込みの定義域として残す（J70-5） |
| 検査の割り当ての「check-formal全体 F-REG」の行 | L70末、変えていないRustの既存コーパスと新Lean。旧交換の互換reader等はL70の内側の作業として置き、旧Rustを新機能対応に変えない | L70末、交換の書き出しだけを新しい版へ改めた処理系（型検査・脱糖・網羅性の判定・区間解析・実行の実装は変えない）で書き出し直した既存コーパスと新Lean。旧版の交換は廃止し、互換 reader を置かない（J70-1）。書き出しの改めは L70.42 が受け持ち、篩・新しい σ・外部の接続の実装を含まない。既存の受理の保存の回帰であり、篩/新σ/externalのRust接続完了とはしない。旧除外は実数/理由を保存し、R50の0件の代わりにしない |
| 残りの手順と見込みの L70 の行 | 互換reader/規範切替/主定理閉鎖を含む | 書き出しの新版（L70.42）/旧 Surface と旧主定理の削除/規範切替/主定理閉鎖を含む。J70-1・J70-5 の増分は枠の外に別に計上する |
| 「L70 の切替の完了条件」の第2段落の最初の文 | 旧判断と旧主定理はこの区切りで削除するか、旧導出の適格な埋め込みだけを述べる互換モジュールとして役割と利用者を明記して残す | 旧 Surface と旧主定理はこの区切りで削除し、旧 Release の判断は旧導出の適格な埋め込みの定義域としてだけ残し、役割と利用者を明記する（J70-5）。削除後の既定 import と依存の閉包を監査し、新しい主定理・表層・交換が旧判断へ戻らないことを照合する |
| 結果とレビュー修正の管理の L70/F-REG の行 | 既存コーパス回帰は新機能のRust接続の証拠にしない | 新しい版で書き出し直した既存コーパスの回帰は、新機能のRust接続の証拠にしない。書き出し直しの入力・処理系の版・manifest を保存する |

L70.42 は処理系の試験の側の書き出しを変える作業で、R10a 以降の型表現・推論・実行の変更ではない。「Rust の開始」は R10a 以降を指すと読める書き方にする必要がある。その文は取りまとめが選ぶ。

## 再開2: 再重1と J70-7〜10 の反映、J70-11 の材料（2026-11-06）

取りまとめの依頼により、RV-L70-plan の処置の確認の再レビュー（重1・重3・重4・中1・中2は可、重2は不可で再重1）の再重1を処置した。あわせて、設計者の J70-7〜10 の決定（本体の作業木の plan「計画の変更と取りまとめへの確認点」の先頭）を反映し、J70-11 の材料を Web の公式の文書で調べた。git の書き込みと `scripts/check.sh` は実行していない。

### 処置

| 項目 | 処置した場所と内容 |
|---|---|
| 再重1 | detail.md F03 (3) を書き直した。`CoreAssumptions` の28欄（`ExternalAssumptions` の3欄を含む）と `TargetAgreement` の1欄、計29欄を、R/ConstraintAssumptions.lean・SubstitutionContracts.lean・ExternalResponse.lean・BuiltinResponse.lean の宣言を読んで一欄ずつ「表全体」「名前ごと」に分け、供給元を表にした。表全体12、名前ごと17（合成済みを C06 から移し仮定側を `Completion` から受ける15、仮定側では kind の制限で空になる2）。完成した表 `StandardModel.complete` と、`RowConditions`・`ReleaseOn`・`TableConditions`・`AssumedTable`・`NameLists`・`Completion`・`composed_rows`・`composed_release`・`table_conditions`・`completion_core` の署名を置いた。L70.05b の完了条件と群 A の必須条件にし、L70.18・.19・群 C・F2 と tables.md の「L60-仮定150」「L60-S05」「L60-受口5」の判定をこの契約へそろえた |
| 契約の型検査 | [completion-trial.lean](completion-trial.lean)（SHA-256 `fbb2a96ff60d385f35c20bd845ec7d69f83042776fe3f5c86c3d3ce601a780e2`）を `formal/` で `lake env lean -M 12288` により検査した。初回は `CompletionCoreStatement` の引数の型を省いたため推論の誤りで失敗し、型を書いて終了0、外側0.81秒（`/usr/bin/time -l`、最大常駐量は補助値で約1.87 GB）。外部の3欄を `ExternalModel.external_assumptions P _ _` で得る適用例も通った。限界: 試行の `complete` は効果表を合成表のまま置き、`Completion` の kind の欄は io・exit だけである。`composed_rows` などの証明はしていない |
| 新しい危険 | C06 の行の証明は固定の表について述べるので、仮定側の `.prim` を関数の引数に持つ値（L60 の関数値が到達しうる27行）では結論を移せない。`composed_rows` で行の入口を一般化する作業を L70.18 に置き、どの行が固定の表の他の名前を読むかを L70.05b で数える。新しい証明の方式が要れば停止条件へ戻す |
| J70-7 | `formal/Benitoite/Core/` を L70.03 の削除の集合・L70.44・F09 の完了条件1・第7.4節に加えた |
| J70-8〜10 | 第7.3節に決定として記した。第2.9節の表の J70-9（結果の型に一致の篩）と J70-10（pattern は絶対形だけ）を反映した。実行時の文字列が相対形のときの `pathMatches` の結果は L70.37 で δ の定義として固定する（候補は false、未決） |
| J70-11 | detail.md 第2.9.1節に、Rust・Java・C#・JavaScript・Haskell の公式の文書で確かめた名前と URL（取得日2026-11-06）を表にした。Swift は頁の本文を取得できず未確認。推す案 A（6類と一対一の `isFinite`・`isInfinite`・`isPositiveInfinity`・`isNegativeInfinity`・`isPositiveZero`・`isNegativeZero`）と案 B（符号の判定を使う）を比べた |

### 見込みの変化

L70.05b を60〜90分から90〜120分へ、L70.18 を90〜150分から120〜210分へ、L70.44 を90〜150分から105〜165分へ（J70-7 の15分）改めた。単位の数は52のまま。

| 区分 | 再開1 | 再開2 |
|---|---|---|
| 枠の内 | 46時間50分〜80時間40分 | 47時間50分〜82時間10分（中心65時間）。枠の上端62時間を20時間10分超える。J70-6 により枠は今は改めない |
| 枠の外：U02 の6件と Q2 | 4時間45分〜9時間 | 同じ |
| 枠の外：J50-1 | 1時間〜2時間 | 同じ |
| 枠の外：J70-1・J70-5（再開2で J70-7 を加えた） | 1時間30分〜3時間 | 1時間45分〜3時間15分 |
| 計 | 54時間5分〜94時間40分 | 55時間20分〜96時間25分（中心75時間53分） |

detail.md が100 KB を超えたので、第2.9節（新しい関数の署名と J70-11 の材料）を [signatures.md](signatures.md) へ分けた。分けた後の detail.md は約102 KB である。

## 再開3: 3回目のレビューの重1と J70-11 の反映（2026-11-06）

3回目のレビュー（不可。`Completion.effKindFresh` が合成表の `none` の効果のラベルを保護せず、A が `effKind "Console.Write" = some .path` を足すと合成済みの `print` の `io_op` が崩れる反例）を処置した。git の書き込みと `scripts/check.sh` は実行していない。

| 項目 | 処置 |
|---|---|
| `complete` の全欄の確認 | `Builtins` の全14欄を一欄ずつ確かめ、collection.md F03 (3) に表にした。A が合成済みの側を変えられた穴は `effKind`・`isResource`・`releaseResponse` の三欄と、`effects` に仮定側の操作が入らないことの計四つだった。`sig`・`delta`・`ioResponse` は名前で分けてあり穴は無く、`sat`・`refGet`・`refSet`・`valKind`・`admitsR`・`valContent`・`externalResponse` は合成表のまま（又は L60 の汎用の構成）で A が触れない |
| 直した構成 | `completeBase` で、`effKind` をラベルの一覧 `L.composedEffects`（合成表の効果表が成功する全ラベル）で分け、一覧の中は `none` を含めて合成表の値にした。`isResource` を資源の一覧で分けた。`effects` は合成表の一覧の後ろに仮定側の操作を足した |
| 直した条件 | `NameLists.WF`（合成済みと仮定側が交わらない、合成表で成功する全ラベルが `composedEffects` にある、資源の一覧の名前が合成表で資源でない）。`Completion` に `kinds`・`effKindComposed`（`composedEffects` のラベルで A が種類を与えない）・`stateFree`（仮定側の操作が `State` を使わない）・`releaseComposed`（合成表の資源の値に解放の応答を足さない）を加えた。任意の B への一般化の前提 `ComposedAgree`（合成済みの名前の署名・応答の一致、効果表の所属の保存、`composedEffects` の `effKind` の一致、資源の一致、`sat`・`valKind`・`valContent`・`admitsR`・`refGet`・`refSet` の一致）を置き、`composed_rows` と `completion_core` の署名に `NameLists.WF` と `ComposedAgree` を渡した |
| Lean の確認 | 直した [completion-trial.lean](completion-trial.lean)（SHA-256 は下）を `formal/` で `lake env lean -M 12288` により検査し、終了0（外側約7秒、`/usr/bin/time -l` の最大常駐量は補助値で約3.3 GB）。`complete_effKind_composed`・`complete_shapeOk_composed`（合成表の `ShapeOk` から完成した表の `ShapeOk`）・`complete_agree`・`complete_state_effect`・`reviewA_not_completion`（レビューの反例の A は、`"Console.Write" ∈ L.composedEffects` のとき新しい `Completion` を満たさない）を証明した。`(baseBuiltins.effects "Console.Write").isSome` は `decide` で確かめたので、整形式の一覧では必ず前提が成り立つ。公理依存は propext・Classical.choice・Quot.sound だけ。途中で、最初の版の未使用の仮定の警告を一度直した |
| 単位と判定 | L70.05b・.18、群 A・C・F2、tables.md の「L60-仮定150」「L60-S05」を新しい契約にそろえた |
| J70-11 | signatures.md に決定（6類と一対一の名前。Float に6、Float32 に5を足す）を記した。初版の「Float は8名のうち新7」を「7名のうち新6」に直した |
| 大きさ | detail.md の第3節 F03 を collection.md へ分け、detail.md を約86 KB にした |

見込みは L70.05b を90〜120分から105〜135分へ広げただけである。枠の内は48時間5分〜82時間25分（枠の上端を20時間25分超える）、計は55時間35分〜96時間40分（中心76時間8分）になった。単位の数は52のままである。
completion-trial.lean の SHA-256: `304b79669cc6d5a2d9e6e5443d385d4268ac09cfbe99826eea9bf91c06345c6f`
