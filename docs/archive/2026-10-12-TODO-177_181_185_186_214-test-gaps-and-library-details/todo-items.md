# 扱う項目の本文の写し

docs/todo は非公開のリポジトリなので、改造を始めた時点（2026-10-12、docs/todo の f3f3ffe）の項目の本文を写す。リンクは docs/todo の中からの相対パスのままである。

## TODO-177 公開前のセキュリティのレビューで後に回した指摘

- 状態: 方針あり
- 出どころ: [later-issues の 99](sources/later-issues.md)、[later-issues の 106](sources/later-issues.md)、[later-issues の 108](sources/later-issues.md)、[later-issues の 109](sources/later-issues.md)、[later-issues の 120](sources/later-issues.md)

`0.0.1` の公開の前に行ったセキュリティのレビューの指摘のうち、公開の前には直さず後に回したものの残りをまとめる。モジュールの読み込み（D-2）、`skill install` の `is_ours`（D-3）、fmt の一時ファイルと出力（D-4〜D-6）、リポジトリの衛生の一部は、改造 `docs/archive/2026-10-11-TODO-165_166_167_169_177_194-small-fixes-and-hardening/` で直した。`uses` の表示の偽装（F-2）は、改造 `docs/archive/2026-10-11-TODO-042_177_195_196_197_198-runtime-and-check-hardening/` で直した（E0339）。括弧の中の F-2・D-2 などは、レビューの指摘の番号である。直し方は指摘のときに示したもので、まだ実装していない。`src/`・`tests/`・`testdata/`・`skill/` で始まるパスは `crates/benitoite/` を起点とし、ほかのパスはリポジトリの根を起点とする。

- `tools/bench/results/` の大きな JSON（A-8。later-issues の 120）: 33 MB 前後の JSON が 3 つ（`2026-10-05-stage1-5b300d4-*.json`）残る。消すか残すかを決める。同じ指摘の A-3（手元の絶対パス）・A-6（`.gitignore`）・A-9（メールアドレス）と内部の不具合の文言は、改造 `docs/archive/2026-10-11-TODO-165_166_167_169_177_194-small-fixes-and-hardening/` で直した（`docs/archive/` の中の記録の絶対パスは、読み取り専用の扱いのまま残すと決めた）。

## TODO-181 ゴールデンテスト・差分テスト・参照インタプリタの穴

- 状態: 未着手
- 出どころ: [later-issues の 17](sources/later-issues.md)、[later-issues の 18](sources/later-issues.md)、[later-issues の 19](sources/later-issues.md)、[later-issues の 28](sources/later-issues.md)、[later-issues の 30](sources/later-issues.md)、[later-issues の 32](sources/later-issues.md)、[later-issues の 35](sources/later-issues.md)、[later-issues の 36](sources/later-issues.md)、[later-issues の 51](sources/later-issues.md)、[later-issues の 85](sources/later-issues.md)、[later-issues の 95](sources/later-issues.md)、[later-issues の 98](sources/later-issues.md)

ゴールデンテストの実行器と、差分テストの道具である参照インタプリタについて、誤りを見逃す箇所と、費用のために検査を外している箇所をまとめる。`src/`・`tests/`・`testdata/`・`skill/` で始まるパスは `crates/benitoite/` を起点とし、ほかのパスはリポジトリの根を起点とする。

- 参照インタプリタの費用（later-issues の 17・35）: `src/refinterp/convert.rs:99-111` の `call_decl` は、組み込みの関数の呼び出しのたびに `roots` の全体を読み直して `opaque` に集め、引数を丸ごと変換用のヒープへ写し、根を積み続ける。長いリストでは呼び出しの回数とリストの長さの積に比例する時間になる。直さずに、`tests/golden.rs:42` の `EXPENSIVE_REFERENCE_CASES` で `list_hof_long` を差分比較から外して避けている（TODO-171）。2026-10-10 に全体の検査でこのケースを差分比較に含めたところ、1 時間 49 分を超えても終わらなかった。要る番号だけを読み、写す量を減らす。直したら、`EXPENSIVE_REFERENCE_CASES` から外すか、全体の検査でだけ比べるかを決める。
- 参照の値の世代（later-issues の 36 の (c)）: `src/refinterp/convert.rs:46` の `RefValue(u32)` は呼び出しの世代を持たず、照合しない。
- 未使用の継続の解放のテスト（later-issues の 18）: `src/refinterp/tests.rs:548-581` は未使用の継続の解放（E-DropRel）を正常な終わりだけで確かめ、582-640 行の escape・実行時エラー・exit の版は継続を含まない。E-EscDropRel・E-ErrDropRel・E-ExitDropRel に当たる場合と、二度目の `resume` の由来の位置の確かめを加える。
- 巻き戻し中の `Stop::Internal`（later-issues の 19。要確認）: `src/refinterp/eval.rs` の巻き戻しの途中の `Stop::Internal` が元の停止を置き換える件と、同じ分岐の行が連続するという前提をコメントか `debug_assert` で示す件。行番号が変わっており、直ったかを確かめていない。
- CLI の報告のテスト（later-issues の 28。要確認）: 並べ替えのテストの空振り、JSON の 1 件 1 行を 2 件以上で確かめること、最後の転送の失敗での `Exited`・`Interrupted` の分岐のテスト。今のテストで確かめていない。
- ベンチマークの差分テストの lines の入力（later-issues の 30）: リポジトリの根の `tools/bench/programs/lines.args.small` の中身はリポジトリの根からの相対パス `tools/bench/programs/lines-small.txt` のままで、`tests/golden.rs:174-176` はベンチマークのディレクトリを基準に入力を作る。VM と参照インタプリタがどちらも読み込みに失敗し、失敗どうしが一致して通る。引数をディレクトリを基準にした `lines-small.txt` に直すか、基準のディレクトリをリポジトリの根にする。
- 差分テストの作業ディレクトリ（later-issues の 32）: `tests/golden.rs:529-576` は一つの `with_directory` の中で `differential::compare` を呼び、`tests/golden/differential.rs:78-110` は VM の実行の後に同じディレクトリで参照インタプリタを走らせる。ファイルを書くテスト（`testdata/io/c12-write-append.bnt`、`l40-file-*.bnt` など）があるので、VM が残したファイルが参照の側の結果に影響しうる。参照の側の前に基準のディレクトリを作り直す。ほかに、外した件数を `eprintln` で示すだけで `--nocapture` でないと見えないこと、書き直し（bless）で `.exit` のない新しいテストを起こせないこと（`golden.rs:309-310` が missing .exit で誤りにする）が残る。
- 集計の表示と脱糖のテストの空振り（later-issues の 51）: (a) check のテストのコア IR の検査の結果を `Summary::record` に `Comparison::Matched` で渡すので、「core IR/differential: N matched」に差分比較をしていない件数が混ざる（`tests/golden.rs:599-603`・85-90・200-204。`check_core_matched` と二重）。(b) `src/ir/desugar/tests.rs:106-150` の `result_types_follow_function_boundaries_and_stay_out_of_other_positions` は、Other の位置の `with`、`handle` の本体、節の `return` の最後の式が型の変わらない式のままで、位置を誤っても落ちない。最後の式を `if`・`match` にする。
- fmt のゴールデンの古い `.formatted`（later-issues の 85）: `tests/golden/formatting.rs:74-90` は元のファイルごとに `.formatted` を引くだけで、元のない古い `.formatted/` のファイルを誤りにしない。書き直しのときだけ消す（同 134-156 行）。
- L40 のゴールデンの細部（later-issues の 95）: 相対パスの program の解決（ADR 0327 の決定 4）のゴールデンがない（`"./` を使う `Process` のテストが見当たらない）。`testdata/io/l40-clock-handled.bnt:10` の `Clock.sleep(1000000)` は、ハンドラが効かない退行のとき約 17 分止まるので、数秒にする。同 5 行の `import Benitoite.Trait` は未使用の疑いがある（要確認）。`testdata/stdlib/l40-collections.bnt:1`・`testdata/io/l40-file-paths.bnt:1` の spec の印「01-07 IO が起きる時期と順序」は、テストの内容との結び付きが弱い。
- 受け入れ例の細部（later-issues の 98 の Linux 以外の分）: `testdata/acceptance/process_shell.bnt:9` は `sort` には `LC_ALL=C` を付けたが、`tr` には付けていない。`fmt_comments.bnt`・`test_replaces_effects.bnt` に、提案された spec の印（01-02「ドキュメントコメント」、01-06「エフェクトの宣言とハンドラの型付け」）を加えていない（各ファイルの 1 行目の印は一つだけ）。`json_summary.stdout` の "1 orders" の表記がそのままである。Linux での実行は TODO-073 が扱う。

## TODO-185 コレクションとテキスト・データのモジュールの細部

- 状態: 要検証
- 出どころ: [初回リリース版の実装プランの R37](../archive/2026-10-09-implement-first-release/20-tasks/R37-map-and-set.md)、[R36](../archive/2026-10-09-implement-first-release/20-tasks/R36-persistent-vector.md)、[取り込み漏れの調査の B-8](sources/2026-10-09-todo-gap/B-implement-archive.md)、[later-issues の 16・24・25・26・63・72・75・86・87・88](sources/later-issues.md)

初回リリース版のコレクション（`List`・`Map`・`Set`・`Bytes`）とテキスト・データのモジュール（`Csv`・`Json`・`Regex`・`Decimal`）の作業の確認で残した点をまとめる。手順の根拠にした文献の確認、設計書に書いていない振る舞い、上限の確かめの不足、テストの補強を含む。

- 永続コレクションの手順の根拠にした文献の事実を、一次資料で確かめる。作業の文書は次の三つを【要検証】とし、実装はこれらを引いている（`crates/benitoite/src/runtime/map/tree.rs:105-107`、`crates/benitoite/src/runtime/list/rrb.rs:14`）。03-06 は計算量を定めているが、根拠の文献を確かめた記録がない。出どころ: [R37](../archive/2026-10-09-implement-first-release/20-tasks/R37-map-and-set.md)、[R36](../archive/2026-10-09-implement-first-release/20-tasks/R36-persistent-vector.md)、[取り込み漏れの調査の B-8](sources/2026-10-09-todo-gap/B-implement-archive.md)。
  - `Map`・`Set` の重みで平衡させる木のパラメータ (3, 2) が、挿入と削除の後に平衡を保つこと（Hirai・Yamamoto 2011）。
  - 集合の演算の計算量 O(m log(n/m + 1)) が、join に基づく方法で得られること（Blelloch・Ferizovic・Sun 2016）。
  - RRB 木の連結の詰め直しの条件 `E_MAX = 2`（Bagwell・Rompf）。
- 永続マップの平衡のテストを補強する。`crates/benitoite/src/runtime/map/tests.rs:355` 以降は、100 万要素の整列した構築と、大きい集合と小さい集合の union までを確かめる。10^4〜10^5 個の昇順・降順の挿入と順の削除、大きさの偏った組の split・difference のテストは見当たらない。join の平衡の回復は一次資料の証明の範囲外なので、テストで補う。出どころ: [later-issues の 25](sources/later-issues.md)。
- 永続マップの小さな点（要確認）。`find`・`remove`・`split` が空の木で鍵の型でない値を拒まない、`build_sorted` に並びの `debug_assert` がない、`tree.rs` のコメントの根拠を設計書の節で示していない、`make` の `vec![]` の確保。どれも確かめていない。出どころ: [later-issues の 26](sources/later-issues.md)。
- `Map.toList`・`keys`・`values` が、要素を集めて確保した後に長さの上限を確かめる（`crates/benitoite/src/builtins/funcs/map.rs:39-42`・`420-431`。`list::from_values` で確かめる）。02-09「一つの操作で作る値の大きさの上限」の規約のとおり、先に `CheckedLen` で確かめる。出どころ: [later-issues の 24](sources/later-issues.md)。
- 集合の演算と Decimal の表現。`Set.union`・`intersection` は、同じ数で表現の違う Decimal（`1.0m` と `1.00m`）について第一の集合の表現を保つ（`crates/benitoite/src/runtime/map.rs:107`・`117`、テストは `runtime/map/tests.rs:158`）。03-06 は `Map.set`・`Set.add`・`Map.fromList` などで元の鍵を保つと書くが、集合どうしの演算は明記していない。明記するかを決める。軽微な点として、モデルとの比較に表現の違う Decimal の鍵を混ぜる、長い `match` の分岐、テストの鍵の補助を共有のモジュールに分ける、は確かめていない。出どころ: [later-issues の 72](sources/later-issues.md)。
- `Bytes.slice` は部分を写して新しい値を作る（`crates/benitoite/src/builtins/funcs/bytes.rs:124` 以降。コメントは実装プランの 10-15 の表現の例外とする）。共有の表現（同じ領域を共有し、開始位置と長さだけを変えた値）にして O(1) にするかを、測定の後に決める（実装プランの 10-15 も測定の後に決めるとしていた）。設計書を今の実装に合わせる直しは、この項目とは別に行う。軽微な点として、`bytes.rs:322` の `copy_from_slice` を zip の形に、`bytes.rs` のテストの `as` を `try_from` に直す。出どころ: [later-issues の 75](sources/later-issues.md)。
- `Csv.formatWith` は ASCII でない区切りを受け付ける（`crates/benitoite/src/builtins/funcs/csv.rs:62`・`66-70` で ASCII を確かめない）が、`parseWith` は ASCII の区切りに限る。このため、`formatWith` で書いたものを `parseWith` で読み戻せない場合がある。03-08 も `parseWith` の制限だけを書く。`formatWith` も ASCII に揃えるかを設計者に確かめる。出どころ: [later-issues の 63](sources/later-issues.md)。
- `Csv` の解析の寛容さ。csv-core が `"abc"x` を `abcx`、`a"b` を `a"b` として誤りにしないことを、03-08 に書いていない（`csv.rs:424` のテストは `a"b` を受け付ける振る舞いを固定している）。テストの穴（`""` の組や引用符の中の CR LF が出力の 4 KiB の境界をまたぐ場合、`parseWith` の `ParseError.line`、`[]` の行の後の BOM のフィールド）は確かめていない（要確認）。出どころ: [later-issues の 88](sources/later-issues.md)。
- `Json` の誤りの報告の細部。入力の終わりで起きた誤りの `column` が、入力によって揃わない（`crates/benitoite/src/builtins/funcs/json.rs:534` のテストは `"[1,\n"` を 2 行 1 列として今の振る舞いを固定している）。03-08 は `line`・`column` の数え方だけを定め、入力の終わりの誤りの位置を定めていない。`1e400` と構文の誤りが両方あるときの報告の順も定めがない。`1e-400` が `0.0` になることをテストで固定していない。出どころ: [later-issues の 86](sources/later-issues.md)。
- `Decimal.fromFloat` の例。01-04 の表は「`Float.toString(x)` の表記が表す数」とだけ書き、指数の表記になる Float（`1e21`、`1.5e-7`）の小数の桁数が読み取れない（実装は指数を展開した後の桁数で、それぞれ 0 と 8）。例を一行足すかを決める。出どころ: [later-issues の 16](sources/later-issues.md)。
## TODO-186 CLI の道具（`fmt`・`test`・`skill install`）の細部

- 状態: 未着手
- 出どころ: [初回リリース版の実装プランの README の「U3・U4 で決めたこと」「U4 の作業の文書で見つかった点」](../archive/2026-10-09-implement-first-release/README.md)、[取り込み漏れの調査の B-6・B-7](sources/2026-10-09-todo-gap/B-implement-archive.md)、[later-issues の 74・78・82・89・99](sources/later-issues.md)（99 は `is_ours` 以外の点）

初回リリース版の CLI の道具（フォーマッタ、テストの実行、Skill の導入）について、作業の確認で見つかり、直さずに残した点をまとめる。決めていない振る舞い、設計書からの近似、軽微な不具合の疑いを含む。

- `benitoite test` のテストを並行に動かすか。06-04 は処理系がテストを並行に動かしてよいとし、並行にしても報告の順序を変えない規則を定めている（06-04「テストの実行」「結果の報告」）。初回リリース版の実装は、一つずつ順に動かす。並行に動かすかを決める。出どころ: [取り込み漏れの調査の B-6](sources/2026-10-09-todo-gap/B-implement-archive.md)。
- `Assert` の失敗の報告で、型の分からない値の構成子を `<constructor #タグ>` と書く（`crates/benitoite/src/runtime/assert.rs:209`）。型パラメータを持つ補助の関数の中の `Assert.equal` などで起きる。06-04 はこの形を定めていない。利用者と LLM には読めない表示なので、構成子の名前を示す手段（実行時に型の情報を持つなど）を検討するかを決める。初回リリース版はこのままとした。出どころ: [取り込み漏れの調査の B-7](sources/2026-10-09-todo-gap/B-implement-archive.md)。
- `Assert` の報告の値の書き出しに大きさの上限がない。`render_value`（`assert.rs:162-187`）は、共有した構造を持つ値を辿って文字列を伸ばし続けるので、共有の構造によって指数的に長くなりうる。10-18・02-10・06-04 に上限の定めがない。上限（切り詰めの規則）を決める。あわせて、表記のテストに `Byte`・`Bytes`・中身を見せない型と、制御文字・双方向制御文字（`assert.rs:798-801` で逃がす）の場合を加える（`runtime/assert/tests.rs` に該当のテストが見当たらない）。出どころ: [later-issues の 74](sources/later-issues.md)。
- テストの実行が `Returned` で終わったとき、書き出しの失敗の報告（`run.reports`）を捨てる（`crates/benitoite/src/cli/tools/test_runner/mod.rs:591`）。捕らえる出力先では起きないとされた。起きないと確かめるか、報告するかを決める（要確認）。出どころ: [later-issues の 89](sources/later-issues.md)。
- フォーマッタが、空の行の規則を `BlankBefore` で近似している。06-03「空の行」の「構文の中身の最初の行（コメントだけの行を含めて数える）」を、理由を持たない `BlankBefore` で近似したままである（`crates/benitoite/src/cli/tools/formatter/print.rs:326-330`）。中身が空の構文の中のコメントと、中身の最初の文が `with` の文の場合に 06-03 から外れうる。外れる場合を確かめ、必要なら `BlankBefore` に理由を加える。出どころ: [later-issues の 78](sources/later-issues.md)。
- `fmt` の細かい点。出どころ: [later-issues の 82](sources/later-issues.md)。
  - `fmt_file` がソースを複製する（`crates/benitoite/src/cli/tools/formatter/mod.rs:178` の `text.clone()`）。大きさの上限の 256 MiB に近いファイルでは、メモリが倍になる。
  - `read_source`（`formatter/mod.rs:222-238`）は普通のファイルかを確かめないので、名前付きパイプや `/dev/stdin` を直接与えると読み終わらない。普通のファイルだけを読むかを決める。
  - リンクのテスト（`crates/benitoite/tests/fmt_command.rs:253-267`）は、一時ファイルをリンクの先のディレクトリに作り、両方に残らないことを確かめていない。
  - 軽微な点として、`cli/tools/args.rs:120` は `entry.file_type()` で足りる、`print.rs:296` の `Some(_line)` は `Some(_)` で足りる。
- `skill install` の細部。出どころ: [later-issues の 99](sources/later-issues.md)。
  - `cli/tools/args.rs:43`・`65` の `ToolCommand::Skill` の分岐は CLI から通らない経路で、成功を返す。誤りを返すか、型で除く。
  - HOME が存在しないパスや相対パスのとき、導入先のディレクトリを `create_dir_all` で作ってしまう（`crates/benitoite/src/cli/tools/skill/mod.rs:95`）。ホームが存在するかを確かめる規則を、設計書で決めていない。
  - 導入の途中で残った別の pid の `.benitoite.install-*`・`.benitoite.old-*` を消さない（`skill/mod.rs:105`・`120` は自分の pid の名前だけを扱う）。

## TODO-214 `with` で束縛したリソースで、`close` の待ちが取り消されたときの解放の失敗

- 状態: 未着手
- 出どころ: 改造 `docs/archive/2026-10-12-TODO-182_183_184-test-reliability-and-io-details/` の `reviews/2026-10-12-X4/report.md` の所見 2、`decisions.md` の R6 とその注記
- 関連: TODO-027

01-10「解放の失敗」は、`with` で束縛していないリソースについて、`close` などの関数が解放を待つ間に呼んだタスクが取り消されたときは、その解放の失敗を捨てると定める（TODO-184 の改造で足した）。`with` で束縛したリソースで同じことが起きたときの扱いは定めていない。今の処理系は、`close` の呼び手が受け取るはずだった失敗を、`with` の解放の失敗（実行時エラー `ReleaseFailed`）として報告する。TODO-184 の改造より前からある振る舞いである。

作業 X4 のレビューは、この振る舞いを次の流れで説明した（`crates/benitoite/src/vm/unwind.rs` の `ReleaseStart::AlreadyReleased` の分岐。行番号は改造の時点で 166-176 行）。

1. `with` で束縛したリソースに `close`（`File.closeWriter` など）を呼ぶ。`close` は状態を解放中にし、解放の仕事の完了を待つ。
2. 待つ間にタスクが取り消され、`with` の解放の枠が解放を始めようとする。解放は進行中なので、枠も完了を待つ。
3. 解放の仕事が失敗で終わり、失敗をリソースの記録（`release_failure`）に置く。
4. 枠が起きて解放を始め直すと、リソースは解放済みになっている。枠は記録した失敗を取り出し、取り消しの解放の失敗として報告する。

この流れは、失敗する偽の解放を持つリソースで、実行の形 Direct で確かめた（`ReleaseFailed "fake flush failure"`）。改造では、`with` の版の筋書きをテストから外した。Request の形は確かめていない。

決めること:

- 捨てるか、`with` の解放の失敗として報告するか。捨てれば、`with` で束縛していないリソースの規則と、`close` を呼んだリソースは解放済みとみなす【方針】に揃う。報告すれば、取り消しの解放の失敗を実行時エラーにする 01-10 の第一段落に揃い、失敗を見落とさせない。
- 解放の失敗の記録を、解放を待った側のうち先に取りに来た方が受け取る今の仕組みを改め、待つ側ごとに区別するか。
- 決めた振る舞いを、Direct と Request の両方の形で、VM を通す再現テストで固定する。
