# W6 のレビュー（e425d24f「Add `benitoite package add`, `update` and `move` (W6)」）

対象: e425d24f。パスは `crates/benitoite/` を省く。行番号は e425d24f の時点のもの。detached の worktree（scratchpad/pkg/rev-W6）でビルドし、実際のディレクトリ（scratchpad/pkg/w6rev/）で三つの命令を動かして確かめた。リポジトリのファイルは変えていない。

## 総評

三つの命令は R13・R21〜R26 のとおりに動く。確かめたのは次のとおりである。

- `add` の書き込み先（入口・`package.bnt`・既存の依存のある側）、相対と絶対の `--path`、既存の依存の後への追加。
- 本体・コメント・シェバン・`//!`・BOM・CR LF・末尾の改行なしのファイルの保持。範囲の外がバイト単位で変わらないこと（下の M2 の場合を除く）。
- `update` の一括（`hash` のある依存だけ）と別名つき（`hash` を足す）。エフェクトの差 `+`/`-`、`(not recorded) -> …`、変わらないときに置き換えないこと。誤った `hash`（E0906 の値）の修正。
- `move` の新規作成・既存の設定（`package` のブロックだけ、コメントだけ）・E0925・E0926・E0928・E0915。読み取りだけの入口で失敗したときの巻き戻し。
- 置き換えたファイルの許可の保持（0755 のまま）。結果がどれも `benitoite check` を通り、整形済みの入力は `fmt --check` を通ること。
- 取り込みのあるコンポーネント、取り込みのないコンポーネント、許されないパスの表示。
- 別の依存の `hash` の食い違いがある設定へ追加するときも、新しい依存の E0917・E0914 を報告すること。

`tests/package_command.rs` の 9 件と単体テストの 3 件は通る。

H はない。M は 3 件ある。どれも、06-09 の記述と実装の食い違いか、R24 の前提が成り立たない場合である。

## M

### M1. 型の別名・レコードの欄を通したエフェクトが集計から漏れ、`effects ""` と記録する

- 箇所: `src/cli/tools/package/effects.rs:43-69`（`Item::Alias`・`Item::Record` を読まない）。`signature` は `TypeExpr::Named` の型引数だけを辿り、別名を展開しない（88-99 行）。
- 問題: R24 の理由「トップレベルの関数の型は宣言に書くので結果は同じ」は、関数の型を `type` の別名で書くと成り立たない。公開の関数がコンソールに書く閉包を返しても、報告は `effects: (none)` になり、記録も `effects ""` になる。後でその閉包が `File.Write` に変わっても `update` は差を示さない。契約の見落としであり、設計原則 2 と 06-09 の「契約の確認」の目的に反する。公開のレコードの関数の型の欄も同じく数えない。
- 再現:
  ```text
  deps/words/Value.bnt:
    import Benitoite.Unofficial.IO.Console
    public type Printer = function(String) -> Unit uses Console.Write
    public function printer() -> Printer
      return lambda(s: String) -> Unit
        Console.writeLine(s)
      end lambda
    end function
  $ benitoite package add Words --path deps/words
    effects: (none)          # 記録は effects ""
  ```
  入口から `Value.printer()("hi")` を呼ぶプログラムは `run` で `hi` を出す（型検査を通る）。
- 修正案: 公開の `type` の別名の右辺と、公開のレコードの欄の型も `signature` と同じ走査で集める（多めに数える側に倒す）。別名を展開する案もあるが、パッケージの中の別のモジュールの別名を引く処理が要る。どちらにするにしても、06-09「`benitoite package`」のエフェクトの段落の「公開のトップレベルの関数と公開の型クラスのメソッドの宣言を読む」に対象を足し、単体テスト `public_contracts_include_nested_function_types_and_trait_methods` に別名の場合を加える。

### M2. コメントだけの既存の `package.bnt` への `move` が、設定の全体を整形し直す（CR LF が LF になる）

- 箇所: `src/cli/tools/package/mod.rs:971-983`（`config.module.header.is_empty()` のとき、`config.text.trim_end()` と移す範囲をつないで `format_source` でファイル全体を整形する）。
- 問題: 06-09「`benitoite package`」は「範囲外の字句とコメントは保ち、範囲外の改行が CR LF なら、挿入する範囲にも CR LF を使う」とするが、この経路だけは既存のコメントの部分も整形器を通る。CR LF のファイルは LF に変わる。コメントの字下げや行末の空白など、整形器が変える箇所も変わる。BOM は残る。項目のある設定（`package` のブロックつき）は `edited` の経路を通り、CR LF が保たれる。二つの経路の振る舞いが揃っていない。
- 再現:
  ```text
  package.bnt = "// comment only config\r\n// second\r\n"
  main.bnt    = "...language \"0.0.3\"..."（入口）
  $ benitoite package move main.bnt
  package.bnt → b'// comment only config\n// second\n\nlanguage "0.0.3" ...\n'
  ```
- 修正案: 項目がないときも `edit::range`（項目なしの挿入位置）と `edit::splice` で継ぎ合わせる。項目なしの `range` はシェバンと `//!` の後に挿入するので、そのままでは既存のコメントの「前」に入る。そのため、設定ファイルに限って「最後のコメントの行の後」を挿入の位置にする小さな関数を足すのがよい。プロセスのテストに、コメントだけの設定への `move` の成功（CR LF を含む）を加える（今は失敗して巻き戻す場合しかない）。

### M3. 形の誤った `effects`（E0929）は `update` で直せず、06-09 の「先頭の欄の診断だけでは編集を拒否せず」と食い違う

- 箇所: `src/cli/tools/package/mod.rs:818-850`。仮の版を作るときに古い `hash` だけを取り除き、`effects` は残したまま `validate` を通す。`validate` は対象のブロックの中の E0929 を関係のある誤りとして報告する（553-562 行）。
- 問題: 誤った `hash` は直せるが、誤った `effects` は直せない。06-09:121 は「先頭の欄の診断だけでは編集を拒否せず、誤った `hash` も更新できる」と書く。E0929 は `check`・`run` も止めるので、利用者（LLM）はファイルを手で直すほかない。E0929 の説明もその手順を示さない。
- 再現:
  ```text
  main.bnt:
    dependency Words
      path "deps/words"
      effects "file.read"
    end dependency
  $ benitoite package update Words
  error[E0929]: malformed recorded effects   （終了状態 2、書かない）
  ```
- 修正案: 仮の版で `hash` と同じく `effects` の欄も取り除いてから検証する。形の誤った古い記録は「前」として使えないので、`(not recorded) -> …` と表示する（`old` を `valid_effects` を通ったときだけ `Some` にする）。単体テストかプロセスのテストに、この場合を加える。

## L

### L1. 関係のない既存の依存の `package.bnt` の誤りで `add` が止まる

- 箇所: `src/cli/tools/package/mod.rs:556`（`dependency_config` は、根の設定でも書き換える文書でもない `package.bnt` の誤りをすべて「関係がある」とする）。
- 再現: 入口に `dependency Other`（`deps/other/package.bnt` に `language` がない）がある状態で `package add Words --path deps/words` を実行すると、E0914（`Other`）で止まる。
- 問題: 06-09 の「対象の依存の記述と依存の設定ファイルの誤りを報告し、本体のほかの import や宣言の誤りで編集を止めない」と比べて、範囲が広い。本体の import の誤りは無視するのに、別の依存の設定の誤りでは止まる。
- 修正案: 対象の別名の依存の根（`dependency_location` で求める）の `package.bnt` に限る。広いままにするなら、06-09 に「どの依存の設定ファイルの誤りでも止める」と書く。

### L2. `move` にディレクトリを渡すと、存在する `main.bnt` を「読めない」と報告する

- 箇所: `src/cli/tools/package/mod.rs:417-422`。
- 再現: `benitoite package move .` → `error[E0101]: cannot read file `…/main.bnt`` と `note: invalid input parameter`。`move deps` も `deps/main.bnt` を読めないと示す。
- 問題: 06-01 は「`move` の入口は必須であり、ディレクトリ … は受け付けない」とするが、利用者には、ファイルがないのか、ディレクトリを渡したのが誤りなのかが分からない。
- 修正案: 使い方の誤り（`text::MOVE_ARGS` に「a file, not a directory」を足す）にするか、E0928 と同じ形の診断にする。

### L3. まだない `package.bnt` を明示して `add` すると、`main.bnt` に書く

- 箇所: `src/cli/tools/package/mod.rs:402`・`476-489`。
- 再現: `package.bnt` のない根で `benitoite package add Words --path deps/words package.bnt` → `added … to …/main.bnt`。
- 問題: 06-01 の規則（「`package.bnt` 自体を指定した場合はそのディレクトリを根とし、入口にはしない」）とは合っている。ただ、明示した名前と違うファイルを書き換える。`add` には `package.bnt` を作る手段がなく、E0927 の注記「create package.bnt」は空のファイルを手で作れという意味になる。
- 修正案: 存在しない `package.bnt` を指定したときは、E0101 か E0927 にする。あるいは、空の `package.bnt` を新しく作って書く（`write::create` を使える）。どちらにするかを 06-01 に一文で書く。

### L4. 新しく作る `package.bnt` が入口の実行の許可を引き継ぐ

- 箇所: `src/cli/tools/package/write.rs:29`。
- 再現: シェバンつきの入口（0755）を `move` すると、`package.bnt` も 0755 になる。
- 修正案: 入口の許可から実行のビットを落とす（`mode & !0o111`）。06-09 の「入口の許可を写した」の記述も合わせて直す。

### L5. 書き込みを拒んだときの診断が、ディスクにない仮の版の行を指す

- 箇所: `src/cli/tools/package/mod.rs:526-572`（`loaded.sources` は仮の版の中身を持つ）。
- 再現: `package add Other --path i/deps/other i/main.bnt` → `--> …/i/main.bnt:10:8` と `path "i/deps/other"` の行を示す。ファイルの中身は変わっておらず、10 行目はディスク上にはない。
- 問題: 診断の第一の読み手（LLM）が、ファイルを開いて位置を探すと食い違う。
- 修正案: 注記で「proposed edit, not written」と示す。少なくとも 06-09 に、診断の位置が書き換え後の内容を指すことを書く。

### L6. 公式でない import の書き方でも組み込みのエフェクトとして数える

- 箇所: `src/cli/tools/package/effects.rs:122-149`。
- 例: `import Benitoite.IO.Console`（正しくは `Benitoite.Unofficial.IO.Console`。`check` では E0321）でも、`Console.Write` を数える。`Unofficial` を除いて比べているためである。
- 評価: R24（型検査をしない）の範囲で、多めに数える側に倒れるので害は小さい。06-09 の「import の名前から組み込みを識別し」に、この扱いを一文で足すとよい。

### L7. 文言と語の置き場所（AGENTS.md「文言」）

- `src/cli/tools/package/mod.rs:722-726`: `add` の仮の版の型板 `"{}\ndependency {alias}\npath {}\nend dependency\n"` が関数の中にある。`text::DEPENDENCY` と同じく `text` に置く。
- `src/syntax/header.rs:17` と `package/mod.rs`・`edit.rs` の `"effects"`: `PATH`・`HASH` と同じく定数（`EFFECTS`）にする。
- `src/cli/tools/package/mod.rs:413` の `"main.bnt"`、`write.rs:13` の `".package.bnt.package-"`: `CONFIG_NAME` などの既存の定数から組み立てる。
- `text::IMPORTS`（51 行）の「component has 1 imports」: 単数と複数を分けるか、E10nn の既存の文に揃える。

### L8. 出力の細部

- 別名なしの `update` で対象がないとき、標準出力に何も書かない（`mod.rs:810-812`）。06-01 には書いてあるが、利用者には何も起きなかった理由が分からない。`no dependencies with hash to update` のような一行を `text` に置くとよい。
- ハッシュが変わらずエフェクトの記録だけを足したとき、`hash: X -> X` と同じ値を二度示す。変わらないときは値を一つだけ示す形にできる。

### L9. `write::create` で一時ファイルを消せなかったときの扱い

- 箇所: `src/cli/tools/package/write.rs:35-47`。
- 問題: 一時ファイルを消せなかったとき、作り終えた `package.bnt` を消して失敗にする。消せなかったときの注記 `rollback` の文（「declarations may remain in both files and cause E0911」）は、入口をまだ書いていないこの時点の状態と合わない。一時ファイルは `package.bnt` と同じ inode への固いリンクなので、`package.bnt` を消すと、中身は一時ファイルの名前の側に残る。
- 修正案: 起きにくい場合なので、一時ファイルを消せないことだけを注記して成功として続けるか、この場合に使う注記の文を分ける。

### L10. 文書

- `docs/design/02-impl/02-10-diagnostics.md:373-375` と `docs/design/06-tooling/06-09-packages.md:115-117`: 見出しの前に空行が二つある。
- 02-10「パッケージ命令の診断」は、実行時エラーの報告の節の後に置いてあり、ほかの E09nn のコードは 06-09 で定めている。コードごとの表を置く場所として揃っていない。06-09「`benitoite package`」に E0923〜E0929 の条件をまとめ、02-10 は区分の表の説明（109 行）だけにする案がある。
- `CHANGELOG.md`: 依存の記述に `effects` の欄が加わったこと、その形を `check`・`run` も確かめる（E0929）ことは、言語の利用者に見える変更である。一文で足すとよい。
- `docs/design/06-tooling/06-09-packages.md:121`: M2・M3 を直さないなら、「範囲外の字句とコメントは保ち」「先頭の欄の診断だけでは編集を拒否せず」の例外を書く。

### L11. テスト（test-audit の観点）

- 作成時の関門のコメント、`// spec:` の印、一時ディレクトリ（`CARGO_TARGET_TMPDIR`。既定の構成では `target/` の下で、git には無視される。Z3 の前例に倣った）、作業の ID を名前に付けないことは守られている。
- 次の場合はプロセスのテストにない。M1〜M3 を直すときに加えるとよい。
  - コメントだけの既存の設定への `move` の成功（M2）。
  - 絶対パスの `--path`。
  - 別名を通したエフェクト（M1）。
  - 形の誤った `effects` の修正（M3）。
- `command_preconditions_reject_unwritable_or_missing_destinations_and_package_dependencies` は一つのディレクトリで六つの場合を順に確かめる。途中の失敗が後の場合の前提を崩すので、失敗したときに原因を追いにくい。急がないが、分けるとよい。

## 確かめて問題がなかった点

- 規約: `unwrap`・`expect`・添字を本番のコードで使っていない。`#[allow]` はテストのファイルだけにある。コメントは日本語で、各モジュールに `//!` がある。処理系の不具合の文字列は `text` の外にある（規約どおり）。
- 不可分の書き込み: 既存のファイルは `.<名前>.package-<pid>` の一時ファイル（0600、`create_new`）から rename で置き換える。失敗したら一時ファイルを消す（読み取りだけの入口で確かめた）。許可は保たれる。新しい `package.bnt` は固いリンクで作るので、既にあるファイルを上書きしない。
- 終了状態: 成功・変わらない・対象なしは 0、診断と使い方の誤りは 2、検証の途中の処理系の不具合は 3（`fmt` の 0・2・3 に揃っている。`--check` の 1 はない）。
- 診断 E0126・E0923〜E0929 の文言と説明は英語で、`gen_skill` の生成物（`skill/references/diagnostics.md`）に入っている。
- 06-01 の予約の名前、使い方の文、`docs/reference/benitoite.md` の予約の一覧から `package` を除いてある。
- エフェクトの集計で、エフェクト変数、利用者が定義したエフェクト、非公開の関数を数えないこと。型クラスのメソッド、引数・戻り値の関数の型の `uses`、`State`・`IO.All` を数えること。
- 二度目の `add` は E0923、二度目の `update` は `unchanged` で、ファイルの更新時刻が変わらない。二度目の `move` は E0925。どれも冪等である。
