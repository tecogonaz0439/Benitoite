# RV-L50.i: L50 群 I（L50.41〜.45）の独立レビュー

2026-11-05。対象はブランチ `m014/l50.i` の未コミットの作業木で、基準は `62974229140883a157b79199d7626f3efb59fe55`（HEAD と一致）である。見たものは次のとおりである。
- 本番の変更3ファイル: `git diff 62974229 -- formal docs/design` で追加19行・削除0行。`formal/Benitoite.lean` の import 2行、01-12 の5段落、07-04 の3段落と表の1行である。既存の Lean の定義・言明の変更はない。
- 新規2モジュール: `ModelTargets`（496行）・`ModelTargetsApplications`（289行）。
- `l50/i/` の記録。

読んだもの:
- 依頼と報告: 担当への依頼、担当の報告（冒頭から25欄の表まで）。
- `l50/detail.md`: 第1節の三モデルの行、第3節 F07・F09、第4節の三モデルの25条件と L60 に残す欄の表、第5節の L50.41〜.45 と群 I の完了条件。
- `l50/i/`: results.md・obligations.md・actual-signatures.md（抜粋）・contracts.lean・conditions.json・audit-summary.json・verification.json・build-check.json・work-check.json・run.py・audit.py（前半）・verify.py。
- 前例: `reviews/RV-L50.h.md`（形を揃えた）、群 H の `Model.lean`・`ModelTargetsExamples.lean`。

Lean で読んだもの:
- 新規2モジュールの全文。
- 旧 `Release/ModelTargets.lean` の冒頭の説明と `builtins`（旧7行の照合のため）。
- `ScopeSignatures.lean` の `builtins`・`unscopedIO`・`unscopedIO_shape`・`effKind`・`admitsR`。`ScopedIOResponse.lean` の `Operation`・`Reply`・`ioResponse`。`ScopeLegacyContracts.pathInput`。`ScopeDelta.input_errors`。
- `ConstraintAssumptions.lean` の `CoreAssumptions`（`release_exists` の前提の形）。`EffectTargets.lean` の `Builtins.TargetAgreement.obs_allowed`（F05）。

git の操作（読み取りを除く）、既存のファイルの変更、`lake build`、cargo の実行はしていない。Lean の検査は `formal/` を作業ディレクトリに `lake env lean -M 12288` で行い、確かめのファイルは `<tmp>/rv-l50-i/` に置いた。`verify.py` は `verification.json` を書き換えるので実行せず、同じ照合の主な部分を一時の台本で再計算した（検査4）。

## 結論

**可**（重0・中0・軽4・情報9）。

完了の判定は満たす。主な点は次のとおりである。
- `ModelTargets.scopeConditions P hp` は、`HasFile P` の下で25欄すべてを名前の付いた定理から構成する。どの欄も True だけの模型・空の sig 表・sat=True の置換に依らない。
- 15行は detail の「旧7＋追加8」と一致し、`sig_cases` は `lookup_mem` から成功する全 lookup を15の場合へ戻す。
- `io_exists` は九つの IO・exit の行で実際の応答を構成する。δ の未定義も lookup の外の名前も使わない。`io_target` と `obs_allowed` は同じ `ioResponse` の応答について、同じ σ の上限へ F05 で接続する。
- 旧 `File.readText` は String 入力・範囲引数なし・Top の `File.Read`・`topTargeted path` を保つ。exit は val を返さない。
- L60 に残す4欄は `ModelScopeConditions.core` の別の入力のまま残る。記録は `release_exists` を閉じたと書いていない。

処置を勧める点は、不要な上限の設定・写しの観測の範囲・写しの未定義の語・docstring の4件である。どれも完了の判定を左右しない。

| # | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 軽1 | 軽 | `ModelTargets.lean` 108〜109行 | `set_option maxRecDepth 4000` と `set_option maxHeartbeats 2000000`（既定の10倍）が、以降のファイル全体に掛かっている。どちらも外した写しが誤りなく通り、実時間は約1.9秒だった（検査2）。上限を上げたままにすると、後で証明が重くなる退行を隠す | 2行を消す | 実行で確定（検査2） |
| 軽2 | 軽 | 01-12 の追加の第3段落（「File.readText は String 入力、…解析した絶対パスを観測する」）、07-04 の追加の段落 | 本番の `readObs`（34〜40行）は、絶対形として解析できたパスだけを観測し、相対形・home 形・解析失敗では観測を空列にする。検査3で、`"a/b"` の観測が `[]` であることを証明した。写しは「解析した絶対パスを観測する」とだけ書き、ほかの入力で観測がないことを書いていない。読み手は、全ての読取りが対象を一つ観測すると読みうる。Top の上限は全てのパスを許すので、対象条件の正しさには影響しない | 01-12 の該当の文に「相対形・home 形・解析できない入力では観測は空である」と加え、07-04 にも同じ限定を一句加える | 読めば確定、実行で確定（検査3） |
| 軽3 | 軽 | 07-04 の追加の第3段落（`ModelTargetsApplications` の段落、171行） | 「旧三操作」「旧読取り」は、07-04 のどこにも定義がない。同じ追加の第1段落は File.readText・print・exit と名指しするが、「旧」の三つがそれを指すことは書いていない。07-04 では「旧」は主に旧 `Release` を指すので、旧 `Release` のモデルの操作とも読める | 「旧三操作」を「File.readText・print・exit」、「旧読取り」を「File.readText」に改める | 読めば確定 |
| 軽4 | 軽 | `ModelTargets.io_typed` の docstring（329行） | 「全九行の実応答を型付けし、exit と値の応答を区別する」と書くが、結論は `Outcome.Typed` と `AdequateResult` だけである。exit と値の区別は `io_kind`（349〜370行）の結論である | 「全九行の実応答の型と適格性を構成する」とし、区別は `io_kind` の docstring に任せる | 読めば確定 |
| 情報1 | 情報 | `entries`（17〜23行）・`sig_cases`（64〜76行） | 15行は、参照2・print・exit・File.readText・Scope の純粋3・File の範囲付き IO 6・起点発行1である。旧 `Release.ModelTargets.builtins` の7行（参照2・print・exit・File.writeTextIn・Scope.checkPathIn・File.readText）に、File の残り5行・pathInValue・widenPathIn・発行の8行を足した集合と一致する。`sig_cases` は `lookup_mem` からの `simpa` で、成功する全 lookup を名前と署名の等号の15場合へ戻す。検査3で、表の長さが15であること、`Http.sendIn`・`Http.checkRequestIn` が none であることを確かめた | 不要 | 読めば確定、実行で確定（検査3） |
| 情報2 | 情報 | 八保存則（88〜106行）と sat の対照（489〜493行） | `builtins` は共通表の `ScopeSignatures.builtins` を基に、`sig`・`effects`・`ioResponse`・`isResource` だけを置き換える。sat は共通の `ModelConstraints.sat` のままである。sat の3欄は共通表の射影、`sat_values` は `ModelConstraints.sat_values` を直接使う。admits の4欄は、15署名の全場合で admits が型引数の個数の検査と同値であること（private の `admits_iff_count`）から保存する。参照の型パラメータは空制約一つなので、`admits_sat` は `sat_unconstrained` に帰着する。tvar 0 の対照は群 H と同じで、両側が意味を持つ。sat が `ScopeDeclarations.http` の要約を使う点は群 H と同じである | 不要 | 読めば確定 |
| 情報3 | 情報 | `readTextSig`（13〜14行）、`io_op`（167〜178行）、`ModelTargetsApplications` 226〜235行 | `readTextSig` は `unscopedIO` で作り、型パラメータ・行・範囲の引数を持たない。効果は `Eff.single "File.Read"`（Top の原子）、形は `topTargeted .path` である。検査3で、効果・`rkinds = []`・`tparams = []`・kind・`opEff` と `effKind "File.Read" = some .path` を `rfl` で確かめた。`io_op` は File.readText に `unscopedIO_shape` の Top の枝を使い、single へ狭めていない。応答は旧の `Ok("")`・`Err` より広く、任意の文字列の Ok・Error・実行時エラーを許す | 不要 | 読めば確定、実行で確定（検査3） |
| 情報4 | 情報 | 純粋 δ の3行（219〜268行）と `ModelTargetsApplications` 247〜275行 | `pure_response` は15場合のうち pure でない12行を kind で除き、checkPathIn・pathInValue・widenPathIn を群 F の一般定理（`ScopeDelta.response`・`pathInValue_response`・`widenPathIn_response`）へ渡す。これらは任意の範囲と値の列を量化するので、絶対形・相対形・非 Top・Top を全入力で扱う。`pure_outcome` は δ の決定性で全実結果へ型・Adequate・非 exit・Ground を渡し、`normal_facts` は篩の事実を返す。適用例は、絶対形の成功を任意の上限で、相対形・home 形の Error を任意の範囲で、射影と拡大を任意の値で示す。上限に入らない絶対形の失敗と解析失敗の Error は適用例になく、一般定理（`ScopeDelta.input_errors` の第2項など）が担う | 不要 | 読めば確定 |
| 情報5 | 情報 | IO の応答（46〜53行、329〜408行） | `ioResponse` は、範囲付き IO 6行（`op ≠ .send`）を群 G の `ScopedIOResponse.ioResponse` に、print・exit・File.readText を具体の応答に結ぶ。`io_exists` は15場合のうち IO・exit でない6行を kind で除き、範囲付き IO 6行は群 G の存在定理、print は Unit、exit は `exitCode ws` の終了、File.readText は `Reply.error 0` を証人にする。証人は Error でよく、正常応答の存在を前提にしない。`io_kind` は全応答について、IO の非 exit と exit の非 val を示す。検査3で、`Http.sendIn` が関係に入らないことを証明した | 不要 | 読めば確定、実行で確定（検査3） |
| 情報6 | 情報 | `targetAgreement`（423〜433行）・`obs_allowed`（436〜443行）・470〜480行の例 | `io_target` は範囲付き IO を `ScopedIOResponse.targets`、File.readText を `readObs_kind`、print・exit を空の観測へ渡す。`obs_allowed` は F05 の `Builtins.TargetAgreement.obs_allowed` に、実表の `io_op`・`targetAgreement`・`sig_scoped` の `namesWF`・同じ `BuiltinArgs`・全実引数の同じ σ への適格性を与える。仮定の追加はない。470〜480行の例は、`io_exists` が作った同じ out・obs に `io_typed` と `obs_allowed` を適用し、存在と同じ σ の上限が同じ応答につながることを示す。`ModelTargetsApplications` の第1例は、File.readTextIn の非 Top と Top の両方で空でない観測の許容を示す | 不要 | 読めば確定 |
| 情報7 | 情報 | L60 に残す4欄（463〜468行、482〜487行、`contracts.lean`、results.md 123行） | `release_exists` と外部の3欄は `ModelScopeConditions.core` の別の入力として残り、記録も閉じたと書いていない。「File.Handle の型付き値により解放条件の前提が充足可能」の主張は正しい。482〜487行の例の型 `.opaque "File.Handle" .top` は、`release_exists` の前提の `.opaque o (.fixed .top)` と定義上等しい（検査3）。L60 への参考として次の二点を記す。<br>・`releaseResponse` は共通表の `fun _ r => r = none` なので、ModelTargets の `release_exists` は `⟨none, rfl⟩` で直ちに成り立つ（検査3で証明した）。前提は空疎でないが、結論は全ての値で自明に満たせる。<br>・`externalResponse` は既定の空の関係のままで、群 H の情報5と同じく、外部関数を宣言する P では `external_exists` が成り立たない | L60 の担当へ申し送る | 読めば確定、実行で確定（検査3） |
| 情報8 | 情報 | 公開の入口と読者 | 公開の定義・定理は全て、`scopeConditions`・ファイル内の例・`ModelTargetsApplications`・`contracts.lean` のどれかが読む。private の5補題も全て使われる。使わない前提は、欄の型が要求する `io_kind` の `BuiltinArgs` だけである。本番のコメントに工程の ID はなく、`#eval`・`sorry`・`axiom`・`admit` もない。01-12・07-04 の写しに段名・未実装の作業・経緯の文はない（「旧」の語は軽3） | 不要 | 読めば確定 |
| 情報9 | 情報 | 記録 | 最終の入力一覧（final-manifest）は現在の作業木の1,039入力と一致し、そのハッシュは verification.json の値と一致した。audit.py・modules.json・new-modules.json・actual-signatures.md・監査入力のハッシュも audit-summary.json と一致した。宣言の写しは163件（ModelTargets 88・Applications 72・契約3）で、results.md の件数と一致する。最大のファイルは initial-manifest-part-02.json の55,753バイトで、群の記録は約0.4 MB である。手元の絶対パスと docs/todo へのリンクは、照合の正規表現（verify.py 121〜122行）のほかに0件、相対リンクの切れは0件だった。生成物の時刻は既定ビルドの区間（00:54:54〜00:55:00）の中で、単独 Lean の `-o` で書いた生成物は既定ビルドが作り直している | 不要 | 実行で確定（検査4） |

## 観点ごとの根拠

### 1. 25欄が空疎でないこと

- **構成**: `scopeConditions`（446〜461行）は、`substitutionAssumptions P`・`responseAssumptions P hp`・`targetAgreement P` と表の12欄の名前の付いた定理を、欄ごとに渡す。
- **模型**: 表は15行で空でない。sat は True でない（情報2）。
- **存在**: `io_exists` は九行で実際の応答を構成し、残りの6行は kind で除く（情報5）。`delta_typed` は実 δ の値を返し、δ の未定義を使わない（情報4）。
- **同じ σ**: 情報6のとおりである。

### 2. 15行と lookup の全場合

情報1のとおりである。Scope の純粋3行・File の IO 6行・File.readText・print・exit はどれも落ちていない。効果表（25〜32行）の File.Read には File.readText・File.readTextIn・File.readBytesIn、File.Write には範囲付きの4書込みが入る。`effect_ops` は全分岐の所属を示す。

### 3. 旧 File.readText と exit

情報3・情報5のとおりである。`ModelTargetsApplications` の226〜235行は、形・範囲の種類・引数の型と、空でない観測の応答を確かめる。効果の等号はこの例に含まれないが、`rkinds = []` が範囲変数を含む効果を排除する。検査3で効果の等号も確かめた。

### 4. 純粋 δ の3行

情報4のとおりである。

### 5. release_exists と L60 の4欄

情報7のとおりである。

### 6. 入口・名前・写し

情報8、軽1〜4のとおりである。

### 7. 記録

情報9のとおりである。

## 実行した検査

| # | 検査 | 結果 |
|---|---|---|
| 1 | `ModelTargets.lean`・`ModelTargetsApplications.lean`・`l50/i/contracts.lean` を `lake env lean -M 12288` で `-o` なしに単独で検査した。あわせて新規2ファイルの `sorry`・`axiom`・`admit` の語を語単位で数えた | 3件とも誤りなく終了0、実時間で約8.7秒・約1.0秒・約1.8秒。語は0件 |
| 2 | `ModelTargets.lean` から `set_option max…` の2行を除いた写しを `<tmp>/rv-l50-i/NoOpt.lean` に作り、同じく単独で検査した。`maxRecDepth` だけを除いた写しも検査した | どちらも誤りなく終了0。前者は実時間約1.9秒（軽1） |
| 3 | `<tmp>/rv-l50-i/Probe.lean` で次を証明した。<br>(a) 表の長さが15、`Http.sendIn`・`Http.checkRequestIn` の lookup が none、File.readText の lookup が `readTextSig`。<br>(b) `readTextSig` の効果が `Eff.single "File.Read"`、`rkinds`・`tparams` が空、kind が io、`opEff` が File.Read、`effKind "File.Read" = some .path`。exitSig の kind が exit。<br>(c) `.opaque "File.Handle" .top` と `.opaque "File.Handle" (.fixed .top)` の等号、File.Handle が資源であること、`release_exists` の型の命題が `⟨none, rfl⟩` で成り立つこと。<br>(d) `readObs [.const (.string "a/b")] = []`。<br>(e) `Http.sendIn` が `ioResponse` に入らないこと。<br>あわせて `#print axioms` を `scopeConditions`・`obs_allowed`・`pure_outcome`・`io_kind` に実行した | 全て通る。公理は全て `propext`・`Classical.choice`・`Quot.sound` の範囲内（情報1・3・5・7、軽2） |
| 4 | 一時の Python で、verify.py の主な照合を書き込みなしに再計算した。最終の入力一覧と現在の作業木、入力一覧のハッシュ、audit-summary.json の各ハッシュ、宣言の写しの件数、ファイルの大きさ、相対リンクの切れを照合した | 全て一致、切れ0（情報9） |

検査の実行は合計で約20秒だった。大きな具体値を作る評価はしていない。担当の163宣言の監査・既定ビルド・work は引用し、再実行していない。

## 取りまとめの追記

- 軽1〜4は取りまとめが直した（上限の設定2行の削除、docstring 2件、01-12・07-04 の File.readText の観測の範囲、07-04 の「旧三操作」「旧読取り」の名指し）。宣言・言明・証明は変えていない。l50/i/results.md の「取りまとめによる修正」。
- 情報7は、L60 への申し送りとして l50/i/results.md に記した。そのほかの情報は処置しない。
- 群 I の作業末の work は終了0、518.84秒、最大常駐量 2,891,890,688 バイト（篩の部分の生成物を消して再ビルド。l50/i/results.md）。
