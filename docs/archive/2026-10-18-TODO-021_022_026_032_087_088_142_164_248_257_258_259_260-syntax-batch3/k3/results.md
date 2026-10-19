# K3: Scopeの実行時API・定数拒否と意味の対応

基準のコミットは `a7b4e62d54b999aa5786d8f991bbd2b1ec8837a1`（K2取り込み後）である。コミットとdocs/todo/の変更は行わない。

## 実装

`prelude/stdlib/Scope.bnt`に三つのopaque record、ScopeErrorの六構成子・Show、三つの検査関数と九つの射影を追加した。条件と対象を保存し、ホストだけをASCII小文字へ揃える。失敗には元入力を保存し、表示用の文字列と最終結果だけをUTF-8の境目で4096バイト以内へ省略する。

`builtins/checked_scope.rs`にホスト・パスの形式、所属、整数の端点、失敗の優先順を集めた。`builtins/funcs/scope.rs`の三つの私有builtinは既存のResult/Pairを返し、標準ソースが通常のrecord/dataを組み立てる。新しいVM値・固定タグ・IOの署名変更はない。静的検査では成功文字列を複製せず、実行時の包みで小文字化する。

K2の標準束縛の同定・引数の対応・定数取得・共有予算を使ってScopeの三関数を対象へ加えた。同一Call内の取得順はソース順とし、失敗判定の順は契約順に保つ。一部が未知でも、既知の形式不良・端点順・各所属を調べる。一次位置・条件の補助位置・関係するconstの由来をE0459〜E0462に渡す。公開境界はK1の仕組みを使う。

01-02・01-06・02-05・03-06と07-04の内外の対応表、英語リファレンス、手書きSkillを更新し、gen_skillで生成したScope参照・診断・索引・埋め込みbundleを更新した。Scopeの成功は保存条件への字面の適合だけであり、操作の許可・OS隔離・外部資源の同一性・IOの成功の保証と区別した。

## テストの関門と意味の対応

作成時の四問は次のとおりである。全テストが本番の公開入口を使い、テスト専用の差し込み口・公開APIの拡大を加えない。

| 持ち主の境界 | 守る契約と捕まえる退行 | 既存の検査では足りない点 |
|---|---|---|
| `checked_args`の公開検査 | Scopeの対象登録、部分既知の拒否、優先順・一次/補助位置、別名・間接/穴/パイプ・型誤り・const由来、opaqueの外部操作拒否 | 既存Regexは一引数であり、Scopeの整数・二種類の所属・条件の位置を通らない |
| `runtime_builtins`の公開実行 | 正規化・全保存欄・六失敗と元入力・失敗順・Showの引用と上限。通常引数を経て静的拒否と実行時Errorを区別 | 静的検査だけでは、私有builtinの番号・Result/Pair・ラッパー・射影の配線が分からない |
| CLIのgolden | importから標準出力・終了状態、フォーマットの性質、VMと参照実行器の一致 | 実行部品の直接のテストではCLI・フォーマッタ・参照実行器の接続を通らない |
| `desugar_export`の局所交換 | 追加拒否を通ったCall/Resultの型・効果・脱糖・コア検査と交換の対象内の出力 | 実行結果だけでは交換器の対象外への脱落を検出できない |

`tests/fixtures/checked-scope.json`の67入力（host 30、path 24、endpoint 13）を静的検査と通常引数経由の実行時検査で共有する。期待値は共通判定部から生成しない。成功18入力と、六種の失敗49入力である。これとは別に部分既知の9例で位置・条件を観察する。新しい検査対象の取得予算はK2の同じ状態を使い、Scope固有の新しい予算を設けない。

| L1の意味・保存 | 対応する独立入力と観察 |
|---|---|
| ValidHostWord/Pattern、HostMatchesのexact/one/many | localhost、ASCII・ハイフン・空ラベル・IPv4形式、大小文字の正規化、一段/多段/頂点、似た接尾辞の拒否。成功時のpattern/hostを射影で照合 |
| ValidPathWord/Pattern、PathMatchesのexact/tree | 根、`/**`、幹自身、任意段の子、要素境界、Unicode、対象側の`*`。不正な空要素・dot・NUL・逆斜線を拒否し、受理したpattern/pathを照合 |
| PortBounds/PortValidとEndpointの失敗順 | 0/65535/一点区間、負数・65536/70000・Integerの両極、逆転→port→ホスト所属→ポート所属の優先順。全五欄を照合 |
| 成功の保存・射影・証拠消去、失敗の入力保存 | 各成功値を公開射影で観察し、失敗の元文字列・整数を照合。長い不正対象の保存とShowの表示上限を別に確認 |

これはL1の小モデルの意味に対応する独立期待値との実装側の照合である。Rustのparserや正規化全体をLeanで証明したとは扱わない。formal/・主定理・公理・Builtins.Assumptionsは変更していない。

既存assertの削除・期待値の緩和・ignoreの追加はない。既存の非互換通知の完全一致の期待文字列だけは、0.0.9の同じ項目へScopeの拒否を追加した意味に合わせて拡張した。版ごとの件数とRegexの内容の主張は保つ。既存の組み込み登録表の期待も、末尾の長さ3・部分数54→55・登録数483→486・純粋な登録数410→413へ正確に拡張した。既存の順序・一意性・能力・型のassertは保つ。既存の局所交換のassertは共通の補助へ移し、すべて保つ。

## 検査

自動選択のworkは一度実行した。以後は、失敗と修正で古くなった検査・未実施の単位だけを名指しで補完した。各check.shの前に同じ基準・同じ指定のdry-runを確認した。Rustの既定lib全件は一度だけ実行し、失敗した2件だけを個別に再実行した。

| コマンド | 終了状態・結果 | 外側の時間 |
|---|---|---|
| `scripts/check.sh --level work --base a7b4e62d54b999aa5786d8f991bbd2b1ec8837a1 --test '*' --dry-run` | 0。fmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tallyを選択。全統合ターゲットに仕様・英語リファレンス・Skillの例を含む | 未計時 |
| 同じ指定（`--dry-run`なし） | 1。fmt成功。追加した二つの補助関数のワイルドカード分岐をlint_defaultが拒否 | 11.574秒 |
| `scripts/check.sh --level work --base a7b4e62d54b999aa5786d8f991bbd2b1ec8837a1 --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally --test '*'`（実行前の同じdry-runは0） | 1。新規テストの添字をlint_defaultが拒否。getへ修正 | 13.766秒 |
| `cargo clippy --all-targets` | 0。警告なし | 14.646秒 |
| 上記と同じ名指しのwork（lint修正後） | 1。fmt・lint_default成功。libは1209件成功・2件失敗・既存ignored 21件。登録表の期待への3件の追加とScope.bntの正規整形が必要だった | 89.298秒 |
| `cargo test -p benitoite --lib table_names_parts_capabilities_and_schemes_are_consistent -- --nocapture` | 0。修正した登録表の1件成功 | 未計時 |
| `cargo test -p benitoite --lib stdlib_sources_are_canonical -- --nocapture` | 0。整形後の標準ソースの1件成功 | 未計時 |
| `scripts/check.sh --level work --base a7b4e62d54b999aa5786d8f991bbd2b1ec8837a1 --only fmt,lint_default,tests_related,source_rules,skill_generated,spec_tally --test '*'`（実行前の同じdry-runは0） | 0。39統合ターゲット278件成功・既存ignored 7件。fmt・lint_default・source_rules・skill_generated・spec_tallyも成功 | 309.314秒 |
| `cargo clippy --all-targets`（登録表の期待修正後の補完） | 0。警告なし | 9.376秒 |
| `git diff --check` | 0 | 未計時 |

成功済みのlib 1209件を繰り返さず、残る二件の成功と合わせて1211件の成功を確認した。全件実行後の変更は登録数の厳密な期待値とScope.bntの空白の整形だけであり、成功済みのテストの契約を変えていない。全統合ターゲットは最後の状態で実行した。spec_tallyは未参照の既存の節を表示したが終了0であり、初回リリースの完了条件の未記入はない。formal/・ヒープの不変条件・安全点を越える値を変更していないため、formal_build・check-formal.sh・特殊構成のheap/stress・release_stackは追加していない。

途中は `cargo test -p benitoite --test checked_args scope_ -- --nocapture`（2件）、`cargo test -p benitoite --test runtime_builtins scope_checked -- --nocapture`（1件）、`cargo test -p benitoite --test desugar_export export_batch3_scope -- --nocapture`（1件）、`BENITOITE_GOLDEN_FILTER=stdlib/scope cargo test -p benitoite --test golden -- --nocapture`（1ケース、部品検査を含む2テスト）だけを局所検査として実行した。いずれも修正後は成功し、局所の外側の時間は未計時である。最終のchecked_argsの5件は計8.11秒であり、新しいlong/ignoreは加えていない。

作成途中には共通の由来集合の型推論、標準ソースのelse-ifの閉じ方、下書きmainのエラー型、準備前のsmoke入力の不在を修正した。共有入力の`//**`は静的・実行時の両方で期待どおり拒否されず失敗したことを確認し、根の木の特例を`/**`だけに限定して成功させた。新規の不正ラベルのテストは、従来の優先順どおりE0451だけを期待する形へ直した。既存テストの期待を緩めて通したものではない。

Rustの差分は、本番が461行追加・9行削除（差し引き452行）、テストが379行追加・12行削除（差し引き367行）である。新規Rustファイルを含み、modules/package.rsとbuiltins/table.rsのcfg(test)内の変更はテストへ分けた。Scope.bntは155行追加した。JSONの共有入力、golden、文書と生成参照はRustの行数に含めない。

## 計画との差と申し送り

具体化はdecisions.mdのR161に記録した。共通判定の成功時の借用、端点の一次/補助位置、B_WORKの固定、R156と同じ追加clippyであり、公開API・保証の範囲を変更しない。初回workは追加した補助関数の全バリアントの列挙不足でlintが停止し、補完時には新規テストの添字もlintが拒否した。全バリアントの列挙とgetへ直した。さらにlibの既存二テストが新しい組み込みの厳密な件数とScope.bntの正規整形を検出した。期待を追加分だけ増やし、標準ソースを既存formatterで整形した。失敗した二テストだけを再実行し、両方成功した。修正で古くなる検査と、未実施の統合・残る単位を補完する。

K4は同じopaque境界を使ってRangeを接続する。RangeはScope/Regexの定数拒否表へ加えない。後の担当は最終APIで訳・版・移行案内をそろえる。K3は本測定・全形式化比較・公開候補の検査を完了したとは扱わない。

取りまとめ用の交換の増分は、Scope標準ソース（公開関数12・私有関数7・Showのメソッド1と三recordの自動アクセサ）、私有builtin登録3、golden `stdlib/scope.bnt`（mainと動的入力の補助関数）、局所交換 `batch3/scope.bnt` の5定義である。5定義はすべて対象内として `target/formal-batch3/k3/` へ書き出した。`exchange-manifest.json`と`routing-manifest.json`は変更せず、最終全比較の前の再集計を取りまとめへ渡す。
