# RV-L00b.02c: 共有数値層と既定 import の群（L00b.02c）の群末の独立レビュー

2026-10-31。レビュー担当は Opus 5.5 のサブエージェントである。対象はブランチ m014/l00b.02c の未コミットの作業ツリーにある `formal/` の本番の変更である。B_WORK `3a41d6c1` からの差分は、既存3ファイル（`Benitoite.lean`・`Interval/Domain.lean`・`Release/Syntax.lean`）の変更と、新規7ファイル（`Shared/Integer.lean`・`Shared/Interval.lean`・`Shared/Approximation.lean`・`Interval/TypeAdapter.lean`・`Interval/ApproxAdapter.lean`・`Release/ApproxAdapter.lean`・`Release/Refinement/ApproxAdapter.lean`）から成る。

照合した入力は次のとおりである。

- [レビュー依頼](RV-L00b.02c-request.md)
- `l00b.02/signatures.md` の第6.3節、第12.2節の `.02c` の行、第31節、第32節
- `l00b.02/results.md` の `.02c` の節、`02c-boundary.lean`、`02c-public-api.md`、`02c-imports.json`
- plan.md の L00b.02c・L00b.04・O169 の行と 2026-10-31 の判断、decisions.md の D30・D64、`l00a.06a/contracts.md` の閉じた条件の行
- 旧の `formal/Benitoite/Interval/` の Eval・Flow・Sound・Environment、B_WORK の `Interval/Domain.lean` と `Release/Syntax.lean`
- `formal/Benitoite/Release/Refinement/` の Syntax（`ConstOK`・`Val`）と Typing（`V_Const`）
- 現行の設計書 01-12「整数の閉区間の領域」と mayFail の段落、`scripts/check-formal.sh` と `formal/tests/`

Lean は局所に三つの補助ファイルで実行した。補助のファイルはリポジトリの外（`<tmp>/rv02c/`）に置いた。いずれも `cd formal && lake env lean -M 12288 <ファイル>` で、終了0、誤り0件、`sorry` なしである。公理の依存は propext・Classical.choice・Quot.sound の範囲である。全体の `lake build` は繰り返していない。

1. `imports.lean`。Lean の olean の実 import から推移閉包を計算した（下の「依存の分離」）。
2. `checks.lean`。反例 `failed_without_mayFail`（中1）、`normalToShared_iff`（軽1）、`other` と Bool の写しの具体例、構成子の数。
3. `checks2.lean`。`constOK_toApprox`（軽2）と `baseToShared_mem`（中2）。

あわせて、`Release/LegacyCheck.lean` を単独で型検査し、誤りの出力がないことを確かめた。

## 総評

**条件付き可**である。重の所見はない。本番の定義と証明に、読んで確定する誤りは見つからなかった。依存の分離は実 import で本物であり、旧の定義は原文のまま移り、五つの境界にも触れていない。共有の四型は、担当の次の判断のとおり、値を落とさない近似として成り立つ。

条件は中の2件を義務の表へ書くことである。どちらも今の定義を誤りにするものではなく、O169 の接続に残る仕事のうち、第32節と plan に行のないものである。この2件を第32節と O169 の担当の行へ書けば、この群を閉じてよい。本番の Lean を変える必要はない。軽の補題の追加は L10 へ回してよい。

## 観点ごとの判定

| 観点 | 判定 | 根拠 |
|---|---|---|
| 共有層の依存の分離 | 可 | olean の実 import で、`Shared.Integer` の閉包は自身だけ、`Shared.Interval` は Integer と自身、`Shared.Approximation` はその二つと自身である。リポジトリのモジュールとして Release・Interval・Surface を一つも読まない |
| `Release.Syntax → Shared.Integer` の循環 | 可 | `Shared.Integer` の閉包が自身だけなので循環はない。`Interval.Domain` の閉包は Release.Types までで、Release.Syntax を含まない |
| 定義の移設 | 可 | `Release/Syntax.lean` の旧28行と `Shared/Integer.lean` の本体は `diff` で一致する。旧 `Domain.lean` の全行は、行を整列した比較で `Shared/Interval`・`TypeAdapter`・新 `Domain` の和に一致し、差は import・見出し・名前空間の行だけである。完全名は `#print` で `Benitoite.Release.min64` などを確かめた。名前空間を保ったので、旧の証明が別の定義へ切り替わる経路はない |
| 既定ターゲット | 可 | `Benitoite` の閉包は424（根を含む）で、`Benitoite/` の下の424ファイルのうち未到達は `Release.LegacyCheck` だけである。これは元から既定外で、単独の型検査は通った。`02c-imports.json` の8ターゲットの脱落は0件である |
| 接続が読む旧の名前 | 可 | `check-formal.sh` と `formal/tests/` は実行ファイルと出力の JSON を読み、`Domain.lean`・`Syntax.lean` の原文を読まない。処理系と道具にも移設した定義の原文を読む箇所はない |
| ValueApprox と所属 | 可 | 整数は種類の等号と区間所属の連言であり、`unknown` は `other` を含み、整数と Boolean の近似は `other` を含まない（`checks.lean` の例） |
| 旧の幅付き整数の写し | 可 | 範囲内だけ証拠付き整数へ写す。新体系の `V_Const` は `ConstOK` を前提にするので、型付いた定数は `.other` に落ちない（`constOK_toApprox`） |
| Bool の写し | 可 | false を bottom、true を unknown へ写すのは、旧 `NormalRange` の Bool が「正常値の有無」であり、true の域が型の全値を許すからである。型の一致する値について所属と同値であることを `normalToShared_iff` で示した。所属の補題は空虚でない（`.base .unit` と `.base .integer8` の true の具体例で両辺が成り立つ） |
| 旧 FlowApprox と戻り値 | 可 | 戻り値の近似は明示引数であり、`toShared_returned` は引数そのものの所属である。評価の健全性を導いたとは書いていない |
| 失敗の成分 | 条件付き | mayFail の値は写るが、`.failed` の所属は移送できない（中1） |
| 実解析からの接続 | 条件付き | adapter の入力は `Interval.FlowApprox` だけであり、実解析の出力 `BaseApprox` の行がない（中2）。共有の型そのものは足りる |
| 独立評価側の分離 | 可 | 警告・追跡・キー・予算・Failure は共有層に現れない。`EvalResult` は失敗理由の型を引数に取る。`EvalOutcome.toShared` と `ofShared` の往復は両向きが証明され、`EvalOutcome` の三形を一対一に写す |
| 新しい型の整数認定 | 可 | `ofRefinementType` は裸の七種だけを認定し、`refined` と Byte は `none` である。`ofRefinementType_embed` は旧の認定との交換を言う |
| adapter の定理の内容 | 可 | `embedConst_toApprox`・`embedVal_toApprox` は新旧の別定義を結び、`legacy_width_boundary` が `.other` への潰れでないことを具体値で示す |
| 構成子の数 | 可 | Lean の metadata で ValueApprox4・ApproxValue3・FlowApprox1・EvalResult3、HasTypeVQ28・HasTypeCQ21・Vs2・Each2・TelArgs2・Arms3・Clauses2 を確かめた。Refinement の Syntax・Typing・Step・TypedFacts のファイルは差分にないので、三族71と TypedFacts56 は不変である |
| 五つの境界と抜け道 | 可 | 主な定理・公理・提供範囲・書ける形・外部状態の定義に差分はない。変更と新規のファイルに `sorry`・`axiom`・`native_decide`・`implemented_by`・`unsafe`・`partial`・`extern`・`opaque`・`admit` はない。本番の `normalToShared_mem`・`embedVal_toApprox` の公理は propext だけである |

## 新しい所見

### 重

なし。

### 中

#### 中1. `ResultMem` の `.failed` は旧解析の mayFail から移送できず、反例がある（読めば確定する。反例は Lean で示した）

- 場所: `Shared/Approximation.lean` 54行の `.failed _ => flow.mayFail = true`、`Interval/ApproxAdapter.lean` 83〜84行の `toShared_mayFail`、signatures.md 第32.2節の「旧 FlowApprox」の行。
- 問題: 共有の `ResultMem` は「失敗するなら mayFail は真」を読む。旧の解析が持つ定理は `NormalSoundness` と `WarningSoundness` の二つだけであり（`Interval/Eval.lean` 2393〜2408行）、失敗の健全性はない。設計書 01-12 も「失敗一般に対する mayFail の完全性を結論しない」と書く。したがって、`toShared_mayFail` は真偽値の複写であり、`outcome.failed` から `ResultMem` を導く根拠にならない。
- 反例: `<tmp>/rv02c/checks.lean` の `failed_without_mayFail`。腕のない整数の `match 1 {}` は `EvalArms.nil` で `.failed .unknown` に評価され、同じ入力で `Models` が成り立ち、`analyzeBase` の mayFail は偽である（`Interval/Sound.lean` の `analyzeBaseKindArms` の `.nil => baseEmpty`）。網羅性の検査を通る入力では同じ形は作れないが、網羅的な入力に限れば成り立つかは確かめていない。
- 影響: 第32節は normal と returned の移送の範囲を明記するが、失敗の成分は「保持」とだけ書く。D64 の try・Fail・exit の区別を接続するとき、この成分の移送を済んだものと読む余地がある。今の定理は偽にならない。
- 修正案: 定義は変えない。第32.2節の「旧 FlowApprox」の行に「`toShared_mayFail` は値の保持であり、`.failed` の所属は移送しない」と書く。O169 の L20/L40 の行に「失敗の所属は、Exhaustive などの入力条件の下で新しい定理として証明するか、接続で mayFail を保守的に真とする」を足す。どちらを採るかはその段で決める。

#### 中2. 実解析の出力 `BaseApprox` から共有近似への写しがなく、O169 の行にも書かれていない（読めば確定する。写しが作れることは Lean で示した）

- 場所: `Interval/ApproxAdapter.lean` の `normalToShared`・`FlowApprox.toShared`。signatures.md 第6.3節と第32.2節。plan.md の O169。
- 問題: `Interval.FlowApprox` を読むのは `Interval/Flow.lean` と `FlowExamples.lean` だけである。中心の定理と Budget の入口の出力は `BaseApprox` と `AnalysisResult` であり（`Interval/Sound.lean` 19行、613行）、`AnalysisResult.normal` は `ConcreteValue → Prop` なので `ValueApprox` へ計算で写せない。今回の adapter は第6.3節の指定どおりだが、R10b と R50 が比べる相手の親の解析結果には届かない。第32節の「旧の幅付き整数の正常域もこの粗い表現を保つ」は `FlowApprox` に限った話で、`BaseApprox.widths` は端点を持つ。
- 確認: 共有の型は足りる。`<tmp>/rv02c/checks2.lean` の `baseToShared` は入力の型を添えて `BaseApprox` を `ValueApprox` へ写し、`baseToShared_mem` は `Contains` からの所属を公理 propext だけで示す。幅の端点も失わない。
- 修正案: 本番の追加は今回でなくてよい。O169 の L10 か R10b の行に「`BaseApprox` と入力の型から `ValueApprox` への写しと所属の補題を置く」と書き、`FlowApprox.toShared` だけで親の解析を接続したと読まないようにする。

### 軽

#### 軽1. 「情報を保つ」は言明になっていない

- 場所: `Interval/ApproxAdapter.lean` 55行の `normalToShared_mem`。
- 問題: 証明されているのは片向きである。全域を `unknown` へ写す定義でも同じ言明が通るので、この定理だけでは Integer64 と Boolean の情報の保持を確かめられない。定義を読めば保っている。
- 修正案: `<tmp>/rv02c/checks.lean` の `normalToShared_iff`（`value.type = type` の下で所属と `NormalMem` が同値）を L10 で本番へ置く。

#### 軽2. 型付きの整数定数が `.integer` へ写る補題がなく、第32節の「後続の担当」は既存の `ConstOK` で足りる

- 場所: `Release/Refinement/ApproxAdapter.lean`、signatures.md 第32.2節の「旧の幅付き定数」の行、`Release/Refinement/Syntax.lean` 16行のコメント。
- 問題: 新体系の `V_Const` は `ConstOK` を前提にし、`ConstOK` は七種の値域を検査する。したがって新体系の型付いた定数では `.other` の枝に入らない。`<tmp>/rv02c/checks2.lean` の `constOK_toApprox` がこれを示す。一方、新 Syntax の16行は旧から写した「値域の検査は型付けの条件にしない」を残し、`ConstOK` と食い違う。旧 Release の型付けには値域の条件がないので、旧導出の埋め込みでは範囲の供給が要る点は変わらない。
- 修正案: `constOK_toApprox` を L10 で本番へ置き、次に Syntax に触れる作業でコメントを直す。第32節の行に「新体系では ConstOK が供給し、旧導出の埋め込みだけが入力の適格性を要する」と足す。

#### 軽3. 設計書 01-12 の正の場所が古くなった

- 場所: `docs/design/01-spec/01-12-core-calculus.md` 1188行「`Interval/Domain.lean` を正とし」。
- 問題: 領域の定義は `Shared/Interval.lean` へ移り、`Domain.lean` は互換入口になった。この群は現行の設計書を編集しない取り決めなので、担当の誤りではない。ほかの節に残るファイル名と併せて、反映の時に直す必要がある。第32.1節の `Interval.Domain` の「旧 import を維持する」も、`Release.Syntax` への推移依存が消えた事実（results.md）と字面が合わない。意味は「旧の import の文が使える」である。
- 修正案: 改造の設計書の反映の項目に 1188行を加える。第32.1節は「旧の入口の名前を維持する」と書き直す。

#### 軽4. 空の近似に複数の表現がある

- 場所: `Shared/Approximation.lean` の `ValueApprox`。
- 問題: `bottom`、`boolean false false`、`integer k .bottom` はどれも所属が空であり、構文は異なる。`checks.lean` で `boolean false false ≠ bottom` と所属の空を確かめた。今の定理に影響はない。`normalToShared` は空の Boolean の域を `boolean false false` へ写すので、L10 の判定が `= .bottom` で到達可能性を読むと、到達しない枝を到達すると扱う。
- 修正案: L10 の WF か `ValueApprox.possible` のような判定を所属と結ぶ補題で定め、構文の等号で空を判定しない。

## 実行しないと分からない疑いの扱い

中1の「網羅的な入力では mayFail が失敗を覆う」は未確認である。中2と軽1・軽2の補題は `<tmp>/rv02c/` で証明済みであり、本番では実行していない。L20 以降の returned の所属、独立評価と Release の算術の対応は、依頼のとおり今回の範囲外である。

## 申し送り

取りまとめへ返す判断は、中1と中2を第32節と O169 の行へ書いたうえで、この群を閉じてよい、である。本番の Lean の変更は要らない。軽1と軽2の補題、軽4の判定は L10 の入力とし、軽3は設計書の反映で扱う。

## 取りまとめの追記

2026-10-31。補助の入力 `checks.lean`・`checks2.lean` を `l00b.02/rv-02c-checks.lean`・`l00b.02/rv-02c-checks2.lean` へ写した。所見の処置は `l00b.02/signatures.md` 第33節と plan.md の O169 の行に載せた。
