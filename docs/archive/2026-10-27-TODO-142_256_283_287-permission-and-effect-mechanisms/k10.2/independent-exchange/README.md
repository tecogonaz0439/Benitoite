# 独立交換の固定入力と期待値

正式な期待値は、B_WORK に既に存在した `test_range_exchange.py` の PATH_CASES・BUDGET_CASES と各検査の手書きの値である。比較より前のコミットの原文を expected-source.py に保持した。corpus・型表・網羅性の五入力は、その独立した手書きの構築から比較前に固定した。Rust や Lean の出力から生成していない。

supplemental-draft-not-used.json は主担当が別に転記した補助の初稿であり、実行の期待値には使っていない。fn:1 を notCovered とした転記は誤りで、正式な手書き期待値では fn:1 は受理、fn:2 と fn:7 が notCovered である。実行後に期待値だけを修正せず、初稿をそのまま保持する。この補助初稿を一致した証拠には数えない。実行台本は初めから正式な期待値を検査しており、8検査すべてでそれが一致した。
