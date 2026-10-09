# エフェクト

- 状態: 確定
- 関連ADR: [0005](../decisions/0005-direct-style-effects.md), [0008](../decisions/0008-effect-variables.md), [0011](../decisions/0011-io-failure-and-entry-point.md), [0012](../decisions/0012-invalid-utf8-input.md), [0037](../decisions/0037-exit-status-values.md), [0045](../decisions/0045-late-detection-of-output-write-failure.md), [0048](../decisions/0048-ioerror-not-equality-type.md), [0063](../decisions/0063-ref-cells-with-io-effect.md), [0065](../decisions/0065-ioerror-kind.md), [0071](../decisions/0071-permission-declaration-and-runtime-denial.md), [0072](../decisions/0072-permission-path-matching.md), [0073](../decisions/0073-run-permission-command-matching.md), [0074](../decisions/0074-static-permission-check-by-name-reference.md), [0091](../decisions/0091-acronyms-in-uppercase.md), [0101](../decisions/0101-unabbreviated-names.md), [0107](../decisions/0107-bytes.md), [0115](../decisions/0115-structured-io-concurrency.md), [0116](../decisions/0116-builtin-fine-grained-effects.md), [0117](../decisions/0117-capabilities-as-effects.md), [0118](../decisions/0118-effect-handlers.md), [0120](../decisions/0120-test-functions-and-assert-effect.md), [0128](../decisions/0128-prelude-and-benitoite-namespace.md), [0129](../decisions/0129-effects-declared-in-modules.md), [0130](../decisions/0130-builtin-effect-names-and-placement.md), [0131](../decisions/0131-script-directory-and-permission-base.md), [0140](../decisions/0140-network-separated-from-local-io.md), [0145](../decisions/0145-network-error.md), [0146](../decisions/0146-runtime-errors-not-in-types.md), [0147](../decisions/0147-remove-permission-declaration-syntax.md), [0149](../decisions/0149-http-exchange-release-failure.md), [0150](../decisions/0150-resource-release-as-state.md), [0151](../decisions/0151-inherited-handlers-tail-resume-only.md), [0155](../decisions/0155-resume-not-in-lazy.md), [0165](../decisions/0165-exit-and-stdio-in-embedded-runs.md), [0177](../decisions/0177-server-mode-after-first-release.md), [0183](../decisions/0183-single-policy-for-all-permission-layers.md), [0184](../decisions/0184-permissions-granted-per-builtin-effect.md), [0186](../decisions/0186-run-time-policy-can-only-narrow.md), [0187](../decisions/0187-standalone-reads-user-policy-file.md), [0214](../decisions/0214-default-policies-allow-process-environment-with-no-names.md), [0215](../decisions/0215-shell-permission-allows-run-commands-via-shell.md), [0216](../decisions/0216-policy-deny-rules-and-standalone-defaults.md), [0254](../decisions/0254-return-type-after-arrow.md), [0255](../decisions/0255-bind-and-shadow.md), [0257](../decisions/0257-match-with-case-arms.md)
- 未決事項: [OPEN-012](../open-issues.md#open-012), [OPEN-015](../open-issues.md#open-015), [OPEN-052](../open-issues.md#open-052), [OPEN-055](../open-issues.md#open-055), [OPEN-057](../open-issues.md#open-057), [OPEN-062](../open-issues.md#open-062), [OPEN-081](../open-issues.md#open-081), [OPEN-083](../open-issues.md#open-083), [OPEN-088](../open-issues.md#open-088)
- 移行元: [設計メモ](../sources/fp-language-design.md) 3.1–3.5

## 目的と範囲

エフェクトの注釈（`uses`）と検査、組み込みのエフェクト、利用者が定義するエフェクトとハンドラ、段階導入の各段階で有効な規則。段階の区切りと時期は[ロードマップ](../00-overview/00-03-roadmap.md)が定める。

現在の版は、最小実行版の範囲と、初回リリース版の範囲を定める。最小実行版の範囲は、IO エフェクトが表す操作、IO が起きる時期と順序、IO の失敗の扱い、プログラムの入口 `main`、IO を行う組み込み関数である。初回リリース版の範囲は、組み込みの細かいエフェクトとその置き場所、可変のセル、影響の大きい操作、利用者が定義するエフェクトとハンドラである。あわせて、初回リリース版の後にサーバモードとあわせて加える実行時の権限制御の方針を定める（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)）。

## 前提

`uses` の構文は[構文](01-02-syntax.md)で定める。関数の型が持つエフェクトの集合、式のエフェクト、関数の本体のエフェクトの検査、エフェクト変数とエフェクトの包含は[型システム](01-06-type-system.md)で定める。本章は、型システムが検査するエフェクトの名前が、実行のときに何を意味するかと、ハンドラの意味を定める。ハンドラの構文は[構文](01-02-syntax.md)で、型付けは[型システム](01-06-type-system.md)で、厳密な意味は[コア計算と脱糖](01-12-core-calculus.md)で定める。

式の評価順序と、実行時エラーが起きたときにプログラムがどう停止するかは[評価意味論](01-08-evaluation.md)で定める。

## 仕様

### エフェクトの型と権限制御の区別

【方針】エフェクトの型は、関数を呼んだときにどの種類の操作が起こりうるかを、実行の前に検査するための情報である。実行のときに、どの操作を許すかを決める権限制御とは別の機構である（[設計メモ](../sources/fp-language-design.md) 3.2）。

最小実行版は、エフェクトの型の検査だけを行い、実行時の権限制御を行わない（[ロードマップ](../00-overview/00-03-roadmap.md)）。`uses IO` を持つ関数は、最小実行版の処理系が提供するすべての IO を行える。初回リリース版も実行時の権限制御を行わない。実行時の権限制御は、初回リリース版の後にサーバモードとあわせて加える（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)、後述の「実行時の権限制御（サーバモード）」）。

### 組み込みのエフェクト

【方針】最小実行版のエフェクトは `IO` だけである。IO エフェクトは、プログラムの外部の状態を読むか、変える操作を表す。最小実行版で IO に当たる操作は次のとおりである。

- 標準出力と標準エラー出力への書き込み
- ファイルの読み取り
- コマンドライン引数の読み取り

【決定】初回リリース版では、外部に作用する操作と可変のセルの操作を、細かい組み込みのエフェクトに分ける（[ADR 0116](../decisions/0116-builtin-fine-grained-effects.md)）。エフェクトは、モジュールの中で宣言するものであり、ほかのモジュールからはモジュールの名前で修飾して書く（[ADR 0129](../decisions/0129-effects-declared-in-modules.md)）。組み込みのエフェクトは、標準ライブラリの次のモジュールの中で宣言する（[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)）。IO を行うモジュールは `Benitoite.IO` の下に、ネットワークの操作を行うモジュールは `Benitoite.Network` の下にあり、どちらも import しなければ使えない（[ADR 0128](../decisions/0128-prelude-and-benitoite-namespace.md)、[ADR 0140](../decisions/0140-network-separated-from-local-io.md)）。

| モジュール | エフェクト | 表す操作 |
|---|---|---|
| `Benitoite.IO.Console` | `Console.Write` | 標準出力と標準エラー出力への書き込み |
| 〃 | `Console.Read` | 標準入力の読み取り |
| `Benitoite.IO.File` | `File.Read` | ファイルとディレクトリの読み取り |
| 〃 | `File.Write` | ファイルとディレクトリの作成・書き込み・削除・移動 |
| `Benitoite.IO.Process` | `Process.Run` | 外部コマンドの起動と、シェルによるコマンドの実行 |
| 〃 | `Process.Exit` | 終了状態を指定したプロセスの終了 |
| 〃 | `Process.Environment` | コマンドライン引数・環境変数・実行を始めるスクリプトのディレクトリの読み取り |
| `Benitoite.IO.Clock` | `Clock.Time` | 時刻の読み取りと、時間の経過を待つこと |
| `Benitoite.IO.Random` | `Random.Generate` | 乱数の生成 |
| `Benitoite.Network.Http` | `Http.Listen` | HTTP の接続の待ち受け、要求の受け付けと応答 |
| 〃 | `Http.Connect` | HTTP のサーバへの接続と、要求の送信 |
| `Benitoite`（prelude） | `State` | 可変のセル（後述の「可変のセル（初回リリース版）」）とタスクの集まりの操作、タスクの結果を待つこと（`Task.await`。[並行処理](01-11-concurrency.md)） |

表のエフェクトの名前は、各モジュールを最後の要素の名前で取り込んだときの書き方である（`import Benitoite.IO.Console` の後の `uses Console.Write`）。`as` で別の名前を付けて取り込んだときは、その名前で修飾する（[名前・スコープ・モジュール](01-03-names-modules.md)）。取り込みは、そのモジュールのエフェクトを `uses` に書くためにも要る。

【決定】各モジュールの IO の関数は、そのモジュールのエフェクトの操作である（`Console.writeLine` は `Console.Write` の操作。[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)）。ハンドラで処理でき、どのハンドラも処理しなければ処理系が実際に行う（後述の「利用者が定義するエフェクトとハンドラ（初回リリース版）」）。`State` は操作を持たないエフェクトであり、ハンドラで処理できない。`Reference` と `TaskGroup` の関数、`Task.await`、リソースを解放する関数（`File.closeReader` など。[リソース管理](01-10-resources.md)、[ADR 0150](../decisions/0150-resource-release-as-state.md)）は、`State` を型に持つ組み込みの関数である。

【決定】prelude のモジュール `IO`（`Benitoite.IO`）が宣言するエフェクトは、`All` だけである。`All` は、prelude の `State` と、`Benitoite.IO` の下のモジュールが宣言するすべての組み込みのエフェクトをまとめたエフェクトである（[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)）。`uses IO.All` は、まとめたエフェクトをすべて `uses` に書いたのと同じ意味である。`IO.All` を書くのに import は要らない。以下、本章で「IO」と書くときは、`IO.All` に含まれるエフェクトの操作を指す。

【決定】`Benitoite.Network` の下のモジュールのエフェクト（ネットワークのエフェクト）は、`IO.All` に含めない（[ADR 0140](../decisions/0140-network-separated-from-local-io.md)）。ネットワークのエフェクトも組み込みのエフェクトであり、その操作（ネットワークの操作）は、IO と同じくハンドラで処理でき、処理系が行うときは実行時の権限制御の対象になる。IO とネットワークの両方を使う関数は、`uses IO.All, Http.Connect` のように書く。ネットワークのエフェクトをまとめたエフェクトは、初回リリース版にはない。IO とネットワークの操作を合わせて、外部に作用する操作と呼ぶ。

【決定】最小実行版のエフェクトの名前 `IO` は、初回リリース版ではエフェクトではなく、prelude のモジュールの名前である。最小実行版のスクリプトの `uses IO` は、初回リリース版では誤りになる。診断は、`uses IO.All` を修正案として示す（[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)）。

【決定】テストの期待の確認を表す組み込みのエフェクト `Assert.Check` は、prelude のモジュール `Assert` の中で宣言し、`IO.All` に含めない（[ADR 0120](../decisions/0120-test-functions-and-assert-effect.md)、[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)）。操作は[利用者プログラムのテスト](../06-tooling/06-04-test-runner.md)で定める。

【決定】処理系は、組み込みのモジュールとエフェクトを、綴りではなく、`Benitoite` の名前空間のどの名前かで照合する（[ADR 0128](../decisions/0128-prelude-and-benitoite-namespace.md)）。利用者のモジュールが、組み込みと同じ綴りの名前のエフェクトを宣言しても、組み込みのエフェクトとして扱わない。

【方針】標準ライブラリの各関数は、行う操作に当たるエフェクトだけを型に持つ。`uses IO.All` と書いた関数の本体が、`IO.All` の一部のエフェクトしか生じないときは、処理系は警告で、本体が生じるエフェクトの集合を示す（[ADR 0116](../decisions/0116-builtin-fine-grained-effects.md)）。

次のものは、どのエフェクトにも含めない。

- 実行時エラー（整数の溢れ、0 による除算など）。実行時エラーを起こしうることは、型にもエフェクトにも表さない（[ADR 0146](../decisions/0146-runtime-errors-not-in-types.md)）。
- 停止しないこと。
- メモリなど、処理系の資源を使い果たすこと。

可変のセルの操作も `State` エフェクトを持つので、純粋な関数（[型システム](01-06-type-system.md)）の結果は、初回リリース版でも引数だけで決まる。資源の不足（[評価意味論](01-08-evaluation.md)）を除けば、同じ引数で二度呼んだとき、どちらも値を返したなら同じ値を返す。どちらかが実行時エラーで止まるとき、どの実行時エラーで止まるかは、関数の中で `Task.all`・`Task.allOk` が起動したタスクの切り替えの順序に依存しうる（[並行処理](01-11-concurrency.md)、[ADR 0319](../decisions/0319-task-results-and-pure-guarantee-under-switching.md)）。

### IO が起きる時期と順序

【決定】IO は、IO を行う関数の呼び出しを評価したときに起こる（[ADR 0005](../decisions/0005-direct-style-effects.md)）。IO の計算を値として構築する型（`IO[T]` など）はない。

【方針】IO が起きる時期と順序について、次の規則を定める。

- 一つの呼び出しを評価するたびに、その関数の IO が一度起こる。
- ラムダの式を評価しても、本体の IO は起こらない。本体の IO は、そのラムダを呼び出したときに起こる。
- 複数の IO は、それを含む式を評価する順に起こる。評価の順序は[評価意味論](01-08-evaluation.md)で定める。

初回リリース版のネットワークの操作も、IO と同じく、関数の呼び出しを評価したときに起こり、本節の規則に従う。

【方針】標準出力と標準エラー出力のそれぞれで、書き込んだ内容は書き込みの呼び出しの順に現れる。標準出力と標準エラー出力の間で、現れる順序が呼び出しの順と一致することは保証しない。プログラムが正常に終わる場合、`main` が `Result.Error` を返した場合、実行時エラーで停止する場合、資源の不足で停止する場合は、それまでに書き込んだ内容を、終了の前にすべて出力しなければならない。ただし、書き込みそのものが失敗した場合（次節）と、処理系が上限を設けていない資源が実行環境で尽きた場合（[評価意味論](01-08-evaluation.md)の「資源の不足」）は、書き込んだ内容の一部が出力されないことがある。

### IO の失敗

【決定】外部の状態によって失敗しうる IO の関数は、`Result[T, IOError]` を返す（[ADR 0011](../decisions/0011-io-failure-and-entry-point.md)）。初回リリース版のネットワークの関数は、`IOError` ではなく `NetworkError` を返す（[エラー処理](01-09-errors.md)の「ネットワークの失敗の種類（初回リリース版）」、[ADR 0145](../decisions/0145-network-error.md)）。`IOError` は、構成子を公開しない prelude の型である。`IOError` の値はパターンで分解できない。

【決定】`IOError` は中身を見せない prelude の型であり、基本型にも代数的データ型にも含めない（[ADR 0048](../decisions/0048-ioerror-not-equality-type.md)）。`IOError` とそれを含む型（`Result[String, IOError]` など）は等値の型ではなく、`=` と `<>` で比べられない（[型システム](01-06-type-system.md)の「等値の型」）。失敗の種類を調べるには、`IOError.message` で文字列にするか、`match` で `Result.Ok` と `Result.Error` を分ける。

【方針】`IOError` に対して、次の関数を定める。

| 関数 | 型 | 値 |
|---|---|---|
| `IOError.message(e)` | `function(IOError) -> String` | 失敗の理由を、人間が読める形で表す文字列 |

`message` の文字列の具体的な文面は定めない。文面は処理系の版によって変わりうるので、失敗の種類を判定する手段にはならない。初回リリース版では、失敗の種類を `IOError.kind` で取り出せる（[エラー処理](01-09-errors.md)、[ADR 0065](../decisions/0065-ioerror-kind.md)）。

【方針】標準出力と標準エラー出力への書き込みが失敗したときは、実行時エラー（書き込みの失敗）とする。書き込みの関数は `Result` を返さない。

【決定】書き込みの失敗は、書き込みの関数を呼び出した時点ではなく、後で検出してよい（[ADR 0045](../decisions/0045-late-detection-of-output-write-failure.md)）。処理系は、失敗を検出した時点で、書き込みの失敗による実行時エラーとして停止する。この報告は、ソース上の位置を持たない。失敗を検出するまでに行った評価と IO は取り消さない。処理系は、失敗を遅くともプログラムを終える前の書き出しで検出する。書き出す時期は処理系の設計（[ランタイム](../02-impl/02-09-runtime.md)）で定める。停止の手順は[評価意味論](01-08-evaluation.md)の「実行時エラーによる停止」で定める。

最小実行版の範囲では、`Result.Error` は `match` か、`Result` を扱う prelude の関数で扱う。初回リリース版では、`Result.Error` をそのまま呼び出し元へ返す前置の `try` を設ける（[エラー処理](01-09-errors.md)、[ADR 0097](../decisions/0097-prefix-try.md)）。

### 外部から受け取る文字列

【決定】外部のバイト列を `String` として受け取る操作は、正しくない UTF-8 のバイト列を置き換えたり捨てたりしない（[ADR 0012](../decisions/0012-invalid-utf8-input.md)）。ファイルの内容が正しい UTF-8 でなければ、`File.readText` は `Result.Error` を返す。コマンドライン引数の扱いは次節で定める。

### プログラムの入口

【決定】プログラムの入口は、引数を取らないトップレベルの関数 `main` である（初回リリース版では、実行を始めるモジュールの `main`。[名前・スコープ・モジュール](01-03-names-modules.md)）。初回リリース版でも、`main` は引数をとらない（[ADR 0117](../decisions/0117-capabilities-as-effects.md)）。`main` の戻り値の型は `Unit` か `Result[Unit, String]` である（[ADR 0011](../decisions/0011-io-failure-and-entry-point.md)）。

【方針】`main` は、加えて次の条件を満たさなければならない。

- 型パラメータとエフェクト変数を持たない。
- エフェクトは `IO` か空集合である（`uses IO` を書くか、`uses` を書かない）。初回リリース版では、`IO.All` に含まれる組み込みのエフェクトと、ネットワークのエフェクトの任意の集まりである（`uses IO.All` のほか、`uses File.Read, Console.Write` や `uses IO.All, Http.Listen` なども書ける。[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)、[ADR 0140](../decisions/0140-network-separated-from-local-io.md)）。利用者が定義するエフェクトは、`main` の中で処理しなければならない。`Assert.Check` は含められない。

`main` がないとき、または `main` が上の条件を満たさないときは、型検査の誤りとする。

次の例は最小実行版のスクリプトである。初回リリース版では、`Console` と `File` のモジュールの import が要り、`uses IO` を `uses IO.All`（または `uses File.Read, Console.Write`）と書く。

```text
function main() -> Result[Unit, String] uses IO
  return match File.readText("input.txt") with
    case Result.Ok(text) ->
      Console.writeLine(Integer.toString(List.length(String.lines(text))))
      Result.Ok(())
    case Result.Error(e) -> Result.Error(IOError.message(e))
  end match
end function
```

【方針】処理系は、プログラムを実行するときに次の順で処理する。

1. コマンドライン引数を検査する。どれかが正しい UTF-8 でなければ、その引数の位置を示す診断を出し、`main` を呼ばずに失敗を表す終了状態で終わる（[ADR 0012](../decisions/0012-invalid-utf8-input.md)）。
2. `main` を一度呼び出す。
3. `main` の戻り値によって終わる。

| `main` の終わり方 | 処理系の振る舞い |
|---|---|
| `()` を返す | 成功を表す終了状態で終わる |
| `Result.Ok(())` を返す | 成功を表す終了状態で終わる |
| `Result.Error(msg)` を返す | `msg` と改行を標準エラー出力に書き、失敗を表す終了状態で終わる |
| 実行時エラーまたは資源の不足で停止する | [評価意味論](01-08-evaluation.md)で定める |

終了状態の具体的な値と、スクリプトにコマンドライン引数を渡す方法は [CLI](../06-tooling/06-01-cli.md) で定める。

### IO を行う組み込み関数

【方針】最小実行版の prelude は、IO を行う関数として次のものを定める（[ADR 0011](../decisions/0011-io-failure-and-entry-point.md)）。これ以外の prelude の関数は純粋であり、[標準ライブラリ](../03-interop/03-06-stdlib.md)で定める。表の型は最小実行版のものである。初回リリース版では、これらの関数は `Benitoite.IO` の下のモジュールの関数であり、import しなければ使えない（[ADR 0128](../decisions/0128-prelude-and-benitoite-namespace.md)）。型の `uses IO` は「初回リリース版のエフェクト」の欄のエフェクトに置き換わり、関数はそのエフェクトの操作である（[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)）。

| 関数 | 型 | 振る舞い | 初回リリース版のエフェクト |
|---|---|---|---|
| `Console.write(s)` | `function(String) -> Unit uses IO` | `s` を標準出力に書く | `Console.Write` |
| `Console.writeLine(s)` | `function(String) -> Unit uses IO` | `s` と改行を標準出力に書く | `Console.Write` |
| `Console.writeErrorLine(s)` | `function(String) -> Unit uses IO` | `s` と改行を標準エラー出力に書く | `Console.Write` |
| `File.readText(path)` | `function(String) -> Result[String, IOError] uses IO` | `path` のファイルの内容全体を UTF-8 の文字列として読む | `File.Read` |
| `Process.arguments()` | `function() -> List[String] uses IO` | コマンドライン引数の並びを返す | `Process.Environment` |

- 改行は U+000A 一文字である。
- `File.readText` は、ファイルが存在しない、読む権限がない、ディレクトリである、内容が正しい UTF-8 でない、などの場合に `Result.Error` を返す。相対パスは、処理系を起動したときの作業ディレクトリを基準にする。内容の先頭の BOM（U+FEFF）は取り除かない。

【決定】処理系のプロセスの中で複数の実行を行うとき（初回リリース版のテストの実行器）は、実行ごとに与える基準のディレクトリを、その実行の作業ディレクトリとして扱う。本章と[IO のモジュール](../03-interop/03-07-io-modules.md)の「処理系を起動したときの作業ディレクトリ」は、この場合は基準のディレクトリと読み替える。`Process.workingDirectory` も基準のディレクトリを返す（[ADR 0165](../decisions/0165-exit-and-stdio-in-embedded-runs.md)）。
- `Process.arguments()` の並びには、スクリプトのファイルのパスを含めない。スクリプトに渡した引数だけを、渡した順に含む。

【決定】初回リリース版では、`Benitoite.IO.Process` に、実行を始めるスクリプトのディレクトリを返す関数を加える（[ADR 0131](../decisions/0131-script-directory-and-permission-base.md)）。

| 関数 | 型 | 振る舞い |
|---|---|---|
| `Process.scriptDirectory()` | `function() -> String uses Process.Environment` | 実行を始めるスクリプトのファイルがあるディレクトリの絶対パスを返す |

- 返すパスは、シンボリックリンクを解決した絶対パスである。処理系を起動したときの作業ディレクトリには依存しない。
- 実行時の権限制御の許可は要らない（後述の「実行時の権限制御（サーバモード）」）。スクリプトと一緒に置いたファイルは、このパスから作ったパスで操作する。

【方針】初回リリース版では、バイト列（[標準ライブラリ](../03-interop/03-06-stdlib.md)の `Bytes`）を読み書きする次の関数を加える（[ADR 0107](../decisions/0107-bytes.md)）。

| 関数 | 型 | 振る舞い |
|---|---|---|
| `File.readBytes(path)` | `function(String) -> Result[Bytes, IOError] uses File.Read` | `path` のファイルの内容全体を、文字コードを解釈せずにバイト列として読む |
| `File.writeBytes(path, data)` | `function(String, Bytes) -> Result[Unit, IOError] uses File.Write` | `path` のファイルを作るか置き換え、内容を `data` にする |

- `File.readBytes` の失敗は、内容の文字コードを除き、`File.readText` と同じである。
- 要する許可（後述の「実行時の権限制御（サーバモード）」）は、`File.readBytes` が `File.Read`、`File.writeBytes` が `File.Write` である。

初回リリース版の IO のモジュールの関数（標準入力の読み取り、ファイルとディレクトリの操作、ファイルのリソースの型、環境変数、外部コマンドの起動、時刻、乱数など）の一覧と、各関数が要する権限は、[IO のモジュール](../03-interop/03-07-io-modules.md)で定める。本節の表の関数も、同章の一覧に含める。

### 可変のセル（初回リリース版）

【方針】初回リリース版の prelude は、可変のセル `Reference[T]` を扱う関数として次のものを定める（[ADR 0063](../decisions/0063-ref-cells-with-io-effect.md)）。セルの操作のエフェクトは、prelude で宣言した `State` である（[ADR 0116](../decisions/0116-builtin-fine-grained-effects.md)、[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)）。これらの関数はエフェクトの操作ではなく、`State` を型に持つ組み込みの関数であり、ハンドラで処理できない。

| 関数 | 型 | 振る舞い |
|---|---|---|
| `Reference.new(v)` | `function[T](T) -> Reference[T] uses State` | `v` を入れた新しいセルを作る |
| `Reference.get(r)` | `function[T](Reference[T]) -> T uses State` | `r` に入っている値を返す |
| `Reference.set(r, v)` | `function[T](Reference[T], T) -> Unit uses State` | `r` に入っている値を `v` に変える |
| `Reference.update(r, f)` | `function[T](Reference[T], function(T) -> T) -> Unit uses State` | `r` に入っている値を、それに `f` を適用した値に変える。`f` はエフェクトを持たない |

- セルは値として渡せる。同じセルを指す値はどれも同じセルを指し、一方から書き換えた値は、他方から読んでも見える。
- `Reference.get` は、それまでに最後に `Reference.set` で書いた値（書いていなければ `Reference.new` に渡した値）を返す。
- セルの操作は外部の状態を読み書きしないので、IO の失敗は起きない。
- セルは、並行に進むタスクの間で共有してよい。セルの一つの操作は、ほかのタスクの操作と混ざらない。`Reference.update` の読み出しから書き込みまでの間に、ほかのタスクがそのセルを操作することはない（[並行処理](01-11-concurrency.md)、[ADR 0115](../decisions/0115-structured-io-concurrency.md)）。

```text
function countNonEmpty(lines: List[String]) -> Integer uses State
  bind n <- Reference.new(0)
  List.forEach(lines, lambda(line)
    if String.trim(line) <> "" then Reference.set(n, Reference.get(n) + 1) end if
  end lambda)
  return Reference.get(n)
end function
```

### 影響の大きい操作（初回リリース版）

【決定】外部コマンドの起動、終了状態を指定したプロセスの終了、ファイルの書き込みは、それぞれ `Process.Run`・`Process.Exit`・`File.Write` のエフェクトを持つ関数で行う（[ADR 0117](../decisions/0117-capabilities-as-effects.md)、[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)）。関数の型のエフェクトにこれらを含まない関数は、これらの操作を行わない。保証の範囲は[セキュリティモデル](../07-quality/07-01-security-model.md)で定める。

【方針】影響の大きい操作の規則は次のとおりである。

- 外部コマンドの起動の関数（`Process.run` など）とシェルによる実行の関数（`Process.shell`）は、`Benitoite.IO.Process` に置く。名前と型は[IO のモジュール](../03-interop/03-07-io-modules.md)の「Process」で定める。
- 終了状態を指定してプロセスを終える関数 `Process.exit` は、`Benitoite.IO.Process` に置く。型は[IO のモジュール](../03-interop/03-07-io-modules.md)の「Process」で定める。この関数は、評価をやめ、すべてのタスク（[並行処理](01-11-concurrency.md)）で開いている `with` のリソースを内側のスコープから順に解放し（[リソース管理](01-10-resources.md)）、出力をすべて書き出してから、指定した終了状態で終わる。解放が失敗したときは、その失敗を標準エラー出力に報告し（解放の失敗を実行時エラーにしないリソースの型を除く。[リソース管理](01-10-resources.md)の「解放の失敗」）、終了状態は指定したものから変えない。出力の書き出しが失敗したときも、同じく報告し、終了状態は変えない。

```text
import Benitoite.IO.Process

function tagRelease(tag: String) -> Result[Unit, String] uses Process.Run
  bind output <- try Process.run(Process.command("git", ["tag", tag])) |> Result.mapError(_, IOError.message)
  return if Process.Output.exitCode(output) = 0 then Result.Ok(()) else Result.Error(Process.Output.standardError(output)) end if
end function

function main() -> Result[Unit, String] uses Process.Run
  return tagRelease("v1.0")
end function
```

`Process.run` は、コマンドが 0 以外の終了状態で終わっても `Result.Ok` を返すので、この例は終了状態を調べて失敗を `Result.Error` にする（[IO のモジュール](../03-interop/03-07-io-modules.md)）。

### 利用者が定義するエフェクトとハンドラ（初回リリース版）

【決定】初回リリース版では、利用者がエフェクトを宣言し、ハンドラでその操作を処理できる（[ADR 0118](../decisions/0118-effect-handlers.md)）。エフェクトはモジュールの中で宣言し、その操作は、エフェクトを宣言したモジュールの関数である（[ADR 0129](../decisions/0129-effects-declared-in-modules.md)）。構文は[構文](01-02-syntax.md)の「エフェクトの宣言とハンドラ（初回リリース版）」で定める。

次の例は、一つのファイルの中でエフェクト `Log` を宣言して使う。同じモジュールの中では、エフェクトを `Log`、操作を `write` と修飾せずに書く。

```text
import Benitoite.IO.Console

effect Log
  function write(message: String) -> Unit
end effect

function process(items: List[String]) -> Integer uses Log
  List.forEach(items, lambda(item) write("item: " + item) end lambda)
  return List.length(items)
end function

function main() -> Unit uses Console.Write
  bind count <- handle
    process(["a", "b"])
  with
    case write(message) ->
      Console.writeLine(message)
      resume(())
  end handle
  Console.writeLine(Integer.toString(count))
end function
```

同じエフェクトを根の下の `Logging.bnt` で `public effect Log` と宣言したときは、取り込んだ側から、エフェクトを `Logging.Log`、操作を `Logging.write` と書く。ハンドラの節も `case Logging.write(message) ->` と書く。

【方針】エフェクトの宣言と操作の規則は次のとおりである。

- エフェクトの宣言は、エフェクトの名前と、操作（operation）の並びからなる。操作は、名前、引数、戻り値の型を持ち、型パラメータを持ってよい。操作は `uses` を持たない。エフェクトは型パラメータを持たない。
- 操作は、エフェクトを宣言したモジュールの関数であり、関数と同じ名前の規則で呼ぶ。宣言したモジュールの中では `write(引数)`、ほかのモジュールからは `Logging.write(引数)` と書く（[ADR 0129](../decisions/0129-effects-declared-in-modules.md)）。操作の呼び出しは、そのエフェクトを生じる。操作の名前は、同じモジュールのほかの関数と同じ名前空間にあり、同じ名前の関数と操作を宣言すると誤りとする。
- 組み込みのエフェクトの操作は、そのエフェクトを宣言した標準ライブラリのモジュールの IO の関数（`Console.writeLine`、`File.readText` など）である（[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)）。
- エフェクトの名前は、型の名前と同じく大文字の名前であり、`uses` に書ける。宣言したモジュールの中では `Log`、ほかのモジュールからは `Logging.Log` と、モジュールの名前で修飾して書く。モジュールと同じ名前のエフェクトは宣言できない。`public` を付けたエフェクトとその操作は、ほかのモジュールから使える（[名前・スコープ・モジュール](01-03-names-modules.md)）。

【方針】ハンドラ `handle 本体 with case 操作(引数) -> 節 … end handle` の意味は次のとおりである。`case` の後の操作は、式で操作を呼ぶときと同じ名前で書く（`case write(message) ->`、`case Logging.write(message) ->`、`case Console.writeLine(s) ->`）。

- 本体を評価する。本体の評価の途中で操作を呼ぶと、その操作の節を持つ、最も内側のハンドラが処理する。節の引数には、操作の呼び出しの引数を束縛する。
- 節の中で `resume(v)` を評価すると、操作の呼び出しの結果を `v` として、本体の続きを実行する。本体の続きの中で再び呼んだ操作も、同じハンドラが処理する（深いハンドラ）。`resume(v)` の値は、続きを実行し終えたときの `handle` の式の値である。
- 本体が値で終われば、その値が `handle` の式の値である。節が値で終われば、その値が `handle` の式の値である。
- 節は、ハンドラの外側で実行する。節の中で呼んだ操作は、外側のハンドラが処理する。
- 節の中の `return` と `try` は、`handle` を含む関数の呼び出しを終える。
- `handle` の本体の中で起動したタスクは、ハンドラを引き継ぐ。タスクの中で呼んだ操作を引き継いだハンドラが処理するときは、節は末尾で再開する節に限る（[並行処理](01-11-concurrency.md)の「タスクとハンドラ」、[ADR 0151](../decisions/0151-inherited-handlers-tail-resume-only.md)）。

【決定】継続は一度だけ再開できる（[ADR 0118](../decisions/0118-effect-handlers.md)）。

- `resume` は節の中でだけ直接呼べる。節の中のラムダと `lazy` の本体からは呼べない（[ADR 0155](../decisions/0155-resume-not-in-lazy.md)）。
- 一つの節の実行の中で `resume` を二度呼ぶと、実行時エラー（継続の二度目の再開）とする。
- 節が `resume` を呼ばずに終わったとき（値で終わるとき、`return` や `try` で関数を終えるとき、実行時エラーで止まるとき）は、本体の続きを捨てる。このとき、本体の中で開いていた `with` のリソースを、内側のスコープから順に解放する（[リソース管理](01-10-resources.md)）。本体の中で起動した、終わっていないタスクは取り消す（[並行処理](01-11-concurrency.md)）。

【方針】組み込みのエフェクトの操作も、`handle` で処理できる。ただし、`State` は操作を持たないエフェクトであり、`State` を型に持つ関数（可変のセルとタスクの集まりの関数、`Task.await`、リソースを解放する関数）を節の `case` に書くと誤りとする。どのハンドラも処理しない組み込みの操作は、処理系が実際に行う。処理系が行う操作だけが、実行時の権限制御（後述）の対象になる。

【方針】ハンドラを使えば、テストで組み込みの操作を差し替えられる（[ADR 0117](../decisions/0117-capabilities-as-effects.md)）。次の例は、ファイルを読む関数を、実際のファイルを読まずに確かめる。

```text
import Benitoite.IO.File

function readPort(path: String) -> Result[Integer, String] uses File.Read
  bind text <- try File.readText(path) |> Result.mapError(_, IOError.message)
  return Integer.parse(String.trim(text)) |> Option.okOr(_, "not a number")
end function

function portIsRead() -> Boolean uses File.Read
  bind result <- handle
    readPort("app.conf")
  with
    case File.readText(path) ->
      resume(Result.Ok("8080"))
  end handle
  return result = Result.Ok(8080)
end function
```

`portIsRead` の本体の `handle` は `File.Read` のすべての操作を処理するわけではないが、本体が呼ぶ `File.Read` の操作は `File.readText` だけなので、処理しない操作は呼ばれない。型の上では、一部の操作だけを処理したエフェクトは除かない（[型システム](01-06-type-system.md)）ので、`portIsRead` は `uses File.Read` を書く必要がある。テストの書き方と実行器は[利用者プログラムのテスト](../06-tooling/06-04-test-runner.md)で定める。

### 実行時の権限制御（サーバモード）

【決定】初回リリース版の処理系は、本節の実行時の権限制御を行わない。スクリプトは、処理系を起動した利用者の OS の権限で行える操作をすべて行える。本節は、初回リリース版の後にサーバモードとあわせて加える実行時の権限制御の方針である（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)、[OPEN-055](../open-issues.md#open-055)）。

【方針】処理系は、利用者が許可していない操作を実行時に拒否する。拒否は実行時エラー（権限の拒否）とし、報告には、拒否した操作の種類と対象（パス、コマンドの名前など）を含める（[ADR 0071](../decisions/0071-permission-declaration-and-runtime-denial.md)、[ADR 0147](../decisions/0147-remove-permission-declaration-syntax.md)）。

【決定】スクリプトは、権限を宣言しない。権限の宣言の構文は設けない（[ADR 0147](../decisions/0147-remove-permission-declaration-syntax.md)）。

【決定】利用者は、スクリプトに許可する操作を一つの形の方針として書く。処理系は、その方針から、実行前のエフェクトによる判定、実行中の権限の判定、OS のサンドボックスの設定を導く。方針は `server settings` が利用者単位のファイルに書き、スタンドアロンモードもそのファイルを読む。実行するときに利用者が渡す方針は、許可を狭める向きにだけ働く（[ADR 0183](../decisions/0183-single-policy-for-all-permission-layers.md)、[ADR 0186](../decisions/0186-run-time-policy-can-only-narrow.md)、[ADR 0187](../decisions/0187-standalone-reads-user-policy-file.md)）。方針のファイルの形は、[サーバモード](../06-tooling/06-07-server.md)の「方針のファイル」で定める。

【決定】許可は、次の組み込みのエフェクトを単位とし、それぞれに対象を添えて与える。シェルによる実行（前述の `Process.shell`）は、エフェクトは `Process.Run` であるが、`Process.Run` とは別に許可を与える。実行する内容が実行時まで分からないからである（[ADR 0184](../decisions/0184-permissions-granted-per-builtin-effect.md)）。どの標準ライブラリの関数がどの許可を要するかは、関数の一覧の「要する権限」の欄に示す（[IO のモジュール](../03-interop/03-07-io-modules.md)、[ネットワークのモジュール](../03-interop/03-09-network.md)）。

| 許可の単位 | 対象 | 許可する操作 |
|---|---|---|
| `File.Read` | パス | そのパスのファイル、またはそのディレクトリの下のファイルとディレクトリの読み取り |
| `File.Write` | パス | そのパスのファイル、またはそのディレクトリの下のファイルとディレクトリの作成・書き込み・削除・移動 |
| `Process.Run` | コマンド | そのコマンドの起動（引数は問わない）。照合の方法は後述する。シェルによる実行は含まない |
| シェルによる実行 | なし | シェルの起動（`Process.shell`）と、そのシェルからの、`Process.Run` で許したコマンドの起動 |
| `Process.Environment` | 環境変数の名前 | その名前の環境変数の読み取り |
| `Process.Exit` | なし | 終了状態を指定したプロセスの終了 |
| `Http.Listen` | 待ち受けるアドレス | 接続の待ち受けと、要求の受け付けと応答 |
| `Http.Connect` | 接続先 | HTTP のサーバへの接続と、要求の送信 |

- 標準出力と標準エラー出力への書き込み、標準入力の読み取り（`Console.Read`）、コマンドライン引数の読み取り、実行を始めるスクリプトのディレクトリの読み取り（`Process.scriptDirectory`）、作業ディレクトリの読み取り（`Process.workingDirectory`）、時刻の読み取りと時間の経過を待つこと（`Clock.Time`）、乱数の生成（`Random.Generate`）、可変のセルの操作は、許可なしに行える（[IO のモジュール](../03-interop/03-07-io-modules.md)の「要する権限」の欄の「なし」）。
- 方針のファイルの書き方（シェルによる実行の許可の書き方を含む）は、[サーバモード](../06-tooling/06-07-server.md)の「方針のファイル」で定める。`Http.Listen` と `Http.Connect` の対象の書き方と照合は、[OPEN-052](../open-issues.md#open-052) で決める。

【決定】どの許可の単位でも、エフェクトを許すことと、対象の並びは別の指定である。対象の並びを空にして許した単位は、エフェクトを許したものとして実行の前の判定を通り、実行時にはどの対象の操作も許さない。たとえば、`Process.Environment` を対象の並びを空にして許すと、スクリプトはコマンドライン引数と二つのディレクトリ（`Process.scriptDirectory`・`Process.workingDirectory`）を読めるが、どの環境変数も読めない。既定の方針は、`Process.Environment` をこの形で許す（[ADR 0214](../decisions/0214-default-policies-allow-process-environment-with-no-names.md)）。

【決定】方針には、許可に加えて除外を書ける。除外は許可に優先する。実行ごとの方針を複数の方針から決めるときは、どれかの方針の除外に当たる操作を許さない。実行の前の判定と実行時の判定は、除外を直接使う。単位ごと除外したエフェクトは、実行の前の判定で許さないものとして扱い、対象を添えた除外は、実行時に、その対象に当たる操作を拒否する（[ADR 0216](../decisions/0216-policy-deny-rules-and-standalone-defaults.md)）。

【決定】シェルによる実行の許可は、シェルを起動し、そのシェルから `Process.Run` で許したコマンドを起動することを許す。処理系の中の判定は、シェルに渡した文字列の中で起動するコマンドを調べない。シェルから起動するコマンドを `Process.Run` で許したものに限るのは、OS のサンドボックスである（[ADR 0215](../decisions/0215-shell-permission-allows-run-commands-via-shell.md)、[OS のサンドボックス](../02-impl/02-12-os-sandbox.md)）。OS のサンドボックスを掛けられずに処理系の中の判定だけで実行したときは、シェルから任意のコマンドを起動できる（[セキュリティモデル](../07-quality/07-01-security-model.md)）。

【方針】許可したパスの相対パスは、ファイルの操作の相対パスと同じく、処理系を起動したときの作業ディレクトリから辿る。実行時の判定では、許可したパスと操作の対象のパスの両方を絶対パスにし、シンボリックリンクを解決する。操作の対象がまだ存在しないときは、存在する最も深い親のディレクトリまでを解決し、残りの構成要素をその後に付ける。操作の対象のパスは、許可したパスのすべての構成要素（`/` で区切った部分）が先頭から一致するときに、許可したパスの下にあるとする。したがって、`./data` を読む許可は `./data/a.txt` を許可し、`./database` を許可しない。実行前の権限の表示では、許可したパスを解決した絶対パスを示す（[ADR 0072](../decisions/0072-permission-path-matching.md)）。

大文字と小文字を区別しないファイルシステムでの照合と、OS ごとのシンボリックリンクの解決の挙動は【要検証】である（[OPEN-057](../open-issues.md#open-057)）。

【方針】`Process.Run` の許可の照合は、許可したコマンドの名前が `/` を含むかで分ける（[ADR 0073](../decisions/0073-run-permission-command-matching.md)）。

- `/` を含まない名前（`git`）は、スクリプトが同じ名前を `/` を含まない形で起動し、処理系が PATH から実行ファイルを探したときにだけ一致する。パスを含む起動（`/usr/bin/git`、`./git`）には一致しない。実行時エラーの報告には、見つけた実行ファイルの絶対パスを含める。
- `/` を含む名前（`./tools/fmt`）は、許可したパスと同じく作業ディレクトリから辿って絶対パスにし、シンボリックリンクを解決する。起動するコマンドも同じく解決し、二つの絶対パスが等しいときに一致する。

【決定】実行の前に、プログラムが要する許可を `main` の型のエフェクトで判定する。`main` のエフェクトに、方針が許可しないエフェクトが含まれていれば、実行せずに拒否する。対象の並びを空にして許したエフェクトは、許可したエフェクトに含める（前述）。まとめた名前（`IO.All`）は、まとめたすべてのエフェクトを要するとみなす。ハンドラで処理したエフェクトは `main` の型に現れず、処理系も行わないので、許可を要しない（[ADR 0183](../decisions/0183-single-policy-for-all-permission-layers.md)）。シェルによる実行は、エフェクトでは `Process.run` と区別できないので、プログラムを構成するすべてのモジュールのどこかで `Process.shell` を名前で参照していれば、シェルによる実行の許可を要すると判定する。参照した箇所が実行されるかどうかは問わない（[ADR 0074](../decisions/0074-static-permission-check-by-name-reference.md)、[ADR 0184](../decisions/0184-permissions-granted-per-builtin-effect.md)）。操作の対象（どのパスか、どのコマンドか）は、実行時に調べる。

【方針】実行時の権限制御と、エフェクトによる静的な検査は、別々の機構である（[目的と設計原則](../00-overview/00-01-goals.md)）。エフェクトは「どの関数がどの種類の操作をしうるか」を実行の前に制限し、実行時の権限制御は「どの対象に対して操作してよいか」を実行時に制限する。拒否できるのは、処理系が権限を判定する経路を通る操作に限る。保証の範囲と、その経路の外にある操作は[セキュリティモデル](../07-quality/07-01-security-model.md)で定める。

【方針】利用者が要る権限を読んで実行を承認する手順と、承認した後に権限や契約が変わったときの示し方は、[OPEN-015](../open-issues.md#open-015) で定める。

### 外部のライブラリのエフェクトと権限の表示（初回リリース版の後）

前節の実行の前の判定は `main` の型のエフェクトで行い、ハンドラで処理したエフェクトは `main` の型に現れない。そのため、外部のコマンドやサービスを包むライブラリ（git のラッパーなど）が専用のエフェクト（`Git.Read` など）を宣言し、既定のハンドラの中で `Process.run` を呼んでも、`main` の型と実行の前の権限の表示に残るのは `Process.Run` だけである。`Process.Run` の許可はコマンドの名前を単位とし、引数を問わない（前節の表）ので、利用者は、そのライブラリが行う操作の違い（`git log` と `git push` など）を権限の上で見分けられない。

【未決】初回リリース版の後に、こうしたライブラリのエフェクトを権限の表示にどう出すかは、[OPEN-081](../open-issues.md#open-081) で決める。候補は、ライブラリのエフェクトのまま言語を変えない案、よく使う少数の道具のエフェクトを組み込みのエフェクトにする案、`Process.Run` の許可の対象を引数の先頭まで細かくする案（照合の規則は [OPEN-083](../open-issues.md#open-083)）、利用者がエフェクトのまとめを宣言できるようにする案である。どの道具のエフェクトを組み込みのエフェクトにするかは決めていない。

### 秘密の値とエフェクト（初回リリース版の後）

API キー・アクセス用のトークン・パスワードなどの秘密の情報（以下、秘密）を `String` の値で扱うと、スクリプトはそれを標準出力や記録に書き出せる。コーディングエージェントの下では、エージェントが標準出力を捕らえて LLM に渡すので、書き出した秘密は LLM に渡る。

【未決】初回リリース版の後に、中身を見せない秘密の型（`Secret` の案）と、秘密を受け取る操作と文字列として取り出す操作のエフェクト（`Secret.Read`・`Secret.Reveal` の案）を設けるかは、[OPEN-088](../open-issues.md#open-088) で決める。これらを組み込みのエフェクトにするか、公式のライブラリのエフェクトにするかは、前節の [OPEN-081](../open-issues.md#open-081) とあわせて決める。ライブラリのエフェクトにすると `main` の型に現れないので、秘密を取り出すスクリプトであることを権限の表示に出せない。

## 未決事項

- [OPEN-015](../open-issues.md#open-015): 契約の変更と権限の差分を利用者に示す方法
- [OPEN-057](../open-issues.md#open-057): 権限のパスの照合の、OS ごとの挙動を含むサーバモードの事実の確認
- [OPEN-052](../open-issues.md#open-052): 実行時の権限制御の方式
- [OPEN-055](../open-issues.md#open-055): サーバモードの設計
- [OPEN-012](../open-issues.md#open-012): 構文の種類ごとの LLM の生成精度（IO の失敗の扱いと `main` の形を測定課題に含める）
- [OPEN-062](../open-issues.md#open-062): 設計書の 2 回目のレビューで指摘された実行時の振る舞いの再現（R01）
- [OPEN-081](../open-issues.md#open-081): 外部のライブラリのエフェクトを、権限の表示にどう出すか
- [OPEN-083](../open-issues.md#open-083): `Process.Run` の許可の対象を引数まで細かくするときの照合の規則
- [OPEN-088](../open-issues.md#open-088): 秘密の値の型と、秘密を扱うエフェクト
