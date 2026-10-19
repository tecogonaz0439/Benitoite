# 相乗り項目の調査

2026-10-18、S3 の調査である。対象は docs/todo の TODO-088・260・087 の残り・259・032・257・258、基準は `fa243b049588482d8d77d24f1e832f5f480ef676`、ブランチは `mod009/design` である。0.0.8 公開後の `6b0568a3ddcc46b0a0e64504139ce286a27fd86a` から基準までの差は S1・S2 の文書だけである。元の項目は [本文の写し](../todo-items.md)、判断を求める23問は [問い](riders-questions.md) に置く。推す案は未採択であり、処理系・現行設計・テスト・formal/ を変更した記録ではない。

判断の基準は [00-01「目的と設計原則」](../../../design/00-overview/00-01-goals.md) と現在の実装である。前回の [改造の記録](../../2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/README.md) の README・decisions・plan・results・reviews と study の分担を参考にした。過去の判断や測定は当時の記録として読み、現在の受け入れ結果として引用しない。

## 調査から推す範囲

相乗り項目には、新しい型の計算やエフェクト消去を持ち込まず、既存の検査・生成・実行の仕組みを使うことを推す。doctest は明示したコードブロックを既存のテストとして実行する。Show・Order は外部の道具で通常の implement を生成する。性能の直しは、関数ごとの表、エフェクト制約の列、縮小候補の生成をそれぞれ別の作業にする。以下の zonk は、推論中の型変数を現在決まっている型へ置き換える処理の実装上の名前である。

確認できた不足の位置は次のとおりである。

| 項目 | ソースから確認できたこと | なお測っていないこと |
|---|---|---|
| 088 | doc の本文は保存するが実行しない。標準ソースには現在、三連バッククォートの例がない | 新しい例の抽出・実行の費用 |
| 260 | E0506 の案内は handle だけ。英日とも11節の先頭に制約付き操作の二段落がある | 修正後の文書例・診断の検査 |
| 087 | 生成領域の保護は再利用できるが、implement の衝突を列挙する情報とテンプレートは未実装 | Show・Order の生成器を実際に作った場合の費用 |
| 259 | 直接の Debug 出力は関数の typeParams の kind と builtin。未対応の型は別の表示関数に依存する | 新旧のハッシュの移行を実装した結果 |
| 032 | 本体ごとの密な NodeMap に全体の番号を入れ、空きも走査する。二乗の処理がある | その処理だけを取り除いた改善幅と、残る費用の割合 |
| 257 | エフェクト制約の線形探索・複製と、Fail 型の子で繰り返す zonk がある | 制約数・型の深さごとの時間の曲線 |
| 258 | 候補を全部作ってから等値で重複を除く。maxShrinks はその後の性質の呼び出しだけを数える | 遅延した生成と比較予算による改善幅 |

## TODO-088: ドキュメントコメントと例の実行

### コメントを保存して Skill へ出すまで

現行の [字句構造](../../../design/01-spec/01-01-lexical.md) と [構文](../../../design/01-spec/01-02-syntax.md) は、宣言の説明を `///`、モジュールの説明を `//!` とする。四つ以上の `/` で始まるものは普通のコメントである。宣言との結び付けや不正な位置の拒否は行うが、Markdown の本文を検査・実行しない。過去の [ADR 0125](../../2026-10-09-design-first-release/decisions/0125-doc-comments.md) はこの選択の経緯を記録しており、現在の規範の代わりにはしない。

[ast.rs](../../../../crates/benitoite/src/syntax/ast.rs) 24行の DocComment は説明全体の span と text を持つ。[parser/items.rs](../../../../crates/benitoite/src/syntax/parser/items.rs) 10〜100行の DocStore は、隣接する行をまとめ、宣言やモジュールへ付ける。結合後の text には各行の元の位置の表がない。doctest の診断を元の `///` の列へ戻すには、コメントの各行と抽出した UTF-8 バイト範囲の対応を別に保持する必要がある。結合文字列内の行番号をそのまま元のファイルの列番号にはできない。

[gen_skill.rs](../../../../crates/benitoite/examples/gen_skill.rs) は、構文の章を読み、[skill/generate.rs](../../../../crates/benitoite/src/cli/tools/skill/generate.rs) の generate_references を呼ぶ。生成部は診断の表と STDLIB を読み、module_reference（342〜463行）で各標準ソースを字句解析・構文解析する。モジュールの doc と公開宣言のシグネチャ・doc を Markdown へ写し、`skill/references/stdlib/` と実行ファイルへ埋め込む bundle を生成する。公開範囲が package の宣言はここでは除く。例の構文解析・型検査・実行は行わない。

現在の標準ソースに fenced code block（三連バッククォートで囲むブロック）は見つからなかった。生成した標準リファレンスのコードブロックの多くは、生成部が付けた宣言の一覧である。これをすべて実行対象にすると、不完全な宣言まで例として扱ってしまう。標準ソースの doc から明示した例だけを抽出し、まず代表的な関数へ例を足す必要がある。doc のある位置には構成子・フィールド・メソッド・操作も含むが、現在の生成部はトップレベルの doc を中心に出す。実行対象の収集と、生成文書へ載せる対象は別途一致を確認する。

### 現在ある三つの文書・期待の検査

| 検査 | 入力と確かめること | doctest に使う場合の注意 |
|---|---|---|
| [golden.rs](../../../../crates/benitoite/tests/golden.rs) | testdata の .bnt と .mode・.exit・.stdout・.stderr・.diag.json 等を読む。CLI の出力・終了状態・診断を期待と照合し、成功例のコア検査等も行う | CLI から元のコメント位置を含む失敗報告までを確かめる境界に使える |
| [reference_examples.rs](../../../../crates/benitoite/tests/reference_examples.rs)、[skill_examples.rs](../../../../crates/benitoite/tests/skill_examples.rs) | 英語リファレンスと Skill の手書き4文書を [doc_examples](../../../../crates/benitoite/tests/doc_examples/mod.rs) で抽出し、一時ファイルから CLI を呼ぶ | 生成された stdlib の文書は入力一覧にない。日本語訳もこの検査の入力ではない |
| [skill_docs.rs](../../../../crates/benitoite/tests/skill_docs.rs) | generate_references の出力と保存した文書・bundle の一致、公開名や生成物の形を確かめる | 生成物が古くないことと、説明の例が動くことは別の契約である |

doc_examples の形式は、`benitoite` と続く `output`、`benitoite check`、`benitoite test`、`benitoite error` と続く `diagnostic` である。`files` で補助モジュールを用意できる。実行時は標準出力・標準エラーを捕らえ、標準入力を空にする。これらは golden と共通する観察対象を扱うが、golden.rs の同じ実行関数を呼ぶ実装ではない。新しい抽出規則を三か所へ写すことは避け、処理系で使える抽出部を文書検査からも呼ぶ案を推す。

### benitoite test の発見・準備・実行

[test_runner/mod.rs](../../../../crates/benitoite/src/cli/tools/test_runner/mod.rs) の select_test_entries（240行以降）は、指定したファイル、またはディレクトリ配下の .bnt を入口とする。下位の別パッケージやシンボリックリンク等の扱いは [06-04](../../../design/06-tooling/06-04-test-runner.md) に従う。collect_tests（304行以降）が集めるのは入口のトップレベルの `@test` 関数だけであり、import したモジュールのテストは実行しない。

準備では入口を検査し、そのファイルのテストをコンパイルして共有する。各テストは別のヒープ・タスク・リソースで順に実行する。`test --check` は実行しない。`--allow-effects` があれば全入口を先に準備し、各テストの宣言上限が許可指定に含まれるかを照合してから、一つ目の実行を始める。これは静的な上限の照合であり、実際のファイルや通信先の実行時の制限ではない。

doctest を追加する際も、例の発見を通常の検査・実行・検査報告・許可照合で共通にする必要がある。例えば後ろの例が `File.Write` を要する場合、先の例を実行した後で拒否する形にはしない。import 先の例を再帰的に実行すると、依存の更新で実行対象が増えるため、明示した入口のコメントだけを集める案を推す。

### Rust・Python・Elixir の一次資料

2026-10-18 に以下の公式文書を確認した。言語ごとの事実と Benitoite への提案を分ける。

| 言語 | 例の書き方と実行 | この調査で参考にする点 |
|---|---|---|
| Rust | Markdown のコードブロックを抽出してコンパイル・実行する。必要に応じて main で囲み、assert で結果を確認する。`no_run`・`compile_fail`・`ignore`、表示だけ隠す行を指定できる | 実行する例と検査だけの例を明示する。[rustdoc book](https://doc.rust-lang.org/rustdoc/write-documentation/documentation-tests.html) |
| Python | docstring の `>>>` と継続行 `...`、直後の期待出力を照合する。testmod 等から実行する。既定では説明ごとにモジュールの大域の名前表を浅く複製し、同じ説明内では前の例の名前を使える | 出力の文字列照合と、例の間で共有する状態の範囲を区別する。[Python doctest](https://docs.python.org/3/library/doctest.html) |
| Elixir | `@doc`・`@moduledoc` の `iex>` と継続行 `...>` の直後に期待値を書く。ExUnit の `doctest Module` で取り込む。標準出力は自動で捕らえず、サンドボックス内でも実行しないと明記する | 対話の表示を値の照合と混同せず、例の実行から隔離を推論しない。[ExUnit.DocTest](https://ex-unit.hexdocs.pm/ExUnit.DocTest.html) |

Benitoite は既存の Markdown の印と Assert を使えるため、対話プロンプトの新しい文法を増やす必要はない。最初は完全なプログラムまたは `@test` 関数を明記し、宣言・import・uses を隠さない案を推す。例えば次は提案するコメント内の例である。現行 doctest の構文として受理された例ではない。

````text
/// ```benitoite test
/// @test
/// function lengthExample() -> Unit uses Assert.Check
///   Assert.equal(actual: List.length([1, 2]), expected: 2)
/// end function
/// ```
````

`benitoite check` は検査だけ、`benitoite error` は指定した診断コードの拒否、通常の `benitoite` は main と output の照合、と既存の意味を揃える。`text` と無印のブロックは実行しない。失敗を期待する例は構文・型の診断に限り、実行時エラーや強制終了を成功条件とする新しい印は初版へ加えない。

実行は `test --doc` で明示的に有効にし、通常の @test に加えて選ぶ案である。例は別の仮想モジュールとして owner を通常の import で使い、公開 API だけを参照する。元のファイルの import や私有の宣言を暗黙にコピーしない。これにより A・C の「作り方を外へ見せない型」の例も利用者と同じ公開境界で検査できる。初版の `files` による追加ファイルは既存のリポジトリ文書検査だけに残し、コメント内では要求しない。

実行時の扱いは通常の @test と揃える。Assert の処理と出力の捕捉を再利用し、未処理の利用者エフェクト・Fail は拒否する。IO の差し替えには例の中で普通の handle を書く。暗黙の模擬 IO は設けない。`--allow-effects` の対象へ全実行例を含め、上限の指定がない場合は通常のテストと同じ OS の権限で動くと説明する。例の抽出や非実行の検査を実行時の権限管理と呼ばない。

標準ライブラリの例は処理系の検査へ含める案を推す。ただし利用者が test を呼ぶたびに標準の例を走らせるのではなく、STDLIB の元の doc を同じ抽出部へ渡す統合テストを用意する。List・Option・Result・String の純粋な例、Failure.toResult の例、Property の小さな例、IO を handle で差し替える例を起点とする。列挙数・実行数・検査だけの数・拒否例の数を記録し、対象があるのに成功0件で通さない。

## TODO-260: E0506 の案内と11節の順序

[diag/codes.rs](../../../../crates/benitoite/src/diag/codes.rs) 845〜847行は、E0506 の本文を `` `{function}` does not handle the effect `{effect}` ``、help の handle を `` handle `{effect}` with `handle ... with` inside `{function}` `` と定める。[effects/declarations.rs](../../../../crates/benitoite/src/typeck/effects/declarations.rs) 80〜118行の check_entries は、main と @test の uses 内の利用者エフェクトを同じ経路で拒否する。標準の Failure.Fail も名前解決後はこの経路に入る。

今回、既存の release バイナリで main の `check --diagnostics=json` と @test の `test --check --diagnostics=json` を確かめた。どちらも終了2、E0506、handle だけの案内であった。表示する effect は `Failure.Fail` であり、uses の `[String]` の範囲は primary に含む。型の引数を案内文の変更だけのために復元する必要はない。

推す修正は、標準 Fail の解決済み ID と一致したときだけ、toResult の help を追加することである。提案する文は `or convert the failure with Failure.toResult inside {function}` とし、必要な import は別の短い説明で示す。一般の Log の E0506 には追加しない。main の uses に Fail を残したまま包んでも拒否は消えないので、toResult で受け止め、入口の uses から未処理の Fail を除くことまで例で示す。

現在の golden の E0506 は [c11-unhandled-main.diag.json](../../../../crates/benitoite/testdata/effects/c11-unhandled-main.diag.json) の Log の期待である。これは共通の案内を一律に変えない場合は保持できる。Fail の main と @test の案内を確かめる行を CLI の境界に置き、対処後の成功例と対応させる。診断表を変えたら gen_skill の diagnostics の生成物も同じ変更で更新し、skill_docs で一致を確認する。

[英語の11節](../../../reference/benitoite.md#11-effect-handlers) は987行から始まり、制約付き操作の二段落が989〜991行、effect と handle の導入が993行、Log の例と output が995〜1026行にある。[日本語の11節](../../../ja/reference/benitoite.md#11-エフェクトハンドラ) は959行から同じ順に並ぶ。推す順は「effect と handle の導入 → Log の例と出力 → 制約付き操作の二段落 → 組み込みの操作と名前の修飾」である。段落の移動だけなら意味とコードは保てる。今回の項目が英日両方を対象とするので、通常のリリース時の訳し直しを待たず同じ作業で揃える。

## TODO-087 の残り: Show・Order の生成

### 再利用できる部分と足りない部分

[tools/derive/README.md](../../../../tools/derive/README.md) の現行手順は preview → diff と manifest の確認 → ハッシュを指定した apply → 通常の check/test → derive check である。Rust の [derive_inventory](../../../../crates/benitoite/examples/derive_inventory/README.md) が通常の宣言収集を使って型・可視性・依存を渡し、Python は型構文を独自に読み直さない。本体は検査しないため、読み取り成功だけでは生成後のプログラムの成功を意味しない。

[derive.py](../../../../tools/derive/derive.py) の structure（147行以降）は宣言と推移的なレコード依存・カスタム関数の署名・設定をハッシュにする。管理領域の元の bytes と生成後の整形した bytes を照合し、手書きへの上書きや古い manifest の適用を拒否する。check は再生成した記録と本文の両方を比べ、ファイルを書かない。この管理は通常の implement にも使える。

一方、現在の生成対象は JSON と Property の通常の関数だけである。設定の許可キーは [config.rs](../../../../crates/benitoite/examples/derive_inventory/config.rs) 110行以降で固定され、Show・Order の指定は拒否される。生成部にも対応するテンプレートはない。既存の名前の衝突検査だけでは、名前を持たない implement の「同じクラスと対象型」の重なりを検出できない。inventory へ実装の解決済みクラス・対象型・宣言位置を足し、管理領域外の実装と衝突する場合に preview の前に拒否する必要がある。

### 最初の生成対象と意味

最初は非循環で型パラメータのないレコードを対象とし、Show と Order を別々に指定できる外部生成を推す。生成先は型を定義したモジュール内に置く。クラス・メソッド・辞書の規則は既存のものを使い、`@derive`、汎用の型の構造、特別な VM 命令を加えない。JSON・Property と同じ領域へまとめられるが、選ばなかった生成を必須にはしない。

[Trait.bnt](../../../../crates/benitoite/src/prelude/stdlib/Trait.bnt) の Show.show の引数名は x、Order.compare は x・y、戻り値は Ordering である。生成する実装もこの契約名を保つ。Show は `Person(name: "Ada", age: 7)` のように、型名・フィールド名・宣言順と、各フィールドの Show を使う案である。文字列を引用する既存の Show を再利用し、手でエスケープしない。情報を隠したい型に Show を無条件で付けず、明示した生成要求を中身の表示を許す判断として扱う。

Order は宣言順の辞書式比較（lexicographic order）とする案である。最初に Equal 以外となったフィールドの結果を返し、全部 Equal なら Equal を返す。比較結果を組み込みの `=` と同じ意味だとは説明しない。既存の Order[Float] は NaN も含む全順序を定めており、`key` 制約とは別である。Show・Order を生成したことによって equality や key が実装されるわけでもない。

生成前には各フィールドについて要求するクラスの実装を確認する。依存するレコードも生成対象なら順にそろえ、それ以外は手書きの実装を使う。対応する辞書がない型は具体的なフィールドの位置とともに拒否する。空レコードも表示と Equal の意味を決め、非公開・public(package)・public の型と別モジュールの依存の可視性を確認する。出力した関数が型検査を通ることと、期待した文字列・比較順になることの双方を確認する。

### 再帰・型パラメータ・専用の実行

現在、inventory は再帰するレコードを参照の形で表せるが、生成の structure は循環を拒否する。対象の型パラメータも inventory で拒否する。単に Python の循環拒否を外すだけでは対応にならない。

| 拡張 | 必要になる設計 | 今回の推す扱い |
|---|---|---|
| 再帰する Show・Order | 相互依存の実装と再帰する呼び出し、有限値でも深い入力での費用、同じクラスの辞書を作る循環と実行の再帰の区別 | 初版の自動生成には含めず、手書きを保つ |
| 型パラメータのある Show・Order | `implement[T: Trait.Show] ...` の必要最小限の制約、型引数の対応、入れ子や高カインド型の扱い、署名のハッシュ | 初版は含めず、再帰とは別に判断する |
| 再帰する Gen/Shrinker | size の減少と停止、相互再帰の基底の選択、縮小で入力を大きくしない条件 | 手書きを保つ。新しい縮小 API と同時に自動化まで広げない |
| 型パラメータのある Gen/Shrinker | 型引数の生成器・縮小器を明示して受け渡す API、型引数付き依存の生成 | 手書きを保つ |
| 専用の Property 実行 | 種の CLI 指定と優先順位、構造化した反例の形式、既存 @test との報告の対応 | 通常の @test と formatFailure を保つ |

再帰・多相の Benitoite の通常の宣言まで禁止する提案ではない。自動生成の範囲の制限である。これらは採る場合に追加で各2〜4作業程度を要し、後述の初版の見積もりへは含めていない。

## TODO-259: inventory の明示的な JSON と移行

### Debug と表示への依存の位置

直接の Debug の出力は [derive_inventory/mod.rs](../../../../crates/benitoite/examples/derive_inventory/mod.rs) 245行にある。関数の `signature.typeParams[].kind` を `format!("{:?}", p.kind)`、`builtin` を `format!("{b:?}")` で書き、例えば `Value`・`Ctor { arity: 1 }`・`Equality` になる。237行の組み込みエフェクトの名前の format は公開名を連結するものであり、Debug ではない。[text.rs](../../../../crates/benitoite/examples/derive_inventory/text.rs) 60行の `{d:?}` はエラー時の stderr の文であり、成功した inventory の JSON とは分ける。

型の木の未対応部分は同ファイル148行で `tag: unsupported` と `resolved: self.show(...)` を出す。show（99〜113行）は Ty.show に解決済みの名前を渡す。これは直接の Debug ではないが、内部の表示の変更で意味のハッシュが変わる別の依存である。113行以降の対応済みの builtin・list・map・option・record は既に明示したタグを持つ。245行の Debug 出力の置換と、こちらの表示への依存の解消は、別の作業として確認する。

ハッシュへの影響にも範囲がある。`semantic`（derive.py 59〜66行）が除くのは span・typeSpan・original・package であり、kind・builtin と unsupported.resolved は残る。関数の署名は設定で選んだ customFunctions の経路で customSignaturesSha256 に入る。全 functions の出力が変わっただけで、すべてのレコードの declarationSha256 が変わるわけではない。現在のカスタム関数は単相を要求するので、Debug を含む型パラメータの多くは生成の対象外である。将来の多相生成へ広げる前に境界を直す理由は、それでも残る。

### 版2の契約の案

inventory の出力を版2とし、内部の列挙名を使わずに値ごとの対応をコードで書く。例えば次の形である。設定の version、inventory の version、生成記録の version は別の契約として扱う。

```json
{
  "version": 2,
  "typeParams": [
    {"name": "T", "kind": {"tag": "value"}, "builtin": "equality"},
    {"name": "F", "kind": {"tag": "constructor", "arity": 2}, "builtin": null}
  ],
  "type": {
    "tag": "application",
    "head": {"tag": "named", "name": "Benitoite.List.List"},
    "arguments": [{"tag": "parameter", "index": 0}]
  }
}
```

これは欄の例であり、既存の target 全体を省略せずに置き換える完成した schema ではない。実装計画では builtin の equality・key・ordered、名前付き型の適用、型パラメータ、型構成子パラメータの適用、関数の契約名・引数・戻り値・エフェクトをすべて列挙する。型の別名は現在どおり解決後の同一性を使う。生の BindingId や BuiltinTy の番号は保存しない。宣言に来ない剛な局所型は拒否し、未知のタグを Debug へ逃がさない。

表示用の resolved と元の original・span は説明用の欄に分け、構造のハッシュには明示した型の木だけを使う。対応していない生成対象でも木は表現し、その型で生成できるかはテンプレートが判定する。これにより Show・Order の対象を調べるために表示文字列を解析せずに済む。

### 生成記録と manifest の移行

生成記録は版2にし、inventoryVersion と構造のハッシュの版も明記する案を推す。GENERATOR_VERSION を上げ、旧記録を新しい値へ書き換えるだけの移行は行わない。旧版の出力ハッシュで管理領域の本文が変更されていないことを確認した後、新しい inventory から preview を作る。出力が同じでも記録の版・ハッシュだけが変わることを表示し、diff と新しい記録の確認を経て apply する。

旧 manifest と receipt は、旧バイナリ・道具・入力のハッシュに結び付いている。新版でそのまま再適用する互換経路は設けない。旧版の未完の適用は旧版で復旧してから、新しい preview を作る。新版の check は旧記録を黙って更新せず、移行が必要であることと手順を報告する。同梱の People の例・設定例・inventory の契約書・derive の説明も同じ切り替えで照合する。

## TODO-032: 関数数に対する二乗の費用

### 全体の番号と本体ごとの表

二乗の処理があることは現在のソースから確認できる。[base/mod.rs](../../../../crates/benitoite/src/base/mod.rs) 83〜87行で IdGen.node は番号を単調に増やし、[parser/mod.rs](../../../../crates/benitoite/src/syntax/parser/mod.rs) 98〜116行の parse は、呼び出し元の IdGen を引き継いで返す。関数の境界で節番号を0へ戻す実装ではない。

これに対して [typeck/generate.rs](../../../../crates/benitoite/src/typeck/generate.rs) 93〜146行の check_function は、関数ごとに Body::new を作る。[context.rs](../../../../crates/benitoite/src/typeck/context.rs) 51〜140行の Body は expr_types・source_effects 等の NodeMap を空から作り、record_type（313行）と式の検査で全体の NodeId をそのまま入れる。NodeMap::insert（base/mod.rs 128〜139行）は、番号 i の最初の挿入でも slots を i+1 個まで None で初期化する。

NodeMap::iter（142〜147行）は全 slots を走査して Some の要素だけを返す。そのため check_type_limits（context.rs 409行以降）と finish（449行以降）では、関数が使わない先行部分の None まで繰り返し読む。空のままの補助表は伸びないが、一つでも書いた表にはこの費用が生じる。Vec の破棄でも、要素の型に破棄処理が必要なら同じ空き部分を含む領域を処理する。

各関数の節数を一定の m、関数数を F とすると、j 番目の本体の表の長さは概ね m×j になる。初期化と走査の総量は `m × (1 + 2 + … + F)`、すなわち O(mF²) である。これは累積の処理量であり、全本体の表を同時に保持して O(F²) の常駐メモリを使うという主張ではない。Body.locals の BindingMap にも全体の束縛番号を添字にする同形の問題があり、引数・局所束縛を持つ入力では合わせて調べる必要がある。

既存の [本測定の所見2](../../../../tools/bench/results/2026-10-18-1c545d8f5c5d.md#所見) は、finish 19.6%、check_type_limits 18.1%、NodeMap の伸長、Body の解放等を観察している。今回のソース調査でその見立ての機構を確認できた。ただし宣言収集や名前解決など他の費用は残る。修正前後の比較をしていないため、check 全体の時間の何割をこの原因だけで説明できるかは未確定である。

### 今回の短い計測

既存の `target/release/benitoite` を使い、一つの .bnt に引数なしの関数を並べた。関数 fI は整数 I を返し、最後に Unit を返す main を置く。各規模で最初の一回を準備として除き、続く三回の最小値を比較した。値は子プロセスの起動から終了までの実時間であり、型検査だけの時間ではない。全24回が終了0であった。

| 追加した関数数 | bytes | 標本1（秒） | 標本2（秒） | 標本3（秒） | 最小値（秒） | 前の非零規模に対する比 |
|---:|---:|---:|---:|---:|---:|---:|
| 0 | 49 | 0.011327 | 0.011414 | 0.013742 | 0.011327 | — |
| 1,250 | 66,579 | 0.031781 | 0.029048 | 0.029250 | 0.029048 | — |
| 2,500 | 135,329 | 0.061986 | 0.060256 | 0.060870 | 0.060256 | 2.07 |
| 5,000 | 272,829 | 0.194924 | 0.193697 | 0.198274 | 0.193697 | 3.21 |
| 10,000 | 547,829 | 0.676756 | 0.682528 | 0.682962 | 0.676756 | 3.49 |
| 20,000 | 1,117,829 | 2.639502 | 2.633717 | 2.637281 | 2.633717 | 3.89 |

環境は macOS-27.0.1-arm64-arm-64bit、バイナリの表示は Benitoite 0.0.8 / Unicode 17.0.0、SHA-256 は `5499a27cb83f74e74ee9b373ff4c140843819f6d26db1f4546b69ae2e4df6dfb` である。バイナリは再ビルドしておらず、正確なビルド元コミットはこの計測だけからは確定しない。電源・ほかのアプリの状態は調整していない参考値である。計測中には別のビルド・検査・調査コマンドを起動しなかった。新しい CPU プロファイルは取っていない。

全標本・準備回・入力の SHA-256 は [check-scaling.json](../s3/check-scaling.json) に保存した。再現には次の生成と計時を使える。これは将来の本測定の代用にはしない。

```python
from pathlib import Path
import subprocess, tempfile, time

binary = Path("target/release/benitoite").resolve()
with tempfile.TemporaryDirectory(prefix="benitoite-s3-scaling-") as tmp:
    for n in [0, 1250, 2500, 5000, 10000, 20000]:
        source = "".join(
            f"function f{i}() -> Integer\n  return {i}\nend function\n"
            for i in range(n)
        ) + "function main() -> Unit\n  return ()\nend function\n"
        path = Path(tmp) / "main.bnt"
        path.write_text(source)
        samples = []
        for attempt in range(4):
            start = time.perf_counter()
            result = subprocess.run([str(binary), "check", str(path)], capture_output=True)
            elapsed = time.perf_counter() - start
            assert result.returncode == 0, result.stderr.decode()
            samples.append(elapsed)
        print(n, samples[0], samples[1:], min(samples[1:]))
```

### 修正案の比較と範囲

| 案 | 効果と費用 | 判断案 |
|---|---|---|
| 本体ごとに番号を詰める | 局所番号と全体番号の対応を持ち、小さな密な表を使う。局所から出力へ移す全箇所と、ラムダ・節の所属を直す必要がある | 長期の候補。構文木（abstract syntax tree、AST）全体の NodeId を付け直す変更には広げない |
| 本体内だけ疎な表にする | 疎な表（sparse map）は実在する番号だけを保存する表である。BTreeMap 等で実在する要素だけを保持・走査する。全体の出力の NodeMap は保てる。局所表の get/insert は O(log m) になる | 最初に推す。番号順の走査を保ち、局所の BindingMap も対象に含める |
| 表を再利用する | 全体番号の表を一回だけ伸ばし、書いた番号の一覧や世代で初期化・走査・破棄を限る | 確保回数を減らせるが、所有する型・効果の残留と消し忘れの検査が要る |

容量だけ再利用して毎回全域を clear・走査する案では、二乗の走査が残る。NodeMap 自体をすべて疎にすると、プログラム全体の密な表の読者にも費用が及ぶため、最初は Body 内の用途に限る。どの案もソース位置と外へ渡す NodeId を保つ。

今回の目標は「小さな関数を多数並べた入力」の費用である。TODO-032 に併記される、多列 match の指数的な費用、リテラルの分岐、長い let に対するコード生成、テスト用の ir/check の Env の複製は、原因と実行段が異なる。この版の完了条件へ一括で含めず、残る問題として明記する。TODO-191 の Integer の網羅も対象にしない。

## TODO-257: 制約の列と Fail の型の確定

### 現在の費用の位置

[traits/solve.rs](../../../../crates/benitoite/src/typeck/traits/solve.rs) 392行以降の solve_classes は、制約を take して未確定の使用を保留し、最終の辞書を使用箇所ごとにまとめる。resolve_normalized（112行以降）は親で正規化した型の子を再度 zonk しない。既にあるこの改善を新しい作業の成果として数えない。上位クラスへの path は要求ごとに幅優先で探し、候補の制約は宣言順に走査する。これは別の探索・記憶の候補である。

TODO の「列全体の複製」に直接対応する箇所は [typeck/solve.rs](../../../../crates/benitoite/src/typeck/solve.rs) にある。equal_function_effects（707〜726行）は両向きのエフェクト制約を作るたび、effects.contains で既存の列を線形探索する。propagate_effects（1793行以降）は Fail を含む場合、変化がなくなるまで effects.clone した列を繰り返して処理する。前者は制約数 C に対し O(C²) 回の要素比較になりうる。後者は反復回数 P を含めて O(PC) 個の複製に、各型と効果の処理費用が加わる。solve_classes 全体が毎回列を clone する、という説明にはしない。

同じ solve.rs の finalize_failure_type（476〜504行）は最初に zonk(t) を行い、子にも同じ関数を呼ぶ。深さ d の一列の型なら、既に展開した残りの部分木を各段で再び展開・複製し、合計 O(d²) の節の処理になりうる。通常の型の確定や関数の潜在効果の中にも移るため、単に外側の Fail を一つ記憶すればすべて済むとは限らない。

[前回の短い計測](../../2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/p1/typeck-performance.md) は、一つの本体の高階呼び出し900個で型検査が24.279msから47.784ms、Failure の import ありで60.107msとなったと記録する。三規模だけであり、深い Fail 型や大量のクラス制約の単独の測定ではない。今回、257の新しい時間の計測はしていない。

### 直す案と意味を保つ条件

まず、Fail 型を一度 zonk し、その正規化済みの木を辿る確定関数へ分ける。未知の型・エラー型・型構成子の既定値、契約名、関数の潜在効果と Fail の内部まで現在と同じ出力を保つ。型変数の結び付きが変わる途中のキャッシュは、更新で古くなる。初版では確定の一回の呼び出し内の結果だけを再利用し、全検査にまたがる記憶を避ける。

次に、エフェクト制約の列を保持したまま重複の索引を足し、影響する型・行の変化で必要な制約だけを処理する待ち行列（worklist）を検討する。診断の reason・型の対を無視した同一視では、異なる使用箇所の診断を落とすおそれがある。初回の登録順、再処理順、使用ごとの辞書の番号、単一 Fail・NoFail・剛な型の脱出の拒否を保つ必要がある。上位クラスの path の記憶も宣言集合を固定した一回の検査内に限る。

待ち行列で失敗型を結び付ける順序を変える部分は、形式化した意味を変えないことの確認が必要である。「性能の修正だから全比較の入力が同じ」として過去の check-formal の成功をそのまま引用しない。型とエフェクトの規則を変更する必要が判明した場合は、処理系の修正より先に Lean の段へ戻す。

### 測り方の案

| 入力群 | 変える量 | 分けて確認すること |
|---|---|---|
| 高階 apply へ純粋なラムダを渡す一つの本体 | 呼び出し100・300・900・1,800、Failure の import の有無 | 032の関数数を固定し、エフェクト制約の増え方を測る |
| Show・Order と複数の上位クラスを使う関数 | 使用100・300・900、型の種類、上位クラスの段数 | 辞書の探索、同じ要求の反復、複数の辞書の番号 |
| Fail[Option[…String…]] 等 | 許容される深さ8・16・32・64、型の幅は固定 | zonk と確定を分ける。型の上限に拒否された時間を成功の時間へ混ぜない |
| Fail を持つ高階の関数型と受け止める境界 | 型の深さと呼び出し数を別々に変える | 潜在効果・NoFail・再 raise の確定も測る |

CLI check の実時間と、読み込み・字句/構文解析・名前解決・型検査の段別の時間を別々に取る。型検査だけを測る補助では同じ解析済み入力を使い、同じ出力の型・エフェクト・診断になることを先に確かめる。定数項だけの入力、成功と意図した拒否、Failure の import だけの場合を対照にする。規模を増やして制限に当たったらその件数と診断を別に報告する。

## TODO-258: 縮小候補を作る量と比較する量

### maxShrinks より前に行う処理

[Test/Property.bnt](../../../../crates/benitoite/src/prelude/stdlib/Test/Property.bnt) 14〜16行の Shrinker は `function(value: T) -> List[T]` を持つ。237〜242行の shrinkList は deleteWidths と replaceElements で候補を全部作り、271〜275行の unique で重複を除いて返す。幅を半分ずつにする削除候補は既に実装されている。TODO の候補案にある「半分ずつ消す候補を先に出す」は、初めて追加する機能としては数えない。

長さ n、要素ごとの候補数 s なら、削除と置換の候補数 k は概ね O(n log n + ns) になる。unique は候補を元の値と比較し、既出の候補を List.contains で線形探索する。異なる候補が多い場合は O(k²) 回の等値比較となり、一回のリスト比較も最悪 O(n) である。List.append で候補の列を伸ばす費用や、候補ごとの take/drop/concatenate も加わる。候補数を減らしたことと、比較一回の費用を減らしたことは区別する。

reduce（357行以降）は候補の関数を呼び、その List が完成してから tryCandidates へ渡す。maxShrinks を増やすのは tryCandidates の性質の呼び出しの直前である。0なら候補の関数も呼ばないが、1以上なら最初の一回で大量の候補と比較を作れる。完成後のリストを take(maxShrinks) しても、この費用は減らない。shrinkOption・String・Map にも unique を通る経路がある。

前回の [RV4 の中1](../../2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/reviews/RV4.md) は debug の長さ24で0.66秒、88で11.4秒を記録した。今回これを release の性能や新しい実測値としては扱わない。

### 等値の制約と重複を除く方法

| 方法 | 必要な契約と制限 |
|---|---|
| 等値で既出の候補と比較する | 現在の equality を保てるが比較回数の上限が要る。一回の構造比較の長さは別の費用である |
| Set/Map を使う | [Set.bnt](../../../../crates/benitoite/src/prelude/stdlib/Set.bnt) は key を要求する。key は Float・Float32 を含む型を除くため、equality の縮小器を一律に置換できない |
| Trait.Order で整列して除く | Order の Equal と組み込みの `=` は同一とは限らない。NaN、利用者が書く辞書、最初の出現順を扱う契約が別に要る |
| ハッシュで候補をまとめる | 同じハッシュの候補はなお等値で確かめる必要がある。[Hash.bnt](../../../../crates/benitoite/src/prelude/stdlib/Hash.bnt) は Bytes の SHA-256 だけで、任意の equality 型の構造ハッシュ API はない。Show の文字列を鍵にすると異なる値を落としうる |

最初は equality を保つ案を推す。Property.check 自体は equality を要求せず、手書きの縮小器にも使える現在の分離を保つ。key 向けの高速な別関数を足す案は、必要性を測った後に選べる。

### 遅延した生成と予算の案

候補を少しずつ返す、純粋な関数の列へ Shrinker を変える案を推す。例えば Done、候補と次を作る関数を持つ Yield、候補を返さず次の処理へ進む Skip の三形を使う。これは提案するライブラリのデータ型であり、VM の新しい遅延機構や State は要らない。削除幅・位置・要素の置換の続きを関数に保持し、候補リスト全体を先に組み立てない。

組み込みの重複除去も一度に全部行わず、等値比較一回を Skip の一段として扱う。残りの処理量の予算が尽きたら、次の生成・比較を始めない。候補を作る一段と比較一回は、対象の値の長さに応じた仕事を含みうるため、これで CPU 時間やメモリ全体の一定上限を保証したとはしない。利用者の任意のコールバック内の無限ループも、この予算だけでは止められない。

予算を maxShrinks へまとめる案では、従来の「性質を何回呼んだか」という shrinks と、生成・比較の回数が一致しなくなる。推す案は maxShrinks の意味を保ち、別の maxShrinkWork と消費した shrinkWork を Config・Counterexample に追加することである。work は候補生成の一段・比較一回・性質の呼び出しを各1として数える。生成段数に比較段を含めた場合は二重に数えず、公開する定義を一つに固定する。どちらかの予算が尽きたら limitReached を立てる。

Shrinker の公開フィールドの型と Config は変わるため、手書き・生成コードの書き換えと規則の版の更新が要る。古い List を返す縮小器を包むアダプタを用意する場合も、List を先に作る費用が残ることを説明する。旧版と同じ seed だけでは縮小結果が同じとせず、Property の libraryVersion・GENERATOR_VERSION・設定・手書きの関数・具体的な反例を保存する。候補の初出順は保ち、予算で止まる位置が変わったことを再現の情報に含める。

計測は、固定した入力から候補を取る時間と Property.check 全体を分ける。長さ24・88・256、全部同じ要素・異なる要素・0・大きな整数を使い、性質が全部成功する場合と最初の候補から失敗する場合を分ける。maxShrinks は0・1・20・1000、作業予算も固定して候補生成数・比較数・性質の呼び出し数・最終の反例を記録する。String は Unicode のスカラー値、Map は鍵順、生成されたレコードはフィールド順の契約も確認する。

## 規模の見込みと形式化

見込みは設計・実装・局所検査を行う担当の作業時間であり、実測でも日程の約束でもない。レビュー待ち・長い全体検査・公開は別とする。一作業は一つの契約を実装して確認する区切りとし、60分へ無理に合わせない。

| 項目 | 初版の主な作業 | 作業数 | 時間の幅 | Lean への影響 |
|---|---|---:|---:|---|
| 088 | コメントの位置と抽出、仮想入力と発見、test/check/許可/報告の接続、標準例と文書 | 4〜6 | 8〜16時間 | 抽出・CLI は外。既存の型付きプログラムへ渡す案なら規則の追加はない |
| 260 | Fail 専用の help と期待、英日の段落移動・生成物の照合 | 1〜2 | 1〜3時間 | 診断と文章だけ。型の規則は変えない |
| 087 | 実装一覧と設定、Show/Order テンプレート、生成記録と実行・文書 | 3〜5 | 6〜12時間 | 通常の implement の生成なら外。辞書の規則を増やす案は別 |
| 259 | 明示した型の木と版、ハッシュ・旧記録の移行、同梱例と契約書 | 2〜3 | 4〜8時間 | 開発用の JSON の境界であり、formal の交換形式とは別 |
| 032 | Body の疎な表と利用側、局所束縛も含む回帰・段別計測 | 2〜3 | 4〜8時間 | 番号・型・意味を保つデータ構造の変更。Lean の規則は変えない |
| 257 | 正規化済み Fail の確定、制約の索引と再処理、測定と辞書・交換の照合 | 3〜5 | 6〜14時間 | 規則を保つ最適化。出力が変わるため Rust/Lean の接続を再確認する |
| 258 | 候補の API と予算、各組み込みの縮小器、生成コードの移行、再現と計測 | 4〜6 | 8〜16時間 | ライブラリの通常の型・関数を使う。任意の縮小の停止や最小性の証明は含めない |
| 合計 | 共有部分をまだ差し引かない粗い見積もり | 19〜30 | 37〜77時間 | 正式モデルの重い追加を相乗りさせない |

再帰/型パラメータのある Show・Order は各2〜4作業・4〜10時間、再帰の Property は3〜5作業・8〜16時間、多相の Property は2〜4作業・4〜10時間、専用の実行器は3〜5作業・6〜12時間の追加を見込む。既存の型クラスで表す限り新しい型計算は要らないが、生成する制約と再帰の扱いは未試作である。上表の上限へ無断で含めない。

版内の順は、A・C の公開境界と D の展開を含む Lean の改造を先にまとめて終え、その後に Rust を進めるという依頼に従う。相乗りでは259の契約を087の前に確定し、258の API が確定してから Property の生成テンプレートを合わせる。032と257は原因が別なので変更を分け、doctest が大量の小さな仮想本体を作る費用とも照合する。260の文言は S2 の Failure の説明と揃える。

docs/todo の TODO-250 の三種類、すなわちエフェクトに値や型を持たせる変更、エフェクトを外す規則、型の計算を相乗りの範囲へ加えない。非公開の試作の findings と、142の検査済み値、022の実行時契約、164の辞書の代案、248の既存値への展開の .lean は参考として読んだ。これらの小モデルの成功は本番の保証と区別する。S1 の [検査済みの値](checked-values.md) と S2 の [Monad2 と構築器](monad2-and-builders.md) の範囲を相乗りの案で広げない。

## S3 の確認と後の計画への申し送り

S3 の基準は上記の完全な HEAD に固定する。文書・計測記録だけの work とし、`scripts/check.sh --level work --base fa243b049588482d8d77d24f1e832f5f480ef676 --dry-run` で選択を確認し、同じ指定の実行を一度行う。写した7項目と原文の一致、S1・S2 の保持、問いの連番、相対リンク、非公開先へのリンク禁止、表・JSON・空白を読み取り用の確認で照合する。結果は [s3/results.md](../s3/results.md) に保存する。

今回は新しい実装の接続を作らないため stage・change・release と Lean のビルドを行わない。後の plan では [07-03](../../../design/07-quality/07-03-compiler-testing.md#実装の規約と静的な検査) に従い、Rust の work の lib 全件・関連統合・clippy・fmt を入口へ一度ずつ割り当てる。doctest と既存の文書検査、inventory と生成管理、Property と derive の新しい接続を stage に名指しする。意味を変えない最適化でも、257の出力の後は必要な全比較を更新する。

change は改造全体の回帰を一度、release は実際の候補の版・同梱物・生成物・移行案内・CLI・配布の照合を担当へ割り当てる。release_stack だけの成功で公開候補の受け入れとしない。形式化した規則を変える必要が出た場合は [07-04「01-12 との対応」](../../../design/07-quality/07-04-formal-semantics.md#01-12-との対応) に従い、Lean の定義・証明・写し・レビューを処理系より先に置く。接続を閉じる区切りと最終の関係状態では check-formal.sh 全体を実行するか、関係入力の一致を根拠に引用する。

性能の受け入れ案は R17・R19・R22 に置く。実装の前後を同一条件で交互に測り、最低でも一回の準備と三標本を保存する。正式な本測定の静かな環境の確認、段別の計測と CPU プロファイル、必要な測定記録と図は後の計画へ割り当てる。今回の未調整の参考値を、既存の回帰検査や本測定の代わりにはしない。
