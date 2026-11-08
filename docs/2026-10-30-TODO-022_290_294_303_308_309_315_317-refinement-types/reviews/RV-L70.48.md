# RV-L70.48: L70 段末レビュー（ChatGPT Pro）の処置の独立レビュー

2026-11-08。対象はブランチ `m014/l70.48` の作業木（HEAD `f1ca09389`）と、基準 `fd280c1c0` からの差分である。本書の `<repo>` は対象の worktree、`<tmp>` は会話の scratchpad の `rv48/`、C は本書を置く改造ディレクトリ、R は `<repo>/formal/Benitoite/Release/Refinement/`、X は `<repo>/formal/Benitoite/Exchange/` を表す。本レビューは処置の確認の一回である。

読んだもの:

- [段末レビューと処置の記録](RV-L70-stage.md)（回答の全文と「取りまとめの判断と処置」）。
- 本体の作業木の依頼文 `work/m014/L70.48-lean-claude-prompt.md`・`L70.48-docs-claude-prompt.md` と報告 `L70.48-lean-claude-report.md`・`L70.48-docs-claude-report.md`。
- [l48/results-lean.md](../l70/l48/results-lean.md)、[stage-results.md](../l70/stage-results.md) の義務19と設計判断3・6、[h3/legacy-recheck.md](../l70/h3/legacy-recheck.md) の番号1・12。
- 本体の作業木の `plan.md` の確認点の先頭の三項目（2026-11-08 の段末レビューの処置の判断、所見6の設計者の決定、段末レビューの指示）と、docs/todo の TODO-332。
- Lean の差分の全部（`X/CanonicalNames.lean`・`X/CanonicalNamesExamples.lean`・`X/CheckInput.lean`・`R/EmbeddedLocalRefs.lean`・`formal/Benitoite.lean`）と、照合のために `R/TermSyntax.lean`・`R/ScopeSyntax.lean`（`FieldRef`）・`X/RefinedJson.lean`・`X/Syntax.lean`（`encodeTy`）・`X/Version.lean`・`X/Builtins.lean`・`X/Observe.lean`・`X/Refined.lean`・`X/CheckSupport.lean`、`R/Typing.lean` の `V_Checked`・`V_CheckedRequest`、`R/Surface/ScopeSound.lean`、`R/Surface/CheckVariance.lean`・`CheckTables.lean`・`CheckInfer.lean`・`CheckOpenInfer.lean` の `dropBound`、`R/StateTyping.lean`・`R/MainTheorems.lean`、`R/Embedding.lean`・`R/HiddenCaptureBoundary.lean`、7入口の `Main`。
- 01-12・07-04・`formal/README.md` の差分と、照合の台本 [verify.py](../l70/verify.py) の差分。

したことは、定義と文書の読み合わせ、名前の写しの JSON の経路の評価（`<tmp>/JsonRoute.lean`。既定ビルドの外）、所見6の両端の補題の試し（Lean の担当の一時領域の `ResultEndpoints.lean`）の再実行、段の照合 `verify.py` の実行である。Lean は `<repo>/formal/` から共有ロックの下で `lake env lean -M 12288 <file>` を一つずつ実行した（二本とも終了0）。`verify.py` は Lean の担当の一時領域（`--tmp` は L70.48 の段の書き出し、`--h2-tmp` は群 H2 の生の出力）を与えて実行し、終了0（`verified`、宣言 126,606、監査の名前 126,591、必須の名前 336、外側 98秒）だった。

`lake build`・`scripts/check.sh`・git の書き込み操作・サブエージェントの起動は行っていない。変更したリポジトリのファイルは本書だけである。

## 結論

**可。重0件、中0件、軽6件、情報4件である。**

段末レビューの6所見は全て処置された。所見2は、型付きの写し `CanonicalNames.fieldRef`・`term`・`slots`・`pred` が篩の述語の中の data と構成子の名前の全ての位置（`Term.dataValue`・`Term.field` の `FieldRef` の両欄・`Pred.constructorIs`）に掛かり、JSON の写しは欄 `predicate` と、述語の外の四つの欄だけの欄の参照をこの写しへ回す。述語の中にほかの名前の位置（効果・不透明型・範囲の名前）はない。JSON の経路は本書の評価でも、内部名の `List.tail` の結果型が標準の結果型と JSON で一致した。所見1は、閉包の data の段が `CheckVariance.metadata` の読む `requirements`・`publicBoundary` を辿り、義務19がレビューの修正案2の形に改められた。所見3・4の文書は今の Lean と一致する。所見5は旧の像に限った補題が置かれ、所見6は設計者の決定で TODO-332 に回り、01-12 に今の性質が書かれた。照合の台本の変更は照合を弱めていない。

残るのは記録と言い回しの軽い点である。例が述語の水準にとどまり、JSON の経路と数え直しの台本・両端の補題の試しが一時領域にだけある（軽1・軽2）。照合表の番号12の理由は、補題が到達先を扱わないと書きながら旧の結論を含むと述べ、何を回収したかが読み取りにくい（軽3）。処置の記録の場所の欄、Lean のコメントの節の名前、07-04 の `readVersion` に小さな誤りがある（軽4〜軽6）。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 軽1 | 軽 | `X/CanonicalNamesExamples.lean` の `tail_predicate_renamed`・`string_value_kept`、results-lean.md「2.」の JSON の試しの段落 | レビューが求めた確認の一つ目は「内部名で表した `List.tail` の署名が、変換後に標準署名と一致する」ことである。置いた例は型付きの述語 `pred` の水準で、署名（結果型の `refined (data …)` を含む）を JSON の写し `CanonicalNames.json` に通した一致と、照合 `standardCheck` に掛けた一致は既定ビルドにない。JSON の経路は Lean の担当が一時領域の `probe-names.lean` で確かめたとあるが、その試しは記録に残っていない。本書の評価（`<tmp>/JsonRoute.lean`）では、`tailNames.json (encodeTy internalTy) == encodeTy standardTy` が真で、値の文字列 `"data:199"` は JSON の経路でも写らなかったので、写しそのものの誤りではない | 試しの入力（`probe-names.lean`）を l48/ に写し、results-lean.md から相対リンクで引く。07-04 の「`Exchange.CanonicalNamesExamples` は…示す」に、例は型付きの述語の水準であり、JSON の写しと署名の照合での一致は既定ビルドの外の試しで確かめたことを一文で添える | 読めば確定（JSON の一致は実行で確認） |
| 軽2 | 軽 | results-lean.md「1. の件数」「6.」、docs/todo の TODO-332 | 数え直しの台本（`prep-all.lean`・`run.sh`・`tally.py`）、JSON の試し（`probe-names.lean`）、所見6の両端の補題の試し（`ResultEndpoints.lean`）は一時領域にだけあり、記録は SHA-256 か名前だけを引く。どれも 1〜6 KB で、AGENTS.md の「結果の根拠になる入力・出力・台本は改造のディレクトリへ写して相対リンクで引く」に当たる。特に `ResultEndpoints.lean` は TODO-332 の出発点であり、一時領域が消えると、両端の補題が通ったことを再現できない（本書で再実行し、終了0・`sorry` なしを確かめた） | 五つのファイルを l48/ の下（例: `l48/probes/`）に写し、results-lean.md の `<tmp>/…` の参照を相対リンクに直す。既定ビルドに入れない旨を同じ段落に書く。TODO-332 の出どころに写した `ResultEndpoints.lean` を加える（docs/todo は別のリポジトリなので、取りまとめがそちらで直す） | 読めば確定 |
| 軽3 | 軽 | h3/legacy-recheck.md の番号12の理由、同番号1の理由の「像の状態の捕捉は全て空」 | 番号12の旧の言明は、有限の遷移列の到達先についての不変条件である。足した理由の文は「補題は…像から実行した後の状態は扱わない」と書くので、引いた補題が覆うのは開始の像（遷移0回）だけである。一方、同じ行は前の文で「合成すると旧の結論を含む」と述べる。到達先で得られるのは型付きの捕捉の位置に限った新しい不変条件であり、`hidden_slot_read_localrefs` は型の付いた状態（`hidden_state_typed`）に隠れた位置があり得ることを示す。旧の遷移と新しい遷移の対応は証明しない（`embedState` の説明）ので、像から実行した到達先に隠れた位置が現れないことは示されていない。また、`embedState_capturesEmpty` が述べるのは最上位の捕捉（実行中の閉包・照合・枠・セル）であり、値の中の閉包（`embedHeldVal` が作る空の捕捉の閉包）は言明に含まない。`embedState_local_invariant` の第1の連言は任意の型付きの状態に成り立つ `StateTyE.local_invariant` そのものである | 番号12の理由を「到達先については、型付きの捕捉の位置の不変条件を回収する。旧の全位置の構文的な条件の到達先での回収は、旧と新の遷移の対応を示していないので含まない。補題は開始の像について、捕捉の位置がないことを示す」の趣旨に改める。判定を「導ける」のまま残すなら、この限定が判定の範囲であることを書く。番号1の「全て空」は「最上位の捕捉が全て空」に合わせる | 読めば確定 |
| 軽4 | 軽 | [RV-L70-stage.md](RV-L70-stage.md)「取りまとめの判断と処置」の所見6・所見1・所見2の「変えた場所」の欄 | 所見6の行は「01-12・07-04 の `StateTyE` の段落」とするが、07-04 は所見6のために変わっていない（差分は 01-12 の4284行付近だけ）。所見1・2の行の「07-04「交換と7入口」」は 07-04 の526行の表の行の見出しであり、変えた段落（64〜78行付近）は節「篩を含む形式化の範囲」にある | 所見6は、07-04 の保証の要約（「証明する性質」か371行付近の `MainTheorems` の段落）に、保存の定理が開始時の結果型と返却値の篩型を結ばないことを一文で足すか、表から 07-04 を除く。利用者が保証を読むのは 07-04 なので、前者を推す。所見1・2の場所は「07-04「篩を含む形式化の範囲」の `standardCheck`・`prepare_agrees` の段落」に直す | 読めば確定 |
| 軽5 | 軽 | `X/CanonicalNamesExamples.lean` の先頭のコメント（07-04「証明する性質」）、`R/EmbeddedLocalRefs.lean` の先頭のコメント（01-12「構築器の分類と環境の対応」） | 名前の写しの段落は 07-04 の節「篩を含む形式化の範囲」にあり、「証明する性質」（19〜51行）にはない。旧の像の局所参照の段落は 01-12 の節「篩を含む状態の型付け」（4292行付近）と 07-04「篩を含む形式化の範囲」（162行付近）にあり、「構築器の分類と環境の対応」（2819行）にはない。既存の `X/CheckInput.lean` の420行付近のコメントも同じく「証明する性質」を引いている | 二つのコメントの節の名前を直す。`CheckInput.lean` の既存のコメントも同じ変更で直すとよい | 読めば確定 |
| 軽6 | 軽 | 07-04 の788行付近（「交換の形式の版」の `Exchange.Refined` の段落） | 「この版の読み手は…前の版を版の誤りで断る（`readVersion`）」の `Exchange.Refined.readVersion` は、同じファイルの `example` だけが読み、7入口のどれも呼ばない。入口が使うのは `Exchange.Version.exchangeJson`（corpus 16・それ以外 8 の判定）と、`intervalDiff` の `corpusVersion` の照合である。所見3の処置で足した次の文はこれを正しく書くので、同じ段落の中で版の判定の関数が二つ名指される | 括弧の `readVersion` を `exchangeJson` に改めるか、`readVersion` は同じ版の番号を定める定義であり入口は `exchangeJson` で判定すると書き分ける | 読めば確定 |
| 情1 | 情報 | `X/CanonicalNames.lean` の `rewrite`・`fieldRefJson?` | JSON の経路を六つの入力で評価した（`<tmp>/JsonRoute.lean`）。(1) 内部名の篩付きの結果型が標準の結果型の JSON と一致。(2) 述語の中の値の文字列は写らない。(3) 述語の外の欄の参照も写る。(4) 述語の外の `constructorIs`・`dataValue` の構成子は従来の欄の名前の規則で写る。(5) `resultJson` は所属の data `Result` を保ち構成子を `Result.Ok` へ写す。(6) `Pred` として読めない欄 `predicate`（余計な欄を持つもの）は従来の経路へ落ち、写しは変えない。述語の中で写しの対象になる名前の位置は三つだけで、範囲の式の基準の名前・`targetValue` の起点・`Sort`・`Measure` は data・構成子・効果・不透明型の名前を持たない | なし | 実行で確認 |
| 情2 | 情報 | 07-04 の75行付近、stage-results.md の義務19 | 閉包の外の行が結果に効く経路は、変性の検査のほかに、準備の段の組込みの素材の形成（`CheckSupport.formedMaterials` が交換の表の全ての組込みを形成し、失敗で入力を断る）もある。07-04 は data の行と変性の検査を例に挙げ、「定理は、閉包の外の行と検査の結果の関係を述べない」と一般に書くので誤りではない。義務19の (a)「全表の形成と整合の検査」はこの形成も含む読み方ができる | R50 で義務19を閉じるとき、(a) に準備の段の全表の形成を含めることを明記するとよい | 読めば確定 |
| 情3 | 情報 | docs/todo の TODO-332 | results-lean.md「6.」は、両端の補題 `final_result_meaning` が前提に `P.VarianceValid` を要し、主定理の前提の `P.WellFormed` が含むかを項目を作るときに確かめる、と申し送った。TODO-332 の本文にこの前提の記述がない | TODO-332 に、返却の側の補題が `P.VarianceValid` を前提に取ることと、主定理の前提との関係を確かめることを一文で足す | 読めば確定 |
| 情4 | 情報 | [verify.py](../l70/verify.py) | 群 H3 の区間で許す変更に足したのは、`reviews/RV-L70-stage.md` と、改造の `plan.md`・`effort-ledger.md` の三つのファイルだけで、ディレクトリ単位の許可ではない。4b は B_WORK から作業木までの `formal/` の .lean の変更を一覧と完全一致で照らし、足したモジュールの既定 import への所属、L70.48 の監査の `sorryAx`・新しい公理・`axiom` の宣言0、必須の名前の群 `L48` への包含を確かめる。L70.48 の .lean は B_H2 からの差に入るので、段5のコメント・heartbeat・`sorry`・`#eval` の検査も受ける。群 `L48` の名前は段4で最終版の環境にあることを確かめられ、型・本体のハッシュの記録 `h3/required-L48.json` は出力の `compared` に入る（書き出しから作り直した内容と保存した内容の照合）。照合は弱まっていない。stage-results.md の件数（足した 52,733 と内訳、系統 7,001・1,281、最終版 126,606・125,604・1,002、モジュール 1,331・397、所属の変化 528、監査の名前 126,591、公理の組 53,872・37,699・3,790・31,214、コメントの検査 595 ファイル）は results-lean.md「段の記録の変化」と h3/audit-summary.json に一致する | なし | 実行で確認 |

## 段末レビューの所見の閉じ方

| 所見 | 重さ | 閉じたか | 根拠 | 本書の関係する所見 |
|---|---|---|---|---|
| 1 閉包の外の data の宣言 | 中 | 閉じた | `dataDeclStrings` が構成子の引数・`requirements`・`publicBoundary` の JSON の文字列を集め、`dataStep` がそれで data を加える。`CheckVariance.metadata` が読む欄（`requirements` を `.both`、`publicBoundary` を各極性で `ty` に掛け、`ty` が `P.varianceFor` を通じてほかの data を読む）と一致する。検査器の `checkPreparedProgram` は全件の変性の検査を保つ。義務19は (a) 全表の形成と整合と (b) 本体の型検査に分け、両表が (a) に成功する条件の下で (b) の閉包の上の対応を示す形で、修正案2の形である。07-04 は閉包の外の data の行が変性の検査を通じて結果に効くことと、定理がその関係を述べないことを書く | 情2 |
| 2 `FieldRef.owner` の写し | 中 | 閉じた | 型付きの写しが述語の名前の全ての位置に掛かる。`resultConstructors_lookup_twice`・`_fieldRef_twice`・`_term_twice`・`_slots_twice`・`_pred_twice` が入れ替えを、`_fieldRef_owner` が構成子だけの写しの所属の保存を示す。準備は同じ `names` を組込みの表・入力・標準ライブラリの宣言・演算子の表の全てに掛け、標準表の側は標準の名前のままなので、比べる両辺の名前の空間は一致する。`tail_predicate_renamed`・`internalSomeField_renamed` は内部名の述語が標準の `tailPredicate` と `someField` に写ること、`string_value_kept` は値の文字列を写さないことを `rfl` で示す | 軽1・軽5・情1 |
| 3 旧の記述 | 中 | 閉じた | 07-04 の要求を保持する値の段落は `V_Checked` の `B.valContent o = none` と `V_CheckedRequest` の内容の型での閉じた型付け・`groundVal req = true`・`req.reqTarget = some target` に一致する。01-12 の `acceptInput` は `none`・`some` の両方で `"Result.Ok"` とする本番の定義に一致する。Scope の解析の表の段落は `ScopeSound.agreed`（表の値が `pathPattern`（`ScopeDelta.parsePattern`）・`RequestDelta.parseHostPattern` の結果と等しいときだけ使う）と `agreed_sound`、表に条件を置かない `productionRules_sound` に一致する。交換の版の段落は、六入口が `exchangeJson`（`builtinCheck` は `readBuiltins`・`readCorpus` の中で）を通り、`intervalDiff` が `corpusVersion` を照合することに一致する。設計書の中に旧の言い回しは残っていない | 軽6 |
| 4 `dropBound` | 軽 | 閉じた | `dropBound` は外側に連続する `.refined` の層だけを調べ、束縛した値（1〜n の番号）を指す層を除き、ほかの層を残す。`.list` などの内側には入らない。`CheckOpenInfer` にも同じ定義がある。07-04・01-12・設計判断6の記述（外側に連続する層だけを除く、内側の篩は除かない、期待型のない位置で断られることがある、健全性には関わらない）は定義と一致する | なし |
| 5 旧の局所参照 | 軽 | 閉じた（言い回しに軽3） | 番号1・12の理由に限定の文と補題の名前が入った。補題は旧の像の最上位の捕捉が空であることと、型付きの像の `LocalStateInvariant` を述べ、隠れた位置の反例が像でないことも示す。補題が覆う範囲（開始の像、最上位の捕捉）と番号12の言明（到達先）の差の書き方が残る | 軽3 |
| 6 返却の篩型 | 情報 | 閉じた（TODO-332） | 設計者の決定（plan.md 2026-11-08）で TODO-332 に回した。01-12 の `StateTyE` の段落は、結果型を状態ごとに存在量化し、保存の定理が開始時の結果型と返却値の篩型を結ばないことを書き、`StateTyE` の定義と `preservation`・`steps_preservation` の証明（`StateTy` の `Eb` だけを取り出して渡す）に一致する。両端の補題の試しは本書でも通った | 軽2・軽4・情3 |

## 観点ごとの根拠

### 1. 所見2（名前の写し）

`Pred` の構成子は14、`Term` は20である。名前を持つ位置は `Term.dataValue` の構成子、`Term.field` の `FieldRef`（`owner : DataName`・`constructor : ConName`）、`Pred.constructorIs` の構成子の三つで、`pred`・`term`・`slots` がこの三つを写す。`compare` の `Sort`、`measure` の `Measure`、`member` の `RangeExpr`、`targetValue` の `PathEnv`・`Target`、`floatClass`・`charactersIn` は data・構成子・効果・不透明型の名前を持たないので、写しの漏れはない。効果の名前は述語に現れない。`term` と `pred` の最後の既定の枝は、それぞれ名前を持たない構成子と `truth`・`falsity` だけを受ける（`resultConstructors_term_twice` が残りの11構成子を `rfl` で列挙していることとも一致する）。

`constructorsOnly` の対応（`resultConstructors`）では、`fieldRef` は所属の data を保ち、構成子だけを写す。変更前の JSON の経路も構成子の欄だけを写していたので、`resultJson` の振る舞いは欄の参照の所属について変わらない。名前の写しの対応（`ofInputs`）では、所属の data を `dataNames` で写す点だけが変わる。

JSON の写しは、欄 `predicate` の値を `Pred` として読めたときだけ型付きの写しへ回し、読めなければ従来の経路へ落ちる。従来の経路でも、四つの欄だけを持つ対象は `fieldRefJson?` が欄の参照として写す。証明書（`Certificate`・`EqProof`）の中の項も、欄の参照は `fieldRefJson?`、構成子は欄の名前 `constructor` の規則で写る（情1の(3)(4)）。

比べる両辺: `prepareParts` は `names.json` を `b`・`input`・`s`・`operators` に掛けて照合用の表を作り、標準表（`StandardModel`）は標準の名前で書かれている。交換の入口の `exchangeJson` は corpus・builtins・stdlib・coverage-program に同じ `resultJson` を掛け、区間の入口も同じ写しを掛ける。

### 2. 所見1（閉包）

`DataEntry` の欄のうち、変性の検査が読むのは `variances`・`requirements`・`publicBoundary` と構成子である。`dataDeclStrings` は構成子・`requirements`・`publicBoundary` の JSON の全ての文字列を集めるので、ほかの data の名前（型の `data` の名前、欄の参照の `owner`、構成子の名前）を上へ近似で含む。値の文字列が data の名前と同じ綴りなら閉包が広がり、照合の対象が増える方向にだけ働く。

件数は前後とも 1,399 が通り 56 を断る。書き出しの data の宣言が `requirements`・`publicBoundary` を持たないので、今の入力で閉包が変わらないことは定義から読める。入力ごとの出力がバイト単位で同じという記録（SHA-256 一致）と矛盾しない。

義務19の書き直しは、検査器が全件の data に変性の検査を掛けることを残し、交換の表と完成表の双方が (a) に成功する条件の下で (b) を結ぶ形である。交換の表が (a) に失敗すれば検査器は断るので、閉包の外の行の影響は受理の側の健全性を損なわない。完成表が (a) に成功することは標準表の性質として一度示せばよい。修正案2の「使わない標準の行の差で本体の検査を妨げない」目的と整合する。

### 3. 所見3・4（文書）

07-04 の要求を保持する値の段落から、`ModelHttp` の拡大の δ に関する注意（拡大が同じ要求を保つことは `ModelHttp` の定理で証明済みとしない）が除かれた。新しい段落は、`reqTarget` と URL の解析の対応、Rust の検査・保持・射影・送信の経路を照合の事項に置くので、拡大の経路はこの「Rust の経路」に含まれると読める。誤りではないが、拡大を名指さなくなった。

01-12 の `acceptInput` の段落の「交換の読者は、Rust の書き出しが使う名前 `Ok` を、読むときに `Result.Ok` へ入れ替える」は、`exchangeJson` の最後の `resultJson` と一致する。

`dropBound` の条件 `p.VarsIn (fun i => i = 0 ∨ n < i)` は、自己変数と束縛の外の値だけを指す層を残す。01-12 の例（引数 n を指す篩を要素の型に持つ List）は、`.list` の内側の層を調べないことの例として正しい。

### 4. 所見5・6

`EmbeddedLocalRefs` の `State.CapturesEmpty` は、`run` の閉包、`matchRun` の捕捉、継続の全ての枠の捕捉（`letF`・`handleF`・`guardF` の二つ）、ストアの `thunk`・`cont` のセルの捕捉を対象とし、`val`・`done` のセルと値の中の閉包を含まない。`embedFrame`・`embedCell`・`embedState` は捕捉に `Capture.empty` だけを置くので、`embedCont_captures`・`embedStore_captures` の証明は定義の展開で閉じる。`hidden_capture_not_embedded` は反例の状態の最上位の捕捉が空でないことを示し、像でないことの十分な理由になる。軽3はこの補題の範囲と番号12の言明の差である。

`StateTyE` は `run`・`matchRun` で `∃ Ψ R a b e e1`、`error`・`exit` で `∃ Ψ R a b e` と結果型 `b` を存在量化し、`preservation` は `StateTy` から `Eb` を取り出して `step_preserved` に渡す。01-12 の追記はこの形と一致する。Lean の担当の `ResultEndpoints.lean` は、`StateTyR`（`b` を添字にした述語）、`StateTyE.iff_result`、`initial_result`、`final_result_meaning` を置き、`sorry` なしで終了0だった。

### 5. 照合と件数

情4のとおりである。stage-results.md の冒頭に、件数が L70.48 の作り直しの後の値であることを一文で足し、本文の「最終版の環境は…L70.48 の Lean の担当が足したモジュールを含む」と合わせている。

## 処置

2026-11-08。Lean の担当の分は [../l70/l48/results-lean.md](../l70/l48/results-lean.md)「確認の後の処置」、文書の担当の分は下の各行に書いた場所にある。

| 所見 | 処置 |
|---|---|
| 軽1 | Lean の担当が `Exchange/CanonicalNamesExamples.lean` に、組込みの表の行の形の署名（`tailRow`）を `CanonicalNames.json` に通した一致を、既定ビルドの中の実行比較 `#guard` として置いた。内部名の結果型の行を写すと標準の結果型の行と一致すること、値の文字列を写さないこと、写す前の行が一致しないこと（対照）を確かめる。JSON の写しは部分関数でカーネルの証明が止まるので、交換の例の既存の形（07-04 がカーネルの証明と区別して述べる、評価による確認）に揃えた。足した名前は4名（`tailRow`・`tailParams`・`internalTailRet`・`standardTailRet`）で、stage-results.md の件数をその後の値（宣言 126,610、足した 52,737、監査の名前 126,595）に直し、`verify.py` は verified |
| 軽2 | Lean の担当が、数え直しの台本・集計・JSON の試し・両端の補題の試し・照合の試しを `l70/l48/probes/` に写し、本文の参照を相対リンクに直した（results-lean.md「確認の後の処置」） |
| 軽3 | 文書の担当が `h3/legacy-recheck.md` の番号1・12の理由を書き分けた。番号12は、到達先では型付きの捕捉の位置の不変条件を回収し、旧の全位置の条件の到達先での回収は含まないこと、補題が扱うのは開始の像の最上位の捕捉であることを書いた。番号1は「最上位の捕捉は全て空」に合わせた。07-04・01-12 の `LocalInvariant` の段落も同じ趣旨に直した |
| 軽4 | 文書の担当が [RV-L70-stage.md](RV-L70-stage.md) の処置の節の「変えた場所」を直した。所見1・2は 07-04「篩を含む形式化の範囲」の段落、所見6は 01-12 の `StateTyE` の段落だけとした |
| 軽5 | Lean の担当が `CanonicalNamesExamples`・`EmbeddedLocalRefs`・`CheckInput.lean` の先頭のコメントの節の名前を直した（results-lean.md「確認の後の処置」） |
| 軽6 | 文書の担当が 07-04「交換の形式の版」の `Exchange.Refined` の段落を直した。版の番号は `corpusVersion`・`sidecarVersion` が定め、六入口は `Exchange.Version.exchangeJson` で判定し、`intervalDiff` は `corpusVersion` と照合すると書いた。入口から呼ばれない `readVersion` は名指さない |
| 情2 | 文書の担当が stage-results.md の義務19に、閉包の外の行が効く経路として準備の段の組込みの素材の形成（`CheckSupport.formedMaterials`）を書き、(a) にその形成を含めることを明記した |
| 情3 | Lean の担当が results-lean.md「6.」に、返却の側の補題の `P.VarianceValid` は主定理の前提 `P.WellTyped B` の欄 `variance` から得られることを書き、両端の補題の試しをその形に直した。docs/todo の TODO-332 の本文には、取りまとめがこの前提の関係と両端の補題の試しの場所を写した（2026-11-08） |
