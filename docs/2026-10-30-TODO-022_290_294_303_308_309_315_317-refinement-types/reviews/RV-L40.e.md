# RV-L40.e: L40 群 E（L40.21〜.28、初回・再開1・再開2）の独立レビュー

2026-11-04。対象はブランチ `m014/l40.e` の未コミットの作業木、基準 `548d3fd94a5f1a171c9bc749b3408f8a9f3c08f8`。再開3が同じ作業木で扱う List.map・List.filter・mapFrom・filterFrom・Map/Set の map・filter・NonEmptyList.map の篩付きの型、`List.get`・`List.append`・整数の加算の精密な署名と、再開3が新しく足したファイル（`StandardListGetPrecisionGap` など）は対象から外した。

読んだもの: `l40/e/` の results.md・results-r1.md・obligations.md・core-r2.md・return-boundary.md・sources-r2-u28.json・ordinary-closed-r2.json・classify-r2.py・verify.py・verify-r2.py・audit-r2.py・audit-summary-r2-final.json・verification-r2.json・checks-r2*.json・checks-r1-r2.json・command-deviations-r1.json・gen-character-r2.py・gen-string-tables-r2.py・character-data-r2.json・string-tables-r2.json。計画と設計は `l40/detail.md` の L40.21〜.28 の行・F06・第9節「L50/L60/L70へ渡す署名」、`l40/a/signatures.md` の F06 と安全な入口の表、`l40/a/safe-contracts.lean`、plan.md「計画の変更と取りまとめへの確認点」の 2026-11-04 の三項、`reviews/RV-L40.e-boundary.md`。Lean は、群 E の新しいモジュールのうち再開2の純粋応答の八本（ByteString・Character・IntegerText・FloatMath・NumericRemaining・StringOrdinary・BytesOrdinary・ListRemaining）、StandardSafeFieldGap・FiniteStepPreservation・StandardSafeContracts は全文を読んだ。StandardOrdinaryCoreProgram・StandardAliasBodies・StandardOrdinaryListBodies・初回と再開1のモジュールは、主な定理の言明と定義の要所を読んだ。処理系は `crates/benitoite/src/builtins/funcs/` の integer.rs・narrow_integer.rs・unsigned_integer64.rs・float.rs・float32.rs・decimal.rs・character.rs・string.rs・bytes.rs・list.rs・mod.rs、`base/prim.rs`・`base/decimal.rs`・`base/display_width.rs`・`runtime/heap/build.rs`・`runtime/mod.rs`・`types/mod.rs` の ORD、`runtime/equal.rs` の Decimal を読んだ。

git の操作（読み取りを除く）、既存のファイルの変更、`lake build`、cargo の実行はしていない。Lean の検査は `formal/` を作業ディレクトリに `lake env lean -M 12288` で行い、補助の入力と出力は `<tmp>/rv-l40-e/` に置いた。

## 結論

**可**（重0・中0・軽3・情報4）。

未接続だった179行は、各モジュールの `response` が全ての P・B・Ψ・型/行/範囲/値引数・結果型・効果を量化した `BuiltinArgs` から、同じ具体 δ の応答・`Outcome.Typed`・`AdequateResult`・exit の排除を結論する。前提は Option の構成子宣言と arity だけであり、出力の型付け・未検査の意味的な仮定・強い lookup はない。core の27行と別名51行は、同じ有限の P・B での `Def.WellTyped` である。具体計算は、境界を優先した100件（`decide +kernel` 96件と `#eval` 4件）の抜き取りで、固定 Rust の出力と全件一致した。Unicode の表と表示幅の表は、生成器を一時領域へ写して再実行し、`formal/` の221ファイルとバイト単位で一致した。固定したもの（既存の Lean 752本、群 A の安全な入口19行、主な十言明、Step/Steps/Runs）は変わっていない。

観点4の結論: 型付けの規則を変えずに精密 getter 06〜14 を閉じる経路は、ないと判断する。根拠は、照合の腕の文脈で束縛変数に触れる事実が束縛の宣言型だけであり、どの導出でも束縛変数を自由に動かすモデルが残ることである（観点4）。

| # | 重さ | 場所 | 問題 | 修正案 | 根拠の種類 |
|---|---|---|---|---|---|
| 軽1 | 軽 | `l40/e/verify-r2.py`、results.md「群末検査の確定結果」の全体verifyの行 | 「179/179の通常契約」の照合は、classify-r2.py が書いた JSON の件数と状態の欄を読むだけである。各行の証拠の定理名の存在も、API 名が証拠のモジュールの表にあることも確かめていない。classify-r2.py はモジュール名と API 名の規則で証拠を割り当てている | verify-r2.py に、証拠の名前が宣言記録にあることと、各 API 名が証拠のモジュールの名前の表（`API.name`・`name k api`・`PublicAPI.name`）にあることの照合を加える。加えない場合は、results.md の表現を「JSON の件数と状態の照合」に改める。本レビューでは外から照合し、49の証拠名はすべて宣言記録にあり、名前を連結で作る48行も Lean の表と一致した | 読めば確定 |
| 軽2 | 軽 | ordinary-closed-r2.json・sources-r2-u28.json の証拠欄（`*.table_response`） | 証拠に挙げた `table_response` は、`{base with sig := lookup}` で各モジュールの名前だけを持つ表と、固定のモデルのプログラムについての言明である（IntegerText は `StandardCollectionModel.program`、NumericRemaining・String・Bytes は `StandardPureResults.program`、Byte は任意の P）。L60 が一つの表へ合成するときに使えるのは、任意の P・B と Option の宣言を前提にした各モジュールの `response` の方である | 証拠欄に `response`（List.range は `range_response`）を併記し、L60 へ渡す署名は `response` であると obligations.md の O011・O030・O059 か detail 第9節の L60 の行に書く | 読めば確定 |
| 軽3 | 軽 | 純粋応答の八モジュールの `API.evaluate` の既定の枝（`malformed`）と F06 の結論 | F06 の結論は `Outcome.Typed` と exit の排除だけなので、型の付いた入力に内部の誤り（`.err "invalid … arguments"`）を返す δ も満たす。本レビューで読んだ範囲では、`arguments` の逆転が既定の枝へ落ちない形を与えている。ただし言明はこれを保証しない | 各 `response` に「`out` は malformed の err でない」を結論として加えるか、R50 の交換で照合する項目として申し送りに名指す | 読めば確定 |
| 情報1 | 情報 | `StandardFloatMathResponse.roundedBits` の特殊値の枝、`squareRoot` の NaN | floor・ceiling・round は、特殊値の入力のビット列をそのまま返す。固定 Rust（この機）は signaling NaN を quiet にする（0x7ff4000000000001 の floor は 0x7ffc000000000001）。言語に Float のビット列を観測する API はなく（`prelude/stdlib/` に Bits の API はない）、NaN の表記は常に `NaN` なので、観測できる差はない。NaN の narrow/widen だけを Rust の payload に合わせた方針とは扱いが揃っていない | 特殊値の枝の docstring に「NaN の payload は観測できない値として扱い、Rust の quiet 化を写さない」と書くか、quiet bit を立てる | 実行で確定 |
| 情報2 | 情報 | `StandardSafeFieldGap` と results.md「getter調査の結論の補足」 | 観点4に、規則の案と代案の評価を書いた。設計者に問う際の材料にする | — | 判断 |
| 情報3 | 情報 | verify-r2.py の `new_leans<=modules` | 再開3がファイルを足した後の作業木では、この照合は失敗する。群末にもう一度実行するときは、再開3のモジュールを `modules-r1.json` に足してから行う | — | 読めば確定 |
| 情報4 | 情報 | results-r1.md（97,241 バイト） | 100 KB の上限まで約3 KB である。これ以上追記しない | — | 読めば確定 |

## 観点ごとの根拠

### 1. 未接続だった179行の通常契約

ordinary-closed-r2.json の179行は、builtin 100（Byte 1・Character 10・七整数幅の表記/解析/Float 変換 21・Float 二幅の丸め等 12・Float/Float32/Decimal の表記と変換 9・String 26・Bytes 13・List 8）、Decimal.fromFloat 1、別名51、その他の core 27 であり、results.md の内訳と一致する。

純粋応答の八モジュールの `response` の言明を読んだ。どれも `BuiltinArgs P B Ψ name sig ts es rs ws a e` を受け、`∃ out, delta … = some out ∧ Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ ∀ i, out ≠ .exit i` を結論する。P・B・Ψ と全ての引数は束縛されていない変数で、F06 の量化（signatures.md「F06：標準行と本体」）と同じである。前提に足しているのは、Option.Some・Option.None の構成子宣言と `DataArity "Option" 1` だけである（Byte と Character は前提なし）。List.contains の署名の admission は `B.sat` の Equality を、List.sort は閉じた13型の `orderedType` を読む。この13型は処理系の `TySet::ORD`（`types/mod.rs`）と一致した。出力の型付けや正常値を欄として受ける前提はない。δ の値は具体的な計算で作り、`Outcome.Typed` は `StandardPureResults` の構成で値から証明している。

Decimal.fromFloat は `fromFloat_parsed` が、同じ bits から作った `floatDecimalParsed bits` を再検査の出口へ渡すことを等号で示す。RV-L40.d の情報R1（解析結果が Float のビット列と結び付いていない）は、これで解消した。`floatDecimalParsed` は処理系の `float_decimal`（`decimal.rs`）と、最短表記の再解析・scale の計算・28桁への一回の丸め・i128 の上限・96 bit の再検査の順序まで一致する。

core の27行は `StandardOrdinaryCoreProgram.declarations_typed`、別名51行は `StandardAliasBodies.declarations_typed` である。どちらも同じ有限の P で `program.defs name = some d` と `d.WellTyped program builtins` を結論する。`builtins` の sig は既存の純粋行の署名の定義（`StandardListResponse.API.signature` など）を参照し、δ の充足を仮定していない。`PublicAPI.all` の名前の列を実行して、27行の API 名と一致することを確かめた。List.fold の helper の Lean の本体は、`.bnt` の `foldFrom` と同じく get → callback → 加算 → 再帰の順である。

鍵の表 `StandardKeyTyping.Table` の欄は、宣言の列・名前の重複なし・`P.cons` の等号・要約の収束の真偽値・`B.sat` の等号であり、すべて具体の表で計算できる。未検査の意味の欄はない。

### 2. 具体計算と処理系の一致

固定 Rust（`rust-toolchain.toml` の 1.98.1）で `<tmp>/rv-l40-e/rs/edges.rs`（`base/prim.rs` の `finite_float_to_text` の写しと、`as`・`floor`・`sqrt`・`parse` を呼ぶ）と `w.rs`（unicode-width 0.2.2 の tables.rs を直接含む）を実行した。その出力を、Lean の定義に対する `decide +kernel` 96件と `#eval` 4件（`edges.lean`・`edges2.lean`）で照合し、全件が一致した。照合した境界は次のとおりである。

- Float の最短表記: 指数 21 と 20 の切替え（`1.0e+21` と `100000000000000000000.0`）、−5 と −6（`0.00001` と `1.0e-6`）、最小の非正規数 `5.0e-324`、最大値、最小の正規数、`-0.0`、−Infinity、NaN、tie の末桁の例（`-165061108685329.63`）。Float32 は `0.1`・`1.0e-45`・最大値・`16777218.0`・最小の正規数。
- 解析: `1e400` が None、`-0` が負の零、`1E5` と `1e+5`、非正規数、`+1`・`1.`・`.5`・`1e`・`NaN` の拒否。整数は `-128`・`128`・`-0`・`+1`・`01`、unsigned の `-0`。
- 変換: 2^53+1 と 2^53+3 の偶数丸め、u64 の最大値、i64 の最小値。narrow の有限値の溢れ（None）、最大値への丸め、非正規数への丸めと零への丸め、signaling NaN の quiet 化。
- 丸め: 0.5・−0.5・−0.3・2.5 の floor/ceiling/round（符号付き零を含む）、`sqrt` の 0.5・2.5・−0.0、負の数の NaN（0x7ff8000000000000）、truncate の 2^63（None）と −2^63。
- String: lines の末尾 LF・単独の CR・CR LF の前の CR、空文字列。split の空の区切り・空の入力・末尾の空片・重なる区切り（`"aaa"` を `"aa"` で分けると `["","a"]`）。trim が FF を除かないこと（`ascii_whitespace` は空白・TAB・LF・CR だけ）。byteSlice の UTF-8 境界と start>stop。語末の Σ（`ΑΣ'Β`・`Α'Σ` などの case-ignorable の扱い）。表示幅は ZWJ の列・国旗・結合文字・VS16・キーキャップ・肌色の修飾・CJK の曖昧幅・TAB の境界。
- Bytes: readSigned の little endian の符号、u64 を超える readUnsigned の None、fromSigned −1、fromUnsigned の溢れ、fromHex の区切りと奇数桁・非 ASCII。

読んで照合したもの: 資源の上限は `MAX_STRING_BYTES` 2^30 と `MAX_LIST_LEN` 2^24、`CheckedLen::check` の `len > limit` と同じ境界である（toHex の2倍・toBinary の8倍・repeat・replace・join・pad の加算を含む）。List.get・take・drop の u32 の境界、List.range の 2^24 要素の上限。List.sort は比較器が NaN を最後に置き、NaN 同士と符号付き零を同順位とし、Decimal を数で比べ、stable な merge sort である（Rust は `sort_by`）。List.contains の Decimal 等値は scale を無視し、`runtime/equal.rs` の `cmp_num` と合う。Decimal の parse・toString は `parse_literal`・`to_text` と、u8 の scale・28桁・96 bit の検査まで一致する。Character の ASCII 二判定は `is_ascii_digit` と `ascii_whitespace` に合う。

Unicode の表の再生成: gen-character-r2.py と gen-string-tables-r2.py を `<tmp>/rv-l40-e/regen/` へ写し、書き出し先だけを一時領域へ替えて実行した。StandardCharacterData.lean・StandardStringTables.lean・幅の状態219本の計221ファイルは、作業木のファイルとバイト単位で一致した。character-data-r2.json は、生成器自身のハッシュを除いて一致した。入力の識別（rustc の版、unicode-width 0.2.2 の tables.rs の SHA-256、生の出力の大きさと SHA-256）は JSON にある。表示幅の生成器は crate の非公開の `width_in_str` を使う。一方、処理系は公開の `UnicodeWidthStr::width` を使う。tables.rs の `str_width` は同じ `width_in_str` の右からの畳み込みであり、Lean の `foldr` と境界での状態の初期化も合う。

### 3. 初回と再開1のモジュール

- FiniteStepPreservation: `step_preserved`・`steps_preserved` の前提は、`P.WellFormed`・`P.WellTyped B`・`P.EffectsOk B`・`B.CoreAssumptions P`・`σ.Valid` と元の `StateTyE` である。旧の主定理 `Release/Theorems.lean` の `preservation` も `hdecl : P.EffectsOk B` を持つ。したがって `EffectsOk` は、主な保存の前提を強めても弱めてもいない。drop/release の四葉（HandlerPreservation）が元からこの前提を要する。結論は同じ σ・Eb の `StateTyE` であり、新しい欄はない。`concrete_finite_preservation` の読者は、効果と操作の表が空のプログラムで `EffectsOk` を計算し、mark の一歩に適用する。前提が充足可能であることだけを示す。
- StandardCollections: `countReply_normal`・`countReply_stop` は、正常値が数学上の個数に等しいことと max64 を超えるときの停止を同値で示す。非負を有限幅の上限へ置き換えていない（L40.21 の基準）。
- StandardKeySummary・StandardKeySound: `key_table_sound`・`key_map_normal` は具体の `Table` と `VarianceValid` から鍵の観測と正規化の存在を結論する（L40.22）。
- StandardRecordFields・StandardDecodeComparison・StandardDecodeBodies: `postprocess_row_typed` は具体の P・B で `BodyTyped` を示す。Error と Raw の二つの実行の補題がある（L40.25）。
- StandardSafeContracts は、群 A の `l40/a/safe-contracts.lean` と import の行を除いて同一である。StandardSafeAnnotations・StandardSafeBodies・StandardSafeSlice の言明は、19行の注釈と、安全な入口のうち getter 以外の本体の `Def.WellTyped`・`%List.slice` の応答である（L40.26）。06〜14 は未完のまま区別されている。
- StandardHigherPositions の各 `*_checked` は、任意の P・B・Ψ についての受理と拒否の対照である（L40.27）。

### 4. getter 06〜14 の結論の独立な確認

`StandardSafeFieldGap.missing_field_equality` は、実際の腕の文脈 `Γ.facts ++ pathFacts …` から欄の等号 `var 0 = field(minimum, var 1)` を含意できないことを、反モデルで示す。反モデルは、束縛を 7 とし、照合値の三つの欄を 0 とするものである。`#print axioms` は許可された三公理だけだった。

独立に、規則（`Refinement/Typing.lean` の `HasTypeArmsQ.plain/guarded`・`V_Refine`・`P_Con`、`PathFacts.lean`）から一般の形で確かめた。腕の本体の文脈の事実は次の三つだけである。

1. 束縛の型 δ の篩。δ は `P_Con` が構成子宣言の欄型から作るので、照合値を参照できない。
2. `pathFacts obs (matchedTests alts)`。`patternTest?` は根のパターンだけを見て、構成子・リテラル・範囲・空/非空の検査を返す。欄の値には触れない。
3. 外側の Φ（持ち上げたもの）。

束縛変数を参照する事実は 1 だけである。したがって、どの導出の文脈でも、照合値の観測を固定したまま束縛変数の値を自由に選ぶモデルが残る。`Entails` は健全なので、欄の等号はどの導出でも出ない。値の構文にも欄の射影はない（`Val.toTerm?` が `Term.field` を作る値はない）ので、本体の書き方を変えても同じである。反モデルは一つの文脈の反証だが、この一般化により、規則を変えずに閉じる経路はないと判断する。同じ理由で、利用者が書く `match r { C(m, _, _) -> m }` も、欄の等号の篩を持つ型を得られない。

規則を足す場合の素描を示す。

- 足す規則: `HasTypeArmsQ.plain/guarded` の腕の事実に `fieldFacts obs alts` を加える。対象は、obs が `some t` で alts が構成子パターン `C(p0,…)` の一つだけの場合とする。位置 j が `.var` で、束縛の番号が k の欄について、`.eq (.var k) (.field ⟨d, C, j, sort⟩ (t の持ち上げ))` を加える。巣のパターンは欄の項を入れ子にする。
- 要る前提: 欄型が観測できる sort を持つこと（関数の欄など、観測が `none` の欄は除く）。`FieldRef.Declared` を得るための構成子の事実（同じ腕の `constructorIs` が与える）。`FactsWF` が新しい事実を受理すること。
- 要る前提（続き）: 束縛の順は `AltsTy` の `List.Perm` で入れ替わるので、事実を作るには実際の束縛の順を使う。or パターンは全ての alt に共通する事実だけにするか、対象外とする。
- 主な定理の証明への影響: 主な十言明の字面は変えずに済む。ただし型付けの関係が広がる。そのため、照合の歩み（MatchStateLeaves・MatchFacts・MatchPaths）で、代入した欄の値について新しい事実が真であることを示す義務が新しく生じる。値の観測の slot と `field` の評価の一致が要る。
- 構造の補題への追随: 移動・置換・型置換・閉包・narrowing・捕捉・legacy の埋め込みの各相互帰納（TypingShift・SubstTyping・TypeSubstTyping・CloseTyping・Narrowing・CaptureRegularity・LegacyArmEmbedding など。`pathFacts` を参照する既存のファイルは約20本）に、`fieldFacts` と移動・置換の可換性の補題を足す。`pathFacts` の三つの補題と同じ形になる見込みである。所要は測っていない。

代案の、精密な getter を純粋な δ として直接検証する案を評価する。Lean の側は既存の規則で閉じる見込みがある。`BuiltinArgs` の逆転で照合値は閉じた data の値になり、結果の singleton は閉じた評価で含意できるためである。ただし信頼の境界が三つの点で変わる。

1. 9行の実装の選択が core から pure に変わる。これは群 A で固定した Row と安全な19行の変更にあたる。
2. 処理系の getter は `.bnt` の自動 getter（core 本体）なので、Lean の δ と処理系の本体の一致が証明から外れる。一致は R50 の交換による照合に移る。
3. 利用者が書く record の照合には効かない。標準の9本だけが精密な型を得る。

言語の機能として欄の等号を使わせるなら規則の追加が要る。標準の9本だけなら δ の案が軽い。どちらも設計者の判断の対象である。

### 5. 固定したものの不変

`git diff --stat 548d3fd9 -- formal/` は `formal/Benitoite.lean` の import の追加だけを示し、既存の Lean ファイルの変更はない。群 E の新しいモジュール268本のソースの SHA-256 は、verified-r2-modules-part-01/02.json と全件一致した。再開2の終了の後に作業木で変わった群 E のファイルは、再開3の新しいファイルだけである。安全な19行は `l40/a/safe-contracts.lean` と同一（観点3）であり、`StandardSafe.fixed_body_contracts` が登録の tel を固定する。StandardContracts・Typing・Semantics などの既存のモジュールは変わっていない。

### 6. 手順の逸脱と記録の検査

command-deviations-r1.json の対象付き `lake build` の23回は再開1の .26 の途中のものである。その後の既定の `lake build`（r1-u28-final-default01、再開2の r2-final-build）は対象も option もなく終了0なので、結果には影響しない。checks-r2*.json の `lake build` は全て引数なしで、`lake env lean` は全て `-M 12288` である（verify-r2.py も照合している）。

公理監査の初回（r2-final-axioms）は、Lean の本体が終了0の後、StandardOrdinaryCoreProgram の宣言名の記録が 101,195 バイトで上限を超え、後処理で終了1になった。二回目（r2-final-axioms-records）は `--reuse-completed` で同じ生出力（15,332,334 バイト、SHA-256 `17327edb…`）を読み、記録を250件ずつ五つに分けた。audit-summary-r2-final.json の公理の組合せの件数の和は 77,211 で、宣言数と一致する。許可した三公理以外の組合せはない。本レビューでは全体の監査を再実行していない。再開3のモジュールが既定の import に入りつつあり、同じ集合を再現できないためである。代わりに、主な定理7件（三つの純粋応答の `table_response`、`missing_field_equality`、`steps_preserved`、二つの `declarations_typed`）の `#print axioms` を確かめ、許可した三公理だけだった。新しいファイルに `sorry`・`axiom`・`native_decide`・`implemented_by`・`#eval` はない（`opaque` の語は構成子の名前だけ）。

verify-r2.py の照合の範囲は軽1のとおりである。証拠名の存在と API 名の一致は、本レビューが外から確かめた。

### 7. 記録

`l40/e/` の各ファイルは 100 KB 以下である（最大は results-r1.md の 97,241 バイト）。手元の絶対パスは verify 系の Python の検査の正規表現の中だけにある。docs/todo へのリンクはない。`private/` の語は Lean の private 宣言を指す用法だけである。

## 実行した検査

| 検査 | 内容 | 結果 |
|---|---|---|
| 境界の照合（数値） | `<tmp>/rv-l40-e/edges.lean`（最短表記・解析・縮小・丸め・平方根・整数の解析と Float 変換の `decide +kernel` 54件、NaN・truncate の `#eval` 4件、`#print axioms` 3件）。期待値は `<tmp>/rv-l40-e/rs/edges.rs` を固定 rustc 1.98.1 で実行した出力 | 終了0、外側1.11秒、最大常駐量 1,624,555,520 バイト |
| 境界の照合（String・Bytes） | `<tmp>/rv-l40-e/edges2.lean`（表示幅・語末の Σ・lines・split・trim・byteSlice・Bytes の読み書きと解析の `decide +kernel` 42件）。期待値は `w.rs` と処理系のソースから | 終了0（自分の書いた一件の構文の誤りを直して再実行） |
| 名前と公理 | `<tmp>/rv-l40-e/names.lean`（core 27行・整数表記21行・Float 丸め12行の名前の列、四つの主な定理の公理） | 終了0、名前は API と一致、許可三公理だけ |
| 主な言明 | `<tmp>/rv-l40-e/checks.lean`（初回と再開1の主な定理の `#check`） | 言明を確認 |
| 表の再生成 | 二つの生成器を一時領域へ写して書出し先だけを替えて実行 | 221ファイルがバイト単位で一致 |
| 記録の照合 | 証拠名49件と宣言記録、268モジュールの SHA-256、公理の組合せの件数の和、179行の内訳、r1 と r2 の pending の差 | 全件一致 |

## 取りまとめの追記

- 軽1・軽2・情報1・情報3・情報4は、担当の再開4で処置した（l40/e/results.md の再開4の表）。軽3は言明を変えず、R50 の交換で照合する項目として申し送りと obligations.md に名指した。
- 観点4の結論（型付けの規則を変えずに精密 getter 06〜14 を閉じる経路はない）を受け、取りまとめが設計者に問うた。設計者は 2026-11-04 に、照合の腕に欄の等号を足す規則と、map・filter を head・tail で書き換える方式を選んだ（plan.md の同日の設計者の決定）。再開5の試行と再開6の本番化で、9行と正常篩の7公開行を閉じた。再開6は RV-L40.e6 でレビューする。
- 規則の出典は取りまとめが一次資料で確かめ（l40/e/sources-match-rule.md）、01-12 の規則の理由の欄に添えた。
