# L00.07 の結果: 非空例と切り替えの整合

2026-10-27。plan「作業 L00.07」を、取りまとめが用意した作業用のディレクトリ（`<wt>`、ブランチ `m013/l00.07`）で行った。担当は Claude のサブエージェントである。コミットは取りまとめが行う。既存の定義と定理は変えていない。並行する L00.06b（案 (i) の節の添字 S）と L00.06c（案 (ii) を暗黙の変換なしで）の結果は待たずに進め、二枝の結果で変わりうる点に印を付けた（下の「両案の選択に要る実物と L30・L40 の義務」）。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L00.07（非空例と切り替えの整合） |
| B_WORK | `91c9af89163fc08103efebf8642607bf05aee06c`（L00.06 と UB10 の取り込みの後の本線） |
| 閉じた範囲 | 純粋な検査から狭い値を作る例、明示拡大、同じ値の転送、別の対象へ操作する節、捕捉した引数を転送する節、対象なしの旧 IO と非 Top の IO の混在を、L00.02〜.06 の模型の定義だけで書いた非空の例と小補題。UB10 の申し送りの (c) の利用者の操作の例（`saveToFile` の形）。範囲の変数を利用者の宣言に置かせない条件の候補と、その条件が要る理由の小補題。L00.06 の申し送りの NT・NV（値の所属の型付けの置き方）の三案の比較。L00.06 の申し送り 2（`GEff` を非 Top の例と Top の旧の例に当てる）。旧の主定理の import と新しい例の import の照合。両案の選択に要る実物と L30・L40 の義務の表 |
| 未完 | なし。本番の接続（Release の型付け・遷移・主定理、Surface の検査と脱糖）は本作業の範囲外であり、言明と担当の段を下の表に置いた。L00.06b・L00.06c の結果の反映は L00.08 が行う |
| 採否 | 採用は決めていない。格納方式・値の所属の置き方・範囲の変数の条件の置き場所・最終の配置は L00.08 が決める |

## 変更と接続

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Scope/SwitchExamples.lean` | 新規。名前空間 `Benitoite.Scope.SwitchExamples`。`Scope.TargetExamples`・`Scope.InferenceExamples`・`Scope.CompatExamples` を import する（推移的に `Domain`・`SignatureExamples`・二案の模型を含む）。定義・構造体・帰納型 36（abbrev を含む）、定理 48、`#guard` 9 |
| `formal/Benitoite.lean` | 既定の import の末尾に `import Benitoite.Scope.SwitchExamples` を一行加えた |
| `l00.07/` | 本書、生のログ（`lake-build.log`・`work-check-dry-run.log`・`work-check.log`・`axioms.lean`・`axioms.log`・`imports_root.lean`・`imports_root.log`・`imports_new.lean`・`imports_new.log`） |

模型の外の新しい定義は例を書くための補助（`writeAt`・`fileWrite`・`removeName`・`handledBound`・`UserOp`・`vtyNoRVar` など）と、比較のための小さい型付け（`ValueTyping` の三案）だけである。中心の定義の候補を足していない。設計書（01-12・07-04 など）には反映していない（採用前の候補のため）。

## 非空の例と骨格の対応

「骨格」の列は使った L00.02〜.06 の定義、「本番の接続と担当の段」の列は、例が示していない本番の言明とそれを閉じる段である。後者は未実装・未証明であり、実装済みの小補題と分けて書く。小さい機械（L00.04 の `Step`・`StTy`）はハンドラ・継続・ストアを持たないので、その上の定理を一般の主定理の代わりにしない。

| 例 | Lean の名前（実装済みの小補題） | 骨格 | 示したこと | 本番の接続と担当の段（未実装） |
|---|---|---|---|---|
| 1. 純粋な検査から狭い値を作り、非 Top の IO へ渡す | `checkPathDelta_ok`・`pathIn_typed_iff`・`writeAt_ty`・`writeAt_obs`・`check_then_write`・`check_then_write_example`（`#guard` 2 件） | L00.03 の `checkPathDelta`・`HasTypeV`・`Entry.inst`・`RangeAdmissible`・`TargetAgreement`、L00.04 の `CallTy`・`Step`・`goodTable`・`target_goodTable` | 検査の δ の `Ok` の値は R に属する対象を保持し、その値で `File.writeTextIn` を `File.Write[R]` の上限で型付けられ、事象の観測は検査した同じ対象一つで R に属する。`/data/**` の内側は成功、`/etc/passwd` は動的な確かめで誤り | 本番の `delta_typed` の項目（L20）、`V_Prim` の R（L20.2）、事象の観測の欄（O1、L20.4）、本番の一段の対象の健全性（L30）。R の整形式性は解析器の出力の性質（L10・L40、Rust は R30・K10） |
| 1'. 局所解析の最小例から IO へ | `minimal_then_write`、`mem_path_kind` | L00.05 の `minimal_checked`・`requiredIndex`・`CVal.toSig` | 必須の判定が `/data/**` を付けた位置の値で、同じ範囲の `File.writeTextIn` を型付けられる（局所解析・値の型付け・効果の上限に同じ R を渡す） | Surface の構文から局所解析の `Step` への対応、型検査器が選ぶ R とコアの δ の R の一致の本番版（L40）。`const` の直接参照（L40） |
| 2. 明示拡大 | `valA_narrow`・`widen_admissible`・`widen_same_value`・`widen_typed`・`widen_not_admissible` | L00.03 の `widenPathIn`・`widenDelta`・`widenPathIn_delta_typed`・`admitsR`・`Range.Sub` | `/data/a.txt` の値（`PathIn["/data/a.txt"]`）は拡大で同じ値のまま `PathIn["/data/**"]` の型を持つ。被覆しない向き（`/data/**` から `/data/a.txt`）は具体化を許されない | 静的な被覆の判定とその健全性（L10）、戻り値の注釈から S を一意に決める規則（L40）、公開名（DET-03） |
| 2'. 同じ値の転送 | `widen_then_write_same_target` | 同上と L00.04 の `io_target` | 拡大した値で広い上限の書き込みを呼んでも、観測は拡大の前に検査した対象（`/data/a.txt`）だけである。広い型で受け取っても対象は広がらない | 本番の `E_Prim`・`E_IO` の保存で同じ値を運ぶこと（L30） |
| 3a. 別の対象へ操作する節 | `removeName`・`handledBound`・`outerLog`・`captured_arg_typed`・`log_clause_obs`・`outerLog_excludes_data`（`#guard` 2 件） | L00.03 の `clauseIndex`・`clause_arg_typed`、L00.04 の小さい機械 | 保護本体が `/data/**` へ書き、節が記録だけを `/logs/**` へ書く。外側の上限は `File.Write["/logs/**"]` だけになり、`/data/a.txt` を許さない。節の添字 S は `/data/**` で、捕捉した引数はその型を持つ | ハンドラの意味（`E_OpPrim` の保存と S の所属、保護本体の効果からの S の導出の精度）は模型にない（L20.2・L30。L00.06b の結果で枝の大きさが決まる）。名前の全操作の節がそろう条件は本番の `handled` が持ち、模型の `removeName` は持たない |
| 3b. 捕捉した引数を転送する節 | `outerForward`・`forward_clause_ty` | 同上 | 節が捕捉した引数を同じ範囲の書き込みへ渡すと、外側の上限は S の原子を持ち、節の書き込みはその上限で型付く | 同上（L30） |
| 3c. 利用者の操作（(c)） | `UserOp`・`saveOp`・`outerSave`・`outerSave_no_user`・`saveOp_not_builtin`・`save_clause`・`save_example`（`#guard` 2 件） | L00.03 の `VTy.opaque`・`Ix.fixed`・`Atom.ofOld`、L00.04 の小さい機械 | 下の「(c) の利用者の操作の例」 | 本番の `V_Op`・`E_Op` は変えない見込み（L30 で点検）。利用者の操作の引数型に非 Top の範囲を書けるのは、本番の `Ty` が範囲を持った後（L10.1）。Surface の E0506・E0513（L40、Rust は UB20） |
| 4. 対象なしの旧 IO と非 Top の IO の混在 | `printLine_inst`・`printCall_ty`・`writeCall_ty_mixed`・`mixed_ty`・`print_obs_nil`・`mixed_progress`・`mixed_reachable`・`mixed_not_empty` | L00.03 の `printLine`（`untargeted`）、L00.04 の `progress`・`reachable_target_sound`・`effect_soundness` | 上限 `File.Write["/data/**"]` と `Console`（名前だけ）を持つ状態は進み、到達先の事象の観測は初期の上限に許され、`Console` の事象は対象を報告しない。対象なしの項目はどの具体化でも変わらない。空の上限では型付かない | 既存の IO の項目が `io_target` の形の条件を満たすことの信頼条件のレビュー（L20.3）、`Event.io` の観測の欄（L20.4） |
| 5. 一般化した効果の非 Top と Top の旧の例 | `nonTopI`・`nonTopI_not_lifted`・`nonTopI_union_empty`・`oldTop_union_empty_I`・`oldTop_union_empty_II` | L00.06 の `GEff`・`TopEmbedding`・`old_*` | 非 Top の効果 `{File.Write["/data/a"]}` は旧の効果の像にない（旧の補題では言明できない）が、一般化した補題はそのまま当たる。Top の旧の例は案 (i)・(ii) のどちらの埋め込みでも旧の言明のまま得る | 本番の型の上の系は Top の構築関数を通す形になる（L10.1・L10.3） |
| 6. 値の所属の型付けの置き方（NT・NV） | `ValueTyping` の `tyA_iff`・`tyA_canonical`・`tyB_canonical`・`tyA_widen`・`tyB_widen`・`tyB_old_conclusion`・`tyC_not_tree` | L00.03 の `HasTypeV`・`Range.Sub` | 下の「値の所属の型付けの置き方」 | L20.1 |

旧の対象ありの Top の例（リダイレクトを追う旧 `Http.send`）は L00.04 の `redirect_allowed` にあり、本作業は重ねていない。

## (c) の利用者の操作の例

UB10 の申し送り 1 の例を、既存の構成子だけで置いた（`saveOp` と `save_clause`）。新しい引数・構成子・範囲の変数は使っていない。

- 宣言: 利用者のエフェクト `Report` の操作 `save` は、引数 `path` に `Scope.PathIn["/data/reports/**"]`、`text` に `String` を取り、`Unit` を返す。写しの `UserOp` は本番の `Release.OpDecl` の `eff`・`names`・`params`・`ret` だけを持ち、範囲の欄を持たない。引数の型は L00.03 の `VTy.opaque pathInName (.fixed reportsTree)` であり、範囲は閉じた範囲として固定される。
- 効果: 保護本体の効果は `UserOp.atom`（本番の `V_Op` の `Eff.single od.eff` に当たる名前だけの原子、Top）である。節の添字 `clauseIndex "Report" bodyReport` は Top になる。利用者の操作の引数の型は宣言の固定の範囲で決まり、節の添字に依らない。
- 節: 節は `File.writeTextIn(path, text)` を行う。外側の上限 `handledBound "Report" bodyReport (fileWrite reportsTree)` は `File.Write["/data/reports/**"]` だけであり（`#guard`）、`Report` の原子を含まない（`outerSave_no_user`）。
- 型付けと対象: 引数が宣言の型で型付けば、節の書き込みは外側の上限で型付き、事象の観測は `/data/reports/**` に属する（`save_clause`）。`/data/reports/2026.txt` の具体の例では観測はその対象一つである（`save_example`）。
- 認定元: `Report.save` は組み込みの表になく、`Report` は対象の種類も操作の一覧も持たない（`saveOp_not_builtin`）。
- 限界: 本番の `E_Op` の遷移（節の本体の実行と再開）と、名前の全操作の節がそろう条件は模型にない。外側の上限を `removeName` と連結で計算したのは本番の `handled` の写しであり、保存の定理で外側の上限が保たれることは L30 の義務である。

## 範囲の変数の条件の置き場所

範囲の変数を型に置く案（L00.03 の `Ix.rvar`）を採る場合、利用者の宣言に `rvar` を置かせない条件が要る。理由を小補題で示した。

- `rvar_uninhabited`: 範囲の変数を添字に持つ型には値が属さない。条件がないと、範囲の変数を書いた利用者の操作は呼び出せない操作になり、後に (a) で具体化を加えると黙って範囲の多相になる。
- `rvar_atom_uncovered`: 範囲の変数の原子は、上限に同じ変数の原子がなければ覆われない。利用者の効果に変数が残ると、`main` の上限へ未解決の変数を運ぶ。
- `inst_of_noRVar`・`saveOp_params_inst`: 条件を満たす型は、どの具体化でも変わらない。`saveOp` は条件を満たし、引数・結果に `rvar` を置いた変種は満たさない（`#guard` 3 件）。

条件そのもの（`vtyNoRVar`・`UserOp.NoRVar`）は Bool の検査として置いたが、置き場所は決めない。候補は次のとおりである。

| 候補 | 内容 | 利点 | 費用・注意 |
|---|---|---|---|
| P1 型の整形式性 | `Ty.WF` に範囲の変数の個数の文脈を加え、プログラムの型（利用者の宣言・関数の定義・ラムダの注釈）は 0、組み込みの署名だけ項目の `nranges` で検査する。型変数の `Ty.WF C.length` と同じ形 | 一箇所で、利用者の操作以外の型（定義・注釈）も覆う | `Ty.WF` の引数が増え、WF の保存・shift/subst の証明へ波及する（L00.01 の申し送り 6「範囲の整形式性」と同じ判断）。二案で同じ |
| P2 宣言ごとの整形式性 | UB10 の案。`OpDecl.Scoped` と定義の宣言の対応する整形式性に「`rvar` を含まない」を加える | 局所的で、変更する定義が少ない | 宣言の種類ごとに足すので、定義・ラムダ・注釈で漏れうる |
| P3 型の分離 | 組み込みの署名の型だけが範囲の変数を持ち、プログラムの型は閉じた範囲だけを持つ（本番の `Ty` の範囲の位置を `Range` にし、署名表の項目を別の型か範囲の列からの関数で持つ） | 条件が構成で成り立ち、整形式性に入れない | 具体化が型の変換になる。L00.03 の「関数の案」に近く、UB10 の「(a) は `Ix` の案が足しやすい」と逆向き |
| P4 `Program.EffectsOk` | UB10 が名前の重なりの禁止を見つけた、利用者と組み込みを分ける述語の連言に加える | 利用者と組み込みの分離が一つの述語に集まる | 型の整形式性ではないので、定義・ラムダの型には及ばない |
| P5 脱糖の補題 | 表層には範囲の変数を書く構文がない（判断 6・10）。脱糖の出力の型に `rvar` が現れないことを補題で示す | 表層の決定をそのまま使う | 交換の入力（`Exchange/*`）や手で書いたコアの例は脱糖を通らないので、コアの側の条件（P1〜P4 のどれか）も要る |

範囲の変数を型に置かず、表の項目を関数として持つ案を採る場合、この条件は要らない（空になる）。どの候補も格納方式 (i)・(ii) で差がない見込みである（推測）。

## 値の所属の型付けの置き方（L00.06 の申し送り 1）

範囲付きの値の所属（L00.03 の `HasTypeV` の `.checked t, .opaque o (.fixed r)` の場合）を本番の型付けにどう置くかを、三案の小さい型付けで比べた（`ValueTyping`）。

| 案 | 値（NV） | 型付けの規則（NT） | 示したこと | 本番への影響（推測） |
|---|---|---|---|---|
| A 新しい葉の規則 | 値に検査済みの対象の構成子を足す | 所属を前提に持つ葉の規則を足す | L00.03 の `HasTypeV` と一致する（`tyA_iff`）。標準形（`tyA_canonical`）と拡大（`tyA_widen`）は規則の場合分けで閉じる | `HasTypeVQ` の相互帰納を場合分けする定理（L00.06 の NT、118 定理）に葉の場合が一つ加わる。部分の導出を持たないので各場合は機械的に閉じる見込み。`Val` を場合分けする定理（NV、10 定理）にも場合が加わる |
| B 定数の規則の言明の変更 | 定数（本番の `Const`）に検査済みの対象を足す | 規則を増やさず、`V_Const` の結論 `c.type` を関係 `ConstTy` の前提に変える | 標準形（`tyB_canonical`）と拡大（`tyB_widen`）は `ConstTy` の場合分けで閉じる。旧の結論 `c.type` は新しい前提の一つの解である（`tyB_old_conclusion`、Top の互換） | 相互帰納の場合の数は変わらない。代わりに `V_Const` を使う箇所（Release・Surface の 25 ファイル・78 か所、字句の数え）の、型を `c.type` と等しいとして使う証明が変わる。`Const` を場合分けする関数・定理にも場合が加わる |
| C `Const.type` だけを変える | 定数に検査済みの対象を足す | 規則の言明を変えず、`Const.type` が対象の完全一致の添字を返す | `/data/a.txt` の値に `/data/**` の型を付けられない（`tyC_not_tree`）。`Ty.Le` に非関数の共変を加えない（判断 6・10）ので、範囲 R の検査の δ の結果型 `PathIn[R]`（`delta_typed`）を満たせない | 採れない。採るには `Ty.Le` か `V_Const` の言明を変える必要があり、A か B に帰着する |

A と B は格納方式 (i)・(ii) によらない（L00.06 の NT・NV の結論と同じ）。どちらを採るかは L20.1 の枝の大きさ（A は場合の追加、B は既存の場合の証明の変更）を決めるが、格納方式の選択には要らない。件数は L00.06 の依存の印と字句の数えであり、ビルドで確かめていない。

## 両案の選択に要る実物と L30・L40 の義務

「両案の選択に要る実物」は L00.08 で格納方式 (i)・(ii) を選ぶ前に要るもの、「L30・L40 の義務」は採用の後に証明するものである。印 ‡ は L00.06b（案 (i) の節の添字 S）、§ は L00.06c（案 (ii) を暗黙の変換なしで）の結果で変わりうる点を示す。

| 項目 | 両案の選択に要る実物（L00.08 の前） | L30 の義務 | L40 の義務 |
|---|---|---|---|
| 捕捉した組み込みの操作の節の添字 S（`E_OpPrim`）‡ | 案 (i) で `PrimSig.inst`・`V_Prim` の R を足して `E_OpPrim` を閉じられるか（L00.06b）。案 (ii) は L00.01 で sorry のまま止まった。模型の `clause_arg_typed`・`captured_arg_typed` は値の型付けだけで閉じる | `preservationE`・`pres_op_common` の `E_OpPrim` の場合で節の引数を S で型付けること。保護本体の効果から S を選ぶ精度（判断 11） | Surface の `HasClausesQ` の節の添字 |
| 署名の具体化と項の範囲（`V_Prim` の R、`.prim` に範囲を持たせるか）‡ | 案 (i) の試行に具体化を足した件数（L00.06b）。項に範囲を持たせるかは UB10 の申し送り 3 のとおり後の `.op` と揃える | `E_Prim`・`E_IO` の保存で具体化した署名を使うこと | 型検査器が選ぶ R と脱糖・コアの δ が使う R の一致（L00.05 の `checkRule_index_agrees` の本番版） |
| 名前の型と暗黙の変換 § | 案 (ii) を明示の構築関数で書いた破損の件数（L00.06c）。EX の定理 12・定義 30、資源の 4 件 | なし | なし（UB10 の申し送り 2: 利用者の原子が黙って Top に狭まる箇所を残さない） |
| 原子の符号の単射性 § | 案 (ii) の `Atom.code_injective`（L00.01 で sorry。L00.06c で閉じるか） | なし（L10 で閉じる） | なし |
| 値の所属の型付け（NT・NV） | 本作業の三案の比較。格納方式によらない。C は採れない | 値の代入・標準形・ストアの場合の所属の保存（L20.1 で規則を置いた後の Release の補題） | Surface の値の型付け（NS） |
| 範囲の変数の条件 | 本作業の P1〜P5。格納方式によらない見込み。`Ix` を採るかは L00.08 | 選んだ置き場所の保存（P1 なら WF の保存） | P5 を併用するなら脱糖の補題 |
| 純粋な検査の δ と `delta_typed` | 不要（二案共通。L00.03 の `checkPathIn_delta_typed`） | なし | 解析器が整形式の範囲を返すことの境界（L10・L40、Rust は R30・K10） |
| 明示拡大の被覆 | 不要（二案共通） | なし | 被覆の判定の健全性（L10）と戻り注釈から S を決める規則 |
| 名前全体の除去と節の IO の外側の上限 | 案 (ii) は `handled_scope` が `rfl`、案 (i) は腕に束縛を一つ足す（L00.01・UB10）。差は小さい § | ハンドラの保存で、節の範囲付きの効果が外側の上限に残り、処理した名前の範囲付きの原子が除かれること（本作業の 3a・3b・3c の本番版） | Surface のハンドラの効果の計算 |
| 一段・到達先の対象の健全性 | 不要（二案共通。言明 `ReleaseStepTargetStatement`、`reachable_of_step`） | 本番の一段の言明の証明。継続を通した対象の伝播（`end_of_noHandler` の対象版）。`BuiltinOnly` の BB に要る `StateTyE` の末尾の添字の単調性 | なし |
| 観測の欄（O1） | 不要（二案共通） | L20.4 で置いた欄を使う `step_soundE`・`progress_io`・`no_event` の場合 | なし |
| 対象なしの旧 IO | 不要（二案共通。本作業の 4） | 既存の IO の項目が `io_target` の形の条件を満たすことの信頼条件（L20.3 で置き、レビューで受け入れる。証明の対象ではない） | なし |
| 利用者の操作（(c)） | 不要（本作業の 3c は既存の構成子で書けた。UB10 は二案の差を小さいと判定） | `V_Op`・`E_Op` の保存は変えない見込み（点検） | E0506・E0513 と、標準の認定（`apiAt`）に利用者の関数が入らないこと（UB20・K10） |
| 局所解析と必須の判定 | 不要（二案共通） | なし | Surface の構文から局所解析の `Step` への対応、`const` の直接参照、`ScopeState` の番号の新規性の不変条件（L00.05 の申し送り） |
| 一般化した効果と Top の系 | 不要（二案共通。本作業の 5 と L00.06） | なし | なし（L10.1・L10.3 で本番の型の上の系を置く） |

どの行も、小さい機械や模型の定理を本番の主定理の代わりに数えない。本番の進行・保存・効果の健全性・脱糖の型の保存の言明は変えず、対象の健全性は別の定理として L30 で証明する。

## import の照合

既定の入口 `Benitoite` を import した環境で、旧の主定理と新しい例の定理の所属するモジュールを確かめた（`imports_root.lean`・`imports_root.log`）。新しい例だけを import した環境で、旧の主定理のモジュールを含むかも確かめた（`imports_new.lean`・`imports_new.log`）。

| 定理 | モジュール | 既定の入口 | `SwitchExamples` の閉包 |
|---|---|---|---|
| `Release.progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound` | `Benitoite.Release.Theorems` | 含む | 含まない |
| `Surface.desugar_typed` | `Benitoite.Surface.Theorems` | 含む | 含まない |
| `Release.steps_preserve`（`reachable_of_step` が使う） | `Release.Lemmas.EffectSound` の閉包 | 含む | 含む |
| `SignatureExamples.target_sound`、`TargetExamples.step_target_sound`・`reachable_of_step`、`InferenceExamples.minimal_checked`、`CompatExamples.TopEmbedding.old_union_empty_right_nested` | 各模型のモジュール | 含む | 含む |
| 本作業の `check_then_write`・`minimal_then_write`・`widen_then_write_same_target`・`log_clause_obs`・`save_clause`・`mixed_reachable`・`nonTopI_not_lifted`・`ValueTyping.tyC_not_tree` | `Benitoite.Scope.SwitchExamples` | 含む | — |

既定の入口は 2621 モジュール、`SwitchExamples` の閉包は 2452 モジュールである。旧の主定理と新しい非 Top の例は同じ既定の入口で検査され、`lake build` の対象から外れたものはない。新しい例は旧の主定理のモジュール（`Release.Theorems`・`Surface.Theorems`）に依存せず、主定理の証明を変えない。警告の解析（`Interval.Flow`・`Interval.Sound`）も新しい例の閉包に入らない（L00.05 の分離のとおり）。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 単一ファイル（1回目、1〜4 節） | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 Benitoite/Scope/SwitchExamples.lean` | 1（下の「失敗と修正」） | 0.81 秒 | 本書 |
| 単一ファイル（2回目） | `cd <wt>/formal && lake env lean -M 12288 Benitoite/Scope/SwitchExamples.lean` | 0。使わない simp の引数の警告 1 件 | 計時なし（1 秒未満） | 本書 |
| 単一ファイル（3回目、5・6 節を加え警告を除いた後） | 同上 | 0。出力なし | 計時なし（1 秒未満） | 本書 |
| 単一ファイル（4回目、注釈の文の修正の後） | 同上 | 0。出力なし | 計時なし（1 秒未満） | 本書 |
| 既定の全体のビルド（1回目） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>` | 0（418 ジョブ、sorry なし） | 1.64 秒（待ち 0 秒） | 4回目の単一ファイルの前の状態。下の 2回目で上書きした |
| 既定の全体のビルド（2回目、最終の状態） | 同上 | 0（418 ジョブ、sorry なし。`SwitchExamples` は 613 ms） | 1.34 秒（待ち 3 秒） | `lake-build.log` |
| 公理の依存 | 新しいモジュールの全 48 定理について、リポジトリの外の一時ファイルで `#print axioms`（`cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <tmp>/l00.07/axioms.lean`）。最終の状態で取り直した | 0 | 0.29 秒 | `axioms.lean`・`axioms.log`。`[propext]` 20 件、`[propext, Quot.sound]` 1 件、`[propext, Classical.choice, Quot.sound]` 27 件。ほかの公理と `sorryAx` はない |
| import の照合（既定の入口） | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <tmp>/l00.07/imports_root.lean` | 0 | 0.88 秒 | `imports_root.lean`・`imports_root.log` |
| import の照合（新しい例の閉包） | 同じ形で `<tmp>/l00.07/imports_new.lean` | 1回目 1（`import Lean` の欠落で `CoreM` が未定義）、2回目 0 | 0.36 秒・0.65 秒 | `imports_new.lean`・`imports_new.log` |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base 91c9af89163fc08103efebf8642607bf05aee06c --dry-run` | 0 | 1 秒未満 | `work-check-dry-run.log`。選択は `formal_build`（`formal/Benitoite.lean` の変更による。sorry の宣言を拒否する）だけ |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base 91c9af89163fc08103efebf8642607bf05aee06c` | 0（`formal_build`、`selected checks passed`。変更 12 件で dry-run と同じ選択） | 0.32 秒（ビルド済み） | `work-check.log`。最終の状態（本書を含む）で一度だけ走らせた。それより前の同じ指定の実行（0.23 秒、終了0）は注釈の修正の前の状態であり、結果に数えない |

単一ファイルの検査は一度に一つだけ走らせた。`-M 12288` は変えていない。大きな具体の計算をカーネルへ展開していない（`decide` は数個の原子の列の等号と小さい範囲の所属だけに使った）。

## 最大常駐量

`/usr/bin/time -l`（macOS）の maximum resident set size の原値（バイト）である。プロセスは並行させていない。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 単一ファイル（1回目） | 793657344 | 756.9 | 0.74 |
| 既定の全体のビルド（2回目、`lake build` 全体） | 1510621184 | 1440.6 | 1.41 |
| 公理の依存（最終） | 735395840 | 701.3 | 0.68 |
| import の照合（既定の入口） | 1519058944 | 1448.7 | 1.41 |
| import の照合（新しい例の閉包、2回目） | 1413234688 | 1347.8 | 1.32 |
| work（`check.sh`、ビルド済み。最終の実行） | 69320704 | 66.1 | 0.06 |

単一ファイルの 2〜4回目は計時していない。メモリの見張り（一つ 13 GB、全体 26 GB）に当たる実行はなかった。

## 失敗と修正

| 失敗 | 原因 | 修正 |
|---|---|---|
| 単一ファイルの1回目が終了1 | (1) `check_then_write_example` の `by decide` の期待型に成功値の変数が残った。(2) `outerSave_no_user` の `cases` が文字列の等式 `"Report" = "File.Write"` で依存の除去に失敗した。(3) 自分の名前空間に置いた `Ix.NoVar`・`VTy.NoRVar` を点の記法で引いたので、`SignatureExamples.Ix` の側を探して見つからなかった。(4) `induction … with` の選択肢に予約語 `opaque` を書いた。(5) `printCall_ty` の `simp` が `printCall.rs` を展開しなかった。(6) `print_obs_nil` で `io_target` の引数の操作名と範囲が推論されず、`admitsR` の証明に `trivial` を当てられなかった | (1) 成功値を明示した。(2) `injection` と `decide` にした。(3) `ixNoVar`・`vtyNoRVar` の関数名にした。(4) `«opaque»` と書いた。(5) `printCall` を `simp` に加えた。(6) 操作名・範囲・引数を明示し、`admitsR` を `simp` で示した。2回目は警告 1 件で終了0、警告を除いて3回目は出力なし |
| import の照合（新しい例の閉包）の1回目が終了1 | 一時ファイルに `import Lean` がなく、`CoreM` が未定義だった（既定の入口は推移的に `Lean` を含む） | `import Lean` を加えた。2回目は終了0 |
| 注釈の文の修正（失敗ではない） | `saveOp` の注釈に表層の構文の形を書いていた。表層の構文は本作業の範囲外で確かめていないので、文で書き直した | 4回目の単一ファイル・全体のビルド・公理の依存・work を最終の状態でやり直した |

## ずれと申し送り

計画からのずれ:

- 触るファイルは plan の `Scope/*Examples.lean` への例の追加ではなく、依頼文が許す新しい `Scope/SwitchExamples.lean` にした。L00.03〜.06 の模型を同時に import して一つの例の中でつなぐためである。
- plan の手順にない L00.06 の申し送り（NT・NV の比較と `GEff` の非 Top の例）を、L00.06 の「追加の点検の提案」の見込み（L00.07 の範囲で 0.5〜1時間）のとおり本作業に含めた。

停止条件: 該当しない。既存の定義と定理を変えておらず、`Builtins.Assumptions` に欄を加えておらず、主定理の前提・結論を変える必要は見つからなかった。

L00.08 への申し送り:

1. 範囲の変数の条件の置き場所 P1〜P5 の選択（`Ix` を採る場合）。UB10 の申し送り 1（`Ix` が (a) に有利）と、P3 が逆向きであることを並べて示す。
2. 値の所属の型付けの置き方 A・B（C は採れない）。格納方式によらず、L20.1 の枝の大きさを決める。
3. L00.06b・L00.06c の結果を、上の表の ‡・§ の行へ反映する。
4. 比較用の模型 `SwitchExamples` は二案の模型（`CompatExamples` を通して `RepresentationExamplesI`・`II`）を import する。採らなかった側の模型を消すときは、5 節の `oldTop_union_empty_I` または `_II` と、案 (i) の原子を使う `nonTopI` を合わせて直す。ほかの節は格納方式によらない L00.03〜.05 の模型だけを使う。
5. 3 節の `removeName`・`handledBound` は本番の `handled` の写しであり、採用定義にしない。最終の配置では本番の `handled` と節の効果の計算に置き換え、模型とともに削除するか `reviews/` の資料へ移す。

## 時間

| 項目 | 内容 |
|---|---|
| 開始・終了 | 19:52 開始、20:06 に終了（本書の作成と最後の work まで。外側約 14 分） |
| 能動時間 | 約 15 分（読む約 5 分、例と証明約 6 分、本書約 4 分。読みと設計の一部は重なる） |
| 検査・ビルド | 全体のビルド 2 回で計約 3 秒（待ち 計 3 秒）、単一ファイル 4 回 各 1 秒未満、公理 2 回・import の照合 3 回 各 1 秒未満、work 1 秒未満 |
| 見込みとの比較 | 見込み 30〜60分に収まった。上端の2倍（120分）を超えていない。区切りの提案はない |
