# RS3: S3 の調べと判断の案（エフェクトを宣言する語）のレビュー

- 対象: `study/effect-keyword.md`、`study/effect-keyword-questions.md`（Codex、S3）
- 前提: [README](../README.md) の「設計者の決定（2026-10-23）」（覆さない）、[S3-prompt.md の保管方針](../work-copies/README.md#f006)、[common.md の保管方針](../work-copies/README.md#f007)、`study/file-effects.md` の 2.3・4・6 節 依頼文・実行の運用記録は git の外に置き、保管していない。結果とレビューはこのアーカイブ内の記録を正とする。
- 開始版: `a0d652c0`（ブランチ `san_benito`）
- レビュー日: 2026-10-23。外部資料の確認日も 2026-10-23 である。
- 行った確認: 設計書・ソースの読み取り、`rg` による候補の語の抜き取り検索、一次資料の取得（WebFetch と curl）。ビルド・テスト・CLI の実行・LLM を呼ぶ評価は行っていない。

## 総評

外部の事実の主張は、抜き取った 8 件のうち 7 件が一次資料と一致した。残る 1 件（Delphi）は、資料のサイトが自動取得を拒むため本文を確かめられなかった。比較の論証は、uses を維持する結論ありきにも、can を推す結論ありきにもなっていない。事実と見込みを分け、成功率の主張を避けている点もよい。

一方、第二候補の `effects` は、ファイルの先頭の部分の `dependency` のブロックで欄の名前として既に使われている。本文はこの衝突を見落としている（指摘 1、重）。このほか、権限の読みの評価が can と may・allows で非対称であること（指摘 2）、新しい語を文脈で読む案を退けながら、旧 `uses` には位置を限った移行の診断を推していて論理が噛み合わないこと（指摘 3）、with の見積もりを流用した根拠が弱いこと（指摘 4）を直すべきである。どれも「改名するなら can」という順位を覆すものではない。ただし、effects を第二候補に置く根拠は崩れる。

## 確かめて正しかった主張

| 主張（effect-keyword.md） | 確かめた根拠 |
|---|---|
| 2.2 Ante: 結果型の後に `can IO, Throw ValidationErr`、`fn Unit => Unit can Emit a`。設計・実装とも開発中 | [antelang.org](https://antelang.org/) の Effects・Generators の節に、両方の例がそのままある。「Ante's design and implementation are both works in progress」とも書かれている |
| 2.2 Hack: `function f()[write_props]: void`。`[io]` という context は一覧にない | [Available Contexts & Capabilities](https://docs.hhvm.com/hack/contexts-and-capabilities/available-contexts-and-capabilities/)。context は defaults・write_props・globals・zoned・leak_safe・rx などで、`io` はない。`IO` は capability であり、defaults に含まれる |
| 2.2 Verse: `<decides><transacts>` を引数と結果型の間に書く。失敗・ロールバック・中断を表す | [Verse Glossary](https://dev.epicgames.com/documentation/en-us/fortnite/verse-glossary) の effect・decides・transacts・suspends・specifier の各項。例は `IsCriticalHealth(Health : float)<decides><transacts> : void` |
| 2.2 Nim: `{.raises: [...].}`・`{.tags: [IO].}` は proc の型にも書ける。Defect は追跡しない | [Nim Manual](https://nim-lang.org/docs/manual.html) の Exception tracking と Tag tracking。`type IO = object` は利用者が定義する型名の例 |
| 2.2 Koka: `() -> <console,exn> int`。`with` は残りを関数として渡す構文とハンドラの適用に使う | [Koka book](https://koka-lang.github.io/koka/doc/book.html) の 3.1.5「With Statements」・3.2「Effect types」・3.4「Effect Handlers」。`with finally{...}` と `with ctl yield(i)` の例がある |
| 2.1 Swift: `rethrows` は `throws` と同じ位置に書く | [Declarations.md](https://raw.githubusercontent.com/swiftlang/swift-book/main/TSPL.docc/ReferenceManual/Declarations.md) の 1500 行以降 |
| 3 Free Pascal: プログラムは `uses` 節で unit を並べる | [Quick Start](https://www.freepascal.org/_new/docs/quick-start/)。`uses MainUnit, Calculations, Utils;` の例 |
| 3 PHP: クロージャは `function (...) use ($x)` で外側の変数を捕らえる | [Anonymous functions](https://www.php.net/manual/en/functions.anonymous.php) |
| 2.2 Roc: effectful な関数は名前の末尾に `!` を付ける | 公式リポジトリの `docs/mini-tutorial-new-compiler.md`（`main!`、`echo!`） |
| 5.1 キーワードの表で、候補のうち既存のキーワードは uses と with だけ | `syntax/lexer.rs:753` の `keyword`、`:789` の uses、`syntax/token.rs` の `KwUses`。01-01「キーワード」の 36 語 |
| 5.1 標準ライブラリのソースで、候補の語は宣言名・引数名に使われていない | `src/prelude/stdlib/**/*.bnt` の出現は、すべて `///`・`//!` の英文のコメントだった |
| 5.1 `!` は `BadSymbol`。`!=` も 2 文字の `BadSymbol` | `syntax/lexer.rs:627–647` |
| 7.2 の算術: 5〜9＋1〜2＋1〜2＋0.25〜0.5＝7.25〜13.5、15＋7.25＝22.25、30＋13.5＝43.5 | 計算どおり。問いの表の 9〜18→14〜27 も合う |

本レビューで検索を広げた結果も記す。`rg` で `crates/`・`tools/`・`docs/`（`docs/archive` を除く）の `.bnt` と、Rust に埋め込んだ Benitoite の例を探した。`function|bind|const` に続く `can|effects|may|needs|does`、`.can` などのドットの後の名前、`can(`・`effects:` は、Benitoite のコードとしては 0 件だった。Rust の識別子（`typeck` の `effects` の欄など）は字句の対象でないので数えていない。従って、リポジトリの中では、can をキーワードにしても名前の移行は生じない見込みが高い。利用者のコードについては、本文の留保どおり分からない。

## 指摘

### 読めば確定する誤りと漏れ

#### 1.【重】`effects` は、先頭の部分の `dependency` のブロックの欄の名前として既に使われている

- 箇所: effect-keyword.md 4.1 の `effects` の行、5.1 の 1 段落目（「uses と with だけが既存のキーワード」）と表の「新しいキーワード」の行、8 節の「語」の行。questions.md 問 1 の B。
- 問題: 01-02「ファイルの先頭の部分」（`docs/design/01-spec/01-02-syntax.md` の 495 行・500 行）は、`dependency 別名 … end dependency` の欄に `path`・`hash`・`effects` を定める。`effects` の値は、パッケージの命令が記録した組み込みのエフェクトの名前を、カンマで区切った文字列である。実装は `syntax/header.rs:11` の `EFFECTS` と `DEPENDENCY_FIELDS` にある。01-01 の 97 行は「`language`・`dependency`・`package` と、そのブロックの欄の名前も予約しない」と定める。このため `effects` を全域のキーワードにすると、二つの問題が生じる。
  - 字句: 欄の名前が `KwEffects` の字句になる。先頭の部分の解析を直すか、01-01 の「欄の名前は予約しない」を改める必要がある。0.0.6 の整理とは別に、この規則との関係を判断しなければならない。
  - 意味: ファイルの先頭に、`effects "Console.Write, Log"`（依存の記録。組み込みのエフェクトだけで、照合しない）と、`effects Console.Write, Log`（このファイルの関数の上限）が並ぶ。二つは、引用符の有無だけが違うほぼ同じ形で、別の意味を持つ。原則 3（直接編集する箇所を壊しにくくする）と原則 4 に反する取り違えを生む。
- 修正案: 5.1 の表に「先頭の部分の欄の名前との衝突」の行を加える。4.1 と 8 節の `effects` の評価を改め、第二候補とするなら、欄の名前を変える費用（package の記録・`benitoite package` の命令・E0929・CHANGELOG 0.0.5 の移行）を別に見積もる。questions.md 問 1 の B にこの短所を明記する。can にはこの衝突がないことも、比較の根拠として書き足す。

#### 2.【中】権限の読みの評価が、can と may・allows とで非対称である

- 箇所: 4.1 の `can`・`may`・`allows` の行、questions.md 問 1 の A。
- 問題: may は「可能性と許可の二義」を理由に can より下に置かれ、allows は「実行権限を付与するように見える」として推されていない。一方 can は「権限を与えたとの誤読は説明で防ぐ」で済ませている。しかし英語の can にも許可の読みがある（`You can leave now.`）。同じ軸で評価していない。また 00-01 とコンセプトによれば、人間の主な接点は「実行前の権限（エフェクト）の確認」である。人間が注釈を「この関数に許す操作」と読むこと自体は目的に合う。避けたいのは、「処理系が実行時にそれを強制している」と誤って信じることである（01-07「エフェクトの型と権限制御の区別」）。本文はこの二つを区別せずに、許可の読みを一律に短所として扱っている。
- 修正案: 評価の軸を、(i) 計算が起こしうる作用の上限と読めるか、(ii) 人間が許す操作の一覧と読めるか（望ましい）、(iii) 実行時の強制や、権限の付与と誤解されるか（望ましくない）、に分ける。can・may・allows を同じ軸で並べ直す。結論として can が上位に残るなら、その差（may は助動詞として「かもしれない」の推量が強い、allows は宣言が付与する主体に見える、など）を一文で示す。

#### 3.【中】新しい語は文脈で読む案を退けながら、旧 `uses` には位置を限った移行の診断を推しており、論理が噛み合わない

- 箇所: 5.2 の 3〜4 段落、6.2 の 2 段落、questions.md 問 3 の「旧 uses の扱い」。
- 問題: 5.2 は、新しい語を注釈の位置でだけ読む案について、改行の判定が主に字句の種類を見ることと、`can()` という呼び出しとの区別を理由に、追加の費用（Δ文脈）が要るとする。ところが、旧 uses を通常の識別子へ戻したうえで「旧注釈の位置でだけ」移行の診断を出す案は、同じ文脈の判定を要する。今は `KwUses` が `syntax/newline.rs:186`・`:248` と `syntax/lambda_bounds.rs:228`・`:344` で継続と短いラムダの境界に関わっている。識別子に戻すと、`-> String` の次の行の `uses Console.Write` は別の文として区切られ、移行の診断を出す前に別の誤りになる恐れがある。本文はこの費用を見積もりに入れていない。
- 修正案: 旧 uses の扱いの選択肢に、「一つの版のあいだ uses をキーワードのまま残し、注釈の位置では移行の診断と編集だけを出し、名前の位置では E0216 と同様に断る」案を加え、費用と原則 5・01-01 との関係を比べる。識別子に戻す案を推すなら、その文脈の判定の費用を Δ文脈 と同じ扱いで 7 節に計上する。

#### 4.【中】新しいキーワードの見積もりに with の追加分をそのまま流用した根拠が弱い。過大と過小の要因が整理されていない

- 箇所: 7.1 の 2〜3 段落、7.2 の (a) の行、questions.md 問 4。
- 問題: file-effects.md 6 節の B（5〜9 時間）の中心は、with をブロックと数えない改行の規則と、三つの用途の判別である。新しい語は、内部の `TokenKind::KwUses` を保てば（6.1 の方針）、字句の表の 1 行、`syntax/parser/text.rs:50`・`:130` の表示、`diag/codes.rs`（uses の語が 36 出現）の文言を変えるだけで、解析・改行・短いラムダの境界は変わらない。リポジトリの中では名前の衝突もない（上記の検索）。この点で 5〜9 時間は過大の可能性がある。一方、次の過小の要因は書かれていない。
  - 長さの違い: `uses` と `with` は 4 文字、`can` は 3 文字、`effects` は 7 文字である。with なら注釈より後の列の位置が変わらない。can・effects では、同じ行の後ろにある診断の位置（ゴールデンの表示・JSON の列）と、整形器（`cli/tools/formatter/`）の行の折り返しが変わりうる。この差で、更新・照合するゴールデンが増える。
  - 指摘 3 の旧 uses の文脈の判定。
  - `tools/derive/`・`tools/try-actions-migrate/` などの生成器が出力する注釈の文字列。これらは「その他の tools 854 出現」に含まれるが、7 節で別に扱っていない。
- 修正案: (a) を「字句の切り替え」「既存の注釈と生成物の移行」「旧 uses の診断」に分け、それぞれ過大・過小の要因を書く。数値を変えないなら、「with の値を上限側の目安として仮置きした」と明記する。確定には、`tools/source-migrate/` で testdata の一部を新しい語へ移す短い試行（読み取りのみ）を先に置くと根拠になる。

#### 5.【中】前提の file-effects.md が uses の維持を推していることとの関係を書いていない

- 箇所: 2 節の末尾の段落、8 節。
- 問題: file-effects.md 4.4 は、表の「effects／using／requires 等へ統一する」の行で「現時点では uses 維持に勝る理由がない」と結論している。本書は can を改名の第一候補に推す。設計者は、同じ改造の中で向きの違う二つの推す案を読むことになる。本書がどの新しい根拠（取り違えの具体化、上限の読み、Ante の先例）によって判断を改めたのか、または両立するのか（「改名しないなら uses、するなら can」）が書かれていない。
- 修正案: 8 節に一段落を加え、file-effects.md 4.4 の結論との関係を明示する。questions.md 問 2 の C の行にも、file-effects.md が推した案であることを書き添える。

#### 6.【軽】行番号の小さなずれと、依頼文への言及の残り

- 1 節: `types.rs:242` の `parse_uses` は 243 行である。
- 2.1 Kotlin の行: 「Java 型の `throws` 宣言語を持つという候補は訂正が要る」は依頼文の候補の一覧への返答であり、読み手には意味が通らない。「Kotlin は検査例外を持たず、`throws` の語もない」と事実だけを書く。

#### 7.【軽】Nim の行が `forbids` と、語としての `tags` を落としている

- 箇所: 2.2 の Nim の行、4.1。
- 問題: 同じ節の Manual は、作用を禁じる一覧の `{.forbids: [IO].}` も proc の型に書けると定める。また `tags` は、利用者が定義する作用の一覧を導く語の先例である。4.1 の比較の候補にない。
- 修正案: Nim の行に forbids を加える。4.1 に `tags` を一行加えるか、「一覧の種類を名指す語（tags・effects）」として effects と並べて扱う。

#### 8.【軽】問いの一覧の不足

- 問 1 の表に、can の読みが最も崩れるエフェクト変数の形（`-> String can E`）を一例並べると、設計者が A の短所を判断しやすい。
- 指摘 1 の衝突を、問 1 の B か問 3 に加える。
- 語を改めても、英語の文書の地の文（`docs/reference/benitoite.md:1016` の「A function lists, after `uses`, every effect it performs」など）と、診断・Skill の説明の言い回しをどこまで直すかは、問いとして示されていない。語に合わせて動詞を変えるか（`can` の後の一覧、など）を、問 3 の「語と意味の境界」に一行加える。

### 実行しないと分からない点

- 指摘 3 の、識別子に戻した `uses` が次の行の注釈で別の文として区切られるかどうかは、机上の推定である。改造で旧 uses を識別子に戻す案を採るなら、移行の診断の再現テストで確かめる。
- 指摘 4 の、長さの違いでどれだけのゴールデンの表示・整形が変わるかは、移行の試行をしないと分からない。
- Delphi の [Programs and Units](https://docwiki.embarcadero.com/RADStudio/Athens/en/Programs_and_Units_%28Delphi%29) は、WebFetch では 403、curl では Cloudflare の確認の頁が返り、本文を確かめられなかった。検索の要約では「プログラムの uses 節が直接依存する unit を挙げる」ことは支えられたが、「カンマ区切り」は確かめていない。Free Pascal の例が同じ形を示しているので、3 節の論旨は変わらない。S3 の作業記録（[S3-log*.txt の保管方針](../work-copies/README.md#分類と元の対応)）には、Delphi・Verse・PHP・Pony の頁を開いた跡が明示されていない（空の `web search:` の行が多い）。Verse と PHP は本レビューで確かめた。Pony・Austral・Dafny・SPARK・Eff・Frank・Links・Effekt の細部（Effekt の `/ {}` の文脈的な読み、Eff の README の記述など）は確かめていない。 依頼文・実行の運用記録は git の外に置き、保管していない。結果とレビューはこのアーカイブ内の記録を正とする。

## 候補の比較についての所見

- 改名するなら can が最も有力である。上限の読み（「行いうる」）、結果型の後に列挙を導く先例（Ante）、3 文字の短さ、リポジトリの中で名前の衝突がないこと、内部の字句の種類を保てば解析を変えずに済むこと、が根拠である。短所は、裸の名詞やエフェクト変数を続けると英文として崩れること（`can E`）と、許可の読み（指摘 2）である。
- effects は、指摘 1 の先頭の部分の欄の名前との衝突で、第二候補の根拠を失う。欄の名前を改めるか、ファイル単位の宣言だけ別の形にしないかぎり、with より下に置くのが妥当である。
- uses の維持は、移行が要らず、file-effects.md の結論とも一致する。取り違えの懸念は具体化されたが、人間・LLM の失敗例は集めていない。成功率の裏付けを採否の条件にするなら、uses と can の二つに絞り、docs/todo の TODO-017 の第二段階の小さな比較を先に行うのが、費用に見合う。
