# RV-L60.c: L60 群 C（L60.10〜.13、外部応答とモデル）の独立レビュー

2026-11-05。対象はブランチ `m014/l60.c` の未コミットの作業木で、基準は `4fa52301d314e1a7cd4079e87889e485981da354`（HEAD と一致）である。見たものは次のとおりである。
- 本番の変更: `git diff 4fa52301 -- formal docs/design`（`formal/Benitoite.lean` の import 2行、`ExternalModelTransport.lean` の import 1行と定理4件、01-12 の3段落、07-04 の2段落と表の2行）と、未追跡の2モジュール（`ExternalModelExamples`・`ExternalModels`）。
- 群 C の記録: `l60/c/` の results.md・conditions.md・conditions.json・handoffs.md、台本（verify.py・axioms.lean の冒頭）、要約の記録（audit-summary.json・verification.json・readers.json・baseline.json・default-build.json・axioms.json・verify.json・verify-first-failure.json・final-records.json・宣言の分割記録）。

読んだもの:
- 依頼と報告: 群 C の依頼文（守ること・止める条件）と担当の報告。
- `l60/detail.md`: 第2.1節の外部の行、第2.4節（四分類と12欄）、F04・F05、第4節の L60.10〜.13 の行と群 C の完了条件の行、第6節の義務のうち群 C の単位を含む行（O061・O062・O063・O088）と O013・O084、第7.2節。
- `l60/a/results.md` の冒頭と「再開4」の12欄の四分類と保留、`l60/a/standard-contract.md` の該当箇所、`l60/b/handoffs.md`、`reviews/RV-L60.a.md`・`RV-L60.b.md`（前例）。
- `plan.md`: 「全 L 作業の停止条件」と「計画の変更と取りまとめへの確認点」の先頭の数項目。
- Lean の既存定義: `ExternalResponse.lean` の `ExternalArgs`・`Builtins.ExternalAssumptions`・`externalReceive`、`ExternalModelTransport.lean` の `model`・`targets`・`http` と `*_scope`・`*_core`、`BuiltinResponse.lean` と `TargetModelConditions.lean` の六空疎欄（`delta_typed`・`io_typed`・`io_kind`・`io_exists`・`io_op`・`io_target`）の前提、`TermSyntax.lean` の `Pred`。

git の書き込み操作、本書以外のファイルの変更、`lake build`、cargo の実行はしていない。Lean の検査は `formal/` で `lake env lean -M 12288` により行い、確かめのファイルは `<tmp>/rv-l60-c/` に置いた。verify.py・audit.py・run.py・inventory.py の記録を書き換える台本は実行せず、読んで判定した。全環境の公理監査は再実行していない。大きな具体値を作る評価はしていない。作業の記録（担当のログ）は、lake の起動と既定ビルドの出力の確認にだけ使った。

## 結論

**可**（重0・中0・軽4・情報4）。

証明の側に、群 C の完了を妨げる誤りは見つからなかった。主な点は次のとおりである。
- 保留6欄の確定は正しい。三モデルの `external_typed`・`external_no_targets` について、`shape_inputs`・`handle_inputs` が `Builtins.ExternalAssumptions` の欄の前提の形（`P.ExternalWF`、`P.externalFunction f = some d`、同じ `B` の `ExternalArgs`、同じ `B` の `externalResponse` への正常 val の所属）をそのまま満たす。`B` は `m.table (program s b)` であり、表の引数の P と入力の P は同じである。Targets の `HasFile P`・Http の `HasHttp P` も同じ `program s b`（又は `handleProgram b`）について供給される。`targets_core`・`http_core`・`model_core` へ直接当てて閉じることを確かめた（検査2）。
- L60.10 の4定理（`response_value`・`receive_value`・`receive_reject`・`receive_error_no_exit`）は任意の P・base・release・Ψ・入力・σ を量化する。L60.12・.13 の `ExternalModels.conditions` は任意の `ModelCase` と任意の P を量化し、Model の宣言条件は `True` で、外部宣言のない P への制限はない。25欄は群 A の `*_scope`、Core と対象条件は群 A の `*_core` を使い、作り直していない。`ExternalModelTransport.lean` の変更は import 1行と定理4件の追加だけである。
- 六正常形の深さは `Shape.list n`・`Shape.data n` の任意の n について帰納（`nested_properties`・`nested_carrier`・`nested_ground`・`nested_check`）で扱い、具体の大きな値を作らない。拒否側は実際に `externalCheck = false` となり、`receive_reject` で `ExternalRefinement` を受信する。handle は borrow の実引数・own の結果・State の効果を保つ。
- 87欄の集計（実質76・自明3・空疎8）は conditions.json の87行と一致し、新12欄の分類は detail.md 第2.4節の目標どおりである。存在3欄は定数 err の証人で閉じ、前提を読まないことを確かめた（検査2）。Model の六空疎の前提は、sig の pure/IO/exit の場合と空の ioResponse の場合に分かれ、`model_no_response_kind` と元の空の関係で偽になる（前提の形を本番の構造体で読んだ）。
- 新しい公理・`sorry`・`native_decide`・`#eval`・`maxHeartbeats`・`maxRecDepth`・工程の ID は、新しい2モジュールにも追加行にも写しにもない。公開37入口は全て名前付きの読者（35）又は既定ビルドの適用例（2）を持ち、private の補題16件は全て使われる。

軽の所見は写しの語、拒否側の篩の選び方、docstring、記録の欠けであり、証明や分類の判定を変えない。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 軽1 | 軽 | 07-04 の78行（`ExternalModels.conditions` の段落）、01-12 の3116行、両章の追加段落の後の空行 | (a) 07-04 に「外部九欄は実質六・自明三」「八十七欄は、実質七十六・自明三・空疎八」「実質に数えない」と、改造の記録の四分類と集計を書く。「実質」「自明」は 07-04・01-12・用語集のどこにも定義がなく、07-04 の他の箇所は「二十五条件」「七十五条件」と「条件」で数えるので「欄」と混ざる。87欄の最終照合は detail.md で群 E・G（L60.22・.32）の受け持ちであり、設計書の現在の性質として先に書くと、群 C の時点の集計が段末の照合済みの値に読める。01-12 の「存在の三欄は定数errによる自明な証人を保つ」も同じ語である。(b) 01-12 と 07-04 の追加段落の後に空行が二つ続く | (a) 設計書には性質だけを書く。例えば「外部三条件のうち型・非exitと無対象の条件は、型付き入力と応答の証拠から示し、存在の条件は任意のerrで示す。Modelのpure/IO/exitの条件は、sigとIO応答関係が空なので前提が成り立たない」とし、件数と四分類は conditions.md・conditions.json に残す。数え方は「条件」に揃える。(b) 空行を一つにする | 読めば確定 |
| 軽2 | 軽 | `ExternalModelExamples.filtered`、`Shape.type`・`handleType`、conditions.md「六正常形と篩拒否」、07-04 の76行「正常側と拒否側は実際に篩を検査する」 | 正常側は `refined a (.not .falsity)`、拒否側は `refined a .falsity` の定数の述語で、受理と拒否は別の宣言（`program s true` と `program s false`）で示す。拒否側の結果型は値を持たない型であり、検査は値を読まずに偽になる。入れ子の最深部まで検査が届くことは示すが、同じ宣言の篩が値によって受理と拒否に分かれることは示していない。conditions.md は「任意の述語の正常応答の存在を示すものではない」と範囲を書いており誤りではないが、07-04 の「実際に篩を検査する」は値に依存する篩を検査したと読める。値に依存する述語は短く閉じる。`.refined (.base .integer) (.lt (.integer 0) (.var 0))` について、同じ型で 1 の検査が真、0 の検査が偽になることを、本番の `nested_check` と同じ simp の集合で確かめた（検査2(6)） | 整数の形に、同じ宣言の値に依存する篩（例えば `0 < x`）で正常値 1 と拒否値 0 を示す証人を一つ足す。足さないなら、07-04 と 01-12 に「受理側は恒真、拒否側は恒偽の篩を用いる」と範囲を書く | 読めば確定、実行で確定（検査2） |
| 軽3 | 軽 | ExternalModelExamples.lean の522行 `program_hasHttp` の docstring、ExternalModels.lean の93行 `responses` の docstring、同23行 `ModelCase` の docstring | (a) `program_hasHttp` の「外部宣言と同名のdataを加えても」は、外部宣言と同じ名前の data を足すと読める。実際に足すのは入れ子にする data `ExternalBox`（同名の data を入れ子にする形）と外部関数の宣言であり、両者の名前は別である。(b) `responses` の「全入力・全σでの二十五条件と三条件」は、任意の P の全入力に読める。言明は証人の宣言（`program s b`・`handleProgram b`）の上の受信と条件であり、量化は全 Shape・Ψ・σ・identity である。(c) `ModelCase` の「範囲APIの別表と混同しない」は、型の定義の中身ではない | (a)「入れ子のdata `ExternalBox` と外部関数の宣言を加えても、範囲IOが読むHTTP宣言の欄とarityは変わらない」とする。(b)「六形の証人の宣言で、全Shape・Ψ・σ・identityの受信と同じ表の二十五条件・外部三条件を読む」とする。(c)「三モデルの区別。各場合の表は `ExternalModels.model/targets/http`」とする | 読めば確定 |
| 軽4 | 軽 | results.md「計画との差と試行の修正」「群末検査と残る手順」 | 担当は作業中に `lake env lean -M 12288 -o .lake/build/lib/lean/.../ExternalModelExamples.olean` と同じ形の `ExternalModelTransport.olean` の書き出しを計4回行い、lake が管理する生成物を lake の外から上書きした。後続のモジュールの局所検査に import を通すためと見られる。最後の既定ビルドの出力では `ExternalModelTransport`・`ExternalModelExamples`・`StandardModelResponse`・`ExternalModels`・`Benitoite` が「Built」と再ビルドされており、最終の状態は lake の生成物と一致する。ただし、この操作と理由が results.md にない | results.md の「計画との差と試行の修正」に一行足す（局所検査のための olean の書き出し、対象の2ファイル、最後の既定ビルドで lake が5モジュールを再ビルドしたこと）。次の群から、局所検査は `lake env lean` の検査だけにするか、書き出す場合は記録する | 読めば確定（作業の記録と既定ビルドの出力） |
| 情報1 | 情報 | conditions.md「三モデルの十二欄」、`ExternalModel.response` | `external_typed` と `external_no_targets` の結論は、F04 の応答関係の定義の成分（`response.2` の carrier と非exit、`response.1` の `obs = []`）を七射影で移したものである。detail.md 第2.4節の定義では、前提が充足可能で、応答の証拠を使って結論を示すので実質に当たり、判定は正しい。ただし「実質」は前提の充足可能性と証拠の使用を指し、ゲストの変換の性質を証明したことではない（07-04 の段落の最後の文がこの範囲を書いている） | なし | 読めば確定 |
| 情報2 | 情報 | `handle_raw_response`・`handleSignature` | 正常側の生の値は、borrow で受けた実引数と同じ `handle identity` を own の結果として返す。抽象の関係は所有の移転を追わないので、型付けと受信の証人としては足りる。受信を拒否した own の後始末（S14）は元の受け持ちに残る（handoffs.md のとおり） | なし | 読めば確定 |
| 情報3 | 情報 | ExternalModels.lean の9行 `model_inputs` | 言明は `raw_response s b Model.builtins` と定義上同じで、`shape_inputs` の Model の場合だけが読む。Targets・Http の場合は `raw_response` を直接使う。重複した例ではなく読者もあるので処置は要らないが、`shape_inputs` へ畳み込める | なし（畳み込むなら results.md の L60.12 の記述も合わせる） | 読めば確定 |
| 情報4 | 情報 | verify.py の conditions の照合 | 新12欄の判定は、欄の名前とモデルから期待値（存在は自明、Model・Http の解放は空疎、ほかは実質）を台本に書いて照合する。台本は記録の整合を見るもので、分類の根拠は Lean の証明と証人である。本書では証人を本番の Core へ当てて独立に確かめた（検査2） | なし | 読めば確定 |

## 観点ごとの根拠

### 1. 保留6欄・自明3欄・空疎8欄の判定

`Builtins.ExternalAssumptions` の `external_typed` と `external_no_targets` の前提は、`P.ExternalWF`、`P.externalFunction f = some d`、`ExternalArgs P B Ψ d ts vs a e`、`B.externalResponse f ts vs out obs` の四つである。`shape_inputs m s b Ψ` は、`m.Declarations (program s b)`、`(program s b).ExternalWF`、`ExternalArgs (program s b) (m.table (program s b)) Ψ (signature s b) [] [] (s.type b) Eff.empty`、`(m.table (program s b)).externalResponse ⟨0⟩ [] [] (.val (s.raw b)) []` を返す。lookup は `rfl` で閉じる。`ExternalModels.lean` の最初の `example` は、これを `conditions` の外部三条件へ `rfl` の lookup とともに当てている。本書では `targets_core (program s b) i.1`・`http_core (handleProgram b) i.1`・`model_core _` へ直接当て、Targets と Http の宣言条件が入力と同じ P のものであることを確かめた（検査2(1)〜(3)）。b = true の正常値で前提が成り立つので、「正常値で全前提を満たす入力」がある。

`external_exists` は `response_err` の定数 err で閉じ、前提を読まない（検査2(4)）。自明の判定は正しい。Model・Http の `release_exists` は `isResource = false` による空疎で、群 A の判定の継承である。Model の六空疎は、`delta_typed`（`sg.kind = .pure`）・`io_typed`・`io_exists`・`io_op`・`io_target`（`.io ∨ .exit`）の5欄が sig の場合、`io_kind` が `B.ioResponse` の場合であり、conditions.md の説明と前提の形が合う。conditions.json の87行の判定は実質76・空疎8・自明3で、Model 21/7/1・Targets 28/0/1・Http 27/1/1 である。

### 2. 六正常形と篩拒否

Unit・整数・List・data・Map の鍵・handle の各形で、正常側（b = true）は `receive_value` により同じ値を受信し、元の結果型で型付き・Ground・任意の σ で Adequate である。拒否側（b = false）は `receive_reject` により `ExternalRefinement` を受信し、生の値は carrier を満たす。List と data は `Shape.list n`・`Shape.data n` の任意の n について、`nestedType`・`nestedValue` の帰納で扱い、最深部の整数の篩まで検査が届く（検査2(5) で任意の n の真偽を読んだ）。Map の鍵は鍵の型に篩を置き、実表の key 制約（`keys`）を読む。handle は群 B の `handleSignature`・`handle_wf`・`handle_arguments`・`handle_typed_iff` を使い、拒否側だけ結果の型を篩にかける。値は各段が単一の要素又は単一の欄の構成で、深さは記号のまま扱い、大きな値を作らない。篩が恒真・恒偽であることは軽2に書いた。

### 3. 全場合の量化と前段の不変

`response_value` は任意の lookup・`instantiate ts vs = some (a,e)`・全 Ψ の carrier・Ground から正常の生応答を作る。`receive_value`・`receive_reject` は任意の P・base・release・Ψ・入力・生応答・σ を受け、`receive_error_no_exit` は任意の err と全 n・obs の exit を扱う。どれも具体の P を前提にしない。`ExternalModels.conditions` は任意の P を量化し、宣言条件は群 A の三モデルと同じである。群 A の `ExternalModel.external_assumptions`・`scope_conditions`・`*_scope`・`*_core` の署名と本文は変わっていない（差分は追加だけ）。

### 4. 停止条件と守ること

主な十言明・型付けの規則・書ける形（P の制限を含む）・提供範囲・精密な外部状態・旧 `Release`・前段と群 A・B の実署名の変更はない。公理は三つの公理の部分集合だけである（検査1・2、記録の監査とも一致）。公開入口の読者は readers.json を生成宣言を除いて読み直し、全37入口に実際の読者があることを確かめた。`model_no_response_kind` と `responses` だけが適用例で読まれ、どちらも実際に適用している。名前と docstring の食い違いは軽3に書いた。コメントと追加行に工程の ID はない。

### 5. 写し

01-12 の3段落と 07-04 の2段落・表の2行は、追加した定理と定義に対応し、今回の変更の箇所に限られる（verify.py の照合の範囲と差分を読んで確かめた）。経緯の文と段名はない。`model_no_response_kind` と `io_kind` の記述は前提の形と合う。四分類の語と集計は軽1、篩の範囲は軽2に書いた。

### 6. 記録

記録は44ファイル（final-records.json の時点で45）・約1.64 MB、最大84,731バイトで、各100 KB 以下である。宣言の写しは群末の5分割一回分であり、baseline の14分割は保護対象のパスと SHA-256 の一覧である。生の出力（ビルド・公理監査）は `<tmp>` にあり、改造には大きさと SHA-256 だけを置く。宣言の件数（200、追加185、private 54、位置のない宣言 追加104・全106）は分割記録から数え直して一致した。verify の初回の失敗（台本の自己検出、終了1）と最終の成功（終了0）は別の記録に分かれ、本番と監査の入力を変えていない。義務の表は、群 C の単位を含む O061・O062・O063・O088 で群 C の分を書き、全体を閉じた行は0とする。O084 は群 C の単位を含まないと書いており、前例の所見（RV-L60.a 軽6、RV-L60.b 軽6）の形を避けている。olean の書き出しの記録の欠けは軽4に書いた。

## 実行した検査

| 番号 | 検査 | 結果 |
|---|---|---|
| 1 | `lake env lean -M 12288` で `ExternalModelTransport.lean`・`ExternalModelExamples.lean`・`ExternalModels.lean` を単独で検査 | 三つとも終了0、出力0バイト（警告なし）。各約0.7〜1.0秒 |
| 2 | `<tmp>/rv-l60-c/probe.lean`（`import Benitoite`）を `lake env lean -M 12288` で検査。(1) `shape_inputs .targets` を `targets_core (program s b)` の `external_typed`・`external_no_targets` へ当てる。(2) `handle_inputs .http` を `http_core (handleProgram b)` へ当てる。(3) `shape_inputs .model` を `model_core` へ当てる。(4) 任意の P・base・入力で `response_err` から存在を閉じる。(5) 任意の n で `Shape.data n` の拒否側の検査が偽、`Shape.list n` の正常側の検査が真。(6) `0 < x` の篩で同じ型が 1 を通し 0 を断る。主な7定理の `#print axioms` | 終了0。(1)〜(6) は全て型検査を通った。公理は全て `propext`・`Classical.choice`・`Quot.sound` だけ。最初の版に入れた自分の補題（List の型の不等）は帰納が要り失敗したので除いた。最終の入力の SHA-256 の先頭16桁は `ce7b61d4ffa4e8e5` |
| 3 | conditions.json・readers.json・宣言の分割記録を読み取りだけの Python で集計 | 87行、実質76・空疎8・自明3。公開37入口の全てに、生成宣言を除いた読者又は適用例がある。宣言の件数は記録と一致 |
| 4 | 作業の記録から lake の起動と既定ビルドの出力を抽出 | 対象を指定した `lake build` はない。`-o` による olean の書き出しが4回ある（軽4）。最後の既定ビルドは1,308ジョブで成功し、変更に関わる5モジュールを再ビルドしている |

## 再開1の再レビュー

2026-11-05。対象は同じブランチの再開1の後の作業木である。読んだものは、再開1の依頼文と担当の報告、results.md の「再開1（RV-L60.c の処置）」と同じ記録の「計画との差と試行の修正」・L60.12 の行、conditions.md の値に依存する篩の段落、`l60/c/resume1.patch`（前回の状態から今回の状態への本番と写しの差分）、作業木の `git diff 4fa52301 -- formal docs/design` と未追跡の2モジュール、verify.py の写しの照合の箇所、verification.json・readers.json である。取りまとめが同時に Lean のビルド出力を作り直すため、今回は Lean を実行していない。判定は差分と記録を読んだ結果だけによる。git の書き込み操作、本書以外のファイルの変更、記録を書き換える台本の実行はしていない。

### 判定

**可**（新しい所見は軽1・情報1）。軽1〜4と情報3の処置は、どれも所見の箇所に限られ、所見を解消している。

| 前回の所見 | 処置の確認 | 判定 |
|---|---|---|
| 軽1 | 01-12（3116行）と 07-04（78行）の段落から「実質」「自明」「空疎」と87欄・外部九欄の集計が消え、「型・非exitと無対象の条件は型付き入力と応答の証拠から示し、存在の条件は任意のerrで示す」と、本番の定理と前提の記述になった。数え方は「条件」に揃った。追加段落の後の二重の空行は一つになった（追加の空行は段落の区切りの5行だけ）。ただし 07-04 の対応表の `ExternalModels` の行に「Modelの六空疎の維持」が残る（新しい軽1） | 段落は解消。表の一語が残る |
| 軽2 | `positiveType`（`.refined (.base .integer) (.lt (.integer 0) (.var 0))`）・`positiveSignature`・`positiveProgram` を足し、`positive_receive_pair` は一つの宣言 `positiveProgram` と一つの拡張表 `ExternalModel.builtins positiveProgram base release` の上で、ExternalWF、任意の Ψ の同じ `ExternalArgs`、整数1と整数0の両方の生応答の所属、1 の正常受信（元の結果型で型付き・Ground・任意 σ で Adequate）、0 の `ExternalRefinement` による拒否（任意 σ で Adequate）を一つの言明で示す。生応答の所属は任意の整数について carrier から作り、検査の真偽だけが値で分かれる。任意の base・release・Ψ・σ を量化し、値は0と1だけである。写しは恒真・恒偽の証人（`receive_pair`・`handle_receive_pair`）と値に依存する証人を本番の名前で書き分けた | 解消 |
| 軽3 | `program_hasHttp`・`responses`・`ModelCase` の docstring を、本書の修正案どおりに中身に合わせた | 解消 |
| 軽4 | 「計画との差と試行の修正」に、`-o` による2つの olean の計4回の上書きと、最後の既定ビルドで5モジュールを再ビルドしたことを一行で記した。再開1では `-o` を使っていないと書く | 解消 |
| 情報3 | `model_inputs` を削除し、`shape_inputs` の Model の場合は他の二場合と同じく `raw_response s b Model.builtins (keys .model b) _ Ψ` を直接読む。`model_inputs` の名前は群 C の本番と記録に残らない（同名の宣言は別の名前空間の `StandardOrdinaryListBodies` だけ）。readers.json では `raw_response` の読者が `receive_pair`・`shape_inputs`、`shape_inputs` の読者が `responses` で、読者は欠けていない。results.md の L60.12 の行の読者名も合わせた | 解消 |

ほかの点:
- `ExternalModels.lean` の差分は、`model_inputs` の削除、`shape_inputs` の Model の枝、二つの docstring の3か所だけである。`ExternalModelExamples.lean` の差分は、`positive*` の4宣言と適用例1件の追加と `program_hasHttp` の docstring だけで、既存の証人の言明と証明は変わっていない。`ExternalModelTransport.lean`・`formal/Benitoite.lean` は前回の状態のままである。
- 公開入口は40（名前付きの読者37・既定ビルドの適用例3）。`positive_receive_pair` は適用例だけが読み、適用例は受理と拒否の両方の等号を取り出している。
- verify.py の変更は、写しの照合で除く範囲の末尾の一文字（改行）と、最後の文の「欄」を「条件」へ合わせた箇所である。保護対象・件数・分類の照合は変わらない。記録は49ファイル・約1.78 MB、最大84,855バイトで、各100 KB 以下である。宣言の写しは今回の6分割一回分に置き換わり、前回の要約は resume1-previous.json に残る。

### 新しい所見

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 軽1 | 軽 | 07-04 の対応表の `ExternalModels` の行 | 段落から四分類の語を除いたが、対応表の行の末尾に「Modelの六空疎の維持」が残る。軽1（前回）の対象の語である | 「Modelのpure・IO・exit署名と空のIO応答関係による前提の否定」などとする。verify.py は表の行を名前の前置きで除くので、照合の変更は要らない | 読めば確定 |
| 情報1 | 情報 | handoffs.md | `positive_receive_pair` は後段の受け口の表にない。値に依存する篩の受理と拒否は、群 D の表層の接続や L70 で同じ形を読む可能性があるが、受け口に載せるかは任意である | なし（後段で読むなら handoffs.md に一行足す） | 読めば確定 |

### 実行した検査

Lean は実行していない（取りまとめの検査とビルド出力の作り直しが同時に動いているため）。`positive_receive_pair` の型検査と全体の既定ビルドは、担当の記録（既定ビルド終了0・1,308ジョブ、公理監査終了0・83,693宣言、verify 終了0）と、前回の本書の検査2(6)（同じ述語で1を通し0を断る検査が同じ simp の集合で閉じる）に拠る。読み取りだけの Python で readers.json の該当行と verification.json を読み、`git diff` と resume1.patch の範囲を照合した。

## 取りまとめの追記

2026-11-05。初回の軽1〜4・情報3は再開1で処置した（`l60/c/results.md` の「再開1（RV-L60.c の処置）」）。再レビューの新軽1は、取りまとめが 07-04 の対応表の文言を直した。新情報1（`positive_receive_pair` を handoffs.md の受け口に載せるか）は任意とされたので載せない。後段が読む場合は、その段の依頼文で名指しする。再開1の後に取りまとめが `scripts/check.sh --level work --base 4fa52301d314e1a7cd4079e87889e485981da354` を実行し、終了0（575.78秒）であった。文言の直しの後に文書の検査（spec_tally・spec_examples）を実行し、終了0であった。
