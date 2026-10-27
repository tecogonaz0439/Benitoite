# A21a の結果

着手: 2026-10-26 15:07:21 JST（最初の時刻記録）。終了: 2026-10-26 15:18:22 JST。所要時間: 11分01秒（最初の時刻記録から）。

B_WORK・HEAD は `cf7472fdc1d20c3fc63fb6d912d99abc2aa5b3b3`、ブランチは `mod012/A21a`。着手時の差分はなかった。

状態: A21a の型板登録・生成参照の更新・指定 work・自己点検を完了した。担当範囲に未完・不合格は残っていない。独立レビューと受け入れは取りまとめへ引き渡す。

## 実装した範囲

plan.md「計画の変更（2026-10-26、L25R・L25S を受けて）」の A21a の行と、依頼の補足を優先した。共通依頼文、前提と依存、受け渡す契約、作業群 A21、D4 の変更・D19 と追記・D20、A19a/A19b の申し送りと取りまとめのレビュー、RV-C4-response.md を確認した。

| ファイル | 変更 |
|---|---|
| `crates/benitoite/src/diag/codes.rs` | W0404 を既存の表に登録した。種類は Check、重大度は Warning。直接引数の主文・一次ラベル・inferred_range・allowed_range・local_analysis・origin と説明を D19 に揃えた |
| `crates/benitoite/skill/references/diagnostics.md` | `gen_skill` で W0404 の節を生成した。手で編集していない |

field_message と fix は登録していない。説明は追記に従い `the argument is always out of range` とした。文言はすべて英語で `diag::codes` の表に収めた。型板に埋める値や追加の定型文は本枝では作らないため、text の子のモジュールへの追加はない。

既存のマクロは全コードを公開の列挙型・ALL・info に登録し、生成器も ALL を読む。そのため、発行処理が未接続でも未使用の許可は不要である。候補を診断へ変える接続、補助位置、JSON、実 CLI の追加確認は A21b へ引き渡す。02-05・02-10・03-06 の診断の文書は A21c の担当範囲である。

Rust の型・シグネチャ、言語の規則、Lean の定義・定理・公理、予算の固定表、割り当て量のテストは変更していない。テストの追加・変更はなく、入力・期待値・上限・ignore も変更していない。A19b の二件の上限（512 MiB・256 MiB）を保って全統合で検査した。

## 検査と結果

実行場所は `<repo>`。固定版 Rust 1.98.1 と、既存の書き込み可能な `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使った。[実行器](run.py)が手元のパスを伏せ、コマンド・終了状態・外側時間を同名の JSON に保存した。

| 検査 | 結果・外側時間 | 記録 |
|---|---|---|
| T-G: `cargo run -p benitoite --example gen_skill` | 終了0、11.741秒 | [出力](gen-skill.log)・[JSON](gen-skill.json) |
| 指定 work の dry-run | 終了0、0.081秒。七単位を選択した | [出力](work-dry-run.log)・[JSON](work-dry-run.json) |
| 指定 work | **七単位成功、検査本体0、473.650秒。外側は473.675秒・終了1（計測の制限）** | [出力](work.log)・[本体](work-check.json)・[外側](work.json) |

作業末の指定は次のとおりである。`--test` を省き全統合とした。先に同じ指定の `--dry-run` を実行した。

```sh
scripts/check.sh --level work --base cf7472fdc1d20c3fc63fb6d912d99abc2aa5b3b3
```

[work-check.py](work-check.py) から一度だけ呼び、外側を `/usr/bin/time -l` で包んだ。指定 work の失敗・再実行はない。

fmt、examples を含む clippy、lib 全件、全統合、ソース規約、生成 Skill、仕様集計の七単位が成功した。lib は **1,332件成功・失敗0・既存 ignored 21件**、全統合は **40ターゲット・388件成功・失敗0・既存 ignored 10件** である。[件数の詳細](work-counts.json)にターゲット別の数を保存した。`call_allocations` は、上限512 MiB・256 MiBの二件を含む3件すべてが成功した。追加の割り当て量の実測は行っていない。生成 Skill の照合に新たな差分はなく、仕様集計の初回リリース版の完了条件の未記入は none だった。

**最大常駐量（maximum resident set size）はサンドボックスの制約で取得できなかった。** 検査本体の終了0の後、time が `sysctl kern.clockrate: Operation not permitted` を報告して終了1となった。real/user/sys は473.66 / 1413.82 / 67.87秒である。未取得を0とせず、計測のための再実行も行っていない。

[自己点検の記録](self-review.json)で、D19 の追記を適用した型板との一致、field_message・fix の不在、変更した本番・生成参照の二ファイルの限定、記録のパスの伏せ方、記録用 Python の構文、`git diff --check` を確認した。[検査入力のハッシュ](work-inputs-sha256.json)は検査中と完了後に一致した。検査後の変更は結果記録と検査の集計だけである。

## 計画との差と申し送り

範囲の変更はなく、停止条件にも当たっていない。4時間の上限による中断はない。A21a の登録は発行処理への未接続を許す指定であり、W0404 が実際の check で出る状態までは本枝の完了に含めない。A21b は OutsideDomain の候補を既存の診断へ接続し、操作・HTTP を対象にせず、ハンドラが処理した Process.exit(300) を check と実 CLI で確認する。

stage・change・release、check-formal.sh、Lean のビルド、性能測定は実施していない。別の状態の検査結果を引用して省いた検査はない。private/ とそこを指すリンクは読まず、git の変更操作、コミット・取り込み・docs/todo の更新・保管・公開、担当の委任は行っていない。rtk・japanese-tech-writing を適用した。

| 残る手順 | 担当・時期 | 見込み |
|---|---|---|
| A21a の独立レビュー・受け入れと取り込み | 取りまとめ、本結果の引き渡し後 | 不明 |
| W0404 の発行・表示・補助位置・JSON と実 CLI の確認、work とレビュー | A21b、A21a の受け入れ後 | 計画の1〜3時間、独立レビューは不明 |
| 診断の文書・生成 Skill の同期、work と案III の区切りの受け入れ | A21c と取りまとめ、A21b の後 | 計画の1〜2時間、独立レビュー・受け入れは不明 |

## 取りまとめのレビュー（2026-10-26）

受け入れる。W0404 の主文・ラベル・四つの注記・説明は D19 と D19 の追記（欄の型板なし、説明は「the argument」）のとおりで、fix はない。生成参照は gen_skill で作り直した。Lean・予算の固定表は変わらず、work は終了0である。A21b へ進む。
