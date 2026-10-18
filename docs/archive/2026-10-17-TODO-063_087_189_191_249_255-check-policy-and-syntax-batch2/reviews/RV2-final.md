# RV2 段2の閉鎖の確認

## 判定

**軽い直しの後に閉じてよい（直しを段3の最初に含めればよい）。**

主な定理の言明の文字列は、開始版から一つも変わっていない。結論が弱まった箇所も見つからなかった。公理も増えていない。`Builtins.Assumptions` に加わったのは、了承済みの R57 の `sat_unconstrained` だけである。期待を変えた既存の例 7 件は、どれも合意済みの意味（案 B、正規形、R15 の一時的な拒否の撤去）に沿っており、期待を緩めて通したものではない。

ただし、定義を通じて主な定理の前提の意味が変わった箇所のうち、一つは了承済みの一覧（R14、R21、R24、R51、R57）の外にある。性質 1 と表層のエフェクトの健全性の前提 `p.WellFormed` に、`OpDecl.DictionaryScoped` が加わったことである（重1）。旧来のプログラムは自動で満たし、TODO-189 の機能に欠かせない条件なので、作り直しは要らない見込みである。それでも、これは**設計者の了承が要る**変更である。段3の最初（O1 の前）に R の番号で了承を記録すること。設計者が了承しない場合は、判定を「先に直すべき点あり」に改める。残りの指摘は、文書の追記、検査の記録、計画の具体化で済む。

## 対象と読んだもの

基準は開始版 `e0530ec1`、対象は HEAD `595cb003`（san_benito）である。読んだものは次のとおり。

- 差分: `git diff e0530ec1..595cb003` の `formal/`、01-12、07-04。主に次のファイルを照合した。
  - Release: `Theorems.lean`（差分なし）、`Typing.lean`、`Semantics.lean`、`WellFormed.lean`、`Assumptions.lean`、`Model.lean`、`NoFail.lean`、`Coverage.lean`
  - Surface: `Theorems.lean`（差分なし）、`WellFormed.lean`、`Typing.lean`（呼び出しの規則）、`CheckSound.lean`、`CheckLemmas.lean`（`Input.Sound`）、`CheckTables.lean`、`CheckProgramSound.lean`、`Lemmas/Program.lean`、`CheckToolsExamples.lean`、`CheckExamples.lean`、`SubstExamples.lean`
- 記録: `decisions.md` の R14〜R70（R14〜R30、R36、R37、R39〜R41、R44、R46〜R70 は本文まで）、`reviews/RV2-initial.md`、`reviews/RV2-L2a.md`、`l1b/results.md`（L1bc7）、`l1c/results.md`、`l4b/axioms.lean`・`axioms-final.log`、`l4bc3/results.md`、`plan.md` の O1〜P1、L4bc2・L4bc3 の差分（`Check.lean`、`check_named.py`、二つの manifest）

追跡するファイルは変えていない。公理の依存を HEAD で確かめるために、`formal/` で `lake build --no-build`（終了0。成果物は最新）と `lake env lean`（`l4b/axioms.lean` の写しを使用。終了0）だけを実行した。

## 観点1 主な定理の言明

### 言明の文字列

`Release/Theorems.lean` と `Surface/Theorems.lean` には差分がない。`Surface/CheckSound.lean` の健全性 11 件と `checkProgram_sound` も、前提と結論の文字列は同じである。変わったのは証明だけだ。網羅性の主な定理（`usefulFuel_none_sound`、`usefulFuelWithView_none_sound` など）の言明も変わっていない。検査器には `checkExpr_single`・`checkBlock_single` が加わったが、どちらも既存の定理に足しただけである。

### 定義を通じた前提の意味の変化

開始版と比べて前提の意味が変わった箇所を、すべて挙げる。

| 箇所 | 影響する定理 | 根拠 | 評価 |
|---|---|---|---|
| `Ty.WF`・`LocTy.WF`・`Eff.WF` に、Fail の内部まで辿ることと、埋め込んだ効果の Canonical を加えた | 進行・保存・エフェクトの健全性（`WellTyped`・`StateTy`） | R14 | 了承済み |
| `V_Lam`・`V_Sub`・`C_Sub` に結果の型の WF を加え、`C_Eff` を新設した | 同上 | R21・R22 | 了承済み。`C_Eff` は旧 `C_Sub` の特例なので、範囲は広がらない |
| `HasTypeClausesQ.cons` に `Eff.WF C.length ε` を、`K_Let` に `Ty.WF 0 a` を加えた | 同上 | R28・R29 | R21 の「整形式の型だけを型付けの対象にする」の範囲内 |
| `V_Fun`・`V_Prim`・`C_Meth` に `Admissible` 等を加えた（型の像の WF と継続型の禁止、`sourceRows`、`sourceQ`、`RowTransport`） | 同上、性質1 | R47、RV2-L2a 軽4 | RV2-L2a で「設計の範囲内で相談不要」と判定済み（下の軽1） |
| `Def.WellTyped`・`ImplDecl.WellTyped` が署名由来の Q で検査し、実装の効果に `substAt` を施すようにした | 同上 | R7・R30・R46・R53 | Q は NoFail の前提でしか読まないので、旧来のプログラムは影響を受けない |
| `Scoped` を `Eff.VarsIn` で Fail の内部まで辿るようにした | 進行（`WellFormed`）、性質1 の `hsig` | R14・R26 | 了承済み |
| `BuiltinOnly` に `ε.fails = []` を加えた | 進行・保存（`StateTy`） | R51 | 了承済み |
| `Builtins.Assumptions` に `sat_unconstrained` を加えた | 進行・保存・エフェクトの健全性・`step_sound`・表層のエフェクトの健全性 | R57 | 了承済み |
| 表層の `Program.WellFormed` に `od.DictionaryScoped` を加えた | 性質1・表層のエフェクトの健全性 | R62 | **了承済みの一覧の外**（重1） |
| 表層の `Expr.Scoped` で、ラムダと部分適用の潜在効果に Canonical を求めるようにした | 性質1 | R14・R36 | R14 の「Ty.VarsIn に Canonical を加える」の範囲内 |
| 表層の型付けに `SingleTy`・`SingleEff`・`Admissible`・移動先の VarsIn を加えた | 性質1 | R7・R36・R52・R60 | 設計者の決定（R7）の具体化 |
| 検査器の `AtomsIn` を、Fail の内部まで辿る `Support` に替えた | 健全性 11 件（`Input.Sound` と各前提） | R40 | Fail を持たない入力では意味が変わらない。`Input.Sound` の欄は増えていない |

### 結論

- `effect_soundness` の結論 `¬ UnhandledOp s` は、未捕捉の `raise` も含むように広がった（`Semantics.lean` の `UnhandledOp`）。結論が強まる変更である。
- 進行の `Final` は変わっていない。
- 性質1 の結論の `WellTyped` は、規則を強めた後の Release についての主張になった。これも結論を強める。
- 検査器の健全性の結論 `HasType` は、`SingleTy` などの前提が増えた表層の型付けについての主張になった。これも結論を強める。

結論が弱まった定理は見つからなかった。

## 観点2 仮定

- `Release/Assumptions.lean` の差分は `sat_unconstrained : ∀ t, Ty.WF 0 t → B.sat [] t ({} : TParam)` の 1 欄だけである。`Model.lean` は `sat := fun _ _ _ => True` に対して `sat_unconstrained := fun _ _ => trivial` で満たしている。`TParam` の既定値 `{}` は `equality = key = false` である。実際の組み込みの表の `satB`（`BuiltinTable.lean` 124 行目）も、この TParam に対しては常に `true` を返す。意味の上で矛盾はない。
- `Input.Sound` の 6 欄は変わっていない（`CheckLemmas.lean` 9 行目）。`withNoFailRows` は既存の 6 欄をそのまま渡している。`Materials.input` は `noFailRows := []` で初期化する。検査器の外部の仮定に、条件は加わっていない。
- formal/ のソースに `axiom`・`sorry`・`admit`・`opaque` の宣言はない。新しく加わった `partial def` は Exchange の読み書きだけにあり、定理の証明は依存していない。ただし、`native_decide` が 3 箇所に新しく入った（軽2）。
- 公理の依存: `l4b/axioms-final.log` は L4bc2 で `Check.lean` を変える前の記録である。そこで HEAD で同じ 30 件を確かめ直した。Release・Surface の 25 件は `[propext, Classical.choice, Quot.sound]`、Core の 5 件は `[propext, Quot.sound]` であり、記録と一致した。

## 観点3 期待を変えた例と L4bc2・L4bc3

- L1b（L1bc7）の 1 件: `Release/SubstExamples.lean` の、任意の効果 `e` を持つ shift の例である。期待を `Eff.shift 2 1 e` に変えた。表現 B では効果の中の Fail 型も移動するので、この期待が正しい。旧表現に当たる `Eff.ofAtoms` の例も rfl で残している（R39）。期待を緩めたものではない。
- L1c（L1cc2）の 6 件:
  - 2 件は `CheckToolsExamples.lean` の `singleEff` と `unionEff` である。支持の外の原子の結果を `false` から `true` に変えた。以前の計算は、有限の原子の一覧の外を黙って切り捨てていた。R40 はこの切り捨てをやめたので、変更後のほうが厳しく、Release の効果と一致する。
  - 4 件は、R15 の一時的な Legacy の拒否を期待していた例である。拒否を期待する形から、完全な ok 値を期待する形に変えた（`l1c/results.md` 73 行目）。R15 が「段2の最終の保証に残さない」と定めた拒否を外したものであり、`isOk` だけで判定する形には緩めていない。
- R67（L4bc2）: strict では、通常節の内側と外側の包含をこれまでどおり両方検査する（`Check.lean` 741〜750 行目）。relaxed の探索中だけ、外側の包含の検査を確定後へ回した。健全性の証明が使う strict の経路は変わらない。正例と負例（純粋な注釈への拒否）も加えてある。妥当である。
- R68: `testdata/fmt/header.bnt` は `language "0.0.6"` を宣言している。現行の `diag::codes` の E0908 は、0.0.7 の互換性の変更を報告する。したがって、二つの manifest に E0908 を加えるのは、既存の診断に記録を合わせる変更であり、期待を緩めるものではない。
- R70: `check_named.py` の全件の独立網羅性の検査は、`require` と期待値をそのまま保って `main` の末尾へ移しただけである。終了1も成功に書き換えていない。妥当である。887 件と 886 件の不一致がすべて character を含むことは、道具で機械的に確かめてある。R66 の受け入れ条件を満たす。

## 観点4 01-12・07-04 の写し（抜き取り）

次を照合し、Lean と一致していることを確かめた。

- 01-12 の「形式化した型付き失敗の捕捉」（956〜976 行目）: `V_Raise`、`HasFailureClause.one`（型文脈・値環境・移動）、`C_Handle_Fail`、`K_Handle_Fail`、`E_OpFail`（T だけの代入、型の比較をしないこと）、`cap = norm (Rest ∪ ec)`
- 01-12 113 行目: V-Fun・V-Prim・C-Meth の Admissible と、型の像が継続型でないこと
- 01-12 1155 行目: `Eb.fails = []`
- 07-04 の仮定の表: 「空制約の成立」の行（104 行目）と、`BuiltinOnly` の注記
- 07-04 228 行目: RV2 初回の軽4 の「01-05 より広い」という記述は、文字の全値域の説明に改められている

食い違いは、次の一点だけである。

### 軽3 07-04 の「外側の前提と結論は保つ」が、DictionaryScoped と食い違う

- 箇所: 07-04「01-12 との対応」の 18 行目付近（差分の追加段落「Releaseの七判断と表層の七判断は…外側の前提と結論は保つ」）と、R63 の「既存の主な定理・健全性11件の外側の言明…は変えない」。
- 問題: 言明の文字列は同じだが、性質1 の前提 `p.WellFormed` の意味は重1 のとおり変わっている。07-04 の対応表の行（「操作の制約と節の辞書」）は DictionaryScoped が何を検査するかを書いているが、それが性質1 の前提の一部になったことは書いていない。
- 修正案: 重1 の了承を記録するときに、07-04 の性質1 の前提の説明に「表層の整形式は操作宣言の `DictionaryScoped` を含む（辞書を持たない宣言は自動で満たす）」の一文を加える。R63 にも、前提の意味の変化を R の番号で参照する一文を加える。

## 観点5 段3以降へ渡すときの不足

### 重1 性質1 の前提に DictionaryScoped が加わった点の了承（設計者の了承が要る）

- 箇所: `formal/Benitoite/Surface/WellFormed.lean` の `Program.WellFormed`（`(∀ o od, p.ops o = some od → od.Scoped ∧ od.DictionaryScoped)`）と、同ファイルの `OpDecl.DictionaryScoped`。影響するのは `Surface/Theorems.lean` の `desugar_typed` と `surface_effect_soundness` である。
- 問題: 主な定理（性質1）の前提を強める変更だが、R14・R21・R24・R51・R57 のどれにも当たらない。R62 は実装担当の「推す案」であり、設計者の了承の記録がない。
  - 旧来の宣言は `dictParams = []` なので、`d.params = [] ++ d.params.drop 0` が成り立ち、自動で満たす。適用できる範囲は旧来のプログラムについては狭まらない。辞書を持つ操作の宣言を扱うには欠かせない条件でもある。
  - それでも、依頼文の停止条件「主な定理の前提の変更」に当たる。
- 修正案: 段3の最初（O1 の前）に、設計者の了承を R71 などの番号で decisions.md に記録する。あわせて軽3 の文書を直す。了承が得られない場合は、`desugar_typed` の中で、辞書の前置を表層の型付けから導く形への作り直しを検討する（この場合は段2を閉じない）。

### 中1 F1 の計画に、単一 Fail を検査する位置の一覧がない

- 箇所: `plan.md`「作業F1」の手順（「具体化後の単一Failも呼び出し・値化・合流で直接検査し」）。照合の相手は 01-12 984〜986 行目と `Surface/Typing.lean` の規則である。
- 問題: Lean の表層は、`SingleTy`・`SingleEff` を次の位置で要求する。
  - 関数・辞書付き関数・メソッド・組み込みの値化
  - 呼び出しとパイプ
  - 部分適用（構築する関数型）
  - `if`・`else if`（結果型と合流後の効果）
  - 検査器の期待型の受け入れ、型の結び、許容効果への包含

  F1 の計画が挙げるのは、このうち初めの二つと「合流」だけである。部分適用、if の結果型、受け入れと結びの移動先が抜けると、Rust が Lean より多く受理する。その差が見つかるのは、F3・P1 の交換の比較に該当する入力がある場合に限られる。
- 修正案: F1 の手順に「01-12『型付きの失敗の表層検査』の各位置（上の5種）で検査する」と書き、各位置の負例を golden に置くことを完了の条件に加える。

### 軽1 Admissible 等の前提の追加を、閉鎖の記録に残す

- 箇所: `Release/Typing.lean` の `Admissible`・`PrimitiveAdmissible`・`MethodRowsAdmissible`。RV2-L2a 軽4。
- 問題: 型引数の WF と継続型の禁止、`sourceRows`・`sourceQ` は、進行・保存の前提 `WellTyped`・`StateTy` の意味を変える。RV2-L2a は設計の範囲内と判定し、私も同じ判断である。WF は R21、行の条件は R7 の具体化であり、`Def.Scoped` と `Val.VarsIn` からいつも導ける。ただ、decisions.md には、主な定理の前提の意味が変わったことを明示した記録がない。
- 修正案: 重1 の了承の記録に、「R47 の Admissible による前提の意味の変化（RV2-L2a 軽4 で範囲内と判定）」を一行添える。コードの変更は要らない。

### 軽2 例に native_decide を新しく使っている

- 箇所:
  - `formal/Benitoite/Surface/CheckExamples.lean` 803 行目（L2bc2 で導入）
  - `formal/Benitoite/Surface/NoFailCheckExamples.lean` 23 行目・35 行目（L2b で導入）
- 問題: 開始版の formal/ には `native_decide` が 0 件だった。`native_decide` を使うと、その命題はコンパイラを信頼する `Lean.ofReduceBool` に依存する。主な定理の依存は変わらない（観点2 で確かめた）が、既定のビルドに入る例の保証が、カーネルの検査より弱くなる。`check.sh` の sorry の拒否も、これを検出しない。
- 修正案: `decide` か `rfl`、または例を分けた `by decide` に置き換える。カーネルでの評価が遅すぎて置き換えられない場合は、07-04 の検査の説明に、`native_decide` を使う例とその理由を書く。あわせて、`native_decide` を数える検査を `formal_build` に加えることも検討する。

### 軽4 P1 の計画に、文字の反例の表示の規則を書く

- 箇所: `plan.md`「作業P1」の手順。R64、`Release/CoverageShow.lean`。
- 問題: P1 の計画が挙げるのは「`_` から最小の有効な文字（例: `'\u{0}'`）へ」の一例だけである。R64 の表示の規則は書かれていない。規則とは、ASCII の可視文字はリテラル、改行・復帰・タブ・逆斜線・単一引用符はエスケープ、それ以外は桁を埋めない小文字の十六進の Unicode エスケープとする、というものである。網羅性の不一致を 0 件にする条件があるので、規則の差は最終的に検出される。ただ、P1 の途中で表示の差と判定の差を見分ける手間が増える。
- 修正案: P1 の手順に「反例の表示は R64 と `CoverageShow` の規則に合わせる」と、`boundary/surrogate`（全域の後の分岐は選ばれないこと）の対照を明記する。

### 軽5 段3の作業中に check-formal.sh 全体を実行したときの扱い

- 箇所: `plan.md` の O2・F3（「局所比較」）、R66・R70。
- 問題: P1 までは、`scripts/check-formal.sh` 全体が character の既知差で終了1になる。O2・F3 で全体を実行した場合の受け入れ方（R66 の道具 `l4bc3/check_character_mismatches.py` を同じ条件で使うこと）が、O2・F3 の節に書かれていない。
- 修正案: 「検査の割り当て」の O2・F3 に、全体を実行する場合は R66 の条件と道具で分類し、character を含まない不一致が一件でもあれば止める、と書く。全体を実行しないなら、その旨を書く。

### 軽6 R57 を実際の組み込みの表に結び付ける

- 箇所: `Release/Model.lean` の `sat_unconstrained`、`Release/BuiltinTable.lean` の `satB`。
- 問題: Model の `sat` はいつも真なので、`sat_unconstrained` がほかの欄と両立することを示す証拠としては弱い。鍵の制約を区別するモデルでは確かめていない。
- 修正案: 任意の改善として、`satB S [] t {} = true` を `BuiltinTable.lean` に一行の定理として置き、実際の表で R57 が成り立つことを示す。閉鎖の条件にはしない。

### Lean の側の不足の確認結果（問題なしとした点）

- Fail の選択: `E_OpFail` は型を比べずに最も内側の Fail の枠を選び、T だけを代入する。F1 の止まる条件「動的な型の選択が必要」と整合する。
- 通常の handle での Fail の節: `opSig .fail = none` により、通常の handle には Fail の節が型付かない。Rust の E0518 と整合する。
- 辞書の順序: `instantiate ((辞書 ++ 値) ++ [κ])` と `DictEv.clause` の番号付けは、O1・O2 の交換 11/4 の比較で照合できる。
- Q の計算: Q は署名の字面からだけ計算する（`Qsig`、`signatureQ`）。交換の `effParams.noFail` で照合する（R65）。
- lazy: `C_Lazy` が空の効果を要求するので、Fail は lazy を越えられない。子タスクは 01-12 の形式化の対象外である（01-11）。F2 の子タスクの扱いは、テストと RV3 の確認に頼ることになる。この点は計画の RV3 の観点に含まれている。
- P1: 網羅性の不一致 0 件と、character の既知差を残さないことが、完了の条件に入っている（`plan.md`「作業P1」）。
