# RV-L20.i: L20 群 I（L20.89〜.96）の独立レビュー

2026-11-02。対象はブランチ `m014/l20.i1` の未コミットの作業木、基準 `e485c90c`。依頼文 `L20.i-prompt.md`、担当の報告、`l20/i/` の記録、`l20/detail.md` の S07・S08・S08a、G06・G09、L20.89〜.96、義務 O039・O046・O138・O143・O167、`plan.md` の確認点、`RV-L20.a4.md` の付録を読み、新規の Lean 7ファイルを全文読んだ。補助の入力は `<tmp>` に置き、既存のファイルを変えていない。

## 総合判定

**条件付き可**。重 0 件、中 2 件、軽 5 件。

Lean の本体に誤りは見つからず、三つの入口（`typed_value_meaning_closed`・`inhabits_of_typed`・`inhabits_of_typed_raw`）、捕捉の3入口、束縛保存、O143 の二定理の言明はそのまま受け入れてよい。新しい公理、独立の信頼条件、弱すぎて空虚な言明、既存の規則の変更はない。主定理の入力から網羅性と全照合成功の束縛までの接続は、補助の入力で実際に閉じた。

条件は適用例と記録の二点である。中1は捕捉の2入口に例の適用がなく「全入口」の記録が過大な点、中2は O167・O138 が求める受理と拒否の対照が本番にない点である。どちらも補助の入力で閉じることを確かめたので、本番への追加は小さい。言明、規則、公理は変わらない。

## 所見

### 中

#### 中1: 捕捉の2入口に例の適用がなく、「全入口」「全定理」の記録が実物より多い（読めば確定）

- 場所: `formal/Benitoite/Release/Refinement/TypedMeaningExamples.lean`、`PatternBindingExamples.lean` 46〜51行、`l20/i/results.md` の L20.93 の行と「Inhabits と捕捉の入口・適用」の表、担当の報告の「意味と所属の各入口には」、`l20/detail.md` の L20.93 の行。
- 問題点1: L20.93 と依頼文は「Month・空型・非空 List・unknown へ全定理を実際に適用する」と書く。4例が通るのは `typed_entries`、つまり型付けの3入口と `valueMeaning_sub` である。L20.92 の `Capture.typed_meaning`・`Capture.typed_coverage` は既定 import の中に読者が一つもない。
- 問題点2: `CaptureOk.typed_variable_coverage` の適用は `month_variable_coverage` の一つで、`CaptureOk` と変数の型付けを仮定のまま受ける。例が具体の捕捉に届いていない。
- 問題点3: `results.md` の表の見出しは「Inhabits と捕捉の入口・適用」で、Month の行は「全入口」と書く。非空 List の行も「全入口」である。捕捉の入口も適用済みと読める。
- 確認: 補助の入力 `P2.lean` で、`cap5 = Capture.empty.extend 5` について `Capture.typed_meaning` と `Capture.typed_coverage` を `monthType` へ適用した。値依存の型 `integer{self = x}` への `Capture.typed_meaning` は、閉じた型付けを仮定する形で通した。`P3.lean` で `CaptureOk.extend` から作った具体の捕捉を `month_variable_coverage` へ渡した。いずれも成功したので、言明に問題はない。
- 影響: L20.92 の入口は言明の確認だけで残り、記録は適用済みと読める。後続の群 J が読むまで使える形の証拠がない。
- 修正案: `P2.lean`・`P3.lean` の形を本番の例へ足す。Month は具体の捕捉で3入口を通す。非空 List は `Capture.typed_coverage` を通す。空篩と unknown の捕捉の適用を省くなら、理由を `results.md` に書く。表の「全入口」は「型付けの3入口」と書き分ける。

#### 中2: O167・O138 の受理と拒否の対照が本番になく、記録に義務の判定がない（読めば確定）

- 場所: `TypedMeaningExamples.lean` 53〜74行、`l20/detail.md` の O167（担当に .89〜.91）、O138（担当に .92）、O039（.85〜.93）、O046（.92）、`l20/i/results.md`。
- 問題点1: O167 は「非観測/None/循環/不変/unknown の制限を受理と拒否の対照で保持」と書く。群 I の例は受理だけである。空篩の例は存在しない値の仮定から矛盾を導くもので、型付かない具体の値を示していない。
- 問題点2: O138 は「unknown で除かず」と書く。`unknown_entries` は所属を結論するが、網羅性で除かれないことの適用がない。`unknownPredicate` は self を読まず、値 5 と無関係に `none` になる。意味と所属は self の観測と評価の組で読むので、self を読む unknown の例の方が実質がある。
- 問題点3: `results.md` の義務の番号は O143 の1件だけである。O039・O046・O138・O167 はこの群が担当に含まれるのに判定がない。群 F の `results.md` は担当の義務に行を設けている。
- 確認: `P2.lean` で次を閉じた。いずれも本番の入口だけで書ける。
  - `¬ HasTypeVQ … 13 monthType`（`reject_top`）。
  - `¬ HasTypeVQ … (.list [13]) (.list monthType)`（`reject_list`）。子の篩まで意味が届くことの確認でもある。
  - self を読む unknown。観測できない鍵を持つ `Map` に `size(self) = size(self)` の篩を付け、`B.sat` の鍵の仮定の下で型付け、3入口を適用し、`evalWith … = none` を示した（`selfUnknown_entries`・`selfUnknown_eval`）。
  - `¬ Exhaustive P selfUnknownType []`（`unknown_not_excluded`）。
- 修正案: 上の4点を本番の例へ足す。`results.md` に O039・O046・O138・O143・O167 の行を置き、閉じた範囲と残る段を書く。O167 の非観測・None・循環・不変のうち、この群の対照が扱わないものは担当の他の単位を示す。

### 軽

#### 軽1: `results.md` の宣言名が実物と違う（読めば確定）

- 場所: `l20/i/results.md` 10行と25行。
- 問題点: `typed_meanings_aux` と書くが、実物は `TypedMeaning.typed_meaning_auxs` である。`signatures.md` は正しい。
- 修正案: 2箇所を直す。

#### 軽2: 計画の文言との差が「計画との差」にない（読めば確定）

- 場所: `l20/i/results.md` の「計画との差と申し送り」、`l20/detail.md` の L20.90・L20.94 の行。
- 問題点1: L20.94 は「変換前後の prefix の事実を供給する」「既存 RootShape/rootShape_of_typing を使い」と書く。実物は Φ が空の閉じた言明であり、prefix の事実は現れない。`rootShape_of_typing` も使わない。`results.md` は「前提に足さない」とだけ書き、計画の文言の扱いを述べない。Refined と Convert は入力の型を移すだけなので、この群に要る事実はない。経路の事実の供給先は群 J である。
- 問題点2: L20.90 は「data/List/Map/Set/Dict と Vs2/Each2 の子を使う」と書く。Map・Set・Dict の子は使わない。理由は L20.90 の行にあるが、差として挙がっていない。
- 修正案: 「計画との差」に2点を足し、prefix の事実の受け手を L20.97〜.99 と書く。

#### 軽3: 07-04・01-12 の前提の書き方が、捕捉の入口について不精確である（読めば確定）

- 場所: `07-04-formal-semantics.md` 96行「これらの意味と所属の入口は CoreAssumptions や進行の定理に依存しない」、`01-12-core-calculus.md` の追加段落「型を閉じる型保存の証明はこの入口の前に行う」。
- 問題点1: `CaptureOk.typed_variable_coverage` は `SubstitutionAssumptions` を受ける。これは `CoreAssumptions` から得られる一部である。任意の値の閉じた型付けを作る `close_value_typed` は `CoreAssumptions` そのものを要求する。意味の導出が要求しないことと、接続の全体が要求しないことは別である。
- 問題点2: 「この入口の前に行う」は手順の文で、何が何を供給するかを述べない。
- 修正案: 「閉じた型付けから意味と所属を導く段は CoreAssumptions を要求しない。閉じた型付けの供給は `close_value_typed` と値置換の仮定による」と書く。

#### 軽4: 新しい語が基準の文書にある語と揃っていない（読めば確定）

- 場所: 01-12・07-04 の追加段落、`results.md`。
- 問題点: 「意味移送」は既存の「意味の移送」と違う。「未知の鍵」は `results.md`・報告の「未観測の鍵」と違い、基準の文書の語は「未観測」である。「観測できる型」「型付き捕捉」「残部」は基準の二文書と用語集にない。
- 修正案: 「意味の移送」「未観測の鍵」と書く。「観測できる型」は `a.HasSort s` を持つ型と書く。「型付き捕捉」は `CaptureOk` と書く。「残部」は S08a の「残りの list」に揃える。

#### 軽5: `bridge_bind_o` に読者がない（読めば確定）

- 場所: `TypedMeaning.lean` 65〜68行。
- 問題点: 定理は証明済みだが、本番のどこからも読まれない。
- 修正案: 消すか、`refine_bridge` の系として使い道を書く。証明には影響しない。

## 観点ごとの確認

### 1. 型付けから意味

- 環境から構成子数を読み、値29・値列2・各要素2、PatTy 9・PatTys 2 を確かめた。`typed_meaning_aux` の `match` の枝を数え、29構成子すべてが現れる。三つの定理は一つの `mutual` で、部分導出だけへ再帰する。
- `typed_meaning_aux` の前提は `VarianceValid`・導出・`Γ = []`・`Φ = []` だけである。Q と C は一般のまま示し、公開の言明は S07 と一字一句一致する。
- 意味は実質を持つ。data の全欄、List の全要素、最外の全篩述語を読む。`reject_list` は `List[Month]` の中の 13 の拒否を入口から導いた。
- Map・Set・Dict は `ValueShapeMeaning` が任意の値に成り立つ形で、値が Map であることも示さない。`Pat` に Map・Set の形はなく、`Inhabits` も同じ扱いで、旧 `Release` の `Inhabits` とも同じである。`ValueMeaning` を読むのは意味・移送・網羅性の9モジュールだけで、外部の受信検査は読まない。網羅性とパターン照合には足りる。Map の要素の型は値の型付けが持つので、意味に求める理由がない。Map の最外の篩述語は読むので、`selfUnknown_entries` は実質を持つ。
- 依頼の「O053」は、`detail.md` では Regular の6操作（.38/.65/.66〜.68）の義務で、L20.89〜.96 を担当に含まない。この群に読者はない。関係する行は O039・O046・O138・O143・O167 である。

### 2. 入力の供給

- `#print axioms` と別に、到達する定数を辿る補助の入力 `P4.lean` を実行した。`typed_value_meaning_closed`（8,798定数）、`alternatives_bindings_typed`（9,809定数）、`Capture.typed_meaning`（9,312定数）に `CoreAssumptions`・progress・preservation の名前を持つ定数は0件である。
- `VarianceValid` は `Program.WellTyped.variance` から得られる。`P1.lean` で `hPB.variance` を渡して確かめた。
- `P1.lean` は、`close_value_typed` の入力と開いた値の型付けから、次の三つを閉じた。
  - `e2e_coverage`: 元の型の `Exhaustive` から `closeVal cap v` の照合の成功。
  - `e2e_meaning`: 元の型への所属。
  - `e2e_bindings`・`e2e_alts`: 開いた `PatTy`・`AltsTy` を `subst_values` で移し、`V_Normal` を通して、全照合成功の束縛を `δ.map cap.closeTy` で得る。

  `P.WellFormed`・`P.WellTyped B`・`B.CoreAssumptions P` は閉じた型付けの段だけが使う。`K_Guard` の `v = closeVal cap vs` と同じ形である。S08 の結論は `CaptureOk.extend` の `cap.closeTy a` の入力と一致する。

### 3. Inhabits の二系と例

- `inhabits_of_typed`・`inhabits_of_typed_raw` の言明は S07 と一致する。4例はどれも定理の適用で、定義の展開で済ませていない。`P2.lean` で Month・非空 List・unknown を具体の `boxProgram` へ適用し、`VarianceValid` の仮定が空虚でないことを確かめた。
- unknown は三値の決定と整合する。`RefinementPossible` は `evalWith ≠ some false` なので、`none` は所属を妨げない。`ValueMeaning` は二値の `interpret = true` を読み、`evalWith_sound` は確定した値にだけ働く。`V_Refine` は `Entails.eq_refl` から入り、評価の失敗を真に変えていない。`unknownTerm` の `mapKeys` は鍵の観測の欠けで `none` を返す。
- 差は中1・中2である。

### 4. S08 の束縛の保存

- 結論は `δ.map Ty.norm` で、raw δ を結論しない。入力は `a.norm` である。
- `VarianceValid` だけへの縮小は前提が減るだけで、P・B・Ψ・p・a・δ・v・ws の量化と結論は S08 の形と同じである。`Q = Qempty`、C・Γ・Φ が空である点も同じである。`Ψ.WF` を外しても本体に影響しない。
- PatTy の9枝と PatTys の2枝は `match` に現れる。P_Convert は入力の型を等号で移し、`(δ.map norm).map norm` を `norm_idem` で閉じる。P_Refined は基底の述語を残す正規形の Annotation を `annotation_norm_subset` で作り、`.forget` の `V_Sub` を通す。P_Con は構成子と標準エラーの両方の値の形を扱う。七欄は `atErrorFields` の宣言と同じ値列である。
- List の前半・後半・中間は `matchVal` の `take`・`drop` と同じ式を読む。`rest` の `none`・`skip`・`bind` の3通りを分ける。
- `alternatives_bindings_typed` は `firstAlt` の左から調べる順に帰納し、`selectSlots` を値列と型列へ同じ `slots` で適用する。`Perm` は結論に要らず、`selectSlots γ slots = some δ` だけを読む。全照合成功の量化は `AltsTy` の全代替で、`e2e_alts` が元の型付けから届く。
- `pattern_bindings_ground` は型付けを読まず、入力の Ground だけを移す。List の中間と標準エラーの枝を含む。

### 5. O143

- `pattern_length_relation` は S08a の言明と一字一句一致する。
- `head_rest_close_typed` は同じ v・rest の閉じた型付け、値置換による観測との一致、`closeVals` の長さの関係を結ぶ。`.95` の文面を満たす。全体の list の観測の `listLength` は結論に含まない。S08a はそこまで求めていない。
- 入力の `hm` は開いた `.list vs` の形である。被検査値が変数なら `closeVal` の結果へ `head_rest_bindings_typed` と `pattern_length_relation` を直接適用できる。
- `head_rest_two` は `[v₀,v₁] → [v₀,[v₁]]` の成功と空 list の失敗を、同じ型付きの入力の中で示す。

### 6. 公理・署名・写し

- 新7ファイルに `sorry`・`axiom`・`native_decide`・`unsafe`・`implemented_by`・`instance`・`set_option`・属性はない。既定 import に7モジュールすべてが入る。`lake build --no-build` は全対象 up-to-date（825 jobs）である。
- `axioms.lean` を再実行し、270件、`sorryAx` 0件、公理は `propext`・`Classical.choice`・`Quot.sound` だけであることを確かめた。出力は 34,667 バイト、SHA-256 は記録と一致する。この実行の最大常駐量は 1,685,962,752 バイトである。
- `signatures.lean` を再実行し、出力が `signatures.md` の一覧と空白を除いて完全に一致する。SHA-256 も記録と一致する。宣言は定理・定義を合わせて60件で、非公開の `ground_list_iff` と unknown の3定義も `signatures.md` にある。
- 01-12・07-04 の追加は軽3・軽4の点を除き Lean と一致する。経緯の文はない。07-04 から消えた「76構成子」「P_Refined」「主な署名は維持する」の内容は、同じ文書の他の段落と新しい段落に残る。腕の実行状態の保存と進行の合成は「結論しない」と書き、証明済みとしていない。

### 7. 記録の主張

- 33 case、60宣言、211宣言と関連59宣言の計270件、構成子数は実物と一致する。
- `results.md` の入力13件の SHA-256 は現在のファイルと一致する。記録の時刻の計算も一致する。
- `l20/i/` と設計書の追加部分に、手元の絶対パス、docs/todo へのリンク、`work/` を出どころとする参照はない。
- 差は中1・中2・軽1・軽2である。

## 推測と確定の区別

- 実行で確かめたもの: 公理監査と署名の再実行、到達する定数の走査、`P1`〜`P4` の接続と例（中1・中2の確認、観点2・3）。
- 読んで確定したもの: 中1、中2、軽1〜5、観点4・5の言明の照合。
- 推測: 中2の「O167 の残りの制限は他の単位が扱う」は `detail.md` の担当の欄からの読みで、各単位の実物は確かめていない。`check.sh --level work` は再実行していない。

補助の入力の SHA-256 の先頭16桁（`<tmp>/rv-l20-i/`）: `P1.lean` f4a5de771cc61de1、`P2.lean` 3a7b736a9021d96c、`P3.lean` 1964e4efe483e3db、`P4.lean` 94d7ff134401c634。

## 取りまとめの追記

2026-11-02。中1・中2と軽1〜5を再開1で処置した。適用例と受理・拒否の対照は既定ビルドへ足し、公理の検査を再実行した（304件、三つの公理だけ）。局所の再レビューは行わない。足したのは例で、言明を変えないためである。処置の後の作業末の work は成功した。
