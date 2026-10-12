# 作業 C2 のレビュー

- 対象: git worktree `Benitoite-C`（ブランチ `impl/TODO-194-C2`、基準 97cd364）のコミットしていない変更。`crates/benitoite/src/base/file_read.rs`（新規）、`src/base/mod.rs`、`src/modules/mod.rs`、`src/cli/tools/formatter/mod.rs`・`tests.rs`、`src/cli/tools/skill/mod.rs`・`tests.rs`、`src/cli/tools/test_runner/report.rs`、`tests/cli_process.rs`、`tests/fmt_command.rs`、`tests/test_command.rs`。
- 観点: 依頼文の 1〜4（正しさと安全、制御文字の逃がし、テストの質、規約）。
- 走らせた検査: `cargo test --test fmt_command --test cli_process --test test_command`（34 件成功。FIFO の 2 件はそれぞれ 0.4 秒）、`cargo test -p benitoite --lib -- base::file_read cli::tools`（54 件成功）。加えて、worktree のデバッグのビルドと、基準の版のビルド（`Benitoite/target/debug/benitoite`）で、`cat m.bnt | benitoite check /dev/stdin` を比べた（所見 1）。

## 結論

所見 1 の扱いを決めれば取り込んでよい。実装は依頼文と補足のとおりで、読み込み・fmt の拒否・逃がしの処理に誤りは見つからなかった。所見 1 は、入口のスクリプトを管（標準入力・プロセス置換）から読めなくなる、記録していない互換性のない変更である。実装の誤りではなく D-2 の決定の帰結なので、直すか、CHANGELOG と設計書に書いて受け入れるかを、オーケストレータか設計者が決める。所見 2 以降は直さなくても取り込める。

## 確かめたこと

- 開いてから確かめる順: `read_regular_file`（`base/file_read.rs` 17〜32 行）は `RDONLY | NONBLOCK | CLOEXEC`（`no_follow` なら `NOFOLLOW`）で開き、開いた記述子の `metadata()` で `is_file()` を確かめてから読む。確かめた後の差し替えで止まる窓はない。
- `O_NONBLOCK` と普通のファイル: Linux・macOS の普通のファイルの `read` は `O_NONBLOCK` を無視する。例外は所見 5 に書いた（どれも稀で、起きても止まらず E0101 になる）。
- 上限 + 1: `read_limited` は `take(limit + 1)` で読み、`limit` が `u64` に収まらないときは `u64::MAX` にする。単体テストが読み手の位置を見て、上限 + 1 より先を読まないことを確かめる。
- E0101 と size limit: `RealFs::read_file` は最大で `MAX_SOURCE_BYTES + 1` バイトを返し、`modules/load.rs` の `check_size`（`size > file_limit`）が今の「size limit」の理由を返す。普通のファイルでないときは `io::Error`（`InvalidInput`、文は `file_read::text::NOT_REGULAR`）が `error.to_string()` を通って今の E0101 の注記に入る。fmt の `read_source` も上限の超過で今の `SOURCE_TOO_LARGE` を返す。
- fmt の拒否: 0600 の一時ファイルを `create_new` で作る → その記述子の uid と、リンクを辿った先の `target` の `std::fs::metadata` を比べる → uid、所有者の書き込みの許可（`mode & 0o200`）、`nlink() > 1` の順で拒む。拒んだときは `PermissionDenied` の誤りにして既存の失敗の経路に乗せるので、一時ファイルを消し、元を変えず、注記 `reason` に `text::OTHER_OWNER` などの文が入る（`io::Error::new` の `to_string()` は文だけを返す）。`--check` は `replace_file` を呼ばないので拒まない（CLI のテストが直接のパスとリンク経由の両方で確かめる）。一時ファイルの uid と比べるので、所有者を写像するファイルシステム（macOS の「所有権を無視」など）でも両方が同じ値になり、誤って拒まない。
- E0125 の説明の文: 「It refuses to replace a read-only file, a file with more than one hard link, or a file owned by another user.」の三つは、拒む三つの場合と一致する。「owned by another user」は、作った一時ファイルの所有者（実行した利用者の実効 uid）との比較であり、文と合う。「read-only」と「所有者の書き込みの許可がない」の差は所見 6 に書いた。
- root で走らせたとき: 拒む判定は許可のビットと uid の比較だけで、`access` の結果を使わないので、0444 のテストは root でも通る（root でも 0444 を拒む）。
- skill: `is_ours` は `symlink_metadata` で普通のファイル（リンクでない）を確かめ、`NOFOLLOW` 付きで開き、1 MiB を超えたら・UTF-8 でなければ `false` にする。`write_failed`・`remove_failed` は `fill_template` になり、パスの中の `{reason}` を展開しない（テストで確かめる）。`run_skill` で逃がした `path` と、`write_failed` などが中で逃がすパスは別の経路なので、二重に逃がす箇所はない。
- 制御文字: `text_line`・`text_failure` の中で逃がし、`json_test` に渡す `file` は元のまま。テストが JSON を読み戻して ESC が残ることを確かめる。skill の 5 種類の行と fmt の「would reformat」も逃がす。
- テスト: FIFO のテストは、別のプロセスのもの（`cli_process`・`fmt_command`）が 5 秒で子を kill して失敗し、プロセスの中のもの（skill）が `recv_timeout` で失敗する。一時ディレクトリを使う。実装者は直す前に 3 件とも時間切れで落ちることを確かめたと報告している（このレビューでは直す前の版を走らせていない）。
- 規約: `unsafe` なし。`unwrap` などはテストのモジュールの中だけ（`file_read.rs` のテストは `#![allow(clippy::unwrap_used)]` を理由のコメント付きで書く）。文言は各モジュールの `text` に置く。新しい `#[allow]` は表の範囲の中である。

## 所見

### 1. 入口のスクリプトを管から読めなくなった（記録していない互換性のない変更）

- 重さ: 直すべき（直すか、書いて受け入れるかの判断を要する）
- 場所: `crates/benitoite/src/modules/mod.rs` 139〜145 行（`RealFs::read_file`）。入口のファイルも `RealFs` で読む（`pipeline.rs` 152 行、`cli/mod.rs` 519 行、`test_runner/mod.rs` 523 行）。
- 問題: 前は `std::fs::read` だったので、`cat m.bnt | benitoite check /dev/stdin`、`benitoite run <(curl ...)` のように、入口のスクリプトを FIFO（管）から読めた。今は `error[E0101]: cannot read file /dev/stdin` / `note: not a regular file` で終了状態 2 になる（基準の版のビルドは終了状態 0。両方を走らせて確かめた）。`test` も同じである。study.md の D-2 は「普通のファイルでなければ入出力の誤りを返す」と決めたが、入口を管から読む使い方への影響は検討の記録にない。設計書 06-01 は入口に管を使えるとは書いていないので、仕様の違反ではないが、CHANGELOG の「Incompatible changes」に載っていない。
- 直し方の案（どちらか）:
  - (a) 受け入れる: CHANGELOG の「Incompatible changes」に「`run`・`check`・`test` のスクリプトのパスとモジュールは普通のファイルに限る。FIFO・デバイスは E0101」を足し、06-01（スクリプトのパス）と 02-04 にも一文ずつ書く。
  - (b) 入口だけ管を許す: import で探したモジュール（悪意のあるリポジトリが FIFO を置きうる、D-2 の本来の懸念）は普通のファイルに限り、コマンドラインで直接与えた入口は FIFO も読む。FIFO と分かったら `rustix::fs::fcntl_setfl` で `NONBLOCK` を外してから読む（`NONBLOCK` のままだと、書き手がいてデータがまだないときに `EAGAIN` で失敗する）。ただし `ModuleFs::read_file` のシグネチャは凍結されているので、入口かどうかを渡す経路の設計が要り、作業が大きくなる。直接与えた FIFO で止まるのは `cat` と同じ振る舞いでもある。
  - 推奨は (a)。(b) にするなら別の TODO にする。

### 2. `replace_file` の doc コメントが拒む場合を書いていない

- 重さ: 直すとよい
- 場所: `crates/benitoite/src/cli/tools/formatter/mod.rs` 263〜265 行
- 問題: 「同じディレクトリの一時ファイルに書き、元のファイルの許可の設定を写してから、名前の変更で置き換える」とだけ書き、0600 で作ることと、三つの場合に置き換えずに E0125 を返すことを書いていない。
- 直し方の案: 「一時ファイルは 0600 で作る。元のファイルの所有者が実行した利用者と違う・所有者の書き込みの許可がない・固いリンクが二つ以上あるときは、置き換えずに E0125 を返す（`replacement_refusal`）」を足す。

### 3. fmt の `text` に足した三つの定数に `///` がない

- 重さ: 直すとよい
- 場所: `crates/benitoite/src/cli/tools/formatter/mod.rs` 37〜39 行（`READ_ONLY`・`HARD_LINKS`・`OTHER_OWNER`）
- 問題: 同じ `pub mod text` のほかの定数は `///` で用途を書いている。実装の規約（公開の項目に `///`）にも合わない。
- 直し方の案: 「E0125 の注記 `reason` に入れる、置き換えを拒んだ理由」と一行ずつ書く。

### 4. skill のリンク・大きすぎるファイルのテストが誤りの文を確かめていない

- 重さ: 直すとよい
- 場所: `crates/benitoite/src/cli/tools/skill/tests.rs` 472 行・479 行（`install_refuses_symlinked_and_oversized_skill_files`）
- 問題: 終了状態 1 と元が変わらないことだけを確かめる。終了状態 1 はほかの書き込みの失敗でも出るので、`is_ours` が `false` を返した（`NOT_OURS`）ことまでは確かめていない。
- 直し方の案: FIFO のテストと同じく `assert_eq!(result.err, line(text::NOT_OURS, &dir))` を足す。

### 5. `O_NONBLOCK` と普通のファイル・開くことの副作用

- 重さ: 記録だけ
- 場所: `crates/benitoite/src/base/file_read.rs` 18〜24 行
- 問題: 次の場合は、普通のファイルでも `read` が `EAGAIN` を返しうる、または開くこと自体に副作用がある。どれも止まらずに E0101 になるか、直す前から同じなので、今回は直さなくてよい。
  - Linux 5.15 より前の強制ロック（mandatory locking）のかかったファイル、`O_NONBLOCK` をそのまま扱う FUSE のファイルシステム。`EAGAIN` は `read_to_end` が再試行しないので E0101 になる。
  - デバイスを指すパス（リンク）を与えると、`metadata` で弾く前に一度開く。テープの巻き戻しなど開くことに副作用のあるデバイスがある（直す前も開いていた）。端末を開くときは `OFlags::NOCTTY` を足すと、Linux でセッションの先頭のプロセスが制御端末を得ることを防げる（費用は一語）。
- 直し方の案: 直さない。足すなら `NOCTTY` だけ。

### 6. 説明の文の「read-only」と判定の規則の差

- 重さ: 記録だけ
- 場所: `crates/benitoite/src/diag/codes.rs` 170 行（E0125 の説明の文）、`src/cli/tools/formatter/mod.rs` 330〜333 行
- 問題: 判定は「所有者の書き込みの許可がない」で、0464（グループは書ける）も拒む。説明の文は「a read-only file」と呼ぶ。所有者の一致を先に求めるので、拒むファイルは実行した利用者（＝所有者）にとって読み取り専用であり、食い違いとまではいえない。注記 `reason` は正確な文（「whose owner has no write permission」）を示す。ACL で書き込みを禁じたファイルは拒まない。
- 直し方の案: 直さない。06-01 と言語リファレンスに反映するときは、「所有者の書き込みの許可がないファイル」と書く。

### 7. 拒む判定と置き換えの間の TOCTOU

- 重さ: 記録だけ
- 場所: `crates/benitoite/src/cli/tools/formatter/mod.rs` 290〜303 行
- 問題: `target` の metadata をパスで読んでから `rename` するまでの間に、別のプロセスが固いリンクを足す・許可を変える・ファイルを差し替えると、判定をすり抜ける。fmt はディレクトリに書ける利用者のファイルを扱う道具であり、同じディレクトリに書ける別の利用者との競合を防ぐ設計ではない（直す前の許可の写しも同じ窓を持つ）。
- 直し方の案: 直さない。設計書に書くなら「判定は置き換えの直前に一度だけ行う」とする。

### 8. 大きなファイルの読み込みで確保が増えうる

- 重さ: 記録だけ
- 場所: `crates/benitoite/src/base/file_read.rs` 39〜40 行
- 問題: 前の `std::fs::read` はファイルの大きさで先に確保したが、`Take` を通した `read_to_end` は大きさの見込みを持たず、伸ばしながら確保する。上限に近い大きなファイルでは、容量が中身より大きくなり、再確保の間は一時的に二つの領域を持つ。
- 直し方の案: 気になるなら、開いた記述子の `metadata().len()` と `limit + 1` の小さいほうで `Vec::with_capacity` する（metadata はすでに取っている）。

### 9. 所有者の判定の単体テストの最後の二つの確かめは意味がない

- 重さ: 記録だけ
- 場所: `crates/benitoite/src/cli/tools/formatter/tests.rs` 552〜553 行（`replacement_refuses_a_different_owner`）
- 問題: `replacement_refusal` はファイルに触れない純粋な関数なので、元の中身とディレクトリの数を確かめても、何も確かめていない（test-audit の「常に通る確かめ」）。
- 直し方の案: 2 行を消す。直さなくても害はない。
