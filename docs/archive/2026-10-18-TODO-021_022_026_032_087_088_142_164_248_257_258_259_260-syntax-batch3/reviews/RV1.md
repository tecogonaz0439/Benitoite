# RV1 段1の前の独立レビュー

対象は、ブランチ `mod009/design` の HEAD `5e134f45`（P1の反映と R109・R112 の回答の記録を含む）である。読んだ文書は decisions.md（B7・R108・R113・R116〜R125）、design.md の 7 と 14、plan.md の L1〜L7・検査表・レビュー表、reviews/preflight.md、p1/results.md、07-04「01-12 との対応」である。照合した formal/ の定義は、`Surface/{Syntax,Typing,Desugar,WellFormed,Check,CheckSound}.lean`、`Surface/Lemmas/{Typing,Invariants,Scoped,SubstClean,ShiftClean}.lean`、`Release/{Typing,Assumptions}.lean`、`Release/Lemmas/Rename.lean`、`Exchange/Version.lean`、`SurfaceCheck/Walk.lean`、`lakefile.toml`、`formal/README.md` と、formal/tests の版の検査である。リポジトリは変えていない。

開始時の状態として、formal/ の既定の `lake build` は成功した（250 ジョブ、キャッシュ済み）。`#print axioms` で `Surface.desugar_typed`・`Surface.surface_effect_soundness`・`Surface.Check.checkExpr_sound`・`Surface.Check.checkImpl_sound`・`Release.effect_soundness` を確かめ、どれも `propext`・`Classical.choice`・`Quot.sound` だけに依存することを確認した。

## 結論

**先に直すべき点あり。** 重い指摘は 1 件である。部分適用（`partialCall`・`partialCon`）は、Lean の脱糖でも型付けでもラムダと同じ境界である。それなのに、design・R123・plan は、これに外側の Δ をそのまま渡している。このままでは、外側の構築器のセルを捕える関数値を受理してしまい、設計者の決定 B7 の A と食い違う。型の保存の証明はこの食い違いを検出しない。直し方は、境界の一覧に二つの規則を足し、負例と言明を合わせることで、文書の修正だけで済む。L1〜L3 の内容には影響しないが、plan の「指摘を反映してから L1」に従い、先に直すことを勧める。

ほかの点は、Γ/Δ の整列・fillBuilders・既存の rename による移行という骨格を含め、今の formal/ の定義と接続できる見込みである。公開の主定理の前提・結論、公理、Builtins.Assumptions を変えずに済むと判断した。中の指摘は 6 件、軽の指摘は 7 件である。「設計者に確認」を要する指摘はない。

## 重

### 重1 部分適用は捕捉の境界なのに、同じ Δ を渡している

- 箇所: design.md 7.2 の表（「lambda・lazy・節（handleFailの節を含む）| 空のΔ」「それ以外の部分式 | 同じΔ」）、14.5 の規則の表（「捕捉の境界」「それ以外の部分式」）、decisions.md R123（「捕捉の境界はlambda・lazy・節（handleFail含む）だけとし」）、plan.md L4 の手順（「lambda/lazy/節（handleFailを含む）は空Δ、その他の部分式は同Δ」）、14.5 の `builders_no_capture`。
- 問題: 部分適用の固定引数と呼び出し先の式は、作った関数値を呼ぶたびに評価される。このため、そこに専用操作を書くと、外側のセルを捕える閉包ができる。たとえば `return g(StringBuilder.copy(b), _)` や、タスクを起動する関数に `f(StringBuilder.byteLength(b), _)` を渡す形である。今の案では、`E_PartialCall` と `E_PartialCon` が同じ Δ を受け取るので、これらを受理する。design 7.2 の E0466 は専用操作そのものの値化・穴しか拒否しないので、この形を拒否できない。これは、決定 B7 の A（「外側の局所名のlambda・lazy・タスクへの捕捉と、穴・パイプ・関数値経由の使用を拒否する」）に反する。一方、脱糖後のセルは普通の Reference なので、`desugar_typed` も `builderOp_desugar_typed` も成り立つ。証明が通っても、この欠落は見つからない。`builders_no_capture` も「lambda/lazy/節」についてしか述べないので、真のまま欠落を見逃す。
- 根拠: `Surface/Desugar.lean` の `.partialCall` と `.partialCon` は `.ret (.lam …)` を作る。コメントにも「非穴の式と callee はラムダの本体で評価する」とある。`Surface/Typing.lean` の `E_PartialCall` は、`f` と `HasHoleArgsQ` を `hideConts Γ` と `some r` で検査する。`E_PartialCon` も `hideConts Γ` で検査する。これは `E_Lam`・`E_Lazy` と同じ扱いである（コメントは「展開したラムダの本体として検査する」）。`Surface/Lemmas/Typing.lean` の `HasTypeQ.desugar_partialCall` の前提でも、引数は `binds args.holeTypes ++ hideConts Γ` の下の計算である。
- 修正案:
  1. design 7.2 の表、14.5 の「捕捉の境界」の行、R123、plan L4 の境界の一覧に、「部分適用（`partialCall` の呼び出し先と固定引数、`partialCon` の固定引数）」を加える。これらは空の Δ で検査し、外側の構築器の参照を E0465 とする。13 の診断の割り当ても合わせる。
  2. 規則としては、`E_PartialCall` の `f` と `HasHoleArgsQ`、`E_PartialCon` の `HasHoleArgsQ` に `[]` を渡す。脱糖の補題は、ラムダと同じく、`fillBuilders _ [] = _` で得たコアの導出を `RenOk.up` と既存の rename で移す。
  3. `builders_no_capture` はコアの側で述べる。整列した Γ・Δ で型が付く式の脱糖について、「その中のすべてのコアの `lam`・`lazyC`・ハンドラの節の本体が、Δ で構築器の位置にあたる外側の番号を自由に参照しない」とする。表層の境界の列挙が漏れていれば、この言明が偽になって証明で漏れが見つかる。
  4. design 15.5 の拒否の例、L6 の空 Δ の境界の負例、L7 の独立入力に、部分適用の負例を加える。固定引数に `copy`、呼び出し先の式に専用操作を含む例を入れ、`return` とタスクの関数への引き渡しで持ち出す二つの形を負例にする。B1 の Rust の名前解決も同じ境界にする。
  5. `tryResultDie`・`tryOptionDie` の説明（`hideConts Γ`、`R = none`）は、その場で評価されて持ち出されないので、同じ Δ のままでよい。ただし表に明記する（軽2）。

## 中

### 中1 Δ の添字の位置と、公開の定義・前提の意味の確かめ方

- 箇所: design 14.5「七判断…同じ名前のままΔの添字を直接追加」、R117、plan L4・L6・L7（「定義を通じた前提の意味も比較」）。
- 問題: Δ の位置が決まっていない。公開の abbrev は `HasType D B op := HasTypeQ D B op Qempty` のように部分適用で定義してあるので、Δ を `C` や `Γ` の後に置くと、abbrev の後ろの引数の並びが変わる。すると `checkExpr_sound` などの公開の言明の文字列まで変わる。また、`Def.WellTyped`・`ImplDecl.WellTyped` は `HasBlockQ … (Qsig …) d.tparams …` を直接書いているので、どちらにしても文字列は変わる（`Program.WellTyped` はこれを経由する）。RV2 で「旧構文の意味が変わらない」ことを、差分を目で読む以外に確かめる手段が計画にない。
- 根拠: `Surface/Typing.lean` の `abbrev HasType … := HasTypeQ D B op Qempty`（543〜573 行）と、`Def.WellTyped`・`ImplDecl.WellTyped`（`HasBlockQ` を直接使う）。`Surface/CheckSound.lean` の 11 件は `HasType`・`HasBlock` などの abbrev で結論を述べる。
- 修正案: Δ はパラメータ `Q` の直後の最初の添字に置き、公開の abbrev を `HasTypeQ D B op Qempty []` とする。こうすると公開の 11 件の文字列は変わらない。`Def.WellTyped`・`ImplDecl.WellTyped` には `[]` を足し、その文字列の変更を l4/results.md に R 番号で記録する。意味が変わらないことの機械的な証拠として、次の二つを L4 で証明する。一つは、規則が Δ を `BuilderCtx.kindAt i := (Δ[i]?).join` だけで読むことにしたうえでの合同の補題 `HasTypeQ.congrΔ`（`∀ i, Δ.kindAt i = Δ'.kindAt i` のもとで判断が移る）である。もう一つは、構築器の構文を含まない式について Δ が任意であるという補題である。二つとも、新しい規則が Δ を読む箇所を除けば一回の相互帰納で済む。

### 中2 L4 の見込みと、全体ビルドを保つ区切り

- 箇所: plan L4（4〜8 時間、区切りは「宣言的判断/脱糖の補題と全読者」→「checkerと健全性」）、見込みの表、R117。
- 問題: 前回の改造では、Q を七判断へ足した L2b が、続きのセッション L2bc4 まで要した。七判断とその読者（`HasTypeQ` だけで 14 ファイル・311 箇所、七判断の合計で約 560 箇所）を変える作業の幅として、4〜8 時間の下限は楽観的である。また L4 には、正式な完了と紛らわしい近道がある。L4 の時点では Δ を読む規則がないので、一般化した脱糖の補題は「従来の Γ での導出を `RenOk Γ (fillBuilders Γ Δ) id` で移す」だけで証明できてしまう。そうすると、本物の帰納による一般化が L5 へ持ち越され、L5 の見込みが崩れる。
- 根拠: docs/archive/2026-10-17-…-syntax-batch2 の plan.md（L2b 450〜900 分の再見積もり）と l2b/results.md（L2bc4 まで続行）。formal の `Surface/Lemmas/Typing.lean` の `HasTypeQ.desugar`・`HasBlockQ.desugar`（約 540 行）。`Check.lean` は公開の `checkExpr` → `checkExprQ` → `checkExprR` の三層で、健全性は `CheckSoundControl.lean` の `mutualSoundness` に集めてある。
- 修正案: L4 を次の三つの区切りに分け、それぞれで全体ビルドを保つ。
  - L4a: Δ の添字、`congrΔ`、すべての読者。checker の `R`・`Q` の関数には Δ を受け取らせるが、まだ使わない。健全性は、`congrΔ`（または Δ を読む規則がない段階での Δ の任意性）で `[]` から移せるので、ビルドを保てる。
  - L4b: `Aligned` を前提にして、脱糖・clean・scoped の補題を本物の帰納で `fillBuilders Γ Δ` へ一般化する。束縛の場合は `fillBuilders.under_*` で、境界の場合は rename で示す。近道の証明では完了としない。
  - L4c: `mutualSoundness` の motive に Δ の不変条件（中4）を足す。
  見込みは 6〜12 時間とするか、4〜8 時間のまま「続きのセッションが 1〜2 回要る見込み」と明記する。plan の「見込みの 2 倍で相談」の基準も、この幅に合わせる。

### 中3 BuilderRefs.Ok が覆うべき条件と、脱糖が種類を知る方法

- 箇所: design 14.5 の `BuilderRefs.Ok` の説明と `builderRefs_typed`、plan L3（「Refs.Okの全欄に実際の宣言表の照合を割り当てる」）、`Expr.builderOp : BuilderOp → Nat → Exprs → BuilderRefs → Expr`。
- 問題: Refs.Ok の説明は「種類・型・効果・引数名」にとどまっている。しかし、コアで参照を型付けする規則は、ほかにも Q に依存する条件を要求する。また、脱糖は環境も Δ も受け取らないので、String・List・Bytes のどの追記を作るか（`+`、`List.append`、`Bytes.fromList` と `Bytes.concatenate`）と、その型引数を、構文だけから決めなければならない。
- 根拠: `Release/Typing.lean` の `V_Prim` は `NamesWF` と `PrimitiveAdmissible C s Q ts es` を、`V_Fun` は `P.defs`・`NamesWF`・`Admissible B C … Q ts es d.eff` を要求する。表層の `E_Prim`・`E_Fun` は、さらに `admits`・`SatAll`・`d.dictParams = []` を要求する。`Release/Assumptions.lean` には `ref_get`・`ref_set` の存在の仮定はあるが、`refNew` の存在の仮定はない。宣言表と `Surface/Lemmas/CallHead.lean` の `funDecl_desugared` で照合するしかない。
- 修正案: `BuilderRefs.Ok D B C Q Δ i refs` が明示する条件を次のとおり定める。
  - 各参照先の宣言の存在、種類（`refNew`・`refGet`・`refSet`、pure）、`NamesWF`、`dictParams = []`、`neffs = 0`、`admits`／`SatAll`、`PrimitiveAdmissible`／`Admissible`。
  - 具体化した型が `contents k` と `cell k` に一致すること。
  `neffs = 0` に限れば、`Admissible` が Q によらず成り立つ補題を一つ置けるので、Q の扱いが簡単になる。`BuilderRefs` は種類ごとの帰納型（`string …`、`list (T) …`、`bytes …`）にするか、`builderOp` に種類を持たせる。そのうえで、Refs.Ok で Δ の種類との一致を検査する。脱糖はこの形で場合分けする。`refNew` の存在を Builtins.Assumptions へ足さない方針は、そのまま維持する。

### 中4 内部の補題と checker の motive に要る Δ の不変条件を列挙する

- 箇所: design 14.5 の「kind内の通常型には既存の整形式・支持・単一Failの条件を別に課す」、`builderCheck_sound`、plan L4〜L6。
- 問題: 既存の内部の補題は、Γ について `EnvClean`・`Env.AtomsIn` を前提にしている。Δ についても、同じ種類の条件が内部の前提として必要になる。前提がないと、`copy` の結果型 `contents k` について、`TyOK`・原子の集合・単一Fail を導けない。今の文書は規則の前提にしか触れていないので、実装担当がこれを「主定理への前提の追加」と取り違えるおそれがある。
- 根拠: `Surface/Lemmas/Typing.lean` の `HasTypeQ.desugar` は `hΓ : EnvClean C.length Γ` と `hR` を前提にし、`HasTypeQ.clean` で結果型を確かめる。`Surface/CheckSound.lean` の各定理は `Env.AtomsIn q.atoms Γ` を前提にする。
- 修正案: 内部の前提として、`BuilderCtx.Aligned Γ Δ`、`BuilderCtx.Clean C.length Δ`（種類の中の型の `TyOK`）、`BuilderCtx.AtomsIn q.atoms Δ`、種類の中の型の `SingleTy` を明示する。束縛の追加と境界でこれらが保たれることを、L3 の補題の一覧に加える。公開の入口では `[]` なので自明に成り立つ。そのため、公開の言明に前提が増えないことを、R 番号の記録で示す。

### 中5 既定のビルドの対象 `surfaceCheck` の Walk.lean が作業のファイルの一覧にない

- 箇所: plan L5・L6 の「触るファイル」。
- 問題: `SurfaceCheck/Walk.lean` の `walkBlock` は `Block` を網羅的に場合分けする。このため、L6 で `Block.builderBind` を足すと、既定の対象 `surfaceCheck`・`surfaceCheckAll` のビルドが壊れる。`walkExpr` は末尾の `| _ => return e` で既定の分岐を持つので、L5 で `Expr.builderOp` を足してもビルドは通る。しかし引数の式を辿らなくなり、後の六入口で節点の分類が黙って欠ける。
- 根拠: `formal/lakefile.toml` の `defaultTargets` に `surfaceCheck`・`surfaceCheckAll` がある。`SurfaceCheck/Walk.lean` の 90〜100 行は `walkBlock` の網羅的な場合分け、89 行は `walkExpr` の `| _ => return e` である。`Block` を網羅的に照合するファイルは、ほかに `Surface/{Check,CheckPredicates,CheckSupport,CheckSoundSequence,CheckExamples,Desugar,WellFormed,Typing}.lean` と `Exchange/{Syntax,Convert}.lean` がある（Exchange は交換の構文木の側）。
- 修正案: L5 の触るファイルに、`SurfaceCheck/Walk.lean`（`builderOp` の引数を辿る）、`CheckPredicates.lean`、`CheckSupport.lean` を加える。L6 にも `SurfaceCheck/Walk.lean`（`builderBind` の本体を辿る）と `CheckSoundSequence.lean` を加える。既定の分岐のある照合は、新しい構成子を明示的に扱ったかを、各作業の results.md で一覧にして確かめる。

### 中6 構築器の型保存と State の言明に必要な補題の一覧は足りているが、余分な補題がある

- 箇所: design 14.5 の補題の表（`BuilderKind.subst_contents`/`shift_contents`、`fillBuilders.under_*` の「型/行のshift・代入・hideContsとの必要な交換」、`builders_scoped_rename`/`builders_scoped_subst`）、plan L3。
- 問題: Δ が型の束縛子を越える場所は一つもない。型パラメータを増やすのは、ハンドラの節（`sg.tparams ++ C`）と handleFail の節（`{} :: C`）だけであり、どちらも空の Δ の境界である。また表層には式の番号の付け替えも型の代入もない（`Expr.rename`・`Expr.subst` は存在しない）。このため、`BuilderKind` と `fillBuilders` の shift・代入との交換、および `builders_scoped_rename/subst` は、どの証明からも使われない見込みである。実際に要るのは、`hideConts` との交換（説明・ガードで同じ Δ を使う場合）と、`shiftEnv` を経た境界での rename だけである。後者は、空の Δ から `none` の位置を埋めるだけなので交換は要らない。不要な補題に L3 の時間を使うと、L4 の不足が大きくなる。
- 根拠: `Surface/Typing.lean` の `E_HandleFail`（節は `({} : TParam) :: C` と `none :: some (E.shift 1 0) :: shiftEnv 1 Γ`）と、`E_Handle` の節。`Surface/Lemmas/{SubstClean,ShiftClean}.lean` は型の範囲の補題だけで、式の代入は扱わない。`Release/Lemmas/Rename.lean` の `RenOk` は `some` の位置だけを要求する。
- 修正案: L3 の一覧から、shift・代入との交換と `builders_scoped_rename/subst` を外す。代わりに `fillBuilders_hideConts : fillBuilders (hideConts Γ) Δ = hideConts (fillBuilders Γ Δ)` と、`Aligned (hideConts Γ) Δ` を置く。後で必要と分かったら L4 で足し、R 番号に記録する。これは時間の配分の指摘であり、見込みの下限を上げる中2と合わせて扱う。

## 軽

### 軽1 公理の比較は formal/README.md の手順を使い、開始版の結果を固定する

- 箇所: plan L7（「既存主定理の定義を辿った前提と公理依存を開始版と比較する」）、検査表の L1〜L7、RV2 の行。
- 問題・根拠: `formal/README.md` の 20〜44 行に `#print axioms` の手順と対象の一覧がある。しかし plan はこの手順を引用していない。今回、主な 5 件が標準の 3 公理だけに依存することを確認した。
- 修正案: L1 の開始時に README の一覧で開始版の結果を記録し、各 L の results.md で同じ一覧を比べる。小さなモデルの具体例（Integer の最大値・最小値、IPv4 形式の例など）で `native_decide` を使わない（`Lean.ofReduceBool` の公理が加わる）。`decide`・`omega`・`simp` で閉じる。

### 軽2 説明・ガードに渡す Δ を表に書く

- 箇所: design 7.2 の表、14.5 の「それ以外の部分式」。
- 問題・根拠: `E_TryResultDie`・`E_TryOptionDie` の説明と、match のガードは `hideConts` の環境で検査する（`Surface/Typing.lean`）。同じ Δ を渡すなら、`Aligned (hideConts Γ) Δ` と中6 の交換の補題が要る。ガードは `Eff.empty` を要求するので、State を持つ専用操作はどのみち拒否される。
- 修正案: 表に「説明・ガード: 同じ Δ（説明はその場で評価し持ち出さない。ガードは純粋の条件で専用操作を書けない）」と明記する。

### 軽3 Scope の言明に InvalidPort の場合がない

- 箇所: design 14.2 の定理名の表。
- 問題・根拠: 3.1 の失敗の優先順は、端点の妥当性、port 自体の妥当性（0〜65535）、ホストの所属、ポートの所属の順である。しかし表には `makeEndpoint_invalidBounds_iff` と `makeEndpoint_outside_iff` しかない。端点が妥当で port が 70000 の場合に何を返すかを、言明が定めていない。
- 修正案: `makeEndpoint_invalidPort_iff`（端点の判定を通った入力について `InvalidPort ↔ ¬ (0 ≤ port ∧ port ≤ 65535)`）を加え、`makeEndpoint_outside_iff` の前提をそれより後の段にする。

### 軽4 L7 の独立入力で、共有する番号を固定する

- 箇所: plan L7 の手順、design 14.6。
- 問題・根拠: 構築器の位置は Γ の番号を一つ占める。そのため、`.local i`、`.resume k`、辞書の `.local j`、`.clause s i depth`（`Γ.length = depth + 1 + …` を要求する）の番号は、どれも構築器の位置を数えに入れる（`Surface/Typing.lean` の `DictEv.HasType.clause`）。Rust の書き出しがこれを数え落とすと、B3 で初めて食い違いが分かる。また、`Exchange/Version.lean` の `validateConstantBody` は束縛の構文を定数の本体から拒否する。構築器の宣言はこの一覧にない。
- 修正案: 独立入力に、構築器の宣言をまたいで、節の辞書・`resume`・受け取った辞書を参照する例を入れる。`validateConstantBody` の拒否の一覧に、構築器のタグを加える（型付けでも `E_Const` が純粋を要求するので拒否されるが、交換の段で早く分かる）。

### 軽5 L2 の幅

- 箇所: plan L2（2〜4 時間）、R119。
- 問題・根拠: formal の表層の例には、`.ctor`・`.tapp` を型クラスの対象に渡して、checker・脱糖・実行まで通した正例がない。`Release/TypeSubst.lean` は `tapp` の代入を `rawApplyTo` で扱うが、表層の例は `CheckLemmas.lean` の小例に限られる。R119 はこの不確実さを認めている。
- 修正案: 3〜6 時間とするか、最初の区切り（`Ty.WF` と `SatAll`）で見込みを見直すと明記する。

### 軽6 小さなモデルと本体の保証を 07-04 の表で分けて書く

- 箇所: plan L1・L2 の写しの更新、07-04「01-12 との対応」。
- 問題・根拠: design 14.1〜14.4 は内外の区別を正しく書いている（`Checked` と `Library.ResultLaws` は Surface の型付けにも脱糖にも接続しない）。しかし 07-04 の対応表に同じ区別が写されないと、後で「Result の法則が Benitoite の implement について証明済み」「Scope の適合がプログラムの安全を保証する」と読まれるおそれがある。
- 修正案: 07-04 に、`Checked.*` と `Library.ResultLaws` は主定理の外にある独立した小さな証明であり、Rust・.bnt との対応は独立の期待値による照合であることを一行で書く。`Monad2Examples` だけが本体の判断に接続することも書く。

### 軽7 L5 の中間状態の範囲を写しへ明記する

- 箇所: plan L5（「公開の空Δだけでは構築器を作れない中間状態だと明示する」）。
- 問題・根拠: L5 の後、L6 の前の取り込みでは、`builderOp` は内部の補題でしか型が付かず、公開の入口では常に拒否される。この状態の 01-12 の写しと 07-04 が「構築器を形式化した」と読める書き方だと、L6 が止まったときに誤解を招く。
- 修正案: L5 の写しは「専用操作の規則と脱糖の補題まで。宣言は L6」と区切りを書き、L6 の完了でその一文を消す。

## 各観点の判断のまとめ

- Γ/Δ の整列・fillBuilders・既存の rename: 成り立つ見込みである。`E_Local` と `V_Var` は `some (some a)` を要求し、`RenOk` は `some` の位置だけを要求する。このため、セルを `none` に置き、境界では空の Δ から rename で移す方式は、今の定義に無理なく乗る。束縛の追加（`some t :: Γ`／`none :: Δ`、`binds δ ++ Γ`／`none` の列）、`with`、handleFail と handle の節、`E_Const` の空の環境は、どれも `fillBuilders` の先頭への追加か空の Δ で扱える。反例は重1 だけ見つかった。
- 主定理・公理・Builtins.Assumptions: 変えずに済む見込みである。`refNew` は Refs.Ok で宣言表から照合でき、`state_effect` と `store_admits` は既存のとおり使える。`surface_effect_soundness` は純粋な main に限る既存の前提のままであり、構築器を除外する条件ではない。`Program.WellTyped` の定義の文字列は変わるが、意味の保存は中1 の補題で示せる。
- A/C と Result の法則: design 14.1〜14.4 は本体の保証と分けている。07-04 への写しで同じ区別を保つこと（軽6）。
- 各区切りの全体ビルド: L1〜L3 は新しいモジュールの追加なので保てる。L4 は中2 の三つの区切りなら保てる。L5・L6 は中5 のファイルを含めれば保てる。L7 は Version.lean の分岐の分離で保てる。
- L7 の交換と旧版の受理: R118 の案は `exchangeJson` の `current`/`current - 1` と `version < current` の拒否、`sidecarVersion` の `== 11` を正しく捉えている。corpus 11 の batch2 の欄を拒否しないこと、10 を受理し続けることは、`test_batch2_exchange.py`（corpus 8/9/10 で batch2 の欄を拒否する検査と、固定入力の版 11 の検査）と `test_named_exchange.py`（版 7 の拒否の文言）を保てば確かめられる。
