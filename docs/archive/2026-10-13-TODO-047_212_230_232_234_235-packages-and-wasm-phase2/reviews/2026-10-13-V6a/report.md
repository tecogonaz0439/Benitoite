# 作業 V6a のレビュー

- 対象: コミット `804eb873`。Cargo.toml、07-03 の 2 行、`testdata/packages/libraries.files/wasm-{hash,regex,json}/`、ゴールデン `wasm-hash-same`・`wasm-regex-same`・`json-wasm-same`。
- 根拠: `decisions.md`（R3〜R7、R10、Q10、Q11、R11）、`plan.md`、`reviews/preflight-V6V7.md`。比べた A は `src/builtins/funcs/{hash,regex,json}.rs` と `src/prelude/stdlib/Regex.bnt`。AGENTS.md、test-audit、実装担当の報告。
- 方法: `git show` でコードを読み、ゲストの関数と A の関数を一つずつ突き合わせた。三つの `.wasm` を取り出して SHA-256 と `strings` を調べ、ゲストと本体の Cargo.lock の版、使用許諾の本文を比べた。cargo は走らせていない。
- 記録: レビュー担当（Opus）が応答で返した全文を、オーケストレータが要点を保ってここに写した。

## 要約

ゲストは A のコードをほぼ逐語に写し、依存の版は本体に揃っている。ゴールデンの範囲では A と同じ結果を返す。WIT と Benitoite の宣言は R3〜R5・R10 に合う。三つの `.wasm` に手元のパスはなく、SHA-256 も README と一致した。High はない。Medium 1 件（大きな入力でゲストがトラップする）、Low 8 件。

## 指摘

### M1（Medium）大きな入力では、64 MiB の上限のためにゲストが A と違う結果（トラップ）になる

- 場所: `wasm-json/rust/src/lib.rs`（`parse`・`JsonMaterial`、`validate`・`pretty`・`minify`・`parse`、`GuestDocument::parse`）、`wasm-regex/rust/src/lib.rs`（`find_all`・`found`）。
- 問題: Json の三つの越え方と `validate` は、入力を写したうえで材料の木を丸ごと作る。10 MB の `[0,0,…]`（約 500 万要素）では木だけで約 120 MB になり、上限を超えてトラップする（机上の見積もり）。document（越え方 3）は状態を持つインスタンスの寿命の合計に数える。Regex の `find-all` は 10 MB の `"a"` に `a` を当てると 1,000 万件になり、結果だけで数百 MB になる。A は同じ入力に答える。V6a のゴールデンは小さい入力だけなので表に出ていないが、V6c・V8 の 10 MB の比較に響く。
- 修正案: ゲストの README と測定の文書に上限とトラップの可能性を書き、入力の種類ごとに C が通る大きさを短い試行で確かめる。`validate` は木を作らない形にできる。Regex の測定は件数を返す `count` を主に使う。トラップしたときの見え方を設計者に伝える。

### L1（Low）07-03 に足した決定の書き方と、Cargo.toml のコメント

- 修正案: 07-03 を「【決定】… 理由: …。」の形に直し、Cargo.toml のコメントに根拠の節（設計書 07-03「実装の規約と静的な検査」）を足す。

### L2（Low）dev のプロファイルで選んだクレートの範囲を aarch64 でしか確かめていない

- 修正案: 選んだ根拠（`cargo tree` で確かめた範囲と、測った機械）をコメントか改造のディレクトリに残す。x86_64 で測る機会があれば `cranelift-assembler-x64` を加えるかを判断する。

### L3（Low）ビルドの再現性は同じ種類の機械の範囲に限られる

- 問題: `json.wasm` に rust-src のパスとホストの三つ組（`1.98.1-aarch64-apple-darwin`）が残り、ほかの種類の機械ではバイト列が一致しない。
- 修正案: README にそのことを書くか、`--remap-path-prefix` で std のパスを `/rustc/<commit>` に揃える。

### L4（Low）THIRD-PARTY の範囲に Rust の標準ライブラリが入っていない

- 問題: `.wasm` には静的に結合した Rust の std・alloc・core と dlmalloc も入っている（`MIT OR Apache-2.0`）。Hash の README は「Benitoite から写したコード」と書くが、Hash のゲストは A のコードを写していない。
- 修正案: 標準ライブラリを表に足すか、載せない理由を書く。Hash の文言を直す。

### L5（Low）`Codec.parse` が節点の表の不整合を入力の誤りとして返す

- 修正案: 文言に印を付ける（`"internal: " + reason`）か、型で区別する。

### L6（Low）`json-wasm-same` の細部

- `document` の条件で同じ確かめを二度書いている。深い値は 128 段に下げたので、ゲストの反復の書き方は読んで確かめたことになる（コメントに書く）。`acceptance/json_summary.files/orders.json` などの実データを使っていない（V6c で足す）。

### L7（Low）`// spec:` の印と README の言語

- 修正案: 印に 03-10 の該当の見出しも加える。README の言語を Fuzzy（英語）と揃える。

### L8（Low）ゲストの Cargo.toml の、版を固定するためだけの直接の依存（`serde_core`・`zmij`）に理由が書いていない

- 修正案: 「数の書式と本体の版を揃えるために固定する」とコメントを足す。

## 確かめて問題がなかった点

- Regex: 既定の `RegexBuilder`（`size_limit` は除く）、`compile_error`、`find`、`matches` の手順、`replace_all` が `$1` を展開しないこと。ゲストの中で panic しうる箇所はない。
- Json: 写した関数は A と逐語に一致する。重複した鍵、鍵の順、NaN・無限大、-0.0、深さ 127・128・1000 の境界、誤りの行・列・文言の 50 件余りが A と一致する。JSON Pointer の扱い。
- Hash: sha2 0.10.9 は事前点検が許した範囲。速い経路と動的な値の経路の両方を比べる。
- WIT と宣言: すべて `s64`、版まで書いた第 3 引数、R4 の外部の型の宣言、`borrow`／`own` の方向、`uses State` の有無、R3 の名前の照合、`Json.ParseError` の直接の使用、`public(package)` の使い方。
- ビルドと配布物: SHA-256 の一致、手元のパスがないこと、空の `[workspace]`、版の一致、THIRD-PARTY の表が `.wasm` に入る依存と合うこと（ビルド用と wasm32 で入らない依存を正しく除く）、MIT の本文の一致。
- dev のプロファイルの変更は `cargo deny check licenses` に影響しない。テスト（関門、名前、Regex は一件、時間は debug で最大 4.06 秒・gc-stress で最大 5.61 秒、参照インタプリタからの除外）。
