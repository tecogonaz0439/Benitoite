# L10 `Console`・`Clock`・`Process` の小さな関数

- 依存する作業: [L00](L00-u3-interfaces.md)、[L03](L03-bytes.md)、[R29](R29-runtime-builtins.md)
- 難易度: 2（1〜5。README の「作業一覧」）
- 規模の見込み: 小（500 行未満）
- ブランチ: impl/L10-console-clock-process

## 目的

IO のモジュールの小さな 7 の操作の本体を書き、ソースの関数 `Process.command` を確かめる。10-15 の部分 29（`console::MORE_DECLS`）・部分 30（`process::ENVIRONMENT_DECLS`）・部分 31（`clock::MORE_DECLS`）である。あわせて、実際の時計の地方時の差（`Clock::local_offset_minutes`）を `jiff` で書く（10-16「時計」）。

| 部分 | 項目 | 権限 | 行う場所（02-09「組み込みの操作とハンドラ表」） |
|---|---|---|---|
| 29 | `Console.readAllLines`・`Console.readAllBytes` | `Io` | 作業用のスレッド |
| 30 | `Process.scriptDirectory`・`Process.environmentVariable`・`Process.workingDirectory` | `Io` | VM のスレッド（すぐに完了する） |
| 31 | `Clock.now`・`Clock.localOffsetMinutes` | `Io` | VM のスレッド（すぐに完了する） |

依存の理由: `Console.readAllBytes` は `Bytes` の値を作る（L03）。`Clock.now` は `Time.Instant` のレコードを作るが、テストでは値をレコードの欄の関数 `Time.Instant.unixNanoseconds`（01-05 のレコードの型の名前のモジュール）で読むので、`Time` の組み込みの関数（L24）の本体を要しない。依存の欄の L24 は外してよい（オーケストレータの決定。README の作業一覧と依存の図は、オーケストレータが合わせる）。標準入力を読む仕組みは R29 の `Console.readAll` のものを使う。

## 読む設計書の節

- [IO のモジュール](../../design/03-interop/03-07-io-modules.md)の「共通の規則」（行の分け方）、「Console」「Process」（本作業の関数の行と箇条）、「Clock」
- [ランタイム](../../design/02-impl/02-09-runtime.md)の「組み込みの操作とハンドラ表」、「実行ごとの状態」の基準のディレクトリ、「一つの操作で作る値の大きさの上限」
- [エフェクト](../../design/01-spec/01-07-effects.md)の「外部から受け取る文字列」
- ADR: [0131](../../design/decisions/0131-script-directory-and-permission-base.md)、[0165](../../design/decisions/0165-exit-and-stdio-in-embedded-runs.md)、[0287](../../design/decisions/0287-stdlib-details-decided-in-u3-plan.md) の決定 1、[0012](../../design/decisions/0012-invalid-utf8-input.md)

インターフェース:

- [標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)の「IO のモジュール」の表、`IO/Console.bnt`・`IO/Process.bnt`・`IO/Clock.bnt` に加えた宣言、「レコードの値の作り方」
- [IO とネットワークの追加](../10-interfaces/10-16-io-and-network-additions.md)の「使うクレート」の `jiff`、「時計」、「作業用のスレッドで行う操作」
- [組み込みの関数の型付きの形](../10-interfaces/10-11-builtin-interface.md)の `IoServices`（`script_directory`・`working_directory`・`environment_variable`・`now_millis`・`local_offset_minutes`）
- [スケジューラと IO 実行器](../10-interfaces/10-10-scheduler-and-io.md)の `Clock`
- R29 の作業の文書（標準入力の読み取り、`IOErrorKind` への対応）

## 作るもの

- `src/builtins/funcs/console.rs`・`process.rs`・`clock.rs` の上の 7 項目の本体と単体テスト
- 実際の時計（R25 が `src/runtime/sched/parts.rs` に置いたもの）の `local_offset_minutes` を `jiff` で求める形に書き換えたもの。`jiff` をクレートの依存に加える（10-16 の表の指定。L24 が先に加えていれば、その指定を使う）
- `Process.command` と、`Process.Command` のレコードの更新を確かめるスクリプトのテスト

## 手順の要点

- `Console.readAllLines`・`readAllBytes`: R29 の `Console.readAll` と同じく、`Lend::Stdin` で標準入力の読み手を借り、`after_output_flush` を付けた仕事にする。残りを上限（2^30 バイト）より 1 バイト多い分まで読み、上限を超えたら資源の不足（`InputTooLarge`）。`readAllLines` は 03-07「共通の規則」で行に分け（`String.lines` と同じ。分け方は `string.rs` の `String.lines` の宣言のマクロの中に書いてあるので、`string.rs` の中の非公開の関数に抜き出して両方から使ってよい。`string.rs` は R08 のファイルだが、この抜き出しのために作業を止めなくてよい）、UTF-8 でなければ `InvalidUTF8`、行の数がリストの上限を超えたら資源の不足。`readAllBytes` は文字コードを解釈せずに `Bytes` にする。
- `Process.scriptDirectory`: `IoServices::script_directory` の絶対パスを文字列にする。パスが UTF-8 でないときの扱いは設計書が定めていない（型は `String` で `Result` を返さない）。処理系が起動するスクリプトのパスは CLI が文字列として受け取る（10-13）ので起きないはずであり、起きたら `Stop::Internal` とする。
- `Process.environmentVariable(name)`: `IoServices::environment_variable` の値。定義されていなければ `Result.Ok(Option.None)`、UTF-8 でなければ `InvalidUTF8` の `Result.Error`。`name` が空か、NUL か `=` を含むときは `InvalidInput` の `Result.Error`（OS に渡せない引数。03-07「IOErrorKind と関数の対応」）。空の名前も NUL・`=` と同じ扱いにする。名前の検査は `IoServices::environment_variable` を呼ぶ前に行い、検査に通らない名前を services に渡さない。
- `Process.workingDirectory()`: 基準のディレクトリ（`IoServices::working_directory`。02-09「実行ごとの状態」）の絶対パス。UTF-8 でなければ `InvalidUTF8`。
- `Clock.now()`: `IoServices::now_millis` のミリ秒を 1,000,000 倍してナノ秒にし（溢れを検査する）、`Time.Instant` のレコード（`alloc_fields(FieldsKind::Ctor, tags::RECORD, &[ナノ秒])`）で返す。
- `Clock.localOffsetMinutes()`: `IoServices::local_offset_minutes` を返す。実際の時計の `local_offset_minutes` は、`jiff::tz::TimeZone::try_system()` で得たタイムゾーンの、現在の時刻での UTC からの差（秒）を分にした値とし、得られなければ 0 を返す（ADR 0287 の決定 1）。テスト用の時計（R25）の値は変えない。
- 10-16 の【要検証】の三つめ（タイムゾーンのデータを同梱しない `jiff` で OS の時差を得られるか）を、macOS と、タイムゾーンのデータを持つ Linux のコンテナ（オーケストレータが用意できれば）で確かめ、結果を完了の報告に書く。得られる環境で得られなければ、作業を始める前の報告と同じく作業を止めて報告する。

## 受け入れテスト

- 項目ごとの単体テスト（10-12「確かめること」）: 仕事を返す関数は、`WorkerWait` を `run` して完了の処理を呼ぶところまで確かめる（R29 と同じ）。
  - `readAllLines`: `"a\r\nb\n"` で `["a", "b"]`、空の入力で `[]`、`readLine` で一行読んだ後の残りだけ、正しくない UTF-8 で `InvalidUTF8`。
  - `readAllBytes`: 正しくない UTF-8 を含む入力をそのまま返す。
  - `environmentVariable`: 定義された変数、定義されていない変数、空の名前、`=` を含む名前、NUL を含む名前。テストはプロセスの環境変数を変えず、テスト用の `IoServices`（R08 の第 1 段の一時的な実装か、R26 のテスト用の部品）で値を与える。
  - `workingDirectory`・`scriptDirectory`: 与えた基準のディレクトリとスクリプトのディレクトリを返す。
  - `now`: テスト用の時計の値（ミリ秒）からナノ秒のレコードを作る。溢れる値で `IntegerOverflow`。
  - `localOffsetMinutes`: テスト用の時計の値を返す。
- 実際の時計: `TZ` を指定して処理系の子プロセスを起動するテスト（`TZ=UTC` で 0、`TZ=Asia/Tokyo` で 540。`/usr/share/zoneinfo/Asia/Tokyo` がない環境では、`TZ=Asia/Tokyo` の期待を 0 にする）。環境変数を変えるのは子プロセスだけにする。
- スクリプト: `Process.command("git", ["status"])` の欄が 03-07 の既定の値であり、`Process.Command(..cmd, workingDirectory: Option.Some("./sub"))` で一つの欄だけが変わる。`Clock.now()` の値は `Time.Instant.unixNanoseconds` で読む（`import Benitoite.Unofficial.Time`）。
- スクリプトのテストで U3 の非公式のモジュールを取り込むときは、非公式の名前（`import Benitoite.Unofficial.Json` など。ADR 0286 の決定 3）で書く。03-08 などの設計書の例の `import Benitoite.Json` の形を写すと、E0321 になる。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 10-15 の項目の名前・権限・引数の数と位置を変えていない
- `jiff` の版と機能、【要検証】の確かめの結果を完了の報告に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「組み込みの関数」の行。
- 時計を `std::time` から直接読まず、差し替えられる時計（`IoServices`）だけを使っているか（実際の時計の実装の中を除く）。
- テストがプロセスの環境変数やタイムゾーンを書き換えていないか（子プロセスだけで変えているか）。

## 難易度の理由

どの関数も既存の口を読むだけであり、R29 と同じ形で書ける。判断は、UTF-8 でないパスと環境変数の扱い、時差を得られないときの扱いに限られる。
