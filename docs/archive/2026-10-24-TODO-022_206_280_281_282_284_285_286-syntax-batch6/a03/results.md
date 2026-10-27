# A03 の結果

状態: A03 の実装・局所検査と、指定された work の七単位を完了した。検査本体は終了0である。time -l による最大常駐量の取得はサンドボックスの制限で失敗した。独立レビューと受け入れは取りまとめが担当する。

## 基準と実装した範囲

- 作業日: 2026-10-25。
- ブランチ: `mod012/A03`。B_WORK と開始時の HEAD はともに `41ce26cfcf71aebec354e1445c645384ab1b8783`。開始時の差分はなかった。
- plan.md の A03、前提・内部契約・work A03、D2/D20、study 8.1、Lean の L01 の定義、A02 の申し送りと取りまとめのレビューを確認した。
- private/ と、それを指すスキルは読んでいない。git の変更操作は行っていない。`interval/mod.rs` の一時的な `#![allow(dead_code)]` は残した。

`interval/domain.rs` に Integer64 の正常値の閉区間を実装した。Bottom は空集合、Top は Integer64 の全値域とし、非空区間の端点を非公開の `i128` の組に保持する。構築時に値域と交差し、逆転や不交差を Bottom へ正規化する。所属・包含・交差・凸な合流を持ち、合流で穴を失う。無限端、ヒープ確保、ホストの `usize` への数値変換を使わない。失敗可能性を区間の中に含めず、型・エフェクトの規則を変えていない。

`interval/mod.rs` に部品の宣言を追加し、設計書 02-05 に領域・端点・予算との区別を反映した。既存の本体の収集・番号付け・駆動・保持形式は変更していない。上限の定数100,000・1,000,000は32ビットに収まることを点検した。

## 検査

Cargo は先行作業の `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使用した。manifest・lock・検査設定は変更していない。rtk proxy 経由で実行し、保存ログの絶対パスを `<repo>`・`<home>`・`<tmp>` へ伏せた。

| コマンド・確認 | 終了状態 | 外側の時間・記録 |
|---|---|---|
| `rustc --edition 2024 --test <tmp>/benitoite-a03/domain-probe.rs -o <tmp>/benitoite-a03/domain-probe` を `/usr/bin/time -l` で実行 | コンパイルして実行可能な出力を生成。外側は計測失敗で1 | 0.298秒。[domain-probe-build.log](domain-probe-build.log) |
| `<tmp>/benitoite-a03/domain-probe --nocapture` | 0、2件成功 | 0.210秒。境界14例と列挙した集合841組。[domain-probe.log](domain-probe.log) に検証用入力の写しも保存 |
| `cargo test -p benitoite --test call_allocations long_constant_chain_has_bounded_check_allocations -- --exact --nocapture` を `/usr/bin/time -l` で実行 | 検査1件成功。外側は計測失敗で1 | 68.823秒（初回ビルド59.41秒、検査8.52秒）。総割り当て455,783,723バイト、既存512 MiB未満。[allocation-chain.log](allocation-chain.log) |
| `cargo test -p benitoite --test call_allocations repeated_constant_diagnostics_share_bounded_origin_work -- --exact --nocapture` | 0、1件成功 | 1.433秒（検査1.33秒）。総割り当て267,658,002バイト、既存256 MiB未満。[allocation-repeated.log](allocation-repeated.log) |
| `cargo fmt --all` | 0 | 外側未計測。編集後の整形 |
| 02-05 のリンク・アンカー・フェンス・末尾空白・禁止リンクと数値の幅の読み取り点検 | 最終0 | 0.024秒。相対リンク101件。[docs-check-final.log](docs-check-final.log) |
| `git diff --check`（読み取り） | 0 | 外側未計測 |
| `scripts/check.sh --level work --base 41ce26cfcf71aebec354e1445c645384ab1b8783 --dry-run` | 0 | 0.094秒。[dry-run.log](dry-run.log) |

局所検証は Lean の L01 と独立した具体的な期待値を使った。正規化では空・一点・Integer64 の両端・値域外・`i128::MIN/MAX` を確認した。集合の検証は `[-3,3]` 内の全28区間と空集合を列挙し、交差・凸包・包含を列挙した要素から求めて照合した。Top/Bottom の両側の演算、端で触れる交差、正負の区間の合流に0が含まれること、最小値と最大値の合流も確認した。

読み取りの文書点検の初回は、既存のコードブロック中の `unused: function(` をリンクと誤認した。点検用スクリプトがフェンスとインラインコードを除いて読むように直し、101件のリンク先とアンカーを確認した。設計書側の修正は不要だった。初回の記録は [docs-check.log](docs-check.log) に残した。

作業末の指定は次のとおりである。dry-run では fmt・examples 込み lint_default・lib_default・全統合 tests_related・source_rules・skill_generated・spec_tally の七単位を確認した。

```sh
env CARGO_HOME=<tmp>/benitoite-a01a-cargo /usr/bin/time -l /bin/zsh -c 'scripts/check.sh --level work --base 41ce26cfcf71aebec354e1445c645384ab1b8783; check_exit=$?; print -r -- "A03_CHECK_EXIT_STATUS=$check_exit"; exit "$check_exit"'
```

| 結果 | 外側の時間 real / user / sys | 最大常駐量（maximum resident set size） |
|---|---|---|
| 七単位が全て成功。`A03_CHECK_EXIT_STATUS=0`。外側は time -l の計測失敗で1。[work.log](work.log) | 450.96 / 1411.54 / 54.31秒（実行器の外側450.963秒） | 取得不能。サンドボックスの制限による `sysctl kern.clockrate: Operation not permitted` |

work は一度だけ実行した。既定 lib は **1,286件成功・失敗0件・既存の除外21件**、全40統合ターゲットは合計 **378件成功・失敗0件・既存の除外10件** である。割り当て量の3件もこの状態で成功した。fmt・examples 込み clippy・ソース規約・Skill の生成物の一致・仕様集計も成功し、初回リリースの完了条件の未記入は0件だった。仕様集計の「参照のない仕様節」の一覧は、検査の失敗と区別してログに残した。

work の後は結果記録だけを更新した。最終の `git diff --check`、A03 のログ・結果の相対リンクとパス伏せ、変更ファイルの一覧の読み取り点検も終了0である。公開の型検査・診断の署名、テストの入力・上限・期待値・ignore は変えていない。32ビットについては上限の定数と `usize` 非使用の点検であり、実機検査やクロスビルドは実施していない。

## 計画からのずれと申し送り

- A03 の領域は L01 に対応する Integer64 の部品である。値の解析を駆動へ接続する A04〜A07 と、七種の値域への拡張 A13 を先取りしていない。Lean の定義・定理・公理は変更していない。
- 公開の型検査の出力はまだこの領域の演算結果を持たないため、恒久的なテストやテスト専用の公開範囲・差し込み口を追加していない。test-audit の作成時の関門に照らし、局所の数学的な検証は一時入力で行い、既存の公開境界のテストを work で実行する。本番 Rust は追加85行・削除0行、テスト Rust の変更は0行である。
- A04: `Interval::normalize`・`top`・`bottom`・`bounds`・`contains`・`is_bottom`・`is_subset_of`・`meet`・`join` を局所環境へ使用できる。端点を直接書き換える入口はない。区間自体は固定長の値なので、環境等へ保存する項目の中身として扱い、端点を予算へ二重計上しない。
- A05/A06: 中間計算を `i128` で求めた後に `normalize` で正常値の集合を作る。数学的な区間や途中の失敗可能性は呼び出し側で別に保持する。子 Bottom に親の警告を重ねず、Top と Bottom を区別する。
- 割り当て量の二つの検査は上限・入力・期待値を維持して成功した。5,000定数・1,000診断の余裕は777,454バイトであり、後の環境や結果の保持を追加する担当も局所で確認する必要がある。
- 独立レビュー・受け入れは取りまとめが担当する。stage・change・release、Lean ビルド・全比較、heap/stress、性能比較はこの作業の割り当てに含めず実行していない。
