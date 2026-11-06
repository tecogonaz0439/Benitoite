# RV-L70.f2: L70 群 F2（新しい δ の行、L70.37・.38）の独立レビュー

2026-11-06。対象はブランチ `m014/l70.f2` の未コミットの作業木（変更27ファイルと新規10モジュール・記録）である。基準は `a5a3f7d8993c6f96d8ab90285ddee274347f3862` で、HEAD と一致する。本書の `<repo>` は対象の worktree、`<tmp>` は指定された scratchpad の `rv-l70-f2/`、C は本書を置く改造ディレクトリ、R は `<repo>/formal/Benitoite/Release/Refinement/` を表す。本レビューは本レビュー一回である。

読んだもの:

- 本体の作業木にある依頼文 `work/m014/L70.f2-prompt.md` と再開1〜3の依頼文、再開3の担当の報告、[担当の記録](../l70/f2/results.md)の全節（特に再開3の「止めずに進めた変更」の表）と同じディレクトリの台本・JSON・反例のファイル。
- 本体の作業木の最新の `plan.md` の先頭の、群 F2 の停止への三つの判断（① String の所属、`Refinement.check` の `some true` だけ `Ok`、J70-9 の結果型を群 D へ回すこと）と停止の条件の改め。
- [signatures.md](../l70/signatures.md) の第1節、[U02 の決定](../u02/decisions.md) の S4・S11・R9(b)、[detail.md](../l70/detail.md) の L70.37・.38・J70-9・J70-10・群 F2 の行、[candidates.md](../u02/candidates.md) の R9 の比較（U1・DET-L15 の意味の確認）。
- `git diff a5a3f7d8 -- formal docs/design` と新規の R の10モジュール（`TargetText`・`StringMembership`・`BooleanResult`・`PredicateResponse`・`RefinementCheck`・`RefinementCheckResponse`・`CheckAdmissibility`・`StandardModelPredicateInputs`・`StandardModelCheckInputs`・`MembershipInferenceBoundary`）。核の `Typing.lean`（`C_DependentApp`・`HasTypeTelArgsQ`・`C_If`・`V_Refine`）、`Syntax.lean` の `signatureTel`、`BuiltinResponse.lean` の `BuiltinArgs`、`LogicSound.lean`、`BuiltinSchema.lean`、`PublicNames.lean` の写しの定義を読み合わせた。

したことは、定義と証明の読み合わせ、`AtInput` から `TargetText` への移動の機械的な照合、変更したモジュールの宣言の頭の差の抽出、新しい宣言の読者の確認、ビルドの生成物がソースより新しいことの確認、`<tmp>` に置いた二つの確かめのファイルの単独 Lean 検査である。Lean は `<repo>/formal/` から `lake env lean -M 12288 <file>` で一つずつ実行した。`-o` は使っていない。

`lake build`・cargo・`scripts/check.sh`・担当の台本（`verify.py`・`type_diff.py`・`run_check.py`）の実行と git の書き込み操作は行っていない。台本は読んで判定した。処理系の実装・表層（`Surface/`）・群 D・E の並行の作業は検査していない。変更したリポジトリのファイルは本書だけである。

## 結論

**条件付き可。重0件、中2件、軽0件、情報3件である。**

新しい15行（`Scope.pathMatches`・`hostMatches`、`String.charactersIn`、Float の6と Float32 の5の分類、`Refinement.check`）は、δ・全 `BuiltinArgs` での型付け・合成表への接続が閉じている。群 F2 の完了条件（392行の表での `NameLists.WF`・`composed_rows`・`completion_core`）と群 C の `included_guarantees` は、既定ビルドの生成物の上で公理 `propext`・`Classical.choice`・`Quot.sound` だけに依存する。String の所属の追加（候補①）は、整形式・閉じた評価・情報順序・置換の保存まで閉じ、既存の対象値の所属の意味を変えていない。`Refinement.check` は `some true` だけを `Ok` とし、型付けは表示器に依存しない。新しい公理・`sorry`・独立の信頼条件・書ける形の制限はない。

条件は中2件の処置である。どちらも J70-9（呼出しの結果型に真偽と述語の一致の篩を付ける）の受け持ちの記録に関わり、本番のコードの誤りではない。取りまとめが plan.md と results.md の申し送りを直せば、コードを変えずに処置できる。中1は、Float の分類を F2 の行の署名で今閉じる選択肢を含む。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 中1 | 中 | results.md 再開3「止めずに進めた変更」の3行目、R の `PredicateResponse.API.signature`、plan.md の 2026-11-06 の F2 再開2の項 | 取りまとめが結果型を素の `Boolean` で仕上げることを認めたのは `pathMatches`・`hostMatches` だけである。担当は Float・Float32 の11行と `charactersIn` にも同じ扱いを広げた。そのうち Float の理由（「公開名の写しとの一致を別に読む」）は障害になっていない。`signatureTel` は結果型をずらさない。`HasTypeTelArgsQ.param` は引数の値を残りの依存列と結果へ代入する。したがって結果型 `Boolean{r \| r = true ⇔ floatClass w c x}` は、今の `PrimSig` で F2 の行に書ける。再開2の反例（範囲の欄は値の置換で変わらない）は、類が関数名で決まる Float には当たらない。一方、plan.md は群 D に `pathMatches`・`hostMatches` の表層の変換だけを割り当てている。Float と `charactersIn` の J70-9 は、どの群も受け持っていない | 次のどちらかを取りまとめが決め、plan.md に記す。(a) Float の11行の署名の結果に一致の篩を置く。δ の応答は `BooleanResult.typed` と `float64_eval`・`float32_eval` で型付く。群 F2 の追加の処置とし、合成表の行の数と構成子は変えない。(b) 群 D の受け持ちに、Float の11行と `charactersIn` を明示して加える。どちらでも、results.md の当該の行の理由を「Float は署名で表せるが、選んだ担当の境界の都合で回した」などの実際の理由に直す | 定義を読めば確定。依存列の形は検査1の2で `rfl` を確認した。署名の変更後の型付けの全称の証明は試していない |
| 中2 | 中 | plan.md の F2 再開2の項の「新しい型付けの規則は要らない」、results.md 再開3「篩の内外の一致と後続の入口」、R の `BooleanResult.typed` | `BooleanResult.typed` は、空の文脈・`Qempty` の閉じた Boolean 値について、閉じた評価で篩を確かめた期待型を与える。実行の後に値を代入した状態で δ の応答を型付けるのには足りる。しかし J70-9 の表層の型付けは、開いた文脈の呼出し（対象が変数）に篩付きの結果型を与える必要がある。核では、組込みの呼出しの結果型は署名の依存列から来る。`pathMatches`・`hostMatches` の範囲は `RangeExpr` の定数であり、値の引数から作れない。範囲を受け取る経路は範囲パラメータの具体化（`Tel.instR`）だけである。`charactersIn` の両端は `Char` の定数であり、範囲パラメータでも渡せない。したがって群 D には、受け口の補題に加えて、次のどちらかが要る。一つは、範囲パラメータを受け取って結果に所属の一致を置く内部の行を合成表に足すことである。もう一つは、述語の範囲・両端に引数を置ける拡張である。今の plan.md の文は、この補題だけで閉じると読める | plan.md の項に、受け口の範囲（閉じた値の応答の型付けまで）と、開いた文脈には上のどちらかが要ることを書き加える。`charactersIn` には範囲パラメータの経路もないことを明記する。群 D の再開の依頼文に、合成表へ行を足す場合は群 F2 と同じ完了条件（`NameLists.WF`・`composed_rows`・`completion_core`）を引き継ぐことを入れる | 規則と署名を読めば確定。開いた文脈で閉じられないことの全称の否定は証明していない |

## 観点ごとの根拠

### 1. String の所属（候補①）

`Pred.Sorted` の `member` は、対象の sort に加えて、`k` が path か host のときに String の sort も受け付ける（`Context.lean`）。`Pred.atomValue` は、項の解釈が String の値なら `stringMember k r s` を返し、そうでなければ従来の対象値の分岐へ進む。`stringMember` は `parseTargetInput` で解析し、絶対形の対象のときだけ `SnapshotMem none k r t` を判定する。解析失敗と相対形・`~` 形は `false` である。`memberReady` の String の分岐は、種類が path・host であること、`r.WF`、`r.FitsKind k`、起点なしでの `resolveSnapshot` の成功を要求する。失敗すれば評価は `none` である。したがって、文字列の解析失敗は「所属しない」、範囲の検査の失敗は評価不能、となる。依頼の二つの扱いと一致する。

- **既存の意味の保存**: 対象値の項は `interpret` が `.string` を返さないので、従来の分岐に入る。`HasTypeVQ.target_member_interpret` はこの場合分けを証明し直しており、言明の型は同じである。`Pred.member_mono` も両方の分岐で証明され、型は同じである。`memberReady` の対象値の分岐は字面が同じである。以前の整形式は String の項を除いていたので、整形式の述語に対する従来の評価は変わらない。
- **解析の同一性**: `TargetText.lean` は `AtInput.lean` から除いた定義の写しである。除いた行と新しいファイルを空行を除いて比べた。差は、`private` を外したこと、名前空間とモジュールの見出し、`parseAtInput` の String の場合を `parseTargetInput` として切り出したことだけであった。At と所属の判定は同じ字句解析を使う。
- **保存**: `Pred.sorted_bind`・`Pred.Sorted.map`・`Pred.Sorted.references` に String の場合を加えた。情報順序（`ObservationOrder`）と値の置換（`ObservationSubstitution`）の `memberReady` の補題は、観測の一致から解釈の一致を返す形に一般化した。元の形の補題は、同じ型の私的な系として残っている。
- **論理の健全性**: `LogicSound` と証明書の検査器は、新しい `atomValue` の上で既定ビルドを通る。所属を導くどの規則も、文字列の解析の意味で健全である。`BuiltinSchema` の `member k t .top` は対象の sort にだけ使い、String に当てていない。
- **`matches_evalClosed`**: 前提は、kind が path・host であることと、リテラルの pattern が絶対範囲 `r` に解析されることだけである。対象 `s` は全称で量化している。結論は `Pred.member k (.string s) (.absolute r)` の閉じた評価が `some (matchString k pattern s)` に等しいことである。`PublicNames.memberPredicate` は絶対範囲だけを述語へ写すので、相対形のリテラルから述語は作られない（J70-10。静的な診断は R60）。
- **DET-L15・U1**: `string_length_not_member` は、バイト長と文字数が等しい `/b` を反例として、長さの二つの事実から所属を導く導出がないことを、論理の健全性から示す。`string_length_certificate_rejected` は、全ての証明書について同じことを示す。これは「長さや連結から所属を導かない」を意味の側で保証する形であり、空疎ではない。U1（所属は保持型と部分型で表す）については、`predicate_no_targets` が判定は保持対象と要求を作らないことを示す。String の篩から保持値や `PathIn` を発行する規則は足していない。

### 2. 15行の δ と型付け

`PredicateResponse.response` は、`API` の全ての値と全ての `BuiltinArgs` について、`ts`・`es`・`rs` が空であることと結果型 `Boolean` を導く。そのうえで、δ の値、型付け、`AdequateResult`、非 exit を返す。前提は署名から取り出しており、空疎な仮定はない。`RefinementCheck.response` も、全ての `BuiltinArgs` について、`Ok` の場合と `CheckError` の場合の両方を型付ける。

証人の対照は両側とも意味を持つ。`composed_inputs` は、合成表の実際の lookup と δ を通して、14行それぞれの真の入力と偽の入力を確かめる。`path_pattern_rejections` は相対形 `a` と `/a/../b` の拒否である。`integer_accept_reject` は非負の期待型への 1 と −1 である。`OptionField.undecided` は、型付きの `Option.None` で評価が `none` になり `CheckError` を返す場合である。四分類の「実質」の判定に同意する。

Float の分類は `ieeeClass` を読む。`finite` は指数部が全て1でないことであり、零と非正規数を含み、NaN と無限を含まない。`isInfinite` は正負の無限の `or` であり、NaN を含まない。正負の零は符号のビットで分ける。NaN の拒否の例（`0x7FF8000000000000`・`0x7FC00000`）も、Float64 と Float32 の NaN のビット列として正しい。signatures.md の J70-11（6類と一対一の名前、`isFinite` は Java などの意味）と U02 の FloatClass の6類に合う。`float64_eval`・`float32_eval`・`characters_eval` は、全てのビット列・全ての文字列で、公開名から写した述語の閉じた評価と δ が一致することを示す。

### 3. `Refinement.check`

- `run` は `t.core = u.core ∧ accepts v u = true` のときだけ `Ok` を返す。`accepts` は外側の全ての篩を見る。自己変数を観測できない値（`toTerm?` が `none`）と評価の `none` は `false` である。`run_refined_rejected` は、`some false` と `none` の両方で `CheckError` を返すことを示す。plan.md の判断と一致する。
- `run_ok` は、δ の水準の等式としては消去（L70.33）の受け口に足りる。ただし前提は値ごとの `accepts v u = true` である。静的な部分型や含意から `accepts` は導けない（情報1）。
- `CheckError` は欄が `expected: String` の一つだけの record（構成子名はデータ名と同じ）であり、合成プログラムの宣言に入った。S11 の欄と合う。Show の実装は R40 の受け持ちである。
- `checkExpectedText` を不透明な本文として R40・R60 へ回したことは妥当である。`RefinementCheck.response` は表示器 `render` について全称で量化しているので、合成表の表示器を後で処理系の書式に替えても、型付けの証明は変わらない。処理系との比較では差が出る（情報2）。
- `checkAdmits` の生の置換・正規化した置換・型パラメータの改名での保存（`CheckAdmissibility`）は、篩を `predBind (upValues θ.values)` で運ぶ形で示した。`admits_form(With)` の第三の場合 `row = p392` の追加は、既存の行で元の二択に戻る。

### 4. 合成表と完了条件

392行の表で、`StandardModel.nameLists_wf`・`composed_rows`・`completion_core`・`included_guarantees` の公理を、既定ビルドの生成物から単独で確かめた（検査2）。生成物はどの `.lean` よりも新しい。新しい名前は仮定側の一覧と交わらない。仮定側の件数（δ 80・IO 47・状態16・外7・資源4）は変わらず、新しい15行は全て純粋である。`composedEffect_member` は、効果の一覧の `decide` が再帰の上限に達した箇所を、行の所属からラベルの所属を得る証明に替えた。上限は増やしていない。

`RowEnv.check` は新しい信頼条件ではない。`RowEnv.ofAgree` の型は前と同じであり（検査2の `#check`）、新しい欄は `Includes` の `extends_` と `check_declarations` から内部で供給される。`RowEnv.base` も同じ宣言を合成プログラムから得る。

型の差の表は、`type_diff.py` の範囲（`StandardModelSignatures` の生成宣言と `RowEnv`）では機械的な比較である。範囲外の変更したモジュールについて、宣言の頭の差を抜き出して読んだ。言明の型が変わったのは手書きの `admits_formWith`・`admits_form` の二つだけであった。そのほかの差は、定義の値（`Pred.Sorted`・`atomValue`・`memberReady`・`scopePure`）、新しい宣言、証明の本体である。表は全てを覆う。

### 5. 群 D へ渡す `BooleanResult.typed`

言明は、空の文脈で、期待型の基が `Boolean` であり外側の全ての篩が閉じた評価で真になる Boolean の定数に、その期待型を与える。具体の適用（`self = true` の篩）と、偽の値での `accepts` の拒否がある。実行時の応答の型付けの部品としては正しい。開いた文脈の静的な型付けには足りない（中2）。Float には、署名の依存列で閉じる経路がある（中1）。

### 6. 守ること

- 01-12 の写しは、所属の整形式（String の sort）、閉じた評価の解析失敗の偽と範囲の検査の失敗の `none`、合成表の392行・純粋376行、新しいモジュールの性質を、実物どおりに書いている。07-04 のモジュールの表と件数も一致する。古い件数（377・361）は両文書と合成表のモジュールに残っていない。段名・工程の ID・経緯の文はない。
- 新しい10モジュールは根の `Benitoite.lean` から import される。新しいモジュールに `sorry`・`axiom`・`set_option maxHeartbeats`・`maxRecDepth`・`#eval` はない。
- 公開の新しい宣言には、同じモジュールか後のモジュールの読者か、具体の適用がある。`composed_inputs`・`path_pattern_rejections`・`string_path_cases`・`concatenation_member_contrast` は、それ自体が証人の具体的な言明である。
- 記録は `results.md` が 86,818 バイト、`l70/f2/` の全体が約165 KB であり、上限の内にある。

### 情報

- **情報1（群 E へ）**: 型付きの値でも `accepts` が偽になることがある。検査1の1で、`Option.None` に対する `Option.Some` の第0欄が0という述語は、二値の解釈 `interpret` では真であり、閉じた評価は `none` である（`OptionField.undecided`）。`V_Refine` は含意（`Entails`）だけを要求するので、「`v` が静的に `U` を持つ」ことから `accepts v U = true` は一般には出ない。消去の規則は、部分型や含意でなく、消去する呼出しの値について閉じた評価が `some true` であることの証拠を前提にする必要がある。plan.md の「静的に some true を示した場合だけ」の具体的な形として、群 E の依頼文に写すとよい。
- **情報2（R40・R60・形式化と処理系の比較へ）**: 合成表の `checkExpectedText` は定数 `"expected refinement"` である。処理系は期待型を診断の書式で表示する（S11 の E1）。Rust と Lean の実行を比べる照合では、`CheckError.expected` の欄を比較から外すか、表示器を表の引数にする必要がある。
- **情報3（R50 へ）**: `CheckError` の宣言を `byteOrder` と `roundingMode` の間に入れたので、`StandardModel.constructorNames` の中で、`RoundingMode` と At の公開の宣言の構成子の位置が後ろへずれた。既存の構成子どうしの相対の順序は保たれ、同じ型の鍵の比較には影響しない。L60 で R50 へ回した鍵の順序の照合は、この新しい並びで行う。

## 実行した検査

| 検査 | 内容 | 結果 |
|---|---|---|
| 検査1 | `<tmp>/Probe.lean` を単独で検査。(1) `OptionField.predicate` を `Option.None` で開いた述語の `interpret` が `true` であること。(2) Float.isFinite の結果に一致の篩を置いた試しの署名 `depSig` について、`depSig.tel = .param "x" (.base .float) (.done depRet Eff.empty)` が `rfl` であること。(3) `matches_evalClosed`・`PredicateResponse.response`・`RefinementCheck.response`・`run_ok`・`BooleanResult.typed`・`string_length_certificate_rejected`・`nameLists_wf`・`Pred.member_mono`・`OptionField.undecided` の `#print axioms` | (1)(2) は成立。(3) は全て `propext`・`Classical.choice`・`Quot.sound` の部分集合。このファイルが import しないモジュールの `completion_core`・`composed_rows` の名前を引いた2行だけが未知の名前の誤りになり、終了1。検査2で補った |
| 検査2 | `<tmp>/Probe2.lean`（`StandardModelApplicationExamples` を import）を単独で検査。`completion_core`・`composed_rows`・`included_guarantees` の `#print axioms` と `RowEnv.ofAgree` の `#check` | 終了0。三つとも上の三公理だけ。`ofAgree` の型に `check` の宣言の前提はない |
| 検査3 | `AtInput.lean` から除いた行と `TargetText.lean` の比較（空行を除いた diff） | `private` の除去・見出し・`parseTargetInput` の切り出しだけの差 |
| 検査4 | 変更した合成表と観測のモジュールの、証明でない削除行と宣言の頭の差の抽出 | 言明の型の変化は `admits_formWith`・`admits_form` だけ |
| 検査5 | `formal/` の `.lean` のうち、`StandardModelApplicationExamples.olean`（19:21:40）より新しいものの探索 | 0件 |
| 検査6 | 新しい公開の宣言の読者の `grep` と、新モジュールの `sorry`・`axiom`・`set_option`・`#eval` の `grep`、設計書の古い件数の `grep` | 読者のない補助の宣言なし。禁止の要素なし。古い件数なし |

Lean は同時に一つだけ実行し、各回 `-M 12288` を付けた。具体値の大きな評価は行っていない。生の出力は `<tmp>/probe.out` に置き、改造には写していない。

## 取りまとめの追記

2026-11-06。群 F2 は Codex が実装し、独立レビューは Claude（Opus 5.5）が行った。中1・中2 は、コードを変えずに取りまとめの記録で処置した（plan.md の「RV-L70.f2」の項）。14の判定の関数の J70-9 は群 D の J70-9 の作業が受け持ち、開いた文脈の呼出しの経路（範囲パラメータを受ける内部の行か、述語の拡張）もその作業で選ぶ。情報1〜3 は群 E の L70.33・R40・R60・R50 への申し送りとした。work の検査は、群 E までの san_benito を取り込んだ状態で取りまとめが行う（`C/l70/f2/results.md`）。
