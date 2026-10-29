# RV-R20.2: 成功値・射影・忘却と合流の独立レビュー

2026-10-29。対象は R20.2（停止の後の R20.2b を含む）の未コミットの差分（未追跡の `typeck/scope/local.rs`・`local_tests.rs`・`lower.rs` を含む）と `r20.2/` の results.md・ログ。Lean の `ScopeState` の `absStep`・`stepCost`・`Budget.admit`・`Run.step/enter/leave`・`pathCheck`・`requestLitBound`・`projectRule`・`absArg`、`ScopeLower` の `directHead`・`constArg?`・`argForm`・`rhsStep`・`armEntry`・`rejoin`・`analyzeExpr`、`ScopeAccept` の `factFree`・`statesAt`・`acceptCall`・`acceptOccurrence`・`acceptBody`、`ClauseScope.slot` と照合した。公開の `pipeline::check_text` と `scope_inputs` から `ScopeBodyInput::analyze` を呼ぶ外部の小さな探査で入力を通した。作業用のディレクトリと git の状態は変えていない。記録の10ファイルの SHA-256 は今の状態と一致した。

結論: 取り込んでよい。重大0・中0・軽4。

## 指摘

| 番号 | 重さ | 箇所 | 問題 | 修正案 |
|---|---|---|---|---|
| 軽1 | 軽 | `local_tests.rs` の予算の検査、`local.rs` の `Enter`/`Leave` | 予算のテストは本体と全体に同じ上限を与えるものだけで、lambda などの入口で本体の操作数を0に戻すこと、外側の保持数を足すこと、本体の超過は出口で外側へ伝えず全体の超過だけ伝えること（Lean の `Run.enter`/`Run.leave`/`rejoin`）を確かめるテストがない。探査で4形（本体5/全体100で lambda の中だけ超過し外側の事実が残る、全体8で lambda の中で超過し外側も止まる `Whole/Operations`、本体の保持数1で `Body/Items`、全体の保持数1で `Whole/Items`）を手計算と比べ、すべて Lean と一致した（実装の誤りではなく検査の欠け） | この4形を通常のソースのテストとして加える |
| 軽2 | 軽 | `01-12-core-calculus.md` に加えた段落 | 言語仕様の部（01-spec）に、Rust の `ScopeBodyInput::analyze`・`ScopeArgument::Integer(i64)` 相当の実装の記述が増えた（AGENTS.md は 01-spec に処理系の実装方式の記述を入れないと定める。R20.1 の段落が先にあった）。同じ内容は 07-04 の対応表と 02-05 にもある | 01-12 の段落は削るか一文に縮め、02-05「Scope の必須判定の入力」へのリンクにする |
| 軽3 | 軽 | `scope/lower.rs`・`scope/local.rs` の先頭の `//!`、`ScopeState::next_id` | 二つのモジュールの `//!` に対応する設計書の章がない。公開の `next_id` に `///` がない | 章の参照と `///` を足す |
| 軽4 | 軽（R20.3 への申し送り） | `local.rs` の `analyze` の `stopped = stopped.or(run.stopped)` | 返す停止は最後の Run の状態だけで、lambda の中で本体の予算を超え出口で外側が回復した場合は `None` になる。Lean の `acceptBody` も `result.1.exceeded` だけを読むので一致するが、R20.3 が「本体のどこかで止まったか」と読むと意味がずれる | R20.3 の依頼文に「`stopped` は最後の Run の超過であり、Lean の `exceeded` と同じ意味で読む。途中で止まって回復した内側の地点は、事実のない記録として Top になる」と加える |

## 問題がなかった点

- 事実の記録: 直接の検査の Result を保存すると `absApply` の結果だけを記録し、Ok の腕はそこから由来を写して `nextId` を成功値の番号にする。射影は transfer を持たない。費用は `stepCost` と一致する。四つの入口を通常のソースで確かめてあり、規則の対象は六つの宣言に限られる。頭の分類は `identity::name_form` と同じ。`Failure.raise` の右辺と構築器の操作は計上されず、型注釈付きの束縛は計上される。
- 忘却: 別個体・別名・再包装・未知の呼び出し・`try`・パイプの右辺の結果には事実がない。lambda・lazy・handle の保護本体と各節・Fail の節・Task の action では位置を保って事実だけを消す。節の位置の順は `ClauseScope.slot` と合う。辿らない式は `analyzeExpr` の `_ => (r, [])` と一致し、記録のない出現は空の状態で読む（`factFree`）。R20.1 の再確認の申し送りを満たす。
- 合流: Save/Restore は `rejoin` と一致し、合流した値の束縛は未知になる。`RangeState` も区間解析の合流も使っていない。
- 定数と範囲: 文字列・Integer のリテラル、直接の負号付きリテラル（i64::MIN を含む）、const の直接参照の鎖だけを読む。`requestLitBound` は L40.3d の後の定義と一致し、`endpoint_pattern` は逆転した区間を未知にする。整数は `i64` のまま扱い、U+0000 の文字列の表現は持ち込んでいない。
- 独立期待値: 番号・位置・射影の列は Lean の規則から手で作ってあり、逆転区間は L40.3d の定義から未知に戻されている。不正なパスやホストを未知とする期待値は形式化の外の解析器に依り、妥当。
- 追加の修正: 登録済みの組み込みの操作（`builtin_ops`）を直接の頭に加えた。Lean の primName と一致し、利用者の操作は除いたまま。
- 規約・設計書・記録: 明示のスタックで書かれ再帰はない。本番に `unwrap`・添字・`as`・lint の免除はない。解析は本番からまだ呼ばれていない。01-06・02-05・07-04 は実装と一致し、未実装の機能を実装済みと書いていない。W-R（check.sh 自身の終了0、484.25秒）、比較器の自己検査（39件）、初回の停止と失敗の記録はそろう。

## 対応（取りまとめ）

| 指摘 | 対応 | 置き場所 |
|---|---|---|
| 軽1 | 採る。予算の枝で加える（推す案） | R20.5 |
| 軽2・軽3 | 採る | R20.3 の最初の項目 |
| 軽4 | 採る | R20.3 の依頼文 |
