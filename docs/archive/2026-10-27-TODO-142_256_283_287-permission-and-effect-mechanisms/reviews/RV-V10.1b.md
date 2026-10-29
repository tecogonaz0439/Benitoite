# RV-V10.1b: 回帰・J2 の差分案・H31 の局所比較の独立レビュー

2026-10-30。対象は `v10.1b/` と未コミットの差分（基準 `bae86164`。`range-sources/expected.json` の変更と入力2件）。ファイルと git の状態は変えず、レビュー用の target で CLI を作り直して J2 の入力と範囲の実ソースの局所比較を再現した。`lake build`・`check-formal.sh`・`check.sh` は走らせていない。主な再現の出力を `v10.1b/rv-probes/` に写した。

結論: 重大0・中4・軽4。差分案は未適用で処理系に影響しない。中1・中2・中3・中5 を直してから取り込む。

## 自分で再現・照合したこと

- J2: `check --report=json` で、send の節だけのハンドラは終了2・E0501 一件・7行19列（`protected()`）・残る効果 `Http.Connect["api.example", 443]`、完全なハンドラは終了0。sendIn の節だけのハンドラも E0501 になった（両方の節を持つハンドラだけが完全）。期待値の固定 → CLI のビルド → 実行の順で、三つのハッシュも一致した。v0.0.12 から HEAD への `Http.bnt` の差分は `Connect.sendIn` の追加だけである。
- 差分案: `git apply --check` は終了0、`src/` に差分はない。境界テストの変更案は計画どおり（0.0.12→E0908、0.0.13→受理、0.0.14→E0907）。
- H31: 期待値の固定 → 書き出しの順で、変更前の expected.json は HEAD と一致した。書き出した corpus から非 Top を数え直し、signature は3（ops/0 の PathIn と sample の surface・core の header の PathIn）、forward は7（加えて両 header の File.Write の添字と、節の本体の writeTextIn の ranges）で、期待値と一致した。二点を実際に通している。書き出しのテストは出力先をリポジトリの中に限るので、レビュー用の target では書き出しを再現できなかった。担当の書き出しへレビューの CLI で `test_range_sources.py` を走らせ、終了0・17群・20定義・非 Top 14群（h31 は3と7）・Top 互換3群・拒否8・除外8・報告26入力・50コマンドを再現した。
- 依存のハッシュ: 06-09 の規則で計算し直し、旧値 `957fa49a…`、新値 `3964a146…` とも一致した。
- H11: 01-06 の59行と `typeck/scope/lower.rs` の block・with（`i != 0`）・Constant の記録位置を照合し、読解は正しい。
- 義務の行23・35は未確認・未完のまま。行35を局所の成功だけで閉じていない。

## 指摘

| 番号 | 重さ | 箇所 | 問題 | 修正案 |
|---|---|---|---|---|
| 中1 | 中 | `j2-rewrite-inventory.md/.json` の「テストと登録・文言」 | `crates/benitoite/src/typeck/pattern_ext.rs:920`（`#[cfg(test)]` の中で MemFs の `package.bnt` に `language \"0.0.12\"` を書く）が漏れている。0.0.13 の登録の後、external の場合に E0908 が先に出て lib のテストが失敗する。エスケープした形が検索に掛からなかったと見られる | src を5ファイル（計10、重複を除いて68）にし、`git grep -E '0\.0\.12|0, 0, 12'` で数え直した結果を記録する |
| 中2 | 中 | 同上 | テストが読む文書の例が、一覧にも除外の表にもない。`docs/reference/benitoite.md` の2059・2077・2109行（reference_examples が `benitoite check` で検査する files の例）、`docs/design/01-spec/01-02-syntax.md:477`（spec_examples が読む text の例）、06-09 の20・32行、docs/ja、install.md。reference_examples の例は版上げの後に E0908 になる見込み | 「文書の例」の区分を一覧に加え、読むテストを添える。01-02 の例が版を照合するかは V10.3a で確かめる |
| 中3 | 中 | `j2-registration-proposal.patch` の `SCOPED_HTTP_OPERATIONS_HELP` | 「additional Http operations」は不正確。増えたのは `Http.Connect.sendIn` の一つだけで、Q2 の「事実だけ」に照らすとぼかしている | 例: 「Http.Connect declares send and sendIn; a handler that handles only Http.send leaves Http.Connect in the effect contract」 |
| 軽4 | 軽 | 同上の summary と help | 既存の E0908 の summary・help は小文字で始まり（固有の語を除く）、句点がない。案は大文字で始まり句点がある | 既存の形に揃え、テストの notes/helps の案も同時に直す |
| 中5 | 中 | `expected.json` の `h31` ブロック、results.md | `formal/tests/test_range_sources.py` は exit・definitions・nonTopRangesMinimum・nonTopRanges・surface だけを読み、`h31` の欄（署名の添字・効果・prim・出現の数）は一回きりの `v10.1b/verify-local.py` だけが確かめる。常設の比較は件数3・7で一部を守るが、prim の取り違えや件数が同じまま位置がずれる退行は捕まえない。results.md はこの区別を書いていない | results.md に明記する。V10.1d でも `verify-local.py`（または同等の照合）を走らせるよう申し送る。比較器の拡張は J3 の判断に回す |
| 軽6 | 軽 | `expected.json` の `nonTopRangesAddition.counting` | h31 の2件の数え方がない（`h31-expectations.json` だけにある） | 足すか、足さない理由を results.md に書く |
| 軽7 | 軽 | test-audit の関門の記述 | h31-user-forward は signature の場合の内容を含む。signature の場合に固有なのは扱わない利用者原子 Audit を header の Top として残す点で、既存の user-spelling と近い | signature の場合だけが捕まえる退行を一文で書く。書けなければ forward の1件へ絞ることを検討する |
| 軽8 | 軽 | W-R の出力先 | 書き出し先の環境変数を渡し忘れ、テストが既定の場所に書いた件は、移した一覧とハッシュの不変が残り妥当。ただし check.sh の work の既定の振る舞いである | 後の作業の W-R に出力先の環境変数の指定を書く |

## 問題がなかった点

- J2 の期待値を実行の前に固定し、対照（完全なハンドラ）が受理されること。
- 差分案が未適用で、節の書き換え方・移行の手順・移行の例を含まないこと（Q2）。
- 一括置換から除いた8行（0.0.4 と 99.0.0 を狙う入力、ゼロのハッシュ、過去の登録、CHANGELOG）の判断。
- ハッシュの再計算が 06-09 の規則どおりであること。
- 期待値を処理系の出力から作らず、固定の台本が処理系を呼ばないこと。
- 局所の比較を全比較の代わりにせず、K10.3b の入力ハッシュが古くなることを記録していること。
- 行23・行35・H08・H09 を確認済みに変えず、H11 の文書の不足と実行の要る受理の差を分けていること。
- W-R の dry-run の7項目の選択、check.sh と time の終了状態、07-03 の普通の作業の欄。
- 相対リンクは全件存在し、手元の絶対パス・`work/`・docs/todo へのリンク・担当の名前はない。

## 対応（取りまとめ）

| 指摘 | 対応 | 置き場所 |
|---|---|---|
| 中1・中2・中3・軽4・中5・軽6・軽7 | 採る。中5 は比較器を拡張せず（J3 に当たる台本の変更を避ける。設計者の委任による取りまとめの判断）、results.md に明記し、V10.1d で `verify-local.py` を走らせる | V10.1bb、V10.1d |
| 軽8 | 採る。V10.3a 以後の W-R・W-V の依頼文に出力先の環境変数を書く | 取りまとめ |
