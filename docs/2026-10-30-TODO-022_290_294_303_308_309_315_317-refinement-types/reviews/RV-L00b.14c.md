# RV-L00b.14c: Reference と StoreOk の代表の独立レビュー

**判定: 条件付き可。所見は重0、中1、軽6である。** 偽の事実の反例はなく、本番の補題の修正は求めない。分類は「閉じた（記録した代表の言明が閉じた）」でよい。条件は、中1の残件の書き直しと、その処置を設計者の判断へ回すことである。

2026-11-01。レビュー担当は Opus 5.5 のサブエージェントである。対象はブランチ `m014/l00b.14c` の未コミットの作業ツリー、基準は `b5a00e9a` である。

## 動かしたもの

補助の入力は `<tmp>/rv14c/` に置いた。実行は `cd formal && lake env lean -M 12288 <ファイル>` である。

| 入力 | 内容 | 結果 |
|---|---|---|
| `lake build` | 既定のビルド | 終了0、725ジョブ |
| `rv-14c-t1.lean` | `boundary.lean` の本文の写しに、不変性の負例と篩の内容型の正例を足したもの | エラー0、`sorry` 0。写しを通したので境界の本文の再実行を兼ねる。公理は propext・Classical.choice・Quot.sound だけである |
| `rv-14c-t3.lean` | `refGet` の型パラメータの kind だけを変えた表の反例（中1） | エラー0、`sorry` 0。公理は同じ三つである |

本番の3モジュールの SHA-256 は `source-delta.json` と一致する。`formal/Benitoite.lean` の差分は import 1行である。新規の本番ソースに `sorry`・`admit`・`axiom`・`native_decide`・`unsafe`・`partial`・`implemented_by`・`opaque` はない。全宣言の公理依存（15,080件）は再実行していない。

## 所見

### 中

**中1. `ReferencePrimitives` の残件は、表からの構成では閉じない**（再現済み、`rv-14c-t3.lean`。**五つの境界のうち「主な定理の前提」に触れる予告**）

- 場所: `ReferencePreservation.lean` の `ReferencePrimitives`、`ConstraintAssumptions.lean` の `PrimSig.StoreShape`・`Builtins.CoreAssumptions`、`results.md`「残り・送り先・義務行」の L40/L60 の行、`signatures.md`「実装中の補助契約の確定」。
- 問題: 主定理は抽象の `B` について述べるので、全状態の保存へ合成するとき、`E_RefUpdate` の場合に `ReferencePrimitives` を `CoreAssumptions` から得る必要がある。残件の行は「実際の組み込み表と照合し、表から構成する」と書くが、具体の表の照合では抽象の `B` の場合を閉じない。さらに、旧 `Assumptions` の `ref_get`・`ref_set`（存在と kind）を足しても足りない。
- 再現: `rv-14c-t3.lean` は `refGet` の型パラメータの kind だけを `.constructor 1` にした表を作る。`StoreShape` は kind を定めないので通る。この表で次を閉じた。
  - `assumptions`: `CoreAssumptions` が成り立つ。
  - `ref_get_field`・`ref_set_field`: 旧二欄も成り立つ。
  - `update_source_typed`・`update_real_step`: update の開始は型付き、実際の `E_RefUpdate` がある。
  - `primitives_fail`: `ReferencePrimitives` は偽である。
  - `update_not_preserved`: 到達はどの `Ψ` でも型付かない。
- 帰結: 今回の本番の定理は仮定付きなので偽ではない。実装担当の「kind と存在だけでは従わない」という分析も正しい。ただし全状態の保存には、`CoreAssumptions` か `StoreShape` の強化が必ず要る。これは `signatures.md` の「欄を足す案は採らず」が今回の代表の範囲の判断であり、後の段では避けられないことを意味する。
- 修正案: 残件の行を次のように改める。「L20/L40 の合成の前に、`ref_get`・`ref_set` の欄を足し、`StoreShape` の `.refGet`・`.refSet` に `s.tparams.map TParamDecl.kind = [.value]`（または update と同じ kind）を足す。そこから `ReferencePrimitives` を任意の `ts` について導く。主な定理の前提を変えるので、取りまとめが設計者へ提示する」。見込みの 1〜2 時間は補題の分だけであり、判断を含まないと書く。旧二欄を足すのは既定の方針（`CoreAssumptions` の docstring の「旧欄の残りは担当する後続の群で加える」）だが、kind の欄は旧体系にない新しい条件である。実表は kind が `.value` なので、処理系の変更と利用者の書ける形の縮小は生じないと見込む（全表の確認は未実施）。

### 軽

**軽1. 境界に Reference の内容型の不変性の負例がない**（再現済み、`rv-14c-t1.lean`）。依頼の守る契約は現内容の観測の排除などを挙げるが、部分型の不変性を捕まえる負例が `boundary.lean` にない。Reference に共変の規則を足す退行は、現行の境界では検出されない。`rv-14c-t1.lean` の `le_strengthen_fails`・`le_weaken_fails`・`le_under_false`（矛盾した Φ の下でも不可）・`loc_not_small`・`nine_not_small`・`cell_rejects_nine`・`reference_var_no_sort` を境界へ写すことを勧める。

**軽2. 篩の内容型の呼出しの具体の正例がない**（読めば確定、一部再現）。`results.md` の「内容型は篩を含んでよい」は定理の一般性としては正しいが、`boundary.lean` の呼出しの代表は `Integer` だけで、`raw_cell_*` も Unit の正規化の確認である。`rv-14c-t1.lean` の `store_small`・`read_small` はセルの水準の正例を閉じた。`prim` を `Reference[Integer{self < 8}]` で型付ける呼出しの水準の正例は、今回は閉じていない（`primitive` の写しの結果の注釈の場合で打ち切った）。不足は証明の手間であり、反例ではない。境界へ足すか、セルの水準までと記録に書く。

**軽3. `_hc` は保存の言明で使われない**（読めば確定）。`StateTyE.reference_new`・`reference_set` の `_hc : closeVal Capture.empty v = v` は証明で使わず、`*_transition` の view の照合でだけ要る。`signatures.md` は保存の補題の入力として記し、理由を述べない。保存の補題から外すか、遷移と組にするための入力であると書く。

**軽4. 文書の古い記述が残る**（読めば確定）。`signatures.md` の「開始の型付けからの逆転と保存」の「旧体系と同じ形の存在を補助入力に明記する」と、決定の表の「update の既知の get/set の存在を入力で列挙する」は、後の節の「存在と kind だけでは型付かない」で覆された。後の節が正であることは読めば分かるが、前の二箇所に後の節への参照を足すとよい。

**軽5. 書込み後の保持の正例は `refl` の移送である**（読めば確定）。`pending_after_write`・`CaptureOk.reference_write_snapshot`・`BoolSnapshot.if_after_set` は、`Ψ` を変えない書込みに対して `.refl` の移送を当てる。主張は正しく、`CaptureOk`・`GuardBodyTy` が `μ` に依存しないことを確かめている。ただし guard は `Eff.empty` なので、待機中の guard の本体の前に実際に set が挟まる遷移はない。実質の検査は `extension_guard`・`extension_capture` のストア拡張にある。`results.md` の「書込み後にも壊れない」に、この区別を一文足す。

**軽6. 実行の代表と保存の代表の接続、および `f` の仮引数の名前**（読めば確定）。

- `execution` の s4 と s7 は `.mk capR …`・`.mk capX …` の呼出しであり、4本の保存の代表（`Closure.pure` のみ）の対象でない。`pure_get_start`・`pure_set_start` は別の状態である。9遷移のうち保存の代表が直接扱うのは s1 の new だけである。`results.md` は範囲を明記しているので誤りではないが、Φ の閉じ方が効く位置は L20 に残る。「D19 の方式が破れる反例は得ていない」の根拠の範囲として、L20 の行に s4・s7 の形を名指しする。
- 形式側の `Ty.LeQ` は `fn` と `Tel.param` の名前を保つので、`update` の `f` は仮引数の名前が `value` の関数に限られる（`identity` がそうである）。旧体系からの既存の形であり、本作業の変更ではない。Rust の型検査が名前の違う lambda を受け取るかは確かめていない。L30 の Rust との照合の入力に足す。

## 確かめて問題がなかった重点

| 重点 | 結果 |
|---|---|
| Reference の不変性 | `Ty.LeQ` に reference の規則はなく、`refl`・`convert`・`trans` と refined の規則だけが関わる。`refCore_right` で正規形の等号に落ちる。data にも共変の規則はない。`loc_not_small` と `le_under_false` で再現して確かめた |
| 違反する値の書込み | `CellOk.val_write`・`val_read` は `b.norm = a.norm` を要求する。`Reference[Integer]` の場所を `Reference[Integer{self < 8}]` として渡せず、`cell_rejects_nine` で 9 を載せたセルを否定した |
| 別名と現内容 | 述語は Reference の変数を読めない（`reference_var_no_sort`）。`CaptureOk` の事実は `Pred.Sorted Γ none` を満たし、`predBind` の閉じた事実だけである。`.loc` の項は `none` である。`CaptureOk.store` が保つのは値の項の事実だけである。`Ty.assume` は Reference の内容へ入らない |
| get の結果型 | `BuiltinArgs.reference_get` は型引数 `x` を返し、`canonical_ref` がセルの型との正規形の等号を与える。Φ の外部の入力はない |
| 開始からの保存 | 4本とも `StateTyE` を分解し、到達の型付けを入力に含まない。入力は `CoreAssumptions`、開始の状態、`B.sig`、kind、新しい場所（または読むセル）、update の `ReferencePrimitives` だけである。`Eb`・継続・最終の型は `K_Sub` で同じものへ戻る |
| `pullback` と `primitive_call` | `TelClosure` の推移は `tel_narrow` の Transport で文脈を狭め、中間の型付けを仮定しない。`C_App`・`C_DependentApp`、`V_Normal`・`V_Sub`・`V_Refine`、`C_Sub`・`C_Eff`・`C_Normal` を扱う |
| `ReferencePrimitives` の空虚さ | 入力は二つの組み込み値の型付けだけで、具体の表で構成できる（境界の `update_saved`・`update_pair`、`rv-14c-t1.lean` の `raw_primitives`）。到達の計算・閉包・状態を含まない |
| 正規化した型引数 | `pure_primitive_view` が `Ty.normTys ts` の view を返し、`E_RefUpdate` の `ts` と一致する。非正規の `[Integer{true}]` でも入力を作れる |
| update の代表 | `.closure runtime body` への限定は `results.md`・`signatures.md` と一致する。`update_body` は任意の `f` で閉じ、`R` は `pure_replace` で開始の閉包から再利用する。`Eff.empty` の `f` は set を行えない |
| ストアの拡張 | `allocate_reference` は `μ l = none` から `Ψ l = none` を領域条件で導き、有限性・WF・Declared・領域・全セルの移送を示す。`write_reference` は `l` 以外のセルを変えず、`Ψ l = .ref` の場所のセルは `.val` だけである。Cell 6形、ContTy 10構成子、GuardBodyTy 1構成子を確認した |
| 観測 | Reference に sort はなく、`.loc` の項は `none` である。`Pred.eq`・`le`・`lt` は integer、`compare` は `Comparison.Allowed` の scalar だけで、data・list の構造の等号は述語にない。欄が欠落した項どうしで偽の結論を出す経路はない。`eq_refl` は同じ項の反射だけである。`FieldRef.Declared` は `(a.subst ts []).HasSort` を要求するので、`G[Reference[...]]` の欄も読めない |
| RootShape と match | 根の `constructorIs` は不変で、欠落の欄を補っていない。L00b.14b-paths の部分的な像と矛盾しない |
| guard | `guarded` の規則の `Eff.empty` は既存で、[01-05](../../design/01-spec/01-05-data-types.md)の「エフェクトを持ってはならない」と一致する。`guard_with_set_untyped` は効果の被覆の逆転で否定し、結果型に頼らない |
| 境界の実在性 | `execution` は実際の `Step` である。`body_needs_snapshot_fact` は `x = 9` のモデルで否定するので空虚でない。`program_start` の結果型は Integer で、`final_typed` の篩は閉じた評価の Φ から来る。元のソースの get が篩を推論したと読める記述はない |
| 件数 | 値29、計算24、Step 76、ContTy 10、Cell 6、公開30（定義2・補題28）がコードと一致する。`verification.json` の三族の 76 は既存の値で、変更はない |
| 記録 | `l00b.14c/` と依頼に手元の絶対パスはない。`docs/todo/` へのリンクはない。本番の既存の判断・遷移は変えていない |

## 五つの境界

主な定理の前提と結論、新しい公理、提供範囲、利用者の書ける形、精密な外部状態のいずれも、今回の変更は動かしていない。中1だけが、次の段で「主な定理の前提」に触れることを予告する。

## L20 への入力

中1の処置に加え、任意の捕捉を持つ呼出し元（s4・s7 の形）の Φ の閉じ方を L20 の最初の代表とする。`update_body` は任意の `f` で閉じているので、残るのは閉性と Adequate の移送である。進行の側の `get` のセルが `.val` であることは、`canonical_ref`・領域条件・`CellOk` から導けるが、今回は言明していない。

## 取りまとめの追記

2026-11-01。補助の入力は `l00b.14c/rv-14c-t1.lean`・`t3.lean` へ写した。中1は残件にせず、`plan.md` の先頭の判断のとおり、この作業のうちに `CoreAssumptions` と `StoreShape` を強め、`ReferencePrimitives` を導く形へ改める。軽1〜6 は同じ再開で処置する。
