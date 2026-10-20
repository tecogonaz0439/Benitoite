# RV4 実行の共有とライブラリ・道具のレビュー（H1・H2・G1〜G7）

## 対象と方法

- 対象: `git diff 498943fe..e9de51fc`。Z2 の後に H1・H2・G1〜G7 を取り込んだ状態であり、HEAD は `e9de51fced4c04668cd92b73f0838246efb3418c` である。
- 読んだもの:
  - plan.md の「段の順序とレビュー」、作業H1〜G7、RV4 の行、「検査の割り当て」の H・G の行
  - design.md の 5・7・8・11 節
  - decisions.md の R185〜R197
  - h1・h2・g1〜g7 の results.md（必要な箇所は commands.jsonl も）
  - RV3.md と RV3-response.md
  - 各作業の Rust・BNT・Python の差分と、関係する docs/design の差分
- 実行したこと:
  - `cargo build --release -p benitoite` で作った `./target/release/benitoite` に、`work/m010/reviews/rv4-scratch/` の小さな .bnt を与えた（`check`・`run`・`test`・`check --report=json`・`--allow-effects`）。
  - 保管した 6 ファイルが内容を変えずに移ったことを、`git diff --name-status -M100%` で確かめた。
- しなかったこと:
  - cargo test の全件、scripts/check.sh、scripts/check-formal.sh、lake build
  - 名指しの cargo test と tools/derive/test_derive.py
  - 古い版との比較用の worktree の作成
  - SHA-256 の再計算（shasum の実行が許可されなかったので、git の完全一致の改名の検出で代えた）
- 所見ごとに、確かめた事実か推測かを記す。RV3 で済んだ論点は扱わない。

件数は重 0・中 1・軽 5 である。

## 中

### 中1 行末の値の `record` の後で、大文字で始まる次の行がつながる（G1、確かめた事実）

- 場所:
  - `crates/benitoite/src/syntax/newline.rs` の `resolve_newlines`（55〜58 行）。条件は `previous == Some(K::KwRecord) && next != Some(K::UpperIdent)` である。
  - `docs/design/01-spec/01-01-lexical.md` の「改行の扱い」の規則 2 への追記「`record` の直後は、次の字句が大文字識別子でなければ式の末尾として扱い」。
- 問題点:
  - 01-01 のキーワードの節は、`record` を名前を要求する位置で小文字の名前として使えるとし、値への参照と束縛の名前も同じように扱うとする（R187）。
  - ところが改行の規則は、直前の字句が `record` かどうかと、次の字句の種類だけで、宣言か値かを決めている。
  - その結果、値の `record` が行末にあり、次の行が大文字の識別子で始まると、改行が消える。二つの文が一つにつながる。
  - 関数の本体の中ではレコード宣言は始まらない。本体の中の `record` の後で改行を消す理由はない。
- 失敗の筋書き:
  - `rv4-scratch/rec1.bnt` の 22・23 行は次のとおりである。

    ```
      bind y <- record
      Console.writeLine(Integer.toString(y + n))
    ```

  - 期待は、二つの文として受理されることである。
  - 実際は、E0201 "expected a newline or the end of the block, found `Console`" が 23:3 に出た。
  - 同じファイルの、パラメータ名・ラムダのパラメータ・関数型のラベル・名前付き引数・リストのパターンの `record` は受理された。次の行がキーワード（`bind` など）で始まる場合も通る。
  - Log の API は `record` の名前を勧めている（`case Log.emit(record) ->`、`function(record: Log.Record)`）。このため、節や sink の中で `bind saved <- record` と書き、次の行で `Console.writeLine(...)` や `Log.emit(...)` を呼ぶ形は自然に生じる。
  - 診断は改行の扱いに触れない。利用者にも LLM にも修正の手掛かりにならない。
- テストの不足: G1 で足したテスト（checked_args・declarations・test_command）は、名前付き引数・関数型・パラメータの `record` を確かめる。値の `record` を行末に置き、次の行を大文字で始める入力はない。
- 修正案:
  - 宣言か値かを、`record` の直前の字句で決める。行頭・ファイルの先頭・`public`・注釈の後なら宣言とし、`<-`・`return`・`(`・`,`・演算子の後なら値とする。
  - または、字句の段では `record` の後の改行を残し、宣言の構文解析で `record` の直後の NEWLINE を読み飛ばす。
  - どちらの案でも、01-01 の規則 2 への追記を同じ変更で直す。
  - 上の入力と、`public record` の後で改行してから型名を書く宣言を、parser のテストに足す。

## 軽

### 軽1 W0501 の修正案が `uses Log.Log` を勧める（G1、確かめた事実）

- 場所: `crates/benitoite/src/typeck/effects/declarations.rs` の `effect_name`（276 行付近）。
  - 組み込みのエフェクトでは、取り込みの別名か、モジュールの最後の段と宣言の名前を `.` でつなぐ。
  - Log ではモジュールの最後の段も名前も `Log` なので、`Log.Log` になる。
- 問題点:
  - design 5.1 は、正規表示・許可名・報告を `Log` にそろえるとする。
  - 型の表示（E0401）・E0512 の注記・E0501 の help・`check --report=json` の expanded は `Log` である。W0501 の修正案だけが `Log.Log` になる。
- 失敗の筋書き:
  - `rv4-scratch/log2.bnt` の `function f() -> Unit uses IO.All` で Log.info を呼んだ。
  - W0501 の help は "write `uses Log.Log`" で、修正の差分も `uses Log.Log` だった。
  - 同時に出た E0501 の help は "add `uses Log`" だった。
  - `uses Log.Log` は受理されるので、誤りにはならない。ただし LLM が修正案をそのまま適用すると、正規でない綴りが広がる。
- 修正案:
  - モジュールの最後の段と同じ名前の組み込みエフェクト（今は Log だけ）では、名前だけを返す。
  - W0501 の Log の修正案を固定するテストを足す。

### 軽2 `record` を名前に使える位置の規定と実装がそろっていない（G1、確かめた事実）

- 場所: `docs/design/01-spec/01-01-lexical.md` のキーワードの節の【決定】と、レコード宣言の欄の構文解析。
- 問題点:
  - 01-01 は「名前を要求する位置では小文字の名前としても使える」と書き、例としてパラメータ名・引数のラベル・値への参照・束縛の名前を挙げる。
  - レコードの欄名も名前を要求する位置だが、拒否される。
  - 一方、構築の先読み（`exprs.rs` の `record_ahead`）は `Box(record: …)` の `record` を受ける。二つの扱いがそろっていない。
- 失敗の筋書き: `record Box` の欄に `record: Integer` を書くと、E0201 "expected a record field, found `record`" になる。実害は小さい。
- 修正案:
  - 01-01 に、使えない位置（レコードの欄名など）を明記する。
  - または、欄名にも許し、自動アクセサの名前との衝突も確かめる。

### 軽3 E0467 があると、同じプログラムの型の誤りが報告されない（G1、確かめた事実）

- 場所:
  - `crates/benitoite/src/pipeline.rs` の `check_stages_counted`。`source_location::expand` の診断に誤りがあれば、型検査へ進まない。
  - `docs/design/02-impl/02-04-resolver.md` の「位置の式の事前展開」。
- 問題点:
  - 位置の式の展開は、名前解決と型検査の間の段である。E0467 は名前解決の誤りと同じく、ファイル全体の型検査を止める。
  - 02-04 はこの止まり方を書いていない。
- 失敗の筋書き:
  - `rv4-scratch/here5.bnt` に、`bind f <- SourceLocation.here` と、無関係の `bind x: Integer <- "not an integer"` を並べた。
  - 出た誤りは E0467 の 1 件だけで、E0401 は出なかった。
  - 同じく `here3.bnt` では、E0467 の 4 件と同じファイルにある `SourceLocation.here(1)` の E0402 が出ず、E0467 を消した `here4.bnt` で初めて出た。
  - 修正の往復が一回増える（原則 1）。
- 修正案:
  - E0467 の式を誤りの式に置き換えて、型検査を続ける。
  - 続けないなら、02-04 に「E0467 は型検査の前に報告し、型の誤りはその後に報告する」と書く。

### 軽4 三つの不透明型の `=` と Assert の表示が、内部の欄を示すことを書いていない（G3、確かめた事実）

- 場所:
  - `docs/design/03-interop/03-06-stdlib.md` の Range（CheckedLength・CheckedIndex）と NonEmptyList の節。
  - `crates/benitoite/skill/references/stdlib/Range.md` と `NonEmptyList.md`。
- 問題点:
  - 03-06 は「等値・key・Showを包みの公開契約として追加しない」と書く。
  - しかし用語集の「不透明型」の定義（`@opaque` の型は内部構造に従う）により、`=` は保存した欄全体で比べる。`Assert.equal` も使える。
  - Assert の失敗の表示は、内部の欄の名前と値をそのまま出す。
  - 構築・更新・パターン・アクセサの拒否（E0340）はすべて確かめた（`rv4-scratch/opaque1.bnt`・`opaque2.bnt`）。公開の境界から中身を作ること・壊すことはできない。
- 失敗の筋書き:
  - `rv4-scratch/opaque4.bnt` の二つの `Assert.equal` の失敗は、それぞれ次の表示だった（left の行だけを示す）。

    ```
    left:  NonEmptyList(first: 1, rest: [2])
    left:  CheckedLength(minimum: 0, maximum: 5, length: 1, values: [1])
    ```

  - 公開の関数は head/tail である。表示の `first`・`rest` を見た LLM が `NonEmptyList.first(x)` と書くと、E0340 になる。
  - `opaque3.bnt` の `ne = ne` と `ci = ci` は受理された。補間は E0422 で拒否された。
- テストの不足: 不透明な包みの `=` と Assert の表示の振る舞いを固定するテストはない。
- 修正案:
  - 03-06 と Skill の参照に、`=` は保存した対象の List・欄を含めて構造で比べること、Assert の表示は内部の欄を示すことを明記する。
  - 構造の等値を約束したくないなら、等値の型から外す規則を別の項目にする。

### 軽5 現役の道具の README が、改造のディレクトリの保管先へリンクしている（G6、確かめた事実）

- 場所: `tools/source-migrate/README.md` の 50 行。リンク先は `../../docs/2026-10-19-TODO-…-syntax-batch4/historical-tools/named-arguments-migrate/README.md` である。
- 問題点:
  - AGENTS.md「改造の進め方」の 5 により、改造を終えると、このディレクトリは `docs/archive/` へ `git mv` で移る。そのときこのリンクは切れる。
  - 保管 README は移動後に HISTORICAL を替えるよう案内している。しかし、現役の README 側の更新は、どこの作業にも割り当てられていない。
- 修正案:
  - 改造を閉じる作業の点検項目に、このリンクの付け替えを加える。
  - または、リンクにせず「改造のディレクトリ（終了後は docs/archive/）の historical-tools/named-arguments-migrate」と文字で書く。

## 確認した内容（指摘なし）

### 1. 変換区間と世代（H1）

確かめた点（コードを読んで確かめた）:

- 変換表の寿命:
  - `ToHeapSession<'e>` と `FromHeapSession` は、`heap.epoch` の閉包の中で作り、閉包の中で捨てる。
  - 表が持つヒープ値は `'e` に縛られるので、区間を越えて残せない。
  - 区間の中には安全点がない（回収は区間の後の `collect_requested` だけ）。表に置いた値を根に置く必要はない。
- 行きの表（RefKey）:
  - 鍵は、構成子のタグ、String・Bytes の長さ、種類ごとの別の場合を含む。
  - 元の Value を `retained` で保持するので、解放された番地の再利用を同じ対象と取り違えない。
  - 明示の作業列は、Remember を子より先に積む。二度目の Visit は、一度目の完成の後に処理される。
  - 処理中（None）への再入は Internal になる。Rc の不変の値には循環がないので、正しい入力では起きない。
- 戻りの表:
  - 鍵は (ObjId, ObjKind) である。
  - Opaque・Host・NetworkError は、一度だけ RootStack へ積む。
  - セル・Func・Dict・ListNode は、従来どおり拒否する。
- 世代:
  - 通常の組み込みの呼び出しごとに、世代を checked_add で進める。前の区間の RefValue を拒否するテストがある。
  - 外部関数の入口は世代を進めない。ただし外部の結果は不透明な値を拒否するので、古い RefValue が戻る経路はない。
- テスト:
  - 六種類の引数間の共有、戻り値内の共有、深さ 12 の共有した子の同一性、同じ並びの別の種類・タグの区別を、Rc::ptr_eq と object_id で観察する。
  - copy 後の物理表現は、既存の `builders_tests.rs` の `snapshots_capacity_and_list_children_survive_collection` が、三種類について容量の増加と GC の後まで確かめる。
- 02-08・02-09・07-03・07-04 の追記は、実装と一致する。

### 2. 外部 Store の隔離（H2）

- 共有の所有者:
  - `ExternalSession` が持つのは、Engine・二つの表・見張りだけである。Store・Instance・stateful・制限・実行番号は、実行ごとの `ExternalRuntime` に残る。
  - 表は SHA-256 で引いた後に bytes を比べる。補助は ComponentKey も比べる。
  - 失敗したコンパイルは保存しない（session_tests で確かめる）。
- 隔離の検査:
  - `test_command` の新しいテストは、1・10・50 件のテスト、別のパスの同じ bytes、doc の例と main を通す。
  - stateful の `live=1`、純粋な補助の `adapted()=41` を二度、実行用のコンパイル回数 normal 2・adapter 1、静的な照合の回数 4・8 を、独立の期待値と比べる。
  - これにより、テストどうし・実行どうしで Store や大域の状態が漏れないことを確かめている。
- 見張り:
  - 見張りは所有者の寿命に合わせ、最後の所有者の Drop で unpark/join する。
  - external_signals は、先に終わったテストの後でも中断できることと、後のテストのファイルを作らないことを確かめる。
- 補助の元ゲストの純粋性の再確認は、統計に数えない追加のコンパイルである。03-10 はこれを明記しているので、指摘しない。

### 3. Log の既定・ハンドラ・位置・許可（G1・G2）

実行して確かめた:

- `SourceLocation.here()` の展開:
  - 展開される位置: トップレベルの const、import の別名、`Benitoite.SourceLocation.here()`、括弧の中、ガード、match の腕、ラムダ、lazy。
  - 位置: 列はコードポイントで数え、呼び出しの開始を指す。
  - ファイル名: 絶対パスの入口ではファイル名だけになる。
- here の誤った使い方:
  - 値としての使用、引数への受け渡し、パイプの両形は E0467 になる。
  - 余分な引数・ラベル・穴は、E0402・E0451 になる（R188 のとおり）。
  - 展開の走査は Expr を網羅する match であり、漏れはない。
- Log の効果:
  - `uses IO.All` だけで Log を呼ぶと E0501 になる。
  - `--allow-effects Console.Write` だけで Log を使うと E0512 になる。
  - `check --report=json` の expanded は `Log` を正規名で出す。
  - `as` の別名は E0339 になる。利用者の Log モジュールは、prelude の Log を隠して動く。
- 既定の出力と標準ハンドラ:
  - 書式は、水準・JSON の引用・NaN・u64 の最大値・属性の重複で、design 5.3 の書式に一致する。
  - Debug は捨てる。
  - withTextLogger・withAttributes・空と非空の withSinks、節からの送り直しは、どれも重ねて出力しない。
- テストの確かさ（読んで確かめた）:
  - io_modes の三件は、両 IO 方式で順序・エスケープ・一回性・sink の Fail の後の未実行を厳密に比べる。
  - runtime_builtins は、R0202 と最後の書き出しを確かめる。
  - desugar_export の log-standard は、VM と参照インタプリタの差分比較にも通している。

### 4. 三つの不透明型（G3）

- 拒否:
  - 外からの構築・更新・表現のパターン・自動アクセサは、E0340 で拒否される。
  - NonEmptyList の内部の欄（first・rest）も、外からは E0340 になる。
- 失敗の優先順と値:
  - checkLength は InvalidBounds を先に返す。
  - checkIndex は、負の添字と長さ以上の添字を同じ OutOfBounds で返し、失敗値へ List を保存しない。
  - map は、先頭を先に一度だけ変換する。
- テスト: Reference の記録で、順序・途中の Fail・先頭の Fail の後の未実行を確かめる。
- 中身は壊せないが、表示から欄の名前が見える（軽4）。

### 5. 生成の有限性・制約・記録の移行（G4・G5）

コードを読んで確かめた（test_derive.py は実行していない）:

- 宣言グラフ:
  - 強連結成分は Kosaraju 法で、明示の積み重ねで求める。
  - 最小量は未確定から固定点で決め、必須欄の循環は None のまま拒否する。
  - 非正則な再帰は、辺の型引数の並びで拒否する。
- 生成の予算:
  - 予算は「最小量＋size」である。後ろの必須欄の最小量を先に予約する。
  - 容器の個数は `budget div child_min` で抑え、子には実消費量だけを引く。
  - 各節点は 1 以上を消費するので、生成は停止する。size 0 では容器が空になり、Option も None になる。
  - 加算は `MAX - minimum` で飽和させる。容器の `cap + 1` も、節点の消費 1 があるのであふれない。
- 縮小:
  - 削除の段を欄順に先に置き、その後に一欄ずつの置換を行う。
  - 置換の自己候補は `=` で遅延して除く。equality の要求は、shrink_equality の固定点で署名へ伝える。
- 記録の移行:
  - 旧記録（版 1・2）は読み取りで照合し、本文のハッシュが合わなければ止まる。
  - apply と check は、版 3 と生成規則の版の一致を要求する。

### 6. 保管の hash（G6）

- 6 ファイルは、すべて完全一致の改名（R100）で移っている。manifest.json の開始版は G5 の取り込み `b72e4bf4` である。
- 現役の参照:
  - check.sh の glob・分類・dry-run の表示、try-actions-migrate の除外一覧、AGENTS.md、source-migrate の README から、旧道具への参照を除いた。
  - 現役のファイルに残る参照は、test_policy の仮のパスと軽5 のリンクだけである。
  - `named_inventory` を使う現役の example はない。
- 保管 README は「戻せば通る」と書かず、旧 parser と N1 の入力が要ることを明記している。

### 7. Writer の同期と後片付け（G7）

- 一度目の中断: 中断の前にファイルが空であることを確かめる。SIGINT・SIGTERM と両 IO 方式で、130・全内容・空の stderr を照合する。
- 二度目の中断:
  - 親が両端を非ブロッキングで持つ二つの FIFO を使う。
  - 内側の目印で、一度目の受信と解放の開始を観測する。
  - 外側では、詰め物を 4096 バイトだけ読み、未読数の増加で部分書き込みを観測する。
  - 二度目の中断の後に、残りの詰め物と本文の一部だけがあることを照合する。
  - flush が全量を書き終えた場合は、assert が失敗する。誤って成功にはならない。
- 後片付け:
  - Process の Drop が子を kill/wait し、読み手を join する。
  - 欄の宣言順により、fifos は一時ディレクトリより先に捨てられる。
  - 本番のコードは変えていない。
- Linux での同期は確かめていない（design 11.2 が未達の扱いを定めている）。

### 8. 横断

- 作業 ID と TODO 番号:
  - 追加した行（crates・tools・scripts）に、作業 ID（H1・G3 など）と R 番号の引用はない。
  - 設計書への追加に、【未決】【要検証】・TODO 番号の引用はない。
- 新しいコードのコメントが引く設計書の節は、すべて存在する（02-04「位置の式の事前展開」、03-10「実行」、07-03「中断の要求のテスト（初回リリース版）」ほか）。
- 依存と大域の状態:
  - Cargo.toml と Cargo.lock は変わっていない。
  - H2 の sha2 は既存の依存である。新しい大域の状態はない。
  - 番地の `as usize` は識別にだけ使い、32 ビットでも成り立つ。
  - MAX_LIST_LEN と Integer の対応は 03-06 に記してある。
- 規約: 本番のコードに、新しい unwrap・添字・panic・unsafe はない。
- テストの弱化: H・G で、既存の assert の削除・期待値の緩和・新しい ignore は見つからなかった。既存のテストで gc-stress の入力を縮めたのは、H1 の百万要素・百万段の長いテストだけであり、既定の構成は元の大きさを保つ。新しい共有のテストは、gc-stress で深さを 6 にしている（既定は 8・12）。
