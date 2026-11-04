# RV-L50-plan: L50 の詳細計画の下書きの独立レビュー

2026-11-04。対象は `l50/detail.md`（91,825 バイト、SHA-256 `cc11f94f…3f82bdc`）・`l50/results.md`（13,310 バイト、SHA-256 `0406470a…00a85ca`）で、どちらも未追跡、基準は 09b0ea34 である。`formal/`・`plan.md`・対象の下書きは変更していない。Lean の補助入力は一時領域 `<tmp>` に置き、再現に要る全文を本書の末尾へ写した。パスは改造のディレクトリからの相対で書く。L40 の段末は 2026-11-04 に設計者が受け入れたので、下書きの「L40 段末の受け入れ待ち」は解消したものとして読んだ。

## 総合判定

**条件付き可**（中3・軽7、計10件）。

骨格（12群の依存順、相互の帰納と型付けの定義を変えない方針、L50 と L60 の三モデルの条件の分け方、主定理の閉鎖を L70 に残すこと）は正しい。数えられる数は、Lean の定義を読んだ範囲ですべて一致した。義務は plan の担当26行・L20 の残る段9行・L30 の4行・L40 の13行・和集合29行・差の3行（O022/O034/O065）・共通4行を機械的に再現した。申し送りの出どころも、一件を除き（軽3）拾えた。

条件は三つである。第一に、`Eff.Allows` と `Eff.allows_norm` は既に `EffectFacts` にあり、下書きは同じ完全名の定義を新しいモジュールに置く案になっている（中1）。第二に、F03 の「ほかの23規則の排除」は L40 の `HasTypeVQ.canonical_held` が既に与えており、控除から落ちている（中2）。第三に、J50-1 は U02 の確定の時期を plan の「L70 前」から L50 の .20 の前へ早める判断を含むのに、それを判断として書いていない。二案の利用者への違いも書かれていない（中3）。中1・中2 は群 A の L50.01・L50.05 の前に、中3 は取りまとめが plan へ写す前に直す。

## 所見の分類

| 種類 | 所見 |
|---|---|
| 読めば確定する誤り・欠け | 中1、中2、軽2、軽3、軽4、軽5、軽6、軽7 |
| Lean で確かめた事実に基づく指摘 | 中1（既存の `Eff.Allows` の型と本体）、中2（`canonical_held` の型）、情報1（F01 の二式は Valid なしで証明できる） |
| 実行しないと分からない推測 | 軽2 の「L50 の三モデルで F05 を使えない」は、群 H〜J で Core を作らないという下書きの範囲から読んだ |
| 判断の問題 | 中3、軽1 |

## 中

### 中1: `Eff.Allows` と `Eff.allows_norm` は既に本番にある。F02 の新しい定義は同じ完全名になる

- 箇所: 第3節 F02 の「`EffectTargets`（新）に次を定義する」、L50.09 の触るファイル、第8節の T07（`Eff.allows_norm`）、第1節の控除表（C01〜C18 に `EffectFacts` がない）。
- 問題: `R/EffectFacts.lean` は名前空間 `Benitoite.Release.Refinement` で `def Eff.Allows (σ : PathEnv) (κ …) (e : Eff) (l : EffName) (t : Target) : Prop := ∃ k r, κ l = some k ∧ e.mem (.name l (.fixed r)) ∧ r.Mem σ k t` を定義し、`Eff.allows_norm` も証明している。下書きの F02 は同じ名前空間・同じ名前で、本体を `e.test (…) = true` と書いた定義を新しいモジュールに置く。`EffectFacts` は `TypeSubstAux` から既定の import に入るので、そのままでは同じ名前の二度目の宣言で失敗する。別の名前にすれば、意味の同じ定義が二つになる。T07 は既にある補題を新しい移植として数えている。
- 根拠: 読めば確定、Lean で確かめた（補助入力の `#print Eff.Allows`）。
- 修正案: 控除表に「C19: EffectFacts の `Eff.Allows`・`Eff.allows_norm`」を加える。F02 は既存の定義を使う形に改め、L50.09 は読者の補題だけを `EffectTargets`（新）に置く。第8節の T07 は「既済みの証拠を継承」に分け、新しい移植は13件とする。見込みの .09 と .10 を合わせて直す。

### 中2: F03 の「ほかの23規則の排除」は既存の `HasTypeVQ.canonical_held` が与えている。控除から落ちている

- 箇所: 第2節「値の型付け」の行と「HasTypeVQの規則（全29）」の表、第3節 F03、L50.02・L50.11 の手順と見込み、第1節の控除表。同じく `BuiltinEffects` の事象の被覆（O060 の単位 .09/.17/.23/.54）。
- 問題: L40 の `R/CanonicalValues.lean` の `HasTypeVQ.canonical_held` は、`HasTypeVQ P B Ψ Q C [] Φ v T` と `T.Holds o kind ix` から、`v` が `const (.opaque …)`・`checked`・`checkedRequest`・`checkedAt` の四形のどれかであることを結論する。`valueForm_typed` と型の符号で示しており、V_Sub の逆向きの芯の逆転も含めて、包む規則3本を一度に扱っている。L40 の `g/cases.md` もこの補題を「範囲添字」と「checked / checkedRequest / checkedAt」の行の証拠に挙げる。したがって F03 に残るのは次の二つだけである。
  - `const (.opaque o' _)` の枝を、`ConstOK` の `B.valKind o' = none` と `hk : B.valKind o = some k` の矛盾で除くこと。名前の一致は `Ty.Holds.unique_name` で得る。
  - 三つの保持値で、既存の `inv_checked*` と F01 から所属を得ること。

  下書きは .11 に「導出の帰納を一度だけ行い、芯/valKind/ConstOK で他23規則を排除」（45〜90分）と書き、.02 では逆向きの LeQ の逆転を新しい課題として扱う。これは既にある証明の作り直しになる。同様に、`R/BuiltinEffects.lean` の `ShapeOk.operation`・`CoreAssumptions.io_event_covered`・`io_transition_covered`・`pathBases_event_covered` が、IO と PathBases の事象を宣言の効果で覆うことを既に示している。O060 の受け持つ単位はこれに触れていない。
- 根拠: 読めば確定、Lean で確かめた（補助入力の `#check @HasTypeVQ.canonical_held`）。
- 修正案: 控除表に「C20: CanonicalValues の `canonical_held`」と「C21: BuiltinEffects の事象の被覆」を加える。F03 の表は「canonical_held で四形に絞り、opaque 定数を ConstOK で除き、三つの逆転と F01 で所属を得る」に書き換える。.11 の見込みを下げる。残る作業が小さいので、F03 の証明は .02 で行い、型の検査だけで群 A を閉じないようにする（第5節「F03/F04 は型検査だけ」の未確定を一つ減らす）。O060 の行は既存の事象の被覆を引用し、L50 で足すのは同じ σ の許容（F02/F05）だけと書く。

### 中3: J50-1 は U02 の確定を L70 前から L50 の .20 前へ早める。その時期の変更も、二案の利用者への違いも書かれていない

- 箇所: 第9節「設計者の判断が要る項目」の J50-1、第3節 F10、L50.04・L50.20・L50.53、群 A・D の完了条件（「U02 に依存する枝は回答前に起動しない」「U02 待ちを完了へ繰り上げない」）。
- 問題: plan は U02（PathBases・At・エラーの record の公開名と完全署名）を「後でよいもの」とし、期限を「Lean が型付き表層の意味を固定する L70 より前」と定める（decisions の U02、plan の「後でよいもの（U02〜U07）」）。下書きは .20/.53 を U02 の回答の後に置くので、設計者の回答の期限が L50 の群 D まで早まる。回答が遅れると群 D・K が止まるが、下書きはこれを判断の時期の変更として挙げていない。
  二案の書き方にも欠けがある。現在の観測は `AtContracts`・`MatchFacts` が読む `"Scope.ScopeError.At"` の構成子で、七つの String 欄に `AtError.textFields`、すなわち Lean の `reprStr` を入れる。案 A の「既存七String観測への明示変換」は、その七つの String に何を入れるかを定めていない。案 B の「公開 record を正とし」も、欄の名前と型を示していない。利用者への違い（A なら利用者は文字列の欄を比べる、B なら型の付いた欄を照合する）も、J50-1 の「エラーをパターンで照合し欄を参照する書き方に影響する」という一文では読み取れない。
  もう一つの選択肢が挙がっていない。L50 は D61 の保存内容（元の入力・解決後の入力・両起点・失敗種別・原子列）を内部の `AtError` に持たせるところまでを行い、公開形への写しは U02 の回答とともに L70 で行う案である。この案なら群 D・K は回答を待たない。
- 根拠: 読めば確定（plan・decisions・`ScopeSyntax.textFields`・`AtContracts`）、判断。
- 修正案: J50-1 を次の二つの問いに分ける。
  - 時期の問い: U02 の公開形を L50 で確定するか、L70 前の元の期限のままにして L50 は内部の保存だけを行うか。
  - 形の問い: 案 A・案 B の欄の名前と型、利用者が書く照合の例を一つずつ示す。
  
  既定は後者（内部の保存を L50、公開の写しを L70）とし、.20/.53 の完了条件と群 D・K の待ちをそれに合わせることを推す。理由は、D61 の保存内容は決定済みで内部の形だけで閉じられること、U02 の他の項目（構文の少数測定を含む）と同時に決められることである。

## 軽

### 軽1: 群の完了条件が全場合を量化していない箇所がある

- 箇所: 第5節「群の一覧と完了条件」の A・D・K。
- 問題: L40 では、群の照合で「閉じた」と記録した範囲が実際より狭く、群 G の再開が要った。下書きの単位は「全BuiltinArgs」「任意Ψ」と量化しているが、群の完了条件には弱い書き方が残る。A は「F03/F04/F06/F09/F10の形…が確定」で、.05 の「F01〜10の型」と範囲が合わない。D の「既知契約の準備と動的Error、同じσの発行・At三枝…が揃う」は、23の局所の葉と checkAt の8葉の全組から E_AtOk・E_AtError・E_AtPrepareError のどれかへ進むことを書いていない。K の「…を照合」は、照合の結果に各行の実定理の名前を要求していない。
- 根拠: 判断（L40 の教訓に照らした）。
- 修正案: A は「F01〜F10 の完全署名を型検査し、F03・F04 は証明する（中2）」に、D は「23局所葉×8葉の各組から三遷移のどれかの実定理がある」に、K は「各行に実定理又は実 δ の完全名がある」に改める。

### 軽2: F05 が CoreAssumptions を前提に取るので、L50 の三モデルでは使えない

- 箇所: 第3節 F05 の `hc : B.CoreAssumptions P`、L50.35・L50.45（F05 を三モデルの対象の欄へ使う）。
- 問題: F05 が Core から使うのは `io_op`（ShapeOk）だけと読める。ところが L50 の三モデルは Core の29欄のうち25欄しか作らず、external の3欄と release_exists は L60 が作る。このため .35・.45 で F05 を実モデルへ適用できるのは L60 の後になる。
- 根拠: 読めば確定（`ConstraintAssumptions` の欄）。適用できないことは、群 H〜J の範囲の読みに基づく推測。
- 修正案: .05 で `hc` を `hsh : B.ShapeOk b sg` に置き換える。これは下書き自身の「使わない前提を除く」方針の適用である。

### 軽3: 申し送りの出どころに L40 の `g/cases.md` の9行がない

- 箇所: 第7節の出どころの一覧と H 表。
- 問題: `l40/g/cases.md` は、範囲添字・externalRef・externalHandle・pathBases/scopePattern・保持値三形・atError・externalCall/issuePathBases/checkAt・対象3sort・応答の9行に「全有効 σ は L50」と書く。下書きは保持値・At・対象・応答を受けているが、出どころにこの表を挙げていない。externalRef・externalHandle・scopePattern・atError の AdequateResult を全 σ で受ける単位も明示していない。
- 根拠: 読めば確定。
- 修正案: H 表に cases.md の行を加えるか、既存の H の出どころへ足す。F07 の完了条件に、上の4形の結果も全有効 σ の `AdequateResult` に含まれることを書く。

### 軽4: H27 の「2欄と25条件」が第4節と合わない

- 箇所: 第7節 H27「L50はsat_unconstrained/admits_satの2欄と対象の25条件だけを実証する」。
- 問題: sat_unconstrained・admits_sat は第4節の25条件（表の条件12欄）の内数であり、別枠ではない。
- 根拠: 読めば確定。
- 修正案: 「L50 は第4節の25条件（sat_unconstrained・admits_sat を含む）を実証する」に改める。

### 軽5: L40 の段末の受け入れの記述が古い

- 箇所: 冒頭の段落、第1節の L40 の行（「設計者の段末の受け入れは待機中」）、第9節の判断の表の三行目、results.md の「判断」の行。
- 問題: 設計者は 2026-11-04 に L40 の段末を受け入れた（plan の同日の変更記録、README「設計者の決定」）。
- 根拠: 読めば確定。
- 修正案: 受け入れ済みに改め、判断の表から三行目を除く。

### 軽6: 「24ファイル104出現」は数え方が記録されていない

- 箇所: 第9節「定義を変える必要と波及」の AtError/AtPrepare の行、results.md「読み取りと差の扱い」。
- 問題: 検索した字句が書かれていないので再現できない。本レビューで `reprStr|textFields|AtError|atError` を Refinement の直下で数えると、94ファイル・301出現だった。下書きも上限ではないと書いているので影響は小さいが、.04 の波及の棚卸しの基準になる数である。
- 根拠: 読めば確定。
- 修正案: 検索の式を併記するか、数を除いて .04 の棚卸しの結果に任せる。

### 軽7: 「private/生成宣言」が `private/` のディレクトリと読める

- 箇所: L50.57、第11節の A-L の行。
- 問題: 意図は Lean の `private` 宣言と自動生成の宣言だが、改造の文書では `private/` が非公開の運用のディレクトリを指す。
- 根拠: 読めば確定。
- 修正案: 「Lean の private 宣言と自動生成の宣言」と書く。

## 情報

### 情報1: F01 の二式は Valid なしで証明できる

F01 の `RangeExpr.Covers.mem` と `SnapshotMem.mono` を、下書きの署名どおり `σ.Valid` を仮定せずに補助入力で証明した。公理は前者が propext・Quot.sound、後者がそれに Classical.choice を加えたものである。下書きの「強い形を採る案」は成り立つ。.06〜.08 の見込みの下端は短めに読んでよい。ただし、見込みの改定は群 B の通常の結果で行う。

## 確かめて問題がなかった点

- 構成子と葉の数（Lean を読んで数えた）: RangeExpr 3（被覆9対）、PathPattern 2（4対）、PathBase 5、RangeIx 2（4対）、Atom の三形（9対）、Range 4（旧16場合）、Val 25、Comp 16、HasTypeVQ 29（保持3・包む3・その他23。loc だけ2規則で直接26）、`Val.target?` が some の3構文、checkAt 8葉（`PathResolution.checkAt`）、AtPrepare の局所23葉（AtPrepare 3・pattern 2・入力5・bases 4・finishPreparation 9）、AtFailure 7（unbound の展開で11形）、IOShape 3、Outcome 3、Step 76 と下書きが挙げた11の遷移の名前、Checked の makeHost/makePath/makeEndpoint の4/4/7葉。
- 範囲 API: 旧 `TargetTable.entries` の15行（ref2＋13）、`ioIn` の7本と `pureIn` の6本、引数名・型・効果・`rkinds`・`admitsR` が下書きの表と一致した。旧モデルの署名は Model 2・ModelTargets 7・ModelHttp 5 であり、新しい3・15・7（延べ25）の内訳も足し算として合う。
- 条件の欄: CoreAssumptions は SubstitutionAssumptions（値4＋型4）・ExternalAssumptions 3・ResponseAssumptions 4・独自13欄であり、release_exists を除く12欄と TargetAgreement 1 を加えた25欄、L60 に残る4欄×3＝12欄の数え方は正しい。F09 の構造体の欄は Core の欄の型をそのまま写している。
- 控除 C01〜C18 の名前は、すべて下書きが挙げたファイルにある。HeldValues の三つの逆転は芯と被覆を返し、`Ty.LeQ.holds` は前向きだけである（下書きの注記どおり）。`StateTyE.at_ok_all` は `hcurrent` を前提に取り、`E_AtOk` 自身も同じ前提を持つ。F06 の `AtPrepared.current` が要ることの読みは正しい。
- 義務: plan の担当26行と、三段末の残る段の欄の集合（9・4・13）、和集合29、共通4は、表を機械的に解析して再現した。O064 を L60 の担当とする読みも、plan と L40 の義務の照合に一致する。分類の数（技術26・記録2・他段1・共通4、申し送り23・5・2）は本文の表と一致した。
- 申し送り: L40 段末の L50 の行、`g/handoffs.md` の H31、L30 の処分表の Pair の行と A5 の行、L20 の J20-2・「実表・三モデル」の行、RV-L00b.13 の中2・軽2〜4・6・7、RV-L00b.15 と同依頼の再軽3、RV-L10 の O013、RV-L20.bc の sig_scoped、RV-L40.g の6行、l00b.15 theorems の L50 の行は、いずれも H01〜H30 のどれかに受け口があった。L40 の結果で L50 へ分類した標準 API は0件であり、新しい受け口は要らない。
- 試行の再現: results.md の Lean 入力の全文は 3,860 バイトで、SHA-256 が記録と一致した。
- 見込み: 60単位の幅の和は 2,390〜4,455分（中心57時間2分30秒）、群ごとの和も results.md と一致した。枠との差、work の参考値（456.52秒×12）、L40 の台帳の引用も台帳と一致した。外側の時間を能動時間へ代入していない。
- 記録: 二つのファイルは100 KB 未満であり、手元の絶対パス・docs/todo へのリンク・`work/` の参照はない。

## 設計者の判断が要る点

- 中3 の時期の問い（U02 の公開形を L50 で確定するか、元の L70 前の期限のままにするか）。形の問いは、時期が L70 前のままなら U02 の他の項目とともに後で問えばよい。
- 下書きの J50-2 と同じく、新しい前提・公理・精密な外部状態を求める案は、本レビューでも見つからなかった。

## 再現の入力

`formal/` で `lake env lean -M 12288 <tmp>/rv-check.lean` を実行し、終了0、外側の時間は0.36秒（初回の修正前の実行は3.34秒）だった。入力は2,588バイト、SHA-256 `31b7bea42ecc34881cd765d26a743a46183c295a96e055172c020a94f3f16686`。

```lean
import Benitoite.Release.Refinement.LeafInputs
import Benitoite.Release.Refinement.PathBasesLeaves
import Benitoite.Release.Refinement.ModelHttp
import Benitoite.Release.Refinement.EffectFacts
import Benitoite.Release.Refinement.HeldValues
import Benitoite.Release.Refinement.CanonicalValues
import Benitoite.Release.Refinement.BuiltinEffects
namespace RVL50
open Benitoite.Release.Refinement
open Benitoite.Scope.Domain

-- 既存の Eff.Allows の所在と形
#check @Eff.Allows
#print Eff.Allows
#check @Eff.allows_norm

-- F01 の第二式を Valid なしで証明できるか
theorem covers_mem {outer inner : RangeExpr} (h : outer.Covers inner) (σ : PathEnv)
    {k : Kind} {t : Target} (hm : inner.Mem σ k t) : outer.Mem σ k t := by
  obtain ⟨hk, hm⟩ := hm
  refine ⟨hk, ?_⟩
  rcases h with rfl | h
  · simp [RangeExpr.resolve, Range.Mem]
  · cases outer <;> cases inner <;> simp only at h
    · rename_i r s
      simp only [RangeExpr.resolve, List.mem_singleton, exists_eq_left] at hm ⊢
      exact (Range.Covers.sound h) t hm
    · rename_i b p c q
      obtain ⟨rfl, hpq⟩ := h
      simp only [RangeExpr.resolve] at hm ⊢
      cases hl : σ.lookup b with
      | none => simp [hl] at hm
      | some w =>
        simp only [hl, Option.map_some, List.mem_singleton, exists_eq_left] at hm ⊢
        have hc : (PathPattern.atBase w p).Covers (PathPattern.atBase w q) := by
          change PathPattern.Covers p q at hpq
          cases p <;> cases q <;> simp only [PathPattern.Covers, PathPattern.atBase] at hpq ⊢
          · exact congrArg (w ++ ·) hpq
          · obtain ⟨r, hr⟩ := hpq
            exact ⟨r, by rw [hr, List.append_assoc]⟩
          · obtain ⟨r, hr⟩ := hpq
            exact ⟨r, by rw [hr, List.append_assoc]⟩
        exact (Range.Covers.sound (r := .path (PathPattern.atBase w p))
          (s := .path (PathPattern.atBase w q)) hc) t hm
    · exact hm

theorem snapshot_mono {snapshot : Option PathEnv} {k : Kind} {r s : RangeExpr} {t : Target}
    (h : SnapshotMem snapshot k r t) (hc : s.Covers r) : SnapshotMem snapshot k s t := by
  cases snapshot with
  | some σ => exact ⟨h.1, covers_mem hc σ h.2⟩
  | none =>
    cases r with
    | absolute q =>
      rcases hc with rfl | hc
      · exact ⟨h.1, trivial⟩
      · cases s <;> simp only at hc
        exact Range.Covers.sound_memK hc h
    | based _ _ => exact h.elim
    | secrets => exact h.elim

#check @HasTypeVQ.canonical_held
#check @Builtins.CoreAssumptions.io_event_covered
#print axioms covers_mem
#print axioms snapshot_mono
end RVL50
```

## 再レビュー（再開1）

2026-11-04。対象は再開1の後の `l50/detail.md`（99,322 バイト、SHA-256 `b1b0e6af…`）・`l50/results.md`（20,825 バイト、SHA-256 `e63e11ec…`）と、担当の報告である。処置した部分だけを読んだ。中3 は、取りまとめの判断（U02 の期限を plan どおり L70 前に保ち、L50 は D61 の保存内容を内部で持つところまでとする）を前提に読んだ。Lean の新しい試行は行っていない。名前の所在は grep で確かめた。

### 結論

**条件付き可**（新しい所見は中1・軽3、計4件）。

前回の10件はすべて修正案に沿って処置された。軽1 の群 D だけは、前回の本レビューの修正案の書き方に誤りがあったため、処置もその誤りを写している（再1軽1）。条件は再1中1 である。U02 の二案は、既存の公開 `ScopeError` の6構成子のうち `OutsideScope` との関係しか示していない。設計者へ U02 を問う前に直す。L50 の起動の条件ではない。

### 前回の所見の処置

| 所見 | 判定 | 確かめた内容 |
|---|---|---|
| 中1 | 可 | C19 は `EffectFacts` の `Eff.Allows`・`Eff.allows_norm` で、名前と範囲は正しい。F02 と .09 は再宣言せず、既存の定義を使う。T07 は継承に移り、新しい移植は13件になった |
| 中2 | 可 | C20（`canonical_held`、`Ty.Holds.unique_name`）と C21（`ShapeOk.operation`、`io_event_covered`・`io_transition_covered`・`pathBases_event_covered`・`pathBases_transition_covered`）は、いずれも記載のファイルにある。`canonical_held` は Γ を空、C を任意とする形であり、F03 の閉じた入力に合う。opaque 定数の枝を除くための `HasTypeVQ.inv_const` は ValueFacts にある。.02 は F03 を証明し、.11 は 20〜35分の照合へ縮めた。O060 は既存の被覆を継承し、F02/F05 の接続だけを足す |
| 中3 | 可 | J50-1・F10・O097・H20・H21・.04/.20/.53 は内部保存に限られた。U02 に依存する単位の依存の欄・手順はない。.04 は「U02依存部分は実装しない」、.20 は「公開写しはU02後」、.53 は「公開宣言/観測/網羅性の写しはU02後・L70前へ渡す」とし、見込みも縮めた（45〜90分から30〜60・40〜75・30〜55分）。範囲・依存・見込みに矛盾はない |
| 軽1 | 一部（再1軽1） | 群 A は F01〜F10 すべての型検査と F03/F04 の証明を、群 K は各行に完全名を要求する。群 D は「23局所葉×8葉の全184組」とした |
| 軽2 | 可 | F05 は `hsh : B.ShapeOk b sg` と `TargetAgreement` を取り、Core を要求しない。証明に要るものも足りている（判断）。untargeted は ShapeTargets、topTargeted は ShapeOk の `eff = single l` と `effKind l = some k`、single は ShapeOk の `rvar 0` の効果を `rs = [r]` で具体化したものと F04 から得られる。L50 の三モデルは `io_op` を25条件の内で作るので、.35・.45 に適用できる |
| 軽3 | 可 | H31 は cases.md の9行を列挙し、受け持つ単位（02/08/11/17/18/20/28/35/53/54）と、externalRef・externalHandle・scopePattern・atError の全有効 σ の AdequateResult（.28/.53/.54）を示す。外部応答の充足とも区別している |
| 軽4〜7 | 可 | H27 の文言、L40 の受け入れ済みへの更新（「受け入れ待ち」の記述は残っていない）、再現できない数の削除、「Lean の private 宣言と自動生成の宣言」への書き換えを確かめた |
| 情報1 | 可 | F01 の強い形を採った |

### 再1中1: U02 の二案が、既存の公開 `ScopeError` の他の5構成子との関係を示していない

- 箇所: 第9節「U02に提示する公開エラーの二案」の最後の段落（「両案とも既存の`OutsideScope(String, String)`を残す」）。
- 問題: 公開の `Scope.ScopeError` は6構成子を持つ（`docs/reference/benitoite.md` の Scope の節、`crates/benitoite/src/builtins/table.rs` の `tags`）。`InvalidPattern(pattern, reason)`・`InvalidTarget(target, reason)`・`InvalidPortRange`・`InvalidPort`・`OutsideScope(pattern, target)`・`PortOutsideScope` である。At の失敗のうち invalidPattern・invalidTarget は、既存の `InvalidPattern`・`InvalidTarget` と同じ役割に見える。二案はどちらも、これを `At` の中の失敗種別として別に表すのか、既存の構成子へ写すのかを書いていない。同じ失敗を二通りに表すなら、設計原則5（同じ役割の構文を増やさない）に触れる。利用者の照合の書き方も変わる（Rust の `reason` の英文は At 側に欄がない）。設計者が二案を比べるのに必要な材料である。
- 根拠: 読めば確定。
- 修正案: 二案の表の後に、既存6構成子と At の7失敗の対応表を加える。少なくとも invalidPattern・invalidTarget について、既存の構成子を使うか At の内に置くかを各案で示し、照合の例を一つずつ加える。

### 再1軽1: 群 D の「23局所葉×8葉＝184組」は母集団として合わない（前回の本レビューの修正案の誤り）

- 箇所: 群 D の完了条件、L50.18 の手順。
- 問題: 23葉には途中の判定（pattern の some、bases の none など）が含まれる。準備の失敗の葉は checkAt へ進まない。直積を取ると意味のない組が大半になり、到達不能の排除の定理を大量に要求してしまう。前回の軽1 で本レビューが「23局所葉×8葉の各組」と書いたのが原因である。
- 根拠: 読めば確定（`AtPrepare`・`prepareCore`・`finishPreparation` の分岐）、判断。
- 修正案: 次の二つに分ける。
  - 準備の失敗の終端の葉（rvar 1、pattern 1、入力 3、bases 2、finishPreparation 8 の計15）は、それぞれ E_AtPrepareError へ進む。
  - 準備の成功の経路（入力の parse/reqTarget の成功 2 × bases の none/有効 some 2）は、それぞれ checkAt の8葉を経て E_AtOk/E_AtError へ進む。snapshot が none の経路で到達しない葉（based/secrets の未解決など）は、finishPreparation の拒否から除く。

  数は 15＋4×8 を上限とし、実際の数は .18 で数える。

### 再1軽2: F04 の証明を .02 へ移したのに、.14 が同じ手順と見込みを残している

- 箇所: L50.02（45〜90分から60〜105分）、L50.14（45〜90分、「ShapeOkとBuiltinArgsの同じtelから対象位置をlookup→F03」）。
- 問題: F04 の中心は依存列の lookup であり、それが .02 へ移った。.02 は15分しか増えておらず、.14 は手順も見込みも元のままである。どちらかが二重に数えているか、.02 の見込みが足りない。
- 根拠: 読めば確定、判断。
- 修正案: .14 は「.02 の F04 を実読者（型・値の代入後）へ適用する」だけにして見込みを縮めるか、.02 の上端を F04 の分だけ上げる。

### 再1軽3: 案B の公開の型の数と、Rust 側の作業が示されていない

- 箇所: 第9節の案 B の段落と、写しの見込みの表。
- 問題: 案 B は `Scope.RangeExpr`・`Scope.TargetInput`・`Scope.RangeAtom`・`Scope.Target` を公開 data にする。これを型付きで持つには、PathPattern・HostPattern・EndpointPattern・PortRange などの中の型も公開することになるが、その数が書かれていない。案 A の JSON の符号化も、新しい公開の規則として文書化が要る。見込み（A 1時間30分〜3時間、B 3〜6時間）は Lean の L70 の写しだけで、R30/R60 の実装と D10 の文書は含まない。設計者が比べる材料としては片側である。
- 根拠: 読めば確定、判断。
- 修正案: 案 B で新しく公開する型の一覧（入れ子を含む）と、両案の R30/R60/D10 への影響を一行ずつ加える。見込みが不明なら不明と書く。

### 確かめて問題がなかった点

- 見込み: 60単位の幅の和は 2,335〜4,315分、すなわち38時間55分〜71時間55分、中心55時間25分。群ごとの和（A 215〜390 … L 160〜300）、群 B〜K の小計 32時間40分〜60時間25分、枠との差（2時間25分・12時間05分・4時間50分）は、いずれも再計算と一致した。
- 集計: 義務は33行（技術26・記録2・他段1・共通4）、申し送りは31行（技術24・継承5・他段2）で、表の機械的な集計と一致した。
- 記録: detail.md は 99,322 バイトで 100,000 バイトを下回るが、余裕は約0.7 KB である。今後書き足すときは、第9節の U02 の材料を別のファイルへ分けることを推す。

## 再々レビュー（再開2）

2026-11-04。対象は再開2の後の `l50/detail.md`（97,103 バイト）・`l50/results.md`（29,907 バイト）・新しい `l50/u02-options.md`（25,094 バイト）と、担当の報告である。処置した部分だけを読んだ。Lean の新しい試行は行っていない。定義は Lean のソースを読んで確かめた。

### 結論

**可**（新しい所見なし。情報1件）。

再1中1・再1軽1〜3・前回の情報は、いずれも修正案に沿って処置された。

### 処置の確認

| 所見 | 判定 | 確かめた内容 |
|---|---|---|
| 再1軽1（群 D の 47） | 可 | 準備失敗の終端は15葉で、`AtPrepare` の rvar 1、`prepareCore` の pattern none 1、入力 3、bases 2、`finishPreparation` 8 の和である。入力の3は、content なしの parse none、content ありの groundVal 偽と reqTarget none である。bases の2は、pathBases の非 Valid とその他の値である。finishPreparation の8は、valKind 不適合、bound 形成不適合、snapshot なしの6分岐である。成功の経路は、入力の成功2（parse some、groundVal 真かつ reqTarget some）と bases の成功2（none、Valid な pathBases）の組み合わせで4になる。それぞれ checkAt の8葉へ進むので、15＋4×8＝47 を上限とすることは Lean の定義と一致する。到達しない組を .18 で実数とともに記録する条件も、L50.18 と群 D に書かれている |
| 再1軽2（.02 と .14） | 可（情報1） | 任意の p の lookup と型・値の代入を含む F04 の一般証明は .02 に置かれた。.14 は「証明済み F04 の実読者への適用」だけになり、20〜40分に縮んだ。二重計上は解消した |
| 再1中1（ScopeError 6構成子） | 可 | 6構成子の引数は、英語リファレンスの Scope の節と Rust の `tags` に一致する。At 側の分類も Lean と一致する。invalidPattern には bound の形成不適合が、invalidTarget には valKind・groundVal・reqTarget・bases の不適合が含まれる。動的なホストの不所属とポートの不所属はどちらも dynamicCondition であり、`AtFailure.outsideScope` は現行の checkAt も準備も返さない。重複を避ける二つの選択肢も正しく書かれている。旧構成子だけに写すと D61 の保存内容を持てない。At を包みにして旧構成子を原因に使うと、入れ子の制限が要る。照合の例と設計原則5への言及もある |
| 再1軽3（案 B の19型） | 可 | Refinement の新しい6型（AtDetail・AtInput・PathBase・AtFailure・RangeExpr・TargetInput）に、`Scope/Domain.lean` の帰納型と構造体14のうち `Kind` を除く13を足して19になる。13の内訳は PathPattern・NamePattern・Family・IPAddr・CIDR・IPPattern・HostTarget・HostPattern・PortRange・Endpoint・EndpointPattern・Target・Range（＝RangeAtom）である。Word・Port は別名なので数えないという扱いも定義に合う。`Kind` は Target の構成子で区別できるので公開しない、という射影も筋が通る。案 A の JSON 規則の一覧と、R30・R60・D10 の「不明」の明記も揃っている |
| 情報（detail の大きさ） | 可 | 比較の材料を u02-options.md へ分け、detail は97,103バイトになった。三つのファイルとも100 KB 未満で、手元の絶対パス・`work/`・docs/todo への参照はない。相対リンク先（設計原則の章、`Scope/Domain.lean`、`Http.bnt`）も実在する |

見込みを再計算した。60単位の幅の和は2,310〜4,265分（38時間30分〜71時間05分、中心54時間47分30秒）である。群 C は2時間35分〜4時間45分、群 B〜K の小計は32時間15分〜59時間35分である。枠との差（2時間00分・12時間55分・5時間27分30秒）とともに、いずれも記載と一致した。

### 情報1: .02 は F04 の一般証明を引き受けたが、見込みは60〜105分のままである

.14 から lookup と代入の処理が移ったのに、.02 の幅は再開1の値のままである。C20 の利用で F03 が小さくなった分と相殺される見込みはある（判断）。群 A の最初の1時間の点検で .02 の進み方を確かめる。上端の2倍に達しそうなら、通常の停止条件で報告すればよい。計画を直す必要はない。

## 取りまとめの追記

- 初回の中3は、取りまとめの判断で、U02 の時期を plan どおり L70 の前に保つ形とした。L50 は D61 の保存内容を内部の形で持つところまでを行い、公開形への写しは U02 の確定の後に行う。U02 を問う材料は `l50/u02-options.md` に置いた。
- 初回の所見は担当の再開1で、再レビューの所見は担当の再開2で処置し、再々レビュー（再開2）で可とした。再々レビューの情報1（.02 の見込み）は、群 A の最初の1時間の進み方で確かめる。
- L50 の詳細は plan.md の 2026-11-04「L50 の詳細の確定」の項で `l50/detail.md` を正とした。
