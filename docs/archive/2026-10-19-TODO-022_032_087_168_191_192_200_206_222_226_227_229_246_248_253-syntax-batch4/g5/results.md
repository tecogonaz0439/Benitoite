# G5 の実装と検査

基準B_WORK: `e49b22755790fe85f9df4e98104eaf339b8d07b3`（開始時の `git merge-base HEAD san_benito`）。開始時の未コミット差分はなかった。コミットとdocs/todoの変更は行わない。

## 実装と判断

tools/deriveの再帰する縮小器を、候補要求までfactoryの組み立てを遅らせる通常のShrinkStepとして実装した。容器の削除を欄順に先行し、その後は一欄だけを縮小する。必須レコード欄は自分自身を縮小し、親を同型の子で置き換えない。容器の置換では自己候補を遅延して除く。Gen/Shrinkerの使用する型パラメータだけの引数・phantom・標準容器に必要なequalityの伝播を維持する。

Show/Orderは生成予定の実装の頭を登録してから、欄の辞書の要求を型パラメータへ固定点まで伝える。自己/相互再帰は既存の通常の辞書解決で閉じ、Orderからequalityを導かない。浅い表示と辞書式比較、深さ128の有限値、実行時の小さいスタック予算でのR0901を検査する。新しい再帰辞書・Rustの型検査器・formalの変更は不要である。

生成規則3.0.0-syntax-batch4、意味ハッシュ・manifest/receipt・記録版3へ一度切り替えた。Property.libraryVersionは2.0.0、inventoryは2、設定は1を保つ。宣言名順のグラフ、型引数付きの辺、成分、最小量、予算規則、署名/制約、依存先の設定/指定関数/実装、テンプレート版を意味ハッシュへ含める。本文のbytesハッシュを別に照合し、旧本文が改変されていれば移行を提案しない。旧manifestを拒否し、新previewの確認hashによるapply/checkとreceiptの再適用・記録書込失敗の復旧を保つ。

同梱People/Address例は、旧記録版2と本文のハッシュを照合して新previewを確認し、manifest SHA-256 `dedbbfa5b7c17ca45a20dc5bd7056bc05cbf3aad2c2e4cceb63ae94d19f2e171` を指定して移行した。差分は空で、ソース0件の適用により記録だけを版3へ移行した。その後のderive checkも成功した。確認用の一時previewは `/private/tmp/benitoite-g5-example-review/` にあり、現在の記録を正とする。

設計03-08・06-06・07-04の対象外の行に加え、旧版/旧拒否の説明がある03-06・道具のREADME・同梱Skillの手書き部分を更新した。仕様構文・標準ソース・診断表は変更していない。Skillの生成参照はworkで再生成一致を確認する。主定理・公理・Builtins.Assumptionsは変えていない。

判断はR195に記した。比較できないTの直接の欄にequalityを足さず、その独自Shrinkerが自己候補を除く契約を明記した。標準の葉と容器が自己候補や再帰節点数が増える候補を出さない範囲と、独自Shrinkerの往復・停止を保証しない範囲を区別する。旧拒否テストの再帰/多相の入力は新しい成功例で検査し、拒否の行は非正則な再帰と辞書のない関数欄へ替えた。版の期待も新版へ厳密に更新した。assertの削除・緩和、ignoreの追加は行っていない。

## テストの作成時の関門

新しい自己検査は道具のpreview/apply/checkと本番CLIのcheck/testを接続し、候補順・一欄の更新・自己候補の除外・節点数非増加・必須欄/Map・縮小の予算・多相の制約とphantom・再帰するShow/Order・旧記録移行とreceipt・依存変更を独立の期待へ照合する。これらを覆う旧例は単相/非再帰であり、コンパイラ内部の代用やテスト専用の本番入口は追加しない。

入力は浅い独立期待値と、有限の鎖の深さ128を分ける。Python自己検査のCLIは補完の既定構成のcargo buildから起動するものであり、gc-stress全件へ混ぜない。既存のRustの深い入力は変更しない。Listの要素数は最大3件、再帰節点の個数は最大129件とし、深さ128を超えない。低い実行時のスタック予算でR0901も確認する。

## 途中の局所検査

新しいケースと関係する既存ケースだけを直接実行した。初期の局所試行では、lambdaのラベル/束縛の隠蔽と、標準のInteger縮小順（4から0,2,1）・Map表示（Map.fromList）の期待を誤り、失敗を確認した。ラベルに合う外側の束縛名と、標準の厳密な期待値へ直した。旧assertの削除・緩和はない。局所試行の外側時間は一括計測していない。

## 作業末の検査

planのG5行を同じ基準・指定のdry-runで確認し、9単位と4統合ターゲットを選択した後、workを一度だけ実行した。続けて最新helper/CLIのビルド、derive全自己検査を各一度実行し、最後に同梱例を通常CLIとderive checkで照合した。すべて終了0で、作業末の失敗・再実行はない。コマンドの全引数・終了状態・外側時間は[commands.jsonl](commands.jsonl)、出力は下のログへ保存した。

| 検査 | 結果 | 外側時間 |
|---|---|---:|
| [G5 workのdry-run](dry-run.log) | planと同じ9単位・4統合ターゲットを確認 | 0.015秒 |
| [G5 work](work.log) | lib 1246成功・既存ignore21件。関連統合77成功・既存ignore2件。fmt・clippy・source_rules・Skill再生成一致・spec_tally・Python構文・移行器自己検査も成功 | 126.473秒 |
| [derive_inventoryとbenitoiteのビルド](build.log) | 成功 | 0.584秒 |
| [derive全自己検査](derive.log) | 42件成功（既存39件＋新規3件）。実生成コードの通常check/testと低いスタック予算、旧記録/manifest/receipt・改変/依存変更・再適用/復旧も照合 | 68.217秒 |
| [同梱例の通常check](example-check.log) | 成功 | 0.332秒 |
| [同梱例の通常test](example-test.log) | 2件成功 | 0.499秒 |
| [同梱例のderive check](example-record.log) | 本文と版3の記録が一致 | 0.324秒 |

関連統合の内訳はdeclarations 10件、property_library 15件（既存ignore2件）、stdlib_doc_examples 1件、test_command 51件である。clippyはplanのlint_default（lib/tests・gc-mark-sweep）をそのまま実行した。Rustの変更はなく、追加のall-targetsは行っていない。処理系の既存テストを弱めず、新しい道具の振る舞いの主な検査をPythonの公開の管理境界へ集めた。

静的な確認では変更した文書のローカルリンク225件に切れがないこと、git diff --checkが成功することを確かめた。自己検査のPython側のassert呼び出しは147件から166件へ増え、既存assertの削除・緩和とignoreの追加はない。版と対応範囲に伴う7行の更新は厳密な新期待値と拒否例の差し替えであり、その意味をR195と上の実装欄に記した。本番Pythonは211行追加・41行削除（新補助88行を含む）、テストは198行追加・7行削除である（削除行は上記の期待値・拒否入力を更新するための旧行である）。

## 後の作業への申し送り

G5の完了条件を満たした。検査後に更新したのは本結果の記録だけである。formal/の変更はなく、lake buildと全形式化比較は追加していない。stage/change/releaseとgc-stressの全件、版0.0.10への更新・英日全体の照合は計画どおり後の担当へ渡す。主定理・公理・Builtins.AssumptionsとRustの共有インターフェースに変更はない。

直接の型パラメータ欄に渡す独自Shrinkerの自己候補の扱いと、共有の適用receiptへの版欄の付記前からの復旧はR195を参照する。旧未完applyは保存した旧道具で復旧してから新版previewへ移る。種だけで旧生成分布を再現する契約は追加していない。新しいproperty_shrink.pyも、確認するmanifestの道具の入力ハッシュへ含めた。
