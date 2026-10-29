# RV-L40.3c: 検査済みの要求の値がレコードの閉じた値を保持する形の独立レビュー

2026-10-29。対象は L40.3c の未コミットの差分（`formal/`・01-12・07-04）と `l40.3c/` の results.md・記録。差分の読解、`git grep`、担当の記録（`builds/`・`axioms.log`・`python-tests.log`・`work-check.log`・`trial/`）で判断し、`lake build` と単一ファイルの検査は走らせていない。

結論: 取り込んでよい。重大0・中1・軽7。中1 は R20.0b・K10.1 への申し送りの追加で足り、Lean の変更を差し戻す理由にはならない。

## 指摘

| 番号 | 重さ | 箇所 | 問題 | 修正案 |
|---|---|---|---|---|
| 中1 | 中 | `l40.3c/results.md` の「Rust が合わせるべき点」、`Exchange/Builtins.lean` の `readBuiltins` | `readBuiltins` は `valContents` の内容が Release の型へ変換できることしか確かめず、(a) 内容のデータ型の名前が同じ入力の `dataDecls` に宣言されていること、(b) 内容の型が `Http.checkRequestIn` の第4引数・`Http.requestInValue` の戻り値と同じ型であることを照合しない。Rust は `data:N` の名前で書くので、R20.0b で番号を取り違えても気付く経路がない（RV-R10.7 中1 と同じ種類の危険）。また `ModelHttp` には `Http.widenRequestIn` の δ がなく、拡大が保持したレコードを作り直さないことは Lean で示されず、Rust の項目にも書かれていない | 9番目の項目を加える（内容の型は `dataDecls` の `Http.ClientRequest` の `data:N` と同じ名前で書き、二つの署名の型と一致させる。`Http.widenRequestIn` は保持したレコードと endpoint を変えない）。K10.1 で読者に (a)・(b) の照合を加えるかを取りまとめの判断事項として残す |
| 軽1 | 軽 | 07-04 の「`Http.ClientRequest` のレコードの値はこの形である」、`ModelHttp.lean` の冒頭の説明、申し送りの4 | `groundVal` が `Http.ClientRequest` のどの値でも成り立つことを、Lean で示していないのに事実として書く（読解では真） | 「Lean では示していない（標準形の補題は後の課題）」と添える |
| 軽2 | 軽 | results の系の節、`arbitrary_program_transfer_fails`、`checkedReq_not_typed_empty` | 反例は「`Pr'` での型付けから任意の `Pr` での型付けを得る」含意を否定するもので、旧の系全体を否定した実例ではない（結論は妥当） | 「変更前の言明は偽である」を「系の中心の含意（プログラムを取り替える型付けの移送）は偽である」に弱める |
| 軽3 | 軽 | 01-12 の「検査済みの値の葉の規則（V-Checked・V-CheckedRequest の所属）」「値の葉の規則 V-Checked（…V-CheckedRequest）」、`Surface/ScopeState.lean` の docstring 2箇所 | V-CheckedRequest は部分の導出を持つ規則になり、葉の規則ではない | 「規則 V-Checked・V-CheckedRequest」に直す |
| 軽4 | 軽 | 07-04 の重複文と `Http.requestInValue` の行 | 「主定理の言明の字面と `Builtins.Assumptions` の欄は、この変更でも変えていない。」の二文後に「主定理の言明の字面は変えていない。」が重なる。射影が既定のレコードを返す場合に、`groundVal` を満たさない要求を保持する値が抜けている | 重複文を消し、「型の変数を含む要求を保持する値（検査の δ は作らない）」を加える |
| 軽5 | 軽 | `Release/Syntax.lean` の `checkedRequest` の docstring、01-12 の値の説明 | docstring は保持する要求を「型の変数を含まない値」とするが規則はこれを強制しない。01-12 は「空の型の文脈と値の文脈で型を持つ通常の値」とするが、規則は同じストアの型付けと空の NoFail の文脈も求める | docstring を「閉じた文脈で型を持つ値。型の変数を含まないことは規則の前提ではなく、実例の表の検査の δ が `groundVal` で保証する」とし、01-12 の説明から「型付け規則」の注を参照する |
| 軽6 | 軽 | `formal/tests/test_range_exchange.py` の内容を `"104:[]"` にした入力 | 終了2は JSON の別の理由でも出るので、文字列の内容を型として読めずに拒否したとは確かめられない | 他の拒否の検査と同じく誤りの文言を `assertIn` で確かめる |
| 軽7 | 軽 | 同ファイルの `SUMMARIES` の前のコメント | 「等値は常に導出でき、鍵は導出できない」は `always` の意味を逆に書いている（`satisfiesB` は `!s.eq.always` を要求するので `always = true` は「常に導出できない」）。値は正しい | 「不透明型の欄を持つので等値は常に導出できない（鍵も等値を要するので導出できない）」に直す |

## 問題がなかった点

- 定義: `Val.checkedRequest t (req : Val)`、`valContent : OpaqueName → Option Ty`、V-CheckedRequest の前提（同じ Ψ、`Qempty`・`[]`・`[]` で `valContent o` の型）は意図を正しく表す。空の値の文脈は自由な値の変数を排除し、空の型の文脈は型の代入が中へ下りないことと整合し、内容の型は表のデータなので閉じている。実行時に検査の δ へ渡る要求は `delta_typed` で同じ閉じた文脈で型付くので強すぎず、型の変数が残りうる点は δ の結果の側で `groundVal` が抑えるので弱すぎない。`clientRequestDecl` の五つの欄は Rust の `public record ClientRequest` と型・順とも一致する。
- 言明と仮定の不変: `Release/Theorems.lean`・`Surface/Theorems.lean`・`Release/Lemmas/TargetStep.lean`・`Release/Assumptions.lean`・`Core/Assumptions.lean` の差分は空。公理は80件とも標準の三つの部分集合で `sorryAx` はない。変わったのは `Builtins.valContent` の型と V-CheckedRequest の前提だけで、前提の内容が値の型付けを通してだけ変わるという主張は正しい。
- 系の言明の変更: 同じ `Pr` と `StoreTy.Sub Ψ' Ψ` を前提にする形は妥当で、`hc.store hΨ` で証明が閉じる。利用者は互いだけ（ほかは過去の記録の `axioms.lean` だけで、Rust 側や道具にはない）。07-04 が述べる系の役割は、同じプログラムでの実行の型付けに当てる限り失われない。
- ModelHttp と閉性: `groundVal_varsIn` は構造的に正しい。`checkRun` は `groundVal` を満たす要求だけを保持し、`check_send_preserves` は射影が同じレコードを返すことを述べる。既定のレコードは検査の δ が作らない値にだけ返る。`reqTarget : Val → Option Target` の信頼の対象は 07-04 に書かれる。`read_url_steps` は有効。
- 交換: `ContentEntry` を `Exchange/Builtins.lean` へ移し内容を `Exchange.Ty` にした。変換できない内容と範囲の変数は拒否される。sidecar 7 のまま版を上げない判断は 07-04「交換の形式の版」と合う（本番の `valContents` は未接続で、K10.1 まで完成した入力と数えない）。R10.7 の合成の表の文字列の内容は Lean の手動の `builtinCheck` でしか照合しないので自動の検査は壊れない。独立入力の宣言は手で書いた値。
- 設計書: 01-12 の規則の写しと【決定】の段落は Lean と一致し、引用された定理の名前はすべて存在する。L40.3b の「不透明型の定数」を前提にした記述はほかに残っていない（軽3〜5 を除く）。
- 記録: 全体のビルド（573 ジョブ、sorry 0）、work、Python 10本、公理80件、試行7回分の記録がそろう。「Rust が合わせるべき点」の1〜8 は正しい（7 の `data:N` の名前は Rust の `data_name` と一致）。

## 対応（取りまとめ）

| 指摘 | 対応 | 置き場所 |
|---|---|---|
| 中1 | 採る。9番目の項目を results に加え、R20.0b の依頼文に入れる。K10.1 で読者に (a)・(b) の照合を加えるかは K10.1 の起動の前に取りまとめが判断する | L40.3c の担当と R20.0b・K10.1 |
| 軽1〜軽7 | 採る | L40.3c の担当（同じ枝） |
