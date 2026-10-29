# RV-R40.2: 正規表示・bounds と名前による照合の独立レビュー

2026-10-29。対象は R40.2 の未コミットの差分と `r40.2/` の記録。作業用のディレクトリは書き換えず、scratchpad の target でビルドして入力を通した。`review.json` の 20 ファイルの SHA-256 は今の作業ツリーと一致し、レビューした状態と W-40 で検査した状態は同じ。入力は `r40.2/rv-probes/` に写した。

結論: 取り込んでよい。重大0・中1・軽3・参考2。中1 を R40.2 の追補で直すか、R40.3 の最終照合で閉じると記録することが条件。

## 指摘

| 番号 | 重さ | 箇所 | 問題 | 修正案 |
|---|---|---|---|---|
| 中1 | 中 | `cli/tools/test_runner/docs/prepare.rs` 約232行（`effects = Some(EffectSummary::default())`）、06-01「Effects の任意欄 bounds」の「確定した純粋な契約だけが `expanded: []`・`bounds: []` となる」、06-04「check/error 例の契約は例の報告に保持する」、`skill/references/inspection.md` の "A known pure contract has empty..." | 期待どおりに拒否された `error` の doc 例は、例の `effects` が `{"expanded":[],"bounds":[]}` になる（`docerr.bnt`。例の中で `uses File.Write` を宣言し E0401 で拒否される。status ok・終了0で例の effects は空）。新しい文は「空は確定した純粋の契約だけ」と言い切るが実装はこれに反し、06-04 の「error 例の契約を保持する」も成り立たない。集約（aggregateEffects）は error 例を除くので実行の上限は誤らないが、例単位の欄を読む受け手は拒否された例を純粋と読む。挙動は R40.2 の前から | 案 A: 06-01・06-04・inspection.md に「error 例は契約を持たず空の Effects を返す。純粋を意味しない」と書き、06-04 の「保持」を check 例に限る。案 B: error 例の effects を null にする（版2の既存の受け手との互換を点検する必要がある） |
| 軽1 | 軽 | 06-01「契約の解析が未完了なら、その Effects に bounds を置かず…」と inspection.md の "Unfinished contracts do not supply bounds" | 実装（`EffectSummary::value`）は Effects を出すとき必ず `bounds` を置き、未完了なら Effects 全体が null。「Effects はあるが bounds がない」状態をこの処理系は作らない | 「この処理系は Effects を出すとき常に `bounds` を置き、未完了なら Effects を null にする。`bounds` のない Effects（旧版の処理系の報告）は `expanded` の各名前を全対象の上限として読む」と、作り手の規則と受け手の規則に分けて書く |
| 軽2 | 軽 | `diag/codes.rs` の E0407 `scope_widen` | `pending.kind` で種類は分かっているのに、help は `Scope.PathIn` と `Http.RequestIn` の両方を並べる（`widenPathIn` に `Http.RequestIn[...]` の注釈を付けた `w3.bnt` でも同じ文）。誤りではない | 種類ごとの help に分ける |
| 軽3 | 軽 | `cli/inspection.rs` の `scope_value` の `Range::Host` の腕 | エフェクトの原子に Host 単独の範囲は現れない（`Http.Connect["a.example"]` は E0520 で拒否される）のに、この腕は囲みのない `{kind:"exact", name:…}` を出す形で、DET-06 の表にない形を将来黙って出しうる | `internal("host-only scope in effect contract")` を返す。到達しうるならその形を 06-01 に書く |
| 参考1 | — | `builtins/funcs/file.rs` の `writeTextIn`・`appendTextIn`・`writeBytesIn`・`appendBytesIn` | 旧名を `write_done` → `result_error` の `alloc_str` に渡したまま。名前が報告に出るのは失敗の理由の文字列を確保できないときだけで、02-10 の新しい文も読み取りの操作に限るので規則には反しない | 揃えるなら読み取りと同じく名前を引数で渡す |
| 参考2 | — | 06-06 の 133 行・143 行 | ハーネスが読む欄として `expanded` だけを挙げている（06-06 は R40.3 の対象） | R40.3 で bounds の扱いを 06-06 にそろえる |

## 問題がなかった点

- bounds の形: `{name, scope}`、`basis: declaredUpperBound`、all・pathExact/pathTree（`/**` 自身は pathTree "/"）・endpoint（host と ports の minimum/maximum）・ホスト名の exact/one/many と name・IP の exact/cidr と family/address/prefixLength は DET-06 と一致する。`/32`・`/128` は exact に正規化され、`::ffff:192.0.2.1` は v6 のまま、`0.0.0.0/0` は prefixLength 0 の cidr。略記の組 4 つは原子 4 つに展開され、パスの `"` は正しくエスケープされる。Top を空配列にしない。`IO.All` はすべての名前の all に展開される。checkReport 1・testCheckReport 1/2 の形式の版は保つ。
- 旧い受け手の互換: 既存の厳密な比較のテストから bounds を除いても必須の欄は保たれ、名前だけの `--allow-effects` もどの表の例でも成功する。
- 意味の一致: main・各テスト・doc の例・aggregateEffects は同じ `EffectSummary::value` で直列化され、確定した Scheme の宣言上限から作る。ファイルの `uses` の範囲も合併され、集約は被覆による間引きをしない和集合。不完全な場合は null で `"bounds"` の文字は出ない。
- 名前による照合: `--allow-effects=File.Read,File.Write` で範囲付きの main を受理し、不足は E0512・終了2。範囲付きの引数は使い方の誤り（終了2、標準出力は空）。`check` に `--allow-effects` を渡すと単一の JSON の使い方の誤り。
- 処理済みの利用者エフェクト（`u1.bnt`、handled-user の表）は bounds へ戻らない。File.Read 13・File.Write 16・Http.Connect 2 の完全なハンドラ 3 例と一節ずつ欠いた 31 例を、通常の検査・test・集約・E0501・名前による照合まで一つの表で確かめている。
- 資源の停止の名前: `readTextIn` と `readBytesIn` は開始・worker・完了・metadata の上限の検査まで自分の名前を渡し、`readBytesIn` は実 CLI で R0903・終了1を確かめている。追加したのは `&'static str` だけで、言語の値は worker に渡していない。
- E0407: 注釈なし・誤った注釈で新しい help が出て、正しい注釈と戻り型では出ない。
- 安全の説明: 設計書と Skill は bounds を宣言上限と書き、実行時の権限・実際の観測・情報フロー制御ではないことと endpoint が scheme や内容を表さないことを明記する。範囲を実際より広く・狭く報告する入力は見つからなかった。
- 規約と記録: 本番の差分に `unwrap`・添字・`as` はなく、文言は `diag::codes` にあり、gen_skill の生成物は照合済み。設計書と Skill に作業の ID はない。テストの表は独立の期待値。`work.json` は check.sh 自身の終了0、外側 264.57 秒で、初回の2回の失敗と修正も残っている。

## 対応（取りまとめ）

| 指摘 | 対応 | 置き場所 |
|---|---|---|
| 中1 | 案 A を採る（推す案。報告の意味と互換を変えない） | R40.2b |
| 軽1〜軽3 | 採る | R40.2b |
| 参考1 | 名前を渡す形に揃えるのが小さく済めば R40.2b で行い、済まなければ V10 へ | R40.2b・V10 |
| 参考2 | R40.3 で 06-06 をそろえる | R40.3 |
