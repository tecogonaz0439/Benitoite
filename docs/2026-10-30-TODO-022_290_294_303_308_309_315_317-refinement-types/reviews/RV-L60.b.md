# RV-L60.b: L60 群 B（L60.06〜.09、宣言と名目性）の独立レビュー

2026-11-05。対象はブランチ `m014/l60.b` の未コミットの作業木で、基準は `e0156b8294a0cc7bdec1bcf59b442268caa382ae`（HEAD と一致）である。見たものは次のとおりである。
- 本番の変更: `git diff e0156b82 -- formal docs/design`（`formal/Benitoite.lean` の import 2行、01-12 の3段落、07-04 の2段落と表の2行）と、未追跡の2モジュール（`ExternalNominal`・`ExternalSignatureLeaves`）。
- 群 B の記録: `l60/b/` の results.md・conditions.md・handoffs.md、台本（inventory.py・audit.py・verify.py・run.py・support.py）、要約の記録（audit-summary.json・verification.json・readers.json・baseline.json・before-closure-*.json・inventory.json の要点）、axioms.lean の冒頭。

読んだもの:
- 依頼と報告: 群 B の依頼文（守ること・止める条件）と担当の報告。
- `l60/detail.md`: 第2.1節の母集団の表と Ty の21構成子、第2.4節（四分類と12欄）、F02・F03・F08、C04、第4節の L60.06〜.09 の行と群 B の完了条件の行、第5節の申し送り（S12 など群 B の単位を含む行）、第6節の義務のうち群 B の単位を含む行（O060・O087・O088・O157・O168）と O084、第7.2・7.3節。
- `l60/a/standard-contract.md`、`reviews/RV-L60.a.md`（四分類と記録の書き方の前例）。
- `plan.md`: 「全 L 作業の停止条件」と「計画の変更と取りまとめへの確認点」の先頭の数項目。
- Lean の既存定義: `External.lean` の `ExternalTelWF`・`ExternalSignature.WF`・`Program.ExternalWF`、`Declared.lean` の `Ty.Declared`、`Patterns.lean` の `PatTy`、`ObservationType.lean`、`Capture.lean` の `Capture.closeTy`・`closeTyAt`、`HandlerContracts.lean` の `Ty.instTarget`、`CaptureTransport.lean` の `normContTy`、`Context.lean` の `rawApply`、`RefinementNormalForm.lean` の `Ty.core`。処理系は `crates/benitoite/src/builtins/funcs/json.rs` の `JsonMaterial` と `convert` だけを見た。

git の書き込み操作、本書以外のファイルの変更、`lake build`、cargo の実行はしていない。Lean の検査は `formal/` で `lake env lean -M 12288` により行い、確かめのファイルは `<tmp>/rv-l60-b/` に置いた。verify.py・audit.py・run.py・inventory.py の記録を書き換える台本は実行せず、読んで判定した。変換の閉包は、本番から独立に `<tmp>/rv-l60-b/` の読み取りだけの台本で求め直した。全環境の公理監査は再実行していない。大きな具体値を作る評価はしていない。

なお、作業木の `plan.md` と `effort-ledger.md` の変更は、群 B の終了（12:17:01）より後の時刻のもので、取りまとめの記録である。群 B の差分には数えない。

## 結論

**条件付き可**（重0・中1・軽7・情報5）。

証明の側に、群 B の完了を妨げる誤りは見つからなかった。主な点は次のとおりである。
- 既存ファイルの変更は既定 import と 01-12・07-04 の写しだけで、旧 `Release`・型付けの規則・主な十言明・前段と群 A の実署名は変わっていない。`sorry`・`axiom`・`native_decide`・`#eval`・`maxHeartbeats`・`maxRecDepth`・工程の ID は新しい2モジュールにも写しの追加行にもない。
- 鍵4対（`table_wf_iff`）、Occurrence 6規則（`occurrence_declaration` は `ExternalValueType` の9規則の帰納）、UseAt 3規則（`ExternalUseAt.mode`・`use_declaration`）、TelWF 2規則、WF 8欄（`collected_contract`・`declared_use`）、component/resource の受理と拒否（`handle_typed_iff`・`mismatched_handle`）、偽造の3境界は、任意の有限表・全導出・任意の到達型を量化する定理である。具体の表は受理側の充足可能性の証人に使われ、全称の代わりにはなっていない。
- 四分類は detail.md 第2.4節の定義に沿う。F02 の保持の系と `handle_not_source` を自明、異種2対・Map 鍵の key 出現・偽造の型付けの前提を空疎とした判定は正しく、実質へ数えていない。三モデルの保留6欄は繰り上げていない。外部ハンドルを `ResourceRelease.response` へ加えていない。

条件は中1の処置である。読めば確定し、実行でも確かめた。証明の追加は既存の系の適用だけで済む。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 中1 | 中 | inventory.py の `aliases`、`ExternalNominal.transformations`、conditions.md「F02の全変換」、results.md「計画との差と補足」、01-12 の3802行・07-04 の76行の「二十五変換」 | F02 の閉包は、直接の枝を持つ11定義のモジュールに `TypeSubst`・`ValueSubst` を足した13モジュールの中だけで、Ty を返す別名を探す。Refinement の全モジュールで求め直すと、公開の Ty → Ty の包み `Capture.closeTy`（`substTyValues cap.env`）と `Capture.closeTyAt`（`substTyValues (upSubst n cap.env)`）が閉包に入り、25入口から漏れている（検査1(a)）。両者は捕捉の閉包の型（`HandlerOperation`・`CloseApplication` など）で使われる。また、external を wildcard の恒等で通す Ty → Ty の変換（`Ty.instTarget`・`normContTy`・`rawApply t as`・`Ty.core`、private の `annotationType`）を含めるか除くかの基準が記録にない。「F02 の全変換」「25入口」の完了の主張は、この範囲では成り立たない | inventory.py の閉包を既定 import の閉包の全モジュール（少なくとも `Release/Refinement` 全体）へ広げる。`closeTy`・`closeTyAt` の `Preserves` を `substTyValues` の系として足し、`transformations` に入れる（検査1(b)で閉じることを確かめた）。恒等の枝で external を通す変換は、入口に加えるか、「external を恒等で返すので ID を保つ。入口に数えない」と基準と一覧を conditions.md に書く。01-12・07-04 の件数と verify.py の `transforms` を合わせて直す | 読めば確定、実行で確定（検査1） |
| 軽1 | 軽 | conditions.md「Tyの全構文位置」、inventory.py の `positions`、`ExternalNominal.nested_declarations` | 全21位置の宣言照合の根拠は、既存の `Ty.Declared` が全21構成子（Tel の各引数・Eff の Fail 型・篩の Pred を含む）を構造的に辿るという定義そのものである。inventory.py は構成子の名前の集合を照合するだけで、`positions` の表と `declaration_reader: "Ty.Declared"` は手書きの文字列であり、定義と照合していない。Lean の読者は `nested_declarations` の一つの形（Map の data 引数と Fn の List 引数・結果）と根の `declared_arity` だけである。detail.md は全21枝の帰納を作り直さないと定めるので処置は要らないが、results.md・報告の「本番から全構成子を再抽出し…照合しました」は台本が位置まで照合したと読める。名前 `nested_declarations` も一般の補題に見える | conditions.md に「全位置の照合は `Ty.Declared` の定義（全21構成子の構造的な再帰）による既済みの事実で、台本は構成子名の集合だけを照合する。Lean の読者は代表の一形」と書く。`nested_declarations` は形が分かる名前（例えば `map_fn_declarations`）にする | 読めば確定 |
| 軽2 | 軽 | `ExternalSignatureLeaves.constructor_pattern_rejected` と private の `constructor_pattern_data`、conditions.md「偽造の三境界」、01-12 の3806行・07-04 の78行 | 表現を読むパターンの拒否は `.con` だけを扱う。`PatTy` の他の形（`P_Const`・`P_RangeInt`・`P_RangeChar`・`P_List`）が外部型に型付かないことは述べていない。一般化は短く閉じる。wildcard と変数以外の全パターンについて、`P_Convert`・`P_Refined` を通しても観測型が external にならないことを示し、外部型での型付けを全形で拒否できた（検査2） | 補助を「wildcard・変数以外の全パターン」へ一般化して公開の拒否を一つにするか、写しと conditions.md に「構成子パターンに限る。定数・範囲・リストのパターンは別に述べていない」と範囲を書く | 読めば確定、実行で確定（検査2） |
| 軽3 | 軽 | ExternalSignatureLeaves.lean の468〜472行の example、ExternalNominal.lean の316〜319行の example | 468行の example は、言明が `constructor_value_rejected` と同じで、証明はその適用だけである（依頼文の「言明も証明も同じ重複した例」）。316行の example は `distinct` を `a.id`・`b.id` へ当てただけで、表示名を読まないので、docstring の「表示名が一致しても」を示していない | 468行の example を除く（`constructor_value_rejected` の読者は既定ビルドに別に要るなら、具体の P と構成子値への適用にする）。316行は、同じ表示名で異なる ID の二つの宣言を同じ表に置き、両方の型が一致しないことを示す形にするか、docstring を中身に合わせる | 読めば確定 |
| 軽4 | 軽 | `constructor_value_rejected` の docstring、01-12 の3806行「JSONから得る構成子値にもこの内側の境界を適用する」 | 定理は任意の閉じた構成子値についての拒否で、JSON を読まない。JSON の変換結果が構成子値であることは、処理系の `json.rs` の `convert`（全結果が `Json.Value` の構成子）を読んだ記録上の対応であり、Lean の前提にない。docstring の「JSON変換の構成子値は」は、定理が JSON の値を扱うと読める。01-12（言語仕様）に処理系の変換器との対応を書く位置も、07-04 の役割と重なる | docstring を「空の値文脈で型付く構成子値は、全構成子・全欄・全型引数で外部型にならない」とする。JSON の変換器との対応は 07-04 と conditions.md に置き、01-12 からは除く | 読めば確定 |
| 軽5 | 軽 | handoffs.md の「`ResourceRelease.response`へ加えないハンドルの既定例」「`ExternalSurface.call_typed`への既定の適用例」の行 | 後段（L60.D・L60.E・R50）への入口として、無名の `example` を挙げている。無名の例は後段から名前で引けない。特に外部ハンドルが通常資源の解放関係に入らないことは、群 E が通常資源の合成で読む性質である | 二つを名前付きの定理にする（例えば `ExternalSignatureLeaves.handle_not_release`・`handle_call_typed`）。名前を付けないなら、handoffs.md に「後段で同じ形を再び示す。名前の入口はない」と書く | 読めば確定 |
| 軽6 | 軽 | results.md の先頭の表の L60.07 の行、results.md の義務の表の O084 の行、handoffs.md の末尾の段落の S12 | (a) L60.07 の判定の欄が「完了。22変換」のままで、最終の25入口（中1の後はさらに変わる）と食い違って読める。(b) O084 の受け持ちの単位は .01〜.05/.36 で群 B の単位を含まないが、「本群の停止条件と全称・非空性・四分類の照合を完了」と書く（RV-L60.a 軽6 と同じ型）。(c) S12 の受け持ちは .08/.11 で、.11 の三モデルでの正例は群 C に残るが、handoffs.md は「本群の証拠で供給した」とだけ書く | (a) 判定の欄を「完了（最初の範囲は22入口。最終は本書の『計画との差と補足』）」とする。(b) O084 は「群 B の単位を含まない。本群は停止条件を守った」とする。(c) S12 は「.08 の担当分を供給。.11 の三モデルの正例は群 C」とする | 読めば確定 |
| 軽7 | 軽 | 01-12 の3802行「観測型」、3806行「表現パターン」、07-04 の76行「受渡し型」 | 三語とも基準の版の 01-12・07-04・用語集にない。01-12 は同じ概念を「受け渡せる型」「構成子パターン」と書き、観測型は `Ty.observationType` の名でしか現れない | 「`Ty.observationType`」「構成子パターン」「受け渡せる型（`ExternalValueType`）」と既存の語へ揃える | 読めば確定 |
| 情報1 | 情報 | `ExternalNominal.transformations` の引数 | `types` を型の改名と値の改名（`Ty.renameValues`・`renameTy`）に、`k c` を値と型の移動に共用する。任意の一つの変換と任意の引数は、引数を選んで呼べば得られるので、量化は欠けない | なし | 読めば確定 |
| 情報2 | 情報 | verify.py の公開入口の読者の判定 | 既定の適用例の判定は、例の本文に入口の短い名前が現れるかの正規表現による。`norm`・`bind` などの短い名前では誤検出がありうる。適用例だけで読む21入口を全件読み、どれも実際に適用していることを確かめた（ただし軽3の二つは意味が薄い） | なし | 読めば確定 |
| 情報3 | 情報 | conditions.md の WF 8欄の表 | 8欄のうち6欄（monomorphic・kinds・annotation・kinded・uses_unique・sourceTelRows）は `function_lookup` から得た WF の欄の射影で、推論を足すのは uses_exact と shape（`declared_use`）である。detail.md の定義では前提の証拠を使うので実質に当たり、記録は87欄へ加算しないと明記しているので、分類の誤りではない | なし | 読めば確定 |
| 情報4 | 情報 | 署名の component と型宣言の component の不一致 | 異なる component の外部型を使う署名の拒否は、`declared_use`（WF な署名の全使用は `td.component = d.component`）の対偶として全称で得られる。具体の拒否の例はない | なし | 読めば確定 |
| 情報5 | 情報 | `l60/b/` の記録 | 27ファイル・約0.42 MB、最大82,494バイトで、各100 KB 以下である。宣言の写し（declarations-01〜03）は最終監査の一回分で、before-closure-*.json は「25入口への拡大前の監査」と注記され、宣言数（97と100）・対象数（83,473と83,476）の差は追加した3入口と一致する。生の出力は `<tmp>` にあり、改造には大きさと SHA-256 だけがある。手元の絶対パスと docs/todo へのリンクはない。inventory.json と modules.json は既定 import の閉包の一覧を重ねて持つ | なし | 読めば確定 |

## 観点ごとの根拠

### 1. 完了条件の量化

鍵4対: `table_wf_iff` は任意の `P` について `Program.ExternalWF` を、一意性・同種2対の条件・異種2対の非所属の連言と同値で結ぶ。`keys` の `match` の4枝を `cases key <;> cases decl` で全て扱う。未知（`unknown`・`unknown_handle`・関数の `externalRef` の例）・重複（`duplicate` は値が同じでも拒否）・型ID/arity の差し替え（`type_entry`）・関数ID の不一致（`function_entry`）は、任意の表・ID・後続列・到達型を量化する。受理側は `singleton_type`・`singleton_function`・`declarations_wf` で、具体の表は充足可能性の証人である。

全 Ty 21の位置: 軽1のとおり、根拠は `Ty.Declared` の定義である。`Declared.lean` を読み、data・external・tapp の型引数、list・reference・lazy・set・dict の内容、fn の引数・結果・Eff の Fail 型、dependentFn の Tel（param は文脈を一つ増やす）、cont の三欄、map の二欄、refined の基底と Pred を辿り、残りの葉は True であることを確かめた。conditions.md の位置の表はこの定義と一致する。

F02 の全変換: 中1のとおり、直接の枝を持つ11定義は全体の検索と一致した（`=> .external` を返す枝は Refinement の11ファイルだけ）。包みの閉包は13モジュールに限られ、`Capture.closeTy`・`closeTyAt` が漏れる。各 `Preserves` は全自由パラメータ・全 ID・全引数列を量化し、`bind` は既存の `Ty.bind_external` を使う。新しい全21枝の帰納と相互置換はない。`transformed_distinct` は任意の保持する変換について異なる ID の一致を排除する。

uses/State: `ExternalUseAt.mode` は F03 の署名のとおりで、3規則の帰納である。`occurrence_declaration` は `ExternalValueType` の9規則の帰納で、map の key の枝を `key_no_occurrence` で除き、flags・scalar・unit・bytes は出現を持たない。`use_declaration` は TelWF の2規則と UseAt の3規則を組で扱う。State の二枝は `WF.shape` の効果の添字に入っており、detail.md の指定どおり別名の射影を作らず、`pureSignature`・`handleSignature` の WF と、効果を逆にした署名・使用列の欠落・重複の拒否を対にした。

偽造の3境界: `handle_not_source` は `Source`・`SourceScoped` の定義の False の枝で、任意の h・ts・深さを量化する。`constructor_pattern_rejected` は全 `c`・`ps`・`id`・`args`・`δ` を量化し、`P_Convert`・`P_Refined` を通る導出も扱う（範囲は軽2）。`constructor_value_rejected` は空の Γ で任意の P/B/Ψ/Q/C/Φ と全構成子値を量化し、`canonical_external` を使う。

### 2. 四分類

異種2対の前提は、整形式な表への所属から `keys` の False の枝で矛盾するので空疎である（異種の表そのものは具体に作れて WF でないことを例で示す）。Map の key 出現は、適格な `ExternalMapKey` の下で `key_no_occurrence` が任意の導出を否定するので空疎である。偽造の構成子パターン・構成子値の型付けの前提は、観測型と canonical の逆転から False を導くので空疎で、受理側に wildcard・変数と、任意の宣言から作る正しいハンドルの型付けがある。直接構築の拒否は定義の False なので自明である。F02 の25（中1の後は27）の系は定義の展開又は既存の系の適用なので自明である。

実質とした欄には、正常値で前提を満たす入力の証人がある。同種2対は `singleton_type`・`pure_wf` の非空の表、入れ子の宣言の取出しは `boxProgram` を List・Map・篩で包んだ入力（root・element・value・field・refined の5出現）、八欄の読者と使用位置は `declarations_wf`・`handle_arguments`、component/resource の一致は任意の identity の正しいハンドルである。WF 8欄の内訳は情報3のとおりである。三モデルの12欄は、conditions.md・handoffs.md とも群 A の不成立0・空疎2・自明3・実質1・保留6のまま継承し、`handle_arguments` を正常応答の証人へ読み替えていない。

### 3. 受理と拒否の対照

純粋外部と State 外部は、同じ有限表 `declarations` に型宣言と二つの関数を置き、`declarations_wf` で整形式を示す。`handle_arguments` は実ハンドルを borrow の引数に、外部型を own の結果に持つ `ExternalArgs` を、任意の B・Ψ・identity と同じ型宣言の lookup・arity から構成し、固定済みの `ExternalSurface.call_typed` へ同じ `admissible`・`arguments` を渡す例がある。同一の component/resource は `handle_typed_iff` の逆向きで `V_ExternalHandle` を適用して受理し、不一致は `mismatched_handle` が任意の到達型 T と型引数列で拒否する。component 不一致と resource 不一致は別々の例で読む。外部ハンドルは全ての分類関数・全ての解放結果で `ResourceRelease.response` に属さず、`ResourceReleaseModel` は変わっていない。

JSON の境界は、Lean で閉じたのが「空の値文脈の構成子値は外部型に型付かない」ことだけで、処理系の変換結果が構成子値であることは `json.rs` の `convert` を読んだ対応である。`JsonMaterial` の6形（Number は二形）は全て `Json.Value` の構成子（Null は無引数の構成子）になり、外部ハンドルを確保しないことを読んで確かめた。conditions.md と 07-04 は、変換器の健全性と実 CLI を後段に残すと正しく区別している（docstring と 01-12 の書き方は軽4）。

### 4. 停止条件と守ること

主な10言明・型付けの規則・書ける形・提供範囲・旧 Release・前段と群 A の実署名の変更はない（差分は根 import の2行と写しだけ）。新しい公理・sorry・native_decide・不要な上限設定・`#eval` はない。private の定義は `constructor_pattern_data` 一つで、`constructor_pattern_rejected` が読む。重複した例は軽3、名前と docstring は軽1・軽3・軽4である。適用例だけで読む21入口は情報2のとおり全て実際に適用している。コメントに工程の ID と経緯の文はない。

### 5. 写し

01-12 の3段落と 07-04 の2段落・表の2行は、本番の定理の前提と結論に対応する（件数は中1、用語は軽7、JSON の文は軽4）。追加は今回の二モジュールの記述に限られ、既存の段落を書き換えていない。段名・「台帳」などの記録の語・経緯の文はない。07-04 の表が引く 01-12 の節「保持要求と組み込みの遷移」は実在し、追加の段落もその節にある。

### 6. 記録

情報5のとおり、大きさ・一回分の写し・途中の記録の注記は守られている。最終状態と途中の記録の食い違いは、results.md の L60.07 の判定の欄だけである（軽6(a)）。義務の判定のうち、群 B の単位を含む O060・O087・O088・O157・O168 は「担当分完了」とし、残る担当を右の列に書いている。群 B の単位を含まない行は、O084 を除き「供給」「新規担当なし」と書き、閉じたとしていない（O084 は軽6(b)）。

## 実行した検査

1. F02 の閉包の独立の再抽出（中1）。
   (a) `<tmp>/rv-l60-b/closure2.py` を `python3 -I` で実行した。`formal/Benitoite/Release/Refinement` の全 `.lean` から、型が Ty で終わる `def` を集め、直接の枝の11定義を起点に本体の参照の不動点を求めた。閉包は群 B の14の包みに加え、`Capture.closeTy`・`Capture.closeTyAt`、private の `annotationType`、`normContTy` を返した（`OpSig.continuation` と `sourceArgument` は外部型の根を保つ変換でなく、`optionType` は本体の切り出しによる誤検出である）。`=> .external` を返す枝の検索は、Refinement の11ファイルに限られ、群 B の直接の11定義と一致した。
   (b) `<tmp>/rv-l60-b/Check.lean` と `Check2.lean` で、`Capture.closeTy`・`closeTyAt` の `Preserves` が `ExternalNominal.substTyValues` の適用で閉じること、`Ty.instTarget rs`・`normContTy`・`fun t => rawApply t as`・`Ty.core` の `Preserves` が `⟨args, rfl⟩` で閉じることを確かめた。両方とも終了0で、エラーと警告はない。
2. パターンの拒否の一般化（軽2）。`<tmp>/rv-l60-b/Check.lean` の `pattern_observation` で、`PatTy P p a δ` と `p ≠ .wild`・`p ≠ .var` から、任意の id・xs について `a.observationType ≠ .external id xs` を、全10規則の場合分け（`P_Convert`・`P_Refined` は再帰）で示し、`¬ PatTy P p (.external id args) δ` を導いた。終了0である。検査が実際に走ったことは、同じ内容に偽の等式を足した `Sanity.lean` がその行だけでエラーになり、`#print axioms pattern_observation` が `propext`・`Classical.choice`・`Quot.sound` を返したことで確かめた。
3. 新しい2モジュールと写しの追加行での禁止の語の検索。`sorry|axiom|native_decide|maxHeartbeats|maxRecDepth|#eval` と工程の ID（`L\d\d`・`F0\d`・`O\d{3}` など）・「台帳」「群」「段」「改造」は0件であった。
4. readers.json の適用例だけで読む21入口を、各例の本文と照合した（情報2）。

## 再開1の再レビュー

2026-11-05。対象は同じ作業木の再開1の後の状態である。見たものは、再開1の依頼文と担当の報告、results.md の「再開1（RV-L60.b の処置）」、conditions.md・handoffs.md、transform-candidates.json・inherited-protected.json・verification.json、verify.py・inventory.py の変更箇所、本番の2モジュールの変更箇所、01-12・07-04 の追加行（`git diff e0156b82 -- docs/design`）である。前回と同じ条件で行い、本節の追記のほかにファイルを変えていない。git の書き込み、`lake build`、cargo、記録を書き換える台本は実行していない。

### 判定

**可**（新しい所見は軽2・情報3。いずれも受け入れを妨げない）。中1・軽1〜7はすべて処置済みである。処置は所見の箇所に限られる。既存ファイルの変更は前回と同じ三ファイル（根 import と 01-12・07-04 の写し）だけで、F01〜F08・前段の実署名・型付けの規則・主な十言明は変わっていない。

| 所見 | 処置の確認 |
|---|---|
| 中1 | 処置済み。候補を列挙した範囲は `Release/Refinement` の722モジュールで、既定 import の閉包（modules.json の1,045モジュール）に含まれる Refinement のモジュール数と一致し、ディレクトリの `.lean` の722件とも一致する（検査R1）。Ty を引数に取り Ty を返す `def`/`abbrev` を行単位で独立に列挙し、transform-candidates.json の53件と比べた。記録にないものは `embedTy`（旧 `Release.Ty` からの埋め込みで、Refinement の Ty → Ty ではない）だけで、漏れはない。分類の基準は conditions.md の一文（「全自由パラメータで external の芯に同じIDを保つ公開変換を含め、external 全体を恒等の枝で返すだけの変換は数えない。外側に List・Map・data・cont などを作る型生成は除く」）に定まっている。53行を読み、採用29・恒等枝4・型生成16・private 4 のどれにもこの基準が一貫して当たることを確かめた。新しい `packRefinements`・`refineNorm` の `Preserves` は、既存の `Ty.core_packRefinements`・`Ty.core_refineNorm` から、引数列を変えずに芯が同じ外部型であることを示す。任意の述語列・述語について量化しており、意味は保持の系として正しい（分類は自明）。`closeTy`・`closeTyAt` は前回の検査1(b)と同じく `substTyValues` の系である。`transformations`・01-12・07-04・verify.py の件数は29に揃っている |
| 軽1 | 処置済み。conditions.md「Tyの全構文位置」に、根拠が `Ty.Declared` の定義であること、台本が構成子名の集合だけを照合することが書かれた。`map_fn_declarations` に改名され、読者も更新された |
| 軽2 | 処置済み。private の `pattern_observation_not_external` は `PatTy` の全10規則を `match` で場合分けする。`P_Convert`（`observationType_norm` で書き換えて再帰）と `P_Refined`（再帰）を通る導出も含む。`P_Const` は定数の全形、`P_RangeInt`・`P_RangeChar`・`P_List`・`P_Con` は観測型の構成子の違いで閉じ、`P_Wild`・`P_Var` は仮定と矛盾する。公開の `constructor_pattern_rejected` は、`p ≠ .wild`・`p ≠ .var` の全パターン、全 id・args・δ を量化する。前回の検査2の一般化と同じ内容で、公理依存は許可三公理である（検査R2） |
| 軽3 | 処置済み。重複していた example は、具体の `Null` への適用に替わった。ID不一致の example の docstring は、読む内容（ID と引数列）に合わせられた |
| 軽4 | 処置済み。docstring と 01-12 から JSON の文が除かれた。07-04 には、`json.rs` を読んだ対応であって Lean の前提ではないと書かれた |
| 軽5 | 処置済み。`handle_not_release`・`handle_call_typed` は名前付きの定理になり、既定ビルドの中に読者がある。handoffs.md の入口も実名に更新された（形については新軽1） |
| 軽6 | 処置済み。L60.07 の判定、O084（「群Bの単位を含まない。行の判定は変えない」）、S12（.08 の供給と群 C の .11 を分ける）が直された |
| 軽7 | 処置済み。写しの追加行に「観測型」「表現パターン」「受渡し型」は残っていない。`Ty.observationType`・「受け渡せる型（`ExternalValueType`）」・全パターンの範囲の明示に置き換わっている |

verify の引継ぎの扱いは、保護対象の照合を弱めていない。inherited-protected.json の例外は `plan.md`・`effort-ledger.md` の二つに限られ、verify.py は次を要求する: 二つの集合が一致すること、元の baseline のハッシュが記録と一致すること、更新時刻が再開1の記録開始より前であること、現在の内容が固定した大きさ・SHA-256 と一致すること。残る7,234ファイルは元の baseline と照合され、未説明の差を許す条件は足されていない。plan.md の増分は、前回に見た取りまとめの一行の追記である。ただし、取りまとめが二つの記録を編集するたびに固定を作り直す運用になる（情報R1）。

### 新しい所見

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 新軽1 | 軽 | `ExternalSignatureLeaves.handle_not_release`、handoffs.md の L60.E・R50 の行 | 定理は、特定の表 `program [(.type td.id,.type td)]` でのハンドルの型付け・解放関係への非所属・Source の拒否の三つの連言である。非所属の部分は表にも td にも依らず、任意の h・ts・分類関数・解放結果について `rintro ⟨o,i,equal,_⟩; cases equal` で閉じる（検査R2）。現在の形では、群 E は不要な td・arity・B・Ψ を供給しなければならない。ts も `[]` に限られる。handoffs.md の「全資源分類関数・全解放結果についてハンドルの非所属」は、ts の限定を書いていない。既定ビルドの読者も `.1`（型付け）だけを読み、非所属の部分は読まれていない | 非所属を `∀ h ts isResource r, ¬ ResourceRelease.response isResource (.externalHandle h ts) r` という独立の定理にし、handoffs.md の入口をそれに替える。今の連言は、その定理を使う適用例へ移す | 読めば確定、実行で確定（検査R2） |
| 新軽2 | 軽 | `constructor_pattern_rejected` の名前、07-04 の表の ExternalSignatureLeaves の行（「構成子パターン・構成子値の拒否」） | 一般化の後、定理は wildcard・変数以外の全パターンを拒否する。名前と 07-04 の表の行は構成子パターンに限るように読める（01-12・07-04 の本文は全パターンと正しく書く） | 名前を内容に合わせる（例えば `non_binding_pattern_rejected`）。07-04 の表の語を「wildcard・変数以外のパターン」にする | 読めば確定 |
| 情報R1 | 情報 | verify.py の引継ぎの照合、inherited-protected.json | 固定の後、取りまとめが `effort-ledger.md` を再び編集した（12:42:40。現在の SHA-256 `b5a19768…` は固定の `35ae10ab…` と違う）。今の作業木で verify を再実行すると、この照合で止まる。担当の誤りではない。取りまとめが後で work の検査や引用を行うときは、取りまとめの記録の二ファイルを保護対象から外す規則（又は再固定）を先に決める必要がある | なし | 読めば確定 |
| 情報R2 | 情報 | conditions.md の F02 の基準 | `Ty.core`（external を恒等で返す）を除き、`Ty.packRefinements`（external を篩で包む又はそのまま返す）を含める線引きは、基準の文面どおりに当たっている。どちらの保持も自明で、線引きは件数の数え方の区別であり、保持の言明の強さは変わらない | なし | 読めば確定 |
| 情報R3 | 情報 | results.md の先頭の単位の表の L60.09 の行 | 判定の欄が「25入口への補足」のままである。同じ文書の「再開1」の節と F02 の行が最終の29を示すので、誤読のおそれは小さい | なし | 読めば確定 |

### 実行した検査

- R1. 候補の列挙の照合。`<tmp>/rv-l60-b/cand.py` を `python3 -I` で実行した。`formal/Benitoite/Release/Refinement` の全 `.lean`（新しい2モジュールを除く）から、引数に Ty を持ち Ty を返す `def`/`abbrev` の見出しを行単位で集め、transform-candidates.json の名前と比べた。記録にないものは `Types.lean` の `embedTy` 一件だけであった。modules.json の既定の閉包に含まれる `Benitoite.Release.Refinement.` のモジュールが722件であることと、ディレクトリの `.lean` が722件であることも数えた。正規表現の初版は後戻りが多くて終わらず、止めて行単位の版に替えた。
- R2. `formal/` で `lake env lean -M 12288 Benitoite/Release/Refinement/ExternalSignatureLeaves.lean` が終了0で、エラーと警告がないことを確かめた。`<tmp>/rv-l60-b/R1.lean` では、任意の `h`・`ts`・分類関数・解放結果について `¬ ResourceRelease.response isResource (.externalHandle h ts) r` が二行で閉じることを確かめた（新軽1）。`#print axioms ExternalSignatureLeaves.constructor_pattern_rejected` は `propext`・`Classical.choice`・`Quot.sound` を返した。
- R3. 01-12・07-04 の追加行を、旧い語（観測型・表現パターン・受渡し型）と件数の語（二十五・二十九）で検索した。旧い語と「二十五」は0件、「二十九」は3件で、本番の29入口と一致した。

## 取りまとめの追記

2026-11-05。初回の所見（中1・軽7）は再開1、再レビューの新軽1・新軽2・情報R1・情報R3は再開2で処置した（`l60/b/results.md` の「再開1」「再開2」）。情報R2は件数の数え方の区別で、処置しない。F02 の入口は最終で29件である。再開2の後に取りまとめが `scripts/check.sh --level work --base e0156b8294a0cc7bdec1bcf59b442268caa382ae` を実行し、終了0（593.60秒）であった（`l60/b/results.md` の「群 B の作業末の work の検査（取りまとめ）」）。
