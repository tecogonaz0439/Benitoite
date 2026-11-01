# RV-L10.x 独立レビューの記録

2026-11-01。対象は `m014/l10.x` の未コミットの作業ツリー、基準は `efbc8ebf58b0a64320f375e663ad929a29e73e86` である。

**判定: 条件付き可。所見は重0・中1・軽5、計6件である。** 五つの境界（主な定理の前提と結論、新公理、提供範囲、書ける形、精密な外部状態）に触れる所見はない。

中1は `ValueMeaning` の定義と G09 へ残す署名の修正であり、`Inhabits`・`Exhaustive`・`PatTy`・主な定理は変えない。修正後の確認は該当の節だけでよく、全体の再レビューは要らない。

## 所見

### 中1: `valueMeaning_sub` の言明が `scoped_forget` で偽である

- 箇所: `<repo>/formal/Benitoite/Release/Refinement/ValueMeaning.lean` の `ValueShapeMeaning.scoped`。`l10/x/signatures.md`「G09 へ残す完全署名」の `valueMeaning_sub`、同「補助の契約で決めたこと」の1、01-12「篩を読む網羅性と値の意味」の「照合が内部を観測しない型の形は `Inhabits` と同じ上側近似である」。
- 問題: `ValueShapeMeaning.scoped` は任意の値を受ける。`Ty.LeQ.scoped_forget` は `.scoped o k ix` を `.opaque o ix` へ移すが、`.opaque` の意味は成功値と定数の形だけを受ける。したがって `.const .unit` は `.scoped` の意味を持ち、`.opaque` の意味を持たない。意味の判断の中で上側近似から狭い形へ移る部分型の規則は、これ一つである。
- 影響: G09 の V_Sub の場合を `valueMeaning_sub` で閉じる予定は、この署名のままでは閉じない。型付き値の反例ではない。閉じた型付き値で `.scoped` に属するのは `checked`・`checkedRequest`・`checkedAt` だけなので、`typed_value_meaning_closed` と `inhabits_of_typed` の結論は偽ではない。帰納の不変量が弱いことが問題である。依頼の重点の「型付けから `ValueMeaning` を全場合で導けない定義になっていないか」に該当する。
- 再現: `rv-x-t1.lean` の `valueMeaning_sub_statement_false`。Lean で偽を証明した。P は宣言が空で `VarianceValid` を満たす。依存は `propext`・`Classical.choice`・`Quot.sound` だけである。
- 修正案: `ValueShapeMeaning.scoped` の前提に、範囲の添字と値の形を結ぶ判断を足す。`rv-x-t1.lean` の `ScopedValue` が形の例である（`.fixed r` と `checked`、`.fixed r` と `checkedRequest`、任意の添字と `checkedAt`）。`ScopedValue.covers` が `Ty.LeQ.scoped`、`ScopedValue.forget` が `scoped_forget` の移送を閉じることを同じ入力で確かめた。`Inhabits.scoped` は上側近似のままでよい。`ValueMeaningInhabits` の `.scoped` の枝、signatures の決定1、01-12 の該当の文を同じ変更で直す。署名の別案として `valueMeaning_sub` に値の型付けの前提を足す案もあるが、意味を型付けの導出から切り離す設計を崩すので推さない。

### 軽1: 型置換の担当への申し送りがない

- 箇所: `l10/x/results.md`「残りと送り先、群 W への申し送り」。
- 問題: 新 E_Fun などは `d.body.substTy ts es` へ進むので、型置換の保存（L00b.15 の表の G03）で旧 `Exhaustive.substAt` 相当が要る。群 X の移送は値置換・値の移動・型の移動の三本で、型置換の `Inhabits` の反映と、`PatTy`/`AltsTy` の型置換は Lean にも送り先の表にもない。`Ty.subst` は正規化するので、`P_Refined` と `P_Convert` は値置換と同じ扱いが要る。
- 再現: 読めば確定する記録の不足である。言明が偽だという反例はない。読むかぎり、`Inhabits.of_substAt` は値置換と同じ形で成り立つ見込みであるが、Lean では確かめていない。
- 修正案: 送り先の表へ G03 の行を足す。

### 軽2: パターン束縛の型保存の言明の形が申し送られていない

- 箇所: `l10/x/signatures.md` の決定7・10、`results.md` の残りの表。
- 問題: `P_Convert` の前提の型 `a` は注釈を持たなくてよいので、`v : b` から `v : a` を V_Sub で作れない。たとえば `Cont{true}` は不適格だが、正規形は適格である。照合の束縛の型保存は、`v : a.norm` を入力として `δ.map Ty.norm` を結論とする形にし、未変換の導出の生の束縛型へは形成が分かる場合に戻す必要がある。
- 再現: 変数パターンについて、束縛型の述語列が入力型の接頭辞で core が等しいこと（`var_binding_prefix`）と、意味が束縛型へ移ること（`var_binding_meaning`）を `rv-x-t2.lean` で証明した。規則が束縛型を不当に強める反例はなかった。一般のパターンの言明は Lean で確かめていない。
- 修正案: 上の言明の形を L20 の義務へ書く。

### 軽3: L70/R10b への申し送りに束縛型の照合がない

- 箇所: `results.md` の残りの表。
- 問題: Rust の照合が篩付きの被検査値で変数へどの型を与えるかは、`P_Var` の篩型、`P_Refined` の途中の型、`P_Convert` の正規形のどれと対応するかの照合が要る。送り先の表はソースからの型の合成と guard/unknown だけを挙げる。
- 再現: 読めば確定する記録の不足である。
- 修正案: L70/R10b の行へ足す。

### 軽4: 新しい術語の調査の記録がない

- 箇所: `<repo>/docs/design/00-overview/00-04-glossary.md` の「値の意味」「観測の情報の順序」。
- 問題: AGENTS.md は新しい概念の名前を決める前に、他の言語での呼び名と日本語の用例を出典付きで示すことを求める。群 X の記録にその調査がない。「情報の順序」は領域理論の information order に近い語だと思われるが、本レビューでは出典を確かめていない。
- 再現: 読めば確定する手順の不足である。
- 修正案: 改造の判断の文書へ調査と出典を記し、設計者に選んでもらう。

### 軽5: 計画の文書と境界の入力の補強

- 箇所: `l10/detail.md` の X1、`l10/x/boundary.lean`。
- 問題: detail は事実を `a.norm.assume` とし、不適格な継続上の篩を正規化が消すと書くが、現行の `Ty.norm` は消さない。計画の10規則も実際と異なる。`inhabits_of_typed_raw` の WF は、`Inhabits.norm_all_iff` により論理上は要らない。境界には、開いた入口 `nonempty_from_entails` の実例と、値依存の等号だけでは空 List が残る負例がない。
- 再現: `rv-x-t4.lean` の `open_nonempty_instance` が経路条件の非空の述語から実際の変数で入口を使い、`rv-x-t1.lean` の `length_equality_not_exhaustive` が `listLength self == 外側の値` の型で `[head, ...rest]` だけの腕が網羅でないことを示す。どちらも成功した。誤りの再現ではなく、本番の主張を確かめた結果である。
- 修正案: detail の差分は取り込みのときに結果を正として注記する。二つの例を `boundary.lean` へ写す。

## 独立に確かめて問題がなかった重点

| 重点 | 結果 |
|---|---|
| 網羅性の健全性 | 値の型付け29規則を全て読み、閉じた型付き値が `Inhabits` の形に入ることを確かめた。`atError` は `ResultShape.Declared` が標準の誤りの型へ固定する。`checked`・`checkedRequest` は閉じた型で範囲が fixed に限られる。`checkedAt` は `checkedAtOpaque` が覆う。`.const` は `Const.opaque` も `Const.type` で覆う。反例は作れなかった。全導出の証明は G09 に残るので、健全性の完了とは記録しない |
| `refined` の判定 | false の確定だけを除く。内部 slot の欠落・関数・Reference・Lazy の欄は `none` のまま残り、At の値は同じ `toTerm?` で観測する。`RefinementPossible.conjuncts` と `Inhabits.norm_all_iff` により正規化の前後で判定は食い違わない |
| 進行の側の見通し | `rv-x-t3.lean` の `closed_refine_true` が、閉じた V_Refine の `Entails [] (p.open t)` から `p.interpret (selfModel η v) = true` を導く。`toTerm_interpret` が値の項の観測と解釈の一致を示す。部分型のうち `refine` と同じ形の `introduce`、`forget`、`convert`、data、List は `valueMeaning_sub` で閉じる見込みである。中1 だけが閉じない |
| `P_Convert` の妥当性 | 追加は妥当である。正規形の構造の等号だけを読み、述語列と core を保ち、新しい含意を許さない。`P_Refined` だけでは `substituted_pattern` の結論を保てない。元の10規則の入口はそのまま導ける。`Inhabits`・`Exhaustive` の判定を変えず、利用者の構文も増やさない。01-12 の写しは Lean と一致する |
| 情報の順序と単調性 | `observe_mono`・`evalWith_mono`・`bind_observe_info`・`close_preserves_decided` は `of_meaning` と値置換の反映が実際に使う。some の確定値を保つ形で、`interpret` の無条件の不変性を仮定しない。`fallback_info` は `getD` の枝を未観測の場合に限る。反対称性も定理がある |
| `refinementPredicates` の判断 | 妥当である。`Cont{false}` の意味を空の事実から作らず、`Ty.assume_eq_predicates` により適格な型で予定と一致する。継続型上の篩は V_Refine と注釈の形成で閉じた導出に現れないので、型付けからの供給も妨げない |
| 開いた型 | unknown の値を除かず、暗黙の実行時検査もない。`nonempty_from_entails` は静的な含意を受けてから非空型へ強める。`Capture.meaning_coverage` は値置換の反映だけを使う |
| 旧証明の廃止 | `Inhabits.of_core` と `of_subst_values_core` は消え、`reflect_subst_core` の結論は core に限られる。篩へ戻すには `of_core_possible` の全述語が要る。量化が狭まる変更なので `Exhaustive` を前提に読む定理は弱まらない。空虚になるのは篩の値が実際にない場合だけで、その腕の省略は `inhabits_of_typed` に懸かる。`Release/Patterns.lean` は現行になく、旧 Release の `Exhaustive` は別の名前空間で影響を受けない |
| 群 W への申し送り | 同じ P の `VarianceValid` を意味の信頼欄にしないことが明記されている |
| 主な定理と境界 | Typing・TypingShift・TypeShiftTyping・SubstTyping・Narrowing・StateTyping・MatchPaths・ClosedEvaluation・lakefile は基準から差分がない。`PatTy` の追加は承認済みの `P_Refined` と、上で妥当とした `P_Convert` である |
| 正例と負例 | Month・空篩・非空 List は実際の `matchVal` を結論とする。`unknown_not_exhaustive`・`month_13_excluded`・`unknown_with_false_excluded` は空虚でない。`flattened_requires_conversion` は変数パターンの10規則の導出を覆う |
| 件数と記録 | `Inhabits` 24+2+2、`PatTy` 9+2、意味の四族 1+23+2+2、情報の順序 5+2+2、値の型付け29を読んで確かめた。`lake build` は全751ジョブが成功し、変更なしの判定で再利用された。`boundary.lean` の出力は記録と一致し、`axioms.lean` は1,344宣言で sorryAx なし、出力の SHA-256 は記録と一致した。`source-state.json` の完了時27件と検証入力4件のハッシュは一致した。署名の出力は97件である。絶対パス、`work/`、`reference/` への参照はない |
| 文書の写し | 01-12・07-04・用語集の記述は中1 の一文を除き Lean と一致する。規範の text ブロックは変わらず、Rust との全比較の範囲を広げていない |

## 補助の入力

`<tmp>/rvl10x/` に置いた。全て `lake env lean -M 12288` で終了0、sorry なし、依存は標準の三公理だけである。

| ファイル | 内容 | 結果 |
|---|---|---|
| `rv-x-t1.lean` | `valueMeaning_sub` の言明の偽、修正案の形、値依存の等号の負例 | 中1 を再現 |
| `rv-x-t2.lean` | 変数パターンの束縛型の接頭辞と意味の移送 | 問題なし |
| `rv-x-t3.lean` | 閉じた V_Refine から意味の真、値の項の解釈と観測の一致 | 問題なし |
| `rv-x-t4.lean` | 開いた入口の実例 | 問題なし |

## 設計者へ示す点

- `ValueMeaning` の `.scoped` を成功値の形へ絞る（中1）。定義の変更であるが、主な定理の前提と利用者の書ける形は変わらない。
- `P_Convert` の追加と、意味の事実を全 `refinementPredicates` とする判断は、どちらも妥当と判定した。
- 網羅性の健全性は G09 の `inhabits_of_typed` に懸かり、本レビューの反例探索はその代わりにならない。

## 取りまとめの追記

2026-11-01。補助の入力は `l10/x/rv-x-t1.lean`〜`t4.lean` へ写した。中1は本文の修正案のとおり、`ValueMeaning` の `.scoped` の意味を範囲の添字と成功値の形を結ぶ判断へ絞り、同じ変更で 01-12 と signatures を直す。`Inhabits`・`Exhaustive`・`PatTy`・主な定理は変えない。軽1〜5 も同じ再開で処置する。五つの境界に触れないので、plan.md の判断の行は足さない。
