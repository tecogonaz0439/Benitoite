# Y6 のレビュー

対象: 2be749a1「Ground the persistent collection constants in their sources and test skewed workloads」（取り込みは 95946d5b）。`git show` だけで読み、cargo は走らせていない。

一次資料は次のとおり確かめた。

- Hirai・Yamamoto の著者版 PDF（<http://yoichihirai.com/bst.pdf>）。ページの頭に「JFP 21 (3): 287–307, 2011」と「doi:10.1017/S0956796811000104」がある。
- Coq のスクリプト（<http://yoichihirai.com/Balance.v>）。
- Bagwell・Rompf の PDF（Infoscience の bitstream）と、Infoscience の記録の API（`dc.type = text::report`、`dc.date.issued = 2011`）。

## 総評

`make` と `build_sorted` の変更、RRB 木の記述、集合演算のコメントは正しい。直す必要があるのは次の 2 点である。

- 02-08 の理由の文は、一次資料が Coq で証明した範囲を超えて断定している。
- 追加したテストのコメントは、テストが実際に捕まえられない退行（join の平衡の回復の誤り）まで捕まえると主張している。

## 指摘

### 1. 【要修正】02-08 の理由の文が、Coq で証明した範囲を超えている

- 場所: `docs/design/02-impl/02-08-vm.md` の「値の表現」の箇条（マップと集合）。「理由: 挿入と削除の後に平衡を保つ整数の組はこれだけであることが、Coq で証明されている（Hirai・Yamamoto 2011、1 節・7 節）。」
- 問題: 論文が Coq で証明したのは健全性（soundness）だけである。つまり、範囲の内側のパラメータで挿入と削除が平衡を保つこと（7 節）を証明した。範囲の外が失敗すること（完全性、completeness）は、反例の木を作る手順で示している（8 節）。⟨3, 2⟩ が範囲の中のただ一つの整数解であることは、6 節で範囲を定めた結果である。要旨は次のとおり書いている。
  - "Soundness of the range is proved using a proof assistant Coq. Completeness is proved using effective algorithms generating counterexample trees."
  - 1 節の貢献の一覧にも、"(soundness) A proof in Coq ..." と "(completeness) An implemented and tested procedure for producing counterexamples ..." が並ぶ。

  したがって、「これだけであることが Coq で証明されている」は誤りである。AGENTS.md「事実と出典」に反する。調査（study.md 1.5 節）の案の文をそのまま写したことが原因であり、調査の段階で既にあった誤りである。
- 修正案: 「理由: この組で挿入と削除の後に平衡が保たれることは Coq で証明されており（Hirai・Yamamoto 2011、7 節）、平衡を保つパラメータの範囲の中の整数の組はこれだけである（同 1 節・6 節。範囲の外は反例を作る手順で示している、8 節）。」

### 2. 【要修正】テストのコメントが、捕まえられない退行まで捕まえると主張している

- 場所: `crates/benitoite/src/runtime/map/tests.rs` の `skewed_workloads_keep_update_paths_logarithmic` の直前の、作成時の関門のコメント。「回転の条件や join の平衡の回復を誤る退行を、偏った操作の列で捕まえる。」
- 問題: 実装者の報告では、次の二つの退行でテストが通った。
  - `join` の帰りの `balance` を `make` に替える変更。
  - 一重の回転の判定の `<` を `<=` に替える変更。

  コードを読むと、このテストの入力は `join` の回転を通らない。理由は二つある。
  - 削除は 0 から昇順に最小の鍵を消すので、消すノードの左は常に空である。このとき `remove` は `join2(空, 右)` を呼び、`join2` は `join` を呼ばずに右を返す。
  - 集合演算の大きい木は `set_from_sorted` で作った完全に釣り合った木である。7 要素で分割して付け直しても、背骨の部分木が少し重くなるだけで、回転が要るほど崩れない。

  `make` の `debug_assert!` が平衡の崩れを捕まえるので、`balance` を `make` に替えても回転の要る場面がなければ何も起きない。テストが確かめているのは、実質的に「昇順・降順の挿入と最小の鍵の削除で、`balance` の回転の向きと、確保の数の対数の上限が正しいこと」である。`<` から `<=` への変更は、そもそも平衡を崩さない可能性がある。崩していれば `make` の `debug_assert!` が panic したはずなので、この変更を捕まえられないのはテストの欠陥とは言い切れない。しかし「回転の条件を誤る退行」と広く書くのは言い過ぎである。test-audit の「名前や準備データが、実際に確かめていることより多くを約束しているテスト」に当たる。
- 修正案: 次のどちらかにする。
  - (a) `join` の回転を通る場面を足し、`balance` から `make` への変更で失敗することを確かめる。候補は二つある。一つは、昇順の挿入で作った木（`roots[1]` の形。各ノードが Δ の境界に近い）を集合演算の大きい側に使うことである。もう一つは、二つの子を持つノードを消す削除の列（中央の鍵から消すなど）を足すことである。
  - (b) コメントの主張を、確かめている範囲に絞る。例えば次のように書く。「偏った挿入と最小の鍵の削除で、回転の向きの誤りと道筋の長さの退行を捕まえる。平衡の崩れは `make` の `debug_assert!` が捕まえるので、デバッグビルドで走らせる。`join` の平衡の回復はこの入力では通らない。」

  (b) を選ぶなら、`join` の回転を確かめていないことを、後の課題として docs/todo に残すかを決める。

### 3. 【推奨】長いテストにした判断を、R5 と gc-stress の前例に照らして見直す

- 場所: 同じテストの `#[ignore = "long: 32,768 要素の偏った更新。回収の強制の構成で 10 秒を超える"]`。
- 問題: R5 は「2^15 要素で普通のテストにする。10 秒を超えるなら長いテストにする」と決めている。既定の構成での実測は 3.65 秒で、10 秒を超えるのは gc-stress の構成（約 22 秒）だけである。長いテストは `--full` か、選んだ検査に long が入るときしか走らない。そのため、回転の向きの退行を日々の検査では捕まえられない。リポジトリには、gc-stress の構成でだけ大きさを下げる前例がある（`runtime/assert/tests.rs:326`、`builtins/funcs/http_server/tests.rs:296` の `if cfg!(feature = "gc-stress") { … } else { … }`）。設計者のメモ（gc-stress のテストの大きさ）も、gc-stress では大きさを下げる方針である。なお `HeapConfig { stress: false, .. }` と書いても、gc-stress の構成では `heap/core.rs:121` が `stress` を強制する。
- 修正案: `let count: i64 = if cfg!(feature = "gc-stress") { 1 << 12 } else { 1 << 15 };` の形にして `#[ignore]` を外し、普通のテストにする。R5 の文言どおり長いテストに残すなら、それでよいかを設計者に確かめる。

### 4. 【推奨】`join` のコメントの「同じ手順」は言い過ぎである

- 場所: `crates/benitoite/src/runtime/map/tree.rs` の `join` の直前。「同論文に付いた Coq の証明の join_balanced（Δ = 3、Γ = 2）と同じ手順で平衡を保つ」。
- 問題: Coq の `join`（Balance.v）は、片方が `Tip` のとき `insert x r`・`insert x l` を呼ぶ。実装は空の木の重みを 1 として比べ続け、外側まで下る。study.md 1.2 節も「文字どおりの同一ではない」と書いている。`join_balanced` が `p32`（`deltaU = 3 /\ deltaD = 1 /\ ratioU = 2 /\ ratioD = 1`）のもとで平衡を示すことは確かめた。一方、根拠に挙げた 02-08 は `join` も Coq のスクリプトも書いていないので、設計書の節がこの主張を支えていない。
- 修正案: 「重い側の内側を下り、帰りに Γ の判定で回転する。Coq のスクリプト（Hirai・Yamamoto 2011 の付属、Balance.v）の `join` と同じ形で、`join_balanced`（Δ = 3、Γ = 2）がその平衡を示す。一方が空のとき Coq は `insert` を呼ぶ点が違う。」

### 5. 【軽微】02-08 の同じ箇条に残る計算量の記述が、03-06 と食い違う

- 場所: 02-08「値の表現」の同じ箇条。「分割と合併（`Set.union` など）を木の高さに比例する手間で行える。」
- 問題: この作業より前からある文である。分割は木の高さに比例するが、合併は 03-06 の表で O(m log(n/m + 1)) としており、木の高さには比例しない。今回の作業で同じ箇条を書き換えたので、ついでに直せる。
- 修正案: 「分割を木の高さに比例する手間で行え、合併（`Set.union` など）の計算量は[標準ライブラリ](../03-interop/03-06-stdlib.md)の「Map と Set（初回リリース版）」の表のとおりとする。」

### 6. 【軽微】テストのコメントに、平衡を捕まえる仕組みを書く

- 場所: 同じテストの作成時の関門のコメント。
- 問題: 確保の数の上限は余裕が大きい。挿入は実測 44 に対して上限 128、集合演算は実測 73 に対して上限 7,168 である。平衡の崩れを直接捕まえるのは、`make` の `debug_assert!` である（03-06 の確かめ方）。この依存がコメントにないので、release でテストを走らせると検出力が落ちることが読み取れない。上限が線形の退行（32,768）を捕まえる程度の働きをすることは妥当である。
- 修正案: 指摘 2 の (b) の文例のように、デバッグビルドの `debug_assert!` に頼ることを一文足す。

## 問題がなかった点

- `make` の変更: `vec!` をやめ、分岐ごとに配列のスライスを `alloc_fields` に渡す形にした。`?` の位置も、前後の `debug_assert` も変わらない。振る舞いは同じで、正しい。
- `build_sorted` の `debug_assert!`: `windows(2)` とスライスのパターンで添字を使わず、厳密な `Less` を求めている。これは `map_from_sorted` の文書の「同じ鍵を含まない」と一致する。呼び出し元の前提も読んだ。Json は `object.keys()`、Csv は鍵の順で保存した header、VM は定数、refinterp は既存の木を使う。どの呼び出し元の前提とも矛盾しない。鍵の型でない値で `compare_keys` が `Err` を返すと、デバッグビルドで panic する。型検査を通ったプログラムでは届かず、`make` の既存の `debug_assert!` と同じ扱いなので、問題としない。
- 3.4 節の引用: `isBalanced a b = delta * (size a + 1) >= (size b + 1)` と `isSingle a b = (size a + 1) < gamma * (size b + 1)` を PDF で確かめた。コメントの「一重の判定は厳密な <」は正しい。書誌（JFP 21(3): 287–307, 2011、DOI）も一致する。
- 03-06 の RRB 木の記述: 2.5 節の e = a − (⌊(p − 1)/m⌋ + 1) を "the maximum extra linear search steps" と呼んでいることと、"With m = 32 empirical testing shows that setting e = 2 gives a good compromise" を確かめた。「実験から選んだ値であり、証明した値ではない」は資料のとおりである。Infoscience の記録の種別は report、発行年は 2011 で、PDF の各ページの足は「2012/3/11」である。「EPFL Technical Report, 2011」と版の注記は事実と合う（種別の表示は Reports なので、「Technical」を外して「EPFL Report」としてもよい。好みの範囲）。
- `combine` と `rrb.rs` のコメント: 論文との違いを書き、定理をそのまま当てはめないとしている。R4 の判断と合っている。
- テストの残りの作り: モデル（`BTreeMap`・`BTreeSet`）との突き合わせ、削除の前の木の保存、両方の引数順の集合演算は、公開の関数を境界にしており、test-audit の持ち主の境界に合う。
