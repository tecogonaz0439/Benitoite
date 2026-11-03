# RV-L40.b: L40 群 B（L40.06〜.11、構文の逆転と F3 の適用）の独立レビュー

2026-11-03。対象はブランチ `m014/l40.b` の未コミットの作業木、基準 `7f99d078`（san_benito の先端）。新規の Lean 5本（CollectionInversion・ComputationInversion・StandardVariance・ApplicationInputs・ApplicationFormationExamples）は全文を読んだ。既存の変更（ValueInversion・TelApplication・ReferenceCalls・`formal/Benitoite.lean`・01-12・07-04・plan.md・effort-ledger.md）は `git diff` で読んだ。群の記録は `l40/b/` の results.md・obligations.md・start-inputs.md・obstruction.lean・signature-check.lean・f02-signature.lean・axioms.lean・audit.py・signatures.py・verify.py・variance-sources.py と各 json を読んだ。担当の報告3件と依頼文3件も読んだ。

根拠として `l40/detail.md` の第2節、第4節の F01〜F03、第5節の L40.06〜.11・.15 の行と「最初の同種16件と残りの移植」、第7節、`l40/a/signatures.md`（F01〜F03 と「逆転の各枝の完全な命題」）、`reviews/RV-L40.a.md`、plan.md の「計画の変更と取りまとめへの確認点」の先頭の三項と「本番の実績を使う外挿と相談条件」、「義務の対応表」の L40 を含む行を読んだ。形は `RV-L40.a.md` に合わせた。補助の入力と再実行の出力は `<tmp>/rv-l40-b/` に置き、既存のファイルを変えていない。

## 総合判定

**可**（中1・軽4、情報2）。重の所見はない。中1は L40.15 への申し送りが群 B の記録の中にだけあることで、群 C の L40.15 を起動する前に取りまとめが処置すればよい。群 B の受け入れを妨げない。

F03 の二分割は妥当である。`obstruction.lean`（本番では ApplicationFormationExamples）の反例は、型パラメータのない文脈 `C=[]` に `.tvar 0` を結果に持つ関数を置いた Γ での、正当な raw の `C_App` 導出である。`V_Var` は型の形成を要求しないので、この導出は現行の規則で作れる。一方、`HasTypeTelArgsQ` は `open_telArgs_annotation` によって結果型の `WF` を与え、`Ty.LeQ … a (.tvar 0)` は `a.norm.core = .tvar 0` を強いるので `0<0` になる。無条件の共通化の否定（`common_application_false`）はこの論証どおりに証明されている。`inv_app` は直接規則の二枝の選言を無条件に返し、`app_tel` は Store の三条件と `CaptureContextRegular` を前提に共通の依存列へ移す。反例の Γ は `CaptureContextRegular` も `Ctx.WF` も満たさないこと（`context_not_regular`・`context_not_wf`）、結果を Unit にした同形では `app_tel` が実際に適用できること（`common_formed`）が既定ビルドにある。実際の開始は `StateTyE.app_inputs` が `StoreOk` の三条件と空の Γ から閉じた呼出しを取り出すので、後段の主定理が要る閉じた形は供給される。

F02 の `TelClosure.apply` は、`ws` についての帰納で任意の長さの実引数列を扱う。各段で同じ実値 `v` を `SubstOk.openValue` の Transport と既存の `TelLe.bind` で後続へ束縛し、Γ を変えないので `hΓ` を使い回せる。結論は同じ `ws` の元列 t への型付け・結果の `LeQ`・潜在効果の `Covers` である（効果の向きは `done_outputs` と同じく到達列の効果が元列の効果を覆う）。群 A の元の全前提から適用する匿名の例は ApplicationInputs（既定 import）にある。

## 所見

### 中

#### 中1: 全開始の未接続の行（B15-…）は群 B の start-inputs.md にだけあり、L40.15 の詳細の行と見込みに写っていない（読めば確定）

- 場所: `l40/b/start-inputs.md` の「値の全25形」「計算の全16形」「状態・枠・セル」の判定欄、`l40/detail.md` 第5節の L40.15/C の行（382行）、obligations.md の O058・O136 の行。
- 問題点: start-inputs.md は、F02 と `app_tel` の形成条件を本番で供給したのは実際の run（`StateTyE.app_inputs`・`primitive_contract_inputs`）と `Ctx.Regular` を持つ文脈だけと正しく区別し、残りを B15-Def・B15-Impl・B15-Capture・B15-Fn-（fnRef・op・lam・dependentLam・closure・raise・externalRef）・B15-Ret・Let・If・Match・Lazy・Escape・Use・Handle・Resume・Meth・BuilderLet・Guard として L40.15 へ名指した。供給できない行を供給済みとは書いていない。ただし、これらの記号と各行の接続の内容は detail.md の L40.15 の行（「q.view/元コード/捕捉から全開始入力を得る」）にも plan にもなく、群 C の担当が読む根拠に含まれない。特に B15-Fn-* の7形は、app の Step 葉で `inv_fnRef` 等の `SignatureInstance.result` から元列の Annotation を得て `TelClosure.apply` に渡す接続であり、prim で示した形（`primitive_contract_inputs`）を同じ数だけ繰り返す作業になる。L40.15 の見込み（50〜100分）がこの行数を含めて立てられたかは記録から読めない。
- 修正案: 取りまとめが、start-inputs.md の L40.15 への行（約20行）を detail.md の L40.15 の行の注か群 C の依頼文に写し、`primitive_contract_inputs` を雛形として示す。L40.15 の見込みにこの行数が入っているかを確かめ、入っていなければ群 C の起動の前に見込みを改める。

### 軽

#### 軽1: 07-04 の対応表と 01-12 の写しに、CollectionInversion と ValueInversion の今回の逆転が載っていない（読めば確定）

- 場所: 07-04 の篩の形式化の対応表の ValueInversion の行（938行）、01-12「篩の正規形と制約の読み方」の `HasTypeVQ.inv_var` の段落。
- 問題点: 今回 ComputationInversion・ApplicationFormationExamples・ApplicationInputs・StandardVariance の行は加えたが、同じ群の CollectionInversion には行がない。ValueInversion の行と 01-12 の段落は群 A の var と List のままで、`inv_fnRef`・`inv_prim`・`inv_op`・`inv_lam`・`inv_dependentLam`・`inv_raise`（関数の値は `fnCore` と `TelClosure` を返す）、`inv_dict`・`inv_super`（辞書の芯の等号）、Map・Set・Bytes の芯の射影（鍵は正規形の等号、値は `LeQ`）が写っていない。表は補題だけのモジュールを全部は載せないが、同じ群で一方だけを載せると、読者には CollectionInversion が写しの対象外に見える。results.md の初回の節の「補題と読者を追加しただけなので写しは変更しない」と、再開1の「01-12/07-04へ実装済み入口…を反映」とも揃わない。
- 修正案: 07-04 に CollectionInversion の行を加え、ValueInversion の行に関数の八構文のうち今回の6形と辞書の2形を足す。01-12 の inv_var の段落の後に、関数の値の逆転は芯の `fnCore` と `TelClosure`、Map の鍵は正規形の等号、Set の要素は正規形の等号、Bytes と辞書は芯の等号を返すことを一文ずつ写す。

#### 軽2: `HasTypeCQ.app_tel` の docstring が前提の範囲と合わない（読めば確定）

- 場所: `ComputationInversion.lean` 137行。
- 問題点: docstring は「実開始から得る形成条件を使い」と書くが、前提は任意の Γ・Φ での Store の三条件と `CaptureContextRegular` であり、実開始に限らない（実開始からの供給は ApplicationInputs の `StateTyE.app_inputs` が行う）。ApplicationFormationExamples の `common_formed` も実開始でない Γ に適用している。
- 修正案: 「Store の形成と文脈の CaptureContextRegular を使い、app の二枝を同じ依存列へ統一する」に改める。

#### 軽3: results.md の初回の節は、見出しで履歴と分からず、現在と食い違う記述が残る（読めば確定）

- 場所: `l40/b/results.md` の「停止した理由と固定署名の差」「16目的の判定と本番の配置」「旧31逆転の行き先と残件」「更新式へ渡す通常の記録」「義務・検査・申し送り」（20〜196行）。
- 問題点: 5行目に「初回と再開1の停止・保留の記述は履歴」とあるが、各見出しに履歴の印があるのは「単位の時刻（UTC、初回の履歴）」だけである。節の中には「群Bの完了とは判定しない」（太字）、「inv_app 未完」「01-12/07-04の写しは変更しない」「N_g=13」など、現在の判定と逆の記述が残る。途中から読む読者（L40.15 の担当、段末のレビュー）が古い値を拾うおそれがある。
- 修正案: 初回の節の見出しに「（初回の履歴）」、再開1の節に「（再開1の時点）」を付ける。現在値の表（旧31の最終表、N_g、16目的、F02 の確定した署名）への相対リンクを冒頭の判定の行に置く。

#### 軽4: verify.py の既定 import の確認は CollectionInversion の1行だけである（読めば確定）

- 場所: `l40/b/verify.py` の `assert "import Benitoite.Release.Refinement.CollectionInversion" …`、results.md「群末の記録の照合」。
- 問題点: 再開1で加えた ComputationInversion・ApplicationFormationExamples・StandardVariance・ApplicationInputs の import を確かめない。実際には audit.py の `NEW` がこれらのモジュールが既定の環境にあることを確かめており（再実行で700モジュールに含まれることを確認した）、漏れは起きていない。verify.py の確認の範囲を results.md が「既定import」と書くと広く読める。
- 修正案: verify.py の assert を新しい5モジュールの全部に広げるか、results.md に「既定 import の全確認は audit.py の NEW」と書く。

### 情報

#### 情報1: 九つの極性の組は `Polarity.compose` の表の計算である

StandardVariance の九組の例は、`compose` の9通りの値を `decide` で確かめる。定義の表の確認であり、九組それぞれの欄で受理・拒否を示したものではない。受理・拒否の対照は、実 Shrinker の欄（不変で受理、共変・反変で拒否）と七つの不変位置（Reference・Set・Map の鍵・Dict・external・継続・Fail）の例が別に担っている。detail の「9正負組」の要求の読み方としては足りる。

#### 情報2: 値逆転の外側の時間は読取りの時間を含まない

V の E_g（232.942秒で10件）は単位の区間だけで、results.md 115行のとおり読取りや計画の時間を含まない。このため E_g は能動時間の上限にもならない。c_V・c_C を未取得として旧見込みを保つ扱いは、plan「本番の実績を使う外挿と相談条件」の規則どおりである。担当の作業全体の外側の時間は effort-ledger の3行（約23分・約41分・約7分30秒）にある。

## 確認した事項

### 1. 反例と F03 の二分割（観点1）

- 反例の入力（`C=[]`、`Γ=[some (.fn [] [] (.tvar 0) Eff.empty)]`、`Q=Qempty`、`Φ=[]`、`R=none`、`.app (.var 0) []`）は、`V_Var` と `HasTypeVsQ.nil` で作る正当な raw の導出である。`tvar_source` は LeQ の14構成子を場合分けし、`dependentFn` 等の芯が tvar にならないことを `foldFn` の分岐で除く。否定するのは「任意の HasTypeCQ から共通の依存列へ」の共通化であり、直接二枝の選言ではない。同じ反例に `inv_app` を適用すると `C_App` の枝が出る（ApplicationFormationExamples の最初の匿名の例）。
- `app_tel` の C_App の枝は、`open_value_annotation` で関数の Annotation を得て `toTel_in_context` で正規化した依存列へ移し、`V_Sub` と `Ty.norm_toTel` で関数値の型を `.dependentFn` に読み替える。結果は `LeQ r.norm T`、効果は `Eff.covers_norm_right` で正規化した側を覆う。
- 実開始: `StateTyE` の run の定義（StateTyping.lean 159行）から `StoreOk` の三条件と `ClosureTy … q a e1` を取り、`ClosureTy.app_view_typed`（CloseApplication.lean 90行）で空の Γ・Φ の `HasTypeCQ` に移す。返す `a`・`e1` は state の同じ値である。供給できない行の扱いは中1に記した。
- start-inputs.md の形の数は、Syntax.lean の Val 25構成子・Comp 16構成子と一致する。

### 2. 16目的の署名（観点2）

- `signature-check.lean`（signatures.py が群 A の `signature-check.lean` から13命題を抜き出して生成）を再実行して終了0。群 A の固定命題（fnRef・prim・op・lam・dependentLam・raise・mapV・setV・bytesV・dict・super・let・escape）に本番の証明がそのまま当たる。`inv_lam_wf` は `inv_lam` の射影で、F01 の表の規約どおりである。
- 署名の差は results.md の差の表の F03 の二行（`inv_app` の選言と `app_tel` の新設）、内部の橋（`toTel_in_context`）、F02 の四前提の削除だけである。`inv_app` の二枝は群 A の C_App・C_DependentApp の各枝の命題の選言そのもので（変数名 `as`→`ps` だけが違う）、signatures.md 890行の「同じ構文の複数規則の出力は選言」の規約に合う。ほかに黙って変えた署名は見つからなかった。
- 値の逆転は、関数の値が `T.fnCore = some u ∧ TelClosure …`、Map が `T.norm.core = .map k w ∧ a.norm = k.norm ∧ LeQ b w`、Set・Bytes・辞書が芯の等号である。`V_Refine` の枝は到達関係をそのまま返し、元の型全体から T への LeQ を結論にしていない。RV-L40.a の重1の形（芯の等号と facts）に合う。

### 3. F02 の一般証明（観点3）

- `TelClosure.apply` は、`ws` の nil・cons と t の param・done で場合分けし、長さの合わない組を `param_inputs`・`done_outputs` の等号と `cases args` で除く。中間の到達列の Annotation を仮定せず、元列の Annotation を `Tel.annotation_open` で次段へ開く。
- 群 A の元の署名からの適用例は ApplicationInputs 9〜19行（既定 import）と `l40/b/f02-signature.lean` にある。後者も再実行で終了0だった。TelApplication の二引数の具体例も `apply` を通す読者になった。

### 4. 変性の有限表（観点4）

- `StandardVariance.constructors` の14行を実ソースと突き合わせた。`Option.bnt` 12〜15行（`Some(T)`・`None`）、`Result.bnt` 13〜16行（`Ok(T)`・`Error(E)`、型引数は T・E の順）、`Pair.bnt`（`Pair(A, B)`）、`Test/Property.bnt` 28〜37行（`record Shrinker[T]` の欄 `candidates: function(value: T) -> ShrinkStep[T]`、`ShrinkStep[T]` の `Done`・`Yield(T, function() -> ShrinkStep[T])`・`Skip(function() -> ShrinkStep[T])`）、`l40/a/keys/recursive.bnt`（A・B・Phantom）と、型引数の順・欄の数・関数の引数名・結果の型が一致する。record の欄名 `candidates` は ConDecl に現れないが、変性には関わらない。
- metadata は Option・Result・Pair・ShrinkStep・A・B を共変、Shrinker と Phantom を不変とする。`valid` は全14構成子の欄の Annotation・Kind・VarianceOK、arity、共変位置での出現、非出現の引数の不変を証明する。Shrinker の欄が共変・反変で拒否されることも別の例で示す。
- 八つの共変位置は detail 67行の列挙（List・Option・Result 成功・Result 失敗・Pair 左・右・Lazy・Map 値）と一致し、七つの不変位置も同じ行の列挙と一致する。Rust には変性の実装がまだなく、Rust の推論との照合は R10b 以降の範囲である（results.md もそう書く）。

### 5. 旧31逆転と N_g・時刻（観点5）

- 最終表（results.md 268行以降）の31行は、旧移植14（var は群 A）・既済み継承7・供給側の残件10で、detail「最初の同種16件と残りの移植」の N_g=10（N_V=1、N_C=9）と n_V=11・n_C=3 に一致する。
- 単位の時刻は差を計算して確かめた。初回 .06〜.08 は232.942秒、.09 は201.660秒、計434.602秒、再開1の .09 は261.051秒、再開2の .11 は163.148秒で、記録と合う。c_V・c_C の扱いは情報2に記した。

### 6. 公理・禁止構文・写し・義務・記録（観点6）

- 新規・変更の8本に `sorry`・`axiom`・`native_decide`・`#eval`・`implemented_by`・`admit`・`set_option` はない。`formal/Benitoite.lean` は import 5行の追加だけで、除外はない。
- 公理監査を出力先だけ `<tmp>` に変えて `axioms.lean` で再実行した。終了0、外側40秒、700モジュール・68,611宣言。生出力（11,998,440バイト）と対象名の一覧（4,158,492バイト）の SHA-256 は results.md 再開2の `48f24e07…`・`934da7df…` と一致した。依存集合は許可三公理の部分集合だけで、`sorryAx`・`ofReduceBool`・`error:` は0件である。今回のモジュールの件数（ValueInversion 48・CollectionInversion 21・ComputationInversion 17・ApplicationFormationExamples 14・StandardVariance 129・ApplicationInputs 4・ReferenceCalls 45・TelApplication 28）、`TelClosure.apply`・`param_inputs`・`done_outputs`・`app_tel`・`StateTyE.app_inputs` などの名前と、StandardVariance の private の宣言94件が対象に含まれる。群 A からの増分219（68,611−68,392）は results.md の内訳と合う。
- `obstruction.lean` の再実行は終了0で、private と match の補助を含む9宣言が許可三公理だけに依存する。
- 公開した入口には読者がある。`inv_lam` は `inv_lam_wf`、`dict_core` は `inv_dict`、`toTel_in_context` は `app_tel`、`param_inputs`・`done_outputs` は `apply`、`app_inputs` は `primitive_contract_inputs`、`capture_context` と `covariant_positions` は同じファイルの例が読む。使わない前提は F02 から除かれた。名前と docstring の不一致は軽2に記した。
- 01-12・07-04 の追加は Lean の前提と一致し、経緯の文はない。欠けは軽1に記した。
- obligations.md の64行は群 A の64行と同じ義務の番号の集合である。全体の閉鎖を書いた行はなく、O058・O136・O139 の「確定」は F02 の署名の確定を指し、全開始の接続は L40.15 に残すと書いている。
- 記録は全て100 KB 以下（最大は results.md の53,804バイト）。手元の絶対パスと docs/todo へのリンクはない。work の3回の実行は、初回・再開1・再開2の各実装状態で一度ずつであり、生出力（一時領域）の SHA-256 は checks.json と一致した。

## 補助の入力

`<tmp>/rv-l40-b/` に置いた。

- `obstruction.log`・`signature-check.log`・`f02-signature.log`: 群の記録の3入力を `cd formal && lake env lean -M 12288` で再実行した出力。いずれも終了0、誤り0。
- `axioms.log`・`targets.txt`: `axioms.lean` を `L40_AUDIT_TARGETS` だけ一時領域に向けて実行した生出力と対象名の一覧。audit.py は要約を改造のディレクトリへ書くので使わなかった。
- 本レビューからはビルドを起動していない。`scripts/check.sh --level work --base 7f99d078 --dry-run` は選択の確認のためだけに実行した（spec_tally・spec_examples・formal_build が選ばれ、記録の resume2-work と同じ）。

## 取りまとめの追記

- 反例への判断（F03 の二分割）と F02 の4前提の削除は plan.md の 2026-11-03 の項に記した。
- 中1は、start-inputs.md の L40.15 へ渡す行（B15-*）を群 C の依頼文へ写し、`primitive_contract_inputs` を雛形として示して処置する。L40.15 の見込みがこの行数を含むかは群 C の結果で確かめる。
- 軽1〜4・情報は担当の再開3で処置した（docstring と文書だけの変更なので再レビューは置かない）。
- 作業末の work は終了0、166.38秒、最大常駐量 1,709,309,952 バイト（l40/b/results.md）。
