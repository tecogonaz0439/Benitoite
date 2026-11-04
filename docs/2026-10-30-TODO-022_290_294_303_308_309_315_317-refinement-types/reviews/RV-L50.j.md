# RV-L50.j: L50 群 J（L50.46〜.50）の独立レビュー

2026-11-05。対象はブランチ `m014/l50.j` の未コミットの作業木で、基準は `eeddee69d81fc78552c2bcb61ae6f236d8563973`（HEAD と一致）である。見たものは次のとおりである。
- 本番の変更3ファイル: `git diff eeddee69 -- formal docs/design` で追加20行・削除0行。`formal/Benitoite.lean` の import 3行、01-12 の5段落、07-04 の3段落と表の1行である。既存の Lean の定義・言明の変更はない。
- 新規3モジュール: `ModelHttpConditions`（359行）・`ModelHttpApplications`（312行）・`ScopeModels`（39行）。
- `l50/j/` の記録。改造の `effort-ledger.md` の1行の追加は取りまとめの記録なので対象外とした。

読んだもの:
- 依頼と報告: 担当への依頼、担当の報告の全文。
- `l50/detail.md`: 第3節 F09、第4節の三モデルの25条件と L60 に残す欄の表・ModelHttp の署名集合と固定の reqTarget の段落、第5節の L50.46〜.50 と群 J の完了条件、照合表の ModelHttp の行。
- `l50/j/`: results.md・conditions.md・handoffs.md・obligations.md（判定の列）・contracts.lean（冒頭・ModelHttp の欄・末尾の全称の照合）・conditions.json（verify.py の照合を通して）・audit-summary.json・verification.json・build-check.json・verify.py。
- 前例: `reviews/RV-L50.i.md`（形を揃えた）・`RV-L50.h.md`。

Lean で読んだもの:
- 新規3モジュールの全文。
- 既存の `Refinement/ModelHttp.lean`（`valueRun` と埋め込み）と旧 `Release/ModelHttp.lean` の `builtins`（旧5行の照合のため）。
- 群 H の `Model.lean`（表・`builtins`）、群 I の `ModelTargets.lean`（表・`builtins`・宣言の一覧）。
- `TargetModelConditions.lean` の `ModelScopeConditions` と `ModelScopeConditions.core`。
- `ScopeSignatures.builtins`（`isResource`・`releaseResponse`・`sat` の既定）、`Syntax.lean` の `externalResponse` の既定、`ExternalResponse.lean` の `Builtins.ExternalAssumptions`。
- `ScopedIOResponse.lean` の `Payload`・`Reply`・`Operation`・`RequestSent`・`ioResponse`・`send_input`・`sendIn`・`sent_request`・`targets`。
- `RequestDelta.delta`・`RequestDelta.response`、`RequestValueDelta.lean` の `valueDelta`・`requestInValue_response`・`widenRequestIn_response`、`ScopeResponse.delta`・`widen_admitted`。
- `AtPrepare.lean` の `groundTy`・`groundVal`、`ScopeDeclarations.lean` の `result`・`pair`・`clientRequest`・`requestCheckError`・`http`・`HasHttp.file`。

git の操作（読み取りを除く）、既存のファイルの変更、`lake build`、cargo の実行はしていない。Lean の検査は `formal/` を作業ディレクトリに `lake env lean -M 12288` で行い、確かめのファイルは `<tmp>/rv-l50-j/` に置いた。`verify.py` は `verification.json` を書き換えるので実行せず、書き込みを除いた写しを一時の台本として実行した（検査4）。

## 結論

**可**（重0・中0・軽3・情報10）。

完了の判定は満たす。主な点は次のとおりである。
- `ModelHttp.scopeConditions P hp` は、`HasHttp P` の下で25欄すべてを名前の付いた定理から構成する。どの欄も True だけの模型・空の sig 表・sat=True の置換に依らない。
- 7行は detail の「旧5行に widenRequestIn・発行を足した7行」と一致し、`sig_cases` は `lookup_mem` から成功する全 lookup を7の場合へ戻す。
- 純粋3行は群 F の全 BuiltinArgs の定理へ渡り、応答の存在は型付きの引数から `retained_request` が取り出す同じ req で作る。`valueRun` の default の枝を存在の証拠に使わない。
- `io_exists` は `Reply.error 0` の実際の応答を構成し、`io_target`・`obs_allowed` は同じ `ScopedIOResponse.ioResponse` の応答を同じ σ の上限へ F05 で接続する。
- 要求なし・端点の不一致の否定は、受理側と同じ入力の形で前提が満たせる（検査3で具体の要求について確かめた）。
- 三モデル75欄の対応は実物どおりで、L60 に残す12欄は `ModelScopeConditions.core` の別の入力のまま残る。記録は閉じたと書いていない。
- 既存 `ModelHttp` へ並置せず別モジュールに置いた判断は妥当である（情報1）。

処置を勧める点は、読者のない private の定義・docstring・写しの語の3件である。どれも完了の判定を左右しない。

| # | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 軽1 | 軽 | `ModelHttpApplications.lean` 17行 `otherEndpoint` | private の定義で、ファイルの中にも外にも読者がない（`grep` で定義の行だけ）。Lean は使わない private の定義を警告しないので、ビルドでは見つからない。端点の不一致の拒否を具体値で示すつもりで置いたと見えるが、200〜212行の例は記号の `other` で書いてある | 定義を消す。具体の対照を残したいなら、検査3(c) のように `endpoint` と `otherEndpoint` で `send_held` と `send_mismatch` を並べた例に使う | 読めば確定 |
| 軽2 | 軽 | `ModelHttpApplications.lean` 214行の docstring | 「Pair の篩を groundTy が読み飛ばし」と書くが、`groundTy` の `.refined a p` の枝は `groundTy a && decide (p.WF 1)` であり、述語の WF 1 を検査する。例の前提も `hp : p.WF 1` である。読み手は、篩が無条件に無視されると読みうる | 「Pair の篩は述語が WF 1 のとき groundTy が受理し、同じ P の正しい arity と構成子を使う。」とする | 読めば確定 |
| 軽3 | 軽 | 07-04 の追加の第2段落「send_held は具体の成功・Error・err を構成し」 | `ModelHttp.send_held` は任意の `reply : Reply .http out` を受け取り、その応答について両保持形の受理を示す。成功・Error・err の値を構成する定理ではない。01-12 の側には send_held の記述がなく、齟齬は 07-04 だけにある | 「send_held は成功・Error・err の全応答について両保持形の受理を示し」とする | 読めば確定 |
| 情報1 | 情報 | 配置（計画の「既存の ModelHttp へ並置拡張」） | 既存の `Refinement/ModelHttp` は `valueRun` と埋め込みだけを持ち、`ScopedIOResponse ← EffectTargets ← ShapeTargets ← MembershipTargets ← ModelHttp` の経路で IO 応答の上流にある（一時の台本で import の経路を求めた）。表は `ScopedIOResponse.ioResponse` を使うので、同じファイルに置くと循環する。新モジュールは同じ `ModelHttp` 名前空間に置き、既存の射影と旧 `Release` を変えていない。計画の「並置拡張」は名前空間の水準で満たしており、判断は妥当である。代わりに `valueRun` を下流へ移す案は既存の読者（`ScopedIOResponse`・`RequestValueDelta`・`MembershipTargets` など）を変えるので、取らない理由がある | 不要 | 読めば確定 |
| 情報2 | 情報 | `entries`（11〜14行）・`sig_cases`（35〜43行） | 7行は参照2・checkRequestIn・requestInValue・sendIn・widenRequestIn・発行である。旧 `Release.ModelHttp.builtins` の5行（参照2・checkRequestIn・requestInValue・sendIn）に widenRequestIn と発行を足した集合と一致する。`sig_cases` は `lookup_mem` からの `simpa` で全成功 lookup を7場合へ戻す。検査3で、表の長さが7、`File.readTextIn`・`Scope.checkPathIn`・`print` が none、sendIn・widenRequestIn が共通の署名であることを確かめた | 不要 | 読めば確定、実行で確定（検査3） |
| 情報3 | 情報 | 八保存則（50〜72行）と sat の対照（353〜356行） | `builtins` は `ScopeSignatures.builtins ScopeResponse.delta` を基に `sig`・`effects`・`ioResponse` だけを置き換え、sat は共通の `ModelConstraints.sat` のままである。sat の3欄は共通表の射影、`sat_values` は `ModelConstraints.sat_values`、admits の4欄は `common_lookup` で共通表の定理へ戻す（`admits_values` は `ScopeSignatures.admits_iff_count`）。tvar 0 の非空制約の受理と空制約の拒否の対照は群 H・I と同じで、両側が意味を持つ。`set_option maxHeartbeats`・`maxRecDepth` は新規3ファイルのどこにもない | 不要 | 読めば確定 |
| 情報4 | 情報 | 純粋 δ の3行（146〜194行） | `pure_response` は7場合のうち pure でない4行を kind で除き、checkRequestIn を `RequestDelta.response`、requestInValue を `requestInValue_response`、widenRequestIn を `widenRequestIn_response` へ渡す。三つとも任意の `BuiltinArgs` を受け、型付きの唯一の引数から `retained_request` で同じ req と `Val.reqTarget` を得て `.val req` を作る。`valueRun` の default の枝（`embedVal defaultRequest`）は型付きの入力では到達せず、存在の証拠に使われない。`pure_outcome` は δ の決定性で全実結果へ型・Adequate・非 exit・Ground を渡す | 不要 | 読めば確定 |
| 情報5 | 情報 | 送信（205〜241行）と `ScopedIOResponse.sendIn` | `ioResponse` は `b = "Http.sendIn"` と群 G の `ScopedIOResponse.ioResponse` の積で、型付けを定義に含めない。`send_response` は群 G の `sendIn` に表の `valKind`・`valContent` と Response・NetworkError の定数分類を `rfl` で与える。`HasFile P` は Result の宣言を読むために要る。存在の証人は `Reply.error 0` で、正常応答の存在を前提にしない。`io_kind` は Operation の名前から op を send に定め、全 Reply で exit を除く | 不要 | 読めば確定 |
| 情報6 | 情報 | `targetAgreement`（251〜254行）・`obs_allowed`（257〜264行）・`ModelHttpApplications` 153〜198行 | `io_target` は群 G の `ScopedIOResponse.targets` に `common_lookup` を渡すだけで、仮定を足さない。`obs_allowed` は F05 の `Builtins.TargetAgreement.obs_allowed` に、実表の `io_op`・`targetAgreement`・`sig_scoped` の `namesWF`・同じ `BuiltinArgs`・同じ σ の適格性を与える。適用例は、非 Top と Top の両方、`checkedRequest` と `checkedAt` の両形で、`send_held` が作った同じ応答に `io_typed` と `obs_allowed` を適用し、観測 `endpoint` が効果の上限に入ることを示す。例の篩は `.truth` で、`V_Normal` により String へ正規化される。一般の述語は groundTy の例（215〜225行）だけが扱う | 不要 | 読めば確定 |
| 情報7 | 情報 | 受理と拒否（275〜317行、`ModelHttpApplications` 200〜212行） | `send_held` は任意の Reply、範囲、snapshot で両保持形を受理する。`send_without_request` は `RequestSent` の `form` の照合で `.checked t` と `checkedAt … none` を排除する。target? と kind の条件は満たされるので、拒否の理由は要求の欠如である。`send_mismatch` は `sent_request` の保持端点と `groundVal` から同じ req を得て、`reqTarget` の不一致で排除する。前提 `groundVal req`・`reqTarget = some t`・`t ≠ other` は検査3(c) の具体の要求と端点 443・80 で満たせ、受理と拒否の両側が同じ要求で成り立つ。拒否は前提の矛盾で空疎になっていない | 不要 | 読めば確定、実行で確定（検査3） |
| 情報8 | 情報 | 宣言と形（`ModelHttpApplications` 19〜73行、214〜225行） | `typed` は `HasHttp P` から Pair と ClientRequest の lookup を取り、5欄（String・String・List[Pair[String,String]]・Bytes・Integer）の要求を型付ける。215〜225行の例は、`groundTy` の篩付き Pair、`HasHttp program`、Pair の arity 0 の拒否、pair・clientRequest・requestCheckError の arity と全構成子の lookup を同じ P で示す。Result の arity 2 は `result_annotation`（97〜99行）が同じ `program_hasHttp` から読む | 不要 | 読めば確定 |
| 情報9 | 情報 | 三モデル75欄と L60 の12欄（`ScopeModels.lean`、conditions.md、contracts.lean、handoffs.md） | `ScopeModels.conditions` は Model に任意 P、ModelTargets に `hp.file`、ModelHttp に `hp` を渡す。conditions.md の75行の定理名は実在し、contracts.lean の75定理は各欄の完全な型を明記して `scopeConditions` の射影で証明する。12欄の注意は実物と合う: Model・ModelHttp の `isResource` は共通表の `fun _ => false` で release の前提が偽（検査3(b)）、ModelTargets は `isResource` が File.Handle を分類し `releaseResponse` が `r = none` で結論が自明、三表とも `externalResponse` は `Syntax.lean` の既定 `False` なので、外部宣言と `ExternalArgs` を満たす P では `external_exists` が成り立たない。handoffs.md は「閉じたと扱わない」と書く | L60 の担当へ申し送る | 読めば確定、実行で確定（検査3） |
| 情報10 | 情報 | 公開の入口・写し・記録 | 公開の定義・定理は全て、`scopeConditions`・ファイル内の例・`ModelHttpApplications`・`ScopeModels`・contracts.lean のどれかが読む（読者のない定義は軽1だけ）。`sourceTelRows` の読者はファイル内の例だけで、群 I と同じ形である。`ModelHttpConditions` 189〜194行と `ModelHttpApplications` 227〜233行の例は同じ言明と証明で重なる。本番のコメントに工程の ID はなく、`#eval`・`sorry`・`axiom`・`admit` もない。01-12・07-04 の写しに段名・未実装の作業・経緯の文・「旧」の語はなく、名前と前提は実物と一致する（語は軽3） | 重なる例は片方を消してよい | 読めば確定 |

## 観点ごとの根拠

### 1. 25欄が空疎でないこと

- **構成**: `scopeConditions`（328〜343行）は、`substitutionAssumptions P`・`responseAssumptions P hp`・`targetAgreement P` と表の12欄の名前の付いた定理を、欄ごとに渡す。
- **模型**: 表は7行で空でない。sat は True でない（情報3）。
- **存在**: 純粋3行は型付きの引数の同じ req から（情報4）、送信は `Reply.error 0` の実応答から（情報5）作る。δ の未定義も default の枝も使わない。
- **同じ σ**: 情報6のとおりである。

### 2. 7行と lookup の全場合

情報2・4のとおりである。純粋3行の定理は全 BuiltinArgs を量化し、固定の `Val.reqTarget` と `clientRequestTy` を使う。旧の任意の parse へは戻していない。

### 3. 宣言と形

情報8のとおりである。篩付き Pair の groundTy は、前の群の修正（述語の WF 1 を読む）と同じ定義を使う。docstring の語は軽2。

### 4. 送信の受理と拒否

情報5・7のとおりである。

### 5. 三モデル75欄と L60 の12欄

情報9のとおりである。

### 6. 入口・名前・写し

情報1・10、軽1〜3のとおりである。

### 7. 記録

検査4のとおりである。最大のファイルは contracts.lean の60,124バイトで、群の記録は488,753バイトである。手元の絶対パスは verify.py の照合の正規表現（121行）のほかに0件、docs/todo へのリンクは0件、相対リンク18件の切れは0件だった。

## 実行した検査

| # | 検査 | 結果 |
|---|---|---|
| 1 | `ModelHttpConditions.lean`・`ModelHttpApplications.lean`・`ScopeModels.lean`・`l50/j/contracts.lean` を `lake env lean -M 12288` で `-o` なしに単独で検査した。あわせて新規3ファイルの `set_option`・`sorry`・`axiom`・`admit`・`#eval` と工程の ID の語を数えた | 4件とも誤り・警告なく終了0、実時間で約7.3秒・約0.9秒・約0.7秒・約2.0秒。語は0件 |
| 2 | 一時の Python で、`ScopedIOResponse` から既存 `Refinement.ModelHttp` への import の経路を求めた | `ScopedIOResponse ← EffectTargets ← ShapeTargets ← MembershipTargets ← ModelHttp`（情報1） |
| 3 | `<tmp>/rv-l50-j/Probe.lean` で次を証明した。<br>(a) `ModelHttp.entries` の長さが7、`File.readTextIn`・`Scope.checkPathIn`・`print` の lookup が none、sendIn・widenRequestIn の lookup が共通の署名。<br>(b) Model・ModelHttp の `isResource` が全ての名前で false。<br>(c) 端点 443 の具体の要求について `groundVal`・`reqTarget`・443≠80 を示し、同じ要求で `send_held` の受理と `send_mismatch` の拒否が同時に成り立つこと。<br>(d) 全送信応答の観測の長さが1。<br>(e) `File.readTextIn` が ModelHttp の IO 関係に入らないこと。<br>あわせて `#print axioms` を `ModelHttp.scopeConditions`・`ScopeModels.conditions`・`send_mismatch`・`send_without_request`・`obs_allowed` に実行した | 全て通る。公理は全て `propext`・`Classical.choice`・`Quot.sound` の範囲内（情報2・7・9） |
| 4 | verify.py から `verification.json` への書き込みを除いた写しを `<tmp>/rv-l50-j/verify_ro.py` に作って実行した。開始と最終の入力一覧と現在の作業木、追加・変更・削除、既定 import の閉包、監査の各ハッシュと件数、宣言の写し、75欄と12欄、義務と申し送りの件数、生成物の時刻、ファイルの大きさ、絶対パスとリンクを照合する。verify.py 自身の SHA-256 も verification.json の値と比べた | 全て通り、入力1,042件・監査165宣言・追加87宣言・入力一覧のハッシュ `2a4d992d…` が verification.json と一致。verify.py のハッシュも一致 |

検査の実行は合計で約15秒だった。大きな具体値を作る評価はしていない。担当の165宣言の監査・既定ビルド・work は引用し、再実行していない。

## 取りまとめの追記

- 軽1〜3と情報10は取りまとめが直した（読者のない `otherEndpoint` と重複した例の削除、篩付き Pair の例の docstring、07-04 の send_held の文）。言明・証明の中身は変えていない。l50/j/results.md の「取りまとめによる修正」。
- 情報9は、L60 への申し送りとして l50/j/results.md に記した。そのほかの情報は処置しない。
- 群 J の作業末の work は終了0、560.87秒、最大常駐量 2,935,767,040 バイト（篩の部分の生成物を消して再ビルド。l50/j/results.md）。
