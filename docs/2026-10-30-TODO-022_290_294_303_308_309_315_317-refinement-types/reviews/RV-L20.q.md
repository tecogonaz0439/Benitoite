# RV-L20.q: L20 群 Q・R（L20.135〜.144）の独立レビュー

2026-11-03。対象はブランチ `m014/l20.q` の未コミットの作業木、基準 `a6b13f1c`（san_benito の先端）。依頼文 `L20.q-prompt.md`、担当の報告 `L20.q-report.md`、`l20/q/` の記録（results.md・signatures.md・aux-signatures.md・declarations.tsv・各 json・axioms.lean・signatures-main/aux.lean・audit-*.txt）、`l20/detail.md` の L20.135〜.149 の行と群 Q・R・S の見込みの行、`plan.md` の「計画の変更と取りまとめへの確認点」の 2026-11-03 の二項（とくに RV-L20.o の軽5の判断）、`reviews/RV-L20.o.md` を読んだ。新規の Lean 15本のうち、LegacyEmbedding・LegacyStateInputs・LegacyFullEmbeddingExamples・LegacySequenceEmbedding・LegacyCompCases・LegacyControlEmbedding・LegacyMethodEmbedding・LegacyBuilderEmbedding・LegacyHandlerEmbedding・LegacyArmEmbedding・LegacyClauseTables・LegacyClauseContexts・LegacyClauseEmbedding・LegacyShiftAlgebra・LegacyAdequate は全文を読んだ（証明の細部は meth_case・cons_case・failure_case・guarded_case・handle_case を中心に読んだ）。既存の変更は `git diff` で読んだ。照合のために `LegacyRegularity.lean` の `LegacyJudgment`・`LegacyNodeRegular`・`LegacyRule`、`LegacyInput.lean` の `LegacyLocInput`・`LegacyContextInput`、`LegacyValues.lean` の `LegacyClausesInput.signature_wf`、旧 `Semantics.lean` の `ContTy`・`CellOk`・`StoreOk`、旧 `Lemmas/PresHelpers.lean` の `StateTyE`、新 `Refinement/Typing.lean` の `C_App`・`C_DependentApp`・`C_Match`・`guarded`、新 `Refinement/StateTyping.lean` の `ContTy`・`CellOk`・`StoreOk`・`StateTyE` を読んだ。補助の入力は `<tmp>/rv-l20-q/` に置き、既存のファイルを変えていない。

## 総合判定

**可**（重0・中0・軽3、計3件）。

七つの主入口は、いずれも `K.WF P0 → LegacyTables → LegacyOutputInput → ∀ Φ, 新判断` の形で、`LegacyOutputInput.embed` の一つの `induct_regular` から得る。`LegacyRule` の構成子は46、`embed_value`・`embed_values`・`embed_each`・`embed_comp`・`embed_arms`・`embed_clauses`・`embed_failure` の `cases rule` がその全てを扱う（Lean の `cases` は欠けた枝を許さない。構成子の数は補助の入力で確かめた）。計算17枝・腕3枝・節3枝は、子の `Embedded`（帰納仮説）と親 node の形成・表から新しい構成子で親を組み立てており、新しい結論を入力に足す、意味の包含や値の像の等号で代用する、といった形はない。`LegacyStateInput` は旧 `ContTy` の証拠を添字に持つ帰納的な入力とストアのセルごとの入力からなり、新しい StateTy・HasType・Step を欄に持たず、場所から参照先のセルへ展開しない。新しい公理・`sorry`・独立の信頼条件はなく、公理監査の台本を再実行して、15モジュール311定数と既存の対象を合わせた370件の依存が許可三公理だけであることを確かめた。

所見は軽だけで、主な言明・型付けの規則・公理に触れない。01-12 に残った古い一文（軽1）、使わない入力の欄（軽2）、具体の適用例の範囲と名前（軽3）である。

## 所見

### 軽

#### 軽1: 01-12 の「三包装を使う旧導出の型付けの本体は、既定ビルドに含まれていない」が実物と合わず、07-04 と食い違う（読めば確定）

- 場所: `docs/design/01-spec/01-12-core-calculus.md` 3204行（「これらの三包装を使う旧導出の型付けの本体は、既定ビルドに含まれていない。」）、`docs/design/07-quality/07-04-formal-semantics.md` 192行（今回「三包装は、七判断の全導出の埋め込みから呼ぶ。」に改めた）。
- 問題点: 三包装（`legacy_signatureInstance`・`embedDefWithKinds_signatureInstance`・`embedMethSigWithKinds_signatureInstance`）は、`embed_value` の V_Fun・V_Op の枝と `LegacyCompCases.meth_case` から呼ばれ、どれも既定 import に含まれる。07-04 の対応する段落は今回直したが、01-12 の同じ趣旨の文は残っている。レビューの観点1（章どうしの整合）と観点2（実装との対応）に当たる。
- 修正案: 01-12 3204行の末文を、07-04 192行と同じ「これらの三包装は、七判断の全導出の埋め込みから呼ぶ。」に改める。

#### 軽2: `LegacyCellInput` の `.used` の `LegacyLocInput` は、`LegacyStoreInput` の文脈の成分から導ける使わない欄である（読めば確定、Lean で確認）

- 場所: `LegacyStateInputs.lean` 89行（`.used => ∃ b t e r, Ψ l = some (.cont b t e r) ∧ LegacyLocInput K P0 .closed (.cont b t e r)`）、同 95行（`LegacyStoreInput` の `LegacyNodeContext K P0 [] Ψ [] []`）。
- 問題点: `LegacyStoreInput` は `LegacyNodeContext` を持ち、その成分 `∀ l lt, Ψ l = some lt → LegacyLocInput K P0 .closed lt` が全ての場所の型を既に検査する。補助の入力 `probe1.lean` で、`LegacyStoreInput` と `Ψ l = some (.cont b t e r)` から `h.2.1.2.2.2.1 l _ hl` で同じ `LegacyLocInput` が得られることを確かめた。新しい `CellOk` の `.used` も場所の型の存在しか要求しないので、L20.146 がこの欄を読む見込みはない。依頼の「使わない前提を残さない」に反する小さな重複である。なお、`LegacyContRegular` が枠ごとに `LegacyNodeContext K P0 [] Ψ [] []` を繰り返す点は、`LegacyContInput` をストアの入力なしで単独に使う読者（L20.145）がありうるので、重複として扱わない。
- 修正案: `.used` を旧 `CellOk` と同じ `∃ b t e r, Ψ l = some (.cont b t e r)` にし、01-12・07-04 の「六構文を検査する」の文はそのままでよい。欄を残すなら、results.md に「ストアの文脈と重なるが、セル単独の読者のために残す」と理由を書く。

#### 軽3: 具体の適用は新27規則のうち9規則だけを通り、`match_with_conditions` の「条件」は自明な `truth` だけである（読めば確定）

- 場所: `LegacyFullEmbeddingExamples.lean` 110〜130行（`seven_empty_entries`・`match_with_conditions`）、results.md の L20.143 の行（「七系には具体の適用例、CQ には非空 Φ の照合例がある」）と「七入口の署名と前提」の末段。
- 問題点: 七入口の読者はそろっており、各 case 補題には `LegacyOutputInput.embed` という読者があるので、依頼の読者の条件は満たしている。ただし、具体の宣言表と組み込み表の下で `LegacyNodeRegular` を満たした入力が通る新規の規則は、Vs_nil/cons・Each_nil/cons・C_Return・C_Match・Arms_nil・Arms_plain・Clauses_nil・Failure_one である。C_Let・C_App・C_Meth・C_If・C_Lazy・C_Escape・C_Use・builder 2・handler 2・resume 2・C_Sub・C_Eff・Arms_guarded・Clauses_cons は、具体の入力では一度も通らない。とくに Clauses_cons（`LegacyTables.opSigAt`・`clauseSig` と操作自身の文脈の署名の形成）と C_If（`boolCond` を Φ へ足す特殊化）は、表と文脈の対応が最も込み入った枝である。また `match_with_conditions` は `embedHasTypeCQ` を `Φ = [.truth]` に適用しただけで、腕もガードも Φ へ条件を足さない。一般の定理が任意の Φ を扱うので誤りではないが、名前と results.md の「照合例」は中身より強く読める。一般の証明は閉じているので空虚の心配は小さい。RV-L20.o 軽4 と同じ形の範囲の限定である。
- 修正案: 次のどちらかを取りまとめが選ぶ。(a) 例の表に既にある `unitOp` の通常節で Clauses_cons の入力を作り `embedHasTypeClausesQ` へ渡す例と、C_If の例を既定ビルドに足す。`match_with_conditions` は `match_with_truth` などの中身どおりの名前に改める。(b) 足さない場合は、results.md に具体の適用が通る規則の一覧を書き、残りの枝の入力の充足は L20.145〜.148 の具体例で示すと書き、「非空 Φ の照合例」を「Φ = [truth] への適用例」と改める。

## 確認した事項

### 1. 七つの主入口と46規則の合成（.143）

- 七入口の前提は、明示の `K`・`κ`、`K.WF P0`、`LegacyTables K P0 B0 B`、該当判断の `LegacyOutputInput` だけで、結論は `∀ Φ` の新判断である。型文脈は `legacyTypeCtx C κ`、値文脈は `Γ.map (Option.map embedTy)`、ストアは `embedStoreTy Ψ`、戻り先・局所文脈・効果も旧データの像で、群 O の `LegacyJudgment.Embedded` の七形と一致する。`_empty` の七系は `[]` への特殊化だけである。
- `LegacyRule` の構成子は46（値19・列4・計算17・腕3・通常節2・失敗節1）で、`embed_comp` の17枝は `LegacyRegularity.lean` の計算の構成子と一字ずつ対応した。`induct_regular` と `Embedded` は変更されていない（`LegacyTyping.lean` は差分にない）。
- `K.WF` は V_Fun と C_Meth（`kinds.2` で宣言の型引数の長さ）、`LegacyTables` は V_Prim・C_Match・C_Use・C_Handle・腕・通常節で使う。`inputs`（子の `LegacyOutputInput`）は C_Meth が子の `regular` を取るのに使う。各モジュールを単独に型検査して警告は出なかった。
- 腕の `obs = none` は正しい特殊化である。新 `C_Match` は `obs = some t` のときだけ照合値の項と sort を要求し、`none` では条件が空である。旧の腕は経路条件を持たないので、`pathFacts none = []` で失う情報はない。

### 2. 外した前提と残した前提

- `LegacyContextInput` は、各 node の `LegacyNodeRegular` の第1成分 `LegacyNodeContext` がそのものである（`LegacyNodeContext` は `LegacyContextInput … ⟨κ, C, 0, Γ.length⟩` の別名）。各項の入力は第2成分、旧の七つの型付けは `LegacyOutputInput.old` から得られる。`LegacyInputCtx` を独立に受けないことも、`nr = 0`・`nv = Γ.length` が node の添字で固定されているので失うものはない。結論は弱くなっていない（前提を減らしただけで、結論の判断・添字は契約と同じ）。plan.md の 2026-11-03 の判断（前提の少ない定理を主の入口にし、契約の形の系は置かない）に合い、results.md は外した前提と理由を列挙している。
- 表現可能性（整数8の範囲など）と対象保持は node の項と型の入力、宣言の kind 表は `K.WF`、表の片方向の対応は `LegacyTables` にあり、results.md と 01-12・07-04 がこの分担を明示している。残した三前提に、使わない成分や新しい強い条件は見当たらない。

### 3. 計算17枝（.135〜.140）

- C_App は新の非依存の `C_App` へ直接渡す。新しい型付けは `C_App`（fn 型）と `C_DependentApp`（依存列）の二つを持ち、旧の fn の像は前者に当たるので正しい。C_Meth は、実際の辞書型の像から構成子の kind を取り出し（`hcd`）、`ss ++ [τ]` の kind 引数、元署名の `LegacyTypeInput`、行の入力から `embedMethSigWithKinds_signatureInstance` で依存列の具体化を作り、`legacy_signature_arguments` で正規化した引数列・結果・効果を `C_Meth` に渡し、`C_Sub` の `convert` と被覆の正規化で旧の結果型・効果へ戻す。代入前の Q（`MethodRowsAdmissible … Q`）を保つ。
- C_If は子の値の導出から観測 `t` を取り出し、`boolCond t true/false :: Φ` に子の帰納仮説を特殊化する。C_Match は照合値の子の `LegacyNodeRegular` から型の WF を `legacy_wf` で旧型へ移し、群 O・P の `embedExhaustive` と `legacy_unguarded` で条件付きの網羅性を渡す。C_Let・builderLet は `legacy_local_zero` と `Φ.map Pred.lift` で k=0 の局所文脈を対応させる。
- builder 2 は kind の入力と局所参照、handler 2 は効果の構造上の包含（`legacy_eff_sub`・`legacy_union`・`legacy_handled_sub`）と NoFail、resume 2 は文脈とストアの参照、C_Sub・C_Eff は `embedLe` と `embedCovers` で閉じる。いずれも親の形成と子の帰納仮説だけを使い、新しい結論を入力に足していない。

### 4. 腕と節（.141〜.142）

- 空腕は親 node の型の注釈を使う。ガード付きの腕は、ガードの型を `C_Sub` の `introduce` で `refined boolean truth` に上げ、本体を `Pred.open truth (boolean true) :: liftMany δ.length Φ` に特殊化する。旧のガードは条件を持たないので `truth` が最も弱く正しい選択である。δ の束縛は `embedAltsTy` と `legacy_bindParams` で合わせる。
- 通常節は、`LegacyClausesInput.signature_wf` で元の操作の Top の署名の形成（操作自身の型引数の個数で検査）を、`legacy_opSigAt_signature_wf` で実際に選んだ範囲 `S` の署名へ移し、`LegacyTables.clauseSig` と `opSigAt` で新しい `ClauseSig` を作る。型・値の文脈の移動は親 node の形成（`legacy_opContext`）から供給する。失敗節は `failureContext` で型1・値2を足し、`liftMany 2 Φ` の帰納仮説で閉じる。

### 5. 旧状態の入力（.144）

- `LegacyContInput` の10構成子は旧 `ContTy` の10構成子と一対一で、各構成子の `LegacyContRegular` は旧規則の結論の添字（K_Mark の `some a`、K_Update・K_Guard の `none`、K_Handle の `eb`/`t`、K_Handle_Fail の `union (singleFail E) rest`）と一致した。let・guard のコードは同じ旧規則の文脈・戻り先・効果の `LegacyClosedCompInput`、release の値と handler の節は同じ添字の `LegacyOutputInput` と閉性を持つ。子の入力は有限な旧導出の子へだけ下降する。
- `LegacyCellInput` の `.cont` は保存継続の旧 `ContTy` の証拠とその入力を存在量化し、場所の値から参照先のセルを読まない。循環ストアでも定義は各セルを一度だけ検査する。`LegacyStateInput.old` は同じ `ContTy` の証拠 `hk`、ストアの `StoreOk`、コードの `.old` から旧 `StateTyE` を作る。
- 新 `Refinement/StateTyping.lean` の `ContTy`・`CellOk`・`StoreOk`・`StateTyE` が要求する、場所の型の WF・Sorted・Declared（`LegacyNodeContext` の場所の成分）、各型の注釈（`LegacyContRegular`）、`Adequate`（`legacy_*_adequate`）、閉性（`LegacyClosedCompInput` と `Clause.ClosedList`）、List セルの要素型の注釈（`LegacyBuilderInput`）は、いずれもこの入力から取り出せる見込みである。K_Guard の入力型が新では篩付きの Boolean になる差は L20.145 の「Sub/Guard/handle の契約を合わせる」で扱う。L20.145 以降にこの定義をそのまま使える。
- `legacy_value_adequate` などは前提なしの構造帰納で、任意の σ について成り立つ。`run_input` は空ストアと空の継続で同時に満たせる入力であり、`byte_rejected` は旧型付けが受理する（`old_byte_accepted`）整数8の128を、コードの node の項の入力が拒否することを示す。対照として意味がある。

### 6. 公理・署名・設計書

- 新規15本に `sorry`・`axiom`・`admit`・`unsafe`・`partial`、作業ID、手元の絶対パスはない。15本とも `Benitoite.lean` に明記されている。
- 公理監査: 改造内の `axioms.lean` を `lake env lean -M 12288` で再実行し、終了0、15モジュールの定数の合計311、依存の印字370件、公理は propext・Classical.choice・Quot.sound だけだった。最大常駐量は 1,708,376,064 バイト（`/usr/bin/time -l`、手元の arm64/macOS）。
- declarations.tsv の108宣言は、全件の行番号がソースと一致し、公開96宣言は全件が signatures.md か aux-signatures.md にある。
- 01-12・07-04 の追加段落は同一で、変更の経緯の文はない。前提の書き方（`embed` の三前提、外した前提の理由、if の観測、`obs = none`、ガードの `truth`、通常節の署名の出どころ、失敗節の `liftMany 2`、状態の入力の欄、Adequate の任意の σ）は Lean の実物と一致した。例外は軽1の一文である。用語は群 O までの記述と揃っている。

### 7. 記録

- 改造内の記録は最大が aux-signatures.md の86,194 バイトで、いずれも 100 KB 以下である。手元の絶対パスは `<tmp>` に置き換えられ、`work/`・`reference/` の参照と docs/todo へのリンクはない。
- results.md の規則ごとの表は rule-spans.json（検査の成功まで延ばした区間）から作られ、区間が重なるので加算しないこと、複数規則を一つのシェル呼出しで編集した区間を分離していないこと、待ちと能動時間を分けていないことを明記している。rule-times.json（連続した記録区間、合計1,021.893秒）は Vs_cons の0.04秒のように一規則の所要と読めない値を含むが、results.md がそれを単価にしないと書いているので、記録として妥当である。
- results.md の「LegacyTyping.lean 一つの予定から15モジュールに分けた」「途中に一度、対象を指定した lake build を実行した」は計画からのずれとして記録されている。

## 補助の入力

`<tmp>/rv-l20-q/` に置いた。

| ファイル | 内容 | 結果 |
|---|---|---|
| `probe1.lean`・`probe1.out` | `LegacyRule`・`LegacyContInput`・旧 `ContTy` の構成子の数、`embed`・`embedHasTypeCQ`・具体例の `#print axioms`、`.used` の `LegacyLocInput` をストアの入力から導く例（軽2） | 終了0、46・10・10、3公理だけ |
| `axioms.out`・`axioms.time` | 改造内の `axioms.lean` の再実行 | 終了0、3公理だけ、311定数・依存370件、最大常駐量 1,708,376,064 バイト |
| `single-*.out` | LegacyEmbedding・LegacyStateInputs・LegacyFullEmbeddingExamples・LegacyClauseEmbedding・LegacyControlEmbedding の単独の型検査 | いずれも終了0、診断なし |

## 再レビュー（再開1）

2026-11-03。担当の報告 `L20.q-r1-report.md`、results.md の「再開1」の節、01-12・07-04 の該当行、`LegacyStateInputs.lean` の `LegacyCellInput`、`LegacyFullEmbeddingExamples.lean` の `match_with_truth`・`if_true_embedded`・`unit_operation_clause_embedded` を読んだ。軽3は取りまとめが案(a)を選んだ。

### 判定

**可**（軽1〜3は閉じた。新しい所見はない）。

### 処置の確認

- 軽1（閉じた）: 01-12 3204行の末文は「これらの三包装は、七判断の全導出の埋め込みから呼ぶ。」になり、07-04 192行と同じ呼出し関係を述べる。三包装は V_Fun・V_Op の枝と `meth_case` から呼ばれ、実物どおりである。
- 軽2（閉じた）: `.used` は `∃ b t e r, Ψ l = some (.cont b t e r)` になり、旧 `CellOk` の `.used` と同じ形である。場所の型入力は `LegacyStoreInput` の文脈の成分から得られることを、補助の入力 `r1-probe.lean` で `h.2.1.2.2.2.1 l _ hl` により再び確かめた。`LegacyLocInput` と `.used` を分解する読者は Legacy* の中にほかになく、`LegacyStateInput.old`・`run_input` は既定ビルドで通る。新 `CellOk` の `.used` も場所の型の存在だけを要求するので、L20.146 で欠ける情報はない。
- 軽3（閉じた）: `if_true_embedded` は、Boolean 定数の V_Const、両枝の C_Return を子に持つ C_If の node を `LegacyOutputInput` として構成し、任意の Φ で `embedHasTypeCQ` に渡す。一般の証明の C_If の枝（観測を取り出して `boolCond` を Φ に足す特殊化）を実際に通る。`unit_operation_clause_embedded` は、例の表の `unitOp` の `opSig` の lookup、Top の `ClauseSig`、操作自身の空の型文脈での元署名の `LegacyTypeInput`、継続型 `Cont(Unit → Unit ! ∅)` を加えた本体の文脈の形成と return の子、Clauses_nil の尾を構成し、Clauses_cons の枝を通す。どちらも既存の `kinds`・`oldProgram`・`oldBuiltins`・`builtins` と `tables`・`kinds_wf` の一組を使い、同時に満たせる入力である。表の lookup と文脈の接続を実際に経由するので自明ではない。`match_with_truth` は型を変えずに改名され、旧名の別名はない（旧名は初回の記録 `audit-declarations.txt` にだけ残り、results.md は初回の記録として保持すると書く）。results.md の45行は「Φ=[truth] に適用する例で、腕やガードが条件を足す例ではない」と中身どおりである。具体例が通る規則の一覧（列4・計算3〔C_Return・C_Match・C_If〕・腕2・通常節2・失敗節1の計12、ほかに V_Const）は、各例の node の構成と一致した。
- 公理と sorry: 改造内の `axioms.lean` を `lake env lean -M 12288` で再実行し、終了0、15モジュール315定数・依存374件で、公理は propext・Classical.choice・Quot.sound だけだった。新しい3つの例と `run_input` の `#print axioms` も同じ三公理である。変更した2ファイルに `sorry`・`axiom`・`admit` はない。最大常駐量は 1,708,408,832 バイト（`/usr/bin/time -l`、手元の arm64/macOS）。

### 申し送り（所見としない）

- 07-04 934行の表の「七入口の具体例と非空の Φ の照合」は、Φ=[truth] が空でないので誤りではないが、軽3の趣旨に揃えるなら「Φ=[truth] への適用、C_If・Clauses_cons の具体例」と書ける。次に 07-04 のこの行を変えるときに合わせればよい。

### 補助の入力（追加）

| ファイル | 内容 | 結果 |
|---|---|---|
| `r1-probe.lean`・`r1-probe.out` | `.used` の場所の型入力をストアの入力から導く例、追加と改名した例・`run_input` の `#print axioms` | 終了0、3公理だけ |
| `r1-axioms.out`・`r1-axioms.time` | 再開1の `axioms.lean` の再実行 | 終了0、3公理だけ、315定数・依存374件 |

## 取りまとめの追記

- 軽3は案(a)を選んだ。軽1〜3は担当の再開1で処置し、再レビューで可とした。
- 再レビューの申し送り（07-04 の LegacyStateInputs ほかの行の「非空の Φ の照合」）は、取りまとめが中身どおりの記述（C_If・通常節の具体例、Φ = [.truth] での照合の入口の適用）に直した。
- 作業末の work は終了0、148.73秒（l20/q/results.md「作業末の work」）。
