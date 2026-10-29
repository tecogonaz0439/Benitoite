# RV-R30.2: 六つの File 操作の登録と実行の独立レビュー

2026-10-29。対象は R30.2 の未コミットの差分と `r30.2/` の results.md・棚卸し・実ソースの記録・ログ。作業用のディレクトリは書き換えず、scratchpad の target で CLI をビルドして入力を通した。Lean の `TargetTable` の `ioIn` と `clauseIxIn` と照合した。再現の入力は `r30.2/rv-probes/` に写した（実ファイルを読み書きする `r1.bnt`・`r2.bnt` の絶対パスは `<probes>`（この入力のディレクトリ）に伏せた）。

結論: 取り込んでよい。重大0・中0・軽4。

## 指摘

| 番号 | 重さ | 箇所 | 問題 | 修正案 |
|---|---|---|---|---|
| 軽1 | 軽（テストの不具合） | `tests/runtime_builtins.rs` の `file_in_operations_use_the_retained_path_and_preserve_values_and_errors` の冒頭 | `Path::new(env!("CARGO_MANIFEST_DIR")).join("../../target").canonicalize().unwrap()` は、`CARGO_TARGET_DIR` を別の場所へ向けた新しい作業ディレクトリでは `<repo>/target` がないので panic する（コードを読めば確定する）。canonicalize は `checkPathIn` が `..` を含むパスを拒否するために要る | 既存の `golden.rs`・`external_signals.rs` に合わせて `env!("CARGO_TARGET_TMPDIR")` を使い、`create_dir_all` の後で canonicalize する |
| 軽2 | 軽（記録） | `r30.2/handler-inventory.md` | 棚卸しが `crates/benitoite/` の下だけで、`tools/skill-eval/tasks/write_tests/reference.bnt` の `loadsFromFile`、01-07 の `portIsRead`、01-11 の 118 行付近、06-04 の `readPortReadsNumber`、`docs/reference/benitoite.md` の `countWordsCounts` がない。どれも一節だけの部分ハンドラで `uses File.Read` を残しており、直す必要はない | 棚卸しに crates の外の位置と、部分ハンドラであることを確かめた旨を加える |
| 軽3 | 軽 | `skill/SKILL.md` の 184〜186 行 | 六操作の API と、射影・拡大を `bind` で書く案内の二段落が「## Tests」の先頭に入り、テストの定義の段落が三段落目へ下がった。内容は正しい（bind の形、symlink・特殊ファイルを隔離しないこと、Read 13 操作と Write 16 操作は File.bnt と一致） | API と bind の段落を「## Checked values and local builders」へ移し、Tests にはハンドラの操作数の一文だけを残す |
| 軽4 | 軽（任意） | `builtins/table.rs` の `builtin_range_positions` と `builtin_range_signature` | 六操作の名前の列を二回書いている。食い違えば `builtin_signature_valid`・`io_shape_valid` と `decls.rs` の内部の診断で止まるので、黙って Top に落ちることはない | 六つの名前を一つの const にまとめる |

## 問題がなかった点

- 健全性: 注釈のない関数値を範囲の違う二つの PathIn で呼ぶ形（E0401）、`if` の合流と一つのリストへの混在（E0401 と E0519）、`List.map` へ lambda・部分適用・関数値を渡す形（E0519 notCovered か E0454）、lambda を二度呼ぶ形、効果変数を持つ汎用の apply、パイプ、Option から取り出す形、`Task.all`、部分適用した関数値を狭い引数で呼ぶ形は、どれも宣言の上限の外への読み書きを拒否した。ハンドラの節では、保護本体に同じ名前の原子が複数ある場合・旧の Top の操作が混ざる場合・効果変数を経る場合に節の添字は狭く選ばれず、被覆で受けた `/data/**` の本体では `/data/**` になる。節の中で旧の `File.readText` を呼ぶと外側の unknownSource で拒否される。Lean の `clauseIxIn` と一致し、Lean が拒否して Rust が受理する入力は見つからなかった。実行時は `checkPathIn` が `..`・`.`・`//`・相対パスを拒否し、範囲の外へのファイルは作られなかった。保持したパスは絶対パスなので、旧の実処理の `working_directory().join(path)` で置き換わらない。
- 登録と型: 名前の一致で `Single{Path,0}` を旧の前置きの `TopTargeted` より先に判定する。`parameterize_builtin_signature` は引数と原子をともに `rvar 0` にし、形が合わなければ内部の診断を出す。署名・効果・操作名は Lean の `TargetTable` の `ioIn` の六項目と一致する。`file_io.rs` の四経路は通常の脱糖と IR の再検査まで通す。
- 実行と保持: `retained_path` は `checkPathIn` の表現と `pathInValue` と同じ検査をする。旧の本体へそのまま委ね、待つ前に PathBuf と内容を所有へ移すので言語の値は worker へ渡らない。旧の String の入口は変わらず、新旧の操作の節は互いの呼び出しを捕えない。H と H-full を要らないとした判断（PathIn の表現・根・障壁・安全点を変えていない）に同意する。
- ハンドラ: 操作数は File.bnt と一致し、完全な Read の共通の節の文字列二つ（`remaining_clauses`、`READ_CLAUSES`）は追随している。節の引数の射影と拡大の表と L50.4 中3 の受理・拒否はテストの入力と一致する。
- 書き方: 例とテストの射影は `bind` の右辺に書き、型の範囲を実パス・symlink・特殊ファイルの隔離として説明していない。
- 規約・設計書・記録: 本番に `unwrap`・添字・`as` はない。設計書（01-06・01-07・02-08・02-09・03-07・07-01・07-04）は実装と一致し、作業の ID を新しく書いていない（07-04 に既存の `L40.3d` が残り、R30.5 が整理する）。`changed-inputs.json` のハッシュは今のファイルと全件一致し、変更の時刻は W-R の開始より前。`work.json` は check.sh 自身の終了 0 と外側の 471.565 秒を記録している。
- 範囲外の参考: `check --report=json` の `aggregateEffects.expanded` は `File.Write` を範囲なしで表示する（表示と JSON は R40 の担当）。実ファイルのテストは範囲が Top で、狭い範囲での検査から実行までは入力 r1 で確かめた。

## 対応（取りまとめ）

| 指摘 | 対応 | 置き場所 |
|---|---|---|
| 軽1〜軽4 | 採る | R30.2b |
| 参考の二点 | `aggregateEffects.expanded` の範囲の表示は R40 へ、狭い範囲の実行のテストは R30.5 で加えるかを判断する | R40・R30.5 |
