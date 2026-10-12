# Y11 のレビュー

対象: コミット `390bb52e`（Require an absolute existing HOME for skill install and tidy the CLI tools）。`git show` だけで読み、ファイルも検査も走らせていない。照らした文書は、plan.md「作業 Y11」、decisions.md の Q4・R9〜R11、study.md「TODO-186」の 4・6・7 節、AGENTS.md、test-audit、japanese-tech-writing である。

## 総評

計画（調査の作業 C・D）の点はすべて実装されており、要修正の誤りは見つからなかった。

- HOME の確かめ（Q4・R9）: `install`・`uninstall` の両方の `Scope::User` の分岐で、空、相対、存在しない、ディレクトリでない、の四つを拒む。`metadata` はリンクを辿るので、ディレクトリへのシンボリックリンクは通り、壊れたリンクやファイルへのリンクは拒まれる。検査の後で `target_dirs` を回すので、拒んだときは何も作らない。`--project` は HOME を見ない。
- 文言と終了状態: 文言は `text::HOME_NOT_DIRECTORY` に置き、`fill_template` と `escape_terminal_controls` で埋めている（パスに `{reason}` が含まれても再置換されない）。誤りは終了状態 1（`EXIT_FAILURE`）で、06-06 の終了状態の箇条と合う。
- `run.reports`（R11）: `step_end` を読み直した。`Returned`・`MainError` で `reports` が空でなくなるのは、`flush_failure` が最後の転送の `WriteFailure::Io` を足したときだけである。テストの実行器の出力先は `Capture` だけ（`test_runner/mod.rs:404-405`）なので、失敗するのはミューテックスが毒されたときに限られる。書き出し用のスレッドが panic したときは `WriteFailure::Panicked` で `EndKind::Internal` になり、`failure_of` に来ない。コメントの理由づけは正しい。説明の文字列 `"output capture failed"` は処理系の不具合の説明なので、AGENTS.md「文言」のとおり `text` に載せていない。`Interrupted` への変換（`run.rs` の最後）の後は呼び出し側が報告を書くので、そちらの報告も捨てていない。
- fmt の複製の廃止: `text` を `Source::new` へ移し、閉包の中で `sources.get(file).map(Source::text)` から借りている。`write_diag` も同じ `&sources` を借りるだけで、所有権の衝突はない。`get` が `None` のときは処理系の不具合（終了状態 3）になる。振る舞いは変わらない。
- `PathTool` の導入、`entry.file_type()` への置き換え（Unix の `DirEntry::file_type` はリンクを辿らない）、リンクのテストへの一時ファイルの確認の追加は、いずれも計画どおりで正しい。
- 06-06 と CHANGELOG: 06-06 の HOME の箇条、名残の箇条、終了状態の箇条と、CHANGELOG の Changed の行は、実装と食い違わない。名残の箇条は、調査の補足（エージェントが `.` で始まるディレクトリを読まないことは確かめていない）に従い、理由を「別の実行の一時ディレクトリを壊さない」にとどめている。06-01 は 06-06 に委ねているので変えなくてよい。`docs/reference/install.md` は HOME の条件に触れていないので、食い違いはない。

以下の指摘は、推奨と軽微だけである。

## 指摘

### 1. 【推奨】HOME の検査のテストが、テストのたびにリポジトリの中にディレクトリを作る

- 場所: `crates/benitoite/src/cli/tools/skill/tests.rs` の `user_scope_rejects_home_that_is_not_an_absolute_existing_directory`（`relative_existing` の行）
- 問題: `Temp(relative.0.with_extension("existing"))` を `fs::create_dir` で作る。単体テストの作業ディレクトリはパッケージの根なので、テストを走らせるたびに `crates/benitoite/relative-home-benitoite-skill-invalid-home-<pid>-<nanos>.existing/` がリポジトリの中にできる。`Drop` で消すが、次の三つの問題が残る。
  - テストのプロセスが SIGKILL やタイムアウトで止まると、追跡されないディレクトリがリポジトリに残る。
  - クレートのディレクトリが書き込めない環境（読み取り専用の取り出しなど）では、`create_dir` の `unwrap` でテストが失敗する。
  - 存在しない相対パスの行（`relative`）も、検査が退行すると、パッケージの根の下に `.claude/skills/...` を作る。計画は後始末を置けばよいとしているので受け入れられるが、次の修正案を採れば、この危険もなくなる。
- 修正案: 相対パスを、作業ディレクトリから一時ディレクトリへ `..` で上る形で作る。例えば `std::env::current_dir()` の成分の数だけ `..` を重ね、`temp.0` から根を除いたもの（`strip_prefix("/")`）をつなぐ。こうすると、`relative-existing` には `temp.0` の下の既存のディレクトリ（たとえば `temp.0.join("rel-existing")`）を、`relative` には `temp.0.join("rel-missing")` を指す相対パスを使える。`is_absolute()` は偽のままで、作るディレクトリも、退行したときに書き出される先も一時ディレクトリの下に収まる。後始末の `Temp` を相対パスに使う必要もなくなる。`getcwd` は物理的なパスを返すので、macOS の `/tmp`→`/private/tmp` のリンクにも左右されない。

### 2. 【推奨】ディレクトリへのシンボリックリンクの HOME を受け入れることを確かめるテストがない

- 場所: `skill/tests.rs`（HOME の表のテスト）、06-06 の 79 行「ディレクトリへのシンボリックリンクは辿ってよい」
- 問題: 06-06 はリンクを辿ると書き、実装は `std::fs::metadata` で辿る。しかし、リンクの HOME で導入できることを確かめるテストがない。`symlink_metadata` に書き換える退行（`bnt_files` と同じ書き方に揃えようとする変更は起こりうる）は、ほかのテストで捕まらない。壊れたリンクを拒むことも確かめていない。
- 修正案: `#[cfg(unix)]` のテストを一つ足す。`temp.0.join("home-link")` を `temp.home()` へのシンボリックリンクにして `install` を走らせ、終了状態 0 で、`claude(&temp.home())` に書き出されたことを確かめる。あわせて、存在しない先へのリンクを HOME にして、終了状態 1 と `HOME_NOT_DIRECTORY` の文になることを表に一行足す。前者は「存在するディレクトリなら受け入れる」側の境界であり、作成時の関門の「捕まえる退行」を示せる。

### 3. 【軽微】06-06 の HOME の箇条の言い方

- 場所: `docs/design/06-tooling/06-06-agent-skills.md` 79 行
- 問題:
  - 「何も書き出さず・消さず、ディレクトリも作らずに」は、動詞の連用形を中黒でつないでおり読みにくい。
  - 「ディレクトリへのシンボリックリンクは辿ってよい」は、許可の形で書いているが、処理系は常に辿る。設計書は今の実装を書く決まりなので、振る舞いとして断定した方が明確である。
- 修正案: 「…存在するディレクトリでないときは、何も書き出さず、消さず、ディレクトリも作らずに誤りを報告し、終了状態 1 で終える。`HOME` がシンボリックリンクのときは、リンクの先がディレクトリかを確かめる。」

### 4. 【軽微】`metadata` の失敗の理由を区別しない

- 場所: `crates/benitoite/src/cli/tools/skill/mod.rs` の `run_skill`（`std::fs::metadata(&home).is_ok_and(...)`）
- 問題: 親のディレクトリを読めない（`EACCES`）、リンクが循環している（`ELOOP`）などの場合も、「存在するディレクトリの絶対パスでない」と報告する。利用者は原因を取り違えうる。ただし、どの場合も導入を止めるという判断は正しく、頻度も低い。
- 修正案: 今回は直さなくてよい。直すなら、`metadata` の誤りが `NotFound` 以外のときに、`REMOVE_FAILED` と同じ形で `{reason}` を添える文を足す。

### 5. 【軽微】テストが期待する文を、文言の定数から作らず直書きしている

- 場所: `skill/tests.rs` の `user_scope_rejects_home_that_is_not_an_absolute_existing_directory` の `assert_eq!(result.err, format!("error: the home directory `{}` ..."))`
- 問題: 隣の `user_scope_without_home_reports_no_home` は `text::NO_HOME` を使うのに、こちらは英文を写している。文言を直すと二か所を直すことになる。パスの中の `{path}`・`{reason}` が再置換されないことを確かめる意図は、定数から作っても保てる。
- 修正案: `text::HOME_NOT_DIRECTORY.replace("{path}", &escaped)` で期待する文を作る（`str::replace` は置き換えた値を再び走査しないので、パスの中の `{reason}` はそのまま残る）。直書きを保つ意図（文言の退行を捕まえる）があるなら、そのことをコメントで一行書く。

### 6. 【軽微】`bnt_files` のコメントが、リンクを辿らない理由を失った

- 場所: `crates/benitoite/src/cli/tools/args.rs` の `bnt_files`（`entry.file_type()` の直前のコメント）
- 問題: 前のコメントは「`symlink_metadata` はリンクそのものを見る」と、リンクを集めない仕組みを示していた。新しいコメントは規則（辿らず集めない）だけを書き、`entry.file_type()` がなぜその規則を満たすかを書いていない。`metadata` や `path.is_dir()` に書き換える退行を読み手が見落としやすい。
- 修正案: 「`DirEntry::file_type` はリンクを辿らず、リンクそのものの種類を返す。」を一文足す。

### 7. 【軽微】ソースが表にないときに `FormatError::Verify` を借りている

- 場所: `crates/benitoite/src/cli/tools/formatter/mod.rs` の `fmt_file`（`"source missing from source table"`）
- 問題: `FormatError::Verify` は整形の結果の検証の失敗を表す型である。表を引けない場合を同じ型で返すと、どちらも処理系の不具合（終了状態 3）になるので振る舞いは正しいが、型の意味からは外れる。
- 修正案: 今のままでよい。気になるなら、閉包の外で `let Some(source_text) = sources.get(file).map(Source::text) else { … internal_diagnostic … }` と先に引いてから、閉包にはその `&[u8]` を渡す。こうすれば `FormatError` を借りずに済み、閉包も短くなる。

## 確かめたが問題のなかった点

- 空の HOME: `tools.rs` で空を `None` にしており、`run_skill` の `filter` は重複するが、`run_skill` を直接呼ぶテスト（`Some(PathBuf::new())`）のために要る。どちらも `NO_HOME` になる。
- `uninstall` の挙動の変化（存在しない絶対パスの HOME で、今まで 0 だったものが 1 になる）は、CHANGELOG の行に書かれている。
- 拡張した `user_scope_without_home_reports_no_home` と新しいテストは、`temp.home()`・`temp.work()` が空のままであることも確かめており、「何も作らない」を外から観察している（test-audit の作成時の関門に合う）。
- `failure_of` にテストを足さないことは、調査 4.3 の判断（毒されたミューテックスを作るには本番の要らない差し込み口が要る）のとおりである。
- コメントは日本語で、根拠の設計書の節を示しており、保管した実装プランや作業の ID を引いていない。
