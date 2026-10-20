# G3 の実装と検査

基準B_WORK: `ebd22a9361cc5b5bc1dba38382f944b4d522d45a`（開始時の `git merge-base HEAD san_benito`）。開始時の未コミット差分はなかった。コミットとdocs/todoの変更は行わない。

## 実装

RangeへCheckedLength/CheckedIndexと公開の作成・射影、LengthError/IndexErrorの通常のShowを追加した。NonEmptyListを明示importする非公式モジュールとして登録し、fromList/toList/head/tail/mapとEmptyListErrorのShowを通常の標準ソースで実装した。失敗値はListを保存せず、CheckedIndexは対象と成功要素を保存する。NonEmptyList.mapは先頭の変換の後に残りを順に変換する。

現行設計03-06と生成Skill・同梱表を更新した。03-07はIOの章であり、今回の純粋APIと一般のエフェクト多相mapに対応するIOの変更はない。formalの定義・主定理・公理・Builtins.Assumptionsは変更していない。

## テストの作成時の関門と途中の検査

runtime_builtinsの公開実行経路で、独立した25入力の成功・失敗・優先順・全保存欄・Showを確認する。同じJSONをL6の小モデルにも渡し、独立した期待値へ照合する。既存RangeのInteger単体の検査はListの保持・成功要素・非空を扱わない。要素のReferenceの共有、mapの順序と一回性、先頭と中間でFailを起こした後の未実行は別の一つの実行テストで守る。新入力のListは最大3要素、mapの入れ子は1であり、stressでも同じ小ささである。非公開の実装や本番のテスト用の差し込み口は使わない。

declarationsでは三型の外部構築・更新・表現パターン・全自動アクセサ・構成子の値化をE0340で、別ListをRange.getへ渡す試行をE0402で厳密に拒否する。一般のopaqueのテストでは新標準型の登録と印の漏れを検出できないため、この境界を追加した。stdlib_doc_examplesは追加した二つの実行例の抽出と利用者のdoc実行を担当し、既存の全assertを保って総数を15→17、test数を9→11へ更新した。desugar_exportは通常の型・多相関数と脱糖の六入口、VM/独立参照評価への接続を担当する。

途中はruntime_builtinsのchecked_listsフィルタ、declarationsのchecked_listsフィルタ、desugar_exportのexport_batch4_checked_lists、stdlib_doc_examplesだけを直接実行した。局所試行の全時間は一括計測していない。新規テストの試行では、単一構成子の失敗型への不要な既定枝をE0602で拒否されたため、網羅した一枝へ直した。mapの効果テストはor dieのProcess.Exit宣言・Referenceを含むListのisEmptyでの観察・コールバックのラベルを修正した。docの例では外側の値名とlambdaのvalueの衝突、複数行lambdaのreturnの不足を直した。期待する動作は変えていない。

## 計画からのずれ

R193へ、NonEmptyListの保存欄をfirst/restとして公開head/tailとの名前の衝突を避ける判断と、lint_defaultを依頼の全ターゲットclippyへ置き換える指定を記した。初期の欄名head/tailは公開関数がアクセサを隠して自己呼び出しとなり、実行をCtrl-Cで止めた。その後、正しい保存欄と不透明型の拒否を局所テストで確認した。公開の署名・保存する値・既存の名前解決・Leanの定義は変えていない。

## 作業末の検査

G3行（R193のlint置換）を同じ基準・指定のdry-runで確認した後、workを一度実行し、続けて全ターゲットclippyと局所交換を一度ずつ実行した。いずれも終了0であった。コマンドの完全な引数と外側時間は[commands.jsonl](commands.jsonl)、出力は[dry-run.log](dry-run.log)・[work.log](work.log)・[clippy.log](clippy.log)・[exchange.log](exchange.log)に保存した。

| 検査 | 結果 | 外側時間 |
|---|---|---:|
| G3 workのdry-run | 指定した六単位を選択 | 0.013秒 |
| G3 work | lib 1246成功・既存ignore21件。関連五統合ターゲット計70成功・既存ignore3件。fmt・source_rules・skill_generated・spec_tallyも成功 | 121.412秒 |
| 全ターゲットclippy | 成功 | 5.483秒 |
| 六入口の局所交換 | corpus13/sidecar5の1入力8定義・表層8件、Coverage単体1件・プログラムCoverage1件が全件一致 | 1.038秒 |
| L6の小モデルとの共通入力の照合 | 25件の期待値がすべて一致 | 3.155秒 |

統合テストの内訳はdeclarations 10件、desugar_export 29件（既存ignore1件）、property_library 15件（既存ignore2件）、runtime_builtins 15件、stdlib_doc_examples 1件（内部でdoc例17件）である。workの実行中、libの段階で局所交換の新入力へ負の添字の明示的なmatchを追加した。既に成功したlib/fmtの入力は変えておらず、その後のtests_relatedでこの最終入力のコンパイル・書き出し・VM/参照評価を確認した。作業末の失敗・再実行はない。

小モデルの照合は `python3 -B <D>/g3/check_model.py` で行った。runtime_builtinsが読む同じ [checked-lists.json](../../../crates/benitoite/tests/fixtures/checked-lists.json) から [model.lean](model.lean) を生成し、formal/を作業ディレクトリとして `lake env lean <Dの絶対パス>/g3/model.lean` に渡した。長さ13件・添字8件・非空4件の入力と期待値を共通化し、入力ハッシュ・コマンド・件数・時間は[model-results.json](model-results.json)、出力は[model.log](model.log)にある。これは計算結果の照合であり、新しい公理・仮定・定理の変更はない。formal/は変更していないため、既定lake buildは重ねていない。

長さの対応は03-06に記した。runtime::MAX_LIST_LENの16,777,216はi64の最大値以下であり、runtime::list::lenのu32をList.lengthがi64::fromで損失なく変換する。負の添字とi64の両端も共通入力へ含めた。大きなListを確保してこの数値関係の代用にはしていない。

局所交換はworkの `export_batch4_checked_lists` が `target/formal-batch3/g3/` へ書き出した同じ入力を読み、固定manifestのg3へ件数を照合した。coverageDiff・coverageProgramDiff・desugarDiff・builtinCheck・surfaceCheck・surfaceCheckAllで不一致・対象外・除外・燃料切れは0である。入力ハッシュと各入口の報告は[exchange-results.json](exchange-results.json)、集約は[局所の接続記録](../results.md)へ保存した。成功の全射影、エフェクト多相のmap、失敗の構成子のmatchを通常の型と脱糖で渡し、同じソースのVMと独立参照評価も両IO方式で一致した。

生成は `cargo run -p benitoite --example gen_skill`、整形は `cargo fmt --all` で行い、workで再生成の一致とfmtを確認した。spec_tallyの初回リリース受け入れ条件の未記入はない。check.shの全体、gc-stress、all-targetsでのテスト、heap全比較、stage/change/release、check-formal.sh全体は追加していない。指定したworkの成功を改造全体や公開候補の受け入れ完了とは扱わない。

本番Rust/BNTは196行追加・削除0行、テストとその入力・manifestは547行追加・5行削除である。既存のassertを消さず、期待値を緩めず、ignoreを加えていない。削除行は二つのdoc例の追加に伴う厳密な件数の差し替えと、交換の実行対象への新入力の追加である。

## 後の作業への申し送り

G4以降は新APIを利用できる。版上げ・英日リファレンス・手書きSkillの翻訳・改造全体のchange/release・全形式化比較は計画どおり後続へ残す。局所交換と小モデルの照合を全形式化比較の完了とは扱わない。
