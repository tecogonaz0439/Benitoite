# 0316. 初回リリース版では、正規表現の構文を検査の時点で確かめない

- 状態: 採択
- 日付: 2026-10-06
- 関連章: [テキストとデータの処理](../03-interop/03-08-text-and-data.md), [型検査器](../02-impl/02-05-typechecker.md), [診断エンジン](../02-impl/02-10-diagnostics.md), [目的と設計原則](../00-overview/00-01-goals.md)
- 関連 ADR: [0031](0031-numbered-diagnostic-codes.md), [0128](0128-prelude-and-benitoite-namespace.md), [0136](0136-map-and-set-in-constants.md), [0168](0168-regex-match-and-stdlib-opaque-values.md), [0270](0270-open-062-items-in-runtime-rebuild.md), [0286](0286-unofficial-modules-imported-under-unofficial.md)
- 関連する未決事項: [OPEN-062](../open-issues.md#open-062)

## 背景

[テキストとデータの処理](../03-interop/03-08-text-and-data.md)の「Regex」は、`Regex.compile` の引数が文字列リテラルか定数式のとき、処理系が検査の段で正規表現を組み立て、構文の誤りを検査の誤りとして報告すると【方針】で定めていた。根拠は設計原則 1（静的に検出できる誤りを実行前に報告する）である。外部の検証者による 2 回目のレビューは、この検査が検査の工程のどこにも置かれていないことを [OPEN-062](../open-issues.md#open-062) の R08 として指摘した（関数の本体の `Regex.compile(r"[")` が、検査の誤りにならず、実行時の `Result.Error` になる）。[ADR 0270](0270-open-062-items-in-runtime-rebuild.md) の決定 3 は、R08 を U1 の範囲とした。

これを受けて、実装プランは U1 に作業 F17 を置いた。F17 は、名前解決で `Benitoite.Regex.compile` を指す名前を直接書いた呼び出しを本体の中から探し、引数を定数の評価器で文字列にし、U3 の作業 L22 が置く組み立ての関数に渡して、失敗なら診断コード E0444 を報告する。検査の時点と実行の時点で結果が食い違わないように、L22 は組み立ての設定を一か所に置き、`Regex.compile` の本体と組み立ての関数の両方から呼ぶとしていた。

この形では、型検査器が標準ライブラリの特定の関数の名前と、その関数の実装（`regex` クレートの組み立ての設定）を知ることになる。`Benitoite.Regex` は非公式のモジュールであり、設計者が実装を吟味した後に、名前・型・振る舞いを改めて標準に移す（[ADR 0286](0286-unofficial-modules-imported-under-unofficial.md) の決定 6・7）。設計者は、非公式のモジュールを標準に取り込むときに標準ライブラリの実装を随時見直す予定であり、処理系が特定の関数を特別に扱うと、その見直しのたびに型検査器の側も合わせて改めることになる。

検討の材料として、オーケストレータが他の言語の扱いを挙げた。次の内容は、2026-10-06 に各言語・道具の公式の文書、言語仕様、公式のリポジトリのソースで確かめた（出典は末尾の「出典」の節）。

- 正規表現をリテラルの構文に持つ言語の多くは、読み込みかコンパイルの時点で正規表現を組み立て、構文の誤りをその時点で報告する。
  - JavaScript: 正規表現のリテラル `/.../` の構文の誤りは early error（実行の前に報告する Syntax Error）である（ECMAScript 仕様 13.2.7.1）。`new RegExp("...")` は、パターンを解析できなければ実行時に `SyntaxError` を投げる（同 22.2.3.3 RegExpInitialize）。
  - Swift: 正規表現のリテラルの中身をコンパイラが解析し、誤りをコンパイルの時点で報告する（SE-0354、Swift 5.7 で実装）。区切りを `#/.../#` にした形は Swift 5.7 から使え、`/.../` の形はコンパイラの指定（`-enable-bare-slash-regex`）か Swift 6 の言語モードで使える。文字列から作る `Regex(...)` は `throws` の初期化子であり、誤りは実行時に分かる（SE-0350、SE-0354）。
  - Clojure: `#"..."` は読み込みの時点で組み立てられ、`java.util.regex.Pattern` になる（Clojure の Reader の文書）。
  - Racket: リーダーは `#rx"..."` を `regexp` で、`#px"..."` を `pregexp` で組み立てたのと同じ正規表現として読む（Racket Reference の Reading Regular Expressions）。
  - Elixir: `~r/.../` のマクロは、補間を含まないとき、マクロの展開の時点（コンパイルの時点）で `Regex.compile!` を呼ぶので、不正な正規表現はコンパイルの誤りになる。補間を含むときは、実行時に `Regex.compile!` を呼ぶ（公式のリポジトリの `kernel.ex` の `sigil_r`）。Erlang/OTP 28 以降では、組み立てたパターンをそのままコンパイル済みのコードに埋め込めないので、実行時にソースから組み立て直すか、書き出した形を読み込み直す（`regex.ex` の `Regex.__escape__`）。この変更は誤りを報告する時期を変えない。`Kernel.sigil_r/2` の文書（v1.20.4）は、組み立ての時期を明記していない。
  - Perl: perlop の「Gory details of parsing quoted constructs」は、正規表現の組み立てを実行時の処理とし、適切な場合はコンパイルの時点で行うよう最適化しうると書く。文書は補間を含まないパターンをコンパイルの時点で組み立てるとは保証していない。perl 5.34.1 で `perl -c -e 'sub f { $_[0] =~ /[/ }'` を実行すると、実行せずに `Unmatched [ in regex` を報告した。
- 正規表現を文字列として関数に渡す言語では、組み立ては実行時に行い、実行前の検査は lint の道具かメタプログラミングに委ねる。
  - Rust: regex クレートの `Regex::new` は `Result<Regex, Error>` を返し、構文の誤りを実行時に `Err` で返す。Clippy の lint `invalid_regex` は、`Regex::new`・`RegexBuilder::new`・`RegexSet::new`（と bytes の版）の引数のうち、文字列リテラルか定数として評価できる文字列を調べる。群は `correctness` であり、既定の水準は deny である。
  - Go: `regexp.Compile` は誤りを `error` で返し、`MustCompile` は panic する。どちらも実行時である。staticcheck の SA1000（Invalid regular expression）が不正な正規表現を報告し、既定で有効である。go vet の文書が挙げる解析器に、正規表現を調べるものはない。
  - Haskell: pcre-heavy の quasi-quoter `re` は、文書が「コンパイルの時点で確かめる」と書く。regex パッケージも、RE の構文をコンパイルの時点で確かめると説明し、`Text.RE.TDFA` などが quasi-quoter を提供する。
  - F#: FSharp.Text.RegexProvider の型プロバイダは、ソースの上では、型を作る時点（コンパイルの時点）で .NET の `Regex` をパターンから組み立て、グループの名前を得る。文書は、不正なパターンがコンパイルの誤りになるとは明記していない。リポジトリの最後の更新は 2019 年である。
  - OCaml: 標準的なライブラリの Re は、Perl 形式のパターンの解析の失敗を例外（`Re.Perl.Parse_error`）か `result` で実行時に返す。ppx_regexp は、`match%pcre` の分岐に書いた文字列のパターンを前処理の時点で解析し、不正なパターンを位置付きの誤りとして報告する。
- Benitoite と API の形が近い関数型の言語の標準的なライブラリは、実行時にだけ確かめる。Elm の `Regex.fromString` は `String -> Maybe Regex` である。Gleam の gleam_regexp の `regexp.from_string` は `Result(Regexp, CompileError)` を返す。PureScript の `Data.String.Regex.regex` は `Either String Regex` を返す。Erlang の `re:compile` は `{ok, MP}` か `{error, ErrSpec}` を返す。

## 決定

1. 初回リリース版では、処理系は検査の時点で正規表現の構文を確かめない。`Regex.compile` の引数が文字列リテラルか定数式であっても、組み立ては実行時に行い、構文の誤りは `Regex.compile` が返す `Result.Error` で分かる。`Regex.compile` の型（`function(String) -> Result[Regex.Pattern, String]`）は変えない。
2. これは設計原則 1 に対する、正規表現の構文についてだけの例外とする。[目的と設計原則](../00-overview/00-01-goals.md)の原則の本文は改めない。原則 1 の本文は型検査とエフェクト検査で検出できる誤りを挙げており、正規表現の構文の誤りはそのどちらでもない。それでも 03-08 は原則 1 を根拠に検査の時点で確かめるとしていたので、本 ADR はその扱いを例外として記す。
3. 処理系（検査の段）と標準ライブラリの個々の関数との結び付きは、初回リリース版ではできるだけ少なくする。標準ライブラリを見直すときに、結び付きを加える判断をすることは妨げない。そのときは ADR を改めて記す。
4. 実装プランの作業 F17 を取りやめる。L22 が F17 のために置くとしていた組み立ての関数（実装プラン 10-16 の `builtins::regex_check::check_regex_source`）も置かない。
5. 診断コード E0444（文字列リテラルか定数式を渡した `Regex.compile` の正規表現の構文の誤り）は使わない。番号は欠番として残し、ほかの誤りに転用しない（[ADR 0031](0031-numbered-diagnostic-codes.md) の、廃止したコードを別の意味で使わない規則に合わせる）。
6. [OPEN-062](../open-issues.md#open-062) の R08 は、初回リリース版では対処しない。反例の振る舞い（関数の本体の `Regex.compile(r"[")` が実行時に `Result.Error` を返す）は、決定 1 のとおり初回リリース版の振る舞いである。この振る舞いは、L22 の受け入れテスト（閉じない括弧の `compile` が `Result.Error` になる）で確かめる。

## 検討した代替案

- **検査の時点で確かめる（F17 の案）**: `Regex.compile(r"[")` のような誤りを、実行する前に報告できる（原則 1）。しかし、型検査器が `Benitoite.Regex.compile` という名前を束縛で照合し、組み立ての設定を `Regex.compile` の本体と共有する必要がある。`Benitoite.Regex` は非公式のモジュールであり、標準に移すときに名前や振る舞いを改めうるので、改めるたびに型検査器と組み立ての関数も合わせて直すことになる。検出できるのも、引数が定数式であり、名前を直接書いて呼んだ場合に限られる（値として渡した `Regex.compile` は調べない）。設計者は、この費用と範囲の狭さを見て、初回リリース版では採らなかった。
- **lint の道具として別に置く**: 型検査器から切り離せるので、検査の段と標準ライブラリの結び付きは生じない。しかし、初回リリース版には lint の道具を置く計画がなく、道具を一つ加えることになる。lint の道具が標準ライブラリの関数の名前と組み立ての設定を知る点は F17 の案と同じであり、見直しのたびに合わせて直す費用は残る。
- **正規表現のリテラルの構文を加える**: 構文解析の時点で確かめられ、関数の名前を照合する必要もない。しかし、文字列リテラルと `Regex.compile` で書けるものに二つ目の書き方を加える（原則 5）。字句と構文の規則も増え、標準ライブラリのモジュールに属する型 `Regex.Pattern` を構文が直接作ることになり、検査の段より深い結び付きになる。

## 帰結

- 03-08「Regex」の【方針】を、決定 1 の内容に改める。
- 02-10「診断コード」の `E04nn` の行から、正規表現の構文の誤りを外す。実装プラン 10-02 は、E0444 を `DiagCode` から除いて `RETIRED` に加え、「コードの一覧」の行を欠番とする。処理系の `src/diag/codes.rs` には、C02 が置いた E0444 の項目が残っているので、10-02 に合わせて改める必要がある。
- [OPEN-062](../open-issues.md#open-062) の R08 の行と本文に、決定 6 を記す。OPEN-062 の種別は、ほかの項目の再現テストの結果がそろうまで変えない。ADR 0270 の決定 3 は、本 ADR で扱いが決まった。
- 実装プランから F17 の作業の文書を消し、README の作業一覧・依存の図・作業の数、L22 の作業の文書、10-16 の組み立ての関数の節、90-after-completion の OPEN-062 の行を改める。
- 定数式の `Map.fromList`・`Set.fromList`（[ADR 0136](0136-map-and-set-in-constants.md)）のように、検査の段が標準ライブラリの関数を知る箇所は既にある。本 ADR はそれらを見直さない。`Map`・`Set` は prelude の標準のモジュールであり、非公式のモジュールの見直しの対象ではない。
- 利用者のスクリプトの正規表現の誤りは、実行してはじめて分かる。LLM がスクリプトを書くときは、`Regex.compile` の `Result.Error` を `try` で返すか、分岐で扱うことになる（03-08 の例のとおり）。

## 出典

いずれも 2026-10-06 に確認した。

- ECMAScript: [ECMAScript Language Specification](https://tc39.es/ecma262/) の 13.2.7.1 Static Semantics: Early Errors・13.2.7.2 IsValidRegularExpressionLiteral・22.2.3.3 RegExpInitialize。[MDN: RegExp() constructor](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/RegExp/RegExp)
- Swift: [SE-0354 Regex Literals](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0354-regex-literals.md)、[SE-0350 Regex Type and Overview](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0350-regex-type-overview.md)
- Clojure: [The Reader](https://clojure.org/reference/reader)
- Racket: [The Racket Reference, Reading Regular Expressions](https://docs.racket-lang.org/reference/reader.html#(part._parse-regexp))
- Elixir: [Kernel.sigil_r/2](https://hexdocs.pm/elixir/Kernel.html#sigil_r/2)、公式のリポジトリの [kernel.ex](https://github.com/elixir-lang/elixir/blob/main/lib/elixir/lib/kernel.ex)（`sigil_r`・`compile_regex`）と [regex.ex](https://github.com/elixir-lang/elixir/blob/main/lib/elixir/lib/regex.ex)（`__escape__`、修飾子 `:export`）。main の版を読んだ
- Perl: [perlop, Gory details of parsing quoted constructs](https://perldoc.perl.org/perlop#Gory-details-of-parsing-quoted-constructs)、[perlop, qr/STRING/](https://perldoc.perl.org/perlop#qr/STRING/msixpodualn)。perl 5.34.1 の `perl -c` で実測
- Rust: [regex::Regex::new](https://docs.rs/regex/latest/regex/struct.Regex.html#method.new)、[Clippy の lint の一覧（invalid_regex）](https://rust-lang.github.io/rust-clippy/master/index.html#invalid_regex)、Clippy のソースの [clippy_lints/src/regex.rs](https://github.com/rust-lang/rust-clippy/blob/master/clippy_lints/src/regex.rs)、群の既定の水準は Clippy の [README](https://github.com/rust-lang/rust-clippy/blob/master/README.md)
- Go: [regexp.Compile・MustCompile](https://pkg.go.dev/regexp#Compile)、[staticcheck SA1000](https://staticcheck.dev/docs/checks/#SA1000)、[cmd/vet](https://pkg.go.dev/cmd/vet)
- Haskell: [pcre-heavy の Text.Regex.PCRE.Heavy](https://hackage.haskell.org/package/pcre-heavy/docs/Text-Regex-PCRE-Heavy.html)、[regex](https://hackage.haskell.org/package/regex)
- F#: [FSharp.Text.RegexProvider の文書](https://fsprojects.github.io/FSharp.Text.RegexProvider/)、リポジトリの [src/RegexProvider/RegexProvider.fs](https://github.com/fsprojects/FSharp.Text.RegexProvider/blob/master/src/RegexProvider/RegexProvider.fs)
- OCaml: ocaml-re の [lib/perl.mli](https://github.com/ocaml/ocaml-re/blob/master/lib/perl.mli)、[ppx_regexp の README](https://github.com/paurkedal/ppx_regexp/blob/master/README.md) と [common/regexp.ml](https://github.com/paurkedal/ppx_regexp/blob/master/common/regexp.ml)
- Elm: [elm/regex の Regex](https://package.elm-lang.org/packages/elm/regex/latest/Regex)（ソースの [src/Regex.elm](https://github.com/elm/regex/blob/master/src/Regex.elm)）
- Gleam: [gleam_regexp の gleam/regexp](https://hexdocs.pm/gleam_regexp/gleam/regexp.html)（ソースの [src/gleam/regexp.gleam](https://github.com/gleam-lang/regexp/blob/main/src/gleam/regexp.gleam)）
- PureScript: [Data.String.Regex](https://pursuit.purescript.org/packages/purescript-strings/docs/Data.String.Regex)（ソースの [src/Data/String/Regex.purs](https://github.com/purescript/purescript-strings/blob/master/src/Data/String/Regex.purs)）
- Erlang: [re:compile/2](https://www.erlang.org/doc/apps/stdlib/re.html#compile/2)（ソースの [lib/stdlib/src/re.erl](https://github.com/erlang/otp/blob/master/lib/stdlib/src/re.erl)）
