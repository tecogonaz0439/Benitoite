# RV-K10.3: 全比較の失敗の修正と、動かなかった段の再確認の独立レビュー

2026-10-30。対象は K10.3 の未コミットの差分（基準 `d35557f9`）と `k10.3/` の記録、一回目の全比較の出力。設計者の指示（動いた段を走らせ直さない）に従い、レビューアは `lake build`・`check-formal.sh`・Rust の書き出しを走らせず、保存済みの出力のハッシュの照合と、記録・差分・台本の読み取りで確かめた。ファイルと git の状態は変えていない。

結論: 重大0・中1・軽3。K10.3 は取り込んでよく、K10 の段を閉じてよい。中1 は policy を強める修正で、全比較の結果には影響しない。

## 指摘

| 番号 | 重さ | 箇所 | 問題 | 修正案 |
|---|---|---|---|---|
| 中1 | 中 | `scripts/check/test_policy.py` の `test_formal_remaining_batch3_profiles_and_failure_propagation`、`check_named.py:573` | 新しい policy は `check_remaining_batch3` を `runpy` で直接呼ぶので、四群の一覧から一群を消す変更は捕まえるが、`main()` の `check_remaining_batch3(directory)` の一行を消しても通る。既存の check-formal.sh の policy は check_named.py を代用しているので、ここでも捕まらない。results は守る退行に「比較の呼び忘れ」を挙げている。範囲の四呼び出しは `calls.count(call) == 1` と失敗の伝播で固定できている | `main` の AST を読み、`check_remaining_batch3(directory)` を `check_routing` より前に呼ぶことを確かめる一件を足す |
| 軽1 | 軽 | `tests/desugar_export.rs:521-527`（`CorpusStream::push`） | Lean の読者は `scopeAcceptance` が欄をちょうど三つ持つことを要求する（`Exchange/Observe.lean:202`、`Version.lean` の `validateScopeAcceptance`）が、Rust の assert は `limits` しか比べない。patterns や hosts が欠けても Rust で通り、Lean で初めて落ちる | 欄の集合が `{patterns, hosts, limits}` であることを assert し、除外の入力では `acceptance(&Value::Null)` 全体との一致も assert する |
| 軽2 | 軽 | 07-04 の527行（三欄と射影を実ソースと比較する作業は未実施）と529行（この実行比較は未実施である）。K10.3 より前からの記述 | 同じ章の180〜182行は `interval_range_vm.py` が実 VM で minimum・maximum・value を観察すると書き、全比較でも Range37 が成功している。K10.3 は「全比較は未実施」の句だけを書き換えたので、この二文が残った | 実際に接続済みの範囲（実ソースと実 VM の照合。評価関係との一致は信頼の範囲に残る）へ書き直す |
| 軽3 | 軽 | manifest の段の最大常駐量 12.99 GiB | Python が manifest・material・observations を同時に保持する経路で、16 GB 級の計算機では余裕がない。原因はプロファイルで特定していない | 逐次の読み取りへ変える課題として docs/todo に登録する（受け入れを止めない） |

## 問題がなかった点

- (a): `check_programs` は `compare_routing` と同じ `relocation_independent_routing` で両辺を正規化する。対象は `entry: NoMainFile { dir: "..." }` の完全な書式だけで、dir は `crates/benitoite/<name>` に完全一致するか、絶対位置なら末尾が `"/"+suffix` と一致することを確かめ、basename だけでは比べない。ほかの除外の理由は字面のまま比べる。旧比較の三不一致・正規化後の三一致・相対位置の異なる6負例の拒否を確かめた記録がある。
- (b): 空の解析表と本番の四上限は既存の二つの失敗分岐と同じ形で、Lean の desugarDiff・builtinCheck・surfaceCheckAll は `excluded` が空でない入力の検査を飛ばす（`DesugarDiff/Main.lean:350`、`BuiltinCheck/Main.lean:158`、`SurfaceCheck/Batch.lean:175`）ので、受理の誤りにつながる経路はない。K10.1・K10.2 で見つからなかった理由（`check_routing` は schema を見ず、局所照合の入力に入口で失敗する入力がなかった）も妥当。
- 合成の判定: 書き出し直しの1,009ファイルのうち1,008が一回目と大きさ・ハッシュとも一致し、異なるのは `named-programs-corpus.json`（343,290,941 → 343,291,355 バイト、差414バイト）だけ。builtins・coverage・stdlib は一回目と同じ。coverageProgramDiff は coverage と builtins だけを読むので一回目の成功を引用できる。凍結した input-manifest の差は該当の一行だけ。07-03「結果の保存と引用」の欄はそろい、一回目の終了1も書き換えていない。
- 再確認の件数: desugarDiff は golden 373入力一致・419除外と random 1,000入力一致、定義1,075＋72,778、不一致0。builtinCheck は1,373入力・144,932比較・不一致0。surfaceCheckAll は51,742一致・対象外19・準備失敗と不一致0。check_named は1,792入力・73,853定義・coverage 22,483、四群・六入口・拒否の各照合。manifest・verify は終了0。
- 設計書: 07-03・07-04 に作業の ID はない。07-03 の追記は合成の判定の規約として妥当で、07-04 の書き換えは接続済みの範囲と証明していないことを区別している（残りは軽2）。
- W-K: check.sh 自身の終了0、外側330.56秒、Rust 1,455成功・失敗0、policy 31件。formal_build の引用の欄もそろう。

## 対応（取りまとめ）

| 指摘 | 対応 | 置き場所 |
|---|---|---|
| 中1・軽1・軽2 | 採る。軽1 は書き出しの値を変えない assert の追加で、一回目と再確認の全比較で Lean の読者がすべての入力の三欄を受理しているので、全比較を走らせ直さない（設計者の指示） | K10.3b |
| 軽3 | docs/todo に登録する | 取りまとめ |
