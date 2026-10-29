# L00.05 の結果: 局所解析の評価関係と位置

2026-10-27。plan「作業 L00.05」を、取りまとめが用意した作業用のディレクトリ（`<wt>`、ブランチ `m013/l00.05`）で行った。担当は Claude のサブエージェントである。コミットは取りまとめが行う。並行する L00.04 の作業用のディレクトリには触れていない。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L00.05（局所解析の評価関係と位置） |
| B_WORK | `d771588c94c1f24b1a47958043451325dd35a028`（L00.03 の取り込みの後の本線） |
| 閉じた範囲 | 規則の表と一つの評価関係、表の健全性から適用の健全性を導く補題、対象の種類と既知の範囲／未知を引数に持つ抽象値、`BindingScope`・`OperationKey` を共有する局所の状態、一段・多段の健全性（模型）、必須の判定の添字と値の所属、L00.03 の値の型付けとの対応、最小例（直接の検査 → 一度の保存 → 同じ `Ok` 値 → 射影）、精度を失う境界の小例、L00.03 の申し送りの補題 |
| 未完（意図して後へ送る） | 本番の Surface の構文・型付け・脱糖への接続（L40）、被覆による狭い契約の判定（L10 の被覆の判定を使う。模型は添字だけを返す）、予算の計上（DET-08。下に候補を記した）、`ScopeState` の番号の新規性の不変条件（既存の `BindingScope.fresh_valid` を使える見込み）、`const` の直接参照（模型ではリテラルに含めた） |
| 採否 | 採用は決めていない。最終のモジュールと名前空間、`BindingScope` の置き場所は L00.08 が決める |

## 変更と接続

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Scope/InferenceExamples.lean` | 新規。名前空間 `Benitoite.Scope.InferenceExamples`。`Benitoite.Scope.SignatureExamples`（と `Domain`）と `Benitoite.Interval.RangeState` を import する |
| `formal/Benitoite.lean` | 既定の import の末尾に `import Benitoite.Scope.InferenceExamples` を一行加えた |
| `l00.05/` | 本書と生のログ |

既存の定義と定理は変えていない。設計書（01-12・02-05・07-04 など）には反映していない（採用前の候補のため）。

import の範囲: `Interval.RangeState` が import するのは `Interval.Eval`（区間解析の対象構文の評価関係）であり、その先は `Interval.Domain`・`Interval.Identity`・`Checked.Range` である。警告の解析（`Interval.Flow`・`Analyze`・`Sound`・`Budget*`）は import しない。`BindingScope` は今 `RangeState` のファイルにあるので、共有のために評価関係のモジュールまで読み込む。L00.08 または L40 で、定義を変えずに `BindingScope` を小さな共通のモジュールへ移すことを推す。

## 評価関係・抽象値・位置の設計

### 評価関係: 規則の表と一つの適用

| 部分 | 模型の定義 | 既存との関係 |
|---|---|---|
| 規則 | `ScopeRule`。`index`（型検査器が抽象の引数から選ぶ具体化の範囲）、`run`（具体化した範囲を受け取る実行時の評価。コアの δ に当たる）、`transfer`（抽象の適用）の三つの欄 | `Interval.StandardRule` に当たるが、構成子ではなくデータの項目である |
| 表 | `ScopeTable`。`apiAt : OperationKey → Option String`（出現の同定。解決済みの宣言）と `rules : String → Option ScopeRule` | `Interval.ConcreteEnv.standardAt`（`apiAt` と標準束縛の表）と同じ二段の引き方。同じ綴りの利用者の関数は `apiAt` に現れない |
| 評価関係 | `EvalScope T key rs vs v`。構成子は `apply` だけ（表が選ぶ規則の `run` が値を返す） | `Interval.EvalStandardAt` の `apply` と同じ形。`Interval.EvalStandard` のように規則ごとの構成子を持たない |
| 項目の健全性 | `RuleSound`: 抽象の引数が具体の引数に対応すれば、どの具体化の範囲で実行しても、抽象の結果が値に対応する | 規則を加えるときは項目と、この補題を一つ加える |
| 全体 | `apply_sound`: 表の健全性（`TableSound`）から適用の健全性 | 検査・射影・拡大を加えても評価関係の構成子は増えない |

検査（`checkRule k`）、条件の射影（`patternRule`。旧 `Scope.pathPattern(old)` に当たる例）、対象の射影（`valueRule`。`Scope.pathInValue` の候補）を表の項目として置いた。名前は DET-03 の未決であり、例の名前として使った。

### 抽象値

| 型 | 内容 |
|---|---|
| `Bound` | `known r`（閉じた範囲）か `unknown`。`Bound.index` は型の添字で、未知は Top |
| `Origin` | 呼び出しの同定 `key : OperationKey`、対象の種類 `kind : Kind`、`bound : Bound` |
| `ScopeFact` | `pattern r`（解析すると r になるパターンの文字列）、`result o`（一度保存した検査の Result）、`checked o successId`（同じ Result の `Ok` の成功値。番号 successId にだけ有効） |
| `AbsArg` | 規則に渡す抽象の引数。リテラル、束縛番号と事実を持つ局所の読み取り、直接の射影の値、未知 |

対応（`ScopeFact.Models`）は束縛番号と具体の値を取る。成功値の事実は、値が検査した同じパターンの文字列・対象の文字列・解析した対象を保持し、対象の種類が一致し、動的なパターンと型の添字の両方に属し、既知の範囲なら保持したパターンがその範囲に解析されることを意味する（`Origin.CheckedModels`）。`Interval` の `RangeOrigin`・`RangeLocalFact` と同じ分け方（Result の由来と成功値の由来）であり、別の型として置いた。

### 局所位置

| 部分 | 模型の定義 |
|---|---|
| 束縛番号 | `Interval.BindingScope` をそのまま使う（`ScopeState.scope`）。番号の割り当ては `BindingScope.fresh` |
| 呼び出しの同定 | `Interval.OperationKey` をそのまま使う（`Origin.key`、表の `apiAt`） |
| Scope の事実 | `ScopeState.facts`。位置ごとの `Option ScopeFact`。`RangeState.facts` と同じ形の別の成分 |
| 二つの成分 | `LocalState` が一つの `BindingScope` の上に Range の事実（`Interval.RangeLocalFact`）と Scope の事実を別々に持つ。`localState_same_scope` は両者が同じ番号を読むこと、`requiredIndex_range_independent` は必須の判定が Range の成分を読まないことを示す |
| 一段 | `Step` は `call`（標準の直接呼び出しの結果を新しい位置へ一度だけ保存）、`okArm`（Result の `Ok` の腕）、`alias`（別名）、`unknown`（未知の呼び出し・再包装・リテラルの束縛）、`join`（合流と本体の境界）。成功値の事実を作るのは `okArm` だけで、新しい位置の番号を成功値番号にする |
| 入口 | `ScopeState.empty`（ラムダ、handle の保護本体と節、Task の入口。位置と番号を残し、由来を仮定しない） |
| 必須の判定 | `ScopeState.requiredIndex`: 位置の事実が成功値で、読んだ位置の番号と成功値番号が一致するときだけ既知の範囲、それ以外は Top |

必須の判定は型検査の中で行い、Range の警告の解析の結果（`AnalysisResult` など）も Range の成分も入力に取らない。後段の警告の解析と同じ番号を使っても、型の受理の条件は Scope の成分だけで決まる（判断 9 の「後段の区間警告の解析結果を、先行する型の受理条件へ流用しない」）。

## 最小例

`minimalSteps` は次の文の並びを写す（位置 0 が引数 `raw`、入口は `ScopeState.empty ⟨[0], 1⟩`）。

1. `let r = Scope.checkPathIn(pattern: "/data/**", path: raw)`: 直接の検査。結果を一度保存する。事実は `result ⟨keyCheck, path, known /data/**⟩`。
2. `case Result.Ok(p)`: 同じ `Ok` 値。事実は `checked ⟨keyCheck, path, known /data/**⟩ 2`（番号 2 は新しい位置の番号）。必須の判定は `/data/**` の添字を付ける。
3. `Scope.checkPathIn(pattern: Scope.pathPattern(p), path: Scope.pathInValue(p))`: 同じ成功値の直接の射影で得た条件を渡す再検査。射影は読んだ位置の番号と成功値番号を再照合する。新しい検査は残る（判断 7）。
4. `case Result.Ok(q)`: 事実は `checked ⟨keyCheck2, path, known /data/**⟩ 4`。

`#guard` で各段の事実と必須の判定の添字を確かめた（元の `raw` は Top のまま）。`minimal_sound` は、任意の具体の評価について抽象の結果が局所に対応すること、`minimal_checked` は最後の位置の値が `/data/**` に属する対象を保持すること（同じ値と条件の対応）を示す。どちらも一般の `steps_sound` と `requiredIndex_sound` を小例に当てたものであり、本番の解析全体の健全性ではない。

## 精度を失う境界

| 境界 | 模型の扱い | 確かめ |
|---|---|---|
| 未知のパターン（局所の文字列） | `patternBound` が `unknown`、添字は Top。δ は動的なパターンだけを実質に確かめる | `#guard` |
| 射影の結果を局所に保存してから渡す | 既知にしない（局所の束縛の一般的な定数伝播をしない。判断 7） | `#guard` |
| 別名 `let q = p` | 新しい位置は由来を持たない | `#guard` |
| 再包装・別個体（未知の値の `Ok` の腕） | 由来を持たない。同じリテラルの二つの検査も `OperationKey` が違うので由来を合成しない | `#guard` |
| 合流・本体の境界・予算の超過 | `forgetAll`。位置を保ち全ての由来を忘れる | `#guard`、`forgetAll_models` |
| ラムダ・handle・Task の入口 | `ScopeState.empty` | `empty_models` |
| 同じ綴りの利用者の関数 | 出現が同定されないので由来を作らない | `#guard`、`evalScope_unidentified` |
| 番号の食い違い | 成功値番号と読んだ位置の番号が違えば Top（再照合） | `#guard` |
| Result そのもの（`Ok` の腕の前） | 添字を付けない | `#guard` |

保存は一度だけを模型に写した。`call` の結果を保存した位置を別名で読むと由来は残らない。`RangeState.forget` は位置の列を空にするが、本模型の `forgetAll` は位置の数を保って事実だけを消す。どちらを採るかは予算の計上（忘却の費用）と合わせて決める。

## 予算の計上の候補と DET-08 の問い

模型は予算を持たない。超過のときに Top を返すことの健全性は `forgetAll_models`（どの具体の局所にも対応する）から自明である。狭い契約に要る位置なら、包含未確認として拒否する（判断 9。理由の表現は DET-05）。

計上点の候補（本模型の一段に対応させた）:

| 操作・保持 | 候補 |
|---|---|
| 出現の同定と表の参照（`ruleAt`） | 呼び出しごとに 1 操作 |
| 局所の読み取り（`readLocal`）と直接の射影の適用 | 引数ごとに 1 操作、射影の適用に 1 操作 |
| 事実の書き込み（`extend`）、`Ok` の腕の由来の写し、再照合 | 各 1 操作 |
| 忘却（`forgetAll`・入口の `empty`） | 位置の数に比例させるか、世代の番号を進める 1 操作にするか（表現により費用の形が変わる） |
| 保持項目 | 事実を持つ位置ごとに 1 項目とするか、Range のように未知の位置も 1 項目と数えるか。由来（`Origin`）を事実に含めるか、Range の `rangeOrigin` のように別の項目にするか |

DET-08 で設計者に尋ねる問いの案:

1. Scope の必須の判定の予算を、Range の警告の解析の予算（`Interval.Budget` の本体・全体の状態）と分けるか。推す案は分けることである。共有すると、一方の消費が他方の打ち切りを変え、警告の解析の変更が型の受理を変えうる（またはその逆）。
2. 上の計上点と保持の数え方をどれにするか。
3. 本体・全体の上限値をどうするか。Range の 100,000・1,000,000 を根拠なく流用しない（DET-08 の境界）。値の根拠となる測定はまだない。
4. 超過の理由を、既存の `Budget.LimitFailure`（本体か全体か、操作数か保持数か）と同じ欄を持つ形にするか、DET-05 の `budgetExceeded` 一語にするか。
5. 忘却の費用を位置の数に比例させるか、定数にするか（上の表の忘却の行）。

## L00.03 の申し送りの判定の案

### 申し送り 1: 検査の δ の二重の確かめと局所解析の接続

L00.03 の `checkPathDelta` は、具体化した R と動的なパターンの両方への所属を確かめる。本作業で示したこと:

- `checkRun_ok_mem`: δ が `Ok` を返せば、対象は具体化した R に属する。型の添字への所属は δ の確かめだけから従い、局所解析の正しさを使わない。
- `checkRule_sound`: 局所解析の健全性も、どの具体化の範囲で実行したかによらない（`RuleSound` が範囲を全称で量化する）。既知の範囲の所属は、動的なパターンがリテラルと同じ解析結果になることから従う。
- `checkRun_known_redundant`・`checkPathDelta_known_redundant`: パターンが既知の範囲 r に解析されるなら、r での確かめは Top での確かめと同じ結果になる。局所解析が正しいとき、R の確かめは冗長で振る舞いを変えない。
- `checkRule_index_agrees`: 型検査器がコアへ渡す範囲（規則の `index`）は、抽象の結果の由来の添字と同じである。

判定の案（決定しない。L00.08 で尋ねる）:

| 案 | δ の確かめ | 型の保存が要るもの | 帰結 |
|---|---|---|---|
| A | 動的なパターンと具体化した R の両方（L00.03 の模型と同じ） | δ の確かめだけ（`delta_typed` の項目の条件） | 局所解析の正しさは、R の確かめが冗長であること（振る舞いを変えないこと）にだけ使う。局所解析を誤っても、型の所属は崩れず、失敗が増えるだけである。コアの保存定理へ局所解析の健全性を持ち込まない |
| B | 動的なパターンだけ | パターンの文字列が R に解析されること（局所解析の正しさ） | 保存定理の項目の条件が L40 の局所解析の健全性に依存する |
| C | 具体化した R だけ | δ の確かめだけ | 局所解析を誤ると動的なパターンを無視し、振る舞いが変わる。冗長性の補題が振る舞いの一致の根拠に要る |

推す案は A である。型の所属と局所解析の健全性を分け、必須の判定の誤りが型の健全性へ波及しない。費用は一回の追加の所属の判定である。

局所解析の接続の案: L40 では、Surface の型付けが付ける `PathIn[R]` の R、脱糖がコアの署名へ渡す R、規則の `index` が同じであることを示す（本模型の `checkRule_index_agrees` と `checked_hasTypeV` に当たる部分）。未知のパターンでは R = Top で、案 A の δ は動的なパターンだけを実質に確かめる。

### 申し送り 2: 範囲の変数の表し方

成功値の型を `.opaque name (.fixed o.bound.index)` で表した（`checked_hasTypeV`）。局所解析が型へ渡す添字は閉じた範囲なので、`Ix.rvar` を型に置く案と表の項目を関数として持つ案のどちらでも同じ形で接続できる見込みである。選択は L00.08 の格納方式と合わせて決める。

## 定義と小補題の一覧

### 定義

| 名前 | 内容 |
|---|---|
| `Key` | `Interval.OperationKey` の別名 |
| `CVal`・`Parsers` | 比較用の具体の値（検査した同じ文字列を保持する範囲付きの値を含む）、パターンと対象の文字列の解析（形式化の外側。任意の関数として量化） |
| `Bound`・`Bound.index`・`Origin`・`ScopeFact` | 抽象値 |
| `Origin.CheckedModels`・`Origin.ResultModels`・`ScopeFact.Models` | 事実と値の対応 |
| `AbsArg`・`AbsArg.Models`・`ArgsModel` | 抽象の引数と対応 |
| `ScopeRule`・`RuleSound`・`ScopeTable`・`ScopeTable.ruleAt`・`TableSound` | 規則の表と健全性 |
| `EvalScope`・`absApply` | 一つの評価関係と抽象の適用 |
| `checkRun`・`patternBound`・`checkIndex`・`checkTransfer`・`checkRule` | 検査の規則（種類 k で一般化） |
| `patternRun`・`patternTransfer`・`patternRule`・`valueRule` | 射影の規則 |
| `ScopeState`・`Locals`・`ScopeState.Models`・`empty`・`extend`・`forgetAll`・`readLocal` | 局所の状態 |
| `Arg`・`absArg`・`EvalArg`・`EvalArgs`・`Step`・`StepEval`・`absStep`・`StepsEval`・`absSteps` | 一段・多段の具体と抽象 |
| `ScopeState.requiredIndex` | 必須の判定の添字 |
| `CVal.toSig` | L00.03 の模型の値への写し |
| `LocalState`・`toScope`・`toRange` | Range と Scope の成分を分けた局所の状態 |
| 例 | `dataTree`・`toyParsers`・`keyCheck`・`keyCheck2`・`keyPattern`・`keyValue`・`keyUser`・`toyTable`・`entry`・`minimalSteps` |

### 証明した定理（25件）

| 群 | 定理 |
|---|---|
| 評価関係と表 | `evalScope_unidentified`、`apply_sound` |
| 検査の規則 | `patternBound_sound`、`checkRun_some`、`checkRule_sound`、`checkRule_index_agrees` |
| 射影の規則 | `patternRule_sound`、`valueRule_sound` |
| 局所の状態 | `ScopeState.empty_models`、`ScopeState.forgetAll_models`、`readLocal_models`、`absArgs_models`、`extend_models` |
| 一段・多段 | `step_sound`、`steps_sound` |
| 必須の判定と同じ値 | `requiredIndex_sound`、`checked_hasTypeV`、`requiredIndex_range_independent`、`localState_same_scope` |
| L00.03 の申し送り | `checkRun_known_redundant`、`checkRun_ok_mem`、`checkPathDelta_known_redundant` |
| 小例 | `toyTable_sound`、`minimal_sound`、`minimal_checked` |

具体の確かめは `#guard` 14件（コンパイルした判定の評価）で書いた。最小例の各段の事実と添字が6件、精度を失う境界が8件である。`minimal_checked` は、4段の小さい抽象の計算の結果（添字が `/data/**` であること、Top でないこと）を `decide` で二度確かめる。大きな計算をカーネルへ展開していない。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 局所の単一ファイル（途中、9回） | `cd <wt>/formal && lake env lean -M 12288 Benitoite/Scope/InferenceExamples.lean`（一部を `/usr/bin/time -l` で包んだ） | 1・2・3・6回目が 1（下の「失敗と修正」）、ほかは 0。最後の2回は警告もなし | 各 2.0〜2.2 秒 | 本書 |
| 全体のビルド | `cd <wt>/formal && /usr/bin/time -l <repo>/work/m013/lake-build-locked.sh <ログ>` | 0。415ジョブ、`Built Benitoite.Scope.InferenceExamples (2.4s)`、sorry なし。ログの警告は既存のファイル（`Interval/Flow.lean` など）のものだけ | 3.60 秒（ビルド済みの生成物の上） | [lake-build.log](lake-build.log)、[lake-build-time.txt](lake-build-time.txt) |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base d771588c94c1f24b1a47958043451325dd35a028 --dry-run` | 0。選択は `formal_build`（`formal/Benitoite.lean` の変更による。sorry の宣言を拒否する）だけ。本書を加えた後（変更9件）も同じ選択 | 数秒 | [work-check-dry-run.log](work-check-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base d771588c94c1f24b1a47958043451325dd35a028` | 0。`formal_build` が通り `selected checks passed` | 0.23 秒（ビルド済み） | [work-check.log](work-check.log) |
| 公理の依存 | `cd <wt>/formal && lake env lean -M 12288 <一時ファイル>/axioms.lean`（定理25件と主な定義9件の `#print axioms`） | 0 | 0.30 秒 | [axioms.lean](axioms.lean)・[axioms.log](axioms.log) |

公理: 34件とも `propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依存する（依存なし 2件、`propext` だけ 18件、`propext`・`Quot.sound` 14件）。`Classical.choice`・`sorryAx`・独自の公理はない。

Rust の検査は選ばれず、追加もしていない（Lean だけの枝）。

## 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size` の原値（バイト）。一度に一つの Lean のプロセスだけを走らせた。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 全体のビルド（排他の道具。ビルド済みの生成物の上で新しいモジュールだけを作った） | 1508737024 | 1438.8 | 1.41 |
| work の検査（ビルド済み） | 68911104 | 65.7 | 0.06 |
| 局所の単一ファイル（計時した回の最大、1回目） | 995344384 | 949.2 | 0.93 |
| 公理の確かめ | 708542464 | 675.7 | 0.66 |

`-M 12288` は変えていない。work の値は、`formal_build` の `lake build` がビルド済みで新しく作るものがなかったときの値である。

## 失敗と修正

- 1回目（終了1）: 原因は四つ。(1) `local`・`opaque`・`scoped` が Lean の予約語で、`cases … with` の選択肢と構造体の欄に書けなかった。(2) `checkRule_sound` の `match` が具体の値の構成子の形を解決できなかった。(3) `if_congr` が今の Lean にない。(4) 冗長性の補題で `split` が束縛した名前を取り違えた。
- 2回目（終了1）: (1) の名前の置き換えに BSD の `sed` の `\b` を使い、置き換わっていなかった。`perl` で `local` を `loc`、`Step.opaque` を `unknown`、欄 `scoped` を `scopeFacts` に改めた。(2) は補題 `checkRun_some` を置いて書き直し、必須の判定は入れ子の `match` に改めて `cases` で証明した。
- 3回目（終了1）: 同じく名前の置き換えの漏れ。4・5回目は終了0だが、`if_pos`・`if_neg`・`ite_cond_eq_*` の非推奨の警告が出たので、`ite_eq_left`・`ite_eq_right` に改めた。
- 6回目（終了1）: `rw [ite_eq_right …]` が、簡約していない `match` の中の `if` を見つけられなかった。`simp only` に戻して7回目で警告なしの終了0。8回目は終了状態の確認、9回目は `checkRule_index_agrees` を加えた後の再検査（終了0）である。
- 全体のビルド・公理・work は、最後の状態で一度ずつ走らせた。

## ずれと申し送り

計画からのずれはない。依頼文の触るファイルの候補のうち `Surface/ScopeState.lean` は作らず、`Scope/InferenceExamples.lean` に置いた。

L00.06（Top の互換と変更の母集団）への申し送り:

1. 未知は `Bound.unknown`、添字は Top である。旧の Scope の成功値（`CheckedPath` など）から新しい型へ無検査に読み替える経路は本模型にない（判断 7）。
2. `LocalState` は既存の `RangeState` を変えずに並べた形であり、本番で既存の `RangeState` の欄へ Scope の成分を足す場合は、`RangeState` を使う既存の証明が変更の母集団に入る。

L00.07・L00.08 への申し送り:

- 評価関係を規則の表と一つの `apply` にする形（`EvalScope`・`apply_sound`）。現行の `Interval.EvalStandard` は変えない。
- `BindingScope` を小さな共通のモジュールへ移すこと（定義は変えない）。今は共有のために `Interval.Eval` まで import する。
- 申し送り 1 の判定の案 A〜C と補題 `checkRun_ok_mem`・`checkRun_known_redundant`・`checkPathDelta_known_redundant`・`checkRule_index_agrees`。
- 射影の結果を局所に保存してから渡す場合を既知にしない扱い（判断 7 の「局所 bind の一般的な定数伝播を加えない」を、射影の結果にも当てはめた）。直接の引数だけを認める読み方でよいかを確かめる。
- DET-08 の問いの案 1〜5。
- 忘却の表し方（`RangeState.forget` のように位置を空にするか、本模型の `forgetAll` のように位置を保つか）。

L40 への申し送り: Surface の構文から `Step` への対応、`const` の直接参照の扱い、被覆による狭い契約の判定、`ScopeState` の番号の新規性の不変条件は、本模型では扱っていない。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 開始 | 19:09（JST） |
| 終了 | 19:24（本書の作成まで） |
| 外側の所要 | 約15分 |
| 能動時間 | 約14分（読む約5分、模型と証明約5分、本書約4分） |
| 検査 | 全体のビルド 3.60 秒、work 0.23 秒、局所と公理 計約20秒。排他の道具の待ちは0秒 |
| 見込みとの比較 | 見込み 30〜60分に収まった。上端の2倍（120分）を超えていない |
