# 権限の判定の独立小モデルと本番の形式化の対応（PM30.04）

2026-10-27。docs/todo の TODO-256 の第一項・第三項の独立小モデル（`models/PermissionKinds.lean`・`models/Policy.lean`）と、本番の形式化（`formal/Benitoite/Release/`）の対応を記す。レビュー [RV-PM](../reviews/RV-PM.md) の「PM30.04 へ渡す点」の 1〜7 に順に答える。名前と行番号は基準 `709f57037b19fb0105aaaadd36100182b4c2b872` のものである（`formal/` はブランチの開始版 `10099543` から変わっていないことを `git diff --stat` で確かめた）。

**このモデルは本番へ接続していない。** モデルは本番を import せず、本番もモデルを参照しない。以下の対応は読んで確かめた名前の対照であり、モデルの定理を本番の定理として使える、または本番の保証が増えたとは言わない。モデルは、実行時の拒否による停止・サーバ・OS・プロセス間通信・非干渉性・言語サーバ・MCP のどれも証明しない（判断 18）。

## 確かめた名前

各行は、`formal/Benitoite/Release/` の今の内容を読んで、名前・場所・言明を確かめたものである。PM10.02 が最初に確かめ、RV-PM の C 節が独立に一致を確かめた。この記録の作成の際にも名前と行番号を検索で確かめ直した。

| モデル | 本番の名前（場所） | 確かめた内容 |
|---|---|---|
| 種類 `Kind` | `EffName`（`Atom.lean:12`。`String` の別名）、原子 `Atom.name l` | 本番の効果 `Eff` は名前の原子のほかに行の原子 `Atom.rho i` と Fail の型の列を持つ |
| 包含 `KindSet.Subset` | `Eff.Sub`（`Effect.lean:27`） | 名前と行の所属の含意と、Fail の型の所属の含意の組 |
| 宣言上限 `declared` | `StateTyE P B Eb`（`Lemmas/PresHelpers.lean:16`）の `Eb`。`StateTy`（`Semantics.lean:647`）は `Eb` に `BuiltinOnly P B Eb`（`Semantics.lean:613`）を課す | `BuiltinOnly` は Fail を含まず、所属する原子は全て組み込みのエフェクトの名前であることを求める |
| 事象 `Ev` | `Event`（`Semantics.lean:62`）の `io b ws o` と `release v r` | 遷移 `Step P B s (some ev) s'` の印として現れる。IO の遷移 `E_IO`・`E_IOErr`・`E_Exit`（`Semantics.lean:184`〜）は `NoHandler k (.prim b)` を前提にする |
| 実行の列 | `Steps`（`Semantics.lean:325`） | 遷移の印を捨てる。印の列を持つ多段の遷移は `Release`・`Core` にない（`inductive Steps` は `Release/Semantics.lean:325` と `Core/Semantics.lean` だけ） |
| 宣言上限が空の場合の健全性 | `effect_soundness`（`Theorems.lean:52`）・`effect_soundness_noLamNames`（同 62 行） | `Eff.empty` の型付けを前提に、到達する全ての状態が事象を伴う遷移をせず、処理されない操作を呼ばないことを結論する |
| 事象ごとの所属の材料 | `no_event`（`Lemmas/EffectSound.lean:39`）、`ContTy.end_of_noHandler`（同 20 行）、`ContTy.state_end`（`Lemmas/ContLemmas.lean:74`）、`Builtins.Assumptions` の欄 `io_op`（`Assumptions.lean:77`） | `no_event` の証明の中で、IO の事象から `Eff.mem Eb (.name l)`、解放の事象から `Eff.mem Eb (.name stateEff)` を導き、`Eb` が空であることと矛盾させている |
| 状態の型付けの保存 | `preservationE`（`Lemmas/PresMain.lean:18`）、`steps_preserve`（`Lemmas/EffectSound.lean:133`） | 任意の `Eb` について、遷移と `Steps` に沿って `StateTyE P B Eb` を保つ |
| 初期状態 | `stateTyE_init`（`Lemmas/EffectSound.lean:128`）・`stateTyE_init_noLamNames`（同 114 行） | `Eff.empty` の型付けの場合だけを言明する |

## 1. 接続の状態と `WithinDeclared`

モデルの第一項は、事象 ⊆ 宣言上限（`WithinDeclared`）を仮定で受け、宣言上限 ⊆ 方針（`KindCheck`）と合わせて事象 ⊆ 方針を導く（`events_subset_policy`）。本番が今与えるのは、型のエフェクトが `Eff.empty` の場合に事象が一つもないことだけである（`effect_soundness`）。これはモデルでは、宣言上限が空で、列に現れる種類も空になる場合に当たる。空でない宣言上限について `WithinDeclared` を与える本番の定理はない。

## 2. 空でない宣言上限に足りないもの

空でない宣言上限について本番で `WithinDeclared` を言うには、次の三つが足りない。どれも未定義・未証明である。

| 足りないもの | 今の本番 | 状態 |
|---|---|---|
| 印の列を持つ多段の遷移 | `Steps` は印を捨てる | 未定義 |
| `no_event` を空でない `Eb` へ一般化した補題（事象を伴う遷移の種類が `Eb` に属する） | 材料は `no_event` の証明の途中にある（上の表） | 未証明。今の前提（`Builtins.Assumptions`・`EffectsOk` など）だけで証明できるかは確かめていない |
| `main` の型のエフェクト ε と `Eb` の関係 | 初期状態の補題は `Eff.empty` の場合だけ | 未証明 |

これらは本番の形式化に定義と補題を加える作業である。追加するだけで既存の主定理の前提・結論を変えない形にできるかは確かめていない。本番の主定理を変える必要が生じる場合は全 L 作業の停止条件に当たる。どちらの場合も、0.0.13 の計画の外の別の作業として割り当てる必要がある。PM の枝はこれを行っていない。

## 3. `kindOf` の候補の写しと差

本番に、事象から種類を返す関数として定義された名前はない。候補の写しは次のとおりである。

- `Event.io b ws o ↦ l`。ただし `l` は `B.sig b = some s` の `s.opEff = some l`。`io_op` が、IO と終了の組み込みの関数について `s.opEff = some l` と `s.eff = Eff.single l` を与える。
- `Event.release v r ↦ stateEff`（`"State"`）。

差: モデルの種類は名前だけであり、本番の効果の行の原子 `Atom.rho i` と Fail の型の列を扱わない。`BuiltinOnly` の下の `Eb` は名前だけで Fail を含まないので、継続の末尾の `Eb` に限れば名前だけの写しで足りる見込みである。式の型のエフェクト ε の一般の場合（行の変数と Fail を含む）は扱っていない。

## 4. 本番に存在しないもの、確かめていない対応

- 方針、`KindCheck`、対象の判定（`Policy.permits`・`TraceAllowed`）は、本番の形式化に存在しない。モデルだけの概念である。
- 次の対応は確かめていない: 本番の方針の書式と parser、実行時の拒否による停止、サーバ、OS、非干渉性、処理系の Rust の側の実行前の判定（このモデルの `KindCheck` に当たるかどうか）。処理系のソースは読んでいない。

## 5. 範囲付きのエフェクト（案4）との関係

範囲付きのエフェクトの対象と、モデルの `Kind`・`Target` の写しの関係は扱っていない。モデルの `Target` は抽象の型であり、案4 の対象の領域（パス・ホスト・IP・CIDR など）や字面の上限を表さない。判断 18 のとおり、第四項（範囲型）は中心の対象健全性へ一度だけ計上し、小モデルへ二重に数えない。

## 6. 種類判定と対象判定の分離の根拠

判断 18 の「種類を許す記載があり対象が空の場合、種類だけの実行前判定は通り、実行時の対象判定はどれも通らない」の根拠は、例 `Policy.Examples.emptyTargets_example` である。この例は、`KindCheck declaredRead emptyPolicy.kinds` を `emptyPolicy_kindCheck` で証明し、同じ列が `TraceAllowed` を満たさないこと（`not_traceAllowed_of_emptyTargets` による）と、事象のない列が通ること（`traceAllowed_nil`）を並べる。RV-PM の中1が指摘した、`KindCheck` を仮定に取るだけで使わない補題 `kindCheck_passes_but_target_fails` は消した（[RV-PM-handling](../reviews/RV-PM-handling.md)）。分離を一般の定理として証明したとは記録しない。

## 7. 写した定義の同一性

`Policy.lean` は第一項の `KindSet`・`KindSet.Subset`・`KindSet.Subset.trans`・`traceKinds`・`mem_traceKinds`・`KindCheck` を写して持つ。一致は `models/check-same-defs.sh` が確かめる（二つのモデルと `models/same-defs-tail.lean` を一時ファイルへ連結し、`@Policy.X = @PermissionKinds.X` を `rfl` で確かめる）。PM30 の検査で終了 0 であり、写しの `KindCheck` を逆向きにした複製では終了 1 になった（`pm30/results.md`）。このスクリプトを plan の検査の行へ加えて、どちらかのモデルを変えたときに必須にするまでは、保守上の未閉の危険として残る。plan への追加は取りまとめの担当である。
