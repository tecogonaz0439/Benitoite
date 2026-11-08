# L70.48 段末レビューの処置（Lean の担当）の結果

2026-11-08。実装担当（Claude、Opus 5.5）が、L70 の段末レビュー [RV-L70-stage](../../reviews/RV-L70-stage.md)（ChatGPT Pro、条件付き可）の所見のうち、Lean を変える処置を行った記録である。文書の処置（01-12・07-04・`formal/README.md`・[../stage-results.md](../stage-results.md)・[../h3/legacy-recheck.md](../h3/legacy-recheck.md) の理由の文・レビューの処置の節）は、同じ作業木で並行する文書の担当が受け持つ。git の状態を変える操作、サブエージェントの起動、`scripts/check.sh`・`scripts/check-formal.sh` の実行はしていない。

## 基準

| 項目 | 値 |
|---|---|
| 作業ディレクトリ | `<repo>`（git worktree、ブランチ `m014/l70.48`） |
| B_WORK | `fd280c1c0ad1c15d0b6ca0f40f6801989db66db2`。作業の開始時に HEAD と一致した（未追跡は `reviews/RV-L70-stage.md` だけ） |
| 一時領域 | `<tmp>`（会話の scratchpad の `l70-48/`）。数え直しの入力は群 G の一時領域の書き出し（`<tmpG>/stage`。L70.42 の新しい書き出し、48文書） |

## 所見ごとの処置

| 所見 | 処置 | 結果 |
|---|---|---|
| 2（`FieldRef.owner` の名前の写し） | 型付きの写し `CanonicalNames.fieldRef`・`term`・`slots`・`pred` を置き、JSON の写しは篩付きの型の述語（欄 `predicate`）をこの型付きの写しで写し、ほかの位置の欄の参照（導出した四つの欄だけを持つ対象）も `fieldRef` で写す | 置いた。内部名の `List.tail` の述語の例と、値の文字列を写さない例を定理として置いた |
| 1（閉包と全件の宣言の検査） | 閉包の data の段 `dataStep` が、構成子の引数に加えて変性の検査が読む `requirements`・`publicBoundary` の型の data も辿る（`dataDeclStrings`）。検査器の全件の `CheckVariance.check` は変えていない | 置いた。1,455入力の準備の段の件数は変わらない（「1. の件数」） |
| 6（開始時と同じ返却の篩型の保証） | 結果型を添字に固定した状態の型付けの保存を試した | 置けなかった。止まる箇所と要る補題は「6.」 |
| 5（旧の局所参照の保証） | 旧の構文の像の状態の全ての捕捉が空であることと、型付きの像の局所の不変条件を合わせた補題を置いた | 置いた（範囲は「5.」） |

## 2. `FieldRef.owner` の名前の写し

`Exchange/CanonicalNames.lean` に次を足した。

- `CanonicalNames.fieldRef (names) (r : FieldRef) : FieldRef`: 所属の data（`owner`）を `dataNames`、構成子を `constructorNames` で写す。構成子の名前の欄だけを写す対応（`constructorsOnly`。`resultConstructors`）では、所属の data の名前を保つ。
- `CanonicalNames.term`・`slots`（相互の構造的な再帰）と `pred`: 項の `dataValue` の構成子、`field` の欄の参照、述語の `constructorIs` の構成子を写し、ほかの項（`string` など）はそのまま返す。
- JSON の写し（非公開の `rewrite`）: 欄 `predicate` の値が `Pred` として読めれば `toJson (names.pred p)` に置き換える。ほかの位置で、四つの欄 `owner`・`constructor`・`position`・`result` だけを持ち `FieldRef` として読める対象は `toJson (names.fieldRef r)` に置き換える。あらゆる `"owner"` を置き換えるのではない（区間の交換の文書の `owner` の欄は、欄の組が違うので対象にならない）。

写しの性質:

- 入れ替え: `resultConstructors_lookup_twice`（構成子の名前の写しを二度掛けると元に戻る）、`resultConstructors_fieldRef_owner`（構成子だけの写しは所属の data を変えない）、`resultConstructors_fieldRef_twice`・`resultConstructors_term_twice`・`resultConstructors_slots_twice`・`resultConstructors_pred_twice`（欄の参照・項・述語の写しも二度で戻る）。適用例は同じファイルの `example`。
- 比べる両辺に同じ写し: 準備（`CheckInput.prepareParts`）は同じ `names` を組込みの表・入力・標準ライブラリの宣言・演算子の表の全てに掛け、標準表の側は標準の名前のままである。交換の入口（`exchangeJson`）の `resultJson` は corpus・builtins・stdlib の全ての文書に同じ写しを掛ける。この構造は変えていない。

確認の例（`Exchange/CanonicalNamesExamples.lean`、既定 import に入れた）:

- `tail_predicate_renamed : tailNames.pred (internalTailPredicate (.var 0) (.var 1)) = StandardHeadTail.tailPredicate (.var 0) (.var 1)`。`tailNames` は `data:199 → Option`、`ctor:Some → Option.Some`、`ctor:None → Option.None` の対応、`internalTailPredicate` は内部名で書いた `List.tail` の結果型の篩の述語である（`rfl`）。
- `internalSomeField_renamed : tailNames.fieldRef internalSomeField = StandardHeadTail.someField`（`⟨"data:199","ctor:Some",0,.list⟩` が `⟨"Option","Option.Some",0,.list⟩` になる）。
- `string_value_kept : tailNames.pred (.eq (.string "data:199") (.field internalSomeField (.var 0))) = .eq (.string "data:199") (.field StandardHeadTail.someField (.var 0))`（値の文字列は写さず、同じ述語の欄の参照は写す）。

JSON の写しの全体（`CanonicalNames.json`）は部分関数なので定理にできない。一時領域の試し（`<tmp>/probe-names.lean`、既定ビルドの外）で、組込みの表の行の形に置いた内部名の結果型 `refined (data "data:199" [list (tvar 0)]) internalTailPredicate` を `tailNames.json` で写すと、標準の結果型 `refined (data "Option" [list (tvar 0)]) tailPredicate` の JSON と等しいこと、値の文字列 `"data:199"` が写されないこと、述語の外（欄 `goal`）の欄の参照も写ること、`resultJson` が所属の data を保つことを確かめた。

## 1. 閉包の data の段

`Exchange/CheckInput.lean`:

- `dataDeclStrings (d : DataEntry) : List String`（新規）: 構成子の引数（`ctors`）・制約（`requirements`）・公開境界（`publicBoundary`）の JSON に値として現れる文字列。
- `dataStep`: 届いた data の宣言について `dataDeclStrings` に現れる名前の data を加える（前は `ctors` だけ）。
- `closureOf` と `Closure` の説明を合わせた。`closureOf` の式、`prepare_sound`・`prepare_agrees`・`prepare_entry`・`prepare_constraints` の言明、検査器の算法（全件の data に `CheckVariance.check` を掛ける）は変えていない。

### 1. の件数

件数は変わらなかった。群 G の数え方（named-programs は準備の段だけ）に倣い、named-programs の検査の本体は流していない。ほかの47文書も、群 G の表層の一括検査の代わりに準備の段だけを当てた（`surfaceCheckAll` の `Batch.run` と同じ順・同じ前段の検査・同じ準備の判定。検査の本体は流さない）。

- 台本: `<tmp>/prep-all.lean`（入力ごとに `prepare` と表の判定を当て、閉包の data を前の段（構成子の引数だけ）と今の段の両方で作って差を書く。SHA-256 `06a4ed1fea05c53670568e3ca259a1c662845ef46ab0f5d023fe2a8b782bf65c`）、`<tmp>/run.sh`（48文書を共有ロックの下で一つずつ。`dc55bcb8…`）、`<tmp>/tally.py`（`formal/tests/test_range_sources.py` の `preparation_gaps` で原因を分類。`189a8c03…`）。
- 前: B_WORK の Lean（`<tmp>/base-formal`。`formal/` を複製し、変えた3ファイルを B_WORK の内容に戻して `Benitoite.Exchange.CheckInput` まで作った）。後: 作業木の Lean。
- 記録: 前 `<tmp>/prep-base.jsonl`、後 `<tmp>/prep-new-all.jsonl`（どちらも 220,850 バイト、SHA-256 `f14e0372a2c9b72830c27cea5d7c26ee9157773194f9a9c3a9ad29a59008b1f9`。バイト単位で同じ）、集計 `<tmp>/tally-final.json`（`fc8037e7…`）。

| 対象 | 入力 | 準備を通った | 準備の段で断った |
|---|---:|---:|---:|
| named-programs | 1,373 | 1,341 | 32 |
| ほかの47文書 | 82 | 58 | 24 |
| 計 | 1,455 | 1,399 | 56 |

断った56入力の原因（重なりあり）は、前後とも `Http.sendIn` 20・`Scope.ScopeError.At` 22・結果型の篩 23 と、組の誤りで評価できない `scope-tables` 1（`sidecar input identity mismatch`）である。前の版の named-programs の結果は群 G の最後の記録（`prep-np5.jsonl`）と入力ごとに一致した。閉包の data が増えた入力は0件、組込みの表に篩の述語（欄 `predicate`）を持つ入力も0件だった。48文書の書き出しの data の宣言（named-programs を除く 2,952 件を数えた）は、どれも `requirements`・`publicBoundary` が空である（処理系の書き出しがまだ出さない）。したがって、今の書き出しでは閉包の変更も名前の写しの変更も準備の結果に効かない。

所要: 一回の数え直しは named-programs が約28〜32分（最大常駐 約9 GB。前段の読み込みと交換の写しに約8分）、ほかの47文書が計約1分である。named-programs の後の版の一回目は、出力のバッファで進みが見えず遅いと誤認して PID を指定して止め（522秒）、前段の時間を新旧で測った（交換の写し 29.2秒と 32.2秒、最初の3入力の全体 478秒と 497秒）うえで、もう一度流した（1,940秒）。

## 5. 旧の局所参照の保証

`Release/Refinement/EmbeddedLocalRefs.lean`（新規、既定 import に入れた）:

- `Frame.captures`・`Cont.captures`・`Cell.captures`（枠・継続・セルが最上位に持つ捕捉）と `State.CapturesEmpty`（状態の実行中の閉包か照合の捕捉、継続の全ての枠、ストアの全てのセルの捕捉が空）。
- `embedCont_captures`・`embedStore_captures`・`embedState_capturesEmpty : (embedState s).CapturesEmpty`（旧の構文の状態の像は最上位の全ての捕捉が空である）。
- `Capture.empty_all_slots`（空の捕捉には位置がないので、全ての位置についての条件が成り立つ）。
- `embedState_local_invariant : StateTyE P B σ Eb (embedState s) → LocalStateInvariant P B σ (embedState s) ∧ (embedState s).CapturesEmpty`。
- `hidden_capture_not_embedded`（隠れた位置の反例の状態は捕捉が空でないので像でない）。適用例は返却だけの旧の状態の像（`example`、`CaptureLocalRefsBoundary.empty_capture_accepts` を読む）。

範囲: 旧の構文の状態の像（`embedState`）に限る。像の値（`embedVal`）は実行時の閉包を作らず、保持値の像（`embedHeldVal`）の閉包は空の捕捉を持つ。この補題は、像の状態で不変条件の調べる位置が型付きの位置に限られることが制限にならない（捕捉の位置がない）ことを述べる。削除した旧の構文上の述語（旧 `Release/LocalScope.lean` の `Val.LocalRefs` など）を置き直して、新しい述語から旧の述語を導く対応までは示していない。また、像の状態から実行した後の状態は一般に像でない（関数の適用が空でない捕捉を作る）ので、`local_steps_invariant` の到達先の全ての状態についての回収ではない。

## 6. 開始時と同じ返却の篩型の保証

置けなかった。上限4時間のうち、止まる箇所の特定と両端の補題の試しに使った（時刻は「単位の時刻」）。

求めた系: 初期の閉包が型 A で型付き（`ClosureTy P B StoreTy.empty [] none q A ε`）、開始の条件を満たし、`Steps` が継続の空の返却 `.run q' [] μ`（`q'.view = .ret v`）に至るなら、`ValueMeaning P (fun _ => none) A v`。

止まる箇所: 状態の型付け `StateTyE P B σ Eb s` は継続の結果型 `b` を状態ごとの存在量化に置き（`StateTyping.lean` の `StateTyE`）、一段の保存 `StateTyE.step_preserved`（`FiniteStepPreservation.lean`）は約60の葉の定理（30ファイル・167の `StateTyE.` の定理）を分配して閉じる。葉の定理の言明はどれも `StateTyE … source → StateTyE … dest` の形で、証明の中では `b` を渡して組み直す（`obtain ⟨Ψ,R,a,b,…⟩ := h` から `⟨…,b,…⟩` を作る）が、言明が `b` を存在量化に隠すので、`b` が一段で変わらないことは既存の定理から取り出せない。Eb・σ・P・B のどの添字も `b` と結び付かない（`ContTy.K_Empty` は `ε ⊆ Eb` と注釈だけを要求する）ので、既存の言明を別の添字で使い回して `b` を固定することもできない。

要る補題:

1. `StateTyR P B σ Eb b s`: `StateTyE` の本体で `b` を添字にした述語（`StateTyE P B σ Eb s ↔ ∃ b, StateTyR P B σ Eb b s` は定義の並べ替え）。
2. `StateTyR.step_preserved`: `P.WellFormed → P.WellTyped B → P.EffectsOk B → B.CoreAssumptions P → σ.Valid → StateTyR P B σ Eb b s → Step P B σ s l s' → StateTyR P B σ Eb b s'`。葉の定理を全て `StateTyR … b` の形に述べ直す必要がある（証明の大部分は `b` を渡すだけで、`ContTy` の補助の定理は既に `b` を明示の添字に持つ）。主な言明（`StateTyE`・`StateTy` を読む）は変えずに足せる。見込みは葉の定理の述べ直しの機械的な書換えとビルドの繰返しで、能動時間 8〜20時間（未確認の見積もり。30ファイル・約1万行の葉の証明が対象）。
3. `StateTyR.steps_preserved`（2 の反復）。
4. 両端（一時領域の `<tmp>/ResultEndpoints.lean` で既定ビルドの外に試し、通った）:
   - `initial_result : ClosureTy P B StoreTy.empty [] none q a ε → StartCondition P B σ q → StateTyR P B σ ε a (.run q [] Store.empty)`（`initial_typing` と同じ証明）。
   - `final_result_meaning : P.VarianceValid → P.WellFormed → P.WellTyped B → B.CoreAssumptions P → StateTyR P B σ Eb b (.run q [] μ) → q.view = .ret v → ValueMeaning P (fun _ => none) b v`（`ClosureTy.ret_view_typed`・`ContTy.nil_inv`・`HasTypeVQ.V_Sub`・`typed_value_meaning_closed` で閉じる）。

系は 1〜4 を合成すれば得られ、新しい公理・信頼条件・主な言明の変更は要らない。取りまとめが docs/todo の項目にする（前提に `P.VarianceValid` が要る。主定理の前提の `P.WellFormed` が含むかは項目を作るときに確かめる）。

## 文書への申し送り

並行の文書の担当が 01-12・07-04・`formal/README.md`・[../stage-results.md](../stage-results.md)・[../h3/legacy-recheck.md](../h3/legacy-recheck.md) に取り込む内容である。

| 箇所 | 内容 |
|---|---|
| 07-04「証明する性質」の名前の写し（`standardCheck` の段落の「交換の内部名を標準の名前へ写した後の名前で照らす」） | 名前の写し `Benitoite.Exchange.CanonicalNames.json` は、篩付きの型の述語（交換の欄 `predicate`）を型付きの述語として読み、`Benitoite.Exchange.CanonicalNames.pred` で写す。`pred` は、項の構成子の値（`Term.dataValue`）と構成子の判定（`Pred.constructorIs`）の構成子の名前、欄の参照（`Term.field` の `FieldRef`）の所属の data（`owner`）と構成子の名前を写し、値の文字列（`Term.string` など）は写さない（`Benitoite.Exchange.CanonicalNames.fieldRef`・`term`・`slots`）。述語の外にある欄の参照（交換の形が四つの欄 `owner`・`constructor`・`position`・`result` だけの対象）も `fieldRef` で写す。構成子の名前だけを写す対応（`resultConstructors`。`exchangeJson` の `resultJson`）は所属の data を変えない（`Benitoite.Exchange.CanonicalNames.resultConstructors_fieldRef_owner`）。入れ替えの性質は `Benitoite.Exchange.CanonicalNames.resultConstructors_lookup_twice` と `resultConstructors_pred_twice : ∀ p, resultConstructors.pred (resultConstructors.pred p) = p`。確認の例は `Benitoite.Exchange.CanonicalNamesExamples.tail_predicate_renamed : tailNames.pred (internalTailPredicate (.var 0) (.var 1)) = StandardHeadTail.tailPredicate (.var 0) (.var 1)`（`tailNames` は `data:199 → Option`・`ctor:Some → Option.Some`・`ctor:None → Option.None`）と `string_value_kept`（値の文字列 `"data:199"` は写さない） |
| 07-04 同上の閉包の定義（`closureOf` の `data`） | data の段 `Benitoite.Exchange.CheckInput.dataStep` は、届いた data の宣言の構成子の引数・制約（`requirements`）・公開境界（`publicBoundary`）の型に現れる data を加える（`Benitoite.Exchange.CheckInput.dataDeclStrings d = jsonStrings (toJson d.ctors) ++ jsonStrings (toJson d.requirements) ++ jsonStrings (toJson d.publicBoundary)`）。変性の検査 `CheckVariance.metadata` が読む欄と同じである。検査器は従来どおり全件の data に `CheckVariance.check` を掛ける（閉包の外の data の宣言も検査の結果に効く。義務19の書き直しは文書の担当）。1,455入力の準備の段の件数は変わらない（1,399が準備を通り56を断る。今の書き出しの data の宣言は制約と公開境界を持たない）。上の「1. の件数」 |
| 07-04・01-12 の開始時と同じ返却の篩型（所見6） | 系は置いていない。主保存定理と `StateTyE` は継続の結果型を状態ごとの存在量化に置くので、開始時の型と正常な返却値の篩型を結ぶ定理は今の形式化にない。要る補題は上の「6.」 |
| [../h3/legacy-recheck.md](../h3/legacy-recheck.md) の行1・行12の理由（所見5） | 旧の像に限った補題として `Benitoite.Release.Refinement.embedState_local_invariant : StateTyE P B σ Eb (embedState s) → LocalStateInvariant P B σ (embedState s) ∧ (embedState s).CapturesEmpty` を置いた。`Benitoite.Release.Refinement.embedState_capturesEmpty : (embedState s).CapturesEmpty` は、旧の構文の状態の像の実行中の閉包・照合・継続の枠・ストアのセルの捕捉が全て空であることを述べる。像の状態には捕捉の位置がないので、不変条件が型付きの位置だけを調べることは制限にならない。隠れた位置の反例の状態は像でない（`Benitoite.Release.Refinement.hidden_capture_not_embedded`）。削除した旧の構文上の述語を置き直して新旧の述語の対応を示したものではなく、像の状態から実行した後の状態（一般に像でない）についての回収でもない |
| [../stage-results.md](../stage-results.md) の段の宣言の件数の表と本文の件数 | 段の公理監査をこの作業の後の最終版で作り直した（下の「検査」）。表と本文の件数を、作り直した記録（[../h3/declarations.json](../h3/declarations.json)・[../h3/audit-summary.json](../h3/audit-summary.json)・[../h3/modules.json](../h3/modules.json)）に合わせる必要がある。値は下の「検査」に書く |

## 検査

局所の検査（`lake env lean -M 12288 <ファイル>`）は共有ロックの下で同時に一つだけ実行した。作業末の検査は次である。

| 検査 | コマンド | 開始 | 終了状態 | 外側の時間 | 結果 |
|---|---|---|---:|---|---|
| 既定ビルド | `lockf … /usr/bin/time -l lake build`（`formal/`） | 10:01:09 | 0 | 9.5秒（ロックの待ちを除く） | 2350 jobs、`sorry` なし。前に足したモジュールを個別に作ってあったので、作り直したのは29件 |
| 固定入力の交換の試験 | `python3 -B formal/tests/test_{width,try,batch2,batch3,batch4,range,named,extensible}_exchange.py` | 10:01:20 | 全て0 | 計46秒 | 7入口の実行ファイルで、名前の写しの変更の後も全て通った |
| 公理監査（L70.48 の4モジュール） | `python3 -B l48/audit-lean.py prepare|run|analyze --tmp <tmp>/audit --lock <共有ロック>` | 10:01:48 | 0 | 17.8秒 | [audit-lean.json](audit-lean.json)（実行の記録 [audit-run-lean.json](audit-run-lean.json)、入力 [changes-lean.json](changes-lean.json)、台本 [audit-lean.py](audit-lean.py)）。`CanonicalNames`・`CanonicalNamesExamples`・`CheckInput`・`EmbeddedLocalRefs` の全宣言501（private 101、マクロのスコープを持つ名前0、未解決0）。公理の組は なし 209・`propext` 111・`Quot.sound + propext` 2・`Classical.choice + Quot.sound + propext` 179。`sorryAx`・許可の外の公理・`axiom` の宣言は0。必須の名前31名 |
| 段の公理監査の最終版の書き出し | `python3 -B h/stage.py prepare` と `run --which final --tmp <tmp>/stage --lock <共有ロック>` | 10:03:03 | 0（8入力とも） | 既定 import の閉包の入力 531.2秒（ロックの待ちを含む。named-programs の数え直しの後に走った）、7入口は各13〜15秒 | 開始版の書き出しは群 H3 の一時領域のものを使った |
| 段の記録の作り直し | `h/stage.py analyze`・`trust.py`・`obligations.py`・`four.py`・`heartbeats.py`・`comments.py`（記録の出力先は既定の ../h3） | 10:34 | 0 | 約2分 | 下の「段の記録の変化」 |
| 段の照合 | `python3 -B verify.py --tmp <tmp>/stage --h2-tmp <群 H2 の一時領域>` | 11:07:03 | 1 | 98秒 | 1〜5 と 4b は通り、6 の [../stage-results.md](../stage-results.md) の件数の行（`| 足した | 52,733 |`）で止まった。段末の資料の件数は文書の担当の受け持ちで、まだ前の値（52,571・126,444 など）である。照合の台本の、段末の資料の本文だけを新しい件数に差し替えた写し（`<tmp>/verify_dry.py`。本書を書き換えない）では最後まで通った（`verified`。宣言 126,606、監査の名前 126,591、必須の名前 336） |

### 段の記録の変化

[../h3/required-names.json](../h3/required-names.json) に群 `L48`（[changes-lean.json](changes-lean.json) の `required` の31名）を足し、段の記録を最終版の書き出しから作り直した。作り直しで変わったのは [../h3/declarations.json](../h3/declarations.json)・[../h3/audit-summary.json](../h3/audit-summary.json)・[../h3/modules.json](../h3/modules.json)・[../h3/required.md](../h3/required.md)・[../h3/runs-final.json](../h3/runs-final.json)・[../h3/comments.json](../h3/comments.json)（調べたファイルの数 593→595）と、新しい [../h3/required-L48.json](../h3/required-L48.json) である。信頼条件・義務・四分類・heartbeat の記録は変わらなかった。主定理の必須の名前（main）の型・本体のハッシュは変わらなかった（`prepare_agrees` の型のハッシュは L70.48 の監査と段の記録で同じ `0ad1ddcd…`）。

| 値 | 前（B_WORK の記録） | 後 |
|---|---:|---:|
| 最終版の宣言 | 126,444（既定 import の閉包 125,442、7入口 1,002） | 126,606（既定 import の閉包 125,604、7入口 1,002） |
| 状態「足した」 | 52,571 | 52,733 |
| 「足した」の内訳（定理・定義・帰納型・構成子・再帰原理・private・生成・マクロのスコープ・名前付きの公開） | 32,060・18,032・395・1,677・407・28,446・12,926・27・11,179 | 32,177・18,077・395・1,677・407・28,511・12,993・27・11,209 |
| 系統の「足した」（Release.Refinement・Exchange） | 6,942・1,178 | 7,001・1,281 |
| 所属の変わった宣言 | 514 | 528 |
| モジュール（最終版・段で足した・既定 import） | 1,329・395・1,319 | 1,331・397・1,321 |
| 公理監査の名前（targets・printed） | 126,429・126,405 | 126,591・126,567 |
| 公理の組（なし・`propext`・`Quot.sound + propext`・`Classical.choice + Quot.sound + propext`） | 53,802・37,616・3,789・31,206 | 53,872・37,699・3,790・31,214 |

「削除した」「型が変わった」「本体が変わった」「同じ」の件数は変わらない（変えた定義は段の開始版になかった宣言か、既に「本体が変わった」に数えた宣言である）。

### 照合の台本の変更（[../verify.py](../verify.py)）

- 群 H3 の区間（B_H2 から作業木まで）の変更の範囲に、段末レビューの写し `reviews/RV-L70-stage.md` と、取りまとめが群 H の記録のコミットで変えた `plan.md`・`effort-ledger.md` を加えた（後者は B_WORK の時点で既にこの区間にあり、前の照合の後に入った）。
- 「4b」を足した: B_WORK から作業木までの `formal/` の変更が [changes-lean.json](changes-lean.json) の一覧と一致すること、足したモジュールが既定 import の閉包にあること、[audit-lean.json](audit-lean.json) の必須の名前が一覧と同じで `sorryAx` 等が0であること、一覧の名前が段の必須の名前の群 `L48` に入っていること。
- 記録の大きさ・手元の絶対パス・docs/todo へのリンクの検査の対象に l48/ を加えた。

## 単位の時刻（外側の時間。能動時間と待ちは分けていない）

| 単位 | 時刻 |
|---|---|
| 読む | 09:17〜09:22 |
| 所見2 の Lean の変更・入れ替えの性質・例・JSON の試し | 09:22〜09:30 |
| 所見1 の閉包の変更、数え直しの台本と前の版の複製 | 09:30〜09:33 |
| 所見5 の補題（ロックの待ちを含む検査は 10:00 まで） | 09:34〜09:40 |
| 所見6 の切り分けと両端の補題の試し（検査は 10:00） | 09:37〜09:50 |
| 記録・監査の台本・照合の台本の準備 | 09:43〜10:00 |
| 数え直し（前の版。待ち） | 09:32〜10:02 |
| 既定ビルド・固定入力の試験・L70.48 の公理監査・段の公理監査の書き出し | 10:01〜10:13 |
| 後の版の named-programs の遅さの切り分け（止めて前段を新旧で測った） | 10:09〜10:33 |
| 段の記録の作り直しと照合（一回目。段末の資料の件数で止まる） | 10:33〜10:40 |
| 数え直し（後の版の named-programs。待ち） | 10:32〜11:04 |
| 記録 | 10:40〜11:10 |

所見ごとの所要（外側）: 所見2 約10分、所見1 の閉包約5分（数え直しは待ち約1時間30分）、所見5 約10分（上限1時間の内）、所見6 約15分（上限4時間の内。言明の形から、既存の定理の組合せでは置けないことが早く確定した）。

## 計画からのずれ

- 1,455入力の数え直しは、named-programs 以外の47文書も準備の段だけで数えた（群 G は47文書に表層の一括検査を当てた）。準備の段の件数を数えるには十分で、検査の本体を流さない。
- 照合の台本は、B_WORK の時点で群 H3 の区間の変更の範囲の検査（`plan.md`・`effort-ledger.md`）で止まる状態だった。範囲に加えて通した（上の「照合の台本の変更」）。
- 段の記録（h3/）を作り直した。段末の資料の件数（[../stage-results.md](../stage-results.md)）は文書の担当の受け持ちなので変えていない。

## 取りまとめに判断を求める点

1. 段末の資料の件数: 段の記録を作り直したので、[../stage-results.md](../stage-results.md) の状態の表の「足した」行・系統の表・本文の宣言とモジュールの数・公理監査の名前の数・公理の組の数を、上の「段の記録の変化」の値に直す必要がある。直すまで照合は終了1である（件数だけを差し替えた写しでは通る）。
2. 所見6: 系は置けなかった。要る補題（結果型を添字に固定した保存）と見込み（能動時間 8〜20時間、未確認の見積もり）を docs/todo の項目にするか、L70 の中で行うかの判断。
3. 所見5: 置いた補題は、旧の像の状態に捕捉の位置がないことと像の局所の不変条件を合わせたもので、削除した旧の構文上の述語との対応までは示していない。理由の文をこの範囲で書くか、旧の述語を置き直した対応補題まで求めるか（後者は旧の述語の再定義と、旧の値・計算の全構成子の帰納が要る）。
4. 所見1: 閉包の変更は、処理系の書き出しが data の宣言の制約・公開境界を出すようになるまで件数に効かない。義務19 の書き直し（文書の担当）で、この閉包を照合の範囲として使う。

Lean の変更の終わり
