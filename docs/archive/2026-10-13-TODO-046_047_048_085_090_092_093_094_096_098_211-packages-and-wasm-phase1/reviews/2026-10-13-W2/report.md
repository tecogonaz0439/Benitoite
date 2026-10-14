# W2 のレビュー（49500d50「Load local-path packages and resolve their imports」）

対象: `git show 49500d50`。別の worktree（detach、49500d50）で debug のビルドを作り、実行ファイルで再現を確かめた（worktree は削除済み）。確かめた検査: `BENITOITE_GOLDEN_FILTER=testdata/packages/ cargo test --test golden`（29 件、差分の実行 6 件一致）、`cargo test --lib modules`（26 件成功。失敗した `real_fs_matches_memory_for_files_imports_and_missing_modules` は worktree の既知の失敗）。W1 のレビューの所見は繰り返さない。

全体: 依存の読み込み、別名による取り込み、パッケージの中の探索の制限、`ModuleKind::Package` の扱い（名前解決・型検査・脱糖・`Assert` の表）、依存の警告の抑制は、計画と事前点検のとおりに動いた。凍結した型の変更は了承の表の範囲（10-04 の `ModuleKind::Package`、非公開の `Pending`・`Finder` の欄と引数）に収まる。パッケージの中から根・ほかの依存・自分の別名を探さないこと、誤りは示し警告だけを除くこと、`--deny-warnings` が依存の警告に当たらないこと（`check`・`test` の両方）、`test` で依存のファイルの位置が実行時の報告に出ることを、実行して確かめた。

H の所見はない。M が 2 件、L が 7 件ある。

---

## M1. 同じファイルが「根のモジュール」と「依存のモジュール」の二つとして読まれ、別の振る舞いと別の型になる

- 場所: `crates/benitoite/src/modules/find.rs:73-104`（衝突の判定は、import の先頭の段が依存の別名と一致するときだけ行う）、`crates/benitoite/src/modules/load.rs:213`（依存の根に制限がない）。設計書 01-03:279・281。
- 問題: 「同じファイルなら衝突としない」例外は、別名と根の下のディレクトリの名前が一致する構成（`dependency Textkit path "Textkit"`）だけを想定している。別名がディレクトリ名と違う場合（`dependency Tk path "Textkit"`）や、依存の根が根そのもの・根の祖先の場合（`path "."`、`path ".."`）は、根からの import が依存の別名で始まらないので衝突の判定を通らない。その結果、同じファイルが二つのモジュールとして読まれる。
  - 根のモジュールとして読んだ方は、その中の import を根から探す。依存のモジュールとして読んだ方は、パッケージの根から探す。同じソースが別のモジュールを取り込み、結果が変わる。
  - 型も別になる。診断は「expected `Box`, found `Box`」となり、利用者と LLM には原因が分からない。
  - 構文の誤りが同じファイルで二度報告される。
  - 01-03:281 は「同じパッケージを違う別名で記述したときは別のモジュール」と書くが、根のモジュールとの重なりについては書いていない。R4 の「取り違えない」の意図に反する。
- 再現（`a/` の下に置く）:
  ```
  Textkit/package.bnt : language "0.0.3" / package Textkit / end package
  Textkit/Helper.bnt  : public function n() -> Integer  return 1
  Helper.bnt          : public function n() -> Integer  return 2
  Textkit/Slug.bnt    : import Helper / public record Box n: Integer end record /
                        public function make() -> Box  return Box(n: Helper.n()) / get(b) = Box.n(b)
  main.bnt:
    dependency Tk
      path "Textkit"
    end dependency
    import Textkit.Slug as A
    import Tk.Slug as B
    ... Console.writeLine("${A.get(A.make())} ${B.get(B.make())}")
  ```
  `benitoite run main.bnt` は `2 1` を出す（同じ `Slug.bnt` が別の `Helper` を使う）。`bind x <- B.get(A.make())` は `E0401 expected `Box`, found `Box``。`Slug.bnt` に構文の誤りがあると、同じ E0201 が二度出る。`path "."` にして `import Me.Slug` と `import Slug` を並べても、同じファイルが二つのモジュールとして読まれる（E0323 は名前の重なりで出るだけで、`as` を付ければ通る）。
- 修正案（どちらかを選び、01-03 の「依存のパッケージの取り込み」に書く）:
  1. （推す案）根の側で見つけたファイルの正規化したパスが、いずれかの依存の正規化した根の下にあれば誤りにする。E0918 に注記を足すか新しいコードにし、「このファイルは依存 `Tk` のパッケージに属する。`import Tk.Slug` と書く」と示す。別名とディレクトリ名が一致する構成は今の例外のまま通る。
  2. 依存の根が根と同じか根の祖先なら、依存の読み込みで誤り（E0916 か E0917 に注記）にする。`modules/tests.rs` の `package_imports_keep_their_canonical_root_and_reject_the_entry` は `path "."` を使っているので、作り直す必要がある。
  - 1 と 2 を両方入れるのが最も堅い。少なくとも 1 は要る。

## M2. パッケージで見つからないときの E0318 の label が「根のディレクトリの下にない」と言い、誤った場所を指す

- 場所: `crates/benitoite/src/diag/codes.rs:446`（label の型板は一つだけ）、`crates/benitoite/src/modules/find.rs:166-185`。
- 問題: パッケージの根を探して見つからなかった場合も、label は `no file `Slg.bnt` under the root directory` になる。注記は「パッケージの根から探す」と言っており、label と注記が矛盾する。診断の第一の読み手である LLM が、根のディレクトリに `Slg.bnt` を作る修正へ誘導されうる（設計原則 1・4）。`package-isolation` と `alias-only` のゴールデンは、この文言を期待値に固定している。
- 再現: `dependency Tk path "Textkit"` と `import Tk.Slg` で、`no file `Slg.bnt` under the root directory` と `note: modules of the package `Textkit` are imported by their path from the package root `Textkit``。
- 修正案: E0318 の label を引数で切り替える（`"no file `{path}` under {where}"` に `where` = "the root directory" か "the package root `{root}`"）か、パッケージ用の label を持つ別の型板にする。ゴールデンの 3 件と Skill の生成物を作り直す。同じ考えで、E0319 の message「outside the root directory」も、パッケージのときは「outside the package root」にするとよい（L）。

---

## L1. 依存を読めなかったとき、その別名の import が根の E0318 を重ねて出す

- 場所: `crates/benitoite/src/modules/load.rs:213-218` と `find.rs:73-80`（失敗した依存を表に載せないので、`import Me.Slug` が根の探索に落ちる）。
- 再現: `path "main.bnt"`（ディレクトリでない）で、E0916 の後に `E0318 cannot find module `Me.Slug` … no file `Me/Slug.bnt` under the root directory` が出る。
- 修正案: 読めなかった依存の別名を `Finder` に「失敗した別名」として持たせ、その別名で始まる import は診断を出さずに失敗として扱う（連鎖を止める）。

## L2. 依存の非公開の名前に「`public` を付ける」修正案を出す

- 場所: `crates/benitoite/src/resolve/lookup.rs:457-462`（`user_module` に `Package` を加えた）。
- 問題: E0330 の help が、依存のファイル `Textkit/Slug.bnt` を書き換える編集を示す。依存の警告を隠す理由（02-10、06-09。利用者が直すのは根のソース）と食い違う。LLM がパッケージのソースを書き換えると、W3 のハッシュも食い違う。
- 修正案: 修正案の対象を `Entry | User` に戻し、`Package` は標準ライブラリと同じく編集を出さない。代わりに「パッケージ `X` の非公開の名前」という注記を出すと親切である。06-09 か 02-04 に一文を書く。

## L3. 06-09「パッケージの構成」に、まだ実装していない `wasm/` の規則がある

- 場所: `docs/design/06-tooling/06-09-packages.md:54`。
- 問題: WASM のコンポーネントの同梱と `wasm/` は W4・W5 で実装する。設計書には実装した内容だけを書く（AGENTS.md「設計書の規約」）。「`rust/`・`wit/`・`target/` はモジュールの探索の対象にしない」も、import の名前が大文字で始まるために自然に外れるだけで、処理系が持つ規則ではない。誤解を招く。
- 修正案: この段落を消し、W4（または W3 の含めるファイルの一覧）で実装と一緒に書く。

## L4. 依存の `package.bnt` の警告を除く処理は、今は対象がない

- 場所: `crates/benitoite/src/pipeline.rs:252-260`（`Config` で名前の段が 2 以上のもの）、02-10:145、06-09:62。
- 問題: 設定ファイルに出る警告は今はないので、この枝はテストできない。名前の段の数で依存の設定を見分けるのは、名前の約束に結び付いた判定である。
- 修正案: 害はないので残してよい。ただし判定は、`Finder` の依存の表の `config` の ID から集合を作る（load の出力で渡す）か、コメントで約束を明記する。

## L5. 型の名前が同じで出どころが違う型の不一致の診断が、区別できない

- 問題: M1 を直しても、同じパッケージを二つの別名で記述した構成（01-03:281 で許している）では、`expected `Box`, found `Box`` が出る。この弱点は前からあり、パッケージで起こりやすくなった。
- 修正案: 型の表示が同じになるときはモジュールの名前を付ける（`Tk.Slug.Box` と `Words.Slug.Box`）。この改造で直さないなら docs/todo に項目を足す。

## L6. E0916 の注記が OS の文言をそのまま出し、ゴールデンが OS に依存する

- 場所: `crates/benitoite/src/modules/load.rs:443-448`、`testdata/packages/dependency-missing.diag.json`（`No such file or directory (os error 2)`）。
- 問題: 既存の `read_error` と同じ扱いなので一貫はしている。ただしゴールデンの期待値が macOS・Linux の文言に固定される。
- 修正案: 既存の読み込みの誤りのゴールデンがどう扱っているかに揃える。揃っているならこのままでよい。

## L7. 内部の誤りの診断を手で組み立てている

- 場所: `crates/benitoite/src/modules/find.rs:49-70`。
- 問題: `pending.package` は常に登録済みの設定の ID なので、この枝には到達しない。それなのに `Diagnostic` を欄ごとに手で書いている（`resolve/collect.rs:72` にも前例はある）。
- 修正案: `Pending.package` に依存の表の添字を持たせて探索をなくすか、共通の補助の関数にまとめる。急がない。

---

## 確かめて問題がなかった点

- **探索**: 標準ライブラリを最初に照合すること。パッケージの中の import を、その根だけから探すこと（`package-isolation` で、根・自分の別名・ほかの依存を探さないことを確認）。別名だけの import。根の側だけにあるモジュール（`root-fallback`）。綴りの誤りの候補（`Tk.Slug` を示す）。
- **パス**: 正規化した根と表示の根を分けていること。`..` を正規化しない表示（02-02 の例と一致）。絶対パス（単体テスト）。
- **パッケージの根の境界**: パッケージの外を指すリンクは、根の側で同じファイルと照合する前に E0319 で止まる（`file()` が `package` のときは即座に `Err`）。根のリンクが依存のファイルを指す場合の例外は、両方が同じ正規化したパスのときだけ効く。M1 の問題は、この照合を通らない経路の問題である。
- **モジュールの同一性**: 名前 `[別名, 段…]` の Package と、根の User の名前は、上の照合が決定的なので同じ名前にならない（`scheduled` の重複除去で取り違えは起きない）。
- **警告**: `package-warning` の W0401 は、同じファイルを根として `check --deny-warnings` すると出ることを確かめた。抑制のテストは空振りしていない。`test --deny-warnings` でも依存の警告で止まらない。誤り（`package-error`）は示す。
- **テストの実行器**: `@test` は入口のファイルだけから集めるので、パッケージのテストは根の `test` で走らない（根のモジュールと同じ扱い。Q9 の「パッケージの根で走らせる」と整合する）。ディレクトリの走査は依存の `deps/textkit` を拾わない。`Assert.equal` の失敗の表示（`Box(n: 1)`）と、実行時の誤りの呼び出しの痕跡（`Textkit.Slug.divide`、依存のファイルの位置）は正しい。
- **VM と参照インタプリタ**: パッケージの実行のゴールデン 6 件で一致した。
- **設計書**: 01-03・02-01・02-02・02-04・02-10・06-09 の記述は実装と一致する（例外は M1・L3）。CHANGELOG の 2 項目は利用者から見える変更と合う。既存の `###` の見出しは変えていない。
- **テスト（test-audit）**: 新しいゴールデン 18 件は、それぞれ別の経路を確かめている。単体テスト 3 件には関門のコメントがあり、ゴールデンで観察できない ID の順と境界を確かめている。M2 を直すときは、`package-isolation`・`alias-only`・`package-error` 以外の E0318 の期待値も作り直す。M1 を直すときは、再現の構成をゴールデンにする（別名がディレクトリ名と違う、根の下に写した依存）。
