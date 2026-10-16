# キーワード・拡張可能な型・try の詳しい設計

## 目的と範囲

TODO-250 の第 1 弾として、準備、段 1 A（語の分類と return の改行）、段 2 D（拡張可能な型）、段 3 B2（try の処置）、移行・版・公開の整合の順で改造する。Q1〜Q20 と R2・R13・R18 の設計者の回答、および [decisions.md](decisions.md) の他の R1〜R18 の推す案を具体化した設計である。未回答の R は設計者の決定と区別する。実装の作業は [plan.md](plan.md) に定める。

今回作るのは改造の文書だけである。以下の型・関数・診断・版は、実装後に採る仕様を記したものであり、現行実装の説明ではない。今回、処理系・現行設計書・テスト・formal・docs/todo を変更しない。タグ・公開・コミットも行わない。

## 前提と準備

調査の基準は `5ef09b51f4f5fabb321eab610ba0a709441d16eb` である。従来の調査は [study/](study/lexical.md)、今回の追加集計は [study/failure-types.py](study/failure-types.py) と [study/failure-types.json](study/failure-types.json) に置く。実装開始時に HEAD と入力ハッシュを照合し、差があれば対象一覧を更新する。歴史資料は作業漏れを調べるために読み、仕様の根拠は現在の設計書と実装に置く。

目的の優先順位は 00-01 に従う。静的検査が保証するのは型とエフェクトへの適合であり、利用者の意図、外部操作の成功、停止性は保証しない。Process.Exit の追跡は実行時の権限制御や OS の隔離と同じものではない。TODO-249 の一般の型付きの失敗の捕捉、TODO-191 の範囲パターン、TODO-027 のリソースの追加規則・失敗の分類の見直し、正式版の互換性の約束全体は今回変更しない。

### 変更する型と受け渡し

`src/` は `crates/benitoite/src/`、`tests/` は同クレートの tests、Lean のパスは `formal/Benitoite/` 以下を指す。表は既存の公開の型・関数の変更範囲である（R7）。実装の開始時にこの表をレビューし、未記載のシグネチャ変更を実装者の判断だけで行わない。

| 対象 | 変更する内容 | 接続先・不変条件 |
|---|---|---|
| `syntax/token.rs::TokenKind` | `KwDie` を追加 | keyword・表示・名前の拒否・改行・Bounds・formatter の全 match を更新 |
| `syntax/ast.rs::TryExpr` | `action: TryAction` を追加。`ImplicitReturn`, `Return { span }`, `Die { span, message: Option<Box<Expr>> }` | value と処置の位置を別に保持。従来の構築箇所は ImplicitReturn。Die の追加時期とテスト入口は R14 に従う |
| `types/mod.rs::AdtDef` | `extensible: bool` を追加。宣言位置は既存 binding から引く | data・record 共通。生成したレコードの API、tag・ctors・fields は変えない |
| `resolve` のパッケージ比較 | 現在の `collect.rs::same_package` の判断を、名前解決の出力からも参照できる共通の判定へ移す | Entry/User、Prelude/Stdlib、同じ Package の範囲を維持。文字列パスで新規判定しない |
| `modules::{ModuleInfo,ImportLink}` と依存の探索 | 名前を公開しない内部依存の辺（target と構文の Span）を明示 import と別に保持し、cycle は両方を辿る | AST の import や利用者のスコープを捏造しない。既存 ImportLink.decl の架空の NodeId で表現しない |
| `typeck/patterns.rs` の公開の検査関数 | `CoverageView`（外部扱いになる ADT の集合）を引数に加える | check_match・check_binding と、到達可能性・重複・covering の全経路で同じ view。既定で外部とみなす隠れた判断はしない |
| `typeck/patterns::Shape` と Lean の `Shape` / `CoverageWitness` | Rust は `Future(BindingId)`、Lean は `future (d : DataName)` を追加 | 既存の Other/other は整数・文字列などの残りの形として維持。将来の形の型の出どころを失わない |
| `typeck/context::Body` と `Body::new` | 本体の `ModuleId` を明示的に渡して保持 | 関数・実装メソッド・const の入口で渡し、内側の lambda/guard/lazy へ引き継ぐ。CoverageView はこの module と共通の same_package から生成 |
| `typeck/patterns::{MatchIssue,BindingCheck}` | 非網羅の反例に含まれる将来の形の型の束縛番号を保持 | String の反例から型を逆解析しない。E0601/7 の副位置・help の出どころにする |
| `typeck::{TryInfo,TypeckOutput}` | `TryInfo { kind, action }`、`TryActionInfo::Return { ret: Ty } / Die { show: Option<DictExpr>, exit: BindingId }`。必要な確定型・型引数は既存表を使う | Option の show は None。Result の show は必須。囲む ret を die に要求しない |
| `typeck/infer.rs::Constraint::Try` と `context::Body` | 処置と表示制約の出どころを保持。Return の ret と Die を分ける | Class の解決より前に die の E を確定して Show 制約を登録。遅延解決を一回だけで打ち切らない |
| `ir/core_ir.rs::CompKind::App`、`lower_ir.rs` の App | `exit_report: Option<ExitReportArgs>`。原因の String と任意の説明の String の値の参照 | canonical な Process.exit、code=1 にだけ付く。公開の引数・操作の数は変えない |
| `bytecode/program.rs::Proto` | 命令位置に対応する `ExitReportSite { cause_reg, message_reg, span }` の表を追加 | emit・レジスタ割当・liveness・verify・disasm が同じ表を使う。通常の IO 命令の引数は一つ |
| `vm` の要求・停止結果 | `DieFailure { cause: String, message: Option<String>, at: Span }` を要求単位・採用した停止結果に任意で保持。停止理由は `StopReason::Exit { code: u8, die_failure: Option<DieFailure> }`（R56） | 所有した文字列だけ。Direct/Request で同じ。StopReason::Exit の既存の意味・優先順位を維持 |
| `refinterp::RefOutcome::Exited`（R20 の推す案） | `die_failure: Option<DieFailure>` を追加 | VM と原因・説明・位置も比較する。通常 exit は None。公開 run の引数・戻り型名は維持 |
| `runtime/run.rs::RunEnd` | `die_failure: Option<DieFailure>` | Exited(1) の既定の die にだけ Some。main_error と相互に独立。すべての構築・消去経路を更新 |
| `diag::ReportKind` と `diag/render` | `Die` を追加し、既存の Diagnostic の欄で文章/JSON にする | RunEnd の構造化した情報から作り、二重描画しない |
| CLI test runner の `Failure` | `Exit` の失敗の内訳に die 情報を追加 | code 0 の通常 exit も従来どおりテスト失敗。die も次のテストへ続く |
| `modules/package.rs::BreakingChange` | `help: &'static str` を追加。文言は diag::codes または modules::text に定義 | 宣言より後、current 以下のすべての変更から help を作る |
| Lean の Coverage・Surface・Exchange | 有効な型の指定、die の型付き表層と辞書・説明・終了操作を追加 | D: corpus 9/型表 3/網羅性 3。B2: corpus 10/型表 3/網羅性 3。六入口の対象を削らない |

内部の補助型の名前は実装時の整理を許すが、上の情報をなくしたり公開の言語 API を増やしたりしない。ヒープの公開 API と unsafe の範囲は変更する必要がない設計とする。追加が必要になったら理由を報告し、heap の検査の追加を計画へ反映する。

P2 の実装開始時の照合は [p2/types-and-dependencies.md](p2/types-and-dependencies.md)、定義・定理と六入口の差分案は [p2/formal.md](p2/formal.md)、診断の対応案は [p2/diagnostics.md](p2/diagnostics.md) に記す。R19 は入口から到達しない prelude を含む循環検査の起点、R20 は参照インタプリタの結果型の明記漏れを補う推す案であり、G1 のレビュー対象とする。P2 では処理系の型・公開シグネチャ・Lean の定義を変更していない。

## 段 1 A: 字句・語の分類と return の改行

### キーワードと文脈で読む語

既存の 34 語の綴りを保ち、`die` 一語だけを予約する。合計は 35 語である。`function`・`public`・`implement`・`lambda` を別綴りへ変えず、`else`・`shadow` も有効なままとする。`fn`・`pub`・`impl`・`mut`、ループ・並行処理・将来の機能の語は予約しない。`as` と header の語は今の文脈だけで読む。

`die` は識別子を期待するどの位置でも拒否する。局所名、関数名、ラベル、ドットの後、import の別名、フィールド名も E0216 の対象になる。`Die`・`died`・`dieLater` は従来の識別子である。属性名の `extensible` 自体は識別子であり、普通の変数・関数に使える。

段 1 では `die` を単独の式として受理しない。既存の E0216 と E0201 の案内を接続し、段 3 で try の処置として受理する。誤った他言語風の形のために、有効な `fn(...)` などの名前の使用を壊さない。キーワード・式の終わり・継続の判定は token、lexer、newline、lambda_bounds、parser、formatter で揃える。`KwDie` は `newline::is_keyword` に入れ、`continues_after` に入れない。A1 ではまだ受理しない `or die` を help で勧めない。formatter に新しいキーワード表を作らず、実在する分類・位置処理だけを確認する。

### return の直後の改行（R13 の回答 B）

【決定】普通の `return` と処置の `or return` のどちらでも、`return` の直後の物理改行は常に文を終える。普通の `return` の値は、`return` と同じ物理行で書き始めなければならない。行末のコメント・空行・コメントだけの行を挟んでも値を次の行から読み始めない。普通の return と処置を直前の `or` で区別する案 A は採らない。

`syntax/newline.rs::continues_after` から `KwReturn` を外す。削除だけでは `continues_before`（次行の `+`・`|>` など）で改行が消えるため、`resolve_newlines` は `KwReturn` 直後の改行をその判定より先に文末にする。括弧の内側でも return の直後にはこの規則を優先し、改行を捨てた後で parser が復元する方式にはしない。`KwReturn` は `is_keyword` に残す。`or` の前後の継続は変えない。

同じ行で値を書き始めた後の改行の規則は変えない。`return x +` の次行の値、`return (` の括弧内、`return f(` の引数、`return if condition then` の次行の分岐は従来どおり続けられる。値を複数行で書くこと全体を禁じない。短い lambda の一物理行の条件も維持する。

普通の `return` は値を要求する既存の `parser/exprs.rs::parse_return` を使う。現行の `parse_expr` は NEWLINE を式として受理しないので、字句の変更後は既存の E0201（`expected an expression, found a newline`）で値の欠落を報告でき、新しい番号は要らない。ただし主文だけでは移行方法が分からないため、E0201 に `return_value_line` の help ``start the return value on the same physical line as `return` `` を追加する。parse_return で直後が NEWLINE の場合に限って付け、主位置はその改行、補足の位置は return とする。次行の値を読み取らず回復する。`return x +` の後のオペランド不足など、値を書き始めた後の別の誤りにはこの help を付けない。`or return` は値のない専用の処置なので、この診断を通さない。

理由: 普通の return も処置も同じ規則で終わり、普通の return の値を欠く形は実行前に拒否できる。同じ行で値を書き始める形を保ちつつ、検査と診断の明確さを優先する（設計原則 4）。設計者の他言語との比較を含む理由は decisions.md の R13 に記す。

### return の改行で書き直す既存入力と整形の調査

2026-10-15、HEAD `7eb22f8673fb1be2b19d6cc60245caddc0bcbb4f` の追跡ファイルを読み取りで調べた。P1 の候補は try の調査なので、それとは別に .bnt・.formatted・Markdown のコード例とインライン、および Rust の通常/raw/byte 文字列を確認した。Rust の文字列は `tools/named-arguments-migrate/extract.py` の復号と元位置の対応を利用し、短い検査文字列も漏らさないよう言語らしさの絞り込みを外した。ホストに書かれた `return\n`・`return\r` と生成・連結の周辺も別検索した。reference/・docs/archive/・docs/todo/・過去の測定記録・syntax-measure の固定入力は調査と編集の対象外とした。

有効な既存の Benitoite 入力の書き直しは、次の 24 行 / 6 ファイルである。すべて `return` の次の行に長い `if … end if` があり、`return if …` と同じ行へ寄せる。型・uses・返す値・ベンチマークの仕事量は変えず、測定も行わない。

| tools/bench/wit-transfer/ 以下のファイル | return の行 | 数 |
|---|---|---:|
| `large-bytes-adapter.bnt` | 12, 16 | 2 |
| `large-bytes-typed.bnt` | 16, 20 | 2 |
| `large-bytes.bnt` | 14, 18 | 2 |
| `nested.bnt` | 12, 16 | 2 |
| `numbers.bnt` | 46, 50, 54, 58, 62, 66, 70, 74, 78, 82, 86, 90, 94, 98 | 14 |
| `primitives.bnt` | 21, 25 | 2 |
| 合計 | | 24 |

| その他の確認先 | 調査結果と実装時の扱い |
|---|---|
| testdata の .bnt・.formatted と例・標準ライブラリ | 値を次行から始める有効な入力は 0 件。期待値の一括更新はしない |
| `syntax/newline.rs:309` | `continuation_and_new_statement_boundaries` の `"return\n  x"` 1 件が継続を期待している。文末を期待する側へ移し、通常の return の解析の拒否・案内も確認する。24 行の書き直しには数えない |
| `formatter/verify/tests.rs:79` | `before.replace("return call", "return\n call")` は短い lambda を壊した出力を拒否する負の検査。拒否を保ち、有効例へ書き直さない |
| その他の Rust の検査文字列・生成元 | 有効な return の値を次行から始める入力は 0 件。字句名・交換形式のタグ・失敗時の説明にある文字列 `"return"` は入力ではない。`tasks/io/output_tests.rs:565–566` の置換は return の前に改行を加え、値の `()` は同じ行に残すため変更不要 |
| 現行設計書・英日リファレンス・Skill の例 | 値を次行から始める実行例は 0 件。01-08 の行末コメント内の return や記法を移行対象に数えない。規則の説明は次節のとおり更新する |
| formatter の出力経路 | `formatter/print.rs::print`・`split_lines`・`Printer::write_line` は元の改行を保ち、行の折り返し・結合をしない。`roles/walk.rs` の Return は値を辿るだけで、return 後に改行を生成しない。06-03 の契約とも一致する。現行の .formatted と print/tests に直す例は 0 件。新規則で構文エラーになる旧形は通常の fmt が拒否し、fmt に自動移行は追加しない |

この件数は旧 parser を新規則で実行した結果ではない。連結・format! や任意の生成器の出力を完全に解析した証明でもない。A4 の開始時に同じ検索と P1 の全入力一覧で差分を確認し、新規則への変更と 24 行の修正を同じ取り込みで行う。現在の継続を要求する検査 1 件を仕様変更として更新することと、意図した拒否の検査を弱めることを区別する。

### 文書・形式化への反映

01-01「キーワード」、01-02 の属性一覧、02-03 の Token/AST、02-10 の案内、06-06 と Skill の記述を更新する。語の一覧を生成する箇所、`TokenKind` を網羅しているテストも確認する。35 語という表だけを写す新テストは作らず、lexer と parser の既存の表に正負の例を加える。

return の一般規則は A4 で 01-01「改行による区切り」の継続字句から return を外し、優先する文末規則を加える。01-02「ブロックと文」「`return`」「演算子の優先順位と結合性」の関連記述、02-03 の改行判定、02-10 の E0201、06-03 の構文エラー時の扱いも揃える。`docs/reference/benitoite.md` の文の区切りと return、Skill の SKILL.md・common-mistakes.md の案内に、値を同じ行で書き始め、その後は普通の複数行の規則を使えることを記す。生成 grammar.md の説明は `cli/tools/skill/generate.rs` を直し、diagnostics.md とともに gen_skill で作り直す。英語を正とし、最終の英日対応は M8 で確認する。最小版リファレンスへ新規則を混ぜない。

R13 の変更は形式化の対象外である。`Surface/Syntax.lean` の型付き表層の return と `Lemmas/ReturnTry.lean` の escape への脱糖は、物理行も NEWLINE も入力に持たず、返す値の型・効果・作用先を変えない。07-04「01-12 との対応」の既存の物理行の行は短い lambda だけを扱うため、A4 で「return 直後の改行による文末と、値の開始を同じ物理行に限る字句・構文検査」を対象外の独立した行として書き足す。R13 だけを理由に Lean・01-12 の定義や証明を変えたり、既存 return の意味を対象外へ移したりしない。B2 の型・脱糖の変更には従来どおり先行する Lean の変更と証明が要る。

## 段 2 D: 拡張可能な型

### 属性の文法と適用先

既存の属性の構文へ次を追加する。R2 により record にも認める。

```ebnf
ExtensibleAttr = "@" "extensible" .
AttributedType = { Attribute } [ Visibility ] ( DataDecl | RecordDecl ) .
```

引数なしの `@extensible` を一つだけ書ける。`@extensible()` は既存の空引数の属性と同じく意味上は引数 0 個として受理し、整形で書き手の括弧を維持する。標準の文書では括弧なしに統一する。文字列引数があれば E0817、非文字列引数は既存の E0220、重複は E0803、関数・別名・外部の type への指定は E0802 にする。個別の構成子の前の属性は解析の対象に加えず、data 本体内の `@` は既存の E0201 を保つ（R11）。最初の原因を一つ報告し、位置と引数の誤りを同じ属性へ重ねない。`@deprecated` などとの併用は既存の属性の位置規則を保つ。

属性は型の使用条件を変える。01-02 の「評価の意味を変えない属性」という現行の一般化を改め、評価への指示と型検査の使用条件を区別する。型名で失敗型を特別扱いしない。利用者の非公開・public・public(package) の data/record にも同じ属性を使える。

### パッケージの境界と網羅性

定義したパッケージ内では、宣言済みの構成子の列挙で網羅と判定できる。外では、宣言済みの形に検査用の将来の形を一つ加える。同じパッケージかは public(package) の既存の判断と一致させる。ModuleId の大小、ファイルの配置、import の綴りだけでは決めない。

Prelude/Stdlib は一つの範囲、Entry/User は根の一つの範囲、Package 同士は現在の依存の識別に従う。同じ依存の内部モジュールと根の呼び出し元を取り違えない。名前解決で使う共通の判定から、照合するモジュールごとの `CoverageView` を一度作り、型表を複製せず参照する。view は一つの判定の間で不変であり、入れ子の再帰と memo の探索で同じものを使う。view をまたいで memo を再利用しない。

将来の形を覆うのは変数または `_` だけである。`Kind.Other` は既知の構成子であり、将来の形を覆わない。ガード付き分岐を網羅に数えない。入れ子の Result、Option、リスト、レコード、型の別名を展開した位置にもこの条件を適用する。Result と Option 自体には指定を付けない。

| 外部から書くパターン | 判定 |
|---|---|
| 全既知構成子だけ | E0601。将来の形が残る |
| 全既知構成子、最後に `case other` | 受理。最後の分岐を E0602 にしない |
| `case other if condition` のみ | ガードが偽のときの E0601 |
| `case _`、後に `case other` | 後を従来どおり E0602 |
| `Result.Ok(_)`, `Result.Error(error)` | error は変数なので、E が指定付きでも網羅 |
| Error の中も既知の種類だけに分解 | Error 内の変数・`_` の分岐が要る |
| 一構成子型の `bind Only(x) <- value` | 指定付き型を外から見るなら E0607 |
| `ParseError(message: text, ..)` | 既知のレコード形だけ。外部の match にはその他の分岐が要る |

record の `..` は現在の欄の省略だけを表す。R2 は record への新しい構成子や欄の追加の互換性を約束しない。構築・更新・getter は今の型の契約を保つ。コンパイラが生成する getter と record 更新の内部の照合は、既知の record 宣言での全域性を使う。ソースの match/bind の判定へ入れる view を、この生成処理へ流用しない。

### 判定の手順と診断

`typeck/patterns.rs::shapes` で、view が指定する ADT に新しい `Shape::Future(BindingId)` を加える（R9）。既存の `Shape::Other` は整数・文字列・未知の型の残りの形に使うため流用しない。Future の欄の数は 0 とし、変数と `_` だけが覆う。useful・check_match・check_binding・covering_alternatives・入れ子の探索を同じ view で行う。E0609 の予算、判定打ち切り時に部分的な結果を返さない規則、既存の型での選ばれない分岐の検出を維持する。範囲パターンの TODO-191 の差には手を加えない。

反例は、実在しない構成子名にせず、`<future constructor of TypeName>`（record は `<future shape of TypeName>`）とする。

TypeName は既存の構成子の反例表示と揃えて `AdtDef.name` をそのまま使い、型引数や import の別名を付けない。E0607 の `{ty}` の `show_type` とは用途を分ける。型の同一性と宣言の副位置は表示名でなく BindingId から引く。入れ子なら `Result.Error(<future constructor of IOErrorKind>)` の形を保つ。

E0601/E0607 に、指定された宣言の副位置と、`add an unguarded variable or '_' pattern to cover future values of '{future_ty}'` の help を加える。反例に将来の形が含まれる場合だけ出す。help の future_ty は R9 の型名とし、E0607 の主文が使う ty（show_type）と別の引数にする。`MatchIssue` の内部で必要な型の出どころを保持し、反例の String を解析して help を決めない。包括的な分岐の本体を自動で作らない。

E0608（選択肢の中の選ばれない形）にも同じ view を使い、全既知構成子の後の `| other` は将来の形を覆うため拒否しない。先行する `_` が覆った選択肢は従来どおり拒否する。組み込みソースの宣言の副位置が文章/JSON の両方で描画できることは D7 の golden で確認する。

### 標準ライブラリの全失敗型と移行件数

標準ライブラリの .bnt 全 52 ファイルの公開 data/record 宣言 22 件と、Result の失敗側の型・失敗の種類を確認した。専用の公開の失敗型は下表の四型である。不透明な IOError/NetworkError と、Regex・Encoding・Time などが返す String も調査した。String は一般の基本型であり、属性を付ける宣言のある失敗専用の型ではない。失敗を返す用途だけで String 全体を拡張可能にする規則は作らない。

表の数字は「新たに包括的な分岐を足す必要がある既存の match」の数である。外部から Kind を照合する既存 6 件はいずれも包括的な分岐を持つ。ParseError の getter 呼び出し、Result.Error(error) のような error 全体の束縛は、ParseError の構成子を分解する照合に数えない。

| 対象型 | 宣言と構成子数 | 標準ライブラリ | testdata | 例・現在の tools | Skill 手書き/生成 | Rust の検査入力 | 設計書・英日文書 | 合計 |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| `IOErrorKind` | `stdlib/IOErrorKind.bnt:4`、data 9 | 0 | 0 | 0 | 0 / 0 | 0 | 0 | 0 |
| `NetworkErrorKind` | `stdlib/NetworkErrorKind.bnt:4`、data 9 | 0 | 0 | 0 | 0 / 0 | 0 | 0 | 0 |
| `Json.ParseError` | `stdlib/Json.bnt:15`、record 1 | 0 | 0 | 0 | 0 / 0 | 0 | 0 | 0 |
| `Csv.ParseError` | `stdlib/Csv.bnt:4`、record 1 | 0 | 0 | 0 | 0 / 0 | 0 | 0 | 0 |

| 除外する型 | 理由 |
|---|---|
| `IOError`, `NetworkError` | 不透明な組み込み型であり、構成子の照合ができない |
| `String` の失敗値 | 失敗専用の宣言型ではなく基本型。文字列パターンの規則を維持 |
| `Result`, `Option` | 成功/失敗・有無の閉じた二択という設計者の指定 |
| `Json.Value`, `Ordering`, `ByteOrder`, `RoundingMode` ほか | 失敗を表す型ではない |

既存の照合は `file/resource_tests.rs:660,726` の IOErrorKind 2 件、`tests/l32_http_client.rs:331` の NetworkErrorKind 1 件、`skill/references/idioms.md:152`、`docs/design/01-spec/01-09-errors.md:96`、`docs/ja/skill/references/idioms.md:155` の IOErrorKind 各 1 件である。どれも `_` または変数を持つ。Json/Csv の ParseError を構成子で分解する match/bind は調査範囲で見つからなかった。`pure-json/Scan.bnt` などによる ParseError の構築は照合ではなく、R2 によりそのまま使える。

再現はリポジトリの根で `python3 -B docs/2026-10-15-TODO-018_027_072_251-keywords-open-types-try-or/study/failure-types.py` を実行する。出力には入力 1,195 ファイルの SHA-256、全宣言、関連語の 163 候補、6 件の照合を残した。getter・構築・型注釈とパターンを候補の前後で区別し、型名・構成子名・別名 import の別検索でも確認した。これは現在の parser/typeck を新規則へ変えて実行した結果ではなく、字句の候補と個別のソース確認による件数である。連結する Rust 入力や補間を完全に解析する調査ではないため、P1 の基準確定と D の実装後の全ターゲット検査で再確認する。

### 形式化と受け渡し

D は形式化の内側である。`Release/Coverage.lean` に、データ名から外部で有効かを返す view を渡し、shapes に新しい `Shape.future d` を加え、反例に `CoverageWitness.future d` を残す。既存の other は流用しない。shapes_cover・useful_sound・checkMatch_exhaustive_sound・irrefutable_sound・checkMatch_unreachable_sound と CoverageRuntime の接続を更新する。`CtorsComplete` は現在の構成子の完全性を要求するままにし、future を実在の構成子として仮定しない。現在の値についての健全性の結論を弱めない。

`Surface/Syntax.lean::Declarations` に一つの本体に有効な view（既定値はすべて閉じた型）を持たせ、CheckPatterns・CheckPredicates・Check/Typing のソースの match/bind の受理条件へ渡す。`Surface.Program` には関数・実装メソッドの本体ごとの view を持たせ、検査と型付けの入口で `declarationsFor` を作る。すべての宣言・本体に共通の一個の bool にはしない。`patternProgram` は view を消した現在のコアの宣言表のままとし、関数・操作・型クラスの宣言の射影が view に依存しない補題を Program の型保存へ接続する。表層の追加の条件を満たせば、従来のコアの Exhaustive が成り立つ補題を示し、`desugar_typed` と checker の健全性へ接続する。record の取得・更新と try の内部の合成照合は現行の閉じた Exhaustive を使う。`CheckPatterns` の `matchExhaustive`・`bindingExhaustive` は view 付き、`recordUpdateExhaustive`・`tryResultExhaustive`・`tryOptionExhaustive` は明示的に閉じた view を渡す。getter の合成照合も閉じた view を使う。型付き表層のソース照合と合成した内部の照合を分ける条件は、01-12 に写す。

`CoverageShow.lean` に将来の形の表示と `DataName → Option { typeName, isRecord }` の型表示表を加える。既存の ConName ごとの CoverageDisplay は構成子の表示に残す。網羅性 3 に DataName ごとの表示名・record の印を必須欄として加え、Rust と Lean の反例を同じ名前で比較する。Exchange の Syntax・Convert・CheckInput と CoverageDiff・CoverageProgramDiff に有効な指定を渡す欄を加える。Rust の `tests/coverage_export.rs`、`tests/desugar_export/{exchange,named}.rs` と周辺の出力は、型の宣言の属性と照合元から得る view を分けて渡す。標準ライブラリの型を利用者側から見た入力、同じ型を作者側から見た入力、属性しかない宣言、別名・入れ子の独立入力を含める。Rust の「網羅と判断した」という答えを Lean の受理条件にしない。

D2 は D2a〜D2c、D6 は D6a〜D6c に分ける（R10・R12）。D6a は型表を直接構成した入力で view と反例を検査し、D6b は属性未受理のまま corpus 9 を出力し、D6c で属性を受理する。

D7 は Skill の宣言抽出を改め、`@extensible` だけを `public` の前に出力する。`@builtin` など他の属性は従来どおり出さない。06-06 の生成規則と生成器の検査も同じ作業で更新する。

D の形式は corpus 9・型表 3・網羅性 3 とし、六入口へ接続する。旧形式で属性の情報を落とした入力を検査済みに数えない。旧入力では属性なしの閉じた型だけを旧来の意味で読める。通常の width/named の固定入力と版の検査・manifest は D で 9/3/3、B2 で 10/3/3 に更新する。旧版の正常な入力は互換入口の正の検査として残し、旧版に新版の欄を混ぜた入力は独立した負の検査として残す。単に版が古いことだけを拒否理由にしない。パッケージの同一性を解決する Rust の実装と属性の文字列は 07-04 の表に「対象外」と記す。

### 互換性

指定の導入は、外部の全列挙を拒否しうる破壊的変更である。指定付き data へ構成子を足す変更は外部ソースの網羅性を保てるが、同じ結果になることは保証しない。Other の再分類、構成子の削除・改名・欄の変更は別の破壊的変更として記録する。record の欄の追加の互換性は今回定めない。指定を外す場合は、その後の集合の固定の約束と到達不能の診断の変化を公開の説明に記す。

WIT の enum/variant/record の名前・数・順序・型の厳密な対応は維持する。`@extensible` を理由に未知の外部タグを読み込まない。実行時の構成子のタグ・ABI・等値性・鍵の条件を変更しない。

## 段 3 B2: try の失敗時の処置

### 文法と式の境界

```ebnf
TryExpr   = "try" Operand [ "or" TryAction ] .
TryAction = "return" | "die" [ "(" Expr ")" ] .
```

Operand は現在の「try の右の式全体」に、現在の try と同じ深さの `or return` / `or die` だけを停止点として加えた式である。パイプを含む。通常の Boolean の `or` は維持する。任意の `or Expr` を処置として解釈せず、`or fail` など将来の語も予約しない。

以下の境界の表は parser の正負の検査入力を定めるものであり、そのまま新しいコードの手本へ転載しない。解析では Pratt の式の文脈へ処置の停止条件を渡す。先に全字句から「次の or」を検索しない。括弧・引数・lambda・match・if・with・lazy・内側の try へ入るときは、それぞれの範囲へ切り替え、最も内側の try が自分の処置を先に取る。閉じ括弧、コンマ、case、then、do、end、文の終わりは外側へ残す。`or return` の return は値を取らない専用の処置である。

| 入力 | 読み方・診断 |
|---|---|
| `try r \|> convert or return` | パイプ全体を入力にする |
| `try r or flag` | 従来どおり `try (r or flag)`。失敗の処置にはしない |
| `try (choose(a or b)) or die` | 括弧内の or は Boolean |
| `try try r or return or die` | 内側が return、外側が die。文書では括弧付きで示す |
| `(try r or die) + 1` | 成功値に 1 を足す |
| `f(value: try r or return, next: value)` | この引数の try が失敗すれば囲む関数から返す。呼び出しのラベルの正否は別に検査 |
| `try r or return extra` | E0258。return の処置に値を付けられない |
| `try r or die()` / `die(a, b)` | E0258。説明は一つだけ |
| `try r or die + 1` / `try r or die or flag` | E0259。明示形を括弧で囲む |
| `die("reason")` | 単独の式としては E0201。help で try の処置を案内 |

明示形の後は、その try の外の演算子・呼び出し・型適用などを同じ式として無括弧で続けられない。ただし外側の try が待つ `or return` / `or die` は、外側の処置として読める。これを E0259 にしない。`or` の後が return/die でなければ Boolean の解析へ戻すため、不正な処置と断定して E0258 にしない。

`or return` の直後の改行も、A4 で導入した return の一般規則で文を終える（R13 の回答 B）。B6 では直前が or の場合だけを判定する例外を追加しない。次行の演算子も同じ式へ取り込まない。`or` の前後の改行は未完の式の継続とする。括弧内の通常の改行省略も維持するが、return 直後の改行には一般規則を優先する。

`die` は continues_after に入れず、処置の die の直後の物理改行も、括弧の外では次の字句の継続判定に優先して文を終える。説明の閉じ括弧の後も同じ処置の終わりとして扱う。die の `(` は同じ物理行で始まるときだけ説明として読み、改行を越えて次の文の括弧を取り込まない。説明の括弧内の継続は通常の括弧の規則を使う。

短い lambda のヘッダ行に本体を始めたら、処置と説明の閉じ括弧もその物理行に収める。継続できる位置でも行を越えれば E0254。CRLF、コメント、文字列内の改行と補間も現在の line 情報を使う。

### AST・フォーマッタ・名前解決

TryExpr は裸/明示 return/die を区別し、formatter は書き手の選択を保持する。裸の形へ警告を出さず、formatter で自動的に or return を追加しない。処置は入力の最後に ` or return`、` or die`、` or die(expr)` と印字し、入力のパイプを勝手に括弧の内外へ移さない。短いラムダの一行、コメントの順序、再解析した AST の処置・説明、二度目の整形の一致を検証する。

説明式は元の字句スコープで解決する。失敗値を暗黙の error という名前で使えるようにはしない。説明の中にも式の走査を接続し、補間・型注釈・lambda の内側を落とさない。Show と Process.exit は標準の束縛番号で参照し、局所名や import の別名で置き換わらない。読み込みの段で die を含むモジュールへ Trait と IO.Process の内部の依存を加え、通常の循環検査を通す。内部依存は ModuleInfo の別の辺に構文の Span と標準モジュールの target を保持し、明示 import とあわせて循環を検出する。現在の cycle は ImportLink.decl を AST の import の位置へ引くので、架空の decl を作る方法は使わない。内部の辺はソースの try の位置で循環を報告する。利用者の名前空間へ暗黙の import は増やさない。ソースで `uses Process.Exit` と書く場合は、通常どおり `import Benitoite.Unofficial.IO.Process` が要る。die による E0501 の help には uses の追加に加えてこの import も案内し、内部依存だけでは Process という利用者名を公開しないことを説明する。既に別名で import している場合は、その別名で uses を書くよう案内する。

die の導入は R14・R16 に従って先行検査と本番の受理を分ける。B6 は ImplicitReturn/Return だけを追加し、B10a-1 で Die と cfg(test) のクレート内部の解析補助を加えて型を検査する。B10a-2 で脱糖、B10a-3 で corpus 10 の出力を完成し、B11 で共通の parser の本番の受理を有効にする。テストのための本番フラグ・公開 API は追加しない。B8 の報告の検査は構造化した DieFailure を描画入口へ渡す lib の範囲までとし、CLI/test runner の本物の入力での報告は B11/B12 で確かめる。

### 型・エフェクト・書く位置

入力が `Result[T,E]` または `Option[T]` なら成功時の型は T である。類似した利用者型や Boolean は E0440 にする。

| 処置 | 囲む関数・lambda の戻り値 | 表示の制約 | 追加のエフェクト |
|---|---|---|---|
| 裸、`or return` | Result[U,E] または Option[U]。既存の E の一致を保つ | なし | なし |
| `or die`、`or die(message)` | 任意。Result/Option への制約を加えない | Result の E: Trait.Show、Option は不要 | Process.Exit |

Return は既存の E0441/E0442 を維持する。暗黙の E の変換は加えない。die は `Process.exit[T](1)` と同じく失敗側を任意の T として型付けし、Never を新設しない。die を使う高階関数のエフェクト引数にも Process.Exit が残る。`uses IO.All` の展開と過剰な uses の警告も既存の規則を使う。

説明は純粋な String 式であり、成功時には評価しない。直接の return・try（処置を問わない）は parser の `EscapeContext::InDieMessage` と `check_escape` で E0218 にし、`die_message` の help を追加する（R15）。resume は typeck が外側の継続を隠した文脈で E0509 にし、同名の help で説明内の禁止を案内する。両コードの説明文・parser/text を更新し、gen_skill で生成する。

内側に明示した lambda は通常の関数の境界を持ち、その内部の return を一律に拒否しない。呼び出した関数の純粋性を通常の型とエフェクトで検査する。String でなければ E0401、エフェクトがあれば新 E0511 を使う。ガードと lazy の直接の本体の try の禁止、const の式の制限を維持する。

`effects/tail.rs::escape` では裸/明示 return は従来どおり true、die は直接の Process.exit と同じく入力と説明の内部の脱出だけを走査する。`tail_expr` は die 自体を末尾 resume としない。const の式の許可判定は引き続きすべての try を拒否し、参照などを集める走査は入力と説明を両方辿る。die を「必ず抜ける文」とは判定しない。成功時は値を返し、ハンドラも操作を処理できるからである。

E の型が決まった後で die 用の Show 制約と辞書を決める。現在は特殊な Try 制約の解決と Class の解決が別なので、die の Show を登録してから Class の解決・確定表への書き出しへ進む。未確定の入力・入れ子の try・型パラメータの制約を解き直し、単に E0440 や E0705 で早期に打ち切らない。辞書がなければ E0705、型パラメータの制約がなければ E0706 とし、Show の実装または Result.mapError による変換を案内する。Show の無い型を or return で返す入力は引き続き受理する。

### 手本として示す入口と再利用する関数

実装後の手本は、終了する入口と失敗を返す関数を明示して書く。次の例は新構文の実装後に reference/Skill の例の検査で確認する設計案であり、今回は未実装の処理系で実行しない。

```bnt
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.IO.Process

function load(path: String) -> Result[String, IOError] uses File.Read
  return Result.Ok(try File.readText(path) or return)
end function

function main() -> Unit uses File.Read, Console.Write, Process.Exit
  bind text <- try load("input.txt") or die("could not read input.txt")
  Console.writeLine(text)
end function
```

load は IOError を変換せず呼び出し元へ返す。main は IOError の標準 Show で原因を残して実行を終える。main へ Process.Exit を追加することは契約の変更なので、既存例の移行でも処置と uses を一緒に確認する。伝播を教える既存の main は R1 の例外として明示 return を使える。

### 脱糖とコード生成

入力の評価は一度だけとする。Return は既存の mark/escape と二分岐へ写す。Die は入力を let に束縛し、成功側で中身を返し、失敗側で説明、原因の表示、exit の順に評価する（R3）。次はコアの動作を示す擬似記法であり、利用者に提示する Benitoite の構文ではない。

```text
let input = evaluate(operand)
match input
  success(value): return value
  failure(error):
    let message = evaluate(optionalMessage)  // 指定したときだけ
    let cause = Show[E].show(error)          // None なら固定の文字列
    call Process.exit[T](1) { exitReport = (cause, message, sourceSpan) }
```

説明と Show の純粋性は停止性を保証しない。どちらかが停止・資源不足になると、その停止を採り、まだ die の終了情報を結果へ付けない。空の説明でも原因を消さない。説明を指定しない場合と空文字列の場合は実行結果で区別する。String の原因には既存の Show[String] の引用符とエスケープを残し、説明の String はそのままの文字列とする。None の原因は `expected a value, got Option.None` とする。

報告用の引数は公開の操作の引数ではなく、既存の exit の App に付く内部の情報である。IR check は String の型、標準の exit の参照、code=1、Process.Exit を検査する。lowering・変数の置換・自由変数の列挙・レジスタ割当・liveness は原因と説明を使用する値として扱い、死んだ値として捨てない。emit は IO 命令の位置にレジスタの対応を記録し、verify は命令・範囲・その命令が Process.exit かを検査する。本番の VM も範囲と値の種類を確認し、verify の事前実行に依存しない。

参照インタプリタも同じ内部の情報から所有した文字列を作り、成功/失敗・説明の評価回数・ハンドラで処理した後の結果を VM と比較する。差分の正規化では報告の位置と文章を区別できる形にする。Lean へは情報の外部出力そのものを写さないが、説明と Show の計算、その使用と exit 呼び出しの型・効果は落とさない。

### 終了・報告・テストの実行器

Process.Exit の操作は exit 一つのまま、名前とシグネチャを保つ。言語のハンドラの探索も既存の識別を使う。処理された呼び出しは原因を結果へ残さず、その後の独立した Process.exit に持ち越さない。既定の実装へ進む時点でだけ原因・説明を所有した String に写す。Direct/Request とも呼び出しの単位に保持し、Request では RequestId の完了・取り消しとともに解放する。別のタスクへ混ぜない。

既定の die は `EndKind::Exited(1)`、`exit_code=1`、`die_failure=Some(...)` を返す。実行中の Value やエラー E 自体を RunEnd に保持しない。全タスクの取り消し、with の解放、出力の最後の転送は既存の終了経路を使う。解放・flush の失敗は既存の reports に補足として残し、採用した終了状態 1 を保つ。競合する終了・中断・処理系の不具合には既存の優先順位を適用し、採用されなかった die の情報は主な終了理由にしない。panic や組み込みからの OS の即時終了は使わない。

CLI は出力の最後の転送後に die の報告を一度だけ描画し、その後に解放・flush の失敗を reports の順で出す（R18）。文章と JSON で同じ順にし、終了状態は 1 を保つ。採用されなかった die は描画しない。文章形式の案は `error: explicit failure exit`、説明があれば `message: ...`、常に `cause: ...` とソース位置を示す。定型句は diag/codes.rs の text に置く。構造化した原因・任意の説明・位置は RunEnd の DieFailure に保持する。CLI の JSON の報告は既存の Diagnostic の形式を使い、`kind: "die"`, `code: null`、主文に固定の終了の説明、notes に説明（あれば）と原因、primary に位置を出す。これを RuntimeError や main_error へ偽装しない。ReportKind::Die とその描画を追加し、Diagnostic 全体に die 専用の任意欄を増やさない。

CLI test runner は die のテストを一件の失敗として記録し、次のテストを実行する。Failure::Exit から原因・説明・位置を描画し、捕捉した stdout/stderr へ同じ報告を二重に書かない。テストの JSON と文章の両方で原因を失わない。通常の Process.exit・Result.Error・Assert の失敗・中断・Internal の分類を維持する。die の追加エフェクトは Process.Exit だけであり、ホストの終了報告のために Console.Write は要求しない。この効果の説明を Process.Exit と Skill に明記する。

### 標準ライブラリ

IOError・NetworkError の Trait.Show の実装は、クラスのモジュールである Trait に置き、prelude の IOError.message・NetworkError.message を呼ぶ（R71、2026-10-16 の設計者の決定）。実装メソッドのパラメータ名は Show の宣言と同じ `x` とする（message の `e` へ写し替えて実装メソッドの宣言名を変えない）。二型は組み込み型であり、この配置は孤児規則を満たす。R6 により Json.ParseError・Csv.ParseError にも同様の実装を加えるが、それぞれの型のモジュール内に置く。追加の明示辺は Json→Trait、Csv→Trait だけであり、IOError・NetworkError・Trait に明示 import は置かない。Trait の明示 import か die の内部依存があるときだけ Trait を読み、die の内部依存からは IO.Process も読む。Show[String]、Result/Option の閉じた構成子、unwrapOr・mapError の意味を変えない。expect の公開の別名や失敗型の自動 Show 導出は追加しない。

### Lean の定義と証明

B2 の型・エフェクト・脱糖は形式化の内側である。`Surface/Syntax.lean::Expr` に Result/Option の die の場合を加え、入力、成功型、Show の辞書と検査済みの呼び出し、任意の説明、既存の終了操作の参照を保持する。既存の tryResult/tryOption は早期リターンの意味で維持し、裸と明示 return は同じ場合へ写す。

Typing に、入力の型、表示の純粋な String、説明の純粋な String、任意の戻り値 R、結果型 T、Process.Exit を含む効果の和を記す。入力や辞書を信頼する新しい外部仮定は足さず、既存の型付き表層の検査で条件を確認する。説明の直接の escape を禁止する parser の実装は対象外であるが、モデルの説明式は R=None・外側の継続を隠した文脈で型付けし、lambda 内に別の境界を作れることを保つ。

Desugar と `Lemmas/ReturnTry.lean` に、成功値・失敗側の説明と表示・既存の exit への展開と型保存を加える。`Scoped*`, `ShiftClean`, `SubstClean`, `Invariants`, `Extensions*`, `Lemmas/Typing.lean` の全場合を揃え、`Theorems.desugar_typed`・surface_effect_soundness と最終の checker の前提・結論を維持する。`Check`, `CheckSoundControl`, `CheckInduction`, `CheckProgramSound` は新しい構文だけで動く独立した入力でも受理/拒否を確かめる。既存の名前付き契約と実装メソッドの実名の検査も残す。

Release の既存の exit の規則・E-Exit・解放の遷移を使い、Never と別の Process.Exit 操作を新設しない。Exchange の Syntax/Convert/CheckInput と lambdaEffects の全走査、desugarDiff・builtinCheck・coverageDiff・coverageProgramDiff・surfaceCheck・surfaceCheckAll の六入口を corpus 10 へ接続する。Show の辞書の名前と引数の順も保持する。対象内の die を除外理由へ移して成功させない。

型保存が証明するのは型の対応であり、評価回数・失敗側だけの評価・実際の全タスクの制御・出力・報告の一回性は独立した実行の検査で確認する。入力一回の評価は State を持つ入力の計数で、成功時の未評価は説明/Show に純粋な停止計算を置いた対照で、説明→Show は両方が異なる停止理由を持つ対照で観測する。純粋な説明/Show の同じ値を二回計算しても通常の結果だけでは回数を区別できないため、その一回性は独立した期待コアに各計算が失敗側の let 一つだけとして現れることでも確認する。テストのために Show へ効果や計数用の公開 API を足さない。所定の定義・言明のレビューを先に行い、新しい axiom・sorry・admit・native_decide や定理の弱化でビルドを通さない。01-12 の写しと 07-04 の対応表は Lean の変更と同じ作業で更新する。

## 診断番号と文言の案

2026-10-15 の `src/diag/codes.rs` の定義行を全件検索し、E0258・E0259・E0511・E0817 が未使用であることを確認した。構文の最後は E0257（E0255 は欠番）、エフェクトの最後は E0510、属性の最後は E0816 である。既存の欠番を埋め直さない。

| コード | 主文・条件 | 位置・help の案 |
|---|---|---|
| E0201 | 普通の return の直後が NEWLINE で値がない | 改行の主位置、return の補足の位置。`return_value_line` の help で値を return と同じ物理行で書き始めるよう案内。A4 で追加し、新番号は設けない |
| 新 E0258 | `invalid failure action after 'try'` | 不正な処置または空の説明の括弧。`write 'or return', 'or die', or 'or die(message)'`。return に値を付けた場合は `the 'or return' action takes no value` |
| 新 E0259 | `parenthesize an explicit 'try' expression before continuing it` | 処置直後の演算子等。`write '(try ... or ...)' before applying another operator or call`。外側の try の処置は除く |
| 新 E0817 | `'@extensible' takes no arguments` | 属性。`remove the arguments from '@extensible'` |
| E0216 | die を名前として使った | die の字句。改名の案内。別の束縛の参照まで自動修正しない |
| E0218 / E0509 / E0254 | 説明の直接 return・try / 説明の resume / 短い lambda の物理行 | E0218 と E0509 に die_message の context/help を追加。診断の持ち主は R15 に従う |
| E0440〜E0442 | 入力の種類 / Return の戻り値の不一致 | 裸と明示 return で同じ。die に E0441/2 を出さない |
| E0401 | 説明が String でない | 説明式の位置を使う |
| 新 E0511 | `the message of 'or die' cannot perform '{effect}'` | 効果が生じる位置、説明の括弧の副位置。`use a pure String expression for the message` |
| E0501 / E0502 | 関数 / lambda で Process.Exit が許可されない | die の E0501 は uses と正しい import（または既存の別名）の両方を案内。E0502 は既存の lambda の案内を保つ |
| E0705 / E0706 | E の Show 不足 | die の位置、必要な型クラス、`implement Trait.Show or convert the error with Result.mapError` |
| E0601 / E0607 | 将来の形が残る match / bind | 上述の witness と属性の宣言の副位置、包括的なパターンの help |
| E0602 / E0608 | 分岐 / 選択肢の中の選ばれない形 | 同じ view を使い、将来の形を覆う other を拒否しない。本物の重複は維持 |
| E0801/2/3 / E0247 | 属性一覧・位置・重複・綴り | 一覧へ @extensible を追加。構成子の前は既存の E0201。余分な診断を重ねない |
| E0908 | language 宣言後の破壊的変更 | 版ごとの summary/help を複数表示する |

主文の英語の引用符は codes.rs の既存のバッククォート表記に揃える。die の終了報告は新しい E/R 番号にせず、コードなしの実行結果の失敗として描画する。新規コード四件と既存コードの help/副位置の変更、仕様上必須の診断の付け替えを CHANGELOG に記す。期待値の一括再生成で診断を変更しない。

## 最後の移行・版・公開の整合

### サンプルの移行の道具と確認表

`tools/named-arguments-migrate/extract.py` のホスト抽出と元の UTF-8 バイト位置、migrate.py のハッシュ・編集範囲・diff・再適用の検証を共通の `tools/source-migrate/` へ分ける。旧ツールの CLI と既存の検査を保つ。M1/M2 で AGENTS.md のディレクトリ表と scripts/check.sh の Python の構文検査・変更分類へ新しい道具を登録し、自己検査も通常の検査に接続する。今回の入口は `tools/try-actions-migrate/` と `examples/try_actions_inventory.rs` に置き、旧 N1 の BASE と manifest は再利用しない。

候補抽出は .bnt、Rust の通常/raw 文字列、Markdown のコードブロックに加え、インラインの実行例と複数行の例を読む。parser の AST から処置・operand の末尾を取得し、`try e |> f` の途中や短い lambda の外へ処置を挿入しない。補間内も走査する。inline の `try e` のような構文名と一般形は自動編集せず分類する。生成断片、format/concat、負の入力、型検査できない説明用断片は保留とし、生成元と実際の入力を別に確認する。

manifest と review.md は、ID・ホストのパス/行/バイト範囲・元と変更後のハッシュ・変更前後・役割（手本/検査/歴史資料/記法/生成元）・囲む関数・選ぶ処置と理由・変更する uses/戻り値/出力・保留理由・確認状態を持つ。die の採用とその契約変更は人が確認する。既定は読み取りだけ、適用には確認済み manifest のハッシュを要求し、全入力のハッシュと全範囲を検査してから書く。再適用は差分なしとする。期待値を道具で生成しない。

R1 の対象すべてを走査し、変更・既に明示・構文説明・移行前・検査として保持・歴史資料・保留の各件数を照合する。未分類と未確認の現行サンプルをゼロにする。裸の形を保つテストの一覧と変更前後の入力・観測結果を記録し、検査の数だけでなく成功/失敗・早期リターン・入れ子・型の不一致を維持する。生成 Skill は生成元から作り直す。

### 文書と生成物の更新先

| 章・文書 | 反映する内容 |
|---|---|
| 00-03・00-04 | 0.0.6 の実装済みの範囲、拡張可能な型・処置の用語 |
| 01-01・01-02 | 35 語、属性、return 直後の文末と値を同じ行で書き始める規則、try の生成規則・優先順位・改行・短い lambda・例 |
| 01-03・01-05 | パッケージの内外、data/record の網羅性・bind・到達可能性 |
| 01-06・01-07・01-08・01-09・01-11 | 型と効果、早期リターンと終了、表示順、失敗型、子タスクからの終了。裸の形の固定した意味 |
| 01-12・07-04 | Lean の各規則の写し、性質 1、Coverage、対象内外・前提と結論。上書きの追記で旧規則を残さない |
| 02-03〜02-11 | AST、内部依存、型表と制約の解決順、Coverage view、IR、コード生成・liveness、VM、報告、RunEnd・test runner |
| 03-06・03-07・03-08・03-09 と該当する標準 API の章 | Process.Exit、Show と四つの実装、ParseError/Kind の属性・互換性。実際の章の見出しと照合する |
| 06-01・06-04・06-09 | CLI の die 報告と順序、test runner の結果表と JSON、language の宣言と E0908 の複数の案内 |
| 06-03・06-06・07-01・07-03・08-04 | 整形の保持、Skill の手本、終了報告と保証、検査の対応、比較表の Benitoite の例 |
| docs/reference・docs/ja/reference | 現行の型・構文・効果と return の改行の説明、例を明示形へ。最小版の範囲を混ぜない |
| Skill SKILL.md・手書き references・docs/ja/skill | 入口は die、再利用は return、値の同じ行での書き始めとその後の複数行の例、Show・終了・その他の分岐の案内。英語を正として訳を照合 |
| `examples/gen_skill.rs` と `cli/tools/skill/generate.rs`、生成物と bundle | 属性を宣言に残す表示、grammar/diagnostics/stdlib の生成。gen_skill で作り直す |
| CHANGELOG.md | 版間の移行手順・診断・破壊の範囲を 0.0.6 の節へまとめる。リファレンスへ旧版比較節を再設置しない |

見出しを改名・追加するときは `git grep` で spec の印、gen_skill、spec-coverage、コメント・リンクを調べて同じ作業で更新する。実装前の案を docs/design の現在の仕様として書かない。新たな意味が接続された作業で対応する章と Skill 生成物を更新し、移行の最後に全例と英日を照合する。

07-04 へ加える対象外の行は、A4 の return 直後の改行と値の開始行の規則、字句の die/属性・物理行・処置の区切り、パッケージ同一性の解決、説明の直接 escape の構文検査、報告用の Rust の情報と OS 出力、VM の全タスクの取り消しと実際の解放/flush、WIT の構造照合である。型付き表層の既存 return・新しい try と網羅性の条件を対象外へ移さない。

### E0908・TODO-252・0.0.6

BreakingChange の既存の 0.0.5 の項目を保ち、0.0.6 を一件加える。0.0.6 の summary は die の予約、四つの標準失敗型への @extensible 導入、return 直後の改行継続の廃止を示す。help は die という利用者名の改名、外部の match/bind への包括的な分岐、record の制限、普通の return の値を同じ物理行で書き始める修正、明示 try の利用と裸の意味の固定、CHANGELOG の参照を含める。return の値は書き始めた後なら従来どおり複数行にできることも案内する。R13 は互換性を壊す変更として 0.0.6 の移行の一項目にする。B2 の構文追加そのものは既存の裸の形を壊さないが、同じ公開の案内に含める。

check_language は `declared < change.version <= current` の全項目を版順に選ぶ。E0908 の主文の changed は最初の該当版を保ち、各項目の版・summary を notes、対応する help を同じ順に列挙する（R17）。

まず DiagBuilder で主文と位置を作り、その後に `Diagnostic.notes` と `Diagnostic.helps`（置換なしの Help）へ文を追加する。項目ごとに `modules::text` の型板へ版と summary を渡し、BreakingChange.help の文を同じ順に加える。DiagBuilder の共有の引数を上書きしながら note/help を繰り返さない。

関係のない未来の変更を表示せず、E0908 の固定の「名前付き引数だけ」の help をなくす。codes.rs の説明文の earliest は、主文が最初の版を示し、notes/help は該当する全変更を列挙するという説明に改める。既存の一件固定の検査も、選ばれた項目の順と文を厳密に確かめる検査へ更新する。0.0.4 以下なら 0.0.5 と 0.0.6、0.0.5 なら 0.0.6、0.0.6 は受理、未来は E0907 とする。language のないファイルは現行の規則で読む。古い宣言を自動で上げない。

全段の後に Cargo.toml/Cargo.lock、現行入力の language、CHANGELOG と英日の版を一度だけ 0.0.6 へ揃える。旧・新・不正な宣言を試す負の入力は意図を保つ。依存のソースを変えた場合は package hash を計算し直し、ハッシュ不一致を試す期待値と区別する。`tests/runtime_builtins.rs` など Rust が組み立てる入力、統合テスト、tools の現在の参照解、package の fixture と文書をすべて対象一覧と照合する。

版の変更と通常入力の更新は同じ取り込み単位で行う。量が多い場合は先にパッチ・確認表を分割して用意し、版を上げた直後に通常入力が E0908 で落ちる中間状態を作らない。公開前は全体の検査と形式化の差分検査を行う。今回の文書作成では実行せず、実装後の M の作業とする。タグ・実際の公開、docs/todo の更新、改造の保管とコミットは別の指示に従う。

## 検証する契約と残る危険

主となる検査は、構文の境界を parser/formatter、網羅性を typeck と Lean の Coverage、効果と辞書を型検査と core check、評価と停止を runtime/CLI の公開の入口で観測する。test-audit の関門を記録し、同じ契約をすべての層で重ねない。別の層に固有の危険（交換形式の情報落ち、GC による報告値の消失、CLI の二重描画）は個別に確認する。

危険が大きいのは、R2 の record の保守的な制限の意味、同じ型を作者と外部の文脈で見る判定、Boolean の or と短い lambda の境界、Show の制約を登録する順、報告値の liveness と要求の寿命、ハンドラ後の理由の混入、移行する例の Process.Exit と戻り値の契約、版の変更後の統合入力と固定ハッシュである。計画ではそれぞれ独立した完了条件と段の終わりの検査に割り当てる。Lean の証明の試作はまだしていないため、作業量は見込みであり、補題を枝番で追加する余地を残す。
