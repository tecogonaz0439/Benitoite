# 検査済みの値・定数の検査・範囲を確かめる API の調査

2026-10-18 の S1 の調査である。対象は docs/todo の TODO-142・026・022。開始版は `6b0568a3ddcc46b0a0e64504139ce286a27fd86a`、ブランチは `mod009/design` である。以下の行番号はこの開始版を指す。調査中に処理系・現行設計・テスト・formal・docs/todo を変更していない。推す案は未回答であり、現行仕様や採用済みの判断として読まない。

項目の原文は [todo-items.md](../todo-items.md)、判断の選択肢は [checked-values-questions.md](checked-values-questions.md) に置く。版全体は設計者が指定した13件を扱い、TODO-191を含めない。本書の見積もりは、そのうち A と C および共通の土台だけである。

## 推す最初の範囲

A と C に共通する土台は、型の名前を公開し、値の作り方を宣言したモジュールの中へ隠す仕組みである。条件を確かめてから値を作る関数（smart constructor）だけを外へ公開すれば、その関数が守る不変条件を API の契約にできる。現行の利用者定義の公開 data・record には、この分離がない。

推す案では、構築を隠す属性 `@opaque` を data・record に加え、中身は従来の代数的データ型のままとする。A は `Scope.CheckedHost`・`CheckedPath`・`CheckedEndpoint`、C は `Range.CheckedInteger` から始める。モジュールの完全名の案は `Benitoite.Unofficial.Scope` と `Benitoite.Unofficial.Range` である。名前・属性・API はすべて案である。

定数の検査は、名前解決後に対象の関数を直接呼ぶ式の引数だけを調べる。A では範囲の書き方と、定数で分かる対象の不適合を検出する。026 では `Regex.compile` の正規表現を調べる。検査を通しても返り値の Result を取り除かず、実行時の検査を残す。C の一般の範囲検査は実行時だけとし、Result.Error を期待する通常の使い方も可能にする。

この範囲なら、エフェクトへ値や型を追加せず、エフェクトを外す規則も型の計算も変えずに済む見込みである。検査済みの値は、スクリプトが指定した条件への適合を表す。利用者による操作の許可や、OS 上で操作できる範囲は表さない。

## 現行の公開範囲と中身を隠す型

| 確認したこと | 根拠となるファイルと行 | 今回への含意 |
|---|---|---|
| 非公開・`public(package)`・`public` の三段階がある。`public data` は全構成子、`public record` は構築・更新・パターン・フィールドを取り出す関数も公開する | [01-03](../../../design/01-spec/01-03-names-modules.md) 227〜252行 | `public(package)` は型と作り方を分離する指定ではない。同じパッケージの別モジュールでも作れてしまう |
| 構成子・フィールドの束縛が親の公開段階を受け継ぐ | [resolve/mod.rs](../../../../crates/benitoite/src/resolve/mod.rs) 103〜119行、[collect.rs](../../../../crates/benitoite/src/resolve/collect.rs) 447〜474行 | 型と構成子の公開段階を別に保持するか、使用位置で追加の判定を要する |
| 公開契約に現れる型も、その契約以上の公開段階を必要とする | [checks.rs](../../../../crates/benitoite/src/resolve/checks.rs) 16〜87行 | 非公開型を公開関数の戻り値にするだけの回避策は E0329 に当たる |
| レコードの構築・更新は公開の型名からも入る。欄の参照を直接登録する処理がある | [lookup.rs](../../../../crates/benitoite/src/resolve/lookup.rs) 345行以降、[walk.rs](../../../../crates/benitoite/src/resolve/walk.rs) 405〜429行、[records.rs](../../../../crates/benitoite/src/typeck/records.rs) 69行以降・143行以降 | フィールド名を公開表から消すだけでは足りない。構築・更新・パターンの各入口を閉じる必要がある |
| 型の別名は元の型と同じ型を表す | [01-02](../../../design/01-spec/01-02-syntax.md) 810行以降、[01-03](../../../design/01-spec/01-03-names-modules.md) 239行 | `public type CheckedHost = String` では未検査の String を排除できない |
| 標準には中身を見せない組み込み型がある | [types/builtin.rs](../../../../crates/benitoite/src/types/builtin.rs) 9〜19行・208〜229行 | `Regex.Pattern`・`Regex.Match` や HTTP のリソースは利用者が直接構築できない。ただし利用者が同じ種類の型を宣言する構文ではない |
| 属性は既知の名前を列挙して受理する | [parser/items.rs](../../../../crates/benitoite/src/syntax/parser/items.rs) 194〜201行・543〜586行 | `@opaque` は現行では未対応であり、実装するなら適用先・引数なし・重複などの規則が要る |

構築を隠す案では、外部からの構成子の値化、直接呼び出し、部分適用、レコードの構築・更新・パターン・自動アクセサを同じ境界で拒否する。型の別名や import の別名でも境界を迂回できないようにする。同じパッケージの別モジュールも外部として扱う。一方、型名・関数の引数・返り値・型クラスの引数としての使用と、値をそのまま受け渡すことは認める。

公開契約の検査も調整を要する。隠した構成子の引数型やレコードの欄の型は、外部に公開する契約から外せる必要がある。型の公開だけを理由に内部の非公開の補助型まで公開させると、実装を隠す目的に反する。公開関数の署名には従来の公開段階の検査を残す。

通常の data・record の型・表現を使う案では、組み込みの `Ty.opaque` と同じ実装になるとは説明しない。既存の等値判定の可否は内部の型から従来どおり決め、外部に自動の Show や復元の関数を追加しない。特に tools/derive の JSON の復元・生成器が、別モジュールに隠した構成子を組み立てる経路を作らないことが必要になる。生成先が宣言モジュール内でも、検査なしで公開の復元関数を作れば不変条件は破れる。これは TODO-087 の調査との接続点である。

## 現行 IO が受け取る対象

| 操作 | 現行の対象の型 | 根拠となるファイルと行 |
|---|---|---|
| `Http.listen`・`serve` | `host: String, port: Integer`。listen のポート0は OS による選択 | [Network/Http.bnt](../../../../crates/benitoite/src/prelude/stdlib/Network/Http.bnt) 8〜11行・72〜78行 |
| `Http.send`・`get` | `ClientRequest` の `url: String`、または直接 `url: String`。request は公開レコード | [Network/Http.bnt](../../../../crates/benitoite/src/prelude/stdlib/Network/Http.bnt) 23〜25行・44〜51行・114〜121行 |
| `File.readText`・`openReader`・`writeText`・`openWriter` 等 | `path: String`。開いた後は Reader・Writer | [IO/File.bnt](../../../../crates/benitoite/src/prelude/stdlib/IO/File.bnt) 6〜60行 |
| `File.canonicalize` | `String → Result[String, IOError]`、File.Read | [IO/File.bnt](../../../../crates/benitoite/src/prelude/stdlib/IO/File.bnt) 25〜26行、[file.rs](../../../../crates/benitoite/src/builtins/funcs/file.rs) 496〜505行 |
| `Process.run`・`runAttached` | 公開レコード `Command`。program と workingDirectory は String 系 | [IO/Process.bnt](../../../../crates/benitoite/src/prelude/stdlib/IO/Process.bnt) 23〜47行 |
| `Process.shell` | `commandLine: String` | [IO/Process.bnt](../../../../crates/benitoite/src/prelude/stdlib/IO/Process.bnt) 33〜35行 |

この一覧で確認した Network の公開 API は HTTP である。TODO-142 の `Net.Tcp`・`Net.Https` は候補の記法であり、現行の名前ではない。HTTP の URL、待ち受けのホスト、プロセスのプログラム名を同じ「パス」の検査で置き換えられる根拠もない。

推す最初の API は、これらの IO の引数を変えない。検査した対象を取り出して従来の IO へ渡す利用例は作れるが、その後で別の文字列を渡すことを型で禁止する保証は得られない。新しい型が守るのは、値自身に保存した条件と対象の関係までである。IO を必ず検査済みの値経由にする案には、全入口の変更、URL・作業ディレクトリ・リダイレクト等の意味、移行の設計を別に要する。

## Regex.compile・定数式・既存の検査関数

`Regex.compile(source: String)` の戻り値は `Result[Pattern, String]` である。[Regex.bnt](../../../../crates/benitoite/src/prelude/stdlib/Regex.bnt) 4〜6行で宣言し、[regex.rs](../../../../crates/benitoite/src/builtins/funcs/regex.rs) 147〜163行で `regex::RegexBuilder::new(source).build()` を実行する。現在は既定設定で組み立て、失敗を Result.Error にする。エラー表示の4096バイトへの切り詰めは同ファイル120〜143行である。

E0444 は [diag/codes.rs](../../../../crates/benitoite/src/diag/codes.rs) 27〜30行の RETIRED にある。同表は番号を使い回さないと明記する。新しい検査を元の用途で復活させるとしても、この規約の変更を伴うため、推す案は未使用の新しい E04xx を割り当てることである。調査段階では具体的な番号を予約しない。

トップレベルの定数式には、リテラル、定数参照、基本演算、構成子・レコード・リスト、定数だけの補間、列挙した Map・Set の呼び出しを認める。一般の関数・if・match・try は認めない（[01-02](../../../design/01-spec/01-02-syntax.md) 786〜808行）。実装では [consts.rs](../../../../crates/benitoite/src/typeck/consts.rs) 193〜262行の `bad_shape` が形を絞り、28〜88行で形・型の順に検査し、399〜455行以降で値を評価する。全定数の評価予算64 MiBは277〜278行にある。

したがって `const p: Result[Regex.Pattern, String] = Regex.compile(...)` を許す案と、関数の本体で `Regex.compile(source: 定数式)` を追加で検査する案は別である。推すのは後者だけである。任意の純粋関数を検査中に実行する機能（compile-time function evaluation、CTFE）は追加しない。既に [consts.rs](../../../../crates/benitoite/src/typeck/consts.rs) 173〜192行・918〜935行付近には、綴りではなく標準の束縛の識別情報で Map・Set・Pair を照合する先例がある。

既存の「失敗を値として返す」API には次がある。C はこれらと同じ利用の形から始められる。

| API | 返すもの・確認すること | 根拠となるファイルと行 |
|---|---|---|
| `Byte.fromInteger` | `Option[Byte]`、Byte に収まるか | [Byte.bnt](../../../../crates/benitoite/src/prelude/stdlib/Byte.bnt) 3〜5行、[byte.rs](../../../../crates/benitoite/src/builtins/funcs/byte.rs) 7〜11行 |
| `Integer.parse` | `Option[Integer]`、十進整数と範囲 | [Integer.bnt](../../../../crates/benitoite/src/prelude/stdlib/Integer.bnt) 7〜9行、[integer.rs](../../../../crates/benitoite/src/builtins/funcs/integer.rs) 17〜24行 |
| `List.head`・`tail`・`get` | `Option`、空・添字の範囲外 | [List.bnt](../../../../crates/benitoite/src/prelude/stdlib/List.bnt) 11〜21行、[list.rs](../../../../crates/benitoite/src/builtins/funcs/list.rs) 27〜55行 |
| `String.byteSlice`・`characterAt`・`characterSlice`・`fromUTF8` | `Option`、位置・文字の境界・UTF-8 | [String.bnt](../../../../crates/benitoite/src/prelude/stdlib/String.bnt) 7〜21行・87〜89行 |

`List.get` は既に範囲外を None にする。新しい添字型を加えるだけで既存の異常終了がなくなる、とは評価しない。`Integer.absolute` などの停止しうる演算も残るため、C の成功値について範囲を示しただけでは、後の全演算のあふれのなさは保証できない。

## 試作の証拠と今回の具体化

試作の出どころは、docs/todo の sources/2026-10-17-feasibility-spikes/142/findings.md・Scope.lean、および022/findings.md・Intervals.lean・Arithmetic.lean・Symbolic.lean・Certificates.lean・Contracts.leanである。非公開のためリンクしない。試作のビルド成功は記録の報告であり、S1 では再実行せず、本体の検査結果としても引用しない。

### 142 の成立した性質と不足

Scope.lean は、ホストを逆順のラベル列、パスを要素列にし、完全一致と「ある要素列以下」のパターンを扱う。`patLe_iff` と `portLe_iff` は制限した文法の包含判定と意味の一致を示す。`validate_sound` は成功値が元の対象を保ちパターンに適合すること、`checkedEvent_allowed` は検査した対象・ポートをそのまま使った一事象の適合を示す。52定理が独立した Lean ファイルで通ったという記録である。

第一案のエフェクト拡張には二つの反例がある。一原子ずつ覆う判定は分割した区間の和による包含を取りこぼす。相互に包含する範囲でも構文の列は異なり、整列と重複除去だけでは型の等号にできない。第二案にも `unindexed_policy_counterexample` があり、何らかの範囲で検査済みでも、別の指定した範囲への適合は得られない。

最初に作るものは、要素ごとの解析と照合、検査に用いた範囲と対象を保存する値、実行時の作成関数と取り出し関数、定数の引数の追加検査である。範囲の包含の自動判定・高階関数の型を通した範囲の保証は要らない。試作のホストの `tree(..., 1)` は一段以上のサブドメインを表すが、`*` の正式な意味ではない。今回の案では一段の `*.` と、一段以上の `**.` を区別する。この一段だけの照合は試作の tree と異なる条件なので、新しく定義・証明する必要がある。

文字列の解析・正規化、DNS、URL、OS のパス、シンボリックリンク、方針の失効は試作の証明に入っていない。今回も「字面に定めた条件への適合」と「実際の操作先への制限」を分ける。パスの検査の成功は、ファイルが存在することも、リンクを辿った対象が範囲内にあることも表さない。

### 022 の成立した性質と不足

Contracts.lean の `make_success` は、半開区間 `[lo, hi)` の作成成功から、値の保存と所属を導く。`make_none_iff` は失敗と範囲外の同値、`erase_make` は証拠を消した Option Int との一致である。`makeIndex_success` と `Indexed` は、添字を対象のリストと組にして保つ必要を示す。ほかのファイルを含む計69定理が通ったという記録である。

今回の最初の API は、上下端と値を受けて `Result[CheckedInteger, RangeError]` を返し、成功値の中に三つとも保存する案である。範囲の定義不良と値の範囲外を区別する。利用者が単に成否だけを要するなら、既存の `Result.ok` で Option へ変換できる（[Result.bnt](../../../../crates/benitoite/src/prelude/stdlib/Result.bnt) 56〜63行）。区間の上端は Integer の最大値も表せるよう閉区間 `[minimum, maximum]` を推す。試作の半開区間を `maximum + 1` で変換するとあふれうるため、閉区間の比較を直接定義し直す。

整数以外には、長さ、空でないリスト、対象のリスト付きの添字が候補である。今回は少数 API の意味と実装の接続を確かめるため CheckedInteger を推し、残る候補も問いに置く。静的な区間解析、if での絞り込み、部分型、演算の検査除去、SMT は追加しない。試作の反例は、最終結果の範囲だけでは途中の演算のあふれを防げないことも示している。

## 他の言語の一次資料

以下は2026-10-18に一次資料を確認した範囲である。実際の各言語のコンパイラをこの調査で実行してはいない。

| 仕組み | 確認した扱い | Benitoite の判断に使える点 |
|---|---|---|
| Gleam の中身を隠す型（opaque type） | `pub opaque type` は型だけを公開し、外部の構築・パターンを禁じる。作成関数で条件を狭める用途を説明している。[公式 Language Tour](https://tour.gleam.run/advanced-features/opaque-types/) | 既存の名目型の作り方を隠す案に近い。全既存型を抽象化し直す必要はない |
| Scala 3 の opaque type alias | 定義の内側では元の型と同じ、外側では別の抽象型となる。Option を返す安全な作成関数の例がある。[公式リファレンス](https://docs.scala-lang.org/scala3/reference/other-new-features/opaques.html) | 別名にも境界を設ける方式がある。ただし Benitoite の現行の透明な別名と型の計算へ影響するため、今回は data の方式を推す |
| Rust の非公開フィールド | 公開 struct に非公開フィールドを持たせられる。一方、公開 enum の variant は公開である。[Rust Reference](https://doc.rust-lang.org/reference/visibility-and-privacy.html#default) | record と data を機械的に同じ他言語の規則へ合わせる根拠にはしない。今回必要なのは型と構築の分離である |
| Gleam の正規表現の API | 現行 gleam_regexp v1.1.1 の `from_string`・`compile` は Result を返し、壊れた文字列が Error になる例を示す。[保守元の API 文書](https://gleam-regexp.hexdocs.pm/gleam/regexp.html#from_string) | 通常の関数と失敗値で扱う比較例である。この文書だけから「静的検査が一切ない」とは断定しない。旧 gleam_stdlib の regex は非推奨なので現行の比較から外す |
| Elixir の正規表現の記法（sigil） | `~r` はマクロである。v1.18.4 のソースでは、補間なしの文字列かつ OTP 28 未満ならマクロの展開中に `Regex.compile!` し、それ以外は実行時呼び出しを生成する。[Kernel の固定版ソース](https://github.com/elixir-lang/elixir/blob/v1.18.4/lib/elixir/lib/kernel.ex#L6042-L6071)、[Kernel 文書](https://elixir.hexdocs.pm/Kernel.html#sigil_r/2) | リテラルの記法があっても、常に検査時に組み立てるとは限らない。定数・補間・実行環境の区別が要る |
| Rust の書式文字列 | `format!` は文字列リテラルを要求し、コンパイラが書式と引数の適合を調べる。[std::fmt](https://doc.rust-lang.org/std/fmt/#usage) | ライブラリ固有の文字列を静的に検査する先例である。ただし通常の関数呼び出しではなくマクロであり、そのまま移す案ではない |

ここから「他の関数型言語では必ず静的に検査する／しない」という結論は導けない。Benitoite への推論は、既存の呼び出し方を保ち、確認できる定数だけを先に調べる方が、書き方を増やす費用を小さくできるというものである。通常の Result を残せば、実行時入力にも同じ API を使える。

## A と C で共有する部品

| 部品 | 共用する内容 | 分ける内容 |
|---|---|---|
| 型と作り方の公開範囲 | `@opaque` の解析、構成子・欄・更新・パターンの可視性、診断、formatter、生成道具への情報 | Scope は対象と範囲、Range は整数と端点の不変条件 |
| 定数の引数の取得 | 標準の束縛の同定、名前付き引数の位置、既存の定数値の利用、予算と位置の保持 | Regex の組み立て、Scope の文法・所属。C への適用は初版で行わない |
| 検査の意味 | 成功時の値の保存・条件の成立、失敗、証拠を消した実装との対応 | ホストのラベル・パスの要素・ポートと、整数の大小比較は別の判定 |
| 配布と文書 | リファレンス、同梱 Skill と生成物、移行案内、境界を示す利用例 | 142 のサーバ方針への接続と、022 の将来の区間解析 |

「定数の引数を調べる枠」を共用しても、検査関数を任意に登録・実行する汎用の属性は設けない。対象は標準ライブラリの少数の関数を固定表で列挙する。Regex と Scope の判定本体は実行時の実装と共用し、設定や構文のずれを減らす。型検査器から VM や IO を起動してはならない。

追加検査は、型や名前の誤りがある式を評価せず、定数でない引数は「検査しなかった」と扱う。直接の名前が標準の同じ束縛へ解決される import の別名は対象にし、同じ綴りの利用者関数や局所関数値は対象にしない。パイプやプレースホルダで一部の引数だけが与えられる場合も、必要な引数が揃う規則を明記する。推す初版はソース上の通常の直接呼び出しだけであり、それ以外は実行時検査へ残す。

## 形式化の内外と証明の案

現行の [07-04「01-12 との対応」](../../../design/07-quality/07-04-formal-semantics.md#01-12-との対応) は、名前解決・定数式の形や実際の値の評価・組み込みの内部の意味を、型付き表層の規則と区別している。Release の `Ty.opaque` は名前、値は名前と識別値を持つだけで、範囲への適合を表さない（[Types.lean](../../../../formal/Benitoite/Release/Types.lean) 25・47行、[Syntax.lean](../../../../formal/Benitoite/Release/Syntax.lean) 49・69行）。

| 変更の案 | 07-04 による判定の案 | 実装へ進む前の条件 |
|---|---|---|
| 属性で構成子・欄へのアクセスを拒否し、従来の data・record へ渡す | 既存の名前解決の外側。型付き表層の形・型付け・脱糖を変えない条件付き | 型表には内部の全構成子を残す。隠したからといって型の意味や網羅性の表を削らない。対応表へ境界を記す |
| Regex・Scope の定数の直接呼び出しだけを追加で拒否する | 定数評価と標準束縛の同定として外側 | 受理した式を従来の Call として渡す。返り値の型・脱糖・実行時の検査を変えない。対応表へ追加検査の保証と限界を記す |
| Scope と Range を普通の data・関数・Result で表す | 既存の型・脱糖を使用。個別 API の意味は既存の型保存の結論に含まれない | 下の小さな意味の定理と Rust／Benitoite の実装との対応を別に示す |
| opaque の新しい表層型・篩の型・部分型や検査除去を導入する | 形式化の内側。今回は推さない | 必要なら仕様を再判断し、Lean の型・規則・脱糖・証明・写しを処理系より先に直す |

推す案の小さな意味の証明は、次の四つに限る。

1. Scope の解析結果に対する照合の成功から、保存した対象が保存したパターンに適合すること。完全一致・一段の `*.`・一段以上の `**.`・パス末尾 `/**` をそれぞれ定義する。
2. CheckedEndpoint の成功から、保存したホストの適合と `0 ≤ minimumPort ≤ port ≤ maximumPort ≤ 65535`。ポート0の意味は利用する IO ごとに別である。
3. CheckedInteger の成功から、値と端点の保存、および `minimum ≤ value ≤ maximum`。逆転した端点と範囲外を区別した失敗の性質。検査は加算せず比較だけで行う。
4. 証拠を消した値・Result の作成との一致。取り出す操作が保存した値を返し、別の対象や範囲へ置き換えないこと。

実際の文字列解析の全体、隠した構成子を通れないことのソース言語全体の定理、全 IO の対象安全は、この小モデルだけでは証明できない。文字列を要素列へ分ける実装との対応、公開境界、Result の分岐と返す値は、対応表と独立した期待値による検査で結ぶ。Lean の Subtype の証拠を Benitoite の実行値にも持つと説明しない。組み込みの型保存の既存の仮定を、対象安全の仮定へ黙って強めない。

Lean の変更を版に含める場合は、A・C 以外の対象も含め、版の最初の段にまとめる。既定の `lake build` が sorry なしで通り、定義・言明・仮定のレビューが完了してから処理系へ進む。内側の規則を変えるなら01-12の写しも同時に直す。Release を保つ案でも、新しい局所証明を本体の定理への接続済みの証拠と混同しない。

docs/todo の TODO-250 の「一回に重い形式化は一つまで」という方針は保つ。今回指定された13件を過去の組み方へ戻す提案はしない。A・C は上の制限なら重い三種類を避けられる見込みである。調査後に Release の拡張が必要と分かった場合は、他の中心項目と合わせた重さを再評価してから計画を確定する。

## 作業数と時間の幅

次は設計者の回答後に行う実装の見込みであり、S1 自体の所要時間でも0.0.9全体の工数でもない。1作業30〜60分を通常の目安とし、証明と接続で長くなる箇所は時間の幅を優先する。設計者の回答待ち・レビュー待ち・全体検査の待ち時間は含めない。複数のエージェントを使うことも前提にしない。

| まとまり | 作業数 | 作業時間の幅 | 根拠 |
|---|---:|---:|---|
| 共通の公開範囲 | 5〜8 | 4〜8時間 | 属性、型と構成子の分離、record の複数入口、公開契約、formatter・derive 情報・診断の読者 |
| 共通の定数検査と026 | 4〜6 | 3〜6時間 | 直接呼び出しの同定、定数の取得と予算、実行時との Regex 判定共用、診断と互換性 |
| 142 の範囲・値・API | 7〜11 | 6〜12時間 | 小さい文法、保持する範囲と対象、三種類の値、異常入力、取り出し、境界の文書 |
| 022 の整数 API | 3〜5 | 3〜6時間 | 閉区間の検査・二種類の失敗・値と端点の保持。演算や長さ型は含めない |
| A・C の局所的な意味の証明と対応 | 6〜10 | 6〜14時間 | 試作142の2〜6時間、022の4〜12時間を出発点とし、重なる成功・保存の形を共用。文字列の全体証明は含めない |
| 接続のレビュー修正・文書と生成物 | 3〜5 | 3〜6時間 | 隠す境界、定数と動的入力、英語リファレンス・Skill・例の照合 |
| 合計 | **28〜45** | **25〜52時間** | API と公開範囲を小さく固定した場合の見込み |

試作142の処理系8〜20時間には、利用者定義型の新しい公開境界を全入口へ実装する調査は含まれていない。022の通常値の検査APIの6〜20時間も、そのまま構築を隠す型の完成時間にはならない。本表では共通の土台を別計上し、A・C で二重に数えない。独立した本番値の格納方式の試作や、変更差分に基づく実測見積もりは未実施である。

長さ型・空でないリストを加えるなら合計4〜8作業・4〜10時間を追加する見込みである。Checked 値専用の IO の一式、任意の URL の意味、実パスの隔離、サーバ方針の失効、新しいヒープ配置は上の幅に含めない。これらは既存 API と実行器の追加調査なしに時間の上限を約束できない。

## S1 の確認と後の計画への申し送り

今回の成果物は調査文書なので、Rust・Lean の検査は実行しない。作業末の入口は、開始版を基準に `scripts/check.sh --level work --base 6b0568a3ddcc46b0a0e64504139ce286a27fd86a` とし、同じ指定に `--dry-run` を付けてから一度実行する。文書の分類で選ばれる検査がない場合、その成功を実装の回帰検査の成功とは扱わない。リンク・写し・問いの番号・差分も確認する。実行結果は S1 の結果記録に残す。

実装プランは回答を受けてから、共通依頼文と雛形を具体化して作る。work は直前の取り込みを基準とし、Rust の lib 全件・関連統合テスト・clippy・fmt と生成物を入口へまとめる。stage は公開範囲と生成器、定数と Regex／Scope の新しい接続を名指しする。change は改造全体の回帰を一度、release は実際の候補の版・CLI・生成物・移行案内を照合する。今回の文書だけで後の検査の成功や省略を認めない。

処理系へつなぐ計画では、形式化の内側へ入る場合の `check-formal.sh` 全体と、最終の関係状態への実行または引用を別に割り当てる。ヒープや安全点を越える値を変えるなら、doc_default・局所 heap-verify／gc-stress・必要な check-heap も前提へ加える。通常の data と関数だけで済むなら、その条件に当たらない理由を記す。結果の引用は07-03の全欄が揃う場合に限る。
