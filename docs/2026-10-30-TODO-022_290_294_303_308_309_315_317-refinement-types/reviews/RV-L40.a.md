# RV-L40.a: L40 群 A・F1（L40.01〜.05、L40.30〜.32）の独立レビュー

2026-11-03。対象はブランチ `m014/l40.a` の未コミットの作業木、基準 `2a245382`（san_benito の先端）。新規の Lean 6本（TelApplication・StandardKeyTyping・StandardContracts・StandardScalar・StandardBodies・IntervalFailure）は全文を読んだ。既存の変更（`formal/Benitoite.lean`・01-12・07-04・effort-ledger）は `git diff` で読んだ。群の記録は `l40/a/` の results.md・signatures.md・obligations.md・keys/・signature-check.lean・signature-extra.lean・axioms.lean・audit.py・records.py・verify_records.py と各 json を読んだ。担当の報告と依頼文も読んだ。

根拠として `l40/detail.md` の第1〜4節（F01〜F07 と「短い試行の状態」）、第5節の L40.01〜.05・.30〜.32 の行と群、第6〜10節、plan.md の 2026-11-03 の L40 の二項（J40-3・J40-4、詳細の確定）と「義務の対応表」、README「設計者の決定」、`reviews/RV-L40-plan.md` を読んだ。形は `RV-L30.l.md` に合わせた。補助の入力と再実行の出力は `<tmp>/rv-l40-a/` に置き、既存のファイルを変えていない。

## 総合判定

**F1（L40.30〜.32）は可。群 A（L40.01〜.05）は要修正**（重1・中2・軽6、情報2）。重1を処置するまで、群 B を起動しない。中2件は群 B（中1）と U02 の見直し（中2）の前に処置する。

H04 の第一候補 `tracked_failure_sound` は、detail F07 と `l20/n/h04-handoff.lean` の型のまま証明されている。前提は Models・`EvalPartial … (.failed reason) trace`・`TrackedFailure reason trace` の三つで、結論は実際の `BudgetAnalysis.analyze` の `mayFail = true` である。limits・state・fuel・RangeState の条件は公開入口に足していない。内部の RangeState.Models は `ranges_reset_models` と `models_resetRanges` が実入口で供給する。独立評価の7判断の構成子は本番の `Interval/Eval.lean` で数え直し、69・4・4・6・6・6・14 の計109と、別母集団の EvalStandard 7 を確認した。`Interval/` の定義（Success・SuccessAt・NormalSoundness・WarningSoundness）は差分がない。

公理監査は再実行で一致した。出力先だけを `<tmp>` に変えて `axioms.lean` を実行し、終了0、外側37.93秒だった。694モジュール・68,367宣言で、生出力と対象名の一覧の SHA-256 は記録の `e30ea58a…`・`096bcd99…` と一致した。依存集合は許可三公理の部分集合だけで、`sorryAx`・`ofReduceBool` は0件だった。新6モジュールの件数（19・68・179・72・8・114）と、private・生成宣言（`expr_failure._mutual`・`table._proof_1` など）が対象に含まれることも確かめた。鍵の5代表の Rust 照合も、同じ rlib（SHA-256 `557cb03d…`）で一時領域に作り直して実行し、生出力2,142バイト・SHA-256 `d5fee19c…` が記録と一致した。

重1は署名の誤りである。F01・F03 の値の逆転の一部は「元の型から T への `Ty.LeQ`」を返す形で固定されたが、`V_Refine` を経た導出ではこの形が偽になる。V_Const の枝について補助入力で反例を証明した。中1は F02 の公開署名に `Ctx.WF` が要るかどうかの未確認、中2は J40-3 の内部契約を言語の依存型の署名で書いていないことである。

## 群 A の所見

### 重

#### 重1: 値の逆転の「元の型からの `Ty.LeQ … T`」の形は `V_Refine` で偽になる。inv_var の固定署名は群 B で証明できない（V_Const は Lean で反例を確認、他は読めば確定）

- 場所: `l40/a/signatures.md`「F01：元規則の直接前提」の表の inv_var の行（16行）と22行、「逆転の各枝の完全な命題」（930行以降）、`l40/a/signature-check.lean` の V_Var・V_Const・V_AtError・V_Con・V_List・V_Checked・V_CheckedRequest・V_CheckedAt の各枝。`Typing.lean` の `V_Refine`（248〜252行）。detail 第2節「値、計算、状態の開始逆転」の var の行。
- 問題点: `V_Refine` は、値の項 t について `Entails (Γ.facts ++ Φ) (p.open t)` を示せば `v : .refined a p` を与える。一方 `Ty.LeQ P Γ Φ a (.refined a p)` は、a の自己の事実と移した `Γ.facts ++ Φ` から p を導く必要があり、値に固有の事実を使えない。したがって `V_Refine` を通った導出から `Ty.LeQ (元の型) T` は一般に出ない。
  - 補助入力 `ConstBranch.lean` で、`∀ …, HasTypeVQ … (.const c) T → ConstOK B c ∧ Ty.LeQ P Γ Φ (Const.type c) T`（signature-check.lean の V_Const の枝そのもの）の否定を証明した。既存の `month_typed`（5 : `{Integer | 1 ≤ x ≤ 12}`）にこの命題を適用すると `Integer ≤ monthType` が得られ、0 の `subtype_facts` と `Entails.sound` から `1 ≤ 0` が真になって矛盾する。終了0、許可三公理だけに依存する。
  - var は `toTerm? = some (.var i)` を持つので同じ構造で偽になる（経路条件 Φ に `1 ≤ x` がある場合など）。detail の var の行は「coreの対応。篩の事実はfacts」であり、signatures.md の inv_var の `Ty.LeQ P Γ Φ a T` は detail から外れている。atError（`toTerm?` は dataValue）・con・list・checked 系も項を持つので、signature-check.lean の LeQ の形は同様に偽になりうる。
  - signatures.md 22行は「inv_const/con/list/checked/checkedRequest は既存の署名を引用する」と書く。既存の inv_const は `T.norm.core = c.type.norm.core` であり、同じ文書の「逆転の各枝の完全な命題」の V_Const（LeQ の形）と食い違う。型検査（signature-check の終了0）はこの偽を検出できない。
- 修正案: 項を持ち篩を導入できる値（var・const・con・list・atError・checked・checkedRequest・checkedAt）の逆転の結論を、`V_Refine` を通る形に改めて固定し直す。候補は既存の inv_const の型の芯の等号に倣い、`∃ a, …直接前提… ∧ T.norm.core = <元の型>.norm.core`（List・data は要素・型引数の `TypeArgsLe` 又は LeQ を芯の上で返す）と、篩の事実を既存の `HasTypeVQ.facts` で別に読む形である。署名を改めるなら、群 B の起動の前に、var と list について新しい形の証明か反例の有無を補助入力で確かめる。「逆転の各枝の完全な命題」の節は、引用する既存の署名と新しく証明する署名を一つの表に揃え、偽の枝の命題を残さない。関数の八構文（`fnCore` と `TelClosure`）と loc・pathBases・scopePattern・externalHandle（`toTerm?` が none で `V_Refine` を通らない）の形はこの所見の対象外である。

### 中

#### 中1: F02 の公開署名は `Ctx.WF 0 C.length Γ` なしで証明できるかが確かめられていない（実行しないと分からない）

- 場所: `signatures.md`「F02」（26〜37行）、`TelApplication.lean` の `TelLe.open_done`（20〜43行）、`Typing.lean` の `HasTypeTelArgsQ`（370〜377行）、`DependentBeta.lean` の `HasTypeTelArgsQ.one`、`Transport.lean` の `TelLe.bind`（341行）。
- 問題点: 代表の `open_done` は、同じ実値で後続を開く `SubstOk.openValue` の Transport のために `Ctx.WF 0 C.length Γ` を前提にする。一般の `TelClosure.apply` も、二引数目以降で後続の `TelLe` を `TelLe.bind` で開くため、同じ Transport を各段で作る必要がある。`HasTypeTelArgsQ` の構成子は `Ctx.WF` を持たず、`Ty.Annotation` も文脈の事実の形成を含まない。公開署名の前提（WellFormed・CoreAssumptions・Ψ.WF・両 Annotation・TelClosure・args）から `Ctx.WF` を導く道は記録にない。results.md は「供給できない場合は停止する」と書くが、L40.02 の完了の判定（新しい前提なしで完全署名を固定）はこの点を確かめて初めて満たす。L40.11 で判明すると、群 B の中で署名変更の手順に戻ることになる。
- 修正案: 群 B の起動の前に、二引数の代表（後続が一つ目の引数に依存する `param x a (param y (b x) (done r e))`）で、`Ctx.WF` なしに `TelLe.bind` の Transport を作れるかを補助入力で確かめる。作れなければ、F02 の署名に `(hΓ : Ctx.WF 0 C.length Γ)` を加える変更を取りまとめに諮る。閉じた Γ では自明に成り立ち、開いた Γ では開始の導出の不変条件から供給できるかを、その判断の材料として添える。

#### 中2: J40-3 の内部契約が、言語の依存型の署名として書かれておらず、二つの記録で表が食い違う（読めば確定）

- 場所: `results.md`「L40.05末の安全な入口の内部契約」の表、`signatures.md`「安全な入口の内部の契約（J40-3）」の表、`StandardBodies.lean`。plan の 2026-11-03 の J40-3 の項。
- 問題点: plan は「どの証拠を受け、何を返すか」を確定して設計者に示すとする。現在の表は「同じxs:List Tの型付けと0<length xs」のような文章であり、証拠を引数の篩として受けるのか、`NonEmptyList[T]` のような別名の型として受けるのかが署名の形で決まっていない。StandardBodies の3定理は、型付きの値の有限列についての Lean の補題であり、`StandardContracts.Row` の `tel` の形の契約ではない。群 E（L40.26）が core 署名を書くときと、設計者が U02 で公開の形を選ぶときに、同じ材料から異なる署名が読める。記録の間でも次が食い違う。
  - CheckedLength の射影の結論: results.md は「length=元Listの長さ・minimum≤length≤maximum」、signatures.md は「同じ各欄の値」だけである。
  - 同長の別 List: results.md は ys の型付けを受け、signatures.md は受けない。Lean の `safeGet_equalLength` は CheckedIndex でなく二つの列と Nat の添字を受ける。
  - safeHead の証拠: 表は `0<length xs`、Lean は `xs ≠ []` である。safeTail・CheckedIndex.get・NonEmptyList は文章だけで、Lean の署名がない。
- 修正案: 各内部の入口を `[core]` の API 一覧と同じ書き方の依存型の署名で一行ずつ書く。例は `safeGet[T](xs: List[T], i: Integer where 0 <= i && i < List.length(xs)) -> T` である（字面は U02 の未決のまま、内部の形として示す）。結果の型が元の列との関係（`xs[i] = result` など）を型で持つか、Lean の補題だけで持つかを明記する。二つの記録の表を一つに揃え、Lean の3定理が支える部分と群 C/E が証明する部分を同じ表の欄で分ける。

### 軽

#### 軽1: 鍵の照合の表で「具体Table/B.sat」と「現行Release.satB」を別の列にしているが、代表の表では同じ計算である（読めば確定）

- 場所: `results.md`「L40.03」の表、`StandardKeyTyping.lean` の `Representatives.builtins`（122行）と `table`（127行の `Iff.rfl`）。
- 問題点: 代表の `builtins.sat` は `satB summaries C (carrier a) p = true` そのものとして定義されており、`sat_eq` は `Iff.rfl` である。二つの列は独立の照合ではなく、独立の照合は Lean の `satB` と Rust の二つの判定だけである。
- 修正案: 表の注に「代表の表では B.sat を satB で定義したので二列は同じ計算」と書く。一般の Table は `sat_eq` を入力として受けるので、宣言の収集から B.sat を作る L70/R10b の接続で初めて独立になることも添える。

#### 軽2: 5代表の外にある carrier の扱いが R50 への申し送りに名指しされていない（読めば確定）

- 場所: `StandardKeyTyping.lean` の `carrier`（13〜22行）、results.md「L40.03」の末段。
- 問題点: carrier は篩を取り除き、scoped・opaque・external・Reference・Lazy などを関数の骨格へ写す。5代表は data・List・Map・関数欄・未使用の型引数を確かめたが、篩付きの鍵型、Float の拒否、制約付きの型変数（C が空でない場合）、Set・Bytes、標準の Option・Result の data は含まない。results.md は「R50の全比較は未完」と書くだけで、これらが Lean と Rust の対応の未確認の箇所であることを示さない。
- 修正案: results.md の L40.03 の末段に、5代表の外の carrier の形（上記）を R50 と L40.22 が照合する項目として列挙する。

#### 軽3: F07 の二成分の「固定した署名」は任意の関数を量化した命題の型で、定義の形を Lean で固定していない（読めば確定）

- 場所: `signature-extra.lean` 27〜52行、`signatures.md`「F07」の第2段落。
- 問題点: `∀ (joinV : …) a b v, a.Mem v → (joinV a b).Mem v` などは、任意の関数については偽の命題の型であり、detail F07 が定義の形として固定した `normalF`・`returnF`・`joinF`・`seqF`・`joinV` の中身を型検査していない。normalF の局所規則の型もない。signatures.md は detail を参照するだけである。
- 修正案: 定義の形の五つを signature-extra.lean に `def` として書き（証明は不要）、局所規則の命題をその定義について型検査する。又は、signatures.md の F07 に detail F07 の定義の形を写し、#check は形の確認にすぎないと明記する。

#### 軽4: 名前空間と docstring の一部が中身と合わない（読めば確定）

- 場所: `IntervalFailure.lean` の `Representatives.stopped`（279行）・`Representatives.range_error`（283行）、`StandardKeyTyping.lean` の `Representatives.decimal_collections`（139〜145行）。
- 問題点: `stopped` と `range_error` は代表の名前空間にあるが、本番の `report_failure`（1044行）と `standard_nonfixed`（303行）が使う。`decimal_collections` の docstring は「値側の鍵構造も必要である」と必要性を述べるが、証明は二つの KeyShape を構成する十分性だけである。
- 修正案: 二つの補題を `IntervalFailure` の直下へ移すか、代表の名前空間に置く理由をコメントに書く。docstring を「値側の鍵構造を持つ List と Map の KeyShape を構成する」に改める。

#### 軽5: 01-12 の新しい段落の置き場所が内容と合わない（読めば確定）

- 場所: 01-12「閉じた述語の評価と捕捉」（3403行の節）に加えた TelApplication・StandardContracts・StandardBodies・StandardScalar の段落、07-04 の TelApplication の行の「同節の」。
- 問題点: TelApplication は依存列の反変の適用であり、`TelLe`・`TelClosure` を定める部分型の段落（3249行付近）の話題である。StandardContracts・StandardBodies も閉じた述語の評価ではない。07-04 の「同節の」は、これらを「閉じた述語の評価と捕捉」の内容と読ませる。
- 修正案: TelApplication の段落を部分型の段落の後へ移し、07-04 の行の節名を合わせる。標準契約の三つは、置き場所を節名で示すか、07-04 の行で節名を明記する。

#### 軽6: 時間の記録は単位ごとに「未採取」とするだけで、群の合計の外側の時間を引いていない（読めば確定）

- 場所: `results.md`「単位の完了条件と外側の時間」、effort-ledger.md の 2026-11-03 の L40 群 A・F1 の二行（試行1 約66分・試行2 約15分）。
- 問題点: 単位ごとの時刻がないことの記録は正直である。一方、取りまとめの台帳には群の合計（試行1は容量の誤りで停止、試行2は作業木を引き継いで約15分）がある。results.md は試行が二回であったことと、試行1が停止したことに触れない。群 A と F1 を分けられないことは変わらないが、群全体の外側の時間は取得済みである。
- 修正案: results.md に、台帳の二行を出どころとして群全体の外側の時間（約81分、試行1の停止を含む）を記し、単位・群 A/F1 への按分はしないと書く。

### 情報

#### 情報1: `IntervalFailure` は `maxHeartbeats 2000000` と `maxRecDepth 4096` を局所に置く

相互証明（316〜317行）と overflow の評価（1088行）に限った `set_option … in` である。単独検査は4.71秒で、既定のビルドの時間への影響は小さい。後段の F2 で同じ相互証明を広げるときは、上限を上げずに済むかを最初に確かめるとよい。

#### 情報2: 5経路の一部は `#guard` で検査しており、核の証明ではない

直接 overflow・短絡・return 後の番兵・深さ0と予算0の停止は `#guard` で、コンパイラの評価による検査である（既存の Exchange・Interval の例と同じ扱い）。第一候補を適用する具体例（1107行の `example`）、停止（`stopped`）、Range の正常な Error（`range_error`）は核で検査する定理である。results.md の「有限な判定は#guardと定理の証明で検査する」はこの区別と合う。

### 確認した事項

#### 1. H04 第一候補（観点1）

- 言明: `tracked_failure_sound` の引数・前提・結論は detail F07 と h04-handoff.lean の `#check` の型と一字一句同じである。証明は `analyzeExpr_failure` に `ht.1`（reason ≠ unknown）だけを渡す。trace の rejected の部分は使わないが、署名どおりに保持しており、01-12 も「内部の FailureCovered は trace の存在より強い」と書く。
- 帰納: `expr_failure`・短絡二つ・`block_failure`・三種類の腕・`typed_arguments_failure` は一つの `mutual` の相互証明で、`2 * fuel` の減少で終わる。`arguments_failure` は既存の `arguments_typed` で同じ帰納へ移す。正常な子には既存の `expr_value_normal` の Contains を使い、演算自身の拒否は `add/sub/mul/neg_may_overflow_sound` から導く。intDiv/mod は解析が常に `mayFail = true` を返すことで覆う。
- 停止・未対応: fuel 0 は `success_throw` で成功の場合がなく、`report` の停止は `baseUnknown`（`stopped` が `rfl`）へ退く。未対応の関数呼出しも `#guard` で `mayFail = true` を確かめた。
- 標準評価7形: 固定の規則は `fixed_success` が常に `mayFail = true` を返し、固定でない規則は `standard_nonfixed` が失敗の理由を unknown に限る。Range の InvalidBounds・OutOfRange は `finish` が正常な Result.Error を返す（`range_error`）。
- 具体例: 1107行の `example` が、実際の overflow の `EvalPartial`・trace・Models・TrackedFailure を構成し、任意の Parameters に `tracked_failure_sound` を適用する。
- 後段: 実 δ との接続（L40.29）、正常・returned の二成分（.33）、最初の実失敗（.34）、型付き mark（.35）は F2 に残り、results.md と obligations.md もそう書く。

#### 2. F01〜F07 の署名（観点2）

- signature-check.lean の47命題（値26・計算21）と signature-extra.lean は、一時領域で再実行して終了0、出力の SHA-256 が記録の `af2051b3…`・`22f31fe0…` と一致した。値・計算の構成子数（29−3、24−3）は Typing.lean と合う。同じ構文の複数規則（loc・app・handle・resume）の出力を選言とする規約は signatures.md 932行にある。
- 今回証明したもの（F02 の4代表、F04 の `normal_reply_facts`・`_at`、F05 の Table・KeyObservation・code と Unit、F06 の Row・definition_tel と identity、F07 の第一候補、J40-3 の3定理）と、署名だけのもの（F01・F03 の逆転、F02 の一般形、F05 の `key_table_sound` ほか、F07 の二成分と第二候補）は results.md の表で分けている。不足は重1・中1・軽3である。
- F05 の `key_table_sound` の言明は、`satisfiesB` が Float・関数・opaque 等を拒否し、base には対象の型がないこと、atError の項が string の欄を持つ dataValue であることから、読んだ範囲で反例はない。

#### 3. J40-1 の鍵の5代表（観点3）

- Lean の `computed` が示す要約（A・B は等値・鍵とも always=false・依存 [0]、FunctionField は等値 always=true・鍵 always=false、Phantom は両方 always=false・依存なし）と `satB` の結果 `[true,true,true,false,true]` は、Rust の再実行の出力（typeck の eq_summary・key_summary、型検査の誤りの数、IR 検査）と一致した。関数欄の拒否は型検査の E0423 と、同じ宣言を持つ先行の入力の ADT 表を戻した IR の Key 違反で確かめている。判定規則の追加はない。
- 5代表は detail F05 の指定（List[Decimal]・Map[Integer8,List[Decimal]]・相互再帰・関数欄・未使用の関数型引数）を覆う。外側の残りは軽2に記した。

#### 4. J40-3（観点4）

- 既存の List.head/tail/get の Option、Range の Result・RangeError、NonEmptyList.fromList の Result を保ち、Checked 系の元 List・保持 element を捨てない点は plan の範囲に収まる。公開名・字面を決めていない点も合う。設計者に示す材料としての不足は中2に記した。

#### 5. 公理・禁止構文・import（観点5）

- 新6本に `sorry`・`native_decide`・`#eval`・`axiom`・`implemented_by` はない。`formal/Benitoite.lean` は6行の import の追加だけである。名前付きの手書き宣言は 10・17・9・7・5・49 の計97件で、declarations.json と一致した。公開入口のうち `Table` の読者は代表の private の `table` だけ、`DecimalRounding`・`decimalRound` の読者は `rounding_table` である。
- 単独の Lean（`-M 12288`）は新6本とも終了0だった。Decimal の丸めは `base/decimal.rs` の `MAX_SCALE = 28`・`MAX_MANTISSA = 2^96−1`・places が scale 以上のときの0の補いと合い、`RoundingMode.bnt` の五構成子と一対一である。

#### 6. 写し・義務・記録（観点6）

- 01-12 と 07-04 の追加は Lean の定義・前提と一致し、経緯の文はない。未証明の逆転・`key_table_sound`・二成分を証明済みと書いていない。置き場所は軽5に記した。
- obligations.md の64行は、plan の義務の表で担当に L40 を含む56行（主表54行と O167・O169）と detail の差集合4行・共通4行に過不足なく一致した。全体の閉鎖を書いた行はなく、O090・O091・O137・O169 の「F1分」の判定は F1 の範囲に限っている。
- 記録はいずれも 100 KB 以下である（最大は signatures.md の88,041バイト）。手元の絶対パスは検査用の正規表現だけで、docs/todo へのリンク、工程ID の本番コメントへの混入はない。時間の記録は軽6に記した。

## 補助の入力

`<tmp>/rv-l40-a/` に置いた。

- `axioms.log`・`targets.txt`・`axioms.time`: `axioms.lean` を出力先だけ変えて実行した生出力と時間。audit.py は要約を改造のディレクトリへ書くので使わなかった。
- `ConstBranch.lean`: 重1の反例。`cd formal && lake env lean -M 12288 <tmp>/rv-l40-a/ConstBranch.lean` で終了0、許可三公理だけに依存する。
- `key_probe`・`key_probe.log`: `keys/key_probe.rs` を記録と同じ rlib で一時領域にコンパイルし、実行した出力。run_probe.py は key-probe.json を書き換えるので使わなかった。
- `sig.log`・`sigx.log`: signature-check.lean と signature-extra.lean の再実行の出力。

## 再レビュー（再開1）

2026-11-03。担当の報告と `l40/a/results.md` の「再開1：RV-L40.aの処置」の節を読み、処置した箇所を局所に確かめた。読んだのは新規の `ValueInversion.lean`、`TelApplication.lean` の `open_tail`・`open_two` と二引数の例、`IntervalFailure.lean`・`StandardKeyTyping.lean` の変更箇所、`signature-check.lean`・`signature-extra.lean`・`signatures.md`・`safe-contracts.lean`・`safe-contracts.md`、01-12・07-04・plan.md の差分である。補助の入力と出力は前回と同じ `<tmp>/rv-l40-a/` に置き、既存のファイルを変えていない。

### 総合判定

**群 A・F1 とも可**（前回の重1・中2・軽6・情報2はすべて処置済み、新しい所見は中1・軽1）。新しい中1は J40-3 の材料の一行の誤りであり、群 B の起動を妨げない。設計者の見直しに出す前に直せばよい。

### 前回の所見の処置

| 所見 | 確認した内容 | 判定 |
|---|---|---|
| 重1 | var・const・list・con・atError・checked・checkedRequest・checkedAt の8枝が「芯の対応＋同じ値の facts」の形に改まった。補助入力 `NewBranches.lean` で、atError を除く7枝の新しい `#check` の命題を `inv_var`・`inv_const`・`inv_list_core`・`inv_con`・`inv_checked`・`inv_checkedRequest`・`inv_checkedAt` と `HasTypeVQ.facts` から直接証明した（終了0、許可三公理だけに依存）。新しい const の形は証明できたので、`ConstBranch.lean` の反例（旧い形の否定）は新しい署名には当たらない。`ConstBranch.lean` は再実行でも終了0で、本番にも同じ対照（`whole_type_rejected`）が入った。var の形は detail 第2節の「coreの対応。篩の事実はfacts」と一致する。atError は `errorType_eq` で型引数のない data に定まるので、芯の等号は `V_Sub` を通っても保たれる見込みであり、後続の証明と記録されている | 済 |
| 中1 | F02 に `(hΓ : Ctx.WF 0 C.length Γ)` を加えた。`open_tail` は `SubstOk.openValue` の Transport と既存の `TelLe.bind` で後続を開き、`open_two` は二つ目の引数の型が一つ目に依存する列で両方の実引数列・結果の LeQ・効果の Covers を返す。具体例（7/7）も既定ビルドにある。供給の見込みの根拠は妥当である。閉じた Γ では自明であり、開いた Γ では `Ctx.Regular` の `wf` 欄が文脈の操作（`shiftE`・`OpSig.regular_context`・`failureContext_regular`）で保たれる。既存の置換の補題（`SubstTyping.lean` 748行など）も同じ前提を取る。`Ctx.WF` なしの言明が偽だとは示していないことも results.md に正直に書いてある。開始入力から供給できるかは L40.11 の照合に残る | 済 |
| 中2 | `safe-contracts.lean` の19行は、一時領域での再実行で終了0だった。safeGet の添字は `Integer{0≤self ∧ self<length xs}` の引数の篩、safeHead・tail は `nonemptyType` の別名、Checked 系は同じ元値の欄の篩で証拠を受ける。後続の値の参照番号（`.var 1`）と `shiftV` の移動も読んで正しい。欄の位置（CheckedInteger の minimum/maximum/value=0/1/2、CheckedLength の length/values=2/3、CheckedIndex の values/index=0/1）は `Range.bnt` の宣言の順と一致する。results.md・signatures.md・safe-contracts.md の表は一致する。例外は下の新しい中1である | 済（新中1を除く） |
| 軽1 | 表の二列が同じ計算であることを注に明記した | 済 |
| 軽2 | 篩付きの鍵型・Float・制約付きの型変数・Set・Bytes・Option/Result と、carrier が関数の骨格へ写す型を L40.22/R50 の照合対象として列挙した | 済 |
| 軽3 | `signature-extra.lean` に `joinV`・`normalF`・`returnF`・`joinF`・`seqF` を `def` で定め、その定義について局所規則を型検査する（normalF の規則を含む）。`joinV` の定義は detail F07 の定義の形（bottom を単位とし、同じ幅の整数は区間を合わせ、Boolean は各フラグの論理和、異種は unknown）に合う | 済 |
| 軽4 | `stopped`・`range_error` は `end Representatives` の後（282・286行）へ移った。`decimal_collections` の docstring は十分性の言い方に改まった | 済 |
| 軽5 | TelApplication と ValueInversion の段落は「篩の正規形と制約の読み方」へ、標準契約の三つは「標準契約と数値の正常応答」へ移った。07-04 の行は節名を明記した。どちらの節名も01-12に実在する | 済 |
| 軽6 | 台帳を出どころとして群全体の約81分（試行1の停止を含む）を記録し、再開1の約27.2分を別に記録した | 済 |
| 情報1・2 | 申し送りに一行ずつ残した | 済 |

### 新しい所見

#### 中1: NonEmptyList.fromList の内部契約が既存の Result を Option に替えており、J40-3 の範囲を外れる（読めば確定）

- 場所: `safe-contracts.lean` の `nonemptyFromList`、`safe-contracts.md`・`results.md`（187行）・`signatures.md`（132行）の NonEmptyList.fromList の行。現行の API は `signatures.md` 403行の `NonEmptyList.fromList[T](values: List[T]) -> Result[NonEmptyList[T], EmptyListError]` である。`NonEmptyList.bnt` の例も `Result.Ok`・`Result.Error` で照合する。
- 問題点: plan の J40-3 の項は「既存の Option・Result の API は保つので、既存のスクリプトは変わらない」とする。内部契約の `xs:List[T] → Option[NE[T]]` は、この結果型を変える。同じ表の注は「既存のOption・Result APIは保つ」と書いており、表の中で食い違う。このまま設計者に示すと、既存のスクリプトの `match` が変わる案に読める。
- 修正案: `nonemptyFromList` の結果を `Result[NE[T], EmptyListError]` の data（`Names` に result の data 名と EmptyListError を加える）に改め、Ok は同じ xs、Error は正常値として扱うと書く。三つの表を同じ変更で直し、`safe-contracts.lean` を再検査する。Option へ替える意図があるなら、それは公開の形の変更なので、U02 の独立した問いとして設計者に示す。

#### 軽1: safe-contracts.lean の型検査は Tel の項が作れることだけを確かめる（読めば確定）

`#check all` は19個の `Tel` の項が型として成り立つことだけを確かめる。依存列の Annotation（WF・Sorted・Declared）や、`Names` が実際の宣言を指すことは確かめていない。safe-contracts.md の末段は「今回通したのはTelとしての型検査であり、これらの意味の証明ではない」と書き、群 D/E に渡している。処置は不要である。群 E（L40.26）の最初に、この19行の Annotation を一つの具体の `Names` について示すと、番号の誤りを早く見つけられる。

### 再実行

- 公理監査: 出力先だけを `<tmp>` に変えて `axioms.lean` を実行した。終了0、外側38.64秒、695モジュール・68,392宣言。生出力（`deb8e4ce…`）と対象名の一覧（`61130c30…`）の SHA-256 は audit-summary.json と一致した。依存集合は許可三公理の部分集合だけで、`sorryAx`・`ofReduceBool`・`error:` は0件だった。ValueInversion は17宣言である。
- 単独の Lean（`-M 12288`）: `signature-check.lean`・`signature-extra.lean`・`safe-contracts.lean` と、本番の ValueInversion・TelApplication・IntervalFailure・StandardKeyTyping はすべて終了0、出力に誤りはない。新規・変更の7本に `sorry`・`native_decide`・`#eval`・`axiom`・`implemented_by` はない。`formal/Benitoite.lean` の追加は ValueInversion の import の1行だけで、import の除外はない。
- 補助の入力: `NewBranches.lean`（重1の新しい7枝の証明）、`r1-*.log`・`r1-axioms.*`・`r1-targets.txt`（再実行の出力）を `<tmp>/rv-l40-a/` に加えた。

## 再レビュー（再開2）

2026-11-03。担当の報告と results.md の「再開2」を読み、再開1の新しい中1・軽1の処置を局所に確かめた。条件は前回と同じである。

### 総合判定

**可**（残る所見なし）。群 A・F1 とも可とする。

### 確認した事項

- 中1: `safe-contracts.lean` の `nonemptyFromList` は `xs:List[T]` を受け、`.data n.result [nonempty (a.shiftV 1 0), .data n.emptyListError []]` を返す。`Names` の option 欄は result・emptyListError に替わり、option への参照は残っていない。型引数の順（成功が先、失敗が後）は、本番の `AtContracts`・`AtStateLeaves` の Result の使い方と同じである。結果の形は、標準ライブラリのソース `NonEmptyList.bnt` 36行の `fromList[T](values: List[T]) -> Result[NonEmptyList[T], EmptyListError]` と一致する。内部の形では `NonEmptyList[T]` の代わりに `nonemptyType` の別名を使うが、これは J40-3 が予定した別名への移行である。失敗側は同じ `EmptyListError` であり、既存のスクリプトの `Result.Ok`・`Result.Error` の照合は変わらない。safe-contracts.md・results.md 187行・signatures.md 132行の三つの表の行は字句まで一致し、signatures.md に埋め込んだ定義（818〜820行）も Lean の定義と同じである。
- 軽1: 群 E（L40.26）の最初に、一つの具体の `Names` について Annotation と実際の宣言との対応を示す旨の申し送りが加わった。
- 再実行: `safe-contracts.lean` を `-M 12288` で単独に検査し、終了0、誤り0だった。最初の試行は、取りまとめが段末の work のために `formal/.lake/build` の Refinement の生成物を消して再ビルドしていた最中で、olean がなく失敗した。ビルドの終了を待ってから再実行した。本レビューからはビルドを起動していない。

## 取りまとめの追記

- 重1・中1・中2の判断（値の逆転は型の芯の等号と facts の形に、F02 は `Ctx.WF` を要るなら前提に、J40-3 は依存型の署名の表に）は plan.md の 2026-11-03 の項に記した。所見は担当の再開1・再開2で処置し、再レビュー（再開2）で群 A・F1 とも可とした。
- J40-3 の内部の契約の19行（l40/a/safe-contracts.md）は、U02 を決めるときに設計者へ示す（設計者の見直しの対象）。
- 作業末の work は終了0、163.44秒、最大常駐量 1,539,276,800 バイト（l40/a/results.md）。
