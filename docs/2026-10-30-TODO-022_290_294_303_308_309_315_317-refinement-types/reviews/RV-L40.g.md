# RV-L40.g: L40 群 G（L40.36〜.38・.40、再開1・再開2）と L40 段末の資料の独立レビュー

2026-11-04。対象はブランチ `m014/l40.g` の未コミットの作業木、基準 `fcde6fe2`（san_benito の先端）。再開2の新規の Lean 8本（StandardOperatorArguments・StandardFloatOperatorResponse・StandardDecimalOperatorResponse・StandardStringOperatorResponse・StandardIntegerOperatorResponse・StandardOperatorResponse・StandardStructuralEqualityResponse・StandardDecodeConnection）は全文を読んだ。既存の変更（StandardDecodeBodies・StandardEqualityResponse・`formal/Benitoite.lean`・01-12・07-04・plan・effort-ledger）は `git diff fcde6fe2` で読んだ。段末の資料は `l40/stage-results.md`・`axioms.lean`・`audit.py`、`l40/g/` の results.md（初回・再開1・再開2）・resume2-sources.md・resume2-operators.json・additional-unresolved.json・audit-summary.json・obligations.md・handoffs.md・置き換え後の resume1-obstruction.lean を読んだ。

根拠として、plan.md「計画の変更と取りまとめへの確認点」の 2026-11-03 以降の L40 の項、README「設計者の決定」、`l40/detail.md` の L40.25・.28・.36〜.40 の行と第7節の O022・O034・O062・O065・O135・O144、RV-L40.e（軽2・軽3と取りまとめの追記）を読んだ。処理系は `builtins/funcs/operators.rs`・`operators/{signed,unsigned,float32}.rs`・`base/decimal.rs`・`runtime/equal.rs`・`runtime/heap/ctx.rs`（`alloc_str_parts`・`checked_parts_len`）・`runtime/heap/build.rs`（`CheckedLen::check`）を読んだ。形は RV-L30.l に合わせた。確かめの Lean と Rust は `<tmp>/rv-l40-stage/` に置き、リポジトリのファイルはこの記録のほかに変えていない。

## 総合判定

**条件付き可**（重0・中2・軽4、情報4）。中2件を処置すれば、L40 段末の受け入れの資料として可とする。

再開2の δ は処理系の算法を正しく写している。Decimal は `base/decimal.rs` の `checked_div` の0〜28桁のループ（打切り・最後の候補・途中の overflow を候補へ戻さない）、`fit` の降順 scale と元の係数からの丸め直し、`round_magnitude` の HalfToEven、`make` の保存と表現可能性、`add_signed` の符号の分岐と行ごとに一致し、境界を含む20例で Lean の δ と Rust の実行結果が全件一致した。String の連結の上限（`len > 1073741824` で拒否）と UTF-8 バイト列の辞書順、整数 div/mod の群 F2 の `integerBinaryDelta` の再利用、Float の `Float.Model`・`Float32.Model` の使い方（群 E の squareRoot と同じ模型）も確かめた。構造値の `%eq/%ne` は失敗を false へ置き換えておらず、NaN・±0・Decimal の数値の等しさは `values_equal` と一致する。34実名の重複なし、新しい公理なし、`#print axioms` は許可の三公理の部分集合だった。

中1は構造値の等号の応答契約が、型の付いた Equality の値で `InternalComparison` が起きないことを含まないことである。処理系ではこの経路は `Stop::Internal`（処理系の不具合）であり、再開1の依頼文の「結果が Boolean」は正常の枝でしか言えていない。中2は段末の資料の「設計者の見直しの対象」の表から、再開2の根拠になった算術 δ の方針（plan 2026-11-04 の最初の項目）が抜けていることである。軽は義務の証拠の割り付け、後段の表への再開2の申し送りの不足、完全名の誤り、古くなった記述と旧反例のファイル名である。主な十言明・型付けの規則・公理・提供範囲に触れる所見はない。

## 群 G と再開2の所見

### 中

#### 中1: 構造値の `%eq/%ne` の契約は、型の付いた入力で `InternalComparison` が起きないことを結論しない（読めば確定。自明性は Lean で確認）

- 場所: `formal/Benitoite/Release/Refinement/StandardStructuralEqualityResponse.lean` の `reply`（11〜15行）・`response`・`table_response`。01-12「`StandardStructuralEqualityResponse` は…」の段落と 07-04 の同じ行、stage-results.md「群G再開2」の表の「構造等号」の行と55行の段落、後段の表の R50 の行（106行）。
- 問題点:
  - `response` の結論は `Outcome.Typed ∧ AdequateResult ∧ 非exit` である。`.err s` はどの `s`・型・値でもこの三条件を満たす（`<tmp>/rv-l40-stage/Vacuous.lean` で `⟨trivial, …, …⟩` が通ることを確認）。そのため、型の付いた二値に対しても `structuralEqual` が `none` を返して `InternalComparison` になる場合を、この定理は排除しない。`reply_normal` も正常の枝が Boolean であることだけを述べる。`structuralEqual` が型の付いた Equality の値で `some` を返すことを述べる定理は、本番の中に見当たらない（`structuralEqual` の参照は定義・`containsResult`・三つの具体例・本モジュールだけ）。
  - 処理系の `values_equal` で同じ失敗に当たるのは `invalid_comparison()`、すなわち `Stop::Internal` である。コメントにも「型検査を通ったプログラムでは起きない」とある。Lean の `.err "InternalComparison"` は言語の実行時の停止として扱われるので、L60・L70 の安全性の定理は、処理系では不具合となる停止を正当な結果として受け入れることになる。
  - 再開1の依頼文の「結果が Boolean で、非 exit であること」のうち、Boolean は正常の枝でしか示されていない。stage-results と 01-12 の「全型付き入力から同じδの応答存在・型・Ground・AdequateResult・非exitを結論する」は字面としては正しいが、「結果が Boolean」の条件を満たしたと読める。
  - 同じ形は群 E の `StandardListRemainingResponse` の整列にもあり、RV-L40.e 軽3（型の付いた入力に malformed の err を返さないこと）で R50 の照合へ申し送った前例がある。ただし、後段の表の R50 の行（106行）は群 E の八モジュールだけを挙げ、`StandardStructuralEqualityResponse` を含まない。31行の文には「全構造等号とmalformed拒否」とあるが、受け手の表から引けない。
- 修正案: 次のどちらかを取りまとめが選ぶ。
  - (a) L40 で閉じる。Equality を満たす T の閉じた型付き値の対について `structuralEqual l r ≠ none`（または `∃ b, … = some b`）を証明し、`response` の結論に「`out = .val (.const (.boolean _))`」を加える。List・data・Bytes・Map・Set の帰納と、`snapshotDepth` の燃料が足りることが要る。
  - (b) 前例どおり R50 へ申し送る。その場合は、後段の表の R50 の行に `StandardStructuralEqualityResponse` を加え、「型の付いた Equality の値で `structuralEqual` が `none` にならないこと。処理系では `Stop::Internal` に当たり、言語の停止ではない」と書く。stage-results の「構造等号」の行と 01-12・07-04 の該当の文に、正常の枝でだけ Boolean を結論し、型の付いた入力で失敗の枝が起きないことは結論しない旨を一文で加える。
  どちらでも主な言明・型付けの規則は変わらない。

### 情報

#### 情報1: Decimal・Float・String・構造等号の δ と処理系の実行の照合（実行で確定）

- Decimal: `base/decimal.rs` を写した単独の Rust（`<tmp>/rv-l40-stage/dec_main.rs`）と、Lean の `calculate` の `#eval` で、次の20例が全件一致した。1/4、1/3、2/3（末尾の HalfToEven）、MAX/3、1/MAX（0E-28）、MAX/0.1（最初の桁で打切り→overflow）、MAX×10^-28/7、1E-28/3・1E-28/2・3E-28/2（scale 28 での偶数への丸め）、MAX+1・MAX+0.5（丸めて上限超え→overflow）、MAX+0.4、(MAX−1)+0.5、MAX×1.0（scale を下げて収める）、MAX×MAX、MAX·10^-28×MAX·10^-28（scale 27）、−MAX−1、2.5/1E-28、0.1/3E-27。ほかに小さい14例を Lean の `decide +kernel` で確かめた（最小 scale・負の0の符号・negate・0除算など）。
- Float: 非 NaN の13例（0.1+0.2、1/0、0/0、±0 の加算、非正規数の積、Float32 の 0.1+0.2・1/3 など）はビット列まで一致した。NaN は既知のとおり異なる。arm64 の Rust では `nan1+1` が入力の payload `0x7ff8000000000001` を保ち、`-nan1` は符号ビットを反転して `0xfff8000000000001` を返す。Lean の模型はどちらも `0x7ff8000000000000` を返す。Float32 も同様（`-0x7fc00001` は Rust `0xffc00001`、Lean `0x7fc00000`）。正準の NaN の負号でも符号ビットが異なる。R50 の照合の項目の具体例として渡す。
- String: `"a"<"ab"`、`"b"<"ab"` が偽、`"é">"z"`、`"Z"<"a"` などが Rust の `&str` の順序と一致する。
- 構造等号: NaN を含むリストの `%eq` は false・`%ne` は true、`0.0` と `-0.0` は等しい、`1.0m` と `1.00m` は等しい、長さの違うリストは false。いずれも `values_equal` と一致する。

#### 情報2: Decimal の δ の、到達しない分岐の扱いの差（読めば確定）

- 場所: `StandardDecimalOperatorResponse.divDigits` の `let candidate ← roundMagnitude q r d`、`calculate` の `.negate`。
- 内容: Rust の `checked_div` は `round_magnitude` が `None` のとき候補を更新せずに続けるが、Lean は計算全体を `none`（DecimalOverflow）にする。直前に `q ≤ limit` と `r < d` が成り立つので `None` は起きず、結果は変わらない。`.negate` の `make` も表現可能な入力では失敗しないが、証明はない。どちらも処置は要らない。R50 で Wide の照合をするときの読み替えの注記として残す。

#### 情報3: O135 の接続の前提と範囲（読めば確定）

- 場所: `StandardDecodeConnection.decodeThen_normal`・`decodeThen_firstReturn`。
- 内容: 返却値 `decoded` の型付けは前提として受け取り、通常 decoder の型付けと保存から導いてはいない。L70 の主定理の合成でこの前提を保存の定理から供給する。`recordProgram` は二つの Integer 欄と一つの全体条件を持つ一つの record の代表であり、任意の record 宣言（欄の数・型・複数の条件）への一般化は生成器の担当である。stage-results と 01-12 の「同じ有限なrecord宣言でのcoreの接続」の書き方は、この範囲と合っている。

## 段末の資料の所見

### 中

#### 中2: 「設計者の見直しの対象」の表に、算術 δ を足した方針が載っていない（読めば確定）

- 場所: `l40/stage-results.md`「J40 の判定と設計者の見直し」の第二の表（86〜93行）。初回の確認点の表の「設計者の見直しの一覧」の行（230行）も同じ。
- 問題点: plan.md の 2026-11-04 の最初の項目（群 G の再開1の停止の後）は「**設計者の見直しの対象**」と明記し、演算子34行を `Float.Model`・`Float32.Model` と処理系の Rust の算法を写した名前付きの δ で閉じる方針を定めた。再開2はこの方針で実装し、31行の文も「算術δ追加の方針を設計者の見直しの対象として渡す」と書く。しかし、見直しの対象と既に決まったものを分ける表には、この行がない。表に載る他の6行（J40-3・E_Lam・core の正常関係・腕の欄の等号と head/tail・%Map.replaceValues・F2 の計画との差）は plan の 2026-11-03 以降の見直しの項目をすべて拾っているので、欠けているのはこの1行だけである。設計者が表で受け入れを判断すると、Lean の Float の模型が NaN を正準化すること（情報1）や、Decimal の算法を Lean 側に写したことが判断の外に落ちる。
- 修正案: 表に「算術 δ の追加、plan 2026-11-04・群G再開2」の行を足す。変更と実用への影響の欄には「演算子34行の δ を Float の標準の模型と処理系の Decimal・String の算法の写しで定める。Float の模型は NaN の payload と符号を正準化し、Rust と一致しない（R50 で照合）。型付けの規則・公開の署名は変えない」と書き、扱いを「取りまとめが採択、設計者の見直しの対象」とする。230行の一覧にも同じ項目を足す。

### 軽

#### 軽1: 六つの義務の行に、関係のない証拠も一律に足され、L60 へ渡す署名も `table_response` を挙げている（読めば確定）

- 場所: `l40/g/obligations.md` の O022・O034・O062・O065・O135・O144 の行。
- 問題点: 6行すべての末尾に、同じ三つ（`StandardOperatorResponse.table_response`・`StandardStructuralEqualityResponse.table_response`・`StandardDecode.decodeThen_normal/decodeThen_firstReturn`）が付いている。O135（同じ P の宣言・不変欄連鎖・全体条件と decode の順）に演算子と構造等号の表は関係せず、O065（C12 の sig_scoped 等を継承した標準の具体署名の形成）に decoder の接続は関係しない。どの証拠がどの義務の「一部」を閉じたのかが読めない。また、`table_response` は `{base with sig := lookup}` で34名（または `%eq/%ne`）だけを持つ単独の表についての言明である。L60 が一つの表へ合成するときに使えるのは任意の P・B についての各 `response` であり、RV-L40.e 軽2 と同じ点である。
- 修正案: 再開2の三件は、O135 へは decoder の接続だけ、O062・O065 へは演算子と構造等号の `response`、O022・O034・O144 へはそれぞれの「一部」の理由に当たるものだけを割り付ける（additional-unresolved.json の旧不足と照らす）。証拠には `StandardOperatorResponse.response`・`StandardStructuralEqualityResponse.response` を併記し、L60 へ渡す署名は `response` であることを O062・O065 の行か後段の表の L60 の行に書く。

#### 軽2: 後段の表に再開2の申し送りの行がない（読めば確定）

- 場所: `l40/stage-results.md`「後段への実署名と申し送り」の表（97〜109行）。
- 問題点: 再開2の申し送りは31行の文と g/results.md にだけあり、受け手ごとの表に行がない。抜けているのは次のとおりである。
  - R50: Float の模型と Rust の f64・f32 の算術と NaN（情報1の payload と符号の具体例）、Decimal の Nat の正確な計算と Rust の `Wide` の256ビットの拒否、String の上限と順序、構造等号と `values_equal`（共有の走査・深さの境界・中1の失敗の枝）。
  - R40: 生成器が通常 decoder の後に同じ後処理を同じ順（lo→hi→全体条件）で置くこと。任意の record 宣言への一般化。後処理を Def として登録して呼ぶ形にするなら、`decodeThen` の let の合成と同じであることの確認。
  - L60: `StandardOperatorResponse.table` と `StandardStructuralEqualityResponse.table` は、それぞれ `sig` を置き換えた単独の表であり、328 API の表との合成は L60 が行うこと。
- 修正案: R50・R40・L60 の各行に上の項目を足すか、「群G再開2の申し送り」の行を足す。

#### 軽3: stage-results.md の完全名の誤り（読めば確定）

- 場所: `l40/stage-results.md` 53行。
- 問題点: `StandardDecodeConnection.decodeThen_normal/decodeThen_firstReturn` と `StandardDecodeBodies.postprocess_all` と書いているが、Lean の名前空間はどちらも `Benitoite.Release.Refinement.StandardDecode` である（`StandardDecode.decodeThen_normal`・`StandardDecode.postprocess_all`）。モジュールの名前を名前空間として書いており、全名の一覧（declarations-part-*.json）や obligations.md の表記と食い違う。
- 修正案: 「`StandardDecode.decodeThen_normal/decodeThen_firstReturn`（StandardDecodeConnection）と `StandardDecode.postprocess_all`（StandardDecodeBodies）」と直す。

#### 軽4: 古くなった記述と、内容を置き換えた旧反例のファイル名（読めば確定）

- 場所: `l40/stage-results.md` 113行・117行、244行。plan.md 2026-11-04 の最初の項目。`l40/g/resume1-obstruction.lean`。
- 問題点:
  - 113行「確定値と宣言一覧は、監査の終了後に追記する」と117行「確定値は作業末に追記する」は、初回の作業中の予告のまま残っている。確定値は「群G再開2」と「初回の段末監査と作業末の検査」の節に既にある。
  - 244行と plan の項目は `resume1-obstruction.lean` を「Leanの反例」として引くが、このファイルは再開2で新しい δ の応答存在を示す対照（`float_add_present`・`decimal_add_present`）に置き換わった。旧内容の大きさと SHA-256 は g/results.md 177行にあるが、リンク先を開くと反例ではない。ファイル名も内容と合わない。
- 修正案: 113行・117行は、確定値のある節への参照に置き換える。244行には「現在のファイルは再開2で対照へ置き換えた。旧内容の識別は g/results.md「旧反例の置き換え前の識別」」と一文足す。ファイル名を変えるなら（例: `resume2-contrast.lean`）verify-resume2.py の入力と resume1-obstruction-check.json の参照も合わせる。plan は取りまとめの文書なので、取りまとめの判断で同じ注記を足すかを決める。

### 情報

#### 情報4: 64義務・33申し送りの集計と六行の判定（読めば確定。件数は補助の集計で確認）

- obligations.md の64行は、技術50（局所照合44＋再開2で更新6）・継承6・運用3・他段1・共通4で、stage-results の集計と一致する。「一部」と書いた行は残っていない。handoffs.md の33行は今回25・継承3・他段5で一致し、「未完」「一部」の行はない。
- O022・O034・O062・O065・O135・O144 の六行は、いずれも「担当分の局所証拠を照合。…独立レビューと全体の閉鎖は別」とし、残る段（L50・L60・R10b・R40・R50・V10 等）を保っている。閉じていないものを全体の閉鎖としては書いていない。証拠の割り付けは軽1のとおり。
- 共通4行（O016・O027・O084・O118）は独立レビュー・正式RSS・設計者の受け入れを未了として分けている。

## 確認した事項

- **Decimal の写し**: `calculate`・`divide`・`divDigits`・`fit`・`roundMagnitude`・`make` を `base/decimal.rs` の `checked_add/checked_sub/add_signed/checked_mul/checked_div/fit/round_magnitude/make` と行ごとに照らした。桁合わせは `10^(t−s)`（Nat の切り捨ての引き算で Rust の `saturating_sub` と同じ）、最小 scale は `s−t`、29回のループ、`quotient > LIMIT` での打切りと最後の候補、`remainder = 0 ∧ scale ≥ minimum` での即時の返却、候補の `make` の失敗をそのまま overflow にする点（Rust の `?`）、途中の `times_ten`・`add` の溢れを候補へ戻さない点が一致する。`wide` は最終の値だけを 2^256 と比べるが、`Wide::mul`・`times_ten` は単調に増えるので、途中で溢れるのは最終の値が溢れるときに限る。`decimal_error` の写し（0除算を先に区別し、ほかを DecimalOverflow）も一致する。表現可能性は `decimalRepresentable`（|c| ≤ 2^96−1、scale ≤ 28）と `CoefficientModel.save 128` で、Rust の `Decimal::new` と `i128::try_from` に対応する。
- **整数 div/mod**: `StandardIntegerOperatorResponse.delta` は群 F2 の `integerBinaryDelta` を `.intDiv`・`.mod` で呼ぶだけである。実名14件は Rust の `signed.rs`・`unsigned.rs`・`operators.rs` の名前と一致する。
- **Float**: `bits` は `Float.Model`・`Float32.Model` の `ofBits`→演算→`toBits` で、native の `Float` の演算を使わない。群 E の squareRoot と同じ模型である。Rust の `float32.rs` と `operators.rs` は素の `+ − × ÷` と単項の `−` である。
- **String**: Rust の `CheckedLen::check` は `len > limit` で拒否し、`MAX_STRING_BYTES = 1_073_741_824`。Lean は `size_a + size_b ≤ 1073741824` で正常とする。比較の `lessOrEqual = (order ≠ gt)`、`greaterOrEqual = (order ≠ lt)` も正しい。
- **構造等号**: `structuralEqual` は NaN を false、±0 を true、Decimal を数値で比べ、Map の鍵は `decimalNormal` で正規化してから比べる。Float は鍵の型ではない（`keyCode?` が `none`）。範囲の添字を持つ型は等値の型ではない（01-06「等値の型」）。失敗は `InternalComparison` で、false へ置き換えていない。
- **応答契約の量化**: 新しい `response` はすべて任意の `P B Ψ` と原署名の全 `BuiltinArgs` を量化し、群 E の一部のモジュールのような固定のモデルのプログラムへの限定はない。前提は `StandardOperatorArguments.arguments` で原署名から取り出すだけで、強すぎる前提はない。結論は型・Ground・AdequateResult・非 exit で、err の枝は自明に満たす（中1）。
- **O135 の接続**: `decodeThen = .letIn decoder postprocessBody` で、任意の `decoder : Comp` について、同じ let 枠の下の `Steps`（または `FirstReturn`）が返した同じ値を `E_Return` で後処理へ渡し、`postprocess_all` で全ての型付き Result を Error の同じ payload か `checkedRawResult lo hi`（lo→hi→全体の順）へ結ぶ。事象列とストアを保ち、decoder 自身の Stop は `E_ErrPopLet` で同じ理由列のまま外へ出る。`recordProgram.defs` が空のままでも、後処理を Def として呼ばない core の合成としては十分である。生成器全体と全プログラムの宣言収集を後段に残すことは plan の 2026-11-04 の項目（生成器の全実装は R40）と L40.25 の行に合う。L40.25 の完了の判定「通常decode後の欄順/全体条件をcoreの検査列で証明→Error payload/順番を保持」は、代表の record について満たしている。
- **公理の監査**: audit.py の許可は `propext`・`Quot.sound`・`Classical.choice` だけである。audit-summary.json は999モジュール・79,156宣言、新しい公理0。新しい8モジュールはモジュールの一覧と宣言の分割記録に入っており、StandardDecodeBodies に足した `checkedRawResult`・`DecodeResult`・`postprocess_all` も含まれる。`#print axioms` を11件確かめた（下の表）。
- **記録**: `l40/g/` と stage-results.md・axioms.lean・audit.py に 100 KB を超えるファイルはない（100 KB 超は群 D・E の verify 台本だけで、今回の対象外）。手元の絶対パス・`private/` の内容・docs/todo へのリンクはない（`/Users/` の出現は他群の verify 台本の禁止の正規表現だけ）。
- **設計書の写し**: 01-12 と 07-04 の群 G の差分は、本番の宣言名・結論・範囲と一致する。工程の ID（F06）を消した2箇所の書き換えも妥当である。改造の段名・未実装の作業は書いていない。中1の処置 (b) を選ぶ場合は、同じ段落に一文が要る。
- **設計者の見直しの一覧**: plan の 2026-11-03 以降で「設計者の見直しの対象」と書いた項目は、J40-3、L40.15（E_Lam）、L40.23、E 再開2、E 再開6、G 再開1の停止の後の6件である。stage-results の表は G 再開1の停止の後の1件を除いて拾っている（中2）。2026-11-04 の設計者の決定（照合の腕の事実、head/tail）は「決定済み」として区別されている。
- **後段への申し送り**（抜き取り）: RV-L40.e 軽3（malformed の err）は R50 の行に、設計者の決定の head/tail の性能の測定は R40 の行に、%Map.replaceValues の登録は R40 の行にある。再開2の分は軽2のとおり表にない。

## 実行した検査

| 検査 | 内容 | 結果 | 外側の時間 |
|---|---|---|---:|
| `lake env lean -M 12288 <tmp>/rv-l40-stage/Dec.lean` | Decimal の小さい14例の `decide +kernel`、偽の例で検査が働くことの確認、`table_response` の型の印字 | 偽の例だけが期待どおり誤り、ほかは通る | 0.7秒 |
| `lake env lean -M 12288 <tmp>/rv-l40-stage/DecEval.lean` | Decimal の境界20例の `#eval` | Rust と全件一致 | 0.7秒 |
| `rustc --edition 2024 -O dec_main.rs`（`base/decimal.rs` の写し） | 同じ20例を処理系の算法で計算 | 上と一致 | 数秒 |
| `lake env lean -M 12288 <tmp>/rv-l40-stage/FloatEval.lean` と `rustc -O float_main.rs`（arm64） | Float・Float32 の17例のビット列 | 非 NaN の13例は一致、NaN の4例は payload と符号が異なる | 各1秒未満 |
| `lake env lean -M 12288 <tmp>/rv-l40-stage/Misc.lean` | String の7例、34実名の一覧、構造等号の4例、`#print axioms` 9件 | 期待どおり。公理は許可の三公理の部分集合（`entries_unique` は propext だけ） | 0.7秒 |
| `lake env lean -M 12288 <repo>/…/l40/g/resume1-obstruction.lean` | 置き換え後の対照と `#print axioms` 2件 | 終了0、許可の三公理 | 0.7秒 |
| `lake env lean -M 12288 <tmp>/rv-l40-stage/Vacuous.lean` | err の応答が型・値によらず契約の三条件を満たすこと | 通る | 0.7秒 |
| 補助の Python | obligations.md の64行・handoffs.md の33行の分類の集計、記録の大きさ、絶対パスとリンクの検索、監査の一覧への新モジュールの所属 | 上記のとおり | 数秒 |

`#print axioms` を確かめた宣言は `StandardOperatorResponse.table_response`・`entries_unique`、`StandardStructuralEqualityResponse.table_response`、`StandardDecode.decodeThen_normal`・`decodeThen_failed`・`postprocess_all`、`StandardDecimalOperatorResponse.response`、`StandardFloatOperatorResponse.response`、`StandardEqualityResponse.full_arguments`、`StandardResponseContrast.float_add_present`・`decimal_add_present` の11件である。`lake build`・cargo・段末の公理監査の再実行は行っていない。大きな具体値を作る評価はしていない（Decimal の 2^96 前後の係数は `#eval` の任意精度の整数で計算し、`decide` では展開していない）。

## 再レビュー（L40.39）

2026-11-04。対象は担当の応答（`l40/g/review-response.md`、`l40/g/results.md`「再開3（L40.39）」、報告 L40.g-r3）と、処置した箇所だけである。stage-results.md・obligations.md・01-12・07-04 の該当の箇所、`l40/g/resume3-equality-trial.lean`・`resume2-contrast.lean` を読み、Lean で検査した。

### 結論

**可**。中2件・軽4件・情報1〜3件の処置は、いずれも修正案に合っている。新しい所見は情報1件だけである。

### 所見ごとの確認

| 所見 | 処置の確認 | 判定 |
|---|---|---|
| 中1 | (b) を選んだ。部分試行には、深さが正であること、要素の深さが列の深さ以下であること、整数の燃料、子の比較が成功するときの列の比較の存在の4定理がある。`lake env lean -M 12288` で終了0を確かめた。残りは、Equality の型の値から観測の形の対応を作る List・data・Bytes・Map・Set の帰納と、Map の縮約・整列の後の値が元の値側スロットに由来することからの燃料の合成である。既存の鍵の定理（`key_table_sound`）は鍵の型用で Float を含む値に使えず、固定の表を前提とする。これらから、2時間30分〜4時間という見積もりは妥当と判断した（判断）。stage-results の「構造等号」の行と段落、07-04 の表の行と本文、01-12 の本文に、「Boolean を結論するのは正常の枝だけであり、型の付いた Equality の入力で `structuralEqual` が `none` を返す失敗の枝が起きないことは結論しない」が入った。R50 の行には次が入っており、十分である：`StandardStructuralEqualityResponse.response`、処理系では `Stop::Internal` で言語の停止ではないこと、`values_equal` との共有の走査・深さの境界、`snapshotDepth` の燃料の十分性 | 可 |
| 中2 | 見直しの表（103行）と初回の確認点の一覧（243行）に「算術 δ の追加（plan 2026-11-04、群 G 再開2）」が入った。Float の模型による NaN の正準化と Rust との差を書き、扱いは「取りまとめが採択、設計者の見直しの対象」である | 可 |
| 軽1 | O135 は decoder の接続だけ、O062・O065 は演算子と構造等号の `response` だけになった。O022・O034・O144 は三つの証拠を残すが、それぞれに .28／.25 の役割を書いた。これらの行の担当の範囲（.16〜25/28）に合う。証拠は `table_response` から任意の P/B を取る `response` に替わった（obligations.md に `table_response` は残っていない）。L60 の行に、`response` が合成に使う実署名であり、`table`/`table_response` は単独の表であることが書かれた | 可 |
| 軽2 | R50 に2行、R40 に decoder の生成器の1行、L60・L70 の行に追記が入った。修正案の項目（Float の NaN、Decimal の Wide、String、構造等号、生成 decoder の順番・任意の record・Def 登録との同値、単独の表の合成）をすべて含む | 可 |
| 軽3 | 63行は `StandardDecode.decodeThen_normal/decodeThen_firstReturn`（StandardDecodeConnection）と `StandardDecode.postprocess_all`（StandardDecodeBodies）になった | 可 |
| 軽4 | 作業中の予告の2箇所は消えた。対照は `resume2-contrast.lean` に改名され、終了0、`#print axioms` は許可の三公理だけだった。旧名が残るのは results.md の旧内容の識別、`resume1-obstruction-check.json` の履歴のコマンド、verify-resume2.py の「旧名が存在しないこと」の検査、plan.md の取りまとめの注記付きの記述だけで、いずれも履歴か検査として妥当である。257行は、旧反例と現在の対照が異なることを明記した | 可 |
| 情報1〜3 | R50 の行に NaN の具体例と Decimal の到達しない分岐の読み替え、L70 の行に `decoded` の型付けの供給、R40 の行に任意の record への一般化が入った | 可 |
| 情報4 | 処置不要として集計を維持した | 可 |

### 本番の Lean が不変であること

- `git diff fcde6fe2 --stat -- formal/` は前回と同じ3ファイル・212行の追加である。新しい8モジュールと変更した3ファイルの最終の更新時刻は 13:36〜13:54 JST で、初回のレビューの開始（14:05 頃）より前にある。再開3による本番の変更はない（読めば確定）。
- `formal/` の中に `EqualityTrial` や `resume3-equality-trial` への参照はない。部分試行は改造のディレクトリの中にあり、既定の import の外である。名前空間は `Benitoite.Release.Refinement.L40EqualityTrial` で、本番の名前と重ならない。

### 新しい所見

| 番号 | 重さ | 内容 | 修正案 | 根拠の種類 |
|---|---|---|---|---|
| 再情報1 | 情報 | 再レビューの 14:33〜14:40 JST に、このレビュー以外の `lake build` が formal/ で動いていた（14:32 に開始。olean を作り直す途中で、一時は新しいモジュールの olean が存在しなかった）。担当の記録にある群末の既定ビルドは 14:2x に終わっており、その後の別の起動と見られる。終了を待ってから検査したので、検査の結果には影響していない | 取りまとめが自分で起動したビルドなら処置は不要である。そうでなければ、起動元を確かめる | 実行で確定（プロセスと olean の時刻） |

### 実行した検査

| 検査 | 結果 | 外側の時間 |
|---|---|---:|
| `lake env lean -M 12288 <repo>/…/l40/g/resume3-equality-trial.lean` | 終了0。4定理と `#check` 3件 | 1秒未満（並行のビルドの終了待ちに約5分） |
| `lake env lean -M 12288 <repo>/…/l40/g/resume2-contrast.lean` | 終了0。`#print axioms` 2件は許可の三公理 | 1秒未満 |
| 補助の grep・shasum・時刻の確認 | 上記のとおり | 数秒 |

所要は 14:33〜14:41 JST の約8分である。`lake build`・cargo・公理監査の再実行はしていない。

## 取りまとめの追記

- 初回の中1・中2・軽1〜4・情報1〜3は担当の L40.39（l40/g/results.md の再開3、l40/g/review-response.md）で処置し、再レビュー（L40.39）で可とした。中1は L40 での証明を試したうえで、残りの見込み（2時間30分〜4時間）から R50 の照合へ申し送った。前例は RV-L40.e 軽3 である。
- 再情報1の並行の `lake build` は、取りまとめが同じ時刻に起動した段末の work の検査である。
- L40 の段末の work は終了0、456.52秒、最大常駐量 2,931,425,280 バイト（篩の部分の生成物を消して再ビルド。l40/g/results.md）。
- 64義務の L40 の判定を plan.md の義務の表へ写した（設計者の受け入れ待ち）。
