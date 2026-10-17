# エフェクトが確定する場所と shell の参照

## 宣言する集合と本体から求める集合

[01-06「型システム」](../../../design/01-spec/01-06-type-system.md)、[01-07「エフェクト」](../../../design/01-spec/01-07-effects.md)、[02-05「型検査器」](../../../design/02-impl/02-05-typechecker.md) と現在のコードを照合した。報告で使う集合は、検査を通った関数の契約として宣言した集合とする案を推す。本体が行いうる操作を最小まで絞る新しい解析は行わない。

名前解決の `ResolveOutput.main` は入口の main の BindingId を持つ。型検査の `TypeckOutput.main` は同じ束縛と戻り値の形だけを持ち、エフェクトを直接保持しない。main の契約は `types.decl_types.get(main.binding)` の `Scheme.effects` にある。テストも collect_tests が選ぶ binding から同じ表を引ける。

`typeck/decls.rs::uses` は名前解決した effect の BindingId を組み込みまたは利用者のエフェクトへ移し、IO.All を `types/builtin.rs::BUILTIN_EFFECTS` の `in_io_all` が真の項目に開く。uses がなければ空の集合となる。関数の本体は `typeck/generate.rs` と `context.rs`、`solve.rs` が推論し、generate の関数本体の末尾で `body_effect ⊆ scheme.effects` の制約を加える。

したがって、Scheme.effects は「検査に成功した本体の外に現れうるエフェクトの上限」であり、最小の推論結果ではない。`uses IO.All` と書いた main の本体が純粋でも、報告と許可判定には十個の集合を使う。使っていない宣言を除くと現在の契約の確認から意味が変わる。`context.rs::actual_effects` は IO.All の絞り込みを提案する W0501 にも使うが、関数全体の確定結果として TypeckOutput に保存する表ではない。

## 組み込みの名前の一覧

現行の表では、IO.All は State、Console.Write、Console.Read、File.Read、File.Write、Process.Run、Process.Exit、Process.Environment、Clock.Time、Random.Generate へ開く。IO.All 自身は報告する原子的なエフェクトに含めない。Http.Listen・Http.Connect と Assert.Check は IO.All の外である。

出力名は import に書いた名前でなく、組み込みの表に対応する上記の名前を使い、辞書順で重複を除く。BindingId の数値はプロセス内の識別用なので、外部の安定した識別名にはしない。main と @test に利用者の未処理のエフェクトを残すと `typeck/effects/declarations.rs::check_entries` が E0506 を出す。main の Assert.Check は E0415 となる。@test の Assert.Check は有効であり、報告から勝手に除かない。

組み込みのエフェクトを宣言するモジュールの import の別名は禁止される。利用者のモジュールなど、別名が有効な import まで禁止されるわけではない。受け入れ例では有効な別名と、不正な組み込みモジュールの別名による検査の失敗を分ける。

## ハンドラと or die

`typeck/effects/handle.rs` は、全操作の節を持つエフェクトだけを handled に集め、対象の本体から除く制約を作る。節の中で行うエフェクトは外に残る。一部の操作だけを処理したエフェクトは除かない。

`typeck/effects/mod.rs::try_expr` の Die は、標準の Process.exit の束縛を引き、Process.Exit をその式のエフェクトに加える。説明の式は純粋な String に制限される。Return と裸の try は戻り値の失敗へ返す規則を使い、Exit を加えない。Process.Exit を完全に処理するハンドラがあれば、本体の外へ Exit が残らない場合がある。

この除去と、宣言した上限は区別する。Exit を処理して main の uses から Exit を外せる場合は、報告にも Exit はない。一方、処理済みでも明示的に uses Process.Exit を残した場合と IO.All の場合は、宣言した上限に Exit が残るので報告にも残す。報告を作る処理が die の AST を探して Exit を後付けすると、この規則を壊す。既存の型表をそのまま使うべきである。

## Process.shell は Process.Run の一つの操作

`src/prelude/stdlib/IO/Process.bnt` は、run・runAttached・shell を同じ Run エフェクトの操作として宣言する。shell だけのエフェクトはない。`builtins/funcs/process.rs` には三つの別の BuiltinDecl があり、shell は `/bin/sh -c` を起動する。エフェクトの集合だけから shell を見分けることはできない。

名前解決の `ResolveOutput::stdlib("Benitoite.IO.Process.shell")` で標準の shell の BindingId を得て、式の名前参照の `resolved.refs` と比べられる。必要なら `builtin_ops` で組み込みの操作であることも確かめられる。コメント・文字列・同名の利用者の関数は一致しない。値として束縛してから呼ぶ場合も、元の shell の参照がソースにあれば見つかる。

対象範囲は「読み込んで検査したプログラムの AST にある、標準の shell への式の参照」とする案である。入口と依存の補助関数、到達しない関数とラムダの中も含め、ハンドラの case の操作名だけは呼び出し・値の取得と区別する。全 refs を無差別に探す実装は、この区別を確認する必要がある。標準ライブラリも実際の式の参照を走査するが、shell 自身の宣言があるだけでは present にしない。

呼び出しの到達可能性やテストの関数ごとの間接呼び出しの解析は行わない。テストの報告では入口ごとのプログラム単位で参照を返す。名前解決または型検査の失敗では unknown とする。shell への参照が absent でも、Process.run でシェルや別の処理系を起動できるので、安全の証明にはならない。

## package の報告をそのまま使えない理由

`cli/tools/package/effects.rs::Summary` は AST の公開宣言の型・uses を走査する。public(package) は除き、関数の引数や戻り値の関数型なども含め、契約に書いたエフェクトを集める。この用途では IO.All というまとめた名前も記録できる。関数本体や main の検査結果を集める処理ではない。

そのため main の結果やハンドラによる除去の計算にこの集計を転用しない。出力名を作る際の組み込みの表は共有できるが、集合の出どころは型検査の Scheme.effects とする。package の既存の出力を今回の JSON に一緒に変える必要はない。

## 読んだソースの内容のハッシュ

`base/source.rs::Source` は元のバイト列を持ち、`Source::text()` と `SourceTable::iter()` から読める。BOM と改行を除いた表示用の行からではなく、元のバイト列から SHA-256 を計算できる。診断に使う同じ SourceTable を基準にすれば、報告のためにファイルを読み直す必要はない。

`modules/load.rs` は入口・import・package.bnt・埋め込みの標準ライブラリを読み、設定ファイルも SourceTable に加える。`modules/hash.rs` のパッケージのハッシュは複数ファイルの名前や内容をまとめる別の契約であり、一つのソースの内容のハッシュには使わない。sha2 の依存と 16 進表示の方法は再利用できる。

一覧には読んだソースだけを含め、読めなかったファイルは診断に残す。読む途中で失敗した入力の完全な内容を得たようには報告しない。Wasm のバイナリ、パッケージのハッシュ検証だけのために読んだ全ファイル、ディレクトリの存在・不存在の観測はソース表だけでは表せない。この一覧をビルドの全入力や再現可能なスナップショットと呼ばない。検査の成否と対象全体の完全性の扱いは Q3 で定める。
