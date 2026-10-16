# try の実装と、失敗を返す・実行を終える処置

## 現在の処理の対応

根拠は [01-09「エラー処理」](../../design/01-spec/01-09-errors.md)、[01-07「プログラムの入口」](../../design/01-spec/01-07-effects.md#プログラムの入口)、01-12 と以下の実装である。`src/` は `crates/benitoite/src/` を指す。

| 段 | 実装と現在の意味 |
|---|---|
| 構文解析 | `syntax/parser/effects.rs::parse_try`。`check_escape` の後に `parse_expr` を呼び、式全体を `TryExpr.value` に持つ。`syntax/ast.rs::TryExpr` は id・span・value を持つ。失敗時の処置の欄はない |
| 式の境界 | `parser/exprs.rs` の Pratt 法の入口で、`return`・`try` を式の先頭に限る。パイプより弱い。`f(try e)` では一引数の範囲にかかる |
| 型検査 | `typeck/effects/mod.rs::try_expr` が入力・最も内側の戻り値・成功値の制約を作る。`effects/special.rs::solve_try` が標準の Result / Option の束縛を確かめる |
| 制約の解決 | 入力の型が未定なら待つ。Result なら成功値 T を式の型とし、戻り値は Result[U, E]。Option なら戻り値は Option[U]。E は等しい型に限る。型注釈のないラムダの戻り値にも制約を加える |
| 診断 | E0440 は対象が Result / Option でない場合、E0441 は囲む戻り値の種類の不一致、E0442 はエラー型の不一致。`mapError`・`okOr`・`ok` の案内を持つ。`try_owners` によって関数・ラムダ・穴から作る関数の作用先を説明する |
| 脱糖 | `ir/desugar/effects.rs::try_expr` / `finish_try`。入力を一度評価し、二つの構成子で照合する。成功は中身を返し、失敗は囲む関数の戻り値の型引数で包み直して `Escape` にする |
| コード生成 | try 専用命令は作らない。脱糖後の照合と Escape が `bytecode/codegen/emit.rs` などで命令になる。失敗の値の型引数を入力の成功型のままにしない点は、脱糖の既存テストにも残る |
| 形式化 | `Surface.Syntax.Expr.tryResult` / `tryOption`、`Typing.E_TryResult` / `E_TryOption`、`Desugar.desugarExpr`、`Lemmas/ReturnTry.lean`、`Check.lean` と健全性の証明。Result の入力と戻り値で E が同じこと、二構成子の網羅性も前提にする |

現在の try 自体は新たな IO エフェクトを加えない。入力のエフェクトを引き継ぐ。`lazy` の直接の本体とガードでは解析段で禁止し、明示した内側のラムダは別の関数境界として扱う。穴を含む呼び出しでは、呼ぶ式と固定引数は生成した関数の本体で評価し、その中の try も生成した関数から抜ける。251 でもこの時期を変えない。

## main・停止・終了状態・表示

`main` は引数なしで、戻り値は Unit または Result[Unit, String] に限る。Result[Unit, IOError] をそのまま入口で受ける規則はない。IOError を返す処理を現在の try で main につなぐときは、`Result.mapError` で String に変換する。

| 終わり方 | 現在の表現 | CLI の基本の扱い |
|---|---|---|
| Unit / Result.Ok(()) | `MainOutcome::Ok` → `EndKind::Returned` | 0 |
| Result.Error(String) | `MainOutcome::Error` → `EndKind::MainError`、`RunEnd.main_error` | 1、原因と改行を標準エラー出力へ |
| 実行時エラー・資源不足 | `Stop::Runtime` / `Stop::Resource` → `StopReason::Error` → `EndKind::Stopped` | 1、実行時の診断 |
| 処理系の不具合 | `Stop::Internal` → `EndKind::Internal` | 3 |
| Process.exit(code) | 組み込みの `IoReply::Exit` → VM の `StopReason::Exit(code)` → `EndKind::Exited(code)` | 指定値。解放・出力の失敗を報告しても指定値を保つ |
| 中断 | `StopReason::Interrupted` → `EndKind::Interrupted` | 130 |

`runtime/mod.rs::Stop` に明示的な終了の枝はない。`vm/mod.rs::StopReason` と `runtime/run.rs` の終わり方を区別する。`or die` を Stop::Runtime の一種に入れると、明示的な失敗終了という251の方針と、テストの報告の分類を損なう。

明示的な終了では、VM の解放処理を通り、今回の実行のタスクを止め、リソースを解放し、出力の最後の転送を終える。`runtime/run.rs::step_end` と `flush_failure` は、終了状態を保ちながら補足の診断を加える。Rust の `process::exit` を組み込みの実装から直接呼ぶ形ではない。

テストの実行器は `EndKind`・`main_error`・報告から各テストの成否を判定する（`cli/tools/test_runner/mod.rs::failure_of`）。`or die` の説明を普通の Console 出力だけにすると、実行結果に原因を直接保持できず、標準エラー出力の捕捉と失敗の理由の区別が必要になる。このため、原因を実行結果へ持たせ、CLI とテストの実行器が描画する案を推す。

## 表示と既存の関数

`prelude/stdlib/Result.bnt` に公開される関数は map・mapError・andThen・unwrapOr・isOk・isError・ok であり、expect・unwrap による停止はない。Option も同様に、unwrapOr は代替値を返す。これらの引数は普通の関数の評価順で評価する。失敗のときだけ説明を評価する251の処置とは役割が違う。

`Trait.bnt` の `Show[T]` は `show(x: T) -> String` という純粋なメソッドを持つ。String の実装は `builtins/funcs/traits.rs::show_string` を呼び、引用符とエスケープを付ける。数、Boolean、Unit、リスト、Option、Pair、Triple、Map、Set などにも実装がある。IOError・NetworkError と Result の Show 実装は現在ない。エラー型 E の表示と Result 全体の表示は分けて考える必要がある。

251 では E: Show を求め、IOError・NetworkError に既存の message 関数を使う標準の実装を加える案を推す。利用者の直和型も Show を実装するか、`mapError` で String にできる。String の原因は現行の Show の引用符とエスケープを保ち、説明の String はそのまま表示する。既存の Show[String] を今回変更しない。処理系が任意の型を暗黙に文字列化する規則や、新しいエラー専用の型クラスは要らない。Show は純粋であっても、実行時エラー・資源不足・停止しない計算を防ぐ保証ではない。表示中の停止は既存の停止規則を使う。

構文から使う Show と Process.exit は、ソースの同名の局所変数や import の別名では上書きされない標準の束縛を使う。必要な標準モジュールを読み込みの依存へ加え、利用者の名前空間へ暗黙の import を増やさない案とする。現在は Trait が prelude ではないため、この接続も実装の範囲になる。`uses Process.Exit` と書くソースの Process の名前には、通常どおり import が要る。

## 251 の意味の案

`try e or return` は現在の try と同じ型制約・脱糖を使う。既存の `try e` はこの意味に固定して残す。`try e or die` は成功時に T を返し、失敗時に E の表示または None の説明を実行結果へ記録して、1 を指定した既存の終了処理を使う。囲む関数の戻り値へ Result / Option の制約を加えない。Process.exit[T] と同じく、失敗側は任意の T の式として型付けでき、Never の新設は要らない。

`die` の報告を実行結果として扱う案では、追加のエフェクトは Process.Exit とする。これは `main_error` と同じくホストが描画する失敗の報告であり、Console.writeErrorLine の呼び出しへは展開しない。Console.Write を付けない理由と、終了時に報告が出ることはマニュアルと権限の説明に明記する。Console の関数で書く別案を採るなら Console.Write も必須になる。

終了は、既存の `Process.exit[T](code)` の呼び出しに、原因・説明・位置の内部の情報を付ける案とする。Process.Exit の宣言は現在 exit 一操作だけを持つため、別の操作をこのエフェクトへ加えると、既存のハンドラの網羅性を壊す。今回は操作の名前とシグネチャを保つ。ハンドラの探索も exit の既存の識別で行い、既定の組み込みへ到達した呼び出しだけが情報を明示的な終了結果へ移す。ハンドラで処理し終えた場合はその情報を捨て、後の別の exit に混入させない。情報は呼び出しに結び付け、大域の「次の終了理由」には置かない。内部の情報の受け渡しと、解放が始まる前に原因を所有した文字列へ移す境界が、実装時の確認点となる。

説明付きは `or die("設定を読めない")` と書き、元の原因を必ず表示の材料に残す。引数を一般の純粋な String 式まで認め、失敗のときだけ一度評価する案を推す。直接の return・try・resume は説明の式から外へ抜けられないよう禁じる。呼び出した関数内の return と、明示したラムダ内の return は通常の境界を持つ。None は固定の `expected a value, got Option.None` という原因を持ち、空の説明でもこの原因を捨てない。文言は提案である。

`die` は main の外でも使える。再利用する関数では `or return` と型付きの失敗を推し、実行の入口や一回限りのスクリプトで `or die` を推す。高階関数のエフェクト引数にも Process.Exit が残る。`lazy` の直接の本体は純粋であり、ガードも純粋なので `or die` は許せない。今回は既存の try と同じ構文上の禁止も保つ。

## or の境界の案

Boolean の `or` と、try の処置の `or` は、型を見て読み替えず、字句と現在の式の範囲で区別する。処置は「現在読んでいる try のオペランドと同じ深さの `or return` / `or die`」で始める。括弧、引数、ブロック、内側の try の処置には入って探さない。最も内側の try が先に自分の処置を取る。

| 書き方の案 | 読み方 |
|---|---|
| `try r |> convert or return` | パイプ全体が入力。`convert` は一引数の関数値 |
| `(try r or die) + 1` | 成功値へ 1 を足す |
| `g(try r or return)` | この引数内で失敗なら囲む関数から返す |
| `try (choose(a or b)) or die` | Boolean の or は括弧内の引数の一部 |
| `try try r or return or die` | 内側の try に return、外側に die。人が読む例では `try (try r or return) or die` を勧める |
| `try r or return extra` | 誤り。失敗値の包み方を変える構文は今回加えない |
| `try r or die or flag` | 誤り。完了した明示形に演算子を付けるときは `(try r or die) or flag` と書く |

明示形の処置が終わった後は、その try の外の演算子を無括弧で続けない。現在の裸の try は右の式全体を取るままとする。`try (a or die())` の旧コードは die の予約によって誤りとなり、予約語の移行対象として案内する。

通常の複数行の式では、現在の改行継続の規則を使う。`or` の前後の改行は継続にできるが、`or return` で式が完了した後の改行は文の区切りになる。短いラムダでは、改行を空白として扱う位置でも本体を同じ物理行に限る規則を保ち、処置を次の物理行へ追い出す形は E0254 の対象とする。`lambda(value) return try load(value) or return` は一文の本体である。新しい `die` 字句を `newline.rs`・`lambda_bounds.rs`・整形器の終わりの判定にも接続する必要がある。

## TODO-249 に残す拡張

現在の段では `or` の後を処置の構文として分け、return・die 以外は受理しない。後の段で「失敗 E を受け取る操作・関数」「代替値を選ぶ処置」「失敗側でだけ呼ぶラムダ」を、明示した印を持つ別の処置として追加できる構成にする。今回、`or 任意式` を受理したり、すべての綴りを将来の処置として約束したりしない。Boolean の or と任意式の区別を型推論へ委ねる必要を避けるためである。

TODO-249 の実装では、E を保持した失敗を指定したハンドラで捕捉し、回復や Result への変換を行う。表示の制約は終了して人へ報告する境界だけに置き、伝播・捕捉する E 一般へ Show を要求しない。入力を評価する前に捕捉範囲を作るため、計算のラムダか handle を使う。現在の裸の try を新しい捕捉先へ自動で向けることはしない。

Process.Exit 自体は現在もハンドラの対象となる組み込みのエフェクトである。251 の終了操作も同じ扱いとし、明示して差し替えるテストのハンドラは認める案を推す。既定の実行では今回の実行だけを終える。TODO-249 の回復可能な失敗の捕捉で、自動的に die・実行時エラー・中断を捕まえる意味は加えない。将来のサーバでは同じ操作が当該ジョブを終え、ホストのプロセスを終える必要はない。
