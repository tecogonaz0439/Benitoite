# X05T の結果

着手: 2026-10-27 03:55:15 JST。終了: 2026-10-27 04:17:19 JST。所要時間: 22分04秒。

## 対象と変更

B_WORK と着手時 HEAD は `d3f7c3e5327b7e97c57d959c46ce62997bf9f009`、ブランチは `mod012/X05T`。着手時の差分はなかった。plan.md「計画の変更（2026-10-27、RV-X05 を受けて）」の X05T (1)〜(6) と、RV-X05-response.md の判断表を実装した。AGENTS.md・共通依頼文・前提と契約・検査の割り当て・X05R/X05S・D5/D17/D18/D22・RV-X05・3回目 K1 と取りまとめのレビュー・S-X の集約・指定された比較器と書き出しを確認した。rtk・test-audit・japanese-tech-writing を適用した。

| ファイル | 変更と目的 |
|---|---|
| `scripts/check/formal_interval.py`・`interval_artifacts.py` | counts で、比較済みの個別報告・manifest・観測から Bottom と Bottom 以外、利用者の警告、型に対応した非 Top の独立入力を再計算する。10系統全体に Bottom 以外の本体を要求し、各系統に Bottom 以外の本体・利用者の警告・非 Top の独立入力のいずれかを要求する。除外した本体とその独立入力を根拠にしない。新しい根拠の集計を manifest の sourceEvidence に保存する。大きい manifest と観測を同時に全件保持しないよう、既存の書き出しを相対索引と入力順を保って一件ずつ読む |
| `scripts/check/formal_interval.py`・`test_policy.py` | 負例の全12種を和集合で要求し、基本5種は全系統で必須とする。追加の種も表に示した免除以外は必須とする。免除した種に該当する候補・停止・除外が現れた場合も拒否する。Bottom だけの全体・根拠のない系統・負例の欠落を自己検査で拒否し、独立入力だけが系統の根拠になる場合も確認する |
| `formal/tests/interval_source_compare.py` | 基本の負例を選ぶ際、除外を持つ入力を外す。旧定数警告の採用済みの各組から作ったコードと一次位置が旧診断にあることを、多重集合の包含で確認してから新候補をまとめる |
| `crates/benitoite/tests/desugar_export/interval/manifest.rs` | 通常のパイプラインと同じ警告の非表示・一次位置での安定な整列を再検査の診断へ適用した後、W0401・W0402・W0404 のコード・一次位置・順序が一致することを assert する。同じ一次位置の順序も保つ |
| 07-03・07-04・plan.md | return の返す区間が未比較である限界、外部型の除外の根拠と未比較件数、関門と負例の免除、観測の診断の照合を記す。観測入口を内部用の公開入口として残す理由を契約表の注に置き、work X05T の指定を具体化した |
| x05a・x05r・x05s・x05・本改造の results.md | 元の本文を保持し、各末尾へ「RV-X05 による訂正（2026-10-27）」を加えた。Bottom の内訳、除外の限界、定数の真偽欄の読み方、Lean/Lake の版の誤記、X05T 後の関係状態と K2 を補足した |

Lean の定義・定理・前提・結論・公理、本番 Rust、型・署名・言語の規則・予算・既存六入口の入力を変えていない。停止条件には当たらず、系統ごとの新しい関門を満たさない系統は0件である。K1 全体・stage・change・release は実行していない。

## 保存済み K1 への適用

[saved.py](saved.py) は3回目の三出力先 `target/{interval,desugar,coverage}-diff/x05a-k1-run3-20261027` を読み、追加の変異試行だけを `target/x05t-check/saved-run2/` へ保存した。元の全12,063成果物のハッシュと ZIP の SHA-256 を前後で照合し、不変だった（[元の記録の保持](original-preserved.json)）。元 ZIP は [x05a-run3-k1-records.zip の索引とハッシュ](../work-copies/README.md#f475)、SHA-256 `6986e19acfa40abad5507cca1583c7240f417ee96504b58b4ddd4da0e8e4aa9e` であり、書き換えず、削除していない。 追記（2026-10-28）: 生の記録の元は git の外に置き、同日に取りまとめが削除する予定である（この作業では未削除）。大きさと SHA-256 は[保管対応表](../work-copies/README.md#分類と元の対応)に残す。

[新しい counts の根拠](counts.json)は次のとおりである。新しい sourceEvidence 以外の counts の全欄は元の最終 manifest と一致した。非 Top の独立入力には Bottom を含む。型を取得できない入力はこの根拠へ加えず、除外した本体の独立入力も加えない。

| 系統 | 非 Top 本体 | Bottom | Bottom 以外 | 比較した利用者の警告 | 比較済みの非 Top 独立入力 |
|---|---:|---:|---:|---:|---:|
| programs | 78,978 | 74,943 | 4,035 | 38 | 102,323 |
| identity | 195 | 192 | 3 | 68 | 9 |
| manifest/manifest-interval | 249 | 238 | 11 | 8 | 3,018 |
| range/interval | 65 | 65 | 0 | 6 | 7 |
| vm/original | 39 | 39 | 0 | 20 | 0 |
| vm/instrumented | 39 | 39 | 0 | 14 | 0 |
| vm/range/original | 46 | 46 | 0 | 4 | 0 |
| vm/range/instrumented | 46 | 46 | 0 | 2 | 0 |
| vm/shifts/original | 108 | 108 | 0 | 54 | 0 |
| vm/shifts/instrumented | 108 | 108 | 0 | 54 | 0 |

全体の Bottom 以外の本体は延べ4,049件である。いずれの系統も比較した利用者の警告が1件以上あり、7系統で Bottom 以外の本体が0件であることを隠さず、新しい系統ごとの関門を満たした。

保存済みの全1,459成功入力の個別報告・manifest・観測へ、新しい旧定数警告の照合を含む compare_warnings と既存の compare_structure・exclusions を適用した。旧定数警告の採用済みの組と診断は延べ60件ずつあり、全件で照合が通った。件数は10系統の延べ数であり、元ソースの固有数へまとめない。[全点検結果](saved-details.json)に系統ごとの入力数、組と診断、負例を成立させる最初の入力、除外と候補の内訳を保存した。

### 負例の要求と免除

基本の integer・after・context・next・warnings は全10系統に存在し、要求から外した種は0件である。追加の independent・userWarnings・phasePosition・externalType の4種を含め、和集合の全12種がそろうことと、免除以外の種が各系統にあることを要求する。

| 系統 | 要求から外す種 | 保存済みの全入力で確認した理由 |
|---|---|---|
| programs | phasePosition | discovery で停止する入力が0件 |
| identity・range/interval | phasePosition・externalType の4種 | discovery で停止する入力が0件、外部型による除外が0件 |
| manifest/manifest-interval | independent | 警告候補を持つ独立入力が0件（独立入力自体は5,590件ある） |
| vm の6系統 | independent・phasePosition・externalType の4種 | 警告候補を持つ独立入力・discovery 停止・外部型による除外がいずれも0件 |

全入力の形を走査し、実際に欠ける種の集合が免除表と等しいことを確認した。負例を成立させる最初の入力を選び、保存された材料・観測から同じ期待を構成した。除外を持つ入力は意図的に corpus の先頭へ置き、新しい選択がそれを飛ばすことも確認した。53回の既存 intervalDiff の呼出しで、integer・after・context・next・warnings・independent の不一致を所定の欄で拒否した。userWarnings・phasePosition・externalType の負例も各該当系統で拒否した。全件の正の解析や VM 比較は再実行していない。

旧定数警告の穴の再現には、`golden:testdata/stdlib/width-bits-s8-invalid.bnt` の新候補（node 6・outsideDomain・一次位置 `[0,191,193]`）を使った。診断のない採用済みの組を加え、その新候補に対応する利用者の警告を消すと、B_WORK の compare_warnings は受け入れた。変更後は `legacy warning identity without diagnostic` として拒否した。期待を緩めずに穴が閉じたことを確認した。

### 外部型と return の限界

外部型の除外は4入力・12元定義・16本体であり、本体自身の Top/Bottom と親候補・独立入力の候補を検査する従来の条件を保った。除外した独立入力355件中14件の整数区間は Top でも Bottom でもなく、本体14件は Bottom であり、Lean と未比較で残る。両系統の同じ除外を二重に数えない。除外の根拠を「利用者へ出す警告の候補がない」に限り、正常値全般が比較済みであるとは書かない。

return の返す区間は交換・比較していない。正常な継続の Bottom と、返す値の区間を区別する。戻り値の区間の比較、外部型の交換、観測入口を機能の下へ置く検討の docs/todo への登録は取りまとめの後片付けへ渡す。

## 検査と記録

実行場所は `<repo>`。Cargo は `CARGO_HOME=<tmp>/benitoite-a01a-cargo`、Rust の既定構成を用いた。[run.py](run.py) が正確なコマンド・開始/終了・外側時間・終了状態と、手元のパスを伏せたログを保存する。作業末の work は同じ完全な基準と指定の dry-run の後に一度実行した。初回は --test・--only を付けず全統合を含め、下記の失敗の後は古くなった検査と未実行分だけを名指しで再検査した。

| 検査 | 結果・時間 | 記録 |
|---|---|---|
| 関門と索引の局所自己検査 | 2件成功、終了0、0.221秒 | [起動](policy-local.json)・[ログ](policy-local.log) |
| 保存済み K1 への最終の追加照合 | 終了0、84.354秒。10系統・新関門・全報告の警告・免除の形・全負例が一致 | [起動](saved-run2.json)・[ログ](saved-run2.log)・[詳細](saved-details.json) |
| 書き出しの診断の assert | manifest 書き出し1件成功、終了0、13.651秒。型検査失敗の対照も成功へ足さない | [起動](export-local.json)・[ログ](export-local.log) |
| work の dry-run | 終了0、0.086秒。下記の9単位を選択 | [起動](work-dry-run.json)・[選択と理由](work-dry-run.log) |
| 初回の work 本体 | 終了1、177.882秒。全 lib と6統合が成功した後、identity・vm の診断の順序を比べる assert が失敗 | [本体](work-body.json)・[ログ](work.log) |
| 初回の time の外側 | 終了1、177.911秒。real/user/sys 177.90 / 734.30 / 35.47秒、最大常駐量は sysctl の拒否で取得不能 | [外側](work.json) |
| 残りの指定の dry-run | 終了0、0.017秒。下記の8単位と34統合を指定 | [全引数と対象](remaining-work-command.json)・[起動](remaining-dry-run.json)・[選択](remaining-dry-run.log) |
| 残りの work の最初の試行 | fmt で本体終了1・2.455秒、ほかの単位は未実行。修正したタプルの整形を直して同じ指定で再検査 | [本体](remaining-work-body.json)・[外側](remaining-work.json)・[ログ](remaining-work.log) |
| 残りの work の最終の本体 | **終了0、314.960秒**。8単位すべて成功 | [本体](remaining-work-final-body.json)・[ログ](remaining-work-final.log) |
| 同じ試行の time の外側 | 終了1、314.986秒。real/user/sys 314.98 / 808.79 / 18.65秒 | [外側](remaining-work-final.json) |
| 最終点検 | 終了0、2.088秒。元の本文・K1 の全成果物・ZIP の保持、局所 ZIP の読戻し、リンク・構文・パス・差分の空白を確認 | [点検器](audit.py)・[起動](audit-complete.json)・[結果](self-review.json) |

初回の全 lib 1,332件と統合6ターゲット（build_info・call_allocations・checked_args・cli_process・coverage_export・declarations）の成功は、`work.log` から引用する。本体・入力・期待値を変えず、修正が desugar_export のテスト補助だけなので、この成功は古くならない。残りの8単位は fmt・examples を含む clippy・残り34統合・ソース規約・生成 Skill・仕様の集計・検査方針の自己検査・Lean の既定ビルドである。指定と引用の根拠を plan の検査の割り当てへ追記した。Lean の `-M 12288` を維持し、並行ビルド・単一ファイルの検査は行っていない。最終の work 本体は終了0であり、初回に引用した成功と合わせて、全 lib 1,332件・全40統合ターゲット394件（計1,726件）が成功した。[件数](test-counts.json)は各ターゲットの最終成功だけを採り、失敗した desugar_export の途中の32成功件を二重に足していない。既定で ignored の31件は未実行として残す。fmt・clippy・ソース規約・生成 Skill・仕様集計・検査方針の自己検査30件・Lean の既定ビルドと sorry 拒否も通った。Skill の生成物に差分はなかった。

`/usr/bin/time -l` はいずれの試行でも `sysctl kern.clockrate: Operation not permitted` を報告し、**最大常駐量（maximum resident set size）は取得不能**であった。0として扱わない。最終の本体の終了0と、計測を含む外側の終了1を分ける。終了143による停止はない。計測だけを理由に検査を繰り返していない。

## 関係状態・保存・引用の範囲

3回目 K1 の実行状態は `d62dbaa1c9293bd32e3dbb1b65b1efbc90a6d44b`、本枝の基準と HEAD は `d3f7c3e5327b7e97c57d959c46ce62997bf9f009` である。元の5,995ソース入力のハッシュとの比較では、上表のRustテスト・Python4ファイル・設計書2ファイルの計7ファイルだけに差があった。[途中の関係状態・版・ハッシュ](source-state-before.json)に差の一覧、未コミット差分の SHA-256、変更したファイルと未追跡入力の SHA-256、実行ファイルのハッシュを残した。最終の [関係状態](source-state-complete.json)も保存した。状態記録自身は自己参照を避けて各 SHA-256 の一覧から除く。work 後の変更は結果と点検の記録だけである。七つの Lean の比較実行ファイルのハッシュは3回目と一致する。実 CLI のハッシュは異なるが、本枝の保存済み報告への照合と変異試行では実 CLI を起動せず、VM 比較の新しい実行済みも主張しない。

環境は Rust/Cargo 1.98.1・Lean 4.34.1・Lake 5.0.0-src+5045d00・elan 4.2.4・Python 3.9.6・macOS 27.0.1 / arm64 である。Lean/Lake の版は `formal/` で取得し、版の表記の誤りを転記していない。

局所試行の生の記録は [bundle.py](bundle.py) で [x05t-local-records.zip の索引とハッシュ](../work-copies/README.md#f477)（gitignore）へ保存し、全項目を読み戻した。[索引](local-records-index.json)は全ファイルの SHA-256 を持つ。223ファイル・31,980,217バイトを 1,741,431バイトへ保存し、ZIP の SHA-256 は `3c31fb6314d00be544baa8a324ec74421779b2d452bb5fa070172931c63ee7f5` である。 追記（2026-10-28）: 生の記録の元は git の外に置き、同日に取りまとめが削除する予定である（この作業では未削除）。大きさと SHA-256 は[保管対応表](../work-copies/README.md#分類と元の対応)に残す。

引用の判断者は X05T 担当、日付は2026-10-27である。新しい counts・負例・警告照合を保存済み入力へ適用した結果と、短い Rust の書き出しの assert の結果を報告する。元の入力・解析結果・実行ファイルを改変せずに確認した範囲だけを引用する。比較器の関係状態は変わったので、元の K1 が現在の全体を実行済みであるとは主張しない。RV-X05-response の判断どおり、S-X は3回目 K1 と本枝の追加照合を合わせて取りまとめが確認し、最終関係状態の K2 全体は Z01b で実行する。

## 初回の失敗と修正

- 初回の work は、追加した assert が生の診断列を `checked.diagnostics` と直接比べたため、identity の flow と VM の arithmetic で順序が異なり失敗した。`pipeline::append_stage` が依存・Prelude の警告を非表示にし、ファイルと一次位置の開始点で安定に整列していることを読んで確認した。assert の左側へ同じ公開時の射影を適用し、コード・一次位置・公開時の順序を比較する形へ直した。生の観測や候補の比較、本番 Rust の規則を変えていない。
- 修正後の残りの work の最初の試行は fmt がタプルの複数行の整形を要求して停止した。指定どおりに整形し、ほかの単位が未実行の同じ残りの指定を再度実行した。初回の全 work は反復していない。

- 最終点検の最初の起動は、結果文書から参照する `source-state-complete.json` を保存する前だったため、リンクの存在確認で停止した（[起動](audit-final.json)・[ログ](audit-final.log)）。関係状態の保存後に同じ読み取りの点検をやり直した。検査や比較は再実行していない。
- 最初の保存済み照合は、独立入力の型が取得できない場合に文字列となる欄へ `.get` を呼び、終了1・6.890秒で止まった（[初回](saved.json)・[ログ](saved.log)）。型のない入力を非 Top の根拠へ数えない形に直し、新しい `target/x05t-check/saved-run2/` で追加照合を通した。関門・除外・期待値を緩めていない。
- 関係状態の最初の保存では、詳細と起動記録へ同じ `state-before.json` を指定して詳細が上書きされた。詳細名を `source-state-before.json` へ分け、読み取りだけをやり直した（[最初の起動](state-before.json)・[修正後](state-corrected.json)）。検査は繰り返していない。

## 作成時の関門と申し送り

守る契約は、Bottom だけの本体数で非 Top の比較を受け入れないこと、負例の種が黙って消えないこと、診断のない旧採用済みの組が新候補を消さないこと、観測経路が通常の診断のコード・位置・順序を保つことである。退行はそれぞれ、全正常区間の Top 化、負例を成立させる入力の欠落、診断のない組の登録、観測の有無による診断の差である。従来の関門は Bottom を数え、従来の負例は未選択を許し、旧組と診断・観測と通常診断の一致は確かめていなかった。同じ成果物の境界と既存の書き出しを拡張し、診断のない旧組の受け入れは B_WORK で再現した。本番の差し込み口・公開範囲を増やしていない。テストの削除はない。

本番 Rust と Lean の定義の増減は0行。Rust の書き出しのテストは53行追加・削除0行、結果記録を除く Python の比較器・自己検査は178行追加・4行削除である（[集計](change-statistics.json)）。担当の委任、private/ とそこを指すリンクの読み取り、git の変更操作、コミット・取り込み・docs/todo の更新・公開は行っていない。独立レビューと受け入れは取りまとめが行う。

| 残る手順・検査・レビュー・受け入れ | 担当と範囲 | 見込み |
|---|---|---|
| X05T と S-X の独立レビュー・受け入れ | 取りまとめ。新関門・免除の根拠・全保存済み報告の照合・書き出しの診断の assert・訂正を確認する | 不明 |
| U01b 以降・全体の回帰・測定の判断・レビュー・受け入れ | 各担当と取りまとめ。plan の順序と既に承認された範囲に従う | plan の各作業に従う |
| K2 全体・公開候補の検査・手動照合・受け入れ | Z01b と取りまとめ。最終の関係状態で全体を実行する。本枝の追加照合を K2 の代わりにしない | K1 の実測は約44分、最終候補の時間は不明 |
| docs/todo への登録 | 取りまとめの後片付け。戻り値の区間・外部型の交換・観測入口の機能による分離 | 不明 |

## 取りまとめのレビュー（2026-10-27）

受け入れる。`reviews/RV-X05-response.md` の表の全項目を実装・記録した。新しい関門（全体で Bottom 以外の情報を持つ本体が1件以上、系統ごとに Bottom 以外の本体・比較した利用者の警告・Top 以外の独立入力のいずれか）は、個別報告・manifest・観測から件数を数え直して要約と照合しており、要約の自己申告だけに頼らない。負例の免除は入力に該当の形がないことを条件として検査され、免除した系統に該当の形が現れれば止まる。旧定数警告の組と診断の照合は、基準版で受け入れられた改変を変更後に拒否することで確かめた。変えた関門と照合を3回目の K1 の保存済みの出力に当て、全10系統が通った。これで S-X を閉じる（K1 の全体は最終の関係状態の K2 で再び通す）。Lean と本番の Rust には差分がない。
