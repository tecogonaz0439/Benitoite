# B2 の追加段階

基準は開始時のmerge-base `8425c221c7e240011a052d47fa43e8101a6295ea`である。追加段階では、既定のReferenceへの脱糖を保ち、専用コア・下位IR・命令91〜95・Protoの操作表と専用入力・枠のSlot配列・生存と検証・独立参照ストアを先に追加した。

途中の`cargo check -p benitoite --lib`と`cargo test -p benitoite --lib bytecode::`でコンパイルと命令の局所検査を行った。全命令の既存テストへ新5命令の準備を足した後は34件成功した。さらに`cargo test -p benitoite --lib dedicated_builders_survive -- --nocapture`で、手書きの専用コアをVMと独立参照評価へ渡し、三種類・再開/未再開・入れ子の固定した期待内容を確認した。これらの途中検査の外側の時間は未計測であり、最終の関係状態への引用には使わない。

そのまま同じ作業でb2c2の切替へ進み、型検査の専用操作からStateを外し、通常引数の効果は保った。旧Referenceの展開とBuilderRefsは除いた。既定経路・交換13/5・設計書・生成Skillを含む最終状態と完了検査は[b2c2/results.md](../b2c2/results.md)に記す。この追加段階だけをB2完了とはしない。
