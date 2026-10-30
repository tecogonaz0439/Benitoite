# S01: 篩型の本実装の最初の段の調べと判断の案

2026-10-30 の設計者の方向により、範囲の判断は refinement-full.md と questions-full.md で置き換えた。

2026-10-30、RV-S01・RV-S01bを反映した調べである。以下の「推す」は担当の提案であり、採用済みの仕様ではない。将来の工数はすべて**見込み（実測ではない）**であり、能動作業の時間と、ビルド・外部レビュー・受け入れの待ち時間を分ける。過去の記録から引用する実績は、その範囲と計時の種類を明記する。

## 要約

| 判断 | 推す案 |
|---|---|
| 最初の範囲 | 符号付き64ビットの `Integer` の定数端点の閉区間。リテラルの所属、引数・結果・局所注釈・レコードの欄・リスト要素での契約、区間の包含、関数の引数の反変・結果の共変（篩だけを入れ子へ適用し、入れ子の潜在効果は等号）、明示した実行時検査の成功からの導入を含める |
| 利用者への効果 | 固定したポート・割合・月・日番号・再試行上限・分割幅などの契約を関数間で保ち、範囲外の引数と戻り値を実行前に断る。算術全体の安全性、日付の妥当性、任意のリストへの添字の安全性までは保証しない |
| 構文 | 暫定第一候補は `Integer[1..65535]` と既存の `type Port = Integer[1..65535]`。両端を含める。`Int` という別名は増やさない。構文測定前の仮説である |
| 値の導入 | 期待型のある位置で整数リテラルの所属を検査する。動的入力には新しい純粋な検査 `Range.checkRefined(value: input)`（名前も案）を明示し、期待する `Result[Port, Range.RangeError]` から検査対象の区間を確定する。呼び出しに型引数を書く構文は増やさない |
| 推論 | 構造の等号と部分型関係を分ける。既に篩を持つ整数どうしの合流には凸包を使い、普通の `Integer` が混ざれば `Integer` へ戻す。型構成子の引数は不変。局所の束縛を多相にしない現行規則を保つ |
| Lean の骨格 | 専用 `Ty.range`、`Ty.refined base spec`、既存構成子に篩の添字を持たせる形の三案をP1で比べる。添字の形を先に試し、共通の所属・部分型関係・置換の契約を分離する。今回は閉じた整数区間だけを整形式として認める |
| 算術と条件分岐 | 篩の整数を通常の整数として演算・比較することは含める。算術結果や `if` の経路条件から新しい篩を自動導入することは基本案へ含めず、追加案として基本案へ別に加算する費用を示す |
| 検査の補助 | 全域の純粋なclamp相当の関数を用途を選んで追加する案と、既存の明示した失敗時の停止の処置を使う案も問う。clampの追加費用は基本案の外である |
| 既存機能 | `CheckedInteger`・`CheckedLength`・`CheckedIndex`・`NonEmptyList` と既存標準署名を維持する。添字と長さへの拡張、検査の消去、Property の自動生成は後の判断とする |
| 相乗り | docs/todo の TODO-315・317・294 は相乗りを推す。TODO-308 は試作で判断する。TODO-303・289・290・087・306 は全体として相乗りを推さない。TODO-290 のうち新しい契約の比較に必要な部分は接続作業として行う |
| 見込み | 基本案は Lean **22〜76時間**、処理系・表層・文書等 **20〜74時間**、合計 **42〜150時間**。判断用の捨てる試作は別に7〜12時間を上限の候補とする。外部の機械の検査・全比較・レビュー・受け入れの待ち時間は不明 |

設計者の判断は [questions.md](questions.md) の9まとまり・12問にまとめた。利用者が書ける形を制限する案は、本書第14節のL01〜L20と、問いの各まとまりの独立した行に並べた。

## 0. 根拠と、確かめた範囲

### 0.1 決定・調べ・見立ての区別

| 事項 | 出どころと地位 | 本書での扱い |
|---|---|---|
| 0.0.14 の中心は篩型 | 2026-10-30 の設計者の決定。本改造の [README](../README.md) に記録済み | 固定した前提 |
| SB の範囲を出発点に、実用性から推し直せる | 今回の依頼と同 README の設計者の決定 | 基本案と追加案を比較する |
| 一回に形式化の重い項目は一つ | docs/todo の TODO-250、2026-10-17 に設計者と相談した方針 | 範囲付きエフェクトの別の大改造を重ねない |
| 一般の述語と SMT は今回は含めない、ソルバは自作 | 今回の依頼と docs/todo の TODO-311 の設計者の決定 | 再選択の問いにしない |
| TODO-022 は「ほかが落ち着いてから」 | TODO-250 の当時の順序案。TODO-002 の後の版の割り振りとは区別する | 技術上の依存にしない |
| 相対パスはサーバモードより前 | docs/todo の TODO-303 の設計者の決定 | 「0.0.14 に必須」とは読まない |
| TODO-308 の位置の制限は恒久にしない | docs/todo の TODO-308 の設計者の決定 | 今回の一括解消までは決まっていない |
| 勧告照合 | [security-advisories.md](../security-advisories.md) は取りまとめが実施済み。2026-10-30、設計者の判断: 組み込まない | 本担当は再実行していない。対象・未照合範囲・判断を計画へ引き継ぐ必要がある |

基準は2026-10-30に読んだ作業ツリーである。勧告記録は開始版を `80e8127a4f7edff946529153b2002666cc35edc1` としている。本担当は git で開始版や差分を再照合していない。S01で読み取り・文書作成・定理参照の文字列集計を行い、S01bでレビューの根拠の読み直しと文書の修正を行った。S01・S01bでは処理系・Leanのビルド、テスト、例の実行、構文測定は行っていない。S01cでは許可された篩を除いた版のcheckだけをビルド済みの0.0.13で行い、処理系のビルド・テスト・Leanのビルド・例の実行・構文測定は行っていない。以下の新構文の例はすべて案であり、受理・拒否は提案する規則からの予想である。

### 0.2 現在の規則を確かめた資料

現在の判断の根拠は [00-01](../../design/00-overview/00-01-goals.md)、[用語集](../../design/00-overview/00-04-glossary.md)、[01-06](../../design/01-spec/01-06-type-system.md)、[02-05](../../design/02-impl/02-05-typechecker.md)、[07-04](../../design/07-quality/07-04-formal-semantics.md) と現行ソースである。過去の記録は、試作の到達点と判断の経緯を確かめるために読んだ。過去の案を現行仕様とは扱わない。

| 読んだ記録 | 得られた根拠と限界 |
|---|---|
| [SB findings](../../archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/spikes/SB/findings.md)、[Contracts.lean](../../archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/spikes/SB/Contracts.lean)、[FullTypes.lean](../../archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/spikes/SB/FullTypes.lean) | 定数端点、関数の反変・共変、ラムダと let を含む置換、β 簡約、同じ検査成功値への型付けは小モデルで検査済み。本番のストア・継続・Fail・全表層への移植は未達。FullTypes の不透明型と原子は現在の範囲添字を持つ本番定義そのものではない |
| [targets-and-capabilities §2・§8](../../archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/study/targets-and-capabilities.md)、[RV-S4-response R3・R5](../../archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/reviews/RV-S4-response.md) | 固定の契約と値依存の契約を分ける。数値の篩は IO がその値を受け取る場合だけ対象の数値上限に寄与し、パスやホストの範囲の土台にはならない |
| [language-rules A5](../../archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/study/language-rules.md)、[RV-S8](../../archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/reviews/RV-S8.md) | 未知の式に狭い注釈を書くだけで所属を作れない。一方、既に検査した型を持つ関数引数を信頼することとは別の問題。全構成子を一度に変更して長期間ビルド不能にする切り替えも避ける |
| [0.0.12 の調べ](../../archive/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/study/interval-analysis.md)、[判断 D2〜D8・D18](../../archive/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/decisions.md) | 区間解析は正常値の局所近似と警告であり、公開型を変えない。A1 は対象構文の評価関係への健全性で、Release の実行との意味の一致は証明していない。操作を既定の実装として固定できず D4 を狭めた経緯もある |
| 2026-10-17 の試作（docs/todo の TODO-022 が挙げる `sources/2026-10-17-feasibility-spikes/022/` の findings と小モデル。非公開のためリンクしない） | 半開区間・長さ・算術・条件・値の番号の置換・小さな線形証明書の独立した証拠。現在の Release への接続の証拠ではない。`2x = 1` の矛盾をその証明書で扱えない等の限界も記録済み |

## 1. 最初の範囲と利用者への効果

### 1.1 書けるスクリプトと不足する規則

次は新構文を使う案の共通部分である。ポートの下端1はこの例のアプリケーションの方針であり、既存のすべての API の定義域を1始まりへ変える提案ではない。

```bnt
// 案。現在の処理系では実行していない。
type Port = Integer[1..65535]
type Percent = Integer[0..100]
type Month = Integer[1..12]
type DayNumber = Integer[1..31]
type RetryCount = Integer[0..10]
type ChunkSize = Integer[1..4096]

function portIdentity(port: Port) -> Port
  return port
end function

function defaultPort() -> Port
  return 443
end function

function readPort(input: Integer) -> Result[Port, Range.RangeError]
  return Range.checkRefined(value: input)
end function
```

`Range` の import はこの共通例では省略した。`checkRefined` は第5節の新 API の案である。失敗を明示的に処理し、成功値だけを `Port` として後続の関数へ渡す。

| 用途と具体的な断片（案） | 実行前に断れる誤り | SB 相当で足りる部分 | 足りないことと本書の判断 |
|---|---|---|---|
| ポート: `portIdentity(port: 70000)`、`defaultPort` の結果を `0` へ変更 | 引数・戻り値が契約の外 | 定数所属、宣言した引数・結果の型 | 実通信へ渡すには既存の整数引数へ広げればよいが、それだけで狭い接続エフェクトにはならない。IO の署名は変更しない |
| 割合: `function setPercent(value: Percent) -> Percent` に `101` を渡す | 0〜100という契約違反 | 同上 | `value + 1` や平均の結果の篩は SB にはない。基本案では計算後に再検査する。小数の割合も今回の型の対象外 |
| 月: `function monthName(month: Month) -> String` に `13` を渡す | 1〜12という契約違反 | 同上 | `month + 1` の繰上がり、月ごとの分岐の網羅性の精度は追加規則が要る。12月の次が1月という意味は型だけでは決まらない |
| 日番号: `function makeDay(day: DayNumber) -> DayNumber` に `0`・`32` を渡す | 日番号の外側 | 同上 | 2月30日、閏年、月と日の対応は固定した独立区間では検出できない。関係を持つ後の段へ送る |
| 再試行上限: `function configureRetries(count: RetryCount) -> RetryCount` に `-1`・`100` を渡す | 設定値の契約違反 | 同上 | 実際に呼び出す回数の上限・停止性は保証しない。`remaining - 1` を同じ型へ戻す再帰には算術と分岐の証拠が要るので、再検査か通常の整数を使う |
| 分割幅: `function chunks(size: ChunkSize) -> Integer` に `0` を渡す | 幅が正で上限以内という契約違反 | 同上 | `length + size - 1` 等の途中のあふれは残る。正の幅の受け取りと、処理全体の安全性は分ける |
| 固定した添字: `type WeekIndex = Integer[0..6]` の引数に `7` を渡す | 0〜6という引数契約違反 | 固定区間としては足りる | 任意の `xs` に対する `List.get(xs: xs, i: index)` の成功は証明しない。同じ値でも短いリストには使えない。`CheckedIndex` を残す |
| 設定リスト: `bind ports: List[Port] <- [80, 443, 70000]` | 最後の要素の契約違反 | SB の型と不変な List だけでも表現可能 | Rust/Surface の期待型を要素へ渡す実装は要る。今回含める。既存の `List[Integer]` をまとめて `List[Port]` へ変換はしない |
| レコード: `record Config` の `port: Port`・`retries: RetryCount` に範囲外を構築・更新 | 該当欄の契約違反 | 型構造を保存する枠は足りる | 欄の式に包含を使い、アクセサで宣言型を保つ接続を今回含める。欄どうしの関係は扱わない |
| ジェネリクス: `function identity[T](value: T) -> T` に検査済みの Port を渡す | 同じ契約を失って外の値へ差し替える変更を、期待型のある利用箇所で検出 | 型変数を閉じた篩型で具体化することは可能 | 区間端点そのものを多相にする機能、`T` の内部の値を算術する規則は増やさない |

追加価値は、単一の `CheckedInteger` という名前だけでは区別できない端点を型と関数契約へ残せることにある。`Port` と `RetryCount` を同じ普通の整数として受け渡していた箇所で、包含が成り立たない呼び出しを断れる。ただし範囲が同じ二つの別名は同じ型なので、単位や用途の取り違えをすべて防げるとはしない。

上表は誤りの種類を示す例であり、実スクリプトでの発生頻度や LLM の修正成功率の実測ではない。原則1・2の効果は契約を明示して利用する場合に生じる。既存の全標準署名を変えずとも、スクリプトと利用者のライブラリの契約で利用できると見込む。

### 1.2 算術・分岐まで含める選択肢

| 選択肢 | 推すかと理由 | 追加費用の見込み（実測ではない） | 残る不確かさ |
|---|---|---|---|
| A: SB 相当の契約を、リテラル・コンテナ・検査 API まで本番へ接続 | **基本案として推す**。原則1・2・4。推論と不正な狭め方の境界を説明できる | 第13節の合計に含む | 動的検査の署名の具体化、型変数の上下限、現在の全主定理への接続 |
| B: A に整数加減算・符号付き負号・定数倍の結果の型を追加 | 今回の基本案には入れない。繰返しの再検査を減らせるので原則6には寄与する | A に Lean 16〜36時間、処理系等16〜32時間を追加 | あふれは正常値を返さない失敗なので、正常結果の区間だけを型にするなら「あふれない」の証明は要らない。費用は、加算等の結果型が引数の区間型に依存する署名と δ の型付け・具体化・脱糖への接続にある。一般の積・商を含む額ではない |
| C: Aに同じ局所整数と定数の比較（`=`・`<>`・`<`・`<=`・`>`・`>=`、左右の反転も含む）と、純粋な条件の短絡`and`・`or`・`not`による`if`の絞り込みを追加 | B より独立に選べる追加案。クランプや入力検証を書きやすくするが今回は後段を推す（原則4） | A に Lean 20〜44時間、処理系等16〜36時間を追加 | 条件を一度だけ評価し、その真偽と同じ変数の値を結ぶこと、束縛・置換・短絡との接続。`not`は真偽の枝を入れ替え、and/orは実際に評価する枝の事実を合成する。`<>`等で穴が残れば単一区間へ過大近似し、必要な包含を示せない場合は所属を導入しない。任意のBoolean関数や二つの未知の変数の比較は認定しない |
| D: B と C を同時に加える | 基本案からは外す。選ぶなら本改造の範囲を再見積もりする | Aに別枠でLean32〜72時間・処理系等28〜60時間を加算する。基本案の総額ではなく、B+Cの単純和でもない | 一般の再帰の不変条件や `i < length(xs)` はなお対象外。これを加えても一般の算術安全性は得られない |
| E: 0.0.12 の警告解析の出力をそのまま型の所属として採用 | 推さない（原則1・2）。現在の保証で正当化できない | A1 と Release の一般接続を含む費用は未確定 | 評価関係が別で、return は中心二命題の対象外、未知の構造パターンは値の同一性を持たない |

全域の純粋関数 `Range.clampRefined(value)` 相当も候補に加える。期待型の閉区間 `[lo..hi]` が非空であることを確認し、`min(hi, max(lo, value))` を同じ整数表現で返す案である。比較と選択だけなので、この関数自身は算術のあふれや Result を増やさない。所属の証明は min/max の上下限で済む見込み（実測ではない）で、追加は Lean 2〜4時間・処理系等3〜6時間を見込む。C の一般の経路条件を入れずに提供できるが、割合の表示や音量の補正のように丸める仕様の用途に限る。ポートや誤った設定を丸めて受理する既定動作は原則1・2に合わないため推さない。API名は未決であり、型の端点と実際の丸めの端点の一致は明示検査と同様に証明する。

もう一つは、明示検査の失敗時に `try ... or die` 相当で停止する書き方である。利用側に Result の腕を繰り返し書く負担を減らせるが、動的な停止を増やす。原則2に従い、停止と必要なエフェクトをコード・関数契約・診断から確認できる明示の処置として選ぶ。注釈だけで停止を自動挿入する案は推さない。既存の `or die` を使える接続を先に検討し、別名の専用構文を増やさない（原則4・5）。既存の処置で表せる場合は基本案の例・接続点検に含み、専用の停止APIが必要なら別見積もりとする。Q02で丸めと停止を一行ずつ選べるようにした。

0.0.12 の区間は、ある式のある位置で正常に得られる値の過大近似である。例えば局所で `[3,3]` と推定しても、宣言された `Integer` 全体の値域が `[3,3]` になるわけではない。型の導入に使うなら、「その式が正常に値 v を返せば v は I に入る」という命題を Release の評価と結び、同じ式・同じ値への証拠として使う。元の型の全入力の範囲と見なして Property の生成器を作ることは別の誤りである。

基本案では、区間の包含・凸包の数学を再利用し、警告解析の状態・予算・結果は受理の根拠にしない。未知や解析停止を理由に既に型のある契約を消さず、警告の `coverage: all` を型の証明済みの印にも使わない。

### 1.3 一続きのスクリプトで比べる検査とResultの処理

以下は5用途をA・B・Cで書き比べた案であり、各コード枠は約30〜50行の一続きのスクリプトである。篩構文・`checkRefined` は未実装の案で、**篩の構文を含む版の構文解析・型検査・実行はしていない**。ファイル読取り以外は計算と模擬の結果を使い、HTTPや再試行対象の成否を保証する例ではない。実スクリプトでの検査の実行回数と実用性は、実装後の再現・評価へ残す。

既存部分の確認: 篩をIntegerへ置き換え、新APIを既存Rangeの検査と射影を使う仮関数で代えた15本、および下記のAの慣用版5本は、ビルド済みのbenitoite 0.0.13のcheckですべて成功した（処理系のビルド・スクリプトの実行はしておらず、篩の受理の証拠ではない）。

Aは算術・条件からの導入なし、BはAに加減算・一般の負号・定数倍の正常結果の篩を追加、CはAに直接の局所整数と定数の比較によるifの絞り込みだけを追加した案である。BとCを同時には使わない。算術用の単点の定数 `one`・`step`・`scale` は、Bでも通常のリテラルの既定型を変えずに入力区間を明示するために置いた。Cでは新しい束縛を作る前の同じ局所変数を比較し、比較から得た区間が要求型へ含まれる場合だけ注釈を認める。

次表は**表示したコードの静的な箇所数**を字面から数えたもので、実行の計測値ではない。明示の検査は「検査API呼出し数／手書きの整数の境界判定のif数」、Resultの分岐は `match` 一組の数（2腕を1組と数える）である。Aの慣用版では、検査のエラーをResult.mapErrorでStringへ変換して `try … or return` で返し、設定読取りのFileのResultにも同じ処置を使う。慣用版の列は、コードに直接書くResultのmatchの組とtryの箇所を分けた。mapErrorやtryの内部の実行時の分岐が消えるという意味ではない。Optionの分岐は別であり、設定読取りに各案1組ある。注釈・部分型関係の静的検査は数えない。再帰で同じ箇所を繰り返す動的回数とは区別する。

| 用途 | A: 明示検査(API/if)・Resultのmatch | A慣用版: 明示検査(API/if)・Resultのmatch＋try | B: 明示検査(API/if)・Resultのmatch | C: 明示検査(API/if)・Resultのmatch | 比較から分かること（規則上の予想） |
|---|---|---|---|---|---|
| 再試行の残り回数 | 1/1・2組 | 1/1・1組＋try1箇所 | 1/1・2組 | 1/1・2組 | Bだけでは減算前の正の枝を型に使えず、Cだけでは減算結果を導入できない。慣用版でも動的検査は残る |
| ページ送り | 1/1・2組 | 1/1・1組＋try1箇所 | 1/1・2組 | 0/2・1組 | Bの `[1..1100]` はOffsetを越え、Cは同じrawの境界判定を使える。AでもResultの包み直しのmatchは省ける |
| 割合の計算 | 1/0・2組 | 1/0・1組＋try1箇所 | 1/0・2組 | 0/2・1組 | Bは定数倍までなので商の篩は得ない。Cは計算後に検査する。一般の除算をBへ黙って含めない |
| 設定ファイルからポートを読む | 1/0・3組 | 1/0・1組＋try2箇所 | 1/0・3組 | 0/2・2組 | Aの慣用版はFileの失敗も早期に返す。Fileと入力の動的な失敗をなくす提案ではない |
| 次のポートの候補 | 1/0・2組 | 1/0・1組＋try1箇所 | 0/0・1組 | 1/0・2組 | 既知の `[1024..49151] + [1..1]` はPort内なのでBで再検査を省ける。Cだけでは算術結果の篩は得ない |


Aは関数境界の契約を保てる一方、算術を含む再帰やページ送りで再検査が残る。この制約を許して最初の段を閉じる案を推すが、検査の負担が許容できるかは設計者がQ02で選ぶ。Cの成功は手書きの条件に依存し、Bの利点も入力の型で区間を保てる場合に限る。割合を丸めたい場合にはclamp相当、失敗なら終了してよい設定には明示の停止の処置が別の候補となる（1.2）。

Aの慣用版の検査箇所は次の形である（案）。明示したmatch版とエラーメッセージを揃え、`next`を後続へ渡す。tryの成功値の型から新APIの対象を決めるため、5.4・L20の接続を採ることが前提となる。採らない場合は、先に `Result[RetryCount, Range.RangeError]` を注釈して保存する。

```bnt
bind next: RetryCount <- try Range.checkRefined(value: raw) |> Result.mapError(r: _, f: lambda(error) return "invalid retry counter" end lambda) or return
return retry(remaining: next)
```

設定読取りの慣用版では、Fileのmatchも `bind text <- try File.readText(path) |> Result.mapError(r: _, f: lambda(error) return "cannot read config" end lambda) or return` に置き換える。ほかの用途は検査成功値をbindして後続へ渡す同じ変換である。新APIを含むこれらの案の受理は未検証であり、上のcheckはIntegerへ置き換えた既存部分だけの確認である。

#### 再試行の残り回数

案A（35行）。

```bnt
import Benitoite.Unofficial.Range
import Benitoite.Unofficial.IO.Console
type RetryCount = Integer[0..10]
const one: Integer[1..1] = 1

function attempt(remaining: RetryCount) -> Boolean
  return remaining = 2
end function

function retry(remaining: RetryCount) -> Result[RetryCount, String]
  if remaining = 0 then
    return Result.Error("exhausted")
  else
    bind active: RetryCount <- remaining
    if attempt(remaining: remaining) then
      return Result.Ok(remaining)
    end if
    // remaining - 1 に当たる。計算後は明示して検査する。
    bind raw <- active - one
    bind checked: Result[RetryCount, Range.RangeError] <- Range.checkRefined(value: raw)
    return match checked with
      case Result.Ok(next) -> retry(remaining: next)
      case Result.Error(_) -> Result.Error("invalid retry counter")
    end match
  end if
end function

function main() -> Unit uses Console.Write
  bind initial: RetryCount <- 5
  bind result <- retry(remaining: initial)
  match result with
    case Result.Ok(left) -> Console.writeLine(text: Integer.toString(left))
    case Result.Error(message) -> Console.writeErrorLine(text: message)
  end match
end function
```

案B（35行）。

```bnt
import Benitoite.Unofficial.Range
import Benitoite.Unofficial.IO.Console
type RetryCount = Integer[0..10]
const one: Integer[1..1] = 1

function attempt(remaining: RetryCount) -> Boolean
  return remaining = 2
end function

function retry(remaining: RetryCount) -> Result[RetryCount, String]
  if remaining = 0 then
    return Result.Error("exhausted")
  else
    bind active: RetryCount <- remaining
    if attempt(remaining: remaining) then
      return Result.Ok(remaining)
    end if
    // remaining - 1 に当たる。Bだけでは正の枝を使えない。
    bind raw: Integer[-1..9] <- active - one
    bind checked: Result[RetryCount, Range.RangeError] <- Range.checkRefined(value: raw)
    return match checked with
      case Result.Ok(next) -> retry(remaining: next)
      case Result.Error(_) -> Result.Error("invalid retry counter")
    end match
  end if
end function

function main() -> Unit uses Console.Write
  bind initial: RetryCount <- 5
  bind result <- retry(remaining: initial)
  match result with
    case Result.Ok(left) -> Console.writeLine(text: Integer.toString(left))
    case Result.Error(message) -> Console.writeErrorLine(text: message)
  end match
end function
```

案C（35行）。

```bnt
import Benitoite.Unofficial.Range
import Benitoite.Unofficial.IO.Console
type RetryCount = Integer[0..10]
const one: Integer[1..1] = 1

function attempt(remaining: RetryCount) -> Boolean
  return remaining = 2
end function

function retry(remaining: RetryCount) -> Result[RetryCount, String]
  if remaining = 0 then
    return Result.Error("exhausted")
  else
    bind active: Integer[1..10] <- remaining
    if attempt(remaining: remaining) then
      return Result.Ok(remaining)
    end if
    // remaining - 1 に当たる。計算後は明示して検査する。
    bind raw <- active - one
    bind checked: Result[RetryCount, Range.RangeError] <- Range.checkRefined(value: raw)
    return match checked with
      case Result.Ok(next) -> retry(remaining: next)
      case Result.Error(_) -> Result.Error("invalid retry counter")
    end match
  end if
end function

function main() -> Unit uses Console.Write
  bind initial: RetryCount <- 5
  bind result <- retry(remaining: initial)
  match result with
    case Result.Ok(left) -> Console.writeLine(text: Integer.toString(left))
    case Result.Error(message) -> Console.writeErrorLine(text: message)
  end match
end function
```

#### ページ送り

案A（32行）。

```bnt
import Benitoite.Unofficial.Range
import Benitoite.Unofficial.IO.Console
type Offset = Integer[0..1000]
type Limit = Integer[1..100]

function advance(offset: Offset, limit: Limit) -> Result[Offset, String]
  // ページ取得の後、次の開始位置を計算する。
  bind raw <- offset + limit
  if raw > 1000 then
    return Result.Ok(0)
  else
    bind checked: Result[Offset, Range.RangeError] <- Range.checkRefined(value: raw)
    return match checked with
      case Result.Ok(next) -> Result.Ok(next)
      case Result.Error(_) -> Result.Error("invalid offset")
    end match
  end if
end function

function showOffset(offset: Offset) -> String
  return "next=" + Integer.toString(offset)
end function

function main() -> Unit uses Console.Write
  bind offset: Offset <- 900
  bind limit: Limit <- 100
  bind result <- advance(offset: offset, limit: limit)
  match result with
    case Result.Ok(next) -> Console.writeLine(text: showOffset(offset: next))
    case Result.Error(message) -> Console.writeErrorLine(text: message)
  end match
end function
```

案B（32行）。

```bnt
import Benitoite.Unofficial.Range
import Benitoite.Unofficial.IO.Console
type Offset = Integer[0..1000]
type Limit = Integer[1..100]

function advance(offset: Offset, limit: Limit) -> Result[Offset, String]
  // ページ取得の後、次の開始位置を計算する。
  bind raw: Integer[1..1100] <- offset + limit
  if raw > 1000 then
    return Result.Ok(0)
  else
    bind checked: Result[Offset, Range.RangeError] <- Range.checkRefined(value: raw)
    return match checked with
      case Result.Ok(next) -> Result.Ok(next)
      case Result.Error(_) -> Result.Error("invalid offset")
    end match
  end if
end function

function showOffset(offset: Offset) -> String
  return "next=" + Integer.toString(offset)
end function

function main() -> Unit uses Console.Write
  bind offset: Offset <- 900
  bind limit: Limit <- 100
  bind result <- advance(offset: offset, limit: limit)
  match result with
    case Result.Ok(next) -> Console.writeLine(text: showOffset(offset: next))
    case Result.Error(message) -> Console.writeErrorLine(text: message)
  end match
end function
```

案C（31行）。

```bnt
import Benitoite.Unofficial.Range
import Benitoite.Unofficial.IO.Console
type Offset = Integer[0..1000]
type Limit = Integer[1..100]

function advance(offset: Offset, limit: Limit) -> Result[Offset, String]
  // ページ取得の後、次の開始位置を計算する。
  bind raw <- offset + limit
  if raw > 1000 then
    return Result.Ok(0)
  else if raw < 0 then
    return Result.Error("invalid offset")
  else
    bind next: Offset <- raw
    return Result.Ok(next)
  end if
end function

function showOffset(offset: Offset) -> String
  return "next=" + Integer.toString(offset)
end function

function main() -> Unit uses Console.Write
  bind offset: Offset <- 900
  bind limit: Limit <- 100
  bind result <- advance(offset: offset, limit: limit)
  match result with
    case Result.Ok(next) -> Console.writeLine(text: showOffset(offset: next))
    case Result.Error(message) -> Console.writeErrorLine(text: message)
  end match
end function
```

#### 割合の計算

案A（30行）。

```bnt
import Benitoite.Unofficial.Range
import Benitoite.Unofficial.IO.Console
type Completed = Integer[0..1000]
type Percent = Integer[0..100]
const scale: Integer[100..100] = 100

function percentage(completed: Completed) -> Result[Percent, String]
  bind scaled <- completed * scale
  // Bは定数倍まで。商の結果の篩は追加していない。
  bind raw <- scaled div 1000
  bind checked: Result[Percent, Range.RangeError] <- Range.checkRefined(value: raw)
  return match checked with
    case Result.Ok(next) -> Result.Ok(next)
    case Result.Error(_) -> Result.Error("invalid percentage")
  end match
end function

function showPercent(percent: Percent) -> String
  bind digits <- Integer.toString(percent)
  return digits + "%"
end function

function main() -> Unit uses Console.Write
  bind completed: Completed <- 750
  bind result <- percentage(completed: completed)
  match result with
    case Result.Ok(percent) -> Console.writeLine(text: showPercent(percent: percent))
    case Result.Error(message) -> Console.writeErrorLine(text: message)
  end match
end function
```

案B（30行）。

```bnt
import Benitoite.Unofficial.Range
import Benitoite.Unofficial.IO.Console
type Completed = Integer[0..1000]
type Percent = Integer[0..100]
const scale: Integer[100..100] = 100

function percentage(completed: Completed) -> Result[Percent, String]
  bind scaled: Integer[0..100000] <- completed * scale
  // Bは定数倍まで。商の結果の篩は追加していない。
  bind raw <- scaled div 1000
  bind checked: Result[Percent, Range.RangeError] <- Range.checkRefined(value: raw)
  return match checked with
    case Result.Ok(next) -> Result.Ok(next)
    case Result.Error(_) -> Result.Error("invalid percentage")
  end match
end function

function showPercent(percent: Percent) -> String
  bind digits <- Integer.toString(percent)
  return digits + "%"
end function

function main() -> Unit uses Console.Write
  bind completed: Completed <- 750
  bind result <- percentage(completed: completed)
  match result with
    case Result.Ok(percent) -> Console.writeLine(text: showPercent(percent: percent))
    case Result.Error(message) -> Console.writeErrorLine(text: message)
  end match
end function
```

案C（33行）。

```bnt
import Benitoite.Unofficial.Range
import Benitoite.Unofficial.IO.Console
type Completed = Integer[0..1000]
type Percent = Integer[0..100]
const scale: Integer[100..100] = 100

function percentage(completed: Completed) -> Result[Percent, String]
  bind scaled <- completed * scale
  // Bは定数倍まで。商の結果の篩は追加していない。
  bind raw <- scaled div 1000
  if raw < 0 then
    return Result.Error("invalid percentage")
  else if raw > 100 then
    return Result.Error("invalid percentage")
  else
    bind percent: Percent <- raw
    return Result.Ok(percent)
  end if
end function

function showPercent(percent: Percent) -> String
  bind digits <- Integer.toString(percent)
  return digits + "%"
end function

function main() -> Unit uses Console.Write
  bind completed: Completed <- 750
  bind result <- percentage(completed: completed)
  match result with
    case Result.Ok(percent) -> Console.writeLine(text: showPercent(percent: percent))
    case Result.Error(message) -> Console.writeErrorLine(text: message)
  end match
end function
```

#### 設定ファイルの読取り

案A（36行）。

```bnt
import Benitoite.Unofficial.Range
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.IO.Console
type Port = Integer[1..65535]

function parsePort(text: String) -> Result[Port, String]
  match Integer.parse(s: text) with
    case Option.None -> return Result.Error("expected integer")
    case Option.Some(raw) ->
      bind checked: Result[Port, Range.RangeError] <- Range.checkRefined(value: raw)
      return match checked with
        case Result.Ok(next) -> Result.Ok(next)
        case Result.Error(_) -> Result.Error("invalid port")
      end match
  end match
end function

function loadPort(path: String) -> Result[Port, String] uses File.Read
  // ファイルは整数の字面一つを含むものとする。
  match File.readText(path: path) with
    case Result.Ok(text) -> return parsePort(text: text)
    case Result.Error(_) -> return Result.Error("cannot read config")
  end match
end function

function showPort(port: Port) -> String
  return "port=" + Integer.toString(port)
end function

function main() -> Unit uses File.Read, Console.Write
  bind result <- loadPort(path: "port.conf")
  match result with
    case Result.Ok(port) -> Console.writeLine(text: showPort(port: port))
    case Result.Error(message) -> Console.writeErrorLine(text: message)
  end match
end function
```

案B（36行）。

```bnt
import Benitoite.Unofficial.Range
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.IO.Console
type Port = Integer[1..65535]

function parsePort(text: String) -> Result[Port, String]
  match Integer.parse(s: text) with
    case Option.None -> return Result.Error("expected integer")
    case Option.Some(raw) ->
      bind checked: Result[Port, Range.RangeError] <- Range.checkRefined(value: raw)
      return match checked with
        case Result.Ok(next) -> Result.Ok(next)
        case Result.Error(_) -> Result.Error("invalid port")
      end match
  end match
end function

function loadPort(path: String) -> Result[Port, String] uses File.Read
  // ファイルは整数の字面一つを含むものとする。
  match File.readText(path: path) with
    case Result.Ok(text) -> return parsePort(text: text)
    case Result.Error(_) -> return Result.Error("cannot read config")
  end match
end function

function showPort(port: Port) -> String
  return "port=" + Integer.toString(port)
end function

function main() -> Unit uses File.Read, Console.Write
  bind result <- loadPort(path: "port.conf")
  match result with
    case Result.Ok(port) -> Console.writeLine(text: showPort(port: port))
    case Result.Error(message) -> Console.writeErrorLine(text: message)
  end match
end function
```

案C（39行）。

```bnt
import Benitoite.Unofficial.Range
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.IO.Console
type Port = Integer[1..65535]

function parsePort(text: String) -> Result[Port, String]
  match Integer.parse(s: text) with
    case Option.None -> return Result.Error("expected integer")
    case Option.Some(raw) ->
      if raw < 1 then
        return Result.Error("invalid port")
      else if raw > 65535 then
        return Result.Error("invalid port")
      else
        bind port: Port <- raw
        return Result.Ok(port)
      end if
  end match
end function

function loadPort(path: String) -> Result[Port, String] uses File.Read
  // ファイルは整数の字面一つを含むものとする。
  match File.readText(path: path) with
    case Result.Ok(text) -> return parsePort(text: text)
    case Result.Error(_) -> return Result.Error("cannot read config")
  end match
end function

function showPort(port: Port) -> String
  return "port=" + Integer.toString(port)
end function

function main() -> Unit uses File.Read, Console.Write
  bind result <- loadPort(path: "port.conf")
  match result with
    case Result.Ok(port) -> Console.writeLine(text: showPort(port: port))
    case Result.Error(message) -> Console.writeErrorLine(text: message)
  end match
end function
```

#### 次のポートの候補

案A（34行）。

```bnt
import Benitoite.Unofficial.Range
import Benitoite.Unofficial.IO.Console
type Port = Integer[1..65535]
type UserPort = Integer[1024..49151]
const step: Integer[1..1] = 1

function nextPort(current: UserPort) -> Result[Port, String]
  // 設定したポートの次を候補にする。空きポートの保証はしない。
  bind raw <- current + step
  bind checked: Result[Port, Range.RangeError] <- Range.checkRefined(value: raw)
  return match checked with
    case Result.Ok(next) -> Result.Ok(next)
    case Result.Error(_) -> Result.Error("invalid next port")
  end match
end function

function endpoint(port: Port) -> String
  bind number <- Integer.toString(port)
  return "localhost:" + number
end function

function report(port: Port) -> Unit uses Console.Write
  bind address <- endpoint(port: port)
  Console.writeLine(text: address)
end function

function main() -> Unit uses Console.Write
  bind current: UserPort <- 8080
  bind result <- nextPort(current: current)
  match result with
    case Result.Ok(port) -> report(port: port)
    case Result.Error(message) -> Console.writeErrorLine(text: message)
  end match
end function
```

案B（32行）。

```bnt
import Benitoite.Unofficial.Range
import Benitoite.Unofficial.IO.Console
type Port = Integer[1..65535]
type UserPort = Integer[1024..49151]
const step: Integer[1..1] = 1

function nextPort(current: UserPort) -> Result[Port, String]
  // 設定したポートの次を候補にする。空きポートの保証はしない。
  bind next: Integer[1025..49152] <- current + step
  // 結果の区間がPortへ含まれるので再検査しない。
  bind accepted: Port <- next
  return Result.Ok(accepted)
end function

function endpoint(port: Port) -> String
  bind number <- Integer.toString(port)
  return "localhost:" + number
end function

function report(port: Port) -> Unit uses Console.Write
  bind address <- endpoint(port: port)
  Console.writeLine(text: address)
end function

function main() -> Unit uses Console.Write
  bind current: UserPort <- 8080
  bind result <- nextPort(current: current)
  match result with
    case Result.Ok(port) -> report(port: port)
    case Result.Error(message) -> Console.writeErrorLine(text: message)
  end match
end function
```

案C（34行）。

```bnt
import Benitoite.Unofficial.Range
import Benitoite.Unofficial.IO.Console
type Port = Integer[1..65535]
type UserPort = Integer[1024..49151]
const step: Integer[1..1] = 1

function nextPort(current: UserPort) -> Result[Port, String]
  // 設定したポートの次を候補にする。空きポートの保証はしない。
  bind raw <- current + step
  bind checked: Result[Port, Range.RangeError] <- Range.checkRefined(value: raw)
  return match checked with
    case Result.Ok(next) -> Result.Ok(next)
    case Result.Error(_) -> Result.Error("invalid next port")
  end match
end function

function endpoint(port: Port) -> String
  bind number <- Integer.toString(port)
  return "localhost:" + number
end function

function report(port: Port) -> Unit uses Console.Write
  bind address <- endpoint(port: port)
  Console.writeLine(text: address)
end function

function main() -> Unit uses Console.Write
  bind current: UserPort <- 8080
  bind result <- nextPort(current: current)
  match result with
    case Result.Ok(port) -> report(port: port)
    case Result.Error(message) -> Console.writeErrorLine(text: message)
  end match
end function
```

## 2. 対象の型

| 選択肢 | 判断と設計原則 | 費用の見込み（実測ではない） | 残る不確かさ |
|---|---|---|---|
| 64ビット `Integer` だけ | **推す**。日常の件数・設定値の例を扱え、既存 `Range.checkInteger` と対応する（原則4・6） | 基本案に含む | 他の幅を使う実利用の比率は未測定 |
| 算術のある整数七種 | 区間の領域は既に幅でパラメータ化されているので、次の段として比較的追加しやすい。ただし今回の必須にはしない | 基本案へ Lean 8〜20時間、処理系等12〜28時間を追加 | 幅付きリテラル・変換・組み込み・表示・u64最大値・辞書と全交換の接続。六幅には整数の定数・範囲パターンが現状ない |
| `CheckedLength` に相当する長さの篩 | 今回は推さない。`List[T]` の値の長さという別の所属を要する（原則1・4） | Lean 20〜48時間、処理系等20〜48時間を追加する程度から。独立した概算 | リスト構築・append/map/filter・保存・取り出しとの接続は未試作。これら全部の上限の見積もりではない |
| `CheckedIndex` に相当する値依存の添字 | 今回は推さない。固定整数区間だけから同じリストとの関係を導けない（原則1） | 値依存の段全体について過去の Lean 80〜200時間・処理系等80〜240時間を参考にするが、今回の上限へ流用しない | 元のリストの同一性、長さ、束縛・代入・呼び出しが難所 |

七種は `Integer8`・`Integer16`・`Integer32`・`Integer64` と `UnsignedInteger16`・`UnsignedInteger32`・`UnsignedInteger64` である。`Integer64` は `Integer` の別名であり別の八種目ではない。`Byte`（`UnsignedInteger8`）は現在も算術の七種には入らない。内部の数値領域は最初から種類の引数を残し、公開の整形式を Integer64 に限定すれば、六種を後で加える際に `Ty` の構成子を増やさずに済む見込みである。

## 3. 構文の候補と外部の先例

### 3.1 一次資料で確認した書き方

以下の外部資料の取得日はすべて **2026-10-30** である。他の処理系を実行した結果ではない。表の例は資料の表記か、その文法による短い例である。

| 言語・方式 | 書き方と呼び名 | 今回の比較で分かること | 一次資料 |
|---|---|---|---|
| Ada | `subtype Small_Int is Integer range -10 .. 10;`。subtype、range constraint | 両端を含み、逆転した range は null range。部分型の宣言と実行時の検査も持つので、Benitoite の静的な拒否案と意味を同一視しない | [RM 3.2.2](https://www.adaic.org/resources/add_content/standards/12rm/html/RM-3-2-2.html)、[RM 3.5](https://adaic.org/resources/add_content/standards/05rm/html/RM-3-5.html) |
| Pascal（Free Pascal） | `type WorkDays = monday .. friday;`、`0..255`。subrange type | 順序型の上下端を直接書く形。篩を付ける前の型名を書かない点は幅を明示したい本案と異なる | [Language Reference: Ordinal types / Subrange types](https://docs.freepascal.org/docs-html/current/ref/refsu4.html) |
| Nim | `range[0..5]`、`range[1..high(int)]`。subrange type | 篩を付ける前の型と同じ大きさの値を使い、範囲外の代入は静的誤りまたは panic。見た目が近くても自動の実行時検査まで採る理由にはならない | [Manual: Subrange types](https://nim-lang.org/docs/manual.html#types-subrange-types) |
| Liquid Haskell | `[lq\| type Nat = {v:Int \| 0 <= v} \|]`（資料の例）、関数の引数・結果へ述語。refinement type | 一般の論理条件、別名、measure を持つ。整数区間だけの構文より表現力が広い | [Spec Reference](https://ucsd-progsys.github.io/liquidhaskell/specifications/)、[Simple Refinements](https://goto.ucsd.edu/~nvazou/liquidtutorial/SimpleRefinements.lhs.slides.html) |
| F* | `x:int{x >= 0}`、`x:t{p}`。refinement type | 値の束縛名と述語を明示する。公式の `int` は無界整数であり、Benitoite の有限幅算術の証拠へそのまま移せない | [Getting off the ground: Boolean refinement types / Refinement subtyping](https://fstar-lang.org/tutorial/book/part1/part1_getting_off_the_ground.html) |
| Rust の提案・実験 | 提案は `i32 is 1..16` 等。pattern type | パターンで型の値を限定する提案。安定した言語仕様の先例とは扱わない。追跡課題は実験・RFC 未承認の状態を明記し、`S-tracking-perma-unstable`（無期限に不安定）のラベルを持つ | [提案者の草案](https://gist.github.com/joboet/0cecbce925ee2ad1ee3e5520cec81e30)、[rust-lang/rust #123646](https://github.com/rust-lang/rust/issues/123646) |
| Scala ライブラリ refined | `Int Refined Interval.ClosedOpen[7, 77]`、`refineV`。refinement types | 開・閉の組を型名で区別する。動的入力は Either で検査する例がある | [fthomas/refined README](https://github.com/fthomas/refined) |
| Scala ライブラリ Iron | `Int :\| Positive`、区間は `Interval.Closed[L,H]` 等。refined type / type constraint | 静的に評価できない入力は明示した `refineEither` 等を使う。Scala の言語機能の refined type とライブラリを区別する | [Overview](https://iltotore.github.io/iron/docs/overview.html)、[Interval API](https://iltotore.github.io/iron/io/github/iltotore/iron/constraint/numeric%24%24Interval%24.html)、[Refinement Methods](https://iltotore.github.io/iron/docs/reference/refinement.html) |
| TypeScript | `1 \| 2 \| 3`、`type` 別名、type predicate による narrowing | 数値リテラルの union と制御フローによる絞り込みの先例。これらの文書は一般の整数区間の部分型を定義していないので、その先例とはしない | [Everyday Types: Literal Types](https://www.typescriptlang.org/docs/handbook/2/everyday-types.html#literal-types)、[Narrowing](https://www.typescriptlang.org/docs/handbook/2/narrowing) |

これらの資料から LLM の成功率の優劣は分からない。特定言語で使われることと、Benitoite の文脈で生成・修正が成功することを分ける。

### 3.2 Benitoite の選択肢

| 候補 | 利点と欠点 | 判断 |
|---|---|---|
| `Integer{0 <= v and v <= 65535}` | 後の一般述語に近い。ただし `v` の束縛規則が必要で、未実装の任意述語まで書けると誤解しやすい。`0 <= v < n` は現行の比較の連鎖の文法でもない | 今回の第一候補にしない |
| `Integer[1,65535]` | 短いが、型引数の二要素と上下端を同じコンマで表す。`Integer` の型パラメータと誤読しやすい | 比較対象 |
| `Integer[1..65535]` | 既存の閉じた整数の範囲パターンと範囲添字の `..` の字面を使う。端点式の許容範囲まで同じとはしない（3.3）。`List[Integer[1..65535]]` の区切りも明示できる | **暫定で推す**（原則3・4・5）。成功率の優位は未測定 |
| `Integer in 1..65535` | 篩を付ける前の型と範囲を読めるが、`in` の追加または文脈語化と、関数結果型・uses・入れ子での結合順位の規則が要る | 有力な対案として測定する |
| 別名だけで `type Port = ...` を許す | 公開契約を読みやすくできるが、一度しか使わない範囲にも名前が要る | 別名は推奨するが必須にしない。型位置の同じ一形式を別名の右辺にも使う |

`Integer[lo..hi]` は型を書く位置でだけ認め、値としての range を新設しない。整数の型名にだけ特殊な角括弧を認める文法となるため、型引数・Scope の添字・範囲パターンの読取りを整理する必要がある。`Int` は現行の型名ではないので、試作の `Int[...]` をそのまま公開名にしない。

### 3.3 端点・空区間・命名

推すのは閉区間である。既存の Range の API と区間解析も閉区間であり、最大整数の区間に排他的な上端 `max64 + 1` を利用者が書く必要がない（原則3・4・5）。半開区間は添字や長さに読みやすいが、その対象を加える段で別途判断する。今回の内部の所属は `lo <= value and value <= hi` とする。

端点には符号付き整数リテラル、括弧、整数の `const` の直接参照を許す案を推す。ただし現行の01-05「パターンの拡張（初回リリース版）」の両端と01-07「閉じた範囲引数」のポートはリテラルに限るため、許す式は一致しない。対案は、型の端点もリテラルだけに揃える案、型だけconst参照まで広げる案、パターン・範囲添字も同じ規則へ広げる案の三つである。推すのは二つ目である。01-12の `rangeFixedInteger`（リテラル・負のリテラル・const参照・括弧）と01-06の局所認定を前例とし、端点の重複記述を減らす一方、型の記述と照合パターンの役割の差を明記する（原則2・4・5）。三つ目はパターンの脱糖・網羅性とエフェクト注釈の認定も変えるため、今回の費用に含めない。L10で選ぶ。`const` の値は既存の定数式の規則で計算し、型の記述には確定した整数を格納する。型の中に任意の計算式を評価する新しい処理は入れない。`minimum + 1` を型の端点へ直接書く代わりに、その値を `const` へ分ける。定数の型と篩の端点との依存が循環すれば断り、宣言収集・定数評価・別名展開の順序を試作で確認する。

空・片側の省略・逆転の扱いは独立の判断である。全域の区間 `Integer[-9223372036854775808..9223372036854775807]` を受理して別表現として保つ／通常のIntegerへ正規化する／冗長として拒否する、もL18で独立に選ぶ。推すのは受理してIntegerへ正規化する案である。表現だけが違う全域型を増やさず、構造の等号と不変な型引数を予測しやすくする（原則4・5）。推す案は、両端を必須にし、`lo > hi` と Integer の値域外の端点はエラー、一点 `lo = hi` は受理、公開の空区間型は入れない、である。解析領域の `normalize` は値域との交差と Bottom 化を行うが、型注釈の誤記を黙って補正する規則としては使わない。端点省略を認める案は非負整数を簡潔に書ける利点があり、L03 で別に選ぶ。

別名は既存の展開規則に従い、名前の違いで別の型にはしない。`type Month = Integer[1..12]` と同じ範囲の別名は等しい。区間の端点を確定した後の構造で等号を判定し、任意の述語の論理同値を型の等号にしない。

構文・フォーマッタ・診断・文書の作業は基本案の表層の欄に含む。省略形・半開区間・一般述語を重ねる追加費用は未確定である。

### 3.4 測定の判断案

原則の構文基準を満たしたと主張するには測定が要る。`tools/syntax-measure/` の既存の grammar-check は候補の型構文と意味をそのまま検査できないため、まず候補用の文法・課題を用意する。`Integer[lo..hi]` と `Integer in lo..hi` を第一の比較とし、波括弧の述語形式は後の範囲まで比較する場合に加える。

短い予備測定は、生成・境界の変更・エラーの修正・別名・入れ子の List/Result・動的検査の6課題、2候補、各2試行を候補とする。同じ参照の文書と診断情報量に揃え、初回構文誤り・一回の修正成功に加え、上端を含める意味と期待結果の達成を別に採点する。この24試行だけで小さな差を確定しない。既存の第一段階の道具だけでは型と期待結果の成功率を測れないため、課題の手動採点か意味検査の追加が必要である。

準備は処理系等4〜8時間の見込み（実測ではない）。LLM 呼出しの時間・料金は不明で、少数の試行から見積もる。測定を行うかは設計者に問う。**本担当は LLM を呼ぶ測定を実施していない。** 測定を見送る場合は、暫定案を成功率が確認済みの構文として扱わない。

## 4. 術語

| 候補 | 用例・出典（取得日2026-10-30） | 推す扱い |
|---|---|---|
| 篩型（refinement type） | [Erg の日本語公式文書](https://erg-lang.org/the-erg-book/JA/type/12_refinement.html) は「篩型、ふるいがた」を用いる。京都大学の研究紹介にも検索結果で同表記を確認したが、本文の再取得は502で失敗した | **総称として継続する**。現行の TODO の呼び名とも一致する（原則4・5）。Erg の個々の部分型の例の正しさを本案の根拠にはしない |
| 区間型（interval type）／整数の区間の型 | Erg の同文書は「区間型」を篩型の一種として扱う | 今回の範囲の説明には「整数の区間の型」を推す。「区間型」を正式な略称にするかは設計者に選んでもらう |
| 部分範囲型（subrange type） | [Embarcadero の日本語公式文書「単純型（Delphi）」](https://docwiki.embarcadero.com/RADStudio/Athens/ja/%E5%8D%98%E7%B4%94%E5%9E%8B%EF%BC%88Delphi%EF%BC%89) の検索で本文の「部分範囲型」を確認。直接 open は403。英語の原語は Free Pascal・Nim の上記一次資料で確認 | 数値区間には適合する対案。ただし将来の一般述語の総称には使わない |
| 精緻型・詳細化型 | 今回の一次資料の調査では、これらの訳が篩型より定着している根拠を確認できなかった | 未確認。新しい正式名称として導入しない |
| 部分型（subtype）・反変・共変 | F* の refinement subtyping、SB と現行の包含の記述に対応する | 規則の説明に用い、実装時に用語集へ定義と該当章を加える。現行の「型にサブタイピングはない」という文も実装に合わせて改める |

次の語も、正式な術語にする前に設計者が選ぶ。本文では読み取りやすい説明語と現行の「所属」を用い、新しい用語集の項目として確定しない。

| 対象 | 原語・他言語と日本語の用例（取得日2026-10-30） | 選べる候補と推す案 |
|---|---|---|
| 篩を付ける前の型 | Rustの[pattern typesの追跡課題](https://github.com/rust-lang/rust/issues/123646)は `base type` と書く。日本語の[Microsoft C#列挙型の文書](https://learn.microsoft.com/ja-jp/dotnet/csharp/language-reference/builtin-types/enum)には「基になる型」の用例がある。ただし原語はunderlying typeで、篩型の同義語と確認できた例ではない | **説明では「篩を付ける前の型」**、術語なら原語のbase type、訳すなら「基になる型」を候補とする。「基の型」「基底型」が篩型の訳として定着しているかは未確認で、設計者に選んでもらう |
| 値が区間を満たすことを示す条件 | [F*のRefinement subtyping](https://fstar-lang.org/tutorial/book/part1/part1_getting_off_the_ground.html#refinement-subtyping)は、導入で述語がtrueであることの証明を要求する。日本語の「所属」は現行用語集の「被覆」「構造上の包含」と01-12のV-Checkedに用例がある | **「区間への所属を確かめる条件」**という説明にする。「所属義務」は定着した用例を確認できず、術語として採らない。別の術語を選ぶなら出典を追加する |
| 新しい型の有向関係 | F*は `refinement subtyping`、Liquid Haskellは `subtype` と書く。日本語の[京都大学・五十嵐の講義資料](https://www.fos.kuis.kyoto-u.ac.jp/~igarashi/class/sf07w/resume7.pdf)の検索結果に「部分型(subtype)」と代用可能性の説明がある。PDF本文の再取得はタイムアウトしたため、用例の確認範囲は検索結果に限る | **「部分型関係」**を推す。対案は「型の包含」と原語subtyping。「包含」単独では現行用語集の「エフェクトの包含」「構造上の包含」と区別できないため用いない。数学上の区間どうしには「区間の包含」を使う |

Q09で総称・今回の呼び名・上の説明語を選ぶ。日本語の用例があることは、訳語の普及度や各言語の意味が一致する証拠ではない。

「範囲」は既に操作対象の scope を意味するので、整数の篩を無指定に「範囲」と略さない。新概念の用語集の変更は本担当の範囲外である。用語の選択の費用は基本案の文書作業に含む。訳語の普及の程度は今回の用例だけからは断定しない。

## 5. 値の導入と型の判定

### 5.1 導入の規則

| 入口 | 推す規則 | 必要な証拠と残る作業 |
|---|---|---|
| 整数リテラル・直接負号を付けた整数リテラル | 期待する区間への所属を静的に判定する。期待がなければ従来の Integer を推論する | `V_Const` は維持し、同じ整数定数に篩を付ける所属の葉の規則を追加する。`Const.type` を全件単点区間へ変えない |
| `const` の宣言 | `const defaultPort: Port = 443` を受理する。既存の定数式を正常に評価して所属を確かめる | 現行01-06「定数の型」の「定数式の型は宣言の型と等しい」から、篩を要求する定数については評価結果の所属を検査する規則へ変わる（L17）。評価済みの同じ定数と、出力コアの定数の一致を要する。途中のあふれを定数評価で断る現行規則を使う |
| 普通の Integer の定数参照 | 直接の `const` の値を所属検査できる案を推す。任意の純粋関数や局所の bind の値を定数として実行しない | 定数依存の循環、予算超過の診断、所属を付ける出現の記録が要る |
| `bind x: Port <- e` | e に既に篩があれば部分型関係を検査し、リテラル等なら所属を検査する。未知の Integer は注釈だけでは狭めない | `Flow` と式の所属判定を区別する。型 `Integer <= Port` を一般には認めない |
| 関数の引数・結果 | 呼出し元は引数の部分型関係を検査し、関数の本体は全ての return と通常の末尾の結果を宣言型へ検査する | 関数の本体の解析結果を公開署名へ勝手に追加しない。通常の引数の宣言型は本体内で利用できる |
| 明示した動的検査の成功 | `Result` の同じ Ok の値が要求区間を満たす | 検査・結果の生成・脱糖・組み込みの契約・実行の一致を接続する |
| 旧 `CheckedInteger` の射影 | 裸の型は任意の端点を含むので `Range.value` を無条件に Port にしない | 当面は値を取り出し新 API で検査する。旧局所解析の由来からの無検査変換は追加案 |
| 算術・比較 | 篩を忘れて通常のInteger として既存の演算を行う。算術結果の静的な型は通常の Integer | オペランド型の現行の `Equal` をそのまま使うと `p + 1` も断るので、演算の入力で篩を付ける前の型への包含を明示して作る。結果の再導入は基本案に含めない |
| `if`・`match` | 枝が返す既存の篩型を合流する。条件の事実から変数の型を狭めない | `if 1 <= n and n <= 65535 then n` だけでは Port にしない。必要なら新 API を使う |

負号の扱いは現行01-12「名前とリテラル」に揃える。`-5` と `(-5)` は負の定数への所属を検査できるが、`-(5)` は一般の負号の組み込み呼び出しである。Aではその結果から篩を導入せず、`bind n: Integer[-10..0] <- -(5)` は拒否する案である（未実行、L05）。Bを選ぶ場合は一般の負号の結果の規則で扱う。

全域の区間はL18の推す案では通常のIntegerへ正規化し、その後の等号を構造で比べる。部分区間の値をIntegerとして使う向きは値を変えない。相互の部分型関係から、正規化前の任意の型の構造の等号を導く一般補題は置かない。

### 5.2 動的入力の API の選択肢

| 案 | 利点と費用 | 判断 |
|---|---|---|
| 既存 `checkInteger` の成功型を篩に変える | 名前を増やさずに済むが、保存した端点の射影と既存の成功型を壊す。動的端点は固定の返り型にできない | 推さない |
| 新しい `refineInteger(minimum, maximum, value)` から、固定引数を読み取って成功型を選ぶ | 呼出しだけから型を推論できる。端点を型別名と二重記述し、直接呼出し・定数の認定と間接呼出しの差が増える | 対案。原則5と生成時の誤りを比較する |
| **期待型を使う `Range.checkRefined(value)`** | 別名の端点を一度だけ書ける。期待する成功型が決まらなければ注釈を求める。標準宣言の型引数の認定と端点の受け渡しが必要 | **推す**（原則2・4・5）。新しい検査の名前は最終決定前の案 |
| `checkRefined[Port](value)` | 対象が明示されるが、現在は呼出しに型引数を書く構文がない | 今回は増やさない |

推す API は、純粋で、具体的な Integer の閉区間型へだけ具体化できる標準宣言として認定する。全域区間を通常のIntegerへ正規化するL18の案を採る場合、確定したIntegerも全域区間として認定し、最小値・最大値は整数の種類の表から得る。期待型の `Result[Integer, Range.RangeError]` では検査は必ずOkとなるが、対象が未確定の型変数を自動で全域にする規則は加えない。clamp相当も同じ認定を使う。普通の無制約の `function[T](value: Integer) -> Result[T, RangeError]` を利用者が実装できるという意味ではない。通常の型引数の列と組み込みの `admits` 相当の条件を使うか、篩用の署名表の記述を使うかは第9節の試作で決める。

脱糖は、確定した区間の二端点を内部の検査へ渡す。実行本体は比較だけで検査し、成功時に入力と同じ Integer を返す。型引数の区間と実行時に検査する端点の一致をコア検査・交換・組み込み表で確かめる。端点を実行時まで復元できない型消去をしてから、期待型を信頼して整数を返す実装にはしない。原始演算を演算ごとの構成子として増やさず、標準の純粋な組み込みの表の項目として追加する。

`bind checked: Result[Port, Range.RangeError] <- Range.checkRefined(value: input)`、宣言済みの結果型を持つラッパー、具体型の関数値の注釈を入口とする。引数の中・パイプ・レコード欄などの式位置による制限は設けない案である。ただしtry・mapError等を通した期待型の接続は現行の新APIで確認できたものではなく、5.4・L20の独立した判断とする。必要な期待型を伝えられない実装になった場合は、制限として設計者に戻す。Scope の局所由来の位置制限を新 API へ転用する理由はない。

成功は同じ整数、失敗は `RangeError.OutOfRange(lo, hi, input)` とする案である。空・逆転した型を公開しないため、新 API の正常な具体化から `InvalidBounds` は出ない。旧 API の RangeError と共有しても、旧コンストラクタを削除しない。明示的な Result の検査は範囲外のリテラルでも Error を返す設計とし、直接 Port に置く静的誤りと区別する。

### 5.3 証明できない場合の処置と診断

選択肢は、静的に拒否する、実行時の検査を自動挿入する、注釈を信頼して通す、の三つである。**拒否し、明示した検査へ案内する案を推す**（原則1・2・4）。自動挿入では、関数の戻り型を Result へ変えるのか、実行時エラーを増やすのかが見えなくなる。注釈の信頼だけでは未検査の値から契約を作れてしまう。

診断は「実際の値が必ず範囲外」と「所属を確認する証拠がない」を分ける。前者はリテラルと期待区間の両方、後者は実際の型・期待型・契約の宣言位置を示し、`Range.checkRefined` の Result の型注釈と Ok/Error の処理を案内する。狭い区間から広い区間へ渡す場合と、算術で篩を忘れた場合も理由を区別する。未知から具体的な反例の実行を捏造しない。

型注釈のない `bind n <- 443` は Integer であり、後で Port の位置に使うだけで局所の n の型を勝手に狭めない。`bind n: Port <- 443`、`const n: Port = 443`、または明示検査を案内する。この制限はL05の独立の判断とする。

以上の費用は基本案へ含む。旧 API からの無検査導入は Lean 8〜20時間・処理系等8〜16時間の追加の見込み（実測ではない）であり、旧成功値の関係を Release へつなぐ難しさは未試作である。

### 5.4 try・パイプ・Result.mapErrorを通した期待型

現行の推論は、式を読む呼出しへ期待型を渡す方式だけで動いているわけではない。[generate.rs](../../../crates/benitoite/src/typeck/generate.rs)の `bind_stmt`（1504行）は、右辺を `ctx.expr` で読んでから注釈へのFlowを置く。関数のreturnも式を読んでから宣言型へのFlowを置く。したがって、新APIを式の生成時点で直ちに具体化する実装では、外側の注釈がまだ見えないことがある。解く型変数を共有し、制約の情報を使い切った後で対象型を認定する接続が必要である。

| 書き方 | 現行ソースで確かめた接続 | 新APIへの帰結・残る作業 |
|---|---|---|
| `bind port: Port <- try check(...)`、`... or return` | [effects/mod.rs](../../../crates/benitoite/src/typeck/effects/mod.rs):82は入力targetと成功値resultを別の変数でTry制約へ置く。[effects/special.rs](../../../crates/benitoite/src/typeck/effects/special.rs):103のsolve_tryはResultの成功型とresultをunifyする | 外側のPortと成功型Tを結ぶ経路はある。or returnが結ぶエラー型は囲む関数のものと同じだが、囲むResultの成功型だけから入力の成功型を決める規則ではない。値の注釈や後の利用と結ばれなければ対象の注釈が要る |
| `... or die` | 同じ成功型とのunifyを使う。return用の戻り値の条件は使わず、Process.Exitの効果と、Resultならエラー型のShowの制約を追加する | 成功値の期待型への経路はor returnと共通。停止の処置を許すことと新APIの対象認定は別であり、L20へ依存する。RangeErrorのShowは既存実装を使える |
| `try check(...) \|> Result.mapError(r: _, f: lambda(error) ...) or return` | [generate.rs](../../../crates/benitoite/src/typeck/generate.rs):1358のpipeは通常の呼出しへ接続する。[Result.bnt](../../../crates/benitoite/src/prelude/stdlib/Result.bnt):27のmapErrorは `Result[T,X] -> Result[T,Y]` で成功型Tを共有する | Tを保ったままエラー型を変えられる。tryはパイプ全体の外へ置く。穴が作るラムダの固定引数の中にtryを置いて別のreturn境界を作る形とは区別する |
| `bind r: Result[Port,E] <- Result.mapError(r: check(...), f: ...)` | 呼出しの具体化した型変数、戻り値へのFlow、不変なResult型引数の等号がTを結ぶ。[solve.rs](../../../crates/benitoite/src/typeck/solve.rs):1460以降は呼出し・Flow・Tryを再訪して情報を使う | 外側から得たTを新APIの認定時にも読む必要がある。型クラスや新しいadmissionの解決を既存の順序へ加える部分は試作する |

[言語リファレンスのResultの節](../../reference/benitoite.md#9-errors-option-result-and-try)は、再利用する関数にはor return、入口で終了してよい場合にはor dieを明示し、エラー型が違う場合はmapErrorのパイプを使う形を示す。この慣用の形でも型の注釈を一段余計に要求しない案を推す（原則4・5・6）。これはScopeの局所解析がtryで由来を忘れる規則とは別の、型の制約の接続である。

L20の選択肢は、(1)これらの経路で対象が確定した後まで新APIの認定を遅らせて受理する、(2)内側にResultの型注釈を必須にする、であり、(1)を推す。型もResult/Optionの外形も未確定のままなら、無条件に通さず注釈を求める。認定が型の既定値や登録順に先回りしないことをP3の受け入れ条件にする。費用は13.1の期待型・認定の余裕へ含め、未実装の成功を断定しない。

既存の型変数の接続の確認として、失敗だけを返す仮の `choose[T] -> Result[T,String]` を用い、素のtry・or return・or die・mapErrorのパイプ・引数内のmapErrorの5経路は、外側のIntegerの注釈を持つ0.0.13のcheckを通った。これは新APIの篩の認定・成功値の所属の確認ではない。

## 6. 型推論への組み込み

### 6.1 現在の接点と部分型関係を使う位置

現行の [infer.rs](../../../crates/benitoite/src/typeck/infer.rs) の `ITy` は型変数・構成子・関数・型パラメータ・高カインドの適用等を持ち、`Constraint::Equal` と `Constraint::Flow` を分けている。[generate.rs](../../../crates/benitoite/src/typeck/generate.rs) の `flow` は式全体を保存せず、span・related・priorityと、整数リテラルの字面 `int_literal` を制約の理由へ保存する（generate.rs:36）。字面は現在、Floatを期待した場合の修正案に使う（solve.rs:1282）。篩の導入に必要な式の認定・証拠を別に持つ必要がある。[solve.rs](../../../crates/benitoite/src/typeck/solve.rs) の `equal` は型引数と範囲添字の構造を一致させ、`flow_inner` は現在、関数の引数・結果を `equal`、潜在効果だけを被覆で照合する。型変数どうしの Flow は保留する。最後の腕は既知の非関数型どうしに限らず、Varと非関数型の組も `equal(b, a)` へ戻して直ちにbindする（solve.rs:854）。

推す変更は、確定型と `ITy` に篩の記述を持たせ、等号は構造、有向の流れ込みは部分型関係、とすることである。整数の流れ込みは区間の包含で、関数は位置ごとの名前と個数を一致させた上で引数を反変・結果を共変に比較し、最も外側の効果には現在の被覆を使う。入れ子の関数の効果は構造の等号で揃える案を推す。Failのエラー型、型クラス辞書の引数とMapのキーも不変のままにする。

| 位置 | 推す判定 |
|---|---|
| 呼出し引数、bind/shadowの注釈、return・関数の末尾、ラムダの結果 | 実際の型から要求型への部分型関係。リテラル所属は別の導入規則 |
| レコードの構築・更新の欄、リストリテラルの各要素 | 欄・要素の期待型への部分型関係 |
| if/match/handle の各結果 | 共通の結果型への部分型関係。期待型がなければ以下の合流規則 |
| resume の値 | 操作の宣言した結果型への部分型関係。節の中でも偽の篩の値を作れない |
| ラムダ引数の注釈 | 注釈自身を本体の引数型とする。ラムダ全体を期待する関数型へ渡すときは、名前付き関数と同じ反変・共変で照合する（L16） |
| 型構成子の引数、型クラス辞書の型引数、Mapのキー、Failのエラー型 | 構造の等号。部分型関係を型の等号として扱わない（L07） |
| ハンドラの操作の引数 | 操作の署名から得た型を節の環境に置く。節の注釈や本体から勝手に強めない |

現行の `Ty.Le`（Release/Typing.lean:332）と用語集の「エフェクトの包含」は、最も外側の関数の潜在効果だけを被覆で広げる。01-06「エフェクトの包含」は引数・結果の照合に被覆を使わない。これを篩の関係と一緒に再帰させると、既存の効果の規則も変わるため、次の三案をQ03の独立した行L15で選ぶ。

| 案 | 受理と互換性 | LeanとRustへの影響・費用（見込み、実測ではない） |
|---|---|---|
| F1: 篩も効果も最も外側だけ | 最外の整数の篩と最外の関数の効果だけを広げ、関数の引数・結果は等号。Integerを受ける関数をPortを受ける関数の位置へ渡すにはラッパーが要る | 逆転・WFの再帰は減る。F2比でLean4〜8時間、処理系等3〜6時間少ない見込み。`tyLe`は外側の篩を追加し、`tyJoin`は整数の凸包を追加。旧型の関係は維持できる見込み |
| F2: 篩だけ関数の入れ子へ（推す） | 関数の引数は反変、結果は共変に篩を比較し、入れ子の効果は等号。数値の契約の高階利用が広がり、篩のない旧型の効果の受理は維持する目標 | 第13節に含む。外側の被覆を許す関係と、内側の効果を等号とする関係を分け、合成・置換・正則性を証明する。Rustの再帰にも同じ区別を持たせる。`tyLe`を二関係に対応させ、`tyJoin`はまず比較可能な関数なら上側を選び、それ以外の新しい高階合流には注釈を求める。従来の、引数・結果が同じで潜在効果だけが違う関数の合流は既存の効果の和を使って保つ目標とする（L19）。任意の反変型の最大下界までは実装しない |
| F3: 篩も効果も関数の入れ子へ | 篩のない旧コードでも入れ子の潜在効果の違いを許すよう受理が広がる。List等の型引数の不変性とは別の変更である | F2にLean6〜14時間、処理系等4〜10時間追加。`tyLe`・`tyJoin`、深いFailのWF、診断の効果の相違位置・反変方向を変える。旧型全体で現行 `Ty.Le` との同値は要求できず、入れ子効果が等しい部分へ制限する条件を別に承認する必要がある |

`CoverCompat`の `Ty.LeOld` は0.0.13で被覆へ切り替える前の構造上の効果の包含を残した比較用の関係であり、新たに作る「篩を足す前の `Ty.Le`」とは区別する。F1/F2では、篩のない型で現行の最外の被覆との同値を先に示し、旧のTop原子に制限した `Ty.le_iff_leOld` へ合成する。F3ではこの合成の条件も変わる。`EffectCover`の被覆・許可の定義そのものは維持し、代入やFailの型を使う補題が新しい型でも成り立つかを確認する。入れ子への効果の適用を増やすことと、一原子による被覆の意味を変えることを混同しない。

F2でも診断には、篩の端点の相違、反変で照合する引数の方向、入れ子の潜在効果を等号で要求した位置を示す必要がある。最も外側の効果なら被覆で通ることと混同させず、同じ関数値を名前・ラムダのどちらで書いても同じ照合理由を示す。Rustの制約の理由と表層の型表示へのこの接続は基本案へ含む。

ラムダの引数の注釈だけを等号で期待型へ合わせる元の案は、F2と整合しない。`function f(x: Integer) -> Integer` は `function(x: Port) -> Integer` を求める位置へ反変で渡せるのに、同じ本体の `lambda(x: Integer)` は拒否することになる。これは未実装の案の帰結で、実行で再現したものではない。推す修正は、注釈をラムダ自身の契約として本体を検査し、その関数値全体に名前付き関数と同じ関係を使う形である。期待されるPortを根拠に本体内のIntegerをPortへ狭めることはしない。L16は、等号を残す制限を採るかも独立に選べる問いとする。

### 6.2 合流と型変数

合流の選択肢は、区間の凸包、すぐに Integer へ忘れる、共通の期待型がなければ拒否する、である。**同じ整数型に付いた既知の区間は凸包**を推す（原則1・4・6）。例えば `Integer[1..10]` と `Integer[20..30]` の結果は `Integer[1..30]` となり、間の11〜19が入りうることを利用者向けに説明する。普通の Integer が一方にあれば合流は Integer、異なる幅の自動変換はしない。

リテラルを全て単点型として推論する案は最小の区間を得やすいが、`[1,2]` の要素型や辞書選択まで変わる。基本案は、期待型のないリテラルを従来どおり Integer とする。`if flag then 80 else 443 end if` を Port として使いたければ外側の注釈を枝へ伝えて所属を検査する。既に型が確定した Integer の局所変数の値を、その伝播で狭めることはしない。

`flow_inner` の「最初の既知の区間を未確定変数へ bind する」だけの改造では、二つの枝の順で受理が変わるおそれがある。これは現行の篩型で再現した反例ではなく、未実装の方式についての机上の懸念である。実装案では、型の形の単一化と整数の下限・上限の制約を分け、同じ型変数へ流入する下限の区間を合流し、要求側の上限すべてへの包含を最後に確認する。制約の登録順で端点を決めない。

不変な位置で要求される型引数は正確に固定する。例えば `List[Port]` の要素を表す変数を Port へ固定することは、元の List[Integer] の要素に証拠なしで Port を付けることとは異なる。期待型に合わせて新しいリストを構築する各要素を検査するのである。戻り値だけから、未検査の引数の実際の型を書き換えない。

一般の区間不等式や高カインド型まで含めた主要型の存在・完全な推論は約束しない。型変数の正確な位置と部分型関係を使う位置を規則表にし、一意に具体化できない検査対象や関数の合流には注釈を求める。既存の未使用の空リスト等の未確定変数の扱いを一律に厳しくしない。追加した「区間への所属を確かめる条件」がある変数だけを未解決の誤りとして扱う。

### 6.3 一般化・具体化・型構成子・型クラス

現行の01-06は、トップレベルの宣言した型パラメータを使うたびに具体化し、局所の bind・引数・パターン変数は多相にしない。篩でもこれを保つ。型引数に `Port` を具体化して `identity` や `List[T]` へ渡すことは認める。端点の未知変数を自動で量化する一般化や、利用者が範囲変数を宣言する構文は増やさない。

`List`・`Result`・レコード・`Reference`・`Lazy`等の型引数、Mapのキー、型クラス辞書の型引数、Failのエラー型は**不変**を推す。`List[Port] <= List[Integer]` は基本案では成り立たない。リテラルの要素を Integer へ広げて `List[Integer]` を新しく構築することや、`List.map` で値を広げることはできる。Reference を共変にすると、広い型の書込みから狭い型の読出しを偽造できるので、不変性は保つ（原則1）。不変な List の使いにくさもL07として設計者に示す。

演算・書式付き補間、組み込みの `equality`・`key`・`ordered` は、通常のInteger の表現と同じ比較・表示を使えるようにする案である。型クラスは辞書自体を等号で Integer の辞書へ読み替えない。標準の Show・Order は、入力を Integer へ広げて既存の実装を呼ぶ通常のアダプタの辞書を用意する案を推す。Semigroup・Monoid のように結果を T に戻す実装を無条件に引き継ぐと篩を破るため、全型クラスの実装を篩を付ける前の型から継承はしない。利用者の型クラスは対象型との通常の一致で解決する。

ここまでの処理系と辞書・Surface の接続費用は基本案に含む。複雑な型変数の上下限と辞書生成で幅が大きい。可変セル・空リスト・高階関数・Result の try を含む短い例で、推論順と期待型の有無を試作する必要がある。

## 7. 既存機能との関係

### 7.1 検査済みの包みと標準署名

| 対象 | 推す扱いと理由 | 対案・費用・不確かさ |
|---|---|---|
| `CheckedInteger` | 残す。実行時の両端と値を保存し、同じ型の値でも端点が違う。固定の条件を型に残す新 API と用途が異なる（原則5の重複の理由） | 篩型へ置換すると端点の射影や動的端点を失う。既存スクリプトの利用量の棚卸しは実装計画で必要 |
| `CheckedLength[T]` | 残す。実長・元のリスト・動的端点を保持する | Integer の篩だけで置き換えることはできない。長さの段の費用は第2節 |
| `CheckedIndex[T]` | 残す。元リストと成功した要素を保持し、`get` に別リストを渡せない | 同じ範囲の整数だけではこの保証を代替しない |
| `Benitoite.Unofficial.NonEmptyList` の `NonEmptyList` | 残す。既存の head/tail/map の契約を保つ | 長さを型へ導入しても API と表現の移行は別判断 |
| 既存の Integer を受ける標準署名 | 今回は要求を強めない。篩の値は Integer へ広げて渡せる | 一括で Port 等を要求すると旧コードが断られる。原則2に従い、その変更を選ぶ版で移行を示す |

新しい型を同じ VM の整数として表せることと、旧 CheckedInteger のレコードを整数へ読み替えられることは違う。旧 Range の公開境界は `@opaque` な通常の record であり、Lean の `.opaque` の範囲付き値ではない。[Range.bnt](../../../crates/benitoite/src/prelude/stdlib/Range.bnt)、01-12「区間解析のRangeの評価規則と小モデル」（1368行の `.data owner []` と `.opaque` の区別）、07-04「01-12との対応」の `@opaque` の属性・公開境界の行が根拠である。

### 7.2 範囲付きのエフェクトと値型の部分型

整数区間の包含、操作対象の範囲の被覆、型の等号を分ける。`Port <= Integer` ができても `Scope.PathIn[R] <= Scope.PathIn[S]` や `Http.RequestIn[R] <= Http.RequestIn[S]` は追加しない。既存の範囲添字は不変で、明示した拡大とその対象の不変条件を使う。両者が共有できるのは、構造の等号と有向の受理を分ける枠、型の不変条件を使う考え方、診断の位置等である。

したがって篩だけから `Http.Connect[host, portRange]` を自動で生成しない。対象と効果の結合は既存の Scope/Http の IO 契約が担う。整数の篩が情報フロー制御（information-flow control）、非機密化（declassification）、エンドースメント（endorsement）を提供することもない。

TODO-308 の「検査済みの型であることを根拠に射影する」は、型の不変条件を利用する点では本案に近い。しかし整数の部分型を作るだけで位置の記録や ScopeAccept の規則が直るわけではない。第10節で別に判断する。既存署名を維持する費用は基本案に含み、射影の位置制限の除去は含めていない。

## 8. Lean の骨格と主な証明の組み直し

### 8.1 専用構成子・一般の篩の記述・既存構成子の添字

| 骨格 | 利点 | 費用と不確かさ | 推す判断 |
|---|---|---|---|
| SB の `Ty.range I` | 今回の意味と置換が単純。小モデルの結果を移しやすい | 六幅、長さ、他の条件を別の構成子として足すと、型の順序・正規化・置換・網羅性の全場合分けを繰り返す | 試作の比較基準とする |
| `Ty.refined base spec` と、篩の種類・端点項・規則の表 | 同じ構成子の中で、整数区間から長さや条件の種類を増やせる。所属・包含・検査の契約を一度分離できる | 無条件の任意述語や任意の篩を付ける前の型まで許すと、整形式と判定が重くなる。今回は対応する表の項目と閉じた端点に限定する必要がある | 添字の形との比較対象とする。長さ等で利点が確かめられれば採る（原則4・5） |
| 既存の `Ty.base ι` を `Ty.base ι spec` にする等の添字の形 | 構成子の数を増やさず、0.0.13の `Ty.opaque o ix` と同様に、既存の構成子へ情報を足せる。Rustも `ITy::Con(TyCon, Vec<ITy>, RangeIndex)` の前例がある | 全ての `.base` の構築・照合・順序・交換に添字を渡す作業は残る。長さにはList等にも対応欄が要る。既存 `RangeIndex` は操作対象用なので、数値篩を無区別に混ぜず別の種類と整形式を設計する | **先に試す案へ変更**。場合分けの負担が小さいかP1で確認し、未確認の優位は断定しない |
| 最終の値依存型・任意述語を今回すべて定義・証明 | 後の置換の変更を先取りできる可能性 | 今回使わない依存する文脈・値の置換まで Release 全体へ広がる。自作ソルバや一般述語を今回除く決定にも合わない | 推さない |

三案で共通にするのは、所属・部分型関係・整形式と規則表の契約である。一般refined案を選ぶ場合の分担は次であり、構成子を先に確定したものではない。名前は内部設計の説明用で、公開 API 名の決定ではない。

```text
Ty.refined(base, spec)
spec = predicate identifier + arguments
index term = literal | self | bound variable | application(operator identifier, arguments)

table entry = argument sorts / admissible base / meaning / decidable check
             / soundness / renaming and substitution laws

stage1 WellFormed(spec, base):
  base is Integer; spec is a closed integer interval;
  no free value variable; endpoints are representable; lower <= upper
```

一般refined案で型を `Ty` として持つ場合、今回の整形式は `refined (refined …) …`、関数・Reference・Listを対象とするrefinedを拒否する（L02）。後の長さでは `List[T]` を対象にできるが、今回の受理ではない。添字案も数値用の添字をInteger以外へ付けることを断り、対象と篩の種類の対応を整形式で確認する。全域の区間は受理後にIntegerへ正規化する案（L18）とし、正規化・型代入・構造の等号との交換を三案で比較する。端点項の self と外の値の番号を区別し、型・行の置換と、値の項の移動・置換を別の操作として設計する。新しい比較や算術、長さを読む操作は identifier の表の項目として足す。現在の部分型判定は閉じた整数区間の端点比較だけで行い、表に未登録の項目や自由な値変数のある記述を受理しない。

表は任意の Prop を信用して登録する入口にしない。意味を実装した各項目に、判定の健全性・移動・置換との対応の証明を要求する。今回の表は有限で閉じており、未実装の規則に「仮定として健全」を置かない。一般述語の探索・証明書・自作ソルバの実装は docs/todo の TODO-311 の段へ残す。

この骨格でも、後で自由な値変数を許せば、関数の束縛、型を含むエフェクト、ストア・継続の型の文脈を拡張する作業は残る。「今回の証明を一度書けば値依存の段で主定理を触らない」とは見込まない。先に固定するのは、型の構成子・条件の構文・所属の意味・移動と置換の境界であり、後の意味の追加まで証明したことにしない。

### 8.2 0.0.12 の再利用と import の順序

[Interval/Domain.lean](../../../formal/Benitoite/Interval/Domain.lean) の `Subset`・`subset_iff`・`mem_bounds`・`meet`・`join`・`join_least` は再利用候補である。ただし同ファイルは `Release.Syntax` を import する。`Release.Types` からそのまま import すると依存が循環するため、数値の種類・上下限・閉区間の純粋な領域を Release の型より下の共有モジュールへ分け、`IntKind.type/ofType` の型との対応を上の層に残す案を推す。Rust も現在は区間の領域が `typeck` 内部に閉じているので、確定型が依存できる小さな共通の数値表現へ分ける必要がある。

`Interval/Arithmetic` の正常区間と失敗可能性の区別、`Checked/Range` の成功時の同じ値と端点、`Checked/ListIndex` 等の小モデルは後の規則の根拠になる。`Interval/Analyze`・`Budget`・`Flow` 全体を型判定へ持ち込まない。既存の A1 の評価関係に関する健全性を、Release の型導入の規則として無条件に引用しない。

警告解析が新しい篩の型を見ても、通常のIntegerとして対象を認定できるようにする必要がある。現在のRustの`IntKind::of_type`（interval/domain.rs:44）は `Ty::Con(TyCon::Builtin(id), args, _)` の第三欄を無視して整数を認定している。別のrefined構成子なら対象から落ちうる一方、既存のConへの添字なら認定自体は残る可能性がある。ただし添字を無視して型の証拠まで消してよいことにはならず、三案で確認する。基本案では、警告用の入力へ篩を付ける前の型を渡し、関数引数は従来どおりTopから始める。型にある狭い区間を警告の精度向上にも利用する変更は別に証明する。新APIの成功要約を警告解析へ追加することも必須にはしない。型の受理と旧警告解析の結果を相互に依存させない。

### 8.3 部分型・逆転・置換

`Ty.Le` は、型の構造に沿う有限の判定と対応させる。整数区間の包含と篩を付ける前の型への忘却、同じ契約名の関数の反変・共変、最外の効果の被覆を扱う。F2では内部の関係が潜在効果を等号で比べることを明示する。SB の反射・推移の閉包をそのまま探索する判定器にはしない。型構成子の引数は不変なので、Reference などの既存の逆転は多くを維持できる。

| 現行の証明群 | 組み直しの方針 |
|---|---|
| `Release/Lemmas/Basic` の `eq_of_not_fn`・`eq_of_not_fn_left` | 一般命題を削り、篩と整数を除く不変な最外構成子の補題、整数の所属・包含の逆転へ分ける。整形式でない `refined base spec` も生の構文には現れうるため、必要な整形式の前提を明示する |
| `fn_left`・`fn_right`・`fn_fn'` | 名前と個数は一致、引数列は逆向きの包含、結果は順向きの包含、最外の効果は被覆、入れ子の効果は等号（F2）、として返す。等号で `subst` していた呼出しの証明を型付け直しへ変える |
| `inv_const`・canonical forms | `V_Const` 由来と、同じ整数への所属の葉の導入を分ける。Integer の型だけを根拠に任意の篩へ狭めない。関数やストアの場所が整数篩の値になる枝は不可能と示す |
| `TypeRegularity` の `Ty.Le.wf`・`wf_rev` | 最外の `LatentWF` だけでは入れ子の関数の Fail の範囲を得られない。必要な内部の整形式を再帰して要求する補助契約へ改め、V_Sub/C_Sub の既存の移動先の WF を利用する。主定理へ新しい外部条件として押し出さない |
| `SubstTyping`・`Rename` | 同じ型の値の置換という言明を維持する。定数端点なので値の置換は型の端点を変えない。篩の葉と包含の保存を加える |
| `TySubstMain`・型/行の代入 | refinedが持つ型、Fail の内部、正規化・順序・移動との交換までを同じ骨格で追加する。条件が閉じていることを補題として使う |
| `Preservation`・`PresMain`・ストア・継続・辞書 | β簡約では呼出し側の引数を定義側へ広げて代入し、結果を呼出し側へ広げる。Reference は不変、継続の入力と節の結果は包含の向きを分ける。δと操作の実応答にも新しい結果型が付くことが必要 |
| `CoverCompat` 等の旧型との互換補題 | `LatentTopAtoms` だけでは新しい値の部分型を旧 `Ty.LeOld` へ戻せない可能性がある。篩を持たない旧型の部分に制限した互換命題へ直す。旧の効果の同値を全新型へ拡張したことにしない |

SB が挙げた Release 69・Surface 15 は、当時の直接参照の集合である。S01では同じ二つのパターン `Ty\.Le([^A-Za-z0-9_]|$)` と `eq_of_not_fn|\.fn_left|\.fn_right|\.fn_fn|Ty\.fn\.injEq` を、現行の全 `.lean` ファイルへ読み取りだけで当てた。SB の `inventory.py` のコメント除去と宣言への対応付けを利用し、git呼出しとファイル出力は実行していない。RV-S01の独立した再集計も下表と一致したと報告されている。S01bでは件数を再集計せず、関係する定義と呼出しを読み直した。

| 範囲 | Ty.Leを直接参照する定理 | 等号等の補題を参照する定理 | 重複を除く和集合 |
|---|---:|---:|---:|
| Release | 56 | 30 | **75** |
| Surface | 20 | 2 | **20** |
| Core | 18 | 9 | 24 |

定理・補題の宣言位置で重複を除き、コメントは数えない。これは直接の文字列参照であり、推移的な依存解析でも修正必須数でもない。型の構成子への場合分け、型の順序、有限支持、交換形式などは追加で点検する。Core は別の型体系なので、24件を一律に今回の変更へ加えない。

### 8.4 主な定理の前提と結論

| 定理群 | 前提・結論の変更の要否の案 | 証明・定義の変更と停止条件 |
|---|---|---|
| `Release.Theorems.progress` | 公開の前提と「最終状態または遷移できる」という結論の外形は変更不要の見込み | 状態の型付けと canonical forms を拡張する。最終状態には現行も実行時エラーを含むので、あふれが消えるという定理へ読み替えない |
| `Release.Theorems.preservation`（主定理） | 公開の外部前提を増やさず、状態の型付けが保存される外形を維持する見込み | 同じ整数の所属、関数・ストア・継続・δの型付けを再証明する。`preservationE` はその証明が使う内部の補題で、同じ末尾の結果型・許容効果を保つ。主定理と区別する |
| `Release.Theorems.step_sound`（主定理） | 型付き状態で実行器 `step` の結果が関係 `Step` の遷移である外形とoracle・解放・freshの外部条件を維持する見込み | `StateTy` と新検査を扱うδの契約が変わるため、新しい型付き入力での対応を接続する。純粋検査だけを理由にoracleの観測の条件は変えない |
| `effect_soundness`・`effect_soundness_noLamNames`（ともに主定理） | 空効果から事象・未処理操作が出ない、という結論を維持する見込み | Failの不変な一致と従来の被覆の方向を保つ。後者はラムダ名の整形式を外部条件から除いた言明も保つ。実行時の権限制御を新たに保証しない |
| `reachable_target_sound`・`surface_target_sound` | `CoreAssumptions` と `TargetAgreement` の分離および対象の結論を維持する見込み | 0.0.13で増えた主定理も母集団に含む。新しい純粋な整数検査に IO の対象の仮定は要らない |
| `Surface.desugar_typed`・`HasTypeQ.desugar` | 表層で付いた結果型と効果をコアでも保つ。同じ外形を維持する見込み | 篩を型からすべて消し Integer の型付けだけを結論しては足りない。実行時の表現から証拠を消しても、コアの型と導出には所属を残す |
| 表層検査器の健全性 | 合格した式・ブロック等に同じ型付けが存在する結論を維持する見込み | [Surface/FiniteTools](../../../formal/Benitoite/Surface/FiniteTools.lean) の `tyLe`・`tyJoin`、check/accept、有限支持・正規化を更新する |
| 網羅性・非選択の健全性 | 手順が網羅的と判定すれば実値を覆う、という一方向の結論と構成子一覧の前提を維持する見込み | 基本案は通常のIntegerの領域で保守的に判定する。型を付けた値から通常の整数の値への所属を示す。`Coverage.erase` に篩の条件を保存し、等号から逆向きに篩の所属を作らない |

主定理の言明の外形を保てても、前提の中身は変更する。整数の所属の葉の規則を追加すると、`StateTy`、`Program.WellTyped`、表層の型付けと脱糖の結論が篩の値を含む。型付きの値を量化する `Builtins.Assumptions` の `delta_typed`・`io_typed`・`io_exists`・`release_exists`（`OutcomeTy`を含む）は、新しい引数・結果の型付けの導出についても要求を満たす必要がある。例えば `delta_typed` には検査成功の同じ整数が要求区間に属する証拠が要る。純粋検査だから、ほかの三欄の量化する型付けの変更を点検しなくてよい、とはしない。

この変更は、07-04冒頭のV-Checked・V-CheckedRequest・範囲の列を導入した際の「設計者が承認した前提の変更」と同じ種類である。ただし前例の同値補題の範囲は区別する。V-Checkedの導入について示したのは `release_exists_iff_old` であり、delta_typed・io_typed・io_existsの内容の同値は未証明と07-04が明記する。範囲の列の導入では、その列を持たない旧表で三欄の `*_iff_old` を示している。これらを合わせただけで、所属の葉の追加について四欄すべての同値が証明済みとはしない。**所属の葉の追加と、これらの欄が量化する内容の拡張を、Q04で設計者に承認してもらう。** 承認前に、言明の字面が同じことだけで「前提を維持した」と扱わない。

今回の四欄すべての同値は、V-Checkedの前例より強い受け入れ条件の案である。P2では代表例と証明の分け方の可否までを2〜3時間の枠で調べ、四欄すべての本番証明は13.1のReleaseの作業へ割り当てる。受け入れ条件の案は、篩を含まない旧型・旧署名・旧表へ制限したときに、整形式・型付けの規則の前提と上記四欄の内容が従来と同値となる `*_iff_old` 相当の補題を置くことである。07-04が挙げる `RangeWF` の `Ty.wf_iff_old`、`PrimRanges` の `Builtins.delta_typed_iff_old` 等を前例とする。旧型へ制限する条件は引数・結果・ストア・Failの内側まで明記し、欄全体の同値と個別の導出の保存を区別する。表をまたぐ関係を証明するために旧定義の写しや明示した埋込みが要るかはP2で確かめる。同値の成立が示せない範囲は「維持」とせず、変更の具体的な内容を再相談する。F3を選ぶ場合は篩のない型でも入れ子の効果の受理が変わるため、この受け入れ条件の変更も承認が要る。

**上表は本番の証明を通した結果ではない。Q04の承認対象を超える前提の中身の変更、外部前提の追加・結論の弱化・独自公理が必要になれば、具体的な差とともに設計者へ戻す。** `preservationE` 等の内部の補題の前提の修正を、主定理の保証の弱化と同一視しない。

網羅性を篩の区間へ正確に狭める対案では、`Month` の1〜12の腕だけで網羅とできる。基本案は保守的なInteger全域の検査とし、必要ならワイルドカードを求める。新しい完全な区間の初期領域・Inhabits・パターン束縛・反例表示までつなぐ追加は Lean 6〜16時間、処理系等6〜12時間の見込み（実測ではない）であり、L12で独立して選ぶ。現行の `Coverage.erase` の同値による転送補題を、篩を忘れる両方向の同値に流用しない。

### 8.5 Lean 先行の順序と Rust との接続

今回の型・包含・所属・型付け・脱糖・網羅性は07-04「01-12との対応」の**内側**である。字句・型名の綴り・fmt・診断文・CLIのJSONの組立てはそれだけなら外側だが、コアへ渡す型の符号化や新しい検査の受理は内側の規則と対応させる必要がある。

Lean の骨格、規則、主な証明、01-12の写し、定義・言明・仮定のレビューを先に終え、既定のビルドが sorry なしで通ってから処理系へ進む。切り替えは、篩を使わない型に旧定義が対応する補題を先に置き、各段でビルドできる形を保つ案を推す。SB の全ファイルを本番へ貼り、未証明の枝を残して先へ進む計画にはしない。

`check-formal.sh` の比較には次を追加する。型の書き出し・読み取りの形式の版の上げ、固定した端点と篩の種類、型引数の置換、標準検査の具体化をそろえる。既存の六入口と区間解析の比較を新しい一入口の成功で置き換えない。

| 接続 | 足す入力と比較するもの |
|---|---|
| 型・包含・表層検査 | 境界内/外、一点、全Integer域、逆転・値域外の拒否、包含の向き、等号との違い、関数の名前・個数・反変・共変 |
| 脱糖とコア検査 | リテラル・const・引数・結果・レコード・リスト・ジェネリクス・辞書・ハンドラ・resume。同じ結果型と効果で型が付くこと |
| 検査の表と実行 | 新 API が使う端点と型引数、同じ成功Integer、失敗時の保存入力、min64/max64で上端へ1を足さないこと。値と失敗種を独立期待値と照合する |
| 推論 | 枝・要素・引数の登録順を変えても同じ型になる例、期待型のある/ないリテラル、型変数と不変な型引数の拒否 |
| 網羅性 | 保守的な全域判定と篩の値が通常のIntegerでもあること。精度拡張を選ぶ場合は篩の端の穴とガードを追加 |
| 既存の区間解析・Scope | 新型の表現を無視して入力を欠落させないこと。警告の予算停止と型契約の受理が独立であること。外部型を含む未対応入力を黙って比較済みにしない |

これらは有限入力の比較であり、Rust/VMとLeanの全実行の一般対応の証明ではない。新しい形式化の成功と全比較の成功を分けて受け入れる。

## 9. 捨てる試作の提案

選択肢は、SB の小モデルだけを再実行する、現行本番定義を使う限定試作を行う、全本番を一度改造して工数を測る、である。**現行本番定義を使う限定試作**を推す（原則1・4）。SBで通った部分を増やすだけでは、今回の主要な未達である整形式・Fail・ストア・継続・実装の入口の負担が分からない。

| 試作 | 本番から写す範囲と確かめるもの | 能動作業の上限の案（見込み、実測ではない） |
|---|---|---:|
| P1: 共通骨格・逆転・置換 | 現行の Types・EffR・範囲添字・WF・正規化・型/行の置換を省かずに写す。専用range・一般refined・既存構成子への添字の三案を比較し、全域の正規化、refinedの入れ子・関数・Referenceを断る整形式、F2の二関係の区別を点検し、反射・推移・判定の健全性、関数の逆転、入れ子FailのWF、型/行の置換との交換を示す | Lean 3〜5時間 |
| P2: 現行の型付けとの接続 | V_Const/V_Sub/V_Lam/C_Let/C_Appと、Reference・継続・Failを使う代表的な導出を写す。所属の葉を加え、同時置換、β保存、継続へ篩の値を返すこと、誤った狭め方の不成立と、旧型・旧表での `*_iff_old` の代表例を示し、四欄すべてに拡張するための未達を記録する。四欄の同値の本番証明をこの枠だけで完成する見込みにはしない。全進行・保存を完成させたとはしない | Lean 2〜3時間 |
| P3: 表層の検査と実行時検査 | 期待するResultの成功型から区間を具体化する検査、try/or return/or die・パイプ・mapError経由の対象型の確定と認定の遅延（L20）、型変数の合流、最小のShowアダプタを紙上・小さい交換例で確認。新しい純粋検査の成功・失敗・同じ値を返す定理を一つ接続する | 処理系設計等1〜2時間 |
| P4: 結果・未達・見込みの更新 | ソース・ログのハッシュと実際に通った定理、独自公理・sorryの点検、失敗した接続と主定理への影響を整理 | 1〜2時間 |

SBの小モデルは読み取りを含め約24分だった（findings §7）。P1の3〜5時間はその実績の単純な延長ではなく、本番のEffR・範囲添字・WF・型/行置換を省かず三案を比べる未試作の上限である。最初の30〜60分で構築・整形式と旧型の対応を一案に通し、残る比較の量を測って上限を見直す。小モデルの成功を理由に5時間を使い切る必要はない。

全体は各行を合計して **7〜12時間を上限候補**とし、まず最初の2時間でP1の範囲と失敗を報告する。上限に達したら証明が通っていない箇所を残して止め、見込みを更新する。TODO-308を含める判断は、この試作にさらに全部を詰めず、所属不変条件から入口の事実を作る小試行を別枠にする。

Lean の検査は取りまとめが用意する別の機械で行う。固定ツールチェーンと本番同等のプロセスのメモリ上限を使い、個別ファイルにも `-M` を付ける。検査の実時間・待ち時間は不明であり、上表の能動時間へ推定で足さない。試作の成功を本番の formal_build や全比較の結果に引用しない。

汎用の骨格が専用rangeより大幅に重いと分かっても、未実装の述語の公理で通す解決はしない。型の構成子を一つに保ち、今回必要な閉じた区間の記述へ内部表現を狭める代案と、後の値依存で残る変更を設計者へ示す。

## 10. 相乗りの候補

次表の費用も見込み（実測ではない）であり、基本案の合計へは含めていない。項目を閉じる範囲は設計者が決める。

| docs/todoの項目 | 形式化への影響・共有する部分 | 判断と理由 | 追加費用・不確かさ |
|---|---|---|---|
| TODO-308 射影と拡大の位置制限 | 型の不変条件と関数境界の型を使う部分は共有する。しかし `ScopeLower/ScopeAccept` の記録位置、節の添字、接続定理を別に直す | **判断に試作が要る**。引数の検査済みの型を使うことは A5 の「未知への注釈を信頼する」案とは違う。原則1・2・6から検討価値があるが、全部を軽い相乗りと数えない | 最初の試作 Lean 2〜4時間。全実装の上限は未確定。試作で重い独立改造と判明すれば今回は外す |
| TODO-303 プロジェクト根等からの相対パス | 対象の領域、正規化、被覆、実行時の基準の解決と信頼条件を変更する | **推さない**。利用上の必要性は設計者が認めているが、整数の所属と骨格を共有しない。原則2・4と一つの重い項目の方針 | 未見積もり。サーバモードより前という期限を0.0.14への技術依存にしない |
| TODO-289 区間解析の精度 | 条件環境の合流で由来を保つ証明、handle外の既定操作の判断を追加 | **推さない**。今回の基本案は警告解析の出力を型導入に使わないので前提ではない（原則4） | 未見積もり。区間型があっても、既存解析へ入れるには入力の対応が別途要る |
| TODO-290 returnと外部型の比較の残り | returnの近似の追加と外部型の交換の拡張 | **全項目の相乗りは推さない**。新しい篩の戻り値が表層/コアで検査される接続は今回必須だが、既存警告解析の全returnの比較とは別である（原則1・4） | 新型の交換は基本案へ含む。既存の14件等を含む未比較範囲を閉じる費用は未確定 |
| TODO-087 Property専用実行 | seedのCLI、構造化反例、テスト実行と権限制御。専用CLIだけなら形式化の外 | **推さない**。篩から生成器を導く仕事とは項目が違い、今回の型導入の前提でもない（原則4・5） | 未見積もり。篩の生成器を後にtools/deriveへ足す際も、縮小の所属保存が必要 |
| TODO-315 E0519の表示 | 診断の文言と内部用語の整理。受理と全比較の値は変えない範囲にできる | **推す**。新しい所属診断と同じ時に表示・生成Skillを整えられる（原則3・4） | 処理系等2〜4時間。コード・理由・JSONの機械向け番号を維持し、表示の検査だけを変える前提 |
| TODO-306 節の添字の自己循環 | 複数の一貫した解からどれを選ぶかという規範とLean/Rustの推論を変える | **推さない**。整数の合流の規則と混ぜると、受理変更と反例の原因を分けにくい（原則2・4） | 未見積もり。現在の狭い解の受理は一意性の証明ではない。篩の型変数の規則で偶然選択を変えない |
| TODO-317 作業IDの除去 | コメントと一部の交換の期待値を変更。定理の意味は変えない | **推す**。今回もLeanと全比較の入力を更新するので同じ接続の区切りに置ける（原則4） | 処理系・文書等2〜6時間、Leanの点検1〜2時間。引用する全比較より前に終える |
| TODO-294 関数名admitの改名 | `Interval/Budget` の private な関数名。証明の穴ではない | **推す**。区間の共有化と同時に誤検出をなくす（原則4） | Leanの編集・点検0.5〜1時間。定義の振舞いを変えない |

TODO-308の試作では、(a)狭い引数型、(b)宣言した狭い戻り値、(c)ハンドラの節の引数、(d)呼出しの引数の中、(e)パイプ・補間・リスト要素を別々に調べる。現行の `V_Checked` / `V_CheckedRequest` と `Membership` の所属は型の不変条件の根拠になるが、局所解析の受理規則がそれを使う証明までは与えない。Scope/Httpの添字の暗黙の部分型を追加しなくても、射影と明示拡大の入口に使えるかを先に試す。

## 11. 互換性と版

選択肢は、既存の署名・リテラルの既定推論を保つ追加、標準APIを篩の契約へ一括変更、すべてのリテラルを単点型へ変える、である。**追加を推す**（原則2・4）。既存スクリプトに篩を書かない限り、新しい区間への所属の条件を課さず、通常の整数算術と実行時エラーの扱いを保つ。

ただし「機能が追加だから受理は必ず広がる」とは断定できない。型変数と合流、型クラス、関数の包含を変えるので、旧型しかない制約へ新しい既定値が影響しないことを棚卸しと回帰で確認する。Scopeの循環の解、`--deny-warnings`、標準の型クラスの解決も確認対象にする。

互換性の棚卸しには、[tools/derive](../../../tools/derive/README.md)の生成物（レコードのJSON変換、Propertyの生成器・縮小器、Show/Orderの実装）と標準の[Json.Codec](../../../crates/benitoite/src/prelude/stdlib/Json/Codec.bnt)を名指しで含める。現行Codecの `decodeInteger` は `Result[Integer, ConversionError]` を返す。`port: Port` の欄へそのまま使うと型が合わない可能性、Propertyの生成器・縮小器が範囲外を作る可能性、非対応として早期に断る可能性を分ける。これは実行していない机上の懸念で、実在する不具合の断定ではない。計画の棚卸しへ送り、宣言inventory・ハッシュ・生成規則の版、カスタムのencode/decode・生成/縮小の署名、失敗パスの保持、生成後の通常の型検査までを確認する。篩の生成を今回実装しないなら、対応外の診断とカスタム関数へ渡す方法を受け入れ条件にする。未検査の生成物を受理済みとして数えない。

0.0.13の基準である「受理が狭まれば登録」を採る。基本案が旧ソースの受理を保てた場合、破壊的変更の登録は不要という案である。既存署名を強める、旧型の推論が断る例が残る、型クラス実装の対象を狭める、未確定型の従来の受理を断る、警告追加で `--deny-warnings` の受理が狭まる、のいずれかを選ぶなら、[modules/package.rs](../../../crates/benitoite/src/modules/package.rs) の `BREAKING_CHANGES` と [06-09の登録表](../../design/06-tooling/06-09-packages.md#設定ファイルの検査)へ変更を登録する。理由・対象・書き換えの候補は改造の記録へ残す。机上の懸念を実在する破壊として登録する前に、実装時に再現を確認する。

公開版は設計者の決定どおり0.0.14とする。現行06-09は、宣言した版より後の破壊的変更があればE0908、処理系より新しい宣言ならE0907、宣言がなければ現在の規則で読む、と定める。新機能ごとの古い構文への切替をする規則ではない。この方式を保ち、新機能だけを理由に0.0.14を破壊的変更へ登録しない。依存として新機能を使う例には0.0.14を宣言し、古い処理系からはE0907で断れるようにする。本担当は版ファイルや登録表を更新しない。

新機能の利用案内には、普通のIntegerのまま使える例、契約を追加する例、動的入力のResult検査、算術後の再検査、Listの不変性、旧CheckedIntegerを残す理由を示す。新構文を使わないコードへ機械的な書き換えを要求しない。現行06-09は0.1.0まで移行の方法を案内せず、0.0.13のE0908には変更の事実だけを示す。この方針を保つ案であり、受理が狭まる場合の具体的な移行手順を今回CLIにも載せるなら、設計者に別の判断を求める。調べとして書き換えの候補を残すことと、公開CLIの案内を変えることを区別する。互換性の棚卸しと文書作業は基本案に含み、標準署名を強める案の移行費用は未見積もりである。

## 12. 組込み向けの構成・診断・利用者向け文書

| 論点 | 推す案と原則 | 費用・残る不確かさ |
|---|---|---|
| 構成 | 区間・包含・所属の中核は小さな自作の整数比較で実装し、ネットワーク・暗号・Wasmtimeへ依存させない。構成で型の意味を変えない（原則1・4） | 基本案に含む。Rangeモジュールを外した構成では検査APIの利用を名前/型の検査段階で拒否し、型規則そのものは保つ |
| 32ビットと値の表現 | 言語のIntegerは64ビット、端点比較には既存のi128相当を使い、usizeを言語の上限にしない。カウンタ・変換は既存の検査付き方針に従う | 32ビットの実機検査の環境と時間は不明。ホスト幅依存を追加しないコードレビューが必要 |
| 診断の符号 | 形式不良・値域外/逆転、証明できない所属、包含不一致、未確定の検査対象を区別する。汎用のE0401を使える部分と新しい専用符号を設計時に割り当てる（原則4） | 符号の番号は予約しない。E0519を数値篩の失敗へ流用するだけの案は、Scopeの機械向け理由と混ざるので推さない |
| `check --report=json` | 篩の型違反は通常の型検査失敗として `status/complete` と終了状態へ反映する。`intervalAnalysis` は従来の警告解析の集計のままにする | 型の文字列表記・診断とソース位置を確認する。新たな機械可読な区間欄を加える場合は十進文字列と形式の版を別に設計する |
| 契約の表示 | 型の名前だけでなく必要に応じて展開した両端と包含方向を示す。効果の許可一覧へ整数の契約を足さない（原則2・3） | 本改造だけで契約差分の全UIを完成したとしない。ハーネスが読む情報の既存契約との整合が要る |
| 同梱のSkill | 型構文・所属診断・検査API・不変な型引数の例を正の参照文書へ反映し、grammar/diagnostics/stdlibの参照はgen_skillで再生成する | 基本案に含む。本担当は生成物を手で変えない |
| リファレンス・日本語訳・fmt | 英語を正とし、固定範囲の例と保証の限界を記す。ハーネス経由でcheckの結果を確認し、失敗時はResultを処理する流れを主にする。日本語訳はリリース時に同期する | 実行手順やハーネスの説明を重複して写さず、処理系を正とする版を固定した文書を参照する |

整数の値の表現は既存のものを使い、篩のための新しいヒープの包みや unsafe な変換を加えない。新しい実行時検査のRust本体は、端点とIntegerを受けて結果を返す小さな純粋関数に分け、VMの内部やWasmtimeへ直接依存させない。

## 13. 作業の分け方と見込み、検査・レビュー・受け入れ

### 13.1 段全体の実績・近い変更の実績と、新しい幅の算出

S01の基本案はLean64〜128時間・処理系等72〜144時間で、SBの48〜96時間・56〜120時間へ、現行の範囲添字と対象健全性、参照箇所の増加、共通骨格、期待型とコンテナの接続を足した見込みだった。S01bのLean32〜72時間への変更は、部分的な実績を引いた定性的な判断で、下げ幅を再計算できなかった。S01cでは次の記録を照合し、係数と新しい種類の作業への余裕を明示して見直す。いずれも将来の工数は**見込み（実測ではない）**である。

#### 0.0.13のLeanの段全体

[plan.md「作業の数と時間」](../../archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/plan.md#作業の数と時間)のL00〜L50は能動63〜141時間である。各lディレクトリのresults.mdを41件開き、記録された外側の所要を集計した。これは枝ごとの所要の和であり、並行していた改造全体の暦時間や、全担当の能動時間の合計ではない。検査・ビルドを含むが、記録の外の独立レビュー・設計者の待ちは含まない。

| 段・results.mdの件数 | 枝の所要の内訳（分、概数） | 和 | 出どころ・集計上の扱い |
|---|---|---:|---|
| L00・10件 | .01=49（下記の別計数なら94）、.02=11、.03=13、.04=13、.05=15、.06=25、.06b=48、.06c=31、.07=14、.08=26 | 245〜290分 | [L00.01](../../archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/l00.01/results.md)からL00.08まで。並行二案の外側49分を一つとして読む場合と、担当別の49＋45分を数える場合を分ける。26分は初版17＋レビュー反映9 |
| L10・5件 | .1=20、.2=37、.3=12、.4=23、.5=18 | 110分 | [L10.1](../../archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/l10.1/results.md)〜L10.5。試行と本体を含む記録の外側を採る |
| L20・7件 | .1=25、.2=52、.3=47、.4=31、.5=35＋44、.6=26、.7=37 | 297分 | [L20.5](../../archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/l20.5/results.md)の停止前と再開後を両方含め、回答待ちを能動としない |
| L30・4件 | .1=53、.3=20、.4=14、.5=12〜13 | 99〜100分 | [L30.3](../../archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/l30.3/results.md)がL30.2の点検を含むので、独立したL30.2を0分で追加しない |
| L40・11件 | .1=24、.2=25、.3=36、.3b=36、.3c=31＋26＋6、.3d=16、.4=55、.5=44、.6=33、.6b=35、.6c=65 | 432分 | [L40.3c](../../archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/l40.3c/results.md)は二段とレビュー修正を含む。別記した約3分の判断待ちは加えない |
| L50・4件 | .1=60、.2=43、.3=23、.4=50 | 176分 | [L50.1](../../archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/l50.1/results.md)〜L50.4の外側 |
| **41件の和** | 上記の計数の違いを残す | **1359〜1405分＝約22.7〜23.4時間** | 範囲の下端と上端は統計的な誤差の区間ではなく、並行二案の計数方法と概数の違いである |
| 別記録の補足 | L00.08bの配置・削除35、RV-L20-fixの修正15 | ＋50分 | [配置の結果](../../archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/l00.08/results-placement.md)、[修正の結果](../../archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/rv-l20-fix/results.md)。既存41件へは重ねない |
| **較正の参照値** | 補足を含めた枝ごとの所要の和 | **約23.5〜24.3時間** | 能動時間・改造の全待ち・全レビューの厳密な合計はなお不明 |

計画63〜141時間に対する参照値の比は、23.5/141〜24.3/63で約0.17〜0.39である。[time-policy.md](../../archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/time-policy.md)がいう「上端の0.1〜0.2倍の枝が多い」とも矛盾しない。分母は計画時の集約、分子は後の追加枝も含み、厳密に同じ作業量の能動時間を比べたものではない。較正の係数を**0.15〜0.40**と置くのは、この概数を外へ丸めた担当の判断である。

最も近い前例は[L40.6c](../../archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/l40.6c/results.md)である。C-Sub等とTy.Leの効果の関係を構造上の包含から被覆へ替え、旧の像の同値・表層の判定器・保存まで接続した。見込み2〜6時間に対して、能動約50分（読む時間を含まない）、外側約65分である。外側と読み・ビルドの内訳は概数で、単純加算しない。この前例は最外の効果の変更であり、F2の二関係・反変共変・整数への所属の追加の実績ではない。

L20.2のWFの切り替え（能動約45分）とL20.5の範囲の列・四欄への追随（停止前を含め能動約70分）は、機械的な追随と同値補題の較正に使う。0.0.12の[L20b](../../archive/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/l20b/results.md)の44分58秒と[L24](../../archive/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/l24/results.md)の再開後3時間20分21秒はReleaseの型を変えておらず、今回の係数の算出には使わない。

#### 0.0.13の処理系・表層・診断・比較

plan.mdの集約はR10〜R40・K10・V10の回帰/候補部分が56〜138時間、通常のAPI文書・Skill・訳が別に4〜8時間である。枝分け後の[plan-r10-r40.md](../../archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/plan-r10-r40.md)では次の幅へ移し替えているため、集約の数字をそのまま各枝の分母にはしない。

| 段 | 詳細計画の能動時間 | 記録と照合した所要・限界 |
|---|---:|---|
| R10 | 15.5〜37.5時間 | [集約結果](../../archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/r10/results.md)と元の結果。R10.1は本体30＋修正13分、R10.3は35＋19＋13分、R10.4は22＋15分。R10.2aとR10.7には先行分・中断・容量不足の欠測があり、段全体の厳密値は不明 |
| R20 | 17.5〜42時間 | [集約結果](../../archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/r20/results.md)と元の結果。R20.3は50＋20分、R20.4は49＋20分。能動の欠測や分担の重なりがあり、段全体の厳密値は不明。L40.3c/.3dをここへ二重計上しない |
| R30 | 7.5〜20時間 | [集約結果](../../archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/r30/results.md)と元の結果。R30.2は25＋13分。追加の宣言情報・TLS等の修正は別の計時を持ち、当初5枝と同じ範囲としない |
| R40 | 7〜16時間 | [集約結果](../../archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/r40/results.md)と元の結果。R40.1は30＋11分、R40.2は20＋9分、R40.3は約20＋10分。並行分担を外側へ加算しない |
| K10 | 5〜12時間 | [K10.1](../../archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/k10.1/results.md)は約23.8＋8.2＋3.6分、[K10.2](../../archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/k10.2/results.md)は約41.7＋16.8分。[K10.3](../../archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/k10.3/results.md)は最初の時計から48分44秒と修正8分47秒、前の読解は未計測。全比較の待ちを含む外側を能動とはしない |

処理系等の全段の厳密な能動時間は、欠測と分担の重なりがあるため算出しない。比較用には全5段から、見込みと外側を対応させられる次の8枝を選ぶ。分母は当初の枝の見込み、分子は同じ枝に含まれた補修を含む所要である。K10.2の別計画の修正bはここでは両方から除く。これは全段を無作為に抽出した標本ではない。

| 枝 | 計画（時間） | 外側（分） |
|---|---:|---:|
| R10.1（bを含む） | 2〜5 | 43 |
| R10.3（b/cを含む） | 3〜6 | 67 |
| R10.4（bを含む） | 2.5〜6 | 37 |
| R20.3（bを含む） | 3〜6 | 70 |
| R20.4（bを含む） | 2.5〜6 | 69 |
| R30.2（bを含む） | 2.5〜6 | 38 |
| R40.1（bを含む） | 2.5〜6 | 41 |
| K10.2（初回） | 2〜5 | 41.7 |
| **計** | **20〜46時間** | **406.7分＝約6.8時間** |

比は6.8/46〜6.8/20で約0.15〜0.34である。未知の分を0とせず、計時と分担が揃わない全段の比は不明のままとする。比較した枝群の比を丸め、較正の係数を**0.15〜0.40**とするのは担当の暫定判断である。文書・訳も含む全ての処理系等の能動時間を実測した係数ではない。

#### 係数を当てた値と、今回初めて行う作業の余裕

旧幅へ上の係数を当てた値に、0.0.13の機械的な追随では測れていない次の作業への余裕を足す。既存75件の逆転等の全件を短い模型の時間で済むとしないためである。これは重複した実装項目を再加算するのではなく、未経験の作業にも同じ短縮率を適用してよいか分からない分を、較正後の幅へ戻す判断である。

| 今回の追加の余裕 | Lean | 処理系等 |
|---|---:|---:|
| F2の二関係・整数の逆転・深いWF・置換 | 4〜8時間 | 有向の数値制約・合流・順序の確認4〜8時間 |
| 整数の所属の葉・検査のδの同じ成功値 | 4〜8時間 | 期待型と新APIの認定、try・パイプ・mapErrorの遅延2〜4時間 |
| 前例より強い四欄の旧型・旧表での同値 | 2〜4時間 | derive・Codec・生成規則と公開契約の棚卸し2〜4時間 |
| 表層の期待型・脱糖との接続 | 2〜4時間 | 上の期待型と認定の欄に含め、二重計上しない |
| **加える余裕の計** | **12〜24時間** | **8〜16時間** |

算出は、Leanが **(64〜128)×(0.15〜0.40)＋(12〜24)＝21.6〜75.2時間**、処理系等が **(72〜144)×(0.15〜0.40)＋(8〜16)＝18.8〜73.6時間** である。下端・上端をそれぞれ2時間単位で切り上げ、**Lean22〜76時間・処理系等20〜74時間、計42〜150時間**を新しい暫定幅とする。幅の端どうしを使うこの計算は、実績から必然的に導いた上限や統計的な信頼区間ではない。P1〜P3の後に作業別の実績と残りで置き換える。

| 段と費用の内訳 | Leanの能動時間（見込み、実測ではない） | 処理系等の能動時間（見込み、実測ではない） | 検査・レビュー・受け入れの割当て |
|---|---:|---:|---|
| 骨格・型の表現 | 4〜12時間（数値領域1〜3、表現・WF・正規化・置換3〜9） | 4〜10時間（AST/型表現2〜4、型解決・交換2〜6） | 三案・旧型の同値・全域の正規化 |
| 部分型・導入・合流 | 6〜20時間（二関係と逆転4〜12、所属・合流・判定2〜8） | 6〜22時間（有向制約4〜14、期待型・認定2〜8） | 登録順、ラムダ・不変位置、L20の慣用形 |
| Releaseの接続 | 6〜22時間（値/型の置換2〜8、状態等2〜8、四欄・主定理2〜6） | 2〜10時間（純粋検査1〜4、脱糖・実行接続1〜6） | 進行・保存・step_sound・効果・対象と四欄の同値。sorryなしと定義・言明・仮定のレビューを処理系へ進む条件にする |
| 表層・脱糖・交換 | 4〜14時間（検査器と判定2〜8、脱糖・網羅性等2〜6） | 4〜20時間（表層・fmt2〜8、交換・回帰・構成2〜12） | 同じ型・効果の保存、Rust/Leanと実行の照合 |
| 診断・文書・生成物・最終修正 | 2〜8時間（写し1〜2、レビュー後の証明修正1〜6） | 4〜12時間（診断1〜3、文書/Skill/訳2〜5、版/互換性/棚卸し1〜4） | Lean欄は診断文を証明する費用ではない。change・release・最終受け入れを割り当てる |
| **合計** | **22〜76時間** | **20〜74時間** | **能動42〜150時間**。上の追加の余裕を各段へ配分済みで、もう一度足さない |
| 別枠 | 試作・相乗り・clamp・B/C/F3等 | 同左、構文測定も別 | ビルド・全比較・測定の実時間、外部レビュー・設計者の待ちは不明。短い試行から見積もる |

これは担当人数や機械台数を前提にした経過日数ではない。見込みの2倍を超えたら、理由と済んだ範囲を報告する。

### 13.2 検査の割当ての考え方

検査の具体的なコマンド・基準コミットは最終計画に一か所で固定する。本担当は実行しない。新しいテストを設計する担当はtest-auditに従い、所属の誤った導入・包含の向き・型変数の順序・実行時検査との不一致等の境界を選び、実装の写しだけの検査を増やさない。

| 区切り | 検査・測定・レビュー・受け入れの内容 | 実時間の見込み |
|---|---|---|
| 捨てる試作 | 別機の個別Lean検査、定理の公理・ソースハッシュの照合、主定理へ戻す未達のレビュー | 能動7〜12時間の上限候補、検査・待ちは不明 |
| Lean各作業末 | 変更した定義と依存する証明、既定ビルドのsorryなし、01-12の写し、言明・仮定のレビュー | 不明 |
| Rust各作業末のwork | 既定のlib全件・関係する統合テスト・clippy・fmtを入口で各一度。途中は関係する検査だけにする | 不明 |
| 接続の切替時のstage | 表層とコア、組み込みの表、型/行の置換、診断と生成物、構成の接続を計画のonlyで指定する | 不明 |
| Rust/Leanの接続を閉じる区切り | check-formal.sh全体で六入口と独立交換・区間解析・実VMを確認する。最終の関係状態で再実行または条件を満たす証拠を引用する | 不明 |
| 改造全体のchange | 言語・処理系の回帰、必要な構成、生成物、長い対象と検査件数、形式化の既定ビルドを一度確認する | 不明 |
| 性能の測定 | 型変数の制約と全ファイルの型の表現を変えるため、既存の短い比較を候補とする。benchmarkの手順と設計者の指定で範囲を確定する。性能の推測をCHANGELOGへ書かない | 不明。短い試行から見積もる |
| 公開候補のrelease | 最適化ビルドでの深い再帰10件（release_stack）、勧告の二lock照合とツールチェーン確認、実CLI・版・同梱物・移行案内・配布を照合する | 不明 |
| 最終レビューと設計者の受け入れ | 主定理の保証、旧受理との差、L01〜L20の決定との一致、例の実用性、未保証範囲を独立して確認する。終了0だけで受け入れ完了にしない | 不明 |

文書だけの作業にRust全libを追加せず、Leanだけを先行した段でRustとの接続成功を主張しない。構文・仕様の例を変える実装の段ではspec_examples、英語リファレンスの例、生成Skillの一致を割り当てる。ここで挙げた検査の唯一の実行場所と引用条件を計画へ書き、各作業へ全比較を重ねない。

## 14. 利用者が書ける形を制限する決定の案

以下は[questions.md](questions.md)の各まとまりのL01〜L20の行で独立に選ぶ。一括回答もできるが、その場合も行ごとの選択を記録する。利用者が書ける形の制限を推す案の細則へ埋めない。未実装の候補なので、拒否例はいずれも本番で再現していない。

| 問い | 制限の案 | 実用への影響と代わりの書き方 |
|---|---|---|
| L01 | 型の条件を定数端点のIntegerの区間に限り、一般述語・値に依存する端点・関係を今回は書けない | `i < length(xs)`、月と日の対応、偶数、0以外全体、整列性を直接書けない。既存の検査済みの包みと明示検査を使う。一般述語/SMTの除外自体は設計者の決定済み |
| L02 | Integer以外の六種・Byte・Float・Decimal・長さ・関数・Reference等の篩と、refinedの入れ子を今回は書けない | バイナリ形式や小幅整数に同じ構文を使えない。既存の型と変換・検査を使う。内部骨格は種類の追加を見越すが、今回の整形式はIntegerの閉区間だけとする |
| L03 | 両端必須、閉区間だけとし、片側省略・半開区間を認めない | 非負整数には最大値を明示する必要がある。添字の上端 `n` をそのまま排他的に書く用途は後段へ残る |
| L04 | 公開の空区間型、逆転、値域外の端点を拒否し、黙って交差へ正規化しない | 条件付きの空集合を型の別名として書けない。誤記を早く報告できる。一点区間は認める |
| L05 | 期待型のないリテラルと局所束縛を単点の篩として推論しない。Aでは `-(5)` も一般の負号の結果なので所属を導入しない | `bind p <- 443` の後でPortに使うには注釈か検査が要る。期待型のない `if flag then port else 443 end if` もIntegerへ合流し、後からPortとして使うには注釈か検査が要る |
| L06 | Aでは算術結果とifの条件から自動導入しない。C/Dを選ぶ場合も、条件は同じ局所整数と定数の六比較と短絡and・or・notまで | `p + 1`等はAでは明示検査を要する。C/Dでも未知の二変数の関係や任意のBoolean関数から所属を導入しない。穴を単一区間へ近似して必要な包含を示せなければ検査を要する |
| L07 | List・Result・Reference・Lazy等の型引数、Failのエラー型、型クラス辞書の型引数、Mapのキーを不変とする | `List[Port]`を`List[Integer]`へ渡すにはmap等で広げる。新しいリテラルの各要素の検査は可能。ResultもOkの値を取り出して必要なら作り直す。`Fail[Port]`と`Fail[Integer]`、`Map[Port,V]`と`Map[Integer,V]`、両型の型クラス辞書を暗黙に同一視しない |
| L08 | 区間端点の変数を利用者が量化する構文と、一般の部分型制約を宣言する構文は増やさない | 任意の範囲を保つ専用の区間多相は書けない。既存の型パラメータTのidentityやList[T]による受渡しはできる |
| L09 | 所属を証明できない式に暗黙の検査を挿入せず、静的に拒否する | 動的入力のまま契約付き関数を呼べない。Resultの検査と失敗処理を明示する必要がある |
| L10 | 型内の端点式はリテラルとconst参照までとし、任意の算術式・関数呼出しを認めない | 計算した上限はconstへ分ける。端点定数と型の循環を断る。パターンと範囲添字は現行のリテラル限定のままで、端点に許す式は型の位置と異なる |
| L11 | 新検査APIの対象の篩が期待型から確定しなければ断り、呼出しに型引数を書く構文は足さない | 対象が確定しない`checkRefined(value: n)`は型注釈を要する。固定の結果型のラッパーや具体型の関数値は使える。式の位置そのものでは制限しない |
| L12 | matchの網羅性を篩の小区間へ正確に狭めず、通常のInteger全域で保守的に判定する | Monthの1〜12を列挙しても包括的な腕を求められる。精度を今回上げる対案の追加費用も第8節に示した |
| L13 | 篩が同じでも用途別の型別名は区別しない | 同じ範囲の単位違いは不透明な名目型を使う。これは現行の別名の規則を新しい型にも適用する案である |
| L14 | 全型クラスのInteger実装を自動継承しない | Show/Orderの入力だけの委譲は提供し、Semigroup等の結果の閉性は別に証明する |
| L15 | 関数の入れ子では篩だけを反変・共変で比べ、潜在効果は等号に限る（F2） | 入れ子の効果だけを広げる高階利用は拒否する。F1（両方外側）・F3（両方入れ子）も別に選べる |
| L16 | ラムダの引数の注釈と期待する引数型の等号を必須にするか | **等号必須を採らず**、ラムダ自身の注釈で本体を検査し、全体を名前付き関数と同じ部分型関係で渡す。採る場合は同じ契約の関数でもラムダだけを断る |
| L17 | constの宣言で既存の等号だけを要求するか | **篩を要求するconstでは、定数評価後の所属検査を認める変更を推す**。採らなければ `const p: Port = 443` 等は書けない。非篩の旧constは現行の規則を保つ |
| L18 | 全Integer域の区間を通常のIntegerとは別の表現のまま残すか | **受理してIntegerへ正規化**を推す。別表現の維持では相互に使えても不変なList等の等号が食い違いうる。拒否も対案 |
| L19 | 新しい高階関数の合流では、比較可能な上側等を選べなければ注釈を求める | 任意の反変型の最大下界を推論しない。既存の同じ引数・結果で潜在効果だけが違う合流は保つ目標とし、旧受理を狭めるなら再相談する |
| L20 | try・or return・or die・パイプ・Result.mapErrorを通して対象が確定しても、内側のResult注釈を必須にするか | **注釈必須を採らず**、制約の解決後に新APIを認定する。対象がなお未確定なら注釈を求める。or dieの利用案はこの判断に依存する |

これらの制限を一つでも緩める場合は、例・診断・Leanの前提と結論・見込みの該当行を合わせて見直す。制限の採否を、実装担当の判断だけで確定しない。

## RV-S01 への対応

対応先は本書の節番号とquestions.mdの新しい番号である。コード・設計書を開いて現行規則を確かめた項目と、案の規則から予想した例・費用を区別して記した。

| 所見 | 直した場所と内容 |
|---|---|
| S1 | 6.1・8.3、Q03のL15・L16。最外だけ／篩だけ入れ子／両方入れ子の三案、受理と費用、CoverCompat・EffectCover・tyLe/tyJoin・診断、ラムダ注釈の不整合を明記した |
| S2 | 8.4、Q04。所属の葉とStateTy等・四欄の中身の変更への承認、旧型・旧表での `*_iff_old` 相当の条件、step_sound・effect_soundness_noLamNamesを追加した |
| M1 | 1.2・1.3、Q02。5用途×A/B/Cの15本（30〜39行）と静的な検査・Result分岐の箇所数、clamp・明示の停止、Bのδの型付けの費用を記し、未実行と明示した |
| M2 | 8.1・8.2・9、第14節L02・L18、Q01・Q06・Q05。既存構成子の添字を第三案に加え、refinedの整形式と全域区間の表現、IntKind::of_typeの第三欄の扱いを補った |
| M3 | 3.2・3.3、L10、Q01。パターン・範囲添字のリテラル限定との差、型だけconstを許す案と揃える二対案、rangeFixedIntegerの前例を示した |
| M4 | 5.1・6.1・6.2、第14節とQ02・Q03。入れ子・ラムダ、Fail・辞書・Mapキー、const宣言規則、`-(5)`、期待型のないifの各判断を独立した行へ補った |
| M5 | 第11節、Q08。tools/deriveのJSON・Property等の生成物とJson.Codecを計画の互換性の棚卸しへ送り、未実行の懸念を不具合と断定しない形にした |
| M6 | 第9・13節、Q06・Q12。増分と段ごとの費用を分け、0.0.12/0.0.13の記録でLeanを暫定較正し、最終修正のLean欄とSB約24分との差、試作後の再評価を説明した |
| 軽・勧告の判断 | 0.1。2026-10-30の設計者の「組み込まない」を反映した |
| 軽・非公開の試作 | 0.2。2026-10-17の試作に「非公開のためリンクしない」と添えた |
| 軽・外部資料 | 3.1。Liquid HaskellのNatを資料のlqの例へ替え、RustのS-tracking-perma-unstableを併記した（一次資料を再確認） |
| 軽・用語 | 第4節、Q09。base typeと日本語の用例の限界、所属を説明する語、部分型関係と既存の包含の区別を選べる候補にした |
| 軽・定理の区別 | 8.4。preservationEを内部の補題と区別し、HasTypeQ.desugarの実在と同じ型・効果を保つ接続を確認した |
| 軽・flowの説明 | 6.1・6.2。保存するspan/related/priority/int_literalとFloat修正案、Varと非関数型が即時bindされる腕を正した |
| 軽・NonEmptyListと出典 | 7.1。別モジュール名と、Rangeのdata/opaqueの区別を定める01-12・07-04の箇所を示した |
| 軽・問いの束ね | questions.md全体。9まとまり・12問に再編し、一括／個別の回答とL01〜L20の独立した行を残した |

## RV-S01b への対応

| 所見 | 直した場所と内容 |
|---|---|
| 中1 | 1.3の15本。importをUnofficial.IOへ、操作の呼出しをモジュールの関数へ、Integerの除算をdivへ直した。checkで見つけた等号とif連鎖の閉じ方も直し、篩を除いた15本の成功を一行で記録した |
| 中2 | 1.3のA慣用版の列・例、5.4、P3、第14節L20、Q02。try・各処置・パイプ・mapErrorの型変数の接続を読み、認定を遅らせる追加と注釈を要する対案を独立させた。慣用版5本と既存の型変数の5経路もcheckした |
| 中3 | 13.1、要約、Q12。Leanの41件と補足記録、L40.6c、R10〜R40・K10の計画と記録を照合し、比の母集団・欠測・係数・追加の余裕・丸め方・各段の配分を明示した |
| 中4 | Q03。F1/F2/F3ごとの4章・旧受理・新しい型の受理・コードの対応表を追加し、01-06のサブタイピングなしの文の変更も示した |
| 軽1 | 1.2のC、1.3、L06、Q02。六比較、純粋な短絡and/orとnot、単一区間で表せない穴の近似と導入できない場合を定めた |
| 軽2 | 1.3の再試行。A/CからB専用の説明を除き、それぞれの案の処置を示した |
| 軽3 | 3.3。01-05の見出し名を「パターンの拡張（初回リリース版）」へ正した |
| 軽4 | 8.4・P2・13.1・Q04。V-Checkedのrelease_existsの同値と範囲の列の三欄の同値を区別し、四欄の条件は前例より強いと明記した。P2は代表例と未達、本番証明はReleaseの見込みに含めた |
| 軽5 | questions.md。Integerだけの対象の問いを骨格の前のQ05へ移し、骨格はQ06、相乗りはQ07、互換性はQ08へ振り直した |
| 軽6 | 6.3。Mapのキーと型クラス辞書の型引数を名指しし、「辞書」の曖昧さを除いた |
| 軽7 | 1.2とQ02。DのLean32〜72時間等は基本案への別加算であり、基本案の総額ではないと明示した |
