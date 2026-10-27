# A15b の結果

2026-10-25。基準 B_WORK と着手時 HEAD は `8cf22e4df305b4a5983ca4650c5339fd3b50f05e`、作業枝は `mod012/A15b` である。着手時に未コミット差分・未追跡入力はなかった。plan.md の作業群 A15 の A15b と、「計画の変更（2026-10-25、RV-C2 を受けて）」の A15b（RV-C2 の軽1を含む）に限って作業し、担当範囲の文書修正と指定検査を完了した。

## 変更

- 01-04: 七種の整数と64ビットの別名、W0401 の一点の除数0、W0402 の全域外の結果区間を明記した。bind・shadow、比較、if・短絡、match の guard と合流を説明し、Integer64 のリテラル・範囲パターンと、六幅の束縛・ワイルドカード・guard を区別した。部分的なあふれ・一般の積・商と剰余の結果・相関・関数間解析の限界も明記した。既存の定数式による警告の規範は保った。
- 02-05: 算術の段落に残っていた Integer64 だけの比較の記述と、独立入力の Integer64 だけの忘却の記述を、七種の実装に揃えた。警告の型名・型域・十進の閉区間表示、UnsignedInteger64 の定数倍の交差前の端点を u128 のまま表示する規則を加えた。先行作業が更新済みの算術・比較・match の詳細は保持した。
- 02-10: 局所警告の対象演算と七種の幅、既定の型名、値域検査前の結果区間と許容範囲の表示を明記した。文章と JSON は同じ型名・閉区間を使い、既存の標準関数と Decimal の定数警告を保つ。
- 07-04: RV-C2 の軽1に従い、六幅の match の腕を対象外と読める一文を、01-12「区間解析のIntegerパターンと腕入口」に写した状態へ修正した。Rust・VM との接続を形式化の保証に含めない限定は保った。

生成 Skill の W0401・W0402 は、D19 と現在の診断表に一致していた。`cargo run -p benitoite --example gen_skill` を実行して再生成し、`crates/benitoite/skill/` と `src/cli/tools/skill/bundle.rs` に差分がないことを確認した。生成器は構文の章・標準ライブラリ・型名の表・診断の表を読み、今回変更した設計書四章は生成元ではない。生成物の手編集と Rust の変更は行っていない。

## 検査

リポジトリの根で、指定の基準と対象をそのまま使った。作業末の検査は次のコマンドを `/usr/bin/time -l` で包んで一度実行し、子プロセスの終了状態を別に保存した。先に同じ指定へ `--dry-run` を付けて、六単位の選択と理由を確認した。Rust の全 lib・clippy・Lean ビルドは追加していない。

```sh
scripts/check.sh --level work \
  --base 8cf22e4df305b4a5983ca4650c5339fd3b50f05e \
  --only spec_examples,spec_tally,reference_examples,skill_docs,skill_generated,tests_related \
  --test skill_examples --test stdlib_doc_examples
```

| 実行・単位 | 終了・結果 | 外側の時間・記録 |
|---|---|---|
| `cargo run -p benitoite --example gen_skill` | 終了0、生成物の差分なし | 3.294秒。[出力](generate.log)・[実行結果](generate-result.json) |
| 上記指定の dry-run | 終了0、指定の六単位だけを選択 | 0.013秒。[出力](work-dry-run.log)・[実行結果](work-dry-run-result.json) |
| 上記指定の work | **検査本体は終了0、全六単位が成功** | **26.543秒**。[標準出力](work.log)・[標準エラーと計時](work-time.log)・[実行結果](work-result.json) |
| tests_related | skill_examples 3件、stdlib_doc_examples 1件成功 | 上記 work に含む |
| skill_generated | 再生成による状態変化なし | 上記 work に含む |
| spec_tally | 集計の自己検査と仕様集計が成功。初回リリースの完了条件の未記入は none | 上記 work に含む |
| spec_examples | 7件成功 | 上記 work に含む |
| reference_examples | 1件成功 | 上記 work に含む |
| skill_docs | 8件成功 | 上記 work に含む |

統合テストは計20件成功、失敗・ignored は0件である。検査の失敗と再試行、過去の成功結果の引用による省略はない。仕様集計はテスト参照のない節の一覧も出すが、初回リリースの完了条件の未記入はない。今回、見出し名とテストの印を変更していない。

最大常駐量（maximum resident set size）は取得不能だった。`/usr/bin/time -l` は `time: sysctl kern.clockrate: Operation not permitted` と表示して終了1となり、最大常駐量の数値を出さなかった。time の real は26.54秒である。検査本体の終了0は [work-child-status.txt](work-child-status.txt) に別に保存し、計測の制限と区別した。

## 最終点検と申し送り

検査開始時に、設計書四章・同梱 Skill の Markdown 全件・bundle.rs の計76ファイルの SHA-256 を [final-inputs-sha256.json](final-inputs-sha256.json) に保存した。検査後も全件が一致した。[final-check.json](final-check.json) には、変更された追跡ファイルが設計書四章だけであること、Rust と Skill の差分がないこと、見出しの一覧が基準から変わっていないこと、コードブロックを除く相対リンクのファイルが存在することを記録した。`git diff --check` は成功した。最終検査後の編集は結果と確認記録だけである。

計画からの範囲の変更と判断待ちはない。商・剰余の結果区間の伝播と Byte の算術を追加したとは記述していない。言語の規則、型とエフェクト、実行時検査、Lean の定義・定理の前提と結論・公理は変更していない。U02 が担当する見出しの改名も行っていない。

A15b が受け持つ未実施・不合格の検査はない。独立レビュー、S-A2 の段の検査と受け入れは取りまとめへ渡す。Rust/Lean・VM の全比較、change/release、性能比較を本枝で先取りしていない。private/ とそこを指すスキルのリンクは読まず、git の変更操作、docs/todo の更新、コミット・取り込み・公開は行っていない。

## 取りまとめのレビュー（2026-10-25）

01-04・02-05・02-10 を七種の整数の区間解析に揃え、六幅の match のパターンの範囲と商・剰余の結果を伝播しないことを明記した。07-04 の RV-C2 の軽1 を直した。生成 Skill は作り直しても差分がない。受け入れる。
