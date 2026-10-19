# L7の実装結果

2026-10-18、Codex。L7は完了した。B_WORKと作業対象HEADは `963040ed61b1af211cfb22e082060b6ca8c419a5`、開始時の作業ツリーはクリーンだった。コミットとdocs/todo/の変更は行っていない。

## 変更

- Exchange/Syntax・ConvertにbuilderBind/builderOp、種類別のkind/refs、セルのnew/get/set、純粋なprim/funRefと型引数の読書きと表層への変換を加えた。局所番号を付け直さず、lambdaEffectsは宣言の後続と操作の引数も辿る。
- Versionでcorpus8/9/10/11/12とsidecar2/3/4を分け、batch2の拒否・補完をcorpus11未満とsidecar4未満だけに限定した。corpus11/12は同じ必須検査とsidecar4を使う。旧版への新情報の深い混入、新タグの欠落・曖昧な併記・余分な欄と定数本体の専用構文を拒否する。
- batch3-exchangeの五形式・手書きの期待コア・manifestとPythonの入口を加えた。六入口で30定義が一致し、surfaceCheckAllもmatched=30、他の分類は0。coverageは3件、coverage-programは2件の独立期待を保つ。通常辞書、節の辞書、resume、値とセルの交互配置の番号はREADMEに手計算を記録した。--rust-dirは五形式の欠落・0件・除外・対象外を失敗にし、Cargoを起動しない。
- 01-12・07-04に交換契約と未接続の範囲を反映した。R155にJSONの欄・版判定・独立入力の具体化を記録した。formal/Benitoite.leanは既にSyntax/Convertとその依存を正式importしているため、追加のimportは不要だった。

## 言明・定義と公理

[contracts-comparison.json](contracts-comparison.json)は、Exchange以外の本体モデル171ファイルがB_WORKとバイト単位で同じであることを記録する。Releaseの規則・Builtins.Assumptions、公開11件とprogram、捕捉の定理を含むSurfaceの全定義・補題を変更していない。さらに、L1開始版 `8f4bfce16dbfa08f8f3a61e1b0c504e94857d0d3` と公開言明24件を直接比較し、一致した。Input.Sound・Program.WellTyped/WellFormedの定義も一致し、Def/ImplDecl.WellTypedの違いはL4aで決めたQsig直後の空Δだけである。新構文を前提から除く条件はない。

[公理一覧の入力](axioms.lean)はformal/README.mdのコードブロックを全件そのまま保存した。33件の[出力](axioms.txt)はL6c2の出力と一致し、L1開始時の30件の出力も先頭部分で一致した。小モデル・二引数辞書・構築器の補助は[別の入力](additional-axioms.lean)で149件を確認した。[出力](additional-axioms.txt)はpropext・Classical.choice・Quot.soundの範囲内で、sorryAx・Lean.ofReduceBool・独自公理はない。[比較の要約](axioms-comparison.json)を保存した。以前の結果は公理の比較対象として使い、今回のビルドやテストの代わりには引用していない。

## 検査

完了検査は変更を終えてから一度実行した。workは `scripts/check.sh --level work --base 963040ed61b1af211cfb22e082060b6ca8c419a5 --only formal_build,spec_examples,spec_tally` とし、先に同じ指定へ--dry-runを付けて選択を確認した。Pythonの各行は `python3 -B <パス>` である。公理の二件はformal/をcwdとして `lake env lean <本ディレクトリの入力>` を実行した。完全なコマンド・cwd・終了状態・外側の時間は[check-times.json](check-times.json)にある。

| 検査 | 終了状態 | 外側の時間 | 記録 |
|---|---|---|---|
| work（三単位）のdry-run | 0 | 0.010秒 | [work-dry-run.txt](work-dry-run.txt) |
| work（三単位） | 0 | 12.064秒 | [work.txt](work.txt) |
| formal/tests/test_batch3_exchange.py | 0 | 7.101秒 | [batch3-exchange.txt](batch3-exchange.txt) |
| formal/tests/test_named_exchange.py | 0 | 2.428秒 | [named-exchange.txt](named-exchange.txt) |
| formal/tests/test_try_exchange.py | 0 | 3.750秒 | [try-exchange.txt](try-exchange.txt) |
| formal/tests/test_extensible_exchange.py | 0 | 6.623秒 | [extensible-exchange.txt](extensible-exchange.txt) |
| formal/tests/test_batch2_exchange.py | 0 | 1.477秒 | [batch2-exchange.txt](batch2-exchange.txt) |
| formal/tests/test_width_exchange.py | 0 | 1.230秒 | [width-exchange.txt](width-exchange.txt) |
| 新しいPythonの構文解析 | 0 | 0.028秒 | [python-syntax.txt](python-syntax.txt) |
| READMEの公理一覧 | 0 | 0.718秒 | [axioms.txt](axioms.txt) |
| 小モデル・内部補題の公理一覧 | 0 | 0.684秒 | [additional-axioms.txt](additional-axioms.txt) |

workのformal_buildは既定の全体lake buildとsorryの拒否に成功した。仕様例は7件成功・失敗0・ignore0、spec_tallyは自己検査と集計に成功し、初回リリース版の完了条件の未記入は0件だった。節へのテスト参照のない箇所の一覧はwork.txtに保つ。交換テストの件数は{"batch3-exchange.txt": 11, "named-exchange.txt": 13, "try-exchange.txt": 8, "extensible-exchange.txt": 22, "batch2-exchange.txt": 7, "width-exchange.txt": 4}で、すべて成功した。

途中はExchangeと関係する実行ファイルだけをlake buildし、新しいPythonの関係するテストメソッドだけを実行した。途中の失敗は、手書きJSONのmeth/Arm/constructorNameの書式、関数末尾のreturnE、tailMatchの固定件数、partialConに誤って選んだレコードであり、書式と意味の対応を直した。期待の緩和や既存assertの削除・ignore化はない。実行位置を誤った一時スクリプトとリポジトリ根でのlakeの呼び出しは失敗し、正しいcwdへ直して実行した。契約比較の一時スクリプトもQsigの括弧付き表記への照合を直した。

Rustの変更はなく、全lib・全統合・clippy・fmt・gc-stress・check-formal全体は実行していない。構文の章・標準ソース・診断表を変えていないためgen_skillの再生成は不要である。本番Leanは+107/-15行、新規Pythonテストは+266/-0行、既存テストの変更・削除は0行である。JSONは独立入力として加えた。検査時の関係入力のSHA-256は[verified-inputs.json](verified-inputs.json)にある。

## 計画からのずれと申し送り

実装の範囲と保証に変更はない。R155は交換schemaと手書き入力の具体化である。Result/UserResultへのpureは受け取ったMonad2辞書を用いる型と脱糖の比較であり、任意の実装の法則・実行の証明ではない。本体の実装と実行の具体例はL2のままである。

RV2ではL1〜L7の規則・写し・公開言明・前提の意味・公理依存と、独立入力の番号と捕捉の正負をレビューする。T3/M1/B3では、今回固定したcorpus12/sidecar4へ実ソースの出力を接続する。B3がRustのlib.rs/named.rsとcheck_named.pyを12へ切り替え、check_batch3.py・manifestの実ソース比較と最終check-formal.shへの接続を行う。Rustの通常出力はcorpus11のままであり、新しい本番全比較は未接続である。
