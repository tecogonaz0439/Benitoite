# RS2: S2 の調べと判断の案のレビュー

- 対象: `study/file-effects.md`、`study/file-effects-questions.md`（Codex、S2）
- 前提: [README](../README.md) の「設計者の決定（2026-10-23）」（覆さない）、[S2-prompt.md の保管方針](../work-copies/README.md#f003)、[common.md の保管方針](../work-copies/README.md#f007)、docs/todo の TODO-206・TODO-276 依頼文・実行の運用記録は git の外に置き、保管していない。結果とレビューはこのアーカイブ内の記録を正とする。
- 開始版: `a0d652c0`（ブランチ `san_benito`）
- レビュー日: 2026-10-23。外部資料の確認日も 2026-10-23 である。
- 行った確認: 設計書・ソース・Lean の読み取り、既存のビルド済みの CLI（`target/debug/benitoite`、0.0.10、2026-10-21 20:32 のビルド）での小さな確認（スクリプトはリポジトリの外のスクラッチの領域に置いた）、一次資料の取得。cargo のビルド・テスト、Lean のビルドは行っていない。

## 総評

処理系の今の仕様と実装についての主な主張は、抜き取りで確かめた範囲で正しい。特に、(a) 書き足しを型表（Scheme）に入れれば Lean の定義・定理・交換形式を変えずに済むこと、(b) `main` への利用者定義のエフェクトの書き足しが E0506 で拒否されること、(c) `with` の改行の規則との衝突の分析、(d) TODO-276 の再現は、いずれも根拠と一致した。設計者の決定を覆す記述はない。

一方、書き足したエフェクトを AST の `uses` から直接読む利用側の洗い出しに漏れがある。最も重いのは `benitoite package` のエフェクトの報告（06-09）で、ここを直さないと依存の権限の変化を利用者が見落とす（原則 2）。B の結論の根拠には、`with` で必要なエフェクトを列挙する ZIO 1.x（Scala 2）の用例が抜けている。結論（`uses` を維持する）は変わらない見込みだが、設計者の見方の出どころになりうるので、問いに示すべきである。

## 確かめて正しかった主張

| 主張（file-effects.md） | 確かめた根拠 |
|---|---|
| 3.2・3.3: `main`・`@test` に利用者定義のエフェクトや `Fail` があると E0506、`main` の `Assert.Check` は E0415 | `typeck/effects/declarations.rs` の `check_entries`（76 行以降）。01-07「プログラムの入口」の 118 行 |
| 3.2: 入口と外部関数の検査が AST の `f.uses` を直接見るので、Scheme だけへの合併では足りない | `typeck/effects/declarations.rs:92`、`typeck/external.rs:41` の `!external && f.uses.is_some()` |
| 3.2: 操作の宣言の `uses` は E0510 で拒否 | `syntax/parser/effects.rs:73` |
| 3.6: 挙げた診断の番号（E0252・E0419・E0506・E0415・E0514・E0515・E0512・W0501・E0812・E0816・E0501・E0209・E0467・E0403）はすべて表にある | `diag/codes.rs` |
| 3.3: `check --report=json` の `main` の効果は契約（型）から取る | `cli/tools/test_runner/check_report.rs:138`。06-01「main の非実行の検査報告」 |
| 3.7: Lean の `FunDecl` は完成した `eff : Eff` を持ち、`Def` がそれを継承する | `formal/Benitoite/Surface/Syntax.lean:504`・`:593` |
| 3.7: 交換形式は型表から効果を書き出す | `tests/desugar_export/exchange.rs:650`・`:688`（`decl_types` の Scheme の `effects`）。AST の `uses` を読まない |
| 4.1: `case` が続かない `with` はブロックを開く | `syntax/newline.rs:112–124`、01-01「改行」の 289–290 行 |
| 4.3: formal の `uses` は `Desugar.lean:461` のコメント 1 件 | 同ファイル 461 行 |
| 5.1: 再現の出力（E0467、5 行目の E0401、8 行目の独立した E0401、終了状態 2） | 同じスクリプトを同じ CLI で再実行して一致。HEAD の `a0d652c0` は `crates/` を変えておらず、処理系のソースの最後のコミット `37e6ae3d`（10-21 06:18）より後にビルドされている。作業ツリーの未コミットの差分の有無は確かめられないので、文書の慎重な書き方は妥当 |
| 5.1: Declared の制約を Normal より先に解く | `typeck/solve.rs:1257` 以降の `solve` |
| 3.2: Property は専用の属性を持たず、`@test` から `Property.check` を呼ぶ | 06-04 の 250 行 |
| 2.3: Koka・Effekt・Unison・Flix の `with` はハンドラの導入・適用（Koka は一般の糖衣）であり、型のエフェクトは記号や型の位置で書く | 下記「外部の事実の確認」 |

## 外部の事実の確認

| 資料 | 確かめた内容 | 判定 |
|---|---|---|
| [Koka book §3.1.5](https://koka-lang.github.io/koka/doc/book.html#sec-with) | "The with statement essentially puts all statements that follow it into an anonymous function block and passes that as the last parameter." 関数の型は `() -> console ()` | 文書と一致 |
| [Effekt Tour: Effects](https://effekt-lang.org/tour/effects) | 型は `Double / { Exception }`。"Each handler consists of a `try` block, followed by one or more handlers, starting with `with`" | 一致 |
| [Unison: Abilities and ability handlers](https://www.unison-lang.org/docs/language-reference/abilities-and-ability-handlers/) | 型は `I ->{A} O`。ハンドラは `handle e with h` | 一致 |
| [Flix: Effects and Handlers](https://doc.flix.dev/effects-and-handlers.html) | 型は `Int32 \ DivByZero`、`Unit \ { Ask, Say }`。ハンドラは `run { ... } with handler DivByZero { ... }` | 一致 |
| ZIO 1.x の公式の文書（`zio/zio` の `series/1.x` ブランチ、[docs/reference/contextual/index.md](https://github.com/zio/zio/blob/series/1.x/docs/reference/contextual/index.md) 51 行、[docs/reference/core/runtime.md](https://github.com/zio/zio/blob/series/1.x/docs/reference/core/runtime.md) 112 行、[docs/reference/concurrency/promise.md](https://github.com/zio/zio/blob/series/1.x/docs/reference/concurrency/promise.md) 104 行） | `val effect: ZIO[Console with Random, Nothing, Unit]`、`type ZEnv = Clock with Console with System with Random`、`ZIO[Console with Clock, IOException, Unit]`。効果の型の環境の要件（必要なサービス）を Scala 2 の複合型の `with` で列挙する | 文書が調べていない反例（中2） |

## 指摘

### 読めば確定する誤り・漏れ

#### 重1 `benitoite package` のエフェクトの報告が、書き足したエフェクトを数えない（3.5・3.8 の漏れ）

- 箇所: file-effects.md「3.5 モジュールと公開契約、由来の保存」「3.8 処理系の変更箇所と大きさ」、file-effects-questions.md（該当する問いなし）
- 問題: 06-09 の 127 行は、`package add`・`update` が記録する依存のエフェクトを「型検査を行わず、公開のトップレベルの関数と公開の型クラスのメソッドの宣言 … の直接の `uses` … の組み込みのエフェクトの和」として集計すると定める。実装の `cli/tools/package/effects.rs:43–60` も公開宣言の AST の `function.uses` だけを読む。ファイルの宣言で `Console.Write` や `Process.Run` を加えた公開関数があっても、記録される `effects` と `update` の増減の表示（`+`・`-`）に現れない。依存の更新で権限が増えても利用者が見落とすので、原則 2（契約と権限の変更を見落とさせない）と、決定の「契約の変化は今までどおり型に現れる」の趣旨に反する。文書は 3.5 で「ファイルの宣言を追加することは、公開 API の契約を変える操作である」と述べながら、この報告を挙げていない。
- 修正案: 3.5 と 3.8 に `cli/tools/package/effects.rs` と 06-09「`benitoite package`」を加える。この報告は型検査をしないので、ファイルの宣言の組み込みのエフェクトを同じ import の表で識別し、ファイル内の公開のトップレベルの関数が一つでもあれば和へ加える、という構文上の規則を決める（trait のメソッドの宣言・型の中の関数の型には加えない、という決定との対応も書く）。06-09 の本文の改訂と、ファイルの宣言だけで `effects` が変わる場合のテストを計画に入れる。

#### 中1 Skill の生成が宣言の頭をソースの文字列で切り出すので、標準ソースでファイルの宣言を使うと参照の文書から効果が消える

- 箇所: 3.2 の `@builtin` の行（「今回、全標準ソースへ宣言を追加する必要はない」）、3.6 の末尾の段落
- 問題: `cli/tools/skill/generate.rs:500–510` の `decl_head` は、関数の頭を `f.uses` の終わり（なければ戻り値の型の終わり）までソースから切り出す。標準ソースのファイルにファイルの宣言を書くと、生成した `references/` の標準ライブラリの署名から、その効果が黙って消える。LLM が読む第一の資料なので影響が大きい。文書は「必要はない」と書くだけで、使ってよいかを決めていない。
- 修正案: 次のどちらかを問いに加える。(1) 標準ソースではファイルの宣言を使わない（検査で拒否するか、規約として書く）、(2) 使ってよいとし、生成器は合併後の契約で頭を作る。推す案は (1)（生成器の変更が要らず、標準の契約がソースの一行で読める）。

#### 中2 B の結論の根拠に、`with` でエフェクトの要件を列挙する ZIO 1.x（Scala 2）の用例がない

- 箇所: 1 節の 11 行、2.3 の表と 64 行、4.4 の表、file-effects-questions.md の Q1
- 問題: 上の「外部の事実の確認」のとおり、ZIO 1.x の公式の文書は、効果の型の環境の要件を `ZIO[Console with Clock, IOException, Unit]` と `with` で列挙する。これはエフェクト（能力）の要件を型に書く位置での `with` の用例であり、設計者の「`with` で書くものが多い」という見方の出どころになりうる。文書は 2.3 で Scala 3 の交差型 `&` に触れ「旧来の with に似た見た目をエフェクト集合の宣言と数えない」と判断だけを書き、具体的な用例と理由を示していない。文書の結論は「確認した資料からは支持できない」なので誤りではないが、反例を除いた標本で判断した形になっている。
- 修正案: 2.3 の表に ZIO 1.x（Scala 2）の行を加え、`with` が Scala 2 の複合型の演算子であり、ZIO の環境の要件の列挙はその応用であること、Scala 3 は型の `with` を `&` に置き換えたこと（文書が引く [Intersection Types](https://docs.scala-lang.org/scala3/reference/new-types/intersection-types.html) で確かめる）を書く。Benitoite の `uses` の位置に置く語として、`A with B` の並べ方（区切りが `with`）と `with A, B`（先頭の語）は形が違うことも示す。Q1 の説明に「ZIO 1.x では要件を `with` でつなぐが、語の位置と意味が違う」と一言加える。

#### 中3 derive が新しい import の領域を置く位置と、推すファイルの宣言の位置が重なる

- 箇所: 3.1 の位置の行、3.2 の `tools/derive` の行、3.8
- 問題: `tools/derive/README.md` の 268–272 行は、新しい import の領域を「モジュールの文書・ヘッダの宣言・既存の import の後、最初の通常の宣言の前」に置くと定める。推す案（import 群の後・最初の通常宣言の前にファイルの宣言を一度）を採ると、derive がファイルの宣言の後に import を挿入して、推す位置の規則に反するファイルを作りうる。文書は derive について生成した関数の効果だけを論じ、挿入位置を扱っていない。
- 修正案: 3.2 と 3.8 に、derive の import の領域の挿入位置を「既存の import の後、ファイルの宣言の前」に改めることと、その自己検査を加える。`tools/derive/README.md` の改訂も計画に入れる。

#### 中4 整形器（`fmt`）とほかの AST の利用側が変更箇所の表にない

- 箇所: 3.8 の表
- 問題: `cli/tools/formatter/roles/walk.rs`（505・573・660・939 行）は `uses` を役割ごとに整形する。新しいトップレベルの宣言を整形・保持する作業と、06-01「`fmt` のコマンドライン」の改訂が要る。ほかに `examples/try_actions_inventory.rs:21` が関数の `uses` の文字列を読み、`tools/try-actions-migrate` の候補に使う。どれも表にない。
- 修正案: 3.8 に「整形器・移行の道具の inventory」の行を加え、A の見込みのファイル数（本番 10〜20、全体 20〜40）を、重1・中1・中3 とあわせて見直す。

#### 中5 利用者が `main` の権限を読む接点への影響を、問いとして示していない

- 箇所: 3.3、file-effects-questions.md の Q5
- 問題: docs/todo の TODO-206 は、利用者が実行前に権限を確かめる主な接点（`main` の `uses`）を損なわないことを条件に挙げている。ファイルの宣言を書くと、`main` の行だけでは実行前の権限が読めなくなる。文書は `--allow-effects` の照合と JSON の報告（`aggregateEffects`）に効果が入ることだけを扱い、人間が読む表示（ソースの `main` の行、`check` の文章の出力、同梱の Skill が人間へ示す手順）の扱いを論じていない。決定は `main` を含む全関数に書き足すと定めているので、決定は覆さずに、見せ方を設計者に決めてもらう必要がある。
- 修正案: 問いを一つ加える。選択肢の例: (1) Skill の手順で、実行前に `check --report=json` の `main.effects` を人間へ示すよう案内する、(2) `main` を含むファイルのファイルの宣言に、`main` の行と並べて読むことを促す注意（診断ではなく文書）を書く、(3) `check` の文章の出力に `main` の宣言上限を一行出す（CLI の契約の追加になる）。推す案は (1)（契約を増やさず、ハーネス経由の利用を主に置く AGENTS.md「改造の設計で守ること」に合う）。

#### 中6 TODO-276 の推す案の条件が、再現の 5 行目の扱いを一意に定めていない

- 箇所: 5.3 の条件 2・3・5、受け入れ例（327 行）
- 問題: 再現の 5 行目の E0401 は、`f` 自身の注釈ではなく、別の束縛 `n` の注釈（`bind n: Integer <- f`）が `f` の型変数を `Integer` に決め、それが `Option` のパターンと食い違って出る。条件 3 は「`f` 自身の明示の注釈には根拠がある」と書くが、利用側（別の束縛の注釈や、正しく宣言された関数の引数）が誤りに由来する変数へ型を流し込んだ場合に、その型を根拠とみなすかを書いていない。条件 5 の「正しく宣言された関数の戻り値」は戻り値の側だけを扱う。実装者が「`Integer` は宣言から来たので根拠あり」と読めば、受け入れ例の「依存した Option パターンの E0401 が消え」を満たせない。rustc の方式（文書の 5.2 が引く `TyKind::Error` の伝播）では、`f` は誤りの型のまま残り、`n` の注釈も `Option` のパターンもどちらも報告しない。
- 修正案: 条件に「誤りに由来する型変数へ、利用側の注釈・引数の型・パターンが流し込んだ型は根拠としない。その変数を通じて出る不一致は報告しない」を加える。あわせて、誤りの式を直した後には両方の使用が改めて報告されるので、抑制しても誤りを失わない（原則 1 を損なわない）ことを理由に書く。

### 実行しないと分からない点

#### 軽1 例の import が今の CLI で E0321 になる

- 箇所: 3.1 の例（74 行の `import Benitoite.IO.Console`）
- 問題: 今の CLI で `import Benitoite.IO.Console` は E0321（「`Benitoite.Unofficial.IO.Console` として取り込む」の案内）になり、`import Benitoite.Unofficial.IO.Console` は受理された（既存の CLI で確かめた）。01-07 の 45 行も後者の書き方を示す。例は判断の記録や設計書へ写されやすい。
- 修正案: `import Benitoite.Unofficial.IO.Console` に直す。

#### 軽2 ファイルのスコープで解決する理由が、名前の規則から見て強すぎる

- 箇所: 3.5 の 154 行「関数の型パラメータや効果変数の名前により、同じファイルの宣言の意味が変わるのを避けるため」
- 問題: 01-03 の 112 行は、型パラメータとエフェクト変数の名前が、同じモジュールのトップレベルの大文字の名前・import の名前・prelude の名前と同じであることを禁じる。ファイルの宣言の名前が解決できるなら、関数のスコープで解決し直しても意味は変わらない。意味が変わりうるのは、ファイルのスコープで未束縛の名前（`E` など）が、ある関数のエフェクト変数に捕まる場合だけである。結論（ファイルのスコープで解決し、未束縛は診断する）は妥当である。
- 修正案: 理由を「ファイルのスコープで未束縛の名前が、関数ごとに別の型パラメータやエフェクト変数に捕まるのを防ぐため」と絞る。

#### 軽3 文書の例は独立した仮想モジュールなので、ファイルの宣言を引き継がないことを書く

- 箇所: 3.2 の表
- 問題: `cli/tools/doc_examples/source.rs:192` は、文書の例を「import や宣言を暗黙に補わない」独立した仮想モジュールとして扱う。ファイルの宣言のあるファイルの関数の文書の例は、宣言を引き継がない。今の規則と整合するが、利用者や LLM が例の中で `uses` を書き忘れやすい。
- 修正案: 3.2 の表に「文書の例（`///` の例）: 引き継がない。例の中で必要な `uses` を書く」の行を加え、Skill の説明の対象にする。

#### 軽4 用語の扱い

- 箇所: 2.2、3.7、Q2
- 問題: 「ファイル単位のエフェクトの宣言」は既存の語の組み合わせで造語ではないが、採るなら AGENTS.md「文章の規範」に従い用語集（00-04）に行を加える必要がある。文書はこれに触れていない。3.7 の「交換スキーマ」は 07-04 の書き方（「交換用の表現」「書き出し（JSON）」）と揃っていない。
- 修正案: 2.2 に「採るなら用語集へ加える」と書く。3.7 の「交換スキーマ」を 07-04 の語に揃える。

#### 軽5 見積もりの根拠の幅

- 箇所: 3.8 の 201 行、6 節
- 問題: 見込みであることは明記されており、0.0.10 の G1・Z3 の記録を根拠に挙げている点はよい。ただし重1・中1・中3・中4 の利用側が抜けた状態の見積もりなので、ファイル数と時間（A・C で 7〜15 時間）が下振れしている見込みが高い。6 節の時間は担当の作業時間であり、AGENTS.md「ユーザーへの報告」の表（検査・レビュー・受け入れを含めた見込み）には別に作り直す必要がある。
- 修正案: 漏れを加えて見積もりを更新し、根拠に「増えた利用側の数」を書く。

## 問いの一覧（file-effects-questions.md）についての所見

- 過不足: 次の三つを加える。(1) 標準ソースでファイルの宣言を使ってよいか（中1）、(2) `main` の実行前の権限を人間へどう見せるか（中5）、(3) `package` のエフェクトの報告にファイルの宣言を加える規則（重1。選択肢は少ないが、06-09 の契約の変更なので設計者の了承が要る）。
- Q1 の説明に ZIO 1.x の用例を一言加える（中2）。
- Q2（呼び名）は説明上の呼び名であり、設計者が言語の規則として決める重さはない。残すなら「用語集に加えるか」の問いとして示すほうが分かりやすい。
- Q9 は Q1 で `with` を選んだときだけ要る問いである。表の中で「Q1 で with を選んだ場合」と条件を先頭に書くと読み違えにくい。
- Q11（段の分け方）は設計者が言語の規則を決める問いではなく、計画の段で決めてよい。残すなら推す案だけを示し、判断を求めない形にしてよい。

## 指摘の一覧（重さ順）

| 重さ | 番号 | 要旨 |
|---|---|---|
| 重 | 重1 | `benitoite package` のエフェクトの報告（06-09、`cli/tools/package/effects.rs`）が AST の `uses` だけを読み、書き足しを数えない。依存の権限の増加を見落とす |
| 中 | 中1 | Skill の生成がソースの文字列で頭を切り出すので、標準ソースでファイルの宣言を使うと参照の文書から効果が消える。使ってよいかが未決 |
| 中 | 中2 | B の根拠に、`with` で要件を列挙する ZIO 1.x（Scala 2）の用例がない |
| 中 | 中3 | derive の import の領域の挿入位置が、推すファイルの宣言の位置と重なる |
| 中 | 中4 | 整形器・try-actions の inventory が変更箇所の表にない |
| 中 | 中5 | `main` の権限を人間が読む接点（TODO-206 の条件）への影響を問いにしていない |
| 中 | 中6 | TODO-276 の条件が、利用側の注釈が流し込んだ型を根拠とみなすかを定めておらず、再現の 5 行目の扱いが一意でない |
| 軽 | 軽1 | 例の `import Benitoite.IO.Console` が E0321 になる |
| 軽 | 軽2 | ファイルのスコープで解決する理由が強すぎる |
| 軽 | 軽3 | 文書の例がファイルの宣言を引き継がないことを書く |
| 軽 | 軽4 | 用語集への追加と「交換スキーマ」の語 |
| 軽 | 軽5 | 漏れを加えた見積もりの更新 |
