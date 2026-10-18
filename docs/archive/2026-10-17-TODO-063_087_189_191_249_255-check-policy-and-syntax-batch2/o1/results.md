# O1 作業記録

基準B: `8604e358d68e9f19897903afeb5c5b3635a97c18`（RV2-final取り込み）。コミット・docs/todoの変更は行わない。

段2の閉鎖は../results.mdの同名節に記録した。以降のRustは確定したLeanへ合わせる。

## test-auditの作成時の関門

1. VM/参照実行器で、同一の操作節が呼び出し側の型ごとに辞書を受け取り、複数・上位クラスと値化を通じて正しい結果を返す契約を守る。独立IR検査は辞書の数・型・所属・順序を守る。
2. 外側の辞書との番号の衝突、節での実装の再選択、辞書と値の配置の逆転、安全点での辞書の取り落とし、値化での辞書欠落を捕まえる。
3. 既存のハンドラの実行表は制約付き操作を受理できず、この契約を通らない。既存の実行表へ事例を足し、IRの不正入力の表は独立検査に固有の危険として補う。
4. 本物の型検査・脱糖・コード生成・VM/参照実行器を使い、本番用でない差し込み口は加えない。

R74の退行テストも同じ型検査の入口を使う。実装の組み込み制約の補助検査が節の型パラメータを失う退行を捕まえる。既存の実装の制約のテストは通常の型パラメータと具体型を使うため、この経路を通らない。正例と負例で内部停止と制約検査の省略を区別し、修正前の失敗も確認した。

## 検査

途中は `cargo test -p benitoite --test vm_handlers scripts_connect_real_codegen_to_handlers_and_runtime` と、`cargo test -p benitoite --lib operation_`、変更したparserテストの名前による局所検査を実行した。最終の局所結果はVMの一表が成功、operation_が17件成功である。外側の時間は途中の検査では別途計測していない。最後の局所コマンド `cargo test -p benitoite --lib operation_ --test vm_handlers` は名前のフィルタがVMのテストを選ばないため、VMの成功件数に加算しない。

初回の実行例はimportの位置と操作の修飾を誤り、E0219・E0304を返した。モジュール先頭のimportと同じモジュールの操作名へ直した。次に複数引数の契約名、lambdaの明示のreturnを直し、正しい実行例で検査した。参照実行器の引数の列の連結はExactSizeIteratorでないため、変数番号のVecへ集めて既存の個数検査を保った。負例の診断番号は表に定義されたE0451へ合わせた。プロトタイプの誤りを本番の診断や期待値を緩めて回避していない。

作業末の検査と追加変更後の更新を完了した。R73により全targetのclippyはworkと別に一度だけ実行する。workの完全なコマンドは [work-command.txt](work-command.txt)、選択と包含は [work-dry-run.log](work-dry-run.log)、終了状態と外側の時間は [checks.json](checks.json) に保存する。

## 変更と申し送り

- parserは型クラス制約の禁止だけを外し、宣言の既存のSchemeへ保存される制約を使う。型構成子・効果変数・操作自身のusesの禁止は保つ。
- DictExpr.Clauseは節の所属を持ち、遅延解決でも外側のParamと混ざらない。Clause.dict_paramsをコアIR・独立検査・低位IR・自由変数・PERFORM・参照実行器まで接続した。VMの既存の任意個の引数・根の保存を使い、GC本体やunsafeの不変条件は変えていない。
- VMの実行表に5例を加え、独立コア検査とバイトコードの検証も通す。型検査の負例、独立IRの6変異、参照実行器の辞書・継続・ラムダの例を加えた。既存のparserの拒否二例の期待を、決定した仕様に合わせて受理と制約保持へ変えた理由はR72に記録した。
- 現行設計の01-02/06、02-05/06/08/09、英語リファレンスを更新し、診断表から削った禁止の説明をSkillへ再生成した。生成元以外のSkill文書は手で編集していない。
- O2は交換11/4のRust側、穴・パイプ・入れ子・外側の0番と節の0番・ソース順の対照を担当する。10/3の書き出しで新しい節の根拠を受けたら明示的に拒否し、対象外へ分類して成功にしない。O1ではcheck-formal.sh全体・全統合の特殊構成・check-heap.shを追加していない。
- 計画との差は、RV2の先行修正（R71、依頼どおり）、節の根拠の保存の具体化と旧拒否例の変更（R72）、clippyの範囲（R73）、実装の組み込み制約への節の情報の引き継ぎ（R74）である。新しいLean規則・主な定理・公理・Builtins.Assumptionsの変更はない。コミットとdocs/todoの変更は行わない。


## R74の追加修正と検査の更新

workの実行中に、辞書の実装が要求する組み込み制約の補助検査へ節の情報が渡らないことを確認した。型検査の新しい退行テストは、修正前にmissing operation type parameterのassertで失敗（終了101）、修正後に正例・負例とも成功（終了0）した。実装の頭部の検査と本体からの検査を分け、後者だけに節の型パラメータと操作名の表を渡した。workのfmt・lib・統合と先行clippyは修正前の入力なので、最終の成功へ数えず、直接のコマンドで更新する。生成物・集計・規約の関係入力はこの修正で変わらず、局所heap/stressは修正後の入力で実行する。release_stackは開始時刻を確認したところ、修正より前にビルドが始まっていたため、その成功を最終状態へ数えずに更新する。


## R75の検査の構成の取り違えと更新

R74後のfmt・clippyは成功した。通常のlibも1201件成功、21件は既存のignoreである。続く統合テストは10ターゲット成功後、interrupt_processのsigint_at_sort_end_overrides_a_unit_returnとsigint_at_sort_end_overrides_a_result_error_returnが準備待ち30秒で失敗し、コマンドは終了101（外側244.413秒）だった。記録はrust-after-r74.logに保存した。

この通常構成のCargoを局所gc-stressと同じtargetで並行実行したため、実行ファイルがgc-stress版へ置き換わっていた。通常の試験器は20万要素を作り、gc-stress構成用の100要素への短縮を使わない。失敗した二件がこの入力をgc-stressのCLIで実行していたと判断した（R75）。sourceやassert、ignore、時間制限は変えず、特殊構成とreleaseのCargoが終わってから、失敗した二件と未実行25ターゲットを直列に実行する。成功していても共有CLIを使った四ターゲットとinterrupt_processの残り七件は構成の混在を除けないため更新し、libと共有CLIを使わない六ターゲットは重ねない。


## 最終の完了確認

O1を完了した。基準Bは冒頭の8604e358d68e9f19897903afeb5c5b3635a97c18のままである。work入口は一度だけ実行し、R74の追加修正とR75の構成の取り違えで古くなった検査だけを直接更新した。最終の構成でlibは1201件成功、21件は既存の長い対象等のignoreである。統合36ターゲットは、共有CLIを使わない六件、更新したCLIの四件、interrupt_processの二件と残り七件、未実行だった25ターゲットを突き合わせて漏れがないことを確認した。新しいignoreは加えていない。

| 検査 | 終了状態・外側の時間 | 結果と記録 |
|---|---|---|
| planのwork（初回。追加修正の影響分は下で更新） | 0、479.752秒 | 規約・Skill再生成・仕様集計も成功。work.log、work-command.txt |
| fmtの更新 | 0、2.278秒 | 成功。fmt-after-r74.log |
| 全targetのclippyの更新 | 0、6.523秒 | 成功。clippy-after-r74.log |
| R74後のlibと統合の開始 | 101、244.413秒 | lib 1201件と共有CLIを使わない六ターゲットの成功を採用。CLI混在の失敗はR75で更新。rust-after-r74.log |
| 失敗した中断の二件 | 0、10.814秒 | 2件成功、7件は名前のフィルタで非選択。interrupt-after-r75.log |
| 未実行だった統合25ターゲット | 0、236.227秒 | 全件成功。remaining-after-r75.log |
| 共有CLIを使う統合四ターゲット | 0、9.797秒 | 全件成功。cli-after-r75.log |
| 残りの中断の七件 | 0、1.881秒 | 7件成功、済んだ二件は名前のフィルタで非選択。interrupt-others-after-r75.log |
| 修正後のrelease_stack | 0、78.246秒 | 10件成功。release-stack-after-r74.log |
| 局所heap-verifyのvm_handlers | 0、105.308秒 | 全実行表が成功。heap-local.log |
| 局所gc-stressのvm_handlers | 0、107.539秒 | 全実行表が成功。stress-local.log |

完全なコマンド・終了状態・外側の時間はchecks.json、checks-after-r74.json、checks-after-r75.json、cli-checks-after-r75.json、release-stack-after-r74.jsonに保存した。初回clippyは終了0・7.702秒、workのdry-runも終了0であり、文書例・英語例・skill_docsの検査がtests_relatedへ包含され、重複しないことを確認した。

変更したMarkdownと本記録のローカルリンクを確認し、欠損はない。git diff --checkも成功した。段2のLeanの閉鎖は../results.mdの記録どおりで、R74/R75でもformal/は変えていない。通常構成と特殊構成を同じtargetで並行実行しないことを、後の作業へ申し送る。O2への機能上の申し送りは上記の交換11/4と呼び出し形の対照であり、O1の未完の項目はない。
