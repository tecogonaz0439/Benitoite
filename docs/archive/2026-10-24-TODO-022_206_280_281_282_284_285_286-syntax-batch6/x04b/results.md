# X04b の結果

着手: 2026-10-26 23:47:27 JST。終了: 2026-10-26 23:58:30 JST。所要時間: 11分3秒。

## 対象と変更

B_WORK と HEAD は `2a0e03e5097e057fb02b0712344aa7246b326d55`、ブランチは `mod012/X04b`。着手時の差分はなかった。AGENTS.md、共通依頼文、plan の前提・内部契約・X01〜X05・X04a/X04b/X05a/K1 の検査、decisions の D5・D17・D22、README の設計者の決定、study の交換の受け入れ条件と Log の接続、preflight の最初の勧告照合、X01a〜X04a の申し送りを確認した。文章には japanese-tech-writing、シェル出力には rtk を適用した。

| ファイル | 変更 |
|---|---|
| `docs/design/07-quality/07-03-compiler-testing.md` | 既存六入口を維持する区間の全比較、各比較の件数と全定義・停止の扱い、三出力先の manifest、Log の公開利用、方針自己検査の範囲を説明した。formal_build が既定ビルドだけであることを明示した |
| `docs/design/07-quality/07-04-formal-semantics.md` | intervalDiff 単体と全比較の接続を区別し、五 profile・10系統・実 VM・Log・manifest を現行の実装に合わせた。有限の比較、独立期待値だけの照合、A1 の信頼の範囲を区別した |
| `formal/README.md` | 実行方法、三つの出力先と環境変数、新しい空の出力先の条件、10系統のパスと保存する報告を説明した。全比較の古い所要時間を削除し、単一ファイルの Lean 検査例に `-M 12288` を付けた |

コード・Lean の定義・スクリプト・入力・期待値・生成物・既存見出しは変更していない。公開文書から改造の文書や docs/todo へのリンクは追加していない。言語の規則、本番 Rust の型や署名、Lean の主定理の前提・結論、公理を変える必要のある停止条件はない。

## 検査

実行場所は `<repo>`。指定された work は `--test`・`--only` を加えず、先に同じ指定の dry-run を確認して一度だけ実行した。

| コマンド・確認 | 終了状態・結果 | 外側の時間 |
|---|---|---|
| `scripts/check.sh --level work --base 2a0e03e5097e057fb02b0712344aa7246b326d55 --dry-run` | 終了0。formal/README.md のパス分類により formal_build の一単位を選択。[記録](work-dry-run.json)・[出力](work-dry-run.log) | 0.085秒 |
| `/usr/bin/time -l scripts/check.sh --level work --base 2a0e03e5097e057fb02b0712344aa7246b326d55` | 検査本体は既定の Lean ビルドと sorry の拒否を通り、`selected checks passed`。time の計測失敗により外側の終了状態は1。[記録](work.json)・[出力](work.log) | 単調時計で0.241秒、time の real は0.23秒 |

`/usr/bin/time -l` は検査本体の成功後に `sysctl kern.clockrate: Operation not permitted` を出した。maximum resident set size は表示されず、サンドボックスの制限で取得できなかった。外側の終了1を検査の終了0と混同せず記録した。計測だけの失敗を理由に、成功した work を再実行していない。別の Lean ビルドや単一ファイル検査を起動しておらず、並行ビルドもない。Rust のテスト・clippy・fmt・全比較は実行していない。

計画の「文書だけなら対象なし」とは異なり、現行の check.sh は formal/README.md を formal に分類した。指定された自動 work を変えず、選択された formal_build を一度実行した。dry-run と本実行の変更数の差（4件と6件）は、その間に本枝の dry-run の JSON/log を追加したためであり、選択された単位は同じであった。

差分の自己確認では `git diff --check` と `git diff --exit-code 2a0e03e5097e057fb02b0712344aa7246b326d55 -- crates scripts formal ':!formal/README.md'` が終了0であった。追跡済みの差分は上記三文書だけである。追加した6リンクのファイルと見出し、README の10系統のパスと実装の SOURCE_DIRS の一致、Lean の単一ファイルの例11件のメモリ指定、保存記録の手元のパスの伏せ方も確認した。[点検結果と三文書の SHA-256](self-review.json)に記録した。work の後は結果と点検記録だけを追加・更新し、三文書は変更していない。2時間の中断条件には達していない。

## 計画との差と申し送り

X04b の文書の同期の範囲に変更はない。検査の選択と計測の制限は上記のとおりである。X01〜X04a の局所比較は接続を読む根拠として参照したが、本枝の全比較の実行済みの証拠として引用していない。K1・stage・change・release は本枝で実行していない。private/ とそこを指すリンク、担当の委任、git の変更操作、コミット・取り込み・docs/todo の更新・公開は行っていない。

| 残る手順 | 担当と受け渡す内容 | 見込み |
|---|---|---|
| X04b の独立レビューと受け入れ | 取りまとめ。三文書と実装の対応、formal_build と全比較の区別、A1 の限界、指定 work の結果を確認する | 不明 |
| K1 全体の検査・レビュー・受け入れ | X05a と取りまとめ。同じ関係状態で `scripts/check-formal.sh` を一度実行する。既存六入口・各独立交換・五 profile・Rust/Lean の10系統・算術/Range/シフトの VM を含む。三出力先の入力と全報告・manifest・件数を永続の記録へ残す | 全体は不明。計画の仮見込み30〜60分を最初の全件入力の実測で更新する |
| 接続の証拠の集約・レビュー・受け入れ | X05b と取りまとめ。K1 の元の記録を x05/results.md・本改造 results.md・reviews にまとめる。Log は batch3/g2 の直接 call と六入口の成功・入力ハッシュを照合する。シフトの独立期待値だけの62行は評価関係との比較件数へ足さず、Range の理由付き事前選別も残す | 計画の実装・記録1〜2時間。レビューと受け入れは不明 |

## 取りまとめのレビュー（2026-10-27）

受け入れる。07-03・07-04・`formal/README.md` は X04a の全比較の実装と一致し、formal_build と全比較を区別している。計画は「文書だけなら対象なし」としたが、`formal/README.md` の変更で formal_build が選ばれ、成功した（分類の規則に沿う）。X05a へ進む。
