# RV2 段1（全Lean）の独立レビュー

- 日付: 2026-10-19
- レビュー担当: Opus 5.5
- 対象: san_benito の `46339150`（L7 の取り込み）。開始版 `72791407` との差分 `git diff 72791407 46339150 -- formal docs/design`（119 ファイル、追加 17959 行・削除 2640 行）。改造のディレクトリの design.md 12 節、plan.md の Lean の区切りと RV2 の行、decisions.md の R141〜R156、reviews/RV1.md・RV1-response.md、l1〜l7 の results.md。
- 範囲: 定義・言明・仮定・境界を読んだ。証明本文の逐語レビューはしていない。リポジトリのファイルは書き換えていない。

## 結論

Rust の段（T1〜）へ進んでよい。ただし、中 1 件（文書の記述の補足だけで、Lean の直しは要らない）を、plan の「指摘反映をRust開始の条件にする」に従い T1 の前に反映する。

指摘の件数は、重 0・中 1・軽 4 である。

設計者の確認が要る新しい点はない。根拠は次のとおりである。

- 主定理と公開の言明（開始版の README の公理確認の一覧にある 40 件。進行・保存・エフェクトの健全性・step_sound・desugar_typed・surface_effect_soundness・網羅性の 6 件・公開検査器 11 件・checkProgram の 2 件・0.0.9 の小証明など）を `#check @` で両版から出力して比べた。文字列が変わったのは、0.0.9 の内部の補題 2 件（`Surface.HasTypeQ.desugar`・`Surface.builderOp_desugar_typed`）だけである。どちらも計画どおりの変更である（後述）。
- 公理: 開始版の 40 件の `#print axioms` の出力は、両版で完全に一致した。現在の README の 269 件は、すべて標準の三公理（propext・Classical.choice・Quot.sound）の部分集合であり、sorryAx もプロジェクト独自の公理もない。
- `Release/Assumptions.lean`・`Release/Theorems.lean`・`Surface/Theorems.lean` は開始版とファイル全体が同一である。`Builtins.Assumptions` の欄と量化は増えていない。
- 定義を通じた意味の変化は四つある。(a) 型付けの判断に専用の構築器の項が加わった。(b) ラムダ・遅延・節・遅延のセルの本体を、構築器の場所を隠したストアの型で検査する。(c) Integer の定数を 64 ビットの範囲に限った。(d) 上の (b) により `Builtins.Assumptions` の意味が変わった。いずれも設計書で決まっている（(a)(b) は design 3.3・12.2、(c) は 6.2 と R120 の設計者の選択、(d) は R133）。構築器を含まない既存のプログラムと状態については、(a)(b)(d) は判断を変えない（構築器の場所を持たないストアの型では、隠す操作が恒等になるため）。(c) は言語の値域の外の定数を項の集合から除くだけである。

## 確かめたことと方法

| 観点 | 方法 | 結果 |
|---|---|---|
| HEAD | `git rev-parse HEAD` | 当初は c31e64b0 だったので `git checkout --detach 46339150` で切り替えた。以後は 46339150 |
| 生成物のない状態からの既定ビルド | worktree の formal/ には `.lake` がなかった（依存パッケージもない）。`lake build`（既定の 7 対象）。開始版は `git archive 72791407 formal` を一時領域へ展開して同じく実行 | 現在版は 293 ジョブで成功、外側 1 分 51 秒。開始版は 273 ジョブで成功、1 分 45 秒。警告 0 件、sorry の警告 0 件。toolchain は v4.34.1 |
| 危険な語の追加 | 差分の追加行と全ソースを grep（sorry・admit・axiom・native_decide・implemented_by・ofReduceBool・unsafe・opaque など） | 該当なし。追加は `partial def validateIntegerConstants`（交換の JSON 検査の実行用の関数で、証明には使わない）と、`maxHeartbeats 800000` の 2 箇所（LogExamples など。入力と期待値は rfl のまま） |
| 公理の依存 | README の全 `#print axioms` を抜き出して一つの入力にし、両版で `lake env lean` を実行して比べた | 開始版 40 件は出力が完全一致。現在版 269 件（依存あり 242、依存なし 27）は標準の三公理の範囲 |
| 公開の言明 | 開始版の 40 件の名前に `#check @` を付け、両版で出力して diff | 差は上記の内部の補題 2 件だけ（407 行と 404 行。主定理 30 件の部分は 349 行まで一致） |
| 型付け・WellTyped・StateTy・Assumptions の定義 | `git diff` で Typing・Semantics・WellFormed・Assumptions・Model を読んだ | 追加した規則と変わった前提を「観点ごとの所見」に列挙した |
| 交換の自己検査 | `python3 -B formal/tests/test_*.py` の 7 本 | batch2 7・batch3 7・batch4 15・extensible 22・named 13・try 8・width 4、計 76 テストがすべて成功 |
| 退化した言明の確認 | 新しい定理の前提が満たせるか、結論が自明でないかを、具体例と定義から確かめた | 「観点ごとの所見」に記す。退化は見つからなかった。定義どおりで中身の薄い補題が 2 つある（軽 2） |
| 写し（01-12・07-04） | 差分と現行本文を grep で照合した | 規則の写しはおおむね一致する。仮定の意味の変化の記述が欠け（中 1）、型付け規則の表の前提が一つ欠ける（軽 3） |

## 観点ごとの所見

### 定義と写し

- `Release/Typing.lean` に `LocTy.builder`・`StoreTy.Sub`・`StoreTy.hideBuilders`・`LocalCtx`（`List (Option BuilderKind)`）・`LocalRef.HasKind`・`LocalRenOk`・`LocalSubstOk` が加わった。計算・分岐・節・Fail 節の判断に、既定値 `[]` の局所の分類表 Δ が末尾の添字として加わった。`HasTypeCL` は Δ を明記する内部の入口であり、`HasTypeC` は空の Δ のままである（R144）。ストアの型 Ψ と Q は、固定の引数から帰納型の添字へ移した（R143）。これは、規則ごとに Ψ を隠す必要があるための表現上の変更であり、意味は変わらない。
- 加わった型付け規則は `C_BuilderLet`（本体の Γ の先頭に none、Δ の先頭に some kind を積み、同じ型と効果を返す）と `C_BuilderOp`（`LocalRef.HasKind`・通常引数・`op.result kind`・空の効果）の二つである。通常束縛（C_Let・分岐）は `LocalCtx.extend` で Δ を伸ばす。handle の本体とガードは、同じ Ψ と Δ を使う（RV1 の重1 の案A のとおり）。
- 実行規則には `E_BuilderNew`・`E_BuilderOp`・`E_BuilderErr` が加わった。実行の関数 `step` も同じ場合を持ち、`step_sound` の言明は変わらない。`CellOk` には `.builder` の場合（`BuilderCellOk`）が加わり、`.thunk` は隠したストアの型で検査するようになった。`Frame.Closed` の letF は局所深さ 1、`Cell.Closed` は List の要素型と値を検査する。
- `BuilderCellOk` は、種類の一致、`size ≤ limit`、Byte の値域、List の要素の型付けを含む。上限は `maxBuilderBytes = 1073741824`・`maxBuilderListLen = 16777216` であり、`crates/benitoite/src/runtime/mod.rs` の `MAX_STRING_BYTES`・`MAX_LIST_LEN` と一致する。String の尺度は `utf8ByteSize` である。
- 01-12 の写しは、上記の規則・隠す位置の表・専用の実行規則・局所の置換と、表層の E_BuilderOp・B_BuilderBind・E_Block・ArgPlan を記している。07-04 の対応表にも、専用セル・穴とブロック式・交換 13/5・Checked の小証明・Log の例の行がある。欠けている点は中 1・軽 1・軽 3 に記す。

### 主定理の前提・結論と仮定の比較

- `progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`・`desugar_typed`・`surface_effect_soundness`・網羅性の 6 件・公開検査器 11 件・`checkProgram_sound`/`checkProgram_empty` の言明は、`#check @` の出力が文字列で一致した。
- 定義を通じて前提が変わった箇所は次のとおりである。いずれも構築器を含まない項では元と同じ条件になる。
  - `Program.WellFormed`（`Def.Scoped`・`ImplDecl.Scoped`）: `Comp.VarsIn` に局所深さが加わった。定義の本体は引数の数から始まる。この深さが効くのは `builderOp` の `LocalRef.bound` の範囲だけであり、旧来の項には条件が増えない。
  - `StateTy`: 定義の文字列は同じである。`HasTypeC`（空の Δ）・`StoreOk`（`CellOk` の builder と thunk）・`Cont.Closed`（letF の深さ）を通じて意味が変わる。状態の中の計算に自由な `bound` は残らない（`Comp.VarsIn 0 … m` の既定の深さは 0）。
  - `effect_soundness` の `ClosedNoEffVars`: 局所深さ 0 で検査する。
- 0.0.9 の内部の補題 2 件の変化は計画どおりである。`Surface.HasTypeQ.desugar` は、コアの環境を `fillBuilders Γ Δb` から `Γ` と `Δb.toLocal` に替えた（R150）。`Surface.builderOp_desugar_typed` は、前提を `BuilderRefs.Ok` から `Δ.kindAt i = some k` と内容の型の整形式に替え、結論の効果から State を除いた（L4b、R154）。公開の `desugar_typed` は変わっていない。
- `Builtins.Assumptions`: 欄・量化・ファイルは同一である。意味の変化は次項に記す。

### R133: 値の強化・弱化、冪等性・単調性、隠す位置、Assumptions の意味と全モデルの証拠

- 隠す位置は、V_Lam の本体、C_Lazy の本体、通常の節と Fail 節の本体、`CellOk` の thunk、ContTy の K_Handle・K_Handle_Fail が保存する節、の五種類である。これらでは Δ も空になる。handle の本体・ガード・K_Let・保存した継続は元の Ψ を使う。design 3.3 と 01-12 の表に一致する。
- `hideBuilders_idem`（冪等性）・`hideBuilders_sub`（隠したストアの型は元に含まれる）・`hideBuilders_mono`（単調性）・`hideBuilders_strengthen_val/vals/each`（値・値列・各要素の強化）・`hideBuilders_weaken`（隠したストアの型での計算の型付けから元のストアの型へ）を確認した。値の強化は三つの値の判断の相互再帰で書かれている。V_Lam の場合は冪等性で閉じており、計算全体の強化は仮定していない（`Release/Typing.lean` の `hideBuilders_strengthen_val`）。循環はない。
- `Builtins.Assumptions` の意味の変化: `delta_typed`・`io_typed` の入力の `HasTypeVs` と出力の `OutcomeTy`（中の `HasTypeV`）、`io_exists` の入力、`release_exists` の入力に現れるラムダは、本体を隠したストアの型と空の Δ で検査する。ラムダの本体の中で新しく構築器を宣言する導出も、値の判断に入る（L3bc2 の記録のとおり）。どちらか一方へ強める・弱めるだけの変化ではない。ただし、構築器の場所を持たないストアの型 Ψ では判断が元と同じになる。
- モデルの証拠: `Release.Model.assumptions` が唯一の証拠であり、任意の Program について新しい判断で通る（ファイルは整数の定数の表現と `Δ := []` の注釈だけを変えた）。このモデルは Reference.get/set だけを宣言する。`delta := none`、`ioResponse := False` なので delta/io の欄には対象がなく、`releaseResponse` は none を許す。したがって、この意味の変化はどのモデルでも使われていない。開始版でも同じく対象がなかったので、新しい弱点ではない。値の強化を使っているのは `SubstOk.hideBuilders` と `FailureExamples.toResult_typed` の二箇所であり、記録と一致する。
- 設計書には、この意味の変化が書かれていない（中 1）。

### 通常の Reference と局所参照（構築器の専用セル）の隔離

- 通常の型 `Ty` と値 `Val` には、構築器の型も場所も加わっていない。`V_LocRef` は `Ψ l = some (.ref a)` を要求するので、専用セルの場所を値として型付けできない。
- `builder_value_no_free_local`: どのストアの型でも、型の付いた値は自由な `bound` も専用の `loc` も含まない（`Val.LocalRefs 0 (fun _ => False)`）。ラムダの本体まで調べる強い結論である。`dedicated_location_not_captured` は、専用の loc を読むラムダに型が付かないことを示す反例、`dedicated_inside_lambda` は、ラムダの中で新しく宣言することは許すことを示す例である。
- `builder_step_frame`: 専用項の一歩（new・成功・失敗）は、`OrdinaryStoreEq`（Reference の `.val` セルだけを比べる）を保つ。`builder_step_no_event`: 専用項の一歩は事象を伴わない。どちらも `Comp.IsBuilder` で専用項に限っており、任意の一歩へは適用しない（design 12.2 のとおり）。
- `local_steps_invariant`: 型の付いた状態からの任意の有限接頭辞で、`StateTy` と `LocalStateInvariant` が成り立つ。後者は、現在の項・枠・保存した継続・遅延のセルが使う専用の場所がすべて実在する構築器のセルを指すことと、型の付いた通常値が自由な専用参照を持たないことを述べる。結論は `StateTy` からの導出（`StateTy.local_invariant`）と `preservation` の繰り返しで得ており、言明どおりの中身である。前提は具体例 `dedicatedProgram_prefixes` で満たされる（実在のモデルと構築器を使うプログラム）。

### 通常の State と release（リソースの解放）の維持

- `C_Use` は今も効果に State を要求する。Reference の組み込みの関数の型（`PrimSig.StoreShape`）は State の効果を持ったままである。K_Drop・K_Release・`releases` の定義は変わっていない。表層の E_BuilderOp と B_BuilderBind からだけ State が除かれた。L4b の例は、通常の Reference.get を追記の通常引数に使うと State が残る対照を持つ。
- `builder_frames_releases_nil` は、release と drop の枠を含まない枠の列の `releases` が空であることを示す。`drop_local_silent` は、`releases saved = []` のとき、E_DropRel の後の状態が `.run (.ret v) k (σ.set κ .used)` であり事象がないことを示す（R136 のとおり）。escape・error・exit の版もある。

### 公開の健全性 11 件と program 全体

言明は開始版と同一である。公開の入口は空の Δ（`HasType := HasTypeQ … []`）から始まり、内部の帰納で `builderBind` の Δ を扱う。構築器・block を受理する検査の例があるので、拒否だけで健全性を自明にしているのではない（`Surface/BuilderExamples.lean` の `pure_program_checked`・`checkedBlock blockAppend = .ok …` など、`Surface/CheckExamples.lean` の 865 行以降の block の例）。

### TODO-191（有界の Integer と網羅性）

- `Integer64Value` は範囲の証明付きの部分型である。型付けの規則には範囲の前提を加えていない。交換の読者がすべての版で範囲を検査する（R156 は、比較専用の期待コアと未使用の定数まで検査する）。
- `integer_partition_unique`・`integer_covered_iff`・`integer_atoms_partition`・`integer_full_no_other`・`integer_shapes_complete` の言明は、各値が最小区間か other のちょうど一つに属すること、全域の被覆と other が要らないこととの同値、列挙の完全性を述べる。退化はない。
- 依頼の観点にある「論理上限を超えたら R0902 相当の一歩」は、構築器（248）の規則である。`builderCheckUpdate_overflow` と `overflow_atomic` は、任意の大きさの候補について、上限を超えたら元のストアのまま `.error [rValueTooLarge]` へ進むことを示す。`length` は `lengthValue` で、上限から切り詰めのない有界の整数を作る。

### block（return の境界を作らない一般のブロック式）

`E_Block` は、同じ Δ・C・Γ・R・p の `HasBlockQ` から同じ型と効果を返す。脱糖は `desugarBlock` そのものであり、専用のコア・mark・効果の除去はない。`Expr.Exits` に `.block body => body.Exits` がある。性質 1・範囲・clean・捕捉の各帰納に E_Block の場合がある（`Surface/Lemmas/Typing.lean:547`、`Scoped.lean:149`、`Invariants.lean:366`、`BuilderNoCapture.lean:40`）。design の補題名 `block_desugar_typed` は使わず、相互帰納の一つの場合として証明している。交換では corpus 13 だけで受理する。

### TODO-192（プレースホルダの穴の余分な Let の除去）

`ArgPlan`（`direct`／`evaluate`）、`argEvals`、`argValues`、`sequenceArgs`、`callArgs` へ替えた。固定式だけを Let にし、callee を先に一度だけ評価する。旧来の独立した期待コア 3 件は、穴の Let だけを除いた厳密なコアへ変わった（正規化して差を隠してはいない）。型の保存は `sequenceArgs_typed` と `ArgTypesQ` から部分適用の場合へつながる。design の補題名 `hole_args_plan_typed/scoped` は使っていない。

### 内外の判定と未接続の箇所

248・191・192・block は内側、022 は独立した小証明、Log は既存の規則の適用例として 07-04 に書かれている。Rust との全交換比較は未実施であることも、07-04 と L7 の記録に明記されている。一方、design 12.8 が「外側」とした 206 の位置の事前展開・既定出力・CLI、200 の判定の木の共有・行ごとの照合・自由変数・ir/check、物理バッファ・GC・容量・取り消し・Writer の中断、derive・保管・橋渡し・Engine の共有・診断の対象外の行は、07-04 にまだない。plan はどの作業にも割り当てていない（軽 1）。

### 交換 13/5 と旧版 12 の拒否

`sidecarVersion` は 13→5・11/12→4・9/10→3・8→2 である。corpus 12 の構築器は「regenerate with version 13」で拒否し、新版に旧来の refs・newRef・getRef・setRef が混じれば拒否する。block は版 13 だけで受理する。batch3 は旧版の構築器 19 定義を拒否として確かめ、構築器を含まない 11 定義の意味を保つ。batch4 は 45 定義・網羅性 6/3 件を六つの入口へ渡し、版の境界と組み合わせを確かめる。76 テストがすべて通ることを再現した。

### 022 の検査済みの値（Checked/）と Log の例

`Checked/ListLength`・`ListIndex`・`NonEmptyList` は design 12.7 の言明（成功・失敗の同値、端点の不正の優先、射影、添字の要素の一致、head/tail、map）を持つ。主定理や Assumptions とはつながっていない。`Surface/LogExamples.lean` は、公開の checker で両操作・完全なハンドラ・送り直し・不完全なハンドラでの Log の残り・Console.Write の残りを確かめ、checkProgram の成功も示す。新しい規則・公理はない。

### 作業時間が短かったことについて

作業が見込みより短く終わった点を踏まえ、言明が言明どおりのものを示しているかを重点に見た。主定理と公開の言明は文字列が同一であり、Lean のカーネルが全帰納の網羅性を確かめている。新しい型付け規則には、受理する具体例と、主定理へつなぐ具体例がある（`dedicatedProgram_typed`・`dedicatedProgram_prefixes`・`resumedProgram_run`）。したがって、新しい規則が素通り（どの項にも型が付かない、空の Δ に固定される）になってはいない。局所の補題の多くは言明どおりの中身を持つ。中身の薄い補題は軽 2 に挙げた二つだけである。

## 指摘

### 重

なし。

### 中

**中1: `Builtins.Assumptions` の意味の変化が設計書に書かれていない**

- 箇所: `docs/design/07-quality/07-04-formal-semantics.md` の「形式化で仮定するもの」（86 行以降の表）。`docs/design/01-spec/01-12-core-calculus.md` の 1188 行（隠す位置の表）・1225 行・1247 行（「Builtins.Assumptions の欄・量化を変えない」）。
- 問題: R133 と design 12.2 は、V_Lam が隠したストアの型で本体を検査するため、`delta_typed`・`io_typed`・`io_exists`・`release_exists` の入力と出力のラムダの意味が変わると決めている。plan も RV2 でこの比較を求めている。しかし設計書は「欄・量化を変えない」とだけ書いている。読み手は仮定が以前と同じ意味だと受け取る。唯一のモデル `Release.Model` では delta/io の欄に対象がなく、この変化がどのモデルでも使われていないことも書かれていない。仮定の意味は、設計書が正確に書くべき保証の範囲に当たる（AGENTS.md の「保証の範囲」）。
- 修正案: 07-04「形式化で仮定するもの」の表の下に、次の内容の段落を加える。「δ と IO の応答の入力・出力と解放の入力に現れるラムダは、本体を構築器の場所を隠したストアの型と空の局所環境で検査する。欄と量化は変えていない。構築器の場所を持たないストアの型では、以前と同じ判断になる。証拠の `Release.Model` は delta/io の対象を持たず、解放の応答に none を許すので、この変化を使わない」。01-12 の 1225 行・1247 行の「欄・量化を変えない」の後にも、意味の変化と 07-04 への参照を一文加える。
- 後続作業: Lean の直しは要らない。T1 の前に、レビューの反映（P3 などの別 ID）で文書だけを直す。Rust の作業への申し送りは要らない。

### 軽

**軽1: design 12.8 が外側とした項目の対象外の行が 07-04 になく、担当の作業もない**

- 箇所: `docs/design/07-quality/07-04-formal-semantics.md` の「01-12 との対応」の表。plan.md の「Leanを先に完了する範囲と区切り」（43 行）。
- 問題: plan は「位置の事前展開、DAGと行ごとの照合、物理GC、生成道具等は対象外の理由を07-04へ反映する」と書くが、L1〜L7 も Rust の作業もこれを受け持っていない。設計書は実装した内容だけを書く規約なので、Rust の実装の前に行を足さないこと自体は正しい。担当がないまま改造が終わる恐れがある。
- 修正案: 各 Rust の作業の完了条件に、07-04 の対象外の行を足すことを加える。206 の位置の事前展開・既定出力・CLI は G1/G2、200 の判定の木の共有・行ごとの照合・自由変数・ir/check は T3/T4、物理バッファ・GC・容量・取り消し・Writer の中断は B1/B2/G7、derive・保管・橋渡し・Engine の共有・診断は G4/G5/G6/H1/H2/T5 とする。V1 で表の全行を照合する。
- 後続作業: Rust の作業 T/B/H/G と V1 への申し送りで足りる。

**軽2: `snapshot_structure_stable` と、`capture_local_valid`・`resume_local_valid` の第三の結論は、定義からただちに出る**

- 箇所: `formal/Benitoite/Release/BuilderExec.lean` の `snapshot_structure_stable`。`formal/Benitoite/Release/Lemmas/LocalInvariant.lean` の `capture_local_valid`・`resume_local_valid`。
- 問題: `snapshot_structure_stable` の結論は `v = c.snapshot ∧ builderApply .copy updated [] = …` であり、どちらも `rfl` で閉じる。抽象モデルでは値が不変なので、copy の後の追記が取り出した値を変えないことは自明である。二つの `*_local_valid` の第三の結論（既存の専用セルが同じ場所に残る）は、前提の一歩の後のストアを `σ.set κ …` と固定しているので、`Store.set` の性質だけで出る。主な中身は `preservation` と `StateTy.local_invariant` にある。どちらも言明として誤りではない。ただし、これを「copy の後の不変」や「継続と専用セルの対応」の独立した証拠として引くと、保証を大きく見せてしまう。
- 修正案: Lean は直さない。01-12 か 07-04 で、`snapshot_structure_stable` を、抽象モデルで値が不変であることの確認と位置付け、物理表現の共有と書き換えの検査を実装の検査に委ねると書く。
- 後続作業: B2・H1 への申し送り。copy の後の追記が、取り出した String・Bytes・List の物理表現（共有したバッファ）を変えないことを、Rust のヒープの検査と独立した期待値で確かめる。

**軽3: 01-12 の型付け規則の表で、C_BuilderLet・C_BuilderOp の内容の型の整形式の前提が欠けている**

- 箇所: `docs/design/01-spec/01-12-core-calculus.md` の 1181〜1182 行。
- 問題: Lean の `C_BuilderLet`・`C_BuilderOp` は `Ty.WF C.length kind.contents` を前提に持つ。07-04 の対応表（245 行）は「種類の整形式」と書くが、01-12 の写しの表にはない。形式化した規則の写しとして不完全である。
- 修正案: 両行に「kind.contents が C の下で整形式」を加える。
- 後続作業: 中1 と同じレビューの反映で、文書だけを直す。

**軽4: `BuilderInvalidByte` は Lean の抽象化のためだけの失敗である**

- 箇所: `formal/Benitoite/Release/BuilderExec.lean` の `rBuilderInvalidByte` と `builderCheckUpdate`。decisions の R147。01-12 の 1233 行。
- 問題: Lean の Byte は Nat を持ち、256 以上も型が付く。そのため専用の追記で内部の失敗にしている。Rust の Byte は u8 なので、この失敗は起きない。設計書にも「言語の新しい診断ではない」とある。ただし、B2 の交換や参照インタプリタ、診断の表でこの名前を報告として扱うと、存在しない失敗を作り込むことになる。順序（長さの上限を先に検査する）も Lean 固有である。
- 修正案: Lean と文書は直さない。B2 の依頼に、`BuilderInvalidByte` を Rust の診断・停止・交換の期待値へ加えないこと、Rust の上限超過の判定は R0902 だけであることを明記する。
- 後続作業: B1/B2 への申し送りで足りる。

## 付記（指摘としない観察）

- design 12.5 と 12.6 が案として挙げた補題名（`hole_args_plan_typed/scoped`・`block_desugar_typed`）は、そのままの名前では存在しない。前者は `sequenceArgs_typed`・`ArgTypesQ` と既存の部分適用の帰納、後者は相互帰納の E_Block の場合が受け持つ。design は名前を案と明記しているので、問題にしない。
- `hideBuilders_weaken` の公開の形は空の Δ に限る。一般の Δ の弱化は内部の `HasTypeCQ.store` が受け持つ。
- R145 の `instLocalSubst` は、通常束縛を除く位置の像として `.loc 0` を置く。分類表では利用不能な位置なので、型の付いた項には現れない。`LocalStateInvariant` も型付けから導くので、この像が実在しないセルを指すことはない。
- 開始版でも現在版でも、`lake build` は警告なしで通る。README の公理確認の一覧は 40 件から 269 件に増えており、L 作業の記録の件数（L7 の 269 件）と一致する。
- 比較に使った入力と出力は一時領域の `ax-base.lean`・`ax-new.lean`・`ax-base.out`・`ax-new.out`・`chk.lean`・`chk-base.out`・`chk-new.out`・`build-base.log`・`build-new.log` にある（/private/tmp/claude-501/-Users-tecogonaz-src-Benitoite/6253d5a4-70d2-428f-a9e7-3fd241935306/scratchpad/ の下。消えることがある）。
