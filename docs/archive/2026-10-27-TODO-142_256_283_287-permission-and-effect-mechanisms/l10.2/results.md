# L10.2 の結果: 原子と不透明型の範囲の引数（一度の切り替え）

2026-10-27。plan-l10-l50「L10」の表の L10.2 の行を、取りまとめが用意した作業用のディレクトリ（`<wt>`、ブランチ `m013/l10.2`）で行った。担当は Claude のサブエージェントである。コミットは取りまとめが行う。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L10.2（原子と不透明型の範囲の引数。一度の切り替え） |
| B_WORK | `207e5a0a15a1f36409e8aa25103de2d544652992`（L10.1 の取り込みの後の本線） |
| 閉じた範囲 | `Atom.name l ix`・`Ty.opaque o ix`（`ix : Scope.Signature.Ix`）への切り替えと全ての腕・利用側の修正。明示の Top の構築関数、`Eff.single` の Top、資源の型の Top への限定、代入の5補題の一般化と Top の系、`BuiltinOnly` の字面の追随、`handled` の補題、原子の符号の `nameIxCode` への切り替え。小さい例。01-12 の「表記」「構文」と 07-04 の対応表の行 |
| 未完（計画どおり後の枝） | 範囲の被覆の判定（L10.3・L10.4）、意味の被覆の関係（L10.5）、`Ty.WF` の範囲の変数の文脈（L20.2）、値の所属の規則（L20.3・L20.4）、`BuiltinOnly` の BB（L20.7）、`handled` の点検と例（L30.3） |
| 適用した前提の変更の行 | 「資源の型は Top の添字」（問19、L10.2）。`release_exists` の量化は不変で、字面が `.opaque o` から `.opaqueTop o` へ変わった。`BuiltinOnly` は字面だけを Top の構築関数に合わせた（BB の行の「字面の追随は L10.2」）。そのほかの前提・結論の内容の変更はない |
| 停止条件 | 該当なし。`Builtins.Assumptions` の欄の追加 0、公理の追加 0、主定理の言明の字面の変更 0 |

## 試行（最初の30〜60分）

plan「検査の割り当て」の「L の一度の切り替えの試行ビルド」の行に従った。L00.01 の案 (i) の最終の差分（`l00.01/candidate-i/trial-30-final.diff`）を B_WORK に当て（B0 からの差は `Release/Lemmas/EffectSound.lean` の追加だけで、`git apply --check` が通った）、比較用の型 `ScopeRange` を採用定義の `Scope.Signature.Ix` に置き換えた。構成子は `Atom.name (l : EffName) (ix : Scope.Signature.Ix)`、`Ty.opaque (o : OpaqueName) (ix : Scope.Signature.Ix)`、Top の構築関数は `abbrev Atom.nameTop l := .name l (.fixed .top)` と `abbrev Ty.opaqueTop o := .opaque o (.fixed .top)` とした（既定引数と暗黙の変換なし）。原子の符号は L10.1 の申し送り 1 のとおり `2 * Order.nameIxCode l ix`、不透明型の木と比較は `Order.ixCode` にした。

| 試行 | 差分 | 終了 | 時間 | 最大常駐量 | 誤りの診断 | 壊れた宣言 | 壊れたファイル | 未検査のモジュール |
|---|---|---:|---:|---|---:|---:|---:|---:|
| 1 | [trial/trial-1.diff](trial/trial-1.diff)（56ファイル、+203/−167） | 1 | 167.02 秒 | 2651570176 バイト（2528.7 MiB、2.47 GiB） | 21（sorry の警告3は別） | 9 | 2 | 3 |

- 失敗したモジュールは `Scope.TopCompat`（`TopEmbedding.lift_single` の1宣言）と `Scope.RepresentationExamplesI`（`Atom.ofRelease`・`toRelease?`・`toRelease_ofRelease`・`toRelease_eq_some`・`liftAtoms`・`liftAtoms_ofRelease`・`liftAtoms_single`・例1件の8宣言）だけである。どちらも、旧の名前だけの原子 `Release.Atom.name l` を一引数で書いていた。
- 未検査（失敗したモジュールに推移的に依存）: `Benitoite.Scope.CompatExamples`・`Benitoite.Scope.SwitchExamples`・`Benitoite`（入口）。本体のビルド 2 で `SwitchExamples` の5節の7件の誤り（1宣言の埋め込み `embIx` と、それを使う証明）が新たに見つかった（下の「失敗と修正」）。
- 数え方は L00.01 の道具 `count_breaks.py` を写した [trial/tools/count_breaks.py](trial/tools/count_breaks.py)（診断の位置を直前の宣言へ対応付ける）。集計は [trial/counts-1.json](trial/counts-1.json)、全出力は [trial/build-1.log](trial/build-1.log)。
- 件数の読み方: 試行は L00.01 で全体が通るまで直した差分の上に積んだので、上の数は「案 (i) の差分を `Ix` に替えたときの残りの破損」である。構成子を変えただけの破損の総数は L00.01 の記録（三系列の和で113宣言・42ファイル）にある。上端（3時間）の2倍を超える見込みはないので、本体へ進んだ。代案（新しい定義を並べて一群ずつ移す方式）は使っていない。

## 変更と接続

### 変えた構成子と定義

| ファイル | 変更 |
|---|---|
| `Release/Atom.lean` | `import Benitoite.Scope.Signature`。`Atom.name (l) (ix : Scope.Signature.Ix)`。明示の Top の構築関数 `Atom.nameTop`、`Atom.nameTop_eq`（`Ix.top` との一致）、`Atom.name_inj`。旧の原子の像 `Atom.TopImage`（範囲の位置が Top の名前の原子と行）と `topImage_nameTop`・`topImage_rho`、系を得るための `Atom.exists_name_iff_top` |
| `Release/Types.lean` | `Ty.opaque (o) (ix : Scope.Signature.Ix)`。`Ty.opaqueTop`・`Ty.opaqueTop_eq`。Fail の列は `List Ty` なので、Fail の列の不透明型も同じ構成子で範囲の位置を持つ |
| `Release/Order/Atoms.lean` | `import Benitoite.Release.Order.Range`。`Atom.code (.name s r) = 2 * Order.nameIxCode s r`。`code_injective` は `nameIxCode_injective` で閉じた。L00.01 の試行の `tri`・`pairCode`・`wordsCode`・`rangeCode` は置かない（L10.1 の定義を使う） |
| `Release/Order/Types.lean`・`Release/Finite.lean` | 不透明型の木 `.node (.rank 1) [.node (.text o) [], .node (.nat (Order.ixCode r)) []]`（L10.1 の申し送り 3）、`tyCompare`・`tyCompareWith` は名前の比較の後に `compare (ixCode r) (ixCode q)`。`Ty.toTree_injective` の腕は `ixCode_injective` で閉じた |
| `Release/Effect.lean` | `Eff.single l` は `.nameTop l` の一原子（`Eff.mem_single` の字面が `.nameTop l`）。`Eff.mem_single_name`: `mem (single l) (.name m r) ↔ m = l ∧ r = Ix.top` |
| `Release/Typing.lean` | `handled` の名前の腕を `.name l _` とし、範囲の位置を見ないことを注釈に書いた（L00.06b の限界 4 の試行の定義と同じ）。`C_Use` は `.opaqueTop o` と `.nameTop stateEff` |
| `Release/Semantics.lean` | `K_Release`・`K_Drop` は `.opaqueTop`・`.nameTop`。`BuiltinOnly` の字面を `a = .nameTop l` にした。`BuiltinOnly.topImage` |
| `Release/Assumptions.lean` | `release_exists` の字面を `.opaqueTop o` にした（欄の数・量化は不変） |
| `Release/Syntax.lean` | `Const.type (.opaque o _) = .opaqueTop o`（定数の型は Top のまま） |
| 腕の追加だけ | `Normalize`・`TypeShift`・`TypeSubst`・`TypeSubstLemmas`・`TypeRows`・`TypeVariables`・`TypeBounds`・`NoFail`・`CoverageTypes`・`BuiltinTable`・`Lemmas/Closed`、`Surface/AdmissibleCheck`・`NoFailCheck`・`Lemmas/ShiftClean`。型の移動・型と行の代入・正規化は `.opaque o r => .opaque o r` で範囲の位置を変えない |
| Top の構築関数への字面の書き換え | `Release/Lemmas/*`（`ContLemmas`・`EffectSound`・`FailureBase`・`Inversion`・`Progress`・`Basic`）、`Surface/*`（`Check`・`Typing`・例と検査の補題）、`Interval/*`（`with` の資源の枠）、`SurfaceCheck/Validation.lean` |
| `Exchange/Convert.lean` | 交換の原子と不透明型は Top として読む。範囲付きの不透明型の書き出しは `"ranged opaque type is not in this exchange version"` で拒否する。Top のパターンは `.opaque n (.fixed .top)` と明示した |
| `Interval/EvalClosed.lean` | `sameType` の不透明型の腕を `.opaque a ra, .opaque b rb`（名前と範囲の位置の両方の一致）にした。試行の差分の `.opaqueTop a, .opaqueTop b` は非 Top の型の一致を見ない形だったので、範囲の位置まで比べる形に広げた |
| `Scope/TopCompat.lean` | `TopEmbedding.lift_single` の言明を `emb.ofRelease (.nameTop l)` にした（旧 `Eff.single` は Top の原子） |
| `Scope/RepresentationExamplesI.lean`（比較の模型） | 本番の原子が範囲の位置を持つようになったので、模型の原子に本番の非 Top の名前の原子を運ぶ構成子 `other` を加え、`ofRelease` を単射に保った（Top は模型の Top、非 Top は `other`）。符号を3を法とする形にした。被覆と所属には `other` を使わない |
| `Scope/SwitchExamples.lean`（模型） | 5節の `embIx` は範囲の位置をそのまま運ぶ埋め込みにした。`nonTopIx_not_lifted` に「原子がすべて `Atom.TopImage` の効果」の前提を加えた（本番の効果は非 Top の原子を含みうるので、無条件の言明は偽になる）。`nonTopI_not_lifted` は証明だけを直した |
| 新 `Release/RangeIxExamples.lean`、`Benitoite.lean` | 小さい例（下の「確かめた例」）。既定の import の `Benitoite.Release.Theorems` の次に一行加えた |

黙った Top への狭め（範囲を捨てて Top に置き換える定義）は置いていない。差分の中で範囲の位置を捨てるパターンは、範囲によらず同じ判定をする述語（`Ty.WF`・`RawWF`・`Legacy` などの不透明型の腕、`AdmissibleCheck`・`signatureQ` の名前の腕、`BuiltinTable` の等値の要約）と、`Const.type`（第2引数は値の番号）と、意図した `handled` だけである。交換の `fromEff` は交換の原子の一覧（Top の原子だけ）を走査するので、非 Top の原子を書き出さない（置き換えはしない。L50.1 への申し送り 5）。

### 一般化した補題と Top の系

代入の5補題の言明を範囲の位置へ一般化した（`∃ l, a = .name l ∧ …` → `∃ l r, a = .name l r ∧ … (.name l r)`）。旧の言明は、旧の原子の像 `Atom.TopImage` に限る Top の構築関数の系として残した。

| 一般化した補題 | Top の系 |
|---|---|
| `Eff.mem_rawBind_rowImage`（`TypeComposition`） | `Eff.mem_rawBind_rowImage_top` |
| `Eff.mem_bind`（`TypeComposition`） | `Eff.mem_bind_top` |
| `Eff.mem_substRho_rowImage`（`SubstEnv`） | `Eff.mem_substRho_rowImage_top` |
| `Eff.substRho_true_scoped`（`TypeScopedSubst`） | `Eff.substRho_true_scoped_top` |
| `Eff.substAt_name`（`TypeScopedSubst`） | `Eff.substAt_nameTop` |

同じ形で `Eff.substRho_true`（`match a with | .name l r => …`）も範囲の位置を持つ言明になった（L00.01 の試行と同じ）。代入が範囲の位置を変えないことは、`Eff.mem_bind_name`（代入の後の名前の原子は、同じ名前と同じ範囲の位置で元の効果にあるか、行の像から来る）、`Ty.substAt_opaque`・`Ty.shift_opaque`・`Ty.bind_opaque` で示した。

### `handled` の補題

- `handled_name`: `Eff.test (handled P B h) (.name l r) = Eff.test (handled P B h) (.nameTop l)`（定義から `rfl`）。
- `mem_handled_name_iff`: 範囲の位置の違う同じ名前の原子は、`handled(H)` に同時に含まれるか同時に含まれない。

### 主定理の言明の比較

| 定理 | 変更前後の言明 | 旧の像で旧の内容と同値であることを示す補題 |
|---|---|---|
| `Release.progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound` | `Release/Theorems.lean` は差分に現れない。字面は同じ | 言明が使う定義のうち変わったのは `StateTy` の `BuiltinOnly`・`K_Release`・`K_Drop`・`handled` と `Builtins.Assumptions.release_exists` の字面で、どれも Top の像の上で旧と同じ項である。`Atom.nameTop_eq`・`Ty.opaqueTop_eq`（Top の構築関数は `abbrev` で、旧の Top の項そのもの）、`BuiltinOnly.topImage`（末尾の効果は Top の像だけ）、`handled_name`（Top の原子での判定は旧の定義と同じ式）、`Eff.mem_single`（`Eff.single` は Top の一原子）、`Eff.*_top` の系 |
| `Surface.desugar_typed`・`surface_effect_soundness` | `Surface/Theorems.lean` は差分に現れない。字面は同じ | 同上。表層の `with` の規則は `.opaqueTop o`、操作と終了の原子は `.nameTop` で、旧と同じ項である |

ただし、プログラムの型には範囲付きの不透明型と原子を書けるようになったので、主定理はそれらを含むプログラムにも適用される（`Ty.WF` の不透明型の腕は `True` のままで、`rvar` を拒否しない。L20.2 への申し送り 1）。閉じた値に範囲付きの不透明型を与える規則はない（`Const.type` は Top）。

## 確かめた例

`Release/RangeIxExamples.lean`（`example` 10件、`#guard` 3件）。範囲の位置の違う原子・型の非等号（`/data/**` と `rvar 0` を Top と区別）、`Eff.single` が Top の原子を含み範囲付きの同名の原子を含まないこと、型代入が不透明型の範囲の位置を変えないこと、代入が範囲付きの名前の原子を同じ範囲の位置で残すこと、Fail の列の範囲付きの不透明型の所属と Top の型との区別、`Atom.code` が Top・`/data/**`・`rvar 0` を区別し同じ範囲で一致すること、`handled` が範囲の位置を見ないこと。大きな `decide` は使っていない。

## 設計書

| ファイル | 変更 |
|---|---|
| `docs/design/01-spec/01-12-core-calculus.md` | 「表記」に、範囲の位置 `ix ::= fixed R | rvar i` と `L[ix]`・`O[ix]`、範囲の位置のない綴りが Top を表すこと、明示の Top の構築関数（既定引数と暗黙の変換なし）と理由、現在の表層言語と Rust が Top だけを作ることを【方針】として書いた。「構文」の箇条に、構造の等号、`Eff.single`、代入・移動・正規化が範囲の位置を変えないこと、Fail の列、符号、`handled`、資源の型と `BuiltinOnly` の Top、定数の型を書いた。` ```text ` のブロックは変えていない |
| `docs/design/07-quality/07-04-formal-semantics.md` | 「01-12 との対応」の表に「表記・構文（名前の原子と不透明型の範囲の位置）」の行を加えた（「Rust は未接続」を含む）。「形式化で仮定するもの」の `BuiltinOnly` の箇条を「範囲の位置が Top の原子だけ」に直した |

L10.1 が足した 01-12 の節「操作の対象の範囲の領域と被覆」と、07-04 の同名の行は変えていない（L10.3 と並行するため）。両者の「現在のエフェクトの原子と型はこれらを使わない」「エフェクトの原子・型…はこれらを使わず」は本枝の後は事実と合わない（原子と型が `Ix` を、原子の符号が `nameIxCode` を使う）。取り込みで直す必要がある（申し送り 8）。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 試行のビルド | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>` | 1 | 167.02 秒（排他の待ち 0 秒） | [trial/build-1.log](trial/build-1.log) |
| 本体のビルド 2 | 同上 | 1（`SwitchExamples` だけ） | 164.85 秒 | [build-2-body.log](build-2-body.log) |
| 本体のビルド 3 | 同上 | 0（426 ジョブ） | 1.28 秒 | [build-3-body.log](build-3-body.log) |
| 本体のビルド 4 | 同上 | 1（新しい例のファイルの構文の誤り） | 159.05 秒 | [build-4-body.log](build-4-body.log) |
| 局所の単一ファイル | `cd <wt>/formal && lake env lean -M 12288 <ファイル>`（`TopCompat`・`RepresentationExamplesI` 3回・`EvalClosed`・`SwitchExamples`・`RangeIxExamples` 2回） | 最後は全て 0 | 各数秒 | 本書 |
| 作業末の既定の全体のビルド | 排他の道具 | 0。`Build completed successfully (427 jobs).`、`declaration uses 'sorry'` なし | 0.97 秒（ビルド済みの生成物の上） | [lake-build.log](lake-build.log) |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base 207e5a0a15a1f36409e8aa25103de2d544652992 --dry-run` | 0。選択は `spec_tally`・`spec_examples`（01-12 の変更による）と `formal_build`（`formal/Benitoite.lean` による）。plan-l10-l50「work の割り当て」の見込み（01-12 か 07-04 を変えた枝）と一致 | 数秒 | [work-check-dry-run.log](work-check-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base 207e5a0a15a1f36409e8aa25103de2d544652992` | 0。`spec_tally` の自己検査と集計、`spec_examples` 7件成功、`formal_build` 成功、`selected checks passed` | 9.35 秒 | [work-check.log](work-check.log)・[work-check-time.txt](work-check-time.txt) |
| 公理の依存 | `cd <wt>/formal && lake env lean -M 12288 <l10.2>/axioms.lean` | 0 | 数秒 | [axioms.lean](axioms.lean)・[axioms.log](axioms.log) |

公理: 55件（新しい定理19、言明か証明を変えた定理と符号に依存する定理21（`TopCompat` の1を含む）、模型の8、旧の主定理7）の `#print axioms` は、三つ全て34、`propext`・`Quot.sound` 3、`propext` だけ11、依存なし7であり、`propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依存する。`sorryAx` と独自の公理はない。

Rust の lib 全件・clippy・fmt は選ばれず、加えていない。`scripts/check-formal.sh` は実行していない（K10 と最終の関係状態の担当）。

## 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size`。排他の道具の値は待ち合わせた子孫のうち最大の一プロセスの値で、並行した lean のプロセスの合計ではない。

| 実行 | 原値（バイト） | MiB | GiB |
|---|---:|---:|---:|
| 試行のビルド 1（全体の再ビルド） | 2651570176 | 2528.7 | 2.47 |
| 本体のビルド 2 | 2647441408 | 2524.8 | 2.47 |
| 本体のビルド 4 | 2656157696 | 2533.1 | 2.47 |
| 作業末の既定のビルド | 1508884480 | 1439.0 | 1.41 |
| work の検査全体（cargo のビルドとテスト、`spec_tally`、ビルド済みの `formal_build` を含む一括の値） | 1437745152 | 1371.1 | 1.34 |

単一ファイルの `lake env lean -M 12288` は計時で包んでいない。`-M 12288` は変えていない。

## 失敗と修正

- 試行1: `TopCompat`・`RepresentationExamplesI` の9宣言（上の表）。`lift_single` は `.nameTop l` に直した。模型は `other` の構成子で埋め込みを単射に保った。模型の局所の検査の1回目は `liftAtoms_single` の `other` の腕が閉じず（両辺の `==` が false になることを `simp` が出さなかった）、`beq_false_of_ne` で書き換えて閉じた。2回目は非推奨の `if_false`・`if_neg` の警告が出たので `↓reduceIte` に替えた。
- 本体のビルド 2: 試行で未検査だった `SwitchExamples` の5節が失敗した（7件、宣言 `embIx`・`nonTopIx_not_lifted` とそれを評価する `#guard`）。`embIx` を範囲の位置を運ぶ埋め込みにし、`nonTopIx_not_lifted` に旧の効果の像の前提を足した（上の表）。ビルド 3 で終了0。
- 本体のビルド 4: 新しい例のファイルで、`#guard` の前に `/-- -/` の注釈を置いた構文の誤り。通常の注釈に替え、局所の検査で不要な `simp` の引数の警告2件も消した。
- 作業用の Python で設計書を書き換えるとき、macOS の Python 3.9.6 が長い行の多バイト文字で `SyntaxError: Non-UTF-8 code` を出した（ファイルは正しい UTF-8 で、`compile` には通る）。`exec(compile(open(...).read(), ...))` で実行した。結果に影響しない。

## ずれと申し送り

計画からのずれ: L00.01 の差分が触らなかった `Scope/TopCompat.lean`・`Scope/RepresentationExamplesI.lean`・`Scope/SwitchExamples.lean`・`Interval/EvalClosed.lean` の挙動の拡大（上の表）を本枝で直した。前者三つは模型と採用定義の互換の層で、本番の原子が範囲の位置を持つと旧の埋め込みの言明が成り立たなくなるための追随である。新しいファイル `Release/RangeIxExamples.lean` は計画の候補の名前になかったので、例の置き場所として本枝で決めた。

### L10.4 へ

1. 効果の行の整列と重複除去は `Atom.code`（`2 * nameIxCode l ix`）の順で行う。`/32` の CIDR と同じアドレスの完全一致は別の符号の別の原子であり、`Range.normalize` を整列の前に通すかは義務 6 と合わせて決める（L10.1 の申し送り 4 のまま）。
2. `Release/Order/Atoms.lean` の非公開の `charsCode_injective`・`digit_lt` は使われなくなった（`Atom.charsCode`・`codeBase` は模型が使う）。整理は L50.3 の旧の互換層の整理でよい。

### L10.5 へ

3. 旧の言明を系として残す形は `Atom.TopImage` と `Atom.exists_name_iff_top` で作れる（5件の系はいずれも一行の書き換え）。`Eff.Sub` と `Eff.eq_of_sub_of_sub` は変えていない（構造上の包含のまま）。
4. `Scope.TopCompat` の `TopEmbedding` は本番の原子（範囲付き）を旧の側に持つので、本番の型での具体化は恒等に近い（`SwitchExamples.embIx`）。「旧の効果」は原子がすべて `Atom.TopImage` の本番の効果として前提に書く必要がある（`nonTopIx_not_lifted` の形）。L00.06 の系を本番の型で置くときはこの形を使う。

### L20・L30・L50 へ

5. L20.2: `Ty.WF` の不透明型の腕は `True` のままで、プログラムの型の `rvar` を拒否しない（`Ix.WF` を入れる枝）。名前の原子の `rvar` も同じく制限していない。
6. L20.3・L20.4: `Const.type` は Top の不透明型を返す。閉じた値に範囲付きの型を与える規則はまだない。
7. L20.7: `BuiltinOnly` は Top の名前の原子だけを許す（`BuiltinOnly.topImage`）。BB の拡大はこの定義の上で行う。L30.3: `handled_name`・`mem_handled_name_iff` を名前全体の除去の点検に使える。
8. L50.1: 交換の読み込みは原子と不透明型を Top として読み、範囲付きの不透明型の書き出しは拒否する。`fromEff` は交換の原子の一覧を走査するので、非 Top の原子は書き出されない（誤りにもしない）。新しい版の交換で扱う。

### 取りまとめへ

9. 01-12「操作の対象の範囲の領域と被覆」の「現在のエフェクトの原子と型はこれらを使わない」と、07-04 の同名の行の「エフェクトの原子・型・型付け・主定理と `Builtins.Assumptions` はこれらを使わず、変更しない」は、本枝の後は事実と合わない。L10.3 の取り込みと合わせて、「原子と不透明型は範囲の位置 `Ix` を持ち、原子の符号は `nameIxCode` を使う。被覆の判定は型付けに接続していない」の趣旨へ直す必要がある。本枝は並行の指示によりこの節と行を変えていない。
10. 既定の import（`Benitoite.lean`）には `Benitoite.Release.Theorems` の次に `Benitoite.Release.RangeIxExamples` を一行加えた。L10.3 の行と衝突すれば取り込みで解く。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 開始 | 22:07 ごろ（JST、依頼文を読み始めた時刻。分は推定） |
| 試行の終了 | 22:27（件数の集計まで） |
| 終了 | 22:44（本書の作成まで） |
| 外側の所要 | 約37分 |
| 能動時間 | 試行 約15分（文書を読む約12分を含む）、本体 約14分（定義と証明約6分、設計書約3分、本書約5分）。合計 約29分（外側の所要から全体のビルドの待ち約8分を除いた値） |
| 検査 | 全体のビルド 5回の内側の時間の和 約493秒（排他の待ち 0 秒）、work 9.35 秒、局所の検査と公理の確かめ 計数十秒 |
| 見込みとの比較 | 見込み 1.5〜3時間を下回った。上端の2倍（6時間）を超えていない |
