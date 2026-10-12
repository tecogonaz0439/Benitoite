# 調査: `uses` の表示の偽装（TODO-177 の F-2）

調べた版は、ブランチ `san_benito` のコミット `1f951aa`（`benitoite --version` は `0.0.2`）である。debug のビルド（`cargo build -p benitoite`）の実行ファイルで、リポジトリの外（`/private/tmp/claude-501/uses-study/`）に置いた小さな `.bnt` を `check`・`check --diagnostics=json`・`run`・`test` に渡して確かめた。`cargo test` の全体と `scripts/check.sh` は走らせていない。行番号の起点は、`src/`・`tests/`・`testdata/`・`skill/` で始まるパスは `crates/benitoite/`、ほかのパスはリポジトリの根である。「（推測）」と書いた箇所は、コードや文書を読んだだけで実行していない。

出どころは docs/todo の TODO-177 の F-2（later-issues の 106）である。関連は docs/todo の TODO-143（契約の変更と権限の差分を利用者に示す方法）。

## 要点

- 所見は今のコードで成り立つ。`import Benitoite.Unofficial.IO.File as Console` の後に `uses Console.Write` と書いた `main` は、`check` を診断なしで通り（終了状態 0、文章と JSON のどちらも何も出さない）、`run` でファイルを書いた。
- 処理系は、この版では実行前に権限の一覧を示さない（00-02「エフェクトと権限の置き場所」、00-03 の表）。利用者と LLM が見る「表示」は、ソースの `main`（テストではテストの関数）の `uses` そのものであり、同梱の Skill は「`uses` を読んで表の言葉で利用者に伝える」手順を課している（`skill/SKILL.md` の「Before running」）。したがって、偽装の経路は「`uses` に現れる名前が import の別名で決まる」ことの一点に絞られる。
- 偽れる経路は、エフェクトを宣言する標準ライブラリのモジュールに `as` で別の名前を付ける形だけである。確かめた形は、`File as Console`（操作の名前 `Read`・`Write` が一致するので最もまぎらわしい）、`File as Console` と `Console as File` の入れ替え、`Process as Console`（`uses Console.Run`）、prelude の `import Benitoite.IO as Pure`（`uses Pure.All` が `IO.All` と同じ意味になる）、`import Benitoite.Assert as Log`（`uses Log.Check`）。
- 利用者のモジュールに組み込みと同じ名前（`Console` など）を付けても偽れない。そのモジュールのエフェクトは利用者のエフェクトであり、`main` とテストの関数の `uses` に残すと E0506（処理されないエフェクト）になる。組み込みの操作を行うには、そのモジュールの関数も `main` も組み込みのエフェクトを `uses` に書く必要がある。
- 推奨は、エフェクトを宣言する標準ライブラリのモジュール（`Benitoite.IO`、`Benitoite.IO.*`、`Benitoite.Network.*`、`Benitoite.Assert`）への `as` を誤りにする案（a）である。新しい診断 E0339 を加える。既存のテスト・ゴールデン・例・言語リファレンスで、この形の別名を使うものは、型検査の単体テスト 1 件だけである。形式化（`formal/`）は名前解決と import を対象外としており、Lean を先に直す必要はない。
- 作業は小さい（名前解決の 1 ファイルと診断の表、テスト、文書）。ほかの担当と重なるのは、診断の表（`src/diag/codes.rs`）、生成物 `skill/references/diagnostics.md`、`CHANGELOG.md`、言語リファレンスである。

## 所見の確かめ

### 再現

```text
import Benitoite.Unofficial.IO.File as Console

function main() -> Result[Unit, String] uses Console.Write
  return Console.writeText("/private/tmp/claude-501/uses-study/a/pwned.txt", "hello")
    |> Result.mapError(_, IOError.message)
end function
```

- `benitoite check`: 何も出さず、終了状態 0。`--diagnostics=json` も何も出さない。
- `benitoite run`: 何も出さず、終了状態 0。`pwned.txt` に `hello` が書かれた。

静的に追跡するエフェクトの集合は正しい。`Console.Write` は名前解決で `Benitoite.IO.File` の `Write`（組み込みの `File.Write`）に結び付き、型検査はそのエフェクトで検査している。偽れるのは、人間と LLM が読む名前だけである。

### 偽れる経路の一覧

| 形 | 結果 | まぎらわしさ |
|---|---|---|
| `import Benitoite.Unofficial.IO.File as Console`、`uses Console.Write` | `check` は診断なし、`run` でファイルを書いた | 高い。Skill の表で `Console.Write` は「端末に書く」と読まれる。`File.Read` も `Console.Read` に見せられる |
| `File as Console` と `Console as File` を同じファイルに書き、`uses Console.Write, File.Write` | 診断なし。`Console.writeText` がファイルを書き、`File.writeLine` が端末に書いた | 高い。両方を並べると、読み手は書かれた名前どおりに取り違える |
| `import Benitoite.Unofficial.IO.Process as Console`、`uses Console.Run` | 診断なし、`run` で `Console.shell(...)` を実行した | 中程度。`Console.Run` は Skill の表にないが、「端末で何かを走らせる」程度に読まれうる |
| `import Benitoite.IO as Pure`、`uses Pure.All` | W0501（`` `uses IO.All` allows more effects ... ``）だけで終了状態 0。本体が `IO.All` のすべてのエフェクトを生じるなら警告も出ない（推測） | 高い。`Pure.All` は純粋に見える |
| `import Benitoite.Assert as Log`、`uses Log.Check` | 診断なし | 低い。`Assert.Check` は外部に作用しない |
| `Benitoite.Network.Http` に別の名前（例: `as Clock`）、`uses Clock.Connect` | 試していないが、上と同じ経路で通る（推測） | 中程度。ネットワークの接続を、時計の操作のように見せられる |

最もまぎらわしいのは、操作の名前が一致する `File` と `Console`（どちらも `Read`・`Write`）の組である。ほかの組み込みのモジュールの間には、エフェクトの名前の一致がない（`Process` は `Run`・`Exit`・`Environment`、`Clock` は `Time`、`Random` は `Generate`、`Http` は `Listen`・`Connect`）。ただし、別名を自由に付けられる以上、`Safe.Run` や `Pure.All` のように、名前そのもので無害に見せる形はどのモジュールでも作れる。

### 偽れない経路

- 利用者のモジュール `Console.bnt` に `public effect Write` を宣言し、`import Console` の後に `main` に `uses Console.Write` と書くと、E0506（`` `main` does not handle the effect `Console.Write` ``）になる。テストの関数でも同じく E0506 だった。`main` とテストの関数の `uses` に残せるのは組み込みのエフェクトだけなので、利用者のエフェクトで組み込みの名前を真似ても、表示より強い操作は隠せない。
- 処理系は組み込みのモジュールとエフェクトを綴りではなく `Benitoite` の名前空間の名前で照合する（01-03「標準ライブラリの名前空間と prelude（初回リリース版）」、01-07「組み込みのエフェクト」）。利用者が同じ綴りのエフェクトを宣言しても、組み込みとして扱わない。
- 取り込んだモジュールが取り込んでいるモジュールの名前は見えない（01-03）。利用者のモジュールを通して組み込みのモジュールを別の名前で出し直す経路はない。
- エフェクトに別名を付ける構文はない（型の別名は型だけを対象にする。01-06「型の別名（初回リリース版）」）。
- `uses Benitoite.IO.All` と完全な名前で書く形は通るが、正しい名前なので偽装ではない。

### 利用者に見えるもの

- `check` は、誤りも警告もなければ何も出さない（`src/diag/render.rs` の `render_check_text`。診断が空なら空の文字列を返す）。`--diagnostics=json` は診断ごとに一つの JSON を出すだけで、エフェクトの一覧の欄はない。`run` も実行の前に権限を示さない。これは 00-02 の【決定】「初回リリース版では、処理系は実行に必要な権限を示さず…」と 00-03 の表のとおりである。
- 利用者と LLM が実行の前に確かめるのは `main` の `uses` である（07-01「スクリプトは権限を宣言しない」の段落、06-06「実行の前の確認」、`skill/SKILL.md` の「Before running」）。言語リファレンス（`docs/reference/benitoite.md` の 70 行）は "Reading the `uses` of `main` tells you everything a script may do." と書いており、別名があるとこの文は成り立たない。

### 診断の中のエフェクトの名前（あわせて見つけた食い違い）

診断がエフェクトを示す名前は、診断ごとに作り方が違う。

- E0501（宣言していないエフェクト）は、組み込みの本来の名前を示す。`File as Console` の下で `uses` を書かずに `Console.writeText` を呼ぶと、`` this function performs `File.Write` but does not declare it `` と出し、修正案は `` add `uses File.Write` `` だった（`src/typeck/context.rs` の 433〜449 行の `effect_diagnostic`）。この修正案に従うと、`File` は取り込んでいないので E0332（`` the module `File` is not imported ``）になり、E0332 の修正案は `import Benitoite.Unofficial.IO.File` を足す編集で、足せば同じモジュールの二度目の取り込み（E0324）になる。修正案をたどっても通らない。
- W0501（`IO.All` が広すぎる）の修正案は、取り込みの別名で名前を書く。`File as Console` の下では `` write `uses Console.Write` `` と示した（`src/typeck/effects/declarations.rs` の 262〜319 行の `effect_name`。コメントに「修正案も取り込み時の別名を使う」とある）。W0501 の文言そのものは、`uses Pure.All` と書いても `` `uses IO.All` `` と示す。

推奨の案（a）にすれば、組み込みのエフェクトの名前は常に本来の名前と一致するので、この食い違いも起きなくなる。

### 名前解決の今の作り

- `src/resolve/imports.rs` の `imports`（12〜139 行）が、import ごとに名前（`as` の名前、なければ最後の要素。21 行）を決め、`BindingKind::Module(target)` の束縛を作る（118〜127 行）。`as Benitoite` の誤り（E0325）は 29〜37 行で検査している。新しい検査を置く場所はここである。
- 名前の衝突の修正案は、`as` を付ける編集を出す。E0323（二つの import の名前が同じ。38〜61 行）と E0305（import の名前がトップレベルの型などと同じ。87〜117 行）は、どちらも衝突した側の import に `as <修正案の名前>` を付ける。修正案の名前は `import_alias`（141〜180 行）が名前の最後の二つの要素から作る。実際に、`import Lib.Console` の後に `import Benitoite.Unofficial.IO.Console` と書くと E0323 が `as IOConsole` を、`record File` と `import Benitoite.Unofficial.IO.File` を並べると E0305 が `as IOFile` を修正案として示した。案（a）では、この二つの修正案を組み込みのモジュールの側に付けないよう直す必要がある。

## 直し方

### 案の比べ方

| 案 | 中身 | 言語仕様の変更 | 既存の資産への影響 | LLM の書きやすさ | 設計原則との関係 |
|---|---|---|---|---|---|
| (a) 誤りにする | エフェクトを宣言する標準ライブラリのモジュールへの `as` を誤りにする | 01-03「モジュールと import」の誤りの一覧に 1 項目。01-07「組み込みのエフェクト」の表の下の段落を書き換える | 型検査の単体テスト 1 件の書き換え。E0323・E0305 の修正案の作り方の変更 | 影響はほとんどない。Skill の例・評価の課題・言語リファレンスに、この形の別名はない | 原則 3（許可する操作を理解できる）を満たす。`uses` の名前と Skill の表が常に一致する。原則 1（静的に検出して実行前に報告）にも合う |
| (b) 警告にする | 同じ形を警告（W0302）にする | 01-03 に警告の項目 | (a) と同じ | (a) と同じ | 偽装を意図するスクリプトは警告を気にしない。`check` は終了状態 0 で、`run` も既定では止まらない（`--deny-warnings` は既定でない）。原則 3 の保証としては弱い。正当な使い道がない形を警告に留める理由も薄い |
| (c) 本来の名前を示す | 別名を許したまま、処理系が `main` の `uses` を本来の名前で示す（`check` の出力や JSON の欄） | 01-03 は変えない。CLI（06-01）と診断の JSON の形に新しい出力を加える | 既存のテストへの影響は小さいが、新しい出力の形を決めてテストする必要がある | 書き方は変わらない。LLM と利用者は、ソースではなく処理系の出力を読む手順に変わる | 00-02・00-03 が初回リリース版に含めないとした「実行前の権限の表示」に当たり、TODO-143 の範囲と重なる。ソースの `uses` の偽装は残るので、Skill の手順を「出力を読む」に変えない限り防げない |
| (d) `uses` には本来の名前だけ | 組み込みのエフェクトを `uses` に書くときは、別名によらず `File.Write` の形で書く | 01-07 で、組み込みのエフェクトの名前の引き方を、ほかの修飾した名前と別の規則にする | 名前解決とエフェクトの名前の引き方の特別扱い。`uses Console.Write` が利用者の `Console` モジュールと組み込みのどちらを指すかの規則も要る | `uses` と本体で同じモジュールを別々の名前で書くことになり、誤りやすい | 原則 5（同じ役割の構文を理由なく増やさない）に反する。標準ライブラリとの疎結合の方針にも合わない |

### 推奨: (a) 誤りにする

理由は三つある。第一に、偽装の経路が別名の一点に絞られるので、そこを閉じれば「`check` を通った `main` の `uses` に現れる組み込みのエフェクトの名前は、表 01-07 の名前と一致する」と言える。Skill の手順と言語リファレンスの文（"Reading the `uses` of `main` tells you everything..."）を、そのまま正しくできる。第二に、組み込みのエフェクトを持つモジュールに別名を付ける正当な理由は、名前の衝突を避けることしかなく、衝突は利用者の側の名前を変えて避けられる。第三に、今のリポジトリでこの形を使うものは単体テスト 1 件だけで、LLM が書くスクリプトにもほとんど現れない（Skill の例、`tools/skill-eval/` の課題、言語リファレンスに例がない）。

規則の形の案は次のとおりである。

- 対象は、組み込みのエフェクトを宣言する標準ライブラリのモジュールとする。今は `Benitoite.IO`（prelude。`IO.All`）、`Benitoite.IO.Console`・`File`・`Process`・`Clock`・`Random`、`Benitoite.Network.Http`、`Benitoite.Assert`（prelude。`Assert.Check`）の 8 つである。名前の綴りや接頭辞（`Benitoite.IO.` など）で決めず、組み込みのエフェクトの表（各エフェクトの定義が持つモジュールの名前）から決めると、後でモジュールを加えても漏れない。
- 取り込みの名前（`Benitoite.Unofficial.` を挟んだ名前）でも、標準の名前でも同じに扱う。
- `as` の名前が本来の名前と同じ形（`import Benitoite.Unofficial.IO.Console as Console`）も誤りにする。許しても害はないが、規則と診断が単純になる（原則 5）。
- 純粋なモジュール（`Json`・`Time`・`Trait` など）への `as` は今までどおり許す。標準ライブラリのソース（`src/prelude/stdlib/IO/Clock.bnt` の 4 行の `import Benitoite.Unofficial.Time as TimeValue`）とゴールデン（`testdata/types/f20-interpolation-show-alias.bnt` の `import Benitoite.Trait as T`）が使っている。

名前の衝突の修正案は次のように直す。

- E0323: 衝突した二つの import の一方が対象のモジュールなら、`as` の編集を、もう一方（利用者のモジュール）に付ける。今は後に書いた側に付けている。
- E0305: import が対象のモジュールなら、`as` の編集を出さず、トップレベルの宣言の名前を変えるよう示す（編集は付けない）。
- E0332（取り込んでいないモジュール）の修正案は今のままでよい。対象のモジュールに別名がなくなるので、二度目の取り込みを勧める場合が起きなくなる。

### 形式化との関係

07-04「01-12 との対応」の表は、「初回リリース版の拡張: モジュール」を「対象外（入力の時点で一意な名前に消えている）」としている。エフェクトの名前も「モジュールと名前の組を一つの文字列で表す」（同表の「エフェクトの名前と開始状態」、段階 B1）ので、import の別名は Lean の定義に現れない。案（a）は名前解決の段だけを変え、型の規則と脱糖に触れないので、Lean の定義と性質 1 の証明を先に直す必要はない。07-04 の表も、既存の「モジュール」の行が import の規則を含むので、書き足しは要らない（`check-formal.sh` を通す必要もない）。

## 影響

### 設計書

- `docs/design/01-spec/01-03-names-modules.md` の「モジュールと import（初回リリース版）」: 【方針】の誤りの一覧に「組み込みのエフェクトを宣言する標準ライブラリのモジュールに `as` で名前を付けた場合」を加え、理由を 1〜2 文で書く。例の前の箇条（「`as` を書けば、その名前（`GShape`）で使う」）にも、例外を一言添える。
- `docs/design/01-spec/01-03-names-modules.md` の「標準ライブラリの名前空間と prelude（初回リリース版）」: 非公式のモジュールの箇条（「名前の最後の要素か `as` の名前で修飾する（`Console.writeLine`、`uses Console.Write`）」）を直す。
- `docs/design/01-spec/01-07-effects.md` の「組み込みのエフェクト」: 表の下の段落（「`as` で別の名前を付けて取り込んだときは、その名前で修飾する」）を、別名を付けられないことと、そのため `uses` の名前が常に表の名前になることに書き換える。
- `docs/design/02-impl/02-04-resolver.md` の「import の宣言の誤り」: 誤りの一覧に同じ項目を加える。「誤りと修正案」の節に、E0323・E0305 の修正案の付け方の変更を書くか確かめる（推測。今の節の記述は読んでいない）。
- `docs/design/07-quality/07-01-security-model.md`: 「スクリプトは権限を宣言しない」の段落（56 行付近）に、`uses` の組み込みのエフェクトの名前が表の名前と一致することを、案（a）の規則への参照とともに一文で加える。
- `docs/design/06-tooling/06-06-agent-skills.md` の「実行の前の確認」: 手順の前提として同じことに触れるか確かめる（推測）。
- 00-04 の用語集は変えなくてよい（推測）。

### 処理系とテスト

- `src/resolve/imports.rs`: 対象のモジュールへの `as` の検査（E0339）と、E0323・E0305 の修正案の付け方の変更。
- `src/diag/codes.rs`: E0339 の項目（文言、修正案の文、説明）。
- `src/resolve/tests.rs`: E0339 の正と負の場合（取り込みの名前・標準の名前・prelude の `Benitoite.IO`・`Benitoite.Assert`・純粋なモジュールへの `as` は通ること）、E0323・E0305 の修正案の付く側。
- `testdata/modules/` に E0339 のゴールデン（`.bnt` と `.diag.json`）を 1 件加える。07-03「テストの設計の原則」とスキル `test-audit` の作成時の関門に従い、単体テストと重ならないものに絞る。
- `src/typeck/effects/tests.rs` の 458 行: `import Benitoite.Unofficial.IO.Console as C` を使う E0419（`uses` の重複）のテストを、別名なしの `Console.Write` に書き換える。
- `src/syntax/parser/items.rs` の 876 行の `import Benitoite.IO.Console as C` は構文解析だけのテストなので、変えなくてよい。
- `src/typeck/effects/declarations.rs` の `effect_name` は、別名がなくなるだけで動きは正しい。変える必要はない（推測）。
- 診断の単体テストやゴールデンで、`IOConsole`・`IOFile` のような修正案の名前を期待するものはない（`git grep` で確かめた）。

### 文書と生成物

- `docs/reference/benitoite.md`: 548 行（`import Lib.Text as T` の説明）と 575〜577 行（非公式のモジュールの取り込み）に、IO・ネットワークのモジュールと `IO`・`Assert` に `as` を付けられないことを加える。70 行の "Reading the `uses` of `main` tells you everything a script may do." は、案（a）の後は正しくなるので残す。コードの例は `tests/reference_examples.rs` が検査するので、誤りを期待する例を加えるなら、その形で書く。
- `skill/SKILL.md`（手で書く）: 96 行の import の箇条に「IO・ネットワークのモジュールは `as` で別の名前を付けられない」と加える。「Before running」の手順は、案（a）の後は変えなくてよい。今の版では、案（a）を入れるまでの間、`main` の `uses` を読む前に import の `as` を確かめる注意を書くことも考えられる（TODO-177 の項目の直し方は Skill への注意を挙げている）。
- `skill/references/diagnostics.md`（生成物）: E0339 を加えたら `cargo run -p benitoite --example gen_skill` で作り直す。
- `docs/ja/`: 英語の版を変えたら、リリースのときに訳し直す。
- `CHANGELOG.md` の「Unreleased」の「Incompatible changes」の表に 1 行を加える（例: "An import of an IO or network module, `IO`, or `Assert` with `as`" / `E0339` / "Remove `as` and refer to the module by its last name. If the name collides with a user module or declaration, rename that one instead."）。`0.0.x` ではどの版でも互換性を壊してよい（05-01「互換性の方針」）。
- docs/todo の TODO-177 の F-2 を閉じる（`docs/todo/README.md` の決まりに従う）。TODO-143 には、処理系が権限を示すときに本来の名前で示すことを書き足すか検討する。

## 問いの候補

### 問い 1: 直し方の強さ

- 選択肢: (a) 誤りにする／(b) 警告にする／(c) 別名を許し、処理系が本来の名前で `uses` を示す／(d) `uses` には本来の名前だけを書く。
- 推奨: (a)。
- 理由: 偽装の経路が別名だけなので、そこを閉じれば Skill と言語リファレンスの「`main` の `uses` を読めば分かる」が成り立つ。警告では、偽装を意図するスクリプトを止められない。(c) は初回リリース版に含めないとした実行前の権限の表示に当たり、TODO-143 の範囲になる。(d) は名前の引き方に特別な規則を足す（原則 5）。

### 問い 2: 対象のモジュール

- 選択肢: (1) `Benitoite.IO.*` と `Benitoite.Network.*` だけ／(2) (1) に prelude の `Benitoite.IO`（`IO.All`）と `Benitoite.Assert` を加える（組み込みのエフェクトを宣言するモジュールのすべて）／(3) 標準ライブラリのすべてのモジュール。
- 推奨: (2)。決め方は、組み込みのエフェクトの表から引く。
- 理由: `import Benitoite.IO as Pure` で `uses Pure.All` と書ける（W0501 の警告だけで通ることを確かめた）ので、(1) では漏れる。(3) は、純粋なモジュールの別名（標準ライブラリのソースの `Clock.bnt`、ゴールデンの `Trait as T`）まで禁じ、偽装と関係のない書き方を狭める。

### 問い 3: 本来の名前と同じ別名（`as Console`）

- 選択肢: 誤りにする／許す。
- 推奨: 誤りにする。
- 理由: 意味のない書き方であり、例外を作らない方が規則と診断の文が短い。LLM がこの形を書くことはまれと考える（推測）。

### 問い 4: 名前の衝突の修正案

- 選択肢: (1) E0323 は利用者のモジュールの側に `as` を付け、E0305 は宣言の名前を変えるよう示す／(2) 修正案の編集を出さず、文で示すだけにする。
- 推奨: (1)。
- 理由: 今の修正案（`as IOConsole`・`as IOFile`）は案（a）の後に誤りを生む。E0323 の衝突の相手は必ず利用者のモジュールなので、相手の側に付ければ編集をそのまま適用できる（組み込みのエフェクトを持つモジュールどうしは最後の名前が重ならない）。

### 問い 5: 診断のコード

- 選択肢: (1) 新しいコード E0339 を加える／(2) E0325（`Benitoite` を名前に使えない）を広げる。
- 推奨: (1) E0339。`src/diag/codes.rs` の名前解決の誤りは E0301〜E0338 が使用中で、E0339 が空いている。警告にするなら W0302 が空いている（W03 は W0301 だけ）。
- 理由: E0325 は名前空間の予約を扱う別の規則で、説明と修正案が違う。文言の案は `` the module `{module}` declares built-in effects and cannot be renamed with `as` ``、ラベルは `` renamed here ``、修正案は `` remove `as {name}` and write `{original}.` instead of `{name}.` ``（編集は `as` の部分を消すだけにする）。

### 問い 6: Skill への注意

- 選択肢: (1) 案（a）とあわせて import の箇条に一文を加えるだけ／(2) あわせて、「Before running」に「import の `as` を確かめる」手順を加える。
- 推奨: (1)。
- 理由: 案（a）の後は、`check` を通ったスクリプトに対象のモジュールの別名は残らないので、確認の手順を増やす必要がない。手順を増やすと、利用者に示すまでの作業が長くなる。

## 作業の大きさと重なり

- 大きさ: 小さい。処理系の変更は `src/resolve/imports.rs`（検査の追加と修正案の付け方の変更で数十行）と `src/diag/codes.rs`（1 項目）。テストは名前解決の単体テストの追加、ゴールデン 1 件、型検査の単体テスト 1 件の書き換え。文書は設計書の 4〜6 か所、言語リファレンス、`SKILL.md`、生成物の作り直し、CHANGELOG。一つの作業として、他の作業を待たずに進められる。
- ほかの担当との重なり:
  - `src/diag/codes.rs`: check の資源消費（TODO-195）の制限の診断、ほかの担当が加える診断と同じファイルに項目を足す。番号の割り当て（E0339 を本件が使う）を先に決めておけば、取り込みのときの衝突は表の行の足し合わせで済む。
  - `skill/references/diagnostics.md`（生成物）: 診断を加える担当がそれぞれ作り直すので、最後に取り込む作業がもう一度作り直す。
  - `CHANGELOG.md` の「Unreleased」と `docs/reference/benitoite.md`: HTTP（TODO-198）、Regex（TODO-196）、`Task.withTimeout`（TODO-197）の担当も書き足すので、節ごとの足し合わせになる。
  - `src/resolve/` と `src/modules/`: ほかの担当は触れない（推測。各担当の対象は `src/typeck/traits/solve.rs`・`src/typeck/patterns.rs`・`src/ir/decision.rs`・HTTP の組み込み・`src/builtins/funcs/regex.rs`・`src/vm/dispatch/tasks/`）。
  - `src/typeck/`: 本件で触れるのは `src/typeck/effects/tests.rs` の 1 件の書き換えだけで、TODO-195 が触れるファイルと重ならない。案（c）を選んだ場合は `src/typeck/effects/declarations.rs` に触れるが、これも TODO-195 のファイルとは別である。
