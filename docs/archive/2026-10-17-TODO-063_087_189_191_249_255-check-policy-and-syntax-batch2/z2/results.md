# Z2 の修正結果

基準 B: `af489ecf3be46338c0e04f807e35eaa3fc2496af`（RV4 の記録）。plan に Z2 の節はないため、本依頼と reviews/RV4.md を完了条件とした。判断と検査の割り当ては decisions.md の R104 に記録した。コミット・docs/todo・formal/ の変更は行っていない。

## 修正

- 重1: decision.rs は文字の区間の和が全域を覆えば、既定の行の有無によらず既定分岐を省く。02-06 も合わせた。二列の相関を Boolean・Character の二種類で判定の木の差分比較と p1-character-domain の golden へ追加した。0・m/n の境界・z・サロゲートの両隣・最大文字を組み合わせ、既存の出力4行に42行を追加した。未被覆のコア入力を内部エラーにする既存の assert は保った。
- 軽1: Codec.rejectExtra は入力の余分な鍵を Key にする。l21_json の一件で、改行・タブ・引用符・バックスラッシュを含む鍵の経路と Show の全文を検査する。03-08 と生成元の説明を更新した。
- 軽2: Property.tryCandidates は残りの候補を先に調べる。候補が二件で、予算が1・2・3の場合を一件の表で検査し、予算2での完了と予算1での打ち切りを区別した。
- 中1・軽3・軽4: 縮小の費用と size の注意を06-04・英語リファレンス・Property の生成元に追記した。同梱 SKILL.md の derive の手順を開発用の道具の説明二文へ縮めた。AGENTS.md の表へ tools/derive/ を追加し、gen_skill で Json.Codec と Test.Property の参照文書を再生成した。

既存の derive の余分な鍵の期待一つを Field("a") から Key("a") へ更新した。これは軽1による経路の種類の変更であり、assert の削除や期待の緩和ではない。既知の欄の失敗を Field とする既存の期待はすべて保った。

本番のコード（Rust と標準ソース）は12行追加・7行削除、テストコード（Rust と Python）は106行追加・1行削除である。別に golden の入力56行と期待する出力42行を追加した。既存のテストの削除・ignore の追加はない。

## テストの作成時の関門

1. 守る契約は、網羅した二列の match の先勝ちと正常な変換、入力の鍵を引用・エスケープする診断、候補を使い切ったときの正しい上限到達表示である。
2. 文字の全域でも既定分岐を作る変更、Key を Field に戻す変更、候補の有無より先に予算を調べる変更で失敗する。
3. 既存の文字のテストは一列か型検査だけであり、相関のある行列の変換を通らない。判定の木の比較を主とし、golden では本物の Pair の型検査から VM・参照実行器と CLI の終了状態までを確認する。既存の Codec の例は余分な鍵の Show を、Property の例は候補を使い切る瞬間と予算が一致する場合を扱わない。
4. 本番の差し込み口・公開 API・テストダブルは追加しない。既存の比較器・golden・公開のライブラリの実行補助を使う。

## 検査

途中は追加した回帰テストだけを実行した。各コマンド・終了状態・外側の時間は regressions-before.json、before-property-corrected.json、regressions-after.json に保存した。ログは同じ接頭辞の .log に置いた。

| 局所検査 | 修正前 | 修正後 |
|---|---|---|
| `cargo test -p benitoite --lib exhaustive_character_columns_preserve_correlated_rows` | 101、12.044秒。decision の empty pattern matrix | 0、6.011秒 |
| `cargo test -p benitoite --test l21_json codec_extra_key_path_escapes_untrusted_key` | 101、4.105秒。未エスケープの Field の経路 | 0、5.260秒 |
| `cargo test -p benitoite --test property_library exhausted_candidates_at_exact_budget_do_not_report_limit` | 101、3.673秒。誤った limitReached | 0、1.964秒 |
| `BENITOITE_GOLDEN_FILTER=p1-character-domain cargo test -p benitoite --test golden` | 101、2.338秒。Direct/Request とも終了3、empty pattern matrix | 0、2.408秒。期待する出力と終了0、VM/参照実行器の一致1件 |

Property の新規テストは初回にラムダの引数名 budget が契約の value と一致せず E0454 になった（101、1.908秒）。テスト入力だけを value に直し、上表の意図した失敗を確認してから本番を修正した。局所 golden の比較件数は golden-local-summary.txt に保存した。

作業末の work は次の指定で一度だけ実行した。自動の dry-run と同じ指定の dry-run はともに終了0（1秒未満）で、選択を R104 に固定してから実行した。lib 全件・関連統合・fmt を別のコマンドで重ねず、clippy だけ依頼の all-targets に置き換えた。

```sh
scripts/check.sh --level work --base af489ecf --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,python_syntax --test golden --test verify --test l21_json --test property_library --test reference_examples --test skill_docs --test skill_examples
```

| 作業末の検査 | 終了状態 | 外側の時間 |
|---|---:|---:|
| 上記の work | 0 | 247.765秒 |
| `cargo build -p benitoite --example derive_inventory --bin benitoite` | 0 | 2.632秒 |
| `python3 -B tools/derive/test_derive.py` | 0、23件成功 | 30.161秒 |
| `python3 -B tools/derive/derive.py check --root tools/derive/examples --config tools/derive/examples/derive.json` | 0、生成領域・生成記録が一致 | 0.253秒 |
| `cargo clippy --all-targets` | 0、警告なし | 7.232秒 |
| 変更文書のローカルリンク（コード内の表記を除く） | 267件、宛先・見出しの不一致0件 | 0.084秒 |

各コマンドと終了状態・外側の時間は completion-checks.json、出力は対応する .log に保存した。時間は time.monotonic でプロセスの起動から終了まで測った。work は lib 1209件成功・既存21件ignore、関連7統合ターゲット計30件成功・失敗0件だった。golden は784ケース、VM/参照実行器の比較273件一致であり、今回の相関例も通った。比較から外す既存の条件を変えていない。golden-work-summary.txt に件数を保存した。fmt・ソース規約・生成 Skill・仕様集計・Python構文も成功した。全体の check.sh・all-targets のテスト・gc-stress・lake build・check-formal.sh は実行していない。

最終の `git diff --check` は終了0（0.019秒）で、diff-check.json に保存した。

## 計画からのずれと申し送り

R104 のとおり、clippy は依頼の all-targets を一度実行し、work の lint_default と重ねない。Python 変更で自動選択される migrate_selftests は別の二道具の検査なので、今回変更した derive の全自己検査へ置き換える。関連統合ターゲットは golden の読者 verify と、文書・Skill の読者も含めて名指しした。

縮小候補の重複除去の最適化と RV4 の観察1・観察2は行わない。取りまとめ担当が後の課題を管理する。Lean の正式な規則・定理・仮定・ヒープの不変条件は変更しておらず、全形式化比較・特殊構成の全件検査・change/release・版と訳の更新は V1 に残す。
