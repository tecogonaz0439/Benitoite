# RV-L70.g: L70 群 G（7入口の切替・受理の規則・交換の照合・旧判断の削除）の独立レビュー（Lean・交換・試験）

2026-11-07。対象はブランチ `m014/l70.g` の HEAD `4823e272` で、`git log -1` の一致を確かめた。差分の基準は `05341b96`（`git diff 05341b96 HEAD`）である。L70.42（`crates/benitoite/tests/`）は RV-L70.g42 でレビュー済みなので、`git log 7ae7994c..HEAD -- crates/benitoite/tests` の3コミットの変更だけを見た。本書の `<repo>` は対象の worktree、C は本書を置く改造ディレクトリ、S は `<repo>/formal/Benitoite/Release/Refinement/Surface/`、X は `<repo>/formal/Benitoite/Exchange/` を表す。文書（01-12・07-04・`formal/README.md`）は別のレビュー担当が見るので、Lean の言明と食い違う箇所だけを挙げる。本レビューは本レビュー一回である。

読んだもの:

- 本体の作業木の依頼文 `work/m014/L70.g-prompt.md`・`L70.g2-claude-prompt.md`・`L70.g3-claude-prompt.md` と、報告 `L70.g-claude-report.md`・`L70.g2-claude-report.md`・`L70.g3-claude-report.md`。
- [群 G の結果](../l70/g/results.md)の全体、[exchange-contract.md](../l70/g/exchange-contract.md)・[modules-for-spec.md](../l70/g/modules-for-spec.md)・[ok-name-inventory.md](../l70/g/ok-name-inventory.md)・[scope-rules.md](../l70/g/scope-rules.md)・[f09.json](../l70/g/f09.json)・[verification-g2.json](../l70/g/verification-g2.json)・[entries-closure.json](../l70/g/entries-closure.json)。台本 [f09.py](../l70/g/f09.py)・[verify_g2.py](../l70/g/verify_g2.py)・[graph.lean](../l70/g/graph.lean)。
- 本体の作業木の `plan.md` の「計画の変更と取りまとめへの確認点」の先頭から、2026-11-07 の群 G・群 D・L70.42 の全項目。
- Lean: X の `CheckInput`・`BuiltinAgreement`・`CanonicalNames` の全文、`Observe` の受理の入力、`Convert` の演算子の表、`Syntax` の `Expr` の符号化と `OperatorEntry`。S の `ScopeRules`・`ScopeSound` の全文と、基準版の旧 `Surface/ScopeState`・`Surface/ScopeSound` の対応部分。S の `CheckBuiltinSource`・`CheckInput`・`CheckPreparation`（`enabled`・`prepare`・`prepare_custom`）・`Basic`（`DictEv.inScope`）・`CheckInfer`・`CheckOpenInfer`・`CheckInferCertificates` の差分、`Check.lean` の `E_Binary`・`E_Neg`、`CheckAccept.checkProgramAccepted_sound`・`CheckMaterialsSound`・`CheckDeclarationBase` の前提。入口の `SurfaceCheck/Main.lean`・`SurfaceCheck/Batch.lean`。`R/ScopeDelta.resultValue`。
- 試験: `formal/tests/` の `test_width_exchange`・`test_try_exchange`・`test_batch2_exchange`・`test_named_exchange`・`test_extensible_exchange`・`test_range_rejections`・`test_range_sources`（分類の表）・`test_batch5_exchange` の差分、`crates/benitoite/tests/desugar_export/check_named.py` の差分（7ae7994c 以後）と `exchange.rs` の `con_name`。

実行したこと:

| 対象 | 結果 |
|---|---|
| `cargo test -p benitoite --test desugar_export --test coverage_export` | 終了0（脱糖 49通過・1無視。外側20秒） |
| 固定入力の試験 `test_width_exchange`・`test_try_exchange`・`test_batch2_exchange` | どれも OK（4・8・8試験） |
| 固定入力の試験 `test_named_exchange`・`test_extensible_exchange` | 失敗10・1。全て `Pair.left (fn:12): definition.header.ret`（取得関数の結果型の篩、R10b に分類済み）で、results.md の記録と同じ |
| `verification-g2.json` の対象と、`git diff --name-status 05341b96 HEAD -- formal/` の削除以外の `.lean`（試験を除く）の照合（読み取りの短い台本） | 両者は一致した（足した16・変えた52、差0） |
| `git diff 05341b96 HEAD` の追加行の `implemented_by`・`@[extern]`・`unsafe`・`native_decide`・`ofReduceBool` の検索 | 0件。`@[csimp]` は `holeLam_eq_decide`（等号を証明した置き換え）の1件だけ |
| `git diff --name-only 05341b96 HEAD -- crates/benitoite/src` | 0件 |

`lake build`・`lake env lean`・`scripts/check.sh`・`scripts/check-formal.sh`・named-programs の検査の本体・git の書き込み操作は行っていない。変更したリポジトリのファイルは本書だけである。

## 結論

**条件付き可。重0件、中2件、軽7件、情報6件である。**

受理の規則の移植は旧の規則と健全性の形を保ち、成功値の名前の写しで `productionRules_sound` は `Result.Ok` について中身のある主張になった（情1）。`prepare_sound`・`prepare_entry`・`prepare_agrees` は記録の主張どおりの言明で、隠れた強い前提はない（情2）。F09 の照合は主張を裏付け、自動生成の補題の差の許しは他の差を隠さない（情4）。公理監査の対象は群 G の全モジュールと一致し、`sorryAx` と新しい公理は0である（情5）。処理系の本体の差分は0である。

条件は中2件の処置である。

- 中1: 標準表との一致の判定は data の宣言の中身を比べない。`Closure.data` は作るが読まれない。07-04 の「data の宣言の差は、その data を署名に持つ組み込みの関数の署名の差として断る」は、名前の写しが偶然に失敗した場合（構成子の数が違う ordinary の標準の data）にしか成り立たない。
- 中2: 準備の段の拒否を分類する照合の台本は、`surfaceCheckAll` が一入力でも分類済みの拒否を出すと、その文書の残りの入力の比較（不一致・末尾の照合の件数・分類の理由）を丸ごと読み飛ばす。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 中1 | 中 | X/`CheckInput.lean` 82〜115行（`Closure.data`・`closureOf`）・391〜394行（`standardCheck` の呼出し）、X/`BuiltinAgreement.lean` 32〜42行（`ShapeEq`）、X/`CanonicalNames.lean` 139〜156行（`standardData`）、07-04 67行「data の宣言の差は…断る」 | 判定 `standardCheck` は `closure.prims` の組込みの署名の欄（`ShapeEq`）だけを比べる。署名の型は data を名前と型引数で指すだけで、構成子の集まりと構成子の引数の型は比べない。`Closure.data` には本番の読者がない（`closure.data` の読み出しは0件）。一方、検査器は構成子の表を交換の `b.dataDecls` から作る（277行）。そのため次の差は判定を通る。(a) 標準ライブラリの ordinary の data で、構成子の名前と数が標準と同じで、構成子の引数の型だけが違う宣言（`standardData` は名前と数だけを照らし、写しが成功するので、署名は一致する）。(b) `builtin` が `result`・`option` の data では、`standardData` が構成子の数を照らさない（148行の `info.builtin != .ordinary ∨ …`）。交換の `Result` が構成子 `Error` を欠いても `Result` へ写り、`Result.Ok` の腕だけの照合が交換の表の下で網羅的と判定される。取りまとめが At を緩めない理由に挙げた「構成子の足りない交換の表の下で網羅性を誤って受理しうる」形が、`Result`・`Option` では判定に捕まらない。At の差が捕まったのは、構成子の数の違いで写しが失敗し、署名に交換の内部名が残ったためである。処理系の今の書き出しで (a)(b) が起きる例は見つけていない。`prepare_agrees` の言明は署名だけを述べるので、定理の誤りではない | 次のどちらかを選ぶ。(i) `closure.data` の各 data について、写した交換の宣言（構成子の名前の集合、各構成子の引数の型、`ntys`）を標準の宣言（`StandardModel.declarations` の行）と比べる有限の判定を `standardCheck` に加え、`Prepared` にその成功の事実を持たせる。`standardData` の builtin の場合にも構成子の数を照らす。(ii) 比べないままにするなら、07-04 の該当の文を「data の宣言の中身は比べない。差が署名の名前の違いとして現れる場合だけ断る」に直し、`Closure.data` を除くか読者を置き、R50 の義務の表に「照合の対象の data の宣言と完成表の data の表の一致」を足す。(i) は判定を厳しくする側で、処理系の正しい書き出しを断るかは F-REG の前に固定入力で確かめる | 読めば確定（判定の欄・写しの条件・読者の検索）。(b) の網羅性の誤受理は実行していない |
| 中2 | 中 | `crates/benitoite/tests/desugar_export/check_named.py` の `run_surface`（とその `check_named`・`check_width`・`check_programs` の `surfaceCheckAll` の呼出し）、`formal/tests/test_batch2_exchange.py` の `surface_gaps`、`formal/tests/test_batch5_exchange.py` の書き出しの照合（250〜262行）、`formal/tests/test_batch3_exchange.py` の同じ形、`SurfaceCheck/Batch.lean` 252〜254行 | `surfaceCheckAll` は準備の失敗が一件でもあれば、他の入力の不一致や `q11Agrees` に関わらず終了2を返す。台本は、終了2で `preparationErrors` が全て分類の表の原因なら、報告を `None` として `counts`・`outcomes`・`nonTopRanges` の照合を全て飛ばす。named-programs（1,373入力のうち31が分類済みの拒否）では、`check_programs` の `surfaceCheckAll` の照合（`surfaceCounts`・`surfaceOutcomes` の分類の理由）が F-REG で一度も働かない。各入力の受理は同じ関数の単独の `surfaceCheck` の繰り返しで確かめるので、受理と拒否の入れ替わりは捕まる。しかし単独の入口は末尾の照合の件数（`q11Agrees`・`tailMatches`）を照らさない。今回の `request-in` の `tailMatch [0,0]` の書き出しの誤りは `surfaceCheckAll` の `q11Agrees` が偽になって見つかった種類であり、同じ文書に分類済みの拒否が一件あると隠れる。batch2・batch3・batch5 の書き出しの照合も同じ形である | 分類の経路でも報告を読み、次を要求する。`counts.mismatched == 0`、`q11Agrees` が真、`counts.preparationFailure == len(preparationErrors)`、`counts.matched + preparationFailure` が期待の件数（named-programs なら `surfaceCounts` から拒否の分を引いた値）。`outcomes` の比較は、拒否した入力の定義を除いて行う。あわせて、分類した拒否の件数が予期した上限（F-REG の表の件数）を超えたら失敗にする | 読めば確定（終了状態の決め方と台本の分岐）。隠れた不一致が今あるかは実行しないと分からない |
| 軽1 | 軽 | X/`CheckInput.lean` 106〜115行の `closureOf`、X/`Syntax.lean` の `encodeExpr` の `.neg`、S/`Check.lean` 524行の `E_Neg` | 単項の負号は交換の JSON で `{"neg": {…}}` と欄の名前だけに現れ、`jsonStrings` は欄の名前を数えない。演算子の表の `op` が `"neg"` の行の組込み（`Integer32.negate` など）は、`used` の中の `"neg"` からは閉包に入らない。検査器は `E_Neg` で `q.opPrim .neg t` の組込みの署名を読む。今は、同じ定義の `core`（処理系の脱糖の期待）が `{"prim": {"name": "…negate"}}` を持つので、その文字列から閉包に入る。閉包が上への近似であることは、検査器が読む全ての組込みの名前が入力に文字列として現れることに依っており、その一つが期待のコアという比較の対象の側にある。07-04 の「参照の数え方を広い側に倒して判定を緩めない」はこの依存を述べない | 演算子の表の全行の組込みを閉包に入れる（表は小さい）か、`Expr` の欄の名前 `neg`・`binary` を見たときに対応する `op` を `used` に足す。R50 の義務「検査器が閉包の外の行を読まないことの接続」の言明は、この修正の後の閉包について立てる | 読めば確定（符号化と `jsonStrings` の定義）。閉包の値は評価していない |
| 軽2 | 軽 | X/`BuiltinAgreement.lean` 143〜145行の `composedNames`、X/`CheckInput.lean` 391〜394行 | 閉包の組込みのうち、写した名前が標準表の合成済みの名前でないものは、仮定側の名前として何とも照らさない。名前の写し（`primitiveAliases` の有限表）から漏れた標準の組込みや、処理系の書き出しの名前の誤りは、判定を黙って通る。手書きの固定入力の `prim:8` のような内部名も同じである | 閉包の組込みのうち合成済みでない名前の件数と一覧を `Prepared` と報告に残し、F-REG で既知の仮定側の名前の一覧（`NameLists` の仮定側）に含まれない名前があれば数える。R50 の申し送りに一行足す | 読めば確定 |
| 軽3 | 軽 | X/`BuiltinAgreement.lean` 1〜10行の冒頭の説明 | 「名前は交換の名前のまま照らし」は、今の `prepareParts`（`CanonicalNames.ofInputs` で写した表で照らす）と合わない | 「交換の内部名を標準の名前へ写した照合用の表で照らす」に直す | 読めば確定 |
| 軽4 | 軽 | X/`BuiltinAgreement.lean` 113〜124行の `admits_normKey`、101〜111行の `sat_normKey` | 正規化の正しさを支える二つの補題に本番の読者がない（`sat_normKey` の読者は `admits_normKey` だけ、`admits_normKey` は0件。`CheckInput.lean` 385行のコメントが名前を引くだけ）。補題の言明自体は正しく、`satB_normKey` は `TParam` の二つの真偽値の四つの場合の `rfl` で閉じる。`prepare_agrees` は正規化した `canonicalSig` について述べるので、検査器の表の制約の意味が完成表と同じであることへ繋ぐには、R50 でこの補題が要る | `prepare_agrees` に系を一つ置き、閉包の合成済みの名前で、正規化前の写した署名の `admits` の意味が完成表の署名の制約と同じことを `admits_normKey` から述べる。置かないなら、R50 の義務の表でこの補題を読者として名指しする | 読めば確定 |
| 軽5 | 軽 | `formal/tests/test_named_exchange.py` の `test_checker_rejects_false_contracts`、`test_extensible_exchange.py` の網羅しない照合の拒否、`test_try_exchange.py` の `test_checker_checks_exchanged_die_contracts`、`test_batch2_exchange.py` の `test_checker_rejects_wrong_error_and_dictionary`、results.md「3. 固定入力の試験」の「変更前も変更後も同じ入口で拒否する（終了状態が同じ）入力…に限った」 | (1) 期待の理由の多くが、別々の誤り（ラベル・位置・部分適用・穴・パイプ・コールバック・網羅しない照合・束縛・誤りの型）から一つの総称の文 `type or certificate check failed` に変わった。終了1と位置は照らすので受理と拒否の入れ替わりは隠さないが、検査器が意図した理由と別の理由で断る後退を区別できなくなった。(2) `operator` の場合は終了1（検査器の拒否）から終了2（準備の段の標準表との照合の拒否）に変わった。拒否のままだが、results.md の「終了状態が同じ」の記述と合わない。検査器自身は演算子の組込みの引数名の偽りを断らなくなり、仮定側の名前の演算子では捕まらない | (1) 総称の理由の試験には、同じ入力から誤りを一つだけ除いた対照（受理）を各場合に置くか、検査器の報告に案内の再検査のどの段で落ちたかの副理由を足して照らす。(2) results.md の文を「拒否のまま。演算子の偽りの1件は準備の段の拒否（終了2）に変わった」に直し、仮定側の演算子の名前で同じ偽りを断るかを一件確かめる | 読めば確定（差分）。(2) の仮定側の場合は実行していない |
| 軽6 | 軽 | C/`l70/g/graph.lean`、results.md「4. L70.44 削除の適用と F09 の三条件」 | F09 の照合に使った宣言グラフの書き出しの台本は、`mod.startsWith` の部分適用を直した写しを一時領域で使ったと記録され、改造に置いた `graph.lean` は直す前の版のままである（`.any mod.startsWith`）。7入口の個別のグラフを作る import の形も改造にない。`f09.json` の入力の SHA-256 はあるが、改造の台本だけからは作り直せない | 使った版の `graph.lean`（7入口の import の違いを引数にした形）を改造へ写し、`f09.json` にその SHA-256 を足す | 読めば確定 |
| 軽7 | 軽 | S/`CheckPreparation.lean` 14〜17行の `enabled`、X/`CheckInput.lean` 443〜459行の `prepare_entry`、results.md の F-REG への申し送り | `prepare_entry` が示す「実入口の準備が恒等」は、交換の7入口が群 D の名前解決（篩の述語の呼出しと射影の内部行の収集）を一度も通らないことを意味する（`.custom` では `enabled` が偽）。篩の中で利用者の述語を呼ぶ入力を交換で検査すると、内部行なしで検査するので、処理系が受理し Lean が断る差になりうる。F-REG への申し送りの表にこの形がない | F-REG への申し送りの表に「篩で述語を呼ぶ入力は、交換の入口では内部行の準備を通らない」を一行足し、該当する入力の件数を F-REG で数える。交換の表に内部行を足す経路が要るかは R50 の判断とする | 読めば確定（`enabled`）。該当する入力の有無と結果は実行しないと分からない |
| 情1 | 情報 | S/`ScopeRules.lean`・S/`ScopeSound.lean`、X/`Observe.lean` 227〜253行 | 受理の規則の移植は意味を弱めていない。`okPayload`・`CheckedModels`・`ResultModels`・`factModel`・`LitModels`・`argIndex`・`CheckSpec.BoundSound`・`CheckSpec.Contract`・`checkRule`・`checkRule_sound` は、旧 `Surface/ScopeState` の定義と、値の型（`Refinement.Val`）と解析の引数の分け方（`Parsers` の代わりに `pattern`・`target`・`known`）を除いて同じ形である。`pathCheck_boundSound` の前提 `known s = some r → pattern s = some r` は、`agreed` で作る既知の範囲では `agreed_sound` から定義どおりに成り立ち、健全性に表の条件は残らない。成功値の名前は、`acceptInput` が `ok := "Result.Ok"` を渡し、実例の表の δ は `ScopeDelta.resultValue true` が `.con "Result.Ok" …` を返すので、`modelTargets_contract`・`modelHttp_contract` の `Ok` の場合は実際に通る経路である（`ok := "Ok"` のときのような空の主張ではない）。旧の接続定理（`scope_check_connection` 系）は移していないが、plan.md の判断で群 H の監査の対象になっている | なし | 読めば確定 |
| 情2 | 情報 | X/`CheckInput.lean` 206〜233行の `Parts`、426〜478行の三つの定理、`SurfaceCheck/Main.lean` | `prepare_sound` は、準備が成功した `Prepared` の `input` について `Check.Input.Sound` を結論にし、前提は準備の成功だけである。`Parts` の証拠（支持・`satDecOf_sound` などの判定の健全性・演算子の支持）は準備の中で構成している。入口は `prepared.input` をそのまま `checkProgramAccepted` に渡す。`prepare_entry` の恒等は `prepare_custom` から定義どおりに従う。`prepare_agrees` の前提は `L.WF` だけで、`T`・`A` は任意である。ただし次の三点を後段への申し送りに書く。(1) 交換の表の許容の命題は判定の真偽で定義するので、`Sound` の判定の欄は定義から成り立つ（交換した表の下での健全性）。(2) `Materials.checkProgramAccepted_sound` で受理から型付けを得るには、`Sound` のほかに本体の支持 `DefSupport`・`ImplSupport`（`BlockSupport`）が要り、交換の準備はそれを示さない。7入口の成功から型付けまでを閉じる定理はまだない。(3) `prepare_agrees` は照合用の表について述べ、検査器の表との対応は述べない（記録どおり） | R50 の義務の表に (2) を足す | 読めば確定 |
| 情3 | 情報 | X/`CanonicalNames.lean` 286〜293行の `resultJson`、X/`Version.lean` 225行、`Interval/Exchange.lean` 733行、`crates/benitoite/tests/desugar_export/exchange.rs` の `con_name` | 成功値の名前の入れ替えは、交換の文書の読み込みの一か所（`exchangeJson`、網羅性の独立の文書を除く）と区間の交換の読者で一度だけ行う。処理系の書き出しは、標準の `Result` の構成子0だけを `Ok` と書き、他の構成子（`Error` を含む）と利用者の構成子は `con:N:tag` と書くので、利用者の構成子 `Ok` を標準の成功値と取り違えることはない。期待（コア・区間の値・網羅性の文書）も同じ文書の中にあり同じ写しを受けるので、比較の両辺の写しは揃う。手書きの固定入力で利用者の data に `Ok`・`Error` を使う入力を足すと、標準の名前に写る点だけが注意である | 手書きの固定入力の README か `resultConstructors` の説明に、構成子の名前 `Ok`・`Error`・`Result.Ok`・`Result.Error` を標準の Result の外で使わないことを書く | 読めば確定 |
| 情4 | 情報 | C/`l70/g/f09.py`・`f09.json`、`entries-closure.json` | F09 の三条件の照合は主張を裏付ける。削除した146モジュールは既定の import と7入口のどのグラフにもなく（`present` の検査）、旧判断（41名）への逆戻りは既定と7入口で0である。自動生成の補題の差の許し（`eq_N`・`eq_def`・`_sparseCasesOn_N.else_eq`）は、名前が一致する行の差を誤りにしないだけで、許した行は入口の環境の行（その依存）で置き換えてから同じ逆戻りと削除の検査にかける。したがって他の差を隠さない。許した件数は入口ごとに318〜446件で記録されている。7入口の依存の照合も `pass: true` である | なし | 読めば確定（台本）。グラフの書き出しは軽6 |
| 情5 | 情報 | C/`l70/g/verify_g2.py`・`verification-g2.json` | 公理監査の対象（足した16・変えた52モジュール、11,788宣言）は、`05341b96..HEAD` の Lean の差分（削除と試験を除く）と一致した。最後の Lean の変更は `f7de1668` で、監査はその後に行われ、`4823e272` は Lean を変えていない。`sorryAx` と新しい公理は0で、`implemented_by`・`native_decide` の類の追加もない。`verify_g2.py` の版の固定（`GROUP_TIP`・`MERGE`）は、`e1b5b847..dc22b231` の間の L70.42 の Lean の変更を `git diff MERGE` 側で拾っており、結果として漏れはない | なし | 実行で確定（対象の照合） |
| 情6 | 情報 | S/`Basic.lean` 146〜158行、S/`CheckInfer.lean`・`CheckOpenInfer.lean` の `funDicts`・`opDicts`・`methName`、S/`CheckInferCertificates.lean` の `inferDict` | 節の辞書の番号の確かめは、交換の入力だけを狭める。`ClauseScope.slot` の番号は `0 ≤ i < dictCount` で、処理系の書き出しはこの範囲だけを持つので、正しい入力を断らない。`methName` の受け手の辞書と `tryResultDie` の辞書は `inferDict` を通るので、`guard` で同じく断る。型付けの規則と健全性の証明は変わらない | なし | 読めば確定 |

## 重点ごとの根拠

### 1. 受理の規則の移植

情1のとおりである。新しい `ScopeSound.productionRules` は、検査の二項目に実例の表の δ（`deltaRun ModelTargets.builtins checkPathName` など）を、射影と拡大の四項目に同じ名前の δ を使う。旧は拡大を `widenRule`、パスの射影を値なしにしていた。射影と拡大の規則は添字と転送だけを読み、受理は実行を読まないので、受理の結果は変わらない。表と形式化の解析が食い違う項目を未知（Top）にする `agreed` は保守的な側で、scope-rules.md の F-REG への申し送りに件数を数える指示がある。

### 2. 7入口の保証

情2のとおりである。`prepare_sound` は `Parts.sound` を経て `Materials.input_sound` に、準備の中で形成した支持と判定の健全性を渡す。`prepare_entry` は `Parts.custom : base.builtinSource = .custom table` と `prepare_custom` から恒等を得て、`prepare_sound` の結論を書き換えるだけである。`prepare_agrees` は `Parts.agreement`（`standardCheck_sound` の結論）を `agrees_complete` に渡す。`agrees_complete` は合成済みの名前で `standardSig n = some row.signature` を作り、`complete_sig` と `signatureWith_shape` で完成表の行へ移す。どれも `sorry` や仮定の追加はない。

### 3. 照合の対象 `closureOf`

組込みの名前は、入力の JSON に値として現れる文字列と演算子の表の `op` で数える。検査器が名前を固定して読む組込みは、`Check.lean` の `E_Binary`・`E_Neg` の `opPrim` と、入力に文字列で現れる `primName` だけである（`B.sig` に名前の定数を渡す箇所は表層の検査器になかった）。`binary` の `op` は値の文字列なので数えられる。`neg` は欄の名前なので数えられず、期待のコアに依存する（軽1）。data は閉包を作るが判定で読まず、data の宣言の中身は比べない（中1）。効果の名前・範囲付きの型の欄（`effects`・`effKind`・`valKind`・`valContent`・`admitsR`）は判定の対象外であり、07-04 と results.md がそう書いている。

R50 の義務「検査器が閉包の外の行を読まないことの接続」の送り方は、言明の形として妥当である。ただし、今の閉包の定義のままでは軽1の経路で接続が成り立たないので、閉包を直してから義務を立てるのがよい。中1の data の宣言の一致も同じ義務の表に足す必要がある。

### 4. 照合の正規化

- 名前の写し（`CanonicalNames.ofInputs`）: 写しは `put` と `noCollision` で単射に保たれ、ordinary の data は標準ライブラリの宣言（`package == "stdlib"`）に限る。検査器の表は写さない。写しが意味のある差を隠すのは中1の (b) の場合（builtin の data の構成子の数を照らさない）である。
- 成功値の名前の入れ替え: 情3のとおり、両辺に同じ写しをする。
- 鍵の印の正規化: `normKey` は鍵の印を持つ制約だけを `{ key := true }` にし、`satB_normKey` は四つの場合の `rfl` で閉じる。`sat_normKey`・`admits_normKey` の言明は正規化が制約の意味を変えないことを正しく述べる。正規化は照合用の表の側だけで、検査器の表は変えない。補題の読者は軽4。

### 5. 実行できる checker（案 (a)）

`BuiltinSource.standard`・`.predicates` は、構成した表とその構成の等号（既定値 `by rfl`）を持つ。等号の欄が表を一意に決めるので、`builtins` の値は前と同じであり、規則と `Input.Sound` の意味は変わらない。`predicateOverlay` は `noncomputable` を除いただけで本文は同じである。`.standard P` の既定値は非計算的な `StandardModel.builtins` を評価するので、`.standard` の入力を作る側は実行できないが、交換の7入口は `.custom` だけを使うので影響しない。

### 6. 節の辞書の証拠の番号の範囲

情6のとおりである。

### 7. L70.44 の削除

情4のとおりである。削除の計画（146モジュール・42コマンド）と `deletion.py --verify-applied`、`entries_closure.py` の `pass: true`、`admit` の0件は記録で確かめた。台本の再実行はしていない。

### 8. 試験の期待の変更

拒否の期待の変更は、終了状態を照らしたまま理由と位置を新しい検査器のものにした形であり、受理と拒否の入れ替わりを期待の変更で隠した箇所は見つけなかった。旧版の読み分けの試験は、版の拒否の試験に置き換わった（旧版を読まなくなったことに合う）。弱くなった点は軽5である。分類の表 `test_range_sources.py` の `preparation_gaps` は、拒否の文の名前が全て表にあるときだけ分類し、それ以外は `None` を返して呼出し側が失敗にするので、未分類の準備の失敗は通さない。ただし分類した後の扱いに中2の穴がある。named・extensible の固定入力の試験は R10b の差で失敗のまま残っており（実行で確かめた）、作業末の work の検査では失敗として現れる。

### 9. 公理と sorry

情5のとおりである。

### 10. 処理系の本体

`crates/benitoite/src/` の差分は0件である。

## 処置

2026-11-07、群 G の三人目の Claude の担当。基準は `4823e272`。作業末の検査の結果は [results-claude.md](../l70/g/results-claude.md) の「RV-L70.g の処置」にある。X は `formal/Benitoite/Exchange/` を表す。

| 番号 | 処置 | 場所 | 理由 |
|---|---|---|---|
| 中1 | 修正案 (i) を採った。閉包の標準ライブラリの data（`Prepared.standardData`）について、標準の宣言と同じ名前の data は構成子の数・型引数の数・同じ名前の構成子の引数の型（`tysEq`）を照らし、写らなかった data で表示名が標準の宣言に対応するものは差とする。builtin の Result・Option も同じ照合を受けるので、構成子の欠けを断る。`prepare_agrees` の結論に `DataListAgrees` を足した。数え直しで `At` が9入力から22入力になり（data `Scope.ScopeError` の差）、ほかの新しい拒否はない | X/`BuiltinAgreement.lean`（`DataAgrees`・`dataCheck`・`dataCheck_sound`・`DataListAgrees`・`dataDisagreements`）、X/`CanonicalNames.lean`（`displayCounterparts`）、X/`CheckInput.lean`（`prepareParts`・`Prepared.standardData`・`prepare_agrees`） | 判定を厳しくする側で、処理系の正しい書き出しを断った入力はない（新しく断った13入力は全て ScopeError の At の差）。利用者の data は名前が同じでも照らさない（固定入力の利用者の `Pair`）。構成子の順序は比べない（`Option` の順序が処理系と標準で違う）。`tysEq` を等号にする標準の宣言の支持は R50 の義務にした |
| 中2 | 修正案のとおりにした。分類した拒否があっても、残りの入力の不一致0・準備の失敗の件数・末尾の照合の件数（拒否した入力を除く定義の注釈の和）を要求し、期待の件数と分類の理由は断った入力の分を除いて照らす | `formal/tests/test_range_sources.py`（`classified_all`・`surface_checks`）、`crates/benitoite/tests/desugar_export/check_named.py`（`run_surface`・`remaining_counts`）、`formal/tests/test_batch2_exchange.py`・`test_batch3_exchange.py`・`test_batch5_exchange.py`・`test_range_rejections.py` | 予期した上限で失敗にする案は採らず、件数を記録に残した（分類の表にない原因は既に失敗になる） |
| 軽1 | 期待の核（欄 `core`）を除いた部分で数え、演算子は欄の名前（`neg`）でも数える。全ての data を並べる `dataTypes` と、全ての実装を並べる `impls` は種から外し、名前が入力に現れる実装の宣言だけを数える | X/`CheckInput.lean`（`surfaceWords`・`closureOf`） | 閉包が期待の核に依らず、検査器が読む演算子の組込みを含むようにする。属性と実装の表を種に入れると全ての入力が全ての data を照らし、中1の照合が ScopeError で全ての入力を断る |
| 軽2 | 断らず、`Prepared.unknownBuiltins` と `surfaceCheck` の報告の欄 `unknownBuiltins` に残した（取りまとめの判断と違う。取りまとめに判断を求める） | X/`CheckInput.lean`、`formal/SurfaceCheck/Main.lean` | 断る形で試すと、標準表が仮定側として持たない組込み（`%Boolean.toString`・`TaskGroup.open`・`Json.*` など）を使う入力（named-programs の20入力の試しで15）と、手書きの固定入力の内部名の組込みを全て断った。標準表の合成済みの行がこれらの名前を持たないので、止める条件の「合成表が満たさない前提」に当たると判断した |
| 軽3 | 冒頭の説明を、写した照合用の表・data の照合・鍵の印のそろえに合わせた | X/`BuiltinAgreement.lean` 冒頭 | 修正案のとおり |
| 軽4 | `prepare_constraints` を置いた。照合の署名は写した表の署名の `normKeys` であり、`admits` の意味が同じことを `admits_normKey` から述べる | X/`CheckInput.lean`（`prepare_constraints`、`Prepared.canonicalRawSig`、`Parts.canonical_eq`） | 修正案のとおり |
| 軽5 | (1) 検査器は再検査の失敗を `type or certificate check failed` 一つで報告し、具体的な理由を返さないので、期待は変えていない。(2) results.md の「終了状態が同じ」の文を、演算子の偽りの1件が終了2に変わったことを書く形に直した。演算子の組込みは標準表の合成済みの行で、照合が引数名を比べて断る | results.md「3. 固定入力の試験」 | 取りまとめの判断（具体的な理由を返す場合だけ書き直す） |
| 軽6 | F09 で使った版の `graph.lean` に直し、入口ごとの8件の入力を作る台本 `graph_inputs.py` を置いた。作った8件は前の担当の入力とバイト単位で一致した。`f09.json` に `graph_script` を足した | C/`l70/g/graph.lean`・`graph_inputs.py`・`f09.json` | 修正案のとおり。グラフは置かず大きさと SHA-256 を残す |
| 軽7 | F-REG・R50 への申し送りの表に足した | results-claude.md「F-REG・R50 への申し送り」 | 修正案のとおり |
| 情1 | なし | — | — |
| 情2 | (2) を R50 の申し送りの表に足した | results-claude.md「F-REG・R50 への申し送り」 | 修正案のとおり |
| 情3 | 処置しない（固定入力の README と `resultConstructors` の説明は並行の文書の担当の受け持ちのファイルを含むので、この区間では変えない） | — | 取りまとめの依頼の対象外 |
| 情4〜情6 | なし | — | — |

## 処置の確認

2026-11-07。対象は HEAD `83ee549f`、差分は `git diff 4823e272 HEAD` の Lean・交換・試験の部分である（RV-L70.g-docs の処置の文書の部分は別の担当が見る）。読んだものは、上の「処置」、[results-claude.md](../l70/g/results-claude.md) の「RV-L70.g の処置」以後、本体の作業木の `plan.md` の確認点の先頭の二項目、X/`BuiltinAgreement.lean`・`CanonicalNames.lean`・`CheckInput.lean` の差分の全体、`SurfaceCheck/Batch.lean` の準備の失敗の報告、`formal/tests/` の `test_range_sources.py`・`test_named_exchange.py`・`test_batch2_exchange.py`・`test_batch3_exchange.py`・`test_batch5_exchange.py`・`test_range_rejections.py`・`test_range_exchange.py` の差分、`range-exchange/standard-scope-declarations.json`、`check_named.py` の差分である。

実行したこと: 固定入力の試験 `test_named_exchange`（13試験）・`test_extensible_exchange`（22）・`test_range_exchange`（9）・`test_batch3_exchange`（7、外側4秒）は全て OK だった。`test_range_rejections.py` は書き出しの出力の引数が要る台本で、引数なしの起動は278行の要件で止まった。処置の確かめには使っていない。`lake`・`check.sh`・`check-formal.sh`・git の書き込み操作は行っていない。

### 結論

**可。** 中1・中2・軽1〜軽7・情2 は閉じた。情3 の処置しないという判断も妥当である。処置で足した変更に、意味のある差を隠すものや未分類の失敗を通すものは見つからなかった。新しい軽の所見が4件あるが、どれも後段への申し送りか小さな直しで足りる。

### 所見ごとの確認

| 番号 | 確認 |
|---|---|
| 中1 | 閉じた。`DataAgrees` は、構成子の数の一致と、交換の各構成子について同じ名前の標準の構成子があり、型引数の数と引数の型（`tysEq`）が一致することを要求する。照合用の構成子の名前は一意であり（`uniqueKeys` と写しの単射）、数が同じなので、構成子の名前の集合も一致する。順序を比べないのは妥当である。篩付きの核の構成子は名前で引き（`ConDecl` は番号を持たない）、網羅性の判定も名前で行うので、順序の違いは検査器の判断に効かない。builtin の Result・Option も `standardData` に入り、`count` で構成子の欠けを断る（元の所見の (b)）。利用者の data を照らさないことも差を隠さない。利用者の data は標準の宣言に対応する意味を持たず、検査器は交換の名前でしか引かないからである。写らなかった標準ライブラリの data は、`displayCounterparts` で写らないこと自体を差にする（At が22入力になった）。残りは軽8 |
| 中2 | 閉じた。分類の経路でも報告を読む。不一致0、`preparationFailure` と拒否の数の一致、末尾の照合の件数（拒否した入力を除く定義の注釈の和）を要求し、期待の件数と分類の理由は断った入力の分を除いて照らす（`classified_all`・`remaining_counts`）。分類の表にない拒否が一件でもあれば `None` を返して失敗にする。`preparationErrors` の各行は `group`・`input` を持つ（`Batch.lean` 226〜228行）ので、除く入力の特定も正しい。拒否した入力の名前が件数の表の鍵にない場合は `KeyError` になる。これは失敗の側に倒れる |
| 軽1 | 閉じた。期待の核（`core`）を数える元から外しても、検査器は `inScope` の `surface` だけを読む（`prepareParts` の `.inScope surface _`）ので、閉包が期待の核に依らなくなった。`neg` は欄の名前で数える。`dataTypes` を外しても、検査器が読む網羅性の view の data の名前は表層の `coverageView` の値として数えられる。`impls` は名前が値に現れる実装だけを数える。実装のメソッドの本体は定義の `implementation` の欄に実装の名前を持つので、検査する利用者の実装は数えられる。例外は軽10 |
| 軽2 | 処置は記録の形で、取りまとめの判断（plan.md の先頭の項目）と設計者の見直しの対象として確定している。`Prepared.unknownBuiltins` と、単独・一括の両方の報告の欄に残る。最後に一覧の外を断る形にすることが R50 の義務に入っている。所見の「黙って通る」は解消した |
| 軽3 | 閉じた |
| 軽4 | 閉じた。`prepare_constraints` は `canonical_eq`（`rfl`）と `admits_normKey` から証明され、補題の読者になった。言明は記録どおりで、新しい前提はない |
| 軽5 | (1) 検査器が具体的な理由を返さないことは、取りまとめの判断として了解する。(2) 閉じた |
| 軽6 | 閉じた（`graph.lean`・`graph_inputs.py`・`f09.json` の `graph_script`） |
| 軽7・情2 | F-REG・R50 の申し送りの表に入った |
| 情3 | 処置しない理由は妥当である |

### 処置で足した変更の確認

- `prepare_agrees` の (2) と `dataDisagreements_nil`・`dataCheck_sound`: 証明に仮定の追加はない。`prepareParts` は差の一覧が空でなければ先に断り、その後に `dataGaps = []` の証拠を取るので、報告と証拠は食い違わない。
- `prepare_constraints`: 上の軽4のとおり。
- `standard-scope-declarations.json`（21件）: 標準表から書き出したもので、range の固定入力はこれで準備の data の照合を通る。準備を通ったこと自体が、標準の宣言との一致の確かめになっている。固定入力は Lean の検査器を試す入力であり、処理系の書き出しの形（6構成子）は、書き出しを読む試験で At として分類したまま残る。これは取りまとめの判断のとおりである。
- `KNOWN_DESUGAR_DIFFERENCES`: 列挙した差があるのに消えたときは失敗になり、列挙の外の差は不一致のまま残る。終了状態を0に直すのは、残りの不一致がないときだけである。残りは軽9。
- batch3 の試験の時間の上限60秒: `run_tool` の全ての入口の上限であり、判定には効かない。今回の実行は4秒だった。

### 新しい所見

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 軽8 | 軽 | X/`BuiltinAgreement.lean` の `DataAgrees`、`StandardKeyTyping.DataDecl`、R50 の申し送りの表 | 標準の宣言は名前・型引数の数・構成子と引数の型しか持たない。交換の data の、record の欄の名前（`conFields`）・`extensible`・変性は照らせない。`extensible` は網羅性の判定に効くが、照合の外にある。あわせて、`prepare_agrees` の説明の「構成子の名前の列」は、順序を比べない実装と合わない | R50 の義務の表に「data の欄の名前・`extensible`・変性と完成表の data の表との一致」を足す。説明は「構成子の名前の集合」に直す | 読めば確定 |
| 軽9 | 軽 | `formal/tests/test_named_exchange.py` の `known_desugar` | 既知の差は（入力・定義・経路）だけで照らし、差の中身（期待が実際の型に欄の関係の篩を足した形であること）を照らさない。同じ経路に別の原因の差が出ても、既知の差として数えられる | 一致とみなす条件に、`expected` の `refined.base` が `actual` と等しく、篩が `field` の関係であることを加える | 読めば確定 |
| 軽10 | 軽 | X/`CheckInput.lean` の `closureOf` | 利用者の実装のうち、本体を持つメソッドがなく、名前が入力の値に現れない実装（印の型クラスの実装など）は、数える元に入らない。検査器はその実装の対象の型を読む（`ImplEntry.convert`）。対象が標準ライブラリの data なら、その data は照合の対象から漏れる | 利用者の実装（`input.impls` のうち `s.impls` にないもの）は常に数える。標準ライブラリの実装の一覧（`s.impls`）だけを名前で絞る | 読めば確定。該当する入力の有無は調べていない |
| 軽11 | 軽 | `formal/tests/test_range_rejections.py` の分類の経路（`classified_all` の後の `continue`） | 期待した拒否の入力が標準表との差で準備の段に断られると、検査器の拒否を確かめずに分類として残す。今は0件だが、0件であることを要求していない | この試験は標準表に合わせた固定入力だけを読むので、`preparationRejected` が0であることを要求する | 読めば確定 |

### F-REG・R50 への申し送りの確認

results-claude.md の申し送りの表は、元の所見の残りを全て持っている。

- F-REG: `Http.sendIn`・At・結果型の篩・`unknownBuiltins`・軽7の内部行。
- R50: 閉包の外の行・標準の data の支持・鍵の印の接続・`DefSupport`・`ImplSupport`・`unknownBuiltins` の振り分け。
- R10b: 既知の差。

足りないのは軽8の data の欄の名前・`extensible`・変性の1行だけである。

## 処置の確認の後の処置

2026-11-07、基準 `83ee549f`。結果は [results-claude.md](../l70/g/results-claude.md) の「処置の確認の後の処置」にある。

| 番号 | 処置 | 場所 |
|---|---|---|
| 軽8 | R50 の申し送りの表に「data の欄の名前・`extensible`・変性と完成表の data の表との一致」を足した。説明の「構成子の名前の列」を「集合」に直した | X/`CheckInput.lean` の `prepare_agrees` の説明、07-04 の data の照合の文、results-claude.md |
| 軽9 | 経路に加えて差の中身（期待の結果型が実際の結果型に欄の関係の篩を付けた形）を照らす。違えば既知の差として数えない | `formal/tests/test_named_exchange.py` の `known_shape`・`known_desugar` |
| 軽10 | 利用者の実装を全て数え、標準ライブラリの信頼する実装だけを名前で絞る。1,455入力の準備の段の件数は変わらなかった | X/`CheckInput.lean` の `closureOf`、07-04 の `prims` の箇条 |
| 軽11 | 拒否の独立入力で準備の段に分類された入力が0であることを要求する | `formal/tests/test_range_rejections.py` |
