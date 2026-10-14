# パッケージ管理と外部の関数（WASM）の設計案

> 2026-10-12 に `work/2026-10-11-package-wasm-design-draft.md`（リポジトリの外）から写した。同じ日に各項目へ取り込んだ（TODO-002 の順序を改め、TODO-211〜213 を加えた）。本文の `work/2026-10-11-package-samples/` の例は、このディレクトリの [package-samples/](package-samples/README.md) に写した。本文の「TODO-002 の文面はまだ古い順序のままである。直すときは設計者の指示を得る」は写した時点の記述であり、取り込みの指示を受けて TODO-002 を直した。

2026-10-11 の設計者との相談で決めた方向と、Claude が出した設計案をまとめる。改造のディレクトリ（`docs/YYYY-MM-DD-TODO-…-<名前>/`）を作るときの元の資料とする。決定ではない部分は「案」と書く。外部の事実のうち、付録の調査で一次資料を確かめたものには出典を添え、確かめていないものは「未確認」と書く。

## 1. ロードマップの中の位置

設計者は、docs/todo の TODO-002 の順序（サーバモードを先頭に置く）を見直し、次の順で進めると述べた。

1. 今行っている不具合・懸案の項目の対策
2. パッケージ管理と外部の関数（WASM）を一つの改造として
3. 構文の見直し（TODO-205）
4. サーバモード（実行時の権限制御を含む）
5. その後は検討中

TODO-002 の文面はまだ古い順序のままである。直すときは設計者の指示を得る。

サーバモードより前に外部の関数を入れるので、この改造が保証に加えるのは静的な照合だけである（2.3）。実行時に操作の対象を絞る仕組みは、サーバモードで加える。

## 2. 決まった方向

### 2.1 入れるもの

- 依存の記述（3 章）。
- 外部の関数の宣言 `@external("wasm", "モジュールのパス", "関数の名前")`（TODO-046。ADR 0139 で表面を決めてある）。
- パッケージごとの言語の版の宣言（TODO-096 の手段 5）。最小の形は「対応する処理系の版の範囲」とする（案）。構文の見直しで、旧い構文で書かれたパッケージを読み込んだときに、その旨を診断で示すために使う。

依存の記述と `@external` の見た目は、構文の見直しで変わる前提で置く。この改造では、何を書くか（意味）を固めることを優先する。

### 2.2 パッケージに含めるもの

パッケージの基本は、Benitoite で書いたパッケージである。パッケージに含めるファイルは、`.bnt` のソース、WASM のコンポーネント、パッケージの設定（依存の記述と言語の版の宣言）、使用許諾の文書、説明の文書に限る（TODO-093 の方向）。処理系は導入のときにコードを実行せず、パッケージのソースを根の下のモジュールと同じく読んで、型とエフェクトをすべて検査する（ADR 0156）。公開の関数の型はエフェクトを含む（ADR 0154）ので、パッケージが行いうる外部の操作は型から分かる。

外部の関数とパッケージの組み合わせは、次の三つの形になる。

| 形 | 内容 |
|---|---|
| 1. Benitoite だけのパッケージ | `.bnt` のソースだけを含む。公式の追加のライブラリ（git やパスワードマネージャのラッパー。TODO-097）もこの形で書く想定である |
| 2. WASM を含むパッケージ | `.bnt` のソースに `@external` の宣言があり、同梱した WASM のコンポーネントの関数を呼ぶ。モジュールのパスはパッケージの根からのパスとする |
| 3. パッケージを介さない外部の関数 | 根のディレクトリの下に WASM のコンポーネントを置き、スクリプトの `@external` から直接呼ぶ。モジュールのパスは根からのパスとする（ADR 0139 の決定 3） |

例は `work/2026-10-11-package-samples/` に置いた。形 1 の Textkit（純粋）と Todo（ファイルを読み書きする）、形 2 の Fuzzy（編集距離を WASM で計算する）の三つのパッケージを、今の処理系で動く形（根の下のモジュールで代用）と、提案の構文で書いた形で示した。

### 2.3 保証の範囲と、エフェクトの照合

WASM のモジュールは、処理系が与えるホストの関数を通してしか外部に作用できない。このため、宣言の `uses` が、モジュールの取り込み（imports）から求めたエフェクトを含むかを読み込みのときに検査すれば、今の「静的検査だけを保証する」範囲に収まる（TODO-048 の案）。この改造で宣言する保証の案は次のとおりである（TODO-004 への答え）。

- パッケージと外部の関数が起こしうるエフェクトは型に現れる。宣言を超えるホストの関数は解決せず、呼べない。
- 操作の対象（パス、ホスト）は絞らない。絞る仕組みはサーバモードで加える。

### 2.4 ホストの関数の操作と、言語のハンドラ

この改造では、WASM の中から呼んだホストの関数の操作を言語のハンドラに渡さない（TODO-048）。渡さないままでは、ハンドラが型から除いたエフェクトの操作を処理系が実際に行うことになり、エフェクトの保証が破れる。そこで、外部の関数のエフェクトはハンドラで型から除けない、という規則で塞ぐ。

設計者は、ハンドラに渡す実装をフェーズ 3 以降で行いたいと述べた。渡すと、WASM の関数についても、言語の関数と同じく次のことができる。

- テストのための差し替え（偽のファイル、固定した時計や乱数）
- 仮想化と dry-run（書き込みを一時ディレクトリへ向ける、外部コマンドを起こさずに記録する）
- 操作の記録と監査
- ハンドラで処理したエフェクトを型から除くこと

このため、権限にかかわる部分は、フェーズ 3 で広げられる形で作る。

- 「ハンドラで除けない」規則は、フェーズ 3 で外す暫定の制限として置く。
- ホストの関数の呼び出しは、すべて一か所の入口（IO 実行器の入口）を通す。フェーズ 3 では、そこにハンドラへの経路を差し込む。

渡す実装には、WASM の実行をホストの関数の呼び出しの途中で止め、節を実行してから再開する仕組みが要る。節が `resume` を呼ばずに終わるときは、WASM の実行を捨てる。Component Model の非同期（WASI 0.3）や Wasmtime の async の仕組みで実現できるかは未確認である。

### 2.5 WASM の形式と、関数を書く言語

- 形式は Component Model と WIT とする。将来、Rust 以外の言語で書いたコンポーネントも同じ宣言から呼べるようにするためである。
- 関数は Rust で書く想定とする。フェーズ 1 は、`wasm32-unknown-unknown` でビルドし、`wasm-tools component new` でコンポーネントに包む方式を推す（案）。`wasm32-wasip2` を対象にすると、Rust の標準ライブラリが panic の表示などのために WASI のインターフェースを取り込み、取り込みが空であることで純粋と判定する検査を通らなくなるおそれがあるからである。どちらの方式で何が取り込まれるかは未確認であり、フェーズ 1 の試作で確かめる。

### 2.6 後回しにするもの

- 出所の署名（TODO-095）。サーバモードの登録の署名と一体で決める。この改造では、依存の記述の中身のハッシュで完全性だけを保つ。
- パッケージを単位とする権限の絞り込み（TODO-094 の後半）と、外部のライブラリのエフェクトを権限の表示に出す仕組み（TODO-054）。実行時の権限制御を前提とする。この改造では、依存を加える・更新するときにエフェクトとその差分を示すところまでとする（案）。
- 公式の追加のライブラリの配り方（TODO-097）。
- 実行時の権限制御と、操作の対象の絞り込み。

## 3. 依存の記述

### 3.1 書く場所

設計者の決定: 単体のスクリプトのために入口のファイルの先頭に書け、プロジェクトのために設定ファイルにも書けるようにする。どちらに書くかは利用者が選ぶ。

付録の調査では、両方に書ける言語の扱いは三つに分かれた。片方を無視する（uv、Stack、Ruby）、誤りにする（Elixir）、合算する（Scala CLI。ただし推奨は一か所にまとめること）である。設計者は次の案を採ると決めた。

- 一つの根の依存は一か所に書く。入口のファイルの先頭と設定ファイルの両方に依存の記述があれば、誤りとする。理由: 片方を黙って無視すると、利用者が読む依存と実際に使う依存が食い違い、設計原則 1・2 に反する。
- 依存の記述を書けるのは、入口のファイルと、根の設定ファイルだけとする。取り込まれるモジュールのファイルに書いたら誤りとする（TODO-090 の「モジュールのファイルごとには書かない」）。
- 設定ファイルは根のディレクトリの直下だけを見て、親を遡らない。根は実行を始めるファイルのあるディレクトリである（ADR 0127）。衝突が起きうるのは、依存を先頭に書いた入口のファイルと設定ファイルが同じディレクトリにある場合だけである。プロジェクトの下のサブディレクトリに置いた単体のスクリプトは、別の根になる。

### 3.2 書き方

付録の調査では、先頭の記述をコメントに埋める言語（Python の PEP 723、Scala CLI、cabal、Stack）と、言語の構文で書く言語（Roc、F#、Kotlin、Elixir、Deno、Rust の frontmatter）に分かれた。設計者は次の案を採ると決めた。

- 依存の記述は言語の構文で書く。理由: パーサが検査し、位置の付いた診断を出せる（設計原則 1・4）。
- 設定ファイルにも同じ構文のブロックを書く（たとえば根に置く `project.bnt`。名前は未定）。理由: 先頭から設定ファイルへ移すときはブロックを動かすだけで済み、同じ役割の構文を二つに増やさない（設計原則 5）。
- 先頭の記述を設定ファイルへ移す命令を設ける（`benitoite package` の下に置く案）。Scala CLI の `fix`（実験的）が先例である。

### 3.3 版とハッシュ

TODO-090 の方向（ロックファイルを設けず、記述に版と中身のハッシュを直接書く）を引き継ぐ。付録の調査では、ハッシュを記述に直接書く先例は Roc（URL の最後の部分が中身のハッシュ）だけだった。uv・Deno・Go は、ハッシュを別のファイル（`X.py.lock`、`deno.lock`、`go.sum`）に置く。Rust の RFC 3502 は、ロックファイルをスクリプトに埋め込む案を検討したが、長さと分かりにくさを懸念して保留にした。

記述が長くなるのを避けるため、次の形を案とする。

- 根の記述には、直接の依存だけを版とハッシュ付きで書く。
- 依存の依存は、ハッシュの連鎖で固定する。各パッケージの依存の記述はそのパッケージの中身のハッシュの対象に含まれるので、直接の依存のハッシュが、その先の依存のハッシュまで固定する。
- 最小版選択の結果、あるパッケージが自分で固定した版と違う版が選ばれた依存だけを、根の記述に書き出す。

最小版選択とハッシュの連鎖の組み合わせ方（選び直した版のハッシュの書き方、根の記述と依存の依存の記述が食い違ったときの規則）は、改造のときに詰める。

### 3.4 取得の時点

TODO-090 の方向（`run`・`check` は手元にない依存を取得してハッシュで確かめる、ネットワークを使わない指定を設ける、ハッシュのない記述は取得せずに誤りとする）を引き継ぐ。付録の調査では、uv が実行のときに環境を自動で作り、`--offline` でキャッシュだけを使う。

## 4. 値の受け渡し

設計者の決定: この改造では、Benitoite が今持つ型と WIT が持つ型の共通部分だけを受け渡す。WASM に合わせた新しい型（幅の違う整数など。TODO-020）は、構文の見直しの改造で検討する。

Benitoite の側は 01-04・01-05 で確かめた。WIT の側の型の一覧と、再帰する型を書けないことは未確認であり、改造を始めるときに一次資料で確かめる。

| Benitoite | WIT | 扱い |
|---|---|---|
| `Integer`（64 bit の符号付き整数） | `s64` | 対応する |
| `Float`（binary64） | `f64` | 対応する |
| `Boolean` | `bool` | 対応する |
| `Character`（Unicode のスカラー値） | `char` | 対応する |
| `String` | `string` | 対応する。境界で UTF-8 を確かめる |
| `Byte` | `u8` | 対応する |
| `Bytes` | `list<u8>` | 対応する |
| `Unit` | 戻り値なし | 対応する |
| `List[T]` | `list<T>` | 要素の型が対応するときに使える |
| `Option[T]`・`Result[T, E]` | `option<T>`・`result<T, E>` | 対応する |
| `Pair`・`Triple` | `tuple<…>` | 対応する |
| レコード | `record` | 欄の名前の変換の規則が要る（WIT は kebab-case） |
| 利用者が定義した型（直和型） | `variant`・`enum` | 再帰せず、型パラメータを持たない型に限る |
| リソースの型（01-10） | `resource` | 対応させる（設計者の決定。フェーズ 2 の Regex で使う） |
| `Decimal`・`Map`・`Set`・関数 | なし | 渡せない |
| なし | `s8`〜`s32`・`u16`〜`u64`・`f32`・`flags` | 宣言の側に型がないので、これらを使うコンポーネントは読み込みのときに誤りとする |

## 5. フェーズ

### 5.1 フェーズ 1: 純粋な WASM の関数

到達点は、パッケージ管理と外部の関数の両方が動くことを確かめられる形とする。スクリプトが手元のパスの Benitoite のパッケージを依存として取り込み、そのパッケージが同梱した純粋な WASM の関数（取り込みのないコンポーネントの関数）を `@external` で呼ぶところまでを作る（2.2 の形 2。例の Fuzzy）。あわせて、依存の記述（入口のファイルの先頭と設定ファイル）、言語の版の宣言、エフェクトの照合（取り込みが空なら純粋）を入れる。形 1 と形 3 も、同じ仕組みの部分集合として動くことを確かめる。

あわせて決めることは次のとおりである（TODO-047）。

- WASM の実行系（Wasmtime などの候補）、そのライセンス、配布物の大きさへの影響。
- トラップとメモリ不足の扱いと、`Result` との対応。
- 実行時間とメモリの上限。サーバモードの前でも、無限に回る WASM の関数で処理系が止まるのを防ぐ。
- タスクの切り替えと中断の要求。WASM の関数を実行する間は、VM が呼び出しの回数の予算でタスクを切り替えられず、中断の印も読めない。fuel か epoch で実行を区切ってタスクへ戻す案がある。今の Regex の改造（TODO-201）で VM の側に作った区切り方と揃える。fuel と epoch の仕組みが何を保証するかは未確認である。

### 5.2 フェーズ 2: Unofficial のライブラリを WASM で書けるかの検証

今 `Benitoite.Unofficial` で提供しているモジュールのうち、どれを WASM で実装できるかを、仮の実装で確かめる。事前の見込みは次のとおりである。

| モジュール | 見込み |
|---|---|
| `Console`・`File`・`Process`・`Clock`・`Random`・`Http` | 移せない。WASM に与えるホストの関数の側にあたる |
| `Path` | 移せるが利点が小さい。OS ごとの区切りを引数で渡す必要がある |
| `Hash`・`Encoding`・`Csv` | ほぼそのまま移せる。大きなバイト列を境界で写す費用がかかる |
| `Regex` | 移せる。コンパイル済みの正規表現を WIT の resource で持つ |
| `Json` | 工夫が要る。WIT で再帰する型を書けないなら（未確認）、木構造の値をそのままは渡せない |
| `Time` | 大部分は移せる。タイムゾーンのデータの同梱が別の問題になる |

仮に実装する対象は、それぞれ違う難しさを持つ次の三つとする（設計者の了承済み）。

| 対象 | 確かめること |
|---|---|
| `Hash` | 最も単純な形（バイト列を渡して結果を受け取る）。境界で値を写す費用を、ほかの二つと比べる基準にする |
| `Regex` | WIT の resource と Benitoite のリソースの型の対応。長い照合を fuel か epoch で区切り、取り消しと中断を効かせること |
| `Json` | 再帰する値の受け渡しと、三つの実装の性能の比較（5.2.1） |

検証の観点は、移せるか、境界を越える費用（今の `@builtin` の実装との比）、WIT の型での表しやすさ、中断との関係、WASM のバイナリと処理系の大きさである。費用は `benchmark` スキルの短い測定で取る。

#### 5.2.1 Json の三つの実装の性能の比較（案）

同じ課題を、三つの実装で比べる。

| 実装 | 作れる時期 | 中身 |
|---|---|---|
| A. Unofficial の `Json`（Rust の `@builtin`） | 今ある | `parse`・`stringify`・`stringifyPretty` の三つが組み込みの関数で、`Json.Value` を直接作る |
| B. Benitoite で書いた外部のライブラリ（2.2 の形 1） | 今書ける | 文字の列を再帰で読む構文解析器を Benitoite で書く。パッケージ管理の前でも、根の下のモジュールとして置けば測れる |
| C. Rust で書いた WASM の外部のライブラリ（2.2 の形 2） | フェーズ 1（実行基盤）とフェーズ 2（resource）の後 | 中身は Rust の JSON の実装 |

`Json.Value` は再帰する型なので、WIT で再帰する型を書けなければ（未確認）、C は木をそのまま返せない。境界の越え方の候補は次の三つで、それぞれ測れるものが違う。

1. 文字列から文字列へ（検証、整形、パスを指定した値の取り出し）。境界で文字列を写す費用だけを測れる。
2. 平らな節点の表で返し、Benitoite の側で `Json.Value` の木に組み直す。A・B と同じ値が得られるが、組み直しの費用が Benitoite の側にかかる。
3. resource で文書を WASM の側に持たせ、要る値だけを問い合わせる（Regex と同じ形）。木を作らないので、大きな JSON から数か所だけを読む課題では、最も速くなる可能性がある。

一つの数字で比べると、境界の費用と構文解析の速さが混ざるので、課題を分けて測る。

| 課題 | A | B | C |
|---|---|---|---|
| 解析して `Json.Value` を全部作る | ○ | ○ | 越え方 2 |
| `Json.Value` を文字列に書く | ○ | ○ | 越え方 2 の逆（表に直して渡す） |
| 解析して数か所の値だけを読む | ○ | ○ | 越え方 3 |
| 整形・検証だけ（文字列から文字列へ） | ○ | ○ | 越え方 1 |

- 入力の大きさは、1 KB・100 KB・10 MB 程度の三段とする。
- C は、初回の読み込み（コンポーネントの機械語へのコンパイル）と、2 回目以降の呼び出しを分けて測る。
- 三つの実装が同じ入力の集合に同じ結果を返すことを、測る前に確かめる。
- 測定は `benchmark` スキルの手順と `tools/bench/` で行う。

比べて分かることは次のとおりである。

- B と A の差: Unofficial のモジュールを Benitoite で書き直して公式の追加のライブラリへ移すと、どれだけ遅くなるか。TODO-097 が移す手段の一つに挙げた「Benitoite で書き直す（速さが要るものは遅くなる）」の判断の材料になる。
- C と A の差: WASM の境界の費用。
- C と B の差: 速さが要るライブラリを WASM にする価値があるか。

B は今書けるので、先に作っておけば、フェーズ 2 で C ができたときに三つをすぐに並べられる。B をいつ作るかは、設計者が決める。

### 5.3 フェーズ 3 以降

ホストの関数の操作を言語のハンドラに渡す（2.4）。

## 6. 改造で詰める論点

- 依存の記述の構文と、設定ファイルの名前（構文の見直しで変わる前提の仮の形）。
- 言語の版の宣言の形と、旧い構文のパッケージを読んだときの診断。
- プロジェクトの設定とパッケージの設定を一つのファイルにするか。例では、プロジェクトは `project.bnt`（`project` のブロックと依存の記述）、パッケージは `package.bnt`（`package` のブロック）と分けて書いた。パッケージも依存を持つので、一つにまとめる案もある。
- 最小版選択とハッシュの連鎖の組み合わせ（3.3）。0.x の版の扱い（TODO-090 の残る点）。
- 中身のハッシュの計算の規則（パスの正規化、改行、実行の属性）。
- 取得元（TODO-093。git の HTTPS・SSH と手元のパス）と、採る git のライブラリ。
- パッケージの名前空間と取り込み方（TODO-092）。
- 依存を加える・更新するときに示すエフェクトの差分の形（TODO-094 の前半）。
- パッケージの中の WASM のパスの基準（パッケージの根からのパス。TODO-049・098）。
- 形式化の範囲との関係。`@external` と依存の記述が、07-04「01-12 との対応」の形式化した範囲の内側に入るか。

関連する docs/todo の項目: TODO-002・003・004・005・020・046〜050・054・082（処理系のコアの WASM 化。この改造とは別の判断）・084・085・090〜098・201。

## 付録 A. 依存の記述の調査（関数型の言語）

2026-10-11 にサブエージェントが一次資料を調べた結果の要約である。

| 言語 | 先頭の記述 | 形 | 設定ファイル | 両方あるとき | 固定 | 移す命令 |
|---|---|---|---|---|---|---|
| F# | `#r "nuget: 名前, 版"` | F# Interactive の指令 | `.fsproj` | 規則は文書にない | 版の指定だけ | 未確認 |
| Scala CLI | `//> using dep …` | コメント。コードより前に置く | `project.scala` | 合算する。CLI の指定が優先する | なし | `fix`・`export`（実験的） |
| Haskell（cabal） | `{- cabal: build-depends: … -}` | コメント | `cabal.project` | 文書にない。ソースからは周りの設定を使わないと推定 | 未確認 | 未確認 |
| Haskell（Stack） | `-- stack script --snapshot … --package …` | コメント | `stack.yaml` | `stack.yaml` を無視する | スナップショット | 未確認 |
| Elixir | `Mix.install([...])` | 関数の呼び出し | `mix.exs` | プロジェクトの中で呼ぶと誤り | `:lockfile`（1.14 から） | 未確認 |
| Roc | ヘッダの URL（最後の部分が中身のハッシュ） | 構文 | なし | 該当なし | URL の中のハッシュ | 該当なし |
| OCaml・Gleam・Elm | なし | | `dune-project`・`gleam.toml`・`elm.json` | 該当なし | | |

補足:

- Scala CLI は親のディレクトリへ遡らず、渡した入力だけを見る。調べた中で設定ファイルを親へ遡って探すのは dune だけだった。
- Elixir の `Mix.install` は 1.12 の告知で「experimental」とされた。今も実験的かは確かめていない。
- cabal は、`{- project: … -}` のブロックを 3.8.1.0 で加えた。欄は「currently not validated」とされる。

出典:

1. https://learn.microsoft.com/en-us/dotnet/fsharp/tools/fsharp-interactive/
2. https://fsprojects.github.io/Paket/fsi-integration.html
3. https://scala-cli.virtuslab.org/docs/reference/directives
4. https://scala-cli.virtuslab.org/docs/guides/introduction/using-directives
5. https://scala-cli.virtuslab.org/docs/guides/introduction/dependencies
6. https://scala-cli.virtuslab.org/docs/reference/root-dir/
7. https://scala-cli.virtuslab.org/docs/commands/fix
8. https://scala-cli.virtuslab.org/docs/commands/export
9. https://scala-cli.virtuslab.org/docs/guides/power/offline
10. https://www.scala-lang.org/blog/2024/08/22/scala-3.5.0-released.html
11. https://cabal.readthedocs.io/en/stable/cabal-commands.html （run の節）
12. https://hackage-content.haskell.org/package/hackport-0.9.1.0/src/cabal/release-notes/cabal-install-3.8.1.0.md
13. https://github.com/haskell/cabal/blob/master/cabal-install/src/Distribution/Client/ScriptUtils.hs
14. https://docs.haskellstack.org/en/stable/topics/scripts/
15. https://mix.hexdocs.pm/Mix.html （Mix.install/2）
16. https://elixir-lang.org/blog/2021/05/19/elixir-v1-12-0-released/
17. https://github.com/elixir-lang/elixir/blob/main/lib/mix/lib/mix.ex
18. https://github.com/roc-lang/roc/blob/main/docs/langref/packages.md
19. https://github.com/roc-lang/roc/blob/main/docs/mini-tutorial-new-compiler.md
20. https://ocaml.org/docs/toplevel-introduction
21. https://dune.readthedocs.io/en/stable/usage.html
22. https://gleam.run/documentation/gleam-toml-reference
23. https://guide.elm-lang.org/install/elm.html
24. https://www.unison-lang.org/docs/tooling/project-workflows/

## 付録 B. 依存の記述の調査（関数型以外の言語）

| 言語・道具 | 先頭の記述 | 設定ファイル（探し方） | 両方あるとき | スクリプトの固定 |
|---|---|---|---|---|
| Python（PEP 723・uv） | `# /// script` のコメントの中の TOML | `pyproject.toml`（`uv run` はスクリプトのディレクトリから探す） | uv はプロジェクトの依存を無視する | 任意の `X.py.lock`（`uv lock --script`）と `exclude-newer` |
| Rust（cargo script） | `---cargo` の frontmatter（nightly の `-Zscript` だけ） | `Cargo.toml`（スクリプトは自動では見つけない） | 埋め込みの manifest では workspace を禁じる | ロックファイルは target の下に置かれ、残らない |
| Deno | import の中の `npm:`・`jsr:`・`https:` | `deno.json`（親のディレクトリへ探す） | import map が裸の名前を解決する。優先の規則は未確認 | `deno.lock`（完全性のハッシュ付き） |
| Ruby | `gemfile do … end`（`bundler/inline`） | `Gemfile` | 外側の Bundler の環境を外す（ソースからの推論） | なし（ソースからの推論） |
| Kotlin | `@file:DependsOn(...)`（`.main.kts`。Experimental） | Gradle | 未確認 | 未確認 |
| Go | なし | `go.mod`（親のディレクトリへ探す） | `go run pkg@ver` は `go.mod` を無視する | `go.sum` |

補足:

- PEP 723 は 2024-01-08 に Final となった。同じ種類のブロックが複数あれば、道具は誤りとしなければならない（MUST）。スクリプトを「プロジェクトにならないもの」として扱い、ロックを標準にせず道具に委ねる。
- uv は「even if uv run is used in a project, the project's dependencies will be ignored」と書く。
- Rust の RFC 3502 は「Workspaces for single-file packages should not be auto-discovered」と書く。ロックファイルの置き場所は「Deferred」とした。
- Deno の資料は、アプリケーションでは HTTPS の import より registry を勧める。ファイルごとに版がずれやすく、`deno add` で管理できないためである。JSR を作った公式の理由に、URL の import の問題は挙がっていない。

出典:

- [S1] https://peps.python.org/pep-0723/
- [S2] https://packaging.python.org/en/latest/specifications/inline-script-metadata/
- [S3] https://docs.astral.sh/uv/guides/scripts/
- [S4] https://docs.astral.sh/uv/concepts/projects/run/
- [S5] https://docs.astral.sh/uv/reference/cli/
- [S6] https://doc.rust-lang.org/nightly/cargo/reference/unstable.html#script
- [S7] https://rust-lang.github.io/rfcs/3502-cargo-script.html
- [S8] https://goals.rust-lang.org/2026/cargo-script.html 、 https://github.com/rust-lang/rust/issues/148051
- [S9] https://docs.deno.com/runtime/fundamentals/modules/
- [S10] https://docs.deno.com/runtime/packages/
- [S11] https://docs.deno.com/runtime/fundamentals/configuration/
- [S12] https://jsr.io/docs/why
- [S13] https://guides.rubygems.org/bundler_in_a_single_file_ruby_script/
- [S14] bundler 4.0.22 の gem の `lib/bundler/inline.rb`（https://rubygems.org/downloads/bundler-4.0.22.gem）
- [S15] https://kotlinlang.org/docs/custom-script-deps-tutorial.html
- [S16] https://github.com/Kotlin/KEEP/blob/master/proposals/scripting-support.md
- [S17] https://go.dev/ref/mod
- [S18] https://pkg.go.dev/cmd/go#hdr-Compile_and_run_Go_program
