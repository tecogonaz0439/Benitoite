# 担当 spec-copies の記録（L70.45 のうち削除に依らない写し）

- 開始 2026-11-07 08:20 JST、終了 2026-11-07 08:40 JST（外側の時間。資料読みを含む）。
- 作業木 `Benitoite-l70g`（ブランチ `m014/l70.g`、基準 `eb4f0ef9`）。git の書き込み操作、`scripts/check.sh`・`check-formal.sh` の実行はしていない。一時領域 `/private/tmp/benitoite-l70-g/` は読むだけである。
- 根拠: [results.md](results.md)、[exchange-contract.md](exchange-contract.md)、[scope-rules.md](scope-rules.md)、[prepare-surface.md](prepare-surface.md)、[coverage-entries.md](coverage-entries.md)、[entries-closure.md](entries-closure.md)、[interval-results.md](interval-results.md)、[exchange-results.md](exchange-results.md)、[modules-for-spec.md](modules-for-spec.md)、各モジュールの実物。Codex の担当の写しの候補（一時領域の `spec-candidates/fragments/`）は読んだが写していない（下の「書かずに残したもの」の 5）。

## 変えたファイル

| ファイル | 変更 |
|---|---|
| `docs/design/01-spec/01-12-core-calculus.md` | 下の表の 01-12 の行 |
| `docs/design/07-quality/07-04-formal-semantics.md` | 下の表の 07-04 の行 |
| `formal/README.md` | 段階 E1・E2 の表に `Release/Refinement/CoverageShow.lean`、`Exchange/RefinedJson.lean`、`Exchange/FormationTypes.lean`・`CheckSupport.lean`、`Exchange/BuiltinAgreement.lean` の4行を足した |
| `formal/Benitoite/Release/Refinement/AtInput.lean`・`AtPatternText.lean` | コメントの「設計書 01-07「範囲」」を、01-07 に実在する見出し「閉じた範囲引数」へ直した（各1行。コメントだけ） |

用語集は変えていない（新しい術語を足していない）。

## 写した節と根拠のモジュール

| 写した内容 | 書いた箇所 | 根拠のモジュール・宣言 |
|---|---|---|
| 交換の論理の証明書の鍵（位置と番号）の決め方、重複の拒否、鍵のない問い合わせ | 01-12「篩を含む表層の検査と受理」の `ExchangeCertificate` の段落の次（新しい段落） | `CheckInferCertificates.logicProof`、`CheckTables.checkProgram`（根 `[0]`・`[1]`）、`CheckDeclarations`（`path ++ [1]`・メソッドの番号）、`Exchange.CheckInput.certificateTable`、`Exchange.LogicCertificateEntry.validate` |
| 検査の表の構成元（`.standard` が表と構成の等号を持つ、検査器が実行できる） | 01-12 同節の `Check.BuiltinSource` の段落、07-04「篩を含む形式化の範囲」の `Surface.CheckOpen` の段落 | `Surface/CheckBuiltinSource.lean` |
| 部分適用のラムダの選択の有限判定と `holeLam` の csimp | 07-04 同範囲の `Surface.Desugar` の段落の末尾、対応の表の `ValueRenamingFixed` の行 | `ValueRenamingFixed`（`Ty.renameFixed`・`Eff.renameFixed`・`shiftImage_pair_iff`）、`Surface.Desugar`（`holeLamDecide`・`holeLam_eq_decide`） |
| 入力の準備と健全性（`prepare_sound`）、交換した表と標準表の有限の一致の判定（`BuiltinAgreement`）と、その結論の範囲（`q.B = complete L T A` を与えないこと） | 07-04「証明する性質」の `SurfaceStandardSupport` の段落の次（新しい二段落） | `Exchange.CheckInput`（`prepare`・`prepare_sound`・`prepare_agrees`）、`Exchange.CheckSupport`、`Exchange.FormationTypes`、`Exchange.BuiltinAgreement`（`standardCheck`・`standardCheck_sound`・`agrees_complete`）、`SurfaceLibrary` の `hB` |
| 受理の規則と健全性（篩付きの表層） | 01-12「篩を含む表層の検査と受理」の末尾（新しい【決定】と表と二段落）、07-04 の `Surface.Identity` の段落、対応の表の `Surface.ScopeRules・Surface.ScopeSound` の行、「形式化で仮定するもの」の `patterns`・`hosts` の項目と対象の解析の【決定】 | `Surface.ScopeRules`、`Surface.ScopeSound`（`productionRules`・`agreed`・`productionRules_sound`・`modelTargets_contract`・`modelHttp_contract`）、`Exchange.Observe`（`acceptInput`・`acceptInput_sound`・`acceptInput_tableSound`・`acceptInput_none_noRules`） |
| 網羅性の表示 | 07-04「01-12 との対応」の `CoverageShow` の段落、対応の表の `CoverageShow` の行 | `Release.Refinement.CoverageShow` |
| 7入口が篩付きの判断を読むこと | 07-04「道具と置き場所」の新しい【決定】、対応の状態の表の「型検査器の入口の必須の判定の受理」の行の末尾の一文 | 7入口の本文、[entries-closure.md](entries-closure.md) の閉包の結果（旧 Surface は区間の入力の構文だけ、`Core` 0、旧の判断・主定理の名前 0） |
| 区間の接続（旧構文への写し、コードの関係、報告の三成分） | 01-12「区間解析の独立交換の読者」の冒頭の【決定】の一文・表の次の新しい段落・`analyzeCorpus` の段落、01-12「篩を含む状態の型付け」の `EnvRel` の段落と `IntervalConnectionExamples` の次の新しい段落、07-04 の同じ二箇所、対応の表の `IntervalReport`・`Surface.SourceRename・Surface.FieldPlacement` の行 | `Interval.SurfaceSyntax`（`eraseExpr`・`eraseBlock`・`eraseTy_embed` ほか）、`Interval.SurfaceCode`、`Surface.SourceRename`、`Interval.ReportFlow`、`Release.Refinement.IntervalReport`（`Connection`・`connect`）、`Interval.Exchange` の `reportFlowJson` |
| 外部除外の段落（O157） | 07-04 の対応の状態の表の「外部の関数と外部の型」の行、「区間解析を含む全比較への接続」の `externalType` の段落 | 処理系の書き出し（`desugar_export`・`interval/manifest.rs`。変えていない）、`Exchange.Syntax`・`Convert`（外部の型・参照・宣言表）、`CheckSupport.formedExternal`、`Interval.SurfaceSyntax.eraseTy`（外部型→不透明型）・外部関数の参照→空名の関数参照 |

` ```text ` のブロックと見出しは変えていないので、`cargo test --test spec_examples` は実行していない。新しいリンクは足しておらず、変えた段落の既存のリンクは元のまま残した。Lean のコメントの変更はコメントだけなので、Lean の検査は実行していない。

## 書かずに残したもの（L70.42・L70.44 の後に直す箇所）

1. 交換の版の段落（L70.42 の担当）: 07-04「道具と置き場所」の「交換の読者は corpus 8・…・15 …を受理する」の段落（同じ段落に「`surfaceCheck`・`surfaceCheckAll` は型検査器の入口（`CheckAccept.checkProgramAccepted`）を使い」の文がある）、「六つの入口は corpus 15 …を受け付ける」の段落、「交換の形式の版」の節（`Exchange/Observe.lean` の必須の判定の入力の段落を含む）、「区間解析の独立交換の読者」の `surfaceVersion: 14` か `15` の記述と、「区間解析を含む全比較への接続」の「Surface 14」。区間の交換は表層の版16だけを受ける（[interval-results.md](interval-results.md)）ので、これらは版の担当が直す。
2. 旧 `Benitoite.Surface` の Scope のモジュールを正とする節（L70.44 の後）: 01-12「Scope の局所解析の状態と規則の表」「Scope の局所解析の予算と忘却」「Scope の局所解析の表層からの対応」「Scope の必須の判定の受理と拒否の理由」「Scope の局所解析の接続定理」の【決定】は `Benitoite.Surface.ScopeState`・`ScopeLower`・`ScopeAccept`・`ScopeSound` を正とする。07-04 の「証明する性質」の接続定理の【決定】（`Surface/ScopeSound.lean`、`scope_check_connection` ほか）、「形式化で仮定するもの」の Scope の【方針】のモジュールの並び、対応の状態の表の Scope の4行も同じである。篩付きの表層の規則と健全性は今回 01-12「篩を含む表層の検査と受理」に写したので、削除の後は旧の節を篩付きのモジュールへ改めるか除く。
3. 形式化のモジュールの表のうち削除で変わる部分（L70.44 の後）: 07-04「01-12 との対応」の旧 `Release`・旧 Surface の記述、残す旧 Release のモジュールの一覧と役割（F09 の三つ目の条件。[modules-for-spec.md](modules-for-spec.md) の三表は削除の閉包で確定してから写す）。`formal/README.md` の段階 A（`Core/`）・段階 C（`Surface/`）・旧 `Release/CoverageShow.lean` の行。
4. 規範の位置付けの段落（L70.44 の後）: 01-12「本章の位置付け」、07-04「目的と範囲」（「篩型は初回リリース版に含めない」）と「証明する性質」の冒頭（「性質 1〜3 の全体の証明は `Benitoite.Release` …について述べる」）。新判断だけを規範とする文は、旧主定理の削除と同じ変更で書く。
5. Codex の担当の写しの候補の断片（一時領域）は写していない。01-12 の位置付けの断片と 07-04 の進め方・性質の断片は 4 に当たり、削除の後の状態を前提にしている。07-04 の仮定の断片のうち、有限支持の形成と証明書の再検査の内容は今回の `prepare` と証明書の鍵の段落に含めた。`scopeAcceptance` を「Lean は文字列の解析を証明せず…表を検査する」とする断片の文は、表の項目を形式化した解析と照らす今の実装（`agreed`）と合わないので採らなかった。
6. [modules-for-spec.md](modules-for-spec.md) の最初の表の `Exchange.CanonicalNames` の行（読者を `Exchange.CheckInput` とする）は今の実装と合わない。`CanonicalNames` は既定 import の閉包に無く、読者も無い（取りまとめの判断で名前の写しは採らない）。設計書には書いていない。

## 取りまとめに判断を求める点・申し送り

1. 旧 `Surface.ScopeSound` の接続定理（`scope_check_connection`・`scope_local_connection`・`scope_local_typed`・`evalScope_core_step`・`scope_check_core`・`http_check_connection` ほか）は、篩付きの表層へ移していない（[scope-rules.md](scope-rules.md) の「移していないもの」）。L70.44 で旧 Surface を削除すると、07-04「証明する性質」の接続定理の【決定】の対象が無くなる。新しい表層へ移すか、【決定】を除くかの判断が要る。
2. 受理の成功値の構成子の名前: 01-12 の新しい段落に、交換の入口が ok を `"Ok"` とすること、δ の成功値は `Result.Ok` なので健全性が成功値の対応を述べるのは ok を `"Result.Ok"` とした場合であることを、実装どおりに書いた（results.md の判断点 2）。名前の結び方を変えたら、この一文を直す。
3. コメントの見出しの誤り（受け持ちの外なので直していない）: `Release/Refinement/Surface/Desugar.lean` の `holeLam_eq_decide` の docstring と `Release/Refinement/ValueRenamingFixed.lean` のモジュールのコメントは「設計書 01-12「部分適用」」を引くが、01-12 にその見出しは無い。写しは 07-04「篩を含む形式化の範囲」の `Surface.Desugar` の段落に置いたので、そこを引く形に直すとよい。
4. `Exchange.RefinedExamples` は既定 import の閉包に無い（どのモジュールも import しない）。[exchange-results.md](exchange-results.md) は既定ビルドの読者・適用例とするが、根の `Benitoite.lean` に入るまで `#guard` は既定ビルドで実行されない。設計書には書いていない。
5. 7入口の依存の照合の記述（07-04「道具と置き場所」の新しい【決定】）は [entries-closure.md](entries-closure.md) の結果（照合時の作業木の状態）に基づく。群 D との結合と L70.44 の削除の後に同じ台本を再実行し、結果が変われば一文を直す。
