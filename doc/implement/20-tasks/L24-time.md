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
- ADR: [0173](../../design/decisions/0173-time-format-specifiers.md)、[0138](../../design/decisions/0138-crates-and-licenses-for-stdlib.md)

インターフェース:

- [標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)の「テキストとデータ」の表と `Time.bnt`、「レコードの値の作り方」
- [IO とネットワークの追加](../10-interfaces/10-16-io-and-network-additions.md)の「使うクレート」の `jiff`

## 作るもの

- `src/builtins/funcs/time.rs` の 11 項目の本体と単体テスト。`jiff` を依存に加える（10-16 の表の指定。L10 が先に加えていれば、その指定を使う）

## 手順の要点

- `Time.Instant` と `Time.DateTime` の値はレコードであり、欄を宣言の順で読み書きする（10-15「レコードの値の作り方」）。
- 変換の関数（`fromUnixSeconds` など）は、整数の算術で書き、結果が `Integer` のナノ秒に収まらなければ実行時エラー（`IntegerOverflow`。03-08 の「`Integer` の溢れと同じ扱い」）。`toUnixSeconds`・`toUnixMilliseconds`・`differenceMilliseconds` は負の無限大の向きへ切り捨てる（`div_euclid` を使う）。
- `offsetMinutes` は −1439 以上 1439 以下でなければならず、外なら実行時エラー（`ArgumentOutOfDomain`。引数の位置は関数ごとに書く）。
- `toDateTime(t, offset)`: `jiff::Timestamp` と `jiff::tz::Offset` で、その時差で見た日付と時刻を求める。`nanosecond` は秒の端数のナノ秒。
- `fromDateTime(dt)`: 欄の値が範囲の外（月 13、2 月 30 日、時 24 など）か、`jiff` が扱えない年なら `Result.Error`。うるう秒（秒 60）は扱わないので `Result.Error`。`offsetMinutes` が範囲の外なら、実行時エラーではなく `Result.Error` とするか実行時エラーとするかを 03-08 は定めていない（`offsetMinutes` の範囲の実行時エラーは「渡すと」と書く）。`DateTime` の欄の一つとして値の誤りに含め、`Result.Error` とし、`///` のコメントと完了の報告に書く。
- `formatISO8601(t, offset)`: `2026-09-28T12:34:56.789+09:00` の形。時差が 0 なら末尾を `Z` にする。秒の端数は、0 でなければ必要な桁まで書く（末尾の 0 を省く）。
- `parseISO8601(text)`: 時差（`+09:00` など）か `Z` を必須とする。時差のない形は `Result.Error`。`jiff` の解析が 03-08 の形より広い形を受け付けるなら、受け付ける形を 03-08 の例の形（`YYYY-MM-DDTHH:MM:SS[.f]±HH:MM` と `Z`）に絞るかを決め、完了の報告に書く。
- `format(t, offset, pattern)`: ADR 0173 の表の指定だけを受け付け、表にない指定を含めば `Result.Error`。`pattern` を表と照らし合わせてから、`jiff` の書式の機能（`strftime`）に渡してよい（03-08）。曜日と月の名前は英語で、地域の設定に依らない。
- 作る文字列の大きさを確保の前に確かめる（`format` は `pattern` の長さに比例する）。

## 受け入れテスト

- 項目ごとの単体テスト: 1970 年の前と後、表せる範囲の端（およそ 1677 年と 2262 年）で溢れと実行時エラー、負の値の切り捨て（`toUnixSeconds` に −1 ナノ秒で −1）、`offsetMinutes` の −1439・1439・−1440・1440。
- `toDateTime` と `fromDateTime` の往復（時差 0・540・−300・端数のナノ秒）。存在しない日付（2 月 30 日、うるう年でない年の 2 月 29 日）で `Result.Error`。
- `formatISO8601`: `Z` になる場合、秒の端数の桁（`.789`、`.000000001`、端数なし）。`parseISO8601` との往復。時差のない文字列で `Result.Error`。
- `format`: ADR 0173 の表の各指定、負の年、`%%`、表にない指定（`%Q`）で `Result.Error`、`%` で終わる `pattern`。
- `Time.Instant` と `Time.DateTime` が `Map` の鍵にできる（スクリプト）。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 10-15 の項目の名前・権限・引数の数と位置を変えていない
- `jiff` の版と機能、`fromDateTime` の `offsetMinutes` と `parseISO8601` の受け付ける形の判断を完了の報告に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「組み込みの関数」の行。とくに、時刻の計算が溢れを検査しているか。
- `jiff` のタイムゾーンのデータを同梱する機能を入れていないか（10-16 の表の指定）。

## 難易度の理由

クレートが暦の計算を行うが、範囲と切り捨ての規則、書式の指定の制限、03-08 が定めていない端の場合の扱いを一つずつ決めて確かめる必要がある。
