# RV-L40.d: L40 群 D（L40.16〜.20、scalar と有限事実の読者）の独立レビュー

2026-11-03。対象はブランチ `m014/l40.d` の未コミットの作業木、基準 `5e2012958fe8aab1edca8587ec8dd731a1527a82`（san_benito の先端）。新規の Lean 5本（StandardInteger・StandardByteCharacter・StandardFloat・StandardDecimal・StandardFactExamples）は全文を読んだ。既存の変更（`formal/Benitoite.lean`・01-12・07-04・effort-ledger.md）は `git diff` で読んだ。群の記録は `l40/d/` の results.md・obligations.md・sources.json・sources.py・audit.py・axioms.lean・run.py と各 json を読んだ。

根拠として `l40/detail.md` の第2節「数値の正常結果と Stop」、第3節、第4節の F04・F06、第5節の L40.16〜.20 の行と群 D の行、第7節、`l40/results.md`「既存の公開APIと契約の分類」、plan.md「計画の変更と取りまとめへの確認点」の先頭の七項と義務の対応表を読んだ。処理系は `crates/benitoite/src/builtins/funcs/` の integer.rs・narrow_integer.rs・width_bits.rs・unsigned_integer64.rs・operators.rs・byte.rs・character.rs・decimal.rs、`base/decimal.rs` の round、`runtime/equal.rs`、`builtins/table.rs` を読み、標準ソースは `prelude/stdlib/` の整数各幅・Byte・UnsignedInteger・UnsignedInteger8・Float・Float32 を読んだ。形は RV-L40.c.md に合わせた。git の操作、既存のファイルの変更、`lake build`、cargo の実行はしていない。補助の入力と再実行の出力は `<tmp>/rv-l40-d/` に置いた。

## 総合判定

**可**（重0・中1・軽5、情報3）。重の所見はない。中1は、床除算・absolute・min/max・bitwise・shift・負号の名前付きの部分表について、全七幅の等号の定理がなく具体例だけであることで、定理を足すか、.28 へ渡すことを記録に明記すれば足りる。群 D の受け入れを妨げる誤りは見つからなかった。

数値の正常結果は、型域だけの仮定ではなく実際の変換・演算から固定されている。`integerConvert` は対象幅の Some/None を実分岐で返し、`integerConvert_some/none` が同値を与える。加減乗・負号は Interval の `WidthBinary.apply`・`checkedNeg` を呼び、`integerDelta_binary_facts` が名前付きの表の等号・型付け・有限の葉を同じ正常応答から作る。Rust との対応を読んで照合した。

- 床除算は Rust の `checked_div` の後に `checked_rem(..).unwrap_or(0)` で補正する。Lean の `integerFloorDelta` は切捨ての商・剰余を補正した後に `integerChecked` を通す。最小値÷−1は商 2^(w−1) が域外になり IntegerOverflow、最小値 mod −1 は剰余0で正常の0となり、両者は一致する。0除算はどちらも DivisionByZero である。
- absolute は Rust の `checked_abs` と Lean の `natAbs` の後の `integerChecked` が一致する。符号付きの最小値は IntegerOverflow、unsigned は同じ値を返す。
- shift の count は Rust の `shift_amount(n, 幅−1)` と Lean の `count < 0 ∨ 幅 ≤ count` の判定が一致し、どちらも ArgumentOutOfDomain である。shiftRightUnsigned は符号付きの幅にだけある（width_bits.rs と各 `.bnt`）。Lean も unsigned の幅では none を返す。
- u64 の toInteger は Rust が `i64::try_from` の Option を返し、Lean も Option を返す。小幅の toInteger は全域である。
- Byte・Character の変換は Rust の `u8::try_from`・`char::from_u32(u32::try_from(n))` と一致する。Byte の shift も count を検査する（byte.rs）。

境界は補助の入力 `edges.lean` で実際の名前付きの表から確かめた（全件 `rfl`/`decide` で終了0）。確かめた場合は次のとおりである。Integer8 と Integer の最小値÷−1 は IntegerOverflow、最小値 mod −1 は0、最小値の absolute は IntegerOverflow、0除算は DivisionByZero、count 8 と −1 は ArgumentOutOfDomain、`1 <<< 7` は −128、u64 の 0 の bitwiseNot は最大値、127+1 と u64 の 0−1 と −128 の負号は IntegerOverflow、域外の定数 `integer8 200` は none となる。unsigned の幅の shiftRightUnsigned・negate と `Integer.fromInteger` は none、Byte の count 8 は ArgumentOutOfDomain、`byte 256` の toInteger は none となる。Decimal の places −1 は ArgumentOutOfDomain、scale を増やす丸め（1.5 から3桁）は 1500・scale 3、HalfAwayFromZero の −2.5 は −3、−1.0 の fromDecimal は None となる。正常な Option.None を Stop にした箇所も、Stop にすべき場合を正常として証明した箇所もない。

Float 二幅の12分類・12比較は IEEE の規則どおりである。NaN と 1.0 の比較は ne だけが真、±0 は eq・le・ge が真、−∞ と +∞ は ne・lt・le が真となる。具体のビット列（1.0・quiet NaN・±∞・±0）を手で確かめた。数の等号は `runtime/equal.rs` の `(Value::Float(a), Value::Float(b)) => a == b` と、構造の中の Float 成分の扱いに合う。`Float.isInfinite` は Float.bnt にないことを確かめた。Decimal の丸めは `base/decimal.rs` の round と順序（places の検査、scale の拡大の0補完、商と余りからの一回の丸め、最終の仮数の検査）・五モードの増分の条件が一致する。builtin の誤りの写し（InvalidPlaces→ArgumentOutOfDomain、Overflow→DecimalOverflow）と truncate・fromDecimal（`checked_rem`・`checked_div` は tmod・tdiv）も一致する。96 bit の仮数の上限 79228162514264337593543950335 は MAX_MANTISSA と同じであり、`decimal_coefficient128` は U03 の128ビットの保存係数と区別している。

L40.20 の読者は両側とも意味を持つ。`length_le` は `checked_refinement` に実際の証明書（`.hyp 0` の長さの等式と `.use 3` の n>0）を渡し、`length_without_positive_rejected` は空 List・n=0 のモデルで同じ source/target の `Ty.LeQ` 自体を否定する。`false_body_rejected` は Boolean=true のモデルで前提なしの本体を否定する。if・guard・後続腕は元の CaptureOk で閉じ、`E_IfF/E_IfT`・`E_GuardT/E_GuardF` の具体の歩みも既定ビルドで検査されている。観測 none の原子は none のまま、到達しない右辺は `unreachable_right_rejected` で導けないことを示す。

`git diff` の範囲は `formal/Benitoite.lean` の import 5行の追加と、01-12・07-04・effort-ledger.md への追記だけである。群 A〜C の固定署名・`E_Lam`・主な十言明・型付け・実行の規則・CoreAssumptions に差はない。新5本に `sorry`・`native_decide`・`#eval`・`axiom`・`implemented_by` はない。`decide` は有限表の照合に限られ、`set_option maxHeartbeats 4000000` は名前付きの表の simp 5定理に付く（情報1）。

公理監査は、`axioms.lean` を出力先だけ `<tmp>` に替えて `lake env lean -M 12288` で再実行した（外側39.52秒、最大常駐量 2,049,605,632 バイト）。710モジュール・69,557宣言、新5モジュールは 321・82・22・131・89 の計645宣言で、results.md の値と一致した。`#print axioms` は69,557件すべてにあり、公理依存は propext・Quot.sound・Classical.choice の部分集合だけ、`error:` は0件だった。新5本の olean はソースより新しい。sources.json の36入力の SHA-256 は現在の作業木と全件一致し、抜き取った12署名（Decimal.round・UnsignedInteger64.toInteger・Float32.isInfinite・Integer.shiftRightUnsigned ほか乱択8件）は実物の行と一致した。19モジュールの公開関数は数え直して239件だった。

## 所見

### 中

#### 中1: 床除算・absolute・min/max・bitwise・shift・負号の名前付きの表について、全七幅の等号の定理がない（読めば確定）

- 場所: `StandardInteger.lean` の `integerDeltaAt`（274〜328行）と、492〜504行の具体例、`integerBits_typed`・`integerMinMax_typed`・`integerAbsolute_normal`・`integerNeg_reply` と floor の匿名例（586〜599行）。results.md「本番の追加と数値の担当分」の表の min/max・bitwise・shift・床方向の行、obligations.md の O124・O046。
- 問題点: 名前から本体への等号を全七幅で証明したのは、加減乗（`integerDelta_binary`）・六比較（`integerDelta_order`・`integerDelta_equality`）・fromInteger・toInteger だけである。床除算・床剰余・absolute・minimum・maximum・bitwise 4種・shift 3種・`%…negate` は、内側の関数（`integerFloorDelta` など）について任意の幅の性質を示すが、`integerDelta "<幅>.floorDivide" …` がその関数へ届くことは Integer8 と u64 の `rfl` の具体例でしか確かめていない。detail の L40.16 の行は「正常算術/比較/min/max/bitwise/shiftの実δを固定」を求め、results.md も「全七幅の純粋な数値応答の表」として O124 を担当分完了と判定している。表の定義は正しく（補助の入力で他の幅の境界も通る）、誤りは見つからなかったが、名前の連結（`moduleName ++ ".shiftRightUnsigned"` と符号の条件など）の誤りを全幅で捕まえる定理がない。
- 修正案: `integerDelta_binary` と同じ証明で、`integerDelta_floor`（modulo の真偽）・`integerDelta_absolute`・`integerDelta_minMax`・`integerDelta_bitwise`（4種）・`integerDelta_shift`（符号付きは3種、unsigned は2種）・`integerDelta_negate`（`k.min < 0`）を全七幅で証明する。足さない場合は、results.md と obligations.md の O124・O046 に「名前付きの表の全幅の等号は加減乗・比較・明示変換に限り、ほかは .28 で全行と一緒に照合する」と書く。

### 軽

#### 軽1: `%eq`・`%ne` の型引数の扱いが、五つの部分表で異なる（読めば確定）

- 場所: `StandardInteger.lean` の `integerDelta`（344〜351行。`ts = [t]` を要求し、篩を外して整数の幅を読む）と、`characterDelta`・`float32Delta`・`float64Delta`・`decimalDelta` の `"%eq"`・`"%ne"` の行（型・行・範囲の引数を受けず、照合もしない）。01-12 の追記「他の数値の行では空の型・行・範囲引数を使う」。
- 問題点: 処理系の `%eq` は一つの組み込みの関数で、型引数を一つ持つ。整数の表は `[T]` だけを受け、他の四つの表は引数を見ないので、.28/L60 で一つの δ に合成すると、同じ `%eq` の呼び出しが表によって受理・拒否を変える。現状でも誤りではないが、01-12 の文は Character・Float・Decimal の等値が型引数を見ないことを書いていない。
- 修正案: 四つの表の `%eq`・`%ne` も整数と同じく `ts = [t]`（篩を外した芯が対応する型）を要求する形に揃えるか、揃えるのは .28 とし、その旨を results.md の申し送りに書く。01-12 の文は実際の扱いに合わせる。

#### 軽2: Decimal.fromFloat の名前付きの行がなく、`decimalConversionReply` に読者がない（読めば確定）

- 場所: `StandardDecimal.lean` 26〜28行の `decimalConversionReply` と 198〜200行の例、`decimalDelta`。results.md 58行、detail の S34「Decimal.fromInteger/truncate/fromFloat は S07 と併用し整数性/切捨て/失敗を区別」。
- 問題点: `l40/results.md` の分類で Decimal.fromFloat は S07 の追加の関係の対象である。`decimalDelta` に `"Decimal.fromFloat"` の行はなく、`decimalConversionReply` は任意の解析結果を受ける出口で、具体例が一つあるだけである。results.md は Float 表記の解析を外側に残すと書くが、名前付きの行と正常な None の型付けを誰が受け持つかは書いていない。
- 修正案: 外側の解析を引数に取る形（`float_decimal` に当たる関数を仮定せず、解析結果の再検査だけを行う）で `"Decimal.fromFloat"` の行を足すか、results.md と obligations.md の O124 に「fromFloat の名前付きの行は .28、Float 表記の解析は外側」と書く。

#### 軽3: Option を返す正常応答の型付けがなく、申し送りでも名指していない（読めば確定）

- 場所: `integerOption`・`byteOption`・`decimalOption` と `characterDelta` の fromInteger、`decimalTruncateReply`。results.md の表の「変換の None は正常な Option 値」と 48行の .28 への申し送り。
- 問題点: 型付けを証明したのは定数の結果（`integer_result_typed`・`byte_result`・`decimalRound_typed` など）だけで、`.con "Option.Some" [T] [v]`・`.con "Option.None" [T] []` を `Option[T]` で型付ける定理はない。この型付けは P.cons の Option の宣言に依存するので、.28 の BuiltinArgs の照合で扱うのが自然だが、results.md は「全行の結果の型・名前・引数の数の収集と全量化は .28/L60」と一般的に書くだけである。
- 修正案: results.md の申し送りに「Option を返す明示変換（各幅・Byte・Character の fromInteger、u64 の toInteger、fromDecimal、Decimal.truncate・fromFloat）の結果の型付けは .28 で P.cons の Option の宣言と一緒に証明する」と名指して書く。

#### 軽4: Lean の docstring の作業の ID と、01-12 の処理系の事実の文（読めば確定）

- 場所: `StandardFactExamples.lean` 73行「B04 の Not を本体の返却値の篩に使用する。」。01-12 の追記「処理系の構造比較の Float 成分も数の等号で比べる。」、07-04 の StandardFloat の行「Float 成分の構造比較は IEEE の等号である」。
- 問題点: B04 は L30 の改造の文書の番号で、本番のコメントに作業の ID を残さない決まり（O118、AGENTS.md「コメントと名前」）に当たる。verify.py の検査（`L40[.〜]|B15-`）はこれを捕まえない。01-12・07-04 の Float の文は Rust の `runtime/equal.rs` の事実であり、Lean では構造比較を形式化していないので、Lean の定義の写しの中に置くと形式化した性質と読める。
- 修正案: docstring は「Boolean の偽側の有限な葉から得た Not を、返却値の篩に使う。」とする。01-12 の文は削るか、言語の等号の規則を定める章の節を参照する形にし、07-04 の行では「構造比較の Float 成分は形式化の範囲外（処理系は IEEE の等号を使う）」と範囲を分けて書く。verify.py の正規表現に `\bB\d{2}\b` を加える。

#### 軽5: Byte の六比較が L40 のどの単位にもない（読めば確定。計画の側の漏れ）

- 場所: 処理系の `%Byte.less`・`%Byte.lessOrEqual`・`%Byte.greater`・`%Byte.greaterOrEqual`（operators.rs 361〜388行、table.rs）と `%eq`・`%ne`。detail 第2節「整数比較 七幅×6=42」、S03（整数/Character/Float/Decimal）、`byteDelta`。
- 問題点: Byte は七幅と別の8番目の幅であり、その比較は S03 にも 42 組にも入っていない。群 D の担当の範囲の外で、D の判定は誤りではないが、どの単位も Byte の比較の正常応答を受け持っていない。
- 修正案: 取りまとめが、Byte の六比較を .28 の行に加えるか、D の追加の作業として `byteDelta` に4行と等値を足すかを決め、detail の S03 に Byte を書き足す。

### 情報

#### 情報1: 名前付きの表の simp の重さ

`integerDelta_binary`・`_fromInteger`・`_equality`・`_toInteger`・`_order` の5定理は `set_option maxHeartbeats 4000000` を付ける。`findSome?` で七幅を順に試す表を simp で展開するためである。既定ビルドは通るが、中1の定理を足すと同じ重さが増える。`integerDelta` を幅ごとの表の結合ではなく、名前の接頭辞から幅を一度だけ決める形にすると軽くなる見込みである（実行していない）。

#### 情報2: 公理監査の最大常駐量

再実行の最大常駐量は 2,049,605,632 バイトで、`-M 12288` の上限より十分小さい。results.md は RSS を計画上の非採取としているので、この値は参考である。

#### 情報3: sources.py の名前の照合の範囲

sources.py の名前の照合は、Lean のソースに文字列のまま現れる名前が Rust の文字列の集合にあることと、連結で作る加減乗・比較・負号の名前の存在を確かめる。床除算・min/max・bitwise・shift の連結名は Rust の登録との照合がなく、`.bnt` の署名の照合（`check`）だけで覆っている。`.bnt` の `@builtin` の名前と Rust の登録の一致は処理系の側の検査が保証するので、実害はない。

## 確かめた観点の要約

| 観点 | 判定 |
|---|---|
| 1. 数値の正常結果と Stop・各幅の境界 | 可。Rust と一致。境界は補助の入力で実表から確認。全幅の名前の等号の不足は中1 |
| 2. Float の分類・比較、Decimal の丸め・比較・表現外 | 可。IEEE と `equal.rs`、`base/decimal.rs` の round と一致。96 bit と128 bit の区別あり |
| 3. 標準ライブラリの API の照合 | 可。36入力の SHA-256、抜き取り12署名、239件を再確認。架空の API・暗黙の変換なし。fromFloat は軽2、Byte の比較は軽5 |
| 4. L40.20 の読者 | 可。length_le と二つの拒否の対照、if・guard の閉じ方と歩み、unknown と到達しない右辺 |
| 5. 群 A〜C の固定署名・規則の不変 | 可。`git diff` は import と文書の追記だけ |
| 6. 公理・監査・写し・義務・記録 | 可。監査を再実行して一致。B04 と 01-12 の文は軽4。義務64行は detail 第7節の母集団と一致。記録は各100 KB 以下、手元の絶対パスと docs/todo へのリンクなし |

## 実行した検査

| 検査 | 内容 | 結果 |
|---|---|---|
| 公理監査の再実行 | `axioms.lean` の `-- LOCAL_INPUTS` を空にした写しを `<tmp>/rv-l40-d/audit-input.lean` に置き、`L40_AUDIT_TARGETS` を `<tmp>` に向けて `lake env lean -M 12288` | 終了0、39.52秒。710モジュール・69,557宣言、新5モジュール645宣言、許可三公理だけ |
| 境界の具体例 | `<tmp>/rv-l40-d/edges.lean`（`import Benitoite`、名前付きの表の33例） | 終了0 |
| 記録の照合 | sources.json の36入力の SHA-256、12署名の行、19モジュールの公開関数の件数。plan と detail 第7節の母集団と obligations.md の64行 | 全件一致 |
| olean の新しさ | 新5本と `Benitoite.lean` のソースと olean の更新時刻 | olean が新しい |

## 再レビュー（再開1）

2026-11-03。担当の処置（`l40/d/results.md`「再開1」、plan.md「計画の変更と取りまとめへの確認点」の先頭の項）を、前回と同じ条件で局所に読み直した。新5本のうち変更した箇所（StandardInteger の 25〜29行・273〜416行・660〜824行、StandardByteCharacter の `byteDeltaAt`・`byteDelta`・240〜304行、StandardFloat・StandardDecimal の `scalarDelta` を使う入口と 140〜386行、StandardFactExamples の 380行以降の合成例と `optionProgram`）、01-12・07-04 の追記、verify.py・sources.json・audit-summary.json を読んだ。処理系は `builtins/table.rs` の `EQUALITY` と `builtin_scheme` の Equality の枝（996〜1007行）を読んだ。取りまとめの work 検査の終了を待ってから、単独の Lean を二つ実行した。

### 判定

**可**（重0・中0・軽0、情報1）。前回の中1・軽1〜5・情報1・3は処置されている。新しい公理はない。

### 各所見の処置の確認

| 所見 | 確認した内容 | 判定 |
|---|---|---|
| 中1 | `integerDelta_floor`・`_absolute`・`_minMax`・`_bitwise`・`_bitwiseNot`・`_shift`・`_negate` は、いずれも任意の `k : IntKind` と任意の `IntegerValue k` を量化し、`cases k` で七幅すべてを証明する。左辺は名前で引いた `integerDelta`（型・行・範囲の引数は空）、右辺は同じ幅の本体である。shift の前提 `op = .shiftRightUnsigned → k.min < 0` と negate の前提 `k.min < 0` は、width_bits.rs の `unsigned_shift!` が Integer8/16/32 に、Integer.rs が Integer に、operators/signed.rs が符号付きの幅に置く実 API と一致する（符号付き4幅で前提が成り立ち、unsigned では成り立たないことを補助の入力で `decide` した）。shiftLeft・shiftRight は前提が空になる | 解消 |
| 軽1 | Character・Float 二幅・Decimal・Byte の表は共通の `scalarDelta`/`scalarArguments` を通る。等値は型引数がちょうど一つで、`scalarTypeCore` で篩を外した芯が表の基本型と一致し、行・範囲の引数が空のときだけ受理する。他の項目は三つの引数列がすべて空である。整数の表は独自の分岐だが、同じ `scalarTypeCore` で幅を読み、条件は同じである。処理系の `%eq`・`%ne` は `eq[T]` の一つの value の型引数、二引数とも T、結果 Boolean であり、形が合う。合成例は六つの表で受理2件・拒否5件を確かめる | 解消 |
| 軽2 | `decimalFromFloatDelta` が `Decimal.fromFloat` の名前・Float 入力・引数列を検査し、`decimalConversionReply` で再検査する。`decimalFromFloat_typed` が Some・None の型付けを返す | 解消（情報R1） |
| 軽3 | `scalarOption_typed` は V_Con で Some・None を `Option[T]` に型付ける。前提の構成子宣言と型引数数1は、`optionProgram`・`optionArity` が実際に満たすので空でない。各幅の fromInteger・Byte・Character の fromInteger・u64 の toInteger/fromDecimal・Decimal.truncate/fromFloat に読者がある | 解消 |
| 軽4 | 新5本に B04 などの作業の ID はない。verify.py の検出は L・B・O・TODO・RV の形に広がった。01-12・07-04 から Float 成分の構造比較の文を除いた（07-04 927行の「構造比較」は別の TermStructuralEq の行） | 解消 |
| 軽5 | `byteDeltaAt` に `%Byte.less` など4種と `%eq`・`%ne` を置き、`byte_compare` が任意の UInt8 二値・六比較について名前付きの応答・Boolean の型付け・整数値の有限述語の一致を返す | 解消 |
| 情報1 | 新5本に `maxHeartbeats` はない。`integerConvert_self` を simp に渡して大きな範囲の展開を避けている | 解消 |
| 情報3 | sources.json の39入力の SHA-256 は現在の作業木と全件一致した。239件・109署名・不一致0 | 解消 |

### 実行した検査（再開1）

| 検査 | 内容 | 結果 |
|---|---|---|
| 境界と引数検査の具体例 | `<tmp>/rv-l40-d/edges2.lean`。前回の境界（最小値÷−1、最小値 mod −1、最小値の absolute、count 8、unsigned の shiftRightUnsigned・negate）、全幅の定理の任意の k への適用、符号付きの前提の真偽、`%eq` の空・異なる型引数・別の幅の型引数・二つの型引数の拒否と篩付きの受理、順序比較への型引数の拒否、Byte の六比較の 0/255/256、Decimal の places −1 と負の fromDecimal | 終了0 |
| 公理監査の再実行 | 前回と同じ方法、出力先は `<tmp>/rv-l40-d/` | 終了0、41.71秒、最大常駐量 2,061,025,280 バイト。710モジュール・69,677宣言、新5モジュールは 347・160・24・141・93 の計765宣言。69,677件すべてに `#print axioms` があり、依存は propext・Quot.sound・Classical.choice の部分集合だけ、`error:` は0件 |
| 記録 | `l40/d/` の各ファイルは最大 47,255 バイト。手元の絶対パスは verify.py の検査の正規表現の中だけ | 可 |

### 情報

#### 情報R1: fromFloat の行の解析結果は Float の入力と結び付いていない

`decimalFromFloatDelta` は解析結果 `parsed` を引数に取り、Float のビット列とは関係なく受ける。results.md と docstring はこれを外側の境界として明記しており、処置としては足りる。L60 の具体表で、処理系の `float_decimal` に当たる関数から `parsed` を作るとき、同じビット列を使うことを確かめる必要がある。

## 取りまとめの追記

- 中1（全七幅の定理）と軽5（計画の漏れだった Byte の六比較）は、後段へ送らず群 D の再開で処置すると判断し、plan.md の 2026-11-03 の項に記した。所見は担当の再開1で処置し、再レビュー（再開1）で可とした。
- 情報R1（`Decimal.fromFloat` の行が解析結果を Float のビット列と結び付けずに受け取る）は、L60 で具体表を作るときに同じビット列から作っていることを確かめる申し送りとする。
- 作業末の work は終了0、173.27秒、最大常駐量 1,695,973,376 バイト（l40/d/results.md）。
