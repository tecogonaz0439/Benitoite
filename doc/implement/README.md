# 初回リリース版の実装プラン

- 状態: 骨子を設計者が確認した（2026-09-30）。`00-common/` と `10-interfaces/` の全章（10-01〜10-19）、`20-tasks/`（作業の文書 104 件。U1・U2 の 66 件、U3 の L00〜L41 の 21 件、U4 の D00〜D34 の 17 件）、`90-after-completion.md` は草稿。U3・U4 は、骨子で挙げた決めることを設計者が決めた後に（下の「U3・U4 で決めたこと」）、インターフェースの章（10-15〜10-19）と作業の文書を書いた（2026-09-30）。作業の文書を書く途中で見つかった点も、設計者が決めた（下の「U3 の作業の文書で見つかった点」「U4 の作業の文書で見つかった点」）

本文書は、Benitoite の初回リリース版の処理系を実装するための実装プランの目次である。実装を担う LLM（以下「実装 LLM」）が、[設計書](../design/README.md)と本プランだけを読んで実装できるように、作業を分け、各作業の入力・出力・受け入れテスト・完了条件を定める。置き場所と単位は [ADR 0253](../design/decisions/0253-first-release-plan-location-and-units.md) に従う。

## 範囲

初回リリース版を四つの単位に分ける（ADR 0253）。本プランは、まず U1 と U2 を並べて書いた。U1 と U2 が共有する中間表現とバイトコードを一度で凍結するためである。U3 と U4 は、U1・U2 のインターフェースを凍結した後に書き足した。

| 単位 | 内容 | 本プランでの扱い |
|---|---|---|
| U1 フロントエンドの拡張 | 字句・構文・名前解決・型検査・脱糖・判定の木・コード生成を、初回リリース版の言語に広げる | インターフェースの章（10-01〜10-14 の U1 の分）と作業の文書を書いた（草稿） |
| U2 値の表現とランタイムの作り直し | [ADR 0258](../design/decisions/0258-sixteen-byte-value-enum.md)〜[ADR 0271](../design/decisions/0271-self-made-gc-as-exception.md) の作り直し。段に分ける（[ADR 0268](../design/decisions/0268-staged-runtime-rebuild.md)） | インターフェースの章（10-01〜10-14 の U2 の分）と作業の文書を書いた（草稿） |
| U3 標準ライブラリ | prelude の追加、IO・テキストとデータ・ネットワークのモジュール | 決めることを設計者が決めた後に、インターフェースの章（10-15・10-16）と作業の文書を書いた（草稿） |
| U4 ツール | `fmt`、`test`、同梱の Agent Skill、配布 | 決めることを設計者が決めた後に、インターフェースの章（10-17〜10-19）と作業の文書を書いた（草稿） |

作り直しの検討の経緯は [U2 の検討資料](studies/u2-runtime/README.md)にある。資料は経緯であり、決定は設計書の側を正とする。

## 構成

最小実行版のプランと同じ構成をとる（ADR 0253 の決定 1）。

| 場所 | 内容 | 状態 |
|---|---|---|
| [00-common/](00-common/) | すべての作業に共通の決まり: [リポジトリとクレートの配置](00-common/00-01-repository-layout.md)、[実装の規約](00-common/00-02-conventions.md)、[作業の進め方](00-common/00-03-workflow.md)、[実装の確認の観点](00-common/00-04-review-checklist.md) | 草稿 |
| [10-interfaces/](10-interfaces/) | 凍結する Rust の型と関数のシグネチャ（後述の「インターフェースの章」） | 草稿（10-01〜10-19） |
| [20-tasks/](20-tasks/) | 作業ごとの文書（一作業一ファイル。下の「作業一覧」から引く） | 草稿 |
| [90-after-completion.md](90-after-completion.md) | すべての作業を終えた後に行うこと | 草稿 |
| [studies/](studies/u2-runtime/README.md) | 設計の検討資料（U2 の作り直し） | 採択済み |
| [tools/extract_interfaces.py](tools/extract_interfaces.py) | `10-interfaces/` から Rust のコードを取り出して置き、コンパイルを確かめる道具（最小実行版のプランの道具を、既存のクレートの作り直しに合わせて広げた） | 使える |

インターフェースの読み方（`file=`・`sig=`・`append=` の見出し、見出しの属性 `replace`・`task=`・`needs=`、道具の使い方）は、後述の「インターフェースの読み方」で定める。

## 最小実行版の実装との関係

処理系は `crates/benitoite/` のクレートの中で作る。新しいクレートは作らない。最小実行版の実装から次の形で移る（下の「決めたこと」の 11）。

1. 最初の作業 C04 が、最小実行版のモジュールを `crate::legacy` の下へ移す（`src/legacy/`）。移さないのは `base` だけである。最小実行版の CLI とテストは、`legacy` の実装で動き続ける。
2. 初回リリース版のモジュールは、C04 が空けた最終的なパス（`src/syntax/`・`src/vm/` など）に置く。最小実行版のコードを引き継ぐモジュールは、作業が `src/legacy/` の同じファイルを写して広げる。
3. 最小実行版のテストは、構文の改め（F02）の直後に新しい構文へ書き直し（C03）、初回リリース版のパイプライン（F18）が揃ったら、初回リリース版の実行器と CLI に切り替える（C05）。U2 第 1 段は、書き直したテストを初回リリース版のパイプラインで新しい VM に通して完了とする（下の「決めたこと」の 5）。`legacy` の中に第 1 段のための経路は作らない。
4. 移行の締め（C18）で `legacy` を消す。

どの時点でもクレートはコンパイルでき、`scripts/check.sh` が通る（[00-03](00-common/00-03-workflow.md)「確認と取り込み」）。移行の間の配置は [00-01](00-common/00-01-repository-layout.md)「移行の間の配置」で定める。

| モジュール | 初回リリース版での扱い |
|---|---|
| `base` | 移さずに `legacy` と共有し、型を加える（複数のファイルのソースの表、モジュールの ID、`Decimal`） |
| `diag` | legacy から写して広げる（診断コードの追加、`help:` の修正案の拡大） |
| `syntax` | 字句と AST と構文解析器の入口を新しく定める。最小実行版の構文の改め（`->`・`bind`・`shadow`・`data`・`match … with`。[ADR 0254](../design/decisions/0254-return-type-after-arrow.md)〜[ADR 0257](../design/decisions/0257-match-with-case-arms.md)）で、構文解析器を書き直す。文字の読み方は legacy から写してよい |
| `resolve`、`typeck`、`types` | legacy から写して広げる（モジュール、レコード、型クラス、エフェクトとハンドラ） |
| `ir`（脱糖、判定の木、コア IR の検査器） | コア IR と下位 IR の型は、U1・U2 の共有の章で凍結し直す。脱糖・判定の木・検査器は legacy から写して広げる |
| `bytecode` | 命令の集合と符号化を、共有の章で凍結し直す。コード生成は legacy から写して広げる（F15） |
| `runtime::heap`、値 | 作り直す（16 バイトの値、自前の確保器、二つのメモリの管理。ADR 0258〜0260） |
| `vm` | 作り直す（区画と枠、振り分けのループ、ハンドラ、タスク。ADR 0262・0263・0266・0267） |
| `runtime::sched`・`runtime::io` | 作り直す（送り出しの列、IO 実行器、書き出し用のスレッド。ADR 0264・0265） |
| `builtins` | 型付きの形で書き直す（[ADR 0261](../design/decisions/0261-typed-builtin-interface.md)）。関数の意味は legacy から写す |
| `refinterp` | VM と値を共有しない `Rc` による値の型で書き、組み込みの関数の本体だけを VM と共有する（ADR 0268、[ADR 0276](../design/decisions/0276-reference-interpreter-shares-builtin-bodies.md)）。初回リリース版のコア IR まで広げる（[ADR 0213](../design/decisions/0213-formal-verification-stage-1-in-first-release.md)） |
| `pipeline`、`cli` | legacy から写して広げる（モジュール、ディレクトリを指定した実行、シェバン）。`test`・`fmt` は U4 |

C18 が消すもの: `src/legacy/` の全体（最小実行版の `Rc` による値とヒープ、VM、二つの IO の方式で別々の経路）。第 1 段で採らなかったメモリの管理の実装は、R14 が再現できるリビジョンとして残し、本番のコードから消す。

最小実行版のテスト（ゴールデンテスト 197 件など）は、古い構文で書いてあり、C05 までは `legacy` の構文解析器で動く。F02 の後に新しい構文で書き直したもの（C03）を別の場所に置き、C05 が初回リリース版の実行器に移して古いものを消す（[00-03](00-common/00-03-workflow.md)「構文の改めとテストの移行」）。

## 作業の ID

作業の ID は、単位ごとに頭の文字で分ける（ADR 0253 の決定 2。下の「決めたこと」の 1）。最小実行版の `T` とは重ねない。

| 頭の文字 | 単位 |
|---|---|
| `C` | 単位をまたぐ作業（土台、最小実行版の実装からの移行、インターフェースの配置、テストの移行、統合のテスト） |
| `F` | U1 フロントエンドの拡張 |
| `R` | U2 値の表現とランタイムの作り直し。第 1 段を `R00`〜`R19`、第 2 段以降を `R20` 以降とする |
| `L` | U3 標準ライブラリ |
| `D` | U4 ツール |

## インターフェースの章

「持ち主」は、章の型を決めて凍結する単位である。「共有」の章は U1 と U2 の両方が使うので、両方の作業が始まる前に一度で凍結する。

| 章（仮の名前） | 凍結するもの | 持ち主 | 置き換える最小実行版の章 |
|---|---|---|---|
| 10-01 base | クレートの骨組み（`lib.rs` は C01 が置く）、専用の整数の型、span、複数のファイルのソースの表、`Decimal` の値の表現 | 共有 | 10-01 |
| 10-02 diagnostics | 診断の表現、追加する診断コードと文言の型板 | U1（U2 は実行時の報告の分を足す） | 10-02 |
| 10-03 syntax | 字句、AST の拡張（モジュール、レコード、型クラス、エフェクト、ハンドラ、属性、パターンの拡張、リストの展開など） | U1 | 10-03 |
| 10-04 modules and resolve | モジュールの表、依存グラフ、束縛と参照の表 | U1 | 10-04 |
| 10-05 types | 型とエフェクトの表現、型クラスと辞書、型検査の出力 | U1 | 10-05 |
| 10-06 ir | **コア IR と下位 IR**（辞書、レコード、`try`、`lazy`、`with`、`handle`・`resume`、定数）、脱糖・判定の木・検査器・参照インタプリタのシグネチャ | **共有** | 10-06 |
| 10-07 bytecode | **命令の集合と符号化**（レコード、辞書とメソッドの呼び出し、`handle`・`resume`・`drop`、`FORCE`・`UPDATE`、解放の枠、セルの操作、タスクの起動、定数の初期化）、**コンパイル済みプログラムの形**、コード生成が渡す生存の情報 | **共有** | 10-07 |
| 10-08 values and heap | 16 バイトの値、対象の種類と頭、確保器、回収しない区間の型（`Value<'epoch>`・`NoGcCtx<'epoch>`）、根の保存領域、二つのメモリの管理の共通の API、リスト・マップ・集合・構造の等しさの関数、止まる理由、panic 境界 | U2 | 10-08 の前半 |
| 10-09 vm | 区画、呼び出しの枠と包む枠、振り分けのループの状態、予算と要求、ハンドラの記録、タスクの対象 | U2 | 10-08 の後半 |
| 10-10 scheduler and io | タスクとリソースの状態、送り出しの列、要求の番号、IO 実行器、操作の記録、完了の型、書き出し用のスレッド | U2 | 10-08 の IO の部分 |
| 10-11 builtin interface | 組み込みの関数の型付きの形、権限ごとの文脈、応答、大きさを確かめる構築、登録、組み込みの関数の番号と、番号・名前から引く関数（`builtins::builtin_decl`・`lookup_builtin`） | **共有**（U2 が持ち、U1 と U3 が使う） | 10-10 の前半 |
| 10-12 builtin table | 組み込みの関数の名前・番号・型の表（U1 の型検査と prelude が参照する）。10-11 が C01 で置く `builtins/table.rs` に `sig=` として足す | **共有**（U3 で追加する） | 10-10 の後半 |
| 10-13 pipeline and cli | パイプライン API と CLI（`run`・`check`、ディレクトリとシェバン）、実行時エラーの報告（`runtime::report`）、実行の流れ（`runtime::run`） | 共有 | 10-09 |
| 10-14 prelude and stdlib sources | 標準ライブラリのソースの置き方と、U1 の型クラスが要る分の prelude | U1（U3 で追加する） | 10-11 |
| [10-15 stdlib additions](10-interfaces/10-15-stdlib-additions.md) | U3 が加える標準ライブラリのソースの全文（10-14 の `STDLIB` の末尾に加えるモジュール、10-14 のモジュールに加える宣言）と、組み込みの関数の表に加える 24 の部分と 136 の項目（10-12 の `PARTS` の末尾）、加える構成子のタグ。10-12・10-14 を `append=` で広げる | U3 | — |
| [10-16 io and network additions](10-interfaces/10-16-io-and-network-additions.md) | IO とネットワークの組み込みの関数が使うランタイムの口（ランタイムの内部への口、受け付けた要求の保存、HTTP のサーバの接続の層と準備の待ちの規則、外部コマンドの標準入出力、隠れた乱数の生成器、テスト用のハンドラ表のネットワークの失敗、要求の本体の上限）、F17 が呼ぶ正規表現の組み立ての関数、U3 が使うクレートの版と機能。10-10・10-11 を `append=` で広げる | U3 | — |
| [10-17 formatter](10-interfaces/10-17-formatter.md) | フォーマッタのモジュール（字句と改行の印の列・コメント・AST から役割の表を作る関数、整形、整形後の検証）。10-03 の `lex`・`parse` の出力を使う | U4 | — |
| [10-18 test runner](10-interfaces/10-18-test-runner.md) | テストの関数を実行する関数（`runtime::run` に加える）、`Assert.Check` の処理と 10-09 の `EndKind::CheckFailed` の中身、結果の報告の文章と JSON Lines、値の書き出し、`Assert` のソース。10-02・10-09・10-13・10-14 を広げる | U4 | — |
| [10-19 skill and distribution](10-interfaces/10-19-skill-and-distribution.md) | `cli::tools` の中身（`skill install`・`uninstall`、`--licenses`）、埋め込む Skill と第三者のライセンスの表示の置き方、Skill の文書を生成する道具、`scripts/release.sh` の段と入出力。10-13 を広げる | U4 | — |

## インターフェースの読み方

コードブロックの見出しは、最小実行版のプランと同じく二種類ある。パスは処理系のクレート `crates/benitoite/` からの相対パスである。

- `rust file=<パス>`（標準ライブラリのソースは `text file=<パス>`）: C01 か C02 が、そのまま置くコード。以後の作業は変えない（`lib.rs` の `legacy` の宣言と `dead_code` の許可は、C18 が外す）。
- `rust sig=<パス>`: 後の作業が中身を書く関数のシグネチャ（`;` で終わる宣言）と、その作業が置く型。シグネチャは変えない。C01・C02 の `place` が、本体を `todo!()` にした関数（`todo!()` の仮置き）として置き、後の作業が本体に書き換える（[00-02](00-common/00-02-conventions.md)「`todo!()` の仮置き」）。
- `rust append=<パス>::<項目>`・`text append=<パス>::<項目>`・`rust append=<パス>`（`text` も同じ）: 前の作業が置いたファイルに、書いたとおりのコードを差し込む（後述の「U3・U4 で決めたこと」の 2）。U3・U4 の章が、10-01〜10-14 のファイルを直接書き換えずに広げるために使う。`::<項目>` がなければファイルの末尾に加える。あれば、その項目の閉じ括弧の直前に加える。項目は、`.rs` では `const`・`static` の配列の名前（`= &[ … ]` の要素の末尾。例: `src/prelude/mod.rs::STDLIB`）か、`trait`・`struct`・`enum`・`mod` の名前（`{ … }` の中の末尾。例: `src/builtins/table.rs::tags`、`src/builtins/iface.rs::IoServices`）、`.bnt` では `effect`・`trait` の名前（`end effect`・`end trait` の行の前）か `imports`（import の宣言の並びの末尾。なければ先頭の `//!` の説明の後）である。配列と `struct`・`enum` の要素の区切りのコンマは、道具が補う。`append=` は、そのパスの `file=`・`sig=` を置いた後に当てる。ブロックの本文が（空白と閉じ括弧の前のコンマの違いを除いて）既にファイルにあれば置いたものとみなすので、`place` を何度実行してもよい。差し込む先のファイルか項目がなければ、どのファイルも書かずに止まる。見出しの後ろに属性 `append` を書く形（`file=<パス> append`）はない。

同じパスのブロックは、章のファイル名の順、章の中で現れた順につなげる。同じパスに `file=` と `sig=` の両方があるときは、`file=` のコードの後に `sig=` の仮置きを並べ、`sig=` の作業がその本体を書き換える。

初回リリース版は既存のクレートの上に置くので、見出しの後に次の属性を空白で区切って書ける。

| 属性 | 意味 |
|---|---|
| `replace` | そのパスの既存のファイルを置き換える。`sig=` だけのパスに付けると、既存のファイルを `sig=` の仮置きだけのモジュールに置き換える。付けないパスに既存のファイルがあるとき、`file=` のブロックは置けない。C04 が最小実行版のモジュールを `src/legacy/` へ移して元のパスを空けるので、C01・C02 の時点で既存のファイルがあるのは `src/lib.rs`（C04 が書いた移行の間の形）と `src/base/` だけである。したがって、`replace` を付けるのは 10-01 の `src/lib.rs` と `src/base/mod.rs` だけである |
| `task=C01`・`task=C02`・`task=L00`・`task=D00` | このブロックを置く作業。章の既定と違うとき（10-01 の `lib.rs`、10-08〜10-10 の第 2 段の分など）に書く。インターフェースを置く作業は、C01・C02 と、U3 の L00・U4 の D00 である |
| `needs=10-06,…` | このブロックが参照する項目を定める、ほかの章。`check` の対象にそれらの章がないとき、このブロックを外してコンパイルする |

章の既定の作業は、章の冒頭の説明の後に `- 置く作業: C01` の形の行を一つ置いて示す。`task=` のないブロックは、この作業に属する。

取り出しの道具 [tools/extract_interfaces.py](tools/extract_interfaces.py) には、三つのコマンドがある。使い方の詳細は道具の先頭のコメントにある。

| コマンド | 使う人 | 内容 |
|---|---|---|
| `list [--chapters 10-07,10-08] [--task C01]` | 本プランの作成者、C01・C02 | 章ごとに、置くファイル、凍結する項目、置く作業を表示する |
| `place crates/benitoite --task C01 [--overwrite] [--dry-run]` | C01・C02 | ブロックをクレートに書き出す。`sig=` の関数は `todo!()` の仮置きとして書き、仮置きを置いたファイルの先頭に仮置きの許可（`#![allow(clippy::todo, unused_variables)]` とそのコメント）を置き、書く前に rustfmt で整える。`sig=` だけのパスに既存のファイルがあれば、まだ置いていないブロックの仮置きを末尾に足す。`replace` のファイルは `--overwrite` を付けたときだけ上書きし（C01 の `lib.rs`、C02 の `base/mod.rs` があるので、C01・C02 とも `--overwrite` を付ける）、`replace` のないパスの既存のファイルに当たる `file=` があれば、どのファイルも書かずに止まる。書く内容が既存のファイルと同じなら変えないので、何度実行してもよい。`--dry-run` は、書かずに変わるものを表示する |
| `check [--chapters …] [--task C01] [--base crates/benitoite]` | 本プランの作成者 | 作業用のワークスペースに、`place` と同じ書き出し（`todo!()` の仮置きを含む）を作業の順に重ねて作り（`--task C02` は C01 → C02。C でない作業は、すべての C の作業の後にその作業だけを重ねる。`--task L00` は C01 → C02 → L00。`--task` を付けないときは C01 → C02 → D00 → L00）、Rust 1.98.1 の Clippy でコンパイルする。クレートに許可を加えない。`--chapters` で章を絞ったときだけ、`lib.rs` に `#![allow(dead_code, unused)]` を加える。lint は [00-02](00-common/00-02-conventions.md) の lint の表を使い、機能は [00-01](00-common/00-01-repository-layout.md) の「機能（feature）」の表から作る。`gc-mark-sweep` と `gc-refcount` のそれぞれについて、その機能だけの場合と、排他でないほかの機能をすべて加えた場合の二通りでコンパイルする。`--base` を付けると既存のクレートの上に重ね、章に含めない既存のモジュールと合わせて確かめる |

`check --base` と `place` の対象は、C04 の後のクレート（最小実行版のモジュールを `src/legacy/` へ移したもの）である。C04 の前にインターフェースの章を確かめるときは、C04 の手順（[00-01](00-common/00-01-repository-layout.md)「移行の間の配置」）を写した作業用のクレートを作り、`--base` に渡す。C01 の章は、C02 の章を書く前に `check --task C01 --base <C04 の後のクレート>` で確かめ、全体は `check --base <C04 の後のクレート>` で確かめる。U3 の章（10-15・10-16）は `check --task L00 --base <C04 の後のクレート>` で、U4 の章は `check --task D00 --base <C04 の後のクレート>` で確かめる。L00 と D00 は互いに依存しないので、どちらを先に置いても結果が同じになるように `append=` を書く（同じ項目に両方が加えるときも、互いのブロックを参照しない）。すべての章が揃ったので、検査のための仮の章（stub）は使わない。

C02 は C01 が置いたファイルを変えない（[00-03](00-common/00-03-workflow.md)「インターフェースの凍結」）。C01 の `lib.rs` と各 `mod.rs` は、C02 の章が置くモジュールも宣言しておく。`place` は、`mod` の宣言に合わせて中身のないモジュールを作り（いずれかの章がそのモジュールの下にファイルを置くなら `x/mod.rs`、そうでなければ `x.rs`）、C02 はそれをないものとして埋める。

## 作業一覧

難易度と規模の目安は、最小実行版のプランと同じである（難易度 1〜5、規模は小: 500 行未満、中: 500〜1500 行、大: 1500 行超）。担当は、難易度 5 の作業を Opus（Claude Opus 5.5 のサブエージェント）、それ以外を Codex（GPT-6-Luna、推論の度合い max）とする（[ADR 0285](../design/decisions/0285-implementer-assignment-for-first-release.md)）。Opus が実装した作業は GPT-6-Astra がレビューする（レートに余裕がなければ Codex）。依存・難易度・規模は、各作業の文書を書くときに見直した値である。表と作業の文書の冒頭が食い違うときは、作業の文書を正とする。

### 単位をまたぐ作業

| ID | 作業 | 依存する作業 | 難易度 | 規模 | 担当 |
|---|---|---|---|---|---|
| [C00](20-tasks/C00-foundation.md) | 土台の更新（lint の設定、`unsafe_code` をヒープのモジュールだけに許す、`scripts/check.sh` と Miri・回収の強制の検査のスクリプト、メモリの管理を切り替える機能の設定） | — | 2 | 小 | Codex |
| [C04](20-tasks/C04-legacy-move.md) | 最小実行版の実装を `crate::legacy` へ移す（[00-01](00-common/00-01-repository-layout.md)「移行の間の配置」の手順。`base` のほかのモジュールと `pipeline.rs` を `src/legacy/` へ移してパスを書き換え、`lib.rs`・`main.rs`・`tests/`・`examples/`・`fuzz/` の参照を改める。振る舞いは変えない） | C00 | 1 | 中 | Codex |
| [C01](20-tasks/C01-stage1-interfaces.md) | U2 第 1 段が使うインターフェースを置く（10-01 の `lib.rs`、共有の 10-07 の全体、10-08・10-09・10-11 のうち第 1 段の分） | C04 | 1 | 大 | Codex |
| [C02](20-tasks/C02-remaining-interfaces.md) | 共有と U1 の残りのインターフェースを置く（10-01〜10-06、10-12〜10-14、10-09〜10-11 のうち第 2 段の分） | C01 | 1 | 大 | Codex |
| [C03](20-tasks/C03-test-rewrite.md) | 最小実行版のゴールデンテスト 197 件を新しい構文へ書き直す。最小実行版の言語の機能だけを使い、構文だけを改める（文字列補間など初回リリース版で加わる機能に置き換えない）。書き直したものは `testdata-next/` に置き、F02 の構文解析器で読めることを確かめるテストを加える。期待する出力は C05 が確かめる（00-03「構文の改めとテストの移行」） | F02, F03 | 3 | 大 | Codex |
| [C05](20-tasks/C05-test-switchover.md) | テストと CLI の切り替え: C03 が書き直したテストを `testdata/` に移して C10 の実行器で走らせ（二つのメモリの管理と回収の強制、参照インタプリタとの差分）、期待する出力を確かめる。古い構文のテストと、それを走らせる `legacy` の実行器の部分を消す。`main.rs` を初回リリース版の CLI に切り替え、CLI のプロセスのテストとベンチマークのプログラム（`tools/bench/programs/` の `.bnt`）を新しい構文に移す（00-03「構文の改めとテストの移行」） | C03, C10, F14, F16, F18, R03, R04, R08 | 3 | 大 | Codex |
| [C10](20-tasks/C10-golden-runner.md) | 初回リリース版のゴールデンテストの実行器を作る。`legacy` の実行器を写し、初回リリース版のパイプラインで実行し、複数のモジュールと CLI のオプションに広げる（[ADR 0224](../design/decisions/0224-golden-test-format-for-first-release.md)。`test`・`fmt` の方式は U4）。`legacy` の実行器は、古い構文のテストとともに C05 が消す | F18, F13, F14, C03 | 3 | 中 | Codex |
| [C11](20-tasks/C11-golden-frontend.md) | ゴールデンテスト: フロントエンド（構文、モジュール、レコード、型クラス、エフェクトの型付け、診断） | C10, F18, R34, R35, R37 | 2 | 大 | Codex |
| [C12](20-tasks/C12-golden-runtime.md) | ゴールデンテスト: ランタイム（ハンドラ、`Lazy`、`Reference`、タスク、リソース、出力、IO の方式） | C10, R29, R23 | 2 | 大 | Codex |
| [C13](20-tasks/C13-spec-examples.md) | 言語仕様の例と付録 08-04 の例を処理系で検査する（07-03「言語仕様の例の検査」。`tools/grammar-check` を置き換える） | F18 | 2 | 中 | Codex |
| [C14](20-tasks/C14-random-differential.md) | 差分テスト: 型の付くプログラムを無作為に作り、VM と参照インタプリタで比べる（ADR 0213） | F14, R29, F18, R34 | 5 | 大 | Opus（Claude） |
| [C15](20-tasks/C15-fuzz.md) | fuzzing の対象を初回リリース版のパイプラインに移して広げる（複数のファイルからなる入力、モジュールの読み込み） | F18 | 3 | 小 | Codex |
| [C16](20-tasks/C16-bench.md) | ベンチマークの更新（07-02 の初回リリース版の項目。初回リリース版の CLI で動かす道具と、追加のプログラム trait・handler・tasks・cycle・listget。U3 を要する map・http は含めない。本測定は [90-after-completion.md](90-after-completion.md) で行う） | R12, R23, R29, R34, R36 | 2 | 中 | Codex |
| [C17](20-tasks/C17-spec-coverage.md) | 仕様の網羅の道具の更新 | C11, C12 | 1 | 小 | Codex |
| [C18](20-tasks/C18-legacy-removal.md) | 移行の締め: `src/legacy/` を消し、テスト・例・fuzzing・測定の道具に残る `legacy` の参照を初回リリース版のモジュールに移す。`lib.rs` の `legacy` の宣言と `dead_code` の許可を外す。最小実行版の文書だけを確かめるテスト（`tests/language_reference.rs`）は消す。残っている `todo!()` の仮置きのファイルと、受け持つ未了の作業を完了の報告に挙げる（00-01「移行の間の配置」、00-02「`todo!()` の仮置き」） | C05, C13 | 2 | 中 | Codex |

### U1 フロントエンドの拡張

| ID | 作業 | 依存する作業 | 難易度 | 規模 | 担当 |
|---|---|---|---|---|---|
| [F01](20-tasks/F01-lexer.md) | 字句: 追加するキーワードと記号（`bind`・`shadow`・`data`・`match`・`<-`・`@`）、`Decimal` のリテラル、複数行の文字列と raw 文字列、文字列補間の字句、ドキュメントコメント、シェバンの行 | C02 | 4 | 大 | Codex |
| [F02](20-tasks/F02-parser-core.md) | 構文解析 1: 最小実行版の構文の全体の書き直し（波括弧のブロックから、キーワードで始めて `end` で閉じるブロックへ。`function`・`lambda`・`if … then`・`->`、`bind`・`shadow`、`data`、`match … with case`、演算子 `=`・`<>`・`and`・`or`・`not`・`div`・`mod`）と、他の言語の書き方（最小実行版の書き方を含む）への診断 | F01 | 4 | 大 | Codex |
| [F03](20-tasks/F03-parser-modules-records.md) | 構文解析 2: モジュールと import・`public`、レコード、型の別名、定数、属性、ドキュメントコメント | F02 | 3 | 中 | Codex |
| [F04](20-tasks/F04-parser-traits-effects.md) | 構文解析 3: 型クラスと実装、エフェクトの宣言と `handle`・`resume`、`with`、`lazy`、`try`、文字列補間、パターンの拡張、組のパターン、リストの展開 | F02 | 4 | 大 | Codex |
| [F05](20-tasks/F05-module-loading.md) | モジュールの読み込み: 根のディレクトリの下の探索、依存グラフ、循環する import、標準ライブラリのソースをモジュールとして持つこと（02-04） | F03, F04 | 4 | 中 | Codex |
| [F06](20-tasks/F06-resolver.md) | 名前解決の拡張: モジュールの表、import、公開、prelude と `Benitoite` の名前空間、エフェクト・型クラス・実装の名前、`bind` と `shadow` の規則 | F04, F05, R08 | 4 | 大 | Codex |
| [F07](20-tasks/F07-typeck-records-constants.md) | 型検査 1: レコードとフィールドを読む関数、型の別名、定数の型と評価、`Byte`・`Decimal`・ビット演算 | F06, R08 | 4 | 大 | Codex |
| [F08](20-tasks/F08-typeck-traits.md) | 型検査 2: 型クラス（上位の型クラス、実装の検査、一貫性、辞書の解決、組み込みの制約 `equality`・`key`） | F07 | 5 | 大 | Opus（Claude） |
| [F09](20-tasks/F09-typeck-effects.md) | 型検査 3: 組み込みの細かいエフェクト、利用者が定義するエフェクトとハンドラ、`resume` を書ける位置、`lazy`、可変状態、`with`、`try` | F07 | 5 | 大 | Opus（Claude） |
| [F10](20-tasks/F10-typeck-patterns.md) | 型検査 4: パターンの拡張（ガード、選択肢、範囲、リスト、必ず照合するパターン）と網羅性 | F07 | 4 | 中 | Codex |
| [F11](20-tasks/F11-desugar.md) | 脱糖の拡張: 辞書の引数、レコード、`try`、`lazy`、`with`、`handle`、文字列補間、リストの展開、定数 | F07, F08, F09, F10, F13 | 4 | 大 | Codex |
| [F12](20-tasks/F12-decision-tree.md) | 判定の木: パターンの拡張（[ADR 0159](../design/decisions/0159-pattern-extensions-in-decision-trees.md)） | C02 | 4 | 大 | Codex |
| [F13](20-tasks/F13-core-check.md) | コア IR の検査器の拡張（コア計算の初回リリース版の型付け規則） | C02, R08 | 4 | 中 | Codex |
| [F14](20-tasks/F14-refinterp.md) | 参照インタプリタの評価: 初回リリース版のコア IR（継続は枠を写して保存、`Lazy`、`Reference`、`with`）。値と組み込みの関数の呼び出しは R10 のものを使う | R10, C02, R08, F11 | 4 | 大 | Codex |
| [F15](20-tasks/F15-codegen.md) | コード生成の拡張: レコード、辞書とメソッドの呼び出し、`handle`・`resume`・`drop`、`FORCE`・`UPDATE`、解放の枠、セルの操作、タスクの起動、定数の初期化 | F11, F12, R05, R09 | 5 | 大 | Opus（Claude） |
| [F16](20-tasks/F16-diagnostics.md) | 診断の拡張: `help:` の修正案の拡大（[ADR 0035](../design/decisions/0035-help-suggestions-without-rewriting.md)）、追加の診断コード、警告（`@deprecated` など） | F06 | 3 | 中 | Codex |
| [F17](20-tasks/F17-regex-literal-check.md) | OPEN-062 R08: 正規表現のリテラルを検査の時点で確かめる（U3 の `Regex` と調整） | F07, F08, F09, F10, L22 | 2 | 小 | Codex |
| [F18](20-tasks/F18-pipeline-cli.md) | パイプラインと CLI: モジュール、ディレクトリを指定した実行、シェバン（`run`・`check`）。`runtime::run` の最初の形（そのときある VM の実行の関数を使う） | F11, F15, F16, R09, R38 | 3 | 中 | Codex |

### U2 値の表現とランタイムの作り直し

| ID | 作業 | 段 | 依存する作業 | 難易度 | 規模 | 担当 |
|---|---|---|---|---|---|---|
| [R01](20-tasks/R01-allocator.md) | 確保器と対象の頭（`unsafe` をヒープのモジュールに閉じ込める） | 1 | C01 | 5 | 大 | Opus（Claude） |
| [R02](20-tasks/R02-no-gc-region.md) | 回収しない区間の型と根の保存領域（`Value<'epoch>`・`NoGcCtx<'epoch>`、ヒープの取り違えの防止） | 1 | R01 | 5 | 中 | Opus（Claude） |
| [R03](20-tasks/R03-mark-sweep.md) | マーク・スイープ: 安全点での回収、回収の閾値、戻りの連鎖と後始末の回収の位置 | 1 | R02 | 4 | 中 | Codex |
| [R04](20-tasks/R04-refcount.md) | 改良した参照カウント: 最後の使用での移動、どの `Slot` からも指されない対象のその場での再利用（命令 `CONR` が使う口 `reuse_ctor`。[ADR 0280](../design/decisions/0280-reuse-by-dedicated-construct-instruction.md)）、ADR 0239 の循環の回収 | 1 | R02, R06 | 5 | 大 | Opus（Claude） |
| [R05](20-tasks/R05-liveness-and-asm.md) | コード生成が渡す生存の情報（最後の使用、使わなくなったレジスタ）。二つの方式で共通に使う。テスト用のバイトコードの組み立て（`bytecode::asm`。命令列と原型とコンパイル済みプログラムを手で組み立てる。R09・R11・R13 のテストが使う。10-07「第 1 段で実行するプログラム」） | 1 | C01 | 4 | 中 | Codex |
| [R06](20-tasks/R06-values-and-lists.md) | 16 バイトの値と対象の種類、`Reference` のセルの対象（ヒープの単位） | 1 | R02 | 3 | 中 | Codex |
| [R07](20-tasks/R07-typed-builtins.md) | 組み込みの関数の型付きの形（権限ごとの文脈、応答、引数の読み出し、大きさを確かめる構築） | 1 | R06 | 4 | 中 | Codex |
| [R08](20-tasks/R08-builtin-table.md) | 既存の組み込みの関数を型付きの形へ移す（数値、文字列、リスト、演算子。最小実行版の IO の関数は `Console.writeLine` など 03-07 の名前に改めて移し、第 1 段の `IoServices` の一時的な実装を書く。IO の関数は非公式のモジュールの関数として始まる。[ADR 0286](../design/decisions/0286-unofficial-modules-imported-under-unofficial.md)）。組み込みの関数の表の全体（[10-12](10-interfaces/10-12-builtin-table.md)。後の作業が本体を書く項目は仮の本体で宣言する）と、表を引く関数 | 1 | R07, C02 | 2 | 大 | Codex |
| [R09](20-tasks/R09-vm-core.md) | VM の核の作り直し: 区画、呼び出しの枠と包む枠、振り分けのループの局所の状態（`CONR` によるその場での再利用を含む）、予算と要求の知らせ。panic 境界の中身を写す（`runtime::panic`）。テストは、R05 の組み立てで作ったバイトコードのプログラムで行う | 1 | R06, R05, R07, R08 | 5 | 大 | Opus（Claude） |
| [R10](20-tasks/R10-refinterp-values.md) | 参照インタプリタの `Rc` による値の型と、組み込みの関数を呼ぶときのヒープの値との変換（[ADR 0276](../design/decisions/0276-reference-interpreter-shares-builtin-bodies.md)） | 1 | R06, R07 | 3 | 中 | Codex |
| [R11](20-tasks/R11-heap-verification.md) | ヒープの確かめ方: コンパイルの失敗のテスト、確保の世代の検査、毒、到達可能性を独立に計算して比べるテスト、対象ごとに確保する構成、Miri。組み立てたバイトコードのプログラムを、二つのメモリの管理と回収の強制で VM に通すテスト（参照カウントで `CONR` の再利用が起きることの確かめを含む） | 1 | R03, R04, R09 | 4 | 中 | Codex |
| [R12](20-tasks/R12-stage1-measurement.md) | 第 1 段の測定: C05 が新しい構文へ移したベンチマークと追加のワークロードを、初回リリース版の CLI で測る。比べる構成、閾値の係数 k、暫定に採る方式の記録 | 1 | R11, C05 | 3 | 中 | Codex |
| [R13](20-tasks/R13-overlapping-windows.md) | 窓を重ねる形の比較（[OPEN-063](../design/open-issues.md#open-063)） | 1 | R09 | 3 | 小 | Codex |
| [R14](20-tasks/R14-stage1-wrap-up.md) | 第 1 段の締め: 暫定に採らなかった方式をリビジョンとして残し、本番のコードから外す | 1 | R12 | 2 | 小 | Codex |
| [R20](20-tasks/R20-handlers-and-continuations.md) | ハンドラと一度だけ再開できる継続（区画の移動、引き継いだハンドラ）。`RunState` のスケジューラとリソースの表の欄、`handle`・`drop` の枠の戻り | 2 | R14, C02 | 5 | 大 | Opus（Claude） |
| [R21](20-tasks/R21-unwinding-and-stop.md) | 枠を降ろす処理（原因と枠の種類の表）と止める手順の辿り | 2 | R20 | 5 | 中 | Opus（Claude） |
| [R22](20-tasks/R22-lazy.md) | `Lazy` の対象と `LAZY`・`FORCE`、`update` の枠 | 2 | R21 | 3 | 中 | Codex |
| [R23](20-tasks/R23-reference-cells.md) | `Reference` の VM への組み込み（版の番号によるやり直し、命令 `UPDATE`）、`Reference.new`・`get`・`set` の本体 | 2 | R21 | 3 | 小 | Codex |
| [R24](20-tasks/R24-resources.md) | リソースの表と解放の枠、リソースの状態 | 2 | R21 | 4 | 中 | Codex |
| [R25](20-tasks/R25-tasks-and-scheduler.md) | タスクとスケジューラ: タスクの状態、取り消し、`TaskGroup`、`handle` との対応、行き詰まりの判定、順序を与えるスケジューラと仮想の時間、テスト用の筋書き（`sched::testing`）。`Task`・`TaskGroup` の七つの組み込みの関数の本体 | 2 | R24, R22, R23 | 5 | 大 | Opus（Claude） |
| [R26](20-tasks/R26-dispatch-queue-and-io-executor.md) | 送り出しの列と IO 実行器: 二つの方式、イベントループ、作業用のスレッド、操作の記録、完了の処理の順序。第 1 段の実行の関数を使う箇所（`runtime::run`）を移してから消す | 2 | R25 | 5 | 大 | Opus（Claude） |
| [R27](20-tasks/R27-output-writers.md) | 出力: 書き出し用のスレッド、転送の時点、容量の待ち | 2 | R26 | 4 | 中 | Codex |
| [R28](20-tasks/R28-interrupt-and-stop-procedure.md) | 中断の要求と、ランタイムの止める手順 | 2 | R26 | 4 | 中 | Codex |
| [R29](20-tasks/R29-runtime-builtins.md) | ランタイムに結び付いた残りの組み込みの関数 13 項目（`Lazy.force`・`Reference.update`、時間の待ち（`Clock.sleep`・`Clock.monotonicMilliseconds`）、テストに要る最小限の IO（`Console.readLine`・`Console.readAll`、`File.writeText`・`File.appendText`・`File.openReader`・`File.readLine`・`File.closeReader`、`Process.exit`）、`IOError.kind`。[ADR 0273](../design/decisions/0273-u2-u3-boundary-for-runtime-builtins.md)、[10-12](10-interfaces/10-12-builtin-table.md)「作業ごとの項目の数」。`Reference.new`・`get`・`set` は R23、`Task`・`TaskGroup` の七つは R25。`Console`・`File`・`Process`・`Clock` の関数は非公式のモジュールの関数として始まる。ADR 0286） | 2 | R26, R27 | 3 | 中 | Codex |
| [R30](20-tasks/R30-open-062-reproduction.md) | OPEN-062 の再現テスト（R01〜R05、R13。R14 と R04 の HTTP の分は U3 の L33） | 2 | R29 | 3 | 中 | Codex |
| [R31](20-tasks/R31-io-mode-and-interrupt-tests.md) | IO の方式のテストと、別のプロセスでの中断の要求のテスト | 2 | R28, R29 | 3 | 中 | Codex |
| [R32](20-tasks/R32-verifier-evaluation.md) | 検証器による範囲の確かめの省略の評価（[OPEN-064](../design/open-issues.md#open-064)） | 3 | R14 | 4 | 中 | Codex |
| [R33](20-tasks/R33-memory-management-remeasure.md) | メモリの管理の確定のための測り直し（ハンドラ・タスク・永続コレクションの後。C16 が作った handler・tasks・cycle で測る。HTTP と map の分は U3 の後に測り、OPEN-036 の決着はそれを待つ。[OPEN-036](../design/open-issues.md#open-036)） | 3 | R30, R36, R37, C16 | 3 | 小 | Codex |
| [R34](20-tasks/R34-type-class-instructions.md) | 型クラスの命令の VM の処理（`GETDICT`・`DICT`・`SUPER`・`METHOD`・`TAILMETHOD`、辞書の定数の `LOADK`。10-07「命令の表」） | 2 | R09, C02 | 3 | 中 | Codex |
| [R35](20-tasks/R35-decimal-and-byte.md) | `Decimal` の対象と、`Decimal`・`Byte` の算術と比較の命令、`Decimal` の定数の `LOADK`（算術そのものは F07 が `base::decimal` に自作する。[ADR 0275](../design/decisions/0275-self-made-decimal-arithmetic.md)） | 2 | R08, R09, C02, F07 | 2 | 小 | Codex |
| [R36](20-tasks/R36-persistent-vector.md) | `List` を永続ベクタ（RRB 木。03-06「List の内部の表現」、[ADR 0104](../design/decisions/0104-list-as-persistent-vector.md)）に移す。`runtime::list` のシグネチャは変えない。第 1 段の比較に混ぜない（ADR 0268 の決定 4） | 2 | R14 | 4 | 大 | Codex |
| [R37](20-tasks/R37-map-and-set.md) | `Map` と `Set` の重みで平衡させる二分木（`runtime::map`、構造の等しさ、`Map`・`Set` の定数の `LOADK`。02-08「値の表現」、[ADR 0103](../design/decisions/0103-map-and-set-ordered-by-key.md)）。組み込みの関数は、定数式に書ける `Map.empty`・`Map.fromList`・`Set.empty`・`Set.fromList` と、その値をテストで確かめる `Map.toList`・`Set.toList` の六つだけを書く（10-12）。残りは U3 | 2 | R08, R09, C02, R35, F07 | 4 | 大 | Codex |
| [R38](20-tasks/R38-runtime-error-reports.md) | 実行時エラーの報告（`runtime::report`。呼び出しの履歴、タスクの起動の履歴、行き詰まりの記録、解放の失敗。02-08「実行時エラーの情報の記録」） | 2 | R09, C02 | 3 | 中 | Codex |

作業の数は、単位をまたぐ作業が 15、U1 が 18、U2 が 33（第 1 段 14、第 2 段以降 19）である。第 1 段の ID は R01〜R14 を使い、R15〜R19 は空けておく。

### U3 標準ライブラリ

本節の作業の文書とインターフェースの章（10-15・10-16）は、後述の「U3・U4 で決めたこと」に従って書いた（2026-09-30）。依存・難易度・規模は、作業の文書を書くときに見直した値である。表と作業の文書の冒頭が食い違うときは、作業の文書を正とする。担当は U1・U2 と同じく [ADR 0285](../design/decisions/0285-implementer-assignment-for-first-release.md) の規則（難易度 5 は Opus、ほかは Codex）で決めた。

U3 は、[標準ライブラリ](../design/03-interop/03-06-stdlib.md)・[IO のモジュール](../design/03-interop/03-07-io-modules.md)・[テキストとデータの処理](../design/03-interop/03-08-text-and-data.md)・[ネットワークのモジュール](../design/03-interop/03-09-network.md)が定める関数のうち、U1・U2（[10-12](10-interfaces/10-12-builtin-table.md) の 164 項目と [10-14](10-interfaces/10-14-prelude-and-stdlib-sources.md) のソース）が作らないものを作る。モジュールごとの関数の数は次のとおりである。「設計書」の数は、各章の関数の表の関数の数（一つの行に複数の名前を挙げたものは名前ごとに数える）である。

| 区分 | モジュール | 設計書 | U1・U2 | U3 | 実装の方法（[03-01](../design/03-interop/03-01-library-structure.md)「実装の方法」） |
|---|---|---|---|---|---|
| prelude | `Character` | 12 | 5 | 7（Unicode の性質による分類と、大文字・小文字の変換） | 組み込み（Rust の標準ライブラリ） |
| 〃 | `String` | 22（01-04 の位置の関数 5 を含む） | 18 | 4（`toUppercase`・`toLowercase`・`toUTF8`・`fromUTF8`） | 組み込み |
| 〃 | `Map` | 14 | 3 | 11（組み込み 7、ソース 4） | 組み込み（R37 の `runtime::map`）とソース |
| 〃 | `Set` | 14 | 3 | 11（組み込み 7、ソース 4） | 同上 |
| 〃 | `Bytes`・`ByteOrder` | 16 と型 `ByteOrder` | 0 | 16 | 組み込み（16 進と 2 進の変換は自作） |
| 〃 | `NetworkError`・`NetworkErrorKind` | 2 と型 `NetworkErrorKind`（[01-09](../design/01-spec/01-09-errors.md)） | 0 | 2 | 組み込み |
| 〃 | `Trait` の実装 | — | `Map`・`Set` 以外 | `Map`・`Set` の `Show`・`Semigroup`・`Monoid` | ソース |
| IO | `IO.Console` | 8 | 6 | 2（`readAllLines`・`readAllBytes`） | 組み込み（Rust の標準ライブラリ） |
| 〃 | `IO.File` | 26 | 6 | 20（ファイルとディレクトリの操作 14、`Reader`・`Writer` のリソースの関数 6） | 同上 |
| 〃 | `IO.Process` | 9 | 2 | 7（環境変数・作業ディレクトリ・`scriptDirectory`・`command`、外部コマンドの起動 `run`・`runAttached`・`shell`） | 同上 |
| 〃 | `IO.Clock` | 4 | 2 | 2（`now`・`localOffsetMinutes`） | 同上と `jiff` |
| 〃 | `IO.Random` | 9 | 0 | 9 | 自作の生成器（SplitMix64・xoshiro256**。[ADR 0172](../design/decisions/0172-random-conversion-procedure.md)）、種は `getrandom` |
| テキストとデータ | `Path` | 10 | 0 | 10 | Rust の標準ライブラリ |
| 〃 | `Json` | 11 | 0 | 11 | `serde_json` とソース |
| 〃 | `Regex` | 13 | 0 | 13 | `regex` とソース（`replaceAllWith` など関数を受け取るもの） |
| 〃 | `Csv` | 5 | 0 | 5 | `csv-core` |
| 〃 | `Time` | 11 | 0 | 11 | `jiff` |
| 〃 | `Encoding` | 4 | 0 | 4 | `base64` |
| 〃 | `Hash` | 1 | 0 | 1 | `sha2` |
| ネットワーク | `Network.Http` | 16（サーバ 8、応答と要求の関数 5、クライアント 3） | 0 | 16 | サーバは `httparse` と `mio` の上の自作の接続の層とソース、クライアントは `ureq`・`rustls`・`rustls-graviola`・`rustls-platform-verifier`（[ADR 0143](../design/decisions/0143-http-and-tls-crates.md)） |

U3 が作る関数は、合わせて 162 である（prelude 51、IO 40、テキストとデータ 55、ネットワーク 16）。prelude の 51 は標準のモジュールの関数、ほかの 111 は非公式のモジュールの関数である。表の「IO」「テキストとデータ」「ネットワーク」の区分のモジュールは、スクリプトから `import Benitoite.Unofficial.IO.File`・`import Benitoite.Unofficial.Json`・`import Benitoite.Unofficial.Network.Http` の形で取り込む。表・10-15・10-16・10-12 の名前は、標準に加えた後の名前（`IO.File`）で書く（後述の「U3・U4 で決めたこと」の 1、[ADR 0286](../design/decisions/0286-unofficial-modules-imported-under-unofficial.md)）。prelude の `Assert` の四つの操作は、テストの実行器と一体なので U4 が作る（10-14「モジュールの一覧」）。

言語仕様のうち、標準ライブラリの振る舞いを規範として定めるのは次の箇所であり、U3 の作業はこれらも読む。[エフェクト](../design/01-spec/01-07-effects.md)の組み込みのエフェクト（`Random.Generate`、`Process.Run` とシェルによる実行、`Http.Listen`・`Http.Connect`）、[エラー処理](../design/01-spec/01-09-errors.md)の `IOErrorKind`・`NetworkErrorKind`、[リソース管理](../design/01-spec/01-10-resources.md)のリソースの型（`File.Writer`・`Http.Listener`・`Http.Exchange`）と `Http.Exchange` の解放の失敗、[並行処理](../design/01-spec/01-11-concurrency.md)の、`Http.serve` が起動するタスクと引き継いだハンドラである。

テストは、[処理系のテスト戦略](../design/07-quality/07-03-compiler-testing.md)に従う。組み込みの関数ごとの単体テスト（差分テストでは確かめられないので、項目ごとに書く。[ADR 0276](../design/decisions/0276-reference-interpreter-shares-builtin-bodies.md) の決定 4）、ゴールデンテストの `stdlib`・`io`・`network` の区分、同じスクリプトの中のループバックの通信による HTTP のテスト（[ADR 0222](../design/decisions/0222-http-tests-over-loopback.md)）、`Map`・`Set` の操作の列のモデルとの比較である。

| ID | 作業 | 依存する作業 | 難易度 | 規模 | 担当 |
|---|---|---|---|---|---|
| [L00](20-tasks/L00-u3-interfaces.md) | U3 のインターフェースを置く（10-15・10-16）。R08 と同じく、10-15 のすべてのソースを置き、表の新しい 24 の部分の 136 の項目を仮の本体で宣言する。モジュールは `append=` の見出しで 10-14 の `STDLIB` の末尾に加え、非公式のモジュールは `unofficial` を真にする。10-12 の照合のテスト（F06）が U3 のソースを含めて通り、U3 のソースが名前解決と型検査を通ることを確かめる。10-16 の口の既定の実装の上書きと、構造体に欄を加えた箇所の既定の値 | F18, R29, R37 | 2 | 大 | Codex |
| [L01](20-tasks/L01-unicode-functions.md) | `Character`・`String` の Unicode の関数（9） | L00 | 2 | 小 | Codex |
| [L02](20-tasks/L02-map-and-set-functions.md) | `Map`・`Set` の残りの関数（組み込み 14、ソース 8）と、`Trait` の `Map`・`Set` の実装。操作の列のモデルとの比較を広げる | L00, R37 | 3 | 中 | Codex |
| [L03](20-tasks/L03-bytes.md) | `Bytes`・`ByteOrder`、`String.toUTF8`・`fromUTF8`（18） | L00, R35 | 3 | 中 | Codex |
| [L10](20-tasks/L10-console-clock-process.md) | `Console`・`Clock`・`Process` の小さな関数（8。`Console.readAllLines`・`readAllBytes`、`Clock.now`・`localOffsetMinutes`、`Process.scriptDirectory`・`environmentVariable`・`workingDirectory`・`command`） | L00, L03, L24, R29 | 2 | 小 | Codex |
| [L11](20-tasks/L11-file-operations.md) | `File` のファイルとディレクトリの操作（14。`readBytes`・`readLines`・`exists`・`info`・`listDirectory`・`walk`・`canonicalize`・`writeBytes`・`appendBytes`・`createDirectory`・`remove`・`removeTree`・`rename`、ソースの `copy`）と、03-07「IOErrorKind と関数の対応」 | L00, L03, R29 | 3 | 中 | Codex |
| [L12](20-tasks/L12-file-resources.md) | `File` のリソースの関数（6。`readChunk`、`File.Writer` の `openWriter`・`write`・`writeLine`・`writeChunk`・`closeWriter`） | L11, R24 | 3 | 中 | Codex |
| [L13](20-tasks/L13-external-commands.md) | 外部コマンドの起動（`Process.run`・`runAttached`・`shell`。シェルを通さない起動、`/bin/sh -c`、シグナルで終わったときの終了状態、`runAttached` の標準入出力のつなぎ先。取り消しと中断の要求では子プロセスを止めない（02-09「タスクの待ちと取り消し」。後述の「U3 の作業の文書で見つかった点」の 4）） | L10, R26, R27, R28 | 4 | 中 | Codex |
| [L14](20-tasks/L14-random.md) | `Random`（9。自作の生成器と範囲の変換の手順、隠れた生成器と OS の乱数の種） | L00, R26 | 2 | 小 | Codex |
| [L20](20-tasks/L20-path.md) | `Path`（10） | L00 | 2 | 小 | Codex |
| [L21](20-tasks/L21-json.md) | `Json`（11。値の型、解析と誤りの位置、文字列化） | L02 | 3 | 中 | Codex |
| [L22](20-tasks/L22-regex.md) | `Regex`（13）。F17 が呼ぶ、正規表現の源を実行時の `Regex.compile` と同じ設定で組み立てて成否と理由を返す純粋な関数を置く | L00 | 3 | 中 | Codex |
| [L23](20-tasks/L23-csv.md) | `Csv`（5） | L00 | 2 | 小 | Codex |
| [L24](20-tasks/L24-time.md) | `Time`（11。`Instant`・`DateTime`、ISO 8601、書式） | L00 | 3 | 中 | Codex |
| [L25](20-tasks/L25-encoding-and-hash.md) | `Encoding` と `Hash`（5） | L03 | 1 | 小 | Codex |
| [L30](20-tasks/L30-http-server.md) | HTTP のサーバの接続の層: `mio` のイベントループの上の HTTP/1.1（`httparse`）、`Http.listen`・`listenerPort`・`accept`・`requestOf`・`respond`・`closeListener`・`closeExchange`、`Http.Exchange` の解放の扱い（ADR 0149）、要求の本体の上限と状態コード 413・400、受け付けの失敗の分類とやり直し（ADR 0170）、`NetworkError.kind`・`message` | L03, R24, R26, R27, R28 | 5 | 大 | Opus（Claude） |
| [L31](20-tasks/L31-http-serve-and-helpers.md) | `Http.serve`（ソース。受け付けた要求ごとにタスクを起動する）と、応答を作る関数・要求を調べる関数（5。組み込みは `pathSegments` だけ） | L30, L21, R25 | 3 | 中 | Codex |
| [L32](20-tasks/L32-http-client.md) | HTTP のクライアント（`Http.get`・`clientRequest`・`send`。作業用のスレッドでの `ureq`、TLS、証明書の検証、リダイレクト、時間切れ） | L30, R26 | 4 | 中 | Codex |
| [L33](20-tasks/L33-network-tests.md) | ネットワークのテスト: `network` の区分のゴールデンテスト、テスト用のハンドラ表による失敗の注入（Rust のテストから `CliEnv::parts` で与える。ADR 0287）、OPEN-062 R14 の再現テスト、R30 が U3 の後に回した R04 の HTTP の受け付けの確かめ | L31, L32, C10 | 3 | 中 | Codex |
| [L40](20-tasks/L40-stdlib-golden-tests.md) | 標準ライブラリのゴールデンテスト（`stdlib`・`io` の区分）。ADR 0137 の各モジュールの主な機能を、スクリプトとして確かめる | L01〜L03, L10〜L14, L20〜L25, C10 | 2 | 大 | Codex |
| [L41](20-tasks/L41-map-and-http-bench.md) | ベンチマークの追加（07-02 の map と http。C16 が U3 に回した分）。本測定は [90-after-completion.md](90-after-completion.md) で行う | L02, L31, L32, C16 | 2 | 小 | Codex |

U3 の作業の数は 21 である（Opus 1、Codex 20）。F17 が依存する「U3 の `Regex` の作業」は L22 とした（後述の「U3・U4 で決めたこと」の 9）。

#### U3 の作業の文書で見つかった点

10-15・10-16 と U3 の作業の文書を書く途中で、次の点が見つかった（2026-09-30）。1〜3 は、設計者に確かめたうえで、同じ日に設計者が決めた。4〜8 は、設計書の定めに合わせて本プランの側を改めたか、設計書が実装プランに委ねた点を本プランで決めたものである。

| # | 点 | 本プランでの扱い |
|---|---|---|
| 1 | `File.copy` の型は `uses File.Read, File.Write` だが、操作の宣言は `uses` を書けず一つのエフェクトにしか属さない（01-02）ので、操作としてはこの型を与えられない | `File.readBytes` と `File.writeBytes` を呼ぶソースの関数とした。写せる大きさが `Bytes` の上限（2^30 バイト）までになる（10-15「部分と番号」）。設計者がこの扱いと上限を決め、03-07「File」に【方針】として書いた（[ADR 0291](../design/decisions/0291-file-copy-limit-and-http-server-details.md)） |
| 2 | `Http.requestOf` は解放した後の `Http.Exchange` にも使える（03-09）ので、要求の内容を接続と別に、実行の終わりまで持つ必要がある。長く動く `Http.serve` では、受け付けた要求の数に比例してメモリが増える | 設計者が、解放した後の `requestOf` を解放したリソースの使用（実行時エラー）とし、要求の内容を解放のときに手放すと決めた。03-09 の規則を改めた（[ADR 0289](../design/decisions/0289-request-of-after-release-is-runtime-error.md)）。10-16「受け付けた要求の保存」と L30 を改めた |
| 3 | HTTP のサーバの細部（一つの接続で一つの要求、chunked の本体、頭の上限と 431、処理系が付けるヘッダ、UTF-8 でない要求を 400 にすること）を 03-09 が定めていない | 10-16「HTTP のサーバの接続の層」の「実装プランで決める値」で決めた。設計者が、理由の句を除いて 03-09「サーバの接続と要求の読み方」に【方針】として載せると決めた（[ADR 0291](../design/decisions/0291-file-copy-limit-and-http-server-details.md)）。UTF-8 でない要求は OPEN-062 の R14 であり、クエリの扱いは R14 の修正の候補と異なる。L33 が再現テストを書き、その結果を見て改めるかを決める |
| 4 | 骨子の L13 の「中断の要求と取り消しで子プロセスを止めること」は、02-09「タスクの待ちと取り消し」の「起動した外部コマンドを終わらせることもしない」と食い違う | 02-09 に従い、子プロセスを止めない。上の表の L13 の行を改めた |
| 5 | 10-10 の `IoRuntime::random_state` が `u64` であり、xoshiro256** の 256 ビットの状態を持てない | 10-10 を `[u64; 4]` に改めた（10-16「隠れた乱数の生成器」）。種を入れるのは L14、`IoView::random_u64` は R26 が xoshiro256** の一歩として書く |
| 6 | U2 の口（`IoServices`・`StateServices`・`RuntimeParts`・`IoRuntime`・`ResourceTable`）では、HTTP のサーバ、`Http.requestOf`、ネットワークの失敗の注入、`Process.runAttached` のつなぎ先を書けない | 10-16 で、既定の実装を持つトレイトの関数と、既定の値を持つ構造体の欄を `append=` で加えた。構造体の欄を作る箇所に既定の値を加えるのは L00 である |
| 7 | `Benitoite.IO.Clock` はエフェクト `Time` を宣言するので、`Benitoite.Time` を同じ名前で取り込むと E0305 になる | `import Benitoite.Unofficial.Time as TimeValue` と別の名前で取り込む（10-15「`IO.Clock`」）。利用者から見える型は `Time.Instant` のままである |
| 8 | `Http.listen` にテスト用のハンドラ表で `ConnectionRefused` などを当てると、03-09 の「返しうる種類」の表にない組み合わせになる | テストが指定したときだけ起きるので許した（10-16「テスト用のハンドラ表のネットワークの失敗」） |

作業の文書の中で【要検証】としたもの: 10-16 の三つ（`ureq` と `rustls-graviola` と `rustls-platform-verifier` の組み合わせ、`graviola` のビルド先、`jiff` の OS の時差。README の「U3・U4 で決めたこと」の 3）、`csv-core` のライセンスの表示を `cargo deny` が読めるか（L23）、`serde_json` の誤りの列の数え方（L21）。

### U4 ツール

U4 は、[CLI](../design/06-tooling/06-01-cli.md) の `test`・`fmt`・`skill` と `--licenses`（[ADR 0206](../design/decisions/0206-test-command-line-and-exit-status.md)〜[ADR 0208](../design/decisions/0208-test-report-destination.md)）、[フォーマッタ](../design/06-tooling/06-03-formatter.md)、[利用者プログラムのテスト](../design/06-tooling/06-04-test-runner.md)、[Agent Skills 対応](../design/06-tooling/06-06-agent-skills.md)（[ADR 0230](../design/decisions/0230-skill-embedded-and-installed-by-subcommand.md)〜[ADR 0232](../design/decisions/0232-skill-evaluation-with-tasks-and-harnesses.md)）、[配布形態](../design/05-platform/05-01-distribution.md)（[ADR 0233](../design/decisions/0233-distribution-via-github-releases.md)〜[ADR 0235](../design/decisions/0235-third-party-licenses-generated-and-shown-by-option.md)）を作る。CLI の振り分けと入口のシグネチャ（`cli::tools`）は [10-13](10-interfaces/10-13-pipeline-and-cli.md) が凍結済みであり、F18 が置いた仮の中身を U4 が置き換える。予約したサブコマンドの名前（ADR 0209）は F18 の範囲である。LSP（06-02）、パッケージ管理（06-05）、サーバモード（06-07）は初回リリース版に含めない。

ロードマップの初回リリース版の完了条件のうち、`test` と `fmt` の行と、各環境での単一バイナリの実行の行は U4 が受け持つ。受け入れテスト（`testdata/acceptance/`）の対応は 07-03「受け入れ例と仕様の項目の対応」に従う。

| ID | 作業 | 依存する作業 | 難易度 | 規模 | 担当 |
|---|---|---|---|---|---|
| [D00](20-tasks/D00-u4-interfaces.md) | U4 のインターフェースを置く（10-17〜10-19）。`Assert` のソースと、その操作の組み込みの関数の表の部分を加える（prelude のモジュールなので、表の部分がないと名前解決が止まる） | F18 | 1 | 中 | Codex |
| [D01](20-tasks/D01-formatter-roles.md) | フォーマッタ 1: AST を辿って字句の位置ごとの役割の表を作り、字句の間の空白と字下げの規則を当てる（06-03「字句の間の空白」「字下げ」「入力表現」） | D00, F03, F04 | 4 | 大 | Codex |
| [D02](20-tasks/D02-formatter-comments-and-verify.md) | フォーマッタ 2: コメント、空の行、行末と文字、複数行の文字列。整形後の検証（字句とコメントの並びの比較、再解析）。標準ライブラリのソースが正規形であることのテスト | D01 | 3 | 中 | Codex |
| [D03](20-tasks/D03-fmt-command.md) | `fmt` のコマンドライン（`test` と共有するコマンドラインの解釈、ディレクトリの指定、`--check`、一時ファイルと名前の変更による書き換え、書き換えの失敗の診断 E0125、終了状態。ADR 0207・ADR 0247） | D02 | 2 | 小 | Codex |
| [D04](20-tasks/D04-fmt-golden-and-fuzz.md) | ゴールデンテストの `fmt`・`fmt-check` の方式と、`check`・`run` のすべてのゴールデンテストでの冪等性と診断の不変の確認（ADR 0224）。fuzzing にフォーマッタの対象を加える | D03, C10, C15 | 2 | 中 | Codex |
| [D10](20-tasks/D10-test-runner-core.md) | テストの実行器 1: テストの関数を一つの実行として動かす関数（`runtime::run::run_test`）、`Assert.Check` の処理（どのハンドラも処理しなかった操作を VM が送り出しの列に置かずに受け、失敗なら `StopReason::CheckFailed` で止める）、値の書き出し、出力の捕捉と空の標準入力、`Process.exit` と中断の要求（終了状態 130）の扱い | D00, R28, R29 | 4 | 大 | Codex |
| [D11](20-tasks/D11-test-report-and-command.md) | テストの実行器 2: テストの関数の集め方、ファイルごとの検査とテストを順に動かすこと（並行に動かさない）、結果の報告（文章の形と JSON Lines、失敗の詳細。ADR 0252）、`test` のコマンドラインと終了状態（ADR 0206・ADR 0208） | D10, D03 | 3 | 中 | Codex |
| [D12](20-tasks/D12-test-golden.md) | ゴールデンテストの `test` の方式と `test` の区分のテスト | D11, C10 | 2 | 中 | Codex |
| [D20](20-tasks/D20-skill-generation.md) | 同梱の Agent Skill の生成: 処理系のクレートを使う生成の道具（`examples/gen_skill.rs`）で、文法（01-02 の文法の全体）、標準ライブラリのリファレンス（モジュールごとに一つのファイル。ソースの宣言とドキュメントコメント、モジュールの状態と取り込みの名前）、診断コードの説明を生成してリポジトリに置き、実行ファイルに埋め込む。生成物が古くないことを確かめるテスト（ADR 0288） | D00, L00 | 3 | 中 | Codex |
| [D21](20-tasks/D21-skill-handwritten-docs.md) | 手で書く Skill の文書（`SKILL.md`、イディオム集、よくある誤り集、既知の言語との対応表）と、載せたコードの例をゴールデンテストと同じ仕組みで検査すること | D20, D12, L33, L40 | 2 | 中 | Codex |
| [D22](20-tasks/D22-skill-install.md) | `skill install`・`uninstall`（エージェントごとの置き場所、既存のディレクトリの扱い、一時ディレクトリと名前の変更、終了状態） | D20 | 2 | 小 | Codex |
| [D23](20-tasks/D23-skill-evaluation-tools.md) | Skill の評価の道具（`tools/skill-eval/`、スキル `skill-eval`、処理系の起動を数える包みのコマンド、HTTP の課題のサーバ、約 10 の課題と解）。LLM を呼ぶ評価そのものは、設計者の了承を得て [90-after-completion.md](90-after-completion.md) で行う | D21, D22 | 3 | 中 | Codex |
| [D30](20-tasks/D30-third-party-licenses.md) | 第三者のライセンスの表示（cargo-about 0.9.2 による `THIRD_PARTY_LICENSES` の生成と NOTICE の補い、機能 `bundled-licenses` での埋め込み、`--licenses`、リリースのスクリプトを通さないビルドの文）、`LICENSE-MIT`・`LICENSE-APACHE` | D00, L14, L21〜L25, L30, L32 | 2 | 小 | Codex |
| [D31](20-tasks/D31-release-script.md) | リリースのスクリプト `scripts/release.sh`（三つの環境のビルドと試験、任意の確認としての公開の `https` の URL への接続、WSL2 での確かめ（設計者の機械）、アーカイブと `SHA256SUMS`、`rust-toolchain.toml`、配る実行ファイルで受け入れテストを動かす `tests/acceptance_binary.rs`） | D30, D32, D22, D34 | 3 | 中 | オーケストレータと設計者 |
| [D32](20-tasks/D32-open-060-facts.md) | OPEN-060 の事実の確認（Gatekeeper、開発機の上のコンテナと仮想機械、WSL2 への SSH、Skill の置き場所の確かめ直し）。結果を OPEN-060 と 05-01 に記録する。Gatekeeper と WSL2 の試行は設計者の機械で設計者が行う。ネットワークと設計者の機械が要るので、オーケストレータが設計者と行う（ADR 0292） | — | 2 | 小 | オーケストレータと設計者 |
| [D33](20-tasks/D33-user-documents.md) | 利用者向けの文書: `doc/reference/` の英語の言語リファレンスを初回リリース版の範囲に書き直す、導入の手順、`CHANGELOG`、README の著作権と、LLM が生成したことの注記（ADR 0242）、日本語の訳（`doc/ja/`） | D21, D03, D11, D22 | 2 | 大 | Codex |
| [D34](20-tasks/D34-acceptance-tests.md) | 受け入れテスト: ロードマップの初回リリース版の完了条件の各行に `testdata/acceptance/` のテストを対応させ、仕様の網羅の道具が空の行を誤りにする（07-03「受け入れ例と仕様の項目の対応」） | D04, D12, L13, L21, L40 | 2 | 中 | Codex |

U4 の作業の数は 17 である（Codex 15、オーケストレータと設計者 2）。D31・D32 は、ネットワークと設計者の機械での試行を要するので、Codex に割り当てず、オーケストレータが設計者と行う（[ADR 0292](../design/decisions/0292-release-checks-needing-network-by-orchestrator.md)。後述の「U4 の作業の文書で見つかった点」の 2）。

#### U4 の作業の文書で見つかった点

10-17〜10-19 と U4 の作業の文書を書く途中で、次の点が見つかり、設計者が決めた（2026-09-30）。

| # | 点 | 決めたこと |
|---|---|---|
| 1 | 型が分からない値（型パラメータを持つ補助の関数の中の `Assert.equal` など）の書き出しを、06-04 が定めていない | 構成子の値を `<constructor #タグ>` と書く（10-18「確認と値の書き出し」）。初回リリース版はこのままとする |
| 2 | D31・D32 はネットワークと設計者の機械を要し、Codex の `workspace-write` のサンドボックスでは行えない | オーケストレータが設計者と行う（[ADR 0292](../design/decisions/0292-release-checks-needing-network-by-orchestrator.md)、00-03「担当と起動の方法」） |
| 3 | 作業の文書で書いた文言（`fmt --check` の行 `would reformat <表示名>`、`test` の結果の報告の文、`SKILL.md` の前付けの版の型板 `{{benitoite-version}}`、`doc/reference/` と `doc/ja/` の文書のファイルの名前） | 書いたとおりとする（10-17・10-18・10-19、D33） |
| 4 | 処理系の版の番号と、著作権表示の `<設計者の名前>` が決まっていない | 初回リリース版の版は `0.1.0`（[ADR 0090](../design/decisions/0090-version-numbers-and-codenames.md)）。著作権表示は `Copyright (c) 2026 tecogonaz and Benitoite contributors`（[ADR 0290](../design/decisions/0290-copyright-holder-name-and-open-021.md)。OPEN-021 の決着）。D30・D31・D33 と 10-19 を改めた |

## 依存と順序

```text
C00 ─ C04 ─ C01 ─┬─ R01 ─ R02 ─┬─ R03 ──────────┐
                 │             ├─ R04（R06 も）─┴─ R11（R09 も）
                 │             └─ R06 ─ R07 ─ R08（C02 も）
                 ├─ R05 ─ R09（R06・R07・R08 も）   R13（R09 の後）   R10（R06・R07 の後）
                 │
                 └─ C02 ─ F01 ─ F02 ─┬─ F03 ─┬─ F05 ─ F06 ─ F07 ─ F08〜F10 ─ F11 ─ F15 ─ F18 ─┐
                                     ├─ F04 ─┘                                                │
                                     └─ C03（F03 も）─────────────────────────────────────────┴─ C05 ─ R12 ─ R14   （U2 第 1 段の完了）
                    C02 ─ F12, F13     R10 ─ F14     R08 ─ F06, F07, F13, F14     F13 ─ F11     R09 ─ F15     R09・R38 ─ F18
                    C05・C13 ─ C18

                    R14 + C02 ─ R20 ─ R21 ─ R22〜R24 ─ R25 ─ R26 ─ R27〜R29 ─ R30   （U2 第 2 段）
                    R14 + C02 ─ R34、R35（F07 の後）、R36、R37（R35・F07 の後）
                    R09 + C02 ─ R38
                    R12・R23・R29・R34・R36 ─ C16 ─ R33（R30・R36・R37 も）
```

図に描き切れない依存は、作業一覧の「依存する作業」の欄を正とする。C05 は、C03・F18 のほかに C10・F14・F16・R03・R04・R08 を待ち、R12 は C05 のほかに R11 を待つ。R08 は R07 のほかに C02 を待ち（組み込みの関数の表が C02 の型を使う。10-12「置く作業と既存のファイル」）、F18 は F16 を待つ（診断の書き出しの中身を F16 が書く。10-02）。F06・F13・F14 は R08 を待ち（組み込みの関数の表を引く関数と、組み込みの関数の型の中身を R08 が書く）、F07 も R08 を待つ（定数の評価器が `Float` の文字列への変換 `base::prim::float_to_text` を呼ぶ。10-01）。F11 は、脱糖の出力をコア IR の検査器で確かめるので F13 を待ち、F15 は、生成したバイトコードを VM で実行して確かめるので R09 を待つ。C10 は、初回リリース版のパイプラインでゴールデンテストを走らせるので、F18・F13・F14・C03 を待つ。C16 は、追加のベンチマーク（handler・tasks・cycle・trait・listget）を VM で実行するので R23・R29・R34・R36 を待ち、R33 は C16 が作った handler・tasks・cycle のプログラムで測り直すので C16 を待つ。

- 移行: C04 は、ほかのどの作業よりも先に行う（C00 の後）。C04 の後は、最小実行版の CLI とテストは `legacy` で動き、初回リリース版のモジュールは最終的なパスに置かれる。どの取り込みの後も、クレートがコンパイルでき、`scripts/check.sh` が通る（[00-03](00-common/00-03-workflow.md)「確認と取り込み」）。
- すぐに始められる: C01 の後の U2 第 1 段の R01〜R11 と R13（R08 は C02 の後。C02 はインターフェースを置くだけなので C01 の直後に行える）。これらの作業は、R05 が作るテスト用のバイトコードの組み立てで命令列を手で作り、VM と二つのメモリの管理を単体テストで確かめるので、U1 を待たない。
- U2 第 1 段の完了: 第 1 段は、新しい構文へ書き直した最小実行版のテストが初回リリース版のパイプラインで通ったときに完了とする（下の「決めたこと」の 5）。このテストを新しい VM で走らせるには U1 の F18 までの全体が要るので、第 1 段の完了までの道筋は C02 → F01 → F02 → … → F15 → F18 → C05 → R12 → R14 となる。C03 は F03 の後に行い（書き直したテストが `import` を使う）、C05 が F18 の後にテストを走らせる。
- 第 2 段の開始: U2 第 2 段以降の作業のうち、ハンドラ・タスク・IO・出力・リソース・`Lazy` と `Reference` の VM への組み込み・永続ベクタ（R20〜R33、R36）は、第 1 段の測定と締め（R14）の後に始める（ADR 0268 の決定 5）。これらは根の持ち方と確保の負荷を変えるからである。二つのメモリの管理に共通の API だけを使う R34・R35・R37・R38 は、R09 の後に進め、両方式でテストを通す（ADR 0278、下の「決めたこと」の 13）。したがって、R20〜R33 と R36 は U1 が F18 まで揃った後に始まる。
- C01 は共有の 10-07（命令の集合）を含むので、C01 の前に、U1 と第 2 段の命令も含めた命令の集合を書き上げる。
- U1 の起点: C02（共有と U1 のインターフェース）の後の F01。U1 の作業は、最小実行版のテストを壊さない（C05 までは、最小実行版のテストは `legacy` の構文解析器で動く）ので、F02 を単独で取り込める。F02 の後に C03 が書き直したテストは、以後の U1 の作業が構文解析器を変えたときに、読めることを確かめる対象になる。
- U1 と U2 が合う点: R05（生存の情報）と F15（コード生成）はどちらも生存の情報を使う。R10（参照インタプリタの値）の後に F14。R09（VM の核）と R38（実行時エラーの報告）の後に F18。U2 第 2 段（R20 以降）は、共有の章（10-06・10-07）の命令と、F15 のコード生成を前提にテストを書く。統合のテスト（C12・C14）は、F18 と R29 の両方を待つ。フロントエンドのゴールデンテスト（C11）は、`run` のテストのために R34・R35・R37 も待つ。
- 移行の締め: テストと CLI を切り替え（C05）、言語仕様の例の検査を処理系に移した（C13）後に、`legacy` を消す（C18）。

U3・U4 の依存は次のとおりである。図に描き切れない依存は、上の U3・U4 の表の「依存する作業」の欄を正とする。

```text
（U3）
F18・R29・R37 ─ L00 ─┬─ L01、L20、L23、L24、L22 ─ F17
                     ├─ L02（R37 も）─ L21
                     ├─ L03（R35 も）─┬─ L25
                     │                ├─ L10（L24・R29 も）─ L13（R26〜R28 も）
                     │                ├─ L11（R29 も）─ L12（R24 も）
                     │                └─ L30（R24・R26〜R28 も）─┬─ L31（L21・R25 も）─┐
                     │                                           └─ L32（R26 も）──────┴─ L33（C10 も）
                     └─ L14（R26 も）
                    L01〜L03・L10〜L14・L20〜L25・C10 ─ L40      L02・L31・L32・C16 ─ L41

（U4）
F18 ─ D00 ─┬─ D01（F03・F04 も）─ D02 ─ D03 ─ D04（C10・C15 も）
           ├─ D10（R28・R29 も）─ D11（D03 も）─ D12（C10 も）
           ├─ D20（L00 も）─┬─ D21（D12・L33・L40 も）─ D23（D22 も）
           │                └─ D22
           └─ D30（L14・L21〜L25・L30・L32 も）
                    D32 ─ D31（D30・D22・D34 も）      D04・D12・L13・L21・L40 ─ D34      D21・D03・D11・D22 ─ D33
```

- U3 の起点: L00 は、パイプライン（F18）と、U2 が作る組み込みの関数の表と `Map`・`Set` の表現（R29・R37）の後に始める。移行の締め（C18）は待たない。L00 は、R08 と同じく U3 のすべての項目を仮の本体で宣言するので、以後の L の作業は項目の本体を書くだけで、表の番号を変えない（10-12「番号の振り方」）。
- 純粋なモジュールの作業（L01・L02・L20〜L25）は、IO 実行器（R26）を待たない。IO とネットワークの作業（L10〜L14、L30〜L32）は、U2 第 2 段の IO 実行器・出力・止める手順（R26〜R28）とリソース（R24）を待つ。`Clock.now` が `Time.Instant` を返すので、L10 は `Time` の L24 を待つ。
- F17（U1）は L22 を待つ。OPEN-062 の R14 の再現テストは L33 が書く。
- U4 の起点: D00 は F18 の後に始める。フォーマッタ（D01〜D04）は構文だけを使うので、U2 と U3 を待たない。テストの実行器（D10〜D12）は、U2 第 2 段の止める手順・IO 実行器・出力・中断の要求と、テストで使う `Process.exit`・`Console` の関数（R28・R29 とその依存）を待つ。Skill の生成（D20）は、標準ライブラリのすべてのソースとドキュメントコメント（L00）を待つ。
- リリース（D31）は、事実の確認（D32）、ライセンスの表示（D30）、受け入れテスト（D34）を待ち、U3・U4 の最後に行う。U3・U4 を終えた後の測定（map と http、OPEN-036 と OPEN-009 の決着）と Skill の評価は、[90-after-completion.md](90-after-completion.md) の「U3・U4 を終えた後に行うこと」で行う。

## 決めたこと

骨子について、次の点を設計者が確認した（2026-09-30）。10〜12 と 14 は、インターフェースの章を書く途中で設計者が決めた。5 は、その後に設計者が改めた。15・16 は、作業の文書を書く途中で設計者が決めた。17 は、同じ時期にオーケストレータが決め、設計書（02-10）に書き加えた。18 は、実装プランのレビュー（[相談の第 6 回](studies/u2-runtime/consult/06-plan-vm-review.md)・[第 7 回](studies/u2-runtime/consult/07-plan-scheduler-review.md)）で見つかった点について、設計者が決めた。

| # | 事項 | 決めたこと |
|---|---|---|
| 1 | 作業の ID の付け方 | 単位ごとの頭の文字（`C`・`F`・`R`・`L`・`D`）とする（上の「作業の ID」） |
| 2 | 第 1 段の二つのメモリの管理と U1 の作業の並べ方 | Cargo の機能（`gc-mark-sweep`・`gc-refcount`）で切り替え、第 1 段の間は両方を同じ枝に置く。U1 の作業は回収の方式に依存しない API だけを使う。R14 で採らなかった方式を外す（[00-01](00-common/00-01-repository-layout.md)「機能（feature）」） |
| 3 | 共有のインターフェースの凍結の時期 | 第 1 段が使う分（C01）を先に凍結して U2 第 1 段を始め、共有と U1 の残り（C02）はその後に凍結する。C01 は、共有の命令の集合（10-07）を全体で含む（[00-03](00-common/00-03-workflow.md)「インターフェースの凍結」） |
| 4 | 第 1 段の VM が実行する命令 | 共有の章で決める新しい命令の集合のうち、最小実行版の言語の分を実装する。ほかの命令は第 2 段の作業（R20〜R25、U1 の機能に伴う命令は R34・R35）が足す |
| 5 | 構文の改めと既存のテストの移行の時期、U2 第 1 段の完了の条件 | 最小実行版のテストは、F02 の直後に新しい構文へ書き直し（C03）、初回リリース版のパイプライン（F18）が揃ったら初回リリース版の実行器で走らせる（C05）。第 1 段の完了の条件（ADR 0268 の決定 3）の「最小実行版のすべてのテスト」は、この書き直したテストと読む。したがって、第 1 段の測定（R12）と締め（R14）、暫定に採るメモリの管理の方式の判断は、U1 の F18 までと C05 を待つ。それまでの第 1 段の作業は、手で組み立てたバイトコードのプログラムによる単体テストで VM と二つのメモリの管理を確かめる（2026-09-30、設計者の判断。[00-03](00-common/00-03-workflow.md)「構文の改めとテストの移行」）。当初は「F02 と C03 を早くに行い、一度に取り込む」とし、次に 11 に合わせて「最小実行版のフロントエンドと使い捨ての第 1 段のコード生成（R15、`src/legacy/stage1/`）で古い構文のテストを新しい VM に通して第 1 段を完了する」と改めたが、設計者がこれを取り下げ、使い捨ての経路を作らない現在の形にした |
| 6 | U2 と U3 の境目 | ランタイムに結び付いた組み込みの関数（`Task`・`TaskGroup`・`Lazy`・`Reference`・時間の待ち）と、U2 のテストに要る最小限の `Console`・`File` は U2（R23・R25・R29）が作る。ほかは U3。ADR 0253 の単位の範囲を改めるので、[ADR 0273](../design/decisions/0273-u2-u3-boundary-for-runtime-builtins.md) に記録した |
| 7 | 型付きの組み込みの関数の包みの作り方 | `macro_rules!` による宣言のマクロとする（[00-02](00-common/00-02-conventions.md)「組み込みの関数の書き方」） |
| 8 | コンパイルの失敗のテストの道具 | rustdoc の `compile_fail` の例とし、依存を増やさない。ワークスペースの設定で期待どおりに働くかは【要検証】であり、C01 で確かめる（[00-02](00-common/00-02-conventions.md)「テストの規約」） |
| 9 | Rust の版 | 1.98.1 のまま進め、上げる必要が生じたら作業を止めて報告する |
| 10 | `Decimal` の算術に使うクレート | クレートを使わず自作する（2026-09-30、設計者の判断。[ADR 0275](../design/decisions/0275-self-made-decimal-arithmetic.md)）。F07 が 01-04 の規則どおりに書く |
| 11 | 最小実行版の実装からの移し方 | 最初の作業（C04）が最小実行版のモジュールを `crate::legacy` の下へ移し、古い CLI とテストを動かし続ける。初回リリース版のモジュールは最終的なパスに置く。どの時点でもクレートがコンパイルでき、`scripts/check.sh` が通る。新しい経路が揃ったら、移行の締め（C18）で `legacy` を消す（2026-09-30、設計者の判断。上の「最小実行版の実装との関係」、[00-01](00-common/00-01-repository-layout.md)「移行の間の配置」） |
| 12 | 参照インタプリタと組み込みの関数 | 参照インタプリタの値は `Rc` による値の型とし、VM の値・ヒープ・VM から独立させる。組み込みの関数を呼ぶときだけ、引数をヒープの値に変換して VM と同じ組み込みの関数の本体を呼ぶ。組み込みの関数の正しさは単体テストで確かめる（2026-09-30、設計者の判断。[ADR 0276](../design/decisions/0276-reference-interpreter-shares-builtin-bodies.md)） |
| 13 | メモリの管理に触れない第 2 段の作業を先に進めるか | 進める（2026-09-30、設計者の判断。[ADR 0278](../design/decisions/0278-stage-1-completes-on-new-syntax-tests.md)）。R34・R35・R37・R38 は第 1 段の測定（R12）を待たず、R09 の後に進め、両方式でテストを通す。ハンドラ・タスク・IO・出力・リソース・`Lazy` と `Reference`・永続ベクタ（R20〜R33、R36）は R14 の後 |
| 14 | インターフェースの章を書く中で見つかった、設計書に定めのない点 | 次のとおりとし、設計書を改めた（2026-09-30、設計者の判断）。(1) 中断の要求のシグナルの登録に `signal-hook` 0.4.4 と `signal-hook-mio` 0.3.0 を使う。Unix 系の OS だけでよい（[00-02](00-common/00-02-conventions.md)「依存するクレート」、02-09「中断の要求」、ADR 0163 の状態の欄）。(2) `//!` の説明だけからなり宣言を持たないファイルは、空のモジュールとする（01-02「ドキュメントコメント」、02-03）。(3) `@deprecated("")` は E0804 の誤りとする（01-02「属性」、02-10）。(4) `Process.exit` と中断の要求で止めた後の出力の書き出しの失敗の JSON の `kind` は `"runtime"` とする（02-10）。(5) 名前の重なりには、名前空間に入る名前が増えても E0305・E0306 を使う（02-10）。(6) 一つの型クラスの中のメソッドの名前の重なりは E0328 の誤りとする（[ADR 0279](../design/decisions/0279-no-duplicate-method-names-in-trait.md)、01-02・01-06）。(7) 01-03 の名前の重なりの一覧にエフェクトを加えた。(8) 孤立した実装は型検査器（F08）が判定し、コードは E0701 のままとする（02-04、02-05「実装の検査」）。(9) C05 がゴールデンテストの期待する出力で受け入れる違いに、JSON の `helps` のオブジェクト化、`more diagnostics` の行、`--version` の Unicode の版、書き直した文言の型板を加えた（[00-03](00-common/00-03-workflow.md)「構文の改めとテストの移行」） |
| 15 | 参照カウントのその場での再利用を行う箇所 | 命令 `CONR` でだけ行い、ヒープの設定 `HeapConfig::reuse` で無効にできる。命令の並びは設定によらない。マーク・スイープでは `CONR` は `CON` と同じに振る舞う。F15 が `CONR` を置き、R04 が再利用の口を、R09 が命令を書き、参照カウントで再利用が起きることは R11 が確かめる。R12 は再利用の有無の両方を測る（[ADR 0280](../design/decisions/0280-reuse-by-dedicated-construct-instruction.md)、10-07「その場での再利用の命令」） |
| 16 | 凍結する関数の宣言の置き方 | C01・C02 の `place` は、`sig=` の関数を本体が `todo!()` の関数（`todo!()` の仮置き）として置き、そのファイルの先頭に lint の許可を置く。本体を書く作業は、受け持つ関数の `todo!()` を残さず、ファイルに `todo!()` がなくなったら許可を消す（[00-02](00-common/00-02-conventions.md)「`todo!()` の仮置き」） |
| 17 | 標準ライブラリのソースの検査の誤りの報告 | 検査の診断としては書かず、`internal error` として書いて終了状態 3 で終える（02-10「処理系の不具合と処理系の制限の報告」、10-13 の `cli::execute`） |
| 18 | 実装プランのレビューで見つかった、取り消しの時期・行き詰まりの判定・テストの規則 | 次のとおりとし、設計書を改めた（2026-09-30、設計者の判断）。(1) E-DropRel で辿っている途中に届いた取り消しは記録だけにし、辿り終えた時点で、戻りの処理に進まずに取り消しの手順に移る。次の切り替えの位置は待たない（[ADR 0282](../design/decisions/0282-cancellation-timing-during-unwinding-and-requests.md) の決定 1、02-08「取り消し」、10-09、R21・R25）。(2) 取り消しと全体の停止では、外部の操作に移る前の要求を失効させ、組み込みの関数を呼ばない。`serve_request` は世代と今の待ちを確かめる（同 決定 3・4、02-09、10-10、R26・R28）。(3) 行き詰まりの判定で外部の待ちに数えるのは、完了がいずれかのタスクを起こしうるもの（操作の結果、貸したリソースの返却と解放、出力の容量と転送の完了を待つタスクがあるもの）だけとし、配送先を外した操作と、完了を待つタスクのない出力の転送は数えない。取り消したタスクの終わらない標準入力の読み取りが残っても、行き詰まりを報告する（[ADR 0283](../design/decisions/0283-deadlock-counts-only-waits-that-can-wake-tasks.md)、02-08・02-09、10-10 の手順 5、R25〜R27）。(4) 応答を組み立てるだけの `Task`・`TaskGroup` の七つの組み込みの関数は、ADR 0276 の決定 4 の例外として、スクリプトの受け入れテストで確かめる。`Task.withTimeout` の期限の正規化だけを単体テストにする（[ADR 0284](../design/decisions/0284-task-builtins-tested-by-scripts.md)、07-03、10-12、R25） |

次の点は、設計書で決まっているので確かめる対象にしなかった。参照インタプリタは初回リリース版のコア IR まで広げ、タスクを使わないプログラムに限って差分テストを行う（ADR 0213、[中間表現と脱糖](../design/02-impl/02-06-ir-and-lowering.md)の「参照インタプリタの範囲」）。確かめ方は `scripts/check.sh` と別のスクリプトで行い、GitHub Actions は使わない（[処理系のテスト戦略](../design/07-quality/07-03-compiler-testing.md)の「ヒープとランタイムの確かめ方（初回リリース版）」）。作業の担当は難しさの見積もりの後に決める（OPEN-059）。非公式のライブラリの位置付けは、後述の「U3・U4 で決めたこと」の 1 で決めた（[ADR 0286](../design/decisions/0286-unofficial-modules-imported-under-unofficial.md)）。

## U3・U4 で決めたこと

U3・U4 のインターフェースの章と作業の文書を書く前に、次の点を設計者が決めた（2026-09-30）。1 は、骨子が推した案 (c)（名前を最終のままにし、状態で区別する）ではなく、案 (a)（非公式の名前空間）を設計者が選んだ。2〜17 は、骨子が推した案のとおりである。

### 1. 非公式のライブラリと標準ライブラリの関係（OPEN-066）

設計者は、型付きの形（[ADR 0261](../design/decisions/0261-typed-builtin-interface.md)）で書いた関数を、まず非公式のライブラリとして扱い、実装を吟味したものから標準ライブラリに加える方向を示していた（[OPEN-066](../design/open-issues.md#open-066)）。これを次のとおり決め、[ADR 0286](../design/decisions/0286-unofficial-modules-imported-under-unofficial.md) に記録した。設計書は [03-06](../design/03-interop/03-06-stdlib.md)「標準のモジュールと非公式のモジュール（初回リリース版）」、[01-03](../design/01-spec/01-03-names-modules.md)「標準ライブラリの名前空間と prelude（初回リリース版）」、[02-04](../design/02-impl/02-04-resolver.md)「モジュールの探し方」、[06-06](../design/06-tooling/06-06-agent-skills.md)、[05-01](../design/05-platform/05-01-distribution.md)「互換性の方針」を改めた。

- 標準ライブラリのモジュールは「標準」か「非公式」のどちらかの状態を持つ。状態はモジュールを単位に決める。
- 非公式のモジュール `Benitoite.X.Y` は `import Benitoite.Unofficial.X.Y` で取り込み、prelude に入らない。取り込んだ後の書き方（`Console.writeLine`、`uses Console.Write`）は標準のモジュールと同じである。非公式のモジュールを `Benitoite.X.Y` で、標準のモジュールを `Benitoite.Unofficial.X.Y` で取り込むと E0321 とし、正しい取り込みの名前への置き換えを示す（10-02）。
- モジュールの同一性、組み込みの型とエフェクトの表（10-05）、組み込みの関数の表の名前（10-12）、ソースの置き場所（10-14）、設計書の本文と例は、標準に加えた後の名前（`Benitoite.IO.Console`）で書く。処理系は、`STDLIB` の項目の `unofficial`（10-04 の `StdlibModuleSource`）で取り込みの名前を決める。
- 設計者が吟味を終えたモジュールは、マイナーの版で標準に移す。移す作業は、`STDLIB` の `unofficial` を偽にし、スクリプト・ゴールデンテスト・Skill の例・標準ライブラリのソース（`Benitoite.Task` の `import Benitoite.Unofficial.IO.Clock`）の import の行を書き換え、`CHANGELOG` に移行の手順を記す。取り込みの名前が変わるので、互換性を壊す変更である（[ADR 0236](../design/decisions/0236-compatibility-during-0x.md)）。組み込みの関数の表の名前と設計書の本文は変えない。

初回リリース版の状態は次のとおりである。設計者の指示は「言語の中核を除くすべてを非公式とし、U3 の 162 の関数と U2 の IO の関数を非公式とする。言語の中核（基本型の演算、`List`・`Option`・`Result`・`Pair`・`Triple` の基本の関数、`Task`・`TaskGroup`・`Lazy`・`Reference`、01-spec が規範として定めるもの）は標準とする」であった。U3 の関数のうち prelude のモジュールに加える 51 は、この二つの条件の両方に当たる。状態をモジュールの単位で決めたので、prelude のモジュールの関数はすべて標準とした（理由は ADR 0286 の「検討した代替案」）。

| 状態 | モジュール | 関数の数（U1・U2 ＋ U3） | 取り込み |
|---|---|---|---|
| 標準 | prelude のすべてのモジュール（基本型、`List`・`Map`・`Set`・`Bytes`・`ByteOrder`、`Option`・`Result`・`Pair`・`Triple`、`IOError`・`IOErrorKind`・`NetworkError`・`NetworkErrorKind`、`RoundingMode`、`Reference`・`Lazy`・`Task`・`TaskGroup`、`Assert`、`IO`） | U3 の 51 を含む | import なし |
| 標準 | `Benitoite.Trait` | — | `import Benitoite.Trait` |
| 非公式 | `Benitoite.IO.Console`・`File`・`Process`・`Clock`・`Random` | U2 の 16（R08・R29）、U3 の 40 | `import Benitoite.Unofficial.IO.Console` など |
| 非公式 | `Benitoite.Network.Http` | U3 の 16 | `import Benitoite.Unofficial.Network.Http` |
| 非公式 | `Benitoite.Path`・`Json`・`Regex`・`Csv`・`Time`・`Encoding`・`Hash` | U3 の 55 | `import Benitoite.Unofficial.Json` など |

非公式から始める関数は、U2 の 16 と U3 の 111 の合わせて 127 である。01-spec が規範として意味を定める IO の関数（01-07 の `Console.writeLine`・`File.readText`・`Process.exit`・`Process.scriptDirectory` など）とエフェクトも、属するモジュールとともに非公式とした。設計者が IO の関数を非公式と明示したからである。非公式でも、意味は 01-spec と 03-07〜03-09 の定めに従う。

### 2. そのほかの事項

| # | 事項 | 決めたこと |
|---|---|---|
| 2 | U3・U4 のモジュールを `STDLIB` に加える方法 | 取り出しの道具に、既存の `file=` の配列の末尾に要素を加える属性（`append` など）を足す。10-15 と 10-18 は、10-14 の `src/prelude/mod.rs` の `STDLIB` の末尾にこの属性で加え、`check --base` で U3・U4 の章を重ねたクレートのコンパイルを確かめる。10-12 の `PARTS` は、10-12 が末尾への追加を既に許している。道具は 10-15 を書くときに改めた（見出し `append=<パス>::<項目>`。前述の「インターフェースの読み方」） |
| 3 | 使うクレートの版と機能 | 名前は ADR 0138・ADR 0143 のとおり。版・機能・`rust-version`（Rust 1.98.1 で使えるか）は、各作業の文書を書く日に `cargo info` と crates.io の配布物で確かめ、00-02 の `mio` と同じ形で作業の文書に書く。次の三つは【要検証】であり、確かめられなければ作業を始める前に設計者に報告する: `ureq` に `rustls-graviola` の provider と `rustls-platform-verifier` を渡せるか、`graviola` が三つのビルド先（特に `x86_64-unknown-linux-musl`）で使えるか、タイムゾーンのデータを同梱しない `jiff` で OS の時差を得られるか |
| 4 | `Clock.localOffsetMinutes` が OS の時差を得られないとき | 0 を返す。型は変えない（[ADR 0287](../design/decisions/0287-stdlib-details-decided-in-u3-plan.md)、03-07「Clock」） |
| 5 | 受け付ける要求の本体の大きさの上限 | 16 MiB（16,777,216 バイト）。【方針】として 03-09「要求と応答の型」に書いた（ADR 0287） |
| 6 | ネットワークの失敗を注入する手段 | Rust のテストから、`CliEnv::parts` のテスト用のハンドラ表で与える。ゴールデンテストの形式（[ADR 0224](../design/decisions/0224-golden-test-format-for-first-release.md)）は広げない（ADR 0287、07-03「HTTP のテスト（初回リリース版）」） |
| 7 | 手元の TLS のサーバで TLS の組み立てを確かめるか | 処理系のテストでは確かめない。リリースの試験（D31）に、公開の `https` の URL へ一度接続する手順を任意の確認として置く（ADR 0287、07-03） |
| 8 | 標準ライブラリのソースの走査を O(n) にする内部の組み込みの関数 | U1・U2 の後の測定（C16 の listget など）で `List.map` などの費用が目立つときだけ加える。加えるなら L00 に宣言を足し、作業を一つ加える |
| 9 | F17 が待つ `Regex` の作業 | L22 とし、F17 が呼ぶ「正規表現の源を実行時と同じ設定で組み立てる純粋な関数」を 10-16 で凍結する。F17 の作業の文書と上の U1 の表の依存を L22 に改めた |
| 10 | OPEN-062 の R14 と、R04 の HTTP の分 | L33 が再現テストを書き、R30 と同じ手順で OPEN-062 に記録する。R30 の作業の文書に書き加えた |
| 11 | map と http の測定と、OPEN-036 の決着の時期 | map と http の測り直しを待って OPEN-036 を決着させる（ADR 0268 の決定 5）。L41 がベンチマークを加え、測定は U3・U4 の後に行う。OPEN-036 と R33 の作業の文書に書き加えた |
| 12 | `Assert.Check` の処理の仕方 | 組み込みの操作の振り分けで、どのハンドラも処理しなかった `Assert` の操作をテストの実行器が受け、失敗ならそのテストの実行を終える（10-09 の `EndKind::CheckFailed`）。利用者のハンドラが先に処理できることは、ほかの組み込みの操作と同じ振り分けの規則で満たす。06-04 の「テストの実行器がハンドラとして処理する」の範囲の中の決定なので、設計書は改めない |
| 13 | テストを並行に動かすか | 初回リリース版では一つずつ順に動かす。06-04 は並行に動かしてよいとしたので、設計書は改めない |
| 14 | Skill の文書を生成する時点 | 処理系のクレートを使う生成の道具で生成し、生成物をリポジトリに置く。ビルドは埋め込むだけにし、生成物が古くないことをテストで確かめる。06-06 の【決定】（ビルドのときに生成する）と 05-01「ソースからのビルド」を改め、[ADR 0288](../design/decisions/0288-skill-documents-generated-by-tool-and-committed.md) に記録した |
| 15 | Skill の参照の文書の分け方 | 標準ライブラリのリファレンスはモジュールごとに一つのファイルとし、文法、診断コードの説明、イディオム集、よくある誤り集、既知の言語との対応表はそれぞれ一つのファイルとする。標準ライブラリのリファレンスは、モジュールごとに状態と取り込みの名前を示す（ADR 0286 の決定 8） |
| 16 | `THIRD_PARTY_LICENSES` を作る道具 | cargo-about とする。【要検証】: 依存のクレートごとの版・ライセンス・著作権表示と、Apache-2.0 の NOTICE ファイルの内容を載せられるか（05-01「ライセンスの表示」）。D30 の作業の文書を書くときに確かめる。ライセンスの検査は `cargo deny` のまま |
| 17 | OPEN-060 の事実の確認 | D32 で、D31 を書く前に行う。WSL2 と Gatekeeper の試行は設計者の機械を使うので、設計者と日を合わせる。Linux（arm64）のコンテナは、開発機の Apple の `container` を候補として試す |

次のものは U3・U4 に含めない: UTF-8 以外の文字コード（OPEN-043）、プロパティベーステスト（OPEN-046）、ドキュメントコメントの例の実行（OPEN-047）、標準の型クラスと重複する関数を隠すか（OPEN-050。初回リリース版を実装した後に評価する）、実行時の権限制御とサーバモード（OPEN-052・OPEN-055）。
