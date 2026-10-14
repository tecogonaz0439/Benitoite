# 作業 Z3 のレビュー

- 対象: コミット `1e699b12`（41 ファイル、+2,048 / −336）。
- 根拠: オーケストレータの指示と実装担当の報告、Z2・V6a・V6c のレビューの記録の指摘、AGENTS.md の「実装の規約」、スキル test-audit。
- 方法: 差分を読み、`typeck/decls.rs`、`pipeline.rs`、`external/types.rs`、serde_json 1.0.151 の `MapKey`、rust-src 1.98.1 の使用許諾のファイルと照らした。Json の B の最短表記は机上で例を辿った。ゲストの SHA-256 と残るパスを確かめ、Rust の根の LICENSE-MIT（コミット 48a229ce）と照らした。cargo と python は走らせていない。
- 記録: レビュー担当（Opus）が応答で返した全文を、オーケストレータが要点を保ってここに写した。

## 要約

指摘と指示はおおむね正しく直されている。E0812・E0816 を型検査の段に移したこと（判定の場所、別名、他のモジュールの外部の型、二重の報告がないこと、呼び出し側の誤りより先に出ること、凍結の型に触れないこと）と、Json の B の最短表記の直し（2 の冪、非正規化数、最小の正の非正規化数、最大の有限の値）は正しい。ゲストの `validate` と作り直し・SHA-256 も正しい。Medium 2 件、Low 4 件。

## 指摘

### M1（Medium）予算を使い切った後の E1010 が、診断の文言を表の外で上書きしている

- 場所: `external/check.rs` 609〜620 行（`exhausted_declaration`）、`external/text.rs` の `declaration_budget`。
- 問題: `DiagBuilder::new(DiagCode::E1010).arg("ty", "")` の後に `diagnostic.message` を差し替えている（本番のコードではここだけ）。skill の参照の文書に載らず、JSON の診断に空の `ty` が残り、主ラベルも空になる。
- 修正案: E1010 の表に注記か場合ごとの型板を足し、`message` の直接の代入を除く。`gen_skill` で作り直す。

### M2（Medium）外部の型を欄に持つレコード・直和型を辿る新しい判定に、テストがない

- 場所: `typeck/external.rs` 35〜58 行（`contains_external` の `TyCon::Adt` の分岐と `visited`）、`external/tests.rs` 1374 行からの表。
- 問題: 外部の型を欄に持つ `record` か `data` を外部の関数に渡す例がなく、この経路の誤りを捕まえられない。
- 修正案: `record Holder`（`cell: Cell`）を `function f(h: Holder) -> Integer` に使う行を、`uses` なし（E0816）、`uses State`（診断なし）、`uses Console.Write`（E0812 で `uses State` への置き換え）の三つと、後方で宣言したレコードの場合で足す。

### L1（Low）判定の範囲が以前の照合の段より広く、報告の順が変わった

- 問題: `Ty` の全体を辿るので、関数の型の中や型パラメータを持つ型の型引数の中の外部の型、存在しない resource を指す外部の型（E1012）にも、E1010・E1012 より先に E0816・E0812 が出る。往復が一回増え、03-10 の「同じ原因の診断を重ねない」と少しずれる。
- 修正案: 判定を「渡せる形」に揃える（`Ty::Fn` と型引数を辿らない）か、03-10「照合」に「エフェクトの検査は型検査の段で行うので、E1010・E1012 より先に報告される」と書く。

### L2（Low）THIRD-PARTY に、静的に結合した sysroot のクレートが足りない

- 問題: `regex.wasm` に結合された hashbrown 0.17.1（std の依存、`MIT OR Apache-2.0`）が表にない。compiler_builtins（`MIT AND Apache-2.0 WITH LLVM-exception AND (MIT OR Apache-2.0)`）も三つとも載せていない（結合しているかはバイナリでは確かめていない）。足した std・alloc・core と dlmalloc の出どころの記述は正しい。
- 修正案: Regex の表に hashbrown を、三つの表に compiler_builtins を足す。結合を確かめた手順を一文で書く。

### L3（Low）「理由:」の後に、決定と説明の文が続く形が残っている

- 場所: 02-09 355 行、03-10 132 行。
- 修正案: 「理由:」の文を段落の末尾へ移すか、後ろの文を別の段落に分ける。

### L4（Low）CHANGELOG の Fixed に、試験用の部品の変更が入っている

- 修正案: pure Json と WASM の Json のゲストについての後半を除き、E0812・E0816 と E1010 の変更だけを残す。

## 確かめて問題がなかった点

- E0812・E0816 は `check_declarations` の後、`traits::collect` の前に全モジュールを対象に検査し、照合の段の判定は消してある。足したテストは呼び出し側が `Console.Write` を宣言していない形で E0812 を確かめる。
- Json の B: 2^-24 では下側の候補が下側の間隔の半分を超えて離れるので読み戻せず、直した後は A と一致する。下側の候補が元の値に戻るかの判定は Rust の Dragon の条件と同じ。非正規化数では中点の判定が常に偽になり、`5e-324` と `1.7976931348623157e308` の出力は変わらない。
- ゲストの `validate` は `parse_seed` を共用し、誤りの位置と文言、深さの上限は変わらない。`json.wasm`・`regex.wasm` の SHA-256 と大きさは README と一致し、ホストのパスと三つ組は残っていない。
- README とメモリの上限の記述、E0253、宣言ごとの E1010、デストラクタの名前、試験用のコンポーネント、E0812 のラベル、文書の直し。
