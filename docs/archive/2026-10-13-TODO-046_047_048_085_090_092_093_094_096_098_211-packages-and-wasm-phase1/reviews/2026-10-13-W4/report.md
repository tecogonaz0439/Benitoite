# W4 のレビュー（0e5e2371「Add Wasmtime and check `@external` declarations (W4)」）

対象: `git show 0e5e2371`。確かめには別の worktree（0e5e2371、`CARGO_TARGET_DIR=scratchpad/pkg/rev-target`）を使い、主の作業ディレクトリは変えていない。行番号は 0e5e2371 のもの。パスは `crates/benitoite/` を省く。

走らせたもの: `cargo test --lib external`（19 件成功）、`--test external_signals`（3 件成功。ただし後述の H1）、`testdata/external/`・`testdata/packages/`・`testdata/fmt/` のゴールデン（成功）、`scripts/check.sh --base 28d1d7f7 --dry-run`、CLI での試し（シンボリックリンクで外へ出る形、入れ子の型、型の別名、利用者の `Pair`、本体の回復、`run`・`test`、パッケージの根での開発、`path` のない依存）。

## 総評

決定どおりに実装されている。Cargo の機能は `runtime`・`component-model`・`std`・`cranelift` だけで `default-features = false`（Q1）。`engine_config()` は燃料と epoch を有効にし、シグナルは既定のまま（Q13）、`wasm_backtrace_max_frames(None)` は非推奨の `wasm_backtrace(false)` の代わりとして妥当である。凍結した型の変更は `ResolveOutput::externals` の欄だけで、Q14 の了承の範囲に収まる（`BindingKind`・`FnDecl` はコメントだけの変更）。外部の関数を含まないプログラムでは、`check_externals` が表が空なのを見て直ちに返り、`Engine` を作らず、ファイルシステムも読まない（`external/check.rs:98`）。脱糖の追加の判定も表の先頭を見るだけである。したがって、外部の関数を持たない `check` の費用は増えない。

パスの検査は堅い。CLI で、ファイルのシンボリックリンク（`wasm/x.wasm -> ../../out/x.wasm`）とディレクトリのシンボリックリンク（`wasm -> ../out`）のどちらも E1003 になることを確かめた。大文字小文字の照合、`.`・`..`・空の段・隠し名、パッケージでの `wasm/` の制限も単体テストが押さえている。型の照合では、入れ子（`Option[List[Pair[Integer, String]]]`）、合成の型の別名（`type Rows = List[Pair[…]]`）、利用者の `data Pair` を標準ライブラリの `Pair` と取り違えないこと（E1010 になる）を CLI で確かめた。一つのコンポーネントは検査の間に一度だけ読み、コンパイルする（`check.rs:220` の `BTreeMap`。テストあり）。`check` ではコンパイルだけを行い、インスタンス化しない。

主な指摘は、シグナルのテストが `target/` の有無に依存すること（H1）、W4 の作り直しで `path` のない依存に余計な誤りが出るようになった退行（M1）、パッケージを自分の根で開発しているときに `wasm/` の制限が効かないこと（M2）、03-01 の Wasmtime の大域の状態の記述が macOS の実際と合わないこと（M3）である。

## H（取り込みの前か直後に直す）

### H1. シグナルのテストが、リポジトリの `target/` がないと失敗する

- 場所: `tests/external_signals.rs:61-65`
- 問題: 子のプロセスは作業用のディレクトリを `CARGO_MANIFEST_DIR/../../target/wasm-signal-probe-<pid>` に `create_dir` で作る。親の `target/` がなければ作れずに panic し、親の側は「probe did not become ready」で失敗する。`CARGO_TARGET_DIR` を別の場所にしたとき（worktree での作業、このレビューの手順、CI のよくある構成）や、`cargo clean` の後に `target/` がないときに起きる。レビューの worktree では、別のテストがたまたま `target/l13-unit` を作っていたので通った。
- 再現: worktree で `target/` を退けてから `CARGO_TARGET_DIR=<外> cargo test -p benitoite --test external_signals` → `interrupts_after_wasm_call_have_exit_status_130 ... FAILED`（`external_signals.rs:65:37` の panic）。
- 修正案: 統合テストに Cargo が与える `env!("CARGO_TARGET_TMPDIR")` の下に作る（`create_dir_all` を使う）。リポジトリの中に書かないことにもなる。

## M（W5 の前に直すか、設計者に尋ねる）

### M1. `path` のない依存で、E0904 に続いて意味のない E0916 が出る（退行）

- 場所: `modules/load.rs:205-215`、`modules/package.rs:82-91`（`dependency_location`）
- 問題: 作り直す前の `load.rs` は、`path` の欄がなければ黙って `continue` していた（欄がないことは E0904 が報告する）。共有の関数 `dependency_location` は欄がないときに `InvalidInput` の誤りを返すので、読み込みがそれを E0916 として報告するようになった。san_benito の今の HEAD でも同じである。
- 再現:
  ```text
  dependency Fuzzy
    hash "sha256:00"
  end dependency
  function main() -> Unit
    ()
  end function
  ```
  `benitoite check main.bnt` → E0904「the dependency `Fuzzy` has no `path`」に続き、`E0916: cannot read the dependency `Fuzzy` at ``` / note: invalid file or path` が出る。
- 修正案: `dependency_location` の戻り値を `Option<io::Result<…>>` にするか、欄の取り出しを呼び出し側に戻して、欄がなければ両方の呼び出し側で飛ばす（`dependency_roots` では E0904 で止まっているので飛ばしてよい）。E0904 だけが出ることをゴールデンか `modules` の単体テストで固定する（今は捕まえるテストがない）。

### M2. パッケージを自分の根で開発・テストしているときは `wasm/` の制限が効かず、依存として使われたときに初めて E1003 になる

- 場所: `external/check.rs:188-212`（`ModuleKind::Package` のときだけ `package` を渡す）、03-10「コンポーネントのパス」
- 問題: `package.bnt` を持つディレクトリを根として `check`・`test` すると、そのモジュールは根のモジュールとして扱われ、根の任意の `.wasm`（例えば `x.wasm` や、隠し名でない `rust/target/…/x.wasm`）を指せる。同じパッケージを別のプログラムが依存として読むと、同じ宣言が E1003 になる。パッケージの作者は自分のテストで誤りに気付けない（設計原則 1・2）。
- 再現: `selfpkg/` に `package.bnt`（`package Self`）、`Calc.bnt`（`@external("wasm", "x.wasm", "add")`）、`x.wasm`、`main.bnt`（`import Calc`）を置き、`selfpkg/` で `check main.bnt` → 終了状態 0。`user/main.bnt` から `dependency Self path "../selfpkg"` で読むと E1003「outside the package's wasm directory」。
- 修正案: R5 の文言（根のモジュールは根から）どおりの実装なので、設計者に尋ねる。推す案は「根に `package` のブロックを持つ `package.bnt` があるとき、根のモジュールにもパッケージと同じ `wasm/` の制限を当てる」。採らないなら、03-10 にこの差を書き、`benitoite package` の検査（W6）で報告する。

### M3. 03-01 の Wasmtime の大域の状態の記述が、macOS（既定の Mach ports）の実際と一致しない

- 場所: `docs/design/03-interop/03-01-library-structure.md` の「使う Rust のクレート」の箇条（「トラップのためのプロセス全体のシグナルの処理器と、macOS の Mach の例外の処理」「Wasm に入るスレッドの代替シグナルスタック」）
- 問題: wasmtime 49.0.2 の既定（`macos_use_mach_ports = !cfg!(miri)`、`src/config.rs:312`）では、macOS は `sigaction` の処理器を登録せず（`runtime/vm/sys/unix/signals.rs:34` が Apple で Mach ports なら使わないと assert）、代わりに次を行う（`runtime/vm/sys/unix/machports.rs`）。
  - 例外を処理する**プロセスの寿命のスレッドを一つ起こす**（`thread::spawn(|| handler_thread())`）。
  - **`pthread_atfork` の子の処理器を登録**し、fork した子で Wasmtime を使うと panic する（`lazy_per_thread_init` の assert）。
  - Wasm に入るスレッドごとに `thread_set_exception_ports` を設定する。`sigaltstack` の付け替えは Linux（シグナルの経路）だけで起きる。
  AGENTS.md「大域の状態」は依存の大域の状態を 03-01 に書くよう求めるので、スレッドと `pthread_atfork` が抜けているのは記述の不足である。今の処理系は `Process.run` で fork の後に Wasmtime を使わないので、実害は見当たらない。
- 修正案: 箇条を OS ごとに分ける。Linux は SIGSEGV・SIGBUS・SIGILL・SIGFPE の処理器（前の処理器へつなぐ）と `sigaltstack` の付け替え、macOS は例外のスレッド・`pthread_atfork`・スレッドごとの例外ポート、と書き、出典の行を添える。

## L（ついでに直すか、後の作業で）

### L1. シグナルのテストの中断の部分は、Wasmtime の干渉をほとんど確かめていない

- 場所: `tests/external_signals.rs:157-163`
- Wasmtime は `SIGINT`・`SIGTERM` に触れない（49.0.2 のソースに登録がない）ので、この部分は Wasmtime の変更では落ちない。中断は `Clock.sleep` の間に届き、Wasm の実行中ではない。一方、スタックあふれの部分は意味がある。macOS では Wasm に入ったスレッドに Mach の例外ポートが付くので、Rust の guard page の検出がそのポートを経ても働くことを確かめている（Linux のシグナルの経路は、このマシンでは確かめられない）。
- 修正案: テストの冒頭のコメントに、確かめる範囲（macOS は Mach ports の経路、中断は Wasmtime の処理器との順序の回帰の見張り）を書く。Wasm の実行中の中断は W5 の epoch のテストで確かめる。

### L2. 依存の根の作り直しの I/O の失敗が、処理系の不具合（終了状態 3）になる

- 場所: `external/check.rs:128-134`
- 根の `canonicalize` と `dependency_roots` は、読み込みの段で一度成功した操作を繰り返すので普通は失敗しない。ただし、その間にディレクトリが消えるなど環境の都合で失敗すると、「this is a bug in the implementation」と報告する。
- 修正案: 失敗を E1001（`reason`）として宣言の位置に出すか、読み込みの段が求めた根を `LoadOutput` の外で受け渡せる形を W5 で検討する。今のままにするなら、コメントに「読み込みと照合の間の変化だけで起きる」と書く。

### L3. 診断の文言の細部

- E1002 で `..` や `.` の段は「hidden」の注記「a name that starts with `.` is not part of a package」も付く（`external/path.rs:24-30`。`..` も `.` で始まるため）。根のモジュールの `..` に「パッケージ」の説明が出て紛らわしい。`malformed` のときは `hidden` の注記を付けない。
- E1010 で利用者が宣言した `Pair` を使うと、型の全体（`Option[List[Pair[Integer, String]]]`）を示し、注記は「Pair を渡せる」と言う。受け渡せない内側の型（利用者の `Pair`）を `{ty}` に示すと分かりやすい（`types::plan` が失敗した部分の型を返す形）。
- E1007 の `{found}`・`{expected}` は `text::count` の「2 items」で、引数の数としては「2 parameters」が自然である。
- Wasmtime の検証の誤りは E1004「is not a WebAssembly component」と「failed to parse WebAssembly module: lowered parameter types …」になる。コンポーネントの形をしているが中身が不正、の場合として受け入れてよいが、注記の型板で「the component is invalid: {reason}」とすると読み手に親切である。

### L4. 01-02 の文法で `ExternalFnDecl` がどの規則からも参照されない

- 場所: `docs/design/01-spec/01-02-syntax.md` の「初回リリース版の文法の全体」（`ExternalFnDecl` の行）と、その前の本文の一文
- `Decl = [ "public" ] FnDecl | …` は `ExternalFnDecl` を含まず、関係は本文の一文でだけ示す。生成した Skill の文法（`skill/references/grammar.md`）を読む LLM には、孤立した規則に見える。
- 修正案: `Decl` に `| [ "public" ] ExternalFnDecl`（`@external` を付けたときだけ）を足すか、`AttrDecl` の規則の近くに注を置く。

### L5. 用語集と spec の印

- `docs/design/00-overview/00-04-glossary.md:159-160` の「外部の関数」「core、std」は「初回リリース版は外部の関数を呼ぶ層を持たない」のままである。W4 で宣言と照合を、W5 で呼び出しを入れるので、W5 か W8 で直す。「コンポーネント」「WIT」「world」は用語集にない（記憶の「用語の原語と用語集の候補」の決まり）。
- 01-02 に新しく足した見出し「外部の関数の宣言」に対応する `// spec: 01-02 外部の関数の宣言` の印を持つテストがない（`testdata/external/root/main.bnt` は「属性（初回リリース版）」）。どちらかのゴールデンの印を足すか替える。

### L6. 導入の手順の並び

- `docs/reference/install.md` の「Build from source」で、「You also need a C compiler」が「You need a Rust toolchain」の前に来ている。「also」が先に出るので順を入れ替える。

### L7. 未信頼のコンポーネントのコンパイルの費用

- `check` が、読み込んだコンポーネントを Cranelift で必ずコンパイルするようになった。上限は 256 MiB のファイルの大きさだけで、悪意のある大きなコンポーネントの検査に長い時間とメモリを要しうる（R7 で受け入れた方式の帰結）。パッケージのハッシュの上限は 128 MiB なので、根のモジュールのほうが緩い。W5 の測定のときに、コンポーネントの大きさの上限を下げるか（例: 64 MiB）を docs/todo の項目にする。

### L8. `check.sh` が `scripts/release/about.toml` を分類しない

- 場所: `scripts/check.sh` の `classify`（0e5e2371 と san_benito の HEAD）
- `check.sh --base 28d1d7f7 --dry-run` は `== stop: files outside every kind: scripts/release/about.toml` で止まる（報告のとおり）。san_benito のコミットにはまだ分類がない（主の作業ディレクトリの Z2 の未コミットの変更に `scripts/release/*) select_check licenses` の行があるので、Z2 で直す途中と見える）。Z2 で取り込むことを確かめる。

## 確かめて問題がなかった点

- 機能と依存: `wasmtime = "=49.0.2"`、`default-features = false`、四つの機能だけ。`wat = "=1.261.0"` は dev-dependency だけで、本番の経路は `Component::from_binary` だけを使う。
- ライセンス: `deny.toml` の `allow` と `scripts/release/about.toml` の `accepted` は同じ並び（`Apache-2.0 WITH LLVM-exception`・`Zlib`・`Unicode-3.0` を追加）。03-01 の許可の一覧と理由、C のファイルの唯一の例外（Q12）、05-01 の C コンパイラ、導入の手順の C コンパイラ、00-03 の自作と既存の線引き（R7）が揃っている。
- 属性の規則と回復: E0809〜E0814 の各誤り、`@deprecated`・`public` との併用、属性の順に依らない E0813、本体を書いたときの回復（E0814 の後に続く宣言を正しく読む。CLI で `@test`・コメント・`///`・`public` が続く形も確かめた）。
- 照合: 取り込みが空でなければ E1005（WASI の注記つき）、world の直下だけを探す（インスタンスの中の関数は E1006）、非同期は今の機能構成では Wasmtime が検証で拒み E1004 になる（E1011 は実際には届かない。報告のとおり）、R8 の表（`Bytes` と `List[Byte]` の区別、`Result` の片側の省略、`Result[Unit, Unit]`、`Pair`・`Triple`、別名、入れ子）。対応のない WIT の型（`s32`・`f32`・`record` など）は E1008・E1009 で WIT の綴りを示す。
- テストの実行器と整形: `run`・`test` は脱糖で「external functions are not supported yet」（終了状態 3）になる。W5 までの過渡の状態として計画どおり。`fmt` は照合せず、本体のない宣言を正しく整形する（ゴールデンあり）。ゴールデンの整形の性質の検査は `.wasm` を `MemoryFs` に渡し、意味のある比較になっている。`testdata_components_match_their_text` は `.wat` と `.wasm` の一致を確かめる。
- AGENTS.md の規約: `unsafe`・`unwrap`・`expect`・添字は本番のコードにない。大域の状態を加えていない。文言は `diag::codes` と `external::text` にあり、処理系の不具合の説明だけを直に書いている。コメントに作業の ID はない。テストのモジュールの `#[allow]` は許された箇所である。
- 03-10 は章の形（目的と範囲・前提・仕様）に従い、今の実装（宣言と照合だけ）を書いている。02-01・02-04・02-10・01-07 の変更は実装と一致する。
