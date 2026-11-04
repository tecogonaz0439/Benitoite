# RV-L50.b: L50 群 B（L50.06〜.10）の独立レビュー

2026-11-04。対象はブランチ `m014/l50.b` の未コミットの作業木、基準 `6c8ec4247893fa0013ec74ffabe8e33bc55a0678`（HEAD と一致）。本番の変更3モジュール（`ScopeCoverage`・`MembershipTargets`・`EffectTargets`）、01-12 と 07-04 の写し、`l50/b/` の記録を見た。

読んだもの: 担当への依頼と報告、`l50/detail.md` の第3節 F01・F02、第5節の L50.06〜.10 と群 B の行、第8節の移植表 T01〜T14 と残りの移植の族の表、`l50/b/` の results.md・transplants.md・coverage.md・signatures.md・contracts.lean・audit.py・audit-summary.json・declarations.json の冒頭、群 A の `l50/a/signatures.md` と `reviews/RV-L50.a.md`。Lean は変更3モジュールの差分の全文と、`Atoms.lean` の `RangeExpr.Covers`・`RangeIx.Covers`・`Atom.Covers`、`ScopeSyntax.lean` の `RangeIx.inst`・`PathPattern.atBase`、`PathResolution.lean` の `RangeExpr.resolve`・`RangeExpr.Mem`・`SnapshotMem`・`resolveSnapshot`、`ClosedEvaluation.lean` の `Pred.atomValue`・`Pred.interpret`・`memberReady`・`Pred.atomReady`・`Pred.evalWith`、`Scope/Domain.lean` の `Kind`、`Context.lean` の `Eff.bind`、`EffectFacts.lean` の `Eff.substRho`。

git の操作（読み取りを除く）、既存のファイルの変更、`lake build`、cargo の実行はしていない。Lean の検査は `formal/` を作業ディレクトリに `lake env lean -M 12288` で行い、確かめのファイルは `<tmp>/rv-l50-b/` に置いた。

## 結論

**可**（重0・中0・軽2・情報5）。

群 B の完了条件を満たす。完了の判定より弱い言明で閉じた箇所は見つからなかった。主な入口はすべて全入力を量化している。`RangeExpr.Covers.mem`・`SnapshotMem.mono` は群 A の全称の証明のまま `σ.Valid` を仮定しない。新しい `RangeIx.Covers.inst_mem`・`Pred.member_mono`・`Pred.member_inst_mono` は任意の添字・具体化列・σ・η・種類・項を量化し、`Eff.Covers.allows` は任意の Γ・Φ・σ・κ・名前・対象を量化する。`Eff.allows_bind` は任意の `SubstEnv`（型・行・範囲・値の四つの像）について、元の名前付き原子の範囲の具体化と行の像の二経路への同値を示し、生の `rawBind` でなく正規化後の `Eff.bind` を読む。前提が矛盾する入口や、結論が自明になる入口はない。移植の在庫は 13新移植＋T07 継承1＋在庫外側3＝17完了、残件10（効果合成1・ShapeOk 5・Membership 4）であり、残件はいずれも detail.md 第8節で .30・.14/.23・.11/.13 に割り当てられている。

軽2件は受け入れと拒否の対照の形の不足であり、どちらも一般の言明は成り立つことを実行で確かめた。後続の群（起点差は .52）で置き換えればよく、群 B の受け入れを妨げない。

| # | 重さ | 場所 | 問題 | 修正案 | 根拠の種類 |
|---|---|---|---|---|---|
| 軽1 | 軽 | `ScopeCoverage.lean` の docstring「解決した起点が一致しても、異なる起点の静的な被覆は成立しない。」の例 | 前提 `σ.lookup a = σ.lookup b` を `intro _` で捨て、結論は `a ≠ b` だけから従う。前提を除いた同じ結論も成り立つ（検査4）。対照の受理側、すなわち同じ解決先なら意味の所属は保たれることを示していないので、「解決先で同一視しない」の対照が片側だけになっている（AGENTS.md「受け入れと拒否の対照は、両側が意味を持つ形で置く」）。coverage.md の「この読者の前提は…成立し得る」も、前提が証明に使われないことを補っていない | 例を「`hl : σ.lookup a = σ.lookup b` から `∀ k t, (based b q).Mem σ k t → (based a q).Mem σ k t`、かつ `¬ (based a q).Covers (based b q)`」の連言にする。証明は `simpa [RangeExpr.Mem, RangeExpr.resolve, hl]` と `simp [RangeExpr.Covers, hne]` で通る（検査4）。.52 の全 IO の読者で置き換えるなら、そこで同じ形にする | 実行で確定 |
| 軽2 | 軽 | `MembershipTargets.lean` の末尾の例（`a.observe η = some (.targetValue none (.path w))` から based の `evalWith = none`）と、01-12 の「部分評価で snapshot のない based の所属は評価不能のままである」 | 例の前提は path の対象に限る。写しは対象の種類を限らずに書いている。`memberReady` は `resolveSnapshot none (based …) = none` で false になるので、任意の `t : Target`（host・endpoint を含む）で同じ結論が成り立つ（検査5）。言明は正しいが、例が写しより狭い | 例の前提を `a.observe η = some (.targetValue none t)`（任意の `t`）に広げる。証明は同じ `simp` の列で通る | 実行で確定 |
| 情報1 | 情報 | `EffectTargets.lean` の `Atom.covers_fixed_iff`、coverage.md「Atom の9対と効果」 | 新しい言明が扱うのは内側が name-fixed の3対だけで、残る6対は既存の `Atom.Covers` の定義の分岐に任せている。`Eff.Allows` は固定範囲の原子しか読まないので、同じ σ の許容への接続にはこの3対で足りる。coverage.md の表はこの分担を正しく書いている | なし | 読めば確定 |
| 情報2 | 情報 | transplants.md の `allows_substRho` の行 | 在庫の目的を名前付きの定理でなく、`change` と `Eff.allows_bind` による既定ビルドの例で満たしている。detail.md 第8節の「T11/T12から供給できれば残件から控除」「同名の補題を二本作らない」に合う。後続が同じ形を使うときは、同じ `change` を書く | なし | 読めば確定 |
| 情報3 | 情報 | `ScopeCoverage.lean` の based/based の読者 | 同じ起点で外側のパターンが内側を覆わない場合の拒否の例はない。`RangeExpr.Covers` の定義から直ちに従う（検査6）。9対の表の成立・不成立の照合としては、受理側の例と起点差の拒否で足りる | なし | 実行で確定 |
| 情報4 | 情報 | transplants.md の `TargetAgreement.obs_allowed` の行 | 群 A の全称の証明（任意の P・B・Ψ・呼出し・応答・σ）を在庫の完了に数え、群 B の新移植件数へ加えていない。detail.md 第8節の .35 は実表7行の存在と対象一致であり、一般の目的とは別に残っている。17件の内訳（13＋1＋3）と残件10の割り当ては第8節の表と一致する | なし | 読めば確定 |
| 情報5 | 情報 | results.md「差と後続への申し送り」の T11・T12 | T11・T12 は旧 `EffectCover` の名前に対応する新しい入口の形であり、前段の固定署名ではない。`Eff.allows_bind_of_rows_nil` は範囲像を持つ bind で元の rvar の具体化を保ち、範囲像も空のときの同値を `allows_bind_of_rows_ranges_nil` に分けている。F02 の主入口 `Eff.Covers.allows` と群 A の `RangeExpr.Covers.mem`・`SnapshotMem.mono`・`PathPattern.covers_atBase`・`obs_allowed`、C19 の `Eff.allows_norm` の型は変わっていない（検査2） | なし | 実行で確定 |

## 観点ごとの根拠

### 1. 完了の判定

- 起点付加の4場合: 受理3形（exact/exact・tree/exact・tree/tree）と拒否1形（exact/tree）の例は、起点 `w` と幹・残りの列を任意の `Word` で量化する。`PathPattern.Covers.mem_atBase` は任意の被覆・`w`・対象を量化し、`RangeExpr.Covers.mem` の based の枝がこれを読む。具体列への展開はない。
- RangeExpr の9対: `RangeExpr.Covers` は Top の選言と absolute/absolute・based/based・secrets/secrets の三つの成立枝だけを持つ。例は Top の任意 inner、absolute/absolute（旧 `Range.Covers` との同値で旧 `sound`）、absolute/based と absolute/secrets（Top の場合に限る同値）、同じ起点の based、secrets の反射、based/absolute・based/secrets・secrets/absolute・secrets/based の不成立を、いずれも任意の構成子の引数で示す。secrets の所属は `σ.secrets = some ps` の任意の一覧で同値を与え、none と `some []` と based の lookup none の不成立も任意の σ で示す。
- snapshot: `SnapshotMem none` は absolute だけを許す定義なので、none の読者は absolute の任意の `r`・`s`・σ で `current` へ渡せば足りる。some の読者は任意の σ で `mono` から `current` へ渡す。
- RangeIx の4対: `RangeIx.Covers.inst_mem` は全添字・全列を量化する。fixed/fixed と rvar/rvar（lookup some）の受理、fixed/rvar と rvar/fixed の不成立、`rs[i]? = none` の任意の `i`・列で `rvar i` が残り、どの `fixed r` とも等しくないことを示す。「短い具体化列は範囲変数を残して固定範囲を拒否する」の正しい言明である。
- `Pred.member` の3つの sort: `Kind` の構成子は path・host・endpoint の3つだけであり、`Pred.member_mono` は任意の `k` を量化し、例が3構成子へ適用する。`Pred.member_inst_mono` は範囲の具体化へ渡す。二値の `interpret` の命題であり、部分評価の成功を主張しないと写しにも明記している。
- 効果: `Atom.covers_fixed_iff` は任意の原子 `a` を量化する。`Eff.Covers.allows` は被覆の第1成分から同名の固定原子を取り出し、`RangeExpr.Covers.mem` で同じ σ の所属を移す。`Eff.allows_bind` は任意の `SubstEnv` を量化する同値である。Fail の型列だけの効果、`rs[i]? = none` の rvar、行の像だけの効果、`substAt c ts []`、`substRho` の例は、すべてこの同値の適用であり、例から一般を推した箇所はない。

### 2. 移植の照合

transplants.md の13行は、それぞれ `EffectTargets` の同名の定理（T13 は `Eff.Covers.allows`）に対応し、既定ビルドの中に例か後続の補題の読者がある。T07 は C19 の `Eff.allows_norm` を再宣言せず、例が既存の定理を使う。在庫外側の3目的（`allows_substAt_nil`・`allows_substRho`・`obs_allowed`）の供給は情報2・4のとおりである。残る `allows_bind_comp` は .30、ShapeOk の5目的は .14/.23、Membership の4目的は .11/.13 に detail.md 第8節で割り当てられ、割り当てのない残件はない。

### 3. 異なる起点の拒否

軽1のとおり、拒否の結論は正しいが、前提を使わない片側の対照である。同じ解決先での意味の所属の保存と静的な被覆の不成立の連言は、本番の定義で証明できる（検査4）。

### 4. 既存の定義・署名・主な十言明・公理

`git diff 6c8ec424 -- formal` の削除行は、`RangeExpr.Covers.mem` の証明の内部の3行だけであり、新しい `PathPattern.Covers.mem_atBase` の呼出しに置き換えている。定義・構成子・型付けの規則・主な十言明・旧 `Release` の変更はない。前段の固定署名の型を `#check` で確かめ、群 A の signatures.md と一致した（検査2）。`#print axioms` を8件に実行し、すべて `propext`・`Classical.choice`・`Quot.sound` の部分集合だった（検査1）。private と生成の宣言を含む56宣言の監査は担当の記録を引用し、再実行していない。

### 5. 設計書の写し

01-12 の追加3段落と 07-04 の2行は、本番の宣言名・前提・結論と一致する。段名・工程の ID・未実装の作業・変更前との比較の文はない。軽2の一点だけ、写しが例より広い（言明自体は正しい）。

### 6. 記録

`l50/b/` の最大のファイルは results.md の12,140バイトで、全体は67,325バイトである。手元の絶対パス・`private/` の内容・docs/todo へのリンクは、verify.py の検出の正規表現を除いて0件だった。宣言の記録は declarations.json の一回分だけである。

## 実行した検査

| # | 検査 | 結果 |
|---|---|---|
| 1 | `#print axioms` を `Eff.Covers.allows`・`Eff.allows_bind`・`RangeIx.Covers.inst_mem`・`Pred.member_inst_mono`・`PathPattern.Covers.mem_atBase`・`Eff.allows_substAt_nil`・`RangeExpr.Covers.mem`・`SnapshotMem.mono` に実行 | すべて `propext`・`Classical.choice`・`Quot.sound` の部分集合。`sorryAx` なし |
| 2 | `#check` を `RangeExpr.Covers.mem`・`SnapshotMem.mono`・`PathPattern.covers_atBase`・`Eff.allows_norm`・`Builtins.TargetAgreement.obs_allowed` に実行 | 群 A の signatures.md と同じ型 |
| 3 | `git diff 6c8ec424 -- formal` の削除行の抽出 | `RangeExpr.Covers.mem` の証明の内部の3行だけ |
| 4 | 起点差の両側の対照（同じ lookup から意味の所属の保存、かつ静的な被覆の不成立）と、前提 `σ.lookup a = σ.lookup b` を除いた拒否 | どちらも証明が通る。後者で既存の例の前提が使われないことを確認 |
| 5 | 任意の `t : Target` での snapshot なし based の `evalWith = none` | 同じ `simp` の列で通る |
| 6 | 同じ起点でパターンが覆わない場合の based/based の拒否 | 通る |

検査1〜6は一つの入力 `<tmp>/rv-l50-b/check.lean` で行い、終了0、外側の時間は約1秒だった。出力は検査4の補助の例の未使用変数の警告1件だけである。大きな具体値を作る評価はしていない。レビュー全体の外側の時間は約5分（17:44〜17:49）である。

## 取りまとめの追記

- 軽1・軽2は担当の再開1で処置した（l50/b/results.md の再開1）。情報1〜5は処置しない。
- 群 B の作業末の work は終了0、486.01秒、最大常駐量 2,971,205,632 バイト（篩の部分の生成物を消して再ビルド。l50/b/results.md）。
