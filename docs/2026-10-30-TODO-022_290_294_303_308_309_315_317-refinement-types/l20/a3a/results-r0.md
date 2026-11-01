> 初回停止時の記録である。r1で再開した後、共通のファイル一覧・枝一覧・完了条件のJSONは現行の結果へ更新した。以下の件数と判定は初回停止時のものであり、現在の判定は results.md を正とする。

# A3a の結果（停止）

2026-11-02。B_WORK は `14492156debe5f6b8925963e55c2d9aecdc6923c`、ブランチは起動依頼の `m014/l20.a3a` である。git による照合・切替・作成・コミットは行っていない。開始時の内容と各ファイルの SHA-256 は [baseline.json](baseline.json) に保存した。

**A3a は未完である。公開補題 `HasTypeVQ.shift_types_var` の現行署名が新定義の下で偽になるため、共通依頼文の署名変更時の停止条件で止めた。** 主な十移送の言明の字面は保っている。案1への切替、公理の追加、既定 import からの除外は行っていない。作業中の差分はそのまま残し、既定ビルドが失敗する状態である。

## 停止の根拠と戻す判断

[共通依頼文](../../implementation-request.md)の「示された型やシグネチャの欄・引数を加える、変える、消す必要が生じたら、実装を進めずに取りまとめへ報告する」に従った。S12.11 の七つの公開 shift 補助だけでなく、`HandlerAlgebra.lean` の `HasTypeVQ.shift_types_var` にも kind の対応を渡す必要がある。主な十移送とは別の公開補題である。

現行の同補題は、`C'.length = C.length + k` と `TypeCtxMap k c Γ Δ` だけを受ける。長さが同じでも C の kind は一致しない。次の例は、`k=0`、`c=0`、Γ=Δである。

- C は `[constructor 0]`、C' は `[value]` の宣言列とする。
- Γの変数0は、引数のない `fn [] [] bytes empty` 型を持つ。
- Cの下では、`V_Sub` と `Ty.LeQ.fn_effect` で結果の潜在効果へ `Fail[tapp 0 []]` を加えられる。
- C'の下でも同じ型へ移せるという現行の結論は、結果型の `Declared` と矛盾する。Γの元の関数型はC'の下でも宣言照合を満たすので、この矛盾を変数の注釈の不適格さで回避できない。

[stop-reproduction.lean](stop-reproduction.lean) の `source_typed`・`target_untyped`・`signature_false` は、既存の本番の `HasTypeVQ`・`TypeCtxMap`・`Ty.Declared` を使う。`result_declared` は現在の `TypingDeclared.lean` の結果宣言照合の証明を局所に再掲したもので、新しい信頼条件ではない。`TypeShiftExchange` 以下だけを import し、停止している上位モジュールの古い成果物を使わない。単独 Lean の検査は `-M 12288`、終了0。三定理の公理依存は `propext`・`Classical.choice`・`Quot.sound` のみである。

提案は [signatures.md](signatures.md) の末尾に完全な形で記した。`HasTypeVQ.shift_types_var` と private の `shift_var_aux` へ、既存の `TypeParamRenaming C C' (shiftIndex k c)` を渡す。唯一の外部の読者 `ContextMap.shiftE` では `TypeParamRenaming.prefix C extra` から供給する。新しい独立の信頼条件は要らない。**この追加署名は未実装**であり、取りまとめによる指定の改訂を待つ。

## 到達点と完了条件の照合

| 項目 | 判定・証拠 | 残る作業 |
|---|---|---|
| 完全署名を実装前に保存 | 済み。[signatures.md](signatures.md) | 後続のmotiveのLeanでの展開・本体の成立は完了扱いにしない |
| L20.08: CとTypeArgsKinded | TypeCtx、射影、values/valueParam、固定したkindのTypeArgsKindedとordinary/shift/substは局所ビルド成功 | 新しい全型置換の契約を後続の本体へ渡す接続は未確認 |
| L20.09: 全C読者とconstraints射影 | 75の型注記を変更、保持7を照合。Admissible/SubstitutionContracts/ConstraintAssumptionsの下位ビルド成功 | 上位の全読者のビルドは未完 |
| L20.10: tappと旧Cの橋 | Ty.Declared.tappを変更。旧context三署名とLegacyTypeInput/annotationのtargetをCκに変更 | LegacyValuesの上位ビルドはHandlerAlgebraで遮断。11橋の全体通過は未完 |
| L20.11: 宣言・節・旧C | Def/Impl/Scoped/OpSig/Failure/V_Raiseの定義を変更。ProgramTypingとHandlerContractsは局所ビルド成功 | ProgramWellFormed等の上位読者、旧橋の合成、V_Raiseの全読者は未完 |
| L20.12: Declaredの値移送・norm | rawSubstV/normのtapp二枝の局所ビルド成功。閉じた場所の定義追加0 | TypeFormationの `List.replicate n ({} : TParam)` が残る。closed_context/NoTappの全読者の再検査は未完 |
| L20.13: kindを保つ改名 | TypeParamRenamingと五包装、kindRenaming、TAK.shiftTypesが局所ビルド成功。KindRenaming/lengthを同名で低層へ移動 | 追加の公開署名の判断で停止 |
| 既定ビルド | 失敗。TypeFormationとHandlerAlgebra。下表の終了1 | 群末の完了条件は未達 |
| 主な十言明 | 字面が開始時と一致。[main-signatures.json](main-signatures.json) | 全体の型検査・公理依存は未完 |
| sorry・新公理・import除外 | 本番への明示したsorry/新公理の追加0、既定import/lakefileの変更0 | 失敗した定義のelaborationが出すsorryの警告は成功の証拠に使わない |
| 旧Release | Refinement以外のLeanは開始時から不変 | なし |
| rowKinds・kind像全族 | A3bへ残した。今回のSignatureInstanceは五欄のまま | A3bが実装・検査する |
| 関門(b) | 未通過 | A3b/A3cの三型引数case、escape/lambdaの注釈、誤個数拒否を本番で閉じる |
| W-L・全体A-L | 未実施 | 署名の判断後に既定ビルドを通し、全体監査・作業末の検査を実行する。今回の部分監査で代えない |
| 独立レビュー・受け入れ | 未実施 | 取りまとめ・設計者 |

## 計画の件数との比較

[occurrences-before.json](occurrences-before.json) は開始時の全出現の内容・行・列・変更/保持の分類、[occurrence-reconciliation.json](occurrence-reconciliation.json) はファイルごとの照合である。

| 集合 | 計画 | 今回の差分・照合 | 差と扱い |
|---|---:|---:|---|
| 明示した型注記の変更 | 69 | 75 | +6。CaptureRegularityの4出現とStateTypingの2出現。前群で追加されたCの読者である |
| 生のconstraintsの型を保持 | 7 | 7 | 0。Syntaxの5、SatAll/Admissibleの相手の2。全て保持 |
| 四移送の手修正の枝 | 39 | 35を編集 | −4。未編集はV_Refine/C_ResumeNorm/guardedと、Pred.Declaredだけを使うplain。plainはhCの追加が要るか再照合する。35はビルド成功件数ではない |
| 四移送の外のV_Raiseの明示arity | 4 | 5を編集 | +1。前群で増えたCaptureRegularityの1枝を含む |
| 既存Declared.tappの直接の枝 | 4 | 4を編集 | rawSubstV/norm/型shift/旧context。最後の旧contextは上位ビルド未確認 |
| 新たに必要と判明した手修正 | 計画外 | private shift_var_auxの2枝 | V_Sub/V_Refine。公開のwrapperと読者の追随も必要。未実装 |

[branch-inventory.json](branch-inventory.json) は四ファイルの明示したmatch枝の差分である。型shift32・値shift1・値subst1・narrowing1の計35。明示したmatch枝と、同じ証拠を返す成分を含む76構成子は別集合としている。全304枝を作り直してはいない。

`ReferencePreservation` の閉じた実引数のkindの取り出しも、出現ごとの存在Kを分解する旧形から、固定した空のCの第二射影へ書き換えた。これは基盤21宣言の表にない読者であり、まだ上位ビルドで検査できていない。

## 検査と公理依存

次のコマンドの作業ディレクトリは `formal/` である。失敗の後に直した下位モジュールの成功は、上位の成功を意味しない。初回失敗と修正後の記録は同じディレクトリの各json/logに保存した。

| コマンド | 終了 | 外側の時間 | 記録 |
|---|---:|---:|---|
| `lake build Benitoite.Release.Refinement.KindValues` | 0 | 24.732秒 | [l20-08-kindvalues.json](l20-08-kindvalues.json) |
| `lake build Benitoite.Release.Refinement.Admissible Benitoite.Release.Refinement.TypeRenaming` | 0 | 1.586秒 | [l20-09-admissible.json](l20-09-admissible.json) |
| `lake build Benitoite.Release.Refinement.Typing Benitoite.Release.Refinement.DeclaredTransport` | 0 | 8.154秒 | [l20-10-declared.json](l20-10-declared.json) |
| `lake build Benitoite.Release.Refinement.TypeShiftKinds Benitoite.Release.Refinement.AdmissibleMap` | 1 | 8.586秒 | [l20-13-shift-context-r1.json](l20-13-shift-context-r1.json) |
| `lake build Benitoite.Release.Refinement.TypeShiftContracts Benitoite.Release.Refinement.LegacyValues` | 1 | 3.003秒 | [l20-13-contracts-r2.json](l20-13-contracts-r2.json) |
| `lake build` | 1 | 9.598秒 | [stopped-default-build.json](stopped-default-build.json) |
| `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/a3a/stop-reproduction.lean` | 0 | 1.164秒 | [stop-reproduction-checked.json](stop-reproduction-checked.json) |
| `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/a3a/axioms-partial.lean` | 0 | 1.918秒 | [stopped-partial-axioms.json](stopped-partial-axioms.json) |

部分の公理依存は、型検査が通った下位18モジュールの全1482宣言（privateと生成宣言を含む）を `#print axioms` で照合した。許可一覧の外は0。対象と集計は [axioms-summary.json](axioms-summary.json)、宣言ごとの一覧は `axioms/`、入力は [axioms-partial.lean](axioms-partial.lean) である。旧主定理・主な十移送・新旧の既定全体を対象にするA-Lは未実施であり、部分の成功から全体を合格としない。初回の再現入力のelaboration失敗の出力にsorryAxが出たが、最終の終了0の三定理には残っていない。

最大常駐量は未取得（群A3aは計画上の非採取）。100 KBを超える生の記録は `<tmp>` に置き、[large-records.md](large-records.md) に大きさとSHA-256を保存した。恒久の根拠として、部分監査の対象名と各公理はモジュールごとのJSONへ写した。

## S12の切替条件と見込み

停止理由は、予定外の公開署名の変更が必要になったことである。固有の手修正が76枝を超える、又は固有の能動時間が42時間40分を超える根拠は、現在の差分からは得ていない。現在編集した四移送35枝と、追加が必要と判明したprivate補題2枝を区別する。案1へは切り替えていない。各局所ビルドの末でこの二つの切替条件を照合し、最後は公開署名の停止条件を優先した。

開始時のスナップショットから本結果文書を作る直前までは 708.2秒である。先行する読み込みの全外側時間は採取していない。能動時間と待ちを全区間で分離できないため、能動時間の実績値や残りへの倍率を作らない。個別のコマンドの外側時間は各jsonに残した。

残りは、当初の未完部分の見込みを縮めず、追加の補題の修正と呼出し側の追随30〜90分を別に見込む。A3a全体の暫定見込みは **5時間〜11時間50分**、起動依頼の上限20時間40分以内である。これは実測比による外挿ではなく、4時間30分〜10時間20分に計画外の30〜90分を足した値である。追加の公開署名の指定が改訂されるまで、実装を再開しない。

| 残り | 見込み | 担当・条件 |
|---|---:|---|
| 公開補題の署名の改訂・確認 | 不明 | 取りまとめ。主な十移送を維持し、上のhC追加案を判断 |
| private補題2枝・wrapper・ContextMap.shiftEの追随 | 30〜90分 | 指定改訂後の実装担当 |
| 上位読者・旧11橋・閉じた型・残る移送の局所検査 | 当初の未完分。2時間30分〜7時間30分 | 実装担当。次の局所ビルドで再見積り |
| 既定ビルド・全体公理依存・作業末の検査・結果照合 | 40〜70分 | 実装担当。上位のコンパイルが通ってから |
| 独立レビュー・受け入れ | 不明 | 取りまとめ・設計者 |

## 変更したファイル

既存ファイルはLean39、設計書の写し2の計41である。差分の行数とSHA-256は [changed-files.json](changed-files.json) に保存した。`plan.md`・`l20/detail.md`・既存のレビュー・処理系・旧Release・既定importは変更していない。

| ファイル（リポジトリからの相対パス） | 追加行 / 削除行 |
|---|---:|
| `formal/Benitoite/Release/Refinement/CaptureRegularity.lean` | 5 / 5 |
| `formal/Benitoite/Release/Refinement/Narrowing.lean` | 7 / 7 |
| `formal/Benitoite/Release/Refinement/TypingShift.lean` | 5 / 5 |
| `formal/Benitoite/Release/Refinement/SubstTyping.lean` | 10 / 10 |
| `formal/Benitoite/Release/Refinement/ReferencePreservation.lean` | 3 / 5 |
| `formal/Benitoite/Release/Refinement/ProgramTyping.lean` | 8 / 8 |
| `formal/Benitoite/Release/Refinement/AdmissibleMap.lean` | 3 / 3 |
| `formal/Benitoite/Release/Refinement/DeclaredTransport.lean` | 5 / 5 |
| `formal/Benitoite/Release/Refinement/HandlerContracts.lean` | 3 / 3 |
| `formal/Benitoite/Release/Refinement/LegacyKinds.lean` | 16 / 0 |
| `formal/Benitoite/Release/Refinement/Declared.lean` | 10 / 10 |
| `formal/Benitoite/Release/Refinement/External.lean` | 1 / 1 |
| `formal/Benitoite/Release/Refinement/ClosedCapture.lean` | 1 / 1 |
| `formal/Benitoite/Release/Refinement/TypeShiftContracts.lean` | 16 / 16 |
| `formal/Benitoite/Release/Refinement/TypeShiftExchange.lean` | 1 / 1 |
| `formal/Benitoite/Release/Refinement/KindValues.lean` | 7 / 9 |
| `formal/Benitoite/Release/Refinement/LegacyTables.lean` | 1 / 1 |
| `formal/Benitoite/Release/Refinement/SubstitutionContracts.lean` | 14 / 14 |
| `formal/Benitoite/Release/Refinement/LegacyDeclarations.lean` | 16 / 16 |
| `formal/Benitoite/Release/Refinement/ProgramWellFormed.lean` | 10 / 11 |
| `formal/Benitoite/Release/Refinement/Typing.lean` | 17 / 17 |
| `formal/Benitoite/Release/Refinement/TypeRenaming.lean` | 28 / 13 |
| `formal/Benitoite/Release/Refinement/TypingDeclared.lean` | 2 / 2 |
| `formal/Benitoite/Release/Refinement/StateTyping.lean` | 2 / 2 |
| `formal/Benitoite/Release/Refinement/LazyPreservation.lean` | 1 / 1 |
| `formal/Benitoite/Release/Refinement/TypeShiftKinds.lean` | 5 / 33 |
| `formal/Benitoite/Release/Refinement/Admissible.lean` | 10 / 10 |
| `formal/Benitoite/Release/Refinement/PathFacts.lean` | 2 / 2 |
| `formal/Benitoite/Release/Refinement/TypeShiftContext.lean` | 22 / 21 |
| `formal/Benitoite/Release/Refinement/Types.lean` | 19 / 0 |
| `formal/Benitoite/Release/Refinement/TypeArgumentRegularity.lean` | 1 / 1 |
| `formal/Benitoite/Release/Refinement/LegacyInput.lean` | 2 / 2 |
| `formal/Benitoite/Release/Refinement/ConstraintAssumptions.lean` | 11 / 11 |
| `formal/Benitoite/Release/Refinement/VarianceValidation.lean` | 2 / 2 |
| `formal/Benitoite/Release/Refinement/TypeShiftTyping.lean` | 43 / 42 |
| `formal/Benitoite/Release/Refinement/LegacyValues.lean` | 14 / 13 |
| `formal/Benitoite/Release/Refinement/Context/Facts.lean` | 1 / 1 |
| `formal/Benitoite/Release/Refinement/Context/Declarations.lean` | 7 / 11 |
| `formal/Benitoite/Release/Refinement/Context/WF.lean` | 2 / 2 |
| `docs/design/01-spec/01-12-core-calculus.md` | 11 / 9 |
| `docs/design/07-quality/07-04-formal-semantics.md` | 1 / 1 |

A3aの記録として本結果、完全署名、開始時のハッシュ、出現・枝・主な署名の比較、再現Lean、部分公理監査とその一覧、コマンドの終了と時間を追加した。これらは独立レビュー済み又は取り込み済みの記録ではない。

最後の完了条件の照合は [self-check.json](self-check.json)、入力・出力・構成の大きさとSHA-256は [artifact-manifest.json](artifact-manifest.json) に保存した。
