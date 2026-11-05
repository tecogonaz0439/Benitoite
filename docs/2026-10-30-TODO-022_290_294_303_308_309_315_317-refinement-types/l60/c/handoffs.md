# 後段へ渡す署名と受け口

完全名の共通の接頭辞は `Benitoite.Release.Refinement.` である。暗黙引数を含む全実型・型のSHA-256と直接の型/値の依存は、[audit-summary.json](audit-summary.json) のdeclarationsの分割記録へ保存する。読み取り経路は [readers.json](readers.json) にある。

| 受け手 | 入口 | 全量化・入力と結論 |
|---|---|---|
| D・L70 | ExternalModel.external_assumptions（継承） | 任意P/base/releaseの同じ拡張表の外部三条件。前段の実署名を変更せず使用 |
| D・L70・R50 | ExternalModel.response_value | 同じf/dのlookup・instantiate ts vs=some(a,e)、全ΨのExternalCarrier、v.Groundからvalの生応答を構成。carrierは本番で構成する証拠であり、新しいゲストの信頼条件ではない |
| D・L70 | ExternalModel.receive_value | 任意P/base/release/Ψ/f/d/ts/vs/a/e/v/obs、ExternalWF・lookup・同じ拡張BのExternalArgs・生応答・検査trueと任意σ。受信の等号と、元の型・閉性・同じσの適格性 |
| D・L70 | ExternalModel.receive_reject | 同じ全入力、検査falseから篩エラーの受信、任意σの生値の適格性、obs=[]。正常応答しか扱わない制限を加えない |
| D・L70 | ExternalModel.receive_error_no_exit | 任意の型付き入力とlookup、任意rのerr受信、全n/obsのexit所属の否定。元の三条件の署名を狭めない |
| E・G | ExternalModels.conditions | 任意ModelCase/Pと、元と同じModelのTrue・TargetsのHasFile・HttpのHasHttp。同じ拡張Bの25欄と外部3欄を返す。Core/TargetAgreementは群Aの既存の三モデルを使う |
| E・G・L70 | ExternalModels.shape_inputs / handle_inputs | 任意三表・全形・正常/拒否の両側・任意Ψ。宣言条件・ExternalWF・ExternalArgs・valの生応答・検査の真偽。handleは任意identityとborrow/own/State |
| G・L70・R50 | ExternalModels.responses | 任意三表・Ψ/σ/identity、全ShapeとList/dataの任意深さ。六正常形の受信の型・閉性・適格性、篩拒否、handleの全err/exitと同じ表の25+3条件 |
| E・G | ExternalModels.model_no_response_kind | 任意P/b/sの成功lookupの全場合からpure/io/exitを排除。io_kindの空疎は別に元のioResponse=Falseを使う |
| E・G | conditions.json | 87欄の行別分類。既存75=実質69/空疎6、新12=実質7/自明3/空疎2。保留6を今回判定、存在3は自明を保つ |

三モデルのCoreとTargetAgreementの既存の証明を再構成していない。通常資源の8葉と最終の87欄の接続・照合はE/G、全開始からExternalArgsを供給して全progress/preservation/step_soundへ合成するのはD/L70、両除外0件・Rust/Lean全比較はL70/R50の担当である。受信拒否したownのcleanupは既存のL70/R50の担当を保ち、通常資源のreleaseへ外部ハンドルを追加しない。U02の公開形、U05の交換版、CaptureReadBoundaryなどの既存の判断を選び直していない。
