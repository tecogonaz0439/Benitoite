# RV-R10.8: E0519 の理由の分類（R10.8 の中1）の独立レビュー

2026-10-29。対象は R10.8 の未コミットの差分のうち `crates/benitoite/`・`docs/design/`・同梱の Skill の生成物と `r10.8/results.md` の中1 の部分（`tools/bench/compare/` は同時に R10.8b が直しているので対象外）。scratchpad の一つの target で dev ビルドを1回行い、入力を `benitoite check` に通した。作業用のディレクトリと git の状態は変えていない。

結論: 重大0・中1・軽3。理由の場合分けは入力を通したすべての場合で Lean の `atomFailure` と一致した。中1 は 02-05 の直し漏れで、これを直せば中1 の部分は取り込んでよい。

## 指摘

| 番号 | 重さ | 箇所 | 問題 | 修正案 |
|---|---|---|---|---|
| 中1 | 中 | `docs/design/02-impl/02-05-typechecker.md` の手順3 | 「理由（必要な範囲が Top なら `unknownSource`、その他は `notCovered`）」と列挙し `atomicCoverOnly` が抜けており、01-07・02-10・実装と食い違う。results の「02-05 は理由の選び方を列挙せず 02-10 を参照する記述であり、変更は不要」という判断は事実と違う | 手順3の括弧書きを 02-10 と同じ三分類に直すか、列挙を消して 02-10 を参照させる。results の判断の文も直す |
| 軽1 | 軽 | 02-10 の E0519 の段落の末尾 | 「文言は `diag::codes`、理由と修正案の文字列は型検査の `text` に置く」とあるが、note・help の英文は `diag/codes.rs` にあり、`typeck/text.rs` には理由の語だけがある | 「文言・注記・修正案は `diag::codes`、`reason` に埋める理由の語は型検査の `text` に置く」とする |
| 軽2 | 軽（任意） | 01-07「閉じた範囲引数」の E0519 の段落 | 「それ以外は `notCovered`」が個数が二つ未満の場合を指すように読める。範囲変数の場合は 02-10 にだけ「（範囲変数を含む）」とある（利用者の構文では範囲変数を書けないので仕様として誤りではない） | 任意。直すなら「それ以外の場合は」と範囲を明示する |
| 軽3 | 軽（任意） | `tests/scope_annotations.rs` の `effect_coverage_uses_one_same_named_atom` | E0501 の行の理由を空文字で表しており表の意味が読み取りにくい | 任意。`Option` にするか、E0501 の行を別の形にする |

## 問題がなかった点

- Lean との一致: 同名の閉じた原子が1つなら `notCovered`、2つ・3つなら `atomicCoverOnly`、同名1つと別名2つなら `notCovered`（別名を数えない）、要求が Top なら同名の閉じた原子が3つでも `unknownSource`（Top の判定が先）、上限に Top と閉じた原子2つなら受理、一原子で覆えれば受理、同名の原子がなければ E0501。endpoint はポート `0..4` の一原子で `0..9` なら `notCovered`、`0..4`・`5..9` の二原子なら `atomicCoverOnly`、別ホストの二原子も `atomicCoverOnly`、要求が Top なら `unknownSource`。二つの名前が同時に覆えなければ名前ごとに理由が出る。ラムダを関数型の引数に渡す経路も `atomicCoverOnly`、標準の Top の操作 `File.readText` は `unknownSource`。数える条件（同じ名前、Top と範囲変数を除く）、一原子の被覆の判定が理由の選択より前にあること（Lean の `acceptAtom` と同じ順）、主位置と副位置が保たれる。範囲変数の場合はコードを読んで `notCovered` に落ちることを確かめた。
- 文言: note は理由ごとに正確で、`atomicCoverOnly` は「和の被覆は判定しない」と書き和なら覆えるとは主張しない。help に直し方があり、`unknownSource` の help は範囲引数を省いた宣言を示す（RV-R10 軽6(c) にも答える）。英文は `diag::codes`、理由の語は `typeck::text`。
- 設計書と生成物: 01-07・02-10 の新しい文は実装と一致する（中1・軽1 を除く）。`skill/references/diagnostics.md` は `codes.rs` と一致する。
- テスト: 公開の `pipeline::check_text` からコード・理由・note と help の全文・主位置・副位置を観測する。修正前の再現ログで退行が失敗として出ている。
- work の記録: check.sh 自身の終了0、外側532.666秒、lib 1,359件・統合41ターゲット422件。外側の time の終了1は `sysctl` の権限の誤りで検査の失敗ではないと区別している。

## 対応（取りまとめ）

| 指摘 | 対応 | 置き場所 |
|---|---|---|
| 中1・軽1 | 採る。文書だけなので、R10.8b の後に取りまとめが直す（Rust の検査はやり直さない） | 取りまとめ |
| 軽2 | 採る（「それ以外の場合は」と明示する） | 取りまとめ |
| 軽3 | 任意のため R40.1 の文言の見直しのときに扱う | R40.1 |

取りまとめの対応（2026-10-29）: 中1・軽1・軽2 を文書で直した（02-05 の手順3を三分類に、02-10 の置き場所の文、01-07 の「それ以外の場合は」、results の誤った判断の文に注記）。直した後に `scripts/check.sh --level work --only spec_examples,skill_generated,spec_tally` は終了0（`r10.8/docfix-check.log`）。R10.8b（同じ枝）で計時の探査を新旧の型の形に分け（`build.py` の `probe_api` が archive の `Ty::Con` の宣言で `--cfg benitoite_range_index` を渡す）、比較器の自己検査は39件すべて成功、`6124775` と B_WORK の両方で `bridge-shared-8` を含む各7点の機能検査が通った。R10.8b の W-R は check.sh 自身の終了0、外側482.724秒、lib 1,359件・統合422件。
