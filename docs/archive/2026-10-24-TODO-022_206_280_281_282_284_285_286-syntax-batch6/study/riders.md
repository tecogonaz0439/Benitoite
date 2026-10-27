# 相乗りの四項目の調べと判断の案

2026-10-24、S2（RV-S2 を受けた S2R の修正を含む）。判断は案であり、設計者の決定は [README](../README.md) を正とする。作業条件は `work/m012/common.md`、調査した開始版は `6ecc9996747db03801004ebee6c38a5283b590a7`（v0.0.11）である。設計原則の番号は 00-01「設計原則」による。

## 判断案の一覧と調査の限界

| 対象 | 推す案 | 互換性 | Lean への影響 |
|---|---|---|---|
| docs/todo の TODO-206 の残り | A'。文書・Skill の例に加え、既定書式の純粋な `formatRecord` を公開する。ファイル／JSON の出力自体は既存 API で書ける | 公開 API を一つ増やす。既存コードの意味と型は保つ | 定義・定理・公理は変更しない見込み。生成参照の再生成と交換の接続の確認が必要 |
| docs/todo の TODO-280 | Property／JSON の生成を preview で拒否し、Show／Order だけなら受理する。JSON の拒否は README の範囲を広げる承認待ちの案。生成器の版は上げない案 a を推す | 生成を受理する入力は狭まる。a では無関係な現行記録の一律移行と、この項目を理由とする E0908 を増やさない | 型・エフェクトの規則を変えず、道具の事前検査で扱う |
| docs/todo の TODO-281 | 計画前の短い比較で増分が30秒以下なら、新水準の `lint_default` に常に `--examples` を足す案 A。旧指定の実行集合は保つ | work／change の検査対象が増える。言語・CLI の互換性は変えない | 検査の運用だけである |
| docs/todo の TODO-282 | 01-03 には言語の版の規則を残し、版ごとの登録内容と具体的な移行案内は 06-09 に集める | 文書の移動だけである | 形式化の対象となる規則の変更なし |

四項目を上記の範囲で進める限り、Lean の定義・定理の変更を必要とする問題は、確認できた範囲では見つからなかった。A' の公開後の交換の接続は未確認である。Log の通常の操作・ハンドラの型付けは形式化済みであり、今回変更しない。リソースの捕捉を特例で許す、ハンドラで出力先のエフェクトを消す、生成関数をファイル単位の宣言から除く、といった案へ広げるなら、相乗りの前提を外れる問題として設計者へ戻す。

今回はソース・設計書・既存テスト・Lean・docs/todo を編集していない。ビルド、Cargo のテスト、`scripts/check*.sh`、`lake build`、性能測定、LLM の評価は実行していない。S2 が実行したのは既存の `target/debug/benitoite` による小例の `check`／`run` と、その出力の読み取り確認である。S2R では再実行せず、保存した入力・出力・ハッシュとソースを読み取った。後述する selftest の変更・検査と公開後の確認は実装段階の案であり、実施済みの結果ではない。

## TODO-206: 開いたファイルと JSON の出力先

### 現在の仕様と実装

| 確認対象 | 現在の契約と根拠 |
|---|---|
| Log の操作と記録 | `Log.emit(record: Log.Record) -> Unit` と `Log.enabled(level: Log.Level) -> Boolean` の二操作を持つ。記録は水準・メッセージ・属性列・明示した位置である。`Log.Value` は Text／Boolean／Integer／UnsignedInteger／Float。属性列は順序と同じキーの重複を保つ。03-07「Log と SourceLocation」、`src/prelude/stdlib/Log.bnt:5–43` |
| 既定の出力 | 未処理の操作だけを扱い、Info 以上を stderr に一記録一行で出す。Log は `IO.All` と独立しており、既定出力のための `Console.Write` は要求しない。`src/builtins/funcs/log.rs:8–32` と 03-07 の同節。Error の水準も終了を意味しない |
| `withAttributes` | 共通属性を記録の属性の前へ足し、両操作を外側のハンドラへ送り直す。Log を消さない。`Log.bnt:162–169` |
| `withTextLogger` | 両操作を処理し、最低水準以上を既定と同じ書式で stderr へ出す。`Console.Write` が残る。既定出力と共有する `formatRecord` は非公開である。`Log.bnt:158–182`、`builtins/funcs/log.rs:42–46` |
| `withSinks` | `List[Pair[Level, function(record: Record) -> Unit uses E]]` と、`Log, E` を持つ本文を取り、結果に E を残す。受理する出力先を列順に一度ずつ呼ぶ。enabled は受理する出力先があれば真。空列は偽を返し記録を捨てる。失敗・停止は後続の出力先より先に伝わる。`Log.bnt:185–197`、03-07 の同節 |
| File と解放 | `openWriter` は `File.Write`、`writeLine` も `File.Write` であり、いずれも `Result` を返す。`with` の解放は State。`src/prelude/stdlib/IO/File.bnt:57–89`、`src/builtins/funcs/file.rs:1103–1159,1173–1235`、03-07「File」、01-10「リソースの型」「解放の時期と順序」 |
| リソースの捕捉 | ラムダに捕捉できる。ただし `with` の解放後に使うと実行時エラーになる。捕捉しただけで寿命が延びる規則はない。01-10「解放したリソースの使用」 |
| Json | `Json.stringify` は純粋で、整形用の改行を入れない。文字列中の LF・引用符等はエスケープする。`Json.Value.Object` の Map には順序付きの重複属性をそのまま保存できない。`src/prelude/stdlib/Json.bnt:5–34`、`src/builtins/funcs/json.rs:393–434`、03-08「Json」 |

上の `src/` はすべて `crates/benitoite/src/` からの相対パスである。出力先の関数型の引数名は `record` であり、名前付き関数型の既存の契約に従う。標準ハンドラはすべて通常の `handle` と `resume` で書かれている。

利用者向けの説明も、この契約と一致している。英語リファレンス `docs/reference/benitoite.md:1123` は、withSinks の順序・失敗の伝播・出力先のエフェクトの残存を説明する。同梱 Skill の `SKILL.md:168` は、Log の許可、enabled による高価な構築の抑制、三つのハンドラを要約する。生成参照 `skill/references/stdlib/Log.md:104–116` は三関数の型を示す。手書き参照 `skill/references/idioms.md:878` 以降は、Log／位置とファイル単位の宣言を案内するが、開いた Writer を捕捉する例と JSON の出力先の例はない。

### 実際の check／run

作業ディレクトリをリポジトリの根として、S2 は `work/m012/scratch/s2/` に次の例と出力を保存した。S2R では git で除外されない [riders-probes/](riders-probes/README.md) に入力・出力・確認記録を写した。実行ファイルの表示は `benitoite 0.0.11`／`Unicode 17.0.0` である。入力・実行ファイル・出力の SHA-256 は [output-verification.json](riders-probes/output-verification.json) にある。

| 例 | check | run | 観察した出力 |
|---|---:|---:|---|
| [file-sink.bnt](riders-probes/file-sink.bnt) | 終了0、0.127秒 | 終了0、0.156秒 | `file-sink.txt` は `first` と `second` の二行。Debug は出さない。既定書式の再現を確認したものではない |
| [json-sink.bnt](riders-probes/json-sink.bnt) | 終了0、0.145秒 | 終了0、0.175秒 | `json-sink.jsonl` は独立して JSON として読める二行。stdout／stderr は空 |

コマンドはそれぞれ `target/debug/benitoite check work/m012/scratch/s2/<例>.bnt` と、同じ入力への `run` である。生の stdout／stderr は `<例>.<check|run>.stdout`／`.stderr`、引数・終了状態・外側の時間は `observations.json`、当時の実行補助は `run-probes.py` に保存した。これらも `riders-probes/` に写した。時間は小例の実行記録であり、性能評価ではない。

ファイルの例は、次の順で動く。

1. `with writer = try File.openWriter(...) or die do` で一度だけ開く。
2. `lambda(record: Log.Record) -> Unit uses File.Write, Process.Exit` に writer を捕捉する。
3. `withSinks` の出力先にそのラムダを渡し、同じ Writer へ `File.writeLine` する。
4. ハンドラの本文が終わってから `end with` で書き出し・解放する。

したがって、型・エフェクト・リソースの寿命・ハンドラの形のいずれにも、今回必要な書き方を妨げる点はなかった。main の宣言は `File.Write, State, Process.Exit` であり、処理し終えた Log は残らない。`or die` の停止方針を選んだため Process.Exit がある。実際の権限の説明では、未処理の Log の許可と、File.Write 等の宣言上限の確認を区別する。本文の外側にファイル単位の `uses Log` を書けば、処理後も main の宣言には Log が加わるので、この例では使わない。

JSON の例は、記録を通常の純粋な関数で `Json.Value` へ変換し、`Json.stringify` の結果を `File.writeLine` で書く。message 内の改行と引用符は一行内にエスケープされた。`withAttributes` の共通属性と個別属性に同じ `tag` を与えたところ、`common`、`event` の順で残った。属性は `{key, value}` の配列とし、Map への変換で重複を失わない形にした。位置も呼び出したファイル・行・列を含む。

この例は、UnsignedInteger64 の最大値を `{"unsignedInteger":"18446744073709551615"}`、非有限 Float を `{"nonFiniteFloat":"NaN"}` の形で明示する独自のデータ形式を選んでいる。現行の Json.Value に符号なし整数の構成子はなく、NaN・無限大の Json.Value.Float は stringify が null と書く（03-08「Json」:118、`builtins/funcs/json.rs:486–495`）。値の種類と内容を失わずに残すため、例では明示したオブジェクトを使った。標準 Log の JSON 形式を新たに定める提案ではない。UnsignedInteger64 の最大値・有限 Float・NaN は実行で確認した。正負の無限大の実行例は今回含めていない。

初回の JSON 例は、存在しない `Float.isInfinite` を使って E0303、終了2になった。`Float.isNaN(number - number)` で非有限値を判定する既存 API だけの式に直した。初回の出力は `initial-json-sink.*` と `observations-initial.json` に残し、最終成功と区別した。`verify-output.py` はファイルの二行、各 JSON 行の解析、属性の順序・値、位置、四呼び出しの成功を読み取り確認した。

なお、書き込み失敗、並行タスクから同じ出力先を呼ぶ場合、解放後の使用、長期間の運用は今回の実行確認に含めていない。`File.Writer` はバッファを持ち、各記録の呼び出しが成功しても、解放時に書き出しが失敗しうる。03-07「File」の既存の規則を例から参照し、毎記録の永続化を保証した書き方としては説明しない。

### 他の言語の出力先との短い比較

外部資料はすべて 2026-10-24 に一次資料で確認した。既存の用語である「ハンドラ」「出力先」を使い、新しい概念名は設けない。

| 対象 | 出力先と書式の組み方 | 今回への判断材料 |
|---|---|---|
| Python logging | StreamHandler は `write`／`flush` を持つストリームへ出す。FileHandler はファイルを開いてストリームとして保持する。整形は Formatter に委ねる。[公式 handlers 文書](https://docs.python.org/3.14/library/logging.handlers.html#filehandler) | 書式と開いた出力先を組み合わせる考え方は Writer を捕捉する例と対応する。Python の全クラス体系を導入する理由にはならない |
| Rust tracing-subscriber | fmt の Layer は書式を選び、MakeWriter で出力先を得る。開いた File を Mutex に入れて保持する例がある。MakeWriter は記録ごとに呼ばれ、必要な状態を保持する責任がある。[公式 MakeWriter 文書](https://docs.rs/tracing-subscriber/latest/tracing_subscriber/fmt/writer/trait.MakeWriter.html)、[fmt の JSON 書式](https://docs.rs/tracing-subscriber/latest/tracing_subscriber/fmt/index.html#formatters) | 出力先の生成と書式を分けて選べる。Benitoite でも開く処理を sink の外へ置けば、記録ごとの再オープンを避けられる |
| Go log/slog | Handler は Enabled／Handle／WithAttrs／WithGroup を持つ。NewJSONHandler は `io.Writer` を受け、一行ごとの JSON オブジェクトを出す。[公式 slog 文書](https://pkg.go.dev/log/slog#Handler)、[NewJSONHandler](https://pkg.go.dev/log/slog#NewJSONHandler) | enabled と emit、共通属性と出力先を別々に扱う現行 API で必要な組み合わせを表現できる。一行一記録の例の根拠になる |

### 選択肢と推す案

| 選択肢 | 評価 |
|---|---|
| A. 既存 API の実行できる例だけを足す | 開いた Writer と JSON の出力は可能である。文書のテキスト例では水準と位置も記録する。ただし非公開の `formatRecord` を呼べず、既定と同じ書式・エスケープを使うには利用者側で書き直す必要がある |
| A'. A に加えて既定書式の純粋な関数を公開する | 推す案。`formatRecord(record: Record) -> String` を公開すれば、Writer の捕捉と既定書式を組み合わせられる。原則 4・5・6 に合う。公開 API と書式の契約の保守、生成参照と交換の接続の確認が加わる |
| B. ファイル専用／JSON 専用の標準ハンドラを足す | 標準 JSON のキー、重複属性、符号なし整数・非有限数、失敗・解放の方針を API の契約として追加する負担が生じる。特に `Log.toJson` を標準に足すと prelude の Log が Json に依存する。構成で外せるモジュールの境界を保つ AGENTS.md の規約に沿わないため採らず、Json を import する利用側の純粋な変換関数にする |
| C. 既定の Log 出力をファイル／JSON に切り替える設定を足す | 今回の確認範囲を越える。出力先を宣言上限と結ぶ設計や、後の実行時の権限制御と重なる |

A と A' のどちらでも、03-07 の既存節に組み方と寿命・失敗の注意を短く追記し、英語リファレンスと手書き `references/idioms.md` に開いた Writer と JSON の例を置く。Skill 本文には手書き参照への案内だけを足す。A のテキスト例は少なくとも水準・位置・メッセージを含む独自の書式と明記する。保存した `file-sink.bnt` は寿命と出力の確認記録として保ち、そのまま文書例に採用しない。A' のテキスト例は公開した関数の結果を `writeLine` に渡す。

公開名の候補は `Log.formatRecord` と `Log.formatText` であり、前者を推す。Python の [Formatter.format(record)](https://docs.python.org/ja/3.14/library/logging.html#logging.Formatter.format) はログ記録を文字列にする名で、日本語の公式文書にも「フォーマッタ」「書式化」の用例がある。Rust の [FormatEvent::format_event](https://docs.rs/tracing-subscriber/0.3.23/tracing_subscriber/fmt/trait.FormatEvent.html) はイベントを Writer に整形する名である。これらを参照して、既存の `Record` を引数に取る内部名を保つ候補を `formatRecord`、テキスト書式を明示する候補を `formatText` とした（2026-10-24 確認）。他言語の関数が Benitoite と同じ純粋性を保証するとの比較ではない。新しい整形方式や Formatter の型は設けない。

例の検査は既存の文書例の検査を使い、同じ確認を複数の Rust テストに重ねない。`tests/doc_examples/mod.rs:131–190` が比較するのは stdout・stderr・終了状態であり、書いたファイルの中身は直接比べない。文書例では `end with` で Writer を解放した後、`File.readText` で読み戻して stdout に出し、期待出力と照合する。確認用の main には `File.Read` と `Console.Write` も加え、ログ出力そのものに必要なエフェクトとは区別して説明する。現在の例の `or die` は明示した停止方針として説明し、回復可能な出力先の失敗を扱いたいときは `Failure.fromResult` と外側の `toResult` など、既存の構成を別の例として検討できる。

### A' の公開性・生成参照・交換の比較

`Log.bnt:157–159` の `@builtin("Log.formatRecord")` と `builtins/funcs/log.rs:42–48` は、純粋な `Record -> String` の既存の実装である。A' ではこの名前と型を保って `public` と doc を足す案とする。既定処理と `withTextLogger` が共有する書式をそのまま提供し、エフェクトと組み込みの件数は増やさない。既存のコードを動かなくする変更は見込まないが、外部から呼べる名と書式が公開の契約になる。

生成参照の差はソースから確認できる。`src/cli/tools/skill/generate.rs:483–499` は package-public を除く公開宣言だけを列挙するため、公開後は `skill/references/stdlib/Log.md` にこの型と doc が加わる。実装時は `examples/gen_skill.rs:17–19,40–55` の通常の生成手順で生成参照と埋め込みの一覧を作り直し、`skill_generated` で一致を確認する。生成物は手で編集しない。英日文書の訳の同期はリリース時へ割り当てる。

交換については、07-04「01-12 との対応」の「Logの既定書式とIO」が標準宣言を本番交換の六入口へ渡すと定める。既存の接続は `tests/desugar_export/batch3.rs:190–198` と `batch4/log-standard.bnt` にあり、後者は `withTextLogger`・`withAttributes`・`withSinks` を呼ぶ。`tests/desugar_export/exchange.rs:2755–2792` は、入力内の関数参照と束縛番号、User 以外という由来で標準関数の宣言を選び、公開性では選んでいない。`formatRecord` は既に組み込みとして登録済みである。この範囲から、同じ名前と型を保つ公開性だけの変更に、新しい交換形式や Lean の定義・定理が必要になる根拠は見つからない。

ただし、公開後の生成参照の実際の差分、名前解決後の束縛・組み込み表の一致、外部から直接呼ぶ入力で六入口の比較が成功することは未確認である。[第4弾の g2/results.md](../../2026-10-19-TODO-022_032_087_168_191_192_200_206_222_226_227_229_246_248_253-syntax-batch4/g2/results.md)「局所交換と申し送り」は既存の1入力10定義・六入口一致と VM／参照評価の一致を記録するが、非公開時の結果であり、A' の成功の証拠にはしない。実装時は既存の Log の交換入力に公開関数の直接利用を加えて局所比較し、改造全体の最終の全比較に含める。Lean の定義・定理の変更は想定しないが、交換の接続の検査を省く案ではない。ここを越える規則の変更が必要と分かった場合は相乗りの前提を再確認する。

実行時の権限制御における Log 出力先の許可は、README の決定どおりサーバモードまで残す。00-01「保証の範囲」と 07-01 の区別を変えず、今回の例の成功や `--allow-effects` の宣言上限の検査を、パスごとの実行時許可の実装と扱わない。docs/todo の TODO-206 全体を閉じる提案ではなく、ファイル／JSON の未確認部分を解消する提案である。

`formal/Benitoite/Surface/LogExamples.lean:29–105` は、通常レコード、emit／enabled、完全な処理と送り直しを既存の checker へ渡す。07-04「01-12 との対応」の「Logの既定書式とIO」は実出力を形式化の対象外とし、型付けと分けて検査している。A は規則・標準宣言を変えず、A' は既存の関数の名前と型を保って公開性を変える。いずれも Lean の定義・定理の変更は想定しない。A' の生成参照と交換の比較の割り当ては前述のとおりである。

## TODO-280: derive の preview とファイル単位の宣言

### 現在の流れと得ている情報

`tools/derive/README.md`「Generation rules 3.1 transition」と道具の定数を照合した。設定は 1、inventory は 3、manifest／receipt／生成記録／意味のハッシュは 3、生成器は `3.1.0-syntax-batch5`、Property.libraryVersion は 2.0.0 である（`derive.py:24–29`）。これらは別の契約の版であり、一括で増やすものではない。

| 段 | 現在の処理 | 根拠 |
|---|---|---|
| inventory | 宣言を解決・収集する。本体の型検査はしない。各モジュールの `fileUses` は原文と元の UTF-8 バイト位置、`importInsertLimit` は宣言の開始位置を持つ。宣言なしなら両方 null。トップレベル関数のシグネチャはファイルの追加分を合併済み | `examples/derive_inventory/mod.rs:467–481`、同 README:50–60,119–125、`src/typeck/decls.rs:968–996` |
| preview | `prepare()` で inventory、型・カスタム関数・領域・生成物を検査し、manifest／diff／次の記録を出す。ソースは書かない | `derive.py:1009,1191–1209` |
| apply | 確認済み manifest の SHA-256、版・root・config、全入力、埋め込み入力、領域と生成計画を照合してから適用する。receipt による再適用・途中復旧がある | `derive.py:1224–1278` |
| derive check | 記録の版と `prepare()` が求める本文・記録との一致を見る。通常の本体検査の代わりにはならない | `derive.py:1211–1222` |

現在は `fileUses` を検証し、import をその前、生成宣言をその後へ置く制約を検査している（`derive.py:321–343,1130–1139`）。新しい import と生成宣言を一つの管理領域へ入れる方式では `uses` をまたげないため、必要な import を手書きで先に足すよう拒否する。カスタム JSON／Property 関数の純粋さも、合併後のシグネチャで検査する（同 `Template.custom`、inventory README:119–125）。

一方、生成先そのもののファイル単位の宣言は拒否していない。`test_derive.py:158` の `test_generated_property_functions_keep_file_effects` は、必要な import を用意した `uses Log` のファイルに生成・apply し、derive check が通り、通常の check は E0401 になることを検査する。宣言を除けば通常の check も通る。RV-A36「軽9」は、この生成後に必ず分かる誤りを preview へ早める改善案である。今回はその自己検査を走らせず、コードと過去の記録を読んだ。

### 生成する宣言の種類による違い

| 選択した機能 | ファイル単位の宣言との関係 | 提案する扱い |
|---|---|---|
| Property | トップレベルの生成器・縮小器・補助関数に追加分が入る。Gen／Shrinker が要求する純粋なコールバックと合わなくなる | preview で拒否する |
| JSON | トップレベルの encode／decode と補助関数に追加分が入る。通常の check が常に失敗するとは限らないが、道具が約束する純粋な Result ベースの変換ではなくなる | 同じく拒否する |
| Show／Order だけ | `generate_trait` は `implement` のメソッドだけを生成し、トップレベルの補助関数を作らない。ファイル単位の宣言は実装のメソッドに加えない | 受理する。既存の import の配置等の制約は適用する |
| 上記の組み合わせ | Property または JSON を含むなら、その生成先で純粋さの問題が残る | 一部を黙って省かず、preview 全体を拒否する |

根拠は `derive.py:607–659,779–849,855–960` と 01-07「ファイル単位のエフェクトの宣言」である。ここでいう JSON の拒否は、改造の README が定めた Property の調べから範囲を広げる案であり、設計者の承認が必要である。道具の README「JSON conversion contracts」が約束する純粋さを維持する方針として示す。

具体的には、`uses Log` のファイルで宣言したトップレベルの encode 関数を、純粋な関数を要求する `Codec.encodeList(encode: ...)` に渡すと型が合わない。RV-S2「軽1」はこの類例で E0401・終了2を再現したと記録する。`derive.py:788–800` も、容器の中のレコードを符号化するとき、レコード用の生成関数を関数値として渡す。したがって容器の中にレコードを持つ型の生成物でも失敗するとの推論が成り立つが、derive 自体の生成・適用・通常の check は未実行である。単純な欄だけなら check を通る場合があることと、純粋な変換という道具の契約は分けて判断する。実装時に容器の中のレコードの反例を再現し、JSON まで拒否する承認の根拠にする。

### 選択肢と推す案

| 選択肢 | 利点と問題 |
|---|---|
| A. 警告して続け、通常の check へ渡す | 既存の入力は受理するが、Property の既知の失敗を生成・確認・適用の後まで持ち越す。警告の見落としも残る |
| B. Property だけを拒否して別ファイルを案内する | TODO-280 の直接の反例に最も小さく対処できる。JSON の「純粋な変換」という道具の契約との不一致は残る |
| C. Property／JSON を拒否し、Show／Order は受理する | 推す案。通常のトップレベル関数を作る機能と、実装のメソッドだけを作る機能を実際の効果で分けられる |
| D. ファイル単位の宣言があれば全機能を拒否する | 実装は単純だが、純粋な Show／Order まで制限する必要がない |

C は原則 1・2・4 に合う。inventory の既存情報で事前に判定し、生成される関数の純粋さの契約を保つ。型・エフェクトの規則を変えたり、生成物をファイル単位の宣言の例外にしたりしない。受理済みの preview／生成記録のある利用者には、新しい道具で同じ生成先が拒否される変更であることを案内する必要がある。

拒否時は、対象ファイル、対象型、選択機能、ファイル単位の宣言の原文と位置、純粋さが必要な理由を示す。対処は「このファイルの宣言を外して必要な関数に個別の uses を書く」または「型定義と生成対象を、宣言のないモデル用モジュールへ移し、操作を行う側から import する」とする。

単に「生成先ファイルを別に指定する」とは案内できない。現行 inventory は対象レコードの宣言元と設定の source の一致を要求する（`examples/derive_inventory/mod.rs:377–383`）。既存の管理領域・記録を持つ型の移動には、README の削除対象・領域の管理手順も必要である。自動移動や新しい出力先設定を、この相乗りへ加える必要はない。

事前検査は `prepare()` の共通の入口で、最初の生成計画を作る前に行う案がよい。preview だけに置くと、derive check と初回 apply の再検証で判断が分かれる。receipt による既存の復旧を壊さないことも確認する。inventory／manifest の形は増やさない。生成器の版と移行案内の扱いは次の独立した問いで決める。

### 生成器の版と BREAKING_CHANGES の登録

生成器の版は、拒否する入力の追加とは別に判断する必要がある。`derive.py:1211–1230` は記録と manifest の `generatorVersion` の完全一致を要求する。版を上げると、ファイル単位の宣言がない現行の記録も一律に `derive.migration_required` になり、新しい preview・確認・apply が必要になる。旧 manifest の apply の報告は `derive.incompatible_manifest` である。これらと、言語の版の照合が出す E0908 は別の拒否である。

| 選択肢 | 互換の負担と E0908 | R2 の範囲と06-09の版の表 |
|---|---|---|
| a. 生成器の版を上げない | 推す案。受理する入力の生成本文と記録を保てば、現行3.1.0の無関係な記録に新たな `derive.migration_required` は出さない。拒否対象は生成先の整理が必要になる。この項目を理由とする E0908 は増やさない | Python・文書の変更にとどめ、package.rs・text.rs に登録を足さない。06-09の版の表は既存の登録を保ち、事前拒否の追加は derive の現行契約・READMEで説明する |
| b. 版を上げ、BREAKING_CHANGES に登録しない | 宣言のない対象も含む全現行記録が `derive.migration_required` になり、旧 manifest も再生成・確認が必要になる。この項目を理由とする E0908 は増やさない | Python・文書にとどまる。06-09では新しい道具の版・移行手順を言語の非互換変更の登録表から区別して示す。package の診断では道具の一律移行を知らせない負担がある |
| c. 版を上げ、BREAKING_CHANGES に登録する | b の一律移行に加え、次の0.0.12へ登録すると `language "0.0.11"` の利用者は derive の利用の有無によらず E0908 の対象になる。より古い宣言にも既存の変更と併せて案内する | Rust の `modules/package.rs` の登録表と `modules/text.rs` の要約・help、および対応する検査・文書に広がる。06-09の版の表にも0.0.12の登録と具体的な移行案内を加える |

ここでいう「E0908 は増やさない」は TODO-280 だけに関する差である。改造の中心の TODO-022 等が独立に登録を必要とするかは、本調査では決めない。0.0.10・0.0.11は `package.rs:163–199` と `text.rs:47–51` に登録済みだが、その先例だけで今回の一律移行を必要とはしない。

a は、生成する本文・記録の契約を変えず、既知の不正な生成先を前もって拒否する案である。原則 1・2・4を満たしつつ、無関係な生成記録まで確認し直す負担を避けられる。受理入力で本文・意味ハッシュ・記録が一致することを実装時に確認する。これらが変わる実装になれば a の根拠が失われるため、b／c を再判断する。a でも古い manifest は道具自身の入力ハッシュの照合（`derive.py:1037–1038,1186–1189,1261–1263`）で拒否されうるので、更新前の manifest を無条件で再利用できるとは案内しない。未完の適用の復旧は保存した旧道具で先に終える。

TODO-282 は版の記述を移す作業であり、登録の意味を変える作業ではない。a／b ならこの項目から登録を増やさず、c なら新しい登録も06-09だけに書く。いずれでも01-03には一般の版の意味と照合規則だけを残す。この整理により、道具の版の表を言語仕様へ書き戻す必要はない。

### selftest を改める案

`test-audit` の作成時の関門に照らし、持ち主は実 inventory・formatter をつなぐ derive の公開の preview／apply／check 境界とする。`test_generated_property_functions_keep_file_effects` を、生成後の失敗を許す検査から、preview の拒否と非書き込みを確かめる表の形の検査へ改める。新しい並行したテスト群は作らない。

| 入力・観察 | 守る契約・捕まえる退行 |
|---|---|
| 必要な import を先に置いた Property／JSON／両方の `uses Log` 入力 | import 不足で拒否された結果と混同せず、純粋さの理由で止まること。ソース・記録・既存領域を変えず、レビュー成果物も出さないこと |
| `uses State` 等、Log 以外の有効な宣言 | Log だけを特例で拒否する漏れを防ぐ。原文を Python で再解釈せず `fileUses` の有無で扱う |
| Show だけ／Order だけ／両方、必要な import は既存 | preview・apply・derive check・通常の check が成功し、過剰な一律拒否を防ぐ |
| 宣言が依存ファイルにだけあり、その依存先が Property／JSON の生成対象に含まれない入力／対象のない空設定 | 対象の生成先だけを見ること。他のモジュールに宣言があるだけで拒否しないこと。依存先も同じ設定の Property／JSON の生成対象なら、その依存先を理由に全体を拒否する |
| 拒否後、生成先の宣言を個別の関数へ移した入力 | 同じ設定を再 preview でき、通常の check まで通るという対処の実効性 |

複数対象の一件に問題があれば preview 全体が非書き込みであることは、既存の `test_multiple_targets_and_regions_apply_together` と非書き込みの準備処理を拡張して確かめる。旧版の記録・manifest、改変した領域、apply の再適用／途中復旧は既存の検査を保ち、必要な行だけ加える。現行の本体検査後の失敗を守る検査は、今回変える契約に対応して置き換えるのであり、失敗を消すために削るのではない。新しい公開 API・テスト用フラグは不要である。

形式化への影響はない。07-04「01-12 との対応」のファイル単位の宣言は、合併済み Scheme を既存の型付き表層へ渡す前処理として対象外に置く。derive が生成を断る入力を増やしても、その合併や表層の関数型を変えない。

## TODO-281: work の lint と examples

### 現在の対象と記録

| 水準・単位 | 現在の対象 |
|---|---|
| work の通常の Rust | `lint_default`: `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep`。examples を指定していない |
| work の heap の変更等 | `lint_heap` が加わる。`--workspace --all-targets`、gc-mark-sweep／heap-verify／alloc-stats の構成である |
| stage | 計画の `--only` で選んだ単位の対象に従う。水準だけで対象を増やさない |
| change の Rust | lint_default と lint_heap の二構成。さらに既定／heap-verify の `cargo test --workspace --all-targets` を行い、examples・benches を含む対象を検査する |
| release | 自動で選ぶのは release_stack のみ。lint は改造の記録と候補との一致を照合し、必要なら計画で追加する |
| 旧指定の rust／full | 専用の旧経路で二つの lint を実行する。既定側の対象は lib／tests、heap 側は workspace all-targets である |

根拠は `scripts/check.sh:424–447,541–546,673–674`、07-03「実装の規約と静的な検査」の水準の表、単位の表、旧指定の互換表である。`classify()` は examples を独立分類せず `crates/*` として Rust にする（同:304）。既存の Cargo.toml に明示した bench ターゲットはなく、`crates/benitoite/benches/` もない。ベンチマーク用の Rust の道具は `examples/bench_run.rs` 等にあるため、`--examples` の追加でこれらも対象になる。

Cargo の `--tests` は、既定では lib・bin の単体テストと統合テストを含む。`--all-targets` は `--lib --bins --tests --benches --examples` に相当する。したがって、07-03 の現行の「examples・binsへ広げない」は、bin が一切ビルド対象にならないという意味に読める点に注意が要る。更新時は「既定側に examples を加える。benches の明示選択はしない」と実際の引数で説明するのがよい。[Cargo 公式の対象選択](https://doc.rust-lang.org/cargo/commands/cargo-check.html#target-selection)（2026-10-24 確認）。

過去の根拠は第5弾の `g1/results.md`「実行と初回の失敗」と RV-G1 の L2 である。初回 change は fmt・lint_default の成功後、lint_heap の all-targets で `try_actions_inventory.rs` の `wildcard_enum_match_arm` を検出して23.003秒で止まった。修正後の work 全体は100.944秒、change の続行は4785.634秒である。これらは lint 単独の時間でも、examples の追加差分の時間でもない。

### 選択肢と時間の見込み

| 選択肢 | 対象と保守 | 時間について既存記録から言える範囲 |
|---|---|---|
| A. 毎回 `--examples` を足す | 増分が30秒以下なら推す条件付きの案。検査単位は増やさず、共有する型・API の変更で examples が壊れた場合も作業末に検出する | 増分は未測定で不明。現行スクリプトの lint の表示見込みはキャッシュ次第で約1〜3分であり、変更後も同じ時間に収まるとは未確認 |
| B. examples を変えた作業だけ足す | 検査する回数を減らせるが、src の API 変更だけで壊れた examples は検出しない。削除・改名の旧パス、明示的な `--only`、stage の扱いも規定する必要がある | 対象外の work は現状と同じ。対象になった回の増分は不明 |
| C. `--all-targets` にする | bins・benches を含め既定側を統一できる。将来の重い bench ターゲットも自動で work に入る | 増分は不明。all-targets の過去の検査は構成が違い、A との差に使えない |
| D. change のままにする | 検査の変更はない | work の増分は0だが、既に観察した検出の遅れは残る |

A は、作業で変更した契約の利用側も確認する 07-03 の方針と、原則 1・4 に合う。例のソースを変えた場合だけでなく、ライブラリの型を変えた場合にも検査する理由がある。examples のコンパイル・lint を前倒しする提案であり、全 examples の実行やテストを work へ前倒しする提案ではない。

規模については、S2R が `.rs` の物理行を数えたところ、examples は配下の補助モジュールも含め16ファイル・3,369行、src は385ファイル・203,461行で、比は約1.66%である。examples のトップレベルの入口は10個である。lib は現在の `--lib` で既に lint の対象であり、Rust の work が選ぶ `skill_generated` は既に `gen_skill` をビルドする（`check.sh:231–235,424`）。これらは追加のコンパイル量が小さいと見込む根拠にはなるが、行数から lint の増分秒数は計算できない。変更量・キャッシュ・入口ごとのコンパイルの影響が残る。

判断の手順は、計画を固める前に、同じソース・Rust toolchain・構成・温まったキャッシュで、現在の `lint_default` と `--examples` だけを加えた clippy を一回ずつ測る短い試行とする。外側の時間をそれぞれ `t_base`、`t_examples` として記録し、両方成功して `max(0, t_examples - t_base) <= 30秒` なら A を採る案を推す。30秒は実測値ではなく、作業ごとの追加待ち時間の判断基準の案であり、設計者の決定後に計画へ固定する。超えた場合は B を候補に戻し、API の変更だけでは examples を検査しない負担も示して計画を決める。C は同等以上の対象を持つため、時間超過の解決策としては選ばない。

この試行は温まった状態での一回の比較であり、キャッシュのない状態や平均時間を保証しない。計画には二コマンドと環境・順序・キャッシュの状態を記録し、最初の通常の work の `lint_default` の外側の時間でも見込みとの差を確認する。試行の見込みは現行の表示を使って計2〜6分、キャッシュを温める準備は不明とする。既存のビルド記録を利用できない場合は準備の見込みを調べ、長いビルドを始める前に設計者へ示す。今回は測定も cargo の実行も行わない。

### スクリプト・文書・固定記録への影響

測定後に A を採る場合、新水準の `run_unit` の `lint_default`（`check.sh:541`）だけを `--lib --tests --examples` にする。change も同じ単位を共有するので、既定側の例に lint が掛かる。旧指定の実行経路（同:674）は変えず、旧 `--only`／`--full` の集合を保つ。release の自動選択も変えない。以下の変更箇所も A を採った場合の案である。

07-03 では水準表の work の「後へ送るもの」にある「examples のビルド」を、全 examples のテストの実行と区別して直す。change の二構成の clippy、lint_default の単位表、既定 lint の表も更新する。同章が保守を要求する `docs/workflow/implementation-request.md` と `change-plan-template.md` を同じ変更で確認し、examples を change まで送る文があれば修正する。

`scripts/check/test_policy.py` は新水準の期待するコマンドを変える。主な箇所は `test_default_switches_to_work_and_stops_with_three`（:361）と change のコマンド照合（:702）である。既存の分類表へ examples のパスを一行加え、src のみの変更でも同じ lint が選ばれること、dry-run が実行しないこと、release は release_stack のみであることを既存の境界で確認する。確認する契約は対象選択であり、壊れた Rust ソースを別に用意して Clippy 自体を再検査する必要はない。

`scripts/check/fixtures/legacy-commands.json` は変更しない案である。旧 only／full の固定記録は保ち、既存の legacy の selftest で差がないことを確認する。旧自動選択の記録も履歴として残し、現在の work の期待値は既存の Python 側の新水準の照合を直す。もし共通化によって旧経路まで変える実装を選ぶなら、それは固定記録の単純更新ではなく、旧集合を保つという契約の変更になるため採らない。

Lean への影響はなく、形式化の定義・定理・交換の形式・入力の意味は変わらない。

## TODO-282: 01-03 の版の記述を 06-09 に集める

### 現在の重複と対応

01-03「依存の記述と `package.bnt`」の295行は、一段落に次の内容を含む。

- `language` の意味、新旧の版の照合、全変更を版順に案内する規則。
- 0.0.5〜0.0.11 の登録内容、各版の具体的な移行の案内。
- derive の inventory／生成器、try-actions の inventory／manifest、package の Log の集計、確認済みハッシュを使う apply 等。
- CHANGELOG の節を名指す版と名指さない版、宣言の更新先、宣言を省略できる場所。

06-09「設定ファイルの検査」の41行は、同じ登録内容と移行の案内を持つ。処理系の正は `src/modules/package.rs:145–198` の `BREAKING_CHANGES` と、`src/modules/text.rs:48–51` の要約・help の文字列である。ここでいう help は E0908 の診断に付く移行方法であり、`benitoite --help` の一般の使い方とは別である。

第5弾の `z1r/results.md` の L3 の対応では、01-03／06-09 の「各版が CHANGELOG の該当節を参照する」を、0.0.5・0.0.8〜0.0.11 は節を名指し、0.0.6・0.0.7 は節を名指さないという実装に合わせた。RV-Z1 の L6 は、道具の情報が 01-spec に増えている問題を次の改造へ送った。今回はこの配置を整理できる。

利用者向けの `docs/reference/benitoite.md`「Migrating to 0.0.11」（:1838）と `docs/reference/install.md`「Updating from 0.0.10 to 0.0.11」（:150）は、inventory 3／生成器3.1.0、try-actions の版2、確認後の language と依存ハッシュの更新を説明し、現在の処理系と合っている。言語の版の一般の説明（同リファレンス:1936）は、宣言の有無で規則を切り替えないことを明記する。06-01 の設定ファイルの案内、02-10「診断の内部の表現」、用語集の「言語の版」とも照合した。E0907／E0908 の具体的な検査は06-09「設定ファイルの検査」にある。

ただし、現行の説明には次の別の不一致が残る。

| 場所 | 読めば確定する不一致 | 修正案 |
|---|---|---|
| `crates/benitoite/skill/SKILL.md:259–263` | 現在の derive の説明が inventory 2、生成器 `3.0.0-syntax-batch4` のまま | inventory 3／生成器3.1.0 の現行契約へそろえるか、細かい版表を道具の README への参照へ置き換える |
| `docs/reference/benitoite.md:2212` | Property の現在の保存事項が inventory 2／生成器3.0.0 のまま。直前の移行節:1840は新しい版 | 過去版の移行の小節は保ち、現行機能の説明だけを直す。訳もリリース時に同期する |
| `docs/ja/skill/SKILL.md:234` | 日本語の訳も inventory 2／生成器3.0.0 のまま | 英語版の修正に合わせてリリース時に同期する |
| `docs/ja/reference/benitoite.md:2079` | 日本語の Property の説明も inventory 2／生成器3.0.0 のまま | 現行機能の説明をリリース時に同期し、過去版の移行節は保つ |

この不一致は 01-03 の移動で自動的には直らない。修正の判断は TODO-280 の文書の側に付け、生成器の版の案 a なら3.1.0、b／c なら計画で固定する新しい版へ現行機能の説明をそろえることを推す。日本語の訳は二文書ともリリース時に同期する対象へ渡す。実行時の反例と推測したものではなく、文字列と定数の不一致である。a／b ならこの項目を理由に処理系の診断の help を変える必要はなく、c なら追加する登録の help を R2 に含める。

### 残す内容と移す内容

| 内容 | 推す置き場所 | 理由 |
|---|---|---|
| 言語の版は執筆時の版を一つ宣言すること、書ける場所・必須／任意 | 01-03 | 言語の利用者に必要な規則である |
| 新しい宣言の拒否、宣言より後から現在版までの非互換変更の照合、全変更の版順の案内 | 01-03 に規則を残す | VM や道具の構成に依らない。各実装がどう判定するかの方式は書かない |
| 版ごとの登録表、derive／try-actions の版、package の報告の変化 | 06-09 | この処理系が現在持つ変更表と道具の契約に依存する |
| CHANGELOG の参照先の文言の違い、preview／apply／check の具体的な手順 | 06-09 の現行の説明を唯一の記述とし、詳細は道具の README を参照 | 同じ文言を二章で保守する理由がない |
| 手動の確認後に language を現在版へ直すこと、依存のハッシュの更新、修正案に自動置換を付けないこと | 06-09、診断の組み立ては02-10 | 移行の操作と処理系の診断の仕様であり、宣言の意味そのものと区別できる |

選択肢は、A「道具の版だけを抜く」、B「版ごとの登録・案内全体を 06-09 に集める」、C「新しい道具の章を作る」である。B を推す。A は同じ長い版表を二か所に残す。C は新しい章・目次・参照先を増やすほどの内容ではない。B は原則 4 と、01-spec を実装方式に依存させない AGENTS.md の規約に合う。0.0.7 の環境変数の拒否等の仕様自体は、それを定める既存の節に残り、01-03 の移行履歴だけを移す。

01-03 の段落は、意味と照合規則を数文に分け、最後に 06-09「設定ファイルの検査」へ参照を置く形がよい。見出し「依存の記述と `package.bnt`」と「設定ファイルの検査」は保つ。TODO-282 単独では言語の規則・診断の文言・版の登録を変えず、文書の構成だけを変える。TODO-280 の案 c による登録の追加は別の判断として同じ06-09へ反映する。

### 見出しの参照と道具への影響

`git grep` で両見出しと 01-03 の参照を、`crates/`・`scripts/`・`tools/`・`formal/`・設計書・リファレンスについて確認した。主な利用側は次のとおりである。

| 利用側 | 内容と今回の影響 |
|---|---|
| `src/modules/package.rs:2,330,506` | 両章の見出しをコメントで参照する。見出しを保てば変更不要 |
| `src/modules/tests.rs:23,127,1175` と packages／external のゴールデン入力 | `// spec: 01-03 依存の記述と package.bnt` に対応する印がある。規則と見出しを残すので移動不要 |
| 01-02「ファイルの先頭の部分」、06-09「前提」、用語集、02-10 | 版の意味や配置・診断の説明を参照する。見出しと一般の規則を保てば参照先が失われない |
| `tools/spec-coverage/spec_coverage.py:55–71,149–152` | 見出しと spec 印を照合する。本文の移動だけなら節の一覧は変わらない |
| `tests/spec_examples.rs:39,796` | 01-03 の text の例を読む。今回、コード例とその見出しは変えない |
| `examples/gen_skill.rs:17` | 文法の抽出元は01-02であり、01-03 の移行段落ではない。本文移動だけで文法参照の再生成の内容は変わらない |

見出しを新設・改名する案は採らないので、README の章の目次、spec 印、生成器の節名の更新は不要である。実装時は文書の自動選択に従い、仕様例と仕様集計を確認する。形式化の定義や言語の版の照合規則を変えないため、Lean の変更は不要である。

## 実装の作業の分け方と見込み

まず生成器の版の案 a／b／c を決め、TODO-281 の短い比較を計画前に行う。その後は R1（lint）、R2（derive と版の説明）、R3（Log）へ分ける案を推す。R1 を先に終えれば、後続で examples を変えたときも採用した対象選択で確認できる。R2 の組み方は次のとおり版の判断で変わる。Log の作業は derive の生成・記録管理に依存せず、別に確認できる。

| 版の判断 | R2 の組み方と理由 | 見込みの大きさ |
|---|---|---|
| a（推す案） | TODO-280の Python の拒否と現行契約の説明を直し、同じ文書変更でTODO-282の移動と旧版表記の修正を行う。新しい版の登録は足さず、06-09の既存の表と道具の現行契約を一度照合する。R2内の順序は拒否・受理の確認、本文の整理とする | 小〜中。Python・文書。実装・文書3〜6時間 |
| b | aに加え、生成器の識別版、一律移行の案内、記録・manifest・receiptの互換の確認をR2前半で扱う。後半で06-09の道具の版を更新してから01-03を整理する。道具の版と登録表を区別する説明を同時に確認する理由がある | 中。Python・文書。実装・文書4〜7時間 |
| c | R2前半をPythonの変更とRustのpackage.rs・text.rsの登録・診断の確認、後半をTODO-282の移動と英語文書の同期に分けて直列に確認する。新しい登録と06-09の表を一致させるため同じR2にまとめる。中心の作業も同じ登録を変えるなら、その担当へ登録を集約して重複編集を避ける | 中。Python・Rust・文書。実装・文書5〜9時間 |

| 作業の候補 | 範囲・変更の大きさ | 実装・文書の見込み | 検査・レビュー・受け入れの見込み |
|---|---|---:|---|
| 計画前の短い比較 | TODO-281。温まったキャッシュで現在のlintとexamplesを加えたlintを各一回測り、増分30秒の基準案で判断する | 計画・記録の時間はR1に含める | 比較2〜6分の見込み、準備は不明。結果を見て設計者がA／Bと計画を決める |
| R1: work の examples の lint | TODO-281。A採用時はシェル一か所、新水準の期待値、07-03と雛形の確認。小。Bなら分類と名指しの規則も計画へ具体化する | Aなら1〜2時間。Bは再見積もり | 方針 selftestと三シェルの構文確認。最初のworkのlint時間を記録。レビュー・受け入れ20〜40分 |
| R2: derive の事前拒否と版の説明の整理 | TODO-280・282。上のa／b／cに従う。旧版表記の修正の判断もTODO-280に含め、日本語のSkill・リファレンスはリリース時に同期する | aは3〜6、bは4〜7、cは5〜9時間 | derive selftestの過去の47件は73.743秒。aでは受理入力の本文・意味ハッシュ・記録の一致、b／cでは一律移行、cではpackageのE0908・helpの整合を確認する。必要なビルド、cの既定lib全件・関連統合・clippy・fmtの時間は不明。文書例・仕様集計、レビュー・受け入れ30〜60分 |
| R3: ファイル／JSON のログの例と既定書式の公開 | TODO-206。推すA'はLog.bntの公開性・doc、文書例、生成参照とSkillの案内。小〜中。Aなら文書だけ | A'なら2〜4時間、Aなら1〜3時間 | 読み戻しを含む文書例、生成参照の一致、既存Log入力に直接利用を加えた六入口の局所比較とVM／参照評価。公開後の時間は不明。レビュー・受け入れ20〜40分 |
| 改造全体との統合 | TODO-022 の実装と合わせて一度だけ change、最終候補の照合・release_stack・受け入れ。各相乗りのために全件を反復しない | 集約・記録1〜2時間の見込み | 第5弾の change は約80分だった。今回の整数解析の変更による時間、形式化の全比較、公開候補の最適化ビルドの時間は本調査では不明 |

R1でA、R3でA'を採る場合、集約・記録を含む実装・文書の合計はaなら7〜14時間、bなら8〜15時間、cなら9〜17時間である。レビュー等とビルド・検査は別枠の見込みであり、実測ではない。根拠は既存のinventory欄・一時プロジェクト・文書例検査を使えること、aに比べbでは記録の移行、cではさらにRustの登録・診断と検査が加わること、第4弾の `g2/results.md` の既存Logの局所接続、第5弾の `g1/results.md` と `z1r/results.md` の検査記録である。Lean の定義・定理の変更数は各作業とも0を想定する。新しい規則や定理が必要なら、この見込みと相乗りの前提を再確認する。

検査の具体的なコマンド・基準・一度だけ実行する担当は、判断後のplanの「検査の割り当て」で固定する。R1はPython・シェルだけなら関係のないRustのlib全件を足さない。R2のa／bもPython・文書だけなら同様であり、Rustのinventoryを変える必要は現時点ではない。cではRustの既定lib全件・関連統合・clippy・fmtをworkへ割り当てる。R3のAは既存の文書例の境界、A'は公開APIと生成参照・交換の局所接続も使う。最終の形式化の全比較は改造全体の関係状態で一度行う。特殊構成の追加が必要な型／ヒープの変更へ広がった場合は、この見込みに含めず、READMEの相乗りの前提と計画を再確認する。

設計者への判断事項は [riders-questions.md](riders-questions.md) に集めた。
