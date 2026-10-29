# L00.01 案 (i) の結果: 範囲を既存の構成子の引数に置く

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L00.01 のうち案 (i)。もう一方の案 (ii) の欄は書かない（取りまとめが合わせる） |
| B_WORK | `6124775788579e60530f55fb85570f26ef7fa900`（B0） |
| 作業用のディレクトリの HEAD | `1009954381de6dd2f4a082b16221f3c762303bd3`（detached。B0 から `formal/`・`crates/`・`scripts/` に差はない） |
| 閉じた範囲 | 既存の構成子を実際に変えた試行（30回の比較用ビルド）、件数の集計、試行の取り消し、独立の比較用の模型 `formal/Benitoite/Scope/RepresentationExamplesI.lean` と既定の import への一行の追加、既定のビルドの成功 |
| 未完の範囲 | なし（依頼の範囲内）。採用は決めていない。格納方式の確定と候補の削除は L00.08 が行う |

## 変更と接続

受け渡す状態の変更は二つだけである（`handoff.diff`）。

- 新規 `formal/Benitoite/Scope/RepresentationExamplesI.lean`（名前空間 `Benitoite.Scope.RepresentationExamples.CandidateI`）。`Release` の定義を変えない独立の模型であり、`Release.Effect` と `Release.Order.Atoms` だけを import する。
- `formal/Benitoite.lean` の末尾に `import Benitoite.Scope.RepresentationExamplesI` を一行加えた。

旧の主定理（`Release.progress`・`preservation`・`effect_soundness`・`Surface.desugar_typed` など）と既存の小補題は変えておらず、既定のビルドの対象のままである。01-12・07-04・設計書は変えていない（比較用の模型であり、採用した規則ではないため）。

模型の内容は次のとおりである。

| 群 | 宣言 |
|---|---|
| 範囲 | `ScopeRange`（`top`・`pathExact`）、所属 `Mem`、一原子の被覆 `within` と `within_sound`・`within_refl`・`within_trans` |
| 順序の符号 | 範囲の符号 `ScopeRange.code`、Cantor の対の符号 `pair`（閉じた形）と `pair_injective`、`ScopeRange.code_injective`、範囲付きの原子の `Atom.code_injective`。文字列の符号の単射性は `Release.Order.Atoms` の非公開の補題と同じ証明を写した |
| 原子と Top の対応 | 範囲付きの `Atom`、旧の原子を Top へ写す `Atom.ofRelease` とその単射性、Top だけが戻る `Atom.toRelease?` と往復・逆向きの補題、旧の所属関数を写す `liftAtoms`（単射、非 Top を含まない、旧 `Eff.single l` が Top の一原子へ写る） |
| 値型 | 範囲付きの `ValTy.opaque o r`、旧の不透明型の Top への写像、`pathIn r`（`Scope.PathIn[R]` に当たる）、所属 `Holds`、構造の等号から範囲の違いを区別する `pathIn_ne_of_ne`、被覆による広い型への所属 `holds_widen` |
| 署名 | 操作の識別子 `OpId`、具体化した署名 `Sig`、`readTextIn r`。識別子が範囲に依存しない `readTextIn_op`、入力の添字と効果の原子が同じ範囲を指す `readTextIn_same_range`、一段の対象の上限への所属 `readTextIn_target_allowed` |
| 非空の例 | `pathExact ["data","a"]` への所属・非所属、Top への所属、型の非等号、旧の裸の型と Top の一致の `example` 5件と `#guard` 10件 |

## 試行の内容

同じ基準から、既存の構成子に範囲の引数を加え、比較用ビルドで壊れた箇所を一層ずつ直した。lake は失敗したモジュールに依存するモジュールを検査しないので、1回のビルドで分かる破損は最初に失敗した層だけである。そこで、直接の利用側を一群ずつ直して再び走らせ、最後に全体が通るまで続けた。試行は三つの系列に分かれる。

| 系列 | 試行 | 内容 |
|---|---|---|
| A 既定引数なし | 1〜3 | `Release/Atom.lean` に比較用の `ScopeRange`（`top`・`pathExact`）を置き、`Atom.name (l) (r : ScopeRange)` と `Ty.opaque (o) (r : ScopeRange)` に変えた（試行1）。直接の利用側の一群として `Order/Atoms.lean` の符号と単射性（試行2）、`Order/Types.lean` の順位・木・比較（試行3）を直した |
| B 既定引数を Top にする変種 | 4〜18 | 両構成子の範囲の引数に既定値 `:= .top` を付け、構築の箇所を変えずに済むかを確かめた。match の腕に引数を足す機械的な書き換え（`tools/fixarms.py`）と、言明・証明の手直しを層ごとに加えた。試行18で全体が通った（23ファイルの変更） |
| C 既定引数なしと Top の構築関数 | 19〜30 | 既定値を外し、`abbrev Atom.nameTop l := .name l .top` と `abbrev Ty.opaqueTop o := .opaque o .top` を加えた。型の不一致の位置の構成子を構築関数へ置き換える書き換え（`tools/fixtop.py`）と手直しを層ごとに加えた。試行30で全体が通った（56ファイルの変更、`trial-30-final.diff`） |

各試行の差分は `trial-<n>.diff`、ビルドの全出力は `build-<n>-trial.log`、宣言・ファイル・未検査の集計は `counts-<n>.json` に置いた。数え方は `tools/count_breaks.py` であり、誤りの診断の位置を、ビルドした時点のソース（基準に試行の差分を当てた写し）で直前の宣言へ対応付けた。`sorry` を含む警告は誤りから生じたものとして別に数えた。

## 比較用ビルドごとの終了・時間・件数

時間は `/usr/bin/time -l` の内側の経過時間（秒）、最大常駐量はその出力の maximum resident set size（バイト）である。排他の待ちは道具がログの先頭に出した値であり、時間に含めない。「未検査」は、失敗したモジュールに推移的に依存するため lake が検査しなかったモジュールの数である。変更した二モジュールに推移的に依存するモジュールは、既定の入口の実行ファイルの根を含めて243ある。

| 試行 | 終了 | 排他の待ち(s) | 時間(s) | 最大常駐量(バイト) | MiB | 誤りの診断 | 壊れた宣言 | 壊れたファイル | 未検査 | 失敗したモジュール |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 0（基準） | 0 | 0 | 0.15 | 69419008 | 66 | 0 | 0 | 0 | 0 | |
| 1 | 1 | 0 | 1.82 | 692944896 | 661 | 6 | 2 | 1 | 240 | Release.Order.Atoms |
| 2 | 1 | 0 | 3.27 | 769916928 | 734 | 11 | 5 | 1 | 237 | Release.Order.Types |
| 3 | 1 | 0 | 2.74 | 777093120 | 741 | 5 | 5 | 1 | 236 | Release.Normalize |
| 4 | 1 | 0 | 3.47 | 779599872 | 743 | 10 | 6 | 1 | 236 | Release.Normalize |
| 5 | 1 | 0 | 2.64 | 741834752 | 707 | 7 | 6 | 1 | 234 | Release.TypeShift |
| 6 | 1 | 0 | 2.14 | 781860864 | 746 | 5 | 5 | 1 | 232 | Release.TypeSubst |
| 7 | 1 | 14 | 2.94 | 760561664 | 725 | 3 | 2 | 1 | 220 | Release.TypeSubstLemmas |
| 8 | 1 | 0 | 1.18 | 724828160 | 691 | 8 | 4 | 1 | 219 | Release.TypeRows |
| 9 | 1 | 0 | 0.97 | 705986560 | 673 | 3 | 2 | 1 | 218 | Release.TypeComposition |
| 10 | 1 | 1 | 2.12 | 723730432 | 690 | 8 | 7 | 2 | 215 | Release.Finite, Release.NoFail |
| 11 | 1 | 0 | 3.15 | 774586368 | 739 | 2 | 2 | 1 | 212 | Release.Typing |
| 12 | 1 | 0 | 11.96 | 1606582272 | 1532 | 11 | 6 | 2 | 201 | Release.BuiltinTable, Release.TypeBounds |
| 13 | 1 | 22 | 1.19 | 734052352 | 700 | 9 | 4 | 1 | 198 | Release.TypeVariables |
| 14 | 1 | 0 | 3.97 | 832864256 | 794 | 4 | 3 | 1 | 189 | Release.TypeScopedSubst |
| 15 | 1 | 0 | 10.52 | 946651136 | 903 | 19 | 6 | 2 | 180 | Release.CoverageTypes, Release.Lemmas.Closed |
| 16 | 1 | 0 | 130.71 | 1670414336 | 1593 | 9 | 9 | 3 | 76 | Surface.FiniteExamples, Surface.Lemmas.ShiftClean, Surface.NoFailCheck |
| 17 | 1 | 71 | 158.85 | 1673199616 | 1596 | 4 | 3 | 1 | 48 | Surface.AdmissibleCheck |
| 18 | 0 | 156 | 26.21 | 2642198528 | 2520 | 0 | 0 | 0 | 0 | |
| 19 | 1 | 3 | 5.46 | 785629184 | 749 | 7 | 3 | 1 | 233 | Release.Effect |
| 20 | 1 | 0 | 5.87 | 742916096 | 708 | 1 | 1 | 1 | 223 | Release.Syntax |
| 21 | 1 | 0 | 2.63 | 778846208 | 743 | 2 | 1 | 1 | 212 | Release.Typing |
| 22 | 1 | 0 | 6.58 | 844464128 | 805 | 21 | 9 | 3 | 195 | Release.BuiltinTable, Release.Lemmas.Basic, Release.Semantics |
| 23 | 1 | 0 | 11.09 | 1396998144 | 1332 | 2 | 2 | 2 | 183 | Release.Assumptions, Release.Lemmas.Inversion |
| 24 | 1 | 136 | 56.51 | 1661435904 | 1584 | 15 | 8 | 4 | 144 | Interval.Analyze, Interval.EvalClosed, Release.Lemmas.ContLemmas, Surface.Typing |
| 25 | 1 | 0 | 40.36 | 1679491072 | 1602 | 7 | 4 | 4 | 106 | Interval.BudgetChildren, Interval.BudgetDiscover, Release.Lemmas.Progress, Surface.CheckTools |
| 26 | 1 | 3 | 52.17 | 1367801856 | 1304 | 7 | 4 | 3 | 65 | Interval.BudgetChildrenExamples, Release.Lemmas.EffectSound, Surface.CheckSupport |
| 27 | 1 | 142 | 33.24 | 1201389568 | 1146 | 6 | 1 | 1 | 46 | Surface.Check |
| 28 | 1 | 3 | 11.17 | 1462353920 | 1395 | 5 | 4 | 2 | 29 | Exchange.Convert, Surface.CheckSoundBasicExpr |
| 29 | 1 | 0 | 14.36 | 2642345984 | 2520 | 16 | 4 | 1 | 1 | SurfaceCheck.Validation |
| 30 | 0 | 0 | 1.81 | 1416577024 | 1351 | 0 | 0 | 0 | 0 | |

時間が短い試行は、それより上流の再ビルドが要らず、失敗した層で止まったためである。上流の `Order/Atoms` を変えた試行17は全体の再ビルドで 158.85 秒を要した。

系列ごとに一度でも壊れた宣言とファイルの一意数（`broken-union.json`）は、A が12宣言・3ファイル（診断22件）、B が65宣言・19ファイル（102件）、C が41宣言・23ファイル（89件）、全体で113宣言・42ファイル（213件）である。各系列は前の系列の修正を引き継いでいる（C は B の腕の修正の後に始めた）ので、系列の和は一つの試行の破損の総数ではない。

## 未検査の範囲と検出数の読み方

- 系列 A の試行1〜3は、243のうち236〜240モジュールを検査できていない。この段階の検出数（2〜5宣言、1ファイル）を破損の総数とみなさない。
- 全体の破損の規模は、全体が通った最終の差分（試行30）で数えた。56ファイル・132宣言で 251 行を加え 166 行を消した（`classify-30.json`）。うち新しく加えた宣言（範囲の型・符号・構築関数・補題）を含む。分類は字句の近似である（`tools/classify.py`。言明と証明の境目は最初の `:=` で区切る）。
- 試行の前に、変更した構成子を字面に書いた箇所を基準の状態で数えた（`census.json`。`tools/census.py`）。`Ty.opaque` が34ファイル・53宣言の70箇所（うち match の腕47）、`Atom.name` が37ファイル・77宣言の140箇所（腕16）、和は58ファイル・123宣言である。これは `.name` の記録の欄や Exchange の自前の型の構成子を除き切れない上限寄りの近似であり、構成子名を書かない `cases` の証明の破損を含まない。
- 試行の系列は、構成子の引数を変えた影響だけを測った。範囲付きの IO の署名（`io_op` の変更）、`io_target`、範囲の整形式性、非 Top の型付けの規則は試行に含めていない。これらの費用は L00.03 以降で別に測る必要がある。

## 言明の変更・証明だけの変更・波及（試行30の最終の差分）

| 区分 | 変更行 | 宣言 | ファイル | 内容 |
|---|---:|---:|---:|---|
| match の腕 | 57 | 45 | 23 | `.opaque o` → `.opaque o r`、`.name l` → `.name l r` の機械的な引数の追加。場合の数は変わらない |
| Top の構築関数への置き換え | 104 | 定義40・例15・証明6・言明17 | 35 | `.name stateEff` → `.nameTop stateEff`、`.opaque o` → `.opaqueTop o` など。`abbrev` なので項は旧と同じ Top の項であり、言明17件は字面の変更だけで意味は変えていない |
| 既存の定理の言明の一般化 | 6 | 5 | 3 | `Eff.mem_rawBind_rowImage`・`Eff.mem_bind`（`TypeComposition`）、`Eff.mem_substRho_rowImage`（`SubstEnv`）、`Eff.substRho_true_scoped`・`Eff.substAt_name`（`TypeScopedSubst`）。`∃ l, a = .name l ∧ …` を `∃ l r, a = .name l r ∧ …` に、`.name l` を `.name l r` に広げた。Top だけの形のままでは代入の補題が非 Top の原子について成り立たないか、意味が弱くなる |
| 証明だけの変更 | 61 | 14 | 5 | 上の言明の分解（`⟨l, rfl, h⟩` → `⟨l, r, rfl, h⟩`）、`Order/Types` の単射性、`Order/Atoms` の単射性など |
| 定義の意味の変更 | 20 | 10 | 3 | `Atom.code` を範囲込みの対の符号に変えた。`Ty.toTree`・`tyCompare`（`Order/Types`）・`tyCompareWith`（`Finite`）に範囲の比較を加えた。範囲の型・符号・構築関数を新設した |
| 交換の旧版との対応 | — | 3 | 1 | `Exchange/Convert`。旧版の原子・不透明型は Top として読み、範囲付きの不透明型の書き出しは旧版では誤りとして拒否する |

主定理の言明は一つも変わっていない。`Release/Theorems.lean` と `Surface/Theorems.lean` は差分に現れず、試行30で既定の全入口とともに通った。ただし、通ったのは、範囲を扱う定義を次のように Top に特化したからである。非 Top の型付けへの接続を示したことにはならない。

- `Eff.single l` は `.nameTop l` の一原子のままで、`io_op` の効果も Top である。
- `BuiltinOnly`（`StateTy` が使う継続の末尾の効果）は、Top の名前の原子だけを許す。
- `Builtins.Assumptions.release_exists`・`ContTy` の解放・Release と Surface の `use` の規則・`Const.type` は、`.opaqueTop o` の資源の型だけを扱う。

波及の差について、壊れ方は二種類だった。構成子の引数の数の変化は、腕と構築の箇所だけに及ぶ機械的な修正で閉じた（腕57行、構築104行）。一方、言明の一般化の5件は、その補題を分解する利用側の証明へ波及した。`Eff.mem_bind` の利用は `TypeComposition` の19箇所と `NoFail`・`SubstEnv`・`TypeScopedSubst` の各1箇所である。

## 試行で分かったこと

1. 既定引数を Top にする変種（系列 B）は、23ファイルの変更で全体が通った。しかし、パターンの `.name l` は黙って `.name l .top` の意味になる。網羅の検査が誤り（Missing cases）を出すのは、腕の受け皿がない場合だけである。受け皿の `_` がある match では、非 Top の原子が黙って別の腕へ流れる。言明の `.name l` も黙って Top だけの意味になる（例: `Eff.substAt_name`、`BuiltinOnly`、`release_exists`）。そのため、ビルドの成功から意味の保存を判断できない。系列 C の明示の構築関数は、全ての構築の箇所を型の誤りとして列挙させ、どこを Top に特化したかが差分に残る。案 (i) を採るなら、既定引数を使わず明示の構築関数を使うことを推す。
2. 比較の関数で範囲を落とす誤りは、比較と木の順序の一致の証明（`compareWith_eq_compare`、`tyCompare_eq_treeCompare`）が検出した。機械的な腕の書き換えで `.opaque a r, .opaque b r2 => stringCompare a b` になった箇所である。
3. 原子の符号に対の符号を再帰（`tri`）で定めると、`rfl` で具体の効果を比較する例（`Surface/FiniteExamples`）が再帰の深さの上限で失敗した（試行16）。閉じた形 `(a+b)(a+b+1)/2 + a` にし、再帰の定義は証明だけに使って解消した。
4. 交換の旧版は Top として読める。範囲付きの型の書き出しには新しい版のタグが要る（試行では旧版での書き出しを誤りとした）。

## 案 (i) の比較の欄

| 観点 | 案 (i)（範囲を既存の構成子の引数に置く） |
|---|---|
| 引数の数 | `Atom.name` が1→2、`Ty.opaque` が1→2。構成子の数は変わらない（`Atom` 2、`Ty` 15）。範囲の型（試行では `top`・`pathExact`）を一つ加える |
| 場合分け | 場合の数は増えない。両構成子を書く全ての腕に束縛を一つ足す（最終の差分で腕57行・45宣言・23ファイル）。既定引数を使うと、腕の不足が黙って Top への特化になりうる（上の1） |
| 比較（等号・順序） | 等号は構成子の構造の一致のまま（`DecidableEq` は導出で得る）。範囲が違えば型も原子も等しくない（模型の `pathIn_ne_of_ne`、判断 5・6 と整合）。固定順序のために、原子の符号の単射性へ範囲の分の補題（試行で5件）を加え、型の木・比較の3関数に範囲の比較を加える。具体の計算に使う符号は閉じた形にする |
| 整形式性 | 試行では `Ty.WF` の不透明型の場合を `True` のまま、腕の引数だけを足した。範囲自身の正しさ（正規のパス、CIDR の host bits など）を `Ty.WF`・`Eff.WF` に入れるなら、両者の不透明型・名前の場合と、その WF の保存の証明に手が入る。これは試していないので費用は未確認である |
| 資源の型 | `B.isResource o` は名前だけを見るので、範囲と独立である。試行では資源の型を `.opaqueTop o` に特化して、`release_exists` の欄の量化を変えずに済ませた。範囲付きの資源の型を許すなら、欄を `∀ r` へ変える必要があり、既存欄の意味の変更（停止条件）に当たる。判断 6・8 の新しい値型は資源ではないので、特化で足りる見込みである。確定は L00.03 で行う |
| 所有元 | 所有元は今の不透明型と同じく名前の文字列（模型では `"Scope.PathIn"`）に置き、範囲を別の引数に持つ。種類と所有元を構造で区別しないので、認定した標準型だけに所属を与えることを別に定める（模型の `Holds` は名前で限った）。利用者の `@opaque` 宣言の名前との衝突を名前で防ぐ点は今と同じである |
| 範囲の数だけ操作 ID を発行しない | 発行しない。操作の識別子は範囲によらず同じで、範囲は具体化の引数である（模型の `readTextIn_op`）。具体化した署名では、入力の添字と効果の原子が同じ範囲を指す（`readTextIn_same_range`）。本番の `io_op` は `s.eff = Eff.single l` を求めるので、範囲付きの効果を許すには B2 の変更が要る（試行では変えていない） |
| Top の対応 | 旧の原子・所属関数・不透明型は Top の範囲へ単射に写り、Top だけが旧へ戻る（模型の `Atom.ofRelease`・`toRelease?`・`liftAtoms` と補題）。本番の試行では `abbrev` の構築関数で旧の項を Top として保ち、主定理の言明を変えずに全体が通った。交換の旧版は Top として読める |
| 変更の規模（試行の Top への埋め込みまで） | 56ファイル・132宣言（新しい宣言を含む）、+251/−166 行。既存の定理の言明の一般化は5件、主定理の言明の変更は0件。非 Top の型付け・IO・対象の健全性は含まない |

## 受け渡す状態の既定ビルドの結果

| ビルド | コマンド | 終了 | 排他の待ち(s) | 時間(s) | 最大常駐量 | 備考 |
|---|---|---:|---:|---:|---|---|
| 31 | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>` | 1 | 135 | 170.27 | 2643918848 バイト（2521.4 MiB、2.46 GiB） | 試行を戻した後の全体の再ビルド。模型だけが失敗した（非公開の補題 `charsCode_injective` を参照した、被覆の向きの誤りで `#guard` 2件が偽、証明1件）。他の410ジョブは成功 |
| 32 | 同上 | 0 | 0 | 1.21 | 1499643904 バイト（1430.2 MiB、1.40 GiB） | 模型を直した後。`Build completed successfully (411 jobs).`。出力に `sorry` の一致は0件 |

- 模型の主な13の定理の公理依存を、一時的なファイルの `#print axioms` で確かめた（`axioms-handoff.txt`）。依存するのは `propext`・`Classical.choice`・`Quot.sound` だけであり、`sorryAx` も独自の公理もない。一時的なファイルは確かめた後に消した。
- 作業末の work の検査 `scripts/check.sh --level work --base 6124775788579e60530f55fb85570f26ef7fa900` は dry-run だけを行った（`check-work-dry-run.txt`、終了0）。選ばれたのは `formal_build`（`cd formal && lake build`、sorry の拒否）だけである。同じ内容を排他の道具でビルド32として行った。道具を経ない全体のビルドを避けるため、check.sh の実行はしていない。

## 最大常駐量

- 計り方: 排他の道具が `lake build` を `/usr/bin/time -l` で包み、maximum resident set size（バイト）を出す。macOS の値は、待ち合わせた子孫のうち最大の一プロセスの常駐量であり、並行して動いた lean のプロセスの合計ではない。
- 比較用ビルドの最大は 2642345984 バイト（試行29。2520.0 MiB、2.46 GiB）である。受け渡す状態の検証では、全体の再ビルド（ビルド31）が 2643918848 バイト（2521.4 MiB、2.46 GiB）だった。基準の再生（ビルド0）は 69419008 バイト（66.2 MiB）である。
- 単一ファイルの `lake env lean -M 12288` は計時で包んでいない。lean-guard の停止は起きていない（ビルドの異常な停止はなかった）。

## 失敗と修正

- 受け渡しの最初のビルド（31）は模型の誤りで失敗した。原因は三つである。`Release.Order.Atoms` の `charsCode_injective` が非公開であること、`allows` で被覆の向きを逆に書いたこと（`#guard` 2件が偽）、`liftAtoms_single` の証明で `simp` が進まなかったことである。補題の証明を模型へ写し、被覆の関数を向きの分かる `within` に改名して `allows` の引数の順を直し、証明を書き換えた。単一ファイルの検査で誤りがなくなったことを確かめてから、ビルド32を行った。
- 比較用の試行の失敗は、上の表と各ログに全て残した。

## ずれと申し送り

- 計画からのずれ:
  - 試行3の前に、`Order/Atoms` の olean を更新するため、道具を経ない部分のビルド `lake build Benitoite.Release.Order.Atoms`（3ジョブ、1秒未満）を一度走らせた。全体のビルドではないが、排他の道具の外であった。以後の部分の確かめは単一ファイルの `lake env lean -M 12288` と道具を経たビルドだけで行った。
  - 構成子の既定引数の振る舞いと公理依存を確かめるために、一時的なファイルを `formal/Benitoite/Scope/` に置いて単一ファイルで検査し、すぐ消した（`OptParamProbe.lean`、`AxiomsProbeI.lean`）。
  - 依頼の「直接の利用側を一群だけ直す」の後も、全体が通るまで層ごとの修正を続けた（試行4〜30）。最初の層だけでは243のうち236以上が未検査で、破損の分布を比べられなかったためである。
  - 記録の手元の絶対パスは `<wt>`・`<repo>`・`<home>`・`<scratch>` に置き換えた（ビルドのログの trace 行、道具の中のパス）。`tools/` の道具は記録として置いたもので、パスを置き換えたためそのままでは動かない。
- 停止条件: 受け渡す状態は既存の定義と定理を変えておらず、旧の四主定理の前提・結論の変更、公理や `Builtins.Assumptions` の欄の追加はない。試行の記録としてだけ、次の2点をレビューに渡す。
  - 案 (i) で非 Top の効果を継続の末尾に許すには、`BuiltinOnly`（`StateTy` の定義の一部）の `∃ l, a = .name l …` を `∃ l r, …` に広げる必要がある。主定理の言明の字面は変わらないが、`StateTy` の内容は変わる。前提の内容の変更として扱うかの判断は、L00.04・L00.06 のレビューに渡す。この点は格納方式によらず、非 Top の効果を型付けに入れる案に共通する見込みである（案 (ii) との突き合わせは取りまとめが行う）。
  - 範囲付きの資源の型を許すと、`release_exists` の欄の量化が変わる（既存欄の意味の変更）。判断 6・8 の型は資源ではないので、Top に特化してこれを避ける見込みである（L00.03）。
- 後続への申し送り: 試行は構成子の引数の影響に限った。`io_op` の具体化（B2）、範囲の WF、非 Top の IO の型付けの費用は未測定である。採否と最終の配置は L00.08 で決める。模型の名前空間とファイル名は依頼の指定のとおりで、L00.08 で採らなかった側を消す。

## 時間

- 開始 17:50、終了 18:39（外側の約49分）。
- 比較用・受け渡しのビルドの内側の時間の合計は約783秒、排他の待ちの合計は686秒である（いずれも別の作業用のディレクトリとの排他を含む）。能動時間は約30〜35分と見積もる（ビルドの間に次の修正を準備した時間を含むので近似である）。
- 見込み1〜2時間に収まり、上端の2倍（4時間）を超えていない。
