# B10a-2 実装結果

## 目的と変更

型検査済みの Die を、成功時には中身を返し、失敗時には説明・原因の表示・既存の終了操作の順に実行するコア IR へ接続した。本番の構文受理と Die の交換出力は後続の作業に残す。

- `src/ir/desugar/effects.rs`: 暫定の InternalError を除き、`TryActionInfo::Die { show, exit }` を使う。入力は分岐の外の一つの let、任意の説明と原因は失敗分岐内の各一つの let に束縛する。Result は確定した辞書を既存の辞書変換へ渡し、標準の Show のメソッドを呼ぶ。Option は固定原因の String を使う。既存の exit の App に原因・任意の説明の値を付ける。Return の構成子・escape・型引数は維持する。
- `src/ir/desugar.rs` と `desugar/die_tests.rs`: B10a-1 と同じ cfg(test) の解析・型検査入口から、公開の脱糖と独立したコア検査器へ通す準備を追加した。Result の String 用の Show・型パラメータの Show・Option と、説明なし・空文字列・通常の説明の九通りを独立した期待コアと比較する。実行の九通りで入力の計数、成功時の説明/Show の未評価、説明と Show の異なる停止位置、原因の引用符と改行、None の固定原因、任意の説明を比較する。
- `src/typeck/effects/tests.rs`: 暫定の脱糖拒否の assert を、脱糖成功と独立したコア検査の成功へ置き換えた。元の全行と型・辞書・標準 exit の assert は維持した。理由は R65 に記した。
- 02-06 と 07-04: 実装済みの脱糖と、クレート内部のテスト入口・本番の受理・Rust の交換出力の境界を反映した。07-04 の更新は共通の関門 K8 による接続状況の同期であり、形式化の定義・証明は変えていない。

IR の検査器と参照インタプリタの本体は、先行した内部報告付き App・Method の既存の経路で処理できるため変更していない。制約・辞書の選択を脱糖で再実装せず、本番用のフラグ・公開 API・ローダの差し込み口も追加していない。

## test-audit の作成時の関門

1. 守る契約は、公開の脱糖が返すコアの型、入力一回、成功側での説明/Show の未評価、失敗側の説明→Show→exit の順と各 let 一つ、標準の辞書・メソッド・終了の参照、原因・説明・位置の保持である。
2. 説明や Show を分岐外へ出す、同じ計算を二回生成する、順序を逆転する、Result の error の代わりに成功値を表示する、型パラメータの辞書を失う、None に辞書を要求する、終了を囲む関数の戻り型で具体化する、報告や位置を落とす退行を捕まえる。
3. 脱糖を主な境界とし、独立した期待コアを厳密に比較する。変数番号は束縛から読み、期待する計算・順序・辞書は TryInfo を使わず構築する。実行の検査は、構造比較だけでは確かめられない停止理由と State の計数を観測する。従来の Return の検査と内部報告を手で付けた App の検査には、Die の分岐生成と辞書への接続がなかった。
4. 既存の cfg(test) の解析・型検査を共有し、脱糖側の準備も cfg(test) に限る。本番の公開範囲の拡大やテスト用の注入引数は要しない。

新機能の接続であり、既存の不具合を直す作業ではない。開発時にテスト入力の data の文法、名前付き引数、lambda の return と契約名を修正した。新しい検査は最初の実行でその入力不備により失敗し、修正後に全行が通った。既存の assert の比較の緩和・ignore・対象外への移動は行っていない。テストの削除はない。本番の Rust は差分で80行増、テストと cfg(test) の準備は426行増である。通常入力と Die 入力の診断・脱糖・コア検査の準備は同じ補助へまとめた。

## 検査

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib ir::desugar::die_tests -- --nocapture` | 2件成功。最後の個別実行1.74秒 |
| `cargo test -p benitoite --lib` | 1,189件成功、失敗0件、既存の ignore 21件。初回164.37秒、準備の共有後の最終ツリー158.21秒 |
| `cargo test -p benitoite --test desugar_export --test random_programs --test golden` | desugar_export 16件成功・既存の ignore 1件、golden 2件成功。random_programs は2件成功・1件失敗。下記参照 |
| `cargo clippy --workspace --all-targets` | 成功。5.31秒 |
| `cargo fmt --all --check` | 成功 |
| `git diff --check` | 成功 |
| `bash scripts/check-formal.sh` | 最後まで成功。lake build、独立入力46件、六入口と最終 manifest の照合が成功 |

乱択差分は300入力・反例0件のまま121.073996167秒となり、既存の60秒制限で失敗した。入力数・種・coverage・時間制限・手動実行の条件は変更していない。R64 の変更前の基準123.066秒との関係と、性能の対策を広げず未達を引き継ぐ判断を R66 に記した。統合検査の終了状態は101であり、成功として扱わない。desugar_export は2.99秒、golden は95.86秒だった。

ログは `/private/tmp/benitoite-b10a-2-*.log` に保存する。

形式化の出力は `target/desugar-diff/run-97605/` と `target/coverage-diff/run-97605/` にある。lake build と各実行ファイルのビルド、独立した width 4件・named 12件・extensible 22件・try 8件、計46件は成功した。脱糖の全コーパスの書き出しは783.130秒であり、include-ignored の desugar_export は17件すべて成功した。

| 六入口 | 結果 |
|---|---|
| coverageDiff | 通常10,020件・view付き10,028件が一致。不一致・fuelExhausted 0 |
| desugarDiff | golden 349入力・random 1,000入力が一致。1,736入力中1,349件を書き出し、既存の check error 387件、範囲外0件を維持 |
| builtinCheck | 対象1,349入力、summary 比較72,468件。不一致・非収束0 |
| coverageProgramDiff | match 16,417件・bind 6,036件、計22,453件が一致。不一致・範囲外・fuelExhausted 0 |
| surfaceCheckAll | 51,645件一致。不一致・準備失敗・lazyRestriction 0。既存の対象外19件・q11 1件を維持 |
| surfaceCheck と最終 manifest | 全1,736入力・73,746定義・22,453 coverage entries の対応が一致。corpus 9・型表3・網羅性3と六入口の件数・分類が一致 |

最終の個別照合は210秒で成功した。契約の破損3件、hole/pipe の破損6件、名前付きの破損6件を意図した理由で拒否し、独立したパッケージ入力の宣言所属と view も一致した。対象内の件数・対象外理由を下方修正していない。

Lean の定義・証明と corpus 9・型表3・網羅性3は変更していない。Die のソース→Rust の交換出力→Lean の一貫した比較は B10a-3/B11 に残る。scripts/check.sh（dry-run を含む）と gc-stress の構成は依頼に従い実行していない。

## 計画との差と申し送り

R65 の暫定拒否の assert の期待値変更と、R66 の乱択差分の時間制限の未達を記録した。言語の仕様・診断・型の受け渡し・交換形式の版は変えていない。B10a-3 は Die の交換出力の暫定拒否を除き corpus 10 へ切り替える。B11 は本番の構文受理と、ソースから内部依存・型・脱糖・実行・報告までの一貫した検査を担当する。

B10 の親の完了確認・測定、B10a/G5 の親の完了と G5b の所定レビューを、この枝の自己確認で完了扱いにはしない。コミットと docs/todo の変更は行っていない。
