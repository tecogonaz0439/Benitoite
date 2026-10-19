# T1の実装結果

2026-10-18、Codex。基準B_WORK・段2開始版B_STAGE2は `95378554353786cab7b323336937ced204d036c7` であり、開始時の作業ツリーはクリーンであった。コミットは作成せず、docs/todo/とformal/は変更していない。

Body専用のBodyNodeMap/BodyBindingMapをBTreeMapで実装し、Bodyの全ノード表・局所束縛表、Scopeの型/効果パラメータ、ClauseBoundsを移した。未登録の番号、更新の戻り値、番号順の走査を保つ。既存のfinish/check_type_limitsは同じiterから実在要素だけを辿り、全体の密なTypeckOutputへ同じ番号で確定結果を書き戻す。baseの表と公開の型・規則・診断は変更していない。02-05の三節に実装を反映した。本番コードは84行追加・33行削除、既存のテストコードは変更0行である。

## 検査

| 種類・コマンド | 終了状態・結果 | 外側の時間 |
|---|---|---|
| 途中: `cargo check -p benitoite --lib` | 0 | 未計時。Cargo表示7.70秒 |
| 比較用oldのビルド: `cargo build -p benitoite --lib --manifest-path target/t1/baseline/Cargo.toml --target-dir target` | 初回101。展開物にLICENSE-MIT/APACHEがなくinclude_strが失敗した。開始版から両ファイルを展開して再実行し0 | 未計時。成功時のCargo表示23.88秒 |
| 局所比較: `python3 -B <D>/t1/compare.py target/t1/probe-old old` | 初回1。比較器でf1-nofail-expected-acceptを成功と分類したが、既存のexit/diag.jsonの期待はE0515であった。比較器を既存の期待に合わせ、再実行0 | 初回2.08秒、成功11.56秒 |
| 比較用mapのビルド: `cargo build -p benitoite --lib` | 0。共通targetの再利用ではoldの成果物が残ったため、lib.rsのmtimeを更新して現在のソースを再ビルドした後でmap比較器をリンクした。再現手順では状態別のtargetを使う | 未計時。再ビルドのCargo表示18.96秒 |
| 局所比較: `python3 -B <D>/t1/compare.py target/t1/probe-map map` | 0。19例（11成功・8拒否）、型出力・診断列・CLI形式の診断・コアの68ファイルが一致。成功例のIR検査も0件の誤り | 2.36秒 |
| `git apply --check --directory=target/t1/baseline <D>/t1/map.patch` | 0。開始版への適用を確認 | 1秒未満 |
| compare.pyの`ast.parse`、状態JSONの全SHA-256照合 | 0 | 1秒未満 |
| 作業末: `scripts/check.sh --level work --base 95378554353786cab7b323336937ced204d036c7 --test '*' --dry-run` | 0。実行前の選択を確認 | 1秒未満 |
| 作業末: `scripts/check.sh --level work --base 95378554353786cab7b323336937ced204d036c7 --test '*'` | 0。fmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tallyが成功。libは1209成功/失敗0/既存ignore21、統合38ターゲットは267成功/失敗0/既存ignore7 | 366.833秒 |
| 作業末の追加: `cargo clippy --all-targets` | 0。R156のbin・exampleを含む対象の検査 | 9.879秒 |
| 最終の差分確認: `git diff --check` | 0 | 1秒未満 |

`<D>` は本改造のディレクトリである。workの本実行は一度だけであり、lib全件・統合・fmtを入口の外で繰り返していない。`cargo test --all-targets`、特殊構成の全件、gc-stress、check-formal、lake buildは実行していない。通常の検査を別の状態へ引用していない。mapの比較状態、再現する差分とハッシュ、入力と比較の説明は [README.md](README.md) と [map-state.json](map-state.json) に保存した。

## 計画からのずれと申し送り

R156に、workのlint_defaultがlib/testsだけであることと、依頼の `cargo clippy --all-targets` を作業末に追加する対応を記録した。疎な表の実装は新しい私有モジュールbody_map.rsへまとめた。意味・形式化・公開契約の判断変更はない。

後のT2/T3はmap.patch・map-state.json・old.json・map.jsonを上書きせず、同じcorpusの全体番号・型・効果・NoFail・辞書・診断順・コアを比較する。map.patchのSHA-256は `2172db67a95a17b632ca165c235d163d6dafc72d202d1bf4f6d7af3a7f87ef9a` である。

512局所束縛の一つの本体でも局所の費用増加は見られなかった。ただしdebugの単一標本であり、R17/R19/R22の達成は判定していない。多列match・長いletのコード生成・IR検査のEnv複製は今回の範囲外である。段末の検査・全形式化比較・本測定・改造全体のchangeは取りまとめへ残す。
