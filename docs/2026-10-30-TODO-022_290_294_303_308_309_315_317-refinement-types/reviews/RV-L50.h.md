# RV-L50.h: L50 群 H（L50.36〜.40）の独立レビュー

2026-11-05。対象はブランチ `m014/l50.h` の未コミットの作業木で、基準は `3ff35eddad3937c3e4ba44144884117af7dc91fe`（HEAD と一致）である。見たものは次のとおりである。
- 本番の変更4ファイル: `git diff 3ff35edd -- formal docs/design` で追加22行・削除0行。`formal/Benitoite.lean` の import 2行、`AtPrepare.lean` の補助定理1本（11行）、01-12 の2段落、07-04 の2段落と表の1行である。
- 新規2モジュール: `Model`（213行）・`ModelTargetsExamples`（177行）。
- `l50/h/` の記録。

読んだもの:
- 依頼と報告: 担当への依頼、担当の報告。
- `l50/detail.md`: 第3節 F09、第4節の三モデルの25条件と L60 に残す欄の表、第5節の L50.36〜.40 と群 H の完了条件、第11節の L60 へ渡す名前。
- `l50/a/model-method.md`、`l50/a/contracts.lean` の F09Model。
- `l50/h/`: results.md・obligations.md・actual-signatures.md・contracts.lean・verification.json・build-check.json・work-check.json。
- 前の群のレビュー: `reviews/RV-L50.g.md`（形を揃えた）と、`RV-L50.a.md` の F09 の照合。

Lean で読んだもの:
- 新規2モジュールの全文。
- `TargetModelConditions.lean` の `ModelScopeConditions`・`ModelScopeConditions.core`。
- `BuiltinResponse.lean` の `ResponseAssumptions`・`TargetAgreement`。
- `ConstraintAssumptions.lean` の `CoreAssumptions`・`PathBasesShape`・`ShapeOk`。`PrimitiveScoped.lean` の `PrimSig.Scoped`。`ExternalResponse.lean` の `ExternalAssumptions`。
- `ScopeSignatures.lean` の `refGet`・`refSet`・`pathBases`・`entries`・`effects`・`builtins`・`lookup_mem`。`ScopeConstraintInstances.lean` の `admits_iff_count`・`substitutionAssumptions`・`admits_sat`。
- `Syntax.lean` の `Builtins` の欄の既定値（`externalResponse`・`admitsR`・`valContent`）。

git の操作（読み取りを除く）、既存のファイルの変更、`lake build`、cargo の実行はしていない。Lean の検査は `formal/` を作業ディレクトリに `lake env lean -M 12288` で行い、確かめのファイルは `<tmp>/rv-l50-h/` に置いた。

## 結論

**可**（重0・中0・軽2・情報8）。

完了の判定は満たす。主な点は次のとおりである。
- `Model.scopeConditions P` は、任意の P について25欄すべてを名前の付いた定理から構成する。どの欄も True だけの模型や空の sig 表に依らない。
- sat は共通表と同じ `ModelConstraints.sat` であり、型パラメータの非空制約を実際に検査する。
- IO に関わる4欄（`io_typed`・`io_exists`・`io_target` と `io_kind`）は、前の3欄が lookup の全三場合の kind から、`io_kind` が空の IO 関係から従う。IO 行のない表では、どちらも正しい導き方である。
- `delta_typed` は kind の不一致で閉じ、δ の未定義を使わない。
- L60 に残す4欄は `ModelScopeConditions.core` の別の入力のまま残り、計画と一致する。

処置を勧める点は、記録の表の崩れと写しの欠けの2件だけである。どちらも完了の判定を左右しない。

| # | 重さ | 場所 | 問題 | 修正案 | 根拠の種類 |
|---|---|---|---|---|---|
| 軽1 | 軽 | `l50/h/results.md`「単位の時刻」（14〜24行） | 表の行の間に空行がある。Markdown の表は空行で終わるので、L50.37〜.40 の4行は表にならず、区切りの行のない段落として表示される。同じ値は「最終照合と単位ごとの所要」の表（165〜169行）に正しい形で再掲されている | 14〜24行の行間の空行を除く | 読めば確定 |
| 軽2 | 軽 | 01-12 の追加の第1段落（3338行）、07-04 の追加の第1段落（163行） | 写しは「pure・io・exit の署名は lookup の全三場合で排除する」（07-04 は「不在は lookup で排除し」）と書く。しかし `io_kind` は前提に kind を持たないので、lookup では閉じない。本番は `Model.builtins` の `ioResponse` を空の関係に定め、`io_kind` はその空から従う（Model.lean 23行・161行。results.md の L50.38 の行も「io_kind は空の同じ IO 関係を使う」と書く）。写しは IO 応答の関係が空であることを書いておらず、応答4条件がすべて lookup から従うと読める | 01-12・07-04 の該当の文に「IO 応答の関係は空であり、io_kind はこの空から従う」と加える | 読めば確定 |
| 情報1 | 情報 | `Model.builtins`（19〜23行）と sat の対照（206〜210行） | `Model.builtins` は共通表の `ScopeSignatures.builtins` を基に、`sig`・`effects`・`ioResponse` だけを置き換える。sat は共通表の `ModelConstraints.sat`（`ScopeDeclarations.http` の要約）のままで、True へ置き換えていない。既定ビルドの対照は、同じ `tvar 0` を鍵制約の文脈で受け入れ、空制約の文脈で拒否する。sat を True にすれば否定の側が、False にすれば肯定の側が失敗するので、両側が意味を持つ。加えて、開いた変数以外の型についても判定が文脈の lookup だけでないことを検査1で確かめた。制約のない文脈で、関数型を鍵制約の下で拒否する | 不要 | 実行で確定（検査1） |
| 情報2 | 情報 | 八保存則（38〜60行） | `sat_rename`・`sat_renameTypes`・`sat_subst` は共通表の `ScopeSignatures.substitutionAssumptions` の射影をそのまま使い、`sat_values` は B に依存しない `ModelConstraints.sat_values` を直接使う。sat の欄は Model と共通表で定義上等しいので、移送は正しい。admits の4欄は `common_lookup` で Model の lookup を共通表の lookup へ戻し、`admits_iff_count` の個数検査を保存する。量化は元の欄の型のままで、型付き値像などの前提を落としていない | 不要 | 読めば確定 |
| 情報3 | 情報 | 宣言と形の12欄（62〜140行） | `sig_cases` は `lookup_mem` から、成功する全 lookup を名前と署名の等号を含めた三場合へ戻す。検査1で、共通表の行（`File.readTextIn`・`Scope.checkPathIn`）が Model では none であることを確かめた。`sig_scoped` は三場合とも `PrimSig.Scoped` の各欄を P の条件なしに証明する。三署名はデータ型を含まないので、P を読まないのは正しい。`pathBases_shape` は発行の行で `PathBasesShape` の7欄を `rfl` で、membership を同じ `effects` の `[pathBasesName]` で示す。検査1で `effects processEnvironmentEff = some [pathBasesName]`、`effects "File.Read" = none` を確かめた。`effect_ops` は `effects` の全分岐を辿る。`store_shape` は参照2行で実際に `StoreShape` を示し、発行の行は前提で除く | 不要 | 読めば確定、実行で確定（検査1） |
| 情報4 | 情報 | 応答4欄と対象一致（142〜179行） | `delta_typed` は `sig_cases` の三場合で `sg.kind = .pure` を `cases` で閉じる。`Model.builtins.delta` は全入力で none（検査1）だが、証明はこれを使わない。`io_typed`・`io_exists`・`io_target` は `no_io`（三場合とも kind が io・exit でない）で閉じる。特に `io_exists` は存在を結論するので、空の関係では閉じず、lookup によってだけ閉じる。`io_kind` の前提は kind を含まないので lookup では閉じない。応答の関係に入るものがあれば、kind が io・exit であることを示さなければならない。IO 行のない表で関係を空に定めるのが、この欄を満たす正しい模型である。共通表の `ioResponse` も lookup の kind を要求するので、Model の lookup で組んでも空になる。空を直接書いたのは同値の簡略である | 不要 | 読めば確定、実行で確定（検査1） |
| 情報5 | 情報 | L60 に残す4欄（199〜204行、`contracts.lean`） | `external_typed`・`external_exists`・`external_no_targets`・`release_exists` は `scopeConditions` に含まれず、`ModelScopeConditions.core` の別の入力として残る。detail の F09 と第4節の表に一致する。L60 への参考として次の二点を記す。<br>・`Model.builtins.isResource` は常に false なので、Model の `release_exists` は前提が偽になり空疎に成り立つ（検査1で証明した）。通常資源の条件の実質は ModelTargets 等の表にある。<br>・`externalResponse` は `Builtins` の既定の空の関係である。`external_typed`・`external_no_targets` は空疎に成り立つが、`external_exists` は外部関数を宣言し `ExternalArgs` を満たす P では成り立たない。L60 は P を制限するか、Model の外部応答を定める必要がある | L60 の担当へ申し送る | 実行で確定（検査1）、読めば確定 |
| 情報6 | 情報 | 発行の読者（`ModelTargetsExamples`） | 量化の範囲は次のとおりである。<br>・`call_arguments`・`call_typed`: 任意の P・Ψ。<br>・`issue`: 任意の q・k・μ・σ（σ.Valid と NoHandler の下）。<br>・`issue_to_at`: 任意の P・σ と At の全引数。ただし空の捕捉・空の継続・空のストアに限る。<br>・`issued_current`: 準備が成功した全入力で snapshot が σ と一致する。<br>・`issued_at`: 任意の P・σ と At の全引数について、準備失敗・検査成功・検査失敗の三場合で実際の Step がある。Step の σ は発行と同じ σ である。<br>・`required_base`: 起点 b とパターン p は任意だが、index は `.fixed (.based b p)` の形に限る。<br>results.md は空の継続・ストアの限定を明記している。依頼の「任意の P・Ψ と全ての At の入力」は満たす。継続・ストアを一般にする必要は、計画の L50.39 の行にない。cwd の例と Ready の受理の例は前提が満たせることを示し、`issued_current` などの前提が空疎でないことの証拠になる。「At を含む計算全体の状態保存を推測しない」限定は、results.md・01-12（4018行）・07-04（165行）のいずれにも書かれている | 不要 | 読めば確定 |
| 情報7 | 情報 | `AtPrepare.lean` の `AtPrepared.of_path_bases`、既存の定義と公理 | `AtPrepare.lean` の差分は11行の挿入だけで、既存の定義・言明に削除や変更はない。主な十言明・型付けの規則・旧 `Release` は差分にない。補助定理を定義元に置いたのは、`prepareCore`・`finishPreparation` が private で、別モジュールから展開できないためである。その結果、下流の再ビルドで既定ビルドが約6分半になった。追加の生成宣言14件は results.md に数えてある。`#print axioms` の7件（`scopeConditions`・`substitutionAssumptions`・`issued_at`・`issue_to_at`・`call_typed`・`required_base`・`of_path_bases`）は全て `propext`・`Classical.choice`・`Quot.sound` の範囲内だった | 不要 | 実行で確定（検査1・2） |
| 情報8 | 情報 | 記録の大きさと禁止の参照 | `l50/h/` の最大のファイルは final-manifest-part-02.json の67,245バイトで、全体は約0.4 MB である。手元の絶対パス・`private/` の内容・docs/todo へのリンクは0件だった。照合の正規表現（verify.py 135〜136行）は検出から除いた。本番のコメントに工程の ID はなく、`#eval` もない。build・work の記録の時刻は L50.40 の区間に収まる | 不要 | 読めば確定 |

## 観点ごとの根拠

### 1. 25条件の対応

- **構成**: `scopeConditions`（182〜197行）は、`substitutionAssumptions P`・`responseAssumptions P`・`targetAgreement P` と表の12欄の名前の付いた定理を、欄ごとに渡す。`sorry`・`axiom`・`admit` の語は0件である。
- **空疎でないこと**: 情報1〜4のとおりである。表は3行で空でなく、sat は True でない。存在を結論する欄（`io_exists`）は lookup で閉じる。空の関係から従うのは、その関係に入ることを前提にする `io_kind` だけである。
- **IO 不在からの導出**: 情報4のとおりである。Model に IO 行がないので、IO の3欄と `io_target` が前提の否定で閉じるのは正しい。
- **δ**: 情報4のとおりである。
- **L60 に残す欄**: 情報5のとおりである。

### 2. 宣言と形の12欄

情報3のとおりである。`contracts.lean` の第1例が、群 A の F09Model と同じ全称の型（`∀ P, ModelScopeConditions P Model.builtins`）であることを示す。単独の検査で終了0だった（検査2）。

### 3. 発行の読者

情報6のとおりである。`issue` は発行を δ や IO 応答で実行せず、`E_PathBasesApply`・`E_IssuePathBases` の二遷移を使う。事象の被覆は `pathBases.eff` の `Eff.Covers.refl` で、効果は Process.Environment である。

### 4. 既存の AtPrepare への追加

情報7のとおりである。

### 5. 設計書の写しと記録

- **写し**: 01-12 の2段落と 07-04 の2段落・表の1行は、本番の宣言名と結論に一致する。経緯の文や工程の ID はない。不足は軽2（`io_kind` の根拠）である。
- **記録**: 情報8のとおりである。表の崩れは軽1である。

## 実行した検査

| # | 検査 | 結果 |
|---|---|---|
| 1 | `<tmp>/rv-l50-h/Probe.lean` で `#print axioms` を7件に実行した。同じファイルで次を証明した。<br>(a) `Model.builtins.sig` は `File.readTextIn`・`Scope.checkPathIn` で none、`Reference.get` で `refGet`。<br>(b) 制約のない文脈で、関数型を鍵制約の下で sat が拒否する。<br>(c) δ は全入力で none、IO 応答の関係は空。<br>(d) `release_exists` は `isResource = false` から空疎に成り立つ。<br>(e) `effects processEnvironmentEff = some [pathBasesName]`、`effects "File.Read" = none` | 全て通る。公理は全て `propext`・`Classical.choice`・`Quot.sound` の範囲内（情報1・3・4・5・7） |
| 2 | `Model.lean`・`ModelTargetsExamples.lean`・`l50/h/contracts.lean` を `lake env lean -M 12288` で `-o` なしに単独で検査した。あわせて新規2ファイルの `sorry`・`axiom`・`admit` の語を語単位で数えた | 3件とも誤りなく終了0、実時間で約0.9秒・約0.7秒・約0.7秒。語は0件 |

検査の実行は合計で約5秒だった。大きな具体値を作る評価はしていない。担当の225宣言の監査・既定ビルド・work は引用し、再実行していない。

## 取りまとめの追記

- 軽1（results.md の表の空行）と軽2（01-12・07-04 に、IO 応答の関係が空であり io_kind がこの空から従うことを加える）は、取りまとめが直した。Lean は変えていない。
- 情報5は、L60 への申し送りとして l50/h/results.md に記した。そのほかの情報は処置しない。
- 群 H の作業末の work は終了0、475.89秒、最大常駐量 2,944,581,632 バイト（篩の部分の生成物を消して再ビルド。l50/h/results.md）。
