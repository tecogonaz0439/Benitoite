# Z3 のレビュー（c358cf8b「Fix the findings of the W4 review (Z3)」）

対象: `git show c358cf8b`。確かめには別の worktree（c358cf8b、`CARGO_TARGET_DIR=scratchpad/pkg/rev-target`）を使い、主の作業ディレクトリは変えていない（終了後に worktree は削除済み）。パスは `crates/benitoite/` を省く。

走らせたもの: 完了条件の 6 つ（`--lib external` 20 件・`--lib modules` 38 件・`--test external_signals` 3 件・`testdata/external/`・`testdata/packages/` のゴールデン・`spec_examples` 6 件。すべて成功）、`cargo test -p benitoite --lib`（全体）、`cargo test -p benitoite --tests --no-fail-fast`（統合テスト全体）、ゴールデン全体（成功。TCP の 10 件もこの環境では通った）、`skill_docs`、`clippy --all-targets`、`fmt --check`。CLI での再現（M1・M2 の元の手順、R19 の各場合）。Wasmtime 49.0.2 の `signals.rs`・`machports.rs`・`traphandlers.rs`・`config.rs`（`~/.cargo/registry` と GitHub の v49.0.2 の raw を取り寄せて diff し、同一であることを確認）。

## 総評

W4 のレビューの指摘は、指示どおりにすべて直っている。元の再現手順で確かめた。

- H1: worktree の `target/` を消し、`CARGO_TARGET_DIR` を外に置いて `--test external_signals` → 3 件成功。作業用のディレクトリは `rev-target/tmp/` の下に作られ、終了後に消える。
- M1: `path` のない `dependency Fuzzy` → E0904（と、`sha256:00` に対する正当な E0906）だけ。E0916 は出ない。単体テストも足されている。
- M2（R19）: 次の 6 通りを CLI で確かめ、R19 のとおりだった。
  | 根の状態 | 宣言のパス | 結果 |
  |---|---|---|
  | `package.bnt` に `package Self` | 入口と `Calc.bnt` が `x.wasm` | E1003 が 2 件（入口・根のモジュールの両方）、終了状態 2 |
  | 同上 | `wasm/x.wasm` | 成功 |
  | `package.bnt` が `language` だけ | `x.wasm` | 成功（制限なし） |
  | `package.bnt` なし | `x.wasm` | 成功（制限なし） |
  | 別のプログラムが同じパッケージを依存として読む | `wasm/x.wasm` | 成功 |
  | パッケージの下位ディレクトリ `tools/t.bnt` を入口にする | — | 根は入口のディレクトリなので制限なし（R19 の「根の `package.bnt`」の文言どおり） |
  `ModuleKind::Config` は根の設定だけで、依存の設定は `PackageConfig` なので、`check_all` の `root_package` の取り出しが依存の `package` ブロックを拾うことはない。
- M3: 03-01 の記述は 49.0.2 のソースと一致する（Linux の SIGSEGV・SIGILL、x86_64・s390x だけの SIGFPE、SIGBUS は Apple と FreeBSD だけ、`MIN_STACK_SIZE = 64 * 4096` と `SS_DISABLE` の条件、macOS の `macos_use_mach_ports: !cfg!(miri)`、`pthread_atfork`、例外のスレッド、`thread_set_exception_ports`、SIGBUS の処理器と前の処理器への委譲、`traphandlers.rs` の `USE_MACH_PORTS` による `lazy_per_thread_init` の振り分け）。リンクの行番号の 3 つだけがずれている（L1）。
- L2〜L6・L8: 修正を確かめた。E1002 の不正な形のパスに隠し名の注記が付かない、E1007 は `2 parameters`、E1004 は `the component is invalid: …`、E1010 は内側の型、01-02 の `Decl` に `ExternalFnDecl`、Skill の生成物の再生成、用語集の 4 行、導入の手順の順。
- AGENTS.md の規約: 本番のコードに `unwrap`・`expect`・添字・`unsafe` はない。文言は `diag::codes` と `external::text`（`PARAMETER`・`PARAMETERS`）にある。コメントは日本語で、作業の ID を引いていない。CHANGELOG の Unreleased の 3 行は振る舞いと一致する。

新しい指摘は、W4 から続くテストの失敗（M1）と、Codex が報告した一時ディレクトリの衝突（M2）である。どちらも Z3 が入れた不具合ではない。

## H

なし。

## M

### M1. `cargo test --lib` と `--test verify` が、外部の関数のゴールデンで失敗する（W4 から。Z3 も同じ形のケースを足した）

- 場所: `src/bytecode/codegen/tests.rs:66`（`corpus_prototype_entries_use_only_parameters`）、`tests/verify.rs:58`（`golden_programs_and_seeded_single_site_mutations`）。
- 問題: 両テストは `testdata/` の `.bnt` をすべて `check_path` し、検査を通ったものを `desugar_checked(..).unwrap()` する。`testdata/external/root/main.bnt`（W4）と `testdata/external/self-package/main.bnt`（Z3）は検査を通るが、脱糖は外部の関数を持つプログラムを「external functions are not supported yet」で拒む（`src/ir/desugar/decls.rs:14`）。そのため unwrap で panic する。Z3 の親 d73b08b6 でも両テストが同じ理由で失敗することを確かめた。W4・Z3 の完了条件が `--lib external` など絞ったテストだけだったので、誰も気付いていない。`scripts/check.sh` の `rust` の検査（テスト全体）は今の san_benito で失敗するはずである。
- 再現: `cargo test -p benitoite --lib corpus_prototype_entries_use_only_parameters` → `InternalError { stage: "desugar", message: "external functions are not supported yet" }`。名前を出すように一時的に直すと、最初に落ちるのは `testdata/external/root/main.bnt`。`cargo test -p benitoite --test verify` も同じ。
- 修正案: W5 が脱糖で外部の関数を扱うようになれば、自然に解消するはずである（W5 の作業中の差分は `bytecode/` に及んでいる）。W5 の完了条件に `cargo test -p benitoite --lib` と `cargo test -p benitoite --test verify` を明記し、両テストが外部の関数を持つゴールデンを実際に通すことを確かめさせる。W5 の取り込みまでに時間が空くなら、両テストで `checked.resolved.externals` が空でないプログラムを飛ばす暫定の直しを入れる。今後の作業の完了条件にも、絞ったテストに加えて `--lib` 全体を入れることを勧める。

### M2. `modules::hash` の 2 つのテストが同じ一時ディレクトリを使い、並列の実行で `AlreadyExists` になる（Codex の報告した断続的な失敗の原因）

- 場所: `src/modules/hash.rs:491-505`（`real_directory`）、それを使う `editor_lock_links_do_not_block_imports_or_hashes`（515 行）と `real_files_reject_links_and_non_regular_files`（554 行）。
- 問題: ディレクトリ名は `hash-test-<pid>-<SystemTime の ns>` である。macOS の `SystemTime::now()` はマイクロ秒の分解能しかなく（試験のプログラムで 10 万回の連続の読み取りのうち 94,836 回が同じ値、値の下 3 桁は常に 000）、同じプロセスの 2 つのスレッドがほぼ同時に呼ぶと同じ名前になる。`create_dir_all` は既存のディレクトリでも成功するので衝突に気付かず、2 つ目の `create_dir(dir.join("Sub"))` が `AlreadyExists` で panic する。片方が先に `remove_dir_all` すると、もう片方が別の理由で落ちることもある。panic したときはディレクトリが残る（後始末の guard がない）。保存先が `CARGO_MANIFEST_DIR/../../target` なので、`target/` を持たない worktree では、どちらかが先に親を作らないかぎり存在に依存する。
- 再現: `<lib のテストのバイナリ> modules::hash::tests::real modules::hash::tests::editor --test-threads=8` を 100 回繰り返すと 70 回失敗した（`hash.rs:515:46` または `554:46` の `Os { code: 17, kind: AlreadyExists }`）。
- ほかのテスト: 同じ型の名付け（pid と時刻）を持つ `cli/tools/formatter/tests.rs`・`cli/tools/args/tests.rs`・`cli/tools/skill/tests.rs`・`tests/fmt_command.rs`・`tests/test_command.rs` は、テストごとに異なる `tag` を名前に含めており（重複する `tag` は見当たらない）、`formatter`・`args`・`fmt_command`・`test_command` は `create_dir` で衝突を検出する。同じ形の問題は `hash.rs` だけである。別の問題として、`modules/tests.rs:571-574` の `real_fs_matches_memory_for_files_imports_and_missing_modules` は `../../target/benitoite-f05-<pid>` を `create_dir` で作るので、`target/` のない worktree で失敗する（既知の失敗の原因）。
- 修正案: `real_directory` を次の形にする。
  - 名前に、プロセスの中で一意な番号を加える（`static NEXT: AtomicU64` の `fetch_add`。テストのモジュールの中の `static` なので、AGENTS.md「大域の状態」の対象の処理系のコードではない。気になるなら、各テストが自分の名前を `real_directory("editor-lock")` のように渡す形でもよい）。
  - `create_dir_all` でなく `create_dir` で作り、衝突を誤りとして表に出す。
  - 置き場所を `std::env::temp_dir()` にして、`target/` の有無に依存しない。macOS の `/var` → `/private/var` のために、作った後に `canonicalize` する（今の実装もしている）。
  - `Drop` で `remove_dir_all` する guard の型を返し、失敗したときも残さない（`modules/tests.rs` の `Temporary` と同じ形）。
  `real_fs_matches_memory_for_files_imports_and_missing_modules` も同じ補助の関数（`modules` の `test_support` に移す）で作り直せば、worktree での既知の失敗も消える。

## L

### L1. 03-01 の出典のリンクの行番号のうち 3 つが、関数の先頭を指していない

- 場所: `docs/design/03-interop/03-01-library-structure.md` の Linux と macOS の箇条（83・84 行付近）。
- 問題: v49.0.2 の GitHub のソース（crates.io の 49.0.2 と同一）で、`foreach_handler` は `signals.rs` の 72 行、`trap_handler` は 131 行、`sigbus_handler` は `machports.rs` の 133 行である。リンクはそれぞれ `#L79`（SIGFPE の条件の行）、`#L137`（`match` の中）、`#L136`（関数の本体の中）を指す。ほかの 4 つ（`signals.rs#L459`、`machports.rs#L75`・`#L496`、`config.rs#L312`）は正しい。
- 修正案: `#L72`、`#L131`、`machports.rs#L133` に直す（`#L79` を SIGFPE の条件の出典として残すなら、リンクの文言を「SIGFPE の条件」にする）。

### L2. E1010 で、利用者の `Pair` が標準ライブラリの `Pair` と同じ綴りで示され、注記と食い違って見える

- 場所: `testdata/external/unsupported-inner.text.stderr`、`src/external/check.rs` の `unsupported`。
- 問題: 文言は「`Pair[Integer, String]` cannot be passed …」で、注記は「the types that can be passed are … Pair, and Triple …」である。読み手（主に LLM）には、渡せると書かれた `Pair` を渡せないと言われたように見える。W4 のレビューの L3 は内側の型を示すことを求めたが、この場合の曖昧さは残る。
- 修正案: 表示の型が標準ライブラリの型と同名の利用者の型のときは、モジュールの名前で修飾するか、「`Pair` here is the type declared in `main.bnt`, not `Benitoite.Pair.Pair`」のような注記を足す。急がないので W8 などでよい。

### L3. W4 のレビューの L7 が勧めた docs/todo の項目が登録されていない

- 場所: `docs/todo/`（非公開のリポジトリ）。
- 問題: 07-01 に脅威の記述は入ったが、「W5 の測定のときにコンポーネントの大きさの上限（256 MiB）を下げるかを決める」という項目は `docs/todo/` に見当たらない（`256 MiB` で検索して、出てくるのは `sources/` の過去の資料だけ）。Z3 の指示は 07-01 だけを求めていたので、Codex の漏れではない。
- 修正案: オーケストレータが docs/todo に項目を足すか、W5 の計画の測定の項に含める。

## 確かめて問題がなかった点

- L2（W4）の E1001: 単体テスト `directories_lost_after_loading_are_component_read_errors` が、根の消失（NotFound）と依存の根の拒否（PermissionDenied）の両方で、宣言のパスの位置に E1001 を一件だけ出すことを確かめている。依存の根の作り直しの失敗は、依存のモジュールの宣言にだけ影響し、根のモジュールの宣言は続けて照合する。
- `dependency_location` の `Option<io::Result<…>>` 化は、`load.rs` と `dependency_roots` の両方で `None` を飛ばしている。E0904 は構文解析器（`syntax/parser/header.rs:153`）が出すので、06-09 の「構文解析の E0904 だけで報告する」と一致する。
- 03-10・06-09 の R19 の記述は実装と一致する（`package` のブロックがなければ `package.bnt` があっても根全体）。E1003 の注記は根の場合に `package` のブロックの名前（`Self`）を示す。
- `self-package` のゴールデンは `check` で終了状態 0、`self-package-outside` は入口と根のモジュールの両方に E1003。既存の `module_roots_and_package_wasm_boundaries` は `package` のブロックのない `package.bnt` で根全体を使える場合に書き換えられ、R19 の否定の側を押さえている。
- `clippy --all-targets`・`fmt --check`・`skill_docs`（8 件）・ゴールデン全体は成功。
- 主の作業ディレクトリ（mod/W5、Codex の作業中）には触れていない。
