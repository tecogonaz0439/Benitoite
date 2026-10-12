# TODO-174 の調査

調べた版: ブランチ `san_benito` の HEAD（8ca4d47）。調査ではファイルを書き換えておらず、cargo も走らせていない。以下の行番号は、断りがなければ `crates/benitoite/` からの相対パスで示す。

## 1. 移行の締めの残り

### (1) `vm/stage1.rs` と `pub mod stage1;`

- 所見はまだ成り立つ。`src/vm/stage1.rs` は `//!` の 2 行だけのファイルで、2 行目に「U1・U2 の終了後に取り除く（実装プラン 90-after-completion）」とある。
- 宣言は `src/vm/mod.rs:8` の `pub mod stage1;` にある。項目は「その `///`」と書くが、今は `///` のコメントは付いていない。
- 直し方: ファイルと宣言の 1 行を消す。`vm::stage1` への参照はリポジトリの中に一つもない（git grep で確かめた）。

### (2) `src/lib.rs` の `#![allow(dead_code)]`

- 所見はまだ成り立つ。許可は `src/lib.rs:7` にあり、理由のコメントは 4〜6 行目にある（「C01 がこの指定を置き、U1・U2 を終えた後に外す」）。
- 外したときに警告になるもの: このクレートはライブラリである。根から辿れる `pub` の項目は、使われていなくても dead_code の警告にならない。警告になるのは、非公開の項目、`pub(crate)`・`pub(super)` の項目、非公開のモジュールの中の `pub` の項目、読まれない欄である。名前の出現を数える簡単な走査で探すと、確かな候補は次の 10 件ほどに収まる。警告が大量に出る見込みは低い。ただし、読まれない欄と、作られない列挙子は名前の走査では見つけきれない。

| 候補 | 位置 | 状態 | 直し方の案 |
|---|---|---|---|
| `stub_expr` | `src/syntax/parser/mod.rs:805` | どこからも呼ばれない（F02 のフックの仮の本体） | 消す。`mod.rs:53` の表の行も直す |
| `stub_decl` | `src/syntax/parser/items.rs:652` | どこからも呼ばれない | 消す（項目に挙がった `items.rs:675` のコメントは、この関数の中にある） |
| `Body::pattern_in` | `src/typeck/context.rs:143`（`mod context;` は非公開） | どこからも呼ばれない | 消し、`typeck/mod.rs:30` の説明も直す |
| `in_table` | `src/bytecode/verify.rs:57` | どこからも呼ばれない | 消す |
| `complete_worker` | `src/builtins/table.rs:49`（`pub(crate)`） | テストだけが使う（`builtins/funcs/mod.rs`・`samples.rs`・`refinterp/convert.rs` のテスト） | `#[cfg(test)]` にするか、テストの補助のモジュールへ移す。45〜48 行目の「第 1 段の VM と参照インタプリタが」も直す |
| `Stage1StateServices` | `src/vm/state.rs:220`（`pub(crate)`） | テストだけが使う（`file/tests.rs`・`http_server/tests.rs`・`reference.rs`・`task.rs`・`vm/dispatch/tasks.rs:421` など） | `#[cfg(test)]` にして、名前から Stage1 を外す（例: `BorrowedStateServices`）。219 行目の「実装プラン R25」も直す |
| `FIELD_BYTES`・`CELL_BYTES`・`DECIMAL_BYTES` | `src/runtime/heap/core/layout.rs:24-26`（`pub(super)`） | `core/tests.rs` だけが使う | `#[cfg(test)]` を付ける |
| `assert_shareable` | `src/bytecode/program.rs:375` | 個別に許可済み（AGENTS.md の表にある） | そのまま |

- 走査の結果には、`#[cfg(test)]` の範囲を取り違えた誤検出（`file.rs` の `remove_tree_job`、`heap/core.rs:1080` のテスト）もあったので、表からは除いた。
- 進め方の案:
  1. 許可を外す。
  2. 次の機能の組み合わせのそれぞれで `cargo clippy --workspace --all-targets`（または `cargo check --all-targets`）を通す。対象は、既定、`check.sh` の `gc-mark-sweep,alloc-stats`、`gc-stress`、`heap-verify`、`heap-per-object`、`heap-verify,heap-per-object`、`bundled-licenses`、release である。`.cargo/config.toml:2` が `warnings = "deny"` なので、どれか一つの組み合わせの警告でもビルドが止まる。`heap-verify` と `heap-per-object` の `cfg` は `src/runtime/heap/core.rs`・`alloc.rs`・`ctx.rs`・`value.rs`・`slot.rs` に約 55 箇所あり、機能によっては片方の構成でだけ使われない項目が出るおそれがある。
  3. 方針は次の三つとする。どこからも使われない非公開の補助は消す。テストだけが使う項目は `#[cfg(test)]` にする。残す項目は、個別の `#[allow(dead_code)]` と理由を書き、AGENTS.md の表に加える。今の見込みでは、個別の許可の追加は不要である。
- 許可を外しても警告にならない死んだ `pub` の項目（手で消すもの）:
  - `builtins/funcs/stage1_io.rs` の `RealIo`（53 行目）と `Output`（18 行目）。`pub mod` の中の `pub` なので、警告では見つからない。
  - 第 1 段の名残。これらは項目の範囲の外にある（問い 2）:
    - `Opcode::in_stage1`（`src/bytecode/instr.rs:230-231`）。使うのはテストと `examples/stage1_bench.rs` だけ。
    - `FieldsKind::ListCell`（`src/runtime/heap/value.rs:202-203`）。作るのはテストだけ。
    - `HeapStats` の `rc_increments`・`rc_decrements`・`rc_elided`・`reuses`（`src/runtime/heap/stats.rs:45-52`）。マーク・スイープでは常に 0 で、出力するのは `examples/stage1_support` だけ。

### (3) AGENTS.md の表

- 所見はまだ成り立つ。AGENTS.md:251 の `src/lib.rs` の `dead_code` の行を消す。
- 同じ表の古い行がほかにもある。
  - AGENTS.md:255 は「`src/runtime/run.rs` の第 1 段の IoServices を包む型（R26 が IO 実行器へ移す）」と書くが、今の `BENITOITE_DEV_PANIC` の処理は `src/cli/mod.rs:706-715,727` と `src/runtime/io/services.rs:270-274` にある。行を「`src/cli/mod.rs` と `src/runtime/io/services.rs`（IO 実行器）」に直すのがよい。
  - AGENTS.md:164-180（`todo!()` の仮置きの手順。`src` に `todo!()` も仮置きの許可も残っていない）と、250・227 の「10-08」は、TODO-006（規約の置き場所）とあわせて扱う。

### `RealIo` と `TestIo`

- `RealIo`・`Output` と、それらのテスト 2 件（`stage1_io.rs` のテストのモジュールの `real_io_buffers_each_stream_until_threshold_or_final_flush` と `failed_final_or_threshold_flush_is_recorded_and_later_writes_fail`）は、本番からは使われていないので消してよい。
- `TestIo`（`stage1_io.rs:175-258`）はテストからだけ使われる。使うのは次の 5 ファイルである。
  - `builtins/funcs/mod.rs:1190,1244,1277`
  - `process/tests.rs:34`
  - `process/external_tests.rs:7`
  - `refinterp/tests.rs:12`
  - `refinterp/resources.rs:172`
- 同じ名前の `TestIo` がほかに三つある。
  - `vm/dispatch/test_support.rs:13`（`IoRuntime` を包む。8 ファイルが使う）
  - `samples.rs:178` の局所の型
  - `refinterp/convert.rs:646` の局所の型
- 案: `builtins/funcs/stage1_io.rs` を `builtins/funcs/fixed_io.rs` などへ改め、`#[cfg(test)] pub(crate) mod` にする。型の名前は、与えた値を返すことを表す `FixedIo` にして、VM の `TestIo` と区別する。「R26 が 10-10 の IoRuntime に置き換えて消す」というコメント（1〜2・50・62・67・172・192 行）は消す。`refinterp/resources.rs:164` のテスト名 `reference_and_stage1_services_do_not_expose_vm_runtime_views` も改める。

## 2. 作業の途中の状態を述べるコメント（網羅の一覧）

`仮の本体|後の作業|担当|未実装|未提供|置き換えて消す|仮置き|中身は作業|欄は R..|一時的な実装|第 1 段|C0x|U1〜U4|個別の指示` などで git grep した。誤検出を除くと約 118 行・70 ファイルある。これに、パーサと型検査のフックの表（約 50 行）が加わる。

| 分類 | 位置 | 案 |
|---|---|---|
| 組み込みの関数の「仮の本体」の頭のコメント | `builtins/funcs/{boolean,character,float,list,string,traits}.rs:2-3` | 3 行目の「名前・権限・引数の数・DECLS の中の位置は変えない」の要点（番号は表の位置で決まる）だけを残し、2 行目は消す |
| パーサのフックの表 | `syntax/parser/mod.rs:5-8,10-46`（「仮の本体」「担当」の列）、`53`（stub_*）、`56-57` | 子のモジュールの役割の表に縮めるか、消す |
| 型検査のフックの表 | `typeck/mod.rs:3`（「F07〜F10 の作業の文書で分ける」）、`8-29`（「仮の本体」「中身を書く作業」の列） | 二つの列を消し、呼ぶ位置と入出力だけを残す |
| パーサの本文のコメント | `items.rs:177`、`items.rs:675`（stub_decl とともに消える）、`items.rs:850`、`items.rs:1005`、`exprs.rs:1020` | 今の動きで書き直す。`exprs.rs:1020` の分岐は、次の欄に書くとおり到達しない |
| パーサのテストの前置き | `effects.rs:469`、`spread.rs:73`、`records.rs:274`、`patterns_ext.rs:340`、`traits.rs:248`、`test_support.rs:34` | 「仮の本体のテストを置き換え」を消し、テストが捕まえる退行だけを書く |
| テストの前置き（その他） | `builtins/funcs/time/tests.rs:11`（「未実装の Time」）、`typeck/effects/tests.rs:414-415`（後述の 4 章）、`vm/dispatch/handlers/tests.rs:879`（「R20 では未実装だった」）、`vm/tests.rs:1006-1009`、`bytecode/liveness.rs:642`（「C01 の仮置き」）、`ir/check.rs:1231`、`runtime/map/tests.rs:4`、`runtime/sched/parts/tests.rs:22`、`bytecode/codegen/tests.rs:260`（「C03 が置く」）、`builtins/funcs/process/tests.rs:90`（stage1_io）、`vm/dispatch/test_support.rs:1`、`builtins/funcs/runtime_test_support.rs:1` | 同上 |
| 作業が中身を書くと述べるもの | `base/prim.rs:1` と `cli/tools.rs:1`（「中身は作業で書く（10-interfaces の sig=…）」）、`cli/tools.rs:3`、`cli/mod.rs:2,42`（「U4 が書く」）、`vm/mod.rs:139`（「U4 が定める」）、`runtime/run.rs:85`、`syntax/lexer.rs:14`、`runtime/io/services.rs:58`（「U3 の L14 である」）、`builtins/table.rs:471`（「U1 が…契約」） | 消すか、今の事実に直す |
| 欄や使い方を作業が決めると述べるもの | `runtime/heap/core.rs:60,95,111`（「欄は R01 が決める」）、`runtime/heap/value.rs:204,206`（R36・R37 が決める）、`runtime/io/event.rs:13,60`（R26・R28・R40）、`vm/state.rs:15,219`、`vm/dispatch.rs:795`（「並行して書く作業（R22・R23・R24）ごとに」）、`builtins/iface.rs:303-304,332,347`（「第 1 段は一時的な実装」「R23 が置き、R25 が置き換える」）、`builtins/table.rs:1,14,45-48`、`bytecode/program.rs:96-97`（「C02 で置くので C01 の本章は」） | 今の構造の説明に直す |
| 第 1 段の名残 | `vm/stage1.rs`、`lib.rs:4-6`、`stage1_io.rs`、`bytecode/mod.rs:4` と `bytecode/asm.rs:1`（「10-07「第 1 段で実行するプログラム」」）、`bytecode/instr.rs:230`、`runtime/heap/value.rs:202`、`runtime/heap/stats.rs:45-52`、`runtime/heap/mod.rs:6,31`（経緯の説明で、残してよい） | 名残の扱いは問い 2 |
| 個別の指示への参照 | `builtins/funcs/map.rs:53,130`、`builtins/funcs/set.rs:44`、`builtins/funcs/file/path_tests.rs:99`、`builtins/table.rs:569`、`runtime/heap/core.rs:1066`、`vm/dispatch/tasks/tests/cancellation.rs:105` | 理由を本文に書き、作業の ID を外す |

項目の例に挙がった箇所の今の位置は次のとおり。どれも、所見はまだ成り立つ。

- `builtins/funcs/*.rs:2-3` は変わっていない。
- `syntax/parser/mod.rs:10-57` は、今は 5〜57 行。
- `typeck/mod.rs:8` は変わっていない。
- `time/tests.rs:11` は変わっていない。
- `items.rs:177・675・850` は変わっていない。
- `exprs.rs:1017` は、今は 1020 行。

追加の所見が四つある。

- **到達しない分岐**: `src/syntax/parser/exprs.rs:1019-1031` の `else if p.at(TokenKind::Comma)` の分岐（「F04 の仮の本体がまだ読まない選択肢」）は到達しない。直前の `patterns_ext::parse_arm_head_rest`（`patterns_ext.rs:19`）は `,` と `|` がある間は読み進め、失敗は `?` で返す。そのため、成功して戻った時点で `,` にいることはない。コメントを直すだけでなく、分岐ごと消せる。dead_code の lint はこれを見つけない。
- **保管した実装プランを読むテスト**: `src/syntax/parser/traits.rs:449-463` の `all_standard_library_sources_parse_as_prelude` は、`include_str!` で `docs/archive/2026-10-09-implement-first-release/10-interfaces/10-14-prelude-and-stdlib-sources.md` を読み、そこにある 27 本のソースを構文解析している。今の標準ライブラリのソース（`crate::prelude::STDLIB`。約 40 本）ではなく、保管した古い写しを確かめている。案: `crate::prelude::STDLIB` を回す形に書き換え、同じことを 12 本だけで確かめる `items.rs:1196` の `stdlib_modules_without_f04_syntax_parse_as_prelude` と一つにまとめる。なお、全ソースの読み込みは `modules/tests.rs:129`・`resolve/tests.rs:15`・`ir/desugar/tests.rs:276` も確かめている。
- **作業の記録の文書**: `testdata/C05-SWITCHOVER.md`（196 行）は C05 の作業の記録で、`testdata/` に残っている。
- **作業の ID を含むファイル名**: ゴールデンテストのファイル名に作業の ID を含むものが 270 件ある（`.bnt` の総数は 577。`concurrency/c12-*`、`io/l40-*`、`traits/f04_*` など）。コメントではないので、項目の範囲の外として扱う（問い 6）。

## 3. 保管した実装プランへの参照

### 件数

| 数えたもの | 行数 | ファイル数 |
|---|---|---|
| `実装プラン` | 723 | 183 |
| `実装プラン`、章番号だけの `10-xx`、作業の ID（R・F・L・D・C・U の 2 桁）のどれかを含む行 | 1,221 | 226 |

1,221 行の内訳:

- 同じ行に「設計書」への参照もあるもの: 111 行
- テストのファイル（`tests.rs` など）にあるもの: 225 行
- モジュール別: builtins 462、runtime 225、vm 200、syntax 70、cli 67、typeck 48、bytecode 44、その他 105
- 引いている節: 10-12 が 189、10-15 が 110、10-18 が 30、00-02 が 28（「00-0x」を含む行は 95）、10-07 が 22、ほか
- 作業の ID: R が 336、F が 153、L が 82、U が 43、D が 22、C が 6

多い定型文は次のとおり。

| 定型文 | 件数 |
|---|---|
| `// テストの失敗は panic で表す（実装プラン 00-02…）。` | 75（文言の揺れを含む） |
| `/// U3 の部分の項目（実装プラン 10-15「部分と番号」）。` | 24 |
| `/// 部分の項目。末尾以外には加えない（実装プラン 10-12「部分と番号」）。` | 21 |
| `docs/archive` を直接書いた箇所 | 1（前節の `parser/traits.rs:451`） |

### 判断の材料

- AGENTS.md「コメントと名前」は、コメントに根拠になる設計書の章と節を示すよう定めている。また、`docs/archive/` は「現在の作業の根拠にしない」としている。保管した実装プランを引くコメントは、どちらにも合わない。
- 一方で、AGENTS.md「実装の規約」自身が、00-02 を docs/archive から写したと明記し、本節を正としている。00-02 を引く 95 行は、引き先を「実装の規約「…」」（AGENTS.md）に置き換えれば、意味を変えずに直せる。すでに `base/file_read.rs:46` がこの書き方をしている。
- 「部分と番号」（10-12・10-15）にあたる決まりは、設計書のどの章にもない。組み込みの番号は表の位置で決まるので、末尾にだけ加える。この理由をコメントの中に書き切れば、引き先は要らない。
- 残りの約 1,000 行は、作業の ID（R26、F04 など）と 10-xx の節を引く。設計者がコードを読んで経緯を調べるときの手がかりにはなる（学ぶ目的）。しかし、どの設計書の節に当たるかは 1 件ずつ判断が要り、一度に機械的に置き換えると誤りが入りやすい。
- 次の版の実装プランと規約の置き場所（TODO-006）が決まると、引き先がまた変わりうる。

### 推奨（段階に分ける）

この改造でするのは、次の 1〜3 である。

1. 2 章の「途中の状態」のコメント（約 170 行）を消すか直す。
2. 00-02 を引く 95 行を「実装の規約「…」」に置き換える。
3. 「部分と番号」の定型文（45 行）を、引き先のない自足した文にする。

残りは次の 4 のように扱う。

4. 約 1,000 行は残す。AGENTS.md「コメントと名前」に一文を加え、コメントの「実装プラン nn-nn」と作業の ID が `docs/archive/2026-10-09-implement-first-release/` を指す経緯の参照であることを示す。そのうえで、その箇所を変えるときに設計書の節へ置き換える。全面の置き換えは TODO-006 の決定の後に回す。

## 4. bytecode の検証器と typeck/effects/tests.rs の古いコメント

### bytecode の検証器

- 所見はまだ成り立つ。古い記述は次の 3 箇所にある。
  - `src/bytecode/mod.rs:3`: 「verify.rs: 読み込みのときの検証器」
  - `src/bytecode/verify.rs:1-2`: 「読み込みのときの範囲と生存の情報の検証（…実装プラン 10-07「読み込みのときの検証器」）」
  - `src/bytecode/verify.rs:23`: 「R32 の評価に使う」
- 本番からの呼び出しはない。`bytecode::verify` を使うのは `tests/verify.rs:18` だけである（統合テストが使うので、`pub` は外せない）。
- 設計書 02-08 の 127 行目は、すでに「検証器は、テストでコード生成の出力を確かめるために使い、読み込みの経路では呼ばない」と書いている。設計書を直す必要はない。
- 案: 三つのコメントを「コード生成の出力を範囲と生存の情報について確かめるテスト用の道具。本番の読み込みの経路からは呼ばない（設計書 02-08「実行の手順」）」の趣旨に直す。`tests/verify.rs:2` の「実装プラン R32」も同様に直す。あわせて `in_table` を消す。

### typeck/effects/tests.rs

- 所見はまだ成り立つ。該当箇所は、今は 414〜415 行である。
- テストの組み立て（416〜457 行）は、`State` の束縛の種類を `find_builtin_effect` で Assert.Check・Http.Connect・Http.Listen に差し替えて型検査に渡している。
- 今は `src/prelude/stdlib/Assert.bnt`（`public effect Check`）と `Network/Http.bnt`（`Listen`・`Connect`）がある。Assert は取り込みの宣言なしで `uses Assert.Check` と書ける（`testdata/test/assert_equal.bnt:4`）。Http は `import Benitoite.Unofficial.Network.Http` の後で `uses Http.Connect` と書ける（`testdata/network/redirect.bnt:5,18`）。
- 案: ソースに実際の効果の名前を書き、束縛の差し替えをやめる。その場合、主な位置を確かめる行（`source.find("State")`）は、効果の名前の位置に変わる。
- 同じ契約（`main` が Assert.Check を使うと E0415 になる）を確かめるゴールデンテストは見当たらなかったので、単体テストのまま残す。

## 5. ir/desugar.rs の `#[allow(clippy::panic)]`

- 所見はまだ成り立つ。`src/ir/desugar.rs:352-355` で、`#[cfg(test)]` を付けた `pub(crate) mod test_support` に許可が付いている。コメントは「実装プラン F11「テストの補助」」を引く。panic を使うのは `unwrap_or_else(|e| panic!("{e:#?}"))` の 1 箇所である。
- AGENTS.md の表の「テストのモジュール（`#[cfg(test)] mod tests`）」を字義どおりに読むと、当たらない。ただし、同じ形の許可がほかにもある。
  - `src/vm/dispatch/test_support.rs:3`（unwrap・indexing）
  - `src/builtins/funcs/runtime_test_support.rs:3`（unwrap・panic・indexing）
  - `src/bytecode/asm.rs:415`（`#[cfg(test)]` のモジュール）
- `clippy::unreachable` は workspace の lint に入っていない（`Cargo.toml` の `[workspace.lints.clippy]`）。そのため、desugar の 1 箇所は `assert!(result.is_ok(), …)` と `let Ok(core) = result else { unreachable!() }` で許可なしに書ける。しかし、それではほかの 3 箇所との食い違いが残る。

## 6. tools/bench/stage1.py の退役

所見はまだ成り立つ（390 行。`write_report` は 201〜253 行目で、本測定の後に埋める前提の固定文を出す）。

消したときに参照が残る箇所:

- **`tools/bench/remeasure.py`**: `import stage1`（20 行目）があり、`stage1.VM_NAMES`・`INPUTS`・`expected`・`percentile`・`system_information`・`sample`・`source` を使う（31・32・48・49・106・191・226・232・242 行）。消すと動かなくなる。
- **`tools/bench/secb6.py`**: `import stage1`（18 行目）があり、41 行目で `stage1.system_information()` を使う。62 行目では `remeasure.sample` も使う。
- **`tools/bench/README.md`**: `stage1.py` の名前を直接は書いていない。ただし、167・231 行目（「R12 の入力と期待値の計算」は stage1.py の関数を指す）と 249 行目（`stage1/returns.bnt`）が、その中身に依存している。
- **スキル `benchmark`（`.claude/skills/benchmark/SKILL.md`）、設計書、`docs/reference`、テスト**: 参照はない。`tests/golden.rs:34` の `BENCH_DIRS` は `tools/bench/programs` の直下だけを読み、`programs/stage1/` は読まない。
- **`tools/bench/results/` の過去の記録**（`2026-10-05-stage1-*` など）: stage1.py のコマンドを書いているが、記録なので直さない。
- **範囲の外の関連物**: `examples/stage1_bench.rs`・`examples/stage1_heap_bench.rs`・`examples/stage1_support/mod.rs` は `gate.py` と `remeasure.py:187-226` が使う。`tools/bench/programs/stage1/*.bnt` は remeasure.py が使う。

直し方の案:

- remeasure.py と secb6.py が使う関数を、remeasure.py の中（または新しい `tools/bench/common.py`）へ移してから、stage1.py を消す。`system_information` は、`run.py:510` の `collect_system_info` で置き換えられる見込みが高い。
- README の 231 行目の「R12 の入力と期待値の計算」を、移した先の説明に直す。
- remeasure.py と secb6.py は R33・SECB6 のために作った一回限りの道具でもあるので、まとめて退役させる選択もある（問い 2）。

## 7. 影響する設計書・テスト・生成物

- **設計書（`docs/design/`）**: 直す必要のある章は見つからなかった。`stage1`・`TestIo`・`dead_code`・`test_support` の記述はなく、検証器の用途は 02-08 にすでに書いてある。07-03 は `#[allow]` の表の場所として AGENTS.md を引くだけで、表の文言を変えても章は変わらない。
- **AGENTS.md**: 表の 251 行を消す。255 行を直す。問い 3 で A を選べば、「テストのモジュール」の行の文言を直す。3 章の推奨 4 を採るなら、「コメントと名前」に一文を加える。
- **テスト**: 影響するのは次のとおり。
  - stage1_io のテスト 3 件（RealIo の 2 件は消し、TestIo の 1 件は移す）
  - `refinterp/resources.rs:164`（改名）
  - `parser/traits.rs:449` と `items.rs:1196`（一つにまとめる）
  - `typeck/effects/tests.rs:406`（`entry_effects_and_uses_duplicates` の組み立て）
  - `Stage1StateServices` と `TestIo` を使う 15 ファイルほど（名前と場所の変更）
  - 消す分岐 `exprs.rs:1020` を通るテスト。分岐には到達しないので、通るテストはないはずである。
- **生成物**: `skill/references` は、構文の章・標準ライブラリのソース・診断の表を変えたときだけ作り直す。今回の変更はどれにも触れないので、`gen_skill` で作り直す必要はない。`// spec:` の印とゴールデンテストも変わらない。
- **検査**: `scripts/check.sh` は Rust の変更として、format・clippy・test・gc-stress・仮置きの許可の残りを選ぶ見込みである。dead_code の許可を外すので、2 章の機能の組み合わせでのビルドも確かめるのがよい。`runtime/heap/core/layout.rs` を変えると、`check-heap.sh` も選ばれる。

## 8. 設計者に判断してもらう問い

1. **保管した実装プランへの参照（1,221 行）の扱い**
   - A: すべて設計書の節に置き換えるか消す
   - B: 段階に分ける（3 章の推奨 1〜4）
   - C: すべて残し、AGENTS.md に注記だけ加える
   - 推奨は B。全面の置き換えは TODO-006 の決定の後に回す。
2. **第 1 段の名残のうち、項目の範囲の外のもの**
   - 対象: `examples/stage1_bench`・`stage1_heap_bench`・`stage1_support`、`gate.py`、`remeasure.py`・`secb6.py`、`programs/stage1/`、`Opcode::in_stage1`、`FieldsKind::ListCell`、`HeapStats` の RC の欄
   - A: この改造でまとめて退役させる
   - B: この改造では stage1.py だけを消し（必要な関数を remeasure.py へ移す）、残りは新しい TODO にする
   - C: 残す
   - 推奨は B。ヒープの統計の欄とベンチマークの道具の出力形式に触れ、測定の手順の見直しを伴うので、別の項目で扱うのがよい。
3. **`#[cfg(test)]` の補助のモジュールの許可（desugar.rs ほか 3 箇所）**
   - A: AGENTS.md の表の行を「テストのビルドだけのモジュール（`#[cfg(test)]` を付けたモジュール。`mod tests`・`test_support` など）と `tests/` の各ファイル」に改め、desugar.rs のコメントの引き先も直す
   - B: desugar.rs だけを許可なしに書き直す
   - 推奨は A。同じ形の許可が少なくとも 4 箇所にあり、B では表との食い違いが残る。
4. **`TestIo`（第 1 段の写し）の置き場所と名前**
   - 推奨: `builtins/funcs/fixed_io.rs` を `#[cfg(test)] pub(crate) mod` にし、型の名前を `FixedIo` にする。VM の `vm::dispatch::test_support::TestIo` はそのままにする。
   - 別案: 名前を変えずに場所だけ移す。
5. **`testdata/C05-SWITCHOVER.md`（作業の記録）**
   - A: 改造のディレクトリへ `git mv` し、改造と一緒に保管する
   - B: 消す（履歴には残る）
   - 推奨は A。`docs/archive/` は読み取り専用なので、直接そこへは移さない。
6. **作業の ID を含むゴールデンテストのファイル名（270 件）**
   - 推奨: 変えない。改名は差分が大きく、`acceptance/INDEX.md` やテストの中の固定の名前（`tests/golden.rs:36,40,45` など）も直す必要がある。必要なら別の TODO にする。
7. **AGENTS.md「実装の規約」の、ほかの古い節**
   - 対象: 164〜180 行の `todo!()` の仮置きの手順、212 行の「10-11 で凍結する」、227・250 行の「10-08」
   - 推奨: この改造では 251・255 行だけを直し、残りは TODO-006 に回す。
