# RV-L50.c: L50 群 C（L50.11〜.15）の独立レビュー

2026-11-04。対象はブランチ `m014/l50.c` の未コミットの作業木、基準 `eb289e60a63a0cb238ad4e2a43aaa5ac1a84676e`（HEAD と一致）。本番の変更3モジュール（`AtInput`・`MembershipTargets`・`ShapeTargets`）、新規2モジュール（`MembershipWiden`・`ScopedCallContracts`）、根の import、01-12 と 07-04 の写し、`l50/c/` の記録を見た。

読んだもの: 担当への依頼と報告、`l50/detail.md` の第2節（値29規則・25構文・U1・U1の位置の母集団）、第3節 F03・F04・F08、第5節の L50.11〜.15 と群 C の行、第8節の残りの移植の族の表、`l50/c/` の results.md・coverage.md・transplants.md・obligations.md、群 A の `l50/a/signatures.md` の F04、群 B の `l50/b/transplants.md`、`reviews/RV-L50.b.md`。Lean は変更・新規モジュールの差分の全文と、`HeldValues.lean` の `checkedRequest_mismatch`・`checked_without_request`・`inv_checkedAt`・`CheckedWitness.request_content`・`checkedAt_request_mismatch`・`checkedAt_without_request`、`CanonicalValues.lean` の `canonical_held`、`ClosedEvaluation.lean` の `observeAs`、`Observation.lean` の `Term.interpret`、`ScopeDeclarations.lean` の `HasDeclarations`・`HasHttp`・`http`、旧 `Release/TargetTable.lean` の `ioIn`・`readTextIn`・`ioErrorTy`、`Refinement/TargetTable.lean`。

git の操作（読み取りを除く）、既存のファイルの変更、`lake build`、cargo の実行はしていない。Lean の検査は `formal/` を作業ディレクトリに `lake env lean -M 12288` で行い、確かめのファイルは `<tmp>/rv-l50-c/` に置いた。

## 結論

**可**（重0・中0・軽2・情報6）。

群 C の完了条件（任意 Ψ の保持対象と同じ要求を返し、型付き single が Top fallback を使わず、F3 と7位置への入口が同じ ws を保つ）を満たす。主な入口はすべて全入力を量化している。`canonical_target`・`request_target`・`canonical_opaque`・`widen_opaque` は任意の P・B・Ψ・Q（`canonical_opaque`・`widen_opaque` は C・Φ も）・範囲・σ を量化し、C20 の `canonical_held` と群 A の `target_member` を再利用して、23規則の帰納・排除を作り直していない。`widen_instTarget_covers` は型の全構成子と opaque/scoped の fixed/rvar の全枝を扱い、`HasTypeVsQ.widen_covers` は全長の列の帰納である。`single_request` と `single_inputs`・`request_inputs` は任意の p・u・ts・es・rs・ws を量化し、任意位置の lookup を private の `single_input` に一本化して再利用している。rs は入力として一度与えられ、結果型や許容効果から逆算する補題はない。前提が矛盾する入口や、結論が自明になる入口は見つからなかった。

軽2件は、前提の一つが型から導けるのに読者へ委ねている点と、拡大の対照の拒否側が被覆の条件を確かめていない点である。どちらも修正の形を実行で確かめた。後続（.25・.35・.51）が使う前に直せばよく、群 C の受け入れを妨げない。

| # | 重さ | 場所 | 問題 | 修正案 | 根拠の種類 |
|---|---|---|---|---|---|
| 軽1 | 軽 | `MembershipTargets.lean` の `HasTypeVQ.request_target`、`ShapeTargets.lean` の `Builtins.ShapeOk.single_request`、`ScopedCallContracts.lean` の `request_inputs` の前提 `form` | 3本はいずれも、値が `checkedRequest target req` か `checkedAt s snapshot target (some req)` であることを前提 `form` として受け取る。この形は残りの前提（空の文脈での型付け、`T.Holds o .endpoint (.fixed r)`、`valKind`、`valContent o = some A`、`Adequate`）から導ける。`canonical_target` の3形のうち、`checked` は `checked_without_request`、`checkedAt … none` は `checkedAt_without_request` で排除できる（検査3）。今のままでは、.25・.35 の実表の読者が同じ排除を各所で書くことになる。前提は充足可能であり言明は正しいので、空疎ではない | `∃ target req, v = .checkedRequest target req ∨ ∃ s snapshot, v = .checkedAt s snapshot target (some req)` を返す補題（例: `HasTypeVQ.request_form`。証明は検査3の12行）を置き、3本は `form` を外して `∃ target req` を結論に含める形にするか、少なくとも `form` を供給する読者の例を置く | 実行で確定 |
| 軽2 | 軽 | `MembershipWiden.lean` の末尾の例（docstring「非TopのパスをTopの不透明型へ広げても、要求なしの RequestIn は受理しない。」）と、`ScopedCallContracts.lean` の比較不能の例 | 前者の拒否側は不透明型の名前（内容を持つ `Http.RequestIn`）による拒否であり、拡大や範囲の被覆と関係なく成り立つ。後者は scoped どうしの静的な部分型の拒否だけで、API の引数の型である opaque で、覆わない範囲へ同じ値を型付けできないことは示していない。拡大の受理と拒否の対照が、被覆の条件について両側の意味を持っていない（AGENTS.md「受け入れと拒否の対照は、両側が意味を持つ形で置く」） | 拒否側に「`.checked (.path ["data"])` は `Scope.PathIn[/other/**]` の opaque に型付かない」（任意の σ で `target_member` から所属の矛盾を導く）を置き、受理側の `/data` → Top と対にする。証明は `target_member`・`simp [RangeExpr.Mem, RangeExpr.resolve]`・`decide` で通る（検査4） | 実行で確定 |
| 情報1 | 情報 | `MembershipTargets.lean` の `target_member_interpret` と直後の例 | 定理自体が任意の `k` を量化しており、例の `cases k` は同じ定理の再適用である。本番の読者はまだない（.28・.35 の担当）。前提 `observed` は `Term.targetValue (some σ) t` の項で充足できる（検査5）ので空疎ではない。`σ.Valid` を `target_member` に足さず、この読者だけの前提にしている点は 01-12 の写しと一致する | なし | 実行で確定 |
| 情報2 | 情報 | `ShapeTargets.lean` の `SingleTargetExamples` | 署名は旧 `Release/TargetTable.lean` の `ioIn ["path"] [pathIn 0] (resultTy (.base .string) ioErrorTy) "File.Read" .path` と欄ごとに一致する写しであり、`Builtins` は一行だけの表である。Refinement 側の実表はまだなく（.21〜.23 の担当）、本番の表の行への適用ではない。それでも `NamesWF`・`ShapeOk`・`BuiltinArgs` の全欄・全実引数の `Adequate` を仮定なしに供給しており、Ψ と σ は任意、範囲は非 Top の `/data/**` である。「全前提を満たす具体例」として本物である | なし | 読めば確定 |
| 情報3 | 情報 | coverage.md「F3 と U1 の7位置」の callback の行 | callback に固有の読者はなく、関数値と同じ任意の `TelClosure` の入口を共有する。全称の入口としては足りるが、builtin が受け取る callback に保持値を渡す実際の葉との接続は .51 が確かめる | なし | 判断 |
| 情報4 | 情報 | `ShapeTargets.lean` の8行の削除 | 削除は `single_target` の宣言の頭部と証明の最初の分解の8行であり、任意位置の lookup を private の `single_input` へ移し、同じ宣言を直後に置き直した。`#check` の型は群 A の signatures.md の F04 と一致する（検査2）。`target_member` の型も変わっていない。定義・構成子・型付けの規則・主な十言明・旧 `Release` の変更はない | なし | 実行で確定 |
| 情報5 | 情報 | `MembershipWiden` の4定理の名前 | 旧 `Benitoite.Release` に同名の `HasTypeVQ.canonical_opaque`・`widen_opaque`・`widen_instTarget_covers`・`HasTypeVsQ.widen_covers`・`Builtins.ShapeOk.single_inst` があり、両方の名前空間を open すると曖昧になる（検査1・6）。在庫の目的名に合わせた命名で、名前空間が異なるので衝突ではない | なし | 実行で確定 |
| 情報6 | 情報 | `MembershipTargets.lean` の `RequestMembershipExamples` | Pair の例は `ScopeDeclarations.HasHttp P` を仮定する。充足する具体の P は本群に置いていないが、`http` の構成子名とデータ名は互いに異なり、有限の lookup で充足できる既存の条件である。受理（443）と拒否（80）は同じ要求で、両側が意味を持つ | なし | 読めば確定 |

## 観点ごとの根拠

### 1. 完了の判定

- L50.11: `canonical_target` は C20 の四形と F03 の `target?` の成功を組み合わせ、保持3形のどれかであることを返す。値29規則・25構文の対応は coverage.md の表が detail.md 第2節の内訳と一致し、新しい帰納はない。`target_member_interpret` は任意の k（path・host・endpoint）・Ψ・Q・範囲（Top を含む）・σ・η・項を量化する（情報1）。
- L50.12: `request_target` は二保持経路のどちらからも、同じ値の `ModelHttp.valueRun`、内容型、`groundVal`、`reqTarget`、同じ σ での所属を返す。一般の例は任意の C・Γ・Φ・絶対範囲で二導入の受理と端点不一致の拒否を示し、具体例は `Pair[String{true}, String]` のヘッダを含む五欄の要求で 443 の受理と 80 の拒否を示す。URL の解析は `parseUrlTarget_https_loopback` の小さい等式で供給し、`native_decide` を使わない。前提 `form` だけが冗長である（軽1）。
- L50.13: `widen_opaque` は定数の枝（Top の自己被覆で S=Top に限る）と保持値の枝（逆転から scoped の導出を再構成し、既存の `.scoped` の共変と `.scoped_forget` を合成）に分け、新しい opaque の共変規則を作らない。`HasTypeVsQ.widen_covers` は全長の列の帰納で、例が `opSigAt` の実際の `clause.params` へ同じ ws を渡す。拡大後に同じ要求と端点を射影する例もある。対照の拒否側だけが弱い（軽2）。
- L50.14: `single_request` は `single_input` と `single_target` を再利用し、任意の p の lookup と F03 の証明を複製していない。非 Top の `File.readTextIn` の例は全前提を仮定なしに供給する（情報2）。
- L50.15: `single_inputs` は `TelClosure.apply` の固定署名に、空の Ctx の整形式と `SignatureInstance.result` を渡して同じ ws を元列へ戻し、`BuiltinArgs.normalized` から F04 へ進む。結果の `LeQ` と効果の `Covers` は適用の出力であり、rs は入力のまま一度だけ与えられる。7位置（直接・明示拡大・関数値・callback・ADT/List・Reference/Lazy・節/resume）と D09 の5入力形には coverage.md の表のとおり全称の入口と既定の読者がある。callback は関数値と入口を共有する（情報3）。

### 2. 在庫

transplants.md の9行は、それぞれ同名の本番の定理と既定ビルドの読者に対応する。群 B の17完了と合わせて26完了、残件は `allows_bind_comp`（.30）の1件であり、detail.md 第8節の割り当てと一致する。ShapeOk の5目的は一般の目的を閉じたもので、.23 の16実署名への適用と .35 の IO 応答・存在は別の担当として transplants.md と obligations.md に残っている。.51/.54 の全実行葉の合成も同様である。

### 3. 既存のファイルの削除と不変

情報4のとおり、8行の削除は宣言の移動であり、F04 の型は群 A と一致する。`#print axioms` を本群の主な14件に実行し、すべて `propext`・`Classical.choice`・`Quot.sound` の部分集合だった（検査1）。private と生成の宣言を含む218宣言の監査は担当の記録を引用し、再実行していない。

### 4. 設計書の写し

01-12 の追加4段落と 07-04 の2行は、本番の宣言名・前提・結論と一致する（`target_member_interpret` の `σ.Valid` と観測の等号、`request_target` の二構文の形と `valContent`、`widen_*` の長さ・形成・被覆の前提、`single_inputs` の `TelClosure.apply` への供給）。段名・工程の ID・未実装の作業・変更前との比較の文はない。本番の追加行にも工程の ID・`#eval`・`sorry`・`axiom`・`native_decide` はない。

### 5. 記録

`l50/c/` の最大のファイルは declarations.json の45,315バイトで、全体は約172 KB である。手元の絶対パス・`private/` の内容・docs/todo へのリンクは、verify.py の検出の正規表現を除いて0件だった。作業木の差分には担当の範囲外の `effort-ledger.md` の1行の追加があるが、取りまとめの記録である。

## 実行した検査

| # | 検査 | 結果 |
|---|---|---|
| 1 | `#print axioms` を `canonical_target`・`target_member_interpret`・`request_target`・`canonical_opaque`・`widen_opaque`・`widen_instTarget_covers`・`HasTypeVsQ.widen_covers`・`single_inst`・`single_request`・`single_target`・`single_inputs`・`request_inputs`・`parseUrlTarget_https_loopback` に実行 | すべて `propext`・`Classical.choice`・`Quot.sound` の部分集合。`sorryAx` なし |
| 2 | `#check` を `Builtins.ShapeOk.single_target`・`HasTypeVQ.target_member` に実行 | 群 A の signatures.md と同じ型 |
| 3 | `form` を残りの前提から導く補題（`canonical_target` と `checked_without_request`・`checkedAt_without_request`） | 通る |
| 4 | `.checked (.path ["data"])` が `Scope.PathIn[/other/**]` の opaque に型付かないこと（任意の σ） | 通る |
| 5 | `observeAs η (.target k) (.targetValue (some σ) t) = .targetValue (some σ) t`（sort の一致の下で） | 通る |
| 6 | `git diff eb289e60 -- formal docs/design` の削除行の抽出 | `ShapeTargets.lean` の8行だけ。情報4のとおり |

検査1〜5は `<tmp>/rv-l50-c/Check.lean` と `<tmp>/rv-l50-c/Widen.lean` の二つの入力で行い、外側の時間は各約0.8秒だった。出力の誤りは、両方の名前空間を open したための `#check` の名前の曖昧さ1件（情報5）と、`Widen.lean` の未使用の simp 引数の警告1件だけである。大きな具体値を作る評価はしていない。レビュー全体の外側の時間は約5分（18:47〜18:53）である。

## 取りまとめの追記

- 軽1・軽2は担当の再開1で処置した（l50/c/results.md の再開1。`HasTypeVQ.request_form` を加え、三つの入口から前提 `form` を外した）。情報1〜6は処置しない。
- 群 C の作業末の work は終了0、482.16秒、最大常駐量 2,943,287,296 バイト（篩の部分の生成物を消して再ビルド。l50/c/results.md）。
