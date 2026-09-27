# エフェクト

- 状態: 草稿
- 関連ADR: [0005](../decisions/0005-direct-style-effects.md), [0008](../decisions/0008-effect-variables.md), [0011](../decisions/0011-io-failure-and-entry-point.md), [0012](../decisions/0012-invalid-utf8-input.md), [0037](../decisions/0037-exit-status-values.md), [0045](../decisions/0045-late-detection-of-output-write-failure.md), [0048](../decisions/0048-ioerror-not-equality-type.md), [0063](../decisions/0063-ref-cells-with-io-effect.md), [0065](../decisions/0065-ioerror-kind.md), [0069](../decisions/0069-capabilities-passed-from-main.md), [0070](../decisions/0070-capabilities-for-high-impact-operations.md), [0071](../decisions/0071-permission-declaration-and-runtime-denial.md), [0072](../decisions/0072-permission-path-matching.md), [0073](../decisions/0073-run-permission-command-matching.md), [0074](../decisions/0074-static-permission-check-by-name-reference.md), [0075](../decisions/0075-capability-guarantee-scope-and-test-substitution.md)
- 未決事項: [OPEN-012](../open-issues.md#open-012), [OPEN-015](../open-issues.md#open-015), [OPEN-018](../open-issues.md#open-018), [OPEN-026](../open-issues.md#open-026), [OPEN-029](../open-issues.md#open-029), [OPEN-032](../open-issues.md#open-032)
- 移行元: [設計メモ](../sources/fp-language-design.md) 3.1–3.5

## 目的と範囲

エフェクトの注釈（`uses`）と検査、ケーパビリティ、ハンドラ、段階導入の各段階で有効な規則。段階の区切りと時期は[ロードマップ](../00-overview/00-03-roadmap.md)が定める。

現在の版は、最小実行版の範囲（エフェクトの段階導入の段階 1）と、v1 の範囲（段階 2）を定める。最小実行版の範囲は、IO エフェクトが表す操作、IO が起きる時期と順序、IO の失敗の扱い、プログラムの入口 `main`、IO を行う組み込み関数である。v1 の範囲は、可変のセル、ケーパビリティ、権限の宣言と実行時の権限制御である。利用者が定義するエフェクトとハンドラは、後の段階で加える。

## 前提

`uses` の構文は[構文](01-02-syntax.md)で定める。関数の型が持つエフェクトの集合、式のエフェクト、関数の本体のエフェクトの検査、エフェクト変数とエフェクトの包含は[型システム](01-06-type-system.md)で定める。本章は、型システムが検査するエフェクトの名前 `IO` が、実行のときに何を意味するかを定める。

式の評価順序と、実行時エラーが起きたときにプログラムがどう停止するかは[評価意味論](01-08-evaluation.md)で定める。

## 仕様

### エフェクトの型と権限制御の区別

【方針】エフェクトの型は、関数を呼んだときにどの種類の操作が起こりうるかを、実行の前に検査するための情報である。実行のときに、どの操作を許すかを決める権限制御とは別の機構である（[設計メモ](../sources/fp-language-design.md) 3.2）。

最小実行版は、エフェクトの型の検査だけを行い、実行時の権限制御を行わない（[ロードマップ](../00-overview/00-03-roadmap.md)）。`uses IO` を持つ関数は、最小実行版の処理系が提供するすべての IO を行える。

### IO エフェクトが表す操作

【方針】IO エフェクトは、プログラムの外部の状態を読むか、変える操作を表す。v1 では、加えて可変のセルの操作を表す。最小実行版で IO に当たる操作は次のとおりである。

- 標準出力と標準エラー出力への書き込み
- ファイルの読み取り
- コマンドライン引数の読み取り

v1 では、可変のセルを作る・読む・書き換える操作も IO エフェクトに含める（[ADR 0063](../decisions/0063-ref-cells-with-io-effect.md)、後述の「可変のセル（v1）」）。

次のものは IO エフェクトに含めない。

- 実行時エラー（整数の溢れ、0 による除算など）。実行時エラーを起こしうることを型やエフェクトで表すかは【未決】である（[OPEN-026](../open-issues.md#open-026)）。
- 停止しないこと。
- メモリなど、処理系の資源を使い果たすこと。

可変のセルの操作も IO エフェクトを持つので、純粋な関数（[型システム](01-06-type-system.md)）の結果は、v1 でも引数だけで決まる。資源の不足（[評価意味論](01-08-evaluation.md)）を除けば、同じ引数で二度呼んだとき、同じ値を返すか、同じ実行時エラーを起こすか、どちらも停止しない。

### IO が起きる時期と順序

【決定】IO は、IO を行う関数の呼び出しを評価したときに起こる（[ADR 0005](../decisions/0005-direct-style-effects.md)）。IO の計算を値として構築する型（`IO[T]` など）はない。

【方針】IO が起きる時期と順序について、次の規則を定める。

- 一つの呼び出しを評価するたびに、その関数の IO が一度起こる。
- ラムダの式を評価しても、本体の IO は起こらない。本体の IO は、そのラムダを呼び出したときに起こる。
- 複数の IO は、それを含む式を評価する順に起こる。評価の順序は[評価意味論](01-08-evaluation.md)で定める。

【方針】標準出力と標準エラー出力のそれぞれで、書き込んだ内容は書き込みの呼び出しの順に現れる。標準出力と標準エラー出力の間で、現れる順序が呼び出しの順と一致することは保証しない。プログラムが正常に終わる場合、`main` が `Err` を返した場合、実行時エラーで停止する場合、資源の不足で停止する場合は、それまでに書き込んだ内容を、終了の前にすべて出力しなければならない。ただし、書き込みそのものが失敗した場合（次節）と、処理系が上限を設けていない資源が実行環境で尽きた場合（[評価意味論](01-08-evaluation.md)の「資源の不足」）は、書き込んだ内容の一部が出力されないことがある。

### IO の失敗

【決定】外部の状態によって失敗しうる IO の関数は、`Result[T, IoError]` を返す（[ADR 0011](../decisions/0011-io-failure-and-entry-point.md)）。`IoError` は、構成子を公開しない prelude の型である。`IoError` の値はパターンで分解できない。

【決定】`IoError` は中身を見せない prelude の型であり、基本型にも代数的データ型にも含めない（[ADR 0048](../decisions/0048-ioerror-not-equality-type.md)）。`IoError` とそれを含む型（`Result[String, IoError]` など）は等値の型ではなく、`==` と `!=` で比べられない（[型システム](01-06-type-system.md)の「等値の型」）。失敗の種類を調べるには、`IoError.message` で文字列にするか、`match` で `Ok` と `Err` を分ける。

【方針】`IoError` に対して、次の関数を定める。

| 関数 | 型 | 値 |
|---|---|---|
| `IoError.message(e)` | `fn(IoError) -> String` | 失敗の理由を、人間が読める形で表す文字列 |

`message` の文字列の具体的な文面は定めない。文面は処理系の版によって変わりうるので、失敗の種類を判定する手段にはならない。v1 では、失敗の種類を `IoError.kind` で取り出せる（[エラー処理](01-09-errors.md)、[ADR 0065](../decisions/0065-ioerror-kind.md)）。

【方針】標準出力と標準エラー出力への書き込みが失敗したときは、実行時エラー（書き込みの失敗）とする。書き込みの関数は `Result` を返さない。

【決定】書き込みの失敗は、書き込みの関数を呼び出した時点ではなく、後で検出してよい（[ADR 0045](../decisions/0045-late-detection-of-output-write-failure.md)）。処理系は、失敗を検出した時点で、書き込みの失敗による実行時エラーとして停止する。この報告は、ソース上の位置を持たない。失敗を検出するまでに行った評価と IO は取り消さない。処理系は、失敗を遅くともプログラムを終える前の書き出しで検出する。書き出す時期は処理系の設計（[ランタイム](../02-impl/02-09-runtime.md)）で定める。停止の手順は[評価意味論](01-08-evaluation.md)の「実行時エラーによる停止」で定める。

最小実行版には、`Err` を呼び出し元へ伝える構文（Rust の `?` など）はない。`Err` は `match` か、`Result` を扱う prelude の関数で扱う。v1 では後置の `?` を設けることを方針とし、規則を[エラー処理](01-09-errors.md)で定める。`?` を確定するかは【未決】である（[OPEN-029](../open-issues.md#open-029)）。

### 外部から受け取る文字列

【決定】外部のバイト列を `String` として受け取る操作は、正しくない UTF-8 のバイト列を置き換えたり捨てたりしない（[ADR 0012](../decisions/0012-invalid-utf8-input.md)）。ファイルの内容が正しい UTF-8 でなければ、`File.readText` は `Err` を返す。コマンドライン引数の扱いは次節で定める。

### プログラムの入口

【決定】プログラムの入口は、引数を取らないトップレベルの関数 `main` である（v1 では、実行を始めるモジュールの `main`。[名前・スコープ・モジュール](01-03-names-modules.md)）。v1 では、`main` は `Caps` 型の引数を一つとってもよい（後述の「ケーパビリティ（v1）」、[ADR 0069](../decisions/0069-capabilities-passed-from-main.md)）。`main` の戻り値の型は `Unit` か `Result[Unit, String]` である（[ADR 0011](../decisions/0011-io-failure-and-entry-point.md)）。

【方針】`main` は、加えて次の条件を満たさなければならない。

- 型パラメータとエフェクト変数を持たない。
- エフェクトは `IO` か空集合である（`uses IO` を書くか、`uses` を書かない）。

`main` がないとき、または `main` が上の条件を満たさないときは、型検査の誤りとする。

次の例は最小実行版のスクリプトである。v1 では、ファイルを読むので `read` の権限の宣言が要る（後述の「権限の宣言（v1）」）。

```text
fn main() -> Result[Unit, String] uses IO {
  match File.readText("input.txt") {
    Ok(text) => {
      Console.println(Int.toString(List.length(String.lines(text))))
      Ok(())
    }
    Err(e) => Err(IoError.message(e))
  }
}
```

【方針】処理系は、プログラムを実行するときに次の順で処理する。

1. コマンドライン引数を検査する。どれかが正しい UTF-8 でなければ、その引数の位置を示す診断を出し、`main` を呼ばずに失敗を表す終了状態で終わる（[ADR 0012](../decisions/0012-invalid-utf8-input.md)）。
2. `main` を一度呼び出す。
3. `main` の戻り値によって終わる。

| `main` の終わり方 | 処理系の振る舞い |
|---|---|
| `()` を返す | 成功を表す終了状態で終わる |
| `Ok(())` を返す | 成功を表す終了状態で終わる |
| `Err(msg)` を返す | `msg` と改行を標準エラー出力に書き、失敗を表す終了状態で終わる |
| 実行時エラーまたは資源の不足で停止する | [評価意味論](01-08-evaluation.md)で定める |

終了状態の具体的な値と、スクリプトにコマンドライン引数を渡す方法は [CLI](../06-tooling/06-01-cli.md) で定める。

### IO を行う組み込み関数

【方針】最小実行版の prelude は、IO を行う関数として次のものを定める（[ADR 0011](../decisions/0011-io-failure-and-entry-point.md)）。これ以外の prelude の関数は純粋であり、[標準ライブラリ](../03-interop/03-06-stdlib.md)で定める。

| 関数 | 型 | 振る舞い |
|---|---|---|
| `Console.print(s)` | `fn(String) -> Unit uses IO` | `s` を標準出力に書く |
| `Console.println(s)` | `fn(String) -> Unit uses IO` | `s` と改行を標準出力に書く |
| `Console.eprintln(s)` | `fn(String) -> Unit uses IO` | `s` と改行を標準エラー出力に書く |
| `File.readText(path)` | `fn(String) -> Result[String, IoError] uses IO` | `path` のファイルの内容全体を UTF-8 の文字列として読む |
| `Process.args()` | `fn() -> List[String] uses IO` | コマンドライン引数の並びを返す |

- 改行は U+000A 一文字である。
- `File.readText` は、ファイルが存在しない、読む権限がない、ディレクトリである、内容が正しい UTF-8 でない、などの場合に `Err` を返す。相対パスは、処理系を起動したときの作業ディレクトリを基準にする。内容の先頭の BOM（U+FEFF）は取り除かない。
- `Process.args()` の並びには、スクリプトのファイルのパスを含めない。スクリプトに渡した引数だけを、渡した順に含む。

### 可変のセル（v1）

【方針】v1 の prelude は、可変のセル `Ref[T]` を扱う関数として次のものを定める（[ADR 0063](../decisions/0063-ref-cells-with-io-effect.md)）。

| 関数 | 型 | 振る舞い |
|---|---|---|
| `Ref.new(v)` | `fn[T](T) -> Ref[T] uses IO` | `v` を入れた新しいセルを作る |
| `Ref.get(r)` | `fn[T](Ref[T]) -> T uses IO` | `r` に入っている値を返す |
| `Ref.set(r, v)` | `fn[T](Ref[T], T) -> Unit uses IO` | `r` に入っている値を `v` に変える |

- セルは値として渡せる。同じセルを指す値はどれも同じセルを指し、一方から書き換えた値は、他方から読んでも見える。
- `Ref.get` は、それまでに最後に `Ref.set` で書いた値（書いていなければ `Ref.new` に渡した値）を返す。
- セルの操作は外部の状態を読み書きしないので、IO の失敗は起きない。

```text
fn countNonEmpty(lines: List[String]) -> Int uses IO {
  let n = Ref.new(0)
  List.forEach(lines, fn(line) {
    if String.trim(line) != "" { Ref.set(n, Ref.get(n) + 1) }
  })
  Ref.get(n)
}
```

### ケーパビリティ（v1）

【決定】ケーパビリティ（capability）は、影響の大きい操作を行う権利を表す、中身を見せない prelude の型の値である。利用者のコードはケーパビリティの値を作れない。`main` が `Caps` 型の引数をとると、処理系はケーパビリティの全体を表す `Caps` の値を渡す。個々のケーパビリティは `Caps` から取り出し、ケーパビリティを要する操作に引数で渡す（[ADR 0069](../decisions/0069-capabilities-passed-from-main.md)）。

【決定】v1 でケーパビリティを要する操作は、次のものに限る（[ADR 0070](../decisions/0070-capabilities-for-high-impact-operations.md)）。

| ケーパビリティ | 取り出す関数 | 取り出す関数の型 | 要する操作 |
|---|---|---|---|
| `ExecCap` | `Caps.exec(caps)` | `fn(Caps) -> ExecCap` | 外部コマンドの起動と、シェルによるコマンドの実行（`sh(...)`） |
| `ExitCap` | `Caps.exit(caps)` | `fn(Caps) -> ExitCap` | 終了状態を指定したプロセスの終了 |
| `FsWriteCap` | `Caps.fsWrite(caps)` | `fn(Caps) -> FsWriteCap` | ファイルとディレクトリの作成・書き込み・削除・移動 |

`sh(...)` は、シェルによる実行を行う std の関数を指す仮の表記であり、名前と置き場所は std を設計するときに定める。

標準出力と標準エラー出力への書き込み、ファイルの読み取り、コマンドライン引数と環境変数の読み取り、可変のセルの操作は、ケーパビリティを要しない。

【方針】ケーパビリティの規則は次のとおりである。

- `Caps.exec` などの取り出す関数は、エフェクトを持たない。
- ケーパビリティの型は、どれも等値の型ではない。
- ケーパビリティは、ほかの値と同じく、引数で渡し、ラムダに捕捉し、データ構造に入れられる。このため、関数の型だけでは、その関数がケーパビリティに辿り着けるかは判定できない。保証は「ケーパビリティの値に辿り着けない計算は、そのケーパビリティを要する操作を行えない」の形で述べる（[ADR 0075](../decisions/0075-capability-guarantee-scope-and-test-substitution.md)、[セキュリティモデル](../07-quality/07-01-security-model.md)）。
- ケーパビリティを要する操作の関数（外部コマンドを起動する関数など）は std で定め、ケーパビリティを最初の引数にとる。
- 終了状態を指定したプロセスの終了は、評価をやめ、開いている `with` のリソースを内側のスコープから順に解放し（[リソース管理](01-10-resources.md)）、出力をすべて書き出してから、指定した終了状態で終わる。解放が失敗したときは、その失敗を標準エラー出力に報告し、終了状態は指定したものから変えない。

```text
permissions {
  run "git"
}

fn tagRelease(exec: ExecCap, tag: String) -> Result[Unit, String] uses IO {
  Command.run(exec, ["git", "tag", tag])
}

fn main(caps: Caps) -> Result[Unit, String] uses IO {
  tagRelease(Caps.exec(caps), "v1.0")
}
```

この例の `Command.run` は、説明のための仮の名前である。

### 権限の宣言（v1）

【決定】実行を始めるモジュールに `permissions { ... }` の宣言を書き、スクリプトが必要とする権限を並べる。処理系は、宣言にない操作を実行時に拒否する。検査は、宣言にない種類の操作を呼び出しうるプログラムを誤りとする（[ADR 0071](../decisions/0071-permission-declaration-and-runtime-denial.md)）。

```text
permissions {
  read "./data"
  write "./out"
  run "git"
}
```

【方針】宣言に書ける権限は、次のとおりとする。どの prelude と std の関数がどの種類の権限を要するかは、関数の一覧の「要する権限」の欄に示す（[標準ライブラリ](../03-interop/03-06-stdlib.md)）。

| 権限 | 許可する操作 |
|---|---|
| `read "パス"` | そのパスのファイル、またはそのディレクトリの下のファイルとディレクトリの読み取り |
| `write "パス"` | そのパスのファイル、またはそのディレクトリの下のファイルとディレクトリの作成・書き込み・削除・移動 |
| `run "コマンド"` | そのコマンドの起動（引数は問わない）。照合の方法は後述する |
| `shell` | シェルによるコマンドの実行（`sh(...)`）。実行する内容は実行時まで分からない |
| `env "名前"` | その名前の環境変数の読み取り |
| `exit` | 終了状態を指定したプロセスの終了 |

- パスの権限の `"*"` は、すべてのパスを表す。
- 標準出力と標準エラー出力への書き込み、コマンドライン引数の読み取り、可変のセルの操作は、宣言なしに行える。
- `permissions` の宣言は、実行を始めるモジュールに一つだけ書ける。取り込んだモジュールには書けない。宣言がなければ、宣言なしに行える操作だけを許可する。

【決定】宣言のパスの相対パスは、ファイルの操作の相対パスと同じく、処理系を起動したときの作業ディレクトリから辿る。実行時の判定では、宣言のパスと操作の対象のパスの両方を絶対パスにし、シンボリックリンクを解決する。操作の対象がまだ存在しないときは、存在する最も深い親のディレクトリまでを解決し、残りの構成要素をその後に付ける。操作の対象のパスは、宣言のパスのすべての構成要素（`/` で区切った部分）が先頭から一致するときに、宣言の下にあるとする。したがって、`read "./data"` は `./data/a.txt` を許可し、`./database` を許可しない。実行前の権限の表示では、宣言のパスを解決した絶対パスを示す（[ADR 0072](../decisions/0072-permission-path-matching.md)）。

大文字と小文字を区別しないファイルシステムでの照合と、OS ごとのシンボリックリンクの解決の挙動は【要検証】である（[OPEN-032](../open-issues.md#open-032)）。

【決定】`run` の宣言の照合は、宣言の名前が `/` を含むかで分ける（[ADR 0073](../decisions/0073-run-permission-command-matching.md)）。

- `/` を含まない名前（`run "git"`）は、スクリプトが同じ名前を `/` を含まない形で起動し、処理系が PATH から実行ファイルを探したときにだけ一致する。パスを含む起動（`/usr/bin/git`、`./git`）には一致しない。実行時エラーの報告には、見つけた実行ファイルの絶対パスを含める。
- `/` を含む名前（`run "./tools/fmt"`）は、パスの権限と同じく作業ディレクトリから辿って絶対パスにし、シンボリックリンクを解決する。起動するコマンドも同じく解決し、二つの絶対パスが等しいときに一致する。

【決定】実行の前の検査は、プログラムを構成するすべてのモジュールのどこかで、ある種類の権限を要する prelude・std の関数を名前で参照していれば、プログラムはその種類の権限を要するとみなす。参照した箇所が実行されるかどうかは問わない。要する種類の権限が宣言にないときは、実行の前に誤りとして報告し、診断は足りない宣言を修正案として示す（[ADR 0074](../decisions/0074-static-permission-check-by-name-reference.md)）。操作の対象（どのパスか、どのコマンドか）は、実行時に調べる。

【決定】最小実行版では宣言なしにファイルを読めたが、v1 ではファイルを読むスクリプトに `read` の宣言が要る。最小実行版のスクリプトのうち、ファイルの読み取りを行うものは、v1 では宣言を加えないと誤りになる（[ADR 0074](../decisions/0074-static-permission-check-by-name-reference.md)）。

### 実行時の権限制御（v1）

【決定】処理系は、宣言にない操作を実行時に拒否する。拒否は実行時エラー（権限の拒否）とし、報告には、拒否した操作の種類と対象（パス、コマンドの名前など）を含める（[ADR 0071](../decisions/0071-permission-declaration-and-runtime-denial.md)）。

【方針】実行時の権限制御と、エフェクトとケーパビリティによる静的な検査は、別々の機構である（[目的と設計原則](../00-overview/00-01-goals.md)）。ケーパビリティは「どの関数が影響の大きい操作をしうるか」を実行の前に制限し、権限の宣言は「どの対象に対して操作してよいか」を実行時に制限する。拒否できるのは、処理系が権限を判定する経路を通る操作に限る。保証の範囲と、その経路の外にある操作は[セキュリティモデル](../07-quality/07-01-security-model.md)で定める。

【方針】利用者が宣言を読んで実行を承認する手順と、承認した後に宣言や契約が変わったときの示し方は、[OPEN-015](../open-issues.md#open-015) で定める。

## 未決事項

- [OPEN-015](../open-issues.md#open-015): 契約の変更と権限の差分を利用者に示す方法
- [OPEN-018](../open-issues.md#open-018): 外部に作用するすべての経路を IO 実行器に通せるか
- [OPEN-026](../open-issues.md#open-026): 実行時エラーを起こしうることを型やエフェクトで表すか
- [OPEN-029](../open-issues.md#open-029): エラーを呼び出し元へ伝える構文
- [OPEN-032](../open-issues.md#open-032): 権限のパスの照合の、OS ごとの挙動
- [OPEN-012](../open-issues.md#open-012): 構文の種類ごとの LLM の生成精度（IO の失敗の扱いと `main` の形を測定課題に含める）
