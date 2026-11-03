# RV-L40.c: L40 群 C（L40.12〜.15、全 canonical forms と開始の入力）の独立レビュー

2026-11-03。対象はブランチ `m014/l40.c` の未コミットの作業木、基準 `4d27a9306e76b51f0686d04338a574053755dd4d`（san_benito の先端）。新規の Lean 5本（CanonicalValues・CanonicalCells・ComputationInputs・LeafInputs・LambdaApplicationExamples）は全文を読んだ。既存の変更（Semantics・Step・CapturedFacts・ClosureStateLeaves・DependentBeta・ExternalStateLeaves・`formal/Benitoite.lean`・01-12・07-04・plan.md・detail.md・effort-ledger.md）は `git diff` で読んだ。群の記録は `l40/c/` の results.md・initial-results.md・start-inputs.md・leaves.md・obligations.md・obstruction.lean・axioms.lean・audit.py・run.py・verify.py と各 json を読んだ。担当の報告2件と依頼文2件、反例の独立調査 [RV-L40.c-obstruction.md](RV-L40.c-obstruction.md) と、それを受けた plan.md の「計画の変更と取りまとめへの確認点」の先頭の項も読んだ。

根拠として `l40/detail.md` の第2節、第4節の F03、第5節の L40.12〜.15 の行と群 C の行、第6節、第7節、第8〜10節、群 A・B の記録（`l40/a/signatures.md`、`l40/b/results.md`・`l40/b/start-inputs.md`）、[RV-L40.a.md](RV-L40.a.md)・[RV-L40.b.md](RV-L40.b.md)、01-12 の規範の E-Lam（321・867行）を読んだ。形は RV-L40.b.md に合わせた。git の操作、既存のファイルの変更、`lake build` はしていない。補助の入力と再実行の出力は `<tmp>/rv-l40-c2/` に置いた。

## 総合判定

**可**（中0・軽4、情報4）。重・中の所見はない。軽の4件は写しと記録の字句であり、群 C の受け入れを妨げない。E_Lam の変更そのものは取りまとめの判断のとおりで、plan.md の項が示すとおり設計者の見直しの対象として残る（軽3）。

E_Lam の変更は判断のとおりである。`Step` の構成子は増えておらず（`E_Lam` の暗黙引数に `f` を足し、前提を三つにしただけ）、`ws.length = signature.arity` は変更前からあった前提である。`closeVal Capture.empty (.closure t q) = .closure t q` は定義上の等号なので（Step.lean の適用例が `rfl` で通る）、既存の closure への遷移の前提と到達先は変わらない。新しく加わる遷移は、`closeVal Capture.empty f` が closure になる f、つまり lam・dependentLam・closure の三形に限られ（`var` は `.const .unit`、他の構成子は同じ構成子に閉じる）、lam・dependentLam を頭に持つ app は変更前にどの規則にも当たらなかった（`stepRun` の `| (.app _ _), _, _ => none`）。補助の入力で、view が `.app f ws` かつ `closeVal Capture.empty f = .closure t b` の run 状態からの `Step` は、事象も行先も E_Lam のものだけであることを証明した（「実行した検査」の節の `rv_elam_unique`）。Refinement には決定性の定理も `step_sound` もまだなく（L70）、`step_lambda` が変更した三枝の計算結果と `Step` を同時に返す。

`StateTy`・`StateTyE`・型付け・`CoreAssumptions` は差分に現れない（`git diff` の対象は上記の6本と `Benitoite.lean` だけ）。保存の葉は `lambda_beta_all` が `close_empty_typed`（`close_value_typed` と `CaptureOk.empty`）で空捕捉の closure の型付けを作り、既存の `inv_closure` と `apply_all` に渡す形で、`dependent_beta_all` は署名を保ったまま `rfl` で読む。CapturedFacts・DependentBeta の追随は新しい前提への `rfl` だけである。

反例の解消は仮定なしに成り立つ。`captured_and_direct` は obstruction と同じ捕捉変数の生 lambda の状態と、直接書いた同じ lambda の状態が同じ行先へ進むことを、`rfl` の前提だけで示す。`two_steps` は任意の P・B・σ で型付きの開始から二歩を構成する。`delta_return_path` は `B.delta … = some (.val nested)` と `sg.kind = .pure` を仮定とする経路であり、results.md「反例の解消とδの経路」は、具体の δ の表と `CoreAssumptions` の充足例を作っていないことを明記している。

canonical forms は型付けの導出から得ている。`valueForm_typed` は導出の帰納で型の符号と値の構文を結び、`V_Sub`・`V_Normal`・`V_Refine` は符号を保つ。tvar・tapp・ctor・cont の型の閉じた値は False に落ち、atError は `ResultShape.Declared` を返す専用の逆転に分けた。空の篩は `Inhabits` から排除し、raw な型付けからは排除していない。セルは `StoreOk` の二つの対応から六セルを返し、ref の内容は正規形の等号、Lazy は `LeQ` のまま返す。

B15 の全22行と76葉への供給は、記録の言う範囲で閉じている。start-inputs.md・leaves.md・obligations.md・results.md が名指す定理105件はすべて既定の環境に実在する（監査の対象名との照合）。供給元は `StateTyE.inputs`（全四状態）・`ClosureTy.inputs`・`HasTypeCQ.inputs`（全16構文）・関数七形の `*_contract_inputs`・`lambda_inputs`・`if_inputs`・`match_inputs`・`guard_op_inputs` で、いずれも既存の `StateTyE`・`StoreOk`・`CoreAssumptions` 以外の仮定を置かない。`ClosureTy.inputs` は `CaptureContextRegular` を保持し、完全な `Ctx.WF` を取り出すのは宣言の注釈から `Ctx.Regular` を得る `Def.WellTyped.inputs` の場合だけである。76葉の読者は匿名の適用例で、共通の `StateTyE.inputs` を既存の葉の開始と行先へ当てる形である（情報2）。

公理監査を出力先だけ `<tmp>` に替えて再実行し、705モジュール・68,912宣言、生出力と対象名一覧の SHA-256 が results.md の値と一致した。新5モジュールの環境の宣言は 111・22・43・44・47 の計267件で、手書きの公開60・private40・匿名の例107件も数え直して一致した。

## 所見

### 軽

#### 軽1: 07-04 と 01-12 の写し、Lean のコメントに、変更前との比較の文が残る（読めば確定）

- 場所: 07-04「01-12 との対応」の「実行の規則」の行（1063行）の「既存closureの遷移先はそのままで」、01-12 の 3265行の「f が既存の closure なら」、07-04 の依存 β の行（261行）の「既存 closure への入口」。Lean では `Step.lean` 332行の適用例の docstring「到達先と引数数の条件も変わらない」、`LambdaApplicationExamples.lean` 94行「以前のno_stepという結論は」と145行「以前の行き詰まりを経由して」。
- 問題点: 設計書は現在の決定だけを書く（AGENTS.md「設計書の規約」）。「そのままで」「変わらない」「以前の」は変更前の規則との比較であり、経緯の文になる。「既存の closure」は値の形の closure を指すつもりだが、「前からある closure の規則」とも読める。
- 修正案: 07-04 は「closure は空捕捉で閉じても同じ値なので、同じ前提で同じ行先へ進む」と現在の性質で書く。01-12 と 07-04 の「既存の closure」は「closure の値」に改める。Lean のコメントは「捕捉変数から読む生 lambda の状態にも Step がある」「型付きの開始から、捕捉に生 lambda を持つ closure を経て次の本体へ進む」のように現在の主張に改める。

#### 軽2: 01-12・07-04 の ComputationInputs の記述が ret と ite の形より広い（読めば確定）

- 場所: 01-12 の 3261行「計算の全16構文について元の直接規則の前提と到達結果の `LeQ`・外効果の `Covers` を保持する」、07-04 の ComputationInputs の行（946行）。
- 問題点: `Comp.Inputs` の ret の枝は `HasTypeVQ … v T`（到達型そのものでの型付け）、ite の枝は各 Boolean の経路条件の下で到達型・外効果での本体の型付けであり、`LeQ` と `Covers` の連言を持たない。他の14構文は記述どおりである。
- 修正案: 「ret は到達型での値の型付け、if は両枝の経路条件の下の型付けを返し、他の14構文は元の直接規則の前提と到達結果の `LeQ`・外効果の `Covers` を返す」と分けて書く。

#### 軽3: results.md の変更の範囲と承認の状態の書き方が、作業木と plan の項と揃わない（読めば確定）

- 場所: `l40/c/results.md` の「宣言・検査・完了条件」の最後の段落（「既存ファイルの変更はBenitoite.leanとSemantics/Step/CapturedFacts/ClosureStateLeaves/DependentBetaの6本だけ」）、完了条件の表の「plan/detail/README/レビュー/群A・Bの記録 | 変更0」、最後の段落の「追加の仕様判断・規則変更の承認を求める未処置点はない」、obligations.md の O118「本番2モジュールの実定義と前提を01-12/07-04へ反映」。
- 問題点: 「6本だけ」は初回の終わりに記録したハッシュとの比較であり、基準 4d27a930 との差には初回で変えた ExternalStateLeaves（非公開の `external_inv` を `inv_externalRef` へ移した）を含む7本がある。verify.py の `CHANGED` と initial-results.md は7本を正しく数えているので、results.md だけが基準からの差と読める書き方になっている。plan.md と detail.md は取りまとめが変えており、「変更0」は担当の変更に限った意味である。E_Lam の変更は取りまとめが了承したが、plan.md の項は設計者の見直しの対象と明記しており、「承認を求める未処置点はない」は担当から取りまとめへの未処置点に限られる。O118 の「2モジュール」は初回の時点の数で、再開1の5モジュールと既存6本の写しと合わない。
- 修正案: 「既存ファイルの変更は、基準からは ExternalStateLeaves を含む7本、初回の終わりからは6本」と基準を明記する。完了条件の表の行を「担当による変更0（plan・detail の注は取りまとめ）」とする。最後の段落に「E_Lam の前提の変更は plan の項のとおり設計者の見直しの対象として残る」を足す。O118 を「新5モジュールと変更した既存の実行規則・葉」に改める。

#### 軽4: check-formal.sh への影響の記述が、決め手になる事実を挙げていない（読めば確定）

- 場所: `l40/c/results.md` の「canonical forms・写し・処理系との接続」の check-formal.sh の段落。
- 問題点: 記述は Rust の実行時の値に生の lambda がないことを根拠にするが、決め手は、check-formal.sh が比較に使う実行ファイル（desugarDiff・builtinCheck・coverageDiff・coverageProgramDiff・surfaceCheck・surfaceCheckAll・intervalDiff）のどれも `Benitoite.Release.Refinement` を import しないことである（各実行ファイルの import は `Benitoite.Exchange.*`・`Benitoite.Interval.Exchange`・`Benitoite.Release.CoverageShow` などで、`Exchange`・`Interval`・`Surface` の配下にも Refinement の参照はない）。今回の変更が check-formal.sh に触れるのは先頭の既定の `lake build` だけで、それは担当の既定ビルドと work で通っている。
- 修正案: 上の事実を一文で足す。実行の要否の判断は次節に記す。

### check-formal.sh の実行の要否（判断）

07-04「01-12 との対応」の【決定】は、check-formal.sh 全体を「Rust と Lean の接続を閉じる区切りと最終の関係状態」で確認するとし、Lean だけを先行した段では未接続の契約と担当・時期を計画へ残すとする。AGENTS.md「テストの運用」も同じ時期を求める。今回の E_Lam の変更は Refinement の実行関係と実行関数だけに触れ、比較の実行ファイルは Refinement を読まないので、Rust と Lean の接続を閉じる区切りにも、比較の対象の関係状態の変更にも当たらない。したがって L40 の段末で check-formal.sh を実行する必要はない。plan.md の検査の割り当ての F-REG（L70末）・F-CONN（R50末）・F-CLOSE（K10）・F-FINAL（V10）がそのまま担う。Refinement の進行・保存を Rust の実行と対応づける読者が R50 以後に加わるときは、E_Lam が生 lambda の頭も受けることを、その接続の入力の範囲に含める（情報1）。

### 情報

#### 情報1: δ・IO・外部へ渡る値には、生 lambda と closure の二つの表し方が残る

E_Lam は関数の位置の生 lambda を適用時に空捕捉で閉じるが、捕捉変数から読んだ生 lambda が δ・IO・外部の引数やセルの内容になる場合は生の形のまま渡る（セルから読む場合は次の view で closure になる。RV-L40.c-obstruction の 1.5）。Rust の実行時には closure の一形しかないので、L60 の実表や R50 以後の接続で、同じ関数値の二つの表し方に δ の応答が依存しないことを、表の条件か比較の入力で扱う必要が生じうる。今回の変更が作った差ではなく、変更前からある表現の差である。

#### 情報2: 76葉の読者は匿名の適用例である

LeafInputs の78件の適用例は、`StateTyE.inputs` を既存の保存の葉の開始と行先へ当てる形で、環境に宣言を残さない。L70 が全分配するときは、名前付きの `StateTyE.inputs`・`lambda_inputs`・`if_inputs`・`match_inputs`・`guard_op_inputs` と各 `*_contract_inputs` を直接使えばよく、適用例は供給の形の確認として足りる。

#### 情報3: obstruction.lean は現在の規則では型検査を通らない

`no_step` は新しい規則では偽であり、results.md は「ファイル全体を現在の規則で再検査したとの主張はしない」と書き、監査要約の `historical_inputs` にハッシュを残している。改造を保管するときに読者が誤解しないよう、ファイルの先頭のコメントに「変更前の規則での反例の記録」と書くかは取りまとめの裁量である。

#### 情報4: L40.15 の外側の時間

results.md の単位の表では、規則と葉の追随が約10分、L40.15 の供給が約16分である（いずれも外側の時刻）。見込み50〜100分より短いが、results.md は能動時間と分けられないとして未経験の群へ外挿しないと書き、群・段の枠を変えていない。plan の更新式の扱いどおりである。

## 確かめた観点の要約

| 観点 | 判定 | 根拠の種類 |
|---|---|---|
| 1. E_Lam の変更・構成子・既存 closure の到達先・重なり・`step` との対応・保存の葉・主な十言明等の不変・個数の前提 | 判断のとおり。重なりなしを補助の Lean で証明。個数の前提は変更前からある | 読めば確定、重なりは実行で確定 |
| 2. 反例の状態の Step・二歩・δ 経路・他の行き詰まり | 反例と二歩は仮定なし。δ は応答等号の仮定で、results.md の記述は正直。関数の型の閉じた値は8形で、生 lambda の3形を含め全形に app の規則がある。捕捉の値・セル・δ の応答・継続の枠の値に、関数として適用される位置で新たに行き詰まる形は読んだ範囲で見つからない | 読めば確定（一般の進行は L70） |
| 3. canonical forms の導出・空篩・atError・場所/セル/継続 | 導出から得ている。F03 の要求を覆う | 既定ビルドで確定、形は読めば確定 |
| 4. B15 の22行と76葉、CaptureWF と Ctx.WF、見込み | 名指しの定理は全件実在。未証明の仮定なし。Ctx.WF の推測なし | 監査の対象名との照合、読めば確定 |
| 5. check-formal.sh | 段末の実行は不要。既存の F-REG/F-CONN/F-CLOSE/F-FINAL が担う（軽4・前節） | 読めば確定 |
| 6. 公理・sorry・import・監査の再生成・写し・義務・記録 | 新公理・sorry・native_decide・#eval なし。新5モジュールは既定 import。監査を再生成して一致。写しは軽1・軽2、記録は軽3。記録は各100 KB 以下、手元の絶対パスと docs/todo へのリンクなし。inputs.json の14ファイル・17記録のハッシュは現在の内容と一致 | 実行で確定、他は読めば確定 |

## 実行した検査

いずれも `formal/` で実行した。既定ビルドの olean は担当の最終ビルドのもので、対象の全ソースより新しいことを更新時刻で確かめた。

| 検査 | 入力 | 終了 | 外側の秒 | 最大常駐量 | 結果 |
|---|---|---:|---:|---:|---|
| 公理監査の再生成 | 改造の `l40/c/axioms.lean` の `-- LOCAL_INPUTS` を空にした `<tmp>/rv-l40-c2/audit-input.lean`、`L40_AUDIT_TARGETS=<tmp>/rv-l40-c2/audit-targets.txt`、`L40_INVENTORY_ONLY=0` で `lake env lean -M 12288` | 0 | 38.36 | 約2.05 GB | 705モジュール・68,912宣言、一覧と `#print axioms` が一対一、公理は propext・Quot.sound・Classical.choice の部分集合だけ。生出力（12,070,243 bytes）SHA-256 `57e3cd08e03ad3ad5805526df22cf46e6d3e65debaf28eefeb908fbcaf0c51d0`、対象名一覧 SHA-256 `a450b8420db1804676c38ba3ed29df3976279acfa3921328d8a92b1f39b89b47`（results.md と一致） |
| E_Lam の重なりの確認 | `<tmp>/rv-l40-c2/rv_check.lean`（1,877 bytes、SHA-256 `79479b0574d40470863bcbfd43e8433903c1fbadccd0df007613b2742e8f6d08`）を `lake env lean -M 12288` | 0 | 0.86 | 約1.77 GB | `rv_close_empty_closure_only`・`rv_elam_unique` とも公理は propext・Classical.choice・Quot.sound だけ。出力 SHA-256 `f67da14295189abaa9b4c632ca6f3847a43b6ef817be25cb5c9b09820ca37019` |

改造の audit.py・verify.py は改造内の json を書き換えるので使っていない。重なりの確認の途中の6回は補助の入力の誤り（同じ証明の heartbeats 超過、`case` の引数名の位置、q.code で述べる checkAt の三規則の扱い）で終了1になり、直して再実行した。

## 付録: 重なりの確認の補助の入力

```lean
import Benitoite
namespace Benitoite.Release.Refinement
noncomputable section
/-- 空捕捉で closure になるのは lam・dependentLam・closure だけ（他規則と重ならない）。 -/
theorem rv_close_empty_closure_only (f : Val) {t : Tel} {q : Closure}
    (h : closeVal Capture.empty f = .closure t q) :
    (∃ ns ps body, f = .lam ns ps body) ∨ (∃ t' body, f = .dependentLam t' body) ∨
      (∃ t' q', f = .closure t' q') := by
  cases f <;> simp [closeVal,Capture.env,Capture.empty,Capture.values] at h ⊢
  all_goals first
    | (left; exact ⟨_,_,_,rfl⟩)
    | (right; left; exact ⟨_,_,rfl⟩)
    | (right; right; exact ⟨_,_,rfl⟩)
    | skip
set_option maxHeartbeats 4000000 in
/-- 関数の位置が lam・dependentLam・closure の app 状態からの Step は E_Lam の行先だけである。 -/
theorem rv_elam_unique {P B σ q k μ ev d f ws t b}
    (h : Step P B σ (.run q k μ) ev d) (hv : q.view = .app f ws)
    (hc : closeVal Capture.empty f = .closure t b) :
    ev = none ∧ d = .run (b.apply ws) (markPush k) μ := by
  have hf := rv_close_empty_closure_only f hc
  cases h
  case E_Lam =>
    rename_i f2 sig2 body2 ws2 hc2 _ hq
    rw [hv] at hq
    obtain ⟨rfl,rfl⟩ := Comp.app.inj hq
    rw [hc] at hc2
    cases hc2
    exact ⟨rfl,rfl⟩
  -- q.code で述べる checkAt の三規則は view が checkAt になるので app と食い違う。
  all_goals try
    (have hv' := hv
     unfold Closure.view at hv'
     rename_i hcode _ _
     first
       | (rw [hcode] at hv'; cases hv')
       | (rename_i hcode' _; rw [hcode'] at hv'; cases hv'))
  all_goals
    rcases hf with ⟨_,_,_,rfl⟩|⟨_,_,rfl⟩|⟨_,_,rfl⟩ <;>
      simp only [hv, reduceCtorEq, Comp.app.injEq, false_and, and_false] at *
#print axioms rv_close_empty_closure_only
#print axioms rv_elam_unique
end
end Benitoite.Release.Refinement
```

## 取りまとめの追記

- L40.15 の停止は、独立の調査（RV-L40.c-obstruction.md）を受けて、E_Lam の前提を広げる判断を plan.md の 2026-11-03 の項に記した（設計者の見直しの対象）。detail.md の F03 の該当の文に注を足した。
- 軽1〜4・情報は担当の再開2で処置した（コメント・docstring・文書だけの変更で、本文の hash の一致を担当が確かめた。再レビューは置かない）。情報1は L60・R50 への申し送りとして results.md に名指した。
- check-formal.sh は、比較の実行ファイルが Refinement を import しないので、L40 の段末では実行しない。接続の検査は plan の F-REG・F-CONN・F-CLOSE・F-FINAL が担う。
- 作業末の work は終了0、169.97秒、最大常駐量 1,840,775,168 バイト（l40/c/results.md）。
