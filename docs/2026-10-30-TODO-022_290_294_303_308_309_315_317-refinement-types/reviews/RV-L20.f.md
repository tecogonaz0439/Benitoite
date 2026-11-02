# RV-L20.f: L20 群 F・G（L20.71〜.84）の独立レビュー

2026-11-02。対象はブランチ `m014/l20.f` の未コミットの作業木、基準 `ee5fe230`。依頼文 `L20.f-prompt.md`、担当の報告、`l20/f/` の記録、`l20/detail.md` の S05・S06・S10、L20.71〜.84、義務 O008・O056・O058・O136・O139・O140・O143、`plan.md` の確認点を読み、新規の Lean 11ファイルを全文読んだ。補助の入力は `<tmp>` に置き、既存のファイルを変えていない。

## 総合判定

**条件付き可**。重 0 件、中 1 件、軽 5 件。

Lean の本体に誤りは見つからず、二つの S06 の入口、closeVal の33 case、七つの遷移の葉の言明はそのまま受け入れてよい。行先の型付けを仮定に隠す形、弱すぎて使えない形、新しい公理、既存の規則の変更はない。条件は記録の修正である。中1は、S05 が求めた view の契約の形と実物の差が「計画との差」に書かれておらず、記録の表が実物より多くを保持すると読める点である。定理の言明、型付けの規則、公理には影響しない。

## 所見

### 中

#### 中1: ClosureViewTy は通常値だけを持ち、S05 の「値・型・行を列挙する case の形」との差が記録にない（読めば確定）

- 場所: `formal/Benitoite/Release/Refinement/ClosureViewTyping.lean` 103〜114行、`l20/detail.md` 362行（S05）、`l20/f/results.md` の「実行の view の16構文」の表と「計画との差と申し送り」。
- 問題点1: S05 は「16構文形すべてについて、一歩で閉じる値・型・行と、そのまま cap に残す子コードを列挙する case 定義の形」と書く。実物は構成子一つの判断で、閉じた型付けを持つのは `readValues` の値だけである。結果の a・e・R は等号で保持するが、各構文の枝はない。
- 問題点2: `results.md` の表の見出しは「一歩で閉じる通常値・注釈」で、builderLet・builderOp の kind、externalCall の型像、checkAt の errorType を載せる。meth の型・行像も載せる。`ClosureViewTy` と `view_typed` はこれらの像の注釈を返さない。閉じた計算全体の型付けを返すのは `app_view_typed`・`method_view_typed` だけで、値は `ret_view_typed` が返す。残りの枝の値は `∃ t` であり、たとえば条件値が boolean であることは返さない。
- 確認: 元の導出と `CaptureOk` が `ClosureViewTy` に残るので、情報が失われたわけではない。`close_app_aux`・`close_method_aux` と同じく C_Sub・C_Normal・C_Eff を通す補題で取り出せる見込みである（他の構文の枝は未実行）。S05 も捕捉を失う型付けを要求していないので、言明の修正は要らない。
- 影響: 後続の L20.110〜.115 が externalCall・builderOp・checkAt の葉を作るとき、この表から閉じた kind・型像の注釈が既にあると読むと、見積もりと依頼文を誤る。S05 の全契約を閉じたとする .78 の判定も、この範囲で過大である。
- 修正案: `results.md` の見出しを「実行が閉じる物」と「`ClosureViewTy` が型付きで保持する物」の二列に分け、kind・型像・errorType は後者に含めない。「計画との差」に、case 定義の形でなく単一の判断にしたことと、型・行像の取り出しを L20.110〜.115 へ送ることを書く。

### 軽

#### 軽1: 値依存の等式を「使う」と書くが、群 F・G の証明に読者がない（読めば確定）

- 場所: `results.md` の「七つの遷移と依存β」末尾の段落と .83 の行、`01-12-core-calculus.md` の追加段落「型置換と捕捉による値の置換は」。
- 問題点: `Capture.closeTyAt_typeSubst` など四等式の読者は `TypeValueExchange.lean` の中だけである。`close_pred_apply_all`・`close_facts_apply_all` の読者は本番にない。関数とメソッドの葉の捕捉は空から作るので、今は要らない。`results.md` の「既存の TypeValueExchange の四等式を使う」は、使用先があると読める。等式そのものは任意の述語・Φ について証明済みで、O136 の .83 の言明は満たす。
- 修正案: 「公開した。群 F・G の葉には読者がなく、最初の読者は値依存の入口を扱う後続の単位である」と書く。

#### 軽2: 環境を捨てる反例の記述が 07-04 から消え、保管の入力は現行の定義で通らない（実行で確定）

- 場所: `07-04-formal-semantics.md` の「捕捉した Φ」の行、`l20/detail.md` 1497行（O008）、`l00b.14b/boundary.lean` 129行。
- 問題点1: 基準の行にあった「環境を捨てる場合の反例と区別する」を今回の変更が消した。O008 の .71〜.84 の条件は「環境を捨てる旧反例を保つ」であるが、`results.md` に記述がない。
- 問題点2: 反例は既定ビルドの外の `boundary.lean` にある。現行の定義で実行すると `body_typed` が2件の誤りになる。原因は C_If の前提の変更で、群 F・G の変更ではない。ほかの宣言の誤りは出ない。
- 修正案: 07-04 の句を戻す。`boundary.lean` の `body_typed` を現行の C_If へ直して再実行するか、O008 の「保つ」の検査先を改造の末の項目へ移すことを記録する。

#### 軽3: 新しい語が既存の設計書と用語集にない（読めば確定）

- 場所: 01-12・07-04 の追加段落。
- 問題点: 「全適用」「子コード」「構築器操作」は基準の二文書と用語集にない。「通常と依存の全適用」の「通常」は、01-12 の「非依存」と違う語で、通常 lambda とも紛れる。
- 修正案: 「全引数の適用」「非依存の入力列と依存列」「残す本体のコード」「構築器の操作」と書く。

#### 軽4: ClosureCallInputs が 07-04 に現れない（読めば確定）

- 場所: `07-04-formal-semantics.md` の追加段落。
- 問題点: 新11モジュールのうち `ClosureCallInputs` だけが本文にない。閉包と宣言の呼出しの逆転を担うモジュールである。対応表には他の多くのモジュールもないので、表の欠けとはしない。
- 修正案: `ClosureApply` か `CloseApplication` の文に一句足す。

#### 軽5: 体裁（読めば確定）

- 場所: `formal/Benitoite.lean` 末尾、`ClosureApply.lean` 158行ほか。
- 問題点: import の間に空行が二つ入る。`ClosureApply.lean` に160字を超える行が2行ある。
- 修正案: 空行を消し、長い行を折る。証明には影響しない。

## 観点ごとの確認

### 1. S06 の二入口

- `ClosureTy.apply_all`・`DependentClosureTy.apply_all` の言明は S06 の予定どおりで、`signatures.md` と一致する。
- 供給元を確かめた。`ContTy.apply_let` は K_Let の `ClosureTy [x]` へ `V_Sub` で移した実引数を渡す。E_Lam は `app_view_typed` → `closure_inputs` で `HasTypeTelArgsQ` を任意の元状態から得る。Ground は `view_read_ground` が `q.ClosedAt 0` から導く。どれも入力に新しい仮定を足さない。
- R は `hc.mapReturn` で移し、K_Let では `return_wf`・`return_normal` から shift と代入が消える。依存版は `some a` で、`markPush` の K_Mark と合う。結果の a・e も K_Let で閉じる。
- `(Closure.mk cap b).apply ws = .mk (cap.extendMany ws) b` が `rfl` なので、E_MatchBody の行先にも同じ入口を使える。ただし腕の事実を足す `Φ` の分は `CaptureOk.bindParams` の範囲外で、後続の担当である。
- `apply_all` は `StoreOk` から `Ψ.WF` しか読まず、`hP`・`hPB` も読まない。S05・S06 の固定どおりで、主定理から供給できる。`hideBuilders Ψ` で要るときは `Ψ.WF` だけを取る `TelBodyTy.capture_all` を使える。

### 2. closeVal の33 case

- 環境から構成子数を読み、値29・値列2・各要素2、計算24、Comp 16、ContTy 10 を確かめた。`close_value_aux` の枝は、葉18と個別11で29である。
- `hleaf.subst` の18枝は `simpa only [closeVal, Val.subst, ...]` がカーネルを通り、closeVal と一致する。V_Var もこの枝にある。
- V_Lam・V_DependentLam は本体と cap を保ち `.closure` を作る。V_Closure は同じ値を保つ。空の Each は `.nil` だけで形成を要求しない。V_Refine は `hc.conditions` 由来の `tr.entails` で閉じ、Φ の真を別に仮定しない。

### 3. view と16構文

- `Comp.readValues` と `Closure.view` を突き合わせ、16構成子の通常値がすべて一致することを確かめた。resume の k だけが除かれる。01-12 の列挙は実物と一致する。
- `Comp.readValues_resolve` と `resolve_id` により、読む値は局所参照の解決で変わらない。子コードと ρ は `q = .mk cap (source.resolveLocals ρ)` が保持する。差は中1である。

### 4. 七つの遷移の葉

- 行先を `Refinement/Semantics.lean` の構成子と一字ずつ比べた。E_Let・E_Return・E_Lam・E_Fun（`d.body.substTy ts es`）・E_Meth（`ss ++ ts`、`vs ++ ws`）・E_Super・E_Mark とも同じである。前提は規則の view・lookup・個数だけで、行先の型付けを含まない。
- `StateTyE` 版は同じ σ・Eb を返し、`StateTy` 版は `hσ`・`Eb`・`hEb` をそのまま渡す。
- 補助の入力で、依存 lambda、通常 lambda、捕捉した変数が閉包である零引数の場合へ `dependent_beta_all` を適用した。`q.view` の等式は `rfl` か定義の展開で与えられ、任意の元 `StateTyE` から成り立つ。
- 引数の順序は `(Capture.empty.extendMany [v,w]).env 0 = w` で確かめ、`bindParams`・Tel・E_Meth の順と合う。

### 5. 既存の宣言の変更

- `git diff` の formal は追加と改名だけである。`normal_return_tail` の private を `_base` へ改名し、同じ言明の公開入口を足した。ほかは既存補題の公開の別名6件である。規則・定義・既存の言明の変更はない。`Typing.lean`・`StateTyping.lean`・`ConstraintAssumptions.lean`・旧 `Semantics.lean` に差分はない。

### 6. 公理と署名

- 新11ファイルに `sorry`・`axiom`・`native_decide`・`unsafe`・`implemented_by`・`instance`・属性はない。`set_option` は `maxRecDepth` の2件だけである。import の除外はない。
- `lake build --no-build` は全対象 up-to-date（818 jobs）である。`axioms.lean` を再実行し、846回、16モジュール798宣言、`sorryAx` 0件、公理は `propext`・`Classical.choice`・`Quot.sound` だけであることを確かめた。この実行の最大常駐量は 1,684,717,568 バイトである。
- `signatures.md` の定理105件の見出しを、抜き取りでなく全件、ソースと空白を正規化して比べ、差は0件である。定義2件と判断1件も記載がある。

### 7. 記録の主張

- 手書きの宣言は定理105・定義2・判断1の108件に既存への追加7件で、115件（定理112）と一致する。`inputs.sha256` の22件は現在のファイルと一致する。
- 記録と設計書の追加部分に、手元の絶対パス、docs/todo へのリンク、`work/` を出どころとする参照、「費用」の語、変更の経緯の文はない。
- RSS の未取得は `implementation-request.md` の扱いどおりである。01-12・07-04 の写しは、軽1・軽2・軽3・軽4の点を除き Lean と一致する。まだ証明していない全76遷移を済みとは書いていない。

## 推測と確定の区別

- 実行で確かめたもの: 公理依存の再実行、構成子の数、`dependent_beta_all` の3通りの適用、`apply` の等式、`boundary.lean` の失敗。
- 読んで確定したもの: 中1、軽1、軽3〜5。
- 推測: 中1の「他の構文の枝も同じ補題で取り出せる」という見込みだけである。

## 取りまとめの追記

2026-11-02。中1と軽1〜5を再開1で処置した。中1は記録の修正とし、各構文の型・行像の取り出しを L20.110〜.115 へ送る（`plan.md` に記録）。軽2は保管の入力を変えず、要る宣言を現行の C_If に合わせて `l20/f/boundary.lean` へ写して通した。処置の後の作業末の work は成功した。局所の再レビューは行わない。処置は記録と体裁だけで、Lean の言明を変えないためである。
