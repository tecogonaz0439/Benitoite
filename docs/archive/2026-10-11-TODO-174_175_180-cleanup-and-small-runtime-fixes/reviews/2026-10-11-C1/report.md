# 作業 C1 のレビュー

対象: コミット 8cc202f（親は 272110d）。`git show` と `git diff` だけで読んだ。cargo は走らせていない。ファイルは書き換えていない。行番号は 8cc202f のもの。

## 結論

処理系の振る舞いを変える誤りと、消したものへの参照の残りは見つからなかった。heap の内部の層の不変条件と型の寿命の印も保たれている。要修正は 1 件で、テストのコメントの正しさの問題である。ほかは任意の指摘で、多くは改造の文書への記録の漏れである。

## 指摘

### 1. 新しいコメントが、確かめている理由を正しく書いていない（要修正・軽微）

- 場所: `crates/benitoite/src/vm/tests.rs:996`（`invalid_operands_and_unknown_instructions_stop_and_disassembly_lists_all`）
- 問題: コメントは「型の合わない Unit のレジスタを命令が拒み」と書く。しかし並べた命令は、すべてがレジスタの型で止まるわけではない。
  - 例えば `LAZY`（`vm/dispatch/lazy.rs:21-37`）は、レジスタを読まずに `bx` 番の proto（ここでは main）から閉包を作り、その値をレジスタ 0 に書いて進む。止まるのは後の別の理由による。
  - テストが実際に確かめているのは「この不正なプログラムで、各命令が panic も成功もせずに `Stop::Internal` で止まること」だけである。
- 直し方: コメントを「検証器を通していない不正な被演算子のプログラムでも、命令は panic せず、処理系の不具合（`Stop::Internal`）として止まる（AGENTS.md「失敗を panic で表さない」、設計書 02-08「実行の手順」）」の趣旨に直す。テスト名の `invalid_operands` は、このコメントの趣旨と合うので、そのままでよい。

### 2. 計画と違えた三点が、改造の文書に記録されていない（任意。オーケストレータの作業）

- `decisions.md:41` と `plan.md:59` は、`exprs.rs` のコンマの分岐を「到達しない分岐」として消すと書いている。実際は、ガード（`patterns_ext.rs:48-` の `if 式`）の後のコンマで到達する。実装はこの分岐を残し、テストを加えた。
- `plan.md` の C1 の 4 は、`Stage1StateServices` を `#[cfg(test)]` にすると書いている。実際は本番の `vm/dispatch/tasks.rs:425` が使うので、`BorrowedStateServices` として本番に残した。
- `plan.md` の C1 の 2 にある `bundled-licenses` の clippy は、生成物 `THIRD_PARTY_LICENSES` がないので走らせなかった。
- 直し方: 改造の判断の記録（`decisions.md` の「決まったこと」か、作業の結果の節）に、三点とその理由を書き足す。

### 3. 移行の名残が、C2 の一覧に入っているか確かめる（任意）

次の三つは、コメントではないか、範囲外として残したものである。C2a・C2b の対象の一覧に入っているかを確かめ、入っていなければ加えるか、docs/todo の項目にする。

- `crates/benitoite/src/runtime/run.rs:452` の内部の不具合の文言 `"stage 1 execution ended with pending requests"`。終了状態 3 の説明なので、変えても診断の契約には触れない。
- `crates/benitoite/src/refinterp/convert.rs:504` のテスト名 `round_trips_preserve_stage_one_values_and_heap_kinds`。
- 参照カウントの名残。`runtime/heap/stats.rs:15-17` の `HeapConfig::reuse` の説明（「再利用は参照カウントの方式だけが行う」）と、`stats.rs:66` の `HeapFaultKind::CountMismatch`。報告も候補に挙げている。

### 4. `entry_effects_and_uses_duplicates` の `@test` の場合は何も確かめていない（任意）

- 場所: `crates/benitoite/src/typeck/effects/tests.rs:419`
- 問題: `typeck/effects/declarations.rs:108` の E0415 の判定は `main` にだけかかる。そのため `@test function sample() ... uses Assert.Check` は、`@test` がなくても診断なしになる。
  - 直す前の版も、`r.main = None` で同じ形だったので、契約を弱めたわけではない。
- 直し方（どちらか）:
  - 行を消す。
  - 意図を「`main` 以外の関数は Assert のエフェクトを書いてよい」と明示し、`@test` を外した形にする。

### 5. `tools/bench/README.md` の記録の形の説明がわずかに不正確（任意）

- 場所: `tools/bench/README.md:112`
- 問題: 「`summaries` に各組の `wall`・`run` の中央値…を記録」とある。しかし `legacy` の組には `run` の要約がない（`gate.py:101-105` は空の配列を飛ばす）。
- 直し方: 「`legacy` の組は `wall` だけ」と一言加える。

### 6. `gate.py` の記録に、比べた版の情報がない（任意）

- 場所: `tools/bench/gate.py:106`
- 問題: JSON は、ラベルがどの実行ファイルを指すか（パス、コミット）を残さない。
  - 直す前の版も同じだった。
  - 07-02 の測定記録の方針（処理系の版、計算機の情報を添える）に照らすと、後で JSON だけを見て比べ直すときに困る。
- 直し方: `{"versions": {label: path}, "revision": run.git_revision(), "system": run.collect_system_info()}` を加える。補足 9 が任意として挙げていたものである。
- あわせて任意: 各回の版の順を固定せず回ごとに入れ替えると、順による偏りを減らせる（`gate.py:92-95`）。

### 7. 小さな体裁（任意）

- `crates/benitoite/src/vm/verification_tests.rs:410,479`: `reuses == 0` を消した跡に空行が残っている。消してよい。
  - 消したアサーションは、272110d の時点でも `reuses` を増やす箇所がなく（`stage1_support` が読むだけ）、つねに真だった。契約は弱まっていない。
- `crates/benitoite/src/bytecode/codegen/tests.rs:251`: 引く節が「02-08「実行の手順」」になっている。出力を保つ回帰のテストなので、07-03「テストの設計の原則」の方が合う。

## 確かめて問題がなかった点

### 1. 振り分けと heap

- **`ObjRef` の `_epoch`**: 消した読み出しの関数 `epoch()` は、272110d でも呼ばれていなかった。欄は `Epoch<'e>`（`fn(&'e ()) -> &'e ()` の PhantomData による不変の印）のまま残り、`from_raw` と世代付きの構築の両方で初期化している。区間の寿命の制約は変わらない。`#[derive(Debug)]` の欄名が変わるだけで、出力に ObjRef の Debug を使う箇所はない。
- **`Allocation::capacity`**: 読むのは `core.rs:676-687` の毒埋め（`#[cfg(feature = "heap-verify")]` の中）と、`core/tests.rs:435-` の heap-verify のテストだけである。`release` は `class` と `separate_index` だけを使う。構築の 3 か所すべてに同じ cfg を付けている。`heap-per-object` の有無と組み合わせても、局所の `capacity` は使われる。`alloc.rs` の頭の不変条件 A1〜A4 は capacity に触れていない。
- **`CHUNK_BYTES` と `SIZE_CLASSES`**: `CHUNK_BYTES` は `not(heap-per-object)`、`SIZE_CLASSES` は `any(test, not(heap-per-object))` に限った。使う箇所の cfg と合っている。
- **テストだけの補助**: `HeapCore::heap_no` と `HeapCore::tag` を `#[cfg(test)]` にした。本番からの呼び出しはない。欄 `heap_no` は本番で直接読んでいる。`FIELD_BYTES`・`CELL_BYTES`・`DECIMAL_BYTES`、`event::deregister`、`complete_worker` も `#[cfg(test)]` にした。
- **機能の組み合わせ**: `alloc-stats` は `cfg!` の一か所（`cli/mod.rs:736`）だけで使われるので、cfg の組み合わせに影響しない。check.sh と check-heap.sh の組み合わせ（mark-sweep と heap-verify、それに per-object、alloc-stats、gc-stress）は、実装担当が走らせた clippy の組み合わせに含まれる。
- **消した補助と欄**: `Context::stdlib`、`ClauseContext::node`、`pattern_in`、`stub_expr`、`stub_decl`、`push`、`in_table`、text の定数 14 個。どれも 272110d で読む箇所がない。`codegen` の `text::LAZY` と `text::HANDLE` は別のモジュールの定数である。
- **`FieldsKind::ListCell`**: 本番で作る箇所は 272110d にもなかった（`alloc_fields(FieldsKind::ListCell` はテストだけ）。heap のマークと解放にも ListCell の特別な扱いはない。assert、equal、convert のパターンから外しても振る舞いは変わらない。
- **`complete_worker` の文言**: 変えた文言はテストのビルドだけの関数の中にある。比べている `samples.rs:510` も同時に直している。

### 2. 第 1 段の退役

`stage1`・`in_stage1`・`RealIo`・`stage1_io`・`Stage1StateServices`・`rc_*`・`reuses`・`remeasure`・`secb6`・`stage1_bench`・`ListCell`・`C05-SWITCHOVER` を検索した。範囲は src・tests・examples・fuzz・tools・scripts・.claude・docs/design・docs/reference・AGENTS.md で、`tools/bench/results/` と `tools/syntax-measure/` は除いた。

- 消したものへの参照の残りはない。
- 残る `TestIo` は、`vm/dispatch/test_support.rs` のものと、テストの中の局所の型だけである。
- `SECB6` のコメント（`runtime/io/resources.rs:52`、`vm/dispatch/tasks.rs:786`）は、消した道具ではなく対策の名前を指す。直すかは C2 の範囲である。

### 3. gate.py

- `bench_run` の引数の形 `--trigger-factor=100 --io-mode=direct -- SCRIPT ARG` は、`examples/bench_run.rs:30-62` と合っている。
- `run_nanos` は `run.parse_bench_stats`（行の頭の `bench-run: ` を読み、要る項目を確かめ、欠ければ `RuntimeError`）で読み、失敗したら止める。
- 温める実行でも、出力と統計を確かめている。
- 交互の実行、出力の照合、`--legacy` の扱い（`BENITOITE_DEV_IO_MODE=direct` は legacy だけに渡す）、`--version` の形とラベルの重複の検査、JSON の `samples` と `summaries`（`median` と `min`）は正しい。
- 07-02「性能の関門」の、本測定は中央値、短い測定は最小値で比べる手順として使える。
- `import run` は、スクリプトのディレクトリが `sys.path` の先頭に入るので動く。

### 4. README と設計書

- README の節の消し方と名前の付け替え（「入力の調整」と、それを引く文）、legacy の版の作り方（`LEGACY_BUILD/release/benitoite`）は正しい。
- 消した節名を引く箇所は残っていない。
- 07-02 は gate.py と実行の段の時間を述べるだけなので、直す必要はない。

### 5. テスト

- **標準ライブラリのテスト**: `STDLIB` の全本を `SourceKind::Prelude` で読み、診断なしとモジュールの文書を確かめる。直す前の二つのテストの和より広い。本数を固定していないのもよい。
- **`entry_effects_and_uses_duplicates`**: 束縛の差し替えをやめ、実際のエフェクトの名前で E0415 の位置と注記、Network の許可を確かめる。直す前の内容を保っている（`@test` の場合は指摘 4）。
- **改名した二つのテスト**: `rewritten_eval_programs_keep_outputs` は出力の照合を保ち、段の命令の制限だけを外した。VM のテストは、直す前の「第 1 段でない 19 命令」と同じ並びを明示した。逆アセンブルは全命令に広げた。
- **ガードの後のコンマのテスト**: 誤りが 1 件であること、位置、矢印の期待、次の分岐への回復を確かめる。分岐に到達することの根拠にもなる。
- **長いテスト 2 件**: Ctor の 2 欄の連なり（次は欄 1）と 1 欄の入れ子の形で、Rust のスタックを使い切らないことを確かめる契約を保つ。miri では短い深さで走る。
- **`r04_reuse_checks_contract...`**: 誤った候補を `Func` に替えても、種類の誤りを確かめる契約は同じである。

### 6. 改名、AGENTS.md、規約

- **改名**: `FixedIo` と `BorrowedStateServices` の改名に漏れはない。`fixed_io` は `#[cfg(test)] pub(crate) mod` になった。
- **`BENITOITE_DEV_PANIC` の行**: 許可の実際の位置（`cli/mod.rs:707,713`、`runtime/io/services.rs:263`）と合っている。
- **AGENTS.md の表**: 表の前の文、`src/lib.rs` の行の削除、テストのモジュールの行の文言はどれも一貫している。表の写しは、設計書・スクリプト・スキルのどこにもない。
  - 表にない `ir/desugar.rs:354` の `#[allow(clippy::panic)]` は、C1 の前からあり、TODO-175 の範囲である。
- **規約**:
  - 新しい行に `unwrap` などはない（テストを除く）。
  - 個別の `#[allow(dead_code)]` は足していない。
  - 新しいコメントに作業の ID や保管した実装プランの番号はない（`README.md:256` の L41 は既存の文）。
  - 新しいコメントが引く設計書の節（02-03「誤りからの回復」、02-08「値の表現」「組み込みの関数の呼び出し」、02-09「メモリの管理」「IO 実行器」）は、どれも実在する。
- **`C05-SWITCHOVER.md`**: 内容を変えずに改造のディレクトリへ移した。読むテストや道具はない。
