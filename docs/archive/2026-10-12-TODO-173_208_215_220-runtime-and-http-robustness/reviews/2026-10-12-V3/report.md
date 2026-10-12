# V3「検査の道具と文書」のレビュー

対象: `4c23bb20`（san_benito の `6df2bfe5` "Merge branch 'mod/V3'" の第 2 親）。ファイルは `git show 4c23bb20:<path>` で読んだ。ビルド・テスト・`check.sh` は走らせていない。走らせたのは、BSD grep の出力の形を確かめる読み取りだけの `grep -rlw --include='*.rs' unsafe_code crates/` だけである。

## 結論

止める指摘（高）はない。`check.sh` は bash として正しく、Q4・R9 の受け取り方に合っている。ただし、07-03 に書いた時間の測定値と添え書きは直す必要がある（中 1）。選び方の理由も 07-03 に足す必要がある（中 2）。

確かめて問題がなかった点:

- **Q4 の選び方**: `default_lib` を選ぶのは、`--only` で名指ししたとき（`check_names` に足してある）、`--full`（266 行の並び）、`classify` の `crates/benitoite/src/runtime/heap/*` の分岐（180 行）の三つだけである。`--only heap`・`--only rust`・`--only long` では選ばない。`$test_args` を渡さないので、長いテストは含まない（345 行）。`heap` の分岐は `runtime/*` の分岐より前にあるので、順序も正しい。
- **既定の機能の Clippy**: `has rust` の分岐の中で、条件を付けずに走る（326 行）。`--full` と、`rust` を選ぶ変更（Cargo.toml・`crates/*`・`fuzz/*`・ヒープ・ランタイム）と、`--only rust`・`--only long` のどれでも走る。`.cargo/config.toml` の `[build] warnings = "deny"` が効くので、警告でも失敗する。
- **set -e の下での失敗の伝わり方**: `check_unsafe_allows` は `run_check` の `if "$@"` の中で呼ばれる。その中では `set -e` が効かないが、`failed` を明示して `return` するので、失敗は伝わる。`while read` とプロセス置換の組み合わせも、既存の `check_placeholder_allows` と同じ形である。
- **bash 3.2 と BSD grep**: 使っているのは `local`・`case`・プロセス置換・`printf -v`・`${!var}` だけで、どれも bash 3.2 にある。この Mac の `/usr/bin/grep`（BSD grep 2.6.0-FreeBSD）は `-rlw` と `--include` を受け付ける。引数の `crates/` の末尾にスラッシュがあっても、出力は `crates/benitoite/...` の形になり、`//` にはならない。出力は許す一覧の 6 ファイル（`core.rs`、`core/` の `alloc.rs`・`layout.rs`・`mark_sweep.rs`・`verify.rs`、`tests/call_allocations.rs`）と一致するので、今のリポジトリはこの検査を通る。
- **case の並べ方**: case のパターンの `*` は `/` にも当たるので、`core/*.rs` は入れ子のファイルにも当たってしまう。そこで入れ子の `core/*/*` を先に置いて拒否しており、この並べ方は正しい。
- **対象の範囲**: `check.sh` 自身や `Cargo.toml` の `[workspace.lints]` は `.rs` でないので、検査の対象にならない。`fuzz/` と `tools/bench/programs/rust/` は `crates/` の外にあるので含まれない。どちらもワークスペースの lint を受け継がないので、外してよい。
- **07-03 の検証器の書き直し**: 「機能 `heap-verify` の構成でのヒープの検証器」への書き直しは、実装と一致する。`core.rs` の `generations`・`next_generation`・`ObjHeader::generation`・`mod verify` は、どれも `cfg(feature = "heap-verify")` の下にあり、`debug_assertions` には結び付いていない。

## 指摘

### 中 1: 07-03 の時間の記述が、測った条件を代表しておらず、実行環境の失敗の添え書きを設計書に残している

- 場所: `docs/design/07-quality/07-03-compiler-testing.md` 287 行（「既定の機能のライブラリのテストを加えると、…測り直していない。」）。同じ値を使う `scripts/check.sh` 288 行（`describe default_lib "... ~41 s with cached build"`）。
- 問題:
  1. 約 41 秒は、ビルドが約 2 秒、つまり既定の機能のライブラリのテストの実行ファイルがすでにある状態で測った値である。`default_lib` が選ばれるのは主に `src/runtime/heap/` を変えたときで、そのときはクレートを既定の機能でビルドし直す。だから実際の時間は、この値を大きく超える見込みである（study.md 4.2 節の見込みは数分）。AGENTS.md「テストの運用」は、走らせる前に見込みの時間を報告するよう定めているが、`--dry-run` が示す値は、その根拠として小さすぎる。
  2. 「TCP を使う 3 件は実行環境の権限の制約で失敗した」は、Codex のサンドボックスの事情である。処理系の設計の記述ではない。
  3. 「全体の検査の時間は、この追加の後には測り直していない」は、確かめていない事項の断り書きである。AGENTS.md の「設計書の規約」では、確かめていないことは設計書に書かない決まりになっている。
- 直し方: オーケストレータがサンドボックスの外で測り直す。ヒープのファイルを変えた直後と同じ状態（たとえば `touch crates/benitoite/src/runtime/heap/core.rs` の後）で `scripts/check.sh --only default_lib` を走らせ、TCP の 3 件を含めて全件が通ることを確かめる。そのうえでビルドとテストの時間を測る。07-03 には「約 N 分（ライブラリの再ビルドを含む。YYYY-MM-DD の測定）」の一文だけを残し、TCP の添え書きと「測り直していない」の文を消す。測定の詳細は改造の `measurements.md` に置く。最後の検査を `--full` で走らせるなら、286 行の「約 28 分」もその値に改める。走らせないなら、「既定の機能のライブラリのテストを加える前の測定で」の断りは残してよい。`describe` の文言も、再ビルドを含む値（例: `~N min incl. rebuild`）に揃える。

### 中 2: `default_lib` を選ぶ条件の理由が 07-03 にない

- 場所: 07-03 282 行（「選んだ検査」の項目の「既定の機能のライブラリのテスト（`default_lib`）は、`src/runtime/heap/` を変えたときに選ぶ。…」）。
- 問題: 【方針】の項目に決定だけが書いてあり、なぜ処理系の変更の全部ではなくヒープの変更に限るのかが書かれていない。AGENTS.md の「決定の書き方」は、決定の直後に「理由: 〜。」を置くよう定めている。この条件は設計者の判断（Q4）であり、理由がないと、後の改造が `rust` の条件に広げるか狭めるかを判断できない。
- 直し方: 直後に、たとえば次の 1〜2 文を足す。「理由: `heap-verify` の有無で変わるのは値とヒープの表現であり、その違いで結果が変わりうるのは主にヒープの変更である。毎回の選んだ検査にライブラリのテストの再ビルドと 1 回分の実行を足す費用は、ほかの変更では見合わない。」長いテストを含めない理由（長いテストは heap-verify の構成で走らせる）も、同じ文に添えるとよい。

### 低 3: 単語の一致なので、`unsafe_code` を許可していないファイルでも失敗し、表示と文書もその振る舞いと合わない

- 場所: `scripts/check.sh` 93-112 行（`check_unsafe_allows`）。07-03 302 行。AGENTS.md 191 行・254 行。
- 問題: `grep -w unsafe_code` は、`#![forbid(unsafe_code)]`・`#![deny(unsafe_code)]` のように締める属性にも当たる。コメントや文字列でこの語に触れたファイルや、`crates/` の下に置いた追跡していない一時の `.rs` にも当たり、どれも `unexpected unsafe_code allow` として失敗する。今は当たるファイルがないので、偽の失敗は起きない（事前点検の補足のとおり、複数行の属性を拾うために選んだ方式でもある）。ただ、表示の「allow」と、07-03 の「`unsafe_code` の許可が…に限られる」は、実際に確かめていること（この語が出てくるファイルが一覧に限られる）と合わない。
- 直し方: 方式はこのままでよい。そのうえで (a) 失敗したときに `grep -nw unsafe_code "$source_file"` で当たった行を示し、読み手が許可かどうかを見分けられるようにする。(b) 表示を `unsafe_code outside the allowed files: <path>` のような中立の文言にする。(c) 07-03 の「確かめること」の欄に「`unsafe_code` の語を単語として探すので、許す一覧の外ではコメントにもこの語を書かない」と一文足す。

### 低 4: 継承と `#[path]` のため、許可を書かない `unsafe` は検査をすり抜ける

- 場所: AGENTS.md 191 行（「`unsafe` を書いてよいのは、…`core/` の直下の Rust ファイル…だけである。`scripts/check.sh` が…確かめる。」）。`check.sh` 102 行の入れ子の拒否。
- 問題: `core.rs` 27 行の `#![allow(unsafe_code)]` は、`core` の下のすべての子のモジュールに受け継がれる。だから `core/x/y.rs` のような入れ子のファイルは、自分で許可を書かずに `unsafe` を使え、検査を通る（入れ子を拒否する分岐が働くのは、許可を自分で書いたときだけである）。`core.rs` はすでに `#[path = "core/mark_sweep.rs"] mod mode;` を使っており、`#[path]` で `core` の外のファイルを子にしても同じことになる。AGENTS.md は「`unsafe` を書いてよいのは直下のファイルだけ」と書いたうえで「check.sh が許可の場所を確かめる」と続けるので、`unsafe` の場所そのものを確かめていると読める。
- 直し方: どちらか一つにする。(a) `check_unsafe_allows` に二つの確かめを足す。一つは `crates/benitoite/src/runtime/heap/core/` の下に深さ 2 以上の `.rs` がないこと（`find … -mindepth 2 -name '*.rs'`）、もう一つは `core.rs` と `core/*.rs` の `#[path = "…"]` が `core/` の中を指すこと。(b) AGENTS.md の文を「`scripts/check.sh` は `unsafe_code` の許可を書いた場所を確かめる（子のモジュールへの継承は確かめない）」と、確かめる範囲が分かる形に改める。

### 低 5: `|| true` が grep の入出力の誤りを隠す

- 場所: `scripts/check.sh` 109 行（`grep -rlw … crates/ || true`）。既存の 88 行も同じ形である。
- 問題: grep が読めないファイルなどで終了状態 2 を返しても、検査は何も出さずに通る。そうなると偽の成功になる。
- 直し方: 結果を変数に受けてから、終了状態で分ける。たとえば `files="$(grep -rlw --include='*.rs' unsafe_code crates/)" || [ "$?" -eq 1 ] || return 1` のようにし、2 のときは失敗させる。急ぐものではない。

### 低 6: ヒープの外にある構成ごとの分岐の変更では `default_lib` を選ばない

- 場所: `scripts/check.sh` 176-184 行（`classify`）。
- 問題: `src/vm/dispatch.rs:373` と `src/vm/tests.rs:1737` には、`cfg!(feature = "heap-verify")` で振る舞いを分ける箇所がある。また、`crates/benitoite/Cargo.toml` の `[features]`（`default` の中身）を変えると、既定の構成そのものが変わる。どちらの変更でも `default_lib` は選ばれない。Q4 の受け取り方（`runtime::heap` を変えたとき）には合っているので、誤りではない。
- 直し方: 設計者の「ライブラリ改造時」がこれらを含むかを、最後の確認のときに一言尋ねる。含めないなら、`classify` のヒープの分岐のコメントに「ヒープの外の `cfg!(feature = "heap-verify")` の変更は、`--only default_lib` で名指しする」と書いておく。

### 低 7: 既定の機能の Clippy は examples と benches に掛からない

- 場所: `scripts/check.sh` 326 行、07-03 299 行。
- 問題: heap-verify の Clippy は `--workspace --all-targets` で走るが、既定の機能の Clippy は `-p benitoite --lib --tests` だけである。今は examples の中に `heap-verify` で分ける箇所がないので、実害はない。
- 直し方: 揃えるなら `--all-targets` にする。追加のビルドの時間はわずかである。このままにするなら対応は要らない。07-03 の欄はコマンドをそのまま写しているので、実装との食い違いはない。

### 低 8: 構成の呼び方が章の中と章の間でそろっていない

- 場所: 07-03 の 282・287・299-300・349 行は「既定の機能」「配布物と同じ機能の構成」「配布物の機能の構成」を使う。02-09 の 25 行は「既定の構成（`gc-mark-sweep` だけ）」を使う。
- 問題: AGENTS.md の「文章の規範」は、同じ概念に章をまたいで別の語を使わないよう定めている。また、配布物は `bundled-licenses` も有効にしてビルドするので、「配布物と同じ」は正確には「ヒープに関わる機能が配布物と同じ」である。
- 直し方: 02-09 に合わせて「既定の構成（機能 `gc-mark-sweep` だけ）」に統一する。表の検査の名前も「既定の構成の lint」「既定の構成のライブラリのテスト」にする。AGENTS.md の `scripts/` の行も同じにそろえる。

## 漏れの確認

- plan.md V3 の 1〜3 の項目は、すべて実装されている。R7（TODO-161 への書き足し）は、plan のとおりオーケストレータの作業として残っている。
- `default_lib` の全件が通ることは、まだ誰も確かめていない（実装担当の報告では、TCP の 3 件がサンドボックスで失敗した）。中 1 の測り直しのときに、あわせて確かめる必要がある。
- 先頭の使い方のコメント（4-9 行）には `--only` の名前の一覧がないので、足さなくてよい。16-17 行の追記で足りている。
