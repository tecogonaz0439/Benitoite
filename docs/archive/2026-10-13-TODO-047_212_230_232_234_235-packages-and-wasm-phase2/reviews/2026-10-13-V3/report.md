# 作業 V3 のレビュー

- 対象: コミット `5bc22c82`（Pass records, variants and enums across the external boundary (V3)）。
- 根拠: `decisions.md`（R3・R8）、`plan.md`（共通の決まりと作業 V3）、`reviews/preflight-V1V3.md`（共通と V3 への補足）、AGENTS.md の実装の規約、スキル test-audit、実装担当の報告。
- 方法: `external/types.rs`・`convert.rs`・`check.rs`・`text.rs`・`mod.rs`・`tests.rs`、`diag/codes.rs`、ゴールデン（`records`・`record-mismatch`・`unsupported-inner`）、文書の差分を読んだ。Wasmtime 49.0.2 の `runtime/component/values.rs`（`lift` と `lift_variant` の燃料の数え方）と、wasmparser 0.258.3 の `limits.rs` と `validator/types.rs` を突き合わせた。cargo は走らせていない。指数的に増える例は、コードを読んで導いたもので、実行して確かめてはいない。
- 記録: レビュー担当（Opus）が応答で返した全文を、オーケストレータが要点を保ってここに写した。

## 要約

照合と変換は R3・R8 と事前点検の補足のとおりで、型の合うプログラムが誤った結果、panic、内部の誤りになる入力は見つからなかった。重い指摘は一つで、宣言の型の展開に大きさと深さの上限がない（Medium）。ほかは Low が 4 件。

## 指摘

### M1（Medium）宣言の型の展開に大きさと深さの上限がなく、共有した型（DAG）で指数的に大きくなる

- ファイルと行: `crates/benitoite/src/external/types.rs` 40〜147 行（`plan`・`expand`）、185〜296 行の `bind`、298〜333 行の `DeclPlan::show`。
- 問題1（指数的な大きさ）: `expand` は型の束縛ごとに `DeclPlan` の木を新しく作り、共有しない。再帰の検出は経路で行うので、兄弟の欄で同じ型を使う形は通る。欄を二つ持つ型を n 段重ねると節点は 2^n になる。展開はコンポーネントを読む前に行われ、宣言ごとに展開し直す。
- 問題2（深さ）: `expand`・`bind`・`show`、`DeclPlan` と `WitPlan` の Drop は Rust の再帰である。V3 からは型の宣言の連なりの長さだけ深くなり、入れ子の上限では抑えられない。スタックを使い尽くすとプロセスの異常終了になる（AGENTS.md「再帰の深さ」）。
- 再現の入力（実行していない）: `record T0`（`a: Integer`）、`record T1`（`a: T0`、`b: T0`）… を T40 まで重ね、`@external("wasm", "x.wasm", "f") function f(v: T40) -> Integer` を書くと、`benitoite check` は約 2^40 個の節点を作ろうとする。
- 修正案: wasmparser はコンポーネントの型の深さを `MAX_WASM_COMPONENT_TYPE_DEPTH = 100`、型の大きさを `MAX_WASM_TYPE_SIZE = 1_000_000` で抑える。`DeclPlan` の節点はどれも少なくとも一つの WIT の型の節点に対応するので、これを超える宣言の型はどのコンポーネントとも照合できない。`expand` に深さと節点の数の予算を渡し、超えたら E1010（注記を一つ足す）にする。100 万では検査が重いので小さい値でもよい。03-10「型の対応」に上限と理由を書く。

### L1（Low）注記 `types` の文が、型パラメータの制限をレコードにも掛けるとは読めない

- 場所: `diag/codes.rs` の E1010 の `types`（生成物とゴールデン `unsupported-inner.text.stderr` も）。
- 修正案: 「records and `data` types that have no type parameters, are not recursive, and whose constructors take at most one argument」の形にする。

### L2（Low）注記 `arity` が、どの構成子かを示さない

- 場所: `types.rs` 132 行、`codes.rs` の `arity`。
- 修正案: 注記に `{ctor}` を加えて構成子の名前を示す。

### L3（Low）単体テストの成功の表の一部がゴールデン `records` と重なり、標準ライブラリの直和型を試していない

- 場所: `external/tests.rs` 403 行付近（`aggregate_types_match_structure_and_normalized_names`）。
- 修正案: `records` と重なる行（`byteStart`、enum の `BlueIsh`、`Circle(Float)`・`Empty`）を消すか、関門のコメントにこの表に固有の契約を書く。`records` のゴールデンに `Trait.Ordering` を `enum { less, equal, greater }` に渡す呼び出しを足す。M1 の上限の境界を表に足す。

### L4（Low）利用者が `Option`・`Result` と同じ名前で宣言した `data` の照合の誤りに、標準ライブラリの型との取り違えが示されない

- 場所: `check.rs` の `unsupported`（`user_type` の注記は E1010 にしか付かない）。
- 再現の入力: 同じファイルに `data Result`（`Ok(Integer)`・`Error(String)`）を宣言し、`function f(r: Result) -> Integer` を WIT の `result<s64, string>` と照合すると、E1008 になるが取り違えの注記が付かない。
- 修正案: 名前が `Option`・`Result`・`Pair`・`Triple` のどれかの型パラメータのない利用者の型で、WIT の側が `option`・`result`・`tuple` の場合に、照合の誤りにも `user_type` の注記を付ける。

## 確かめて問題がなかった点

- 名前の比べ方: `-` を除き ASCII の英字を小文字にし、`_` は残す。重複は両側で調べ、位置ごとに比べる。`HTTP-error`・`a-bc`・`byteStart`・`x_y` の場合をテストで確かめている。
- 照合の規則: レコードは `record` だけ、引数のない構成子だけの `data` は `enum` と中身のない `variant`、引数 1 個の構成子を含む `data` は `variant` だけ。ペイロードの有無・数・名前・型の食い違いを `reason` で示す。
- E1010 の系: 型パラメータ、引数 2 個以上、直接・`List` などを通した・相互の再帰を捕まえ、兄弟の欄の共有は通す。別名は展開済み。すべてコンポーネントを読む前に出る。
- 標準ライブラリの型: `Option`・`Result`・`Pair`・`Triple` を先に判定する。標準ライブラリのレコードと `data` はすべて `public`。組み込みのタグの定数は宣言の順と一致する。
- 変換: レコードは頭と欄の数を確かめ、構成子はタグから場合を引く。戻りの向きは WIT の名前から場合を引く。どちらも明示の作業列で、`from_wasm` の作りかけの値は `NoGcCtx` の区間の中に限られる。
- 予算: Wasmtime 49.0.2 の `values.rs` の record・variant・enum の数え方と `lift_variant` に一致し、境界の値で確かめている。
- 結果の確かめ: ゴールデン `records` が欄とタグの対応を両方向で確かめる。
- 規約、テスト（否定のテストが理由まで確かめる、10 秒以内、名前）、文書（03-10、02-09、02-07、リファレンス 21 節、CHANGELOG、`diagnostics.md`）は問題ない。
