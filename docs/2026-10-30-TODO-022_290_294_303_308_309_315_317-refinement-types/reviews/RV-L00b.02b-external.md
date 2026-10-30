# RV-L00b.02b-external: 外部と依存する実引数列の群（L00b.02b-external）の群末の独立レビュー

2026-10-31。レビュー担当は Opus 5.5 のサブエージェントである。対象はブランチ m014/l00b.02b-external の未コミットの作業ツリーにある `formal/` の本番の変更である。B_WORK `9184a3ce` からの差分は、既存20ファイルの変更と、新規4ファイル（External・ExternalResponse・Ground・TelTyping）から成る。

照合した入力は次のとおりである。

- [レビュー依頼](RV-L00b.02b-external-request.md)
- `l00b.02/signatures.md` の第7.2節（外部の入口の署名と三欄）・第12.2節の `.02b-external` の行・第24節・第25節
- `l00b.02/results.md` の `.02b-external` の節、`l00b.02/02b-external-boundary.lean`
- plan.md の「計画の変更と取りまとめへの確認点」の 2026-10-31 の行（外部呼出しは事象を出さず exit を除く判断を含む）と、外部の範囲の行
- decisions.md の D18・D28・D67・D71、study の refinement-full.md の構築経路の表の外部の関数の行
- 改造の README の設計者の決定
- 現行の設計書 03-10「外部の関数」の「宣言の形」「照合」「型の対応」
- 処理系の `crates/benitoite/src/typeck/external.rs`
- 旧の `formal/Benitoite/Release/Semantics.lean`（68遷移の比較のため）
- 前回の [RV-L00b.02b-values](RV-L00b.02b-values.md)（書式と申し送り）

Lean は局所に二つの補助ファイルで実行した。補助のファイルはリポジトリの外に置いた。

1. `cd formal && lake env lean -M 12288 <tmp>/rv02be/counts.lean`（終了0）。Lean の metadata から構成子の数を数え、旧と新の Step の構成子の名前の列を比べた。
2. `cd formal && lake env lean -M 12288 <tmp>/rv02be/stateful.lean`（終了0、約0.5秒、最大常駐約0.75 GB、誤り0件）。次の三つを証明した。公理の依存は propext・Classical.choice・Quot.sound だけである。
   - `uses State` を持つ署名 `get(c: Cell) -> Integer uses State`（uses は引数0の borrow 一件）が `ExternalSignature.WF` を満たすこと。
   - その署名でハンドルを実引数に渡す `externalCall` が `C_External` で型付くこと。
   - 自分自身を欄に持つ data（`Nil | Cons(L)`）が、どの component と unit の指定でも `ExternalValueType` を持たないこと。

既定の `lake build` は担当の結果（640 jobs、終了0）を引用し、繰り返していない。この記録のほかにリポジトリのファイルを書き換えていない。

## 総評

**条件付き可。** 外部の5導出・三欄・3遷移は、以前の判断と第7.2節の署名に合っている。外部呼出しは事象を出さない。exit は external_typed の結論で除かれ、step も exit を遷移させない。Event は2形のままであり、effect_soundness の結論に触れる変更はない。三欄は `CoreAssumptions` の欄であり、公理でも第四の仮定でもない。既定の `externalResponse` と空の外部表の下で三欄は自明に成り立つ。外部表を持つ場合も、常に err を返す表で満たせるので、正常応答の存在を前提へ入れていない。ゲストの状態・所有権のヒープは導入していない。

受渡し型（ExternalValueType）は、03-10 と処理系が受け付ける型より狭くない。基本型13種・Bytes・List・Map・flags・data・外部型・戻り値の Unit をすべて表せる。再帰する data を拒むことは 03-10 の E1010（注記 `recursive`）と一致し、有限の同名の入れ子は受け付ける。状態を持つ署名の非空性も Lean で確かめた。型付けの規則に増えた前提は、どれも型付けできるプログラムを狭めない。場合の数の主張はコードと一致し、旧68遷移の名前と順序も保たれている。抜け道の語はない。

ただし、読めば確定する中の所見が一つある。

- 中1: 補助判断が篩を外部の境界の型として受け付けるため、external_typed は「ゲストが返す値が篩を満たす」ことを信頼条件に含む。受信後の所属の検査を処理系とモデルの義務として記していない。

受け入れの条件は、中1の義務を signatures.md の第24節（または第25節）の義務の対応表に一行で固定することである。担当は L60（三モデルの充足）と R50・L70（表層・交換の照合）である。軽の所見は、取りまとめの判断で後続の群に回してよい。

## 依頼の観点ごとの判定

| 観点 | 判定 | 根拠と補足 |
|---|---|---|
| 1. 宣言表と名目性 | 可 | `Program.externals` は有限列であり、`ExternalWF.unique` で key の重複を、`keys` で key と宣言内の ID の一致・型の arity 0・関数の `ExternalSignature.WF` を検査する。`Ty.Declared` の external は lookup・宣言内 ID・arity と全型引数を検査する（Declared.lean 69行）。rawSubstV・norm の保存も ID と型列の長さを保って閉じている。ExternalKey は型と関数の直和なので、同じ Nat でも型 ID と関数 ID は別の key になる。境界入力の `same_display_distinct_ids`・`nominality_under_bind` が表示名と ID の区別を示す |
| 2. borrow/own と効果 | 可 | ExternalOccurrence は List の element、Map の key/value、具体化した data の構成子と欄の位置、篩を辿る。ExternalUseAt は引数を borrow、結果を own に固定する。uses_exact と uses_unique が過不足と重複を除く。効果は uses が空なら empty、そうでなければ State だけである。これは typeck/external.rs が `STATE`・`RangeIndex::TOP` の一つだけを要求し、外部型がなければ uses を拒む実装と一致する。外部型の出現は実際の欄の具体化から数えるので、未使用の型引数だけでは State を要求しない（03-10「型の対応」の再帰の段落と一致）。通常の資源や IO への自動の追加はない |
| 3. 受渡し型と提供範囲 | **条件付き（中1・軽1）** | 下の「受渡し型と処理系の比較」 |
| 4. 許容と葉の正則性 | 可（軽2を参照） | 下の「型付けの規則へ足した前提の判定」 |
| 5. TelArgs と相互証明 | 可 | 下の「逐次具体化の交換」 |
| 6. 閉性と三つの信頼条件 | 可（中1を参照） | Val.Ground は Ty.WF・Eff.WF の第一引数を0とし、範囲の変数も検査する。束縛の数は、ラムダの引数、builderLet の None、腕の束縛、節の `arity+1`・`2`（fail）、閉包の捕捉と入力で、Subst.lean の rename と一致する。境界入力の `open_annotation_not_ground` は、var がなくても開いた型注釈の値を Ground にしないことを示す。ExternalArgs は空の C/Γ/Φ の型付きの実引数・Ground・閉じた型引数/結果/行を持ち、正常応答の存在を含めない。`CoreAssumptions` は ValueAssumptions と三欄を `extends` するだけである |
| 7. 意味論と実行 | 可（軽3を参照） | E_ExternalApply・E_External・E_ExternalErr はすべてラベル none である。E_External と E_ExternalErr は `P.externalFunction f = some decl` を要求する。step は Closure.view を経て、型引数と実引数を捕捉環境で閉じてから ExternalOracle を呼ぶ。`.exit` には none を返す。Event は io と release の2形のままである。エラーは `.error [r] k μ` で、既存の無事象の失敗の遷移と同じ形である |
| 8. 既存の境界と申し送り | 可 | 障害例の二ファイルの差分は、新しい構成子の不可能な場合の追加だけである（NarrowingObstruction 1行、SubstTypingObstruction 2行）。言明は変わっていない。第24節の7行は担当を変えずに残されており、results.md も external で完了と数えていない |
| 抜け道 | 可 | 新規4ファイルと差分の追加行に、`sorry`・`axiom`・`admit`・`native_decide`・`implemented_by`・`unsafe`・`partial`・`extern` の語はない（語の境界で grep した） |

### 受渡し型と処理系の比較

03-10「型の対応」の表と、補助判断の `ExternalValueType` の9構成子を比べる。

| 03-10 で受け付ける型 | 補助判断での表現 | 判定 |
|---|---|---|
| 各幅の整数・Byte・浮動小数・Boolean・Character・String | `scalar`（`ExternalScalar` の13種。BaseTy から unit と decimal だけを除く） | 一致 |
| Bytes・List[T]・List[Byte] | `bytes`・`list`（要素は unit=false） | 一致 |
| Option・Result・Pair・Triple・レコード・data・一構成子の data | `data`（全構成子の有限な一覧と、具体化した全欄の導出） | 一致。Formal の Ty は record を持たず、レコードも data である |
| Set[D]（引数なしの構成子1〜32個） | `flags` | 一致 |
| Map[K, V]（鍵は Boolean・各幅の整数・Character・String） | `map` と `ExternalMapKey`（浮動小数を除く scalar） | 一致。Decimal・Bytes・Unit・data の鍵は両方で拒む |
| 外部の型（引数は borrow、戻り値は own、同じ component） | `handle`（ID・component・arity 0・空の型引数） | 一致 |
| 戻り値の Unit | `unit`（unit=true の位置だけ） | 一致 |
| 再帰する宣言（E1010 `recursive`）・`Nest[List[T]]` | 有限の導出がないので拒む（Lean で確かめた） | 一致。宣言の数は有限なので、無限の展開は宣言の循環を必ず通る。逆に、処理系が受け付ける循環のない型は有限に展開できる |

補助判断の方が広い点は三つある。data の欄の Unit（`Option[Unit]`・`Pair[Unit, X]`・利用者の `C(Unit)`。03-10 はこれらを拒む）、展開の予算の上限がないこと、篩（`refined`）である。前の二つは signatures 第25.1節が上限として明記しており、健全性を損なわない。三つ目は中1で扱う。狭い点は見当たらない。

### 型付けの規則へ足した前提の判定

| 規則 | 前提 | 書ける形への影響 |
|---|---|---|
| V_ExternalRef | `d.WF P`、`ExternalCallAdmissible`、`SignatureInstance P C Γ d.parameters d.kinds ts []` | 宣言表の性質は `.03` で Program.WellTyped から供給する。外部宣言は単相なので ts は空であり、SignatureInstance の types・kinds・rows は自明である。result は閉じた Tel の Annotation を Γ で求める。表層の宣言検査が通した型だけが現れるので、狭めない。結果は V_Fun と同じく dependentFn であり、呼出しは `.02b-closures` の C_DependentApp を待つ（軽3） |
| V_ExternalHandle | lookup・component・resource・arity の一致と Annotation | ハンドルは処理系が作る実行時の値であり、利用者は書かない。arity 0 と空の型引数の下で Annotation は自明に成り立つ（境界入力の `handle_typed`） |
| C_External | `d.WF P`、`ExternalCallAdmissible`、`HasTypeTelArgsQ … (Tel.bind (typeEnv ts) d.parameters)` | 第7.2節の署名と一致する。TelArgs の param は各引数の型の Annotation を要求する。C_Meth は結果の Annotation だけを要求していたので、前提が一つ多い。ただし、宣言の型は閉じている。先行する実引数を代入した後の型の Sorted・Declared も、その実引数の型付けから得られる。脱糖が満たせる条件であり、狭めない。状態付きの呼出しを Lean で導出した |
| HasTypeTelArgsQ.done | 結果の Tel の Annotation | 正規形の結果と効果を取り出すためのものである。State の効果 `EffR.mk (State の判定) []` は正規形なので、uses を持つ署名でも満たせる（Lean で確かめた） |

### 逐次具体化の交換

- `Tel.open_shift t v k c` は t・v・k・c について全称であり、前提がない。param の後続を cutoff `c+1` で移し、実引数を cutoff `c` で改名する。TelArgs の各引数は同じ Γ で読むので、二つ目以降の実引数の改名の cutoff も `c` のままでよい。`HasTypeTelArgsQ.shift_values` の再帰がその形をしている。
- `Tel.open_subst t v ν ρ` も全称で前提がない。`valEnv (upSubst 1 ν)` と `(valEnv ν).up` の一致と、第23節の `bind_open_exchange` から導く。根とスロットの none を保つ。
- `Tel.instantiate_subst` は Option の観測の像のまま交換を述べ、none の場合も含む。`Tel.instantiate_shift` は `some` を前提とするが、元の `arguments_shift` と同じ形である。言明を空にする前提ではない。
- subst・subst_under_none・narrow・hide_context の各入口は、R のない形で公開されている。後送はない。

### 場合の数の照合

Lean の metadata で次を数えた。HasTypeVQ 20・HasTypeCQ 13・HasTypeVsQ 2・HasTypeEachQ 2・HasTypeTelArgsQ 2 で、合計39である。Val は21、Comp は14、新しい Step は71、旧の Step は68、Event は2、ExternalValueType は9である。新しい Step から E_External で始まる三つ（6〜8番目）を除いた名前の列は、旧の68の列と一致した。三族は相互の match で全構成子を扱っており、網羅性は Lean が検査している。TypedFacts の observation と assume は各20、補助の assume_optional と data_observation は各20である。observation_declared と observation_references は Vs と Each を含めて各24、補助の合計は88になる。いずれも主張と一致する。

## 新しい所見

### 重

なし。

### 中

#### 中1. 篩付きの外部の型を受け付けるので、external_typed がゲストの返す値の篩の所属まで信頼する。受信後の所属の検査を義務として記していない（読めば確定する）

- 場所: External.lean 46行の `ExternalValueType.refined`、21〜24行の `ExternalMapKey` の refined の場合。ExternalResponse.lean 24〜26行の `Outcome.Typed`、30〜32行の `external_typed`。境界入力の `refined_map_key_accepted`。
- 問題: 補助判断は、引数・結果・Map の鍵・data の欄に篩付きの型を受け付ける。external_typed の結論は、応答の値が具体化した結果型で型付くことである。結果型が `{r: Integer | r > 0}` なら、ゲストが正の値を返すことまで信頼条件に含まれる。Map の鍵の篩も、受け取る Map の全ての鍵について同じである。一方、現行の 03-10「型の対応」の表は篩付きの型を持たず、表にない型を誤りとする。study の refinement-full.md の構築経路の表の外部の関数の行は「篩へのABI対応を追加するなら、受信後の所属検査を必須にする」としている。signatures 第25.1節は Unit と ABI の細部を表層・交換へ残すと書くが、篩の所属の検査には触れていない。results.md の残りの表にも、この行はない。
- 影響: 今の定理は偽にならない。三欄は仮定だからである。また、常に err を返す表で満たせるので、矛盾も生じない。ただし、三モデル（L60）が「型付きの値だけを返す応答」を抽象的に置くと、ゲストが篩に反する値を返す場合を信頼の中へ黙って含めることになる。D18 は、未検査の外部の前提を登録しないとしている。このままでは、ゲストが返す値を検査なしに信頼する形になり、保証の範囲が設計の意図より広く読める。
- 修正案: 義務の対応表に次の一行を加える。「外部の境界に篩付きの型を許す場合、処理系は受信した値（結果、Map の鍵、data の欄の全入れ子）の篩の所属を検査し、違反を実行時エラー（err）にする。L60 の三モデルの `externalResponse` は、その検査の後の関係として定める。表層が篩付きの外部宣言を拒む場合は、R50・L70 でその拒否と補助判断の上限の関係を照合する」。どちらを採るか（表層で拒むか、受信後に検査するか）は提供範囲の判断なので、取りまとめが設計者に確かめる。引数側の篩は呼出し側の型検査が保証するので、この義務に含めなくてよい。

### 軽

#### 軽1. 補助判断の上限が処理系より広いことを、L70 の照合の向きとして記していない

- 場所: External.lean 41〜45行（data の欄を unit=true で検査）、signatures 第25.1節。
- 問題: 補助判断は `Option[Unit]`・`Pair[Unit, X]`・`C(Unit)` を受け付け、展開の予算（深さ100・節点数100,000）も持たない。第25.1節はこれを利用者の書ける形の拡張と扱わないと明記しており、健全性も損なわない。ただし、L70 の表層との照合で要るのは「処理系が受け付ける宣言は ExternalSignature.WF を満たす」という向きだけである。逆の向きは成り立たない。どちらの向きを証明するかが文書にない。
- 修正案: 第25.1節に「L70 は処理系の受理から WF への向きだけを示す。逆向きは主張しない」と一文を足す。

#### 軽2. `ExternalCallAdmissible.types` は空の Γ で型引数の注釈を検査する。SignatureInstance は呼出し側の Γ を使う

- 場所: External.lean 129行、Admissible.lean 115行。
- 問題: 現在は単相なので ts は空であり、`ExternalCallAdmissible.map` も `types_nil` に頼って閉じている。将来、多相の外部宣言を加えると、外側の値に依存する型引数をこの欄が拒む。第25.4節の「一般の型引数の外側の値依存を除かない」という方針と、形の上で食い違う。今は影響がない。
- 修正案: 多相の外部宣言を加えるときに `TypeAnnotations P C Γ ts` へ改める、と第25.2節に注記する。今回は本番を直す必要はない。

#### 軽3. E_ExternalApply の保存には、C_DependentApp の前提から HasTypeTelArgsQ を作る道筋が要る

- 場所: Typing.lean 205行の C_App（`.fn` を要求する）、119〜122行の V_ExternalRef（結果は dependentFn）、Semantics.lean 68〜70行の E_ExternalApply。
- 問題: `.app (.externalRef f ts) ws` は、今は型付けできない。Ty.LeQ は dependentFn から fn への規則を持たないからである。`.02b-closures` の C_DependentApp で型付く。遷移の後の `.externalCall` は C_External、つまり HasTypeTelArgsQ で型付ける。C_DependentApp が C_Meth と同じく `Tel.arguments` と HasTypeVsQ の形を使うと、保存の証明に逆向きの補題（Vs と arguments から TelArgs）が要る。その補題は、各引数の型の Annotation を得るために文脈の正則性を必要とする。今回の `HasTypeTelArgsQ.arguments` は、TelArgs から Vs への向きだけを与える。
- 修正案: `.02b-closures` の行に「C_DependentApp の実引数は HasTypeTelArgsQ で検査する。そうしない場合は Vs と arguments から TelArgs を作る補題を同じ群で置く」と記す。L20 の E_ExternalApply の保存の義務も同じ行で示す。

#### 軽4. 境界入力に、uses を持つ署名と、実引数を持つ外部呼出しの正の例がない

- 場所: `l00b.02/02b-external-boundary.lean`（WF を示した署名は、実引数0個・効果 empty の `pureSig` だけである）。
- 問題: uses_exact の逆向き、State の効果の正規形、ハンドルの実引数の TelArgs は、どの正の例でも通っていない。本レビューで Lean により成り立つことを確かめた（`<tmp>/rv02be/stateful.lean` の `get_wf`・`get_call_typed`）ので、本番の誤りではない。ただし、後の変更で State の効果が正規形でなくなると、uses を持つ全ての署名が WF を満たさなくなる。その退行を今の境界入力は捕まえられない。
- 修正案: 次の群か `.03` の境界入力に、`get(c: Cell) -> Integer uses State` の WF と型付きの呼出しを加える。再帰する data の拒否の例（`recursive_rejected`）も合わせて加えるとよい。
