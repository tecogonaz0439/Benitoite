# S8・S9: 案4 の言語規則の決定と Lean の骨格

2026-10-27。実装プランを作る前の判断材料である。S8・S8b の判断案へ、README「設計者の決定（2026-10-27、言語の規則の問い）」を S9 で反映した。Q1〜Q8・Q10〜Q14 は決定済みであり、未決の問いは Q9 だけである。以下の構文・API は決定を具体化する案、Lean の追加名・証明の配置・時間は実装前の案であり、検証済みではない。IP の正規形・CIDR の細則とフォーマッタの扱いは、この決定を実装可能にするための推奨する細則として区別する。

## 基準と決定済みの範囲

言語規則と計画の開始版は `san_benito` の `3597b310ea0d91fb3a3bb3fcf281c7aa57ac9a34` とする。S8b の文書修正を始めた HEAD は `b0675576470e52bc81de4e840ee75d4b71bb260e` で、作業ツリーに差分はなかった。S8 初版の調査基準 `80d1eead` から開始版まで、および開始版からこの HEAD まで、設計書・Rust・Lean・検査スクリプトの差はないことを読み取り専用の git diff で確認した。S8 の集計はこの同一性に基づいて引用する。

`AGENTS.md` を読み、今回の依頼を優先して `private/` とそこを指すスキルのリンクを読んでいない。公開の `japanese-tech-writing` に従った。S8b では本文と [`work/m013/scratch/S8b/`（写し）](../evidence/work-copies/m013/scratch/S8b/) の下だけを変更し、ビルド、Cargo のテスト・測定、`scripts/check*.sh`、Lean の実行、LLM を呼ぶ評価、状態を変える git の操作は行っていない。勧告については既存記録の「今回は組み込まない」を C1 に引き継ぐ。新しい勧告照合を行ったとはしない。

[README](../README.md)「設計者の決定」に従い、案4 を中心とし、閉じたパターン、扱い1、名前全体を処理するハンドラ、既存の String の入口の維持を前提とする。Scope の成功の局所解析は中心に含める。`io_target` を信頼する条件として明示する判断 P1 は再度問わない。情報フロー制御（information-flow control）の実装は 0.0.14 であり、0.0.13 では D2〜D9 の判断と入口・出口の棚卸しを行う。非機密化（declassification）とエンドースメント（endorsement。信頼の付与、または完全性レベルの引き上げ）は、README「設計者の決定（2026-10-27、訳語）」に従って書く。

現行仕様の根拠は `docs/design/`、現行実装の根拠は `crates/benitoite/src/`、形式化の根拠は `formal/` である。S8 初版は、保管した ADR 0072・0183、OPEN-057 を、当時の依頼で指定された経緯の確認に限って読んだ。今の判断の根拠には docs/todo の TODO-109・142・256 と README の決定を使う。[synthesis](synthesis.md) の SK・SD の追記は、それより前の「関門は未確認」という文章に優先する。

S8 初版の根拠の記録は `work/m013/scratch/S8/` にある。S8b の追加の検索結果、参照位置、作業枠の算術、文書の点検結果は [`work/m013/scratch/S8b/`（写し）](../evidence/work-copies/m013/scratch/S8b/) に置く。S9 は HEAD `04c78e527e6c23c0be8a9dbce26f23d685a5e04d` を読み、開始版から設計書・Rust・Lean・検査スクリプトに差がないことを確認した（[`work/m013/scratch/S9/baseline.json`（写し）](../evidence/work-copies/m013/scratch/S9/baseline.json)）。S9 の一次資料、集計、見積もりの算術と静的な点検は [`work/m013/scratch/S9/`（写し）](../evidence/work-copies/m013/scratch/S9/) に置く。ビルド・テスト・Lean・評価・git の状態変更は S9 でも行っていない。以下の表のファイル名は S8 の記録を指す。

| 記録 | 内容 |
|---|---|
| `scope-io-notes.md` | Scope、IO 全入口、局所解析、CLI、独立小モデルのソース位置 |
| `lean-notes.md` | 本番と SA・SK・SD の差、定義・定理・交換の調査 |
| `lean-inventory.py`・`.json`・`.md`、`lean-*.grep.txt` | 基準版を指定した `git grep` と直接参照の集計、入力のハッシュ |
| `external-sources.md` | 外部の一次資料の URL、確認日、使う事実と限界 |
| `current-report.bnt`・`current-report.json` | ビルド済み CLI の版と、小さな現行構文の `check` の出力 |
| `lean-review.md`・`scope-review.md`・`review-handling.md` | 本文の机上のレビューと修正の対応 |
| `verify_document.py`・`document-check.json` | 出力先、リンク、番号、絶対パス、開始版と終了時の差の確認 |

S8 初版の CLI の確認は `target/debug/benitoite` の `benitoite 0.0.12` を使った。`check --report=json` は終了0、`executed:false`、`expanded:["File.Write"]` であった。オプションをパスの後に置いた初回は終了2であり、その失敗も保存した。`--version=json` が示すビルドのコミットは `44a2c9611eceb42e227817c21398369413ff86af` で、今回の HEAD と異なる。したがってこの出力は手元の実行ファイルの確認であり、HEAD のビルド結果として引用しない。以下の新構文は実行していない。

## A. 言語規則の判断案

### A1. `uses`、方針の対象、表示の書き方（Q1・Q11・決定済みの旧 R18）

【決定 Q1】範囲を `File.Write["/data/reports/**"]`、`Http.Connect["api.example.com", 443]` と書く。ポート区間は `443..445`、一点は `443` とする。複数の範囲の和は原子を並べるほか、`uses File.Write["/data/a/**", "/data/b/**"]` と略記でき、構文解析で二原子へ展開する。値型の範囲は一つのままとする。角括弧の中に式、補間、任意の定数計算、否定、範囲変数を入れない。以下の比較は決定の理由を残すものであり、再度の選択を求める表ではない。

| 選択肢 | LLM による生成・修正、人間の読みやすさの見込み | 判定 |
|---|---|---|
| `File.Write["..."]`、`Http.Connect["host", 443..445]` | 既存の型引数・`Failure.Fail[E]` に近く、エフェクト名の直後に対象が見える。引用と括弧が閉じ、変更範囲を判断しやすい。型を取る Fail と閉じた範囲を取る IO の区別は必要 | 推す |
| `File.Write(path: "...")`、`Http.Connect(host: "...", ports: 443..445)` | 引数の役割が見えるが、呼び出しに見える別の構文と長い表示が増える | 型・効果に新しい名前付き引数を入れる必要があるため採らない |
| `File.Write where ...` または汎用の述語 | 表現力は増すが、閉じたパターンより誤記・意味の揺れ・包含の説明が増える | 今回の範囲を越える |

この比較は [00-01「構文の判断基準」](../../../design/00-overview/00-01-goals.md#構文の判断基準) に沿った仮説であり、LLM の生成・修正の成功率と人間の読みやすさは未測定である。Scala の [SIP-23](https://docs.scala-lang.org/sips/42.type.html) は型位置・型引数にリテラルを書く例を示すが、今回の構文の成功率を実証する資料ではない（2026-10-27 確認）。F* の [Programming and Proving with Indexed Effects](https://fstar-lang.org/papers/indexedeffects/indexedeffects.pdf) は indexed effects の一次資料であり、同じパス・ホストの文法の先例ではない（同日確認）。新しい理論用語の日本語名は提案せず、依頼の「範囲付きのエフェクト」「範囲を添字に持つ検査済みの値」を使う。日本語の別の定着名は未確認である。以下の `PathIn` 等は API 識別子の候補である。

docs/todo の TODO-109 は、方針の鍵を操作の種類、値を対象の並びとし、`true` は全対象、`[]` は種類を許すが対象は空としている。**揃えるのは各対象の表記と解析済みの意味であり、`uses` 全体と TOML 全体の文法ではない。** 方針には deny、相対パス、`~`、`{work}`・`{tmp}`・`{secrets}` がある。これらを閉じた型へ持ち込まない。次の TOML は未実装の書式案である。

```toml
# 案。既存の policy.toml の仕様・実装ではない。
[allow]
"File.Write" = ["/data/reports/**"]
"Http.Connect" = [{ host = "api.example.com", ports = "443..445" }]
```

`File.Write["/data/reports/**"]` のパターンと方針の配列要素、`Http.Connect["api.example.com", 443..445]` の組と方針の一つの表を対応させる。ポートの一点は方針でも整数、区間は文字列 `"443..445"` とする候補である。文字列 `"host:port"` 案は IPv6 の区切りや host と port の誤記を分けにくいため推さない。ネットワークの書式は TODO-109 で未決の箇所であり、上の表を既存の決定としない。ADR 0183 の一方針から導く原則を保ち、0.0.14 より前に決める D9 へこの対応を渡す。型に方針の `true`・`[]` をそのまま書く案は、種類の許可と対象集合の空を混同するため採らない。

現行の `EffectRef` は `QualUpper [ "[" CommaList(Type) "]" ]` である（01-02「文法（全体）」:960）。標準 IO の三種 `File.Read`・`File.Write`・`Http.Connect` と、範囲を保持できる標準値型だけに、閉じた範囲引数の別の構文分類を加える。`Failure.Fail[E]` は引き続き値の型を取る。二つ目以降を修飾する規則と関数型の `uses` の最長一致を保ち、`uses A, File.Write["..."]` を受理し、`uses A, List[Integer]` の既存の E0209 を保つ（01-02:129・742〜743）。この区別は構文解析と名前解決の両方の契約にする。

範囲引数の EBNF の案を次に示す。字句の分類は既存の `Type` と文字列・整数の字句を使い、型名を解決してから引数の種類を検査する。`StringLit` は補間のない文字列リテラル、`IntLit` は既存の整数リテラルであり、ポートとしての値域は A2 で検査する。ここでの `ScopeArgs` 等は生成規則の名前である。

```ebnf
EffectRef          = QualUpper [ EffectArgs ] .
EffectArgs         = TypeArgs | PathEffectArgs | EndpointEffectArgs .
TypeArgs           = "[" CommaList(Type) "]" .
PathEffectArgs     = "[" StringLit { "," StringLit } [ "," ] "]" .
EndpointEffectArgs = "[" EndpointArg { "," EndpointArg } [ "," ] "]" .
EndpointArg        = StringLit "," PortArg .
PathValueArgs      = "[" StringLit [ "," ] "]" .
EndpointValueArgs  = "[" EndpointArg [ "," ] "]" .
PortArg            = IntLit [ ".." IntLit ] .
```

`File.Read`・`File.Write` は PathEffectArgs、`Http.Connect` は EndpointEffectArgs とする。ネットワークの略記も同じ原子の反復として、`Http.Connect["a.example", 443, "192.168.1.0/24", 80..81]` を二組へ展開する細則を推す。ポート一つを複数ホストへ暗黙に配らず、必ずホストとポートの組を反復する。値型 `Scope.PathIn` は PathValueArgs、`Http.RequestIn` は EndpointValueArgs を使い、和を認めない。後で HostIn・EndpointIn を足すなら、それぞれ一文字列・一組とする。裸の新型は Top、部分的な省略と空の角括弧は不正とする。型の別名にも同じ区別を保つ。

展開は Rust の構文解析で `UsesList.effects` を作る位置（現行 `syntax/parser/types.rs:242〜281`、`syntax/ast.rs:393〜407`）で行い、名前解決・型検査より前、Lean の型付き Surface より前に終える案を推す。文字列列と文字列・ポートの交互の列を構文上で区別し、元のグループの範囲・個数・各要素のソース位置を補助情報に残す。名前解決はその情報から、範囲を取る標準名か、型引数を取る Fail か、引数を取らない名前かを検査する。したがって `Failure.Fail["a", "b"]` を正しい二原子と誤認して通さない。型引数の列は展開しない。不正入力は回復用の節点へ残し、受理する規則を広げない。

Lean の `Surface/Syntax.lean:7〜10` は既に名前解決・型検査後の表現であり、Release の型とエフェクトを使う。この境界へは、展開済みの原子列だけを送る。Surface・Release・交換に略記の構成子を足さず、元のグループは Rust の診断位置と整形の情報だけに残す。展開・位置対応の正しさは Rust の構文と独立交換入力の照合で確かめる仕事であり、Lean がソースの字句からの展開まで証明するとはしない。

型引数は型を始める字句、範囲引数は文字列・整数の字句で分ける。`1..5` は IntLit・DotDot・IntLit となる（`crates/benitoite/src/syntax/lexer/tests.rs:996`）。ただし `File.Write[Integer]` のような構文上は型引数の入力も保持し、名前解決後に範囲引数が必要だと診断する。`Failure.Fail["x"]` も、範囲の構文として読んだ後で Fail が型を必要とすると診断できる形にする。空の角括弧や式などの不正入力を受け取る回復処理は、受理する生成規則を広げる意味にはしない。診断の分担は Q12 の決定を A3 に反映する。

同じ原子の明示重複は既存どおり誤りとし、同じ名前の異なる範囲は別原子として認める。`443` と `443..443` は一点の同一原子へ解析する。ホスト名は小文字へ揃えてから比較する。略記内も展開後に同じ重複検査を行い、`File.Write["/data/a/**", "/data/a/**"]` や、略記と別原子にまたがる重複を黙って除かず診断する。元の各文字列の位置を二箇所示す。IPv4 `/32`・IPv6 `/128` は完全一致へ揃える細則（A2）に従って同一原子として比較する。推論結果の合併で norm が構造重複を除くこととは区別する。冗長な `File.Write` と `File.Write["/data/**"]` を包含によって同一視・削除しない。ファイル単位と個別の `uses` の合併は構造上の和であり、ファイルの Top を局所の狭い使用やハンドラで取り消さない（01-07「ファイル単位のエフェクトの宣言」）。

【決定 Q11】表示とCLIの接点は次のとおりとする。具体的なJSONの欄と正規表示は、この決定を具体化する案である。

| 接点 | 推す案 | 代案と理由 |
|---|---|---|
| 型表示、`main` の一覧、診断 | 同じ正規表示 `File.Write["..."]`・`Http.Connect["host", lo..hi]`。名前だけは全対象と説明する。宣言上限と本体の推定値を区別する | 毎回別の略記へ変換する案は差分と診断の照合を難しくする |
| `--allow-effects` | 0.0.13 は既存の名前だけを受け付ける。`File.Write` はその種類の全対象の上限との照合であり、範囲付きの型にも使える。範囲付きの引数は使い方の誤りにする | 範囲も受け付けるなら括弧・引用を読める専用解析が要る。今の `split(',')` では host と port のコンマを扱えない。サーバの方針を先取りする第二の範囲指定を作らない |
| `check --report=json` | `effects.expanded` は従来の名前集合を保ち、任意欄 `effects.bounds` に全対象または範囲原子を構造で追加する。`main`、集約、test の報告に同じ形を使う | `expanded` の文字列を範囲付き文字列へ置き換える案は、既存の `--allow-effects` へ渡す利用を壊す |

フォーマッタは略記を保つ案を推す。06-03:28 の「字句を加えも除きもしない」と、同:11 の名前解決を行わない境界に従い、原子の展開をソースへ書き戻さない。元の字句・コメント・改行と括弧の役割を保持し、空白だけを整える。型表示・診断・JSON は展開後の原子を表示するので、`fmt` の出力と型の正規表示を同じものとしない。

JSON の構造の案は次のとおりである。全対象を持つ名前にも明示した要素を置き、未知・未完了を空配列にしない。`bounds` がない旧版の報告は `expanded` の各名前を全対象として読む。新しい欄を無視した受け手も保守的な同じ種類の上限を得るので、06-01:93 の任意欄の追加の条件に従い、既存形式の版を保つ案を推す。対象の精度を必須の成功条件へ変えるなら形式の版を上げる必要がある。

```json
{
  "basis": "declaredUpperBound",
  "expanded": ["File.Write", "Http.Connect"],
  "bounds": [
    {"name":"File.Write", "scope":{"kind":"pathTree","path":"/data/reports"}},
    {"name":"Http.Connect", "scope":{"kind":"endpoint","host":{"kind":"exact","name":"api.example.com"},"ports":{"minimum":443,"maximum":445}}}
  ]
}
```

これは新しい報告の案である。Top の要素は `scope:{"kind":"all"}` とする。冗長原子を保持した契約をこの欄でも失わない。通常の `check` に新しい stdout の行を加えることはせず、既存の報告と型表示の接点で提供する。根拠は `cli/inspection.rs:67`、`cli/check_report.rs:105`、`cli/effect_limit.rs:15` と 06-01「実行前のエフェクト上限の照合」「非実行の検査報告」である。

影響章: 01-02、01-06、01-07、02-03、02-05、02-10、06-01、06-03、06-04、06-06。方針側の未実装の決定は docs/todo の TODO-109 に残す。

### A2. 閉じたパターンと正規化（Q1・Q3）

パス・ホスト名・ポートの領域は現行 Scope を保ち、Q1 の決定によって IP 完全一致・CIDR を追加する。根拠は 03-06「Scope」:130〜152、`builtins/checked_scope.rs:53〜137`、`formal/Benitoite/Checked/Scope.lean:15〜74` である。

| 対象 | 推す規則 | 代案を採らない理由 |
|---|---|---|
| パスの完全一致 | スラッシュ区切りの絶対形式。`/` は受理。構成要素の字面を大小文字も含めて保つ | OS 依存の大小文字同一視や Unicode 正規化を型の等号へ持ち込むと閉じた意味が変わる |
| パスの木 | 末尾 `/**` だけ。幹自身と任意段の子を含む。`/data/**` は `/database` を含まない。`/**` は根を含む受理済みの全パス | 文字列の前方一致、一般 glob、否定は含めない |
| 不正なパス | 相対、`.`・`..`、根以外の末尾 `/`、空要素、NUL、逆斜線を拒否。注釈中の他の `*` も拒否 | 消去・補完して受理する案は入力の誤記を隠し、作業ディレクトリや OS へ依存する |
| ホスト名 | 完全一致、`*.` はちょうど一段、`**.` は一段以上。後二者は幹自身を含まない。ASCII 小文字へ揃える | `*.` を任意段の意味に変えると現行 Scope と食い違う |
| ホスト名の形式 | ASCII 英数字・ハイフンの非空ラベル。空ラベル、末尾ドット、ラベル先頭末尾ハイフン、非 ASCII、URL、ポート付きを拒否。`localhost` は受理。四つの全数字ラベルはホスト名へ戻さず IP の解析へ渡す | IP の誤記をホスト名として受け付けない。IDNA は追加しない |
| IP | 正規化した IPv4・IPv6 の完全一致と CIDR を認める（Q1 決定）。以下の細則を推す | ホスト名との暗黙の相互変換・DNS 解決を加えない |
| ポート | `0 ≤ lo ≤ hi ≤ 65535`。閉区間、一点を許す。型の注釈では省略を拒否し、全対象はエフェクト名だけで示す | `Http.Connect["host"]` を443や全ポートと推測しない |
| 和 | 効果行の原子の並び。値の型の添字は初段では一原子または Top に限る | 値型にも和の構文を増やすと、合流・共変・行の意味との混同が増える |

型注釈や閉じた具体化引数の形式不良は拒否する。動的な文字列、解析の対象外、予算超過の場合にだけ、推論結果を Top とする。既知の不正な注釈を Top に置き換えて受理する案は採らない。現在も Scope の直接呼び出しの既知の不良は E0459〜E0462 で拒否される（03-06:151）。動的な値の不良は検査関数が `Result.Error` を返す。現行の IPv4 形式の拒否は「数字だけの四ラベル」であり、正しい IPv4 だけを拒否しているわけではない。以下の変更では、そのうち有効な正規形を IP として受理し、不正な四ラベルは拒否する。

#### IP・CIDR の細則の案

以下は Q1 の「IP 完全一致と CIDR を認める」を具体化する推奨案であり、現行の Scope の動作ではない。一次資料の確認日はすべて 2026-10-27 で、節と使う事実は [`work/m013/scratch/S9/ip-research.md`（写し）](../evidence/work-copies/m013/scratch/S9/ip-research.md) に記録する。

| 対象 | 受理・正規化の案 | 一次資料と境界 |
|---|---|---|
| IPv4 | ASCII 十進数の四要素を `.` で区切り、各要素 0〜255、1〜3桁、0 以外の先頭の 0 を拒否する。`0.0.0.0` と `255.255.255.255` も字面として受理する。短縮形、整数一個、八進・十六進、符号・空白をIPv4として受理しない（数字に見えるホスト名との分類は後述） | [RFC 3986 §3.2.2](https://www.rfc-editor.org/rfc/rfc3986#section-3.2.2) の dec-octet。受理は接続可能性の保証ではない |
| IPv6 | 8組の16ビット値として解析し、小文字、各組の先頭の0除去、最長の連続0を `::` に圧縮、同長なら最初、0一組だけの圧縮はしない。全0は `::`、loopback は `::1`。注釈・Scope の入力はこの正規形と一致するときだけ受理する | [RFC 5952 §4](https://www.rfc-editor.org/rfc/rfc5952#section-4)。RFC は一般の IPv6 入力では RFC 4291 の全ての正当表記の受理を求める。ここでの入力限定は Benitoite の閉じた範囲の規則であり、一般 parser の RFC 適合を主張しない |
| URL の角括弧 | パターンは `"::1"`・`"2001:db8::/32"` とし、`"[::1]"` を拒否する。URL は `http://[::1]:80/` のように host の区切りとして括弧を使い、URL parser の結果から括弧を外して同じ IPv6 の数値へ正規化する | [RFC 3986 §3.2.2](https://www.rfc-editor.org/rfc/rfc3986#section-3.2.2)。エフェクトの外側の `[...]` と、文字列内の URL の `[...]` は別の構文。zone ID、IPvFuture は初段の対象外 |
| IPv4 射影の IPv6（IPv4-mapped IPv6） | `::ffff:192.0.2.1` の混合表記を正規形とする。IPv6 の128ビットの値を保持し、IPv4 `192.0.2.1` へ射影・同一視しない。IPv4 の CIDR とは互いに包含しない | [RFC 4291 §2.5.5.2](https://www.rfc-editor.org/rfc/rfc4291#section-2.5.5.2)、[RFC 5952 §5](https://www.rfc-editor.org/rfc/rfc5952#section-5)。初段で混合表記を生成するのはこの既知の prefix に限り、他の IPv6 は16進表記にする。OS のアドレス変換を型の等号へ持ち込まない |
| CIDR | `address/p`。p は先頭0のない十進数（0は許す）、IPv4 は0〜32、IPv6 は0〜128。アドレスのホスト部分のビットは全0を要求し、`192.168.1.5/24` は拒否する。`0.0.0.0/0`・`::/0` を許す。`/32`・`/128` は内部で完全一致へ揃える | [RFC 4632 §3.1](https://www.rfc-editor.org/rfc/rfc4632#section-3.1)、[RFC 4291 §2.3](https://www.rfc-editor.org/rfc/rfc4291#section-2.3)。非0のホストビットの拒否、prefix 長の字面、最大長の完全一致化は本言語の追加規則。黙ったネットワークアドレスへの切り下げは誤記を隠すため推さない |

ホスト名と IP は構造で分ける。Scopeの直接入力は、コロンを含むものをIPv6候補、斜線を含む条件をCIDR候補、四つの全数字ラベルをIPv4候補として解析し、不正ならホスト名へ戻さず拒否する。それ以外は従来のホスト名の規則を使う。したがって `127.1`・`123`・`0x7f000001` はScopeでは従来どおりホスト名の字面として受理し、IPv4の短縮形・整数形として解釈しない。`**.0.0.1` も三ラベルのホスト名を幹とする既存の条件である。RequestInのURLは以下の追加の拒否規則で曖昧さを避ける。ホスト名の exact・one・many の所属はホスト名に限り、IP exact・CIDR の所属は同じアドレス族の数値に限る。`**.example.com` が解決すると `192.168.1.1` になる場合でも、互いの包含は成立しない。`**.127.0.0.1` のように IP を幹とする wildcard は拒否し、数値に見える末尾を持つホスト名でも、IP 値をホスト名のラベル列として判定しない。IPv4 `/0` は IPv6 を、IPv6 `/0` は IPv4 を含まない。エフェクト名だけの Top が全対象を覆うこととは区別する。

`RequestIn` は URL の実効 host を構造で分類する。IP なら IPv4/IPv6 の同じ数値表現へ正規化し、IP exact/CIDR とポート区間の積への所属を検査する。ホスト名パターンでは IP を受理しない。URL そのものに CIDR は書けず、CIDR は検査条件にだけ現れる。注釈・Scope の条件の正規形限定と、URL parser が受理した IPv6 の別表記の数値正規化を区別する。URL 中は、host全体が十進または0x付き十六進の1〜4個の数値要素として読める場合、正規IPv4の四要素以外（`123`・`127.1`・`0x7f000001`・`127.0.0.01`など）を新RequestInの検査で拒否する。Scopeでホスト名とする字面がRequestInでは拒否される場合を認め、クライアント側の別の数値解釈を避ける。DNS を呼んで IP の条件を満たすことにはしない。`http://[::ffff:192.0.2.1]/` の host も IPv6 のままである。実効ポートは A4 の scheme の既定を用い、非追従も保つ。

旧 Scope の API も共通の対象領域へ揃える案を推す。現行 0.0.9 の仕様（03-06:132〜138）、`builtins/checked_scope.rs:53〜95` の host_word/host_pattern、`formal/Benitoite/Checked/Scope.lean:15〜29・87〜116` は IP を認めず、四つの全数字ラベルを拒否する。これを host の「ホスト名または IP」に一般化し、`checkHost`・`checkEndpoint` は IP 完全一致と CIDR 条件を受理し、`CheckedHost`/`CheckedEndpoint` の射影は正規形の IP を返す。検査対象 host 自体は一アドレスであり、対象値に CIDR を認めない。旧Scopeのホスト名入力は同じ意味を保つが、従来 ScopeError.InvalidTarget/InvalidPattern だった正規IP・CIDR条件が所属に応じて成功またはOutsideScopeへ変わるのは旧 API の振る舞いの変化である。既知定数の診断と動的 Result の両方、03-06・Checked.Scope の意味・Rust の検査・交換を同じ変更で揃える。これは互換性の帰結の記録であり、移行案内の作業は加えない。

字面の上限という保証は維持する。名前の DNS 解決、IP が私設網か、実際に接続できるか、IPv4-mapped の OS 内部での変換を純粋な Scope の検査で調べない。新 `RequestIn` の URL 正規化と実 IO の対象の一致は B2 の `io_target` のレビュー対象である。

パスについて、字面の静的な範囲と、方針の実パスの照合を明示的に分ける案を推す。ADR 0072 の保管した記録は、方針と対象を絶対化し、シンボリックリンクを解決し、未作成の対象では存在する最深親までを解決する方針であった。docs/todo の TODO-142 はこれとの整合を残る判断としている。一方、今回の純粋な範囲の包含から、リンクの解決後の対象の所属は導けない。例えば `/data/reports/link/a` の字面は木に入っても、リンク先の実体を同じ木に制限したことにはならない。

【決定 Q3】0.0.13 の対象は正規化した API 引数の字面とし、実体への照合は後の方針で行う。実体解決を範囲値の作成にも要求する代案は、純粋な Scope の意味、エフェクト、検査と使用の間の変更の扱いまで変えるため採らない。型の字面の上限を将来の許可と同一視しない。OPEN-057 の大小文字を区別しないファイルシステム、未作成のパス、各 OS の強制との一致は今回確認済みとはしない。

[Rust の canonicalize の文書](https://doc.rust-lang.org/std/fs/fn.canonicalize.html) は絶対化・リンク解決を行い、存在しない対象等では失敗すると説明する（2026-10-27 確認、閲覧表示は1.99.1）。この資料だけでは固定版1.98.1の全 OS の挙動や「最深親まで解決」の正しさは確認できない。

URI の host は IPv4・IP literal・reg-name を分け、大小文字を区別しない（[RFC 3986 §3.2.2](https://www.rfc-editor.org/rfc/rfc3986)、2026-10-27 確認）。ただし Scope の `*.`・`**.` の規則は本言語の閉じた規則であり、DNS や TLS 証明書のワイルドカード一般と同じと説明しない。

```bnt
// 案。各行の受理/拒否を示す型の断片であり、実行例ではない。
function tree(p: Scope.PathIn["/data/**"]) -> Unit uses File.Read["/data/**"]
end function
// Scope.PathIn["./data/**"] と File.Read["/data/../secret/**"] は不正な注釈。
// Http.Connect["*.example.com", 443] は a.example.com を含み、幹と a.b.example.com は含まない。
// Http.Connect["**.example.com", 443..445] は a.b.example.com も含む。
// Http.Connect["192.168.1.0/24", 80] は 192.168.1.20:80 を含む。
// Http.Connect["::1", 80] は URL http://[::1]/ の実効endpointを含む。
// Http.Connect["192.168.1.5/24", 80] は host bits 非0として拒否する。
// Http.Connect["api.example.com"] はポート欠落として拒否する。
```

影響章: 01-02、01-06、01-07、01-12、03-06、03-07、03-09、07-01、07-04。実体の照合と方針への対応は docs/todo の TODO-109・142 の残る点にもなる。

### A3. 包含、不完全性、診断（Q12・Q13）

【決定 Q12・Q13】名前が要求する引数の種類でE0513/E0520を分け、包含未確認は新E0519と理由欄で表す。以下は採択した分類と比較した代案、診断内容の具体化である。

扱い1の決定どおり、型の等号は原子の構造と正規化した並びの一致とする。原子 `a` の被覆は、上限の並びの中に `a` を丸ごと覆う一原子 `b` が存在することとする。効果行の各原子についてこの関係を確認する。名前だけの原子はその種類の全対象を覆い、範囲原子は他の名前や行変数を覆わない。Fail の型、行変数、型の等号は従来の規則を使う。

この関係は対象集合の包含について健全だが完全ではない。SA の `Limits.split_denote`・`Limits.split_not_sub`・`Limits.semantic_eq_not_norm_eq` では、`0..9` と `0..4 ∪ 5..9` は同じポート集合でも、一原子ずつの被覆では前者を後者へ含められず、冗長原子を除く正規化でも同じ形にならない（`spikes/SA/SA.lean:1218・1231・1244`）。相互包含から構造の等号も導かない。一般の和の被覆を加える案は今回の範囲を変えるため採らない。

```bnt
// 案。receivePorts の本体は省略した型の比較例である。
// 0..9 の一原子を次の二原子だけでは被覆したと判定しない。
function forward(action: (function() -> Unit uses Http.Connect["api.example.com", 0..9])) -> Unit uses Http.Connect["api.example.com", 0..4], Http.Connect["api.example.com", 5..9]
  action()
end function
```

診断は「対象が必ず範囲外」と「今回の判定で包含を確認できない」を分ける。範囲の注釈の位置、呼び出し位置、分かった範囲、成功した検査の由来、覆われなかった原子を示す。集合の一部が外だと確認できた場合に限り反例の対象を出す。和による被覆を探索していないだけの場合に、反例を捏造しない。

| 場面 | コードの候補・既存との関係 | 機械向けの補足の案 |
|---|---|---|
| 操作の名前自体を宣言していない | 関数 E0501、ラムダ E0502 を保つ | `effect`、呼び出し・宣言位置 |
| 名前はあるが範囲の被覆を確認できない | 新 E0519 候補。E0518 まで使用済みである。実装開始時に再検索して予約する | `requiredUpperBound`、`knownUpperBound`、`uncoveredAtom`、`reason`、`source` |
| 範囲を取る標準名の引数の形式・個数・対象種が不正 | 新 E0520 候補。名前解決後の期待する引数の種類で分け、Fail の型引数の E0513 を保つ | `expectedScopeKind`、`found`、引数位置 |
| Scope の既知の対象・条件が不正 | E0459〜E0462 を保つ | 現行の形式・所属の分類 |
| CLI で許す名前が不足 | E0512 を保つ | 名前集合の `missing`・`allowed` |

E0513 と E0520 の境界は、推す案では「その名前が何を引数に要求するか」で決める。`File.Write[Integer]` は範囲を取る名前への型の入力なので E0520、`Failure.Fail["x"]` は型を取る名前への範囲の入力なので E0513 とする。`Failure.Fail` の引数なし・複数も E0513、引数を取らない利用者エフェクトへの角括弧も既存どおり E0513 とする。現行 E0513 の宣言は `crates/benitoite/src/diag/codes.rs:951`、非 Fail の角括弧も拒否する検査は `typeck/decls.rs:296〜313` にある。代案は、型と範囲の取り違え・個数を共通の E0513、解析できた範囲の不良だけを E0520 とする方式である。前者は利用者が必要な引数の種類をコードで判別でき、後者は既存の分類を広く保てる。採択された案では範囲を新しく認める三種の診断分類の変更を仕様と診断表へ反映し、構文自体を回復できない場合の既存の構文診断と区別する（Q12）。

E0519 の `reason` は少なくとも `notCovered`、`atomicCoverOnly`、`unknownSource`、`budgetExceeded` を区別する案である。`atomicCoverOnly` は完全な被覆を別に証明したという意味にしない。有限区間の二分割のように既知の制限を説明できる場合の理由であり、一般には「一原子ずつの被覆で確認できなかった」と表示する。

修正案は、対象の作り方の修正、公開の検査の追加、原子を一つの上限に書き直す候補、契約の変更を並べる。契約の拡大は許可の判断と混同させず、元の契約を守る修正とは区別する。自動で `uses File.Write` へ広げる修正は推さない。診断の英文は `diag::codes` に置き、日本語の文書が説明する（02-10「文言の言語」）。

影響章: 01-06、01-07、01-12、02-05、02-10、06-01、07-03。

### A4. 範囲を持つ値と新しい IO の入口（Q2・Q4〜Q7）

旧 `CheckedHost`・`CheckedPath`・`CheckedEndpoint` は無引数の `@opaque public record` である（`prelude/stdlib/Scope.bnt:49〜70`）。条件は値ごとに異なり、現状の型名から特定の範囲を取り出せない。旧型を裸なら Top、`[R]` があれば範囲型という family に変える案もあるが、公開宣言の型引数数、生成文書、交換、型構成子の扱いを一度に変える。旧型を保ち、新型を並存させる案を推す。初段の新型は PathIn と RequestIn に絞る（決定Q6）。

| 新型の候補 | 意味・公開の表記の案 |
|---|---|
| `Scope.PathIn["/data/reports/**"]` | そのパス原子への所属を保証する値 |
| `Scope.HostIn["*.example.com"]`（追加候補） | そのホスト原子への所属を保証する値。初段には入れない |
| `Scope.EndpointIn["api.example.com", 443..445]`（追加候補） | ホスト原子と閉区間の積への所属を保証する値。初段には入れない |
| `Http.RequestIn["api.example.com", 443]` | 検査した同じ要求と endpoint を保持し、URL の実効 host/port の所属を保証する値 |

HostIn・EndpointIn を直接受ける IO は後述の7入口にない。RequestIn は endpoint を内部に保持でき、別の公開 EndpointIn を要求しない。従って初段では両公開型・生成・射影を外す案を推す（Q6）。同時に入れる代案には、検査済み対象を利用者の純粋関数へ渡す用途があるが、型・値の所属・交換と文書の費用が増える。旧 CheckedHost・CheckedEndpoint の入口は保ち、後の追加に備えて中心の対象定義は host/endpoint を扱える形にしておく。

新型の引数省略は Top の略記にする案である。例えば `Scope.PathIn` はパスの形式を検査したが狭い静的上限を保持しない型である。`PathIn["a", "b"]` や `EndpointIn["host"]` の部分的な省略を許さない。型位置で `R` と書く以下の表は閉じた原子または Top のメタ記号であり、利用者が範囲変数 `R` を宣言できるという意味ではない。

値型の添字は不変とし、`Ty.Le` へ非関数の共変変換を加えない案を推す。`PathIn["/data/a/**"]` は `PathIn["/data/**"]` と構造上異なる。IO のエフェクトが `/data/a/**` から `/data/**` へ含まれることとは別である。これにより現行の「非関数の型の包含なら等号」という補題の結論を保てる（`Release/Typing.lean:195`、`Release/Lemmas/Basic.lean:88・94`）。同じ狭い値から呼んだ IO 自体は、広いエフェクト契約の本体で使える。

【決定 Q4】値型は不変に保ち、失敗しない明示の拡大関数を追加する。広い添字へ渡すたびにResultの再検査を要求する必要はない。次は比較した案と判断の理由である。

| 方式 | 利用者への影響 | 形式化と推奨 |
|---|---|---|
| 不変、拡大も check*In で再検査 | 広い型や裸の Top の引数へ渡すたびに Result の処理が要る | 追加の変換規則は少ないが、既に包含を確認できる場合にも失敗の分岐が増える |
| 不変、失敗しない明示の拡大関数を追加 | `Scope.widenPathIn`・`Http.widenRequestIn`（候補名）で広い添字へ渡せる。戻り型の明示注釈から行き先 S を一意に決める | 推す。R を S が一原子で被覆することを静的に確かめ、同じ対象の所属を被覆の健全性から導く。Ty.Le は変えない |
| 添字の暗黙の共変 | 呼び出し時の明示変換が減る | 非関数の包含から等号を導く既存15定理の群などを変更する。今回推さない |

拡大関数は認定した標準の直接呼び出しとして、R と S が確定し、被覆が成立するときだけ型を付け、Result を返さない。対象を変えず、RequestIn では同じ要求を保ち、必要な内部の範囲情報だけを S に対応させる。Top への拡大も含む。狭小化や、包含を確認できない場合は従来どおり再検査が要る。利用者が範囲変数を宣言する多相を追加する意味にはしない。これは新しい署名の表の項目と所属保存の補題の仕事として計画へ割り当てる。

新しい純粋な検査入口の候補は次のとおりである。標準 IO と同様、標準登録に一致する入口だけに閉じた範囲の具体化規則を与える。一般の関数へ値依存の戻り型を導入しない。

| 入口の案 | 型・結果の規則の案 |
|---|---|
| `Scope.checkPathIn(pattern: String, path: String)` | `Result[Scope.PathIn[R], Scope.ScopeError]`。固定した有効な `pattern` から R、未知なら Top |
| `Scope.checkHostIn(pattern: String, host: String)`（初段外） | `Result[Scope.HostIn[R], Scope.ScopeError]`。追加するなら同じ規則 |
| `Scope.checkEndpointIn(hostPattern: String, host: String, minimumPort: Integer, maximumPort: Integer, port: Integer)`（初段外） | `Result[Scope.EndpointIn[H,P], Scope.ScopeError]`。固定の hostPattern と両端点の組から R。いずれか不明なら最初は全 endpoint の Top |
| `Http.checkRequestIn(hostPattern: String, minimumPort: Integer, maximumPort: Integer, request: Http.ClientRequest)` | `Result[Http.RequestIn[H,P], Http.RequestCheckError]`。URL の解析と所属を純粋に検査し、同じ request を保存する |
| 射影 `Scope.pathInValue`・`Http.requestInValue` | 普通の String・ClientRequest を返す。射影だけで旧 IO を狭い操作へ変えない。HostIn・EndpointIn の射影は初段外 |

`checkRequestIn` の誤りの型は、候補 `Http.RequestCheckError` を公開のデータ型として置き、`InvalidUrl(message: String)` と `Scope(error: Scope.ScopeError)` を区別する案を推す。範囲パターン・端点・所属の失敗は後者、URL の構文・非対応 scheme・要求から endpoint を得られない失敗は前者にする。既知定数の静的な拒否と、動的な入力の Result.Error には同じ分類を使う。代案は NetworkError に両方を分類して追加する方式、または ScopeError に URL 不良を足す方式である。専用型なら純粋な検査失敗を sendIn の通信失敗（引き続き NetworkError）から区別でき、Scope の誤りへ HTTP 固有の分類を加えずに済む。Q7で専用型を置く案に決定済みであり、名前と構成子の詳細はこの決定を具体化する案である。

既知の範囲は型検査で閉じた具体化引数として固定し、成功時には実行時にもその R への所属を確認する。動的な条件を静的定数だと仮定しない。Top の具体化でも入力した動的な条件の検査は行うが、成功値の型にはその条件を公開しない。新入口は純粋な組み込みの型保存 `delta_typed` へ接続する。旧 Scope の局所成功を新型の証明とみなすだけでは、この接続は得られない。

新 `check*In` と `checkRequestIn` は、初段では認定できる直接呼び出しに限る案を推す。 pattern・hostPattern とポート端点はリテラルだけでなく、既存の定数評価で値を得られる `const` の直接参照も認める。const の連鎖は既存の評価と予算の範囲に従い、局所 bind の伝播や任意の純粋関数の実行は加えない。これは既存の Regex.compile と Scope の追加検査（01-06:203〜211）に揃える案である。const は新検査の値引数に使えるのであり、A1 の範囲注釈内の式・const 参照を認める意味ではない（Q5）。関数値化、間接呼び出し、穴を含む部分適用、pipe での使用を狭い戻り型へ解釈しない。これらを受理する代案は、値引数の pattern が動的でも期待型の R に属することを追加検査する別の署名が要るため、最小案には含めない。旧 `check*` の関数値としての使用は保つ。直接呼び出しでも、期待する戻り型から未知の pattern を逆算して固定したことにしない。

一方、新 IO の `*In` は入力の添字から署名を具体化し、具体化後は普通の関数の型として高階関数へ渡せる。裸の関数名を値として使うときは、明示された期待型の入力が一つの閉じた R を決める場合だけ具体化する。未確定の添字を持つ多相な関数値を作らず、決まらなければ入力・結果・効果を明示したラムダで包むよう診断する。これらの制限は新 API にだけ設ける決定 Q2・Q5 の具体化であり、既存の一般関数の規則を変えない。

最初に加える IO は、ファイルを一つの対象で読み書きして完結する6操作と、HTTP の限定した1操作、計7操作を推す。

| 新しい操作の候補 | 型の案 | 対応する旧入口 |
|---|---|---|
| `File.readTextIn` | `function(path: Scope.PathIn[R]) -> Result[String, IOError] uses File.Read[R]` | `File.bnt:8` readText |
| `File.readBytesIn` | 同じ引数、`Result[Bytes, IOError] uses File.Read[R]` | :14 readBytes |
| `File.writeTextIn` | `function(path: Scope.PathIn[R], text: String) -> Result[Unit, IOError] uses File.Write[R]` | :34 writeText |
| `File.appendTextIn` | 同上 | :36 appendText |
| `File.writeBytesIn` | `function(path: Scope.PathIn[R], content: Bytes) -> Result[Unit, IOError] uses File.Write[R]` | :38 writeBytes |
| `File.appendBytesIn` | 同上 | :40 appendBytes |
| `Http.sendIn` | `function(request: Http.RequestIn[H,P]) -> Result[Http.Response, NetworkError] uses Http.Connect[H,P]` | `Http.bnt:25` send |

旧 String 入口の操作へ通常の `.bnt` ラッパーとして渡すだけでは、ラッパーに Top のエフェクトが残る。新入口には範囲付きの署名を持つ操作の登録が要る。Rust の処理本体は既存と共有し、使用する対象と新しい操作の署名をつなぐ。新操作を既存の名前のエフェクトへ登録するため、ハンドラの操作一覧にも追加される。既存ハンドラへの影響は A7 で扱う。

`readLinesIn` は `readTextIn` の結果の純粋な分割で作れる追加候補だが、最小の必須集合には入れない。`exists`・`info`・`listDirectory`・`remove` の範囲付き版を同時に作る案もあるが、API 数を固定しないまま見積もりを縮めない。`walk`・`removeTree`・`createDirectory` は再帰・中間の親の対象、`rename`・`copy` は二対象、Reader/Writer と後続操作はリソースへの範囲保持が要るため旧 Top のままとする。`closeReader`・`closeWriter` の State は保つ。`Http.Listen`、Listener/Exchange、Process、Console、Clock、Random も既存のままとする。全入口の位置は `scope-io-notes.md` §3 にある。SK 自身も複数対象を扱っていない（SK findings:84）。

HTTP は、検査した endpoint と公開の `ClientRequest.url` を別引数で受けるだけでは不十分である。二つが異なる URL でも型が付いてしまう。`RequestIn` は同じ request と解析済み endpoint を不透明に保存し、`sendIn` がその同じ値を使う案を推す。URL の更新は再検査を要する。URL は http/https に限り、ポート省略は scheme の既定で実効ポートへ直す。http の80、https の443は [RFC 9110 §4.2.1・4.2.2](https://www.rfc-editor.org/rfc/rfc9110.html#section-4.2.1) で確認した（2026-10-27）。範囲注釈のポート省略とは区別する。

新 `sendIn` はリダイレクトを追わず、3xx の Response を返す案を推す。代案は各 hop を同じ R へ再検査し、外の対象へ追従する前に Error にする方式である。現行 `send/get` は最大10回追う（03-09:207、`builtins/funcs/http_client.rs:61〜66`）ため、新入口の差を文書に示す。最初の URL だけを検査して旧クライアントの自動追従を使う案は採れない。proxy へ自動で接続しない現契約も保つ（同ファイル:63、03-09:205）。

新型は外部で構築・更新・表現パターンに使えず、自動アクセサで内部を取り出せない公開境界を持つ。旧 `@opaque record` を組み込みの `Ty.opaque` と同一視しない。新型は範囲専用の標準型として型検査器に登録し、一般の `@opaque` レコードに任意の値添字を認める拡張は加えない。実行時の表現を既存の不透明なレコードで共有するなら、その表現と `HasTypeV` の所属不変条件の対応を別に示す。新しい公開属性を追加する案は初段に推さない。

`Scope`・IO・Network は今回 `Benitoite.Unofficial` のままにする。公式化を同時に行う案は、範囲の機能と import の移行を結び付ける理由がない。内部の所有元は現行どおり標準の同一性で認定し、利用者の同じ綴りの関数を認定しない（03-06「標準のモジュールと非公式のモジュール」:82〜90）。

```bnt
// 案。PathIn と *In は未実装である。公開契約を明示する例である。
import Benitoite.Unofficial.Scope
import Benitoite.Unofficial.IO.File

function saveReport(path: Scope.PathIn["/data/reports/**"], text: String) -> Result[Unit, IOError] uses File.Write["/data/reports/**"]
  return File.writeTextIn(path: path, text: text)
end function

function saveInput(raw: String, text: String) -> Result[Unit, String] uses File.Write["/data/reports/**"]
  return match Scope.checkPathIn(pattern: "/data/reports/**", path: raw) with
    case Result.Ok(checked) ->
      return saveReport(path: checked, text: text)
        |> Result.mapError(r: _, f: lambda(error) return IOError.message(error))
    case Result.Error(_) -> Result.Error("出力先が報告用の範囲に入らない")
  end match
end function
```

影響章: 01-02、01-05、01-06、01-07、01-12、02-05、02-08、02-09、03-06、03-07、03-09、06-06、07-04。

### A5. Scope の成功の局所解析と公開契約（Q5・決定済みの旧 R12・R13）

推論できない局所値は Top とし、狭い注釈を書いただけでは受理しない。これは既存の保証と決定済みの閉じた範囲からの制約であり、旧 R12 として再度の選択を求めない。すべての動的値に狭い注釈を要求する案は、検査成功から得られる情報を失う。一方、未知でも注釈を信用して狭い型を付ける案は健全でない。必要な位置で明示した新しい検査を行えば、その成功値へ R を付けられる。

| 入口・境界 | 推す規則 |
|---|---|
| 直接の標準 check | 解決済みの所有元・関数・契約引数位置を確認する。閉じた条件を保存した Result の由来を記録する |
| `Result.Ok(checked)` の腕 | 同じ成功値番号の `checked` へだけ条件を結び付ける。パターンは既知でも対象の String 自体は動的でよい |
| 直接の射影 | 同じ checked からの path/host/port と条件の射影を認定する。別個体・同じ綴りの別関数へ転用しない |
| 保存と合流 | 一度保存した Result と直接の Ok 腕まで。別名、再包装、未知の呼び出し、値合流、本体境界で局所の由来を忘れる。新型の既に付いた R は普通の型として保持する |
| ラムダ、handle の保護本体と節、Task | 各入口で局所由来を初期化する。型に明示した R の引数は使えるが、外の成功値の由来を推測して輸入しない |
| 予算・対象外 | Top と理由を返す。狭い契約に必要なら E0519。従来の区間警告はこれまでどおり未知から誤りを断定しない |

現行の Range は、`typeck/interval/flow/range.rs:12〜35・80〜94・265〜286`、`Interval/RangeState.lean:13〜107` に所有元・成功値・忘却の基盤を持つ。ただし後段の区間解析は全本体の型検査と定数評価の後の警告用である（02-05「区間解析の駆動と予算」:245）。このパスをそのまま先行する型の受理条件に使うと循環する。

共有するのは、局所束縛番号 `BindingScope`、解決済み標準の認定、引数位置、成功値の識別、忘却の小さい操作に限る案を推す。Scope の由来は別の成分へ置き、型・エフェクトの制約を確定する前または同時の必須判定へ渡す。既存 `RangeState` 全体を汎用化し直さない。後段の警告は別の消費者として保つ。両者が同じ由来を使っても、「型の契約を通すための証拠」と「警告のための近似」の成功条件は分ける。

旧 `Scope.checkPath` の成功要約だけで `CheckedPath` を新しい `PathIn[R]` に読み替えない。旧成功値の射影を新 `checkPathIn(pattern: Scope.pathPattern(old), path: Scope.path(old))` へ渡す場合は、局所由来から固定した条件を認定できるようにするが、初段は再検査を残す。新 `checkPathIn` を直接使えば所属検査は一度である。旧値からの無検査変換を足す代案は、成功要約・値の不変条件・脱糖の型の保存を結ぶ追加証明を要し、見積もりの削減に数えない。

トップレベル関数は公開・非公開とも引数型、結果型、エフェクト上限を明示する既存規則を保つ。公開関数の R を本体から自動生成して契約を書き換えない。ラムダと局所呼び出しは推論する。関数の本体を呼び出し元へ展開して任意の範囲要約を推論する方式は今回含めない。これにより実装を変えたときに既存契約への適合を再検査できる（00-01 原則2、01-02:142、01-06「型注釈」）。

```bnt
// 案。動的な path は認めるが、関数の上限は本体から勝手に広げない。
function store(raw: String) -> Result[Unit, String] uses File.Write["/data/reports/**"]
  return match Scope.checkPathIn(pattern: "/data/reports/**", path: raw) with
    case Result.Ok(p) ->
      return File.writeTextIn(path: p, text: "done")
        |> Result.mapError(r: _, f: lambda(error) return IOError.message(error))
    case Result.Error(_) -> Result.Error("対象の検査に失敗した")
  end match
end function
// pattern 自体が未知なら戻り値の添字は Top になる。
// その値を使った writeTextIn をこの狭い uses へ入れることは拒否する。
```

影響章: 01-06、01-12、02-05、02-06、07-03、07-04。形式化した局所解析の小モデルと Release の型の対応は B2・B4 で別の義務にする。

### A6. エフェクト変数、高階関数、ハンドラ（Q8・Q9）

行変数は、具体化すると名前・範囲・Fail を含む行全体になる。範囲は閉じているため型代入で変わらず、行代入は行原子をその像へ置き換え、元からある範囲原子を保つ。既存の高階関数に新たな範囲変数は要らない。例えば現在の `List.map[T,U,effect E]` は f の行 E を結果の計算へ渡せる（`List.bnt:67`）。

```bnt
// 案。既存の effect E は、範囲付きの行でも具体化できる。
function twice[effect E](act: function() -> Unit uses E) -> Unit uses E
  act()
  act()
end function

function runReport(action: (function() -> Unit uses File.Write["/data/reports/**"])) -> Unit uses File.Write["/data/reports/**"]
  twice(act: action)
end function
```

値型の引数・戻り値を変えず、最外側の関数のエフェクトを広げられる既存規則を保つ。入れ子の関数型、List の要素、`PathIn` の添字へ共変を拡張しない（01-06:111〜132）。型の等号と範囲の包含を同じ制約として解かない。

ハンドラは決定済みの名前全体を処理する。`File.Write` の全操作の節が揃えば、本体の同名の範囲原子を除けるが、節が行う操作の範囲は出力の上限へ足す。節が `/tmp/cache/**` へ書けば、その範囲が外側へ現れる。元の `/data/reports/**` に押し込めたり、名前を処理したことだけで節の IO も消したりしない。SK の `Examples.redirect_typed`・`redirect_exec`・`redirect_event_in_bound` と、誤った規則の反例 `Examples.wrong_rule_unsound` がこの差を示す（`spikes/SK/SK.lean:1088〜1127`、SK findings §4）。

```bnt
// 案。全操作の節を省略したハンドラの一節の例である。
// handle の出力には節の /tmp/cache/** が必要である。
handle
  File.writeTextIn(path: reportPath, text: "a")
with
  case File.writeTextIn(path, text) ->
    resume(File.writeTextIn(path: cachePath, text: text))
end handle
// 他の File.Write の操作もすべて処理しないと名前全体は除けない。
```

この例の `reportPath` と `cachePath` は、それぞれの添字を持つ値を事前に得たものとする。節はハンドラの外で実行する既存の意味を保つ。State を処理できないこと、エフェクト変数を取り除けないこと、ワンショット、Task が引き継ぐ節は末尾再開に限ることも保つ（01-06「エフェクトの宣言とハンドラの型付け」、01-07、01-11）。

【決定 Q8】新操作の節の引数には、保護本体の同名の閉じた一原子Sを保持し、複数・Top・未確定の行変数ならTopを与える。名前全体の捕捉とは別に、節に渡す値の型と節自身のIOの上限を区別する。次は比較の記録である。

| 方式 | 記録して同じ値を転送する節の上限 | 証明・制限と推奨 |
|---|---|---|
| 節の入口で必ず Top へ忘却 | 常に Top となり、狭い uses の関数では再検査なしに使えない | 同じ閉じた値が R から Top の型を持つ専用補題で済むが、記録・転送の用途の精度を失う |
| 保護本体の ε に同名の閉じた原子が一つだけなら、その原子 S を節の添字とする。複数・同名 Top・行変数があれば Top | 一原子の本体ならその S を保てる。複数・未知なら Top | 推す。捕捉した呼び出しの R が S で被覆されることから、同じ値に S の型を付ける専用補題へ一般化する |
| 内部の剛な範囲束縛で節を全称検査 | 各呼び出しの R を保持できる | 型・行・署名の束縛と代入が増える。初段には推さない |
| 有限な呼び出し出現ごとに節を複製 | 各出現の R を使える | 呼び出し追加で節の検査が変わる。初段には推さない |

推す案の S は、節の本体や期待される出力から逆算せず、節を検査する前の保護本体の ε から決める。部分ハンドラの場合も同じであり、同名原子がない場合も Top とする。Top を併記した行は冗長原子を消さない決定に従って Top にする。範囲を保持した行変数の具体化と、未確定の行変数とは区別する。

呼び出し側の具体化済み署名 `opSigAt(b,R)` と節側の `opSigAt(b,S)` を分け、捕捉直前の代入済みの閉じた実引数について「同じ値の R への所属と R の S への被覆から S への所属を導く」専用補題を証明する。これは一般の Ty.Le の共変でも、任意の局所変数の暗黙変換でもない。明示拡大（Q4）も同じ所属補題を使える。7 IO の戻り型は範囲添字を含まないため、両署名の結果型・型引数数・引数の契約名の一致を IOShape で確かめれば、resume の入力型も一致する。新しい操作は署名の表へ加え、このために値型や評価関係の構成子を追加しない（B1）。

一原子の本体では、捕捉した path の記録・転送は元の狭い S を使える。複数の範囲や行変数から捕捉する節は、固定の狭い範囲で再検査するか、既知の添字を持つ別の値を使う。節が元の対象と違う対象へ書くなら、その対象のエフェクトを出力へ加える規則は変わらない。

【未決 Q9】利用者定義エフェクトへの範囲引数は、[user-effect-scopes](user-effect-scopes.md) で、標準の範囲引数だけの案、型引数も認める案、現状を保つ案を比較する。Q9 が決まるまでは B・C の本番計画と見込みに利用者定義の範囲引数・型引数を含めない。従来の行多相が行全体を運べることと、利用者のエフェクト宣言に範囲変数を束縛できることは別の拡張である。

影響章: 01-02、01-06、01-07、01-11、01-12、02-05、02-06、07-04。

### A7. 互換性の帰結と組込み構成（決定 Q2）

既存の裸のエフェクト、String の IO、旧 Checked 型、Unofficial import、IO.All の展開を保つ。旧スクリプトに新しい検査済み値を必須にしない。既存の File.Read/Write を含む関数は Top のままであり、自動で狭い保証を得たとは報告しない。

新 IO を File.Read・File.Write・Http.Connect の新しい操作として加えると、従来の全操作の節だけでは名前全体を除けなくなる。現行の型規則は一部の節だけを持つハンドラからその名前を除かない（01-06:592、`formal/Benitoite/Release/Typing.lean:120〜135`）。本体が旧操作しか呼ばなくても、節の網羅は名前の全操作の一覧で判定するためである。

特に Http.Connect は今は send 一操作だけである（`crates/benitoite/src/prelude/stdlib/Network/Http.bnt:23〜26`）。従って `case Http.send(r)` を持つハンドラは、今は名前全体を処理する。sendIn を追加すると、同じコードは部分ハンドラとなり Http.Connect が残る。外側が純粋な契約なら拒否され、許す契約があれば main の宣言上限の一覧や `effects.expanded` へ名前が新しく現れ、従来の `--allow-effects` に追加が必要になりうる。サーバの承認は未実装だが、その上限を承認に使うときにも説明すべき差である。実際の呼び出しが増えたと断定したり、自動で許可を追加したりせず、操作一覧の追加による表示の拡大と示す（00-01 原則2・3、`cli/check_report.rs:105`、`cli/effect_limit.rs:15`）。この帰結は規則から確定し、新構文の実行で再現済みという意味ではない。

【決定 Q2】7入口を新操作として加える (a) を採る。`0.1.0` の公開までは移行案内を一切書かず、移行文書・移行例の作成を計画から除く。理由: 現在の利用者は設計者だけである。次の表は比較の記録であり、現在の選択肢ではない。

| 案 | 互換性 | 形式化の手間 | 利用者に見える振る舞いと推奨 |
|---|---|---|---|
| (a) 新操作を追加する（採択） | 従来の完全ハンドラに新節が必要 | 元 b と範囲実引数を分ける署名を証明し、既存の網羅規則を保つ | 採択。操作一覧・不足節と、main・allow-effects の表示の差は仕様上の帰結として残す。移行案内・移行例は作らない。契約や許可を自動で広げない |
| (b) 表層で旧節から新節を合成する | 旧 send 節だけで新 sendIn も捕捉でき、従来の名前消去を保つ | 同じ要求の射影を挟んで `case Http.send(r)` の本体を新節にも使う。コアの操作 ID は別のまま。引数・結果・再開・束縛の保存と脱糖の型保存が要る | 利用者が書いていない新操作も旧節へ入る。明示した sendIn 節を優先し、二重節を作らない規則が必要。実 IO へ転送する旧節の Top はそのまま残す。初段には推さない |
| (c) 範囲付きの入口を新操作にせず、既存操作の具体化として登録する | 操作一覧を保ち、全操作ハンドラを維持できる可能性がある | 旧 String/ClientRequest の節と新しい検査済み引数の署名を、同じ b で対応させる関係が要る。入力の射影、節への変換、結果と同一対象の保存を証明する。範囲を操作 ID に埋め込まない | 旧節が新入口も捕捉することになる。単なる旧 IO のラッパーでは Top を消せない。署名の複数形を持つ規則の費用が増すため初段には推さない |

(b) は File の対応する旧節にも射影を挟んで適用できる。ただし旧 File.Read・File.Write の全操作が揃うときだけ名前を消す。File.Read は11操作、File.Write は12操作である（`IO/File.bnt:6〜29・32〜61`）。一般の利用者が全操作を処理していれば同じ互換性の問題がある。一操作だけの節は既に部分ハンドラなので、追加により初めて名前が残るという変化はない。

取りまとめの14ファイルの検索を、開始版の crates・tools・docs/design・docs/reference で再確認した。すべて一操作だけの節またはその要求の記述であり、case Http.send は0件、File の全操作ハンドラも0件であった。14には評価課題の task.json と task.md の2ファイルを含むため、実行可能なハンドラ14個とは数えない。翻訳と改造の検討文書の追加一致は別に記録した。検索式、ファイル・行、範囲と限界は [`work/m013/scratch/S8b/evidence.md`（写し）](../evidence/work-copies/m013/scratch/S8b/evidence.md)・`handlers.json` にある。既存利用者の外部コードの件数は不明であり、「旧コードはすべて変更不要」とはしない。

(a) を推す理由は、今回調べた例に名前消去の変更対象がなく、合成・同一操作の複数署名という新規則を増やさずに範囲付きの入力を保てるためである。D00 で別名も含む棚卸しと生成物の更新先を固定し、R30・R40 で新節の不足と表示の差を照合する。新しい節を実 IO へ転送すれば、その IO の範囲を出力へ加える既存の規則を適用する。

構成の境界は AGENTS.md「改造の設計で守ること」に従う。範囲の構文・解析済みデータ・包含はネットワーク、暗号、Wasmtime、サーバへ直接依存しない。構成で変えるのは使えるモジュールと標準関数の集合だけとし、同じ原子の意味・等号・包含は変えない。含めない Http の使用は検査の段階で拒否する。将来の Cargo feature の具体名や組込み対応が現在すでに実装済みとはしない。

ポートは数学的な 0〜65535、IP は32ビット・128ビットの明示した幅で扱う。Rust は `[u8; 4]`・`[u8; 16]`（または u32/u128 と検査付き変換）、Lean は `Fin (2^32)`・`Fin (2^128)` または同じ境界証拠を持つ Nat を使う案とし、IPv6 を `usize` へ詰めない。文字列長、原子数、節数、予算の加算と交換の個数では先に上限を確認し、`usize` への変換を検査する。ホストのポインタ幅でパターンの真偽を変えず、64ビットの `usize`、32ビットを越えるビットマスクへの依存を増やさない。32ビット構成でのビルド・実行は今回未確認である。

影響章: 01-03、01-06、01-07、02-01、02-05、03-01、03-06、05-01、06-04、06-06、07-03。

### A8. 保証の範囲と後の情報フロー制御への受け渡し（Q3・Q10）

00-01 と 07-01 に反映する文章の案は次のとおりである。現在の設計書をこの作業では変更しない。

> 範囲付きのエフェクトは、関数が行わせうる操作の種類と、正規化した API 上の対象の静的な上限を表す。範囲を越える呼び出しを型の契約違反として報告する。範囲のないエフェクトは、その種類の全対象の上限を表す。上限の記述と検査の成功は、実行側が操作を許可したことを意味しない。
>
> この保証は、組み込みの IO が検査済み引数の対象を同じ操作の対象として使い、別の対象や追加の操作を観測から隠さないこと（io_target）を信頼する。範囲への所属、包含、実行全体の対象の健全性は、この条件と型付け・保存・ハンドラの規則から導く。対象の健全性そのものを信頼の条件に置かない。
>
> 型の字面の範囲は、パスのリンク解決後の実体、ホストの DNS 解決先、OS の隔離を保証しない。範囲内の値が何を表すか、読み取った内容がどこへ流れるか、外部コマンド内部の操作、利用者の意図との一致、IO の成功、停止性も保証しない。実行時の権限制御と OS の強制はサーバモードとあわせて提供し、それまでは隔離をハーネスと OS に委ねる。

07-01 には、チェック済み値の生成、IO の対象の使用、ハンドラ節の対象、解放、Task、外部コマンドを別の信頼・保証の行にする。`io_target` は `delta_typed`・`io_typed` と同じく形式化の外の実装との対応であり、Lean が Rust のファイル・HTTP の本体を検証済みという意味にしない。SK の `checked_alone_insufficient` は、値の所属だけでは実 IO の対象の一致を導けない反例である。

また `Http.Connect[host,ports]` の対象は host と port の組であり、scheme を含む origin と等しくない。[RFC 9110 §4.3.1](https://www.rfc-editor.org/rfc/rfc9110.html#section-4.3.1) は origin を scheme・host・port の組としている（2026-10-27 確認）。0.0.14 の D5 に渡す R は、最低でも http/https の両方の可能性を含む保守的な上限とする。https の origin だけを許す方針を host/port 一致だけで満たしたことにしない。代案は scheme を案4の原子にも加える方式だが、今回の scope 代数と表層を拡張する。Q10の決定に従い初段はhost/portを保ち、schemeの精度は認定した要求の契約で別に足すか両方を覆うかをD5・D9へ明記する。

影響章: 00-01、00-03、01-07、03-06、03-07、03-09、07-01、07-04。未実装の情報フロー制御とセキュリティ型システム（security type system）、非干渉性の保証はこれらの章へ先取りして書かず、docs/todo の TODO-269・109・154 へ判断を残す。

## B. Lean の骨格の設計

### B1. 最初に決める中心の定義と互換の境界（Q14）

最初に「Lean の骨格の設計」の枝 L00 を置く。今回の依頼に転載された設計者の第6弾の教訓は、Integer64 固定で L01〜L12 を作り、L13〜L16 で七種へ広げると、定義の形に依存する約20の証明ファイルを繰り返し通し直すことになった、というものである（L16 は4枝に分割）。今回は最終の対象を見越して評価関係・抽象値・局所位置を決め、その後の規則・補題・例は小さな枝で追加する。一度の切り替えで既存の証明が長く通らなくなる案を採らない。

初段の公開型を PathIn・RequestIn に絞っても、中心の対象の分類は path/host/endpoint と Top を扱える形にする。host は初めからホスト名・IPv4・IPv6、パターンは IP exact/CIDR を含める。将来の演算ごとに Ty・Atom・評価関係へ構成子を加える方式を既定にしない。L00 の最初の小枝で次の候補を、Top の旧例と非 Top の検査・転送例を使って比べる。

| 骨格の候補 | 旧証明への影響と調べる点 | 推奨 |
|---|---|---|
| (i) 既存の構成子に閉じた範囲の引数を持たせ、旧入口は Top を既定にする | 例: Atom.name の範囲、Ty.opaque の標準型記述の範囲。帰納的な場合の数は増やさずに済むが、パターンの引数数・等号・canonical・値の所属の証明は直す必要がある | 第一候補。旧の表記は構築関数と互換の補題で保ち、単なる既定引数だけで証明が通るとは約束しない |
| (ii) 既存の構成子が持つ名前の記述に範囲を入れ、範囲付き署名は Builtins の表の項目として持つ | 記述を単なる自由な文字列にせず、種類・元名・閉じた範囲と WF を持つ構造にする。構成子の引数数は保ちやすいが、文字列の比較・資源型・所有元との対応が変わる。範囲の数だけ操作 ID を作らない | (i) と実物で比較する第二候補。署名の表を使う点は (i) と併用する |
| (iii) 新しい Ty.scopedValue・Atom.bounded を加える | 全場合分け・巡回・代入・inversion・canonical を増やす。B3 の18定理は優先点検、306定理／75ファイルは点検母集団であり、書き換え数ではない | 今は推さない。採用へ変えるには、直接の全場合分けを追加集計し「言明変更・証明変更・点検のみ」の件数見込みと、小枝で既定ビルドを保つ方法を再提出する |

推す組合せは (i) と Builtins の表である。既存の値型・名前の構成子に閉じた対象記述を載せ、純検査・明示拡大・IO の具体化は表の署名として追加する。値の型付けの所属条件は表の健全性と純検査の保存で示す。名前に R を埋めただけで任意の不透明値に所属が成立したことにしない。旧 record や一般の @opaque 宣言を範囲型へ読み替えず、認定した標準型にだけこの記述を使う。

L00 で決めるものは型と原子の格納先だけではない。Scope の成功の評価関係は、解決済みの標準束縛が選ぶ規則の表と適用の関係にし、抽象値は対象種類と既知の範囲・未知を一般の引数として持つ。局所位置は既存の BindingScope と OperationKey による値と呼び出しの同定を共有し、checkPath・checkHost ごとの別の番号付けを増やさない。現行の参考は `Interval/Eval.lean:169〜182・313` の StandardRule・StandardBinding・EvalStandard、`Interval/Range.lean:30〜35` の表から規則を選ぶ関係、`Interval/RangeState.lean:13〜42` の BindingScope、`Interval/Identity.lean:73` の OperationKey である。現行 EvalStandard 自体は規則ごとの構成子を持つので、そのまま拡張すれば巡回が不要になるとはしない。新しい Scope の評価関係を最初から表で適用する形にするという提案である。

表の各項目には入力・結果・効果の署名、実対象の取り出し、所属を保つ補題を対応させる。新しい項目の性質はその項目を実装して証明し、全体の健全性を表の健全性から導く。対象の健全性そのものや未証明の各演算の結論を、信頼の条件へ移し替えない。純粋な組み込みと実 IO の対応に関する既存の信頼境界は B2 に明記する。

| ファイル（formal/Benitoite/ から） | 変更の候補と先に固定する契約 |
|---|---|
| 新 Scope/Domain.lean、Checked/Scope.lean | 対象種類、閉じた範囲、所属、被覆とその健全性・推移。path exact/tree、host名 exact/one/many、IPv4/IPv6 exact/CIDR、port 閉区間を扱う |
| Release/Atom.lean、Types.lean、Order/* | Top の旧入口、範囲の格納先、構造の等号、閉じた範囲の代入不変性。Ty の新構成子を API ごとに増やさない |
| Release/Effect.lean、TypeSubst*.lean、TypeComposition.lean、Subst.lean | 構造包含と意味の被覆を分け、norm は整列・構造重複の除去に限る。旧の構造等号の補題を互換の形で残す |
| Release/Typing.lean、Syntax.lean、Assumptions.lean | 元の操作 b と R の具体化を分ける標準署名の表、IOShape、節の S、値の所属、明示拡大。既存 B.effects は操作 b の一覧のまま（Typing.lean:62〜73） |
| Release/Semantics.lean、Lemmas/* | 対象の有限列の観測、IO の同一対象、同じ ε の StateTyE・継続・ストア。対象なしと対象ありを区別する |
| 新 Surface/ScopeState.lean、Surface/Check*・Desugar* | 一般の局所事実の成分、成功・射影・忘却・予算、必須判定、同じ R のコア署名。既存 RangeState 全体を作り直さない |
| Exchange/*、SurfaceCheck/Validation.lean、各 Main | 範囲・添字・具体化・観測の読書き、新版のタグ、旧版の明示した Top への対応 |

SA・SK の Pattern.tree stem extra は追加要素が extra 個以上という表現であり、現行 Scope の one（ちょうど一段）を直接表さない（`spikes/SA/ScopeCopy.lean:13〜20`、`Checked/Scope.lean:15〜29`）。最初の対象の定義で exact/one/many を含め、後で one を足すために中心の帰納型を再変更しない。所属・one 同士・one と many・exact と one の包含と推移の証明は小枝で加える。ホストラベルの通常順と逆順の対応も別の補題にする。現行の `*.` を試作の木の意味へ変える案は採らない。

CIDR の所属・包含は、アドレス族ごとの閉区間として扱える。幅 w∈{32,128}、ネットワークの数値 n、prefix 長 p とし、`0 ≤ p ≤ w`、`n < 2^w`、`n mod 2^(w-p)=0` を正しさの条件とする。意味は `[n, n + 2^(w-p) - 1]` で、完全一致は一点である。同じ族の区間 A を B が含むことは `B.lo ≤ A.lo ∧ A.hi ≤ B.hi` で判定する。この部分はポートの閉区間と同じ順序の補題（所属保存・反射・推移）を共有できる。ただし prefix と区間の対応、解析済みのアドレスのバイト列と数値との往復は別の証明義務であり、portの証明だけで済ませない。文字列からのIP parser・RFC5952のformatter自体の正しさは新しくLeanの証明範囲へ加えない。現行Checked.Scopeの境界（`Checked/Scope.lean:4〜8`）と同じく、解析済みの分類・数値から所属を証明し、Rustの文字列処理との対応は独立交換入力・境界例・実装レビューで照合する。B6の追加費用もこの境界を前提とする。

Lean の端点計算は Nat の非負演算で行い、`hi < 2^w` を prefix の条件から示してから Fin へ包む。`/0` の幅 `2^w` はアドレス型に格納しないため、最大端点を越える有限整数の加算や `1 << 128` に依存しない。Rust は同じ境界を固定長バイト列または検査付き固定幅演算で実装し、最大 prefix・/0・最大アドレスを別に照合する。32ビット環境でも意味を変えない。

B1 の新 Scope/Domain と Checked/Scope が担当する補題は、(1) 解析済みのバイト列・数値表現と族の保持、(2) prefix の区間の境界と所属の一致、(3) 同族の被覆の健全性・推移、(4) 異族およびホスト名との非包含、(5) endpoint の port との積の被覆である。B4 の L00 で型の分類を固定し、L10 でこの5群を小枝で閉じ、L40 で旧 Scope・RequestIn の成功と接続し、L50/K10 で独立交換を照合する。Release の進行・保存の各場合を CIDR ごとに増やす骨格にはしない。

CIDR を区間にできても和の包含の判定を完全にするわけではない。例えば一つの `/24` を二つの `/25` の原子で覆う判定は A3 と同じく行わない。`/32`・`/128` の完全一致化以外に、隣接 CIDR を合併したり冗長な広い原子を消したりしない。

`Ty.Le` は「等号、または同じ引数・結果の関数の最外部の効果拡大」を保つ。明示拡大と節への被覆は専用の所属補題で処理する。L00 で候補が絞れなくても、未証明の本番定義の切り替えへ進まない。ビルドを維持した候補と必要な書き換えの見込みを提示し、Q14の決定を保ち、骨格・枝分け・見積もりを計画レビューへ戻す。

### B2. `io_op` と `io_target` の分離

現在の `io_op` は `s.opEff = some l`、`s.eff = Eff.single l`、`s.neffs = 0`、`B.effects l = some bs`、`b ∈ bs` を一度に求める（`Release/Assumptions.lean:77〜80`）。次のように具体化済み署名の形を検査する関係へ変える案を推す。

| IO の形 | 入力と上限の条件 | 保つ条件 |
|---|---|---|
| 旧、対象なし | 元の引数型、名前だけの効果 | opEff、neffs=0、操作一覧への所属 |
| 旧、対象あり | 旧 String 等の型、その種類の Top | 同上。対象なしの操作へ偽装しない |
| 新、単一対象 | `PathIn[R]` または `RequestIn[R]` を対象位置に持ち、効果は同じ R の原子 | 同上。引数添字・効果原子・対象位置の一致 |

`effect_ops` と `opEff_io` は元の操作名から署名・種類へ戻る役割を保つ。`io_op` を「任意の eff でよい」と緩めない。Console や Process.Exit に新しい対象引数を要求しない。複数対象の入口は旧 Top に残すが、観測の表現自体は対象の有限列へ拡張できる形にする。

新しい信頼の条件は、概念的には次の形である。これは完成した Lean コードではなく、引数と結論の境界の案である。

```text
io_target:
  新しい単一対象の範囲付き IO は、具体化済みの署名と型付き引数に対し、
  ioResponse の観測対象が IOShape の引数から得る同じ対象と一致する。
  旧 Top の IO は、リダイレクト・再帰・複数対象も含め、
  観測された対象の操作種類が宣言した種類と一致する。
  全 IO で、対象ありの操作を対象なしとして報告せず、追加の対象を隠さない。
```

「型の付いた引数の対象が R に属する」は `HasTypeV` の不変条件と純検査の保存から示す。「実装がその対象を使う」は範囲付きの形の `io_target` として信頼する。「事象が ε に属する」は両者と範囲包含・継続・保存から証明する。旧Top入口は同じ種類の任意対象を含むため、旧HTTPのリダイレクト先を最初のURLと同一だと要求しない。この三段を一つの仮定にまとめない。新 `check*In` の純粋な実装の型保存は、既存 `delta_typed` が新しい索引付きの結果について要求する内容として、03-06・07-04 の対応表に明記する。

旧条件だけの `CoreAssumptions` と、新条件の `TargetAgreement` を分け、全体の `Builtins.Assumptions` が両者を明示的に含む形を計画のレビュー案とする。旧 R20 は利用者の選択を要する問いから外す。旧 progress/preservation/effect_soundness は CoreAssumptions に依存し、対象の定理だけが両方へ依存する。代案は従来の同名構造体に全フィールドを直接足す形で、移植は単純だが旧定理の同じ `hb` も強い条件を要求する。どちらでも `io_op` の中身が変わるため、「前提は変わらない」とは書かない。引数名・結論の形を保つことと、前提の内容の維持を区別する。

### B3. 主な定理と既存の点検範囲

| 定理・定義 | 維持する結論／追加する言明 | 手が入る箇所 |
|---|---|---|
| `Release.progress`（`Release/Theorems.lean:35`） | `StateTy → Final ∨ ∃ Step` | io_exists の具体化、範囲型の canonical、各操作と節の整合。結論を弱めない |
| `Release.preservation`（同:42）と内部 `preservationE` | 同じ StateTy、内部では同じ ε の StateTyE を保存 | 新値型、代入、IO の結果、節・継続。範囲の相互包含で型の等号を置き換えない |
| `Release.effect_soundness`（同:52）と `effect_soundness_noLamNames`（同:62） | 空の効果の計算から IO・解放の事象と未処理操作が出ない | 範囲原子でも空との包含を帰着させる。State の旧保証を残す |
| `Surface.desugar_typed`（`Surface/Theorems.lean:19`） | `WellFormed ∧ WellTyped ∧ EffectsOk` | 索引型、範囲の具体化、Scope の必須判定とコアの署名の一致。実 IO の io_target を前提に足す必要はない |
| 新 `Release.io_target_allowed` | `StateTyE P B ε s` と対象を持つ一段の事象から `∀ t ∈ observedTargets, Eff.Allows ε t` | 入力所属、io_target、捕捉されない操作の継続の被覆 |
| 新 `Release.targets_soundness` | 初期の型が持つ ε について、任意の到達状態から出る全対象事象が同じ ε に入る | 既存 Steps と同じ ε の保存を使う。新しい trace 関係を作らなくても言明できる |
| 新 `Surface.scope_inference_sound` と接続定理 | 認定した成功値・射影が指す値は推論した R に属し、型検査へ供給した R はコアの入力型と一致する | 小モデルの局所健全性と本番型付けの対応を別々に証明する |

対象の多段の言明は「初期状態から s に到達し、s から対象事象を出すなら、その対象は初期 ε に入る」とする。既存の `Steps` と保存を使い、進行や保存の結論へ観測の命題を押し込まない。途中状態の型の存在だけで ε を取り直すと初期の上限が失われるため、内部の StateTyE を使う。

本番の直接参照を S8 初版で数えた結果は次のとおりである。S8b では入力となる設計書・Rust・Lean・検査スクリプトの同一性を確認して引用する。`lean-inventory.py` は `git grep -n -w <語> <基準コミット> -- <対象>` を各語へ実行し、同じ基準の `git show` をコメント・文字列・自身の宣言名を除いて宣言ごとに集約する。対象は Release、Surface、Exchange、SurfaceCheck、Interval である。数は定理・lemma を数え、def・structure は別に記録する。

| 検索した群 | 定理数／ファイル数 | 読み方 |
|---|---:|---|
| `eq_of_sub_of_sub` | 5／2 | 直接の5件は `Eff.norm_ext`、`Eff.bind_comp_of_types`、`Eff.ext_canonical`（`Release/TypeComposition.lean:52・213・334`）、`union_empty_right_nested`・`union_empty_left_nested`（`Surface/Lemmas/Sequence.lean:351・358`）。構造上の包含を使う証明へ分ける |
| 上記と `Canonical`・`norm` | 149／39 | 例を除くと141／35。SAと一致。宣言の言明に直接現れるもの112件を含む。全部が変更になる数ではない |
| `io_op`・`io_typed`・`io_exists`・`effect_ops`・`io_kind`・`opEff_io` | 6／6 | 例を除くと5／5。直接呼び出しだけであり、進行・保存などの推移的な依存は別に点検する |
| `ioResponse`・`Event`・`E_IO`・`E_IOErr`・`E_Exit` | 6／5 | 観測の引数の変更を読む直接群。定義も含めると22宣言 |
| `NoHandler`・`name_end`・`end_of_noHandler`・`handled`・`HasTypeClausesQ`・`C_Handle`・`K_Handle`・`BuiltinOnly` | 89／29 | 節と継続の対象伝播を点検する群 |
| `eq_of_not_fn`・`eq_of_not_fn_left` | 15／4 | 非関数共変を避けて結論を保つ群 |
| `RangeState`・`RangeOrigin`・`RangeLocalFact`・`BindingScope` | 50／7 | 小さい共有基盤だけを使い、全体の移植を避ける候補群 |
| 全群の重複を除いた和 | 306／75 | 点検の母集団。変更定理の確定数でも、推移的依存の総数でもない |

宣言の一覧と行番号は `lean-inventory.md`・`.json`、grep の生結果は `lean-*.grep.txt` にある。言明と証明の区切りは最初の `:=` による字句上の近似であり、Lean の依存解析ではない。たとえば型構成子を match する定理は上の語を直接含まず漏れる。実際の変更数は骨格を型検査して初めて確定するので、この調べだけで「306件を書き換える」と見積もらない。

この母集団から、変更内容を名指しして計画へ渡せる優先対象は次の18定理である。これは最終の変更件数の予告ではない。IO・代入・範囲を格納する引数の変更で他の定理にも証明の修正が生じうる。

| 区分と数 | 既存定理の一覧 | 言明と証明の変更の見通し |
|---|---|---|
| 構造包含の根拠1件 | `Eff.eq_of_sub_of_sub`（`Release/Effect.lean:73`） | 前提を構造上の包含へ変更するか、同じ言明を別名の構造包含の名前空間へ移す。意味の包含の反対称性としては残せない |
| 上の直接利用5件 | `Eff.norm_ext`、`Eff.bind_comp_of_types`、`Eff.ext_canonical`、`union_empty_right_nested`、`union_empty_left_nested` | 構造の等号という結論を保ち、構造上の包含の補題を使う証明へ移す |
| IO契約の直接利用6件 | `no_event`（`Release/Lemmas/EffectSound.lean:39`）、`preservationE`（`PresMain.lean:18`）、`progress_io`（`Progress.lean:327`）、`step_soundE`（`StepSound.lean:102`）、`opSig_scoped`（`TySubstMain.lean:341`）、`assumptions`（`Release/Model.lean:61`） | io_opの分岐・具体化・観測の新しい場合と、モデルが条件を満たす証明を変える。前提をCoreAssumptionsへ分割すれば型表記にも変更が要る |
| 主定理と派生6件 | `Release.progress`、`Release.preservation`、`Release.effect_soundness`、`Surface.desugar_typed`、`Release.effect_soundness_noLamNames`、`Release.step_sound`（`Release/Theorems.lean:23`） | 表の結論を保つ。CoreAssumptions版を本体として全体Assumptionsからの互換の系を残す工夫は可能だが、同名hbの内容が以前と同じという主張にはしない |

骨格をレビューした時点で、この一覧と306件の母集団を「言明変更」「証明だけ変更」「点検のみ」に分類し直す。今は実行をしていないため、その三区分の正確な件数は未確認である。

主な補題群は、`Types.lean`・`Order/*`・`TypeSubst*.lean`・`TypeComposition.lean` の構造の等号、`Lemmas/Basic.lean` の Ty.Le、`TySubstMain.lean` の IO の neffs=0、`ContLemmas.lean` の name_end/split/resume_append、`Progress.lean`・`PresMain.lean`・`EffectSound.lean` の IO の場合である。共有する格納先と補題を先に決め、規則の追加ごとに型の巡回を繰り返さない。格納先の変更も既定ビルドを保つ小枝で行う。

### B4. 各枝の既定ビルドを保つ切り替えの順（Q14）

各枝の終わりで、既定の `lake build` が sorry なしで通ることを受け入れ条件にする。新しいモジュールも既定の入口から import し、別の入口だけの成功を代用しない。既存の主定理をビルド対象から外したり、空の表だけで済ませたりしない。これは今後の実装の条件であり、S8b・S9 ではビルドを実行していない。

未証明の theorem を先置きしないことは、sorry・独自公理・保証の仮定への移し替えの禁止から決まる。必要な将来の言明は Prop の定義としてレビューできるが、証明済みとは数えず、Builtins.Assumptions のフィールドにも入れない。旧 R22 のこの部分は決まっていることであり、Q14 は一般化版と Top の互換の系を先に置く方式に決定済みである。

推す切り替えは、旧の定義・定理を残し、一般化した補題と Top の互換の系を加え、利用側を小さく移す方式である。定義の引数を増やすだけで全旧証明が自動的に通るとはしない。共有型が変わる場合は、一般の型・評価・局所状態を旧名へ直ちに上書きせず、候補の名前空間に追加する。まず必要な定義と実証できる補題を閉じ、その上の証明を一群ずつ移す。各枝では変更した利用側と必要な補題を同時に閉じ、旧利用側は旧の定理を引き続き使えるようにする。

候補の一般化版は最終の本番へ移すものとし、SK のような別の小モデルだけを完成させてから本番を一度に壊す計画にはしない。型・効果・署名・評価の旧 Top への対応を証明し、移行の途中の Surface と交換は明示した変換を介して接続する。依存の全利用側が移った後の旧名の別名化・互換層の整理には、新しい証明義務を残さない。一般化の境界を分けられず30〜60分の枝で閉じないと判明したら、そこで分割と見積もりをやり直す。L20〜L40 を通すまで既定ビルドが失敗し続ける進め方は採らない。

| 順・枝の群 | 小枝で追加・切り替えする内容 | 各枝を閉じる条件 |
|---|---|---|
| L00 Lean の骨格の設計 | (i) 引数方式と (ii) 記述・表方式を比較。最終の対象分類・評価関係・抽象値・局所位置、Top 互換、署名の表、非空例、依存を決める | 既定ビルドを保ち、旧の主定理と追加した小補題が通る。定義・量化・信頼条件のレビュー。未実装の一般定理を成功に数えない |
| L10 対象の代数と旧構造の分離 | 最初に exact/one/many/tree/port と IPv4/IPv6 exact/CIDR の一般の定義を置き、所属・被覆・推移、構造 norm・和・代入の補題を小枝で追加 | 旧構造の等号の利用側を構造包含の補題へ一群ずつ移し、意味の相互包含を等号に使わない。変更群と旧利用側がともに通る |
| L20 一般の型と署名への段階的な接続 | 型の格納先・WF/shift/subst の互換、純検査と明示拡大の署名・所属補題、IOShape と節の S、観測を別々の枝にする | 変更した定義とその直接の証明を同じ枝で閉じる。新演算は表の項目として追加。未移行の利用側は Top の互換の系を使う |
| L30 Release の一般化した定理 | 値の代入、継続、ストア、IO・捕捉の各場合を順に一般化し、progress・preservation・effect、対象の一段・多段を閉じる | 旧の結論を保つ系も常に通す。非 Top の IO と別対象の節の例を閉じ、全体の対象健全性を仮定へ移さない |
| L40 Scope と Surface | 一般の局所状態へ成功・射影・忘却の表の項目を追加し、純検査、必須契約判定、検査器、脱糖を小枝で接続 | 本番で使う型と同じ R を渡すことを証明。移した利用側と旧 Top の利用側の両方が通る。範囲の追加ごとに評価関係の構成子を増やさない |
| L50 交換と移行の完了 | 読書き・独立入力を一入口ずつ移し、旧互換層を整理し、01-12・07-04 の写しと全体レビューを閉じる | 既定ビルド、全定義・言明・仮定のレビューを完了し、Rust 開始の前提にする。最終の別名化で新規の証明変更を要求しない |
| K10、V10 接続と候補 | Rust と全比較を接続し、最終の関係状態と候補を照合 | 全比較の成功または07-03に従う引用、回帰、実 CLI と同梱物の受け入れ。実装の対象一致はレビューの信頼条件として残す |

代案は、既存の定義を直接一般化し、影響する証明を同じ小枝で直す方式である。互換層は減るが、その枝で変更する定理群と閉じる時間を L00 で特定できる場合に限る。構成子追加を選ぶ場合も、B1 の件数見込みを根拠に、旧定義を残した一般化版から同じ順に移す必要がある。未証明の共有定義の一括切り替えは選択肢にしない。

01-12 の写しは規則を変える枝と同じ変更で直し、07-04 に移行状態と対応を記す。利用者向けに未実装の機能を実装済みとは書かない。Rust は Lean の全段の既定ビルドと定義・言明・仮定のレビューを終えてから始める。

### B5. Rust と Lean の交換・比較で増やす入力

現行の比較は既存六入口 `desugarDiff`・`builtinCheck`・`coverageDiff`・`coverageProgramDiff`・`surfaceCheck`・`surfaceCheckAll` と `intervalDiff` を使う（`formal/README.md`「検査」、`scripts/check-formal.sh:58〜165`）。小モデルの Lean 成功、既定ビルド、独立交換だけを全比較の代わりにしない。

| 増やすもの | 比較する契約と入力 |
|---|---|
| 原子と型 | Top、path exact/tree、host名 exact/one/many、IPv4/IPv6 exact/CIDR、port singleton/range、添字付き標準値型。型代入・行代入後の同じ構造と WF |
| 署名と操作同一性 | 閉じた R の具体化前後、neffs=0、入力の添字と効果、opEff と元 b、全操作の節の一覧。別名化でハンドラをすり抜けない |
| 包含と不完全性 | 含む・含まない・相互包含でも非等号、分割ポートの不完全性、Top、別種の対象、Fail/行との和、型・行代入の合成 |
| parser と正規化 | `*.` と `**.` の差、幹、`/data` と `/database`、大小文字、`.`・`..`、相対、末尾 `/`、IP 正規形・不正形・mapped・URLの括弧・CIDRのhost bitsとprefix端点、略記の展開・重複、逆転・範囲外ポート、引数数不正、二番目以降の uses と Fail |
| 成功由来 | 同じ Ok 値、別個体、保存一回、直接射影、再包装、別名、合流、未知関数、境界、予算停止。認定しない例も含む |
| Surface と脱糖 | R を保持する accepted、Top へ忘れて狭い契約で拒否する rejected、旧 API からの再検査、新しい純検査の型保存、ハンドラの別対象の IO |
| IO の観測 | 対象なし／あり、応答の成功／失敗、同じ要求の対象、追加対象の隠蔽の反例、新 sendIn の非追従。実ネットワークや外部への書き込みなしのモデル・偽の応答で照合する |
| 実装の接続 | 新標準宣言、Rust の型と eff の書き出し、認定した全関係定義の manifest、除外と予算、CLI と報告の対象上限 |

交換のタグ・具体化引数・必須欄を加える形式は版を上げ、旧形式を暗黙に狭い R として読まない。Surface の現行版14と区間の既存 profile を読んでから、新版・Scope 専用入力の所属を固定する。既存の区間の corpus へ必須の契約判定を警告として混ぜない。必要なら Scope 用の sidecar を追加するが、独立の対象の意味を二重定義しない。ソース上の文字列 parser と解析済みの Checked.Scope の証明の接続も比較対象にする。

成功件数だけでなく、原子の種類別、非 Top を得た件数、拒否と理由、忘却・予算停止、元のソースと Surface の同一性、全関係定義の収録を照合する。全 Top、空入力、深さ除外だけの一致を成功としない。新観測が IO 実装の実対象と一致することは引き続き信頼・実装レビューの条件であり、交換で Rust の全 IO を形式的に証明したことにはしない。

### B6. 共有分を分けた時間の見込み

以下は実測ではなく、LLM の設計・証明・実装・関係する検査の準備・文書・レビュー修正の**能動的な作業時間の見込み**である。ビルド・長い検査・別機の待ち、設計者の回答待ちを含まない。7 IO、PathIn・RequestIn の並存、非共変と明示拡大、節の単一原子の保持、非追従、旧 API から新型への再検査を前提とする。S9 は Q1 の略記・IP・CIDR を追加し、Q2 に従って移行文書を外した。Q9 の追加費用は含めず、[別の見積もり](user-effect-scopes.md) とする。

| 段のまとまり | Lean | 処理系 | S8b からの差と根拠 |
|---|---:|---:|---|
| 閉じた対象、one、IP/CIDR、原子・被覆の代数 | 11〜24時間 | 8〜19時間 | 旧6〜13/4〜10へ Lean5〜11、処理系4〜9を追加。B1のIPの5補題群を各1〜2時間程度と結合レビューで見込む。現行Checked.ScopeのHost/Endpointの成功・失敗・消去14定理は接続時の点検母集団。RustはIP正規形・CIDR3〜7時間、略記の構文とfmt1〜2時間 |
| 添字型・署名・具体化・観測の共有骨格 | 6〜14時間 | 6〜14時間 | Leanのみ1〜2時間追加。最初からhostの族を分け、endpointへの伝播と非空例を確認する |
| Release の値・継続・ストア・主定理・対象健全性 | 11〜26時間 | なし | CIDRは対象の代数へ閉じる骨格とし、旧幅を維持。主定理の書き直しを追加しない前提 |
| Scope の成功・必須判定、Surface・脱糖 | 13〜31時間 | 14〜33時間 | 両方2〜5時間追加。旧ScopeのIP拒否から受理への変更、RequestInの族・正規化・所属の対応 |
| 新 IO、HTTP の同一要求と非追従 | 上に含む | 11〜29時間 | Rust1〜3時間追加。URLの括弧とmappedの族を検査値から送信まで保つ |
| 交換・独立入力・Rust の書き出し | 6〜15時間 | 6〜15時間 | 両方1〜3時間追加。IP族・prefix・端点・異族拒否・略記展開後との独立比較 |
| 診断・型表示・JSON・CLI の射影 | なし | 7〜16時間 | Rust1〜2時間追加。略記中の位置・重複、IP/CIDR正規表示。allow-effectsは名前のまま |
| 回帰の準備、定義・仮定・全体レビュー修正 | 8〜21時間 | 4〜12時間 | Lean旧幅維持。Rustの旧5〜14から移行文書の1〜2時間を除く。IPごとの局所レビューは各行に含む |
| 合計 | **55〜131時間** | **56〜138時間** | 各行の下限・上限を一度ずつ加算。旧46〜110/48〜118から +9〜21/+8〜20時間 |

S8b の基礎は synthesis の案4（Lean33〜76/処理系34〜80）と Scope（Lean12〜28/処理系16〜36）の単純和から共有を引き、必須契約判定の差を戻した46〜110/48〜118時間である。SA・SK の対象代数、既存 Scope/Range の再利用と306定理の点検母集団は維持する。今回の差は実装量からの見込みであり、IP の本番証明が既に通ったという根拠ではない。略記をSurfaceより前で展開するため、略記専用のLean構文・脱糖の定理を追加する費用は置かない。展開と交換の照合はRust側へ置く。

本番の日本語仕様・通常の API 文書・Skill の説明には別に4〜8時間を置く。移行案内は含めない。独立小モデル6〜14時間、情報フロー制御の判断文書・棚卸し9〜18時間も別である。版・訳・CHANGELOG・候補の照合は末尾の作業にまとめる。

この見込みには、Q9、添字型の暗黙共変、和の完全な包含、OS の実体解決、IDNA、stream/listenの範囲型、redirectごとの検査、旧成功値からの無検査変換、HostIn・EndpointInの公開を含めない。IP完全一致・CIDRは含む。

30〜60分枠では、Lean55時間は55〜110枠、131時間は131〜262枠、処理系56時間は56〜112枠、138時間は138〜276枠になる。全体でそれぞれ262番号・276番号を予約し、実際には閉じた枝の粒度で選ぶ。算術と旧表との差は [`work/m013/scratch/S9/time-budget.json`（写し）](../evidence/work-copies/m013/scratch/S9/time-budget.json) に保存する。L00とIPの最初の短い枝の実測後に取り直す。検査・測定の待ち時間は C3 のとおり不明である。

## C. 実装プランの段と作業の案

### C1. 段とレビュー

次は [change-plan-template「段とレビュー」](../../../workflow/change-plan-template.md#段とレビュー) の形を使った段の案であり、実行の依頼ではない。`L10.01〜.08` のような ID は、各30〜60分の作業枠を表す。複数枠を一つの巨大な作業として取り込まない。正式な計画では担当する定義・補題・場合・読者・検査を各 ID に列挙する。証明が60分で閉じなければ、その時点で未解決の補題と依存を記録し、同じファイルを複数の担当が同時に書かない形に分け直す。

| 段 | 作業と予約枠（各30〜60分） | 先行条件と接続 | レビューと完了条件 |
|---|---|---|---|
| 0 判断と照合の引継ぎ | D00.01〜.04: Q9の判断、7入口とIPの細則、勧告の記録、形式化の内外 | S9 と README の決定。開始版3597b310、調査HEAD04c78e52 | 既存 security-advisories.md の照合・未照合・設計者の「組み込まない」を入力ハッシュとともに確認。D1・D9 の対応を確定 |
| 0 Lean の骨格の設計 | L00.01〜.16（30分換算8〜16枠、4〜8時間）: 格納先と表の比較、Top 互換、評価関係・抽象値・局所位置、非空例、依存と変更件数の分類 | 決定Q1〜Q8・Q10〜Q14。Q9を別作業へ分けるかの判断。新中心定義と旧証明の境界 | 最初の枝から既定ビルドを保つ。候補の小補題と定義・言明・仮定をレビューし、小枝の移行順を確定 |
| 1 対象・原子と構造の補題 | L10.01〜.48（30分換算22〜48枠、11〜24時間）: exact/one/many/tree、IPv4/IPv6・CIDR、port、所属、構造包含と被覆、norm・和・代入 | L00。旧構造等号の利用側を一群ずつ移す | 各小枝で既定ビルド。意味と構造の混同、one の差、区間の不完全性をレビュー |
| 1 型と署名への小枝の接続 | L20.01〜.28（30分換算12〜28枠、6〜14時間）: 型の互換、WF・代入、署名の表、明示拡大、元 b、節の S、IOShape、観測 | L10 の必要な補題。未移行の利用側は旧互換を使う | 定義と直接の証明を同じ枝で閉じ、既定ビルドを保つ。全共有定義を一度に上書きしない |
| 1 Release の証明 | L30.01〜.52（30分換算22〜52枠、11〜26時間）: 値・代入・継続・ストア、progress・preservation・effect、対象の一段・多段 | L20 の必要な一般化補題から順に接続 | 各小枝で旧主定理と移行済みの一般定理が通る。結論と信頼条件、非 Top の例をレビュー |
| 1 Scope と Surface | L40.01〜.62（30分換算26〜62枠、13〜31時間）: 標準認定と局所位置、成功・射影・忘却、予算、必須判定、check・脱糖 | L10・L20 の必要部分。最終本番接続はL30 | 小枝で既定ビルド。後段の警告を必須の受理条件へ流用せず、旧成功の無検査の型変更を加えない |
| 1 交換と閉鎖 | L50.01〜.56（30分換算20〜56枠、10〜28時間）: 交換6〜15時間＋骨格以外の全体レビュー修正4〜13時間 | L30・L40。各入口を順に移し、旧互換層を整理 | 各枝と最終の既定ビルド、01-12・07-04、定義・言明・仮定のレビューを完了。Rust全比較はK10 |
| 2 Rust の構文と型 | R10.01〜.66（30分換算28〜66枠、14〜33時間）: 略記の展開・fmtの保持、IP/CIDR、型・原子・包含、署名 | Lean全段完了。B6の対象8〜19時間＋骨格6〜14時間 | 新しい型の接続、旧構文と不正注釈をレビュー |
| 2 Scope の必須判定 | R20.01〜.66（30分換算28〜66枠、14〜33時間）: 認定・局所位置、成功・射影・忘却、予算、制約 | Lean全段とR10の型 | 型判定とRange警告の受理条件を分け、予算停止を狭い型の根拠にしない |
| 2 IO と旧APIの挙動の照合 | R30.01〜.58（30分換算22〜58枠、11〜29時間）: 生成・射影、明示拡大、File6入口、RequestIn、誤り型、sendIn、IPの実効host、非追従 | R10・R20、LeanのIO契約 | File と HTTP を別に接続レビュー。対象と呼び出し、旧節の不足と効果表示の差を照合 |
| 2 診断と機械向け表示 | R40.01〜.32（30分換算14〜32枠、7〜16時間）: E0513/19/20、由来、bounds、CLI | R10以降の契約 | 任意欄、Top、未完了、契約拡大を区別して示す |
| 3 Rust/Lean の交換 | K10.01〜.30（30分換算12〜30枠、6〜15時間）: 書き出し、新版、独立入力、実ソース、manifest、全比較 | R10〜R40 | 六入口・intervalDiffと全関係定義の全比較を通し、全Top・空入力・除外だけの成功を拒む |
| 4 全体と候補 | V10.01〜.24（30分換算8〜24枠、4〜12時間）: 回帰準備、レビュー修正、shortの比較、候補との照合 | K10、並行文書と小モデル。検査待ちは別 | change、最終全比較の実行か引用、候補releaseと手動受け入れ。版・訳・CHANGELOG・最終照合を末尾作業に集める |

括弧内は各段の下限・上限を30分枠へ換算した値である。60分枠へまとめる場合は番号を減らす。Lean は L00〜L50 に262番号を予約し、B6 の55〜131時間を55〜262枠で収める。L00 の4〜8時間と L50 の全体レビュー4〜13時間は B6 のレビュー8〜21時間を分けたものである。処理系は R10〜R40・K10・V10 に276番号を予約し、56〜138時間を収める。移行案内の削除は V10 の旧5〜14時間から1〜2時間を引く形で一度だけ計上した。

上表の時間は B6 の能動作業の内訳であり、ビルド・全比較・測定の実行待ちは C3 に別に記録する。各枝は一つの番号または必要ならさらに分けた番号で閉じ、30〜60分の枠を超える見込みなら先に分割を改める。予約容量があること自体は、各証明がその枠で閉じる証拠ではない。小枝が閉じるまでは次の本番利用側を前提にせず、見込みの2倍を超えた時点で調べて報告する。

V10 の末尾作業の30〜60分は、版・生成文書・訳の差分を準備した後の最終照合の目安である。実際の翻訳量は未集計なので、その一作業が必ず60分以内と約束しない。正式計画では変更量を数え、必要なら同じ末尾の作業の見込みを改めて示す。検査の待ちや公開候補の受け入れ待ちは作業時間と別に記録する。

### C2. 本番を変えない並行作業

S8 初版が docs/todo の TODO-256 を読んだ範囲は第一項と第三項である（`security-and-quality.md:591` 見出し）。原文の2026-10-17の「小さい」「安い」は時間の測定ではない。次の時間はこの調べで新たに置く見込みである。

| 並行作業 | 段と作業 ID（各30〜60分） | 内容・受け入れ | 見込みと根拠 |
|---|---|---|---|
| TODO-256 第一項 | 段0〜1、P10.01〜.06 | 宣言上限⊆方針と、事象⊆宣言上限から、事象⊆方針を導く独立の系。非空例と許可不足の反例。本番の証明が終わるまでは本番への接続済みとしない | Lean1〜3時間。包含の推移の短い系、既存定理との対応を書く作業 |
| TODO-256 第三項 | 段0〜2、P20.01〜.12 | 抽象対象述語で allow/deny、deny優先、追加方針の共通部分による狭小化、空対象と種類判定の分離を証明。parserや実サーバを作らない | Lean3〜6時間。三性質の定義・補題と、追加方針を和にする誤案の反例 |
| 上の小モデルのレビューと記録 | 段1〜2、P30.01〜.10 | 定義・量化・仮定・例・既存との対応をレビューし、独立した範囲として記録 | 文書・レビュー2〜5時間。2モデルと各性質を読む時間 |
| D2〜D9 の判断の文書 | 段0から、F10.01〜.16 | questionsの各選択肢と推す答え、SDの条件、典型例の受理表、方針の所有・版・承認、非機密化（declassification）とエンドースメント（endorsement）の契約を具体化。設計者が選ぶ | 4〜8時間。8判断を各30〜60分として置く。回答待ちは別 |
| 入口・出口と Secret の棚卸し | 段0〜2、F20.01〜.12 | File/Http/Console/Process、表示・JSON・ログ・die・テスト失敗・機械向け診断を、入力の分類・出力・未対応で表にする。D3/D4/D6/D8へ戻す | 3〜6時間。既存IO表と表示経路の2群の読解・典型例の照合。件数は正式な棚卸しで固定 |
| 判断の引継ぎのレビュー | 段2〜4、F30.01〜.08 | 採択後のD2〜D9をdocs/todoのTODO-269・154・109へ写す作業を正式計画へ割り当てる。設計書へ未実装機能を写さない | 2〜4時間。判断表・受理表・行き先の整合の3群 |
| TODO-287 の任意の小モデル | 段0から独立 | SH2はREADMEに結果があり、同じ試作をやり直さない。結果と未接続範囲を読む任意のレビューにする | 追加レビュー1〜2時間、1〜4枠の候補。実験は既に済んだ記録として扱い、旧75〜155分を未着手予算へ再加算しない |

TODO-256 の小モデルは Lean4〜9時間、文書・レビュー2〜5時間、合計6〜14時間の見込みである。第一項の種類だけの系と、第三項の `Allow(k,t) ∧ ¬Deny(k,t)` のモデルを分ける。方針にその種類の記載があるが対象集合が空なら、種類だけの実行前判定は通り、対象の実行時判定は通らない。これを対象のない純粋な計算と同じにしない。

第二項の「実行時の権限拒否による停止」は本番に入れない。第四項の範囲型の本番変更は案4の対象健全性として中心に含まれており、小モデルへ二重に数えない。小モデルは非干渉性、実行時拒否の漏れ、OS の強制、デーモン、IPC、秘密、言語サーバ、MCP の証明ではない。D2〜D9 の文書・棚卸し・引継ぎは合計9〜18時間の見込みであり、B6の本番実装と別に置く。

### C3. 正式計画で割り当てる検査・測定・受け入れ

この S8 では次の検査を実行していない。正式な計画は開始版を固定し、各作業の末尾で同じ基準の dry-run を先に確認する。前の作業の取り込みを基準にする work を各一度、接続のある stage を名指しし、改造全体の change と実候補の release を割り当てる。具体的なコマンドは計画の「検査の割り当て」に一度だけ置く。

| 検査・測定・受け入れ | 割り当て | 見込み時間と扱い |
|---|---|---|
| 既定Leanビルド、sorry拒否、定義・言明・仮定と公理依存のレビュー | 最初のL00を含む各小枝とL50。Rustの開始条件 | 実時間は不明。最初の骨格候補とTop互換の小補題で測り直す。能動作業はB6に含む |
| Rustのlib全件、関連する統合テスト、clippy、fmt | R/K各作業末のwork。形式化や文書だけの作業にRust全libを加えない | 実時間は不明。最初の関係作業の記録から見積もる |
| 新入口・型の生成と捕捉、成功値のScope判定、型表示/JSONの接続 | 該当R作業の直接検査とstage | 実時間は不明。必須の型判定と任意の区間警告、非Topの件数を別に確認 |
| compile_failを含むdoc、局所heap-verify/gc-stress、必要なcheck-heap | 新値表現や安全点を越える値の保持を変えるR30。次の作業の前提にする前 | 実時間は不明。既存レコード表現の再利用で不変条件を変えない場合は、対象外の理由を計画へ書く |
| 六入口・intervalDiff・独立交換・manifest・全関係定義の全比較 | K10と最終の関係状態。後者は07-03の引用条件を満たす場合のみ引用 | 実時間は不明。Leanビルドや局所比較で代用しない |
| 最適化したビルドでの深い再帰（release_stack）、既定/heap/stress構成、長い対象、二構成lint | changeと候補release、重なる単位は同じ状態の証拠を引用 | 実時間は不明。実候補の関係状態との一致を受け入れ条件にする |
| 処理系取り込みごとのshort性能比較、必要なtargets/full | 少なくともRの段の区切り、公開準備より前 | shortはbenchmarkの手順。長い測定は短い試行で見積もり、範囲と時間を示して了承を得る。今回測定しない |
| 候補の二lockとRust/Cargo/Lean/elanの勧告、版・生成物・Skill・訳・実CLI・配布の照合 | V10、実際の候補で判定 | 実時間は不明。勧告あり/未照合は記録して設計者へ報告し、勧告だけで検査失敗や受け入れ停止にしない |
| 設計者の判断と最終受け入れ | D00、Fの判断表、V10の候補照合後 | 回答待ちは不明。終了0だけで受け入れ済みとしない |

形式化の検査の待ち時間や全比較の実時間を B6 の能動時間へ重ねて見積もらない。長い検査の所要時間は、この調べで実行を禁じられているため不明である。実装プランの確定時に、既存の同等な記録を読んで引用の可否を判断するか、最初の短い試行へ時間上限を置く。各作業の見込みの2倍を越えたらその時点で原因と残りを報告する。

## 決まっていること

次は既存の規則・README の決定・今回の指示から導ける条件であり、設計者に同じ判断を求めない。実装方法のレビュー案まで採択済みとする表ではない。

| 旧 R 番号・出どころ | 決まっていること | 導ける理由・根拠 |
|---|---|---|
| 旧 R12 | 局所の由来が不明なら Top に戻し、狭い注釈だけを根拠に受理しない | 静的な契約への適合を保証する 00-01 の原則1・2と、README の閉じた範囲の方針による。全動的値を拒否する必要はなく、認定した検査成功から狭い値を作れる |
| 旧 R13 | トップレベル関数の引数・結果・エフェクト契約を明示する | 01-02:142 と01-06「型注釈」の既存規則による。局所の推論を公開契約の自動変更に広げない |
| 旧 R15 | Scope・IO・Network の Unofficial の所有元と import を保つ | 03-06:82〜90 の現行境界を維持する。今回の対象は範囲の導入であり、名前空間の移行を含める決定はない |
| 旧 R18 | 同名の異なる範囲と冗長原子を保持し、型の等号を意味の包含で置き換えない | README P2 の扱い1から導く。norm は構造の重複だけを除き、明示した同一原子の重複は既存どおり診断する |
| 旧 R20 | 既存の信頼条件と新しい対象一致の条件を明記し、どの定理が何に依存するかをレビューする | README P1 と07-04「形式化で仮定するもの」に従う。CoreAssumptions と TargetAgreement の分割は B2 の計画レビュー案であり、構造体の分け方を利用者の選択にしない。io_op の内容の変更は明記する |
| 旧 R22 の証明穴の扱い | 各枝の既定ビルドを sorry なしで通す。未証明の結論を公理・仮定へ移さない。Prop の定義は証明ではない | AGENTS.md と07-04の形式化の順序、今回の重1への指示から決まる。切り替え戦略は決定Q14に従う |
| README の名前全体のハンドラ | 名前を除くのは全操作の節があるときだけで、節自身の IO は出力へ加える | README の決定と01-06:592。sendIn を追加すると旧 send 節だけでは除けない帰結は A7 に示した。新操作を加え、移行案内は作らない決定Q2 |
| README P1・版の割り振り | io_target を実装との一致の信頼条件として明記し、対象健全性を導く。情報フロー制御の実装は0.0.14 | P1、版の割り振り、訳語の決定による。0.0.13ではD2〜D9と棚卸しを行い、非干渉性の保証や実行時の許可を先取りしない |

| 決定 Q 番号 | 決まっていること（2026-10-27） | 本文・理由 |
|---|---|---|
| Q1（旧R1・R2・R4、中5） | 角括弧、複数対象の略記、値型は一範囲。IP完全一致・CIDRを認める | A1・A2。LANのHTTPでIPの直接指定が必要。細則はS9の案 |
| Q2（旧R9、重2） | 7入口を新操作として追加する(a)。0.1.0公開までは移行案内を一切書かない | A4・A7。現在の利用者は設計者だけ。表示の広がりは事実として残す |
| Q3（旧R3・R19） | 正規化したAPI引数の字面を上限にする | A2・A8。純粋な検査を保ち、実体の解決を保証へ加えない |
| Q4（旧R6・R7、中2） | 新型を並存、不変、失敗しない明示拡大 | A4。Ty.Leを保ち、狭小化は再検査 |
| Q5（旧R8、中3） | 新検査は標準の直接呼び出し、リテラルと既知のconst。間接・pipeからは狭くしない | A4・A5。既存の認定と予算に合わせる |
| Q6（旧R6・R9、中4） | 初段の公開型はPathIn・RequestInだけ | A4。host/endpointの中心定義は先に用意する |
| Q7（旧R10・R11、中4） | 同じ要求を保存、非追従、専用RequestCheckError | A4。対象一致と検査・通信失敗を分ける |
| Q8（旧R23、中1） | 保護本体の同名の閉じた一原子Sを節へ保持。複数・Top・未確定行変数ならTop | A6。同じ値の所属と被覆の専用補題を使う |
| Q10（旧R21） | host/portは両schemeの保守的上限、originのschemeは別契約 | A8。https限定をhost/portだけで認定しない |
| Q11（旧R16・R17） | allow-effectsは名前だけ、expandedを保ち任意boundsを追加 | A1。旧受け手も種類の上限を保つ |
| Q12（旧R5、中5） | 名前が要求する引数の種類でE0513/E0520を分ける | A3。File.Write[Integer]はE0520、Failure.Fail["x"]はE0513 |
| Q13（旧R5） | 新E0519と理由欄。範囲外と包含未確認を分ける | A3。和の不完全性から反例を断定しない |
| Q14（旧R22、重1） | 一般化版とTopの互換の系を加え小枝で移す | B1・B4。各枝で既定ビルドを保つ。直接修正が小さく閉じる部分は計画レビューで例外にできる |

## 設計者への問い

未決は Q9 だけである。他の Q の回答は上表へ移した。

| 番号 | 問い | 比較・見積もり | 推す案 |
|---|---|---|---|
| Q9（旧R14） | 利用者が定義するエフェクトに、標準種類の範囲引数だけ、または型引数と範囲引数を認めるか。0.0.13へ入れるか | [user-effect-scopes](user-effect-scopes.md) の三案・形式化の件数・時間・最後の選択肢を参照 | 0.0.13は(c)を保ち、後で(a)を独立の改造として検討する。後で入れるための骨格の余地だけを今確保する。費用と制限は同文書を正とする |

## 未確認の事実

| 番号 | 未確認の事項 | 計画での扱い |
|---|---|---|
| U1 | 新構文・診断からの修正のLLM成功率、人間の読みやすさの実測、日本語のindexed effectsの別の定着名 | 今回は仮説と既存用語で記す。LLM評価は別途了承が要る |
| U2 | 新しい範囲具体化、型巡回、io_targetの観測、四定理とSurfaceの接続を本番Leanで通せること | 実行禁止のため未試行。骨格・証明・sorryなしビルド・定義と仮定のレビューをRust開始の前提にする |
| U3 | SA/SKの木から本番のhost oneへの移植と全包含補題の成立 | ソースの差は確認したが新しい証明は実行していない。段1で閉じる |
| U4 | 新純検査の成功と添字型のdelta_typed、旧成功由来からの再検査、新IOの実対象の一致 | 新APIは未実装。標準署名、所属、実行器、偽の応答の接続で検証する |
| U5 | 新sendInのURL parserと正規化のRFCとの一致、ureqの数値hostの受理集合、mapped IPv6のparser/display、非追従、追加の対象を隠さないこと | IP正規表示と既定ポートの外部規範は確認済みだが、新実装は未試行。zone ID/IPvFutureは初段から外す細則案であり、link-local IPv6に必要なzoneの指定は扱えない。HTTP入口のレビューと検査へ割り当てる |
| U6 | 各OS・大小文字を区別しないファイルシステム・未作成の対象・リンク変更・DNS/IPの実体との一致 | OPEN-057の経緯と同じ未確認を維持。0.0.13で実体の隔離を宣言しない |
| U7 | 外部の完全ハンドラと、別名も含む通常文書・生成物の更新の最終件数 | 開始版の14ファイルの検索では全操作ハンドラ・Http.send節は0件。翻訳と検討文書も別記した。名前解決を伴う全件棚卸しと外部コードは未確認であり、D00で更新先を固定する |
| U8 | 組込みの各Cargo構成と32ビット環境での実ビルド・実行 | 意味を構成で変えない設計条件を先に置き、対応構成を正式計画の検査へ指定する |
| U9 | Lean55〜131時間・処理系56〜138時間、独立小モデル6〜14時間、文書9〜18時間の実際の所要 | すべて工程からの見込み。短い骨格作業で取り直し、待ち時間は別に計る |
| U10 | 最終の全比較、heap、回帰、性能比較、候補の照合の所要と成功 | この調べでは未実施。C3の担当・段へ割り当て、過去の実行を無条件に成功引用しない |
| U11 | 手元の0.0.12バイナリが今回のHEADと同じソースから作られたこと | ビルド識別子が異なるため確認できない。現行の根拠はHEADの設計・Rust・Leanの読解とし、保存したCLI例をHEADの検査結果にしない |

未実装の提案を確かめた事実へ書き換えず、上の未確認を残して実装プランの判断と受け入れへ渡す。

## RV-S8 への対応

以下は S8b 時点の対応記録である。Q1のIP拒否・略記なしとQ2の移行案内、Q9、見積もりは末尾のS9の表と現在の本文が優先する。RV-S8.md は変更していない。以下の「採用」は文書の指摘への対応を意味し、設計者による提案の採択や新実装の検証完了を意味しない。

| 指摘 | 対応した箇所 | 対応・採らなかった案と理由 |
|---|---|---|
| 重1：Lean の骨格と切り替え | B1・B4・C1、Q14、決まっていることの旧R22 | 採用。最初に最終範囲を見越した骨格の比較を置き、既存構成子の引数と標準署名の表を推す。一般化版とTop互換から小枝で移し、各枝の既定lake buildをsorryなしで通す。一括の型構成子追加・L20〜L40の未ビルド状態は撤回した |
| 重2：既存ハンドラと表示の拡大 | A7、Q2、U7 | 採用。Http.Connectがsendだけである根拠と、sendIn追加で旧節が部分ハンドラになる帰結、一覧・allow-effects・後の承認表示の差を明記。(a)移行案内、(b)表層での節の合成、(c)既存操作の具体化を比較し(a)を推す。b/cは互換性の利点を残した選択肢とし、追加の脱糖・署名対応の証明を理由に初段の推奨にしなかった |
| 中1：Topの節で転送の精度を失う | A6・B1〜B4、Q8 | 採用。本体εに同名の閉じた一原子だけがあればそのSを節へ渡し、複数・Top・行変数ならTopとする案を推す。一般の値型共変とは分け、所属と被覆の専用補題を追加する |
| 中2：不変の添字と再検査 | A4・B1・C1、Q4 | 採用。失敗しない明示の拡大を比較に加え、静的な被覆で受理する案を推す。狭小化と不明な包含は再検査に残す。Ty.Leへの暗黙共変は推さない |
| 中3：patternとconst | A4・A5、Q5 | 採用。既存評価で既知のconstの直接参照を認める案と、pipe・間接呼び出し等の制限を明記。範囲注釈内のconstへは広げない |
| 中4：HostIn・EndpointIn、検査の誤り型 | A4・B6、Q6・Q7 | 採用。初段の公開型はPathIn・RequestInに絞る案を推す。checkRequestInはRequestCheckErrorでURL不良とScopeErrorを分け、通信失敗のNetworkErrorと区別する。両追加型や他の誤り型は比較の選択肢に残した |
| 中5：EBNF・診断の境界・fmt | A1・A3、Q1・Q12 | 採用。範囲引数のEBNFを加え、File.Write[Integer]をE0520、Failure.Fail["x"]をE0513とする案と代案を比較。影響章に06-03を加えた |
| 中6：時間と枠数・開始版 | 基準、B6・C1、C2 | 採用。開始版を3597b310とした。46時間は46〜92枠、110時間は110〜220枠。Lean220番号、処理系236番号を予約し、B6の各行と対応させた。並行文書・小モデルの予約不足も同じ規則で直した |
| 軽1 | A6 | 採用。List.bnt:68を:67へ修正した |
| 軽2 | A3 | 採用。split_not_subの参照をSA.lean:1231へ修正した |
| 軽3 | A4 | 採用。Release/Lemmas/Basic.lean:88・94へ修正した |
| 問いにしなくてよいもの・統合・不足・重さ順 | 決まっていること、Q1〜Q14 | 採用。旧R12・R13・R15・R18・R20とR22の証明穴禁止を理由付きで移した。R22の戦略はQ14。旧番号の対応と利用者に見える差を全14問に加え、構文・互換性・API→診断と表示→形式化の順に並べた |
| 訳語の指示 | 基準、A8、C2、決まっていること | 採用。非機密化（declassification）、エンドースメント（endorsement。信頼の付与、または完全性レベルの引き上げ）を使い、初版の「原語で書く」を撤回した |

指摘自体を不採用にしたものはない。指摘で挙がった代案のうち初段に推さないものは、上表と各問いに理由を残した。追加の根拠は [`work/m013/scratch/S8b/`（写し）](../evidence/work-copies/m013/scratch/S8b/) に保存した。S8b の受け入れは本文・根拠の静的な点検までであり、提案するLean・Rustのビルドや動作の検証は行っていない。


## 設計者の決定の反映（2026-10-27）

| 決定・依頼 | 反映した箇所 | 変更と確認の範囲 |
|---|---|---|
| Q1の略記 | A1・B5・B6・C1 | EBNFをエフェクトの反復と単一の値型に分離。Rustの構文解析で展開しSurface/交換には持たせない。重複と元の位置の診断、fmtの略記保持を具体化した |
| Q1のIP完全一致・CIDR | A2・A4・A7・B1・B4・B5 | IPv4/IPv6の正規形、URLの括弧、mappedをIPv6に保つ扱い、host bitsの拒否、異族・ホスト名との非包含、DNS非解決を記した。細則は推奨案であり、標準と独自制限を分けた |
| 旧Scopeとの一致 | A2・B4・C1 | checkHost/checkEndpointのIP拒否から受理への変更を旧APIの振る舞いの変化と明記。Lean/Rust/仕様・既知定数の診断の対応を割り当てた |
| CIDRの形式化 | B1・B4 | 幅32/128の数値、prefixの整列、閉区間の包含、Nat/Finの境界証明を分けた。最初の骨格に両族を含め、64ビットのポインタ幅を前提にしない |
| Q2(a)、移行案内なし | A7・B6・C1・C3 | 新操作追加と表示の広がりを残し、移行文書・移行例の作業を外した。Leanの内部の切り替えは継続する |
| Q3〜Q8・Q10〜Q14 | 決まっていること・各A/B節 | 採択済みと明記し問い表から移した。比較の記録と実装方法の案を残し、未検証の実装を事実には変えなかった |
| Q9の見積もり | A6・問い表、user-effect-scopes | 標準の範囲引数のみ・型も追加・現状維持を別文書で比較。Q9だけを問いに残した |
| 見込みと枠 | B6・C1・U9 | Lean55〜131時間/262番号、処理系56〜138時間/276番号へ更新。追加と削除の差、算術をS9に保存。Q9の追加費用は含めない |
| 静的な受け入れ確認 | S9の記録 | 許可された二文書とscratchだけを変更。参照・表・見積もりを読解と集計で確認。ビルド・テスト・Lean実行・評価は行っていない |


## V10.3d の参照先の整理（2026-10-30）

上の旧配置・実行コマンドは当時の記録として保持する。現在参照する保管物は次のとおりである。同名の文書が後の改訂を含む場合は当時の原本と区別し、V10.3d の複写不足・来歴ハッシュの照合を正とする。機械の来歴のキーや記録済みハッシュは変更していない。

| 当時の参照先 | 保管した写し（本書からの相対リンク） |
|---|---|
| `work/m013/scratch/S8/` | [evidence/S8/lean-inventory.md](../evidence/S8/lean-inventory.md) |
