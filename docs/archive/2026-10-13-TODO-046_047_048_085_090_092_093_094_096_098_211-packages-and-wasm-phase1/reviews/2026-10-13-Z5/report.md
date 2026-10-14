# Z5（d9c2e84a）のレビュー

対象: `Fix the findings of the Z4 and W6 reviews (Z5)`。detached の worktree（`scratchpad/pkg/rev-Z5`）で debug ビルドを作り、以前の入力（`adv/`、`z4rev/`）と新しい入力（`scratchpad/pkg/z5rev/`、道具は `z5rev/env.sh`）で確かめた。パスは `crates/benitoite/` を省く。行番号は d9c2e84a の時点のもの。

## 再実行の結果

| 入力 | 結果 |
|---|---|
| `adv/bigarg`・`adv/alias` | R0905 `exceeded its host value-transfer limit of 268435456 bytes`＋注記 `transfer`、終了状態 1 |
| `adv/manymem`・`adv/initmem` | R0905 `exceeded its total guest linear-memory limit of 67108864 bytes`＋注記 `linear_memory` |
| `adv/bigtable` | R0906 `needed 20000 table elements; the limit is 10000` |
| `z4rev/inst`・`z4rev/tbls` | R0906 `needed 17 core instances`・`17 core tables`、上限 16（以前は R0601 trapped） |
| `z4rev/grow`（`(memory 1 2)` で `memory.grow 100000`） | -1 が返り `done` を出して終了状態 0（単体テスト `memory_grow_beyond_guest_maximum_returns_minus_one` も -1 を確かめる） |
| W6 M2（コメントだけの設定へ `move`） | CR LF・行末の空白・BOM・末尾の改行なし（`// a` のみ、`// a\r\n// b`）・空ファイル・空白だけ、のどれもバイトを保って最後のコメントの後に挿入し、`check` を通る |
| W6 M3（`effects "file.read"` の `update`） | `(not recorded) -> File.Read` で直る。結果は `check` を通る |
| W6 L2・L3・L4・L8 | `move .`・`move deps` は使い方の誤り、存在しない `package.bnt` の明示は E0101 で書かない、新規 `package.bnt` は 0644（入口 0755）、対象なしの一括更新は `no dependencies with hash to update` |
| W6 L6 | `import Benitoite.IO.Console`（誤り）は数えない、正式名は数える。`as` は E0339 なので影響なし |

worktree で `cargo test -p benitoite --lib -- external cli::tools::package modules`（72 件）、`--test package_command`（13 件）、外部の関数とパッケージのゴールデンが通った。`gen_skill` を走らせても差分はなく、Skill の生成物は最新。テストの後の `git status` は空。`modules/test_support.rs` は `std::env::temp_dir()` に戻り、`tests/package_command.rs` は `CARGO_TARGET_TMPDIR`（target の下）を使う。

Wasmtime の数の上限の接頭辞の照合: `Cargo.toml:41` で `wasmtime = "=49.0.2"` に固定してある。49.0.2 の `store.rs:1527` の `bail!("resource limit exceeded: {desc} count too high at {new}")` と `text.rs` の三つの接頭辞は一致し、`{new}` は加算後の数なので「needed N」の意味とも合う。文言が変わっても R0601 に落ちるだけで終了状態 3 にはならず、`object_count_limits_are_resource_failures` が本物のインスタンス化で検出する。02-09 にこの依存と出典が書いてある。受け入れてよい。

## 所見

H はない。M は 2 件、L は 3 件。

### M1. 対象の依存の設定の誤りの判定が、パスの綴りによって漏れる（退行）

- 場所: `src/cli/tools/package/mod.rs:561`〜`:573`（`dependency_configs`）と `:582`
- 問題: W6 L1 の直しで、関係のある設定ファイルを `dependency_location(...)` の結果の第一要素（`fs.canonicalize` した根）に `package.bnt` を付けた文字列で集め、`source.name()` と文字列で比べる。ところが読み込みが付ける `source.name()` は正規化しない表示の名前（`display_root(entry).join(path)`、第二要素）である。`--path` に `..` を含む・シンボリックリンクを通る（macOS の `/tmp` も該当）と一致せず、対象の依存の `package.bnt` の誤りが「関係なし」とされる。`add` は誤りを報告せずに書き込み、書いた結果は `check` で失敗する。Z5 の前は、どの依存の設定の誤りでも止めていたので、この場合は止まっていた。06-09 の「対象の依存の記述と、その依存の根の設定ファイルの誤りを報告し」とも食い違う。`update` も同じ判定を通る。
- 再現（`z5rev/l1`・`l1s`。`deps/words/package.bnt` を `package Words\nend package\n`（`language` なし）にする）:
  ```text
  $ benitoite package add Words --path deps/words              → E0914、書かない（正しい）
  $ benitoite package add Words --path ./deps/../deps/words    → added ...、終了状態 0
  $ benitoite package add Words --path /tmp/.../l1/deps/words  → added ...（/tmp → /private/tmp）
  $ ln -s deps/words wl; benitoite package add Words --path wl → added ...
  $ benitoite check main.bnt                                    → E0914 wl/package.bnt
  ```
- 修正案: 集合に `dependency_location` の第二要素（表示の根）に `CONFIG_NAME` を付けた文字列を入れるか、両側を正規化したパス（`source.name()` を `canonicalize` したもの）で比べる。プロセスのテストに、`..` を含む `--path` かシンボリックリンクで、対象の依存の設定の誤りが E0914 で止まる場合を加える。

### M2. 公開の `data` の構成子の欄にある関数の型の `uses` を数えない（W6 M1 と同じ種類の漏れ）

- 場所: `src/cli/tools/package/effects.rs:74`〜`:78`（`Item::Data(_)` を読まない）、`docs/design/06-tooling/06-09-packages.md:124`
- 問題: W6 M1 の直しは型の別名とレコードを加えたが、公開の `data` の構成子の欄も同じく公開の契約である。構成子に `function(String) -> Unit uses Console.Write` を持たせると、利用側はそれを呼べるのに、報告は `effects: (none)`、記録は `effects ""` になる。後で `File.Write` に変わっても `update` は差を示さない。R24 の「宣言を読めば型と同じ結果になる」と設計原則 2 に反する（W6 M1 と同じ理由）。非公開の別名を公開の関数の型に使うことは E0329 で拒否されるので、そちらは問題ない。公開の `const` は関数の値を持てない（E0433）ので対象外でよい。
- 再現（`z5rev/data`）:
  ```text
  deps/words/Value.bnt:
    import Benitoite.Unofficial.IO.Console
    public data Action
      Run(function(String) -> Unit uses Console.Write)
      Stop
    end data
  $ benitoite package add Words --path deps/words   → effects: (none)、記録 effects ""
  main2.bnt で go(Value.Action.Run(lambda ... Console.writeLine(s) ...)) を run → hi
  ```
- 修正案: `Item::Data` の各構成子の欄の型も `types` に渡す（型引数は `data.type_params`）。06-09「`benitoite package`」の対象の列挙、`docs/reference/benitoite.md` の該当の文、CHANGELOG の Unreleased に「data の構成子の欄」を足し、単体テスト `public_contracts_include_nested_function_types_and_trait_methods` に `data` の場合を加える。

### L1. 正式でない親の import（`import Benitoite.Unofficial.IO`）を通した名前を数える

- 場所: `src/cli/tools/package/effects.rs:168`〜`:177`
- 問題: 照合は「エフェクトのモジュール（`IO.Console`）が標準ライブラリの表で非公式か」だけを見て、import した名前（`Benitoite.Unofficial.IO`）自体が正式かは見ない。`import Benitoite.Unofficial.IO` と `uses IO.Console.Write` は `check` で E0321（`Benitoite.Unofficial.IO` は標準のモジュールでない）だが、`Console.Write` として数える。多めに数える側であり害は小さいが、06-09 の「標準ライブラリの表にある正式な import の名前から組み込みを識別し」とは合わない。
- 再現（`z5rev/imp3`）: 上の宣言で `package add` → `effects: Console.Write`。
- 修正案: import の段（`imports.get(first)` の値）自体が `STDLIB` のどれかの正式名と一致するときだけ受け付ける。急がない。直さないなら 06-09 に「import の名前の接頭辞が正式でなくても、モジュールの名前が合えば数える」と一文書く。

### L2. 存在しない `package.bnt` の明示の注記が `entity not found` になる

- 場所: `src/cli/tools/package/mod.rs:416`〜`:420`
- 問題: `std::io::Error::from(ErrorKind::NotFound)` の `Display` は `entity not found` であり、ほかの E0101（`No such file or directory (os error 2)`）と文言が揃わない。
- 再現: `benitoite package add Words --path deps/words package.bnt`（`package.bnt` なし）→ `note: entity not found`。`benitoite package move nonexist.bnt` → `note: No such file or directory (os error 2)`。
- 修正案: `std::fs::metadata(&target)` の実際の誤りを使う（`if let Err(error) = std::fs::metadata(&target) { return context.fail(read_error(&target, &error)); }`）。

### L3. CHANGELOG の Unreleased に、まだ出していない機能の直しが「変更」として書かれている

- 場所: `CHANGELOG.md` の Unreleased（`Preserve comment-only settings files ...` と `A memory.grow beyond ...` の二行）
- 問題: `benitoite package` も外部の関数も Unreleased の中で加わった機能なので、利用者から見ると「直した」点はない。二行は、それぞれ `package` の項目と外部の関数の項目の説明（最終の振る舞い）にまとめた方が読みやすい。内容は実装と一致する。
- 修正案: 二行の内容を既存の二つの項目に一文ずつ溶かし込む。

## 文書

- 01-09・02-09・02-10・03-10・06-01・06-09・リファレンスの R0905 の注記・R0906・`memory.grow` の -1・2 × 256 MiB＋64 MiB のピーク・`move` のディレクトリ・明示した `package.bnt`・実行のビット・`(not recorded)`・`no dependencies with hash to update` の記述は、実装と一致する（上の M1・M2・L1 の範囲を除く）。
- `update` は、`effects` だけがあり `hash` がない依存に `hash` を足すとき、`effects` の後に `hash` を置く（`add` は `hash`・`effects` の順）。Z5 の前からの振る舞いで、検査には影響しない。所見にはしない。
