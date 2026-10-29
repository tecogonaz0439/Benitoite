# RV-V10.1d: 版上げ後の全比較の影響段の独立レビュー

2026-10-30。対象は `v10.1d/`（未追跡）と、作業ディレクトリの `target/v10.1d-logs/`（台本・ログ・比較の結果）、出力 `target/{desugar,coverage,interval}-diff/v10.1d`、引用元の K10.3 の出力。ファイルと git の状態は変えず、ビルド・テスト・Lean は走らせていない。ハッシュの照合と読み取りで確かめた。

結論: 重大0・中2・軽4。段の選び方・台本・件数・H31 の判定は崩れない。この合成の判定は最終の関係状態へ引用してよい。中の2件は記録の文面の不足で、取り込みの前に直す。

## 確かめたこと（問題なし）

- 段の選び方: formal の408項目と rust-toolchain.toml を K10.3b の最終状態の sourceHashes と比べ、無作為の12件・七実行ファイル・rust-toolchain.toml・lean-toolchain・lakefile.toml がすべて一致した（七実行ファイルは V10.1a の relation-state とも一致）。読者の入力（named-programs-corpus `5bff0451…`・builtins・stdlib・coverage、COV の named-all-corpus・future-corpus）は K10.3・k10.3-reexport・V10.1d の三つで一致し、引用した `report.json` と `surface-check/report.json` も K10.3 と同一。K10.3 の後の変更（506ファイル）は formal/・formal/tests・scripts/・check_named.py・check_batch3.py・batch3/manifest.json・range-budget/expected.json に及ばない。引用した独立段が起動するのは Lean の実行ファイルだけで、実 CLI と cargo を呼ばない。実 CLI を使う三段はすべて走らせ直した。lake build を走らせずに引用した判断は妥当。
- 台本: phase-a/b1/b2 の引数は check-formal.sh の該当段と一字一句一致し、最初に prepare を通る。compare.py と cite.py の重ね方は同じ。cite.py の写しは内容の写しで、3,174件すべて inode が元と異なりリンク数1。K10.3 の manifest の12,872保存物（3,475,896,354 bytes）を全件ハッシュして不一致0、V10.1d の12,904保存物も全件一致。三つの出力先のファイルはすべて最終 manifest に載り、古い出力は混ざっていない。check_named が作り直した2,785件は、計時の4欄のほかは JSON として同一。
- 件数: K10.3 と V10.1d の manifest の counts の違いは rangeSources の groups（15→17）・definitions（18→20）・nonTopRanges、期待値ファイルのハッシュ、計時の欄だけ。旧15群の successes は全件同一で、増えたのは h31-user-signature（1定義・非 Top 3）と h31-user-forward（1定義・非 Top 7）だけ。増えた保存物32件はすべて h31 の名前のファイルで、消えたファイルは0。
- H31 と義務の行35: `h31-final-verify.py` は `v10.1b/verify-local.py` の H31 の照合を一行も弱めず、変えたのは出力先と J2 を外したことだけ（J2 は版上げ前の資料で V10.3a で決着済み）。固定したファイルのハッシュは freeze と一致した。行35を閉じてよい。
- 引用票と記録: f-q.md は 07-03 の欄をすべて埋め、段の実行と引用の合成と明記し、一括の終了0と読める文はない。大きなファイル11件の合計 478,968,832 bytes を検算して一致。写した50件のハッシュは一致し、手元のパス・禁止のリンク・担当の名前はない。

## 指摘

| 番号 | 重さ | 箇所 | 問題 | 修正案 |
|---|---|---|---|---|
| 中1 | 中 | results.md「Lean の設定・固定版・七実行ファイル」末段、f-q.md「終了・時間・最大常駐量」 | 16 GB 級の計算機の注意が「余裕がない」の一句だけ。ログの `peak memory footprint` は区間比較 30,032,057,704 bytes（約27.97 GiB）、manifest 30,307,931,664 bytes（約28.23 GiB）、collect 24,978,917,232 bytes（約23.26 GiB）。区間比較は sys 335秒が user 286秒を上回り、page faults は261,515回。測った計算機の物理メモリは 32 GiB。最大常駐量の14.9 GiB だけを見ると 16 GiB に収まると誤読されうる | footprint の原値と物理メモリを記録し、「16 GB 級では同じ手順で走る保証がなく、ほかの重い作業と並べない」と書く。K10.3 の一回目の 13.385 GiB（getrusage、方式が違う）と並べ、増えた原因は断定しない。TODO-314 の manifest の重複との関係にも触れる |
| 中2 | 中 | results.md「作業と判定」第3段落、f-q.md「判断者・日付」 | README の J2 の決定は V10.1d の起動前に設計者の了承を得ると定めるが、記録は「設計者の委任による取りまとめの判断」とだけ書き、委任の記録先を引いていない | 取りまとめが README に委任の範囲を書き足し、記録からそこへリンクする |
| 軽1 | 軽 | results.md「引用した出力と読者の入力」、f-q.md | 「389ファイルが同じバイト列のまま」のうち73件は check_named が作り直して同じバイトになったもので、K10.3 のまま残る引用は316件 | 二つに分けて書き、引用の範囲を明示する |
| 軽2 | 軽 | f-q.md「設定・固定版・道具」 | Python 3.9.6 は直前の記録の値で、V10.1d の実行では取っていない | そう書く |
| 軽3 | 軽 | results.md「K10.3 と版上げ後の件数」 | RV-UB30 軽2 の限界（effect を宣言する testdata 36件の一つ一つが書き出されたかは確かめていない）が、行35を閉じる判断の脇に書かれていない | 一文で残る限界を書き添える |
| 軽4 | 軽 | 作業ディレクトリ | レビューの途中で同じ作業ディレクトリに V10.1c の修正（`src/typeck/tests/interpolation_formats.rs`）と `v10.1c/` が現れた。V10.1d の final-state の「追跡木に差分なし」は記録の時点では正しい。修正は src 内のテストで交換の入力ではない | 最終の関係状態へ引用するとき、V10.1c の差分を以後の変更に加えてどの段が読むかを判定する |

## 対応（取りまとめ）

| 指摘 | 対応 | 置き場所 |
|---|---|---|
| 中1・軽1〜軽3 | 採る | V10.1db |
| 中2 | README に委任の範囲を書き足した（2026-10-30）。記録からリンクする | README、V10.1db |
| 軽4 | 採る。V10.1c の修正は `#[cfg(test)]` の中のテストの1行で、全比較の書き出しの入力ではないことを F-Q の以後の変更に加える | V10.1db |
