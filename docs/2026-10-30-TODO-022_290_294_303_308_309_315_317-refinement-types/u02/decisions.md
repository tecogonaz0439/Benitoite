# U02 の設計者の決定

2026-11-05〜06。設計者が [candidates.md](candidates.md) の比較と取りまとめの問いに答えて決めた U02 の決定である。At のエラーの公開形（案 B、旧6構成子との重なりを認める、`AtFailure.outsideScope` を公開しない、構文の少数測定を行わない）は [README](../README.md) の「設計者の決定」と [l50/u02-options.md](../l50/u02-options.md) にある。本書はその残りを記す。各項の記号は candidates.md の節を指す。

## 推す案のとおり決めたもの

| 項目 | 決定 |
|---|---|
| Q1・S16 循環 | `Scope.AtInput.Request` を公開せず、要求の At の公開入口も設けない。AtInput は Text と Pattern の二構成子。要求の検査の失敗は旧 `Http.checkRequestIn` の `RequestCheckError` で扱う |
| Q2・S15 pattern | At の pattern 引数に動的な String を受け付ける。L70 で pattern の文字列（基準の名前と secrets を含む）を解析する規則を Lean の核へ足す。R8 は問わない |
| S1 字句 | 字句解析は今のままで、構文解析器が型の直後の `{` だけを篩として読む。他の位置の E0212・E0105 の診断と修正案を保つ |
| S2 束縛名 | 篩の束縛名は必ず書く（`List[T]{xs \| 0 < List.length(xs)}`） |
| S3 述語 | 述語は通常の式として構文解析し、許す形（線形の式・比較・論理・measure・欄）を型検査で確かめる |
| S5 record 全体の条件 | 篩を付けた別名で書ける（`type ValidSpan = Span{s \| Span.low(s) <= Span.high(s)}`）。R10 の決定により、欄の型で前の欄を参照する形も受け付ける |
| S6 値引数の宣言 | `type Window[T](n: Integer) = ...`（型引数の角括弧の後に値引数の丸括弧） |
| S7 値引数の適用 | 関数の呼び出しと同じ規則（一引数は位置指定も可、二引数以上は名前付き） |
| S8 範囲パラメータの宣言 | `[range R: path]`。`[R: path]` の書き忘れには修正案を出す |
| S9 範囲パラメータを使う位置 | candidates.md S9 の位置の一覧（範囲付きの値型の添字と範囲付きのエフェクトの引数、関数型の中を含む） |
| S10 steps の指定 | `@proofSteps(<整数リテラル>)` |
| S11 一般の check | `Refinement.check(value:)` を `Benitoite.Unofficial.Refinement` に置く。エラーは `expected: String` を持つ record `Refinement.CheckError`（Show を実装する） |
| S12 安全な入口 | head・tail は `NonEmptyList.head`・`NonEmptyList.tail` に一本化。添字の取得は `List.at(xs:, i:)`。同じ長さの別の List への検査済み添字の適用は `Range.getFrom(value:, values:)`。既存の15本は名前を保ち結果の型に篩を付ける |
| S13 PathBases | 型は `Scope.PathBases`（等号・鍵・Show なし）。発行は組み込みの関数 `Process.pathBases()`（uses Process.Environment）で、Environment の操作にしない |
| S14 At の入口 | `Scope.checkPathInAt(bases:, pattern:, path:)` だけ。`checkPathAt` は足さない |
| S16 命名 | 既存の公開名の綴りに揃える（P2: `RangeExpression`・`IPFamily`・`IPAddress`・`prefixLength`・`PortRange.minimum`/`maximum` など）。PathBase の構成子は `Root`・`Cwd`・`Home`・`Work`・`Tmp`。Lean の内部名との対応表を L70 に置く |
| K10 CLI | `--proof-steps=<整数>` で確定 |

## 書ける形の範囲の問い（第3節）

| 問い | 決定 | 推す案との差 |
|---|---|---|
| R1 束縛名と引数名の同名 | 拒否する | 推す案のとおり |
| R2 値引数の型 | 篩の項に現れる全ての種類を受け付ける（Integer に限らない） | 推す案と異なる。L70 で値引数の種類ごとの置換と整形式を確かめる |
| R3 範囲パラメータの種類 host | 受け付ける。host の範囲を添字に持つ型とエフェクトは docs/todo の TODO-319 に記した | 推す案と異なる。使う位置のない間の未使用の扱いは R60 で決める |
| R4 範囲パラメータと閉じた原子の混在 | 受け付ける（`File.Read[R, "/tmp/**"]`） | 推す案のとおり |
| R5 範囲パラメータを書ける宣言 | 関数と型の別名（data・record には書かない） | 推す案と異なる。L70 の別名の展開に範囲の置換を足す |
| R6 steps の指定値 | 正の十進の整数リテラルだけ | 推す案のとおり |
| R7 steps を付けられる宣言 | トップレベルの関数だけ | 推す案のとおり |
| R8 | 問わない（Q2 で動的な pattern を受け付けたため） | — |
| R9(a) 利用者の data の構成子の判定 | 述語に書ける。処理系が各構成子に判定の関数（`Shape.isCircle(v)` の形）を生成し、篩の中と外で同じ意味で使う。同じモジュールの同名の関数は誤りとする | 推す案と異なる（設計者が答えの後に改めた）。L70・R10 に生成の規則と述語への写しを足す |
| R9(b) 範囲への所属 | 述語に書ける。Boolean を返す純粋関数（`Scope.pathMatches(pattern:, path:)`・`Scope.hostMatches(pattern:, host:)` の形）を足し、篩の中では pattern をリテラルに限る | 推す案と異なる。決定済みの「文字列の長さや連結から所属を導かない」規則（DET-L15）と U1 との整合を L70 で確かめる |
| R10 record の欄の型から前の欄を参照 | 参照できる（`high: Integer{h \| low <= h}`） | 推す案と異なる。record の欄どうしの依存と順序、構築・更新の検査の意味を L70・R10b で定める。S5 の別名の形と両方を持つ |
| R11 不透明な record の欄との関係 | 公開の射影を欄の measure として登録し、篩の中で `Range.minimum(c)` と書ける | 推す案のとおり。DET-L31 の「可視な不変欄」を「公開の射影がある欄」と読む |

推す案と異なる決定（R2・R3・R5・R9(a)・R9(b)・R10）は、L70 と R 段の作業を増やす。所要は L70 の詳細化で見積もる。

## 後段への申し送り

- 新しい関数の名前（Float の分類、`String.charactersIn`、`Scope.pathMatches`・`Scope.hostMatches`、生成する構成子の判定の関数）の完全署名は、L70 の詳細化で candidates.md の S4 と本書に従って固定する。
- 同じ役割の形を二つ持つ選択（S5 の別名と R10 の欄の参照、旧6構成子と At の失敗の分類の重なり）は、設計原則5の例外として設計書の該当箇所の「理由:」に書く。
