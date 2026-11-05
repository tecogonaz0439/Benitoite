# U02 の残り: 構文の正確な文法と公開 API の候補

2026-11-05。未決事項 U02（[decisions.md](../decisions.md) の「後でよいもの」の U02 の行）のうち、設計者がまだ決めていない部分について、選べる候補を比べる。本書は比較の材料であり、決定でも実装の記録でもない。設計者が 2026-11-05 に決めた At のエラーの公開形（[README](../README.md) の「設計者の決定」の最後の項、[l50/u02-options.md](../l50/u02-options.md) の案 B）と、構文の大枠（D40 の `T{v | predicate}`、案 I・U1・F3、DET-L01〜L31・DET-R01〜R26）は論じ直さない。

本書の作業では、LLM を呼ぶ測定、cargo・`scripts/check.sh`・`lake build` の実行、git の書き込みをしていない。LLM による生成・修正の成功率（00-01 の構文の基準の一つ）は測っていないので、本書でその良し悪しを述べる箇所はすべて推測である。コードの例は、断りのない限り、今の CLI で検査していない。新しい構文を含む例は、今の CLI では構文の誤りになる（第 0.2 節）。

## 0. 前提として確かめたこと

### 0.1 読んだ範囲

[README](../README.md) の 2026-10-30 の層 C の決定と「設計者の決定」、[decisions.md](../decisions.md) の D32・D33・D34・D39・D40・D41・D43〜D46・D57・D61、DET-L06・L07・L14・L15・L22・L23・L31、DET-R12・R22、U02 の行、[plan.md](../plan.md) の O037・O068・O120・O130・O144・O146・O167・O170 の行、調べの [questions-full.md](../study/questions-full.md) の Q02・Q05・Q06・Q06-用語・Q08、[questions-riders.md](../study/questions-riders.md) の Q04・Q16a・Q16b、[refinement-full.md](../study/refinement-full.md) の第 5.5・5.6・6・8.1・8.2 節、[riders-303-290-309.md](../study/riders-303-290-309.md) の第 2.3〜2.5 節、[l40/a/signatures.md](../l40/a/signatures.md) の「安全な入口の内部の契約（J40-3）」、[l40/stage-results.md](../l40/stage-results.md) の J40-3、[l50/detail.md](../l50/detail.md) の第 2・3・9 節、[l50/u02-options.md](../l50/u02-options.md)、[l50/stage-results.md](../l50/stage-results.md) と [l60/stage-results.md](../l60/stage-results.md) の後段への受け口、[l00b.02/signatures.md](../l00b.02/signatures.md) の第 4.2・4.3 節と RV-at の対応表である。[l00b.05/signatures.md](../l00b.05/signatures.md)・[l00b.11/type-shift-contract.md](../l00b.11/type-shift-contract.md)・[l10/detail.md](../l10/detail.md) は U02・公開名・字面の語で探したが、U02 へ送った点は見つからなかった。

言語の今の形は、[英語リファレンス](../../reference/benitoite.md) の第 6〜8・10 節と Range・Scope・Scoped values の節、[01-01 字句](../../design/01-spec/01-01-lexical.md)、[01-02 構文](../../design/01-spec/01-02-syntax.md) の文法・属性・型の別名・エフェクトの節、標準ソースの [Scope.bnt](../../../crates/benitoite/src/prelude/stdlib/Scope.bnt)・[Range.bnt](../../../crates/benitoite/src/prelude/stdlib/Range.bnt)・[NonEmptyList.bnt](../../../crates/benitoite/src/prelude/stdlib/NonEmptyList.bnt)・[Network/Http.bnt](../../../crates/benitoite/src/prelude/stdlib/Network/Http.bnt)・[IO/Process.bnt](../../../crates/benitoite/src/prelude/stdlib/IO/Process.bnt)、Lean の [ScopeSyntax.lean](../../../formal/Benitoite/Release/Refinement/ScopeSyntax.lean)・[Scope/Domain.lean](../../../formal/Benitoite/Scope/Domain.lean)・[TermSyntax.lean](../../../formal/Benitoite/Release/Refinement/TermSyntax.lean)・[AtPrepare.lean](../../../formal/Benitoite/Release/Refinement/AtPrepare.lean)・[AtInput.lean](../../../formal/Benitoite/Release/Refinement/AtInput.lean)・[TargetTable.lean](../../../formal/Benitoite/Release/Refinement/TargetTable.lean)・[SourceScope.lean](../../../formal/Benitoite/Release/Refinement/SourceScope.lean) で確かめた。

### 0.2 今の CLI で確かめたこと

既存のビルドのバイナリ（`<repo>/target/debug/benitoite`、版 0.0.13 の表示）で、次の二つの入力を `check` した。ビルドはしていない。

- `type Port = Integer{p | 1 <= p and p <= 65535}` を含むファイルは、`{` と `}` を E0212（blocks are not written with braces）、`|` を E0105（unexpected symbol）で拒否し、終了 2 となった。01-01「演算子と区切り記号」も `{`・`}`・単独の `|` を「字句として受け付けない記号」とし、構文解析器が文脈に応じた修正案を出すと定める。
- `@proofSteps("200000")` を付けた関数は E0801（unknown attribute）で拒否され、help は書ける属性の一覧を示した。01-02「属性」は属性の引数を文字列リテラルに限る。

### 0.3 読んで分かった、比較の前提を変える事実

次の三点は、既存の文書の候補の前提と食い違う。以下の比較はこれらを前提に置く。

1. **Scope と Http の import の循環**。案 B の `Scope.AtInput.Request(Http.ClientRequest)` を Scope に宣言すると、Scope が Http を import する。ところが [Network/Http.bnt](../../../crates/benitoite/src/prelude/stdlib/Network/Http.bnt) は既に `import Benitoite.Unofficial.Scope` を持つ（`RequestCheckError.Scope(Scope.ScopeError)` のため）。01-03「循環する import」は循環を誤りとする。標準ライブラリにこの規則の例外があるかは確かめていない（未確認）。[u02-options.md](../l50/u02-options.md) の第 4 節は `Http.ClientRequest` を既存の型として数えたが、置き場所の依存の向きは論じていない。
2. **At の pattern 引数は、Lean の核ではリテラルの値だけ**。`prepareCore` は pattern を `parseAtPattern` で読み、これは `Val.scopePattern r` だけを受け、文字列の定数には `invalidPattern` を返す（[AtInput.lean](../../../formal/Benitoite/Release/Refinement/AtInput.lean)・[AtPrepare.lean](../../../formal/Benitoite/Release/Refinement/AtPrepare.lean)）。ソースに書ける `scopePattern` は閉じた正規の範囲だけである（[SourceScope.lean](../../../formal/Benitoite/Release/Refinement/SourceScope.lean)）。本調べで読んだ範囲では、動的な文字列から `scopePattern` を作る規則は見つからなかった。一方、調べ（[riders 第 2.5 節](../study/riders-303-290-309.md)）は「動的な文字列にだけ現れる未束縛の基準は At の Error」とし、旧 `checkPathIn` も動的な pattern を受ける。
3. **At の対象の種類は二つ**。`TargetTable.valKind` は `Scope.PathIn`（path）と `Http.RequestIn`（endpoint）だけを登録する。`CheckedPath` を返す At は Lean のモデルにない。

## 1. 項目の一覧

出どころの略記は、D・DET・U が [decisions.md](../decisions.md)、F・R が調べの問い（F は questions-full、R は questions-riders）、O が [plan.md](../plan.md) の義務の行、J40-3 が [l40/a/signatures.md](../l40/a/signatures.md)、J50-1 が [l50/detail.md](../l50/detail.md) 第 9 節を指す。

### 1.1 決定済みで比較から外すもの

| 番号 | 内容 | 字面の確定 | 出どころ |
|---|---|---|---|
| K01 | At のエラーは `Scope.ScopeError.At(Scope.AtDetail)`、AtDetail は 9 欄の型付き record。旧 6 構成子は変えず、重なりを認める。`AtFailure.outsideScope` は公開しない。構文の少数測定はしない | 構成子名と 9 欄の名前は確定。入れ子の 19 型の名前・欄は第 4 節で比べる | README 2026-11-05、u02-options 第 1・4 節 |
| K02 | 篩の表記の大枠は `T{v \| predicate}`。値依存・長さ・record を一つの形式で書く | 大枠のみ。字句・束縛名・述語の文法は S1〜S4 | D40、F Q06 |
| K03 | 契約は引数・結果の篩へ書き、requires/ensures の別の節を必須にしない | 確定（節を設けない） | D40、F Q06 |
| K04 | 比較の連鎖（`a < b < c`）と区間の略記（`Integer[lo..hi]`）を加えない | 確定 | DET-L22、F Q06 L22 |
| K05 | 長さの measure の名前は `String.byteLength`・`String.characterCount`・`List.length`・`Bytes.length` | 確定。既存の標準関数の名前と一致する（[String.bnt](../../../crates/benitoite/src/prelude/stdlib/String.bnt) ほか）。`Map.size`・`Set.size` も既存名 | D40、F Q06 |
| K06 | 値引数は型引数と違う括弧で宣言する。範囲パラメータは種類を明示し、内部の rvar の表記を公開しない | 大枠のみ。S6〜S9 | D40、DET-L14、F Q06 |
| K07 | 旧 `checkPath`・`checkPathIn` は絶対形だけの純粋な API として残す。PathBases は不透明で偽造できず、`Process.Environment` の下で取得して純粋な At へ明示して渡す | 役割は確定。名前は R Q04 の仮名のまま。S13・S14 | D57、DET-R12・R13、R Q04 |
| K08 | 安全な入口 19 行の内部の契約（受ける証拠と返す型） | 内部契約は確定。公開名は S12 | J40-3、l40 stage-results |
| K09 | `List.get` と整数の加算に精密な署名を足さない。旧 Option・Result の API を保つ | 確定 | l40/e/results（2026-11-04）、D34 |
| K10 | 利用者に見せる呼び名は「ステップ数の上限（steps）」。CLI は `--proof-steps=<整数>`、数え方の版は `proof-steps-v1` | 呼び名と版は確定。CLI の綴りは README で「案」と書かれたまま計画の全体で使われている（S10 で確認だけ問う） | README 2026-10-30・11-03、D39、D45 |
| K11 | 起点の違う組への警告の文言、W0405 の文言 | 確定（U02 の対象外） | D62、D69 |

### 1.2 比較する項目

| 番号 | 項目 | 出どころ |
|---|---|---|
| S1 | 篩の字句（`{`・`}`・`\|` を受け付ける位置と既存の診断） | D40、O167、本書 0.2 |
| S2 | 篩の束縛名の形 | D40、F Q06 |
| S3 | 述語に書ける式の文法 | D03、DET-L01・L07・L31、O144・O130 |
| S4 | 述語に書ける組込みの判定の綴り（Float の分類、文字の範囲、構成子、対象の所属） | D03、Lean の `Pred` |
| S5 | 篩を書ける位置と record 全体の条件 | D02、D35 |
| S6 | 値引数を持つ型の別名の宣言 | D40、F Q06 |
| S7 | 値引数の適用の形 | D40 |
| S8 | 範囲パラメータの宣言 | D40、DET-L14 |
| S9 | 範囲パラメータを使う位置 | D40、DET-L14、O167 |
| S10 | 関数ごとの steps の指定 | README L17、D45、O146 |
| S11 | 一般の check の名前・署名・エラー | U02、D32、DET-L23、O068、調べ 8.1 |
| S12 | 安全な入口の公開名と、既存の射影の完全署名 | J40-3、D33・D34、F Q08 |
| S13 | PathBases の型と発行の入口 | D57、R Q04、DET-R12 |
| S14 | At の入口の名前と完全署名 | D57、R Q04、本書 0.3 の 3 |
| S15 | At の pattern 引数の型 | D57、本書 0.3 の 2 |
| S16 | 案 B の公開型の完全な宣言と、Scope と Http の循環 | K01、u02-options 第 4 節、本書 0.3 の 1 |

書ける形を制限する選択は、各項目の推す案に埋めず、第 3 節に R1〜R11 として分けた。

## 2. 項目ごとの比較

各項目の「影響」は、L70（Lean が型付き表層の意味を固定する段）、R10a（Rust の型表現・構文・名前解決）、R60（表層・fmt・診断/JSON）、D10（文書・Skill）への見込みである。時間は見積もっていない。

### S1. 篩の字句

**決まっている大枠**: `T{v | predicate}`（K02）。

**残る点**: 今は `{`・`}`・`|` が字句として受け付けない記号であり、`{` には「ブロックは `end` で閉じる」修正案を出す（E0212、本書 0.2）。篩のための位置でだけ受け付け、他の位置の診断を保つ方法を決める。

| 候補 | 内容 |
|---|---|
| A | 字句解析は今と同じく三つの記号を字句として切り出し、構文解析器が「型の直後の `{`」だけを篩として読む。それ以外の位置の `{`・`}` は E0212、`\|` は E0105 のまま。`\|\|` は今の修正案（`or`）を保つ |
| B | 字句解析器に「型の文脈」を持たせ、型の直後でだけ三つの記号を字句にする |

```benitoite
type Port = Integer{p | 1 <= p and p <= 65535}

function area() -> Unit
  {   // 候補 A でも B でも E0212 のまま
end function
```

**比べた点**: 01-01 は「受け付けない記号を字句解析器ではなく構文解析器が報告する」と定めており、A はこの分担をそのまま使う。B は字句解析器に構文の文脈を持ち込み、[02-03 の字句](../../design/02-impl/02-03-frontend.md)の分担を変える。LLM が他言語の `{ }` のブロックを書いたときの修正案は、どちらでも残せる。ただし A では、型注釈の直後に誤って `{` を書いたブロック（`bind x: Integer {`）が篩の構文の誤りとして報告されうるので、篩として読めない場合に E0212 の修正案を併記する必要がある（推測）。

**影響**: L70 は表層の構文の写しが要るが字句の規則に依らない。R10a は構文解析器の一か所、R60 は fmt と E0212・E0105 の修正案の分岐。D10 は 01-01 の記号の表と診断の説明を改める。

**推す案**: A。理由: 既存の字句と構文の分担を変えず、他の位置の診断を保てる（原則 4）。

### S2. 篩の束縛名

**残る点**: `{` の直後の名前を、書き手が選ぶか、固定名にするか。

| 候補 | 例 |
|---|---|
| A 任意の小文字識別子を必ず書く | `List[T]{xs \| 0 < List.length(xs)}` |
| B 固定名 `value` を暗黙に束縛し、名前を書かない | `List[T]{0 < List.length(value)}` |
| C A と B の両方を受け付ける | — |

他の言語では、Liquid Haskell が `{v: Int | v > 0}`（[仕様の文書](https://ucsd-progsys.github.io/liquidhaskell/specifications/)、取得 2026-11-05）、F* が `x:int{x >= 0}`（[F* の入門書](https://fstar-lang.org/tutorial/book/part1/part1_getting_off_the_ground.html)、取得 2026-11-05）、Flux（Rust）が `i32{v: v > 0}` と、いずれも束縛名を書く。Flux は [Flux Specification Guide](https://flux-rs.github.io/flux/guide/specs.html) の検索結果の要約で確かめた。本文の取得は 404 で失敗したので、Flux の綴りは一次資料の本文では未確認である。

**比べた点**: A は束縛が字面で分かり、01-01 の「暗黙に文脈で意味が変わる箇所が少ない」に合う。B は短いが、`value` は既存の callback の引数名（`function(value: T)`）や `Range.value` と同じ綴りで、関数の引数に `value` がある署名では外側の名前を隠す。C は同じ役割の形を二つにする（原則 5）。LLM の生成では、上の三言語がすべて名前を書くので A の形を学習している可能性が高い（推測）。

**影響**: B と C は名前解決に暗黙の束縛を足し、L70 の表層の写しにも暗黙の名前の規則が要る。A は既存の局所の束縛の規則で足りる。

**推す案**: A。束縛名と引数名の同名をどう扱うかは制限の問い R1 とする。

### S3. 述語に書ける式の文法

**決まっている大枠**: 量化子のない線形整数と論理の結合、組込みの measure、不変な欄、対象の所属（D03・DET-L01）。型の中で任意の純粋な式を評価しない（DET-L07）。measure の引数は変数か可視な不変欄の連鎖だけで、入れ子にしない（DET-L31）。比較の連鎖を加えない（K04）。Lean の項は変数・各種リテラル・欄・measure・加算・単項負号・定数倍であり（[TermSyntax.lean](../../../formal/Benitoite/Release/Refinement/TermSyntax.lean) の `Term`）、述語は真偽・等号・順序比較・Float の分類・Decimal の表現可能性・文字の範囲・対象の所属・構成子の判定・and/or/not である（同 `Pred`）。

**残る点**: 表層の文法を通常の式の文法の部分集合として書くか、専用の文法を作るか。定数倍の書き方、measure の呼び出しの形、欄の読み方、import の別名の扱い。

| 候補 | 内容 |
|---|---|
| A 通常の式として構文解析し、型検査で許す形を検査する | `{` と `\|` の後を 01-02 の `OrExpr` として読む。許す形は、束縛名と見える引数名、リテラル、`+`・`-`・単項 `-`、片方がリテラルの `*`、比較 6 種、`and`・`or`・`not`、`true`・`false`、括弧、登録した measure と欄の取得の一引数の呼び出し。`div`・`mod`・変数どうしの `*`・`/`・一般の関数呼び出し・`if`・`match`・ラムダは、篩の中で使えない式として型検査が拒否する |
| B 専用の文法を作る | 篩の述語に別の非終端記号を定め、許す形だけを構文として受け付ける |

```benitoite
type Ratio = Decimal{v | 0m <= v and v <= 1m}
type Even = Integer{n | 2 * (n div 2) = n}          // A では型検査で拒否（div）、B では構文の誤り

function prefix[T](xs: List[T], n: Integer{k | 0 <= k and k <= List.length(xs)})
    -> List[T]{ys | List.length(ys) = n}
  return List.take(xs: xs, n: n)    // 既存の List.take(xs, n)。長さの契約は D34 で付ける
end function
```

measure の呼び出しは、今の呼び出しの規則（一引数は `List.length(xs)` と `List.length(xs: xs)` のどちらも書ける、01-02「名前付き引数と関数型」）をそのまま使う。measure の名前は、Scope の追加検査と同じく、import の別名を含む解決済みの標準宣言で判定する（[リファレンス第 8 節](../../reference/benitoite.md#8-constants-and-type-aliases)の Scope の記述と同じ扱い）。record の欄は今の取得関数の形 `Item.price(v)` で読む。

**比べた点**: A は利用者と LLM が既に知る式の文法を使い、篩に書けない式には「この位置では使えない演算」と理由を添えた診断を出せる（原則 1・4）。B は構文の段で拒否できるが、`div` を書いた入力が E0105 などの一般の構文誤りになり、何が使えないかを示しにくい（推測）。B は同じ役割の式の文法を二つ持つ（原則 5）。

**影響**: A は R10a の構文の追加が小さく、型検査（R10b）に許す形の検査が入る。L70 は表層の述語から `Pred`・`Term` への写しの規則を定める。D10 は許す形の一覧と、使えない演算の診断の例を文書に書く。

**推す案**: A。

### S4. 述語に書ける組込みの判定の綴り

**残る点**: Lean の `Pred` のうち、比較と論理以外の四つ（`floatClass`・`charactersIn`・`constructorIs`・`member`）と `decimalRepresented` を、表層でどう綴るか。

| 判定 | 候補 A（既存の標準関数の名前で読み、足りない関数は通常の純粋関数として足す） | 候補 B（専用の構文） |
|---|---|---|
| Float の分類 | `Float.isNaN(v)`（既存）、`Float32.isNaN`・`Float32.isInfinite`（既存）。有限・正負の無限・正負の零の判定は Float に名前がなく、足す関数の名前は未定 | `v is nan` など新しい語 |
| 文字の範囲 | `String.charactersIn(text: s, minimum: '0', maximum: '9')` を足す（名前は Lean の `charactersIn` に合わせた候補。他の言語の確立した名前は確認できなかった） | 区間の略記（K04 で加えないと決まっている） |
| 構成子 | `Option.isSome`・`Option.isNone`・`Result.isOk`・`Result.isError`（既存）だけ。利用者の data の構成子の判定は書けない | `v matches Shape.Circle(_)` など新しい語 |
| 対象の所属 | 述語に綴りを設けず、範囲付きの値型の添字（`Scope.PathIn["/data/**"]`）だけで書く | `Scope.contains(...)` などを measure として足す |
| Decimal の表現可能性 | 利用者は書かない。処理系が正常結果の事実として内部で使う | — |

**比べた点**: A は、書く名前がそのまま実行時にも呼べる関数であり、篩の中と外で意味が同じになる（原則 4・5）。B は新しい語を足す。対象の所属を述語に出さない選択は、DET-L15（文字列の長さや連結から所属を導かない）と U1（D08）の「所属は保持型と部分型で表す」に合う。足す関数（Float の分類・`String.charactersIn`）は、篩とは別に、標準ライブラリの公開関数としての名前と引数名を決める必要がある。

**影響**: L70 は表層の各名前から `Pred` の構成子への写しを定める。R40（標準本体）に関数を足す。D10 は判定の一覧を文書にする。

**推す案**: A。利用者の data の構成子の判定と対象の所属の判定を述語に書けないことは、書ける形の制限なので R9 で別に問う。

### S5. 篩を書ける位置と record 全体の条件

**残る点**: どの型の位置に篩を書けるか。D35 の「record 全体の条件」をどの形で書くか。

篩は型であり、型を書ける位置（引数・結果・`bind` の注釈・型引数・関数型の中・const・別名の右辺・data の構成子と record の欄）のどこにも書けるとするのが、01-06 の型の扱いに沿う。改行は、`(` と `)` の中と同じ扱いにする案を置く（fmt の規則は R60 で決める）。

record 全体の条件の候補は次の二つである。

| 候補 | 例 |
|---|---|
| A record の型に篩を付けた別名で書く。欄は取得関数で読む | 下のコードの `ValidSpan` |
| B 後の欄の型が前の欄を参照できるようにする | `high: Integer{h \| low <= h}` |

```benitoite
record Span
  low: Integer
  high: Integer
end record

type ValidSpan = Span{s | Span.low(s) <= Span.high(s)}
```

**比べた点**: A は S3 の欄の取得と別名だけで書け、新しい規則が要らない（原則 5）。B は短いが、record の宣言に欄どうしの依存と順序の規則（DET-L06 の関数の引数の規則に相当）を足し、構築・更新（`Span(..s, high: 0)`）のたびの検査の意味も決める必要がある。Codec の decode の後の検査（D35）は、A なら別名の篩をそのまま検査すればよい。

**影響**: B を選ぶと L70 の型付けと R10b の構築・更新の規則が増える。

**推す案**: A。B を受け付けないことは、書き手から見れば欄の型で前の欄を参照できないという制限なので、R10 で別に問う。

### S6. 値引数を持つ型の別名の宣言

**決まっている大枠**: 既存の `type` を使い、値引数は型引数と違う括弧で宣言する（D40、候補 `Bounded(n)`）。

**残る点**: 型引数と値引数を両方持つときの順序、値引数の型として書けるもの、別名の右辺で値引数を使える位置。

| 候補 | 例 |
|---|---|
| A 型引数の角括弧の後に値引数の丸括弧 | `type Window[T](n: Integer) = List[T]{xs \| List.length(xs) = n}` |
| B 値引数の後に型引数 | `type Window(n: Integer)[T] = ...` |

```benitoite
type Bounded(n: Integer) = Integer{i | 0 <= i and i < n}

function pick[T](xs: List[T], i: Bounded(List.length(xs))) -> T
  return List.at(xs: xs, i: i)     // List.at は S12 の候補名
end function
```

他の言語では、Liquid Haskell が別名の型引数を小文字、値引数を大文字で並べる（`type GeNum a N = {v: a | N <= v}`、[仕様の文書](https://ucsd-progsys.github.io/liquidhaskell/specifications/)、取得 2026-11-05）。括弧を分ける例として確かめたものはない。

**比べた点**: A は関数の宣言（`function f[T](x: T)`）と同じ順序であり、読み手と LLM が型引数・値引数の順を関数から類推できる（推測）。B は既存の並びと逆になる。値引数は右辺の篩の中でだけ使え、型引数の位置には書けないとする（型と値の名前空間を分ける D17 に従う）。値引数の型を Integer に限るかは R2 で問う。

**影響**: R10a は `AliasDecl` に丸括弧の並びを足す。L70 は値引数を持つ別名の展開を、値の置換（D24）で定める。

**推す案**: A。

### S7. 値引数の適用の形

**残る点**: 型の位置で値引数を渡すときに名前を書くか。

| 候補 | 例 |
|---|---|
| A 関数の呼び出しと同じ規則（一引数なら位置指定と名前付きのどちらも書け、二引数以上は名前付き） | `Bounded(List.length(xs))`、`Between(low: 0, high: n)` |
| B データ構成子と同じく常に位置指定 | `Between(0, n)` |

**比べた点**: A は 01-02 の「二つ以上のパラメータは名前付き」と揃い、引数の取り違えを名前で防げる（原則 1・4）。B は短いが、関数の呼び出しと違う規則を型の位置だけに持ち込む。

**影響**: R10a の型の構文で `UpperIdent "(" CommaList(Arg) ")"` を受ける。引数に書ける式は S3 の述語の項と同じ。

**推す案**: A。

### S8. 範囲パラメータの宣言

**決まっている大枠**: 範囲パラメータは種類付き（path・host・endpoint）で、型・値・エフェクトのパラメータと区別する（D40・DET-L14）。

**残る点**: 関数の型パラメータの並びの中での綴り。今の文法では `[T, effect E]` と `T: key`（制約）がある（01-02 の `FnTypeParam`）。

| 候補 | 例 | 今の文法との関係 |
|---|---|---|
| A `range R: path` | `function read[range R: path](path: Scope.PathIn[R]) -> ...` | `effect E` と同じく前置の語で種類の区別を示す。`:` の後は制約でなく種類 |
| B `path R` | `function read[path R](...)` | `effect E` と同じ形で最も短い。`range` の語がない |
| C `range[path] R` | `function read[range[path] R](...)` | 角括弧が入れ子になる |

```benitoite
import Benitoite.Unofficial.Scope
import Benitoite.Unofficial.IO.File

function readInput[range R: path](path: Scope.PathIn[R]) -> Result[String, IOError] uses File.Read[R]
  return File.readTextIn(path: path)
end function
```

**比べた点**: A は「R は範囲であり、種類は path」と順に読め、`range` は用語集の「範囲（range）」と一致する。ただし `R: path` は制約の `T: key` と字面が似ており、`range` を書き忘れた `[R: path]` は今の文法では未知の制約 `path` として読まれる。この誤りには「範囲パラメータは `range R: path` と書く」修正案を出す必要がある。B は `effect E` の類推で書きやすい（推測）が、`path`・`host`・`endpoint` が型パラメータの並びの先頭で特別な語になり、何のパラメータかを語が示さない。C は入れ子の括弧が読みにくい（推測）。どの候補でも `range`・`path` などは予約語にせず、この位置でだけ意味を持つ語とする（01-01 の `equality`・`key` と同じ扱い）。

**影響**: R10a は `FnTypeParam` に選択肢を一つ足す。L70 は範囲の名前空間の束縛（D17）を表層から写す。D10 は `[R: path]` の誤りの修正案を診断の表に載せる。

**推す案**: A。`host` の種類を受け付けるかは R3 で問う。

### S9. 範囲パラメータを使う位置

**残る点**: R を書ける位置と、閉じた原子との混在。

範囲パラメータを書ける位置は、範囲付きの値型の添字（`Scope.PathIn[R]`・`Http.RequestIn[R]`）と、範囲付きのエフェクトの引数（`File.Read[R]`・`File.Write[R]`・`Http.Connect[R]`）とする案を置く。関数型の中（`f: function(path: Scope.PathIn[R]) -> Unit uses File.Read[R]`）も含める。今の文法では `File.Read[Integer]` のような型を始める字句は E0520 であり（01-02「エフェクトの宣言とハンドラ」）、R も大文字で始まるので、構文ではなく名前解決で範囲パラメータと型を区別する。

呼び出し側で R を明示する構文は足さない。Benitoite は呼び出しに型引数を書く構文を持たず、範囲の具体化は D09 の推論で行う。

**比べた点**: 種類が合わない使い方（path の R を `Http.Connect[R]` に書く）は型検査で拒否する。閉じた原子と R を一つの角括弧に並べる `File.Read[R, "/tmp/**"]` は、今の複数原子の略記の延長だが、受け付けるかは R4 で問う。型の別名・data・record に範囲パラメータを書けるかは R5 で問う。

**影響**: R10a の名前解決、L70 の範囲の具体化、R60 の E0520・E0513 の文言の分岐。

**推す案**: 上の位置の一覧を採る。

### S10. 関数ごとの steps の指定

**決まっている大枠**: ソースの関数ごとの指定が、その関数でコマンドライン・設定・既定値を上書きする。単位は操作の回数（README L17、D45）。

**残る点**: 綴りと置き場所。今の属性は文字列の引数だけを受ける（0.2）。

| 候補 | 例 | 文法の変更 |
|---|---|---|
| A 整数の引数を取る属性 | `@proofSteps(200000)` | 属性の引数に、この属性に限り整数リテラルを足す |
| B 文字列の引数を取る属性 | `@proofSteps("200000")` | なし（属性の名前を足すだけ） |
| C 署名の後の節 | `function f(...) -> T uses E proofSteps 200000` | 新しい語と署名の位置を足す |

他の言語では、Dafny が関数・メソッドの属性 `{:resource_limit}`・`{:rlimit}` を持つ（[Dafny Reference Manual](https://dafny.org/latest/DafnyRef/DafnyRef) の目次の 11.2.15 節で属性名を確認。引数の形と `--resource-limit` との関係は、取得した本文の範囲では確認できず、二次資料の記述だけなので未確認）。Lean は宣言の前に `set_option maxHeartbeats N in` を書いて宣言ごとに上限を変える（Mathlib の文書と Lean の Zulip の記録で確認。Lean の公式リファレンスの本文は確かめていない）。どちらも本体の外の注釈であり、署名の中の節ではない。

**比べた点**: A は数を数として書け、CLI の `--proof-steps=<整数>` と名前が対応する（原則 4）。属性は 01-02 で「型付けと評価の意味を変えない」ものとされ、steps の上限は受理の範囲を変えるが評価の意味は変えないので、この分類に収まる。B は文法を変えないが、数を文字列で書く不自然さがあり、`"2e5"` などの扱いも決める必要がある。C は新しい語と位置を足し、属性で済む役割の構文を増やす（原則 5）。属性はトップレベルの宣言の前にだけ書けるので、A と B では implement の中のメソッドとラムダに個別の指定を書けない（R7）。

**影響**: R10a は属性の引数の文法、R60 は E0801 の help の一覧・E0220 の扱い、R70 は出どころの表示（関数の指定・CLI・設定・既定値）、D10 は 01-02 の属性の表。L70 には影響しない（steps は判定の打ち切りであり型付けの規則ではない）。

**推す案**: A（`@proofSteps(<整数リテラル>)`）。指定値の形と範囲は R6、付けられる宣言は R7 で問う。CLI の綴り `--proof-steps=<整数>` は計画の全体で使われているので、そのまま確定してよいかを確認だけ問う（第 5 節の Q12）。

### S11. 一般の check

**決まっている大枠**: 期待する篩と基の値から `Result[篩付きの型, 検査のエラー]` を返す純粋な検査を明示して使う。暗黙の動的検査は挿入しない（DET-L09）。対象の篩が期待型から一意に決まらなければ注釈を求め、try・mapError・パイプで確定すれば受理する（DET-L23、O068）。引数の評価・回数・順・失敗の payload を保ち、成功を証明した場合だけ `Result.Ok` へ置き換えてよい（D32）。本調べで読んだ Lean の範囲では、この check の内部名は見つからなかった。

**残る点**: 置き場所と名前、エラーの型。

| 候補 | 名前と署名の形 |
|---|---|
| A 一つの標準関数 | `Refinement.check(value: v)`。結果は期待型の篩付きの型と `Refinement.CheckError` の Result |
| B 基の型ごとの関数 | `Integer.check(value:)`・`String.check(value:)`・`List.check(values:)` など |
| C 新しい式の構文 | `check v` |

```benitoite
type Port = Integer{p | 1 <= p and p <= 65535}

function parsePort(raw: Integer) -> Result[Port, Refinement.CheckError]
  return Refinement.check(value: raw)
end function
```

エラーの型の候補は次の三つである。

| 候補 | 宣言 | 性質 |
|---|---|---|
| E1 | `record CheckError` に `expected: String`（期待した型を診断と同じ書式で英語に表示した文字列） | Show を常に実装できる。表示の書式が公開の値になるので、書式の変更が観測できる変更になる |
| E2 | `record CheckError[T]` に `expected: String` と `value: T` | 失敗した値を持ち運べる（RangeError が入力を保持するのと同じ）。Show は `T` の Show を要する。`or die` に渡すには T の制約が要る |
| E3 | `data CheckError` に `Failed` だけ | 情報がない。呼び出し側は自分で渡した値を使う |

他の言語では、Haskell の refined パッケージが `refine :: Predicate p x => x -> Either RefineException (Refined p x)` を持つ（[Hackage の Refined](https://hackage.haskell.org/package/refined/docs/Refined.html)、取得 2026-11-05）。結果の型を型引数の述語で決める点が A に近い。

**比べた点**: A は役割が一つで名前も一つになり（原則 5）、結果の型を期待型から決める規則（DET-L23）を一か所に書ける。B は基の型ごとに同じ役割の関数が増える。C は予約語を足す。名前 `check` は CLI の `check` と同じ語だが、`Refinement.` で修飾するので取り違えにくい（推測）。置き場所を `Benitoite.Unofficial.Refinement` のような import が要るモジュールにするか、prelude にするかも決める必要がある。Scope と Range は import が要る非公式のモジュールである（[リファレンス第 12 節](../../reference/benitoite.md#12-modules)）。エラーの型は、E1 が Show と `or die` を素直に使え、既存の `RangeError` などのエラーの扱いに近い。E1 の `expected` の文字列を機械で解析する用途は想定せず、文書でそう書く。

**影響**: L70 は check の δ と型付け（期待型から結果の篩を決める規則）を表層に足す。R10b は DET-L23 の制約の解き方、R40 は組み込みの本体、R60 は注釈を求める診断、D10 は使い方の例と `try`・`or die` との組み合わせ。

**推す案**: A と E1。置き場所は import が要るモジュール `Benitoite.Unofficial.Refinement` とし、新しい篩の機能をまだ非公式の扱いに揃える案を推す（Range・Scope と同じ扱い）。

### S12. 安全な入口の公開名と完全署名

**決まっている大枠**: 19 行の内部の契約（K08）。既存の Option・Result の API は保つ（K09）。NonEmptyList は篩付きの List の別名へ移す（D33）。

19 行のうち 15 行は既存の公開名（`Range.get`、Range の射影 9 本、NonEmptyList の 5 本）であり、名前を保ったまま結果の型に篩を付ける。新しい公開名が要るのは、内部名 safeHead・safeGet・safeTail・sameLengthGet の 4 行である。

**safeHead・safeTail**: NonEmptyList が `List[T]{xs | 0 < List.length(xs)}` の別名になれば、内部で同じ依存列（`safeHead T`・`safeTail T`）を使う `NonEmptyList.head`・`NonEmptyList.tail` は、非空と証明した任意の List を受ける。

| 候補 | 内容 |
|---|---|
| A 新しい名前を足さない | 非空と証明した List に `NonEmptyList.head`・`NonEmptyList.tail` を使う |
| B List に足す | `List.first`・`List.rest` など |

A は同じ役割の名前を一つに保つ（原則 5）。利用者は `import Benitoite.Unofficial.NonEmptyList` を書く必要がある。**推す案: A**。

**safeGet**: 添字が `0 <= i and i < List.length(xs)` を満たすときに T を返す。

| 候補 | 署名 |
|---|---|
| A | `List.at[T](xs: List[T], i: Integer{k \| 0 <= k and k < List.length(xs)}) -> T` |
| B | `List.element[T](xs: List[T], i: Integer{...}) -> T` |

`List.at` は調べ（[8.2](../study/refinement-full.md)）の仮名である。JavaScript の `Array.prototype.at` は負の添字を末尾から数え、範囲外では `undefined` を返す（[MDN](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/at)、取得 2026-11-05）。LLM がこの意味で `List.at(xs: xs, i: -1)` と書くと、A では篩で静的に拒否される（DET-L09）ので、誤りは実行前に見つかる。引数名 `xs`・`i` は既存の `List.get` と同じにする。**推す案: A**。理由: 短く、他言語の利用で添字を取る関数と分かりやすい（推測）。負の添字の誤用は原則 1 の静的な検査で拒否できる。

**sameLengthGet**: 検査済みの添字を、元の List と同じ長さの別の List に使う。

| 候補 | 署名 |
|---|---|
| A | `Range.getFrom[T, U](value: CheckedIndex[T], values: List[U]{ys \| List.length(ys) = <value の元の List の長さ>}) -> U` |
| B | `Range.getSameLength[T, U](value: ..., values: ...) -> U` |

`getIn` は、Benitoite では `In` の接尾辞が範囲付きの値（`checkPathIn`・`readTextIn`）を表すので避ける。他の言語で同じ役割の確立した名前は確認できなかった（未確認）。**推す案: A**。

**既存の射影の完全署名の書き方**: 内部の契約は `Integer{self=checked.minimum}` のように不透明な record の欄を参照する。Range.bnt の中では欄の取得関数 `CheckedInteger.minimum(value)` が見えるので、標準ソースの完全署名は次のように書ける。

```benitoite
public function minimum(value: CheckedInteger) -> Integer{m | m = CheckedInteger.minimum(value)}
```

ただし、利用者のモジュールでは `CheckedInteger.minimum` が E0340 で使えず、`Range.minimum(value)` は一般の関数呼び出しなので篩に書けない（S3）。利用者は検査済みの境界との関係を自分の関数の契約に書けない。これを書けるようにするかは、書ける形の範囲の問いとして R11 に分ける。文書と診断がこれらの篩を表示するときの書式（内部の欄の名前を見せるか）は、R11 の答えに合わせて D10・R60 で決める。

**影響**: L70 は公開名から内部の依存列への写し（L60 の合成表と同じ）、R40 は `List.at` と `Range.getFrom` の本体、D10 は移行の案内（`NonEmptyList.head` を List に使える）。

### S13. PathBases の型と発行の入口

**残る点**: 型の置き場所と名前、発行の入口を Process.Environment の操作にするか組み込みの関数にするか、等号・表示の可否。

| 候補 | 内容 |
|---|---|
| A | 型は `Scope.PathBases`（組み込みの不透明型）。発行は `Process.pathBases() -> Scope.PathBases uses Process.Environment` の組み込みの関数で、`effect Environment` の操作にはしない |
| B | 型は A と同じ。発行を `effect Environment` の操作として宣言する（`workingDirectory()` などと同じ並び） |
| C | 型を `Process.PathBases` に置く |

```benitoite
import Benitoite.Unofficial.IO.Process
import Benitoite.Unofficial.Scope

function bases() -> Scope.PathBases uses Process.Environment
  return Process.pathBases()
end function
```

**比べた点**: Lean では発行（`E_IssuePathBases`）は節の検査を持たない（[l00b.02/signatures.md](../l00b.02/signatures.md) の RV-at 中2 の対応）。B のように操作として宣言すると、利用者のハンドラが `case Process.pathBases() -> resume(...)` で節を書けるように見え、Lean の遷移と食い違う。A は、範囲付きの IO（`File.readTextIn` など）が組み込みの関数でエフェクトを持ちハンドラで扱えない今の形（[リファレンス第 11 節](../../reference/benitoite.md#11-effect-handlers)の Complete and partial handlers）と揃う。ただし A では、Process.Environment のすべての操作を扱うハンドラでも pathBases の効果が残るので、その説明を文書に書く必要がある。結果を Result に包まない。実行の開始前に固定した値を返し、失敗しないためである（[riders 2.4](../study/riders-303-290-309.md)）。C は検査の入口（Scope）と型が別のモジュールに分かれる。

等号・鍵・Show は持たせない案を推す。等号は別の実行の値の比較を許す意味を持ちうること、Show は secrets の場所を表示しうることが理由である（D60 の通常の要約の扱い）。

**影響**: L70 は発行の表層の型付け（`C_IssuePathBases`）と、ハンドラの効果の差し引きとの関係の確認、R30 は組み込みと実行ごとの σ、D10 は Process と Scope の文書。Process のモジュールが Scope を import するが、Scope は Process を import しないので循環しない。

**推す案**: A。

### S14. At の入口の名前と完全署名

**残る点**: path の At の名前と引数の順、`CheckedPath` を返す At を足すか、要求（RequestIn）の At を足すか。

path の At の署名の案は次である（pattern の型は S15）。

```benitoite
@builtin("Scope.checkPathInAt")
public function checkPathInAt(bases: Scope.PathBases, pattern: String, path: String) -> Result[PathIn, ScopeError]
```

| 論点 | 候補 | 比べた点 |
|---|---|---|
| 名前 | A `checkPathInAt`（R Q04 の仮名） / B `checkPathInWith` | A は旧 `checkPathIn` との違いが接尾辞の At だけで分かり、エラーの構成子 `ScopeError.At` と名前が対応する。B は `With` の語が何を受けるかを示さない |
| 引数の順 | 基準を先に置く | 名前付き引数なので順は呼び出しに影響しないが、文書と fmt の表示を揃える |
| CheckedPath を返す `checkPathAt` | A 足さない / B 足す | Lean の At は PathIn と RequestIn だけを対象にする（0.3 の 3）。B は Lean のモデルに対象を足す作業を伴う。PathIn は CheckedPath の役割を含み、IO へそのまま渡せる |
| 要求の At | A 足さず、`AtInput.Request` も公開しない / B `Http.checkRequestInAt(pattern:, request:)` を足す | 第 S16 節の循環と結び付くので、そこで比べる |

**推す案**: 名前は A、`checkPathAt` は足さない、要求の At は S16 の推す案に従い足さない。

### S15. At の pattern 引数の型

**残る点**: 0.3 の 2 のとおり、Lean の核の At は pattern にソースのリテラルから作った値だけを受ける。表層の pattern 引数の型をどうするか。

| 候補 | 内容 | Lean への影響 |
|---|---|---|
| A 動的な String を受け付ける | 旧 `checkPathIn` と同じく、実行時の文字列も受ける。形式不良は `AtFailure.InvalidPattern`、元の入力は `AtInput.Text` で保持する | L70 で、pattern の文字列を `RangeExpr` へ解析する規則（基準の名前 `{root}` などと secrets を含む）を核に足す。`ScopeDelta.parsePattern` は絶対形だけを読む |
| B String だが、リテラルと const 参照だけを受け付ける | 動的な文字列を静的に拒否する | 核は今のまま。表層でリテラルを `scopePattern` へ写す |
| C 新しい公開の型（例: `Scope.Pattern`）を設ける | パターンの値を変数に入れて渡せる。作る入口は別に決める | 核の `Ty.scopePattern` に公開名を与える。動的な文字列から作る入口を足すなら A と同じ解析が要る |

```benitoite
import Benitoite.Unofficial.IO.Process
import Benitoite.Unofficial.Scope

function checkInput(input: String, allowed: String) -> Result[Scope.PathIn, Scope.ScopeError] uses Process.Environment
  bind bases <- Process.pathBases()
  return Scope.checkPathInAt(bases: bases, pattern: allowed, path: input)   // A では受理、B では allowed が動的なので拒否
end function
```

**比べた点**: A は旧 API と同じ使い方ができ、許可する範囲を引数や設定から受け取るスクリプトを書ける（原則 6）。決定済みの AtDetail が `originalPattern: AtInput` に Text を含むことと、調べの「動的な文字列にだけ現れる未束縛の基準は At の Error」も A を前提にしている。ただし、核の解析の規則を足す作業が L70 に増え、その所要は見積もっていない。B は核を変えないが、旧 `checkPathIn` で書けた形が At では書けなくなる（R8）。C は型を一つ増やし、作る入口の設計が別に要る。

**影響**: A を選ぶと、L70 の追加作業の範囲（解析の定義と、Rust の解析との比較の入力）を取りまとめが見積もる。B なら R60 に「pattern にはリテラルを書く」診断が要る。

**推す案**: A。理由: 決定済みの AtDetail の形と調べの規則に合い、旧 API との使い方の差を基準の引数だけにできる。B を選ぶ場合は、書ける形の制限として R8 に答える。

### S16. 案 B の公開型の完全な宣言と、Scope と Http の循環

**決まっている大枠**: K01。名前は既存の標準ライブラリの命名に揃える（依頼の指示）。

#### 循環の解き方

0.3 の 1 のとおり、`AtInput.Request(Http.ClientRequest)` を Scope に置くと Scope と Http が互いに import する。

| 候補 | 内容 | 影響 |
|---|---|---|
| A `AtInput.Request` を公開しない | 要求の At の公開入口を設けない（S14）。AtInput は Text と Pattern の二構成子 | 公開型の数は 19 のまま（Request は構成子であり型ではない）。要求の失敗は旧 `checkRequestIn` の `RequestCheckError` のまま。返す入口のない構成子を公開しない点で、`outsideScope` を公開しない決定と同じ扱いになる |
| B `ClientRequest` を Scope か下位のモジュールへ移し、Http に別名を残す | `type ClientRequest = ...` を Http に置く | 別名は元の所有者を保つ（[リファレンス第 7 節](../../reference/benitoite.md#opaque-types)）ので、表示や診断の型名が変わる可能性がある（未確認）。既存の利用者のコードの互換を照合する必要がある |
| C At の公開型を Http が import する第三のモジュールへ置く | 例: Scope の At 関連を別モジュールにする | `Scope.ScopeError.At(Scope.AtDetail)` の決定済みの綴りと合わなくなる |

**推す案**: A。理由: 決定済みの綴りを保ったまま循環を避けられ、返す入口のない値を公開しない設計者の判断（outsideScope）と揃う。Lean の内部の At（`checkedAt` の要求、`AtInput` の要求の経路）は内部に残し、公開の写しから外す。

#### 命名の方針

二つの方針を比べる。P1 は Lean の内部名をそのまま使う。P2 は既存の公開名の綴りに揃える。既存の公開名は語を省略しない（`minimumPort`・`timeoutMilliseconds`・`CheckedInteger`）一方、頭字語は大文字のまま書く（`isASCIIDigit`・`IOError`）。

| Lean の内部名 | P1 | P2（推す） | P2 の理由 |
|---|---|---|---|
| RangeExpr | RangeExpr | RangeExpression | 公開名に `Expr` の略語がない |
| Family | Family | IPFamily | Scope の中で `Family` だけでは何の族か分からない |
| IPAddr | IPAddr | IPAddress | 略語を避ける。Rust の `IpAddr` は略す（[std::net::IpAddr](https://doc.rust-lang.org/std/net/enum.IpAddr.html)、取得 2026-11-05） |
| CIDR.prefixLen | prefixLen | prefixLength | 略語を避ける |
| PortRange.lo・hi | lo・hi | minimum・maximum | `CheckedEndpoint.minimumPort` と `RangeError` の欄名に揃える |
| IPAddr.bits（Fin） | bits | bytes（Bytes） | u02-options 第 4 節の射影は Bytes。値はビット列でなくバイト列になる |
| PathBase の構成子 | Root・Cwd・Home・Work・Tmp | 同じ | パス変数 `{root}`・`{cwd}`・`{home}`・`{work}`・`{tmp}`（D54）と一対一にする |

ほかの名前（AtDetail・AtInput・PathBase・AtFailure・TargetInput・RangeAtom・Target・PathPattern・NamePattern・IPPattern・HostTarget・HostPattern・PortRange・Endpoint・EndpointPattern）は P1 と P2 で同じである。`RangeAtom` は用語集の「範囲（range）」と「エフェクトの原子（effect atom）」に合う。IP の族の構成子 `V4`・`V6` は Rust の `IpAddr` の構成子名と同じである（同上）。Go の `net/netip` は CIDR の網を `Prefix` と呼び、接頭辞の長さを `Bits()` で読む（[pkg.go.dev の net/netip](https://pkg.go.dev/net/netip)、取得 2026-11-05）が、Benitoite の文書は既に「CIDR networks」と書くので `CIDR` を保つ。

#### 完全な宣言の候補（P2・循環の推す案 A）

今の CLI では検査していない（型が存在しない）。Scope.bnt に置く形で書く。構成子の名前は Lean の構成子名の頭を大文字にしたものである。

```benitoite
/// Details of a failed At check: the failure kind, the original and parsed inputs, the resolved atoms and target, and both path bases.
public record AtDetail
  failure: AtFailure
  originalPattern: AtInput
  originalTarget: AtInput
  parsedPattern: Option[RangeExpression]
  parsedTarget: Option[TargetInput]
  resolvedPatterns: Option[List[RangeAtom]]
  resolvedTarget: Option[Target]
  patternBase: Option[PathBase]
  targetBase: Option[PathBase]
end record

public data AtInput
  Text(String)
  Pattern(RangeExpression)
end data

public data PathBase
  Root
  Cwd
  Home
  Work
  Tmp
end data

public data AtFailure
  Unbound(PathBase)
  SecretsUnbound
  InvalidPattern
  InvalidTarget
  DynamicCondition
  StaticIndex
end data

public data RangeExpression
  Absolute(RangeAtom)
  Based(PathBase, PathPattern)
  Secrets
end data

public data TargetInput
  Absolute(Target)
  RelativePath(List[String])
  HomePath(List[String])
end data

public data RangeAtom
  Top
  Path(PathPattern)
  Host(HostPattern)
  Endpoint(EndpointPattern)
end data

public data Target
  Path(List[String])
  Host(HostTarget)
  Endpoint(Endpoint)
end data

public data PathPattern
  Exact(List[String])
  Tree(List[String])
end data

public data NamePattern
  Exact(List[String])
  One(List[String])
  Many(List[String])
end data

public data IPFamily
  V4
  V6
end data

public record IPAddress
  family: IPFamily
  bytes: Bytes
end record

public record CIDR
  family: IPFamily
  network: Bytes
  prefixLength: Integer
end record

public data IPPattern
  Exact(IPAddress)
  CIDR(CIDR)
end data

public data HostTarget
  Name(List[String])
  IP(IPAddress)
end data

public data HostPattern
  Name(NamePattern)
  IP(IPPattern)
end data

public record PortRange
  minimum: Integer
  maximum: Integer
end record

public record Endpoint
  host: HostTarget
  port: Integer
end record

public record EndpointPattern
  host: HostPattern
  ports: PortRange
end record

public data ScopeError
  InvalidPattern(String, String)
  InvalidTarget(String, String)
  InvalidPortRange(Integer, Integer)
  InvalidPort(Integer)
  OutsideScope(String, String)
  PortOutsideScope(Integer, Integer, Integer)
  At(AtDetail)
end data
```

宣言について、次の点を文書（D10）に書く必要がある。

- `List[String]` の要素は、パスでは `/` で区切った要素を根から順に、ホスト名では `.` で区切ったラベルを左から順に並べる（Lean の `Word` と `NamePattern.Matches` の向き）。`One` は左端の一ラベル、`Many` は一つ以上のラベルの wildcard を表す。
- `IPAddress.bytes` と `CIDR.network` は網のバイト順で、V4 は 4 バイト、V6 は 16 バイトである。`prefixLength` は V4 で 0〜32、V6 で 0〜128 である。これらの有効性は型では保証せず、処理系が作る値が満たす条件として記す（u02-options 第 4 節）。
- これらは公開の data と record なので、利用者も値を作れる。作った値を At の検査に渡す入口はない（S15 の推す案では pattern は String）ので、検査の結果を偽造する経路にはならない。PathBases は不透明のまま（DET-R12）。
- 等号と鍵は通常の構造の規則に従う。Show は ScopeError の既存の Show（引用・エスケープ・4096 バイトの上限、D61）を `At` にも適用し、secrets を含む原子は一覧名と件数に要約する。Show の実装は Trait.bnt に置く（Trait.bnt は既に Scope を import している）。
- AtFailure を `@extensible` にしない案を推す。ScopeError が閉じた data であり、網羅性の検査で新しい失敗の種類の扱い漏れを見つけられる（原則 1）。

**入れ子の型で名前が重なる構成子**: `TargetInput.Absolute` と `RangeExpression.Absolute`、`PathPattern.Exact`・`NamePattern.Exact`・`IPPattern.Exact`、`RangeAtom.Path`・`Target.Path` などは型名で修飾して書くので衝突しない（[リファレンス第 7 節](../../reference/benitoite.md#data-types)）。`Target.Endpoint(Endpoint)` は型と構成子が同名だが、構成子は `Target.Endpoint` と書くので取り違えない。

**影響**: L70 は 19 型の宣言・観測・照合・網羅性（u02-options 第 6 節の仮見込み 3〜6 時間に、循環の処置と命名の写しを足す）。R30 は内部の値から公開の値への変換、R60 は Show と JSON、D10 は宣言と読み取りの例。

## 3. 書ける形を制限する選択（独立した問い）

各問いは推す案の細則に含めない。答えはほかの問いの推す案に依らない。

### R1. 篩の束縛名と、その型を付けた引数の名前の同名

`n: Integer{n | 0 <= n}` のように、束縛名を引数名と同じにする書き方を受け付けるか。

- 受け付ける: 同じ値を指すので意味は明らかで、LLM が引数名を流用しても通る（推測）。ただし、結果の型の篩の中で引数名と同名の束縛名を書くと、引数でなく結果の値を指すので、取り違えが起こりうる。
- 拒否する（推す）: 束縛名は見える局所の名前と重ねてはならないとし、`shadow` を明示しない限り名前を隠さない今の規則（01-03）に揃える。影響は、書き手が別の一文字を選ぶ手間だけである。

```benitoite
function next(n: Integer{k | 0 <= k}) -> Integer{n | n = k + 1}   // 拒否する案では、結果の束縛名 n は引数 n を隠すので誤り
```

### R2. 値引数の型を Integer に限るか

`type Prefix(s: String) = String{t | ...}` のように、Integer 以外の値引数を受け付けるか。

- Integer に限る（推す）: 案 I の線形整数で使うのは主に整数であり、長さ・添字・境界の用途（D02 の主な用途）を覆う。Character・Decimal・Float を境界にした別名は書けず、各使用箇所に篩を直接書く必要がある。
- 篩の項に現れる全 sort を受け付ける: Decimal の境界（`type AtMost(limit: Decimal)`）などを別名にできる。L70 で値引数の sort ごとの置換と整形式を確かめる範囲が広がる。

### R3. 範囲パラメータの種類 host を受け付けるか

Lean の種類は path・host・endpoint の三つだが、host の範囲を添字に持つ値型もエフェクトもない（0.3 の 3、エフェクトは File が path、Http.Connect が endpoint）。

- 受け付けない（推す）: 使う位置のない種類を宣言できても役割がない。`[range R: host]` は「この種類を使う型やエフェクトがない」と診断する。
- 受け付ける: 将来 host の範囲を持つ型を足したときに文法を変えずに済むが、それまで書いた R は使い道がなく、未使用の警告の扱いを決める必要がある。

### R4. 範囲パラメータと閉じた原子を一つの角括弧に混ぜるか

`uses File.Read[R, "/tmp/**"]` を受け付けるか。

- 受け付ける（推す）: 今の複数原子の略記（`File.Write["/out/a/**", "/out/b/**"]`）の延長であり、二つの原子に展開する。拒否すると `uses File.Read[R], File.Read["/tmp/**"]` と書き分ける必要がある。
- 拒否する: 角括弧の中の字句の種類（文字列か名前か）が混ざらず、構文解析が単純になる。

### R5. 範囲パラメータを関数以外の宣言に書けるか

`type Reader[range R: path] = function(path: Scope.PathIn[R]) -> Result[String, IOError] uses File.Read[R]` や、範囲パラメータを持つ record を受け付けるか。

- 関数の宣言だけ（推す）: D40・DET-L14 の例は関数の署名だけであり、Lean の data の引数の数（`DataArity`）は型パラメータだけを数える。別名・data・record に足すと、変性の検証（D14）と範囲の具体化の規則が増え、所要は見積もっていない。実用への影響は、範囲多相の callback の型を別名で短く書けないことである。
- 型の別名にも書ける: 別名の展開だけで済むので、data・record よりは小さい追加になる。L70 の別名の展開に範囲の置換を足す。

### R6. steps の指定値の形と範囲

`@proofSteps(...)` の引数に何を書けるか。

- 正の十進の整数リテラルだけ（推す）: 属性の引数が実行前に分かる値であることを字面で保証する。上限は CLI の `--proof-steps` と同じ範囲にし、0 と負の数は誤りとする。const の参照（`@proofSteps(largeProof)`）は書けず、複数の関数で同じ値を使うには数を繰り返す。
- 整数の const 参照も受け付ける: 値を一か所で変えられるが、属性の引数に名前解決と定数の評価が入る。

### R7. steps の指定を付けられる宣言

- トップレベルの関数だけ（推す）: 01-02 の属性の位置に合い、文法の変更が引数の形だけで済む。implement の中のメソッドとラムダの条件は、それを含むトップレベルの関数の指定（ラムダ）か、CLI・設定の値（メソッド）で数える。メソッドごとに上限を変えたい場合は、本体をトップレベルの関数に分ける必要がある。
- メソッドにも書けるようにする: implement の中の宣言の前に属性を書く文法を足す。
- ラムダにも書けるようにする: 式の中に属性を書く文法を足す。

### R8. At の pattern をリテラルと const に限るか

S15 で候補 B を選ぶ場合だけ答える。

- 限る: 核を変えずに済む。許可する範囲を実行時の文字列から受け取る使い方は At では書けず、旧 `checkPathIn`（絶対形だけ）か、静的に分かる範囲を使う形へ書き直す必要がある。
- 限らない: S15 の候補 A と同じ。

### R9. 述語に書けない判定

S4 の推す案では、次の二つを述語に書けない。それぞれ独立に問う。

- (a) 利用者の data の構成子の判定（`Option.isSome` などの既存の関数がない型）。書けないとき（推す）、構成子の事実は `match` の分岐の中でだけ使える（D16）。書けるようにするには、構成子の判定の構文か、data ごとに判定の関数を生成する規則が要る。
- (b) 範囲付きの対象への所属。書けないとき（推す）、所属は `Scope.PathIn[...]` などの添字でだけ表す（U1）。String の篩で所属を書きたい用途は、At で PathIn を得る形に書き直す。

### R10. record の欄の型から前の欄を参照すること

S5 の候補 B を受け付けないこと。受け付けない場合（推す）、欄どうしの条件は record に篩を付けた別名で書く（S5 の A）。構築したそのままの値は別名の型を持たず、別名の型で使うには一般の check（S11）か、構築の直後の比較で事実を得る必要がある。

### R11. 不透明な record の欄との関係を利用者の契約に書くこと

S12 の末尾の点である。

- 書けない（今の規則のまま）: 利用者は `Range.value(c)` が `Range.minimum(c)` 以上であることを使えるが、自分の関数の引数に「`Range.maximum(c)` 以下」という篩は書けない。
- 標準の射影を欄の measure として登録し、篩の中で `Range.minimum(c)` と書けるようにする（推す）: 不透明な record の欄を、宣言したモジュールが公開した射影の名前でだけ読めるようにする。DET-L31 の「可視な不変欄」の「可視」を「公開の射影がある欄」に広げる意味になるので、DET-L31 の読み方の確認を伴う。L70 で射影の名前から FieldRef への写しを足す。

## 4. 既存の構文・標準ライブラリとの一貫性の点検

推す案の組み合わせについて、既存の規則との関係を点検した結果を一か所にまとめる。

| 点検の対象 | 結果 |
|---|---|
| 予約語 | 推す案は予約語を足さない。`range`・`path`・`host`・`endpoint` は型パラメータの並びの中でだけ、`proofSteps` は属性名としてだけ意味を持つ |
| 字句 | `{`・`}`・`\|` を型の直後でだけ使う（S1）。01-01 の記号の表と E0212・E0105 の説明を改める |
| 名前付き引数 | 値引数の適用（S7）、measure（S3）、新しい関数（S11・S12・S14）とも、今の呼び出しの規則に従う |
| 属性 | `@proofSteps` は書ける属性の一覧に加え、引数の形をこの属性だけ整数リテラルにする。E0801 の help の一覧を改める |
| モジュールの依存 | Process → Scope、Http → Scope、Trait → Scope の向きだけになり、循環しない（S13・S16 の推す案） |
| 命名 | 新しい公開名は語を省かず、頭字語は大文字（S16 の P2）。`In` の接尾辞は範囲付きの値だけに使う（S12） |
| 同じ役割の形 | 安全な head・tail は NonEmptyList の既存名に一本化する（S12）。一般の check は一つの関数（S11）。旧 API と At の重なりは K01 で設計者が原則 5 の例外として認めた範囲に留まる |

## 5. 設計者への質問の案

重要な順に並べる。各問いは独立に答えられる。各問いの「推す」は第 2・3 節の推す案である。

**Q1. Scope と Http の import の循環をどう解くか**（S16）
推す: A。`AtInput.Request` を公開せず、要求の At の公開入口も設けない。AtInput は Text と Pattern の二構成子になり、公開型の数は 19 のままである。実用への影響: 要求の検査の失敗は旧 `Http.checkRequestIn` の `RequestCheckError` で扱い、AtDetail の型付きの詳細は path の At だけで得られる。対案 B（ClientRequest の移動と別名）は既存の Http の型名の表示の互換を確かめる作業が要る。

**Q2. At の pattern に動的な String を受け付けるか**（S15）
推す: A（受け付ける）。実用への影響: 許可する範囲を CLI の引数や設定から受け取るスクリプトを At で書ける。L70 に、pattern の文字列（基準の名前と secrets を含む）の解析を核へ足す作業が加わり、所要は未見積もりである。対案 B は核を変えないが、旧 `checkPathIn` で書けた動的な pattern を At では書けない（R8）。

**Q3. 篩の字句・束縛名・述語の文法を推す案で採るか**（S1・S2・S3・S5）
推す: 型の直後の `{` だけを篩として読み他の位置の診断を保つ、束縛名を必ず書く、述語は通常の式として解析して許す形を型検査で確かめる、record 全体の条件は篩付きの別名で書く。実用への影響: 書き手は Liquid Haskell・F* と同じく束縛名を書く。`div`・変数どうしの積などは型検査の診断で拒否される。

**Q4. 範囲パラメータの宣言の綴り**（S8・S9）
推す: `[range R: path]`。実用への影響: `[R: path]` と書き忘れると未知の制約の誤りになるので、修正案を診断に足す。対案 `[path R]` は短いが、種類の語だけで範囲のパラメータであることを示す。

**Q5. 値引数を持つ別名の宣言と適用の形**（S6・S7）
推す: `type Window[T](n: Integer) = ...`、適用は関数の呼び出しと同じ名前付き引数の規則。実用への影響: 二つ以上の値引数は `Between(low: 0, high: n)` と名前を書く。

**Q6. 一般の check の名前とエラーの型**（S11）
推す: `Refinement.check(value:)` を import が要る `Benitoite.Unofficial.Refinement` に置き、エラーは `expected: String` を持つ record `Refinement.CheckError`（Show を実装する）。実用への影響: `bind port: Port <- try Refinement.check(value: raw) or die` の形で使える。`expected` の文字列は表示用であり、書式の変更が観測できる変更になることを文書に書く。

**Q7. 安全な入口の新しい公開名**（S12）
推す: head・tail は `NonEmptyList.head`・`NonEmptyList.tail` に一本化し、添字の取得は `List.at(xs:, i:)`、同じ長さの別の List への検査済み添字の適用は `Range.getFrom(value:, values:)`。実用への影響: 非空と証明した List に head を使うには NonEmptyList の import が要る。`List.at` に負の添字を渡すと静的に拒否される。

**Q8. 関数ごとの steps の指定の綴り**（S10）
推す: `@proofSteps(<整数リテラル>)` を関数の前に書く。実用への影響: 属性の引数に整数を書ける唯一の属性になる。

**Q9. PathBases の型と発行の入口**（S13）
推す: 型は `Scope.PathBases`（等号・鍵・Show なし）、発行は `Process.pathBases()` の組み込みの関数で、Process.Environment の操作にしない。実用への影響: ハンドラで発行を差し替えられない。Process.Environment の操作をすべて扱うハンドラの中でも、発行の効果は外へ残る。

**Q10. `CheckedPath` を返す `checkPathAt` を足すか**（S14）
推す: 足さない。At の入口は `Scope.checkPathInAt(bases:, pattern:, path:)` だけにする。実用への影響: 基準の付いた検査の結果は PathIn で受け、旧 CheckedPath の射影（`Scope.path`）の代わりに `Scope.pathInValue` を使う。

**Q11. 公開型の命名の方針**（S16）
推す: P2（`RangeExpression`・`IPFamily`・`IPAddress`・`prefixLength`・`PortRange.minimum`/`maximum`・`IPAddress.bytes`）。PathBase の構成子はパス変数の名前に合わせて `Root`・`Cwd`・`Home`・`Work`・`Tmp`。実用への影響: Lean の内部名と公開名の対応表を L70 の写しに置く必要がある。

**Q12. CLI の綴り `--proof-steps=<整数>` を確定してよいか**（K10）
推す: 確定する。計画の全体と README の後の決定が既にこの綴りを使っている。

**Q13〜Q23. 書ける形を制限する選択**（第 3 節の R1〜R11）
各問いの推す案と実用への影響は第 3 節に書いた。重要な順は、R11（不透明な欄との関係を契約に書けるか）、R5（範囲パラメータを関数以外に書けるか）、R9（述語に書けない判定）、R2（値引数の型）、R7（steps を付けられる宣言）、R1（束縛名と引数名の同名）、R4（範囲パラメータと原子の混在）、R6（steps の値の形）、R10（record の欄の参照）、R3（host の種類）、R8（S15 で B を選んだ場合だけ）である。

## 6. 後段への申し送り

| 担当 | 申し送り |
|---|---|
| L70 | S15 の候補 A を選んだ場合の pattern の文字列の解析、S16 の 19 型（Request を除いた AtInput）の宣言・観測・網羅性、S11 の check の δ と型付け、S12 の公開名から内部の依存列への写し、S13 の発行とハンドラの効果の差し引きの関係の確認 |
| R10a | S1 の字句と構文、S6・S7 の別名、S8 の型パラメータ、S10 の属性の引数 |
| R60 | E0212・E0105・E0801 の修正案の分岐、`[R: path]` の修正案、篩に書けない演算の診断、ScopeError.At の Show |
| D10 | 01-01・01-02 の文法の表、英語リファレンスの Scope・Range の節、生成 Skill の文法と標準署名、AtDetail の読み取りの例と `List[String]` の並びの規則 |
| 取りまとめ | Scope と Http の循環が標準ライブラリにも適用されるかの確認（未確認）、u02-options 第 6 節の L70 の仮見込みの見直し |
