# P2 診断の登録先と旧→新の対応案

## 登録前の確認

HEAD `daa50081364b9cbd3962ed473390d7cdf61d18af` の `crates/benitoite/src/diag/codes.rs` を全定義行で確認した。E0258・E0259・E0511・E0817 は未登録であり、追跡された crates/benitoite の実装・テストにも使用がない。構文の末尾は E0257、エフェクトは E0510、属性は E0816。E0255 など既存の欠番は再利用しない。[uses.json](uses.json) の unused_codes に結果を残した。

以下は design.md「診断番号と文言の案」と R5/R11/R13/R15/R17 に対応する後続の変更案である。P2 で変更した診断・golden・assert は 0 件である。新しい処置の解析前の入力に対し、現行 parser の偶発的なエラーを新規コードの「旧仕様」として固定しない。既存の期待値を変更する作業では、実際の旧出力・新出力と維持先を個別に追記し、golden を一括再生成しない。

`codes.rs` はコード・主文・ラベル・help・説明の正、parser/text と modules/text は各処理の文脈/可変報告の文言の置き場である。主文と副位置の文言は既存と同じバッククォートを使う。以下で「維持」は、主文・help・位置を包括的に緩めることを意味しない。

## 新コード四件

いずれも `diag/codes.rs` の `define_codes!` に Check として登録し、CLI の終了状態は静的検査の失敗 1 とする（R22 により 2 に訂正）。登録した作業で gen_skill と skill_docs を実行する。

| 新コード／担当 | 主文の案 | 主位置・副位置と help | 元の誤りの維持先 |
|---|---|---|---|
| E0258／B7 | `invalid failure action after \`try\`` | 処置の不正な語、空説明なら括弧。`write \`or return\`, \`or die\`, or \`or die(message)\``。return に値が付く場合の help は `the \`or return\` action takes no value`。副位置は必要なら try の位置を使い、実装時に固定 | 新しい処置の専用条件。Boolean or・裸 try の operand 不足・既存の予約語/式の誤りの parser 表と golden は残す |
| E0259／B7 | `parenthesize an explicit \`try\` expression before continuing it` | 処置直後の演算子/呼び出し。`write \`(try ... or ...)\` before applying another operator or call`。外側の try の処置は拒否しない | 裸の try と Boolean or の優先順位の既存表を維持。括弧で受理する対照を追加 |
| E0511／B10a-1 | `the message of \`or die\` cannot perform \`{effect}\`` | 効果を生じる位置が主、説明の括弧が副。`use a pure String expression for the message` | lazy/guard の効果不足、囲む関数/lambda の E0501/2 は既存の持ち主で維持。説明の不純性だけをこの番号へ分ける |
| E0817／D6c | `\`@extensible\` takes no arguments` | 属性の位置。`remove the arguments from \`@extensible\``。宣言の適用先も誤っていれば最初の原因一つだけ | 文字列引数の新属性に使用。非文字列 E0220、位置 E0802、重複 E0803、構成子の前の E0201 は維持 |

実装の持ち主は順に `syntax/parser/{effects,exprs}.rs`、同 parser の明示 try の境界検査、`typeck/effects` の説明の純粋性、`syntax/parser/items.rs` の属性検査である。E0817 の登録・属性受理は D6c で view と同時に有効にする。B10a-1 の E0511 は内部の解析入力でも検査し、B11 まで die の本番受理を先行させない。

## 既存コードの対応

以下の静的診断は旧/新とも終了状態 1（R22 により 2 に訂正）。旧主文を維持する行では新しい条件だけを記し、主文の正は codes.rs の該当定義とする。

| 条件／担当 | 旧→新のコード・主文 | help と主/副位置の差分案 | 理由と元の誤りの検査の維持先 |
|---|---|---|---|
| die を名前にする／A1 | 名前として受理→E0216 `\`{word}\` is a keyword and cannot be used as a name` | die の字句を主、既存 rename=`choose another name`。自動の参照の改名なし | 予約する一語だけを増やす。lexer/parser の既存の語表・名前/ラベル/ドットの拒否表へ追加し、fn/extensible など非予約語の受理も残す |
| return 直後が物理改行／A4 | 一般の継続として受理した入力→E0201 `expected {expected}, found {found}`。既存のオペランド不足の E0201 は維持 | 主は NEWLINE、副は return。`return_value_line` で値を同じ物理行で書き始めるよう案内。値を同じ行で開始した後の別の不足にはこの help を付けない | R13。newline の旧正入力一件は新しい文末条件の表へ移す。formatter の旧負入力は拒否のまま。24 行/6 ファイルの正の入力の移行を別記する |
| 説明から直接 return/try／B10a-1 | E0218 の文脈を追加、主文 `\`{keyword}\` cannot be used inside {context}` は維持 | 直接の return/try の位置が主、context と die_message の help を parser/text と codes へ追加。EscapeContext::InDieMessage と check_escape が担当 | R15。lazy/guard の直接の脱出の既存入力を残す。内側 lambda は自分の return を使える対照を保つ |
| 説明の resume／B10a-1 | E0509 を維持、外側の継続を隠した型検査で拒否 | resume の位置、die_message の help。parser に E0509 の発行を移さない | 説明で外側の節を再開できない。既存 handle の外の resume・継続の型/位置の検査を残す |
| 短い lambda の行越え／B7 | E0254 を維持、主文・既存 help の条件を変更しない | 物理行の境界を従来どおり使う | or の新しい文法を理由に古い短い lambda の拒否を減らさない。syntax と fmt_command の既存入力 |
| try 入力が Result/Option 以外／B10a-1 | E0440 `\`try\` cannot be applied to \`{ty}\`` を維持 | try の位置、既存 kinds の案内を維持 | die にも同じ型の入口を適用。裸/return の不正入力を残す。typeck の try の表・golden |
| Return の囲む戻り型・失敗型不一致／B6・B10a-1 | E0441/E0442 と主文を維持 | declared/declared_lambda/declared_placeholder・placeholder_call と convert/map_error を維持。die には要求しない | 囲む最内の境界と E の一致を弱めない。既存 typeck/golden と P1 の裸の try の負の検査 |
| 説明が String 以外／B10a-1 | 既存 E0401 `mismatched types` を説明にも適用 | 説明式を主、expected/found は厳密な型 | 通常の型不一致を別番号にしない。既存の E0401 表を維持し説明の行を追加 |
| die の Process.Exit 不足／B10a-1 | 関数 E0501/lambda E0502 と主文を維持 | die を発生位置、関数/lambda の宣言位置を副。E0501 は uses の案内と Process の import/既存別名を案内。E0502 の案内は既存どおり | 内部辺は利用者名を公開しない。通常 exit・IO.All・高階関数/lambda の既存の効果検査を維持 |
| die の E:Show 不足／B10a-1 | E0705/E0706 の既存主文を維持 | die の位置と必要なクラスの位置を区別し、`implement Trait.Show or convert the error with Result.mapError` の案内を追加 | 型パラメータの制約不足と具体型の実装不足を区別。既存 trait の検査と、Show のない E を or return で返す対照を維持 |
| 外部の指定付き型の将来の形が未被覆／D6a・D6c | 旧規則で網羅→E0601/E0607（主文は既存） | witness は Future の型を含む形、指定された宣言を副、help=`add an unguarded variable or '_' pattern to cover future values of '{future_ty}'`。future_ty は AdtDef.name、E0607 の ty は従来の show_type | R2/R9。内部なら従来の列挙で受理する対照、external match/bind・入れ子 record の独立入力を追加。既存の閉じた網羅性と E0609 を残す |
| Future を覆う包括的分岐／D6a | 旧 E0602/E0608→新規則では受理。真の重複には同じ E0602/E0608 | 重複の場合の主/covering の位置は従来どおり。同じ view で useful と covering を計算 | 意味上の受理条件の変更。元の「先行 `_` の後」の重複拒否は既存表に残し、全既知構成子の後の変数だけを新しい受理へ分類 |
| @extensible／D6c | 旧 E0801（未知）→有効な data/record は受理、不正適用先 E0802、重複 E0803、文字列引数 E0817 | 属性の主位置、重複は first の副位置と remove。非文字列 E0220、構成子の前の @ は E0201 のまま。E0801 の allowed と E0802 の説明へ対象を追加 | R2/R11。大文字の属性 E0247 や未知属性の旧表を減らさない。parser/items.rs の既存表を拡張 |
| language 宣言後の複数の破壊的変更／M6 | E0908 と主文を維持。changed は最初の該当版のまま | 旧一件の change note と固定 migrate help→該当版順の各 summary note と各 help。主位置は language 宣言を維持 | R17。全該当版を Diagnostic の配列へ追加。一件だけの検査・版境界の負の検査は package.rs の表/package_command/golden で厳密な新出力に合わせる |

## die のコードなしの報告

旧来の通常 exit は報告なしで終了する。die は追加の構造化情報を持つため、通常 exit と区別して新しい ReportKind::Die を描画する。新しい E/R 番号にはしない。

| 項目 | 追加する報告の契約／担当 |
|---|---|
| 終了結果 | 採用した既定の die だけ EndKind::Exited(1)、exit_code=1、die_failure=Some。main_error は独立／B8・B10 |
| 文章 | 主文 `explicit failure exit`、説明があれば message、常に cause、主位置に try。固定文言は diag/codes.rs の text／B8 |
| JSON | kind=die、code=null、主文は固定、notes に説明（あれば）と原因、primary に位置。Diagnostic に専用の任意欄を増やさない／B8 |
| 順序 | 最後の出力転送後、die を一回、その後 reports の解放/flush の失敗を既存順。終了状態 1／R18、B11/B12 |
| ハンドラ/競合 | 処理された操作や採用されなかった die は報告しない。後の独立した exit に持ち越さない／B10・B12 |
| test runner | Failure::Exit から原因・説明・位置を報告。code=0 の普通の exit も既存どおり一件の失敗。次のテストへ進み、捕捉出力へ二重描画しない／B8・B12 |

主となる公開境界は静的診断では parser/typeck と CLI golden、実行報告では run→CLI/test runner である。B8 は人工の DieFailure を渡す既存 lib の描画境界まで、B11/B12 は本物のソース入力で確認する。既存の通常 exit・Result.Error・Assert・中断・Internal の分類の検査は残す。
