# RV-R20.5: 予算の値と拒否理由の独立レビュー

2026-10-29。対象は R20.5 の未コミットの差分と `r20.5/` の results.md・ログ・`limits.json`。作業用のディレクトリは書き換えず、scratchpad の target で release の CLI を一度ビルドして入力を走らせた。Lean の `Budget.admit`・`Run.step`・`blindStep`・`Run.enter`・`Run.leave`・`rejoin`・`Required.ofIndex`・`acceptBody` と照合した。再現の入力のうち要のものは `r20.5/rv-probes/` に写し、全件の大きさと SHA-256 を同じ場所の `MANIFEST.txt` に残した。

結論: 条件付きで取り込み可。中2・軽5。中1 は R20.5 の成果物である採用値そのものに関わり、基準版より精度が下がる退行である。中1・中2 をこの枝で直してから取り込む。

## 指摘

| 番号 | 重さ | 箇所 | 問題 | 修正案 |
|---|---|---|---|---|
| 中1 | 中（退行） | `scope/local.rs` の `DEFAULT_SCOPE_LIMITS`、`scope/input.rs` の `Structure::number`、`scope/mod.rs` の `analyze_pending_with_limits`・`number_with_budget`、`scoped_calls.rs` の `limits()`、02-05 の採用値の【決定】と「理由:」 | 番号付けが局所解析と同じ上限（本体 16,384）を使い、本体のカウンタは入れ子の本体で 0 に戻らず定義ごとに数える。全体のカウンタも定義ごとに作るので、本番では本体と全体が常に同じ値になる。番号付けのイベントは局所解析の操作の 3〜4 倍なので、本番で先に届くのは常に番号付けであり、局所解析の上限で届くのは本体の保持数（512）だけになる（局所解析の最も密な形を 1,000 回並べても番号付けで止まる。`dense-100.json` の候補の比較で失われた範囲も全て `numbering_stopped`）。番号付けの停止はリテラルのパターンも Top にして budgetExceeded で拒否する。`if` を含む行は 400 行（`t4-400.bnt`。399 行は通る）、算術と呼び出しだけの行は 819 行（`t3-819.bnt`）で、最後の `Scope.checkPathIn(pattern: "/data/**", …)` が狭い戻り注釈で E0519 になる。基準版の番号付けの上限（10 万）なら受理していた。採用の根拠は dense-100 の 15,003 イベントに対する約 1.09 倍の余裕だけで、普通の文の密度（1 行 20〜40 イベント）を測っていない。計上の意味は Lean と一致するが、Lean にない番号付けの停止（Rust だけの資源制限）が主な超過の経路になり、Lean が定めるリテラル保持付きの超過は本番でほぼ起きない | 番号付けの上限を `DEFAULT_SCOPE_LIMITS` から分け、共有定数の展開を止める目的で別に測って決める（10 万でもよい。15k イベントで約 4 ms の線形）。または入れ子の本体ごとに数える。そのうえで局所解析の 4 上限のどれが本番で届くかを確かめ、02-05 の「理由:」と results の候補の表を直す。普通の文の密度の入力を測定 Q に加える |
| 中2 | 中 | `diag/codes.rs` の `scope_budget`、`scoped_calls.rs` の `diagnostic(…, analysis.stopped)` | 番号付けで止まった場合も `BudgetExceeded{Body,Operations}` として同じ注記「local Scope analysis exceeded the body operations limit; provenance was forgotten while literal patterns remain readable」が出る。実際には番号付けが止まり、拒否されたのはリテラルのパターンである（`t1.bnt`・`t3-819.bnt`・`t4-400.bnt`）。第一の読み手の LLM に原因と逆のことを示し、直し方（定義を分ける）の案内もない | 番号付けの停止と局所解析の超過を別の注記にする。前者は「この定義の番号付けが上限を超え、全ての規則が Top を要求する」趣旨にし、定義を分ける案内を加える。02-10 を直し、gen_skill で作り直す |
| 軽1 | 軽 | `accept_program` の `signature.admits(ranges)` による NotCovered の判定が、`accept_call` の Required の分類より先に効く | widen では、本体の保持数の超過の後（`t9-511.bnt`・`t9-512.bnt`）、推論した成功値の別名（`t10.bnt`・`t10c.bnt`）、明示の Top の引数（`t11.bnt`）がどれも notCovered になる。同じ形の射影は unknownSource（`t13.bnt`・`t15.bnt`）。DET-05 の「明示の Top も unknownSource」「超過なら budgetExceeded」が widen では成り立たない。Lean では型付けが R を決めてから受理するので健全性の誤りではないが、理由の分類は Lean と比べられない | widen の許容の失敗をどの理由で報告するかを 02-10 と 01-12 の対応の行に書き、K10.2 の比較へ申し送る。Required に寄せるなら判定の順を直し、理由のテストに widen の行を加える |
| 軽2 | 軽 | 計画の R20.5 の節と義務の対応表 | 設計書は Lean の `acceptBody`（`result.1.exceeded`）に合わせて「最後の Run が超過していれば」に改めた（正しい修正）。計画は「本体のどこかで」のまま。帰結として、lambda の中だけで本体の上限を超えた場合の内側の Top の位置は unknownSource になる（コードと Lean を読んだ判断。自然な再現は軽1 の経路に隠れて取れなかった） | 取りまとめが読み替えを記録し、K10.2・R40.1 へ申し送る |
| 軽3 | 軽 | E0521 | 自然に届く入力がなくテストもない。案内の「節の引数に型注釈」が収束させるか確かめていない。再推論は `check_function` だけで行い、const の初期化式のハンドラは再推論なしで E0521 になるので、本文の「関数の handle の数まで再試行」と合わない。主文の「scope inference」は節の範囲の添字の選択の言い方として曖昧 | R20.6 で再現の入力を探して文言を確かめ、const の扱いを 02-05 に書く |
| 軽4 | 軽 | 02-05 の採用値の「理由:」 | 「数百のハンドラを含む入力」は Scope の局所の計上が 0 で上限の根拠にならない。「全体は本体の 4 倍」は測っていない（中1 のとおり本番では届かない） | 理由から外すか、限定して書く |
| 軽5 | 軽（性能） | 節の保留の解き方（`finish_next` ごとの `propagate_effects` と `effect_inputs` の作り直し） | 後の節の lambda の形は 100/200/400 組で 0.11→0.37→1.38 秒、全 File.Read の節の形は 0.18→0.63→2.40 秒で、再推論 1 回でもほぼ二乗。1,000 組で十数秒の見込み。部分更新と索引の再利用にする対策案は妥当 | docs/todo の TODO-028 の子として登録する |

## 問題がなかった点

- 計上（同定、引数の読み取り、checked の再照合、射影の適用、事実の書き込み、Ok の腕、別名、unknown・リテラル・整数・other・const の 0）は `stepCost`・`argCost`・`readCost` と一致する。
- 判定の順は `Budget.admit`（本体の操作数→全体の操作数→本体の保持数→全体の保持数）と一致する。失敗した計上を採らずに忘れる点、停止後に位置だけを増やす点も `Run.step`・`blindStep` と一致する。
- Enter・Leave・Restore は `Run.enter`・`Run.leave`・`rejoin` と一致する。4 形のテストの期待値（停止番号 13/17/9/5、match 22 の事実数）を Lean から手で計算し直して一致した。
- 理由の分類（最後の Run の超過、リテラルの保持、局所の文字列は未知、明示 Top の射影は unknownSource）は実装とテストで確かめてあり、退行テストが基準版で失敗することも記録にある。
- atomicCoverOnly の説明は codes.rs・01-12・02-10 で揃っている。01-06 に RV-R20.4 新3 の修正が入っている。
- 長いテストの印、gc-stress での縮小、release の測定と特殊構成の時間の分離は規約どおり。`limits.json` は Lean の `Limits`/`Cap` と同じ形で K10.1 へ渡せる。
- 本番の差分に `unwrap`・添字・`as` はなく、文言は codes と text に置き、gen_skill の生成物も更新済み。W-R は check.sh 自身の終了 0、483.45 秒、1,830 件成功、比較器の自己検査 39 件。

## 対応（取りまとめ）

| 指摘 | 対応 | 置き場所 |
|---|---|---|
| 中1 | 採る。推す案は、番号付けの上限を局所解析の上限から分けて別の定数にし、普通の文の密度の入力を測定 Q に加えて決め直す。局所解析の 4 上限が本番で届くかを確かめ、02-05 と results を直す | R20.5b |
| 中2 | 採る | R20.5b |
| 軽1 | 採る。分類を文書にし、Required に寄せるかは R20.5b で判断して results に書く。K10.2 へ申し送る | R20.5b・K10.2 |
| 軽2 | 採る。読み替えを R20.5b の results に記録し、K10.2・R40.1 の依頼文に入れる | R20.5b・K10.2・R40.1 |
| 軽3 | R20.6 へ回す（再現の入力、文言、const の扱い） | R20.6 |
| 軽4 | 採る | R20.5b |
| 軽5 | 取りまとめが docs/todo の TODO-307（TODO-028 の子）として登録する。R20.6 の項目 5 で手当てが小さく済むなら行う | docs/todo・R20.6 |
