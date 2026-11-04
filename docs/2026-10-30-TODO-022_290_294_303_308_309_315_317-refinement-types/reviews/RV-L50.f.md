# RV-L50.f: L50 群 F（L50.26〜.30）の独立レビュー

2026-11-04。対象はブランチ `m014/l50.f` の未コミットの作業木で、基準は `57d27892e00cfa4f95c6351f4b35567614e763aa`（HEAD と一致）である。見たものは次のとおりである。
- 本番の変更5ファイル: `git diff 57d27892 -- formal docs/design` で追加306行・削除2行。削除の2行は 07-04 の表の2行の書き換えで、Lean の削除は0行である。
- 新規4モジュール: `ScopeValueDelta`・`RequestValueDelta`・`ScopeResponse`・`ScopeConstraintInstances`。
- 根の import、01-12 と 07-04 の写し、`l50/f/` の記録。

読んだもの:
- 依頼と報告: 担当への依頼、担当の報告。
- `l50/detail.md`: 第3節 F03・F04・F05・F07・F09、第4節の ValueAssumptions・TypeAssumptions の行、第5節の L50.26〜.30 と群 F の完了条件、第8節の在庫、第11節の後段へ渡す名前。
- `l50/f/`: results.md・obligations.md・actual-signatures.md・contracts.lean・audit-summary.json・verification.json。
- 前の群のレビュー: `reviews/RV-L50.c.md`・`RV-L50.e.md`（取りまとめの追記を含む）の群 F への申し送り。

Lean で読んだもの:
- 新規4モジュールの全文。
- `ModelConstraints.lean` の全文（追加分と既存の対照の例）、`EffectTargets.lean` の追加分。
- `SubstitutionContracts.lean` の `ValueAssumptions`・`TypeAssumptions`、`BuiltinResponse.lean` の `ResponseAssumptions`。
- `Adequate.lean` の `Val.Adequate`・`AdequateResult`、`TypeRenaming.lean` の `TypeParamRenaming`、`Admissible.lean` の `SatAll`。
- `ScopeSignatures.lean` の `builtins`・`admitsR`・`pureIn`、`AtInput.lean` の `splitChars`・`splitText`・`parseAtInput`、`ModelHttp` の `valueRun`、`StandardContracts.lean` の `normal_reply_facts`。
- 旧 `Release/EffectCover.lean` の `Eff.allows_bind_comp`。

処理系で読んだもの: `builtins/funcs/scope.rs`（全文）、`builtins/funcs/http_client/checked_request.rs` の `request_value`・`retained_request`・`check` の成功の枝・三つの組み込みの関数、`builtins/checked_scope.rs` の `check_path`、`types/scope.rs` の `Path::parse`。

git の操作（読み取りを除く）、既存のファイルの変更、`lake build`、cargo の実行はしていない。Lean の検査は `formal/` を作業ディレクトリに `lake env lean -M 12288` で行い、確かめのファイルは `<tmp>/rv-l50-f/` に置いた。

## 結論

**可**（重0・中0・軽2・情報7）。

完了の判定は満たす。主な点は次のとおりである。
- 射影と拡大の四つの δ は、型付き入力の全場合で処理系と同じ値を返す。再解決や default への置き換えはない。
- 純粋6行の `ScopeResponse.response` は、任意の P・B・Ψ と元の全 `BuiltinArgs` を量化する。結論は応答の存在・非 exit・`Outcome.Typed`・全有効 σ の `AdequateResult`・正常値の Ground である。
- 八つの保存則は、任意の要約表 S・任意の制約（非空を含む）・任意の型と列を量化する。
- `allows_bind_comp` は前提のない全入力の同値である。

処置を勧める点は記録と写しの正確さの2件だけで、完了の判定を左右しない。

| # | 重さ | 場所 | 問題 | 修正案 | 根拠の種類 |
|---|---|---|---|---|---|
| 軽1 | 軽 | `ScopeValueDelta.lean` の `pathValueRun`（47行）、results.md の「射影と拡大の δ」の表（38行〜）、01-12 の 4026行 | 処理系とパス射影の値が一致する根拠がない。処理系の `path_in_result` は、検査した入力の String を PathIn の欄にそのまま残し、`path_in_value` はその String を返す。Lean は保持した Word の成分を `/` で結び、先頭に `/` を付けた String を作る。二つが一致するには、`parseAtInput .path` が絶対形として受理した `s` と得た `w` の間で `"/" ++ String.intercalate "/" w = s` が成り立つ必要がある。`splitChars` の定義から読めばこの往復は成り立つ。受理する字面も、空の成分・`.`・`..` を拒否する点で `Path::parse` と同じである（検査2の4例）。しかし本番にも記録にも往復の補題や記述がない。results.md の表の列「同じ具体の処理」は、Lean の中で checked と checkedAt が同じ値になることしか示さず、処理系と同じ値であることは示さない | 次のどちらかを行う。<br>・往復の補題を `ScopeValueDelta` に置く。形は `parseAtInput .path (.const (.string s)) = some (.absolute (.path w)) → pathValueRun [.checked (.path w)] = .val (.const (.string s))`。<br>・results.md に、処理系は入力の String を返すこと、一致は往復に依ること、確かめは R 段の比較に送ることを一文で書く。<br>checkedAt の解決後のパスは処理系にまだないので、これも同じ文で書く | 差の存在は読めば確定。小さな入力での一致は実行で確定（検査2）。全入力の往復は判断 |
| 軽2 | 軽 | 07-04 の対応表の `ModelConstraints・ScopeConstraintInstances` の行（973行） | 行を書き換えた結果、本番に残っている宣言の説明が二つ消えた。一つは `sat_bind_values`・`admits_bind_values` の「型変数の像を変えない全置換での sat と admits の同値」である。もう一つは、値の改名・値の置換・非空制約・型像の衝突の対照の例（`ModelConstraints.lean` 296〜338行の例）である。新しい八条件の説明だけが残る | 消えた二つの記述を、新しい八条件の記述と並べて戻す | 読めば確定 |
| 情報1 | 情報 | `ScopeResponse.adequate_externalRef`・`adequate_externalHandle`・`adequate_scopePattern`、01-12 の該当の段落、results.md 55行 | 三つは `intro σ _ _; trivial` で閉じる。根拠は `Val.Adequate` の既定の枝 `| _ => True` である。results.md と 01-12 はこれを「既定の True の枝による自明な性質」「保存した入力の再帰的な適格性を証明するものではない」と明記していて、記述は正直である。`leaves_unobserved` の主張も正しい。三つの構文で `toTerm?` は `none` である。全てのパターンで束縛列の項観測は等しく、引数を変えた二つの実例どうしも推移律で区別されない。`Val.target?` も三つの構文で `none` である。ただし観測は `toTerm?`・`matchVal`・`target?` の範囲で確かめたもので、これ以外の観測（等値の比較の組み込みの関数など）は今回の主張に含まれない | 不要 | 読めば確定 |
| 情報2 | 情報 | `EffectTargets.lean` の `Eff.allows_bind_comp` | 言明は全ての θ・φ・e・σ・κ・l・t について前提のない同値で、三つの経路を持つ。<br>・名前付きの原子に二段の範囲像を順に適用する。<br>・最初の行像を二段目で読む。<br>・`θ.rows.length ≤ i` の行変数は二段目の行像を読む。<br>旧 `Release` の言明は「二段の bind」と「合成した一段の環境 `θ.compose φ` の bind」の許容の同値だった。新しい形は合成の環境を作らず、二段の bind の許容を e の原子で特徴付ける。二段の bind の許容を読む読者はこの同値でどの方向にも書き換えられるので、目的は満たす。一段の環境そのものを要する読者が後で現れたら、そのとき合成を定義する | 不要 | 判断 |
| 情報3 | 情報 | `RequestDelta.valueDelta` が使う既存の `ModelHttp.valueRun` | 型の付かない入力（保持形でない値、`groundVal` が偽の要求）に、Lean は default の要求の値を返す。処理系は `Stop::Internal` を返す。`retained_request` は、型付きの全入力で default の枝に到達しないことを示す。違いは型付けで除かれる入力に限られ、群 F の完了の判定には影響しない | 不要 | 読めば確定 |
| 情報4 | 情報 | detail.md の L50.28 の行「正常値のfactsをF04(旧L40)へ接続」 | 純粋6行の署名は `pureIn` で、shape は `.untargeted` である。そのため F04 の `ShapeOk.single_target` の対象にならない。担当は「F04」を L40 の正常応答の facts と読み、次の二つへ接続した。<br>・`normal_facts`（CoreAssumptions なし）と、既存 `normal_reply_facts` の適用例。<br>・`target_member_interpret` の適用例。<br>この解釈は妥当である | 取りまとめが detail の表記を後で揃えるかを決める | 読めば確定 |
| 情報5 | 情報 | results.md 47行、actual-signatures.md | L60 へ渡す署名は、単独の表の `table_response` ではない。任意の P・B についての `ScopeResponse.response` と、四つの射影・拡大の `response` である。results.md がこれを明記している。actual-signatures.md は暗黙の引数を含む33の型を保存していて、`response`（145行〜）と `delta_typed`（173行〜）を含む | 不要 | 読めば確定 |
| 情報6 | 情報 | results.md の単位の時刻 | 群 F の外側の所要は合計26分00秒である。見込みは4時間5分〜8時間で、L50.29 は31秒だった。results.md は外挿をせず、能動時間と待ちを分離していないことも書いている。L50.29 の4件の言明は既存の `carrier_rawBind_values`・`sat_bind_values` からの1〜3行の証明なので、短さは不自然でない | 不要 | 読めば確定 |
| 情報7 | 情報 | 既存の定義・言明・公理 | `ModelConstraints`・`EffectTargets` への変更は追加だけである。追加したのは補題、`private def renameTypesEnv`（型の改名を bind として読む補助）、`TypeShiftContracts` の import である。既存の行の削除・変更はない。`ValueAssumptions`・`TypeAssumptions`・`ResponseAssumptions`・`Typing.lean`・主な十言明のファイルは差分にない。`ScopeSignatures.substitutionAssumptions` は既存の構造体の欄の型のまま構成していて、前提を強めていない。モデルの側の定理は、注釈の前提も ξ の単調性も要求しない強い形である。`#print axioms` の10件はいずれも `propext`・`Classical.choice`・`Quot.sound` の範囲内だった（`leaves_unobserved` は `propext` だけ）。担当の168宣言の監査は引用し、再実行していない | 不要 | 実行で確定（検査1） |

## 観点ごとの根拠

### 1. 完了の判定

- **パスの射影と拡大**（L50.26）:
  - `path_target` は `canonical_held` の四形を全て場合分けする。opaque 定数と `checkedRequest` は `valKind` の矛盾で除く。`checked` と `checkedAt` の plain の形からはパスの対象を取り出す。`checkedAt` の request の形も `valKind` で除く。
  - `pathValueRun` は保持値の `target?` だけを読み、snapshot や起点を読まない。再解決はない。
  - `widenRun` は `[v]` に `.val v` を返す。処理系の `widen_path_in` も、被覆を確かめた後に同じ値を返す。
  - 型は `widen_opaque` と被覆から広げる。被覆は全 Top の枝か `B.admitsR` の被覆から得る。
  - 処理系との値の一致は軽1のとおりで、根拠の記述が欠けている。
- **要求の射影と拡大**（L50.27）:
  - `retained_request` は四形を全て扱う。`checked` と、`checkedAt` の request が none の形は、既存の `checked_without_request`・`checkedAt_without_request` で除く。残る二つの保持形から、同じ req・型・`groundVal`・`reqTarget` を返す。
  - 処理系の `request_value` は保持レコードの第0欄（元の要求のレコード）を返し、`widen_request_in` は同じ値を返す。Lean の `valueRun` と `widenRun` はこれと同じ値を返す。default の枝の扱いは情報3のとおりである。
- **純粋6行**（L50.28）:
  - `response` は `entries.lookup` の16行を全て場合分けし、純粋でない10行を kind の矛盾で除く。
  - 6行は、群 E の二つの `response` と今回の四つの `response` へ振り分ける。前提は表についての事実（`valKind`・`valContent`・拡大の被覆）と `HasHttp P` だけである。`delta_typed` は、共通表についてこれらを定義から供給する。
  - `delta_typed` の結論は `ResponseAssumptions.delta_typed` の欄の形と一致する。これは contracts.lean の第1例でも確かめられている。
  - `outcome_typed` は δ の決定性から、実際の全応答を扱う。`ground` は全正常値を扱う。
  - `Outcome.err` は `pathValueRun` の malformed な列に残り、例がある。
- **八つの保存則**（L50.29・.30）:
  - 値の4件は、骨格の `carrier` が値の改名・値の代入で変わらないことから、注釈の前提なしに同値で成り立つ。
  - `sat_renameTypes` は `TypeParamRenaming` だけを前提とし、ρ の単射性を要求しない。ρ を定数の0にした適用が型検査を通ることを検査2で確かめた。
  - `sat_subst` は、`satisfies_bind`・`satArgs_bind` の相互の帰納で、型の構造全体を辿る。帰納は data の依存位置、List・Map・Set の要素、篩の型（述語は読まない）を含む。型変数は三つに分ける。
    - `C1` に残る位置。
    - `C0` の像の位置: 閉じた像を `shiftTypes_of_wf_zero` で読む。
    - 文脈の外: 元の sat の成功が偽になるので除く。
  - 行像 `es` は任意で、`carrier` は行を読まない。したがって Fail の列の長さや重複は判定に入らない。
  - 非空制約は、任意の要約表 S と任意の `TParam` を量化して扱う。共通表の16行は全て型パラメータを持たない（`pureIn`・`ioIn` の tparams は空）ので、表の `admits` の保存は個数の照合（`admits_iff_count`）で足りる。非空制約の場合は一般の定理と既存の対照の例が受け持つ。
  - `sat_unconstrained` は F09 の形（`t.WF 0 0 0` を前提とする）より強く、任意の型について成り立つ。`admits_sat` は F09 の形と一致する。
- **前提**: 空疎な前提、具体例だけの閉鎖、一部の場合だけの閉鎖は見つからなかった。各前提は共通表の `delta_typed`・`substitutionAssumptions` で実際に満たされていて、充足可能である。

### 2. 在庫の最後の1件

情報2のとおりである。`allows_bind_comp` は全入力・前提なしの同値で、既定ビルドに行像の経路を読む適用例がある。群 B〜E の記録では、27目的のうち26件が完了し、残りはこの1件だった。したがって在庫の残件は0になる。

### 3. 別枠の結果の葉

情報1のとおりである。自明であることは記録・写しの両方に明記されている。外部呼出しの応答の三条件を L60 に残すことも書かれている。

### 4. 既存の定義・言明・公理

情報7のとおりである。

### 5. L60 へ渡す署名

情報5のとおりである。

### 6. 設計書の写しと記録

- **写し**: 01-12 の追加3段落と 07-04 の追加2段落・表の2行は、本番の宣言名・前提・結論と一致する。不足は軽1（処理系との往復）と軽2（07-04 の行で消えた記述）である。経緯の文や工程の ID はない。
- **記録の大きさ**: `l50/f/` の最大のファイルは initial-manifest-part-02.json の67,654バイトで、全体は約259 KB である。
- **禁止の参照**: 手元の絶対パス・`private/` の内容・docs/todo へのリンクは0件だった。照合の正規表現（verify.py 110〜111行）と、results.md の「private/生成」の語は検出から除いた。

## 実行した検査

| # | 検査 | 結果 |
|---|---|---|
| 1 | `<tmp>/rv-l50-f/check1.lean` で `#print axioms` を10件に実行した。対象は `ScopeResponse.response`・`delta_typed`・`leaves_unobserved`、`ScopeDelta.pathInValue_response`、`RequestDelta.retained_request`、`ModelConstraints.sat_subst`・`sat_renameTypes`、`ScopeSignatures.substitutionAssumptions`・`admits_sat`、`Eff.allows_bind_comp` | 全て `propext`・`Classical.choice`・`Quot.sound` の範囲内（情報7） |
| 2 | 同じファイルで次を確かめた。<br>・`parseAtInput .path` が `"/data/x"` を `.absolute (.path ["data","x"])` にすること（`decide +kernel`）。<br>・`pathValueRun` が `["data","x"]` と `[]` から `"/data/x"` と `"/"` を返すこと。<br>・`"/data/"` と `"/a//b"` を拒否すること（`decide +kernel`）。<br>・非単射の ρ（定数の0）で `sat_renameTypes` を適用できること。<br>・`ModelHttp.valueRun []` が default を返すこと（`rfl`） | 全て通る（軽1、情報3） |

最初の実行では、`Outcome` に `DecidableEq` がないため、`match` を含む等号を `decide` で示せず失敗した。等号を `parseAtInput` の値と `pathValueRun` の値の二つに分けて再実行した（各回の外側の時間は約0.8秒）。大きな具体値を作る評価はしていない。

## 取りまとめの追記

- 軽1は、R 段の比較へ送らずに、担当の再開1で往復の補題 `pathValueRun_parseAtInput` を全入力で証明して処置した（l50/f/results.md の再開1。補助は AtInput.lean への追加で、既存の行の削除はない）。軽2も担当の再開1で処置した。情報1〜7は処置しない。
- 情報4（detail の「F04(旧L40)へ接続」の表記）は、担当の読み（L40 の正常応答の facts への接続）で足りるので、detail.md は改めない。
- 群 F の作業末の work は終了0、452.72秒、最大常駐量 2,928,885,760 バイト（篩の部分の生成物を消して再ビルド。l50/f/results.md）。
