# DET-R01〜26の内外の区別

解析済みの内側の境界は実定理・実定義へ対応する。字句・CLI・外部・公開形の既存所有を、内側の成功から完了へ繰り上げない。

| ID | 要求 | 判定と根拠 | 未実装の受け口・所有 |
|---|---|---|---|
| DET-R01 | 相対範囲の起点は入口 root。祖先探索なし | 後段の所有。解析済みの内側の型を根拠とし、未実装の字句/CLIの拒否を完了としない。 `Benitoite.Release.Refinement.AtPrepare`、`Benitoite.Release.Refinement.RangeExpr`、`Benitoite.Release.Refinement.TargetInput` | R30/R70の字句・CLI・起動/設定の実入力 |
| DET-R02 | パターンの .. を正規化せず拒否する | 後段の所有。解析済みの内側の型を根拠とし、未実装の字句/CLIの拒否を完了としない。 `Benitoite.Release.Refinement.AtPrepare`、`Benitoite.Release.Refinement.RangeExpr`、`Benitoite.Release.Refinement.TargetInput` | R30/R70の字句・CLI・起動/設定の実入力 |
| DET-R03 | パターンの dot/空要素/余分な末尾/を拒否し、. と先頭 ./ の特例を保つ | 後段の所有。解析済みの内側の型を根拠とし、未実装の字句/CLIの拒否を完了としない。 `Benitoite.Release.Refinement.AtPrepare`、`Benitoite.Release.Refinement.RangeExpr`、`Benitoite.Release.Refinement.TargetInput` | R30/R70の字句・CLI・起動/設定の実入力 |
| DET-R04 | wildcard は末尾 /** だけ | 後段の所有。解析済みの内側の型を根拠とし、未実装の字句/CLIの拒否を完了としない。 `Benitoite.Release.Refinement.AtPrepare`、`Benitoite.Release.Refinement.RangeExpr`、`Benitoite.Release.Refinement.TargetInput` | R30/R70の字句・CLI・起動/設定の実入力 |
| DET-R05 | ~user を拒否する | 後段の所有。解析済みの内側の型を根拠とし、未実装の字句/CLIの拒否を完了としない。 `Benitoite.Release.Refinement.AtPrepare`、`Benitoite.Release.Refinement.RangeExpr`、`Benitoite.Release.Refinement.TargetInput` | R30/R70の字句・CLI・起動/設定の実入力 |
| DET-R06 | 任意の環境変数/独自の {name} を展開しない | 後段の所有。解析済みの内側の型を根拠とし、未実装の字句/CLIの拒否を完了としない。 `Benitoite.Release.Refinement.AtPrepare`、`Benitoite.Release.Refinement.RangeExpr`、`Benitoite.Release.Refinement.TargetInput` | R30/R70の字句・CLI・起動/設定の実入力 |
| DET-R07 | NUL/逆斜線/非UTF-8 をこの表記の受理領域に足さない | 後段の所有。解析済みの内側の型を根拠とし、未実装の字句/CLIの拒否を完了としない。 `Benitoite.Release.Refinement.AtPrepare`、`Benitoite.Release.Refinement.RangeExpr`、`Benitoite.Release.Refinement.TargetInput` | R30/R70の字句・CLI・起動/設定の実入力 |
| DET-R08 | 異なる起点をまたぐ静的被覆を認めない | 内側完了・実装の照合は後段。起点差の静的拒否を全σで完了 `Benitoite.Release.Refinement.ScopedTargetExamples.equal_resolution_distinct_base` | R10b/R30/R50/R70/V10の同じ独立期待の実入力 |
| DET-R09 | 一原子を複数原子の和で覆う判定を追加しない | 内側完了・実装の照合は後段。意味上の和と一原子の静的被覆を区別 `Benitoite.Release.Refinement.ScopedTargetExamples.split_endpoint` | R10b/R30/R50/R70/V10の同じ独立期待の実入力 |
| DET-R10 | secrets は単独範囲で、接尾辞/単一対象としての自動選択を認めない | 後段の所有。任意一覧・未指定・空の内側の意味は証明済み。CLIの単独名/接尾辞/混在・登録値の解析は未実装。 `Benitoite.Release.Refinement.ScopedTargetExamples.secrets_members`、`Benitoite.Release.Refinement.PathEnv.Ready.resolve_required` | R30/R70の字句・CLI・起動/設定の実入力 |
| DET-R11 | 必要な基準の未束縛は拒否又は明示 Error。cwd/temp で代用しない | 内側完了・実装の照合は後段。既知契約の必要束縛と動的Errorを分離 `Benitoite.Release.Refinement.PathEnv.Ready.resolve_required`、`Benitoite.Release.Refinement.AtPrepare.error_saved` | R10b/R30/R50/R70/V10の同じ独立期待の実入力 |
| DET-R12 | PathBases を record/JSON/外部型から偽造できない | 内側完了・実装の照合は後段。ソースからpathBasesの直接生成を拒否する内側の定義 `Benitoite.Release.Refinement.Val.Source`、`Benitoite.Release.Refinement.Val.SourceScoped` | R10b/R30/R50/R70/V10の同じ独立期待の実入力 |
| DET-R13 | 旧 checkPath/checkPathIn は絶対形だけ。相対形には bases を渡す At を使う | 内側完了・実装の照合は後段。旧純粋APIは絶対形だけ。実δでは相対/home形を明示Errorへ `Benitoite.Release.Refinement.ScopeLegacyContracts.relative_rejected`、`Benitoite.Release.Refinement.ScopeDelta.input_errors` | R10b/R30/R50/R70/V10の同じ独立期待の実入力 |
| DET-R14 | 任意の実行時基準表/秘密一覧を型/効果へ直接埋め込まない | 内側完了・実装の照合は後段。実行時の一覧はσに保持。静的な構文の範囲へ任意一覧を埋め込まない `Benitoite.Release.Refinement.RangeExpr`、`Benitoite.Release.Refinement.RangeExpr.Mem` | R10b/R30/R50/R70/V10の同じ独立期待の実入力 |
| DET-R15 | external 交換でも内部構築/表現パターン/JSON 偽造を認めない | 後段の所有。外部の型付き応答条件の供給は未実装。空の外部関係から存在を導かない。 `Benitoite.Release.Refinement.Builtins.ExternalAssumptions.external_exists`、`Benitoite.Release.Refinement.Val.Source` | L60の外部の名目性、R50の交換、R30の偽造拒否 |
| DET-R16 | W0405 は通常受理し、deny-warnings だけ不合格とする | 後段の所有。解析済みの内側の型を根拠とし、未実装の字句/CLIの拒否を完了としない。 `Benitoite.Release.Refinement.AtPrepare`、`Benitoite.Release.Refinement.RangeExpr`、`Benitoite.Release.Refinement.TargetInput` | R30/R70の字句・CLI・起動/設定の実入力 |
| DET-R17 | 動的な対象の相対形はその実行の cwd から解く | 内側完了・実装の照合は後段。動的な相対対象は同じσのcwd、home形はhome `Benitoite.Release.Refinement.TargetInput.resolve` | R10b/R30/R50/R70/V10の同じ独立期待の実入力 |
| DET-R18 | root の上書き引数を追加しない | 後段の所有。解析済みの内側の型を根拠とし、未実装の字句/CLIの拒否を完了としない。 `Benitoite.Release.Refinement.AtPrepare`、`Benitoite.Release.Refinement.RangeExpr`、`Benitoite.Release.Refinement.TargetInput` | R30/R70の字句・CLI・起動/設定の実入力 |
| DET-R19 | secrets の空一覧と非空指定を混在できない | 後段の所有。任意一覧・未指定・空の内側の意味は証明済み。CLIの単独名/接尾辞/混在・登録値の解析は未実装。 `Benitoite.Release.Refinement.ScopedTargetExamples.secrets_members`、`Benitoite.Release.Refinement.PathEnv.Ready.resolve_required` | R30/R70の字句・CLI・起動/設定の実入力 |
| DET-R20 | 成功値の射影は解決済み絶対パスを返す | 内側完了・実装の照合は後段。同じ保持絶対対象の射影を完了 `Benitoite.Release.Refinement.ScopedTargetExamples.absolute_projection` | R10b/R30/R50/R70/V10の同じ独立期待の実入力 |
| DET-R21 | CLI の `work`・`tmp`・`secrets` 登録値は絶対形又は ~。裸の相対形/自己参照を拒否 | 後段の所有。任意一覧・未指定・空の内側の意味は証明済み。CLIの単独名/接尾辞/混在・登録値の解析は未実装。 `Benitoite.Release.Refinement.ScopedTargetExamples.secrets_members`、`Benitoite.Release.Refinement.PathEnv.Ready.resolve_required` | R30/R70の字句・CLI・起動/設定の実入力 |
| DET-R22 | ScopeError に At 用の公開構成子を追加する | 後段の所有。内部九欄の保存と七Stringの暫定観測を根拠にし、公開形は選択していない。 `Benitoite.Release.Refinement.AtErrorReaders.check_reader`、`Benitoite.Release.Refinement.ResultShape.Declared`、`Benitoite.Release.Refinement.Program.StandardErrorComplete` | U02確定後・L70前の公開写し、R60の公開構成子/診断 |
| DET-R23 | 動的対象の ..・途中dot・空要素・余分な末尾/を拒否する | 後段の所有。解析済みの内側の型を根拠とし、未実装の字句/CLIの拒否を完了としない。 `Benitoite.Release.Refinement.AtPrepare`、`Benitoite.Release.Refinement.RangeExpr`、`Benitoite.Release.Refinement.TargetInput` | R30/R70の字句・CLI・起動/設定の実入力 |
| DET-R24 | ファイル指定では設定を読まず dependency を使えない | 後段の所有。解析済みの内側の型を根拠とし、未実装の字句/CLIの拒否を完了としない。 `Benitoite.Release.Refinement.AtPrepare`、`Benitoite.Release.Refinement.RangeExpr`、`Benitoite.Release.Refinement.TargetInput` | R30/R70の字句・CLI・起動/設定の実入力 |
| DET-R25 | 隣の設定へ警告せず、root は元の入口指定で決める | 後段の所有。解析済みの内側の型を根拠とし、未実装の字句/CLIの拒否を完了としない。 `Benitoite.Release.Refinement.AtPrepare`、`Benitoite.Release.Refinement.RangeExpr`、`Benitoite.Release.Refinement.TargetInput` | R30/R70の字句・CLI・起動/設定の実入力 |
| DET-R26 | project の入口先頭にも language/dependency を許し、二か所は E0911 | 後段の所有。解析済みの内側の型を根拠とし、未実装の字句/CLIの拒否を完了としない。 `Benitoite.Release.Refinement.AtPrepare`、`Benitoite.Release.Refinement.RangeExpr`、`Benitoite.Release.Refinement.TargetInput` | R30/R70の字句・CLI・起動/設定の実入力 |
