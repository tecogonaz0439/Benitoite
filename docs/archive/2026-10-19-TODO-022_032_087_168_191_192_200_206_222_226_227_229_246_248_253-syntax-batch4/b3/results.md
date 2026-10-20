# B3 の結果

基準は開始時の `git merge-base HEAD san_benito` で得た `cc91036eac270a210ba755dba460000d6d5cf1d1` である。コミットとdocs/todoの変更は行わない。

## 入力と検査の関門

ブロック式の値・名前の範囲・return・try・捕捉拒否・通常ReferenceのStateを公開checkとVMの境界で検査する。ガードの追記とor dieの説明は独立した固定の文字列を期待値とし、既存の本番parser・型検査・脱糖・codegen・検証器・VM・独立参照評価を接続する。内部の呼び出し回数や字面だけを期待にせず、公開APIと本番の差し込み口は増やさない。verifyの既存の変異とassertは保ち、同じ準備をblockでも囲んで拒否境界を通す。

新しい実行入力はリスト長2以下、構築器の要素数2以下、blockの入れ子2以下、handleの入れ子1である。両照合経路の入力も3回の呼び出しと4caseだけであり、stress用の大きさを下回る。既存のVM局所と指定統合の大きさはB2の調整を保つ。parserの上限検査だけはR177の例外とし、498段/1001段を既定・heap/stressとも同じ入力にする。

## 実装と途中の確認

blockを予約語、ASTの式、primaryの解析へ加えた。名前の範囲を一段作り、型検査・脱糖では既存Blockへ現在のreturnの型・位置・構築器の文脈を渡す。元位置・定数/診断の走査・整形・表層交換も内部へ進む。コアの構成子・効果除去・returnのmarkは増やさない。構文と用語・フロントエンド/名前解決の現行設計と生成Skillをそろえた。

途中は関係するcargo checkとblockの局所テストだけを実行した。追加した診断テストの初期の期待で、bindの隠蔽をE0302、未閉鎖をE0213としていた箇所は、既存の規則のE0334・E0214へ修正した。or dieの説明はランタイムの出力ではなくRunEnd.die_failure.messageに保存されるため、その公開の欄で期待内容を照合した。既存テストのassertと期待値は変えていない。

ガードのblock内のifを受理するテストは、修正前にはE0201で失敗した。blockの内部でin_arm_headだけを解除し、return/tryと節の制限を保った後に成功した。498段の受理と1001段のE0208も通常のテストスレッドで成功した。

完了検査のコマンド・終了状態・外側の時間はcommands.jsonlへ保存する。検査の割り当てはplanのB3と補完、R177・R178に従う。


最初の完了clippyはtry_actions_inventoryの非網羅のmatchで失敗した。移行用exampleの三ファイルもblockのbodyへ進むようにし、返した関数の名前の抽出は最後の値へ接続した。再検査は成功した。最初のworkはfmt成功後、libの2件で失敗した。1235件は成功、既存ignoreは21件である。追加した仕様例による抽出件数の14→15と、ノード位置の既存の検査へのBlockExprの接続をR179のとおり直した。既存のShapeのassertも保持し、参照する例の添字だけを移した。修正した2件は個別に成功を確認した。この局所修正確認の外側の時間は未計測である。

成功済みのlib1235件を重ねず、修正した2件と、未実行の全統合・残るworkを合わせて完了を確認する。parserのテストの変更で古くなったfmtとclippyは更新する。既存のassertの削除、期待値の緩和、ignoreの追加はない。


workの全統合の途中では、spec_examplesの既存の除外表がblock追加前のキーワード一覧の先頭行を指していたため失敗した。この一項目の字面だけを新しい一覧へ合わせ、除く項目数7件と存在・分類のassertを保った（R179）。既に成功した33統合ターゲットとspec_examplesの他の6件は繰り返さず、当該1件と未実行のターゲットを後続のworkで確認する。


## 完了検査

指定したworkのdry-runと、失敗後に成功済みの単位を除いた残りのdry-runを確認した。最終的に、libは1237件（初回の1235件と修正後の2件）、統合は40ターゲット321件が成功した。統合ターゲットの一覧と実行記録も照合して欠落0を確認した。通常libの既存ignore21件、統合の9件はそのままとした。文書テスト17件とcompile_fail17件（既存ignore1件）、release_stack10件、全ターゲットclippy・fmt・規約・生成Skill・仕様集計も成功した。全件のgc-stressやworkspace all-targetsのテストは実行していない。

補完はheap-verifyとheap-verify+gc-stressの両方で、VM局所lib160件（既存ignore6件）、両照合経路の局所lib1件、指定4統合ターゲット56件（既存ignore1件）が成功した。GC本体と書き込みの障壁は変えず、B3の計画に従ってcheck-heap全体は加えていない。

コマンドと終了状態・外側の時間の全記録は[commands.jsonl](commands.jsonl)に置く。workの最初のfmt/libから、残りの統合と他の単位への続きは、それぞれ[work.log](work.log)・[work-rest.log](work-rest.log)・[work-remaining.log](work-remaining.log)に残した。下表の時間はPythonのmonotonicで測ったコマンド全体の外側の時間である。局所修正の2件だけは外側を測っておらず、記録もnullとした。

| 実行 | 終了状態・結果 | 外側の時間 |
|---|---|---|
| clippy | 101 | 9.614秒 |
| clippy | 0 | 1.285秒 |
| work | 1 | 66.983秒 |
| clippy | 0 | 5.641秒 |
| work-rest | 1 | 229.745秒 |
| clippy-final | 0 | 0.365秒 |
| spec-example-fixed | 0 | 3.983秒 |
| work-remaining | 0 | 183.219秒 |
| heap-vm-lib | 0 | 35.684秒 |
| heap-block-routes | 0 | 0.182秒 |
| heap-integrations | 0 | 127.367秒 |
| stress-vm-lib | 0 | 35.382秒 |
| stress-block-routes | 0 | 0.180秒 |
| stress-integrations | 0 | 92.972秒 |
| exchange | 0 | 1.049秒 |

## 局所交換と両照合経路

workのdesugar_export通常検査で、`export_batch4_blocks`が`target/formal-batch3/blocks/`へ五形式を書き出した。最後に`python3 -B <D>/b3/check_local_exchange.py`で実状態を再照合した。2入力10定義・表層10件・Coverage単体1件・プログラムCoverage1件が六入口ですべて一致し、不一致・対象外・除外・燃料切れは0である。blockValue・blockReturn・lambdaBlockの3定義は、L7の手書きの301〜303の表層と期待コアにも一致した。報告と入力ハッシュは[exchange-results.json](exchange-results.json)に保存した。Leanの定義・定理・公理・Assumptions・既存の例は変えていない。

同じblock-guards.bntを、通常のdef_tree_work=0と、既存の試行予算MAX_DEF_TREE_WORKを消費済みにした状態で下位化した。通常は正の試行量が残り、消費済みは試行のLimitから保存状態へ戻って行照合へ進み、元の予算量が残ることを確認した。両方の下位IRを実codegen・verify・Direct/RequestのVMへ渡し、独立参照評価も同じ元のコアを評価した。全経路の期待は`gh/ghi/i`である。同じcaseの重複した選択肢でもgは一度、偽のgの後にh/iが残り、真のhの後はiを評価しない。

or dieの説明はcopy(b)の直接の形と、block内でdを追記してcopyする形を確認した。失敗時はそれぞれcontext/contextd、成功時はどちらもcontextであり、説明を失敗時だけ一度評価した。通常ReferenceのState、外側の構築器をhandle本体で操作して後でcopyすること、節のblock内でのresumeと捕捉拒否も確認した。

## 計画からのずれと申し送り

検査の重複を避けるlintの置換と両経路の内部予算の使い方はR177、固定manifestの追加はR178、仕様例の増加とキーワード一覧の参照の更新はR179に記した。最初の失敗後は失敗した検査と変更で古くなったlint/fmt、未実行の単位だけを実行した。既存のassertの削除、期待値の緩和、新しいignoreはない。規範の「必ず抜ける文」にもブロック式を加え、01-12/07-04にはRustとの局所接続を明記した。検査後の変更はこの結果と集約、接続の説明文だけであり、Rust・入力のコード例・生成物は変えていない。

B3を完了し、RV3へ渡せる状態である。取りまとめはRV3でT/B全体とこの両経路の結果を確認する。版全体の形式化比較、change/release、版上げ、英日リファレンスと手書きSkill・移行案内は計画どおり後続へ残す。この局所の成功を版全体の受け入れ完了には使わない。コミットとdocs/todoの変更は行っていない。
