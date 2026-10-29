# L00.06 の結果: Top の互換と変更の母集団

2026-10-27。plan「作業 L00.06」を、取りまとめが用意した作業用のディレクトリ（`<wt>`、ブランチ `m013/l00.06`）で行った。担当は Claude のサブエージェントである。コミットは取りまとめが行う。既存の定義と定理は変えていない。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L00.06（Top の互換と変更の母集団） |
| B_WORK | `ad97eec0c30287a4ef7b9eb7778b3f07db2a0c76`（L00.05 の取り込みの後の本線） |
| 閉じた範囲 | 旧の効果から範囲を持つ原子の効果への変換と構造補題、変換を使う利用側の一群（構造の等号の直接の利用 4 件）の一般化と Top の互換の系、意味の被覆の相互包含から等号を導かない反例。母集団 691 宣言（定理 502）の二案別の分類と根拠、条件付きの印、未分類、段ごとの集計。L10〜L50 の切り替えの順の提案 |
| 未完 | 未分類 19（案 (i)）・20（案 (ii)）宣言の確定。条件付きの印（下の「条件付きの印」）の解消。いずれも後の点検の枝か L00.07・L00.08 の判断に送る（下の「追加の点検の提案」） |
| 採否 | 採用は決めていない。格納方式・最終の配置・候補の削除は L00.08 が決める |

## 変更と接続

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Scope/CompatExamples.lean` | 新規。名前空間 `Benitoite.Scope.CompatExamples`。L00.01 の二案の模型（`RepresentationExamplesI`・`II`）と `Release.Effect`・`Surface.Lemmas.Sequence` を import する |
| `formal/Benitoite.lean` | 既定の import の末尾に `import Benitoite.Scope.CompatExamples` を一行加えた |
| `l00.06/` | 本書、分類の結果（`population.json`・`population-summary.json`）、道具（`tools/deps.lean`・`tools/classify.py`）、生のログ |

設計書（01-12・07-04 など）には反映していない（採用前の候補のため）。

## 互換の補題と利用側の試し

### 置いたもの

| 名前 | 内容 |
|---|---|
| `TopEmbedding α` | 旧の原子を Top の範囲の原子へ写す対応（`ofRelease`・`toRelease?` と往復の二条件）。案 (i) の `embI` と案 (ii) の `embII` で具体化した |
| `GEff α` | 原子の型を `α` にした効果。所属関数と Fail の列（旧の `Release.Ty`）を持つ。正規化・構造上の包含 `Sub`・和・空を旧と同じ形で定めた。Fail の整列は旧の `Eff.norm` を流用した |
| `TopEmbedding.lift` | 旧の効果を Top の原子だけの `GEff` へ写す変換 |
| 構造補題 | `lift_injective`、`lift_sub_iff`（構造上の包含を両向きに保つ）、`lift_norm`、`lift_canonical_iff`、`lift_union`、`lift_empty`、`lift_single`（旧 `Eff.single l` は Top の一原子へ写る）、`lift_mem`（写した効果の原子は旧の原子の像だけ）、`liftAtoms_none`（非 Top の原子を含まない） |
| 利用側の一群の一般化 | `GEff.eq_of_sub_of_sub`（Fail の部分を旧の補題へ帰着）、`GEff.norm_ext`、`GEff.ext_canonical`、`GEff.union_empty_right_nested`、`GEff.union_empty_left_nested` |
| Top の互換の系 | `old_norm_ext`・`old_ext_canonical`・`old_union_empty_right_nested`・`old_union_empty_left_nested`。旧の言明を、一般化した補題と `lift_injective` から得る。`example` で既存の定理と同じ命題であることを確かめた |
| 反例 | `SemanticExample.semCovers_not_eq`・`no_eq_of_semCovers`。`{File.Read[Top], File.Read[/data/a]}` と `{File.Read[Top]}` は正規形で、意味の被覆では相互に包含するが、等しくなく、構造上の包含も成り立たない。意味の被覆の相互包含を前提にした等号の規則は正規形に限っても偽である |

定理は 41 件である。

### 試しの結果

- language-rules B3 の「上の直接利用5件」のうち、代入を含まない 4 件は、同じ証明の形のまま一般化した効果へ移せた。旧の言明は変換の単射性から Top の系として取り戻せた。同じ一般化は二案の原子のどちらでも、埋め込みを差し替えるだけで使える。
- 移す順は「一般化した補題を加える → Top の系を一般化した補題から導く → 旧の利用側は系の名前を使い続ける」である。系の言明は既存の定理と同じ命題なので、利用側の書き換えを後の枝へ送れる。
- `Eff.eq_of_sub_of_sub` の前提の `Eff.Sub` は、原子ごとの所属の構造上の包含である。L00.01 の二案の試行でもこの定理は変更なしで通った（下の分類で両案とも点検のみ）。範囲の意味の被覆は `Eff.Sub` とは別の関係として足し、等号の根拠に使わない。B3 の「前提を構造上の包含へ変更する」は、既存の `Eff.Sub` の意味を保つことで満たせる見込みである。

### 試しの限界

- `GEff` の Fail の列は旧の型のままであり、不透明な型の範囲（案 (i) の `Ty.opaque o r`、案 (ii) の `OpaqueDesc.index`）を含まない。Fail の型の側の互換は試していない。
- 5 件目の `Eff.bind_comp_of_types` は代入の一般化を要するので試していない。案 (i) の試行ではこの定理は証明だけの変更、案 (ii) では点検のみだった。
- 本番の切り替えの後は、旧の型そのものが新しい型の Top の像になる（L00.01 の案 (i) の `nameTop`）。そのときの系は `lift` ではなく Top の構築関数を通した形になる。模型はその対応の形を示すだけで、本番の型での系は L10 で置く。

## 母集団の分類

### 方法

母集団は次の和である（宣言の行は `population.json` の `rows`、集計は `population-summary.json`）。

| 出どころ | 宣言数 | 内容 |
|---|---:|---|
| S8 の棚卸し（`evidence/S8/lean-inventory.json`） | 387（定理 306） | 字句の検索による点検の母集団 |
| language-rules B3 の優先18定理 | 18 | すべて棚卸しに含まれる |
| L00.01 案 (i) の最終の差分（`trial-30-final.diff`）で変えた既存の宣言 | 104 | 新しく加えた宣言 12 は別に記録した（`new_declarations`） |
| L00.01 案 (i) の中間の試行で壊れた宣言（`broken-union.json`） | 104 | |
| L00.01 案 (ii) の最終の差分（`trial-15.diff`）で変えた既存の宣言 | 69 | 新しく加えた宣言 28 は別に記録した |
| L00.01 案 (ii) の各試行で壊れた宣言と仮置きの sorry（`count-*.json`） | 47 | |
| L00.03〜.05 の前提の変更を直接使う宣言（Lean の依存から） | 266 | うち 147 はほかの出どころにない |
| 和（重複を除く） | 691（定理 502、定義 153、帰納型・構造体 34、opaque 2） | 棚卸しの外が 304（定理 196） |

名前のない `example` 30 件（案 (i) の試行で変えたもの 15・壊れたもの 9、案 (ii) で変えたもの 1・壊れたもの 5）は Lean の定数を持たないので行にせず、件数だけを記した（`unmatched`）。

各宣言に、次の三つの証拠を付けて二案それぞれで分類した。

1. 試行の差分: B0 の写しに各案の最終の差分を当て、宣言ごとに言明（最初の `:=`・`where`、等式の証明の最初の腕まで）と本体の字面を旧と比べた。L00.01 の二案の最終の試行は、どちらも既定の全入口が終了0で、失敗した import の先の未検査は 0 だった（案 (ii) は sorry 2 件を含む）。したがって差分に現れない宣言は、その試行の範囲（Top に特化した切り替え）では変えずに通ったことがビルドで確かめられている。
2. Lean の直接の依存: 既定の対象の環境（35046 定数）から、各定数の言明（型）と本体（値）が直接使う定数を書き出した（`tools/deps.lean`）。補助の定数（`match_`・`proof_`・`casesOn` など）は持ち主の宣言へ寄せた。字句の検索と違い、構成子名を書かない `cases` や `simp` が作る項の定数も数える。推移的な依存で「変更」を増やさず、推移的な依存だけのものは点検のみとした。例外として、`Builtins.Assumptions` の欄を証明が推移的に使うかだけは計算した（下の SPLIT）。
3. 前提の変更（L00.03〜.05）: `Builtins.Assumptions` の言明への出現（io_op の内容と既存欄の量化。判断 15 の計画済みの変更と L00.03 の申し送り 1）、`io_op`・`delta_typed`・`io_typed`・`io_exists` の本体での利用、観測の欄（O1）、`BuiltinOnly`（BA/BB）、`RangeState`、捕捉した操作の節（`E_OpPrim`・`opSig`）。

分類は次のとおりである。

| 区分 | 定義 |
|---|---|
| 言明の変更（字面） `statement` | 試行で言明の字面を変えた。定義・帰納型では型や構成子の型を変えた |
| 言明の変更（字面だけ） `statement_text` | 試行で言明の字面を変えたが、Top の構築関数（`abbrev`）への置き換えだけで、項は旧と同じ |
| 言明の変更（前提の内容） `statement_premise` | 言明が `Builtins.Assumptions` を前提に持つ。字面は不変だが、io_op の内容と既存欄の量化が変わるので、同名の前提の内容は以前と同じでない |
| 証明だけの変更 `proof` | 試行で本体だけを変えた、または本体が io_op・量化する欄を直接使う、または `Builtins.Assumptions` を構成する。定義では本体だけの変更（定義の意味が変わりうる） |
| 点検のみ `check` | 試行で変えずに通り、前提の変更を直接使わない。再ビルドで確かめる |
| 未分類 `unclassified` | 試行と依存では三つのどれかに決まらない（下の「未分類」） |

分類の優先は、未分類 > 言明 > 証明 > 点検のみである。分類とは別に、未決の判断によって区分が上がりうる印（`condition_keys`）を付けた。

### 件数（二案別）

| 範囲 | 案 | 言明（字面） | 言明（字面だけ） | 言明（前提の内容） | 証明だけ | 点検のみ | 未分類 | 計 |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| 母集団の全体 | (i) | 10 | 18 | 61 | 72 | 511 | 19 | 691 |
| | (ii) | 33 | 0 | 59 | 25 | 554 | 20 | 691 |
| 定理 | (i) | 8 | 14 | 61 | 10 | 393 | 16 | 502 |
| | (ii) | 8 | 0 | 59 | 13 | 405 | 17 | 502 |
| 定理以外 | (i) | 2 | 4 | 0 | 62 | 118 | 3 | 189 |
| | (ii) | 25 | 0 | 0 | 12 | 149 | 3 | 189 |
| 棚卸しの 306 定理 | (i) | 0 | 5 | 17 | 2 | 275 | 7 | 306 |
| | (ii) | 2 | 0 | 17 | 6 | 274 | 7 | 306 |
| 優先18定理 | (i) | 0 | 0 | 6 | 1 | 6 | 5 | 18 |
| | (ii) | 0 | 0 | 6 | 0 | 7 | 5 | 18 |

306 件のうち、二案のどちらでも試行と前提の変更の直接の利用がなく点検のみになるのは約 9 割（275・274）である。306 件を書き換えの件数として読まない。点検のみは「Top に特化した切り替えで変えずに通った」ことであり、非 Top の型付けへの接続で変わらないことまでは示さない（下の条件付きの印と限界）。

### 優先18定理

| 定理 | 案 (i) | 案 (ii) | 条件付きの印 |
|---|---|---|---|
| `Eff.eq_of_sub_of_sub` | 点検のみ | 点検のみ | なし |
| `Eff.norm_ext`・`Eff.ext_canonical`・`union_empty_right_nested`・`union_empty_left_nested` | 点検のみ | 点検のみ | なし。一般化と Top の系は本作業の模型で示した |
| `Eff.bind_comp_of_types` | 証明だけ | 点検のみ | なし |
| `no_event`・`preservationE`・`progress_io`・`step_soundE` | 未分類 | 未分類 | O1（4件とも）、NT（`preservationE`・`step_soundE`）、NV（`step_soundE`） |
| `opSig_scoped` | 未分類 | 未分類 | なし（言明が `opSig` を書く） |
| `Model.assumptions` | 前提の内容 | 前提の内容 | O1、SPLIT |
| `Release.progress`・`preservation` | 前提の内容 | 前提の内容 | BA |
| `Release.step_sound` | 前提の内容 | 前提の内容 | BA、O1 |
| `Release.effect_soundness`・`effect_soundness_noLamNames` | 前提の内容 | 前提の内容 | なし |
| `Surface.desugar_typed` | 点検のみ | 点検のみ | なし |

主定理の言明の字面は二案とも変わらない。前提の内容は二案とも変わる（判断 15 の io_op の変更と量化）。`Surface.desugar_typed` は `Builtins.Assumptions` を言明に持たず、二案とも変えずに通った（B3 の「io_target を前提に足す必要はない」と合う）。

### 二案で分かれるもの

定理で 45 件、定理以外で 82 件が二案で分かれた。定理の内訳は次のとおりである。

| 案 (i) → 案 (ii) | 件数 | 宣言と理由 |
|---|---:|---|
| 言明（字面） → 点検のみ | 8 | `Eff.mem_bind`・`mem_rawBind_rowImage`・`mem_substRho_rowImage`・`substRho_true`・`substRho_true_scoped`・`substAt_name`・`mem_substAtoms`、`rowsAtoms_spec`。案 (i) は `.name l` が `.name l r` になり、代入の補題の言明を範囲へ一般化した。案 (ii) は名前の記述が構造体の中に範囲を持つので、代入の言明は変わらない |
| 言明（字面だけ） → 点検のみ | 10 | `Eff.mem_single`・`substRho_name`・`ContTy.name_end`・`inv_drop`・`captureEff_state`・`no_unhandled_user`、Surface の 4 件。案 (i) は Top の構築関数へ書き換えた。案 (ii) は `String` からの暗黙の変換で通った（EX。変換を置かなければ案 (i) と同じ書き換えになる） |
| 言明（字面だけ） → 言明（字面） | 4 | `ContTy.inv_release`・`prepend_releases`・`end_of_noHandler`・`HasTypeCQ.inv_use`。案 (ii) は資源の判定を元の名前（`o.base`）で行う形にした。L00.03 が推す「資源の型を Top の添字に限る」を案 (ii) にも適用すれば、案 (i) と同じく字面だけの変更へ下がる見込みである |
| 点検のみ → 言明（字面） | 2 | `HasTypeVQ.inv_prim`・`inv_prim_app`。案 (ii) の試行は `PrimSig.inst` と `V_Prim` の R を同じ試行に入れた。案 (i) の試行は署名の具体化を試していない |
| 前提の内容 → 言明（字面） | 2 | `PrimitiveAdmissible.outer`・`substTy`。同上 |
| 点検のみ → 証明だけ | 11 | `canonical_*` 5 件と `inv_raise`（`inv_prim` の分解の要素数）、`TyCon.toTree_injective`・`tyCompare_eq_treeCompare`（構造の名前の比較）、Surface の 3 件（`V_PrimTop`） |
| 証明だけ → 点検のみ | 7 | `Ty.VarsIn.substAt`・`NoFail.bind`・`bind_comp_of_types`・`bind_ofAtoms_noRhos`、Surface の 3 件。案 (i) の腕の引数の追加と言明の一般化の波及 |
| 証明だけ → 未分類 | 1 | `Atom.code_injective`。案 (i) は対の符号で証明した。案 (ii) は sorry で仮置きした（証明だけの見込み） |

定理以外の 82 件の多くは、案 (i) の腕の機械的な引数の追加（証明だけ 52 件の側）と、案 (ii) の名前の型・署名・表の構造体の変更（言明 20 件の側）である。

二案の差の大部分は試行の進め方の違いである。案 (ii) は署名の具体化（L20 の内容）を同じ試行に入れ、案 (i) は入れていない。案 (ii) は暗黙の変換を使い、案 (i) は明示の構築関数を使った。差をそのまま格納方式の優劣として読まない。

### 条件付きの印（追加の場合分けの候補）

未決の判断や後の設計で区分が上がりうる宣言に、次の印を付けた。件数は定理（括弧は棚卸しの 306 定理）で、二案に共通である（EX だけ案 (ii)）。

| 印 | 意味 | 定理数 | うち今は点検のみ | 決める所 |
|---|---|---:|---:|---|
| NT | 本体が Release の値の型付けの相互帰納（`HasTypeVQ` など 7 つ）を場合分けする。範囲付きの値の所属を持つ型付けの規則を構成子として足すと、場合が一つ増える | 118（61） | 92・90（48） | L20。値の所属の不変条件（L00.03 の `HasTypeV`）を本番でどう置くか |
| CS | 本体が `opSig` を使う。節の添字 S を `opSig`・`HasTypeClausesQ` に入れると相互帰納の証明が変わりうる | 100（27） | 85（22） | L20・L30。判断 11 |
| RS | `RangeState` を使う。L40 で `RangeState` に Scope の成分を足す場合だけ変わる | 54（33） | 54（33） | L40。L00.05 の申し送り 2。別の状態（`ScopeState`）にすれば 0 |
| SPLIT | 言明が `Builtins.Assumptions` を持つが、証明が推移的にも io_op・delta_typed・io_typed・io_exists・io_kind を使わない | 35（8）。前提の内容に分類したものでは 35・33 | 0 | L00.08。CoreAssumptions と TargetAgreement を分ければ、前提を旧の内容の構造体に保てる |
| NS | 本体が Surface の型付けの相互帰納を場合分けする | 22（4） | 22・21（4・3） | L40 |
| BA | 言明が `StateTy` などを通して `BuiltinOnly` に依存する、または本体が直接使う。案 BA なら前提・結論の内容が変わる。案 BB は Top の像の上で同じ | 15（9） | 5・6（3・4） | L00.08。L00.04 が BB を推す |
| O1 | 言明・本体が `Event.io`・`ioResponse`・`io_kind`・`E_IO` を使う。観測の欄を足すと字面か証明が変わる | 12（6） | 0 | L00.08。L00.04 が O1 を推す |
| NV | 本体が `Val`・`Const` を場合分けする。対象を持つ値の形を構成子として足すと場合が増える | 10（7） | 7・2（6・1） | L20 |
| EX | 案 (ii) の試行は暗黙の変換で通った。変換を置かなければ案 (i) と同じく Top の構築関数への字面の変更になる（下限） | 12（4）、定義 30 | 12（4） | L00.08。L00.01 の両担当が明示の構築関数を推した |

NT・CS・NV・NS は格納方式によらない。値の所属を型付けの規則で表すかぎり、二案のどちらでも同じ相互帰納に場合が加わる。L00.01 の二案の試行は Top に特化したので、この費用を含まない。

### 未分類

| 宣言 | 二案 | 理由 |
|---|---|---|
| `preservationE`・`pres_op_common`・`step_soundE`・`no_event`・`progress_io`、`builder_step_no_event`・`builder_step_frame`・`drop_local_silent` など 4 件（`BuilderStore`）、`HasTypeClausesQ.find` | 両方 | 本体が `E_OpPrim` の場合を扱う。捕捉した組み込みの操作の節の添字 S（判断 11）の配置で、言明か証明かが決まる。案 (ii) は試行で sorry を置いて止め、案 (i) は非 Top の型付けを試していない |
| `opSig_scoped`・`opSig_ne_fail`、Surface の `Check.opSig_atoms`・`opSig_clean` | 両方 | 言明が `opSig` を書く。`opSig` に S を入れれば言明が変わる |
| `Step`・`HasTypeClausesQ`・Surface の `HasClausesQ`（帰納型） | 両方 | 構成子の型が `opSig` を含む |
| `Atom.code_injective` | 案 (ii) だけ | 試行で sorry を仮置きした。案 (i) の対の符号と同じ方法で閉じる見込み（証明だけ） |

未分類の 19・20 件は、どれも捕捉した操作の節の添字 S か、案 (ii) の符号の単射性に由来する。

### 直接の集計の限界

1. 試行は Top に特化した切り替えだけである。非 Top の型付け、署名の具体化（案 (i)）、io_target、観測の欄、値の所属の規則はビルドで確かめていない。これらの影響は依存からの印で示し、件数を確定していない。
2. 言明と本体の境目は字句の近似である（最初の `:=`・`where`、等式の証明の最初の腕）。宣言の中のコメントや空白だけの変更も変更に数える。L00.01 の案 (ii) の担当の手の分類とは、`ContTy.prepend_releases` の扱いを照合して道具を直し、一致させた。
3. Lean の依存は、項に現れる定数の直接の参照である。`rfl`・`decide` などの定義の展開に頼る証明は依存に現れず、点検のみに入る。点検のみの正しさはビルドで確かめる。
4. 推移的な依存を変更に数えない。点検のみの宣言でも、変わる定義を推移的に使う証明は、その定義の変更で壊れうる。L00.01 の最終の試行は、その範囲ではすべて通ったことを示した。
5. 案 (ii) の点検のみは、暗黙の変換による黙った狭め（L00.01 案 (ii)「暗黙の変換による黙った狭め」）を含む下限である（EX）。
6. 母集団は棚卸しの対象（Release・Surface・Exchange・SurfaceCheck・Interval）と、依存で見つけた Release・Surface・Exchange・Interval の宣言である。`Benitoite.Core`（段階 A の模型）と新しい `Scope` の模型は除いた。L00.01 の試行は Core を変えずに通った。
7. 棚卸しの基準 `80d1eead` と B0・B_WORK の間で、`formal` は `Scope` の新規ファイルと既定の import の行だけが違う（git diff で確かめた）。棚卸しの行番号はそのまま使えた。

## 追加の点検の提案

格納方式の判断を変えうる未分類と印は次の三つである。L00.08 の前に閉じることを推す。

| 枝の案 | 内容 | 格納方式への影響 | 見込み（能動） |
|---|---|---|---|
| L00.06b 節の添字 S の実物の点検 | 作業用のディレクトリで、案 (i) の最終の差分に署名の具体化（`PrimSig.inst`・`V_Prim` の R）だけを足し、案 (ii) と同じ条件で `E_OpPrim` を閉じられるかを試す。節の添字を Top から始め（L00.03 の `clause_arg_typed` は Top の S を無条件に得る）、値の所属からの拡大の補題で閉じる。試行はコミットせず差分を残す | 案 (ii) は試行で閉じなかった。案 (i) で同じ形が閉じるか、どちらも同じ費用かが分からないと、二案の差を比べられない | 1.5〜3時間 |
| L00.06c 案 (ii) の明示の構築関数の再計数 | 案 (ii) の最終の差分から暗黙の変換を外し、Top の記述を明示の構築関数で書いて、壊れる宣言を数え直す。資源の判定を Top の添字に限る形（L00.03）も同時に当てる | EX（定理 12・定義 30）と資源の 4 件で、案 (ii) の件数は今の数より増える（または減る）。二案の規模の比較を同じ条件にそろえる | 1〜2時間 |
| L00.07 で扱う NT・NV の方針 | 範囲付きの値の所属を、新しい型付けの規則（構成子）にするか、`Const.type` と既存の規則の言明の変更にするかを、非空の例で比べる | 格納方式によらない。L20 の枝の大きさ（相互帰納の 118 定理に場合が加わるか）を決める | L00.07 の範囲で 0.5〜1時間の追加 |

RS・BA・O1・SPLIT は L00.04・L00.05 の推す案（別の局所状態、BB、O1、CoreAssumptions の分離）を採るかで決まる。どれも格納方式によらない。

## L10〜L50 の切り替えの順の提案

各枝の末尾で既定のビルドを sorry なしで通す。件数は上の分類から取った既存の宣言の数で、新しく加える宣言を含まない。

1. **L10.1 表現の切り替え（Top だけ、明示の構築関数）**: 案 (i) は `Atom.name`・`Ty.opaque` の引数の追加、案 (ii) は名前の型の構造体化。構成子の形の変更はすべての腕と構築の箇所を同時に壊すので、この枝だけは一度の切り替えになる。ただし Top に特化した意味を保つ切り替えであり、L00.01 の案 (i) の試行がその範囲で sorry なしに閉じることを示した（既存の 104 宣言、うち定理の言明の一般化 8・字面だけ 14、残りは腕と構築の機械的な修正）。案 (ii) は `PrimSig.inst` と `V_Prim` の R をこの枝に入れず（L20.2 へ）、`Atom.code_injective` をこの枝で閉じる。旧の言明は Top の構築関数の系で保つ。
2. **L10.2 対象の領域の差し替え**: 比較用の `ScopeRange` を `Scope.Domain.Range` に置き換え、所属・被覆・推移・異族の非包含・endpoint の積（L00.02 の義務 1〜6）を加える。既存の宣言は `Order/Atoms`・`Order/Types` の符号と比較の証明だけが変わる見込み（試行で両案 2〜5 宣言）。
3. **L10.3 意味の被覆の関係の追加**: `Eff.Sub` は構造上の包含のまま保ち、範囲の被覆による許可の関係を別に加える。既存の定理の変更は 0 の見込み（`eq_of_sub_of_sub` と直接の利用 4 件は二案とも点検のみ）。本作業の模型の一般化と Top の系をこの枝の形の手本にする。
4. **L20.1 値の所属の型付け**: 範囲付きの値の所属を持つ規則を足す。NT 118・NV 10 定理に場合が加わりうる。規則を部分の導出を持たない葉の規則にすれば、各相互帰納の場合は機械的に閉じる見込みである。大きいので、Release の相互帰納の群（代入・改名・ストア・外側・整形式性・単調性など）ごとに小枝に分けられるよう、先に規則と葉の場合の補題を置く。
5. **L20.2 署名表の具体化と節の添字**: `PrimSig.inst`・`V_Prim` の R・`inv_prim` 群（案 (ii) の試行で言明 4・証明 13）、節の添字を Top から始めて `E_OpPrim` を閉じる（未分類の群。L00.06b の結果で枝の大きさを決める）。
6. **L20.3 信頼条件の量化と io_op**: CoreAssumptions と TargetAgreement を分け、前提の内容が変わる定理（59〜61）のうち SPLIT の 33〜35 を旧の内容の構造体に保つ。残りの約 26 定理と、io_op・量化する欄を直接使う証明を同じ枝で直す。
7. **L20.4 観測の欄（O1）と L20.5 `BuiltinOnly`（BB）**: O1 は定理 12 と定義 5、BB は既存の言明の変更 0（`StateTyE` の末尾の添字の単調性の補題を加える）。BA を採るなら定理 15 の前提の内容が変わるので、別の枝にする。
8. **L30 Release の定理**: 非 Top の IO の場合（`progress_io`・`preservationE` の `E_IO`・`step_soundE`・`no_event`）、一段と到達先の対象の健全性（新しい定理）、節の添字の精度（保護本体の効果からの S）。L20 で既定のビルドが通った状態から、場合ごとに一枝ずつ足す。
9. **L40 Scope と Surface**: Scope の局所状態を `RangeState` と別に置けば RS 54 は 0 になる。Surface の型付けの規則（NS 22）、案 (ii) なら `CheckTables` の言明 6、脱糖との接続。
10. **L50 交換と閉鎖**: `Exchange/Convert` の Top の読み書き（案 (i) で 3、案 (ii) で 1）、案 (ii) なら `Exchange/Builtins` の言明 2、`SurfaceCheck/Validation`。

段ごとの集計（母集団の宣言のファイルを段へ割り当てた数。点検のみを除く）は次のとおりである。

| 段 | ファイル | 案 (i) の言明・前提・証明・未分類 | 案 (ii) の言明・前提・証明・未分類 |
|---|---:|---|---|
| L10（型・効果・代入・順序） | 19 | 言明 10（うち字面だけ 1）、証明 28 | 言明 3、証明 8、未分類 1 |
| L20（型付け・構文・仮定・意味論の定義） | 7 | 言明 3（字面だけ）、証明 7、未分類 2 | 言明 11、証明 4、未分類 2 |
| L30（Release の補題と定理） | 40 | 言明 9（字面だけ）、前提 60、証明 2、未分類 14 | 言明 8、前提 58、証明 7、未分類 14 |
| L40（Surface・Interval） | 55 | 言明 6（うち字面だけ 5）、前提 1、証明 31、未分類 3 | 言明 9、前提 1、証明 5、未分類 3 |
| L50（交換・検査の入口） | 3 | 証明 4 | 言明 2、証明 1 |

案 (i) の L40 の証明 31 の多くは例と検査器の Top の構築関数への置き換えである。案 (ii) は暗黙の変換でこれを避けたので少ない（EX）。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 単一ファイル（途中） | `cd <wt>/formal && lake env lean -M 12288 Benitoite/Scope/CompatExamples.lean` | 初回は誤り（`mem_union` の未解決、変数の暗黙の引数、`Atom` の曖昧さ）、修正後 0 | 1 秒未満 | 下の「失敗と修正」 |
| 既定の全体のビルド | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>` | 0（417 ジョブ、sorry なし） | 3.13 秒（ビルド済みの生成物の上。待ち 0 秒） | `lake-build.log` |
| 公理の依存 | 新しいモジュールの全 41 定理について、リポジトリの外の一時ファイルで `#print axioms`（`lake env lean -M 12288`） | 0 | 1 秒未満 | `axioms.lean`・`axioms.log`。`propext`・`Classical.choice`・`Quot.sound` だけ（39 件が一部または全部に依存、2 件は公理なし）。`sorryAx` なし |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base ad97eec0c30287a4ef7b9eb7778b3f07db2a0c76 --dry-run` | 0 | 1 秒未満 | `work-check-dry-run.log`。選択は `formal_build`（`formal/Benitoite.lean` の変更による。sorry の宣言を拒否する）だけ |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base ad97eec0c30287a4ef7b9eb7778b3f07db2a0c76` | 0（`formal_build`） | 0.21 秒（ビルド済み） | `work-check.log`。一度目（0.22 秒、終了0）は本書と分類の道具を直す前に走らせたので、最終の状態で dry-run とともにやり直した。13 の変更ファイルで選択は同じ |
| 依存の書き出し（分類の入力。検査ではない） | `cd <wt>/formal && DEPS_OUT=<tmp>/l00.06/deps.jsonl /usr/bin/time -l lake env lean -M 12288 ../docs/…/l00.06/tools/deps.lean` | 0（35046 定数） | 10.90 秒 | `deps-run.log`。出力 40 MB はリポジトリに置かない。SHA-256 `164e5f7ae9c4c26116130c49ee221ffa6caf2850b90dd9474743fc32281d3c38` |

## 最大常駐量

`/usr/bin/time -l`（macOS）の maximum resident set size の原値（バイト）である。プロセスは並行させていない。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 既定の全体のビルド（`lake build` 全体） | 1509310464 | 1439.4 | 1.41 |
| work（`check.sh`、ビルド済み。最終の実行） | 68878336 | 65.7 | 0.06 |
| 依存の書き出し（`lake env lean`、一回目） | 1917911040 | 1829.1 | 1.79 |
| 依存の書き出し（`lake env lean`、二回目。出力の欄を足した） | 1913241600 | 1824.6 | 1.78 |

単一ファイルの検査と公理の一時ファイルは計時していない。メモリの見張り（一つ 13 GB、全体 26 GB）に当たる実行はなかった。

## 失敗と修正

| 失敗 | 原因 | 修正 |
|---|---|---|
| `CompatExamples.lean` の初回の単一ファイルの検査が誤り | `GEff.mem_union` の `simp` に `norm` を渡していなかった。`variable (emb)` を言明に使わない定理（`old_*`）では `emb` が引数にならなかった。`open` した二つの名前空間で `Atom` が曖昧だった | `simp` に `norm` を加えた。`old_*` に `emb` を明示の引数として持たせた。案 (i) の原子を別名 `Atom` で置いた。再検査は終了0 |
| 分類の道具の初回の実行が誤り | 案 (ii) の `count-*.json` の欄の形（辞書）を読み違えた | 欄の名前で読むように直した |
| 分類の中間の結果の偏り | 自動で生成した定数（`recOn` など）を宣言として数えた。名前のない宣言を行番号で対にし、削除と誤った。言明の中の `match` の腕で言明を切った。`Prop` の構造体の欄が定理であることを見落とし、欄の到達を 0 にした | 同じ行の前置きの宣言へ寄せる、無名の宣言を順序で対にする、言明に `match` がある場合は腕で切らない、欄の種類に定理を含める、と直した。案 (ii) の担当の手の分類（`prepend_releases` の言明の変更）と照合して確かめた |

## ずれと申し送り

計画からのずれ:

- 触るファイルは plan の `RepresentationExamples.lean` の互換補題ではなく、依頼文が許す新しい `Scope/CompatExamples.lean` にした。二案の模型を同じ形で使うためである。
- 分類の道具（`tools/deps.lean`・`tools/classify.py`）を `l00.06/` に置いた。`deps.lean` は既定のビルドに含めず、`lake env lean` で単独に走らせる。

停止条件: 該当しない。既存の定義と定理を変えておらず、`Builtins.Assumptions` に欄を加えていない。主定理の前提の内容が両案で変わること（言明の変更（前提の内容））は、判断 15 の計画済みの io_op の変更と L00.03 の申し送り 1（量化。案 A を推す）によるもので、L00.03 の判定の案に含まれる。

L00.07 への申し送り:

1. 値の所属の型付けの置き方（NT・NV）を非空の例で比べる。L20 の枝の大きさを決める。
2. 一般化した補題と Top の系の形（本作業の `GEff` と `old_*`）を、非 Top の例と Top の旧の例の両方に当てる。

L00.08 への申し送り:

1. 追加の点検 L00.06b（節の添字 S）と L00.06c（案 (ii) の明示の構築関数）を、格納方式の判断の前に行うか。行わないなら、二案の件数の差を試行の条件の差として扱う。
2. SPLIT の 33〜35 定理を旧の内容の CoreAssumptions に保つ分離（L00.03 の S1〜S3）。
3. `Eff.Sub` を構造上の包含のまま保ち、意味の被覆を別の関係にすること（反例 `no_eq_of_semCovers`）。
4. 比較用の模型 `CompatExamples` は二案の模型を import する。採らなかった側の模型を消すときに、埋め込みの片方と `example` を消す。

## 時間

| 項目 | 内容 |
|---|---|
| 開始・終了 | 19:26 開始、19:51 に終了（外側約 25 分） |
| 能動時間 | 約 20 分（互換の模型と試し 約 7 分、分類の道具と分類 約 10 分、本書 約 5 分の重なりを含む） |
| 検査・ビルド | 全体のビルド 3 秒（待ち 0 秒）、work 0.2 秒、依存の書き出し 2 回 各 11 秒、単一ファイルと公理の検査 各 1 秒未満 |
| 見込みとの比較 | 見込み 2〜3時間の内に収まった。上端の2倍に当たらない |

## 再現の手順

`<wt>` で次を実行する（`<tmp>` はリポジトリの外の一時ディレクトリ）。

```sh
mkdir -p <tmp>/l00.06/b0 <tmp>/l00.06/ci <tmp>/l00.06/cii
for c in b0 ci cii; do git archive 6124775788579e60530f55fb85570f26ef7fa900 formal | tar -x -C <tmp>/l00.06/$c; done
(cd <tmp>/l00.06/ci && patch -p1 -s < <wt>/docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/l00.01/candidate-i/trial-30-final.diff)
(cd <tmp>/l00.06/cii && patch -p1 -s < <wt>/docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/l00.01/candidate-ii/trial-15.diff)
(cd formal && DEPS_OUT=<tmp>/l00.06/deps.jsonl lake env lean -M 12288 ../docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/l00.06/tools/deps.lean)
cd docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms
python3 -B l00.06/tools/classify.py --deps <tmp>/l00.06/deps.jsonl --b0 <tmp>/l00.06/b0 --ci <tmp>/l00.06/ci \
  --cii <tmp>/l00.06/cii --change . --out l00.06/population.json > l00.06/population-summary.json
```

依存の書き出しは既定のビルドの済んだ `formal` の環境を読む。B_WORK の `formal` は B0 と `Scope` の模型だけが違い、模型の宣言は分類から除くので、B0 と同じ結果になる。
