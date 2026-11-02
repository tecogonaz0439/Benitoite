# RV-L20.l: L20 群 L・M（L20.106〜.114）の独立レビュー

2026-11-02。対象はブランチ `m014/l20.l` の未コミットの作業木、基準 `2f2a2790`（san_benito の先端）。依頼文 `L20.l-prompt.md`・`-r1-prompt.md`・`-r2-prompt.md`、担当の三つの報告、`l20/l/` の記録（results.md・signatures.md・stop.md・axioms.lean・各 json）、`plan.md` の確認点の先頭の2行、`l20/detail.md` の S04・L20.110〜.114 の行を読んだ。新規の Lean のうち ReadLocalRefs・LocalInvariant・HiddenCaptureBoundary・CaptureReadBoundary・StoreReplyLeaves・ReplyState・SourcePreparation を全文読み、StateLeaves・ExternalStateLeaves・AtStateLeaves・AtStateInputs・PathBasesLeaves・BuilderStateLeaves・StoreGeneral・ContinuationGeneral は言明を、既存の変更は `git diff` で読んだ。照合のために `Semantics.lean` の Step 全体と、旧 Release の `Lemmas/LocalInvariant.lean` を読んだ。補助の入力は `<tmp>/rv-l20-l/` に置き、既存のファイルを変えていない。

## 総合判定

**可**。重 0 件、中 0 件、軽 6 件。

新しい条件は、後段が要る強さを持つ。`StateTyE.builder_live` は、現在の view の専用操作が指す場所に実在する builder セルがあることを、任意の StateTyE から導く。None の位置を一律に無視した空虚な条件でもない。補助の入力で、存在しない場所を直接実行する状態を `LocalStateInvariant` そのものが拒否することを閉じた。型付きの値は、存在しない場所を実行する閉包を通常の位置に持てないことも閉じた（後述「確認した事項」1）。取りまとめの判断（「実行に使う」をストアの参照・更新とコードの実行に限る）は、δ・IO・外部・At の応答がすべて契約の型付けを経ることから支えられる。読まれない位置の値が、型付けを経ずに導出の読む位置へ移る経路は、実物との照合でも見つからなかった。23遷移の葉の行先は Semantics の規則と一致し、`store_reply` が実際の `Step` を返すので機械的にも保証される。公理の監査を独自の対象の一覧で再実行し、許可された3公理だけを確認した。

軽の所見は、記述の精度（軽1・軽3）、記録の再現性（軽4・軽5）、具体例の範囲（軽2）、後段への申し送り（軽6）である。言明・規則・公理には触れない。

## 所見

### 軽

#### 軽1: `Closure.LocalRefs` の経路条件 Ξ は捕捉元の Φ と結ばれておらず、記録の「残す」が実物より強い（読めば確定）

- 場所: `formal/Benitoite/Release/Refinement/LocalInvariant.lean` 8〜14行（`Closure.LocalRefs`）、`l20/l/results.md` 29行、01-12 と 07-04 の追加段落「実行の閉包には元の導出と局所参照の解決の対応も残す」。
- 問題点: `ClosureTy` の導出は `liftMany ss.length Φ` で検査するが、`Closure.LocalRefs` は Ξ・R・Rs・a・e を存在量化し、Ξ と Φ の関係を持たない。guard の本体だけでなく、すべての閉包でそうなっている。`TypeAnnotations` も残していない。results.md の「guard 本体の追加条件 Ξ は捕捉元の Φ と別の証人として残す」は、Ξ が Φ と関係付いた別の証拠であるように読める。専用参照の条件としては、何らかの導出があれば足りるので、証明には影響しない。後段は StateTyE を同時に持つので、情報も失われない。
- 修正案: results.md と設計書の文を「実行の閉包には、同じ捕捉の CaptureOk と、ある経路条件の下の元の導出と局所参照の解決の対応を残す。経路条件・型注釈の一致は StateTyE の ClosureTy が持つ」と実物どおりに改める。

#### 軽2: `store_reply` の具体の適用は E_Err の一構成子だけで、値を返す応答の葉には具体例がない（読めば確定）

- 場所: `CaptureReadBoundary.lean` 298〜307行（`hidden_capture_reply_states`）、`modelBuiltins`（`delta` は常に err、`ioResponse` は常に偽、外部宣言は空）。results.md 58行。
- 問題点: 23構成子の葉には `store_reply` という読者があり、各葉は一般に証明されている。しかし同時に満たせる表で適用した例は E_Err だけである。δ・IO・外部の正常値と At の成功の葉は、前提が規則の前提と StateTyE と表の三条件だけなので、空虚になる心配は小さい。ただし、具体の表で値を返す応答の契約（`delta_typed` の val の枝、`io_typed`）を満たした例はない。results.md の「この具体表は検査のためのモデルであり、全実表の充足や IO/外部の応答の存在の証明ではない」は正しいが、どの葉に具体例がないかは書いていない。
- 修正案: results.md に「具体の適用は E_Err だけ」と一文で書く。可能なら、同じモデルに val を返す pure の組み込みを一つ足し、E_Prim の葉を一度適用する。

#### 軽3: `InitialPrepared.source_state` の三つの結論のうち二つは入力そのものであり、設計書の「構成する」が強い（読めば確定）

- 場所: `SourcePreparation.lean`、`Preparation.lean` 143〜146行（`InitialPrepared` は `σ.Ready` だけを持つ構造体）、01-12・07-04 の追加段落「その初期状態の StateTy と PathEnv.Ready を構成する」、results.md 52行「InitialPrepared とソースの型付けから同じ初期状態の StateTy/Ready/ExternalWF へ接続」。
- 問題点: 結論の `σ.Ready` は `h.ready`、`P.ExternalWF` は入力の `hext` をそのまま返す。実質の内容は、型付きのソース計算・注釈・閉性・適格性・BuiltinOnly から初期状態の StateTy を作ることである。StateTy の `σ.Valid` も `h.ready.1` から取る。主定理の入力から供給できるかは、`HasTypeC … m a e`・`m.ClosedAt 0 0`・`m.Adequate σ`・`BuiltinOnly P B e`・`σ.Ready` を表層から作る L70 の担当であり、この区別は文書に書かれている。具体の読者 `prepared_unit_source`・`prepared_unit_concrete` は、反例のモジュール `CaptureReadBoundary` に置かれていて、名前からは探しにくい。
- 修正案: 設計書の文を「…を受け、その初期状態の StateTy を構成する。PathEnv.Ready と ExternalWF は入力をそのまま返す」に改める。具体の読者の置き場所は、取りまとめが残すか移すかを決める。

#### 軽4: 公理の監査の対象の一覧が改造の中になく、記録から再実行できない（読めば確定、実行で確認）

- 場所: `l20/l/axioms.lean`（対象を環境変数 `L20_AXIOM_MODULES`・`L20_AXIOM_DECLARATIONS` の一覧から読む）、`audit-summary.json` の `targets`（`audit-modules.txt` 1,144 バイト、`audit-declarations.txt` 3,830 バイト。いずれも `<tmp>`）、results.md 103行。
- 問題点: 二つの一覧は合わせて5 KB に満たない小さな入力で、O016 の結果の根拠である。AGENTS.md は、結果の根拠になる入力・台本を改造のディレクトリへ写し、大きな生の記録だけを大きさと SHA-256 で残す、と定める。今の記録からは、25モジュールと78の明示対象が何かを確かめられない。本レビューは、作業木で変わった Refinement の22モジュール（新規19と変更3）を自分で並べ、同じ台本で再実行した。終了0、1,421定数、依存する公理は propext・Classical.choice・Quot.sound だけ、`AUDIT_EXISTING_COMPILER_REC` は2件だった。結論は記録と食い違わないが、件数の照合はできない。
- 修正案: 二つの一覧を `l20/l/` へ写し、results.md から相対リンクで引く。`declarations-full.json`（35 KB）は大きさの判断を取りまとめに委ねる。

#### 軽5: RSS を今回も採っておらず、依頼文の雛形に採取の指示がない（読めば確定）

- 場所: results.md 76行の O027（「RSS は本体と計測器とも未取得」）、`L20.l-prompt.md`・`-r1-prompt.md`・`-r2-prompt.md`（RSS・`/usr/bin/time -l` の語がない）。
- 問題点: RV-L20.j の軽5で、依頼文の雛形に RSS の採取を足すことを修正案にした。L20.j の再開1では採ったが、この群の三つの依頼文には指示がない。担当の誤りではなく依頼の欠けである。参考として、本レビューの公理の監査（22モジュール）の最大常駐量は 1,732,165,632 バイトだった。
- 修正案: 取りまとめが依頼文の雛形に、作業末の検査を `/usr/bin/time -l` で包み最大常駐量を results.md に残す指示を足す。

#### 軽6: δ の契約は閉包の内部を読むことを許すので、捕捉を刈り込む処理系との対応で前提が要る（読めば確定。後段への申し送り）

- 場所: `CaptureReadBoundary.primitive_reads_hidden_capture`、plan.md の確認点の先頭の行、07-04 の追加段落「信頼条件から、実引数の閉包内の未使用位置を読まない性質は導かない」。
- 問題点: 取りまとめの判断は、専用セルの有効性と型の保存については正しい（「確認した事項」2）。ただし、この判断は δ が閉包の構文を観測してよいことを残す。Rust の処理系が使わない捕捉を保持しない場合、Lean の実行と処理系の実行を対応付ける後段（Rust と Lean の比較、表層からの合成）では、δ がこの観測をしないことを別に仮定するか、比較の対象から外す必要がある。現在の主な10言明は型安全性と効果の健全性なので、この点は言明の誤りではない。
- 修正案: 取りまとめが、Rust と Lean の接続を受け持つ単位の確認点に「δ・IO・解放・外部の応答は閉包の内部の構造に依存しない」ことの扱いを一行足す。docs/todo への登録の要否は設計者が決める。

## 確認した事項

### 1. 新しい条件の強さと空虚でないこと

- `LocalStateInvariant` の形は、旧 Release の `Lemmas/LocalInvariant.lean` の同名の定義を Capture へ拡張したものである。旧の定義も StateTy から導く形で、最後の連言（型付きの値は自由な専用参照を持たない）も同じである。この連言は状態に依存しない定理であり、補助の入力で単独に閉じた。旧と同じ形なので所見にしない。
- 保存は、`StateTyE.local_invariant` によって StateTyE の保存に帰着する。全76遷移で保存を別に示す必要はない。旧の `local_steps_invariant` に当たる合成はまだないが、StateTyE の全保存が L70 の担当なので、results.md の「全76遷移の保存は後段」と合う。
- `StateTyE.builder_live` は存在だけを結論し、セルの内容の種類と操作の一致は結論しない。E_BuilderOp の進行には `builderApply` の成功が要り、これは StateTyE の CellOk と導出の kind から別に得る。後段の進行の証明はどちらも StateTyE から取れるので、欠けではない。
- 補助の入力 `check1.lean`（`lake env lean -M 12288`、終了0）で次を閉じた。
  - `reject_local_invariant`: `.run (場所7の copy を実行する閉包) [] Store.empty` について `¬LocalStateInvariant`。本番の `reject_executed_stale_builder` は StateTyE の否定であり、新条件そのものの否定はなかった。新条件が空虚でないことの直接の確認である。
  - `stale_value_untyped`: 場所7の専用操作を本体に持つ閉包は、どの Ψ・Q・C・Γ・Φ・型でも `HasTypeVQ` に型付かない。`HasTypeVQ.localRefs` の closure の枝が、builder を隠したストア型と `fun _ => False` で本体を検査するためである。
- `Capture.LocalRefs` は Γ の some かつ Ordinary の位置だけを検査する。非 Ordinary で継続でない位置（`ImageOk.hidden`）の値は検査しないが、`Ctx.Readable` が Ordinary を要求するので V_Var はその位置を読めない。継続の位置は `.loc`・`.var` の葉である。Transport により Γ・Φ と述語の参照は残る。

### 2. 取りまとめの判断と、型付けを経ない経路の有無

Semantics の76構成子のうち、値を新しく導入する入口を照合した。

| 入口 | 入る値 | 型付けの出どころ |
|---|---|---|
| E_Prim・E_IO の val | δ・ioResponse の応答 v | `delta_typed`・`io_typed` が同じ Ψ の HasTypeV と Ground を返す（`ReplyState` 54〜93行） |
| E_External | `externalReceive` の v | 受信の三条件（`external_value_all`） |
| E_AtOk | `checkedAt` と `AtRequest B name (closeVal …)` | 元の C_CheckAt と AtPrepared から CheckedWitness |
| E_RefGet・E_ForceDone・E_Force | セルの値・thunk | CellOk |
| E_Op・E_OpFail・E_OpPrim・E_Resume | view の実引数・値、節の本体、保存継続 | 元の導出、節の導出、CellOk の ContTy |
| E_MatchBody・E_MatchGuard | `firstAlt` の束縛 | 被検査値の型付けと PatTy |
| E_Super・E_Fun・E_Meth | 宣言の本体・上位辞書 | WellTyped |

上の `stale_value_untyped` により、契約で型付いた応答は、存在しない場所を実行する閉包を読まれる位置に置けない。型付いた応答の中の None の位置に何があっても、その位置を読むコードは型付かない。`releases` は保存継続の release・drop の枠だけを選び、捕捉の値を実行しない。results.md の76行の表のうち、E_Err・E_IO・E_RefUpdate・E_AtOk・E_DropRel・E_Op の6行を Semantics の規則と照合し、記述は実物と合った。

### 3. 23遷移と handler の残りの葉

- `StoreReplyInputs` の23構成子の前提と行先を、Semantics の同名の構成子と一字ずつ照合し、一致した。`store_reply` は各構成子から実際の `Step P B σ s event dest` を返すので、行先の一致は機械的にも保証される。件数は Reference 4・Lazy 6・δ/IO 5・外部 3・PathBases 2・At 3 で23である。
- 各葉の結論は同じ `StateTyE P B σ Eb` で、σ と Eb を固定する。行先のコードの型付けを入力に持つ葉はない。エラー・exit の葉は元状態と規則の前提だけを受け、`error_from_run`・`exit_from_run` で同じ StoreOk・ContTy を使う。
- handler の残り: E_Drop・E_DropRel・E_EscDrop・E_EscDropRel は `HandlerGeneral` の任意値の葉、E_ErrDrop・E_ExitDrop・E_ErrPopHandle・E_ExitPopHandle と解放の8遷移・E_Use も `HandlerGeneral` の一般の葉である。E_ResumeErr・E_ErrDropRel・E_ExitDropRel は既存の `HandlerPreservation.resume_used`・`err_drop_rel`・`exit_drop_rel` で、値や定数に限定していない。定数返却の代表（`drop_used_const`・`resume_const` など）は一般の葉に数えられていない。

### 4. 開始の準備

`prepared_unit_source` と `prepared_unit_concrete` は、同じ `modelProgram`・`modelBuiltins` について WellFormed・WellTyped・CoreAssumptions・ExternalWF・StateTy・Ready を同時に構成し、後者は有効な σ も具体に作る。表の条件を独立の仮定にしていない。L60（外部応答の存在）と L70（表層からの合成）に残す分は results.md と設計書で分けて書かれている。`InitialPrepared` の中身については軽3。

### 5. 既存の宣言の変更

- `HasTypeCQ.builderBody_image` は前提 `hΓ : Ctx.WF 0 C.length Γ` を外し、非 Ordinary の位置を `ImageOk.contVar` か `ImageOk.hidden` で扱う。結論は同じで、前提だけが減るので言明は強くなる。読者は `BuilderStateLeaves` 106行の一か所である。
- `ReferencePreservation.update_body` は名前を `reference_update_body` に変えて公開しただけで、前提と結論は同じである。読者は既存の `reference_update` と新しい `StateLeaves.reference_update_all` である。
- Typing・StateTyping・Semantics・ConstraintAssumptions の差分はない。

### 6. 公理・署名・設計書

- 既定の `lake build` は851 jobs、終了0。新規と変更のファイルに `sorry`・`axiom`・`unsafe`・`partial`・`implemented_by`・`extern` はない（`opaque` の一致は型の構成子の名前だけ）。
- 公理の監査は軽4のとおり独自の一覧で再実行した。
- 署名の一覧は 90,530 バイトで上限 100 KB の内にある。`LocalStateInvariant`・`StateTyE.local_invariant`・`builder_live`・`store_reply`・`InitialPrepared.source_state` を抜き取り、ソースと一致した。
- 01-12・07-04 の追加段落は Lean の名前と前提を実物どおりに分けて書き、変更の経緯の文はない。前提の表（δ/IO・外部・At・PathBases）は各葉の引数と一致した。「専用参照」「専用セル」「専用場所」「局所参照」は基準の 01-12 に既にある語である。
- 公開の記録に手元の絶対パスはない。追加の文に docs/todo へのリンクはない。依頼文が挙げた `capture-read-audit.js` は `l20/l/` になく、点検の要約は 580 バイトの `capture-read-audit.json` と results.md の表にある。

## 補助の入力

`<tmp>/rv-l20-l/` に置いた。

| ファイル | 内容 | 結果 |
|---|---|---|
| `check1.lean` | `reject_local_invariant`・`stale_value_untyped`・最後の連言の単独の証明 | 終了0、診断なし |
| `modules.txt`・`decls.txt` | 公理の監査の対象（変わった22モジュールと `store_reply`） | — |
| `axioms.out`・`axioms.time` | 同じ台本の出力と `/usr/bin/time -l` の結果 | 終了0、1,421定数、3公理、最大常駐量 1,732,165,632 バイト |

## 取りまとめの追記

2026-11-02。軽1〜4を再開3で処置した（正常応答の4例を既定ビルドへ足し、監査の対象の一覧を改造へ写した）。軽5は依頼文の欠けであり、作業末の work の最大常駐量は取りまとめが採る。軽6は `plan.md` に R 段への確認点として書いた。局所の再レビューは行わない。足したのは例と記録で、言明を変えないためである。処置の後の作業末の work は成功した。
