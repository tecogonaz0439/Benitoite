# RV-S への対応

2026-10-25、SR。基準 B_WORK は `ff99531fc777a298fbb0c17ce678de767bcba884`。判断は README の設計者の決定と D23〜D30 に従った。各所見への対応は次のとおりである。

| 所見 | 対応 | 確認・残る担当 |
|---|---|---|
| 中1 | git-workflow の版上げ手順と plan の Z01a に、対象限定の offline 更新による二 lock の同期・差分確認を追加。advisories.py は `--locked` の更新拒否を入力の誤りとして `ERROR`・理由 `lock needs update (--locked)`・終了1に分類 | 自己検査の既存表へ実文言・旧文言のケースを追加し、修正前の失敗と修正後の成功を確認。旧fuzz lockでも実際に終了1を確認。版上げ時の同期はZ01bへ引き渡す |
| 中2 | 02-09 の「従来の100,000個の範囲を保つ」を訂正し、49.0.2に上限がなかったことと0.0.11からの受理範囲の縮小を明記。CHANGELOGにも差とゲストの解放による対処を追加 | 配布ソース49.0.2/49.0.4を照合。BREAKING_CHANGESへの登録の要否をZ01aの判断に明記 |
| 中3 | 73d12d06 の入力を一時コピーへ展開し、現行実行器で実際の cargo-deny 出力を照合。元の fuzz lock の拒否も保存し、一時入力だけの最小同期後に両対象19件の `ADVISORIES FOUND`・ID・修正版を確認 | 生終了は両1、単位0。作業ツリーのlockは不変。入力調整の理由・差分・全出力・reportは [SRの結果](../sr/results.md) に保存 |
| 軽1 | 集約 results のS05見出しを完了へ改め、2026-10-25に取りまとめがリンクを作成・追跡・確認した記録を追記 | 現在の相対リンクとs05の追記を照合 |
| 軽2 | s02b の本文の一時パスと probe-output のリポジトリの絶対パスを `<tmp>`・`<repo>` に置換 | 生記録のパスを置換した旨をs02b/resultsへ追記。S01〜S05とSRの保存物の手元の絶対パス不在を確認 |
| 軽3 | 07-03とsecurity-advisoriesスキルへ、端末の記録を保存するときも同じ置換を行う規則を追加 | SRの端末記録も置換し、実行器のpath_redactionと置換前の入力ハッシュを保持 |
| 軽4 | check.sh の fuzz manifest/lock を独立した分類行へ分け、rust・advisoriesだけを選択。07-03と自己検査のwork/change表を同期 | 局所分類テストと作業末のpolicy_selftest成功。既存legacy固定記録は変更なし |
| 軽5 | testdata/external/README にcomponent-handlesがexternal::runtime::testsの入力であること、初回生成にロック済みwatクレートを用いたことを追加 | ファイルと既存の再生成手順へ照合。入力バイナリは変更なし |
| 軽6 | s03/resultsの `CARGO_HOME=<tmp>` の閉じるバッククォートを補った | 表記を静的確認 |
| 軽7 | README「設計者の決定（2026-10-25、処理系の作業の途中）」にある取りまとめの追記を確認 | 依頼どおり重ね書きせず、最初の判断・最後の表示だけの扱い・独立スキルの三条件を確認 |
| 軽8 | s02b/resultsに、優先はfailure/has_priority_failureの順序の読みで確認し、同時の超過を起こすテストはないと追記 | 実行で優先を確認したとの主張をしていない。テスト追加なし |
| 軽9 | AGENTSの改造手順2へ、組み込むTODO番号をディレクトリ名へ加え、改名に伴う参照も直す規則を追加 | 手順1との対応を確認 |

作業末は指定の `scripts/check.sh --level work --base ff99531fc777a298fbb0c17ce678de767bcba884 --only policy_selftest,advisories,python_syntax` を、同じ指定のdry-runの後に一度実行し、検査本体0だった。方針自己検査26件・Python構文検査が成功し、現行二lockはともに検出0件。外側20.492秒。timeの最大常駐量はsandbox制限で取得不能であり、検査本体の終了と分けて記録した。

計画からのずれは、中3の元のfuzz lockに版と依存の記録の不一致があったため、一時コピーだけを最小同期した点である。詳細・コマンド・失敗と修正・保存証拠は [sr/results.md](../sr/results.md) にある。作業対象リポジトリのgit変更操作、Rust/Leanソース・作業ツリーの二lockの変更は行っていない。Z01aでの互換性の区分の判断と、取りまとめによるレビュー・受け入れへ引き渡す。
