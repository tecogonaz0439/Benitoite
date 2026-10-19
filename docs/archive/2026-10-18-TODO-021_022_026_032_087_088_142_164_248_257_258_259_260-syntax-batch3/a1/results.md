# A1: RV3の指摘の修正

基準: `7f431373893055a3508b552068f3a496b9cac655`（開始時HEADとsan_benito）。2026-10-18。コミットとdocs/todoの変更は行わない。RV3原文はreviews/RV3.mdへバイト列を保って写した。

## 指摘ごとの対応

- 中1: constごとに直接参照だけを保存し、集合を移して複製を除いた。参照の新規要素を64バイトとして予算へ計上する。診断時に明示の積み重ねと訪問済み集合で辿り、直接参照と連鎖の起点を最大8件示す。途中の宣言を含む省略数をnoteへ出す。Regex/Scopeで共通化した。01-06・02-05も修正した（R169）。
- 中2: 用語集の項目を不透明型（opaque type）に改め、等値の可否と可視性を分けた。01-05/01-06・関連設計章・英語リファレンス・D/design.md・Skill・診断を揃え、生成物をgen_skillで再生成した。診断golden四件はnoteの全文だけを新文言へ更新する。docs/jaはV1に残す（R170）。
- 中3: 一検査の異なるパターンの組み立てを256件までとした。全本体で共有し、成功も数え、到達後も既存のキャッシュは使う。超過分は実行時へ残す（R171）。
- 軽1: 手書きSKILL.mdの非公式モジュール一覧へRangeを追加した。
- 軽2: G1の完了条件に、宣言モジュール内を含む不透明型のrecord/dataのJSON復号・Property生成器・縮小器の拒否テストと、公開前のG1完了の照合を明記した。在庫・生成器本体は変更しない。
- 軽3: binding.opaqueによる宣言全体の免除をやめ、構成子引数と欄の参照だけを公開契約から除く。型パラメータの検査は保つ。現構文は型宣言の制約をE0425で拒否し、構成子・欄以外に参照する型はないことも確認した（R172）。
- 軽4: ScopeError.Showで、引用前の入力を縮めて引用し直す。各引数2000バイト以内、全体4096バイト以内とし、完成したエスケープ・引用符・構成子名・括弧と末尾の省略記号を保つ。既存assertを保ち、制御文字・改行・引用符・非ASCIIの長い入力の検査を既存の両モード実行へ追加した（R172）。
- 軽5: 02-05に毎巡すべてを再投入して巡ごとの処理件数を変えないことを補った（R172）。

## 局所測定

修正前のreleaseを `cargo build --release -p benitoite` でビルドした（終了0、27.54秒）。同じ依存のrelease版regexへ `rustc --edition=2024 -O /tmp/benitoite-a1-regex-probe.rs --crate-name a1_regex_probe -L dependency=target/release/deps --extern regex=target/release/deps/libregex-49a0bd7d9ea9f81b.rlib -o /tmp/benitoite-a1-regex-probe` で結合し、単独の `/tmp/benitoite-a1-regex-probe` を実行した（終了0）。入力と測定箇所は[regex-probe.rs](regex-probe.rs)、出力は[regex-probe.txt](regex-probe.txt)。同時に別のビルドやテストを走らせていない。リンク先はregex 1.13.1のreleaseの既定機能であり、bin-benitoiteのCargo fingerprintが参照するregexのfingerprint 14789477275071638267（fb6a5b4239c73ecdのlittle-endian値）と一致することも確認した。

`\w{1000}` 一件は59006 µs（約59 ms）で `CompiledTooBig(10485760)` となった。256件なら単純換算で約15.1秒であり、病的な入力の静的組み立てを有限に抑える値として256件を採った。これは一件の局所測定からの見積もりで、一般の時間上限や本ベンチマークの結果ではない。

## テストの作成時の四問

1. 診断の上限と直接参照・起点・省略数、Regexの全本体共有の件数上限とキャッシュ、長い連鎖の検査時間・総確保量、Scopeの表示の区切りと完全なエスケープを守る。
2. 推移的集合の再保存、上限の削除・本体ごとのリセット、成功パターンの未計数、上限到達後のキャッシュ無効化、引用後の切断が退行の例である。
3. 既存の二段の由来テストとバイト予算テストでは、長い連鎖・分岐と短いパターンの件数を検出できない。Scopeの既存の長さだけのassertでは不完全な表示を検出できないため、同じ実行例にassertを足した。2万個の例は時間と総確保量を実入口で数える独立の関門である。
4. 本番の公開口・大域状態を足さず、公開checkと既存のテスト専用System委譲を使う。既存の確保回数のassertはすべて保ち、同じ確保器の二測定だけをMutexで直列化した。

## 途中の検査

以下の秒数はCargoのテスト実行部の表示である。作業末の検査は入口全体の外側の時間を別に記す。

- `cargo test -p benitoite --test checked_args constant_origin_labels_are_bounded_and_keep_chain_endpoints`: 修正前は16個の位置を出して失敗（終了101、0.06秒）、修正後は成功（終了0、0.19秒）。
- `cargo test -p benitoite --test checked_args regex_pattern_count_is_shared_and_cached_failures_survive_exhaustion`: 修正前は259診断で失敗（期待257、終了101、0.10秒）、修正後は成功（終了0、0.18秒）。
- `cargo test -p benitoite --test runtime_builtins scope_`: 修正前は追加した区切りのassertで失敗（終了101、0.47秒）。初回の修正はIntegerに `/` を使いE0405となったため、`div`へ修正した。最終の局所実行は終了0、両実行モード成功、0.49秒。既存の短い表示・元の入力・4096バイト・末尾の `...` のassertもすべて残した。
- `cargo test -p benitoite --test call_allocations long_constant_chain_has_bounded_check_allocations -- --nocapture`: 終了0、7.82秒。2万個の連鎖を検査し、E0457一件、起点と末端の二位置、19998件の省略、総確保512 MiB未満、検査10秒未満を確認した。初回が10秒未満だったためlongにはしない。修正前の2万個は推定数GBを確保するため実行せず、小さい診断例で修正前の失敗を再現した。

## 作業末の検査

`scripts/check.sh --level work --base 7f431373893055a3508b552068f3a496b9cac655 --test '*' --dry-run` は終了0。fmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tallyを選び、spec_examples/reference_examplesはtests_relatedに含まれることを確認した。

`RUST_TEST_NOCAPTURE=1 scripts/check.sh --level work --base 7f431373893055a3508b552068f3a496b9cac655 --test '*'` は一度だけ実行し、終了0、外側417.241秒。fmt、lint_default、lib全件1211成功（既存のignore 21件）、統合39ターゲット291件成功（既存のignore 7件）、ソース規約、生成Skillの一致、仕様集計の自己検査と集計がすべて成功した。spec_examplesとreference_examplesもこの統合実行に含む。無作為生成の差分検査と395プログラム/3950変異の検証も成功した。

`cargo clippy --all-targets` は終了0、外側11.681秒、警告なし。構造化した終了状態と外側の時間は[final-checks.json](final-checks.json)へ保存した。workと追加clippyはそれぞれ一度だけ実行し、失敗や補完の再実行は発生していない。

作業末のcall_allocationsで、2万個の連鎖のcheckは7.954947292秒、総確保量は332,005,978バイト（約316.6 MiB）だった。総確保量は解放分を引かず、reallocの新領域も全量として数える。ピーク使用量や64 MiBの定数評価予算とは別の値である。

## 計画からのずれと申し送り

作業範囲の変更はない。上限と局所の実装方法をR169〜R172で具体化し、plan.mdにA1の検査行を追加した。

- 判断の具体化はR169〜R172。新しい私有の補助以外に公開シグネチャは変えていない。formal/と形式化した規則を変えず、01-12は用語とD/Oの対応の説明だけを直した。
- Scope.bntは私有のfitQuoted/renderStringsが二定義増える。公開API・公開定義数・構成子数は変えない。最終の交換manifest/routingの全件再集計は取りまとめ担当へ渡す。新しいgolden入力・API・builtinは加えていない。
- G1は在庫のopaqueと生成の拒否を実装・検査する。V1はdocs/jaを揃える。改造全体のchange・全特殊構成・最終の形式化の全比較・公開候補の照合はオーケストレータに残す。

変更量（`git diff --numstat`、生成Skillと文書・goldenは除く）: 本番srcは+103/−36行、統合テストは+147/−4行。既存assertの削除・緩和・ignore化はない。

最終の `git diff --check` は終了0。RV3の写しは元ファイルとバイト単位で一致する。formal/・docs/ja/には差分がなく、docs/todo/の読み書きとコミットは行っていない。
