# G3b のレビュー（2026-10-16、Opus 5.5 のサブエージェント）

対象: D7・D8・Z3・D9（`git diff a4bea589 d1ad4b0e`）。ファイルは変えず、cargo・lake は走らせていない。【重大】なし。

確かめた点: G3a の指摘 1〜8 はすべて直っている（`testdata/packages/d8-extensible-run` は run で、Direct/Request の二方式と VM・参照インタプリタの比較を通り、data の `case other` が選ばれる行と record の既知パターンの後の `case _` を含む。E0607 の help は `match ... with` に書き換えて `case _ ->` を足す文言で、golden が厳密に比べる）。標準ライブラリの 4 型を外から照合している箇所（idioms.md、01-09、resource_tests.rs、l32_http_client.rs、named.rs、tools/skill-eval の参照解、tools/bench/wasm）はどれも変数か `_` の分岐を持つか `=` か getter を使う。標準ライブラリの中には 4 型を照合する箇所がなく、内側が閉じたままであることは coverage_export の author の入力が確かめる。テストは弱めていない。段 2 D の範囲の取り残しは見つからず、01-12 から実装方式の記述は 07-04 へ移り、【未決】と「先行モデル」の記述は残っていない。

【中】
1. `CHANGELOG.md:9` の「These remain static errors with exit status 1」は誤り（検査の誤りは 2。`d7-stdlib-extensible.exit`・`d6c-extensible-missing.exit`、リファレンス 131 行、02-10 の 143 行）。`exit status 2` に直し、Unreleased に「標準の 4 型への指定で、外の照合が拒否されうる」ことを一文入れる。
2. D9 の完了条件の段の終わりの検査（`check.sh --only rust,default_lib,spec_examples,skill,spec_coverage,formal`）と gc-stress がまだ実行されていない。オーケストレータが実行して記録し、通ってから段 2 D を完了とする。

【軽】
3. `docs/design/01-spec/01-02-syntax.md:748` の属性の表「将来の形を覆う変数か `_`」に「ガードのない」が抜けている。
4. 03-07（IOErrorKind と関数の対応、262 行付近）と 03-09（213 行付近の表）に `@extensible` の言及がない。01-05「拡張可能な型」への参照を一文ずつ置く。
5. E0607 に将来の形の help が付くと、help が 2 行とも「use `match ... with`」で始まり重なる（`d6c-extensible-missing.diag.json` の 3 件目、`d7-stdlib-extensible.diag.json` の 4・6 件目）。将来の形が反例のときは `match` の help を省き、1 行にまとめる（診断の仕様の変更）。
6. `docs/design/06-tooling/06-06-agent-skills.md:58` の「記す。 四つの」の余計な半角空白。
7. `tests/coverage_export.rs` の source 入力で、既存の Kind・Detail・Unused の入力も「3 つずつ選択肢にまとめた分岐」に変わり、分岐を分けた形が独立入力から消えた（乱択と golden で覆われると思われるが未確認）。4 型だけを chunks にし、既存の入力は元の形に戻す。
8. 「`@extensible` は WIT の照合を緩めない」を確かめるテストがない（構成上は成り立つと推測）。任意: wit の testdata に属性付きの record か data を 1 件加える。

## 対応

1. 【中】1: CHANGELOG の終了状態を 2 に直し、標準の四型への指定により外部の既存照合が拒否されうることと移行方法を Unreleased に追記した。
2. 【中】2: オーケストレータが実行する。段末の `check.sh --only rust,default_lib,spec_examples,skill,spec_coverage,formal` は d1ad4b0e で通過済み（34 分、2026-10-16、オーケストレータからの申し送り）。gc-stress と修正後の最終検査もオーケストレータが実行し、Z4 では実行しない。
3. 【軽】3: 01-02 の属性の表に「ガードのない」を補った。
4. 【軽】4: 03-07 の IOErrorKind と 03-09 の NetworkErrorKind の説明に拡張指定と 01-05「拡張可能な型」への参照を加えた。
5. 【軽】5: R46 の推す案に従い、将来の形を含む E0607 では通常の match の help を省いた。既存の assert を保ち、単体テストと JSON・文章の golden で新仕様の help 全体を厳密に比較する。
6. 【軽】6: 06-06 の「記す。 四つの」の半角空白を除いた。
7. 【軽】7: coverage_export の三選択肢ずつの分岐は標準型に限り、依存の Kind・Detail は独立した分岐へ戻した。Unused の宣言と全十件の独立入力を保持し、書き出した分岐の形も確認した。
8. 【軽】8: R47 の推す案に従い、既存の record-mismatch に属性付き record の不一致を追加した。属性なしの二件を保持し、属性付きの引数・結果も E1008・E1009 で拒否することを golden で確認した。二つの manifest の診断列も同期した。

検査（2026-10-16、Z4、既定の構成）: `cargo test -p benitoite --lib` は 1,162 件成功・既存の 21 件 ignore。`cargo test -p benitoite --test spec_examples --test skill_docs --test coverage_export --test desugar_export` は 32 件成功・既存の 2 件 ignore。golden は `BENITOITE_GOLDEN_FILTER` を `extensible`・`record-mismatch`・`c11-refutable-bind` としてそれぞれ成功。`cargo test -p benitoite --test coverage_export export_coverage -- --ignored --nocapture` も成功。`cargo clippy --all-targets`、`cargo fmt --check`、`git diff --check` は成功。gen_skill を実行し、生成物の差分はなかった。E0607 の既存テストを新仕様へ更新した段階では、修正前の実装が help の重複によって失敗することを確認した。formal/ は変更していない。
