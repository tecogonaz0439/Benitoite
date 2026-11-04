# RV-L40.e6: L40 群 E の再開6（欄の等号の規則と head・tail の map・filter）の独立レビュー

2026-11-04。対象はブランチ `m014/l40.e` の未コミットの作業木、基準 `548d3fd94a5f1a171c9bc749b3408f8a9f3c08f8`。再開6の範囲（規則1の本番化と既存27ファイルの追随、精密 getter 06〜14 の9行、規則2と正常篩の7公開行、`%Map.replaceValues`、01-12 と 07-04 の写し、R 段への申し送り、群末の検査の記録）を見た。

読んだもの: 担当への依頼と担当の報告、plan.md「計画の変更と取りまとめへの確認点」の最初の二項目、`l40/e/results.md` の「再開6」の全部、`l40/e/` の r6 の記録（verification-r6.json・audit-summary-r6.json・ten-statements-r6.json・work-r6.json・default-build-r6.json・verify-r6.py・audit-r6.py の冒頭）、`sources-match-rule.md`、`reviews/RV-L40.e.md`。Lean は `FieldFacts.lean`（全文）、`Typing.lean` の差分、`MatchFacts.lean`・`MatchStateLeaves.lean`・`SubstTyping.lean` の差分、`MatchPaths.lean` の `addEvaluatedFacts` と links=[] の枝、`StandardHeadTailContracts.lean`（全文）、`StandardHeadTailResponse.lean` の主な言明、`StandardHeadTailBodies.lean` の定義、`StandardSafeBodies.lean` の `PreciseGetter` と `precise_row_typed`、`StandardMapReplaceValues.lean` の定義と `delta_aligned`、`StandardCollectionRefinedBodies.lean` の行・表・応答・`program_typed`、`StandardMapHigherPrecisionGap.lean`（全文）、`StandardMapSet.lean` の `mapDelta`・`normalizedMap`、`FiniteStepPreservation.lean` の冒頭。設計書は 01-12 と 07-04 の差分。処理系は `prelude/stdlib/` の List・Map・Set・NonEmptyList の `.bnt`、`builtins/funcs/list.rs` の head・tail・append、`runtime/list.rs` の tail・slice。

git の操作（読み取りを除く）、既存のファイルの変更、`lake build`、cargo の実行はしていない。Lean の検査は `formal/` を作業ディレクトリに `lake env lean -M 12288` で行い、確かめのファイルは `<tmp>/rv-l40-e6/` に置いた。

## 結論

**可**（重0・中0・軽4・情報4）。

規則1は、照合の成功から生成した等号が真であることを、任意の巣の経路・slots の並べ替え・捕捉の延長について Lean で証明しており、保存の証明へ接続している。等号は `addEvaluatedFacts` が閉じた評価の `some true` を要求して文脈に入るので、置換の失敗を既定値で真にする経路はない。値置換の側でも、`fieldFacts_bind` が根の `constructorIs` の `FactsWF` から観測の sort を得て、`termBind?` の成功を導く。主な十言明の字面は、基準の版・ten-statements-r6.json・今の作業木の三つで一致した。head・tail・append の精密署名は、既存の実 δ（`rfl` で照合）から全入力について証明されている。8つの純粋署名の `ResponseAssumptions` は仮定でなく定理である。書き換えた本体の字面は Lean の本体と de Bruijn の番号まで一致する。callback の順・回数、効果と失敗の伝播、結果の値、helper の非公開性、公開の引数も元の `.bnt` と同じである。`List.get` と加算の精密署名は足していない。Set.map は `≤` だけを持つ。所見は、設計書の写しの言い回し二件と、R 段への申し送りの不足二件である。

| # | 重さ | 場所 | 問題 | 修正案 | 根拠の種類 |
|---|---|---|---|---|---|
| 軽1 | 軽 | 01-12「条件とパターンからの事実」の `FieldLink` の段落 | 「`LinksValid` は…観測が欄の整数値又は List の長さであることを検査する」「欄の所有元・型引数・番号・sort の照合は、生成した等号の `FactsWF` でも検査する」とある。Lean の `FieldLink.Valid` が見るのは、`measure` が `none` か `some listLength` であることと、経路の各 `FieldRef` の構成子名・欄番号（`BinderPath.con`）だけである。整数の sort は `Pred.Sorted` の `eq` が両辺に要求する integer から、所有元・型引数・結果の sort は `FieldRef.Declared` から決まる。どちらも `FactsWF` だけが検査する。「でも」と書くと、`LinksValid` もこれらを照合すると読める | 「`LinksValid` は `measure` が none 又は listLength であることと、構成子名と欄番号の経路を検査する。欄が整数の sort であること、所有元・型引数・結果の sort は、生成した等号の `FactsWF`（`Pred.Sorted`・`FieldRef.Declared`）が検査する」と改める | 読めば確定 |
| 軽2 | 軽 | 07-04 の再開6の追加の段落（`MatchFacts`… の段落と `StandardCollectionPrecision`… の段落） | 改造の段名「R 段」を引き、まだ実装していないもの（処理系の篩の検査器、head/tail 本体と内部組み込みの Rust の実装）を書いている。基準の版の 07-04 に「R 段」は0件である。設計書の規約（実装している内容だけを書き、未実装は改造のディレクトリか docs/todo に置く）と合わない。同じ段落の「純粋応答の仮定へ接続する」は、`response_assumptions` が `Builtins.ResponseAssumptions` を証明する定理であることを、未証明の仮定のように読ませる | R40 で処理系に入れる時に処理系の記述へ書き換えることを申し送る。今直すなら、段名と未実装の列挙を除き、申し送りは results.md に残す。「仮定へ接続する」は「`Builtins.ResponseAssumptions` を証明する」に改める | 読めば確定 |
| 軽3 | 軽 | results.md「R段への申し送り: 署名の差」「本体の字面」の `%Map.replaceValues` | Rust で実装するための仕様が二点足りない。(a) 実行時に値の列の長さが Map の大きさと異なるときの振る舞い。Lean の δ は `replace` が none を返して応答なしになり、署名の篩がそれを型で除く。(b) `@builtin("%…")` を非公開の関数として `.bnt` で宣言する前例。今の `%` の組み込みは `%Format.*` だけで、`.bnt` には宣言がない（`prelude/` に `@builtin("%` は0件）。読み込み・名前の解決・利用者からの呼出しの禁止が今の処理系で成り立つかは、まだ確かめていない | (a) は、型検査を通ったプログラムでは起きない状態なので処理系の不具合（`Stop::Internal`）とする、と書く。(b) は、R40 の最初に、非公開の `@builtin("%Map.replaceValues")` の宣言を読み込めることと、利用者のスクリプトから名前で呼べないことを確かめる、と書く。結果の構築は、元のキーの表現と順を保ち、値だけを位置で入れ替える（`delta_aligned` により fromList を経ても同じ）と明記する | 読めば確定 |
| 軽4 | 軽 | results.md「R段への申し送り: 欄の等号の検査」 | Lean の `plain/guarded` は `links` を存在量化するので、`LinksValid` を満たす任意の部分集合を許す。処理系の検査器はどの集合を生成するかを決める必要があるが、申し送りに書いていない。少なく生成しても健全だが、精密 getter のような本体が型検査を通らなくなる | 「単一の構成子パターンで、構成子の欄だけを経て到達する変数の束縛のうち、欄が整数の sort のものには値の等号、List の sort のものには長さの等号を、一つずつすべて生成する」と明記する | 判断 |
| 情報1 | 情報 | verify-r6.py の入力の照合 | 一時の写しで再実行すると、01-12 の SHA-256 だけが記録と一致しない。取りまとめが規則の理由に出典を書き足したためであり、`rules_copy_exact`（Lean の二規則の字面が 01-12 に含まれること）は今も真である。他の値は記録と一致した（記録の数だけ 335→338。verify の後に書いた記録の分である） | 次に verify を引用するときは、01-12 の変更を取りまとめの追記として記す | 実行で確定 |
| 情報2 | 情報 | default-build-r6.json・audit-summary-r6.json の `timing_source` | 既定ビルドの約367.5秒と全公理監査の約26.07秒は、開始の記録と出力の mtime からの近似である。results.md の表と担当の報告は、近似であることを書いていない | 表の所要の欄に「mtime からの近似」と添える | 読めば確定 |
| 情報3 | 情報 | 書き換えた mapFrom・filterFrom | 一歩ごとに `tail` が `runtime::list::slice` で新しい頭と境界の道筋を作る（RRB の cut）。以前の `get` は確保しない。計算量は一歩あたり対数だが、確保の回数は増える | R40 の map・filter の測定（計画済み）で、確保の回数も見る | 読めば確定 |
| 情報4 | 情報 | `l40/e/results.md`（85,411 バイト） | 100 KB の上限まで約14.6 KB である | 次の再開は別の results のファイルに書く | 読めば確定 |

## 観点ごとの根拠

### 1. 規則1の健全性と範囲

`FieldLink.Valid` は、選択肢がちょうど一つで（`alts = [alt]`）根が構成子のパターンであること、`slot < n`、`alt.slots[slot]? = some raw`、`BinderPath alt.pat raw route`、空でない経路、`measure ∈ {none, some listLength}` を要求する。`BinderPath` は `.var` と `.con` だけを経るので、List パターンの要素や rest、wild・const・range を経る経路は作れない。wild・const・range は `Pat.binders` が0なので、左の欄の束縛数の計算に正しく入る。or パターンは `alts` が二つ以上になるので、`LinksValid` を満たす `links` は空だけである。

事実の真は次の連鎖で示されている。`BinderPath.matched` は、`matchVal` の成功から、生の束縛の位置 raw の値が `readPath v route` と等しいことを示す（巣の構成子の各段で、構成子名の一致を照合の成功から得る）。`FieldLink.matched` は、`selectSlots` の並べ替えを通して、並べ替え後の slot の値が同じ欄の値であることを示す。`CaptureOk.field_facts` は、捕捉の延長 `cap.extendMany ws` の `n-1-slot` 番がその値であること（`capture_slot`）、観測の持ち上げ `n+i` が延長の外側を読むこと（`capture_lift_term`）を示す。そのうえで `field_equality_true` が閉じた評価の `some true` を導き、`addEvaluatedFacts` に渡す。束縛の値の項 `tw` は、束縛の文脈 `bindParams Γ δ` の `CaptureOk` の `substOk.observations` から、整数又は List の sort について得ている。関数値などを既定の整数へ置き換える経路はない。ScopeError.At も `conFields?` で通常の欄の列として読み、照合の側と同じ構成子名で扱う。

guard は `capture_guard_success` で同じ欄の事実の下に型付けされる。guard 付きの腕の後続は元の Φ で検査され（`guarded` の最後の前提）、パターンの失敗の枝（`capture_plain_success` の `succ n`）は除外の事実だけを加える。失敗や偽の guard から後続へ欄の等号は渡らない。

値置換（`SubstTyping` の plain・guarded）は `fieldFacts_bind` で、`links` が空でなければ根の `constructorIs` の `FactsWF` から観測の sort を得て `termBind?` の成功を導く。置換の後の事実の列は `fieldFacts n (obs.bind (termBind? σ)) links` と一致し、新しい前提はない。

主な十言明（TypingShift・TypeShiftTyping・SubstTyping・Narrowing の10定理）の `theorem` から `:= by` までの字面の SHA-256 を、基準の版（`git show 548d3fd9:…`）と今の作業木で計算した。10件とも ten-statements-r6.json と一致した。`StateTyE.steps_preserved` の言明（`P.WellFormed`・`P.WellTyped B`・`P.EffectsOk B`・`B.CoreAssumptions P`・`σ.Valid` の前提）に、欄の事実のための前提は加わっていない。

小さな Lean の例で、次を確かめた（`<tmp>/rv-l40-e6/rule.lean`、終了0）。

- 選択肢が二つの `alts` には、どの `FieldLink` も `Valid` にならない。
- `C(x, y)` で、生の束縛0（x）に欄1の経路を結ぶ `BinderPath` は作れない。
- 正しい対応（y は生の位置1・欄1）と、巣の `C(_, D(z))` の z（生の位置0、経路 [C の欄1, D の欄0]）は作れる。

### 2. Lean と 01-12・07-04 の写しの一致

01-12 の `FieldLink.predicate`・`fieldFacts` のコードと `plain/guarded` の二規則は、Lean の字面と一致する（verify の `rules in core` を再実行で確かめた）。`FieldLink` の欄、`n-1-slot` と `n+i` の番号、`BinderPath.con` の説明、guard の扱いも Lean と合う。食い違いは軽1の言い回しだけである。07-04 の【決定】は対象・生成の条件・検査の項目・guard の扱いで Lean と一致する。07-04 の追加の段落の問題は軽2である。

理由の欄の出典は、`sources-match-rule.md` の要約と照らして矛盾しない。要約によれば、Chk-Alt は `unapply` で束縛に構成子の引数の型を与え、構成子の結果の型を対象の型へ meet で結ぶ。01-12 は「照合で明らかになる対象と束縛の関係を加える方式」と書き、本書の違いを「measure の代わりに欄の射影の等号」としている。

### 3. getter 06〜14 の9行

`PreciseGetter.tel` は `checkedIntegerProjection`・`checkedLengthProjection`・`InternalContracts.checkedLength`・`checkedLengthValues`・`checkedIndexProjection`・`checkedIndexValues` をそのまま使う。これらを定める `StandardSafeContracts.lean` の SHA-256 は開始時の記録と一致した（verify の照合）。本体は一変数の構成子パターンの match、links は欄一つ（整数又は List の長さ）であり、`HasTypeArmsQ.plain` の新しい前提を `precise_links`・`precise_field_wf` で満たす。`precise_rows_typed` の前提は空であり、`#print axioms` は許可した三公理だけだった。新しい意味論的前提はない。

### 4. 規則2と公開の7行

head・tail・append の署名（`StandardHeadTailContracts`）の結果の篩は、`head_reply`・`tail_reply`・`append_reply` が任意の有限列について閉じた評価で真を示す。実 δ との対応は `real_head`・`real_tail`・`real_append`（`rfl`）である。`option_response`・`append_response` は、任意の `BuiltinArgs` から実 δ の応答・`Outcome.Typed`・`AdequateResult`・非 exit を結論し、篩を前提に置かない。処理系の head（`list::get(xs, 0)`）・tail（`slice(1, MAX)`）・append（末尾に一要素）とも合う。append の長さの上限の停止は正常値の篩の対象外であり、従来の模型の扱いのままである。

`StandardCollectionRefinedBodies.builtins` の署名は8つ（head・tail・append・Map/Set の fromList・toList・`%Map.replaceValues`）だけで、`List.get` と加算はない。`response_assumptions` は定理である。Set.map の結果は `.le` であり（`higherTel` の `map && !filter` 以外の枝）、等式はない。

本体の字面を Lean の `fromBody`・`publicBody`・`higherBody`・`mapCallbackBody true` と照合した。de Bruijn の番号（head の None は acc、tail の None は acc、map の append は y、filter の append は x、再帰の引数 xs・f・ys・新しい acc、filter の偽の枝の acc）は、results.md の `.bnt` の字面と一致する。元の `.bnt` と比べると、次のとおりである。

- callback は head の Some ごとに先頭から一度ずつ呼ばれ、tail はその正常な返却の後に読まれる。元の `get(xs, i)` の順・回数と同じである。
- filter の `if p(x) then` は `bind keep <- p(x)` の後に純粋な tail を挟むだけである。失敗と効果は同じ E を通る。
- Map.map は、元が `Pair.first(value)` を二度読んでいたのを一度にしたが、純粋なので観測できる差はない。
- `delta_aligned` により、元のキーと同じ位置の callback の結果を Pair にした列への fromList と、内部補助の結果が一致する。toList と内部補助は同じ `normalizedMap` を使うので、位置の対応も一致する。
- helper は `public` を持たず、公開の引数（xs/f、xs/p、m/f、m/p、s/f、s/p、value/f）は変わらない。
- NonEmptyList.map は、元が first を先に、rest を順に写していたので、`List.map(xs: value, f: f)` と同じ順になる。S30 の別名化を前提にしている点は results.md に書かれている。

### 5. `%Map.replaceValues`

δ は、入力の Map を既存の `normalizedMap` で縮約済みの entries にし、値だけを位置で入れ替え（`replace`）、既存の `mapDelta "Map.fromList"` に渡す。entries のキーは互いに異なるので、fromList の「同じキーでは最初のキーの表現と最後の値」の規則は働かず、キーの表現と順は元の Map と同じになる。これは元の Map.map の本体（toList の Pair のキーで fromList する）の意味と同じである。`StandardMapHigherPrecisionGap.scalar_contract_gap` は、長さ・大きさだけの中間契約から等式が出ないことの反モデルであり、内部補助を足す理由を支える。Rust の実装の仕様としては軽3の二点が足りない。

### 6. R 段への申し送りの表

署名の差の表（17行）は、関数名・変える前・変えた後・理由を持ち、Lean の tel と一致する（head の `isNone ⇒ L(xs)=0`、tail の Some の欄の長さ、append の `+1`、helper の不変条件、`%Map.replaceValues` の第2引数の同長性と結果の等式）。本体の字面は `.bnt` に写せる形である。欄の等号の検査の要点は、対象の sort、単一の構成子パターン、raw と slot の対応、経路の照合、持ち上げと `FactsWF`、guard、捕捉を押さえている。不足は軽3・軽4である。

### 7. 記録と検査

audit-summary-r6.json は、許可した三公理の組合せだけを持ち、組合せの件数の和が 78,534 宣言と一致する。監査の後に台本を直したこと（実行時 5,465 バイト、今 6,451 バイト）は audit-collection-recovery-r6.json に記されている。本レビューでは、主な定理10件の `#print axioms` を確かめ、許可した三公理だけだった。

work の約5.36秒について。`formal/` の Lean のソースに 10:41 JST 以降の変更はなく、`Benitoite.olean` の mtime（10:48:04）は既定ビルドの終了（01:48:04 UTC）と一致する。work の `formal_build` がキャッシュだけで済んだという記録と合う。

verify-r6.py は、記録を書き換えないように書き出し先だけを替えた写しで再実行した。結果は情報1のとおりである。r6 の新しい記録は各 100,000 バイト以下で、最大は declarations-r6-StandardOrdinaryCoreProgram-part-01.json の 89,922 バイトである。r6 の記録と results.md の再開6に、手元の絶対パス・docs/todo へのリンク・`private/` の内容はない（`/Users/` を含む verify-u2x・r1〜r4 の台本は以前からのもので、検査の正規表現の中だけにある）。`formal/Trial/` はなく、削除前の大きさと SHA-256 は results.md に記録されている。

## 実行した検査

| 検査 | 内容 | 結果 |
|---|---|---|
| 主な言明と公理 | `<tmp>/rv-l40-e6/checks.lean`（`step_preserved`・`steps_preserved`・`CaptureOk.field_facts`・`precise_rows_typed`・`seven_public_rows`・`response_assumptions`・`StandardMapReplaceValues.response`・`delta_aligned`・`option_response`・`append_response` の `#check`、10件の `#print axioms`） | 終了0、外側0.81秒、最大常駐量 1,573,289,984 バイト。公理は propext・Classical.choice・Quot.sound だけ |
| 規則1の小例 | `<tmp>/rv-l40-e6/rule.lean`（or パターンの拒否、誤った経路の拒否、正しい経路と巣の経路の構成） | 終了0（自分の書いた証明を二度直して再実行） |
| 十言明の字面 | 10定理の `theorem`〜`:= by` の SHA-256 を、基準の版・今の作業木・記録で照合 | 10件とも三者一致 |
| verify の再実行 | verify-r6.py の写し（書き出し先だけを `<tmp>` に替え、入力の不一致を止めずに表示） | 01-12 だけ不一致（情報1）。他は記録と一致 |
| 更新時刻 | `formal/` の Lean のソースの 10:41 JST 以降の変更、`Benitoite.olean` の mtime | 変更なし、10:48:04 |

所要は、読みと検査を合わせて約15分（外側の時間）である。

## 取りまとめの追記

- 軽1〜4・情報1〜4は、担当の再開7で処置した（l40/e/results-r7.md）。Lean・Rust・`.bnt` は変えていない。verify は終了0。
- 群 E の作業末の work は終了0、419.31秒、最大常駐量 2,912,403,456 バイト（篩の部分の生成物を消して再ビルド。l40/e/results-r7.md）。
- `%Map.replaceValues` の追加は plan.md に設計者の見直しの対象として記した。R40 で登録・署名・Rust の実装と Lean の δ との照合を行う。
