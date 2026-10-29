# 診断の英文と案内の独立レビュー

R40.1 の診断・設計書の実装担当とは別の担当が、`diag/codes.rs` の E0513・E0519・E0520・E0521、`typeck/text.rs` の補足、実際の CLI 出力を読んだ。テストの作成担当による診断文案のレビューであり、テスト自体の独立レビューは [review-tests.md](review-tests.md) に分けた。

| 対象 | 確認した内容 |
|---|---|
| E0513 | 型引数と範囲引数の双方を拒否対象として示し、要求する型引数の個数と、範囲引数を許さないことを分ける。標準の範囲付きエフェクトの説明と矛盾しない。Failure.Fail の不足・過剰の golden 3件の主文も追随した |
| E0520 | PathIn の複数範囲に対し `exactly one path string literal` と伝え、`found` と主位置は実際の角括弧の列を示す。RequestIn は一組とする |
| E0519 の四理由 | notCovered・atomicCoverOnly・unknownSource・budgetExceeded を区別する。和による包含は調べないという説明を保ち、unknown や予算の拒否を「必ず範囲外」としない |
| Top の操作 | File.Read、File.Write、Http.Connect ごとに利用できる In 入口と検査を案内する。検査結果の範囲注釈を明示する案と、uses の範囲を外して Top へ広げる案を分ける。Read は常設 CLI テスト、Write/Connect は保存した実入力で、案内を当てた後の受理を確認した |
| 入れ子 | 射影・拡大の呼び出しを `bind` の右辺へ移し、その名前を使う案内である。PathIn/RequestIn の射影・拡大を含む四入力が修正前に拒否され、修正後に受理された |
| 狭い関数引数 | `bind` だけでは由来を得ない。裸の入力型にする案では、拡大の戻り型も裸にする必要がある。この補足を指摘し、実装担当が英文に反映した。同じ狭い型で転送する案と区別する |
| 狭い節引数 | bind だけでは直らず、Top にする場合は保護本体の選択も Top とし、必要なら uses を広げる。PathIn/RequestIn の射影・拡大を含む四入力で拒否と修正後の受理を確認し、同じ狭い型で転送する二入力は元の狭い上限を保って受理された |
| DET-05 の位置 | 原子の E0519 は呼び出しを主位置、必要な uses の原子を補助位置とする。成功した検査の値を狭すぎる行き先へ拡大する入力では、出力注釈と成功した検査の呼び出しを補助位置に示す。notes の requiredUpperBound・knownUpperBound・uncoveredAtom・source・reason は意味を区別する |
| 戻り型の補助制約 | ScopeResult の E0401 は実際の呼び出しの頭を指し、`argument 1` ではなく検査・拡大の結果型の一致を説明する。Result[Integer, ScopeError] を検査の結果へ注釈する入力で確認した |
| 予算 | 番号付けの停止は全規則 Top と定義分割の案内、局所解析は最後の Run の超過と由来の忘却・リテラルの保持を示す。共有 const の展開を別の定義へ分離する修正と、局所予算の例で結果型を Top にする修正は受理された |
| E0521 | 最終読者向けに handler の scopes と保護本体の effects の不一致を示す。callback の型・効果を明示する案内は解消を保証しない。自然に上限へ到達する入力と、その案内が拒否を解消することは未確認のままである |

レビュー中に指摘した、入れ子の呼び出しを置く位置の明確化、Top の入力を拡大する際の戻り型も Top とする補足、節の保護本体と uses の変更の区別は、最終の英文に反映された。残る指摘はない。E0521 の未確認は検証済みへ変更していない。

実行の証拠は [diagnostic-cli-tests-final.log](diagnostic-cli-tests-final.log)、[diagnostic-probes-final.log](diagnostic-probes-final.log)、[diagnostic-probes-final.json](diagnostic-probes-final.json)、[diagnostic-budget-and-result.log](diagnostic-budget-and-result.log) に置く。49入力の最終の手動 CLI 検査は4.34秒であり、案内の修正以外の意図的な拒否例も含むため、全件受理の意味ではない。修正前に英文や補足欄が欠けることは、B_WORK の完全 ID を指定した archive の CLI で [diagnostic-regression-before.log](diagnostic-regression-before.log) に再確認した。
