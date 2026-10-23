# F4b 書式の脱糖・定数評価・実行の接続の結果

2026-10-23、F4b実装担当。[plan.md の作業F4b](../plan.md#作業-f4b-書式の脱糖定数評価実行の接続) を対象とする。

## 基準と変更

- B_WORKと開始時のHEAD: `75b6c7174986e5be3b1125fe51e0a3c1db151f7b`。ブランチは `mod011/F4b`。開始時の差分はなかった。
- 脱糖は、先に全式を左から各一度評価し、F4aの `interp_types` と解析済み書式から型別の `%Format.<基本型名>` と七定数を作る。書式付きのStringも書式化し、書式なしのStringはそのまま使う。変換の束縛をすべて置いてから、本文の断片と左から連結する。既存の `bind`・`finish` により評価順を保つ。
- `FormatSpec::constants` で、種類・寄せ・符号・接頭辞・ゼロ埋め・幅・精度をD29の固定定数へ写す。幅省略0・精度省略−1を保ち、定数評価と脱糖が同じ変換を使う。
- 定数評価は、先に全式の値を求め、F3の `base::format::FormatSpec::decode`・`prepare` を使う。全出力バイト数から論理上限・`usize`への変換・共有予算を確かめてから確保し、各片を写す。書式付きの出力に128バイトの見込みを流用しない。評価済み値を置くVecも確保前に予算へ数え、最終の連結も全長を求めてから一度だけ確保する。
- 型検査の `pending_formats` とE0262の未接続の注記、定数評価と脱糖の拒否を除いた。書式の構文エラーのE0262と不適合のE0468は維持した。
- RV-F13のL2の6か所（01-02、01-12の例の前、00-04、E0262の `pending`、生成Skill、英語リファレンス）を接続後の状態へ更新した。01-06・02-03・02-05・02-06・03-06に残る途中状態の説明も更新し、手書きSkillに実行例を加え、生成器を実行した。

## 検査の指定と結果

コマンドはリポジトリの根から実行した。rtkの包みは省略して記す。外側の時間は、記録のある実行を `/usr/bin/time -p` で測った。途中で外側を測らなかった実行は未計測とした。

Wは計画のwork F4bへ、変更したfmtの検証と手書きSkillの実行例の読者を補った指定である。plan.mdの当該行も同じ指定へ更新した。Hは計画で指定された局所特殊構成、Rは最後に変更したテストの整形とclippyの再確認である。

```sh
# W: lib全件・関連統合・clippy・fmt・規約・生成物・仕様集計
scripts/check.sh --level work --base 75b6c7174986e5be3b1125fe51e0a3c1db151f7b --test declarations --test runtime_builtins --test golden --test spec_examples --test reference_examples --test skill_docs --test fmt_command --test skill_examples

# H: compile_failを含む文書テスト・heap-verify・gc-stress
scripts/check.sh --level work --base 75b6c7174986e5be3b1125fe51e0a3c1db151f7b --only heap_local,stress_local,doc_default --test runtime_builtins --test golden

# R: 最後に変更した型受理テストの整形とclippy
scripts/check.sh --level work --base 75b6c7174986e5be3b1125fe51e0a3c1db151f7b --only fmt,lint_default
```

W・H・Rは、実行前に同じ基準と指定へ `--dry-run` を付け、対象と理由を確認した。Wはfmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tally、HとRは名指しした対象を選び、いずれも終了0であった。dry-runの外側の時間はWが0.07秒、Hが0.03秒、Rが表示精度未満であった。分類不能による停止はない。

| 実行 | 終了状態・結果 | 外側の時間 |
|---|---|---|
| `cargo check -p benitoite --lib` | 初回101、`byte_len()`のu64を検査してusizeへ変換するよう修正後0 | 未計測 |
| `cargo test -p benitoite --test runtime_builtins formatted_interpolation_connects -- --nocapture` | 最終0、1件成功。全14型を含む22組と入れ子・連続・書式なしとの混在を、定数とVM・参照評価器の二方式で検証 | 最終1.92秒、途中は一部未計測 |
| `cargo test -p benitoite --lib formatted_interpolation_checks_size -- --nocapture` | 最終0、1件成功。1024の表示幅に対する1025バイトの境界と共有予算超過を検証 | 最終24.76秒 |
| `BENITOITE_GOLDEN_FILTER=formatted_interpolation_order cargo test -p benitoite --test golden -- --nocapture` | 0、2件成功。新規の1入力でCLI二方式・参照評価・フォーマッタを検証 | 5.33秒 |
| `cargo build -p benitoite --examples` | 0、全examples成功 | 14.09秒 |
| `cargo fmt --all`、`cargo run -p benitoite --example gen_skill` | 0、整形と生成を実施。生成物の変更は診断一覧の未接続の注記の削除 | 生成3.26秒、整形は未計測 |
| W | 0、選択した全項目成功 | 196.26秒 |
| `cargo test -p benitoite --lib typeck::tests::interpolation_formats:: -- --nocapture` | 0、最後にE0262の除外を外した型受理テスト2件成功 | 15.84秒 |
| R・初回 | 1、上記の除外を外した後の行の折り返しをfmtが指摘 | 2.38秒 |
| `cargo fmt --all`の後のR | 0、fmt・clippy成功 | 7.20秒 |
| H | 0、文書テスト34件成功・既存の1件ignore。heap-verifyとgc-stressは各構成でgolden 2件・runtime_builtins 23件成功 | 671.29秒 |
| 変更文書の読み取り専用Python確認 | 0、12文書の相対リンク927件・アンカー・既存見出し・フェンス・末尾空白を確認 | 0.248秒 |

Wのlibは1,271件成功・既存の21件ignore。統合はdeclarationsが24件成功・既存の1件ignore、fmt_commandが21件、goldenが2件、reference_examplesが1件、runtime_builtinsが23件、skill_docsが8件、skill_examplesが3件、spec_examplesが7件成功した。clippy・ソース規約・生成物の照合・仕様集計も成功した。

W実行中の最終確認で、F4aの型受理テストに残るE0262の集計除外を2か所外した。実装と検査入力は変えていない。先に済んだlib全件に重ねず、変わった2テストとRを再実行した。その他の成功した検査は繰り返していない。

途中の失敗は、テスト入力の不等号を `!=`、Byteの接尾辞を `b` と誤記したことによる。言語の構文 `<>`・`u8` へ直した。局所予算テストでは、Debugを実装しないEvalErrorを失敗文へ渡したためビルドが止まり、不要な表示を除いた。文書確認の最初の抽出は、複数行のインラインコードをリンクと誤認したため、インラインコードを複数行にまたがって除外するよう点検用スクリプトを直した。既存の期待結果・入力の大きさ・ignore・時間制限は緩めていない。

最終の静的確認では、本記録を含む13文書の相対リンク928件・アンカー・既存見出し・フェンス・末尾空白を `python3 -B /private/tmp/f4b-check-docs.py` で再確認し、終了0、外側0.24秒であった。`git diff --check` も終了0である。

## テストの作成時の関門

- 表層の接続は `runtime_builtins` の1つの表で確認した。型別の頭・定数の順・省略した精度・Stringの書式化の欠落、Float32とDecimalの丸めの取り違え、幅とバイト数の混同を、独立した期待値で検出する。F3のrawの頭のテストは表層の型選択・引数生成・定数評価を通らないため、この境界の検査を加えた。
- 評価順は1つのゴールデン入力で、効果のある4式の出力と、複数の書式付き・書式なしの値の連結を確かめた。式の重複評価・順の逆転、後の式の確保をまたいで前の文字列を失う退行を検出する。式をすべて `eval` してから変換を `bind` し、その後に連結を作る実装と、`finish`が登録順のletにすることも読解で照合した。
- 書式化の定数評価の予算は、既存の局所予算を使う1テストで確認した。1025バイトの許容、1024バイト上限の拒否、共有予算超過の拒否を対照にし、128バイトの見込みの流用を検出する。テストのための公開API・フラグ・差し込み口は増やしていない。
- 宣言と型受理のテストから一時防御の期待と診断除外を取り去り、fmtのテストから段階的な実行拒否の期待だけを除いた。fmtが書式を保持し、不正な書式を拒否する検査は保った。接続後の実行の受け入れは上記の表とゴールデンが受け持つ。
- Rustの本番は132行追加・29行削除、テストは127行追加・54行削除である。src内のcfg(test)とテスト用モジュールを分けて数えた。このほかに新しいゴールデン入力・方式・終了状態・標準出力の4ファイルを加えた。監査によるテストの整理は行っていない。

## 計画からのずれと申し送り

- F4aの途中状態の除去にcontext.rs・generate.rs・診断の表・型受理テストを、固定定数の共用にast.rsを変更した。文書ではL2の6か所に加えて、F4aとF3が残した途中状態の説明も除いた。fmtの検証と手書きSkill実行例の読者をworkの指定へ補った。
- VMと参照評価器は既存の組み込み呼び出しの経路で14頭を実行する。ヒープ内部・NoGc区間・安全点を越える値の保持方式は変えていない。既存のIRの束縛と共通の結果確保を使うため、独立の `check-heap.sh` は追加せず、計画の局所heap/stress/docで新しい経路を検査した。
- 言語の規則、Leanの主な定理の前提・結論、公理を変える必要は生じていない。交換形式・RustとLeanの全比較K1はF5担当へ渡す。F4bが形式化との全接続を確認済みであるとは扱わない。
- 取り込み後のshort測定・独立レビュー・受け入れは取りまとめが担当する。stage・change・release、版上げ、訳、docs/todoの更新、コミット・取り込み・公開の操作は行っていない。
- privateとそこを指すリンク、docs/todo、過去の文書は読んでいない。gitは状態・差分・基準の本文・HEAD・ブランチ名の読み取りだけに使い、変更操作は行っていない。

F4bの範囲を完了した。担当する失敗と未実施の検査、設計者の判断を要する未決事項は残っていない。

## 取りまとめの性能の比較 short（F4b の取り込みの後）

- コマンド: `python3 tools/bench/compare/run.py --tier short --state before=a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a --state after=05fd5111c9cd3707e66994eebbb9536eb9a0e1eb --name batch5-f4b`（比べる元は decisions.md の D41）。
- 終了 0、外側の時間 108 秒（ビルドを含む）。
- 判定: 60 点が「判定不能」、残りが「達成」（しきい値の内側）。W1 比で higher-0-300 +4.2%、functions-modules-1000-1 +3.8%。退行の疑いはない。
- 記録: `tools/bench/results/2026-10-23-05fd5111-batch5-f4b/`（手元の絶対パスは `<repo>` に伏せた）。
