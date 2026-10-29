# L20.1 の結果: BB の拡大の補題の試行（コミットしない）

2026-10-27。plan-l10-l50「L20」の表の L20.1 の行を、取りまとめが用意した作業用のディレクトリ（`<wt>`、ブランチ `m013/l20.1`）で行った。担当は Claude のサブエージェントである。試行はコミットせず、formal を B_WORK に戻した。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L20.1（BB の拡大の補題の試行。コミットしない） |
| B_WORK | `5ba67cb1b0a6ddc04f1530b8d659da28148daaf6`（L10.2 と L10.3 の取り込みの後の本線） |
| 判定 | **成り立たない**（単調性だけが成り立つ）。L00.04 の模型の `stTy_widenTop` の本番版は偽であり、反例を本番の定義で示した。停止条件の表の「`BuiltinOnly` の BB」の行の「L20.1 で拡大の補題が成り立たなければ停止」に当たるので、ここで止める |
| 閉じた範囲 | 単調性の証明、壁の一般形の証明、四主定理の前提を満たす具体の反例、Top のときの対照、代案 BA の測定用の試行ビルド（採用ではない） |
| 未完 | 代案の選択（取りまとめが設計者へ尋ねる）。`K_Empty` を被覆の関係にする案は、被覆の関係（L10.5）がまだないので試していない |
| 設計書 | 変えていない |

## 試した言明と証明の要点

試行の差分は [trial.diff](trial.diff)（`formal/Benitoite.lean` の import 1行と、新しいファイル `Release/Lemmas/WidenTrial.lean`）。名前空間は `Benitoite.Release.WidenTrial`。ただし下の (1)(2)(5) は L20.7 で置く場所を想定して `Benitoite.Release` に置いた。

### 成り立つもの

1. `ContTy.mono_end`: `ContTy P B Ψ R ε k a b ε0 Re → Eff.Sub ε0 ε0' → ContTy P B Ψ R ε k a b ε0' Re`。ContTy に関する帰納法で示した。ε0 を読むのは `K_Empty` の `Eff.Sub ε ε0` だけなので、`K_Empty` の場合は `Eff.Sub.trans`、ほかの場合は帰納法の仮定をそのまま渡す。
2. `StateTyE.mono`: `StateTyE P B Eb s → Eff.Sub Eb Eb' → StateTyE P B Eb' s`（状態の4つの形の各場合に (1) を当てる）。手順 1 の単調性は成り立つ。
3. `stateTy_of_stateTyE_sub`: `StateTyE P B Eb s → Eff.Sub Eb Eb' → BuiltinOnly P B Eb' → StateTy P B s`。条件付きの拡大である（下の「部分的に成り立つ条件」）。

### 壁（`K_Empty` の `Eff.Sub`）

4. `not_builtinOnly_of_sub`: `Eff.mem Eb (.name l r) → r ≠ Ix.top → Eff.Sub Eb Eb' → ¬ BuiltinOnly P B Eb'`。`Eff.Sub` は原子ごとの所属の包含であり、`BuiltinOnly` の原子は `.nameTop l` だけなので、範囲の位置が Top でない原子を含む効果には `BuiltinOnly` を満たす上界がない。RV-PL10 重大2 の見込み（`File.Write[R] ∉ {File.Write[Top]}`）を確かめた。
5. `ContTy.name_end_ix`: 既存の `ContTy.name_end`（Top の原子だけ）の範囲付きの版。原子 `.name l r` は、l を処理する `handle` の枠が継続になければ、同じ範囲の位置のまま末尾に届く（`handled_name` で `handled` が範囲の位置を見ないことを使う）。
6. `not_stateTy_run`: 計算 m のどの型付けの効果も `.name l r`（r ≠ Top）を含み、継続 k に l を処理する枠がなければ、`¬ StateTy P B (.run m k σ)`。(5) で原子を末尾まで運び、(4) で `BuiltinOnly` を否定する。

### 具体の反例

| 構成要素 | 内容 |
|---|---|
| 組み込みの表 `wB` | `Model.builtins` に、操作を持たない組み込みのエフェクト `File.Write` を足したもの。`wB_assumptions : ∀ P, wB.Assumptions P`（型付けを含む欄と `io_op`・`effect_ops`・`state_effect` だけを証明し直し、残りは `Model.assumptions` の欄を写した） |
| プログラム `progOf ix` | 定義 `f : () -> Unit ! {File.Write[ix]}`（本体は `return ()`）だけを持つ。`progOf_wellFormed`・`progOf_wellTyped`・`progOf_effectsOk` |
| 状態 `s0` | `⟨f(), [], ∅⟩`。`callF_typed`・`callF_closed` から `stateTyE_init_eff` で `s0_stateTyE ix : StateTyE (progOf ix) wB (Eff.substAt 0 [] [] (writeEff ix)) s0` |
| 強制 | `callF_forces`: `f()` のどの型付けの効果も `File.Write[ix]` を含む（`inv_app`・`inv_fnRef`・`Ty.Le.fn_fn'`・`Eff.substAt_name`） |
| 反例 | `s0_not_stateTy : ¬ StateTy (progOf dataTree) wB s0`（`dataTree` は `/data/**`） |
| 一般の言明の否定 | `widen_statement_false : ¬ (∀ P B, P.WellFormed → P.WellTyped B → P.EffectsOk B → B.Assumptions P → ∀ Eb s, StateTyE P B Eb s → StateTy P B s)` |
| 対照 | `topWiden_builtinOnly`: Top の像へ広げた末尾 `Eff.single "File.Write"` は `BuiltinOnly` を満たす。`not_sub_topWiden`: しかし初期の効果はそれに構造上含まれない。`s0_top_stateTy`: `ix = Top` のとき同じ状態は `StateTy` に入る。壁は範囲の位置だけであり、名前が組み込みでないことや Fail によるものではない |
| 到達先 | `s0_reachable_stateTyE`: `s0` から到達した状態はすべて同じ末尾で `StateTyE` に入る（`steps_preserve`） |

効果の名前に `File.Write` を使い、範囲の種類（path）と名前の種類が合う原子にした。今の本番の定義は名前と範囲の種類の対応（L20.3 の `effKind`）を持たないが、この反例はその対応を満たすので、L20.3 の後も同じ形で残る。利用者の定義が範囲付きの効果を宣言する形は、非 Top のプログラムの典型であり、作為的な状態ではない。

公理: 26定理と7定義の `#print axioms`（[axioms.lean](axioms.lean)・[axioms.log](axioms.log)）は、いずれも `propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依存する。`sorryAx` はない。

### 部分的に成り立つ条件と、主定理が非 Top のプログラムに言えること

- 拡大が成り立つのは (3) の条件、すなわち `∃ Eb', Eff.Sub Eb Eb' ∧ BuiltinOnly P B Eb'` のときに限る。(4) により、この条件は「Eb の名前の原子がすべて Top の範囲の位置を持つ」ことを含む。末尾 Eb は計算の効果のうち処理されずに残った原子を含むので（(5)）、非 Top の原子がすべて継続の中の `handle` の枠で処理される状態に限って成り立つ。処理されずに末尾に届く非 Top の原子が一つでもある状態は、(6) により `StateTy` に入らない。
- 公開の `progress`・`preservation`・`step_sound` は前提が `StateTy` なので、そのような状態について何も言わない。`effect_soundness`・`effect_soundness_noLamNames` は空の効果の計算だけを扱い（末尾は `Eff.empty`）、影響を受けない。
- 内部の補題は形が違う。`preservationE`（`PresMain.lean`）と `step_soundE`（`StepSound.lean`）は `BuiltinOnly` を前提に持たず、任意の Eb の `StateTyE` について成り立つ。したがって非 Top のプログラムでも、初期の効果を末尾に固定した `StateTyE` の保存と `step` の健全性は既に言える（`s0_reachable_stateTyE`）。`progressE`（`Progress.lean`）だけが `BuiltinOnly P B Eb` を要する。その使い道は `no_unhandled_user` で「末尾に届いた利用者の操作の名前は `P.effects l = none` に反する」ことと、Fail が末尾に届かないこと（`fails = []`）であり、範囲の位置が Top であることは使っていない（下の BA の測定で確かめた）。

## 代案ごとの影響

どちらも `StateTy` の内容の変更であり、受け入れ済みの範囲（問18 の行 10 の BB）の外である。本枝は採っていない。

### 案 BA: `BuiltinOnly` を範囲の位置によらない形にする

測定用に、`BuiltinOnly` の原子の条件を `∃ l r, a = .name l r ∧ P.effects l = none ∧ (B.effects l).isSome` に変えて全体をビルドした（[trial/trial-BA-measure.diff](trial/trial-BA-measure.diff)。測定の後に戻した）。

| 項目 | 結果 |
|---|---|
| 壊れた本番の宣言 | 2。`BuiltinOnly.topImage`（L10.2 が置いた「原子は Top の像だけ」の補題。言明が偽になる。測定では本体を `sorry` にして下流を検査した）と `no_unhandled_user`（分解の形が一つ増えるだけ。`obtain ⟨l, r, hl, …⟩` に直して通った） |
| 壊れたファイル | 2（`Release/Semantics.lean`・`Release/Lemmas/Progress.lean`）。ほかは試行の `WidenTrial.lean` だけで、その失敗は BB の壁を述べる宣言（(4)・`topWiden_builtinOnly`・`s0_top_stateTy`）が BA で偽か形違いになるためである |
| 四主定理と `step_sound` | `Release/Theorems.lean`・`Surface` 側を含め、変更なしでビルドが通った（[trial/build-BA-3.log](trial/build-BA-3.log)） |
| 反例の状態 | BA の定義で `s0` が `StateTy` に入ることを一時ファイルで確かめた（`s0_stateTy_BA`。[trial/ba_check.lean](trial/ba_check.lean)・[trial/ba_check.log](trial/ba_check.log)。公理は標準の三つ） |
| `StateTy` の内容 | 末尾に範囲付きの組み込みのエフェクトの原子を許す。`StateTy` に入る状態の集合が広がる |
| 四主定理の前提 | `progress` の前提が弱まり（結論は強まる）、`preservation` は前提と結論の両方が広がる、`step_sound` の前提が弱まる。`effect_soundness`・`desugar_typed` は変わらない。`Eff.Sub` は構造上の包含のまま（問13 と両立） |
| L20 以降の枝 | L20.7 の「BB を Top の像の上で意味を保つ形にする」は「範囲付きの原子に広げ、旧の像（原子がすべて `Atom.TopImage`）で旧の `BuiltinOnly` と同値であることを示す」に変わる。`BuiltinOnly.topImage` はその前提付きの補題に置き換える。07-04「形式化で仮定するもの」の `BuiltinOnly` の箇条を直す。拡大の補題は不要になる |

### 案「`K_Empty` を被覆の関係にする」

被覆の関係（L10.5 の許可の関係）がまだないので、ビルドしていない。字面からの見込みは次のとおりである。

| 項目 | 見込み |
|---|---|
| `StateTy` の内容 | `K_Empty` の前提 `Eff.Sub ε ε0` を「ε0 が ε を被覆する」（範囲付きの原子は同じ名前の原子の範囲の包含、行と Fail は構造上の包含）に替える。`ContTy` はストアの継続の場所の型付け（`CellOk` の `.cont`）にも使うので、継続の場所の型付けの内容も同時に変わる |
| 四主定理の前提 | `StateTy` の内容が広がるので、BA と同じく `progress`・`preservation`・`step_sound` の前提の内容が変わる。拡大の補題は単調性と被覆の推移で示せる見込み（未証明） |
| 証明の変更 | `K_Empty` を参照する本番の箇所は `Release` の8ファイル・18箇所（`ContLemmas` 7、`FailureCont` 4、`EffectSound` 2 ほか）。`ContTy.inv_nil` の結論が被覆になり、その2ファイルの利用（`Progress`・`ContLemmas`）と、`name_end`・`fail_end` など末尾へ所属を運ぶ補題が「Top は Top にだけ覆われる」「Fail は構造上の包含」の補題を要する。(1) の単調性は被覆の推移を要する |
| L20 以降の枝 | L10.5（被覆の関係と κ）が `K_Empty` より先に要り、κ の `effKind` への具体化（L20.7）が `StateTy` の内容に入る。L20.2（`K_Empty` の `Ty.WF` の文脈）と同じ構成子を変えるので、順序の調整が要る |

### 補足: `StateTy` を変えない形の候補（未評価）

`preservationE`・`step_soundE` は任意の Eb で成り立ち、`progressE` が使う `BuiltinOnly` の部分は範囲の位置によらない。そこで、`StateTy` と四主定理を変えずに、`StateTyE` と範囲によらない末尾の条件を前提とする定理を別に加える形も考えられる。主定理の追加・前提の扱いに当たるかは本枝で判断していない。取りまとめが代案と並べて尋ねるかを決める。

## L20.2〜L20.7 への申し送り

1. 取りまとめ: 本枝は停止条件に当たる。設計者の回答までは plan-l10-l50 のとおり L20.2 以降を起動しない。尋ねる内容は「BA」「`K_Empty` を被覆の関係にする案」と、必要なら上の補足の形である。
2. L20.7（どの案でも）: `ContTy.mono_end`・`StateTyE.mono`・`ContTy.name_end_ix` は案によらず使える。置き場所は `ContTy.mono_end`・`name_end_ix` が `Lemmas/ContLemmas.lean`、`StateTyE.mono` が `Lemmas/PresHelpers.lean` の候補である（試行の差分の証明をそのまま写せる）。
3. L20.7（BA の場合）: `BuiltinOnly.topImage` を「原子がすべて `Atom.TopImage` なら旧の定義と同値」の補題に置き換え、`no_unhandled_user` の分解を直す。反例 `progOf`・`wB` は、BA で非 Top のプログラムが `StateTy` に入ることの小例に使える。
4. L20.2: `K_Empty` に `Ty.WF` の文脈を足すとき、被覆の案を採るなら同じ構成子の変更が重なる。
5. 反例の `wB_assumptions` は `{ Model.assumptions P with … }` で型付けを含む欄（`delta_typed`・`io_kind`・`io_typed`・`io_exists`・`release_exists`）と `io_op`・`effect_ops`・`state_effect` を証明し直した。L20.7 で `Model.assumptions` の新版を作るときに同じ形を使える。

## 検査

L の一度の切り替えの試行ビルドの行（plan「検査の割り当て」）に従い、排他の道具で全体のビルドを走らせた。作業末の work の検査は行っていない（コミットしない試行のため）。

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 単一ファイル 1 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 Benitoite/Release/Lemmas/WidenTrial.lean` | 1（名前空間の中で `ContTy.mono_end` を点記法で引けない誤り5件など） | 0.50 秒 | [trial/single-1.log](trial/single-1.log) |
| 単一ファイル 2〜4 | 同上（計時なし） | 2回目 0、3回目 1（`wB_assumptions` の `delta_typed` の型の不一致）、4回目 0 | 各1秒未満 | 本書 |
| 全体のビルド 1（試行、組み込みの表の変更前） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <l20.1>/trial/build-1.log` | 0。429ジョブ、sorry なし。L10.3 の `IPCover` もここで作られた | 1.59 秒（待ち0秒） | [trial/build-1.log](trial/build-1.log) |
| 全体のビルド 2（試行の最終の状態） | 同上 | 0。429ジョブ、sorry なし | 1.07 秒（待ち0秒） | [trial/build-2.log](trial/build-2.log) |
| BA の測定 1 | 同上（`BuiltinOnly` の変更だけ） | 1（`BuiltinOnly.topImage`） | 0.66 秒 | [trial/build-BA.log](trial/build-BA.log) |
| BA の測定 2 | 同上（`topImage` を `sorry`） | 1（`no_unhandled_user` だけ） | 139.92 秒 | [trial/build-BA-2.log](trial/build-BA-2.log) |
| BA の測定 3 | 同上（`no_unhandled_user` の分解を直す） | 1（試行の `WidenTrial` だけ。上の表） | 9.57 秒 | [trial/build-BA-3.log](trial/build-BA-3.log) |
| BA の反例の確かめ | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <tmp>/l20.1/ba_check.lean`（BA の測定 3 の生成物の上） | 0 | 0.40 秒 | [trial/ba_check.log](trial/ba_check.log) |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <tmp>/l20.1/axioms.lean`（全体のビルド 2 の生成物の上） | 0 | 0.29 秒 | [axioms.log](axioms.log) |
| B_WORK に戻した後の全体のビルド | 同上の道具で `<l20.1>/build-restore.log` | 0。428ジョブ、sorry なし | 144.24 秒（待ち0秒） | [build-restore.log](build-restore.log) |

ログの中の手元の絶対パスは `<wt>`・`<repo>`・`<home>`・`<tmp>` に置き換えた。

## 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size`。排他の道具の値は待ち合わせた子孫のうち最大の一プロセスの値で、並行した lean のプロセスの合計ではない。

| 実行 | 原値（バイト） | MiB | GiB |
|---|---:|---:|---:|
| 単一ファイル 1 | 738689024 | 704.5 | 0.69 |
| 全体のビルド 1 | 1510850560 | 1440.9 | 1.41 |
| 全体のビルド 2 | 1511473152 | 1441.5 | 1.41 |
| BA の測定 1 | 731627520 | 697.7 | 0.68 |
| BA の測定 2（`Semantics` の下流の再ビルド） | 2646605824 | 2524.0 | 2.46 |
| BA の測定 3 | 1509294080 | 1439.4 | 1.41 |
| BA の反例の確かめ | 740556800 | 706.2 | 0.69 |
| 公理の依存 | 700137472 | 667.7 | 0.65 |
| B_WORK に戻した後の全体のビルド | 2645868544 | 2523.3 | 2.46 |

単一ファイル 2〜4 は計時で包んでいない。`-M 12288` は変えていない。

## 失敗と修正

- 単一ファイル 1: 名前空間 `WidenTrial` の中で `theorem ContTy.mono_end` と書いたため `WidenTrial.ContTy.mono_end` になり、点記法で引けなかった。`_root_.Benitoite.Release.` を付けて本番の名前空間に置いた。`callF_closed` の `simp` に `Val.VarsInList` が足りなかった。
- 最初の反例は `Model.builtins` のまま `File.Write[/data/**]` を使ったが、`Model.builtins` は `File.Write` を組み込みのエフェクトに持たないので、Top の原子でも `BuiltinOnly` が成り立たない。壁が範囲の位置だけであることを示せないので、`File.Write` を足した `wB` に替え、Top の対照（`s0_top_stateTy`）を加えた。
- 単一ファイル 3: `{ Model.assumptions P with … }` で、型付け `HasTypeV(s)` を含む欄は表が違うと定義上等しくならない。`delta_typed`・`io_kind`・`io_typed`・`io_exists`・`release_exists` を `Model` と同じ証明で書き直した。
- BA の測定 1〜3 は測定のための段階的な修正で、失敗ではない。

## formal を B_WORK に戻したことの確かめ

試行の差分を保存した後、`git -C <wt> checkout -- formal` と `formal/Benitoite/Release/Lemmas/WidenTrial.lean` の削除で戻した。`git -C <wt> status --short formal` は空であり、`git apply --check` で [trial.diff](trial.diff) と [trial/trial-BA-measure.diff](trial/trial-BA-measure.diff) が B_WORK に当たることを確かめた。生成物も B_WORK の状態で作り直した（上の「B_WORK に戻した後の全体のビルド」）。残したのは本ディレクトリ `l20.1/` だけである。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 開始 | 22:46 ごろ（JST、依頼文を読み始めた時刻。分は推定） |
| 終了 | 23:11（本書の作成まで） |
| 外側の所要 | 約25分 |
| 能動時間 | 約20分（文書と定義を読む約8分、補題と反例の証明約6分、BA の測定の準備約2分、本書約4分）。外側の所要から全体のビルドの待ち約5分を除いた値 |
| 検査 | 全体のビルド6回の内側の時間の和 約297秒（排他の待ち0秒）、単一ファイルと公理の確かめ 計数秒 |
| 見込みとの比較 | 見込み 0.5〜1時間の範囲。上端の2倍（2時間）を超えていない |
