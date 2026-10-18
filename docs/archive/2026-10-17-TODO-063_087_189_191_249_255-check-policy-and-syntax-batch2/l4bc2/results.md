# L4bc2 L4bの続行

基準BはL4b取り込み後の `e022842dbea293a2285a9828632993c736da73b2` に固定する。コミットとdocs/todoの変更は行わない。現行planにL4bc2の節はなく、L4bの続行として表層12件とroutingManifestの原因を調べる。R66の文字の不一致の受け入れ判断は設計者へ問い合わせ中である。

## テスト追加前の四問

1. 守る契約は、ハンドラの節で新たに生じる効果を探索して表層の公開checkerが正しい効果を返し、純粋だとする注釈を拒否することである。
2. 反復の候補を広げる前に節の効果を包含検査する退行と、探索を許す修正によって最終の純粋性検査まで外してしまう退行を検出する。
3. 既存のハンドラ例は節の効果が純粋、または本文の初期候補で既に覆われるものだった。既存CheckExamplesの操作宣言と公開checkExprを共有し、節だけが別の効果を加える正負の対照を追加する。
4. 本番の差し込み口・公開範囲は増やさない。Leanの公開checkerの実計算を評価する。

## できたこと

- `Surface/Check.lean`で通常節の外側の効果の包含を、内側と同じstrict/strictContsの条件へ移した。relaxed探索では実際の効果を外側へ戻して候補へ加え、確定後は両方の包含を要求する。R67へ理由を記した。
- `CheckExamples.lean`の既存の操作宣言を共有し、節だけが別の効果Bを加える正例と、同じ式を純粋と注釈したラムダを拒否する負例を加えた。既存の例・assert・期待値・ignoreは変えていない。
- 01-12・07-04の検査の写しをそろえた。宣言的な型付けの規則と主要定理・健全性11件の言明、公理、Builtins.Assumptionsは変更していない。既存の健全性と支持保存の証明は本体を変えずに通った。
- L4bが記録した表層12件を11入力へ絞り、surfaceCheckの実CLIで全件が成功することを確認した。[12件の結果](surface-selected.json)。
- 旧Rust出力のrouting全1741入力を照合し、差がfmt/header.bnt一件だけであることを確認した。[差の一覧](routing-differences.json)。language 0.0.6へ0.0.7の互換性診断E0908を加える現在の実装に固定記録が追随していない。R68へ修正案を記し、固定記録と入力は変更していない。

## 途中の検査と修正

修正前のsurfaceCheckでc12-builtin-port.bntのfn:42がパス[0,0,1,0]でeffect exceeds the allowed effectとなることを再現した。追加した正例も修正前にdecideで失敗した。最初の新しい負例はreturnを省いたため、効果の検査より前にlambda body does not exitとなった。ラムダ本文をreturnで包み、意図した純粋性の拒否を確認する例へ直した。既存の期待値は変えていない。

局所ビルドはformal/で `lake build Benitoite.Surface.CheckExamples surfaceCheck surfaceCheckAll` を実行し、新規の負例を直した後は古くなった `lake build Benitoite.Surface.CheckExamples` だけを実行して成功した。局所ビルドの外側の時間は採取していない。

旧Rustのtarget/desugar-diff/run-26715の三ファイルから該当11入力を抽出し、surfaceCheckAllでも28定義のmatchedとmismatched=0を確認した。ただし、全体用のexpectedTailMatchが残るため、部分入力のq11Agreesはfalseだった。この部分実行を全体の成功とはしない（[部分入力の集計](surface-local-summary.json)、[標準出力](surface-local.log)）。最初の集計保存スクリプトは存在しないexamples欄を読んでKeyErrorとなったので、正しい欄で保存し直した。各12定義の受け入れはsurfaceCheckの個別のresult.okを別途確認した。

入力の抽出と個別検査には `/private/tmp/l4bc2-surface-{corpus,builtins,stdlib}.json` を用いた。12件の入力名と定義名は上の結果に保存した。個別検査は `surfaceCheck <corpus> <builtins> <stdlib> golden <input> <report> <fn:ID>` の形で行い、全件で終了0かつresult.ok=trueを要求した。外側の合計は1.728秒だった。routingの全件照合はcheck_named.pyのrouting_entries/keyedと既存routing-manifest.jsonを使い、外側14.821秒だった。

## 作業末の検査

L4bc2の専用指定がないため、L4bのworkの名指しを基準Bで一度実行した。正確な指定・時間は [timings.jsonl](timings.jsonl) にある。

| コマンド | 終了状態 | 外側の時間・結果 |
|---|---:|---|
| `scripts/check.sh --level work --base e022842dbea293a2285a9828632993c736da73b2 --only formal_build,spec_examples,spec_tally --dry-run` | 0 | 0.012秒。[選択](dry-run.log) |
| 上記のdry-runを外した指定 | 0 | 16.109秒。既定のlake build・sorry拒否、仕様例7件、仕様集計とその自己検査が成功。[記録](work-check.log) |
| `python3 -B formal/tests/test_batch2_exchange.py` | 0 | 4.660秒。7件成功。[記録](batch2-exchange.log) |

Rustは変更していないのでlib全件・clippy・fmtは追加していない。check.sh全体・gc-stress・all-targetsは実行していない。文字のLeanとRustの判定は今回変えておらず、R66の既知の不一致が残るため、割り当ての決定前にcheck-formal.sh全体を再実行してはいない。RV2を完了とはしない。

## 計画との差と残り・続行手順

現行plan.mdにはL4bc2がなく、L4bの続行手順の第一項は、R66の受け入れ条件を設計者・取りまとめが決めることである。非同期の質問で追加指示を求めたが、この記録の時点で回答はない。planはL4bに「旧Rust出力の全比較の成功」を要求し、P1に文字のRust接続を割り当てている。実装担当だけで不一致を許容する条件へ変えたり、P1のRust実装を先取りしたりはしない。

1. L4bc2の範囲と検査、R66の受け入れ判断を確定する。文字のRust接続を前倒しするなら、P1の判定・表示・移行・統合検査との分担を明示する。
2. 固定記録のE0908への追随（R68）をどの作業で行うか決める。固定記録を変える場合は、exchange-manifestとrouting-manifestの両方をそろえ、E0910とその他全件の一致を維持する。
3. 古くなった検査だけをやり直し、割り当てが確定した全比較を行う。この作業のworkは既に一度成功している。同じ状態で重ねて実行しない。
4. 独立したRV2最終レビューへ定義・言明・仮定と写し、実際の検査結果を渡す。実装者の自己確認をOpusのレビューの完了とはしない。

L4bとL4bc2全体を完了とはしない。現在の変更はsorryなしの既定のビルドが通る状態である。
