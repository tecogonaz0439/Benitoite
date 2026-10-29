# RV-K10.1: 必須判定の入力・区間・全書き出し元の版の照合の独立レビュー

2026-10-29。対象は K10.1 の未コミットの差分（基準 `6b333d12`）と `k10.1/` の記録。作業用のディレクトリは書き換えず、レビュー用の target でビルドし、B-Lean で用意した交換の実行ファイルへ入力を通した。再現の台本・ログ・候補を除いた入力は `k10.1/rv-probes/` に写した（全件は写さず、大きさとハッシュを `LARGE-FILES.txt` に残した）。処理系の本体の差分は0行で、指摘は交換のテスト・台本・文書・記録の範囲にある。

レビュー中、書き出し先の検査がリポジトリの中を要求するため、写したソースから実行したところ、作業用のディレクトリに追跡されない `out/` が一時的にできた。レビューアがすぐ外へ移し、`git status` が元に戻ったことを確かめた。追跡ファイルと git の状態は変わっていない。

結論: 重大0・中2・軽3。挙げた修正を記録と文書へ入れれば取り込んでよい。

## 指摘

| 番号 | 重さ | 箇所 | 問題 | 修正案 |
|---|---|---|---|---|
| 中1 | 中 | `tests/desugar_export/check_batch3.py:97`（版の検査を15/7へ）と `formal/tests/test_batch3_exchange.py:165` の `rust_inputs`（corpus 12/13/14 だけを受ける） | check_batch3 は先に `rust_inputs` を呼ぶので、corpus 15 を受け取ると必ず `AssertionError('expected corpus12, corpus13 or corpus14')` で止まる。batch3 の8構成（b3・blocks・g2・g3・k3・k4・m1・t3）を渡し、8件とも終了1になることを再現した。results の表は「14/6→15/7」とだけ書き、この経路が通らないことを記していない | `rust_inputs` の15/7への追随は K10.2 の担当なので本体は直さない。results の版の表と K10.2 への申し送りに、check_batch3 は `rust_inputs` が追随するまで通らない（未接続）こと、K10.2 で合わせて照合することを書く |
| 中2 | 中 | `builtins.rs::candidate_atoms`、`exchange.rs::attach_metadata`、07-04 の「脱糖の入口 desugarDiff の書き出しの候補は…」の段落、results の64行と115行 | Lean の交換の読者は `candidates` の欄を定義も参照もしない。desugarDiff は corpus 全体の JSON から原子を集める（`DesugarDiff/Main.lean:424`）ので、この欄は原子の一覧と件数に効くだけである。F-local の corpus から欄を除いた入力・空にした入力でも、desugarDiff・surfaceCheckAll は終了0・5定義一致で、nonTopRanges だけが18から17になる。readScoped の上限を `File.Read["/**"]` へ広げ、具体化した原子が定義に現れない入力でも、欄なしで desugarDiff・builtinCheck・surfaceCheckAll は終了0・一致した。同じ段落の既存の理由（候補を型表の原子まで広げても結果は変わらない）と並べると、欄を加える根拠がない。results 115行の candidates-before の失敗は Rust のテスト自身の照合の失敗で、Lean が要した証拠ではない | (a) 欄を外し、07-04 の追加文を消す。(b) 欄を残し、07-04 に「Lean の入力の必須欄ではなく、desugarDiff が原子を集める対象に入るだけで、脱糖の比較結果に影響しない」と書き、results の64行・115行を直し、K10.2 の nonTopRanges>0 の群ごとの条件を欄を除いた件数で判定するよう申し送る |
| 軽1 | 軽 | 07-04 の331行（区間の Surface も15とし、scopeAcceptance の…と ranges を書く）と388行 | 区間の corpus は別の schema で、Surface 15 では範囲の欄が必須になる（`Interval/Exchange.lean:722-734`）が scopeAcceptance は持たない。results の49行とも合わない | 「区間の corpus の Surface は15とし、埋め込みの表層に範囲の欄を書く」と「通常の各入力は scopeAcceptance を書く」に分ける |
| 軽2 | 軽 | W-K の部分選択と formal_build の引用 | 07-03 は「引用して省いた検査は計画に記す」と定めるが、2026-10-29 の判断（九項目の名指しと B-Lean からの引用）は results にしかない | 取り込みのときに README の判断の節へ一行加える |
| 軽3 | 軽 | `routing-manifest.json` | 1,792件の差分は `"version": 14→15` だけで、全 corpus の routing との照合（`check_named.py` の `check_routing`）は K10.1 で走っていない。results の74行は K10.2 へ回すと書いており、記録としては正確 | K10.2 の申し送りに `check_routing` の実行を名指しで入れる |

## 問題がなかった点

- 符号順: `atom_order.rs` の符号を、Lean の `Order/Range.lean`・`Order/Atoms.lean` の式から独立に計算し直した。path の5件、endpoint の11件（v4/v6・exact/CIDR・IPv6 の全幅・exact/one/many）、名前と rho の並び、rvar・固定添字の偶奇で、テストの期待順とすべて一致した。Rust で原子の列を書く箇所は `Surface::eff` の一箇所だけである。
- 書き出しの全体: `desugar_export` を全件実行し、46件成功・既存の無視1件。rvar は全出力で型表の `prims` の下にだけ現れる。通常の全 corpus の全入力が `DEFAULT_SCOPE_LIMITS` の4値を持ち、`r20.5/limits.json` と一致する（scope-tables のテスト専用入力だけが明示の上限）。200000 と comment は交換に出ない。
- Lean の入口での読み込み: 名付きの書き出し11組は、desugarDiff・builtinCheck・surfaceCheckAll がすべて終了0。本番の表を使う builtinCheck も終了0で、R20 の終了2は閉じた。区間の書き出し10件と reader-corpus は intervalDiff が Surface 15 として読めた（入力の誤りの終了2はない）。
- F-local の再現: nonTopRanges=18 と5定義の一致を取り直した出力でも再現した。非 Top の純粋 API（パスと要求の検査と射影）と `File.readTextIn` を含み、旧 identity/make も残る。
- `Ok` の交換名: Lean の受理の入力は `"Ok"` を固定し（`Exchange/Observe.lean:227`）、`validateBuiltinShape` は表示名を照合するので矛盾しない。網羅性の program diff は名付きの各出力で不一致0。同名の利用者構成子は `con:N:t` のままで衝突しない。
- 独立の期待値: 13入口は手書きの `scope-tables-expected.json` が各入口とも参照し、scopeAcceptance の上限と解析結果は smoke のテストに手で書いた値で照合する。
- 07-04: 「未接続」の定義と、valContents の一致を書き手に任せる限界の文は Lean の `readBuiltins` と `ContentEntry` の実装どおりで、作業の ID はない。
- W-K の記録: check.sh 自身の終了0、外側338.19秒、formal_build の引用の欄（HEAD・差分の SHA-256・Lean の入力に差分がないこと・判断者と日付）は 07-03 の欄を満たす。

## 対応（取りまとめ）

| 指摘 | 対応 | 置き場所 |
|---|---|---|
| 中1 | 記録と K10.2 への申し送りを直す | K10.1b・K10.2 |
| 中2 | (b) を採る。計画の K10.1 の完了の条件（候補に署名の原子と具体化した原子を含める）を満たす欄として残し、Lean の必須欄でなく比較結果に影響しないことを 07-04 と results に正確に書く。K10.2 の nonTopRanges>0 は欄を除いた件数で判定する | K10.1b・K10.2 |
| 軽1 | 採る | K10.1b |
| 軽2 | 取りまとめが README に記録する | 取りまとめ |
| 軽3 | K10.2 の申し送りに `check_routing` を名指しで入れる | K10.1b・K10.2 |
