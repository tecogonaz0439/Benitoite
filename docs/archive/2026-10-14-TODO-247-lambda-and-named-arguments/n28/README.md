# N28 失敗を試す testdata の移行

N27 が除いた負の入力 488 ソースを確認し、92 ソースを移行した。複数引数のラベル、匿名だった関数型の契約名、コールバックのパラメータ名と束縛された参照を直した。直接の位置構成子、未知・非公開の名前、誤った構文そのものは維持した。新しい負の golden は `types/named-required-pipe` と `types/arity-single` の二つである。

既存の全 `.exit` とスクリプトの標準出力・標準エラー出力は不変である。診断は既存の 539 件を維持した。コード列の変更は、計画と N1 の対応表にある `types/arity` の関数の不足 E0402 → E0453 の一件だけであり、同じ入力の構成子の E0402 は維持した。失敗する test の報告 7 ファイルも位置だけを変え、結果・失敗理由・比較する値・出力・集計は不変である。

## 記録

- [scope.json](scope.json) と [case-review.json](case-review.json): 全対象の所有するケース、元の誤りとコード、変更前後のハッシュ、変更した元のソース。
- [inventory/manifest.json](inventory/manifest.json): 変更前の全入力と 284 候補。通常の確認済み 156 候補の適用は [manifest.json](manifest.json) と [migration.diff](migration.diff) に記録した。
- individual・syntax-followup の manifest と diff: 型検査まで進まない入力、エラーの変換、関数型、誤った `uses` の列の個別の確認。各 manifest に適用時のハッシュの受領記録を併置した。
- [review.md](review.md): テスト作成時の四つの問いと、個別の移行の理由。
- [expectation-changes.json](expectation-changes.json): ソース編集から計算した位置、ラムダの表示名に埋め込まれた位置、型の表示、E0453 と二つの型変数の流出の診断の全内容の旧新。
- [type-display-review.json](type-display-review.json): N1 の型表示の 11 候補の照合。変更しなかった候補も記録した。
- [invariants.json](invariants.json): 全診断の件数・コード列、終了状態・出力、test の位置以外の報告の一致。
- [second-pass/manifest.json](second-pass/manifest.json)、[second-pass-summary.json](second-pass-summary.json)、[second-pass/migration.diff](second-pass/migration.diff): 移行後の 490 ソースを再抽出し、編集 0 件・差分 0 バイトであることを確認した記録。
- [final-source-hashes.json](final-source-hashes.json) と [line-counts.json](line-counts.json): 移行後のハッシュと、本番・テスト・入力・期待値の行数の増減。

期待値を実行結果で一括更新する指定は使っていない。元の字句・式に対応する位置を確認済みの編集から計算し、内容の違いを個別に確認してから golden の厳密な比較を通した。

## 計画からのずれ

[decisions.md](../decisions.md) の R80〜R82 に推す案として記録した。check・run のほか、N27 が除いた失敗する test の入力と共通依存も同じ作業で移行した。二つの型変数の流出の E0401 は、名前付き呼び出しの制約を後で解く順序により、同じ流出を先に検出する `resume(p)` の位置・型表示・補助情報へ合わせた。操作の節・流出の注記・終了状態は維持し、セルの引数で直接拒否する検査も `secf1-nested-escape` に残した。

`Integer.floorDivide` の名前付きへの移行で W0402 が消える不備は、期待値を変えずに警告用の処理を補正した。標準の束縛を確認した算術関数だけで名前を対応させ、逆順の除数と被除数を取り違えないようにした。本番の差し引きは 5 行増、Rust のテストは 27 行増である。追加した退行テストの修正前の失敗も確認した。公開の型・シグネチャと Lean の規則・定理は変更していない。

## 検査

ユーザーの指定に従い、`scripts/check.sh`（dry-run を含む）と gc-stress は実行していない。

| 検査 | 結果 |
|---|---|
| `cargo test -p benitoite --lib --test desugar_export --test named_arguments` | 成功。1,178 passed、既存の 22 ignored |
| `cargo test -p benitoite --test golden` | 成功。2 passed。新規二件を含む 740 ケース |
| `cargo clippy --all-targets` | 成功 |
| `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` | 成功 |
| `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep` | 成功 |
| `cargo fmt --all --check` と `git diff --check` | 成功 |
| 移行後の再抽出 | 成功。490 ソース、編集 0 件、差分 0 バイト |
| 形式検査（`lake build` と新旧の六入口） | 成功。238 ターゲット、sorry なし。対応表の更新後に最終段を再実行し、1,726 入力の対応と改ざんの拒否も成功 |

形式検査の対応は [exchange-manifest.json](exchange-manifest.json)、[routing-manifest.json](routing-manifest.json)、[routing-changes.json](routing-changes.json)、[formal-results.json](formal-results.json) に記録した。既存 1,724 入力の識別子を維持し、新しい負の二件を加えて 1,726 入力を照合した。既存 68 入力を新形式へ移し、定義の対象内外と網羅性の対象は維持した。除外の診断列の変更は、仕様上の arity の一件と新規二件だけである。

`scripts/check-formal.sh` は `lake build`、網羅性・脱糖の全件の書き出し、1,000 件の固定の生成入力、旧形式の六入口まで成功した。末尾の新旧の対応の照合は N27 の表に新規二件がないため停止した。R82 に従い、N27 の基準を保管したまま N28 の対応表へ接続し、同じ全件の書き出しを使って最終段の `check_named.py` を再実行し、終了状態 0 で成功した。出力は `target/desugar-diff/n28/` と `target/coverage-diff/n28/`、対応表の独立した集計の報告は `target/desugar-diff/n28-validation/` にある。

新形式は 210 入力・694 定義・網羅性の 144 対象が一致した。表層は 637 件が成功し、既存の対象外 19 件・Q11 の一件は移行前の入力・理由と一致した。準備失敗・不一致は 0 件である。旧形式も既存の 1,000 生成入力と移行しなかった golden を独立した入口で検査した。契約の改ざん三件、穴・パイプの改ざん六件、その他の新形式の改ざん六件は、意図した理由で拒否された。

## 後の作業への申し送り

G7 では design.md の診断対応表と、E0453 および R80 の全内容の旧新を確認する。未知・非公開の呼び出しには契約を創作せず、元の負の入力を残した。N33 では R78 の通常・パイプ・穴の名前必須の統一と、Legacy の除去による残りの型表示を確認する。N1 の 11 候補は type-display-review.json に引き継いだ。`diag/codes.rs` の E0209・E0316 の括弧のヘルプの例にも匿名の外側の関数型が残るため、N33 の診断の仕上げで名前を加え、同表の二つの golden と生成する Skill を同時に確認する。

コミットと docs/todo/ の変更は行っていない。
