# L24 `Time`

- 依存する作業: [L00](L00-u3-interfaces.md)
- 難易度: 3（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行。テストを含む）
- ブランチ: impl/L24-time

## 目的

時刻 `Time.Instant` と暦の日付と時刻 `Time.DateTime` を扱う `Benitoite.Time` の 11 の関数の本体を、`jiff` を使って書く。10-15 の部分 40（`time::DECLS`）である。IANA のタイムゾーンの名前は扱わず、時差（分）だけで扱う（03-08「各モジュールの範囲」）。`Clock.now`（L10）と `File.info`（L11）が `Time.Instant` の値を作る。

| 項目 | 権限 |
|---|---|
| `Time.fromUnixSeconds`・`fromUnixMilliseconds`・`toUnixSeconds`・`toUnixMilliseconds`・`addMilliseconds`・`differenceMilliseconds`・`toDateTime`・`fromDateTime`・`formatISO8601`・`parseISO8601`・`format` | `Pure` |

## 読む設計書の節

- [テキストとデータの処理](../../design/03-interop/03-08-text-and-data.md)の「Time」（`Time.Instant`・`Time.DateTime`、表せる範囲、うるう秒、関数の表と箇条、範囲を超えたときと `offsetMinutes` の範囲、`Time.format` の指定の表）、「各モジュールの範囲」、「共通の規則」
- [基本型の意味論](../../design/01-spec/01-04-types-basic.md)の `Integer` の溢れ
- ADR: [0173](../../design/decisions/0173-time-format-specifiers.md)、[0138](../../design/decisions/0138-crates-and-licenses-for-stdlib.md)、[0329](../../design/decisions/0329-csv-and-time-details-from-u3-preflight.md)

インターフェース:

- [標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)の「テキストとデータ」の表と `Time.bnt`、「レコードの値の作り方」
- [IO とネットワークの追加](../10-interfaces/10-16-io-and-network-additions.md)の「使うクレート」の `jiff`

## 作るもの

- `src/builtins/funcs/time.rs` の 11 項目の本体と単体テスト。`jiff` を依存に加える（10-16 の表の指定。L10 が先に加えていれば、その指定を使う）

## 手順の要点

- `Time.Instant` と `Time.DateTime` の値はレコードであり、欄を宣言の順で読み書きする（10-15「レコードの値の作り方」）。
- 変換の関数（`fromUnixSeconds` など）は、整数の算術で書き、結果が `Integer` のナノ秒に収まらなければ実行時エラー（`IntegerOverflow`。03-08 の「`Integer` の溢れと同じ扱い」）。`toUnixSeconds`・`toUnixMilliseconds`・`differenceMilliseconds` は負の無限大の向きへ切り捨てる（`div_euclid` を使う）。`differenceMilliseconds` はナノ秒の差が `i64` に収まらないことがあるので、`i128` で差を求めてから切り捨て、結果を `i64` に戻す。`addMilliseconds`・`fromUnixSeconds`・`fromUnixMilliseconds` も、`i128` で結果のナノ秒を求めてから `i64::try_from` で戻し、戻せなければ `IntegerOverflow` とする。`milliseconds * 1_000_000` を `i64` の `checked_mul` で求めてから足すと、結果は範囲に収まるのに中間の積が溢れる場合（`t` が負で `milliseconds` が大きい正の数など）を誤って溢れとしてしまう。
- `offsetMinutes` は −1439 以上 1439 以下でなければならず、外なら実行時エラー（`ArgumentOutOfDomain`。引数の位置は関数ごとに書く）。`fromDateTime` の `dt` の `offsetMinutes` も同じである（後述）。
- `toDateTime(t, offset)`: `jiff::Timestamp` と `jiff::tz::Offset` で、その時差で見た日付と時刻を求める。`nanosecond` は秒の端数のナノ秒。
- `fromDateTime(dt)`: 欄の値が範囲の外（月 13、2 月 30 日、時 24 など）か、`jiff` が扱えない年なら `Result.Error`。`jiff` が扱える年でも、結果が `Time.Instant` の範囲（およそ 1677〜2262 年）を超える日付（年が 2263〜9999 など）は `Result.Error` とする（実行時エラーにしない）。うるう秒（秒 60）は扱わないので `Result.Error`。`dt` の `offsetMinutes` が −1439 以上 1439 以下でなければ、`Result.Error` ではなく実行時エラー（`ArgumentOutOfDomain`。`function` は宣言の `name` の `Time.fromDateTime`、引数の位置は 0）とする（03-08「Time」、ADR 0329 の決定 4）。ほかの欄の範囲を確かめる前に `offsetMinutes` を確かめる。
- `formatISO8601(t, offset)`: `2026-09-28T12:34:56.789+09:00` の形。時差が 0 なら末尾を `Z` にする。秒の端数は、0 でなければ必要な桁まで書く（末尾の 0 を省く）。
- `parseISO8601(text)`: `jiff::Timestamp` の解析（`text.parse::<jiff::Timestamp>()`。中で `jiff::fmt::temporal::DateTimeParser::parse_timestamp` を呼ぶ）が受け付ける形を、そのまま受け付ける。受け付ける形を絞る照合を書かない（03-08「Time」、ADR 0329 の決定 3）。jiff 0.2.37 のこの解析は、時差か `Z` を必須とし、時差のない形を誤りとする。03-08 の例の形のほかに、分と秒の省略、区切りを書かない基本形式、秒の端数の区切りの `,`、秒を含む時差（±25:59:59 まで）、`[Asia/Tokyo]` のような注記を受け付け、秒の `60` を `59` に丸める（ADR 0329 の背景の 3）。解析した `Timestamp` の `as_nanosecond()`（`i128`）を `i64::try_from` で戻し、戻せなければ（`Time.Instant` の範囲の外。jiff は −9999〜9999 年を表せる）`Result.Error` とする。jiff の誤りの文は、そのまま `Result.Error` の文に使ってよい。
- `format(t, offset, pattern)`: ADR 0173 の表の指定だけを受け付け、表にない指定を含めば `Result.Error`（03-08「Time」、ADR 0173 の決定 2）。`pattern` を字句ごとに読み、`%` の直後が表の指定（`%Y`・`%m`・`%d`・`%H`・`%I`・`%p`・`%M`・`%S`・`%f`・`%j`・`%a`・`%A`・`%b`・`%B`・`%z`・`%:z`・`%%`）と完全に一致する場合だけ受け付ける。フラグ・幅・精度の付いた指定（`%-d`・`%_m`・`%^a`・`%5Y`・`%3f` など）と、表にない指定（`%Q`・`%Z`・`%F` など）は `Result.Error` とする。照らし合わせた後に `jiff` の書式の機能（`strftime`）に渡してよい（03-08）。`jiff` の `%f` は必要な桁だけを書く（末尾の 0 を省く）が、03-08 の `%f` は 9 桁なので、字句ごとに読んだ結果から渡す文字列を組み立て直し、`%f` の字句だけを `%9f` に変える。文字列の置換（`replace("%f", "%9f")`）は、`%%f`（`%` の後に文字 `f`）を壊すので使わない。曜日と月の名前は英語で、地域の設定に依らない。
- 作る文字列の大きさを確保の前に確かめる（`format` は `pattern` の長さに比例する）。
- スクリプトのテストでは、非公式のモジュールを取り込みの名前で取り込む（`import Benitoite.Unofficial.Time`。[ADR 0286](../../design/decisions/0286-unofficial-modules-imported-under-unofficial.md) の決定 3）。03-08 の例の `import Benitoite.Time` の形をそのまま写すと、E0321 になる。一つのスクリプトで `Clock` のエフェクト `Time`（`Clock.Time`）と `Time` のモジュールを同時に使うときは、`import Benitoite.Unofficial.Time as TimeValue` のように別名を付ける（修飾の名前 `Time` のままでは E0305 になる。10-15 の `Clock.bnt` の取り込みと同じ）。

## 受け入れテスト

- 項目ごとの単体テスト: 1970 年の前と後、表せる範囲の端（およそ 1677 年と 2262 年）で溢れと実行時エラー、負の値の切り捨て（`toUnixSeconds` に −1 ナノ秒で −1）、`offsetMinutes` の −1439・1439・−1440・1440。
- `toDateTime` と `fromDateTime` の往復（時差 0・540・−300・端数のナノ秒）。存在しない日付（2 月 30 日、うるう年でない年の 2 月 29 日）と、`Time.Instant` の範囲を超える年（2263 年など）で `Result.Error`。`fromDateTime` の `offsetMinutes` が 1440・−1440 で実行時エラー（`ArgumentOutOfDomain`、`Time.fromDateTime`、引数の位置 0）。`differenceMilliseconds` に範囲の両端の時刻を渡しても溢れない。`addMilliseconds` で、結果は範囲に収まるが `milliseconds * 1_000_000` が `i64` に収まらない場合（範囲の下端に近い `t` に大きい正の `milliseconds` を足すなど）が溢れない。
- `formatISO8601`: `Z` になる場合、秒の端数の桁（`.789`、`.000000001`、端数なし）。`parseISO8601` との往復。`parseISO8601`: 時差のない文字列で `Result.Error`。`9999-01-01T00:00:00Z`（jiff は解析できるが `Time.Instant` の範囲の外）で `Result.Error`。秒の `60` が `59` に丸められる（`2016-12-31T23:59:60Z` が `2016-12-31T23:59:59Z` と同じ時刻）。秒を含む時差（`+09:00:30` など）を受け付ける。注記の付いた文字列（`2026-09-28T12:34:56+09:00[Asia/Tokyo]`）を受け付け、注記のない文字列と同じ時刻になる。
- `format`: ADR 0173 の表の各指定（`%f` が端数の末尾の 0 を含めて 9 桁になること）、`%%`、表にない指定（`%Q`）とフラグの付いた指定（`%-d`）で `Result.Error`、`%%f` が `%f` の文字列になる（`%9f` に変わらない）こと、`%` で終わる `pattern`。負の年は `Time.Instant` の範囲（およそ 1677〜2262 年）で作れないので、`format` の負の年のテストは置かず、範囲の下端の時刻の年が正であること（負の年に届かないこと）だけを確かめる。
- `Time.Instant` と `Time.DateTime` が `Map` の鍵にできる（スクリプト）。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 10-15 の項目の名前・権限・引数の数と位置を変えていない
- `jiff` の版と機能を完了の報告に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「組み込みの関数」の行。とくに、時刻の計算が溢れを検査しているか。
- `jiff` のタイムゾーンのデータを同梱する機能を入れていないか（10-16 の表の指定）。
- `TimeZone::system`・`TimeZone::try_system`・`tz::db()`・`Timestamp::now`・`Zoned::now`、`Zoned` の解析、IANA の名前の解決を使っていないか。これらは jiff の大域のキャッシュや OS の状態に触れるので、純粋な関数に使えない（`Clock.localOffsetMinutes` の `try_system` は L10 の `Io` の関数であり、別である）。時差は `jiff::tz::Offset` と `TimeZone::fixed` だけで扱う。`parseISO8601` の `Timestamp` の解析は、注記（`[Asia/Tokyo]`）を構文として読むだけで、タイムゾーンのデータベースを引かない（jiff 0.2.37 の `src/fmt/temporal/parser.rs` の `ParsedDateTime::to_timestamp` は注記を使わない。データベースを引くのは `Zoned` を作る `to_zoned` だけ）ので、使ってよい。

## 難易度の理由

クレートが暦の計算を行うが、範囲と切り捨ての規則、書式の指定の制限、03-08 が定めていない端の場合の扱いを一つずつ決めて確かめる必要がある。
