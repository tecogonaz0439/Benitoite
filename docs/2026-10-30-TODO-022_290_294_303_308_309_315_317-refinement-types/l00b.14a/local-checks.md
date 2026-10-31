# RV-L00b.14a 対応中の局所検査

初回実装の局所検査は [initial-local-checks.md](initial-local-checks.md) に残した。

本番への補題の移植と R の一般化は、最初の DependentBeta.lean の単独検査で終了0となった。開始の ClosureTy.pure は R=some の型について WF・Declared・Normal を要求するので、その証拠を代表の hR として明記した。新しい信頼条件は置いていない。

既存の境界の呼出しを更新した最初の局所実行は、hideBuilders Ψ から Ψ を逆に推論できず終了1となった。[review-first-boundary.log](review-first-boundary.log) に出力を残した。Ψ=StoreTy.empty を明示して直した。そのログの sorryAx は型エラーを持つ宣言の出力であり、成功の証拠として扱わない。

追加の境界の作成中には、BuilderContents.string に空の List ではなく空の String を渡すこと、空の行の注釈を展開すること、捕捉した閉包の E_Lam に ws と body を明示することを直した。これらの構文・推論の失敗は、必要な数学上の事実が導けない反例ではない。新しい公理や未証明の前提で埋めていない。

最終の verify.py は本番と境界の変更を受けて五検査を全て実行し直した。以前の成功の引用は使っていない。現在の boundary.log は95宣言で、終了0・新しい警告0・sorryAxなし。公理の依存も全対象で再確認した。
