# 番号付けの再帰の枠の点検

2026-10-25。Apple Silicon の最適化しない既定の lib テスト実行ファイルを、`nm` と Command Line Tools の `llvm-objdump --disassemble-symbols=<symbol>` で読み取った。プログラムの実行やテストのスタックの大きさの変更は行っていない。

| 関数 | 修正前の枠 | 修正後の枠 |
|---|---:|---:|
| identity の Walker::children | 0x20 + 0x1000 + 0x70 = 4,240 バイト | 0x20 + 0x440 = 1,120 バイト |
| Walker::expr_inner | 0x20 + 0x2f0 = 784 バイト | 同じ |
| Walker::expr | 0xd0 = 208 バイト | 同じ |

複雑な腕を補助関数へ分け、振り分けが戻り値を直接返す形にした。子を辿る順序と番号の取得・予算の計上順は変更していない。これは個々の関数の逆アセンブルから得た枠の大きさであり、処理系全体の最大スタック量ではない。

修正前の既定 lib は、既存の `typeck::pattern_ext::tests::deep_expressions_stay_within_the_normal_stack` で SIGABRT になった。腕の抽出だけでは同じ局所検査がまだ失敗し、戻り値を直接返す変更後に成功した。局所の成功は [deep-stack-shapes-fixed.log](deep-stack-shapes-fixed.log) に保存した。入力の形を識別するため、その実行だけ既存テストへ診断用の出力を加えたが、直後に削除し、テストの最終差分はない。元の六入力・深さ・期待値・スタックの大きさを維持した。診断出力を外した最終状態は [work-verified.log](work-verified.log) の lib 全件でも成功した。最終の lib テスト実行ファイルでも children の枠が1,120バイトであることを再確認した。
