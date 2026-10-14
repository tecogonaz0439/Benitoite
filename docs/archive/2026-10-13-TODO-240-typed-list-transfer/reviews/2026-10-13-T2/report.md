# コミット 9b0fe82e（TODO-240 T2）のレビュー

レビュー担当: Opus 5.5（サブエージェント）。ファイルは書き換えていない。対象は e410cf5e（T2 を取り込んだ後）のコード。新しいテストを既定の構成と `gc-mark-sweep,heap-verify,gc-stress` の構成で走らせ、すべて通った（gc-stress でも 4 件の合計 0.22 秒）。報告の本文をオーケストレータが保存した（要約を含む）。

## 総評

High と Medium の所見はない。T1 のレビューの M1 と L1〜L7 にすべて対応している。

- `from_iter_exact` は `from_values` と同じ形の木（末尾の葉、厳密なノード、根のシフト量、頭の欄）を作る。長さの検査は確保の前。反復子の長さの食い違いは `Stop::Internal`。`ValueCtx` の区間の中だけで動き、回収は起きない。要素数分の `Vec<Value>` はなくなった。
- `ExternalRoute::of` と `dispatch_three` の除外の範囲は一致している。経路のテストが 2・3 引数の各位置の組を確かめる。
- 文書（03-10・02-09・リファレンス 21 節・CHANGELOG）は実装と合い、L5・L6 は直っている。

## 所見（Low）

- **Low-1**（external/runtime.rs:1749-1766）: `typed_lists_and_dynamic_calls_agree` を 2 引数にしたため、3 引数の `dispatch_three` の `Bytes` の腕（`List[Byte]` の所有）と、数のリストを含む 3 引数の動的な経路を実行するテストがなくなった。修正案: 3 引数の組を残し、`List[Byte]` は `call_both`、数のリストは経路が `Dynamic` であることを確かめて `call` で結果を確かめる。
- **Low-2**（02-09:355）: 「…引数が 2 個以下の場合に限り、3 引数の組は動的な経路で渡す。」の述語が欠けている。修正案:「…引数が 2 個以下の場合に限って型付きの呼び出しで呼び、3 引数の組は動的な経路で渡す。」
- **Low-3**（runtime/list.rs:63）: `nodes` を `Vec::new()` から倍々に伸ばす。修正案（任意）: `Vec::with_capacity(remaining / WIDTH)`。
- **Low-4**（確認だけ）: 実行ファイルの大きさはこのレビューでは測っていない。具体化の数 642 はコメントの計算とマクロの形に合う。

## 対応（オーケストレータ、作業 T3）

Low-1〜3 を直した。Low-1 は `three_argument_list_calls_follow_their_routes` を足した（`(s64, list<T>, f64)` で、`List[Byte]` は型付きと動的の両方、数のリストは動的な経路であることを確かめて結果を確かめる）。Low-4 は T2 の作業の報告で測った値（strip の後 21,936,880 バイト、T1 の前から +480,552 バイト）で確かめた。
