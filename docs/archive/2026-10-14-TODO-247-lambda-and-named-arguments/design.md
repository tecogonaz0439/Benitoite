# TODO-247 詳しい設計

## 目的と範囲

Q1〜Q15 の決定に従い、ラムダの終端省略、文書上の推奨、名前付き引数、名前を持つ関数型、移行、形式化を設計する。段 1 は終端省略と文書上の推奨、段 2 は名前付き引数と契約名・形式化・移行である。公開は両方を終えた後に一回行う。

この文書は実装前の改造の設計である。現在の処理系が実装した仕様を述べる `docs/design/` とは区別する。Q は設計者の決定、R は [decisions.md](decisions.md) の新しい問いに対する暫定方針である。今回は処理系、設計書、テスト、docs/todo、コミットを変更しない。

## 前提と保証

判断の基準は [00-01「目的と設計原則」](../design/00-overview/00-01-goals.md) とする。名前と宣言順も関数の契約であり、一引数の関数値にも名前の一致を求める。静的検査が保証する型とエフェクトの規則への適合を維持する。意図との一致や停止性を新たに保証するものではない。

調査の基準は 2026-10-14、HEAD `fe20b76f6a83f65fc7ea7e679380418b14bbd7a3`、クレート `0.0.4` である。現状の根拠は [study/frontend.md](study/frontend.md)、[study/types-and-calls.md](study/types-and-calls.md)、[study/formal.md](study/formal.md)、[study/migration.md](study/migration.md) にある。本設計で外部言語の規則を新たに仕様の根拠とはしない。

## 段 1: ラムダの終端省略と文書上の推奨

### 文法と物理行

差分の文法は次のとおりである。`statement`、式の優先順位、パラメータ、戻り値と `uses` の構文は現行の規則を使う。`short-statement` は新種の文ではなく、現行の文を一つだけ読む制約を表す。

```ebnf
lambda          = lambda-header, (explicit-body | short-body) ;
lambda-header   = "lambda", "(", [parameter, {",", parameter}], ")",
                  ["->", type, [uses-list]] ;
explicit-body   = block, "end", "lambda" ;
short-body      = short-statement ;
short-statement = statement ;
```

短い形では、`lambda` の先頭から本体の最後の字句の末尾まで、同じ物理行でなければならない。LF と CRLF の行の判定を字句解析で保持し、改行判定が空白として捨てた改行も数える。複数行の文字列・コメント・補間・型注釈を途中に含む形もこの条件で拒否する。末尾の行コメントと、そのコメントの後の改行は本体の終わりの外側である。

本体の式は現行の優先順位で読む。内側の呼び出し、リスト、型、ブロックの区切りは、その構文の解析が消費する。短いラムダを置いた外側のコンマ・`)`・`]`・分岐境界・ブロック境界・行末・EOF で本体を閉じる。境界の字句は外側の解析へ残す。`lambda(x) return x + 1 |> increment` のパイプは本体に入り、ラムダ自体を呼ぶ場合は `(lambda(x) return x + 1)(3)` とする。

単文の `return`、式文、束縛などは現行の型検査に渡す。一行で閉じる `if`・`match` が一つの式を成す場合も認める。戻り値を暗黙に返す規則は加えない。`lambda(x) x + 1` は戻り値を返さない既存の規則で検査し、非 `Unit` の値を捨てれば既存の診断になる。`Unit` の終わりで `()` を返す規則、`return`・`try` の作用先、`resume`・ガード・`lazy` の制限は維持する。

### 終端付きとの判別と入れ子

終端の対応は R20 とする。見出しの最後の字句より後の物理行に本体の最初の字句がある場合は従来の終端付きとして読み、対応する `end lambda` を必要とする。本体を見出しの最後の字句と同じ行に始める場合は、その一文の直後の同じ物理行に対応する `end lambda` があるときだけ終端付きとする。次の行以降の終端、外側の区切りを越えた終端は取らない。内側の括弧やブロックはそれぞれの解析で閉じる。候補がなければ同じ行の単文を短い本体として読む。同じ行の二文の並置は、現在の文の区切りの診断を維持する。

この規則で、`bind g <- lambda(y)` の次の行にある `bind f <- lambda(x) return x + 1` は短い形となり、その直後の行にある `end lambda` は外側を閉じる。間に空行やコメントがあっても対応は変わらない。終端数から外側へ割り当て直す回復は行わない。

見出しの行に本体を書き、次の行でそのラムダを閉じる旧二行形式は、本体の先頭へ改行を加えるか、一行へまとめて移行する。Z1 の調査と書き直しの一覧は [z1-implementation.md](z1-implementation.md) に記録する。二つ目の文・継続行・複数行のブロックを含む旧入力の移行は L1a の記録を参照する。R8 と R19 の旧規則は R20 で改めた。

改行後の演算子で同じ式を継続しようとした場合、または二つの文をラムダの本体として読んだ場合は、明示の終端を求める。短い形が行末で成立した後の独立した文は外側の文である。例えば `bind f <- lambda(x) return x` の次の行の `print()` が、本体の追加か外側の文かは字面だけでは判断できない。この形を一律に拒否することはせず、文書では本体に文を追加するとき先に終端を付けるよう案内する。

直接の入れ子で外側か内側が短い形なら、内側のラムダ全体を括弧で囲む（Q2）。ここで直接の入れ子とは、内側のラムダが外側の単文の式の一部であり、内側の呼び出しの引数や束縛文などの独立した区切りで隔てられていないものをいう。`return` の直後や同じ式の演算の中の裸のラムダはこの検査の対象になる。両方が終端付きなら従来の形を認める。

| 入力 | 読み方 |
|---|---|
| `f(lambda(x) return g(x, 2), 3)` | 段 1 の呼び方。`g` の内側のコンマを消費し、`3` の前で短い本体を閉じる |
| `lambda(x) return (lambda(y) return x + y)` | 両方とも短い形 |
| `lambda(x) return (lambda(y) return x + y) end lambda` | 外側は終端付き |
| `lambda(x) return (lambda(y) return x + y end lambda)` | 内側は終端付き |
| `lambda(x) return lambda(y) return x + y end lambda` | 内側を括弧で囲む診断 |

### 構文解析と改行判定の構成

現行の lexer → newline → parser の順序を保ち、改行判定から Parser は呼ばない（R9）。`resolve_newlines(Vec<Token>) -> Vec<Token>` のシグネチャを維持する。新設の非公開 `syntax/lambda_bounds.rs` は生の字句列と Token の物理行を読み、R20 によるラムダの分類と、短い候補を閉じる行の位置を作る。式・文の AST や診断、ノード ID は作らず、通常の構文解析の前に Parser.tokens・pos を動かす工程も置かない。

境界走査は、括弧・角括弧・補間とキーワードのブロックの対応を積む。ラムダの見出しだけは、パラメータの対応括弧、任意の戻り値の型・uses の終わりを読む非公開の字句カーソルを用意する。この見出しの認識は現行の型の文法に従うが、Parser を再利用しない。関数型の内側の uses、型引数のコンマ、case のガードの if、end の直後の構文名、`with case` とリソースの with を区別する。見出しと本体の開始を識別できない範囲は不正候補とし、通常の parser の既存の構文診断へ委ねる。

見出し直後の最初の非改行字句が見出しの最後の字句より後の物理行なら、ラムダは明示のブロックの開きである。同じ行なら、内側の区切りとブロックを消費した同じ外側の深さで、同じ物理行に R20 の終端があるかを調べる。走査は本体の一文を解析せず、その行の字句範囲と明示の終端の候補だけを与える。同じ行で内側のブロックが閉じない場合は、一行条件に違反する候補としてその行末に境界を置く。外側のコンマや閉じ括弧は通常の parser が本体の終わりとして残し、内側のものでは閉じない。

改行判定は短い候補の物理行末で仮のラムダの開きを閉じてから、外側の括弧・ブロック・継続演算子の既存の規則を適用する。外側の括弧のために Newline を捨てる場合でも、Token の行情報で短い本体はその行を越えられない。明示のブロックの開きは終端まで保持する。`syntax/mod.rs` に補助モジュールを登録し、newline の開きの分類と parser の parse_lambda が同じ非公開の判定関数を使う。境界は span と物理行で参照し、改行の除去・回復用字句の挿入で変わる Vec の添字を永続キーにしない。

通常の parse_lambda は確定した行の範囲で現在の式・文・型の規則を適用し、短い本体がちょうど一文であることを検査する。ラムダの先頭の Token.start_line と本体末尾の Token.end_line を比較して一行条件を確かめ、文字列・コメント・補間内の改行、改行を挟む型注釈と演算子の継続も検出する。AST の `LambdaExpr` に `ending: LambdaEnding` を加え、`Explicit { end_span }` と `Omitted { body_end }` を区別する。意味解析はどちらも同じラムダとして扱う。

走査は既存の深さ・入力の大きさの上限を使い、前進と対応表の再利用を保証する。同じ開始 span の分類を再走査する必要があればメモ化し、不正入力で際限なく探索しない。通常の parser の回復で、外側の終端を内側へ再割り当てしない。Token の欄と全構築箇所の変更は次の R2 の表の範囲で行う。

| 表現・場所 | 欄・型と不変条件 |
|---|---|
| `syntax/token.rs: Token` | `start_line: u32`, `end_line: u32`。1 起点、span.start と排他的 span.end の行。開始 <= 末尾 |
| `syntax/ast.rs: Expr::Lambda` | `Lambda(Box<LambdaExpr>)`。終端情報の追加による Expr・Stmt・Arg の増大を抑える（R15） |
| `lexer.rs`, `lexer/string.rs` | ソースを一度走査した非公開の行開始位置表から、共通の push 経路で span の両端の行情報を付ける。LF・CRLF は一改行。文字列・補間・コメント内の改行も表に含め、字句ごとに先頭からソースを数え直さない |
| `parser/mod.rs: EOF` | EOF のゼロ長 span の行を両欄へ入れる。空入力は 1。最後の Token の end_line とソース末尾で確かめる |
| `parser/items.rs: restore_newline` | 復元する改行 span の開始と末尾の行を Parser.text から求める。新欄を仮の 0 で埋めない |
| 境界走査・parser | Token の複製でも行情報を維持する。非公開の走査は改行判定後の字句列にも同じ分類を返す。AST の最終範囲の検査は parser が行う |

### フォーマッタ

`roles/walk.rs` は `Explicit` の場合だけ `open_end` を使う。`Omitted` の本体へ `block()` の改行の役割を付けず、同じ物理行に保つ。現在の整形器には行幅による自動改行はないため、幅の機能を新設する作業は含めない。終端の追加・削除は行わず、書き手が選んだ形を保つ（Q12）。名前付き引数を導入した後も引数順を保つ。

整形後の検証は、現在の字句・コメントの一致と再解析に加えて、ラムダごとの終端の種別、本体に属する字句の範囲、短い形の同一物理行の条件を比較する。絶対のバイト位置や行番号は整形で変わるため、字句の通し番号と木の対応で比べる。整形を繰り返して出力が変わらないことも既存の境界で検査する。

### 文書上の推奨

`else`・`else if` は有効な構文の説明を残し、値や処理の選択には `match` を推奨する。条件成立時だけの処理と早期リターンには `else` のない `if` を推奨する。条件の評価回数・順・選ばれた分岐だけの評価と `return` の作用先を保つ。作用を含む条件をガードへ移さず、必要な場合は真偽値の `match` を入れ子にする。

`shadow` の構文と意味の説明には非推奨であることを添える。一般例では、値の意味を表す別名で一度ずつ `bind` する。意図した名前の再利用も抑える設計意図を説明する。構文説明と専用テストを削除せず、警告は追加しない。

包括的な最後の分岐では `case other` や `case otherCode` を推奨する。通常の変数束縛であり予約語ではないこと、外側の局所名と衝突させないこと、包括的な分岐の後に到達しない分岐を置かないことを説明する。構成子内・捨てる束縛・部分適用の `_` 全般へ非推奨を広げない。

段 1 の実装中は、例に現在の位置呼び出しを使う。段 2 を終えてから `List.map(xs: xs, f: lambda(value) return value * 2)` に統一する（Q3）。段 1 の中間文書を単独で公開しない。

### 段 1 の診断案

番号は現行の表で未使用であることを確認した提案であり、実装開始時にも再確認する。英語の文言は `diag/codes.rs`、動的な補助文は各モジュールの `text` に集める。既存の診断番号を別の意味に使い回さない。

| 番号 | 条件 | 主文の案 | 主位置・補助と修正案 |
|---|---|---|---|
| E0254 | 見出し・内側の構文・式の継続などで省略候補が物理行を越える。改行で区切った複数文の違反も同じ診断に統合 | `a lambda without \`end lambda\` must fit on one physical line` | 開始と越えた改行・字句。`add \`end lambda\` to use a multiline body` |
| E0256 | Q2 の直接の入れ子 | `parenthesize the inner lambda when either lambda omits \`end lambda\`` | 内側のラムダ全体。確定した範囲にだけ括弧の編集を出す |

R10 により E0255 の新設は取り下げる。正常な短い形の次の独立した行は外側の文であり、複数文として E0254 を出す条件にしない。同じ行の二文の並置は現行の NEWLINE_OR_END の診断を維持する。`;` は現行どおり不正な記号として診断する。一般の閉じ忘れは E0214、違う終端は E0213 のままにする。欠けた `)` や不正な型を、複数行のラムダの診断へ置き換えない。E0243 の主文は `a lambda is written as \`lambda(parameters)\` followed by a body` とし、ヘルプで短い形と終端付きの条件を説明する。E0218・E0204 の文脈制限も短い形に適用する。

## 段 2: 名前付き引数と名前を持つ関数型

### 文法と呼び出しの対象

```ebnf
call             = callee, "(", [argument, {",", argument}], ")" ;
argument         = [parameter-name, ":"], (expression | "_") ;
function-type    = "function", "(", [named-type, {",", named-type}], ")",
                   "->", type, [uses-list] ;
named-type       = parameter-name, ":", type ;
parameter-name   = lower-identifier ;
```

構文解析は位置引数と名前付き引数の両方を AST に残す。混在や個数ごとの許否は、呼ぶ値の型を知る型検査で決める。ラベルには通常のパラメータ名と同じ識別子の規則を使い、`_`・予約語・修飾名を認めない。ラベルは局所変数への参照ではなく、名前解決のスコープに加えない。関数型の名前も局所の値を束縛しない。関数型内の重複名は E0310 で拒否する（R4）。

引数がゼロなら `f()`、一つなら `f(e)` と `f(value: e)` のどちらも認める。二つ以上のパラメータを持つ関数では、明示引数をすべて名前付きにする。通常呼び出しには例外を作らず、各パラメータを一度ずつ指定する。指定漏れ・未知・重複は静的な誤りであり、既定値・引数の展開・自動の再部分適用は加えない。

| 対象 | 規則 |
|---|---|
| 宣言した関数、組み込み、ラムダ、局所の関数値、型クラスのメソッド、エフェクトの操作、外部の関数 | 関数型の契約名で対応付ける |
| 直接のデータ構成子の構築とパターン | 従来の位置指定。名前付きなら専用診断 |
| 位置フィールドのデータ構成子を関数値に束縛した後 | `arg1`、`arg2`、… の契約名。直接の構築とは区別する |
| レコード構成子を関数値に束縛した後 | 宣言順のフィールド名。取り出す関数の `value` とは区別する（R13） |
| レコードの構築・更新・パターン | 現行のフィールドの規則。呼び出しの `Arg` に統合しない |
| レコードの取り出す関数の関数値 | 一引数の契約名 `value`（R4） |
| 属性、ハンドラの節の束縛、`resume` | 現行の専用の規則。呼び出しの名前指定を要求しない |

大文字名だけで構成子とレコードを判別しない。`record_ahead` は現在のレコード構文を認識し、普通の小文字の呼び出しと式の結果への呼び出しの `name:` は通常の引数として解析する。構成子・レコードの最終判定は名前解決後の束縛の種類による。`Pair.Pair(arg1: x)` は RecordExpr へ解析されるので、`resolve/walk.rs` の record 経路と `resolve/lookup.rs` でもデータ構成子を判別し、ラベル位置へ E0456 を出す（R13）。真のレコードには現在の欄の未知・重複・不足の診断を使う。関数の `..base` は受理しない。

### AST と静的な型の表現

型変更の具体案は R2 である。引数型の既存の並びを保ち、同じ長さの契約名の並びを追加する。既存の `params` をすべて別の構造体に変える方式より、型の走査と既存の型のアサーションを維持しやすい。長さと一意性を宣言収集時・出力確定時に検査し、不変条件が壊れた内部データを診断なしで受理しない。

| 表現・場所 | 変更する欄と不変条件 |
|---|---|
| `syntax/ast.rs: Arg` | `Named(Box<NamedArg>)` を追加。`NamedArg { name: Name, value: ArgValue }`、`ArgValue = Expr(Expr) | Placeholder(PlaceholderArg)`。既存の位置引数の二種は維持する。`name.span` と値の位置を分ける |
| `FnType` | `param_names: Vec<Name>` を追加。`params: Vec<TypeExpr>` と同じ長さ。移行中は `names_origin: ContractOrigin` を追加し、旧表記では params と同じ長さの位置名を仮置きし、各 Name.span は元の引数型の位置とする。仮名から修正用の編集を作らない。最終版では Named の実名だけを出力する |
| `types/mod.rs: FnTy, Scheme` | `param_names: Vec<String>` を追加。`params` と同じ長さで重複なし。名前と順を `Eq`・`Hash`・型表示に含める。移行中は `names_origin: ContractOrigin` を追加する |
| `typeck/infer.rs: IFnTy` | `contract: IContract` を追加。`Known(Vec<String>)` または `Var(ContractId)`。移行中だけ `Legacy(Vec<String>)` も持つ。名前の変数は型変数・エフェクト変数とは別に扱う |
| `Solver` | 契約変数の union-find と、後述の保留呼び出しを追加。`Known` の統合は位置ごとに完全一致 |
| `Body` と `TypeckOutput` | `call_plans: NodeMap<CallPlan>` を追加。キーは呼び出しノード。パイプ右辺の呼び出しもそのノードで区別し、挿入の印を含める |
| `CallPlan` | `arity`, `source_to_param: Vec<u32>`, `inserted_first: bool`, `hole_names: Vec<String>`。明示引数のソース順と同じ長さ。穴の順もソース順 |
| `ir/core_ir.rs: Lambda<C>, Def<C>, OpDef` | `param_names: Vec<String>` を追加する。Lambda と Def は利用者の `params` と同じ長さ、OpDef は arity と同じ個数。`Var.name` は診断用の局所名として維持し、契約名を兼用しない。下位 IR への写像も欄を保持する |
| コード生成 | `FnTy`・`Scheme` と IR 由来の静的な名前を確認した後、既存の位置指定の命令へ写す。VM の命令、関数・クロージャ・値の実行時レイアウトに名前の欄を加えない |

移行中の R2 の追加表は次のとおりである。公開される最終の型に Legacy を残さず、N33 で欄・列挙子とその全分岐を削除する。

| 表現 | 移行中の意味と処理 |
|---|---|
| `ContractOrigin` | `Named` と `Legacy`。FnType・FnTy・Scheme に names_origin を追加する。出どころの NodeId・Span は別の記録表へ置き、型の Eq・Hash に位置を入れない |
| `Legacy` の名前 | 旧注釈で名前を得られない場合は arity と同じ個数の `arg1`〜を仮置きする。宣言やラムダの実名を保持できる場合は実名を記録する。どちらも確定した公開契約とはしない |
| 構造上の Eq・Hash | 型・エフェクト・名前の並び・origin を含める。Legacy と Named は同じ名前でも別。名前を無視した Eq を導入せず、Hash も同じ判定に合わせる |
| `IContract` の統合 | Known 同士は位置一致、Var 同士は union、Var と Known は確定。Legacy 同士と Legacy/ Known の旧適合は、旧経路の理由が付いた制約に限り arity と型・エフェクトを従来どおり検査する。旧成分の結果は Legacy のまま保持し、仮の名前で Known を確定しない |
| 厳密な制約との接続 | 新しい明示型と名前付き呼び出しでは Legacy をワイルドカードにしない。宣言・注釈から既知の実名を得るか、該当する入力の適合成分を移行する。未確定なら E0455。出力確定時に Var は正常な FnTy に変換しない |
| 出力と削除 | 旧入力の途中の型表示は旧表記を保ち、Named は名前付きで表示する。旧比較の出力だけ origin を旧形式へ写す。新比較には Legacy を渡さず、N33 の全件再検査で Legacy の出力をゼロにする |

名前は宣言と明示の型注釈、ラムダの実際のパラメータから取る。一引数であっても名前を捨てない。位置フィールドのデータ構成子を値にした場合と直接の構成子の穴は宣言上の位置から `argN` を作る。レコード構成子の値では宣言順のフィールド名を使う。`Pair.Pair(_, right)` の関数型は `function(arg1: A) -> Pair[A, B]` である。型クラスの辞書や継続の内部引数は利用者の `param_names` に数えず、コアで必要な補助パラメータには衝突しない内部名を別に与える。

### 適合と推論

関数型どうしの適合は、個数と対応する位置の名前が等しいことを先に検査し、その後に現行の引数型・戻り値型・エフェクトの適合を適用する。型パラメータの置き換え、型の別名の展開、剛な型の処理、エフェクトの包含、分岐の型の合流でも名前を保持する。名前の alpha 変換は行わない。引数を反変に検査する既存の箇所でも名前は同じ位置で比較する。

例えば `function(a: A, b: B) -> R` と `function(b: B, a: A) -> R` は異なる契約である。呼び出しの指定順を変えられることは、関数値の宣言順を変えられることを意味しない。`List.map` の `function(value: T) -> U` へ `lambda(x)` を渡した場合は名前不一致であり、期待型から `x` を `value` へ読み替えない。明示の `lambda(value) return old(value) end lambda` で利用者が合わせる。

未確定の関数値への呼び出しからは、戻り値とエフェクトと個数の制約を作れるが、ラベルのソース順を契約順にしない（Q4）。`IContract::Var` と保留した呼び出しの制約に、ソース順の引数型・名前・位置・穴・挿入の情報を持たせる。宣言、ラムダ、型注釈、他の等しさの制約で契約が `Known` になってから対応付ける（R5）。

`Solver` は通常の等しさ・Flow・型クラス・エフェクトの解決と保留呼び出しの解決を、変化がなくなるまで進める。契約が決まった呼び出しが引数型の Flow を追加し、それが別の契約を確定する場合も再訪する。部分適用では、生成する関数の契約変数と元の呼び出しの対応を連動させ、穴の名前を確定後に取り出す。最後まで契約が定まらなければ E0455 で型注釈を要求し、その契約を一般化しない。型が関数かどうかも決まらない既存の E0407 とは区別する。エラー済みの子には重複する推論診断を出さない。

例として `lambda(g) return g(b: 2, a: 1)` だけでは契約順を決めない。`g: function(a: Integer, b: Integer) -> Integer` のラムダのパラメータ注釈、または同じ検査単位に既知の関数型を与える制約があれば対応付ける。呼び出し元の都合で、既に検査を終えた関数を後から単相化する新しい推論方式は加えない。

未使用の `bind run <- lambda(g) return g(1) end lambda` も、R12 により E0455 で拒否する。一引数の位置呼び出しから合成名を付けない。使われないことを理由に未確定の契約を正常な出力へ渡さず、エラー型として回復する。同一の検査単位で一つの契約変数を `lambda(a)` に確定させてから `lambda(b)` を合わせれば E0454 となる。先に検査・一般化する apply 自体が未確定なら、呼び出し元より前に E0455 となる。名前を注釈した高階関数の通常の型・エフェクトの多相性は維持する。

### 名前付き呼び出しの対応付け

型検査は、全ての引数の式をそれぞれ一度だけ型検査し、後から決まるパラメータ型との Flow を保留できるようにする。型の推論順を宣言順へ変えない。対応表は次の手順で作る。

1. 名前解決済みの呼ぶ値の種類と、最終的な関数型の個数・契約名を得る。
2. 直接の構成子なら位置指定で照合する。通常の関数なら、混在を拒否し、一引数の位置指定だけを位置 0 に対応させる。
3. 名前付きなら、契約名から位置を引く。未知の名をラベルの位置で報告し、既に占めた位置の指定を重複として報告する。
4. パイプの自動挿入があれば、位置 0 を先に占める。その位置を明示した場合も重複である。
5. 未指定の位置を宣言順に列挙し、指定漏れを報告する。誤りのない場合だけ `CallPlan` を出力する。
6. 各ソース引数の型を対応先のパラメータ型へ Flow し、穴の型と生成する契約名を確定する。対応付けの誤りがある位置から、無関係な型不一致を連鎖させない。

一引数の位置指定・直接の構成子でも、脱糖は検査済みの対応表を使う。名前の誤りを脱糖で再推測しない。表の欠落・範囲外・重複など検査後には起きない状態は `InternalError` にする。VM の範囲検査も現行のまま残す。

### パイプと部分適用

直接の穴がないパイプ右辺の呼び出しには位置 0 の引数を補う。全体のパラメータ数が二つ以上なら、残りの明示引数はすべて名前付きである。`xs |> List.map(f: action)` を認め、`xs |> List.map(action)` は名前必須、`xs |> List.map(xs: ys, f: action)` は位置 0 の重複である。空いている唯一の位置を探索する方式にはしない。

直接の穴がある右辺や、括弧で囲んだ右辺へは、現行どおり右辺の関数値を作ってから一引数で適用する。`xs |> List.map(xs: _, f: action)` は穴が一つの関数を呼ぶ。穴が二つなら、一つの値だけのパイプは個数の誤りになり、自動の再部分適用をしない。

パイプの直接の右辺が構成子の構築なら、Q8 の対象の区別を維持し、残りのフィールドも位置指定とする。`left |> Pair.Pair(right)` は位置 0 に左辺を補う直接の構築である。位置フィールドのデータ構成子を関数値へ束縛した後の呼び出しには、通常の関数型の `argN` の規則を使う。レコード構成子値は R13 のフィールド名を使う。

`f(b: _, a: _)` で生成する関数型は `function(b: B, a: A) -> R` である。元の宣言順へ穴を並べ直さない。固定した引数と呼ぶ式は、部分適用を作った時点では評価せず、その関数を呼んだ時に評価する。`return`・`try` の作用先と `resume` の制限は現行の部分適用のラムダの境界を維持する。

### 脱糖・コード生成と評価順

脱糖は、呼ぶ式を先に、明示引数の式をソース順に計算し、保存した値の参照だけを宣言順に並べる。宣言 `f(a, b)` に対して `makeFunction()(b: readB(), a: readA())` は次の順となる。

```text
let callee = makeFunction()
let source0 = readB()
let source1 = readA()
invoke callee [source1, source0]
```

これはコアの説明用の記法である。実装では現行の ANF の `pending` を使い、既に値であるものに不要な計算を作らない。途中で停止・`return`・`try` が発生した場合、後の式や呼び出しを実行しない。型クラスは、利用者が書いた呼ぶ式と引数の順を保持した後、既存の辞書の呼び出しへ移す。操作も、ソース順に値を得てから操作宣言の位置で開始する。

パイプは左辺を最初に一度評価し、次に右辺の呼ぶ式、明示引数の順で評価する。左辺の値は必要な安全点を越えて保持できる保存領域へ置く。通常呼び出しの順という説明で代用しない。部分適用はこの束縛列全体を生成したラムダの本体の内側に置く。作成時に副作用を早めない。

`ir/desugar/exprs.rs` の `call`・`pipe`・`placeholder` と `dicts.rs`・`effects.rs` が対応表を消費する。コード生成の `app`・`method`・`vals` は並んだ値を既存の連続するレジスタへ移す。呼ぶ命令、`Call`・`TailCall`、組み込み・外部境界は位置指定のままとする。並べ替えを末尾呼び出しの前の値の配置で終え、名前を調べる実行時の辞書を作らない。

評価途中の値の生存期間とレジスタの干渉に注意する。位置順の配置で未コピーの元のレジスタを上書きしないよう、現在の `vals` の配置規則を確認する。安全点の根と末尾呼び出しの性質を、参照インタプリタとの一致と `call_allocations` で検査する。実行時間・コンパイル時間・メモリの増加は未測定であり、影響がないとは断定しない。性能を数値で測る別作業には `benchmark` を適用する。

### 標準ライブラリと組み込みの契約名（Q10）

既存の外側のパラメータ名はすべて維持する。付録の表は現在の宣言から得た名前であり、段 2 の公開契約にそのまま採用する。Rust の組み込みの本体の変数名は正にしない。`@builtin` の公開型は対応する `.bnt` の宣言を正とし、`builtin_scheme` が型を与える内部の組み込みには下の内部名の表を使う。

まだ名前のない内側の関数型には、次の契約名を追加する（R4）。戻り値型・エフェクトとその変数の現行の規則を維持する。同じ関数型を持つ非公開の補助宣言、型クラスの宣言・実装、コンテナ内の関数型にも同じ名前を使う。

| 対象 | 外側の契約名の順 | 内側の関数型の契約名の順 |
|---|---|---|
| `List.map`, `List.forEach` | `xs, f` | `value` |
| `List.filter`, `any`, `all`, `find` | `xs, p` | `value` |
| `List.fold` | `xs, initial, f` | `acc, value` |
| `Set.map`, `forEach` / `filter` / `fold` | `s, f` / `s, p` / `s, initial, f` | `value` / `value` / `acc, value` |
| `Map.map`, `forEach` / `filter` / `fold` | `m, f` / `m, p` / `m, initial, f` | `key, value` / `key, value` / `acc, key, value` |
| `Option.map`, `andThen` | `o, f` | `value` |
| `Result.map`, `andThen` | `r, f` | `value` |
| `Result.mapError` | `r, f` | `error` |
| `Reference.update` | `reference, f` | `value` |
| `Regex.replaceAllWith`、内部の `replaceFrom` の `f` | 公開は `pattern, text, f` | `match` は予約語のため使わず `matched` |
| `Network.Http.serve`、内部の `serveLoop` の `handler` | 公開は `host, port, handler` | `request` |
| `Task.all`, `allOk`, `race` のコンテナ内の関数型 | `actions` | 引数なし |
| `Task.withTimeout`, `TaskGroup.spawn` | `milliseconds, action` / `group, action` | 引数なし |
| `Trait.Functor.map`, `Monad.flatMap`, `Traversable.traverse` と実装 | `x, f` | `value` |
| `Trait.Applicative.apply` と実装の `fs` 内の関数型 | `fs, x` | `value` |
| `Trait.Foldable.fold` と実装 | `x, initial, f` | `acc, value` |
| レコードの取り出す関数 | 生成される一引数 | `value` |
| 位置フィールドのデータ構成子の関数値・直接の穴 | 宣言上の位置 | `arg1, arg2, …`。穴は元の位置の名前 |
| レコード構成子の関数値 | 宣言順の欄 | フィールド名（R13）。直接のレコード構文の穴は従来どおり禁止 |

`List` の `mapFrom`・`filterFrom`・`foldFrom`・`forEachFrom`・`anyFrom`・`allFrom`・`findFrom`、`Trait` の `applyFrom`・`flatMapFrom`・`traverseFrom` も、対応する内側の型に同じ名前を加える。`List.fold` の本体の呼び出しは `f(acc: acc, value: element)`、`Map.fold` は `f(acc: acc, key: key, value: value)` とする。Map の実装で `List.fold` に渡すラムダは `acc, value` で受け、`value` から key と value を取り出す別名を衝突なく束縛する。

型クラスの既存の `show(x)`・`compare(x, y)`・`combine(x, y)`・`pure(x)` は維持する。実装は宣言と一致させる。公開の一引数関数の名前を一律に `value` へ変えない。このため直接渡せる組と、ラッパーが要る組を次のように区別する。

| 使用 | 判定と明示の適合例 |
|---|---|
| `List.map` に `lambda(value)` | 名前が一致する |
| `List.map` に `Integer.toString`（現在 `n`） | 不一致。`lambda(value) return Integer.toString(value)` |
| `List.forEach` に `Console.writeLine`（現在 `text`） | 不一致。`lambda(value) Console.writeLine(value)` |
| `List.map` に `Trait.show`（現在 `x`） | 不一致。型クラスの制約も維持した明示のラムダ |
| `List.map` に `Pair.first`（現在 `p`） | 不一致。明示のラムダで `value` を渡す |
| `List.map` にレコードの取り出す関数の値 | 名前 `value` と型・エフェクトが適合すれば直接渡せる |
| `Result.mapError` に既存のメッセージ関数 | 宣言の名前が `error` なら直接渡せる。それ以外は `lambda(error)` で包む |

上の例で短いラムダに本体の別名束縛も必要になれば、終端付きへ直す。ラムダの改名には、その本体の束縛先と名前解決済みの参照だけを更新し、入れ子の別の局所名や文字列を置換しない。

| 内部の型・生成する補助関数 | 契約名の順 |
|---|---|
| 二項演算・等値と非等値 | `left, right` |
| 単項の符号反転・文字列補間 | `value` |
| `%List.length` | `xs` |
| `%List.getFront`, `%List.getBack` | `xs, index` |
| `%List.slice` | `xs, front, back` |
| 脱糖で追加する辞書の引数 | 利用者の並びの前に、番号で一意な `%dict1`, … を内部の静的型だけに付ける |
| ハンドラから生成する継続の内部パラメータ | 内部の静的型に `%resumeValue`。専用の継続型に通常の呼び出し規則を適用しない |

内部名の `%` は表層の識別子として受理せず、公開の名前の一覧と混ぜない。Lean の組み込み表と交換形式でも同じ名前を使う。型付き組み込みの登録マクロと `BuiltinDecl` の raw 呼び出しには公開名検索の機能を追加しない。登録 ID・個数・権限・結果の既存のアサーションを維持する。

### 段 2 の診断案と優先順位

| 番号 | 条件 | 主文の案 | 位置・補助と対処 |
|---|---|---|---|
| E0257 | 名前のない関数型 | `each function-type parameter must have a name` | 型のパラメータ。`write \`function(name: Type) -> Result\``。文脈の契約が不明なら名前を創作した編集を出さない |
| E0449 | 複数パラメータへの位置指定 | `this function requires named arguments` | 最初の位置引数。宣言の名前と順を表示し、確定した対応にだけ `name: ` の挿入案 |
| E0450 | 名前指定と位置指定の混在 | `named and positional arguments cannot be mixed` | 最初に方式が変わる引数。最初の方式への副位置 |
| E0451 | 未知の名前 | `this function has no parameter named \`{name}\`` | ラベル。利用できる名前を宣言順に表示 |
| E0452 | 重複 | `the parameter \`{name}\` is supplied more than once` | 二度目のラベル、最初の指定。自動挿入と衝突ならパイプの位置も表示 |
| E0453 | 指定漏れ | `missing arguments for parameters: {names}` | 呼び出し、宣言順の不足名。既定値は補わない |
| E0454 | 関数型の名前・順が不一致 | `function parameter names do not match` | 渡した関数値／ラムダ名、期待と実際の並び。不一致の最初の位置を表示 |
| E0455 | 最終的にも契約順が未確定 | `the parameter names and order of this function cannot be determined` | 呼ぶ式。`add a function-type annotation with parameter names` |
| E0456 | 直接のデータ構成子に名前指定（RecordExpr の経路を含む） | `direct constructor calls use positional fields` | ラベル。関数値として束縛する場合との違いを案内 |

個数だけの誤り E0402、呼べない値 E0403、引数型の E0401 は維持する。ラベルがある呼び出しの不足は E0453、名前のない一引数や構成子・関数値へのパイプ一引数の個数の誤りは E0402 とする。E0454 は、引数の型が同じでも名前が違う場合を独立して示す。新しい優先順位で別の診断へ変わる負の入力は、次節の「仕様上の診断の変更」として理由を承認し、元の誤りの退行の検査も保つ。

診断は解析の誤り、呼べない値、混在または名前必須、未知・重複、不足、対応する型の不一致の順で原因を絞る（R6）。未知・重複を報告した同じ呼び出しでは、その結果だけから生じた不足や型不一致を抑える。契約が未確定なら E0455 を優先し、呼び出しの順から仮の契約を作って E0454 を出さない。子の式の独立した誤りは報告する。

編集案は、式の元の順を保ってラベルを挿入する。混在・穴・個数違い・未確定の関数値・局所名の改名では、一意に安全な対応を確認できなければ説明だけにする。診断を出したまま実行へ進む回復は行わない。

### 版と移行の診断（Q11）

名前付き呼び出し・名前必須の関数型・関数値の名前と順の適合・高階の契約名を、一つの互換性を壊す変更として `modules/package.rs` の `BREAKING_CHANGES` に登録する。版番号は設計者が `0.0.5` と決めた（2026-10-15）。

既存の E0907（未来の版）・E0908（互換性の境界を越えた古い版）を使い、E0908 のヘルプには名前付き呼び出し・関数型の移行文書を案内する。N35 で現行入力の `language "0.0.3"` 等を `0.0.5` へ更新する。testdata には `rg -l 'language "0.0.3"' crates/benitoite/testdata` で 46 ファイルが該当し、examples・docs・tools・Rust の埋め込み文字列と生成器も一覧化する。旧版や未来の版そのものを試す入力は一括更新の対象にせず、版の境界と E0907・E0908 の期待を見直す。古い `language` を書いた入力で関係のない解析診断が先に大量に出ないよう、現在のモジュール読み込みの版検査の順を確認する。`language` を書かない入力も新しい規則で検査し、古い複数位置指定には E0449、古い関数型には E0257 を出す。古い文法で実行する経路は公開しない。

現在の英語リファレンスに移行節を置き、元の例、新しい例、同じ評価順、型とラムダ名の修正、穴・パイプ・構成子値の差を示す。名前のない型に番号名を足すだけで適合するとは案内しない。公開名の変更は通常の型と同じ契約の変更として扱う。今回の Q10 では既存の外側の公開名の改名はゼロであり、新しい内側の名前と生成関数の名前を明記する。

E0257 の移行入力は、旧い型の引数を最後まで読むことで外側の区切りを保ち、その箇所のエラーを出す。名前を補った正常な FnType として実行へ渡さない。E0449 の旧い呼び出しは AST に位置引数を残してから拒否するので、既知の宣言の名を使う編集を出せる。旧い言語の版の判定は package の読み込みで行う既存の仕組みを維持する。

### 既存入力の機械的な移行

2,045 は `.bnt` の複数の明示引数の候補の見積もりである。標準ライブラリ 147、testdata 1,502、その他 396 の合計で、パイプの 12 と Rust の文字列の 782 候補は別である。厳密な変更件数・成功するテスト件数にはしない。旧構文を試す入力、型の誤りを試す入力、比較資料も含まれる。

リポジトリ内の移行専用の道具を `tools/named-arguments-migrate/` に作る。一般利用者へ新しい CLI のコマンドとして公開しない。既存の解析・名前解決・型情報とソース位置を使う読み取り用の Rust の補助と、対象の抽出・パッチ出力のスクリプトを組み合わせる。通常の実行経路へテスト専用のフラグを加えない。

道具は既定で書き込まず、`manifest.json`、分類別の Markdown の確認表、unified diff を出す。各候補にパス・元のバイト範囲・ソースのハッシュ・旧入力の結果・期待する診断・契約名とその出どころ・修正前後・保留理由を記録する。適用は確認済みの manifest のハッシュと範囲が一致する場合だけ行う。二度目の実行で差分が出ないことを確認する。

正しく解析・型検査できる入力では、宣言の位置で名前を加え、ソースの順を維持する。高階の型注釈とラムダの名前は、その期待契約と名前解決済みの束縛単位で直す。誤りを試す入力では、対象の診断を manifest に記録し、その検査まで到達するためのラベル・型・ラムダのパラメータ名とその束縛の参照を直す。契約を確定できない入力、他言語の例、連結・生成する Rust の文字列は保留し、個別に直す。

Rust の raw・通常の文字列と Markdown のコードブロックは、元のファイルの範囲へ戻せる抽出器を使う。エスケープを読み替えた後の行番号を元ファイルの編集位置として使わない。生成する入力・補間内の式も一覧に出す。生成物は生成元を変更して再生成する。既存の assert を削除せず、出力・終了状態の期待値を緩めず、診断コードは承認した仕様上の変更だけを厳密な新期待値へ直し、`.expected` を実行結果で一括更新しない。字面の位置や名前を表示する型の期待値の変更は、旧新の理由を個別に記録する。

宣言のない関数値の命名は R11 とする。適合でつながるラムダ・注釈・変数を一成分として、宣言の期待契約があればそれを優先する。なければ、同じ検査単位のソース順で最初に定義したラムダの名前を移行候補にする。候補名と元の名前の双方を manifest に記録し、名前解決済みの束縛単位で本体の参照も直す。衝突・相反する期待契約・公開される関数値・成分の確定不能は保留し、確認済みの案だけを適用する。処理系が実行時や型検査時に読み替える規則ではない。

### 負のテストの分類と仕様上の診断の変更

| 分類 | 対応と記録 |
|---|---|
| 元の誤りを維持する移行 | ラベル・型・ラムダ名を直して元の検査へ到達させ、対象の診断・終了状態を維持する |
| 仕様上の診断の変更 | 新しい優先順位で先に検出する契約の誤りを、旧→新・入力・根拠の節・元の誤りが残る検査とともに記録する。N28 で厳密な期待値を直し、G7 で設計者が対応表を承認する |
| 表示・位置の変更 | 型名の表示と span の旧→新を記録する。N19・N20 の時点から golden で確認する |
| 新規則だけの負のケース | 移行とは別に追加し、test-audit の関門を通す |

診断対応の初期表は次のとおりである。実装の N1 で実ファイルを対応付け、各変更で件数と理由を確認する。

| 旧診断・入力の例 | 最終の診断・移行の判断 |
|---|---|
| E0402、二引数への `f(1, 2, 3)` | 旧構文そのものを残すなら E0449 が先。ラベルへ移行し過剰な名前を指定すれば E0451。不足へ移行した別ケースなら E0453。単に E0402 の退行検査と同一視しない |
| E0401、型も名前も違うラムダ | 名前の違いが残れば E0454 が先。引数型の誤りを守るケースはラムダ名と本体の参照を合わせ、E0401 まで到達させる |
| E0402、一引数の位置呼び出し・直接の構成子の個数 | 現行の E0402 を維持する |
| E0243、`testdata/syntax/c11-lambda-colon.diag.json` | 番号は維持し、L2 で主文・ヘルプの変更を個別に記録する |
| N18 の準備用の解析検査、`f(item: 1)` の E0201 | N21b で通常値の名前指定を一般入口へ接続し、成功となる。公開入口の正常なラベルの受理は `tests/named_arguments.rs` で検査する。元の E0201・コロンの主位置の assert は、未接続の `f(item: _)` と `1 |> f(item: 1)` で維持する |
| N28、`testdata/types/arity.bnt` の `add(1)` | `add(left: 1)` に移行し、E0402 → E0453（不足は `right`）とする。「段 2 の診断案と優先順位」の名前付きの不足の規則による。E0402 の副位置「function declared here」はなくなり、E0453 は呼び出し位置と不足名を示す（R92）。終了状態 2 と二つ目の `Shape.Rect(1)` の E0402 を維持する。一引数の関数の E0402 は `types/arity-single.bnt` と既存の単体テストで保つ |
| N28、`handlers/secf1-effect-confusion.bnt` と `secf1-value-confusion.bnt` | E0401 → E0401。名前付きの `Reference.set` の対応の制約を後で解くため、同じ操作の剛な型変数 `T` の流出を先に `resume(p)` で検出する。主位置・型表示と、その位置に付く補助情報だけを変更し、操作の節・流出の注記・終了状態 2 を維持する（R80）。引数からセルへの流出を直接報告する検査は `handlers/secf1-nested-escape.bnt` の同じ E0401 に残す |

N28 の全入力の分類と診断の旧新は [n28/review.md](n28/review.md) と [n28/expectation-changes.json](n28/expectation-changes.json) に記録する。G7 の設計者による承認の対象とする。`Integer.floorDivide` の名前付きへの移行で消えた W0402 は処理系の警告の経路を補正し、元の期待値を維持する（R81）。

「元の診断コードを必ず維持する」と「新仕様の優先順位を適用する」を同時に要求しない。終了状態の比較や assert は削除せず、仕様上変えた診断も具体的な新コードへ一致させる。

除外は `reference/`、`docs/archive/`、docs/todo、最小実行版のリファレンス、過去の測定記録、構文の比較案の記録、生成済み Skill の参照文書とする。現行の examples、ベンチマークの入力、Skill 評価の参照解、fuzz の種、生成器は対象に含めるが、測定や LLM を呼ぶ評価は実施しない。道具の検査は、正規表現の候補数が減ったことだけで完了にしない。

## 形式化の設計と処理系との対応

### 対象の判定

| 変更 | 範囲と 07-04 の記録 |
|---|---|
| ラムダの終端省略の綴り・物理行・境界の解析、整形 | 「対象外」。解析後のラムダは C1 の既存の型付けと脱糖の対象内 |
| `else`・`shadow`・包括的なパターンの文書上の推奨 | 規則の変更なし。置換した例の意味をテストで維持する |
| 契約名を持つ型・通常の呼び出し・ラムダの適合 | B の共有型、C1、E2 の対象内 |
| 名前の並べ替え、パイプ、穴、構成子の関数値 | C1・C2・E2 の対象内 |
| 利用者の操作・ハンドラと型クラス | B1・C4 および B2・C5・E2 の対象内 |
| 外部宣言・WIT の接続 | 既存の外部境界の行に「対象外」を追記。一般の関数型まで除外しない |
| 属性・移行診断と移行道具 | 「対象外」。型付き表層より前の処理として記録 |

この判定と記録は `07-quality/07-04-formal-semantics.md` の「01-12 との対応」に反映する。段 1 は形式規則を変えず、対象外の行と同じ表層へ写ることを先に確認する。段 2 は、定義と証明を処理系の変更より先に終える（Q14）。

### Lean の型とコア

`Release/Syntax.lean` の `Ty.fn` に `names : List String` を追加し、既存の `params : List Ty` と同じ長さ、一意な名前を持たせる。`Val.lam`、関数・操作・組み込み・メソッドのシグネチャにも契約名を保持する。これは静的な型と注釈であり、de Bruijn の局所変数名や実際のクロージャのレイアウトとは別である。段階 A の `Core/` は最小実行版のモデルとして維持する。

`Release/WellFormed.lean` と型付けに名前の整形式条件を追加し、関数型の適合に位置ごとの名前一致を入れる。既存の定理の前提へ「必要な名前は全部正しい」という新たな外部の仮定を足して済ませない。型付け・表層の検査からその条件を導く。`Subst.lean` と `TySubst*`・`Rename`・`SubstTyping` の補題は、型・値の置き換えと変数の移動で名前の並びを変えないことを示す。

`Semantics.lean` の呼び出しは位置で値を渡す規則を維持する。名前は実行の分岐に使わず、ラムダと静的型の注釈として残す。`Canonical`・`Inversion`・`Regularity`、保存、進行、ストア・継続・辞書の補題、`EffectSound` と最終の `Theorems` を新しい構文で維持する。型とエフェクトの保証を弱める定理への置き換えや `sorry`・新しい公理は使わない。

### 表層の呼び出しと性質 1

文字列補間が参照する変換関数にも宣言の契約名を保持する（R76）。Integer と幅付きの数は `n`、Float・Decimal は `x`、Character は `c`、Byte は `b` を使い、内部の Boolean の変換の静的な契約は `value` を使う。NamedSurface の `InterpPart.converterName` と `converterTypes`、直接の頭を検査する補題は同じ対応を使う。公開の変換関数の引数名を補間のために改名しない。

`Surface/Syntax.lean` の通常呼び出しには、ソース順の式の並び、明示ラベルの有無とラベル、対象位置 `positions : List Nat` を持たせる。呼び出しの型付けは、ラベルと契約名の一致、位置の範囲、重複のなさ、全位置の指定と、ソース位置ごとの期待型を検査する。位置を Rust が与えたことだけを信用しない。

レコードの位置対応とは補題を必要に応じて共用するが、関数の評価・辞書・穴・パイプの規則は独立して定める。`Surface/Desugar.lean` は呼ぶ式、ソース順の引数の `let` を作り、束縛された値の参照だけを位置順に並べる。`Calls.lean`・`CallHead.lean`・`Typing.lean` には、その参照の置き換えが型を保存する補題を置く。Z4 で加える `CallOk.recordFields_source` は、対応表でソース位置 k を宣言位置 i に対応させたとき、並べ替え後の第 i 成分が k 番目に束縛した値の参照 `.var (n - 1 - k)` となることを、挿入引数を含めて示す（R44）。callee の先行評価とソース順の束縛は脱糖の定義と具体例で確かめる。ソース順の計算の束縛を宣言順へ移す等式や、評価順全体の意味保存は証明しない。

`HoleArgs` は各引数のラベルと位置を持ち、穴の位置で契約名を取り出す。生成するラムダの名前と型の並びを穴のソース順にする。パイプの自動挿入は位置 0 の占有とその重複検査、穴付き・括弧付き右辺は一引数の適用として定める。直接の構成子の穴は `argN` を使い、直接の構築には名前必須を適用しない。

操作のシグネチャ、ハンドラの局所束縛、辞書を通すメソッドも同じ契約を使う。ハンドラの局所名の綴りは固定しない。`Surface/Typing`・`WellFormed` の型付き表層と、`Check*` の実行可能な検査を同じ規則にし、`CheckSoundCalls`・`CheckSoundDicts`・`CheckProgramSound` などの健全性と `Surface/Theorems` の性質 1 を維持する。

### 交換形式と差分検査

`Exchange/Syntax.lean`・`Convert.lean`・`Builtins.lean`・`CheckInput.lean` と `tests/desugar_export/` の JSON に、関数型と宣言の契約名、ソース順のラベル・式、位置対応、穴とパイプの挿入の情報を追加する。交換形式は corpus 7 → 8、組み込み・標準ライブラリの型表 1 → 2、網羅性 1 → 2 とし、足りない欄を最終版で自動補完しない。比較前の正規化で局所の内部名を揃えても、契約名と対応表を消さない。偽のラベルや対応位置を含む入力で Lean の検査が拒否することを確認する。

旧形式の接続を壊して Rust を一括変更しないため、証明作業中は `NamedRelease/`・`NamedSurface/`・`NamedExchange/` の新しいモデルを別の名前空間で追加し、旧入口の検査も維持する（R7）。ここで定めた最終の規則を先に証明し、定義と言明のレビューを終え、Rust の新形式の出力を接続した後で既存の `Release/`・`Surface/`・`Exchange/` に置き換える。移行用の名前空間と旧形式の接続は N34・N34a・N34b で切り替え・削除する。旧モデルで新形式の名前の検査を代用することはしない。

Rust の名前付き呼び出しの書き出しは N21a で非接続の補助として追加し、N21b で通常呼び出しの実行・脱糖と同時に接続する。保留推論・穴・パイプ・操作・メソッドを有効にする N22〜N24 でも、その作業と同時に新形式の出力と検査を加える。N25 は接続開始ではなく、全経路と対象件数の照合を行う。N18〜N24 の各取り込みで check-formal.sh を通す。N19 は新型を扱う出力補助と独立入力、N20 は新宣言・ラムダを使う完全移行済みの最小プログラムの新形式への接続も同じ作業で用意する。N21a はその出力補助へ CallPlan と名前付き引数の書き出しを追加する作業である。

移行単位はテスト入力とその形式化で書き出す依存宣言を含む一つのプログラムである。旧構文・旧適合だけの単位は corpus 7 と旧モデル、移行済みの全契約が既知の単位は corpus 8 と Named モデルへ出す。各入力の版・対象内件数・対象外理由を manifest と照合する。名前付きの入力を corpus 7 へ出したり、新形式の型から名前を消したりしない。新旧が混在する単位は依存を含めて移行してから新しい呼び出しを有効にし、どちらにも検査されない対象内の成功入力を作らない。旧形式を通すだけのために対象外へ回さない。

組み込みと標準ライブラリの型表は旧 1 と新 2 を併存させ、各 corpus の版に合う型表を渡す。網羅性の入力は、それが属するプログラムの型の版に応じて 1 または 2 に書き出す。N15 で desugarDiff・builtinCheck・coverageDiff・coverageProgramDiff・surfaceCheck・surfaceCheckAll の六つに対応する Named の入口を作り、coverage_export も新旧の比較に含める。最終的な拒否条件は corpus 8／型表 2／網羅性 2 に統一する。

`01-spec/01-12-core-calculus.md` は、完成した Lean の定義・型付け・脱糖の写しに合わせて更新する。Named モデルの定義を追加・接続する間は、規則の写しと定理の対応を改造ディレクトリの formal-rules.md に置き、処理系がまだ実装していない規則を現在の設計書へ先に書かない。正式モデルへ切り替える N34a で、01-12 と 07-04 を同じ変更にする。現在の設計書へ「準備中」のモデルの説明は書かない。

`lake build` は `sorry` なしで通す。`scripts/check-formal.sh` で脱糖・網羅性・型検査出力の差分検査を通し、範囲内の入力を対象外へ移して失敗を隠さない。差分検査の件数・範囲外の理由も旧新で比較する。性質 1 は型の保存であり、解析境界や IO 順全体の保証ではないため、実行の順序を観測する既存の境界でも確認する。

## 文書と生成物の変更表

| 文書 | 段 1 | 段 2 |
|---|---|---|
| `01-spec/01-01-lexical.md`, `01-02-syntax.md` | 物理行・単文・入れ子・終端の文法、推奨を追加 | 名前付き引数・名前付き関数型・パイプ・穴・対象の境界を追加 |
| `01-spec/01-03-names-modules.md` など名前とスコープの章 | `shadow` と包括的なパターンの説明を調整 | ラベルは参照・束縛ではないこと、関数型内の名前の一意性 |
| `01-spec/01-05-data-types.md`, `01-06-type-system.md`, `01-07-effects.md`, `01-08-evaluation.md` | 一般例の文書上の推奨 | 型の契約と適合、操作、評価順、構成子値・高階の契約名 |
| `01-spec/01-12-core-calculus.md` | 同じ既存のラムダへ写す確認 | Lean の写しと名前・ソース順の脱糖 |
| `02-03-frontend.md`, `02-04-resolver.md` | 境界・物理行・AST | Arg と型注釈の欄、ラベルを解決しない規則 |
| `02-05-typechecker.md`, `02-06-ir-and-lowering.md`, `02-07-bytecode.md`, `02-08-vm.md` | 意味は既存規則のまま | 名前・保留制約・対応表・値の配置・末尾呼び出しと位置の VM |
| `02-10-diagnostics.md` と診断の一覧の参照箇所 | 新しい構文診断と E0243 | 名前・型・移行の診断と優先順位 |
| `03-06-stdlib.md`, `03-10-external-functions.md` を含む標準ライブラリと外部の章 | 一般例の推奨 | 公開契約名、内側の型、WIT は位置の照合を維持 |
| `06-03-formatter.md`, `06-06-agent-skills.md`, `07-04-formal-semantics.md` | 短い形の整形・案内・対象外の記録 | 名前の順を保つ、生成元、範囲内の規則と対象外の外部境界 |
| `docs/reference/benitoite.md`, `install.md` の現行の例 | 短い形と非推奨の案内 | 全ての現行例と移行節 |
| Skill `SKILL.md`, 手書き `idioms.md`, `common-mistakes.md`, `language-comparison.md` | 推奨と有効な構文を区別 | 名前の契約、ラッパー、穴・パイプ、診断への対処 |
| Skill の `grammar.md`, `diagnostics.md`, `stdlib/` | 生成元の変更後に gen_skill | 生成元・型表示・標準ライブラリを変えて gen_skill |
| `docs/ja/reference/`, `docs/ja/skill/` | 中間では書き換えない | 公開前に英語の最終版から訳し直す |

表中の省略した章のファイル名は、実装作業を始めるとき `docs/design/README.md` の現在の目次で確定する。見出しを変える場合は名前で参照するテスト・コメント・生成器も更新する。設計書には実装後の内容だけを書く。章を増やす場合は目次と参照を同じ変更で直す。過去の記録と最小実行版のリファレンスは維持する。

## 実装の途中の整合と最終の関門

全作業の後でコンパイルと関係するテストを通すには、大量の入力を直す前に名前必須を一括で有効にしない準備が要る（R1）。名前付きの新構文・対応表・静的な名前の欄を先に追加し、段 2 の開発中だけ旧構文と旧適合の経路を維持する。新しい名前付き呼び出しの未知・重複・不足の検査と評価順は、この準備中から実施する。

暫定の旧表記から補う名前は `Legacy` として出どころを区別し、新しい最終契約と同じものとは扱わない。新しい明示の関数型どうしは名前を厳密に検査する。未移行単位の旧適合は、呼び出しの Flow に加え if・match の分岐、リスト、Reference.set、レコードの欄、戻り値の等しさ・Flow にも旧経路の理由と位置を付け、型・エフェクトを既存の規則で検査する（R11）。新しい明示型や名前付き呼び出しの境界まで旧適合を伝播させず、その成分を同じ作業で移行する。移行 manifest で残数を報告する。暫定経路を切り替える公開 CLI・環境変数・言語版は作らない。最終の切り替え作業で Legacy と旧適合を削除し、全入力を最終規則で再検査する。削除しなければ改造の完了とはしない。

準備中は、位置指定の旧呼び出しから生じた引数の Flow に旧経路の理由を持たせる。一引数の旧呼び出しを含め、そこで渡すラムダと新しい標準ライブラリの内側の型がまだ名前不一致でも、旧規則の型・エフェクトの検査を続けられるようにする。これにより N20 の宣言の変更だけで未移行の全テストが失敗することを避ける。名前付きへ直した呼び出しの Flow は、初めから厳密な名前の比較を行う。位置指定の一引数自体は最終版でも有効だが、旧 Flow の扱いは N33 で除去し、渡す関数値の名前は例外なく検査する。

テストの追加・変更には `test-audit` の作成時の関門を適用する。各テストが守る契約と退行、既存テストとの差、持ち主の境界を記録する。既存の assert は消さず、期待値を緩めず、別の理由の失敗で負のテストを通さない。L・N の各作業の具体的な検査は [plan.md](plan.md) に定める。

最終の確認は、全入力の移行、名前付き呼び出しの意味と診断、短いラムダの境界、形式化の定理と差分、文書と生成物の一致、暫定経路と名前空間の削除である。全体の検査は公開前に `scripts/check.sh --full` で行う。実装時間・証明時間・配置の費用は未測定であり、作業の時間の目安を達成実績として扱わない。

## 付録: 現行の宣言から採用する外側の名前

次の表は `src/prelude/stdlib/` の全 `function` 宣言を読み、モジュールと引数名の同じ組でまとめたものである。公開・非公開、操作と型クラスの宣言・実装を含む。名前と順はこの改造で維持する。Trait の同名の実装は同じ組にまとめ、行番号で元を確認できるようにする。表の `builtin` は直前の `@builtin` が指定する登録名であり、本体の Rust の引数名ではない。

組み込みのエフェクトの操作には `@builtin` が付いていない。`resolve/collect.rs` は標準モジュール内の組み込みのエフェクトを判定し、`Benitoite.<モジュール>.<操作>` で登録表を引く。付録の IO・Network.Http の操作名と引数名が、その登録された組み込みの公開契約でもある。通常の `@builtin` の 312 宣言と、これらの操作を合わせて確認する。内部のソースに現れない演算等は本文の内部名の表を使う。

| モジュール | 引数名の宣言順 | 関数・宣言の行（組み込みの登録名） |
|---|---|---|
| `Assert` | `actual`, `expected` | `equal`（6）、`notEqual`（8） |
| `Assert` | `condition`, `message` | `isTrue`（10） |
| `Assert` | `message` | `fail`（12） |
| `Byte` | `n` | `fromInteger`（5） [builtin `Byte.fromInteger`] |
| `Byte` | `b` | `toInteger`（9） [builtin `Byte.toInteger`]、`toString`（13） [builtin `Byte.toString`] |
| `Byte` | `a`, `b` | `bitwiseAnd`（17） [builtin `Byte.bitwiseAnd`]、`bitwiseOr`（21） [builtin `Byte.bitwiseOr`]、`bitwiseExclusiveOr`（25） [builtin `Byte.bitwiseExclusiveOr`] |
| `Byte` | `a` | `bitwiseNot`（29） [builtin `Byte.bitwiseNot`] |
| `Byte` | `a`, `n` | `shiftLeft`（33） [builtin `Byte.shiftLeft`]、`shiftRight`（37） [builtin `Byte.shiftRight`] |
| `Bytes` | 引数なし | `empty`（5） [builtin `Bytes.empty`] |
| `Bytes` | `bs` | `fromList`（9） [builtin `Bytes.fromList`] |
| `Bytes` | `ns` | `fromIntegers`（13） [builtin `Bytes.fromIntegers`] |
| `Bytes` | `s` | `fromHex`（17） [builtin `Bytes.fromHex`]、`fromBinary`（21） [builtin `Bytes.fromBinary`] |
| `Bytes` | `b` | `toList`（25） [builtin `Bytes.toList`]、`toHex`（29） [builtin `Bytes.toHex`]、`toBinary`（33） [builtin `Bytes.toBinary`]、`length`（37） [builtin `Bytes.length`] |
| `Bytes` | `b`, `i` | `get`（41） [builtin `Bytes.get`] |
| `Bytes` | `b`, `start`, `stop` | `slice`（45） [builtin `Bytes.slice`] |
| `Bytes` | `a`, `b` | `concatenate`（49） [builtin `Bytes.concatenate`] |
| `Bytes` | `b`, `offset`, `count`, `order` | `readUnsigned`（53） [builtin `Bytes.readUnsigned`]、`readSigned`（57） [builtin `Bytes.readSigned`] |
| `Bytes` | `n`, `count`, `order` | `fromUnsigned`（61） [builtin `Bytes.fromUnsigned`]、`fromSigned`（65） [builtin `Bytes.fromSigned`] |
| `Character` | `c` | `toInteger`（5） [builtin `Character.toInteger`]、`toString`（13） [builtin `Character.toString`]、`isASCIIDigit`（17） [builtin `Character.isASCIIDigit`]、`isASCIIWhitespace`（21） [builtin `Character.isASCIIWhitespace`]、`isAlphabetic`（25） [builtin `Character.isAlphabetic`]、`isNumeric`（29） [builtin `Character.isNumeric`]、`isWhitespace`（33） [builtin `Character.isWhitespace`]、`isUppercase`（37） [builtin `Character.isUppercase`]、`isLowercase`（41） [builtin `Character.isLowercase`]、`toUppercase`（45） [builtin `Character.toUppercase`]、`toLowercase`（49） [builtin `Character.toLowercase`] |
| `Character` | `n` | `fromInteger`（9） [builtin `Character.fromInteger`] |
| `Csv` | `text` | `parse`（11） [builtin `Csv.parse`]、`parseWithHeader`（19） [builtin `Csv.parseWithHeader`] |
| `Csv` | `text`, `delimiter` | `parseWith`（15） [builtin `Csv.parseWith`] |
| `Csv` | `rows` | `format`（23） [builtin `Csv.format`] |
| `Csv` | `rows`, `delimiter` | `formatWith`（27） [builtin `Csv.formatWith`] |
| `Decimal` | `x`, `places`, `mode` | `round`（5） [builtin `Decimal.round`] |
| `Decimal` | `x` | `absolute`（9） [builtin `Decimal.absolute`]、`truncate`（17） [builtin `Decimal.truncate`]、`toFloat`（21） [builtin `Decimal.toFloat`]、`fromFloat`（25） [builtin `Decimal.fromFloat`]、`toString`（29） [builtin `Decimal.toString`] |
| `Decimal` | `n` | `fromInteger`（13） [builtin `Decimal.fromInteger`] |
| `Decimal` | `s` | `parse`（33） [builtin `Decimal.parse`] |
| `Encoding` | `b` | `base64Encode`（5） [builtin `Encoding.base64Encode`]、`base64UrlEncode`（13） [builtin `Encoding.base64UrlEncode`] |
| `Encoding` | `text` | `base64Decode`（9） [builtin `Encoding.base64Decode`]、`base64UrlDecode`（17） [builtin `Encoding.base64UrlDecode`] |
| `Float` | `x` | `toString`（5） [builtin `Float.toString`]、`truncate`（13） [builtin `Float.truncate`]、`isNaN`（17） [builtin `Float.isNaN`]、`absolute`（21） [builtin `Float.absolute`]、`floor`（25） [builtin `Float.floor`]、`ceiling`（29） [builtin `Float.ceiling`]、`round`（33） [builtin `Float.round`]、`squareRoot`（37） [builtin `Float.squareRoot`] |
| `Float` | `s` | `parse`（9） [builtin `Float.parse`] |
| `Float32` | `n` | `fromFloat`（5） [builtin `Float32.fromFloat`]、`toFloat`（9） [builtin `Float32.toFloat`]、`toString`（17） [builtin `Float32.toString`]、`truncate`（21） [builtin `Float32.truncate`]、`isNaN`（25） [builtin `Float32.isNaN`]、`isInfinite`（29） [builtin `Float32.isInfinite`]、`absolute`（33） [builtin `Float32.absolute`]、`floor`（37） [builtin `Float32.floor`]、`ceiling`（41） [builtin `Float32.ceiling`]、`round`（45） [builtin `Float32.round`]、`squareRoot`（49） [builtin `Float32.squareRoot`] |
| `Float32` | `s` | `parse`（13） [builtin `Float32.parse`] |
| `Float64` | `x` | `toString`（4）、`truncate`（14）、`isNaN`（19）、`absolute`（24）、`floor`（29）、`ceiling`（34）、`round`（39）、`squareRoot`（44） |
| `Float64` | `s` | `parse`（9） |
| `Hash` | `b` | `sha256`（5） [builtin `Hash.sha256`] |
| `IO.Clock` | `milliseconds` | `sleep`（9） |
| `IO.Clock` | 引数なし | `monotonicMilliseconds`（11）、`now`（13）、`localOffsetMinutes`（15） |
| `IO.Console` | `text` | `write`（6）、`writeLine`（8）、`writeError`（10）、`writeErrorLine`（12） |
| `IO.Console` | 引数なし | `readLine`（18）、`readAll`（20）、`readAllLines`（22）、`readAllBytes`（24） |
| `IO.File` | `path` | `readText`（8）、`openReader`（10）、`readBytes`（14）、`readLines`（16）、`exists`（18）、`info`（20）、`listDirectory`（22）、`walk`（24）、`canonicalize`（26）、`createDirectory`（42）、`remove`（44）、`removeTree`（46） |
| `IO.File` | `reader` | `readLine`（12）、`closeReader`（64） [builtin `IO.File.closeReader`] |
| `IO.File` | `reader`, `maximumBytes` | `readChunk`（28） |
| `IO.File` | `path`, `text` | `writeText`（34）、`appendText`（36） |
| `IO.File` | `path`, `content` | `writeBytes`（38）、`appendBytes`（40） |
| `IO.File` | `from`, `to` | `rename`（48）、`copy`（67） |
| `IO.File` | `path`, `mode` | `openWriter`（50） |
| `IO.File` | `writer`, `text` | `write`（53）、`writeLine`（56） |
| `IO.File` | `writer`, `content` | `writeChunk`（59） |
| `IO.File` | `writer` | `closeWriter`（75） [builtin `IO.File.closeWriter`] |
| `IO.Process` | 引数なし | `arguments`（6）、`scriptDirectory`（8）、`workingDirectory`（12） |
| `IO.Process` | `name` | `environmentVariable`（10） |
| `IO.Process` | `code` | `exit`（18） |
| `IO.Process` | `command` | `run`（24）、`runAttached`（26） |
| `IO.Process` | `commandLine` | `shell`（28） |
| `IO.Process` | `program`, `arguments` | `command`（48） |
| `IO.Random` | `low`, `high` | `integer`（6） |
| `IO.Random` | 引数なし | `float`（8）、`boolean`（10） |
| `IO.Random` | `xs` | `shuffle`（12）、`choose`（14） |
| `IO.Random` | `seed` | `fromSeed`（19） [builtin `IO.Random.fromSeed`] |
| `IO.Random` | `generator`, `low`, `high` | `nextInteger`（23） [builtin `IO.Random.nextInteger`] |
| `IO.Random` | `generator` | `nextFloat`（27） [builtin `IO.Random.nextFloat`] |
| `IO.Random` | `generator`, `xs` | `shuffleWith`（31） [builtin `IO.Random.shuffleWith`] |
| `IOError` | `e` | `message`（5） [builtin `IOError.message`]、`kind`（9） [builtin `IOError.kind`] |
| `Integer` | `n` | `toString`（5） [builtin `Integer.toString`]、`toFloat`（13） [builtin `Integer.toFloat`]、`absolute`（25） [builtin `Integer.absolute`] |
| `Integer` | `s` | `parse`（9） [builtin `Integer.parse`] |
| `Integer` | `a`, `b` | `floorDivide`（17） [builtin `Integer.floorDivide`]、`floorModulo`（21） [builtin `Integer.floorModulo`]、`minimum`（29） [builtin `Integer.minimum`]、`maximum`（33） [builtin `Integer.maximum`]、`bitwiseAnd`（37） [builtin `Integer.bitwiseAnd`]、`bitwiseOr`（41） [builtin `Integer.bitwiseOr`]、`bitwiseExclusiveOr`（45） [builtin `Integer.bitwiseExclusiveOr`] |
| `Integer` | `a` | `bitwiseNot`（49） [builtin `Integer.bitwiseNot`] |
| `Integer` | `a`, `n` | `shiftLeft`（53） [builtin `Integer.shiftLeft`]、`shiftRight`（57） [builtin `Integer.shiftRight`]、`shiftRightUnsigned`（61） [builtin `Integer.shiftRightUnsigned`] |
| `Integer16` | `n` | `fromInteger`（5） [builtin `Integer16.fromInteger`]、`toInteger`（9） [builtin `Integer16.toInteger`]、`toString`（17） [builtin `Integer16.toString`]、`toFloat`（21） [builtin `Integer16.toFloat`]、`absolute`（25） [builtin `Integer16.absolute`] |
| `Integer16` | `s` | `parse`（13） [builtin `Integer16.parse`] |
| `Integer16` | `a`, `b` | `minimum`（29） [builtin `Integer16.minimum`]、`maximum`（33） [builtin `Integer16.maximum`]、`floorDivide`（37） [builtin `Integer16.floorDivide`]、`floorModulo`（41） [builtin `Integer16.floorModulo`]、`bitwiseAnd`（45） [builtin `Integer16.bitwiseAnd`]、`bitwiseOr`（49） [builtin `Integer16.bitwiseOr`]、`bitwiseExclusiveOr`（53） [builtin `Integer16.bitwiseExclusiveOr`] |
| `Integer16` | `a` | `bitwiseNot`（57） [builtin `Integer16.bitwiseNot`] |
| `Integer16` | `a`, `n` | `shiftLeft`（61） [builtin `Integer16.shiftLeft`]、`shiftRight`（65） [builtin `Integer16.shiftRight`]、`shiftRightUnsigned`（69） [builtin `Integer16.shiftRightUnsigned`] |
| `Integer32` | `n` | `fromInteger`（5） [builtin `Integer32.fromInteger`]、`toInteger`（9） [builtin `Integer32.toInteger`]、`toString`（17） [builtin `Integer32.toString`]、`toFloat`（21） [builtin `Integer32.toFloat`]、`absolute`（25） [builtin `Integer32.absolute`] |
| `Integer32` | `s` | `parse`（13） [builtin `Integer32.parse`] |
| `Integer32` | `a`, `b` | `minimum`（29） [builtin `Integer32.minimum`]、`maximum`（33） [builtin `Integer32.maximum`]、`floorDivide`（37） [builtin `Integer32.floorDivide`]、`floorModulo`（41） [builtin `Integer32.floorModulo`]、`bitwiseAnd`（45） [builtin `Integer32.bitwiseAnd`]、`bitwiseOr`（49） [builtin `Integer32.bitwiseOr`]、`bitwiseExclusiveOr`（53） [builtin `Integer32.bitwiseExclusiveOr`] |
| `Integer32` | `a` | `bitwiseNot`（57） [builtin `Integer32.bitwiseNot`] |
| `Integer32` | `a`, `n` | `shiftLeft`（61） [builtin `Integer32.shiftLeft`]、`shiftRight`（65） [builtin `Integer32.shiftRight`]、`shiftRightUnsigned`（69） [builtin `Integer32.shiftRightUnsigned`] |
| `Integer64` | `n` | `toString`（4）、`toFloat`（14）、`absolute`（29） |
| `Integer64` | `s` | `parse`（9） |
| `Integer64` | `a`, `b` | `floorDivide`（19）、`floorModulo`（24）、`minimum`（34）、`maximum`（39）、`bitwiseAnd`（44）、`bitwiseOr`（49）、`bitwiseExclusiveOr`（54） |
| `Integer64` | `a` | `bitwiseNot`（59） |
| `Integer64` | `a`, `n` | `shiftLeft`（64）、`shiftRight`（69）、`shiftRightUnsigned`（74） |
| `Integer8` | `n` | `fromInteger`（5） [builtin `Integer8.fromInteger`]、`toInteger`（9） [builtin `Integer8.toInteger`]、`toString`（17） [builtin `Integer8.toString`]、`toFloat`（21） [builtin `Integer8.toFloat`]、`absolute`（25） [builtin `Integer8.absolute`] |
| `Integer8` | `s` | `parse`（13） [builtin `Integer8.parse`] |
| `Integer8` | `a`, `b` | `minimum`（29） [builtin `Integer8.minimum`]、`maximum`（33） [builtin `Integer8.maximum`]、`floorDivide`（37） [builtin `Integer8.floorDivide`]、`floorModulo`（41） [builtin `Integer8.floorModulo`]、`bitwiseAnd`（45） [builtin `Integer8.bitwiseAnd`]、`bitwiseOr`（49） [builtin `Integer8.bitwiseOr`]、`bitwiseExclusiveOr`（53） [builtin `Integer8.bitwiseExclusiveOr`] |
| `Integer8` | `a` | `bitwiseNot`（57） [builtin `Integer8.bitwiseNot`] |
| `Integer8` | `a`, `n` | `shiftLeft`（61） [builtin `Integer8.shiftLeft`]、`shiftRight`（65） [builtin `Integer8.shiftRight`]、`shiftRightUnsigned`（69） [builtin `Integer8.shiftRightUnsigned`] |
| `Json` | `text` | `parse`（23） [builtin `Json.parse`] |
| `Json` | `value` | `stringify`（27） [builtin `Json.stringify`]、`stringifyPretty`（31） [builtin `Json.stringifyPretty`]、`asString`（50）、`asInteger`（58）、`asFloat`（66）、`asBoolean`（75）、`asArray`（83）、`asObject`（91） |
| `Json` | `value`, `k` | `get`（34） |
| `Json` | `value`, `index` | `at`（42） |
| `Lazy` | `value` | `force`（5） [builtin `Lazy.force`] |
| `List` | `xs` | `length`（5） [builtin `List.length`]、`isEmpty`（9） [builtin `List.isEmpty`]、`head`（13） [builtin `List.head`]、`tail`（17） [builtin `List.tail`]、`reverse`（37） [builtin `List.reverse`]、`sort`（57） [builtin `List.sort`] |
| `List` | `xs`, `i` | `get`（21） [builtin `List.get`] |
| `List` | `xs`, `x` | `prepend`（25） [builtin `List.prepend`]、`append`（29） [builtin `List.append`]、`contains`（53） [builtin `List.contains`] |
| `List` | `xs`, `ys` | `concatenate`（33） [builtin `List.concatenate`] |
| `List` | `xs`, `n` | `take`（41） [builtin `List.take`]、`drop`（45） [builtin `List.drop`] |
| `List` | `start`, `stop` | `range`（49） [builtin `List.range`] |
| `List` | `xs`, `f` | `map`（60）、`forEach`（103） |
| `List` | `xs`, `f`, `i`, `acc` | `mapFrom`（64） |
| `List` | `xs`, `p` | `filter`（74）、`any`（117）、`all`（129）、`find`（141） |
| `List` | `xs`, `p`, `i`, `acc` | `filterFrom`（78） |
| `List` | `xs`, `initial`, `f` | `fold`（91） |
| `List` | `xs`, `acc`, `f`, `i` | `foldFrom`（95） |
| `List` | `xs`, `f`, `i` | `forEachFrom`（107） |
| `List` | `xs`, `p`, `i` | `anyFrom`（121）、`allFrom`（133）、`findFrom`（145） |
| `Map` | 引数なし | `empty`（5） [builtin `Map.empty`] |
| `Map` | `pairs` | `fromList`（9） [builtin `Map.fromList`] |
| `Map` | `m` | `toList`（13） [builtin `Map.toList`]、`size`（33） [builtin `Map.size`]、`keys`（37） [builtin `Map.keys`]、`values`（41） [builtin `Map.values`] |
| `Map` | `m`, `k` | `get`（17） [builtin `Map.get`]、`remove`（25） [builtin `Map.remove`]、`contains`（29） [builtin `Map.contains`] |
| `Map` | `m`, `k`, `value` | `set`（21） [builtin `Map.set`] |
| `Map` | `m`, `f` | `map`（44）、`forEach`（63） |
| `Map` | `m`, `p` | `filter`（49） |
| `Map` | `m`, `initial`, `f` | `fold`（54） |
| `Network.Http` | `host`, `port` | `listen`（11） |
| `Network.Http` | `listener` | `listenerPort`（13）、`accept`（15）、`closeListener`（59） [builtin `Network.Http.closeListener`] |
| `Network.Http` | `exchange`, `response` | `respond`（19） |
| `Network.Http` | `request` | `send`（25） |
| `Network.Http` | `exchange` | `requestOf`（55） [builtin `Network.Http.requestOf`]、`closeExchange`（64） [builtin `Network.Http.closeExchange`] |
| `Network.Http` | `path` | `pathSegments`（68） [builtin `Network.Http.pathSegments`] |
| `Network.Http` | `host`, `port`, `handler` | `serve`（72） |
| `Network.Http` | `listener`, `group`, `handler` | `serveLoop`（79） |
| `Network.Http` | `status`, `s` | `text`（90）、`html`（95） |
| `Network.Http` | `status`, `value` | `json`（100） |
| `Network.Http` | `headers`, `name` | `header`（105） |
| `Network.Http` | `method`, `url` | `clientRequest`（114） |
| `Network.Http` | `url` | `get`（119） |
| `NetworkError` | `e` | `kind`（5） [builtin `NetworkError.kind`]、`message`（9） [builtin `NetworkError.message`] |
| `Option` | `o`, `f` | `map`（10）、`andThen`（18） |
| `Option` | `o`, `fallback` | `unwrapOr`（26） |
| `Option` | `o` | `isSome`（34）、`isNone`（42） |
| `Option` | `o`, `error` | `okOr`（50） |
| `Pair` | `p` | `first`（9）、`second`（15） |
| `Path` | `base`, `child` | `join`（5） [builtin `Path.join`] |
| `Path` | `parts` | `joinAll`（9） [builtin `Path.joinAll`] |
| `Path` | `p` | `parent`（13） [builtin `Path.parent`]、`fileName`（17） [builtin `Path.fileName`]、`stem`（21） [builtin `Path.stem`]、`extension`（25） [builtin `Path.extension`]、`isAbsolute`（33） [builtin `Path.isAbsolute`]、`components`（37） [builtin `Path.components`]、`normalize`（41） [builtin `Path.normalize`] |
| `Path` | `p`, `extension` | `withExtension`（29） [builtin `Path.withExtension`] |
| `Reference` | `value` | `new`（5） [builtin `Reference.new`] |
| `Reference` | `reference` | `get`（9） [builtin `Reference.get`] |
| `Reference` | `reference`, `value` | `set`（13） [builtin `Reference.set`] |
| `Reference` | `reference`, `f` | `update`（17） [builtin `Reference.update`] |
| `Regex` | `source` | `compile`（6） [builtin `Regex.compile`] |
| `Regex` | `pattern`, `text` | `isMatch`（10） [builtin `Regex.isMatch`]、`find`（14） [builtin `Regex.find`]、`findAll`（17）、`split`（51） |
| `Regex` | `m` | `matchText`（23） [builtin `Regex.matchText`]、`matchByteStart`（27） [builtin `Regex.matchByteStart`]、`matchByteEnd`（31） [builtin `Regex.matchByteEnd`] |
| `Regex` | `m`, `index` | `group`（35） [builtin `Regex.group`] |
| `Regex` | `m`, `name` | `namedGroup`（39） [builtin `Regex.namedGroup`] |
| `Regex` | `pattern`, `text`, `replacement` | `replaceFirst`（43） [builtin `Regex.replaceFirst`]、`replaceAll`（46） |
| `Regex` | `pattern`, `text`, `f` | `replaceAllWith`（56） |
| `Regex` | `pattern`, `text`, `start`, `afterMatch` | `findAt`（61） [builtin `Regex.findAt`]、`spanAt`（64） [builtin `Regex.spanAt`] |
| `Regex` | 引数なし | `maxStringBytes`（67） [builtin `Regex.maxStringBytes`] |
| `Regex` | `pattern`, `text`, `start`, `afterMatch`, `acc` | `findAllFrom`（69）、`splitFrom`（76） |
| `Regex` | `pattern`, `text`, `replacement`, `start`, `afterMatch`, `parts` | `replaceAllFrom`（83） |
| `Regex` | `pattern`, `text`, `f`, `start`, `afterMatch`, `parts` | `replaceFrom`（92） |
| `Regex` | `parts`, `part` | `appendPart`（106） |
| `Regex` | `parts` | `finishParts`（120） |
| `Regex` | `text`, `start`, `stop` | `sliceOrEmpty`（125） |
| `Result` | `r`, `f` | `map`（10）、`mapError`（18）、`andThen`（26） |
| `Result` | `r`, `fallback` | `unwrapOr`（34） |
| `Result` | `r` | `isOk`（42）、`isError`（50）、`ok`（58） |
| `Set` | 引数なし | `empty`（5） [builtin `Set.empty`] |
| `Set` | `xs` | `fromList`（9） [builtin `Set.fromList`] |
| `Set` | `s` | `toList`（13） [builtin `Set.toList`]、`size`（29） [builtin `Set.size`] |
| `Set` | `s`, `x` | `contains`（17） [builtin `Set.contains`]、`add`（21） [builtin `Set.add`]、`remove`（25） [builtin `Set.remove`] |
| `Set` | `a`, `b` | `union`（33） [builtin `Set.union`]、`intersection`（37） [builtin `Set.intersection`]、`difference`（41） [builtin `Set.difference`] |
| `Set` | `s`, `f` | `map`（44）、`forEach`（59） |
| `Set` | `s`, `p` | `filter`（49） |
| `Set` | `s`, `initial`, `f` | `fold`（54） |
| `String` | `s` | `byteLength`（5） [builtin `String.byteLength`]、`characterCount`（13） [builtin `String.characterCount`]、`isEmpty`（25） [builtin `String.isEmpty`]、`lines`（49） [builtin `String.lines`]、`trim`（57） [builtin `String.trim`]、`characters`（69） [builtin `String.characters`]、`toUppercase`（77） [builtin `String.toUppercase`]、`toLowercase`（81） [builtin `String.toLowercase`]、`toUTF8`（85） [builtin `String.toUTF8`] |
| `String` | `s`, `start`, `stop` | `byteSlice`（9） [builtin `String.byteSlice`]、`characterSlice`（21） [builtin `String.characterSlice`] |
| `String` | `s`, `i` | `characterAt`（17） [builtin `String.characterAt`] |
| `String` | `s`, `part` | `contains`（29） [builtin `String.contains`]、`byteIndexOf`（41） [builtin `String.byteIndexOf`] |
| `String` | `s`, `prefix` | `startsWith`（33） [builtin `String.startsWith`] |
| `String` | `s`, `suffix` | `endsWith`（37） [builtin `String.endsWith`] |
| `String` | `s`, `separator` | `split`（45） [builtin `String.split`] |
| `String` | `xs`, `separator` | `join`（53） [builtin `String.join`] |
| `String` | `s`, `old`, `new` | `replace`（61） [builtin `String.replace`] |
| `String` | `s`, `n` | `repeat`（65） [builtin `String.repeat`] |
| `String` | `cs` | `fromCharacters`（73） [builtin `String.fromCharacters`] |
| `String` | `b` | `fromUTF8`（89） [builtin `String.fromUTF8`] |
| `Task` | `actions` | `all`（7） [builtin `Task.all`]、`allOk`（12） [builtin `Task.allOk`]、`race`（16） [builtin `Task.race`] |
| `Task` | `milliseconds`, `action` | `withTimeout`（20） [builtin `Task.withTimeout`] |
| `Task` | `task` | `await`（24） [builtin `Task.await`] |
| `TaskGroup` | 引数なし | `open`（5） [builtin `TaskGroup.open`] |
| `TaskGroup` | `group`, `action` | `spawn`（9） [builtin `TaskGroup.spawn`] |
| `Time` | `seconds` | `fromUnixSeconds`（22） [builtin `Time.fromUnixSeconds`] |
| `Time` | `milliseconds` | `fromUnixMilliseconds`（26） [builtin `Time.fromUnixMilliseconds`] |
| `Time` | `t` | `toUnixSeconds`（30） [builtin `Time.toUnixSeconds`]、`toUnixMilliseconds`（34） [builtin `Time.toUnixMilliseconds`] |
| `Time` | `t`, `milliseconds` | `addMilliseconds`（38） [builtin `Time.addMilliseconds`] |
| `Time` | `a`, `b` | `differenceMilliseconds`（42） [builtin `Time.differenceMilliseconds`] |
| `Time` | `t`, `offsetMinutes` | `toDateTime`（46） [builtin `Time.toDateTime`]、`formatISO8601`（54） [builtin `Time.formatISO8601`] |
| `Time` | `dt` | `fromDateTime`（50） [builtin `Time.fromDateTime`] |
| `Time` | `text` | `parseISO8601`（58） [builtin `Time.parseISO8601`] |
| `Time` | `t`, `offsetMinutes`, `pattern` | `format`（62） [builtin `Time.format`] |
| `Trait` | `x` | `show`（13）、`pure`（43）、`show`（75）、`show`（81）、`show`（87）、`show`（93）、`show`（99）、`show`（105）、`show`（111）、`show`（117）、`show`（123）、`show`（129）、`show`（135）、`show`（141）、`show`（147）、`show`（153）、`show`（159）、`show`（165）、`show`（172）、`show`（181）、`show`（188）、`pure`（389）、`pure`（434）、`show`（487）、`show`（494） |
| `Trait` | `x`, `y` | `compare`（19）、`combine`（25）、`compare`（197）、`compare`（203）、`compare`（215）、`compare`（221）、`compare`（227）、`compare`（233）、`compare`（239）、`compare`（245）、`compare`（251）、`compare`（263）、`compare`（269）、`compare`（275）、`compare`（281）、`compare`（287）、`compare`（293）、`compare`（299）、`compare`（318）、`compare`（329）、`compare`（340）、`combine`（357）、`combine`（369）、`combine`（501）、`combine`（513） |
| `Trait` | 引数なし | `empty`（31）、`empty`（363）、`empty`（375）、`empty`（507）、`empty`（519） |
| `Trait` | `x`, `f` | `map`（37）、`flatMap`（51）、`traverse`（63）、`map`（383）、`flatMap`（402）、`traverse`（417）、`map`（428）、`flatMap`（451）、`traverse`（470） |
| `Trait` | `fs`, `x` | `apply`（45）、`apply`（393）、`apply`（438） |
| `Trait` | `x`, `initial`, `f` | `fold`（57）、`fold`（408）、`fold`（464） |
| `Trait` | `s` | `showString`（67） [builtin `Trait.showString`] |
| `Trait` | `c` | `showCharacter`（70） [builtin `Trait.showCharacter`] |
| `Trait` | `x`, `y`, `i` | `compareListsFrom`（304） |
| `Trait` | `fs`, `xs`, `i`, `acc` | `applyFrom`（443） |
| `Trait` | `xs`, `f`, `i`, `acc` | `flatMapFrom`（456）、`traverseFrom`（475） |
| `Trait` | `xs` | `appendToList`（524）。戻り値の関数型の契約名は `value` |
| `Triple` | `t` | `first`（9）、`second`（15）、`third`（21） |
| `UnsignedInteger` | `n` | `fromInteger`（4）、`toInteger`（9）、`toString`（19）、`toFloat`（24）、`toDecimal`（29）、`absolute`（39） |
| `UnsignedInteger` | `s` | `parse`（14） |
| `UnsignedInteger` | `x` | `fromDecimal`（34） |
| `UnsignedInteger` | `a`, `b` | `minimum`（44）、`maximum`（49）、`floorDivide`（54）、`floorModulo`（59）、`bitwiseAnd`（64）、`bitwiseOr`（69）、`bitwiseExclusiveOr`（74） |
| `UnsignedInteger` | `a` | `bitwiseNot`（79） |
| `UnsignedInteger` | `a`, `n` | `shiftLeft`（84）、`shiftRight`（89） |
| `UnsignedInteger16` | `n` | `fromInteger`（5） [builtin `UnsignedInteger16.fromInteger`]、`toInteger`（9） [builtin `UnsignedInteger16.toInteger`]、`toString`（17） [builtin `UnsignedInteger16.toString`]、`toFloat`（21） [builtin `UnsignedInteger16.toFloat`]、`absolute`（25） [builtin `UnsignedInteger16.absolute`] |
| `UnsignedInteger16` | `s` | `parse`（13） [builtin `UnsignedInteger16.parse`] |
| `UnsignedInteger16` | `a`, `b` | `minimum`（29） [builtin `UnsignedInteger16.minimum`]、`maximum`（33） [builtin `UnsignedInteger16.maximum`]、`floorDivide`（37） [builtin `UnsignedInteger16.floorDivide`]、`floorModulo`（41） [builtin `UnsignedInteger16.floorModulo`]、`bitwiseAnd`（45） [builtin `UnsignedInteger16.bitwiseAnd`]、`bitwiseOr`（49） [builtin `UnsignedInteger16.bitwiseOr`]、`bitwiseExclusiveOr`（53） [builtin `UnsignedInteger16.bitwiseExclusiveOr`] |
| `UnsignedInteger16` | `a` | `bitwiseNot`（57） [builtin `UnsignedInteger16.bitwiseNot`] |
| `UnsignedInteger16` | `a`, `n` | `shiftLeft`（61） [builtin `UnsignedInteger16.shiftLeft`]、`shiftRight`（65） [builtin `UnsignedInteger16.shiftRight`] |
| `UnsignedInteger32` | `n` | `fromInteger`（5） [builtin `UnsignedInteger32.fromInteger`]、`toInteger`（9） [builtin `UnsignedInteger32.toInteger`]、`toString`（17） [builtin `UnsignedInteger32.toString`]、`toFloat`（21） [builtin `UnsignedInteger32.toFloat`]、`absolute`（25） [builtin `UnsignedInteger32.absolute`] |
| `UnsignedInteger32` | `s` | `parse`（13） [builtin `UnsignedInteger32.parse`] |
| `UnsignedInteger32` | `a`, `b` | `minimum`（29） [builtin `UnsignedInteger32.minimum`]、`maximum`（33） [builtin `UnsignedInteger32.maximum`]、`floorDivide`（37） [builtin `UnsignedInteger32.floorDivide`]、`floorModulo`（41） [builtin `UnsignedInteger32.floorModulo`]、`bitwiseAnd`（45） [builtin `UnsignedInteger32.bitwiseAnd`]、`bitwiseOr`（49） [builtin `UnsignedInteger32.bitwiseOr`]、`bitwiseExclusiveOr`（53） [builtin `UnsignedInteger32.bitwiseExclusiveOr`] |
| `UnsignedInteger32` | `a` | `bitwiseNot`（57） [builtin `UnsignedInteger32.bitwiseNot`] |
| `UnsignedInteger32` | `a`, `n` | `shiftLeft`（61） [builtin `UnsignedInteger32.shiftLeft`]、`shiftRight`（65） [builtin `UnsignedInteger32.shiftRight`] |
| `UnsignedInteger64` | `n` | `fromInteger`（5） [builtin `UnsignedInteger64.fromInteger`]、`toInteger`（9） [builtin `UnsignedInteger64.toInteger`]、`toString`（17） [builtin `UnsignedInteger64.toString`]、`toFloat`（21） [builtin `UnsignedInteger64.toFloat`]、`toDecimal`（25） [builtin `UnsignedInteger64.toDecimal`]、`absolute`（33） [builtin `UnsignedInteger64.absolute`] |
| `UnsignedInteger64` | `s` | `parse`（13） [builtin `UnsignedInteger64.parse`] |
| `UnsignedInteger64` | `x` | `fromDecimal`（29） [builtin `UnsignedInteger64.fromDecimal`] |
| `UnsignedInteger64` | `a`, `b` | `minimum`（37） [builtin `UnsignedInteger64.minimum`]、`maximum`（41） [builtin `UnsignedInteger64.maximum`]、`floorDivide`（45） [builtin `UnsignedInteger64.floorDivide`]、`floorModulo`（49） [builtin `UnsignedInteger64.floorModulo`]、`bitwiseAnd`（53） [builtin `UnsignedInteger64.bitwiseAnd`]、`bitwiseOr`（57） [builtin `UnsignedInteger64.bitwiseOr`]、`bitwiseExclusiveOr`（61） [builtin `UnsignedInteger64.bitwiseExclusiveOr`] |
| `UnsignedInteger64` | `a` | `bitwiseNot`（65） [builtin `UnsignedInteger64.bitwiseNot`] |
| `UnsignedInteger64` | `a`, `n` | `shiftLeft`（69） [builtin `UnsignedInteger64.shiftLeft`]、`shiftRight`（73） [builtin `UnsignedInteger64.shiftRight`] |
| `UnsignedInteger8` | `n` | `fromInteger`（4） |
| `UnsignedInteger8` | `b` | `toInteger`（9）、`toString`（14） |
| `UnsignedInteger8` | `a`, `b` | `bitwiseAnd`（19）、`bitwiseOr`（24）、`bitwiseExclusiveOr`（29） |
| `UnsignedInteger8` | `a` | `bitwiseNot`（34） |
| `UnsignedInteger8` | `a`, `n` | `shiftLeft`（39）、`shiftRight`（44） |

調査した宣言は 563、名前の組でまとめた行は 235 である。名前以外の型の一覧を複製するものではなく、内側の関数型の名前は本文の Q10 の表を正とする。

