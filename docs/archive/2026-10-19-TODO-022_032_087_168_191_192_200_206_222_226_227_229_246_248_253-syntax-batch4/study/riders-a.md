# 相乗り A の調査: ログ・整数の網羅性・検査済みの値・生成

2026-10-19。処理系の開始版は c31e64b03d2810343e1779926bea4ebc958b6164（0.0.9）、調査時の HEAD は 19174b5a50570233288aa76d0f3670ca7ef20c4e、ブランチは mod010/design である。両コミットの差は S1 の文書3ファイルだけであり、ここで調べた処理系は開始版と同じである。対象の本文は [項目の写し](../todo-items.md)、採否と選択肢は [26問](riders-a-questions.md) に置く。以下は調査と提案であり、設計者の決定、実装、証明の成功を表さない。

## 1. 採用する範囲の案と前提

ログ、三種類の検査済みの値、再帰・型パラメータを持つレコードの生成を進める案を推す。Integer の全域も採る案を第一候補にするが、Lean の定数の有界化を先に確かめる区切りが要る。Character の変更をそのまま写すだけでは済まない。専用の Property CLI は今回も含めず、その分を生成の対応範囲へ使う案である。

根拠は現行の [目的と設計原則](../../design/00-overview/00-01-goals.md)、[検査の四水準](../../design/07-quality/07-03-compiler-testing.md#実装の規約と静的な検査)、[形式化の内外と先行順序](../../design/07-quality/07-04-formal-semantics.md#01-12-との対応) とする。docs/todo の TODO-250 末尾の方針に従い、版に含む Lean の変更は処理系より先の一段にまとめる。エフェクトを外す中心の TODO-248 に、暗黙のエフェクト、エフェクトに値・型を加える規則、型の計算を追加しない。

前回の [README](../../archive/2026-10-18-TODO-021_022_026_032_087_088_142_164_248_257_258_259_260-syntax-batch3/README.md)・[判断](../../archive/2026-10-18-TODO-021_022_026_032_087_088_142_164_248_257_258_259_260-syntax-batch3/decisions.md)・[詳しい設計](../../archive/2026-10-18-TODO-021_022_026_032_087_088_142_164_248_257_258_259_260-syntax-batch3/design.md)・[計画](../../archive/2026-10-18-TODO-021_022_026_032_087_088_142_164_248_257_258_259_260-syntax-batch3/plan.md)・[結果](../../archive/2026-10-18-TODO-021_022_026_032_087_088_142_164_248_257_258_259_260-syntax-batch3/results.md)・[RV5](../../archive/2026-10-18-TODO-021_022_026_032_087_088_142_164_248_257_258_259_260-syntax-batch3/reviews/RV5.md) は、調査と問いの分け方、R10〜R12 の見送り、検査時間の教訓を読む資料とした。当時の判断を今回の決定へ読み替えない。

## 2. TODO-206: 組み込みのログ

### 2.1 試作で確かめた範囲

docs/todo の sources/2026-10-11-language-direction/memo.md と log-trial/ の log.bnt・sinks.bnt・project/ を読んだ。試作は利用者の Log エフェクト、emit または write 操作、水準・文字列・属性の列を使う。ハンドラで水準を選び、出力先の関数を複数呼び、属性を足して外側のハンドラへ操作を送り直す。project/ は書く側をロガーの選択から分けている。

この記録は 2026-10-11 に実行した結果である。今の 0.0.9 で再実行はしていない。試作には旧版の複数の位置引数や旧関数型の綴りが残るため、そのまま現行の受け入れ入力には使えない。時刻と位置、一度開いたファイルを捕捉する出力先、JSON 出力は、試作の成功範囲に含まれない。

### 2.2 現在の宣言・実行・報告

次の位置はいずれも調査時の行番号である。

| 役割 | 現在の処理と追加する場所 |
|---|---|
| 操作の宣言 | [Console.bnt:4](../../../crates/benitoite/src/prelude/stdlib/IO/Console.bnt#L4) が Write の4操作を宣言する。組み込みのログも標準ソースに操作の型を置き、Rust の実体と照合する形を使える |
| エフェクトの識別 | [types/builtin.rs:369](../../../crates/benitoite/src/types/builtin.rs#L369) の BuiltinEffectDef と、同:412 の BUILTIN_EFFECTS が正規名・IO.All への所属・ソース宣言の有無を持つ。番号は末尾追加である |
| IO.All | [types/builtin.rs:385](../../../crates/benitoite/src/types/builtin.rs#L385) と [IO.bnt:1](../../../crates/benitoite/src/prelude/stdlib/IO.bnt#L1)。型への変換時に in_io_all が真の原子へ展開し、確定した EffectSet には IO.All 自体を残さない |
| 標準の公開名 | [prelude/mod.rs:8](../../../crates/benitoite/src/prelude/mod.rs#L8) に埋め込みモジュールと prelude 指定がある。[resolve/collect.rs:233](../../../crates/benitoite/src/resolve/collect.rs#L233) が State と標準モジュールを prelude に登録する |
| ハンドラの検査 | [typeck/effects/handle.rs:45](../../../crates/benitoite/src/typeck/effects/handle.rs#L45) は BindingKind::Op を要求する。Console の effect 操作も処理できる。State を持つ普通の組み込み関数は操作ではなく、同じ扱いで捕捉できない |
| ハンドラの探索 | [vm/dispatch/handlers.rs:403](../../../crates/benitoite/src/vm/dispatch/handlers.rs#L403) の find が局所・継承ハンドラを探す。同:482 の io は見つからなければ None を返す |
| 既定の動作 | [vm/dispatch/handlers.rs:46](../../../crates/benitoite/src/vm/dispatch/handlers.rs#L46) は IO 命令で先に io を呼び、未処理なら Assert の特別処理、次に execute_builtin へ進む。ログの既定の出力は、この既存の未処理 IO の口に組み込み関数として足せる |
| 標準エラーへの出力 | [builtins/funcs/console.rs:33](../../../crates/benitoite/src/builtins/funcs/console.rs#L33) と同:83 の write_text が Stream::Stderr と write_output を使う。ログも同じ出力バッファ・待ち・失敗の扱いへ接続する。ホストの stderr へ直接書く別の口を作らない |
| 宣言上限 | [cli/inspection.rs:49](../../../crates/benitoite/src/cli/inspection.rs#L49) は関数の確定した宣言上限を原子的な組み込みエフェクトの一覧にする。利用者の未処理エフェクトは入口で受理しない |
| 許可の照合 | [cli/effect_limit.rs:17](../../../crates/benitoite/src/cli/effect_limit.rs#L17) が正規名を解析し、同:39 が宣言上限と比べ E0512 を出す。これは実行前の上限照合であり、OS の隔離や実行時の権限制御ではない |
| JSON の契約 | [cli/check_report.rs:54](../../../crates/benitoite/src/cli/check_report.rs#L54) は effects.basis=declaredUpperBound、expanded=正規名の列を出す。同:180 の schemaVersion は1。実行せず、上限を報告する契約を保って Log を追加する |

利用者のハンドラが処理した操作について、処理系の既定出力を重ねてはならない。逆に節の中で操作を呼び直せば、そのハンドラの外を探し、最後まで未処理なら既定出力を使う。Log を単なる Console.writeErrorLine の補助関数にすると、利用者のハンドラに届く前に出力先を決めてしまうため、独立した操作にする理由がある。

### 2.3 名前と操作の案

エフェクトの正規名を Log、標準モジュールを Benitoite.Unofficial.Log、操作を Log.emit と Log.enabled にする案を推す。Log モジュールを prelude に置き、明示した uses Log のまま使えるようにする。通常の補助関数は Log.debug・info・warn・error とする。

ただし、現在の名前解決では同名の標準モジュールをエフェクトとして読む仕組みが不足する。[resolve/lookup.rs:1051](../../../crates/benitoite/src/resolve/lookup.rs#L1051) の final_name は Type・Record・Class・Ctor・Value では同名の内部宣言を選ぶが、Effect では選ばない。同:184 の type_in_module と同:196 の as_module も確認した。標準モジュール内の public effect Log を uses Log から解決し、Log.info を同じモジュールへ解決する一般の規則を足す必要がある。モジュールの束縛を根の組み込み Log で上書きする案は採らない。代案は既存どおり Log.Output と書くことであり、L1 で選ぶ。

表のソース宣言は module=["Log"]・name="Log" として同定する案である。このまま現行の effect_name を使うと表示が Log.Log になるため、同名の標準モジュールとエフェクトを短い正規名 Log へ写す規則も必要になる。型表示・CLIの許可名・JSON報告・パッケージの契約の集計を同じ規則へ揃える。内部の宣言の同一性は解決済みの番号と完全な名前で保つ。この表示の追加を、既存の表への一項追加だけで済むとは扱わない。

API の具体案は次である。SourceLocation と Log の型は説明用の修飾名であり、現在存在する API ではない。

~~~text
Log.emit(record: Log.Record) -> Unit uses Log
Log.enabled(level: Log.Level) -> Boolean uses Log
Log.info(message: String, attributes: List[Log.Attribute],
         location: SourceLocation.Location) -> Unit uses Log
Log.debug / Log.warn / Log.error も同じ引数
Log.Attribute = key: String と value: Log.Value の普通のレコード
Log.Record = level・message・attributes・location の普通のレコード
~~~

emit は水準に応じて情報を渡す操作であり、enabled は選択されたハンドラに問い合わせる操作である。Log を完全に処理するハンドラは両操作の節を持つ。既定の enabled は Info 以上を真とし、emit も同じ基準で判定する。問い合わせをせず emit することも許す。複数の出力先を使うハンドラの enabled は、どれか一つが出すなら真とする。

### 2.4 位置を得る二案と形式化

ソース位置（source location）を「式を書いた位置」と「実行時にその操作を呼んだ位置」に分けて比べる。この区別をしないと、Log.info の本体に置いた位置の式が、利用者の呼んだ行を指すと誤解する。

| 案 | 仕組みと利点 | 追加が必要な契約と形式化 |
|---|---|---|
| A: 操作の節が呼び出し位置を受け取る | どの操作の節でも操作命令の位置を読める。利用者のログにも使える | 節に暗黙の値を束縛するなら、Surface/Release の節の引数、型付け、代入、継続と交換形式の内側である。注釈だけに見せて証明対象から外せない。Log.info を挟むと、得られるのはその内部の emit の行であり、利用者の位置へ遡る追加規則も要る |
| B: 位置を表す式 | SourceLocation.here() のような専用の式を、その式のファイル識別子と行・列から作る通常の値へ展開する | 型付き表層に渡す前に通常のレコード構築・リテラルになるなら、位置の取得と名前の同定は07-04の外側に置ける。SourceLocation という新しいコア基本型や、実行時のスタック探索は要らない |

B を推す。ここでの「脱糖後にリテラルなら外」は条件が足りない。形式化した型付き表層に新しい位置の式を残し、その脱糖でリテラルへ変えるなら、その場合の型付け・型保存は内側である。形式化へ渡す前に展開を終え、既存の表層のレコードとリテラルだけを書き出す案を区別する必要がある。

呼び出す側で次のように位置を明示する。既定引数は [構文の現行規則](../../design/01-spec/01-02-syntax.md#名前付き引数と関数型) の範囲にない（同ファイル284行）ので、位置を暗黙に補う既定引数を今回だけ仮定しない。

~~~text
Log.info(message: "集計を終えた", attributes: [],
         location: SourceLocation.here())
~~~

SourceLocation.here() は説明用の API 案である。引数なしの直接呼び出しを解決済みの標準束縛で認識し、位置の値へ置き換える。別名 import は認め、同じ綴りの利用者関数は特別扱いしない。関数値化・部分適用は拒否する案とする。ラムダ内の直接呼び出しは、そのラムダを書いた位置になる。包む関数は位置を明示して受け取り渡す。これは Rust の呼び出し位置の自動伝播を実装する提案ではない。

Location は file: String・line: Integer・column: Integer とする。file はパッケージ識別とパッケージ内の相対パスを含む表示用識別子、行・列は1始まり、列は既存診断と同じUnicodeコードポイント数にする案である（base/source.rs:16、同:74のline_col）。パスを開く権限やファイルの存在は表さない。文書例の仮想入力は元のコメントの位置へ戻す。入力元がない内部生成コードは利用者の位置を捏造せず、API からの直接呼び出しを生成しない。これらと日本語・複数バイト文字の列、同名ファイル、外部パッケージの識別を Rust 側で照合する。

### 2.5 他言語の一次資料

以下は2026-10-19に一次資料を読んで確かめた事項である。Benitoite で同じ機能があるという根拠にはしない。

| 対象 | 確認した事実と今回の判断への含意 |
|---|---|
| Go log/slog | メッセージ・水準・属性を Record と Handler に分け、既定ロガー、TextHandler、JSONHandler を持つ。Debug・Info・Warn・Error の補助と Enabled があり、無効なログでも通常の引数は評価される。包む関数では出力元の位置を自分で渡す必要がある。[公式パッケージ文書](https://pkg.go.dev/log/slog#hdr-Overview)、[包む関数](https://pkg.go.dev/log/slog#hdr-Wrapping_output_methods)、[費用](https://pkg.go.dev/log/slog#hdr-Performance_considerations) |
| Rust | #[track_caller] が付いた呼び出しの連鎖を Location::caller() が観測する。Location から file・line・column を得る。関数ポインタへの変換では実際の呼び出し位置を失う場合が明記されている。[Rust Reference](https://doc.rust-lang.org/reference/attributes/codegen.html#the-track_caller-attribute)、[std::panic::Location](https://doc.rust-lang.org/std/panic/struct.Location.html) |
| Swift | #fileID・#line は現在、標準ライブラリのマクロとして実装される。単独のマクロ式を引数の既定値にすると呼び出し側の位置で評価するが、より大きい式の内部では宣言側の位置になる。式だけで補助関数の呼び出し元が自動で得られるわけではない。[Swift Book の公式ソース、Literal Expression と Macro-Expansion Expression](https://github.com/swiftlang/swift-book/blob/main/TSPL.docc/ReferenceManual/Expressions.md) |
| Kotlin | Kotlin 向けライブラリ kotlin-logging は、無効な水準ならメッセージのラムダを評価しない書き方を提供する。これは言語標準の logging 機能の説明ではない。[開発元の README](https://github.com/oshai/kotlin-logging#call-log-methods-without-checking-whether-the-respective-log-level-is-enabled) |
| Python logging | Logger・Handler・Formatter を分ける。stacklevel は包む関数の枠を飛ばす位置指定、extra は記録の追加属性である。msg と引数を分けて整形でき、isEnabledFor で水準も調べられる。[公式 logging 文書](https://docs.python.org/3/library/logging.html#logging.Logger.debug)、[isEnabledFor](https://docs.python.org/3/library/logging.html#logging.Logger.isEnabledFor) |

Swift の Web 表示は JavaScript を要求したため、同プロジェクトの文書ソースを読んだ。#fileID の文字列の厳密な組み立て方は今回の確認範囲から外す。Kotlin の標準ライブラリに一般の logging がないという否定の主張も、この調査では行わない。

### 2.6 既定の出力と費用の案

既定は標準エラーへ一記録一行のテキストを出し、Info 以上とする。水準は Debug・Info・Warn・Error の四つ、Error に終了の意味を持たせない。時刻は初版の既定出力に含めない。時刻を付ける利用者のハンドラは Clock.Time を宣言する。これにより時計取得を Log の裏で追加せず、固定入力の報告を比較できる。

形式は level=INFO source="app/Main.bnt:12:3" message="集計を終えた" と、その後の属性 key=value とする。文字列値と鍵は JSON の文字列と同じ引用・エスケープ規則で一行に収め、改行・制御文字を生のまま挿入しない。属性は宣言されたリスト順を保ち、予約した level/source/message と区別するため属性の鍵を attr."key" と表す案である。重複した鍵も勝手に消さない。これは JSON そのものの形式ではない。JSON 出力を標準の第二の既定形式としては増やさず、公開した Record から利用者のハンドラで組み立てられるようにする。

属性の値は閉じた Log.Value とし、Text(String)・Boolean(Boolean)・Integer(Integer)・UnsignedInteger(UnsignedInteger64)・Float(Float) の案を推す。幅付きの数は損失のない対応先へ変換する。Float の非有限値は文字の nan・inf・-inf として出し、JSON の数だと説明しない。任意の型の存在型や、操作に型クラス辞書を直接渡す API は足さない。Log.attribute[T: ToLogValue] と変換の型クラスを普通の標準ソースで提供し、利用者は明示した実装で表現を選べる。表示がそのまま機密情報の保護になるとは保証しない。

メッセージと属性を作る費用は、通常の引数評価のままでは捨てられない。第一案は Log.enabled の後の if 内で文字列補間と属性の構築を行う形とする。Lazy のメモ化や例外の保持をログの意味へ持ち込まない。問い合わせから emit までの間に利用者が状態を変えることは可能なので、enabled は予約や必ず出力する保証ではない。低費用を必要としない短いログは直接 Log.info を呼べる。

IO.All には Log を含めず、独立した原子として表示する案を推す。現行の Http.Listen/Connect・Assert.Check のように、組み込みだから必ず IO.All に入れるという規則ではない。既定が stderr を使うことは Log の説明に明記し、同じ操作に Console.Write も重ねて要求しない。利用者の出力ハンドラが File.Write を使えば、その外側の宣言上限は File.Write になる。check --report=json の declaredUpperBound にはその上限を出し、実際に書いた回数や未使用水準を推定して消さない。既定出力を使う main の --allow-effects には Log が必要である。

### 2.7 07-04 の内外

Log は型や値をパラメータに持たない普通のエフェクト名である。Release.Atom の名前は String（[Atom.lean:13](../../../formal/Benitoite/Release/Atom.lean#L13)）であり、Log 専用の集合演算は要らない。未処理の IO をホストで処理する仕組みと、捕捉された操作の規則を使う。既定出力と enabled の返り値は組み込みの既存の IO の契約に載せ、新しい種類の消去規則や Builtins.Assumptions の追加を必要としない案である。

ただし、標準宣言・組み込み表・交換入力の追加と、表層検査・操作捕捉の実例の照合は要る。SourceLocation.here の事前展開、同名モジュールの名前解決、具体的な書式と出力バッファは形式化の外側として07-04の対応表へ記す。実装時に新しい節の引数や動的な位置取得へ変更するなら、この分類と見込みをやり直す。

## 3. TODO-191: Integer の範囲の網羅性

### 3.1 Character で変えたことと現在の整数

0.0.8 の [判断 G1](../../archive/2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/decisions.md)（342行付近）と [詳しい設計](../../archive/2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/design.md#todo-191-characterの全域の網羅性) は、Character だけを全域判定へ変え、Integer の有界化を含めないとした。文字では Unicode スカラー値の二つの閉区間を端点で分割し、文字の列から「その他」を外した。直積の欄の相関を保ち、各列を特殊化する手順を使う。

現行の [typeck/patterns.rs:392](../../../crates/benitoite/src/typeck/patterns.rs#L392) の shapes は Integer と Character を区間に分ける。Character は有効な値域の境界を加えるが、Integer には常に Shape::Other を残す。同:374 の interval は整数を i64 から i128 へ広げて端点を計算する。Integer の全域の範囲でも網羅としない例は同:1083 に残る。

Lean 側の [Coverage.lean:138](../../../formal/Benitoite/Release/Coverage.lean#L138) に charBounds/charPartition、同:961 に char_partition_cover、同:1028 に shapeStep_character がある。整数は同:185 の shapes に other を保ち、同:1015 の shapeStep_integer と有用性（usefulness）の補題へ接続する。0.0.8 の成功は、この文字の変更についての証拠である。

### 3.2 有界のモデルを先にそろえる理由

Integer と Integer64 は同じ基本型であり、値域は −2^63〜2^63−1 である。[types/builtin.rs:58](../../../crates/benitoite/src/types/builtin.rs#L58) の別名の定義を確認した。一方、[Release/Syntax.lean:41](../../../formal/Benitoite/Release/Syntax.lean#L41) の Const.integer は Lean の Int を持ち、[Typing.lean:260](../../../formal/Benitoite/Release/Typing.lean#L260) の Inhabits.const はその任意の定数を含む。

したがって「−2^63〜2^63−1 を覆えば現行の Exhaustive が成り立つ」とする命題には、値 2^63 が反例になる。交換の読み込みで範囲外を拒否するだけでは、Lean の全値に関する定理の反例は消えない。Checked.Range の IntegerRepresentable は独立した小モデルの入力条件であり、現行の Inhabits に自動で適用されるものでもない。

採る場合の第一案は、通常の型 Ty を増やさず、Const.integer の数値を符号付き64ビットで表せる値に限定することである。数学上の定義案は Signed64 = { n : Int // −2^63 ≤ n ∧ n ≤ 2^63−1 } とする。範囲の端点の計算では Int に戻して max+1 を扱う。数値の演算は既存の組み込みの仮定を使い、算術全体の正しさやあふれの不在の証明へ広げない。

Surface は [Syntax.lean:53](../../../formal/Benitoite/Surface/Syntax.lean#L53) の正のリテラルに Nat、同:117以降の正・負のパターンとExpr.negIntにも自然数の大きさを持つ。したがってConstだけを変えず、正の大きさは2^63−1以下、直接の負号の大きさは2^63以下という異なる有限の入力へ制限する。最小値の負号の右の2^63を、単独の正のリテラルとして先に検査して拒否しない。Literal.toConst・Pattern.toCore・negIntの脱糖と交換の読者をこの差へ接続する。括弧を挟む通常の単項演算の規則は維持する。

別案は値の全体に「実装で表せる値」の述語を足し、Exhaustive と型付け・実行の接続にその条件を渡すことである。この案はリスト・レコード・関数の結果・組み込みの応答まで条件を保存する仕事になる。表層検査器だけを有界にして、コアの網羅性の前提へ未証明の仮定を足すことは推さない。

### 3.3 採る型と診断・移行

今回採るのは Integer/Integer64 だけを推す。Integer8・Integer16・Integer32・UnsignedInteger16/32/64・Byte/UnsignedInteger8 は、現行では数値のリテラル・範囲パターン自体を許さない。[typeck/pattern_ext.rs:113](../../../crates/benitoite/src/typeck/pattern_ext.rs#L113) の range_end と同:215 の変換、および07-04の幅付き数の対応を確認した。Integer64 の接尾辞 s64 は同じ旧整数へ分類される範囲で扱い、別の基本型にはしない。

将来ほかの幅を扱うときの有界モデルは、符号付き w ビットなら [−2^(w−1), 2^(w−1)−1]、符号なしなら [0, 2^w−1] である。Int8/UInt64 は他言語との比較の呼び方であり、Benitoite の公開名は Integer8/UnsignedInteger64 である。今回この表に従って数値パターンの構文まで広げると、型検査・パターン表現・交換・コード生成の対象が増えるため分ける。

Integer の判定は min と max+1 を端点へ足し、隙間も含む全域の区間を作って Other を外す。端点ごとの計算は i128/Lean Int で行い、値を列挙しない。ガードのある行を網羅の根拠にしない、直積の相関を保つ、燃料切れは網羅とみなさない、という現行の条件を保つ。TODO-032・200 の判定の最適化と同じコードへ触れるため、判定の意味と計算量の変更を計画で接続する。

全域を覆うガードなしの行の後の case _ は E0602 にする案である。Character と同じ「決して選ばれない分岐」の規則に揃える。移行では、その case _ の削除を案内し、複数の区間・レコードの欄・List の入れ子まで同じ結果になることを確認する。必要な処理を最後の _ に残したい場合は、先の区間を本当に全域でなくなるよう直す必要がある。根拠を示さず末尾の分岐を一括削除する移行器は追加しない。

Rust は固定幅の整数について最小値から最大値までの範囲を全域とし、全域の範囲パターンを反駁不能（irrefutable）とする。usize/isize への特別な規則まで Benitoite の64ビット Integerへ持ち込むものではない。[Rust Reference の range patterns](https://doc.rust-lang.org/reference/patterns.html#range-patterns)

### 3.4 Lean の変更の大きさと採用の条件

変更は07-04の内側である。区間の被覆・候補の区間・ShapeStep・任意の view と燃料の補題U、網羅性・非選択・束縛・表層検査器の健全性までつなぐ。有限の整数定数は型と行の代入で変わらないため、Ty/Eff の構成子や代入の意味を増やす変更とは区別できる。ただし Syntax・Surface のリテラル・交換の読者と多数の例にも波及するので、「Character と同じ数行の修正」とは見積もらない。

Lean 段の先頭で Signed64 の表現と整数リテラルの接続を試し、既存の進行・保存・エフェクト健全性・性質1・網羅性の定理の外側の前提を増やさず閉じることを条件にする。ここで値全体の新しい不変条件や組み込み応答の新仮定が必要になれば、第二の重い形式化として扱い、設計者へ範囲を戻す。S2 の調査だけで軽いと確定したわけではない。見送りは I1 の明示した選択肢として残す。

## 4. TODO-022: 長さ・空でないリスト・添字

### 4.1 既存の CheckedInteger と試作の限界

[Range.bnt:47](../../../crates/benitoite/src/prelude/stdlib/Range.bnt#L47) は @opaque public record CheckedInteger に最小・最大・値を保存し、同:61 の checkInteger が閉区間を確かめて Result を返す。逆転した範囲を先に報告し、上端へ1を足さない。値ごとに範囲が違っても型は同じであり、静的な篩型ではない。

[Checked/Range.lean:21](../../../formal/Benitoite/Checked/Range.lean#L21) は証拠付き構造、make、成功・二種類の失敗・証拠を消した計算と射影の一致を示す。同:91 付近の IntegerRepresentable は実装との照合条件である。07-04はこの証明を主定理から独立させている。@opaque の公開境界は名前解決で保証し、Lean の小証明だけで Rust の境界まで証明したことにはしない。

docs/todo の試作022の findings.md と Contracts.lean も読んだ。makeIndex は Fin xs.length を作り、Indexed は元リストと添字を束ねる。長いリストの添字を短いリストへ流用できない反例がある。他の .lean の区間・算術・置換・証明書の定義も確認したが、それらの静的解析を今回の API へ加える案ではない。試作248の findings.md と局所操作・捕捉・領域・脱糖の小モデルは、通常の値と構築器を混同しない根拠の補足として読んだ。これらを正式モデルの検査結果へ引用しない。

### 4.2 三つの型と API の案

Range には整数の契約がすでにあるため、長さの数だけを別に包む型は加えず、対象を保持する型を加える。空でないリストは慣用名 NonEmptyList とする。不変の List を共有して保存し、元の値を勝手に書き換える口を公開しない。

| モジュールと不透明型 | 作成関数と読み出しの案 | 成功時に残す情報 |
|---|---|---|
| Benitoite.Unofficial.Range.CheckedLength[T] | `checkLength[T](minimum: Integer, maximum: Integer, values: List[T]) -> Result[CheckedLength[T], LengthError]`。lengthValues(value) -> List[T]、length(value) -> Integer、lengthMinimum/lengthMaximum(value) -> Integer | 閉区間の両端、元リスト、検査した長さ |
| Benitoite.Unofficial.NonEmptyList.NonEmptyList[T] | `fromList[T](values: List[T]) -> Result[NonEmptyList[T], EmptyListError]`。toList(value) -> List[T]、head(value) -> T、tail(value) -> List[T]、`map[T,U](value, f) -> NonEmptyList[U]`（f のエフェクトを明示して伝える） | head と tail、または元リストと先頭値。空の構築口を公開しない |
| Benitoite.Unofficial.Range.CheckedIndex[T] | `checkIndex[T](values: List[T], index: Integer) -> Result[CheckedIndex[T], IndexError]`。indexValues(value) -> List[T]、index(value) -> Integer、get(value) -> T | 元リスト、0始まりの添字、検査で取り出した要素 |

表の補助名は衝突を避ける案であり、Range.value の多重定義を仮定しない。すべて純粋な API とし、NonEmptyList.map のみ渡した関数のエフェクトを持つ。CheckedLength を、String のバイト数や文字数をまとめた型にはしない。今回の「長さ」は List の要素数とする。文字列と Bytes の API は単位を選ぶ別の問いが要るため、この初版へ黙って加えない。

LengthError は InvalidBounds(minimum, maximum) と OutOfRange(minimum, maximum, actual)、IndexError は OutOfBounds(index, length)、EmptyListError は空であることを表す一種類とする。Length は 0 ≤ minimum ≤ maximum を先に検査し、その後 List.length の閉区間を調べる。負の添字と長さ以上の添字は同じ OutOfBounds だが入力値を保持する。失敗の値に要素の全体を保存せず、Result から利用者が回復の処置を選ぶ。

CheckedIndex.get が別のリストを引数に取らないことが要点である。長さだけを保持する CheckedIndex を任意の List.get に渡す形では、元より短いリストへの取り違えを防げない。検査で成功した要素を包みにも保存すれば、get は Option の取り出しに再失敗せず普通の射影で実装できる。NonEmptyList も head と tail を持つ表現なら、head で通常の List.head の失敗を再導入しない。List の記憶域は共有できるが、元の長いリストを包みが生存させる費用は残る。

既存の [List.bnt:11](../../../crates/benitoite/src/prelude/stdlib/List.bnt#L11) の length、同:19 の head、同:27 の get は保つ。head/get はすでに Option を返すため、この追加の価値は新しい異常終了の防止だけではなく、検査と使用を分け、以後の読み出しの戻り値を T にできる点にある。CheckedLength から別の長さ範囲への暗黙変換や、List への部分型化は加えず、条件を変えるときは作成関数で再検査する。

### 4.3 小証明の追加と他言語

独立した小モデルで、任意の要素型について次を示す案である。

1. checkLength 相当の成功なら元のリストが保存され、0 ≤ minimum ≤ length ≤ maximum である。InvalidBounds と OutOfRange の条件、優先順、証拠を消した計算との一致も示す。
2. fromList 相当の成功と非空性が同値であり、toList の保存、head/tail の復元、map が非空性を保つ。
3. checkIndex 相当の成功なら 0 ≤ index < length であり、保存した要素が元リストのその位置の値である。get の射影との一致と、負・長さちょうどの拒否も示す。

Lean の自然数の長さと Integer の照合には、実リストの上限と i64 の表現可能性を明示する。主定理や Builtins.Assumptions を広げず、Checked.Range と同じ独立した証明として既定ビルドへ含め、01-12へ写す。Rust/.bnt の成功・失敗・優先順・保存欄・@opaque の外部からの拒否は独立の期待値で照合する。表層の型検査へ値の長さを持つ規則を加える変更ではなく、07-04の主定理の外側である。

Haskell の NonEmpty a は a と [a] を持ち、nonEmpty は通常のリストから Maybe (NonEmpty a) を返し、head は a を返す。[Data.List.NonEmpty の公式配布文書](https://hackage.haskell.org/package/base/docs/Data-List-NonEmpty.html) Scala の Cats も head と tail を持つ NonEmptyList と、Option を返す fromList を提供する。[Cats の開発元文書](https://typelevel.org/cats/datatypes/nel.html) Rust の NonZero<T> は非ゼロという条件を型として表し、内部フィールドを非公開にする。[標準ライブラリ文書](https://doc.rust-lang.org/std/num/struct.NonZero.html) これらは作成時の検査と、利用時の条件付きの値の前例である。NonZero のメモリ配置の最適化まで、Benitoite の @opaque レコードに期待するものではない。

## 5. TODO-087: 再帰・型パラメータのあるレコードの生成

### 5.1 現在の生成と管理

[tools/derive/README.md:127](../../../tools/derive/README.md#L127) の Property 契約と同:174 以降の Show/Order 契約を確認した。現行は非循環・型パラメータなしのレコードに限り、通常の関数と implement を生成する。生成器は乱数の状態を欄順に受け渡し、各欄へ同じ size を渡す。縮小器は一欄ずつ候補を作り、ShrinkStep を遅らせてつなぐ。Show は欄順の表示、Order は最初の非 Equal を返す辞書式順序である。

入口の制限は [derive_inventory/mod.rs:377](../../../crates/benitoite/examples/derive_inventory/mod.rs#L377) にあり、target の型パラメータを拒否する。inventory 自体は型・引数・再帰する参照を展開せず表せる（[inventory 契約:56](../../../crates/benitoite/examples/derive_inventory/README.md#L56)）。Python が型構文を独自に読み直す必要はない。

循環の拒否は [derive.py:172](../../../tools/derive/derive.py#L172) の structure の active 集合、辞書依存は同:627 の TraitDependencies、型に応じた Property 生成は同:791、Show/Order の本文は同:598 にある。再帰対応ではこれらを一緒に直す。Show の対象を増やすだけで型クラスの解決規則を変える必要があるとは、現時点では分かっていない。

生成記録は版2、inventory 版2、意味のハッシュ版2、GENERATOR_VERSION は 2.0.0-syntax-batch3 である。宣言・推移的依存・指定した関数のシグネチャ・設定・書式化後の本文のハッシュ、欄順、テンプレート版、Property.libraryVersion と実装依存を持つ。[derive.py:1084](../../../tools/derive/derive.py#L1084) の check は再生成した記録と本文を照合し、差分があれば preview/review/apply を要求する。check の成功は通常の型検査・テストの成功ではない。

### 5.2 再帰するレコードの生成器

最初の対象は、普通の有限の値を作れる、同一モジュール内の自己再帰と相互再帰のレコードとする案を推す。List・Option・String 鍵の Map を通る再帰を扱い、型パラメータ付き再帰は同じ引数を同じ順で渡す形に限る。再帰のたびに Nest[T] が Nest[List[T]] になる非正則なデータ型（non-regular datatype）、任意の data の構成子の選択、高カインドのパラメータ、関数・リソースを通る再帰は今回の自動生成の範囲外とする。通常の型の宣言は引き続き許す。

型引数を変えて自身を使う型は、Bird・Meertensの論文でnon-regular datatype（nested datatype）と呼ばれる。[著者の公開論文 Nested Datatypes](https://www.kestrel.edu/people/meertens/pub/nest5.pdf) 大きさを受け取る生成器には、QuickCheckのsizedとresizeの前例がある。[QuickCheckの配布文書](https://hackage.haskell.org/package/QuickCheck/docs/Test-QuickCheck-Gen.html) これらが以下の総節点数の予算を自動で保証するという意味ではない。

生成器を作る段階で子の生成器を無限に作り始めないよう、子の呼び出しは Gen.run の内部まで遅らせる。size を再帰の深さだけにすると、複数の子がそれぞれ size−1 を使う木は指数的に増えうる。今回の案は、同じ再帰のまとまりで使うレコード節点数の予算を子へ分配する方式である。List の各要素へ残り予算をそのまま複製しない。

size=0 でも Gen[T] は T を返す必要がある。強連結成分（strongly connected component、互いに参照し合う型のまとまり）ごとに、Option.None・空の List/Map を選んで有限の値を作れるかを先に求め、最小の基底の節点数を計算する。直接の必須欄だけで閉じた循環（A の必須欄が B、B の必須欄が A など）は生成前に拒否する。必須欄をたどった先に空の容器で止まる箇所がある場合は、有限の基底を作れる。

size は「その基底を超えて増やせる再帰節点数」と解釈する案である。各必須欄と子へ必要な最小予算を予約し、追加分だけを乱数で配る。内部の補助関数で残量を受け渡すか、先に分配して呼ぶ。公開の Gen.run の型は保つ。各呼び出しで消費する量と基底への遷移を決め、size=0、1、複数の子、相互再帰で停止することを受け入れ条件にする。

これは再帰部分の節点数の予算であり、文字列のバイト数や全値の記憶量の絶対上限ではない。非再帰の容器の既存 size 契約は保ち、再帰を含む経路だけ新しい配分を使う。利用者の要素の生成器や独自の欄の生成器の停止は保証できない。乱数の消費順、基底の選択、欄順、予算配分を生成規則の版に含め、旧い種だけで同じ値が再現すると約束しない。

### 5.3 縮小の停止と Show・Order

縮小器は生成器と同様、再帰する縮小器の組み立てを candidates の内部まで遅らせる。子を削る候補を先に、その後に一欄の子・要素の縮小を並べる。Option.None や容器の削除によって節点数を減らし、同じ構造を保つ候補では既存の要素の縮小を使う。元の値をそのまま候補に出さない。

標準の生成した縮小器については、再帰節点の減少と葉の縮小の順序を使って、候補を受け入れ続けても同じ値を往復しない条件を定める。任意の利用者の縮小器までその条件を自動で証明できるとはしない。[Property.bnt:57](../../../crates/benitoite/src/prelude/stdlib/Test/Property.bnt#L57) の maxShrinks・maxShrinkWork と limitReached を引き続き使う。予算はコールバック内部の時間を止めるものではない。縮小全体の停止性や反例の最小性を無条件には約束しない。

Show/Order は、再帰する欄について通常の値の再帰として比較・表示する。型に循環があることと、辞書に無限の依存があることを分ける。現行の [typeck/traits/solve.rs:114](../../../crates/benitoite/src/typeck/traits/solve.rs#L114) は選んだ実装の制約を解く。たとえば Show[Node[T]] の実装が要求するのが Show[T] だけなら、List[Node[T]] の表示の解決は Node[T] の型を無限に展開する必要がない。生成道具の active 検査を無条件に消すのでなく、まとまり内で生成される実装のシグネチャを先に登録し、その要求が外側の型パラメータの制約へ閉じるかを確認する。

Show は型・欄名と宣言順を保ち、Order は欄順の辞書式比較を保つ。任意の循環する Reference の参照先まで辿るような実装は作らない。深い有限の値でのスタックと表示量の限界は、値に再帰があるだけでは解消しないため、受け入れの大きさを明示する。これらは生成する通常関数の契約であり、コアの型計算や新しい再帰辞書の規則を導入する提案ではない。

### 5.4 型パラメータを持つレコード

生成器・縮小器は各要素の Gen/Shrinker を値の引数に取る。全ての T に標準の生成器があるとは仮定しない。たとえば Box[T] の案は次の形になる。

~~~text
genBox[T](element: Property.Gen[T]) -> Property.Gen[Box[T]]
shrinkBox[T](element: Property.Shrinker[T]) -> Property.Shrinker[Box[T]]
implement[T: Trait.Show] Trait.Show[Box[T]]
implement[T: Trait.Order] Trait.Order[Box[T]]
~~~

T の欄だけなら shrinkBox に equality は必須でないが、List[T]・Option[T]・Map[String,T] の標準縮小器は重複除去に equality を要求する（[Property.bnt:278](../../../crates/benitoite/src/prelude/stdlib/Test/Property.bnt#L278)）。必要な組み込み制約だけを生成署名へ伝える。レコード自身が宣言した key/equality と、標準クラスの要求も保持する。Order[T] が組み込み equality を与えるとはしない。

phantom の型パラメータには使わない生成器を要求せず、宣言順のうち必要なものだけ渡す。名前の衝突は既存の生成名の検査で扱う。独自の欄の関数に多相関数を指定する拡張まで必須にせず、初版は解決済みの型パラメータと標準の容器で書ける範囲を自動化する。既存の単相の独自関数の契約は維持する。

### 5.5 生成記録と移行

循環する依存を無限に展開してハッシュに入れない。到達できる宣言を解決済みの名前ごとに一度だけ集め、名前を一定順に並べ、型引数を含む辺と各宣言の構造を記録する。型パラメータの具体化のしかた、生成関数の引数、最小基底、予算配分の規則、制約、選んだ実装、テンプレート版も記録に含める。まとまり内の一型の変更で、それに依存する全出力が再確認の対象になる。

GENERATOR_VERSION・対象テンプレートの版・意味のハッシュの版を更新する。inventory の欄が変わるなら inventory と生成記録の版も同じ変更で上げる。旧い本文のハッシュが合うことを確認してから、新しい preview と diff と記録を出し、確認した manifest だけを apply する既存の流れを保つ。旧 manifest を新しい道具で受理する互換策は取らない。JSON の再帰・多相の生成へは広げず、JSON も同時に指定した非対応 target は機能別に拒否する。

### 5.6 専用の Property CLI

0.0.9 の [R12](../../archive/2026-10-18-TODO-021_022_026_032_087_088_142_164_248_257_258_259_260-syntax-batch3/decisions.md#r12-property専用の実行) は、CLI がどの Config を上書きするかという隠れた入力を増やさないため、普通の @test と Property.check/formatFailure を採った。現行の [Property.bnt:67](../../../crates/benitoite/src/prelude/stdlib/Test/Property.bnt#L67) の Counterexample には設定・種・試行番号・元の値・縮小後の値・作業量・版がある。一方、[test_runner/report.rs:176](../../../crates/benitoite/src/cli/tools/test_runner/report.rs#L176) の JSON は通常のテスト結果の報告であり、任意の T を構造化して保存する契約ではない。

今回も専用実行は見送る案を推す。--seed だけを足して Property.check の内側の Config を黙って上書きする案は採らない。含めるなら、Property の専用入口、Config を渡す方法、優先順（明示した CLI 値と宣言の既定値）、test --check の非実行契約、反例をデータにする変換関数とその失敗、報告の版を一組で設計する。Show の文字列を構造化した値と呼ばない。

再現のためには種だけでなく、Config・ライブラリと生成規則の版・独自関数・性質のコードが要る。再帰生成の分布を変える今回の版でも、発見した具体的な反例は固定したテストへ保存する案内を保つ。生成したコードと管理記録は07-04の外側であり、普通の型・エフェクト・脱糖の規則を使う。型クラスの解決や辞書の実行そのものを変更する必要が判明したら、その部分は内側へ戻して見積もる。

## 6. 規模の見込みと検査への引き継ぎ

以下は一人が順に作業する場合の能動作業の時間の幅であり、実測ではない。設計の具体化・実装・局所検査・文書と生成物の更新を含む。中心の248と相乗りB/C、全改造の検査待ち、公開作業は含まない。上限を成功の保証としない。

| 項目 | 作業の分け方 | 作業数 | 時間 |
|---|---|---:|---:|
| 206 | 名前・契約、位置の事前展開、標準ソース、組み込みの既定出力、報告と許可、接続と文書 | 6 | 18〜32時間 |
| 191 | 有限整数の定義、被覆と補題U、表層・交換、Rustの判定、診断・移行と接続 | 5 | 18〜36時間（Lean 10〜22時間を含む） |
| 022 | 独立した小証明、長さと添字、NonEmptyList、境界と例の照合 | 4 | 10〜18時間（Lean 3〜6時間を含む） |
| 087 | inventoryと署名、循環の管理、予算付き生成、縮小、Show/Order、記録移行と例 | 6 | 20〜38時間 |
| 合計 | 専用CLIを含めない案 | 21 | 66〜124時間 |

根拠は206の既存IOの探索・出力・報告を共有できること、191の定数が未有界であること、022に@opaqueと小証明の前例があること、087のR10/R11の未試作の追加幅と現行の三つの循環拒否である。191は任意の型を有界化する仕事に広がればこの幅を超える。087は前回の多相化4〜10時間・再帰8〜16時間に、Show/Orderと循環の管理・総予算の設計を加えた。予算付き生成器と有限整数の正式モデルへの接続は今回試作していないため、幅を狭める証拠はない。

相乗りAのレビューと修正には別に8〜16時間を見込む。合わせて74〜140時間である。操作の節への暗黙の位置を選ぶ場合は206に8〜20時間、専用のProperty入口とCLI・反例の構造化を含める場合は3〜5作業・10〜20時間を別に加える。これらも未試作の幅であり、重い形式化を一つまでにする条件との再評価が要る。

後の計画には次を引き継ぐ。ここでは実装やテストを追加せず、検査の具体コマンドの割り当ては実装プランで一箇所に集める。

- Lean 段で191と022の証明、および206の標準宣言の接続例を248・192等の版全体のLean変更とまとめる。定義・言明・仮定と01-12の写しをレビューし、既定ビルドの sorry なし成功を処理系へ進む条件とする。
- 実装中は関係する検査だけ、作業末は固定した基準から work を一度行う。新しい接続に限り stage を名指しする。Rust と Lean の接続が閉じた区切りと最終の関係状態で check-formal 全体を実行または条件を満たす結果から引用する。
- 206は二つのIO方式、捕捉時の無出力、外側への送り直し、複数出力先、出力失敗、宣言上限とJSON報告を同じ入力で確かめる。位置の式は呼び出しの構文・補助関数・文書例の元位置を確かめる。
- 191は最大・最小とその隣、全域・一点の穴・重複・ガード・直積・入れ子・燃料切れを、RustとLeanの独立した期待値へ接続する。032/200との接続の担当を明示する。
- 022は成功の保存と外部からの構築・更新・パターン・アクセサの拒否、添字の対象取り違え、非空の保持を確かめる。087は size=0、多分岐の予算、相互再帰、縮小の遅延、必要な辞書、再生成と改変拒否を確認する。
- 深い再帰や長いリストは、既定・heap-verifyで元の大きさを保ち、gc-stressだけ大きさを下げた契約を計画に固定する。全件の特殊構成を局所作業ごとに繰り返さない。
- change は改造全体の回帰、release は実候補・版・同梱物・CLI・証拠の照合である。性能を測る必要が出ても tools/bench/compare/ の short・targets・full を使い、改造専用の測定器を作らない。

## 7. S2 の確認記録

この調査で書く対象は todo-items.md への末尾の追記と、この文書・問いの文書だけである。処理系・現行設計・テスト・formal・docs/todo は変更しない。外部の資料は本文に出典を置き、未確認の細部と案を区別した。試作の記録・過去の成功を今回の検査の成功として引用しない。

文書だけの work の基準は、S1 の取り込み 19174b5a50570233288aa76d0f3670ca7ef20c4e とした。次の確認は2026-10-19に実行した。能動作業時間の見込みや将来の処理系の受け入れ結果ではない。

| 確認 | 結果 |
|---|---|
| scripts/check.sh --level work --base 19174b5a50570233288aa76d0f3670ca7ef20c4e --dry-run | 終了0、外側の時間0.067秒。変更3ファイル、文書だけのため実行単位なし |
| 同じ基準と指定で --dry-run を外した work | 終了0、外側の時間0.060秒。作業末の実行は一度。Rust・Leanを走らせたという意味ではない |
| ローカルリンク・行参照・節への参照の照合 | 77か所、リンク先ファイル・行の範囲・節の候補の欠落なし。docs/todoへのリンクなし |
| 問いと写しの照合 | L11・I4・C5・P6の計26問。TODO4件はリンクを文字列化した本文と一致。S1の本文は開始版の全文を先頭に保つ |
| git diff --check と変更範囲 | 空白の誤りなし。変更はtodo-items.mdとstudy/riders-a.md・riders-a-questions.mdだけ。コミットなし |

初回の簡易リンク照合では、コード中の角括弧と括弧をMarkdownリンクとして拾った。API表の型をコード表示に整え、コードブロックとコード表示を除く照合へ直して上表の結果を得た。確認記録と外部用語の出典の追記は文書だけであり、workの選択を変えない。
