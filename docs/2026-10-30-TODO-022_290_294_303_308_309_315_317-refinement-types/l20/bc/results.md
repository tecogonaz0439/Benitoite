# L20 群 B・C の結果

2026-11-02。指定ブランチは `m014/l20.bc`、B_WORK は **`da0049469694b2f26fd14173336bfe0c18aa5b11`**。ブランチの照合・切替・作成・コミットは行っていない。共通依頼文、detail の群 B・C と L20.28〜.38・S02・S03・S09・文脈の31位置、plan の停止条件と指定された冒頭八項、A3c の gate/signatures と独立レビューを読んだ。初回の判定は実装担当の自己点検である。独立レビュー RV-L20.bc は条件付き可（中1・軽11）であり、その全所見の処置と再検査を末尾の r1 に記す。設計者の受け入れは未実施である。

## 完了条件の照合

L20.28〜.38 の本体を番号順に実装した。各単位の署名を本体の前に signatures.md に記し、最終の完全署名を同ファイルに整理した。群の実装側の条件と作業末の検査は満たした。RV-L20.bc の所見の処置は末尾の r1 のとおりであり、修正版の独立レビューと受け入れは取りまとめに残る。

| 単位 | 判定と本体の証拠 |
|---|---|
| L20.28 | PrimSig.Scoped、CoreAssumptions.sig_scoped、PrimSig.Scoped.inst_source/inst、CoreAssumptions.opSignaturesWF。範囲深さ rkinds.length を保持し、具体化後は深さ0の SignatureScoped を返す。tel と同じ tparams の kind を読む。制約は同じ列の別の射影であり Scoped の検査対象ではない |
| L20.29 | LegacyDeclarationInputs、functionBodyInput/methodBodyInput/superBodyInput、declarationBodyInputs と三つの本体への射影。新 WellTyped を入力へ足さず、メソッドの Q は代入前の Qsig。辞書の二供給元は既存の op_dictionaryInputs/impl_dictionaryKinds |
| L20.30 | 全構文の Annotation.substAt/Tel.annotation_substAt/Declared.typeSubst を使用。Ty.subst_substAt と reject_unsorted_tapp_image を追加。源の tapp の Sorted と像の非 Sorted を同じ言明で返す。正しい入力との対照は TypeSubstGateExamples.appTy、gate_annotation_lam、gate_annotation_escape。NoTapp を新しい入力にしない |
| L20.31 | RangeFormation の SourceScoped.bind/instR、RangesOnly の WFImages と支持の移送、範囲写像の Sorted/Declared/HasKind。instR/shiftR と型・値の交換は既存の mapRanges/bind の補題も使う。対象二ファイルに旧 WF/VarsIn/RawWF の同値の読者はない |
| L20.32 | TypeValueExchange。Ty/Eff/Tel の開いた像と値置換、closeTyAt/closeEffAt/closeRAt/closeTel、LocalCtx の kind の交換。lambda と依存 lambda の実際の closeVal が返す閉包は、同じ cap と型置換した body を持つ。実行時閉包全体に Val.substTyAt を掛ける等号や、環境を捨てる instantiate の等号は主張しない |
| L20.33 | PatTy.substAt の全9場合。P_Convert の正規化と P_Refined の全述語を含む。構成子の欄の行支持は Program.WellFormed.cons から供給 |
| L20.34 | PatTys.substAt の2場合と AltsTy.substAt。append・長さ・selectSlots の写像を同じ証明で照合 |
| L20.35 | Inhabits.of_substAt と InhabitsAll/InhabitsEach の反映。元の全24構成子を覆う。data/List の子は値の大きさ、refined の基底は型の大きさで帰納。refineNorm_iff から RefinementPossible を取り出し、core だけから篩を戻さない。checkedAt/atError も含む |
| L20.36 | Exhaustive.substAt。像の正規形の所属を反映し、元と同じ値・ps の照合成功を返す。unguardedPats_substTy は腕の型置換前後のパターン列を結ぶ |
| L20.37 | SignatureInstance.closedInput、RowTransport.substAt、Admissible/PrimitiveAdmissible/MethodRowsAdmissible.substAt、TypeArgsKinded/SatAll.append、dict_callInputs・dict_call_link と二つの method_body_input。型付きの辞書とメソッドの ss を結合し、ss++ts の完全な内部入力、行個数、代入前の QTel の RowTransport を返す。実装と呼出しの類、対象の像の正規形の一致、辞書引数の型付けも同じ逆転で供給する。既存の SignatureInstance.typeScope・method_body_typeScope・raise_typeScope・fail_input、SatAll.substAt、NoFail.substAt と接続。admits の移送を独立の信頼条件へ足さない |
| L20.38 | TypeSubstBindings。値束縛1/n/n+1/2と型束縛k/1、hide・params・extend・extendNone・shiftE、R と L の写像。OpSig.context/failureContext の交換と、同じ S02Internal.C の IH を型束縛下へ渡す under_types。31位置の対応は下表 |

新規の7モジュールは SourceScope・PrimitiveScoped・RangeFormation・LegacyDeclarationInputs・TypeValueExchange・PatternTypeSubst・TypeSubstBindings である。すべて既定の Benitoite.lean に import した。01-12 と 07-04 は、同じ定義・証明した範囲へ写しをそろえた。

## sig_scoped と停止条件

旧 CoreAssumptions の残り一欄を、`sig_scoped : ∀ b s, B.sig b = some s → PrimSig.Scoped P s` として接続した。旧20欄は新しい欄又は導出として対応する。実表と三モデルの充足は **L50/L60**、主定理での使用と最終の照合は **L70** に残る。LegacyTables には追加していない。

PrimSig.Scoped は NamesWF、宣言の範囲深さを保持した SourceScoped、同じ型パラメータ列の kind、依存列の Sorted・Declared、操作の位置の条件を持つ。操作の条件は、既存 OperationWF と、最上位の対象以外に範囲変数を持たない引数型、および範囲変数を持たない結果型である。効果原子の範囲添字は WF に含まれないため、後二者は RangesScoped でも検査する。これは S09 が指定する旧 TargetRangesOnly と結果型の範囲の条件を、実際の opSigAt の読者へ供給するものである。旧 Scoped の引数の位置の条件は全項目に掛かったが、新しい条件は opEff ≠ none の操作だけに掛かる。また、最上位の scoped を opaque と並ぶ対象の位置に認める。この二点は緩和である。instTarget の読者は opSigAt だけであり、非操作の V_Prim は Tel.instR で依存列全体を具体化するためである。

主な十の移送の言明、公開 S02 の十四署名、型付けの規則、ValueMeaning を変更していない。旧 Release のソースを変更していない。新しい公理・独立の信頼条件・既定 import からの除外はない。利用者の書ける形を狭める Rust の変更はなく、処理系を変更していない。

行支持の追加の欠けは見つからなかった。今回使う供給元を次のように照合した。

| 位置 | 行支持の供給元 |
|---|---|
| 宣言の依存列 | SignatureScoped と新しい PrimSig.Scoped.source |
| 組み込みの呼出し・節 | 既存の PrimitiveAdmissible.sourceTelRows と ClauseSig。変更なし |
| 外部署名と At | 既存の ExternalSignature.WF.sourceTelRows と AtCallAdmissible の入力の行支持。変更なし |
| 構成子の欄 | Program.WellFormed.cons の SourceScoped の行支持。PatTy と Inhabits で実際に使用 |
| 実装の辞書型 | dict と tvar から定義される既存の形を維持 |
| ストアと実行時の閉包 | WF000 を行支持の空性へ読み替えない。S02 の TypeSubstCode と恒等の成分を維持 |

## 31位置と同じ相互族への接続

写像を共有する位置は一行にまとめ、位置数を保持した。`C` は S02Internal.C、`Body/Arms/Clauses` は同じ内部入力を受ける各成分である。これらの命題の全証明は群 D の担当であり、今回の写像の証明を全相互帰納の完成としない。

| 元の規則・位置 | 数 | 今回の写像と子の成分 |
|---|---:|---|
| V_Lam | 1 | bindTypes_hideConts → bindTypes_params、閉じた像の shiftV、R の shift、L=[]。子は C |
| V_DependentLam | 1 | hideConts と同じ入力、Tel の置換。子は Body |
| V_Closure | 1 | S02_Closure の恒等、外側の注釈とは分離 |
| V_CheckedRequest | 1 | req の閉じた Q/C/Γ/Φ は既存のまま |
| V_CheckedAt | 1 | S02_Witness の恒等 |
| CheckedWitness.request | 1 | 同じ閉じた request の判断 |
| C_BuilderLet | 1 | bindTypes_extendNone、Φ.lift、R の shift、LocalCtx.typeSubst_extend。子は C |
| C_Let | 1 | bindTypes_extend、Φ.lift、R/型/効果の shift、typeSubst_localExtend。子は C |
| C_If | 2 | boolCond の true/false と Φ は同じ述語。各子は C |
| C_Lazy | 1 | hideConts、R=none、L=[]。子は C |
| C_External | 1 | instantiatedTel_substAt、外部署名の既存の行支持。子は Args |
| C_Meth | 1 | Tel.arguments_typeSubst と SignatureInstance.substAt。子は Vs |
| HasTypeTelArgsQ.param | 1 | 既存の Tel.open_typeSubst、型注釈と実引数の観測の交換。子は Args |
| TelBodyTy.param | 1 | bindTypes_extend、閉じた像の shiftV。context を持たない入力を Body へ渡す |
| CaptureOk.mk | 1 | S02_Capture の恒等。閉じた像と facts の既存の条件を保持 |
| DependentClosureTy.mk | 2 | S02_Closure の恒等。capture と Body の隠したストアを別に扱う |
| HasTypeArmsQ.plain | 2 | bindTypes_params・R/Lのshift、後続の excludedFacts++Φ。子は C と Arms |
| HasTypeArmsQ.guarded | 2 | hideConts・R=none の guard と、同じ p.open true を持つ body。両子は C |
| HasTypeClausesQ.cons | 1 | TypeSubstInput.under、context_typeSubst、型k・値n+1。子の C は under_types で接続 |
| HasFailureClause.one | 1 | TypeCtx.valueParam の型1、failureContext_typeSubst の値2、liftMany 2。子は C |
| ImageOk.ordinary | 1 | S02_Image は True。像の文脈の全移送を新たに主張しない |
| ClosureTy.mk | 3 | capture、bindParams、R/局所kind・参照の既存の境界。closeRAt/closeTel と閉包コードは TypeValueExchange を使う |
| GuardBodyTy.mk | 3 | capture、同じ真の述語の body、閉じたR/L。型像は closeTyAt と同じ cap で閉じる |
| **合計** | **31** | 相互14判断の内25位置と外の6位置 |

通常節の bindTypes は sg.params/ret の正規形を返す。OpSig.substAt による文脈との等号は証明したが、原文の sg の文脈へ戻す narrow/ContImages/C_ResumeNorm の橋は指定どおり **D3・L20.54** に残る。lambda・escape・メソッドの包装は D1/D2、全十四成分の相互帰納は D4・L20.60 の担当である。

## 計画との差と実装中の修正

- SourceScoped と SignatureScoped を新しい SourceScope に、既存の Ty.TargetWF/BinderTypes.TargetWF/PrimSig.OperationWF を PrimitiveScoped に移した。ConstraintAssumptions が宣言の形成を読む依存の循環を避けるためであり、移した定義の意味は同じである。
- 値・型束縛の共有補題を、新しい TypeSubstBindings に置いた。TypeValueExchange と PatternTypeSubst を読むため、TypeSubstContracts に置くと循環する。公開 S02 の字面を変えていない。
- A3c が既に証明した全形成、SignatureInstance/SatAll/NoFail の移送と fail_input を再利用した。新しく同じ全帰納を書いていない。PatternNormalForm の data の逆転も、同じ命題・証明を Inhabits.data_inv として公開して再利用した。
- 初回の既定ビルドは SourceScope の依存の循環で失敗し、定義を下位モジュールへ移して解消した。次のビルドは RangeFormation の OpSignaturesWF の import 不足で失敗し、Context.Declarations の import を明示して解消した。その後の局所検査と既定ビルドは成功した。局所の証明作成中には、名前空間・目標型・正規化・生成された match の違いによるエラーを修正した。未解決の検査失敗はない。
- 最初の work と公理検査の後、自己点検で新しい Scoped.operation が OperationWF だけでは旧の範囲の位置の条件をすべて表さないと確認した。WF が読まない効果原子の範囲を RangesScoped で明記した。S09 の旧条件の必要部分であり、行支持・型付け規則・独立の信頼条件を足していない。この変更で古くなった検査を、同じ引数の work と公理検査で再確認した。
- 完了条件の再照合で、メソッド本体の ss++ts の kind・Annotation・制約を結合した入力も追加した。型付きの呼出しから Sub/Normal/Eff を通して取り出す。独立の kind や制約の条件を仮定しない。この追加を含む work と公理依存を再確認した。
- 拒否例の作成時には test-audit を適用した。守る境界は型像の形成であり、WF だけの像を受理する退行を捕まえる。A3c の arity の拒否例では sort の誤りを検査しない。追加の実行器や処理系 API は設けていない。削除したテストはない。

## 検査

入力は指定の B_WORK と本作業の未コミットのソース・写しである。引用した別状態の検査はない。作業末の work は --only を付けず、--base だけを指定した。最初の成功の後の署名の修正とメソッドの接続の追加、およびそれぞれの再確認は上記のとおりである。Rust の lib 全件や全比較は追加していない。

| 検査 | コマンド・中身 | 終了 | 外側の時間 |
|---|---|---:|---:|
| 局所 Lean | formal で `lake env lean -M 12288 Benitoite/Release/Refinement/<関係ファイル>.lean`。SourceScope・PrimitiveScoped・RangeFormation・LegacyDeclarationInputs・TypeSubstFormation・TypeValueExchange・PatternTypeSubst・TypeSubstCalls・TypeSubstBindings の関係する本体 | 最終の各入力0 | 個々の呼出しは約0.2〜2.8秒。初期の作成中の失敗は上記の処置表のとおり |
| 初回の既定ビルド | formal で `lake build`。依存の循環を修正した状態 | 0 | 52.312秒 |
| 途中の既定ビルド | formal で `lake build`。群B、パターンの反映までの各状態 | 0 | 6.387秒・52.097秒 |
| work dry-run | `scripts/check.sh --level work --base da0049469694b2f26fd14173336bfe0c18aa5b11 --dry-run`。18ファイルの差分から spec_tally/spec_examples/formal_build を選択 | 0 | 0.112秒 |
| 最初の work | `scripts/check.sh --level work --base da0049469694b2f26fd14173336bfe0c18aa5b11` | 0 | 10.947秒 |
| 署名修正後の work | 同じ `scripts/check.sh --level work --base da0049469694b2f26fd14173336bfe0c18aa5b11`。最終の署名と写しで、対応表の自己検査・再集計、仕様書の例7件、既定 Lean ビルドと sorry 使用の拒否 | 0 | 56.035秒。仕様書の例は7成功・0失敗、3.14秒 |
| 最初の公理依存 | formal で `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/bc/axioms.lean` | 0 | 1.787秒 |
| 署名修正後の公理依存 | 上と同じコマンドを、修正後の署名で再確認 | 0 | 1.792秒 |
| 最終の work | 同じ `scripts/check.sh --level work --base da0049469694b2f26fd14173336bfe0c18aa5b11`。メソッドの入力の接続も含む最終のソースと写し。対応表の自己検査・再集計、仕様書の例7件、既定 Lean ビルドと sorry 使用の拒否 | 0 | 7.625秒。仕様書の例は7成功・0失敗、3.14秒 |
| 最終の公理依存 | 上と同じ `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/bc/axioms.lean` | 0 | 1.798秒 |

検査の構成は Lean 4.34.1（arm64-apple-darwin24.6.0、commit `5045d0056413266e57c625dcd7c365b10e377c52`）。lakefile の既定 target と `moreLeanArgs = ["-M", "12288"]` を変更していない。作業末の既定ビルドは work 内の実行を証拠とし、件数の採取だけの追加ビルドは行っていない。

RSS は**未取得（計画上の非採取）**。能動時間と待ち時間は分離していない。開始時刻を採取していないため、全作業の外側の時間は確定していない。最初の明示的な UTC 時刻採取は 2026-11-01 22:51:49 であり、それ以前に共通依頼文等を読んでいる。最終の記録時刻は 2026-11-01 23:29:47 UTC で、その間の約38.0分を下限としてのみ扱う。指定見込み6時間30分〜13時間55分、上限27時間50分を、今回の短い実績から改定していない。

## 公理依存と成果物

[axioms.lean](axioms.lean) は既定 import を読み、変更した13モジュールの全宣言をモジュール番号から列挙する。private・生成宣言も対象とし、不在・空のモジュールを拒否する。最終の列挙は **814宣言**、旧主定理・三モデル・十の移送の明示的な18件を合わせて **832件の印字**であった。

現れる公理は **propext・Classical.choice・Quot.sound の三つだけ**で、sorryAx・独自公理・未承認依存は0件である。新規7ファイルには sorry・axiom・native_decide・implemented_by を置いていない。新しい信頼条件を Lean の公理として宣言していない。

| 対象モジュール（Refinement 以下） | 列挙した宣言 |
|---|---:|
| SourceScope | 63 |
| PrimitiveScoped | 22 |
| ProgramWellFormed | 20 |
| ConstraintAssumptions | 61 |
| Context.Declarations | 126 |
| RangeFormation | 50 |
| LegacyDeclarationInputs | 18 |
| TypeSubstFormation | 130 |
| TypeValueExchange | 29 |
| PatternNormalForm | 33 |
| PatternTypeSubst | 22 |
| TypeSubstCalls | 172 |
| TypeSubstBindings | 68 |


全記録は本作業木で実行したもの、判断者は実装担当、判断日は2026-11-02である。01-12 の PrimSig.Scoped の写しは全欄を Lean と照合した。07-04 の未移行の記述も現在の対応へ直した。後の変更は結果の記録だけで、検査したソースと写しは変えていない。入力・設定の SHA-256 と生ログの大きさ・SHA-256 を次に記す。生ログの保存先は `<tmp>`、ファイル名は照合用であり、文書の根拠をその場所へリンクしない。

入力と設定（本リポジトリの根からの相対パス）:

| パス | バイト | SHA-256 |
|---|---:|---|
| `formal/Benitoite.lean` | 14806 | `dff67284614bfe21a8b7fd27f97bf8944ed8ae179b7e49ed6388a4afdb70c86f` |
| `formal/Benitoite/Release/Refinement/SourceScope.lean` | 6247 | `7649cc424ac2ee93bd57a73b5f6a932960818fa6187dfe1ccd1527d89248d36f` |
| `formal/Benitoite/Release/Refinement/PrimitiveScoped.lean` | 1324 | `ef768329c5afc708db21776b2db77f087c18b11bf73cd7be3c4c81e9a16613b9` |
| `formal/Benitoite/Release/Refinement/RangeFormation.lean` | 16434 | `deeebf9eeae41d5d0cd2e4aaefd850d8140144bba4353e4bcfb97edfd0e7b57f` |
| `formal/Benitoite/Release/Refinement/LegacyDeclarationInputs.lean` | 4776 | `0411ce2414fcd593015bb0959e2cc63e646d2e0510c4a7fa6a75db4fb655e51d` |
| `formal/Benitoite/Release/Refinement/TypeValueExchange.lean` | 8875 | `c96b732f32124d8195a0171384b5905c1b1228dbb7eeab0571ec524f8e44dadd` |
| `formal/Benitoite/Release/Refinement/PatternTypeSubst.lean` | 8618 | `fd98c0d1496d4a48f75d765215986157dcafc2e9077c8801b3de9cc15fec254b` |
| `formal/Benitoite/Release/Refinement/TypeSubstBindings.lean` | 15206 | `35719fa546e38d0c7f8c8954f316999044b233de276f142a06250df7e3d5608b` |
| `formal/Benitoite/Release/Refinement/ProgramWellFormed.lean` | 3109 | `3c158c2536a2c30543429b5c856d0df2407069899f2213b2976ab0e1bab691ab` |
| `formal/Benitoite/Release/Refinement/ConstraintAssumptions.lean` | 11853 | `6696bfe3c70175d16ee3186f1b98afe6f10975a6b5d44aec53f966e0b400578e` |
| `formal/Benitoite/Release/Refinement/Context/Declarations.lean` | 12309 | `c64d5103aec7b318d8e5f5732b9a6afc7080cfcc8b3e8d1041277f706f2ed1e8` |
| `formal/Benitoite/Release/Refinement/TypeSubstFormation.lean` | 53330 | `c1ac6a38e204a13e27256295205f5d80acbb99bab864674153c9caa2ecab0c41` |
| `formal/Benitoite/Release/Refinement/TypeSubstCalls.lean` | 35601 | `0771b275c92676f7aea96b33e137c3f5edec2b0708559ac24d360b509a883218` |
| `formal/Benitoite/Release/Refinement/PatternNormalForm.lean` | 9275 | `53817c42de1ca33434f0c7ee053bc842f901b89347a47c8ac1aceead9d066526` |
| `docs/design/01-spec/01-12-core-calculus.md` | 723603 | `ccad8eadcd1c9822b881ea5b6bdb851d9a3a741d11a49bd871db4418582478d4` |
| `docs/design/07-quality/07-04-formal-semantics.md` | 467557 | `546aad14c6e9566ec7870b189edd874f2429fd16b9b238cd146df6337b41e0c5` |
| `formal/lean-toolchain` | 25 | `d5edba4e4b8faad9c1baeadb265716d20d03be4d1a2647dc5e35b0c0325bea7b` |
| `formal/lakefile.toml` | 872 | `10f2661bff8fce95a9253d976427d0ca44038ec12350c955badbc1cf1efa6e3a` |
| `Cargo.lock` | 50695 | `075ddfa31b648a04030efcbfb30365910dff6d8de62b0e903b57d28dc5e6324d` |
| `rust-toolchain.toml` | 66 | `4d7d5425fe623392e565a964fc135c563c316ce125058199eb40b2953ba6ecbb` |
| `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/bc/signatures.md` | 33618 | `15a4fb70b911c64955f8a9b679e13ea1d8885855338771f18be2d08b3ad50d3a` |
| `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/bc/axioms.lean` | 2333 | `f475db4b80e4d53479dbc7a26ef1dddad2f0736285e5ac34e3760c3186fab83c` |

生ログ（`<tmp>`）:

| ファイル名 | バイト | SHA-256 |
|---|---:|---|
| `benitoite-l20-bc-build-initial.log` | 69251 | `492f000f6ff9347594e8bd43ea74f12af722a7a4baa264db528210f0a5b759f8` |
| `benitoite-l20-bc-build-source.log` | 45309 | `1f4284f7f90113aae58047ba810a9f5d5bb993e28fb5c04db51d91d3e7790315` |
| `benitoite-l20-bc-build-scoped.log` | 46249 | `c1c0bf9a0baa12757aab644ec93ac0cc3f53d0ff464a3f1593899b23ddef18a6` |
| `benitoite-l20-bc-build-b.log` | 41447 | `39c256ce2725f01feb216c53f7d2b2981efcb65d6ba8370be6ad669758e88f39` |
| `benitoite-l20-bc-build-pattern.log` | 45463 | `09aafed8f6fa16127ee40ecf43c0608a7627adf8d90f6194ce9cf63978ab579b` |
| `benitoite-l20-bc-work-dry.log` | 759 | `27873b7c6e7f66f2657b5c164416d53463603c4ea3cbca285b65e4a987582492` |
| `benitoite-l20-bc-work.log` | 5718 | `a1946fdbf3990454d4e162f9bf054d2e64ccf6ee15abfb6f7903d9a3c06b83c5` |
| `benitoite-l20-bc-axioms.log` | 102716 | `312bb2547cc6c241f2548ca9409daa5f64e42e6740d998a3cc9af6eaf871f59f` |
| `benitoite-l20-bc-work-final.log` | 5718 | `d994914f557d5dd7b36d4d56bda8cd778e61be18c81cc9c856bd18021cdf7d8e` |
| `benitoite-l20-bc-axioms-final.log` | 102716 | `312bb2547cc6c241f2548ca9409daa5f64e42e6740d998a3cc9af6eaf871f59f` |


| `benitoite-l20-bc-work-accepted.log` | 5718 | `93277954fd938c88556e7cbb8af9547a59416f5955522a6f9066a4a579cfd32f` |
| `benitoite-l20-bc-axioms-complete.log` | 104749 | `e6f9d4d18e61c2911aaccb0c9b5d9ab2b2f435f2e94635de80429dec5d032371` |

## 申し送り

実装担当による完了条件の照合を済ませた。群 B・C の独立レビューと所見処置、設計者の受け入れは取りまとめが行う。標準の実表と三モデルの sig_scoped の充足は L50/L60、原文の節の文脈との橋は L20.54、全コードの相互型置換は群 D、全状態と Rust の接続・全比較は後段の指定のままである。本結果をそれらの完了として扱わない。

## r1: RV-L20.bc の所見の処置

2026-11-02。中1と軽1〜11を本群で処置した。追加・強化する完全署名を signatures.md に先に記し、レビューの補助 Lean で証明された辞書の core の保存と dict_call_link、unguardedPats_substTy を本番の逆転とパターンの補題へ組み込んだ。主な十言明・公開 S02 の十四署名・型付けの規則・ValueMeaning は変更していない。新しい公理・独立の信頼条件・行支持の追加はない。

| 所見 | 処置 |
|---|---|
| 中1 | dict_callInputs に正規形の core と辞書引数の HasTypeVsQ を加えた。dict_call_link を追加し、二つの method_body_input と内部の method_input_aux は同じ id の類の一致・対象型の正規形の一致・辞書引数の型付けを返す。HasTypeCQ の逆転は Sub・Normal・Eff を通る |
| 軽1 | 07-04 の ProgramWellFormed は SourceScope の SourceScoped を読むと記した |
| 軽2 | 07-04 の対応表に新規7モジュールを全て加えた |
| 軽3 | 07-04 の CoreAssumptions の列挙に宣言の形成を加えた |
| 軽4 | PrimSig.Scoped は kind を読むと直し、制約を検査しないことを01-12と本記録に記した |
| 軽5 | 旧条件からの二つの緩和と、その実読者の理由を01-12・07-04・本記録に記した。定義は変えていない |
| 軽6 | Ty.TargetWF の文書コメントを PrimitiveScoped の同定義の直前へ移し、01-12 の写しをそろえた |
| 軽7 | reject_unsorted_tapp_image に源の tapp の Sorted を加えた。対照の既存例は TypeSubstGateExamples.appTy、gate_annotation_lam、gate_annotation_escape である |
| 軽8 | under_types は出力の命題の等号と List/Option/BuilderKind の場合分けで局所文脈を同定する。生成された match の名前を本文から除いた |
| 軽9 | 追加箇所の連続する空行、句点後の半角空白と新規 import の空行・順序を整えた |
| 軽10 | unguardedPats_substTy により C_Match が読む腕の型置換前後のパターン列を結んだ |
| 軽11 | L50/L60 の表の充足の義務を以下に追記した |

L50/L60 への申し送り: 新しい sig_scoped の kinds と declared は、表の署名に現れる data・class・external の宣言を同じ P に要求する。TargetTable・ModelTargets・ModelHttp などの Result を含む表について、表が読む data の arity を P が持つことも充足の義務に含める。旧 Scoped は P を読まなかった。この強化は kind と宣言照合に必要であり、P の条件なしの充足を主張しない。

修正版の完了条件を再照合した。L20.28〜.38 の範囲で、中1・軽1〜11の未処置はない。追加した宣言は dict_core_le（private）、dict_call_link、unguardedPats_substTy の3件である。既存の4逆転の結論と reject_unsorted_tapp_image の言明を強め、全122宣言の署名を signatures.md に記した。構造体更新を含む既存の private な5署名の省略末尾も本体と照合して補った。01-12 の PrimitiveScoped の全欄と07-04の新規7モジュールの対応を再照合した。計画からの新たなずれと停止条件への該当はない。plan・detail・レビューの記録・処理系・旧 Release は変更していない。

検査中の局所の失敗は、存在量化した τ の型推論と、その型の明示の構文だけであり、`∃ τ : Ty` として修正した。型付けの規則や追加の前提で解消していない。最終の局所検査は TypeSubstCalls・TypeSubstBindings・TypeSubstFormation・PatternTypeSubst の4件とも終了0である。拒否例は既存の例の言明を強めたもので、実行器や処理系のテストは追加していない。

| r1 の検査 | コマンド・中身 | 終了 | 外側の時間 |
|---|---|---:|---:|
| work dry-run | `scripts/check.sh --level work --base da0049469694b2f26fd14173336bfe0c18aa5b11 --dry-run`。20ファイルの差分から spec_tally/spec_examples/formal_build を選択 | 0 | 0.110秒 |
| work | `scripts/check.sh --level work --base da0049469694b2f26fd14173336bfe0c18aa5b11`。対応表の自己検査・再集計、仕様書の例7件、既定の lake build と sorry の拒否。--only なし | 0 | 56.712秒 |
| 写しの最終整形後の work | 同じコマンド。01-12 の空行と説明の順の修正を含む最終入力。例は7成功・0失敗、3.31秒 | 0 | 3.925秒 |
| 公理依存（A-L） | formal で `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/bc/axioms.lean`。既定 import、private・生成宣言を含む全13モジュールと明示18件 | 0 | 1.953秒 |

公理依存は **826宣言・844件の印字**で、現れる公理は **propext・Classical.choice・Quot.sound の3種だけ**、sorryAx は0件である。初回から件数が変わったモジュールは PatternTypeSubst（31）、TypeSubstCalls（179）、TypeSubstBindings（64）で、ほかは上表と同じである。生成された match の参照を除いた分の減少も含む。既定ビルドは work 内の実行を証拠とし、lakefile・既定 target・メモリ上限を変えていない。

検査した状態は B_WORK を基準とする本作業木で、別状態の結果を引用していない。判断者は実装担当、判断日は2026-11-02、記録時刻は 2026-11-01 23:49:57 UTC。以下の入力・設定を検査後に照合した。その後の編集は本結果の追記だけである。RSS は未取得（計画上の非採取）、全作業の開始時刻と能動時間・待ち時間の分離は未取得である。修正版の独立レビューと設計者の受け入れは取りまとめに残る。

r1 で変更した入力（相対パス）:

| パス | バイト | SHA-256 |
|---|---:|---|
| `formal/Benitoite.lean` | 14801 | `19666f5900a485f628febc0c378fd03d6ad1598aee133a4edb0582b118ca6230` |
| `formal/Benitoite/Release/Refinement/PrimitiveScoped.lean` | 1428 | `63a50359defd89bc837f77a205359a84397f4ab1f88036489c474dae9f7c1d1c` |
| `formal/Benitoite/Release/Refinement/Context/Declarations.lean` | 12205 | `e0408586f4cddd1231fed255014bc9fd83beb5fdfe2715332dcd167e6daaf32b` |
| `formal/Benitoite/Release/Refinement/TypeSubstFormation.lean` | 53370 | `a924cf65550d3f10b404a3dffe5d42146ee8256efc100eabcffdee556e8a7bfb` |
| `formal/Benitoite/Release/Refinement/PatternTypeSubst.lean` | 8956 | `42be86cb24ba3a56457641e5c560512121b916a7fa049823a300d953c287a221` |
| `formal/Benitoite/Release/Refinement/TypeSubstCalls.lean` | 38317 | `cfe9cdc4bf1dbbf2e88b8b958a3fd87957428d86c60ea89c1a60b740a4df7dae` |
| `formal/Benitoite/Release/Refinement/TypeSubstBindings.lean` | 15035 | `69328828eef176eb5ef99d5ce21847955ae7d3252ca9cf82f5fa7ff6db1ef5db` |
| `docs/design/01-spec/01-12-core-calculus.md` | 724472 | `cb6d5a622e2748f0bbec7d75e5078b96f539252ea6038640703e27d0a066543d` |
| `docs/design/07-quality/07-04-formal-semantics.md` | 469041 | `9470bc6e7cdbc58d3c535c585a071e7a1f487d7e14171415936f790e1c83b3a2` |
| `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/bc/signatures.md` | 35428 | `1588150341a10abcbe6fdb19a2159eb146191219682da3ae97fcbac3e4fef01a` |

変更していない入力・設定の大きさと SHA-256 は初回の表のとおりである。

生ログ（`<tmp>`）:

| ファイル名 | バイト | SHA-256 |
|---|---:|---|
| `benitoite-l20-bc-r1-work-dry.log` | 759 | `07a3980d2a1054e7c551b66e88edaf5d76ddf869fb306a3439b8cf05bec3f2d0` |
| `benitoite-l20-bc-r1-calls.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `benitoite-l20-bc-r1-bindings.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `benitoite-l20-bc-r1-pattern.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `benitoite-l20-bc-r1-formation.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `benitoite-l20-bc-r1-work.log` | 5718 | `080ac37bc3ffedb852dc6bd48896d50775d0fd0926c75b08e12d082fe116fe01` |
| `benitoite-l20-bc-r1-work-final.log` | 5718 | `4f8f93704db6195e58aa6aebef949b3a5fbb8918cf720b4ccfa4db8d8d565eca` |
| `benitoite-l20-bc-r1-axioms.log` | 106373 | `bdd15acf5380ace44e74c8bfce3819c8c88cb31f164452769238b55f465896af` |

## 作業末の work

`scripts/check.sh --level work --base da0049469694b2f26fd14173336bfe0c18aa5b11` を、Refinement の生成物を消した状態で実行した。終了0、外側102.65秒、最大常駐量1381171200バイト。
