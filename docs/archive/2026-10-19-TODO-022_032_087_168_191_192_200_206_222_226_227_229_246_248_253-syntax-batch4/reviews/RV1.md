# RV1 段1の前の独立レビュー

対象は、ブランチ `mod010/design` の HEAD `580ad65d3c4e9e1d06e8f24ae0bf9696169a0306`（P1 の反映をコミットしたもの）である。読んだ文書は README.md、decisions.md（全体で引き継ぐ決定、R101〜R131）、design.md の 2〜4・6・12・14.1 節、plan.md の全体（L1〜L7、内部契約、検査の割り当て、区切りと見込み）、implementation-request.md、reviews/preflight.md と preflight-response.md である。照合した formal/ の定義は、`Release/{Syntax,Typing,Semantics,Assumptions,Theorems}.lean`、`Release/Coverage.lean` の整数の箇所、`Surface/{Syntax,Typing,Builders,Desugar,Theorems}.lean`、`Surface/Lemmas/Typing.lean` の署名、`formal/tests/test_batch3_exchange.py` である。処理系は `bytecode/codegen/emit.rs` の handle・lazy の生成、`bytecode/program.rs` の `ProtoOrigin`、`tests/desugar_export.rs` の版、`scripts/check.sh` の分類と Python の検査を読んだ。リポジトリは本書のほかに変えていない。cargo のビルドとテストは実行していない。

開始時の状態として、formal/ の既定の `lake build` は成功した（273 ジョブ、キャッシュ済み）。`#print axioms` で `Release.progress`・`Release.preservation`・`Release.effect_soundness`・`Surface.desugar_typed`・`Surface.surface_effect_soundness` を確かめ、どれも `propext`・`Classical.choice`・`Quot.sound` だけに依存することを確認した。L1 の work 行（`--only formal_build,spec_examples,spec_tally`）と B2 の work 行（`--test '*'` 付き）を `--dry-run` で確かめ、計画どおりの単位が選ばれることを確認した（B2 では spec_examples 等が tests_related に含まれるとして省かれる）。

## 結論

**先に直すべき点あり（直しは文書の追記で済み、L1〜L3 の内容は変わらない）。** 重い指摘は 1 件である。design 3.2 は handle の本体で外側の構築器を同じ Δ で使うことを許すが、処理系は handle の本体を別の Proto の閉包として生成する。一方、plan B2 の内部契約は専用保持先を閉包の捕捉へ加えないと固定している。このままでは、型検査と Lean が受理する「外側の構築器を handle の本体で追記する」プログラムを、B2 で実装できない。どちらの規則に寄せるかは設計者の判断であり、規則を狭める案を採るなら L4 の Lean の規則も変わるので、L1 の前に決めておくことを勧める。

事前点検の 15 指摘は、すべて design・plan・decisions に正しく反映されている。共有番号と σ/ρ の置換（重1）は脱糖の六関数を変えずに済む形になっており、今の formal/ の `BuilderCtx.Aligned` と番号の付け方にそのまま接続できる。中の指摘は 2 件で、hideBuilders を使った置換の補題に要る「値の強化」の補題と隠す位置の列挙、および L3/L4 の補助段階が構成子なしでは作れない点である。軽の指摘は 6 件である。主な定理の前提・結論、公理、Builtins.Assumptions の形を変える必要のある言明は見つからなかった。

## 重

### 重1 handle の本体で外側の構築器を使う規則を、処理系が閉包で実装できない（設計者に確認）

- 箇所: design 3.2「if/match・block・handleの本体・通常引数の評価では同じΔを使う」、study/local-builders.md の同じ文、design 3.4「ラムダの捕捉リストへ専用保持先を加える救済はしない」、plan の内部契約表の B2（根）「クロージャのCaptureSourceへ追加しない」、作業 B2。Lean では `Surface/Typing.lean` の `E_Handle` と `E_HandleFail` が本体を同じ Δ で検査する。
- 問題: 処理系は `handle` の本体を `body_proto` で別の Proto にし、`Closure` 命令で閉包を作ってから `Handle` 命令で呼ぶ（`bytecode/codegen/emit.rs` の `handle`、`ProtoOrigin::UserHandleBody`）。本体の自由変数は閉包の捕捉で渡る。0.0.9 では構築器が通常の Reference のセルだったので、この経路で問題がなかった。新しい案では構築器は呼び出し枠の専用 Slot にだけあり、閉包の捕捉へ加えない。そのため、次のプログラムは型検査と Lean で受理されるのに、B2 の契約のままでは本体の Proto から `b` に届かない。

  ```text
  function f() -> String
    bind b: StringBuilder <- StringBuilder.new()
    bind _ <- handle
      StringBuilder.append(builder: b, text: "x")
      pause()
    with
      case pause() -> resume(())
    end handle
    return StringBuilder.copy(b)
  end function
  ```

  design 14.1 の継続の例は構築器を handle の本体の中で宣言しているので、この欠落を検出しない。Fail の節を持つ handle（`handleFail`）の本体も同じである。
- 根拠: Lean のコアでは `handle m h` の `m` は同じ計算の一部であり、意味論に問題はない。食い違いは処理系の生成の形だけにある。lambda・lazy・節は Δ を空にするので、別の Proto でも問題にならない。
- 修正案: 次のどちらかを設計者が選び、design 3.2・3.4、plan の内部契約表 B2（根）と作業 B2 の完了の条件、design 14.1 の受け入れ例に書く。
  - A（推す）: 規則を保つ。handle の本体の Proto（`UserHandleBody` に限る）にだけ、外側の専用 Slot を渡す専用の欄（例: `Proto.builder_inputs: Vec<u16>` と、Handle 命令が親の枠の専用 Slot を本体の枠へ渡す手順）を加える。通常の CaptureSource には加えず、検証器が `UserHandleBody` 以外での使用を拒否する。保存継続が本体の枠を保持するので Host は根から辿れる。Lean は変えない。B2 の完了の条件に、外側の構築器へ handle の本体で追記し、操作を捕捉して再開・破棄・Fail で抜ける例を加える。
  - B: 規則を狭め、handle（handleFail を含む）の本体でも外側の Δ を空にして E0465 とする。design 3.2、study の写し、decisions の B 系の記述、Lean の `E_Handle`・`E_HandleFail` の本体（L4）を変える。表現力は減るが、本体の中で宣言した構築器は使える。
  - どちらも採らずに B2 で handle の本体を同じ枠へ展開する案は、VM の handle の実装の変更が大きく、今回の範囲を超える見込みなので推さない。

## 中

### 中1 hideBuilders の置換に要る「値の強化」の補題と、隠す位置の列挙

- 箇所: design 3.3 末尾・12.2 の補題の一覧（`hideBuilders_weaken` だけを挙げる）、R118、plan L3 の手順。design 3.3 の「通常値へ入る計算」。
- 問題: 置換の補題は、置換する値を lam・lazy・節の本体の中へ運ぶ。今の案ではそれらの本体を `Ψ.hideBuilders` で検査するので、`Ψ` で型が付いた値を `Ψ.hideBuilders` でも型付けできる必要がある。たとえば `E_Return` で `let x ⇐ return v in return (λy. … x …)` の `x` に `v` を置換するとき、λ の本体の中の `v` は隠した Ψ で型付けしなければならない。design が挙げる弱化（隠した Ψ から元の Ψ）は逆向きであり、これだけでは `subst_typed` が閉じない。
- 根拠: `Release/Typing.lean` の値の規則で Ψ を読むのは `V_LocRef`・`V_LocLazy` と、`V_Lam` の本体（その中の `C_ResumeL` など）だけである。hideBuilders は builder の位置だけを none にするので、ref・lazy・cont の位置は変わらない。値の型付けに builder の位置を読む規則はない。
- 修正案:
  1. 12.2 の一覧に `hideBuilders_strengthen_val : HasTypeVQ Ψ … v A -> HasTypeVQ Ψ.hideBuilders … v A`（`HasTypeVsQ`・`HasTypeEachQ` も）と、補助の `hideBuilders_idem`・`hideBuilders_mono`（`Ψ ⊑ Ψ'` なら隠した方も ⊑）を加える。強化は値の相互帰納だけで示せ、`V_Lam` の場合は冪等性で閉じるので、計算の判断との循環はない。弱化は既存のストアの型の拡張の補題と `hideBuilders_mono`・「隠した Ψ ⊑ Ψ」の組み合わせで示せる。
  2. 「通常値へ入る計算」を列挙に置き換える。隠す位置は、`V_Lam` の本体、`C_Lazy` の本体、`HasTypeClausesQ` と `HasFailureClause` の節の本体、`CellOk` の `.thunk`、`ContTy` の `K_Handle`・`K_Handle_Fail` の節の検査である。ガード、match の分岐の本体、handle の本体、resume の引数、`K_Let`・`K_Guard` の枠、`CellOk` の `.cont` は元の Ψ のままとする。
  3. `Builtins.Assumptions` の `delta_typed`・`io_typed`・`release_exists` は `HasTypeV` を通じて述べているので、`V_Lam` の変更で意味が変わる。形は保たれるが、既存のモデル（`Release/Model.lean` など）が引き続き満たすことを上の強化の補題で確かめ、その意味の変化を R 番号で記録し、RV2 の比較の対象に含める。

### 中2 L3・L4 の補助段階は、構成子を先に足さないと作れない

- 箇所: plan「Leanを先に完了する範囲と区切り」の表（L3 の補助段階「共有番号・σ/ρの置換・hideBuildersの弱化・長さの上限の補助が追加済み、旧規則の定理も通る」、L4 の補助段階）、作業 L3・L4 の手順、R111。
- 問題: σ/ρ の置換は `LocalRef` を含む `Comp` の構成子がなければ定義できず、`StoreTy.hideBuilders` は `LocTy.builder` がなければ意味を持たない。一方、plan は「核の構成子だけを先に増やして既存証明を壊す取り込みを作らない」とする。このままでは補助段階に入れられるものがほとんどなく、L3 の 12〜24 時間が実際には一度の切り替えになり、続きへ渡す区切りが作れない見込みが高い。
- 根拠: `Release/Syntax.lean` の `Comp`・`Val` は相互帰納型であり、`Release/Typing.lean` の `LocTy`・`Release/Semantics.lean` の `Cell` も網羅的な照合で多くの関数と補題から読まれる。
- 修正案: 区切りを次のように具体化する。どれも既定のビルドと既存の定理を保てる。
  - L3 の第一段階: `Comp.builderLet`・`Comp.builderOp`・`Cell.builder`・`LocTy.builder` と `LocalRef`・`BuilderContents` を足し、rename・置換・型代入・`VarsIn`・`Closed`・`WellFormed`・`step` の構文上の場合だけを加える。型付けの規則と `Step` の規則は足さず、`CellOk (.builder _)` は偽とする。新しい項は型が付かないので、型付きの状態に現れず、主定理はそのまま通る。`hideBuilders` は、型付きの状態では builder の位置が空なので恒等と同じになり、`V_Lam` などをこの段階で隠した Ψ へ切り替えても既存の証明への影響を局所に抑えられる。強化・弱化・上限の補題もここで閉じる。
  - L3 の第二段階: 型付けの規則、`Step`、`BuilderCellOk`、進行・保存・無事象の場合を一緒に加える。
  - L4 の第一段階: 表層の `refs` と State を残したまま、脱糖の先を専用コアへ替える。コアの専用操作は State を持たないが、`C_Eff` で表層の効果（State を含む）まで広げられるので、`desugar_typed` を保てる。
  - L4 の第二段階: 表層の `E_BuilderOp`・`B_BuilderBind` から State と `refs` を除き、`BuilderRefs`・`refs.Ok` と交換の読者を直す。
  - この形で切れない場合だけ、R111 のとおり設計者に相談する。

## 軽

### 軽1 builderLet の一歩の σ 0 と、閉じていることの述語

- 箇所: design 12.2「builderLetの一歩ではρ 0 = loc ℓ、ρ (i+1) = bound i、σ (i+1) = var i」「σ 0に通常値の型の義務はなく」。
- 問題: `StateTy` は項が閉じていること（`Comp.VarsIn 0`・`Cont.Closed`・`Store.Closed`）を構文で要求する。σ 0 を `.var 0` などにすると、置換後の項の閉じていることを型付けから導く補題が別に要る。また、`VarsIn` 系が `LocalRef.bound` を数えないと、自由な bound が残った項も閉じていると判定される。
- 修正案: σ 0 は閉じた値（例: `.const .unit`）と明記する。`VarsIn`・`VarsInNoLamNames`・`ClosedNoEffVars`・`Frame.Closed`・`Cell.Closed` に `LocalRef.bound` の範囲を含め、`StateTy` の項に自由な bound がないことを構文でも保つと L3 の手順に書く。

### 軽2 `drop_local_silent` の `ev = none` は規則から自明である

- 箇所: design 12.3 の `drop_local_silent`、R119。
- 問題: `E_DropRel` はつねに事象なしの一歩であり（`Release/Semantics.lean`）、解放の事象は後で `release` の枠を処理するときに起こる。`releases k' = []` の仮定がなくても `ev = none` は成り立つので、今の言明は構築器について何も述べていない。
- 修正案: 結論を「`s' = .run (.ret v) k (σ.set κ .used)`」とし、後続に解放の枠が積まれないことを内容にする。構築器だけを持つ枠の `releases` が空であること（`releases` は `release` と `drop` の枠だけを拾う）を、別の補題として置く。

### 軽3 `test_batch3_exchange.py` の構築器の検査は、受理から拒否へ変わる

- 箇所: design 12.8・R122・plan L7 の「既存`test_*_exchange.py`で旧版の受理/拒否が保たれる」。
- 問題: `formal/tests/test_batch3_exchange.py` と `batch3-exchange/corpus.json`（版 12）は、構築器の欄（`builderBind`・`builderOp`・`refs` など）を受理し、その意味の拒否を細かく検査する。L4/L7 の後は版 12 の構築器を「版13で再生成」の理由で拒否するので、これらの検査は「保たれる」のではなく、期待を変えるか版 13 の入力へ移す必要がある。
- 修正案: L7 の手順に、batch3 の構築器の検査を版 13 の新しい入力（test_batch4）へ移し、batch3 には版 12 の構築器の拒否の理由を確かめる検査を残すと書く。構築器を含まない batch3 の検査は変えない。

### 軽4 block の交換の欄を誰が足すかが決まっていない

- 箇所: design 12.8「専用builderLet/builderOp/localRefとblockは版13だけで許す」、plan L5 の触るファイル（Exchange がない）、L7。
- 問題: L5 は `Expr.block` を表層へ足すが、触るファイルに `Exchange/{Syntax,Convert}.lean` を含まない。L7 の手順も構築器の欄だけを挙げる。
- 修正案: L5 の触るファイルに Exchange の読者を加え、版 13 だけで block を受け、旧版の block を拒否すると書く。L7 の独立入力にも block を含める。

### 軽5 効果が空であることを要求する位置で、構築器の操作が観測できる変更になる

- 箇所: design 3.2「ガードの局所操作は効果が空なら受理し」、作業 T3・B2 の完了の条件。
- 問題: 0.0.9 では効果が空の式は可変の状態を変えられなかったので、ガードと `or die` の説明の評価回数は観測できなかった。新しい規則では、ガードや説明の中の `append` が効果なしで受理され、後の `copy` で評価の順序と回数が観測できる。Lean の `E_MatchGuard`・`E_GuardF` の順序と一致させる義務は T3 にあるが、T3 の時点では構築器の新しい規則がまだないので、この観点の検査を作れない。
- 修正案: B2 の完了の条件（または B3）に、ガードで構築器へ追記する例を T2 の共有した判定と T3 の行ごとの照合の両方の経路で実行し、ガードが一つの case で一度だけ評価され、失敗したガードの追記が残ることを確かめる例を加える。`or die` の説明に `copy(b)` を書く例も受理の例として加える。

### 軽6 P1 がコミットされ、基準の記述が古い

- 箇所: README「P1の基準は現在のHEAD `f4a8bec2…`」、plan の基準表「現在の`B_WORK`」、依頼文の「現在の基準」。
- 問題: P1 の変更は `580ad65d` としてコミット済みである。L1 の基準は取り込みの後に差し替える決まりなので検査の選択には影響しないが、「現在の」の記述が実際の HEAD と合わない。
- 修正案: RV1 の修正を取り込むときに、P1 の記録の基準（`f4a8bec2`）と現在の HEAD を分けて書く。L1 の基準の差し替えは従来どおり取りまとめが行う。

## 事前点検の指摘ごとの確認

| 指摘 | 反映先の確認 | 直し方の判定 |
|---|---|---|
| 重1 番号の共有と置換 | design 3.3・12.2・12.4、plan の内部契約表と L3/L4、R117、依頼文に入っている。`fillBuilders`・射影の語は残っていない | 正しい。表層の `BuilderCtx.Aligned` と `.local i ↦ .ret (.var i)` の番号付けにそのまま接続できる。σ 0 の扱いと閉じていることの述語は軽1 |
| 中1 論理上限とエラーの一歩 | design 12.2、plan L3・内部契約表、R121、依頼文 | 正しい。上限は max64 より十分小さく、length の有界性を示せる。R0902 は 01-08 の実行時エラーの停止であり、Lean の error 状態（解放の枠を処理する）と対応する |
| 中2 hideBuilders と弱化 | design 3.3・12.2、plan L3・内部契約表、R118 | 方向は正しいが、置換に要る値の強化の補題と隠す位置の列挙が足りない（中1）。Assumptions の意味の変化も記録が要る |
| 中3 Exits の block | design 12.6、plan L5、R123 | 正しい。`B_Seq` の `¬ e.Exits` とも整合し、全経路が抜ける block の後の文を Lean でも拒否する |
| 中4 全統合の特殊構成 | plan の work 行（B2/B3/G2 に heap_local・stress_local がない）、補完行、R124。dry-run で選択を確認した | 正しい |
| 軽1 OrdinaryStoreEq と drop | design 12.2/12.3、R119 | 定義の絞り方は正しい。`drop_local_silent` の結論は自明なので言い直しを勧める（軽2） |
| 軽2 証明付きの整数の構文 | design 6.2・12.5、plan L1、R120 | 正しい。型付けの前提を増やさない。Coverage は区間を Int で扱うので上端+1 の問題は生じない |
| 軽3 L1 の全読者 | plan L1 | 正しい |
| 軽4 版 13/5 | design 12.8、plan L4/L7、R122 | 版の分岐は正しい。batch3 の検査の期待が変わる点は軽3、block の交換は軽4 |
| 軽5 G6 の現役の参照 | plan G6、R126。check.sh・source-migrate の README・try-actions の除外一覧・07-03・AGENTS の参照を確かめた | 正しい |
| 軽6 B2 の区切り | plan B2、R127 | 正しい |
| 軽7 T1 の limits.rs | plan T1、R128 | 正しい |
| 軽8 標準構築器の説明 | design 13.3、plan B2、R129 | 正しい |
| 軽9 B_WORK | plan の基準表、依頼文、README、R130 | 正しい。P1 のコミット後の記述は軽6 |
| 軽10 preflight と RV1 | plan のレビュー表、README、依頼文、R131 | 正しい |

## Lean の言明ごとの判定

「正しい」は、今の定義と主な定理の前提・結論を変えずに成り立つ見込みであることを表し、証明済みという意味ではない。

| 言明（design の節） | 判定 | 理由 |
|---|---|---|
| `Release.progress`（12.1） | 正しい | 型付きの状態の項は Δ が空なので bound を含まず、loc は Ψ の builder から `BuilderCellOk` の反転で場合を尽くせる |
| `Release.preservation`（12.1） | 正しい（中1の補題が要る） | 置換を lam などの本体へ運ぶ場合に値の強化が要る。保存継続は元の Ψ の `ContTy` で型付けできる |
| `Release.effect_soundness`・noLamNames 版（12.1） | 正しい | 専用操作と上限超過の一歩は事象を伴わない。`effect_soundness` は error 状態を排除しない |
| `Surface.desugar_typed`（性質1） | 正しい | 脱糖の補題は `StoreTy.empty` で述べているので、隠した Ψ は空と一致する。L4 の第一段階では `C_Eff` で表層の効果まで広げられる |
| `Surface.surface_effect_soundness` | 正しい | 言明は変わらない |
| `CheckSound` の公開 11 件と program | 正しい | Exits を含む全相互帰納に block の場合を足せばよい |
| Coverage の補題U と系（12.1・12.5） | 正しい | 整数の値は部分型で有界になり、区間は Int のまま扱える |
| `HasTypeCL`・`HasTypeC := HasTypeCL []`（12.2） | 正しい | 値の判断に Δ を足さない形と整合する |
| `LocalScoped`・`NoFreeBuilders`（12.2） | 正しい | 共有番号なので範囲の述語に LocalRef の場合を足す形になる。閉じていることの述語は軽1 |
| `StoreTy.hideBuilders`（12.2） | 正しい | 位置を詰めず none にするので番号を保つ。冪等性と単調性の補題を足す（中1） |
| `BuilderCellOk`（12.2） | 正しい | 種類・要素の型・Bytes の範囲・上限を含む |
| `OrdinaryStoreEq`（12.2） | 正しい | `.val` のセルだけを比べる |
| `rename_typed`・`subst_typed`（12.2） | 仮定が要る | 値の強化の補題（中1）がないと lam・lazy・節の本体の場合が閉じない。σ 0 は閉じた値にする（軽1） |
| `hideBuilders_weaken`（12.2） | 正しい | 既存のストアの型の拡張の補題と単調性から従う |
| `builder_value_no_free_local`（12.2） | 正しい | `V_Lam` の本体は Δ が空で bound が型付かず、隠した Ψ では loc も型付かない |
| `builder_step_no_event`・`builder_step_frame`・`builder_copy_contents`（12.2） | 正しい | new は `.val` 以外の新しいセルを置くだけで、上限超過の一歩も事象を伴わない |
| `builder_store_extend`・`cont_local_store_weaken`（12.3） | 正しい | 既存の拡張と同じ形である |
| `capture_local_valid`・`resume_local_valid`（12.3） | 正しい | `E_Op` が保存する `k1 ++ [handleF h]` の枠は元の Ψ で型付けし、節は隠した Ψ で型付けする |
| `drop_local_silent`（12.3） | 正しいが自明 | `E_DropRel` はつねに事象なしである。結論を後続の継続の形に言い直す（軽2） |
| `local_steps_invariant`（12.3） | 正しい | 値の位置の loc は型付かず、隠す位置の列挙（中1）から通常値の非出現を導ける |
| `snapshot_structure_stable`（12.3） | 正しい | Lean の値は不変である |
| `Integer64Value.toInt_bounds`・`integer_*`（12.5） | 正しい | 部分型の定義と Character の区間の扱いの流用で示せる |
| `E_Block`・`block_desugar_typed`（12.6） | 正しい | 既存の `HasBlockQ` と `desugarBlock` の系である |
| `hole_args_plan_typed/scoped`（12.6） | 正しい | 固定式はラムダの本体で評価し、表層の規則も Δ を空にしているので、構築器の捕捉は生じない |
| `checkLength_*`・`checkIndex_*`・`nonEmpty_*`（12.7） | 正しい | 独立した小モデルの性質である |
| `Builtins.Assumptions` の形の維持（12.2） | 正しい（意味の記録が要る） | 形は変わらないが、`HasTypeV` の変更で意味が変わるので、モデルが満たすことの確認と R 番号の記録を求める（中1） |

## 捕捉と持ち出しの経路の確認

lam・lazy・ハンドラの節・部分適用（固定式と呼び出し先はラムダの本体で評価され、表層の規則も Δ を空にする）は、Lean でも処理系でも捕捉の境界になっている。パイプは `callComp` で番号をずらすだけで閉包を作らない。ガード・match の分岐・block の値・resume の引数・`or die` の説明は同じ計算の中で評価され、持ち出しの経路にならない（効果の観測は軽5）。保存継続は構築器を参照するが、継続は通常値にならず（`V_Var` と `hideConts` が禁じる）、一回の再開の規則で同じセルへ戻る。構築器そのものを値にする経路は、Γ の位置が none なので `E_Local` が型付けない。doctest と derive の生成コードは通常の関数として同じ規則を通る。処理系の生成の形だけが handle の本体で Lean と食い違う（重1）。

## 計画の引き継ぎと検査の指定

L1・L2 の区切りは、既定のビルドを保てる。L3・L4 は中2の段階分けを入れれば、どの区切りでも sorry なしの既定ビルドで続きへ渡せる見込みである。B2 の追加段階と b2c2 の区切りは、重1の選択を内部契約へ書き足せば成り立つ。依存の順序は、Rust の交換の出力が版 12 のまま L4〜B2 の間に残るが、`tests/desugar_export.rs` は Lean を呼ばず、全比較は V1 の後の一度だけなので、途中の work が失敗することはない。L 作業の work 行は formal_build・spec_examples・spec_tally を選び、`formal/tests/*.py` は check.sh の python_syntax の対象外なので、L7 の補完行で直接実行する計画で足りる。
