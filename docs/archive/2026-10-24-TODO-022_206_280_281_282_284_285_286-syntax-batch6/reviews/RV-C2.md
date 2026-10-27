# RV-C2: 区切り C2 の定義・言明・仮定のレビュー

- 日付: 2026-10-25
- 担当: Claude Code のサブエージェント（Opus 5.5、取りまとめが依頼）
- 対象: コミット `074c9d3c` を取り出した別の作業ディレクトリ。`formal/Benitoite/Interval/` の全43ファイル、`formal/Benitoite.lean`、`formal/lakefile.toml`。設計書は 01-12 の区間解析の節と 07-04。差分の基準は L13 の基準 `a6350374`。
- 照合した文書: plan.md の「前提と依存」「受け渡す契約」「Surfaceの全構成子の分類」「全L作業の停止条件」、L13〜L17・A13〜A15 の節、「計画の変更（2026-10-25、L16 の区切りを受けて）」。decisions.md の D2・D5・D8・D8a・D15・D16・D16 の追記・D20。README.md の設計者の決定。reviews/RV-C1.md・RV-C1-response.md・RV-C1R.md。l13〜l17 の results.md。言語仕様は 01-04 の「Integer」の節と幅付き整数の節、01-02 のパターンの制約（`Surface/CheckPatterns.lean`）。
- 方法: 読み取り、`git diff`・`git show`・grep による照合だけで行った。中心命題・`Reached`・`Models`・`WarningLocated` の本文を基準と抜き出して比べ（md5 が一致）、01-12・07-04 に追加した識別子338件が Lean に実在することを確かめ、証明の穴・公理・特殊な指定の有無と差分のファイルの範囲を確かめた。作業ディレクトリに `.lake` がないため `lake build` と `lake env lean` は実行していない。既定ビルドの成功、sorry がないこと、`#print axioms` の結果は l16〜l17 の results.md の記録に依った。

## 所見の要約

| 区分 | 件数 |
|---|---:|
| 重大 | 0 |
| 中 | 1 |
| 軽 | 5 |

判定: 条件付き受け入れ。

中心の二命題の本文は基準から変わっていない。`Reached`・`Models`・`WarningLocated` の本文、予算付きの入口 `analyze`・`analyzeExpr`・`analyzeBody`・`Parameters`、`BudgetBody`・`BudgetWhole` も同じである。`analyze_normal_sound`・`analyze_warning_sound`・`analyze_warning_located`・`analyzeBody_*`・`analyzeExpr_independent_sound`・`analyzeBody_independent_sound` は、上限・初期消費・深さを全称量化したまま、新しい前提を加えていない。公理、`Builtins.Assumptions`、旧主定理にも変更はない。評価関係の新しい規則は 01-04 の整数の規則と一致し、`Unmodeled` と具体規則は重ならず、規則のない形も残っていない。

ただし、C2 で Lean が接続した範囲が、処理系の作業 A13〜A15 の割り当てと計画の分類表に反映されていない（中1）。A13 の着手前に直すことを受け入れの条件とする。D15 の停止条件には当たらない。

## 中

### 中1 A13〜A15 の割り当てと計画の分類表が、C2 で Lean が接続した範囲に追いついていない（読めば確定）

- 場所: plan.md「Surfaceの全構成子の分類」の「C2で追加」の行、作業群 A13・A14・A15 の手順と枝の表、「計画の変更（2026-10-25、L16 の区切りを受けて）」、01-12「区間解析の独立入力の保存と保証」の振り分け表の「neg・tryResult・tryOption・resume」の行。
- 問題:
  - (a) 分類表は「現在のnegはオペランドを独立解析し、親はTopとする」と書く。現在の Lean の `BudgetAnalyze.expr` は、`negModeled`（符号付き四種）の負号の子を同じ共有状態で解析し、`negOwnTyped` で親の候補列へ保存する。`binarySupported` は七種の加算・減算・乗算・整数除算・剰余・六比較へ広がった。独立入力に残るのは、符号付き四種以外の neg と、対象外の二項演算だけである。
  - (b) L16b2・L16c は、六幅の定数比較の認定・絞り込み・短絡の条件環境（`comparisonKindAt`・`refineKindEnv`、予算付きでは `BudgetEnvironment` の根の一回の分類と `constantKind` の計上）、種類付きの局所位置（`AbstractSlot.integerKind`）とその bind/shadow・捕捉の忘却・合流、六幅の match の腕（`matchKind` の認定、`armListKind`、`BudgetScan.armKind` の計上、未認定のときの skip と未対応の記録）を加えた。A13〜A15 の手順と完了条件はこれらを挙げていない。
  - X02 は操作数・保持数・停止位置・分類を厳密に比較し、全結果が Top であるだけの一致を受け入れない。A11 の固定表の36形は幅付きの入力を含まないので、固定表ではこの欠けを検出できない。
- 修正案: 分類表の「C2で追加」の行を C2 の後の状態に直す。A13〜A15 の枝の表（必要なら枝を足す）に、種類付きの局所位置と条件環境の合流、六幅の比較の認定・絞り込みとその計上、六幅の match の腕を割り当てる。完了条件に、`BudgetEnvironment`・`BudgetPatterns` と同じ回数の計上と、作り直す固定表に幅付きの比較・match・負号・定数倍の形を加えることを入れる。01-12 の振り分け表の neg の行は「符号付き四種以外の neg」とする。
- 時期: A13 の前。

## 軽

### 軽1 07-04 の一文が、六幅の match の腕を接続の範囲外と読める（読めば確定）

07-04 265行の末尾の文（「残る六幅の match の腕の解析と、Rust・VM への接続は含まない」）は L16c の前の状態のままである。01-12 と 07-04 の128行・418行は接続済みと書く。「六幅の match の腕は 01-12「区間解析のIntegerパターンと腕入口」に写す。Rust・VM への接続は含まない」と改める。時期: A15 まで。

### 軽2 01-12 の見出しが「Integer64」のまま、七種を扱う内容になっている（読めば確定）

「区間解析のInteger64加算」「区間解析のInteger64の減算・乗算・一般の負号の接続」「区間解析のInteger64除算と剰余」「区間解析のIntegerパターンと腕入口」。07-04 が見出し名で参照しており、アンカーを保つために改名しなかったと読める。U02 で `git grep` で参照を探し、同じ変更で改名する。時期: 後でよい（U02）。

### 軽3 未対応の二項演算を独立入力にする経路の例が、型の合わない入力に置き換わり、固定表からもこの経路が消える（読めば確定）

`BudgetChildrenExamples.lean` 45行と `SyntacticReachExamples.lean` 29行は、乗算の接続に伴い「未対応の二項演算」の例を Integer の子を持つ Float の `/` に置き換えた（型検査を通らない入力）。A11 の固定表の `unsupported` 形も接続の後は親での直接解析になり、作り直すと「左右を独立入力にする」経路を持つ形がなくなる。型の合う未対応の二項演算（Boolean の `=` の左右に整数の比較や除算を置く形、Byte の比較など）を例と固定表に置く。時期: A15 まで（固定表を作り直す枝と同じ変更）。

### 軽4 言明の文字列の一致と、意味が変わらないことを区別した記録がない（読めば確定）

l13〜l17 の確認は、中心命題と既存定理の言明を文字列で比べている。言明が参照する `EvalPartial`・`Unmodeled`・`matchOther*` の除外条件・`ConcreteValue`・`targetOperationAt`・`concreteRule`・`AbstractSlot`・`topSlot`・`SlotModels` は C2 で変わった。本レビューでは、変更が未知の規則を言語仕様どおりの具体規則へ置き換える向きであること、`Models` が強まっていないこと（`SlotModels` の既存の場合は不変で新しい場合を足しただけ）、`targetOperationAt`・`concreteRule` の拡大が新しく事象を作る形の集合と一致することを確かめた。C2 の受け入れの記録に、言明が依存する定義の変更点とその向きの一覧を残し、後の区切りの自己点検に「言明が参照する定義の差分」を確かめる手順を入れる。時期: 後でよい（C3 の区切りまでに手順へ入れる）。

### 軽5 D2 の「matchのリテラル・範囲・guard」が、六幅では束縛・ワイルドカード・guard に限られることが判断の記録にない（読めば確定）

言語仕様は六幅の定数・範囲パターンを許さないので、C2 は六幅の腕を `widthPatternMatch`（束縛・ワイルドカード）と guard だけで接続した。D2 は七種すべてについてリテラル・範囲のパターンを扱うと読める。D2 に一文を加える。時期: A13 の前。

## 確かめて問題がなかった観点

1. 言明と仮定: 中心の二命題、`Reached`・`Models`・`WarningLocated`、予算付きの入口の本文が基準と一致し、`BudgetBody`・`BudgetWhole`・`Budget`・`BudgetWalk` に差分はない。`analysis_savesInputs`・`analysis_located`・`analysis_within` は `_kind` 版を一般化して証明し、旧言明を Integer64 の特殊化として導く。新しい補助定理の仮定は内部に閉じ、入口の定理の前提には入っていない。formal の差分は `Interval/` の27ファイルだけで、旧主定理・Core・Release・Surface・`Builtins.Assumptions`・`Benitoite.lean`・`lakefile.toml` は不変。`axiom`・sorry・`admit`・`native_decide`・`implemented_by`・`extern`・`unsafe`・`partial def`・`opaque` はない。新しい `maxHeartbeats` の指定は Sound.lean の一か所だけ。`topSlot_models`・`forgetSlot_models` により前提を満たせる条件も保たれる。
2. 評価関係: `IntKind.checkedAdd`・`checkedSub`・`checkedMul`・`checkedNeg`（`kind.min < 0` の証拠で符号付き四種に限る）・`checkedDivMod`（0 を先に拒否、商は `tdiv`、剰余は `tmod`、最小値の `div -1` はあふれ、`mod -1` は 0）は 01-04 と一致する。符号なしの負の差はあふれで周回しない。左から評価し、正常な引数を得た位置だけに事象を作る。Byte は対象外で `Unmodeled`、Integer の別名は `IntKind.integer64` 一つ、値域外の幅付きの葉と符号なしの負号は `Unmodeled`。`Unmodeled` と具体規則は重ならず（`not64`、`matchOther*` の除外、`concreteRule_known`・`unsupported_trace_empty`・`unknown_analysis_sound`）、外した形はすべて具体規則を持つ。
3. 空虚さ: `targetOperationAt` と `concreteRule` の拡大は `Unmodeled` から外した形とちょうど一致する。未知の neg・未対応の二項演算の内側は親の構文的な到達可能性から除き、独立入力として保証する。L17 の最後の例は七種それぞれについて `evalClosed` から `EvalPartial` の導出を作り任意の `Parameters` の `analyze_normal_sound` へ渡す。
4. 抽象解析: 定数倍の端点の交換、両辺が複数値なら Top、商・剰余の結果を伝播しない、`x-x` の相関を使わない、部分的なあふれを警告しない、六幅の match は束縛・ワイルドカードだけを照合し `integerKindPatternRange` は Top、未認定なら腕を辿るだけで未対応を記録、比較の絞り込みは同じ幅の局所位置と定数に限り逆向きに伝えない。
5. 01-12 と 07-04: 追加箇所の写しは Lean と一致し、追加した識別子はすべて実在する。Rust とホストの幅は証明の対象外と明記されている。
6. 独立例: 新しい表はすべて `decide +kernel` で実際の入口を計算し、期待値は十進の値と手で数えた番号で固定している。期待を緩めた例や削除した例はない。
7. 予算の計上: 乗算と負号が直接の解析へ移り独立入力の枠がなくなったことは D16 とその追記に矛盾しない。新しいコードに計上されない走査はない。
