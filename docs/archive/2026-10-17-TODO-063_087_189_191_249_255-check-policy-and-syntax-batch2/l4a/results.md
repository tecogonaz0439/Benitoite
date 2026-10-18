# L4a 文字の区間と有用性の証明

基準Bは、L3b取り込み後の `f1796a6ae07086aae28da77befc5383449effaae` に固定する。

## テスト追加前の四問

1. 守る契約は、Character全域の網羅性・必ず照合する束縛・非選択の位置、欄どうしの相関、ガードと将来の構成子の扱い、実在する文字の反例である。Releaseの判定・表示・実行の照合と、表層の公開checkerを境界にする。
2. サロゲートの列挙、値域の端や一点の穴の見落とし、欄の独立した判定、ガード行の算入、文字の全域から将来の構成子まで覆う誤り、整数のotherの削除、最小の反例と表示の不一致を検出する。
3. 既存の文字の例はotherを残す旧規則を確認しており、全域を受理する場合と境界の穴を区別しない。既存のCoverageExamplesの準備と表を使い、文字の新規則の正負の対照を加える。表層ではbind/shadow・matchが同じ判定を使う接続、実行の系では最後の分岐の非選択、表示では実際の照合との対応という各境界固有の危険だけを確かめる。
4. 本番の公開範囲・フラグ・差し込み口は増やさない。既存の判定・checker・Pat.matchValを直接使い、期待値と反例の文字は手で定める。

## 実装

- Releaseの文字の列からotherを外し、固定した四端と入力区間の端でCharの全域を分割した。`char_partition_cover` は任意のCharの被覆、`segments_refine` と `char_partition_query` は区間の内部に入力の端がないことを証明する。`shapeStep_character` から補題Uと各系へ接続し、整数と文字列のotherは保った。
- CoverageShowは文字区間の下端を文字リテラルまたはUnicodeエスケープへ表示する。0・一点の穴・サロゲートの前後・最大値について、判定の反例と独立の期待値を比べ、選んだCharが元の分岐に照合しないことを確認する。入れ子の構成子の反例も表示と照合を確認する。
- 14のLeanの例を追加した。全域・リテラルとの和・一文字の穴・全域後の分岐・同じ分岐の選択肢・ガード・二欄の相関・構成子とリスト・外部view・整数の全域据え置きを扱う。Surfaceの公開checkerでmatchとbind/shadowの両形を確認し、実行時の非選択の系にも全域後の分岐を接続した。
- 01-12・02-05・07-04の写しを更新し、Character全域を表層より広いとする旧記述を改めた。LeanとRustの判定・反例表示が未接続であることを明記した。

既存の例の期待を二つ変更した。97から最大値までを覆う例の反例はotherから実際に欠けた区間0〜96となり、全域の一範囲の例は非網羅から網羅となる。これはL4aで決定した意味の変更であり、非選択の位置と燃料切れの期待は保っている。既存のassertの削除、期待値の緩和、ignoreの追加はない。

## 途中の検査

`formal/` で、変更した所とその読者だけを対象に次を実行した。

- `lake build Benitoite.Release.Coverage`
- `lake build Benitoite.Release.CoverageExtension Benitoite.Release.CoverageShow Benitoite.Release.Lemmas.CoverageRuntime Benitoite.Surface.CheckPatterns`
- `lake build Benitoite.Release.CoverageShow`
- `lake build Benitoite.Release.CoverageShow Benitoite.Release.Lemmas.CoverageRuntime Benitoite.Surface.CheckExamples`
- `lake build Benitoite.Release.Lemmas.CoverageRuntime Benitoite.Surface.CheckExamples`
- `lake build Benitoite.Release.Lemmas.CoverageRuntime`

作成中の失敗は、新しい証明でOptionのbindの等式を展開する箇所、関数を含むviewの例でのDecidableの生成、実行の例でArm.altsを展開する箇所、レコード宣言の字下げである。新規の補助証明・例の記述を修正し、各対象の成功を確認した。反例の表示の補助APIを調べるための一時Lean入力でも、存在しないChar.isPrint/isControlの参照を確認し、実装には使っていない。最初のlake呼び出しはリポジトリの根を作業ディレクトリにしたため失敗し、formal/へ直した。一時編集スクリプトの作業ディレクトリと文字コードの指定の誤りも修正した。これらの試行の外側の全経過時間は採取しておらず、結果の引用には使わない。

## 完了の検査

作業末は、根で次の同じ基準・名指しを使い、dry-runの後に一度だけ実行した。

| コマンド | 終了状態 | 外側の時間と結果 |
|---|---:|---|
| `scripts/check.sh --level work --base f1796a6ae07086aae28da77befc5383449effaae --only formal_build,spec_examples,spec_tally --dry-run` | 0 | 0.011秒。指定の三単位だけを選択。[選択の記録](dry-run.log) |
| 上記から `--dry-run` を外した指定 | 0 | 97.041秒。仕様網羅性の自己検査・集計、仕様例7件、六実行ファイルを含む既定のlake buildとsorryの拒否が成功。[workの記録](work-check.log) |

spec_tallyにはテスト参照のない仕様の節も表示されるが、初回リリース版の完了条件の未記入はなく、終了状態は0である。完了検査の失敗・再実行はない。検査中に02-05の既存の「RustとLeanは同じ」という説明を文字全域の未接続の範囲に合わせて限定した。検査が読む見出し・例・テストの印・Leanの入力は変えていない。

Rustのソースとテストは変更していないため、lib全件・clippy・fmtは追加していない。check.shの全体、gc-stress、check-formal.shの全比較は実行していない。

最終の文書5ファイルのローカルリンク261件は、参照先の存在の検査が成功した（終了状態0、0.003秒）。`git diff --check` も成功した（終了状態0、0.020秒）。

## 計画からのずれと申し送り

[R64](../decisions.md#r64-l4aの文字と整数の区間の補助を分ける)に、整数と文字の補助の分離、既存の共通の証明を使う判断、文字の表示規則を記録した。CoverageExtensionとSurface.CheckPatternsの証明は変更せず、新しい定義について再検査する。主な定理・補題Uとその系・健全性11件の前提と結論、公理、Builtins.Assumptionsは変更していない。範囲と完了条件の変更はない。

L4bには交換の版と六入口の契約・全比較を残す。文字全域のRustの判定・診断・移行はP1で接続する。P1ではR64の文字の表示規則もそろえる。今回のLean先行の結果を、接続後のRustの全比較の証拠として引用しない。コミットとdocs/todoの変更は行っていない。

L4aは完了した。
