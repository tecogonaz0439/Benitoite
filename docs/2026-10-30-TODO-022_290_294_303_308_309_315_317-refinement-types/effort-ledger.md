# 所要の記録（L00b.02 から）

設計者の指示（2026-10-31）により、作業の単位ごとに外側の時間とトークン数を記録する。測るための作業は置かず、普段の起動とレビューの記録から採る。

- 外側の時間: 起動から報告までの壁時計の時間（担当の能動時間の上限。待ちとの分離はしない）。
- トークン数: Codex は記録の末尾の `tokens used`（セッションの累計。再開したセッションは前の行との差も書く）、レビューのサブエージェントは完了の通知の `subagent_tokens`。
- 読み直しの量: 新しいセッションが最初の成果物を書くまでの量は、記録から分けられたときだけ書く。

| 日付 | 単位 | 担当 | セッション | 外側の時間 | トークン数 | 成果 |
|---|---|---|---|---:|---:|---|
| 2026-10-31 | L00b.02（最初の起動） | Codex（GPT-6.1-Sol、high） | 新規 | 約10分 | 172,575 | 契約の境界の確認で停止（`l00b.02/contract-boundary.md`）。大半は読むこと |
| 2026-10-31 | L00b.02 再開1（署名の下書き） | Codex | 同上の再開 | 約57分 | 累計438,156（差265,581） | `l00b.02/signatures.md` の初稿 |
| 2026-10-31 | RV-L00b.02-sig | Opus 5.5（medium） | 新規 | 約19分 | 286,464 | 条件付き可（重4・中8） |
| 2026-10-31 | L00b.02-r2（署名の改訂と起動単位） | Codex | 新規 | 約20分 | 227,909 | 署名の改訂、起動単位の表、`case-inventory.json` |
| 2026-10-31 | RV-L00b.02-sig2 | Opus 5.5（medium） | 新規 | 約10分 | 226,612 | 条件付き可（重なし、中3・軽6） |
| 2026-10-31 | L00b.02-r2 再開1（署名の追記・配分・.02a の着手） | Codex | r2 の再開 | 約22分 | 累計439,160（差211,251） | 署名の追記、三段の配分、ScopeSyntax.lean（16型・60構成子、5補題）。WF の保存の条件で停止 |
| 2026-10-31 | L00b.02-r2 再開2（.02a の続き） | Codex | r2 の再開 | 約28分 | 累計629,539（差190,379） | References の判断と WF の補題（12宣言）、Term20/Pred14 の下書き。参照と hide の条件で停止 |
| 2026-10-31 | L00b.02a（.02a の仕上げ） | Codex | 新規（01a18e1e） | 約102分 | 794,002 | 構文の全 sort（Ty21 など）、移動・置換・narrowing 各15場合、TypedFacts、宣言照合、Tel と kind。既定ビルド619ジョブ、公理は許可の三つだけ |
| 2026-10-31 | RV-L00b.02a | Opus 5.5（medium） | 新規 | 約8分 | 187,411 | 条件付き可（重1・中2・軽3）。重1は Dict[Cl, F] の kind |
| 2026-10-31 | L00b.02a-fix（RV の所見の対応） | Codex | 01a18e1e の再開 | 約25分 | 累計890,221（差96,219） | 重1を案 (i) で修正（TParamDecl.kind・ClassDecl.argumentKind）。中1・中2・軽2は後続の義務に固定、軽1・軽3は文書。ビルド619ジョブ、公理は三つだけ |
| 2026-10-31 | L00b.02b-values（値の葉、途中で停止） | Codex | 新規（01a18e9e） | 約38分 | 662,859 | V12/C9 まで（各族25場合）。sat/admits の置換での保存が署名から出ないため停止（案 A を推す） |
| 2026-10-31 | L00b.02b-values 再開1（案 A で仕上げ） | Codex | 01a18e9e の再開 | 約46分 | 累計1,187,677（差524,818） | V18/C12/Vs2/Each2＝各族34場合、Val19/Comp13・状態の構文・旧68遷移・step・埋め込み。案 A の四条件を ValueAssumptions に。ビルド636ジョブ、公理は三つだけ |
| 2026-10-31 | RV-L00b.02b-values | Opus 5.5（medium） | 新規 | 約13分 | 251,400 | 条件付き可（重なし、中2・軽5）。中1は旧の高カインド型の埋め込みの kind |
| 2026-10-31 | L00b.02b-values 再開2（所見の記録） | Codex | 01a18e9e の再開 | 約4分 | 累計1,236,420（差48,743） | 中1・中2・軽1〜5 を署名と義務の表に固定（本番は変えない） |
| 2026-10-31 | L00b.02b-external | Codex | 新規（01a18eff） | 約25分 | 603,813 | V2・C1・TelArgs2 の5導出（各族39場合）、外部の宣言表と三欄、無事象の3遷移（Step71）、Tel の逐次具体化の交換。ビルド640ジョブ、公理は三つだけ |
| 2026-10-31 | RV-L00b.02b-external | Opus 5.5（medium） | 新規 | 約11分 | 240,911 | 条件付き可（重なし、中1・軽4）。中1は外部の境界の篩をゲストに信頼させる点 |
| 2026-10-31 | L00b.02b-external 再開1（所見の対応） | Codex | 01a18eff の再開 | 約6分 | 累計831,746（差227,933） | 中1・軽1〜3 を署名と義務の表に、軽4 の正の例3つを境界入力に（本番は変えない） |
| 2026-10-31 | L00b.02b-at | Codex | 新規（01a18f27） | 約52分 | 486,292 | 保持値の V6・C2・Witness2、PathEnv の Valid・Required・Ready、At の準備、Adequate、CoreAssumptions の改訂、Event3・Step76。ビルド650ジョブ、公理は三つだけ |
| 2026-10-31 | RV-L00b.02b-at | Opus 5.5（medium） | 新規 | 約14分 | 284,234 | 条件付き可（重なし、中2・軽4）。中1は pathBases の署名の形の欄、中2は handler の下の発行 |
| 2026-10-31 | L00b.02b-at 再開1（所見の対応） | Codex | 01a18f27 の再開 | 約10分 | 累計629,069（差142,777） | pathBases_shape の欄と旧の欄の改訂、発行から handler の検査を外す、AtError.Closed を削除、Source から .loc を除く。ビルド650ジョブ、公理は三つだけ |
| 2026-10-31 | L00b.02b-handlers（着手で停止） | Codex | 新規（01a18f71） | 約11分 | 288,305 | 多相節で型パラメータを先頭に足すときの sat/admits の保存が出ないため停止（反例2つ）。0/14 |
| 2026-10-31 | L00b.02b-handlers 再開1（型パラメータの改名の一般形で仕上げ） | Codex | 01a18f71 の再開 | 約91分 | 累計1,152,370（差864,065） | 14/14 導出（C5・Arms3・Clauses2・Failure1・ImageOk3）、PatTy7／PatTys2／AltsTy・Inhabits・Exhaustive、三族の被覆義務63。TypeParamRenaming による sat/admits の保存を TypeAssumptions に。ビルド669ジョブ、公理は三つだけ |
| 2026-10-31 | RV-L00b.02b-handlers | Opus 5.5（medium） | 新規 | 約11分 | 233,000 | 条件付き可（重1・中1・軽3）。重1は guard の文脈が外側の構築器の専用操作を拒む点、中1は標準エラーの構成子一覧の固定 |
| 2026-10-31 | L00b.02b-handlers 再開2（所見の対応） | Codex | 01a18f71 の再開 | 約12分 | 累計1,246,352（差93,982） | 重1は guard を元の Ψ と広げた局所文脈に戻し三族の guard の場合を閉じ直す、中1は StandardErrorComplete を宣言表の構成子一覧で一般化、軽1〜3は署名と義務の表。ビルド669ジョブ、公理は三つだけ |
| 2026-10-31 | L00b.02b-closures | Codex | 新規（01a18fea） | 約37分 | 434,422 | 8/8導出（V_DependentLam/Closure、C_DependentApp、TelBody2/CaptureOk/ClosureTy/DependentClosureTy）、ContTy10・CellOk6・StoreOk・StateTyE4・StateTy、三族の被覆義務71、TypedFacts V28。ビルド671ジョブ、公理は三つだけ |
| 2026-10-31 | RV-L00b.02b-closures | Opus 5.5（medium） | 新規 | 約18分 | 369,938 | 不可（重3・中1・軽5）。StateTy が Step で保たれない反例を Lean で証明。開いたコードへ閉じた型を渡す箇所が三つ、中1は C_Handle の Eff.Covers |
| 2026-10-31 | L00b.02b-closures 再開1（所見の対応） | Codex | 01a18fea の再開 | 約54分 | 累計832,824（差398,402） | 重1〜3・中1・軽1を本番で修正、StoreTy.CaptureView、OpenCodeTy11／OpenArmsTy4 を追加、C_Handle を Eff.Sub へ戻す、遷移の正例23行19種類。ビルド671ジョブ、公理は三つだけ |
| 2026-10-31 | RV-L00b.02b-closures-r2 | Opus 5.5（medium） | 新規 | 約18分 | 334,916 | 条件付き可（重なし、中3・軽3）。前回の重1〜3・中1は解消。中2は OpenCodeTy より局所文脈に kind を残す案が軽い、中1はソースの行の Annotation、中3は遷移の表の不足 |
| 2026-10-31 | L00b.02b-closures 再開2（構造の差し替え） | Codex | 01a18fea の再開 | 約35分 | 累計1,412,356（差579,532） | OpenCodeTy など7定義を削除し、ClosureTy.mk が code0・L・ρ を保持する形へ。ClosureTy を相互帰納の外へ（17→14型）。resolveLocals と交換の補題、遷移の正例30行23種類。ビルド673ジョブ、公理は三つだけ |
| 2026-10-31 | RV-L00b.02b-closures-r3 | Opus 5.5（medium） | 新規 | 約21分 | 382,582 | 条件付き可（重なし、中3・軽3）。差し替えの本体は成立。中1は K_Handle と CaptureOk の接続、中2は全遷移が依存する補題の不足（証明済み）、中3は builderBody_keepsBound の前提 |
| 2026-10-31 | L00b.02b-closures 再開3（所見の対応） | Codex | 01a18fea の再開 | 約18分 | 累計1,945,974（差533,618） | CaptureOk の継続の項目で行を読まない形へ（案 (a)）、K_Handle にソースの ts、恒等・開放の補題を本番へ、builderBody_image、遷移の正例37行23種類。ビルド673ジョブ、公理は三つだけ |
| 2026-10-31 | RV-L00b.02b-closures-r4（絞った確認） | Opus 5.5（medium） | 新規 | 約9分 | 230,591 | 条件付き可（重なし、中1・軽2）。緩和の範囲は正しい。定義の変更なし、義務を L20 へ |
| 2026-10-31 | L00b.02c | Codex | 新規（01a190b2） | 約19分 | 281,733 | Shared.Integer／Interval／Approximation と adapter、Release.Syntax に依存しない共有層、ValueApprox4／ApproxValue3／FlowApprox1／EvalResult3。ビルド683ジョブ、公理は三つだけ |
| 2026-10-31 | RV-L00b.02c | Opus 5.5（medium） | 新規 | 約8分 | 205,661 | 条件付き可（重なし、中2・軽4）。本番は変えず、失敗の所属と実解析の出力の写しを O169 へ |
| 2026-10-31 | L00b.03 | Codex | 新規（01a190cf） | 約29分 | 377,306 | Context/ の4モジュール（公開定義18・定理69）。Ctx.Ordered／Regular、facts の再構成、宣言順の入力列、kind の固定、緩い捕捉の延長。入口の正例・負例54定理。ビルド687ジョブ、公理は三つだけ |
| 2026-10-31 | RV-L00b.03 | Opus 5.5（medium） | 新規 | 約12分 | 303,714 | 条件付き可（重なし、中2・軽6）。中1は参照順序を読む判断がないこと、中2は extendNone の形を作る遷移がないこと |
| 2026-10-31 | L00b.03 再開1（所見の対応） | Codex | 01a190cf の再開 | 約9分 | 累計443,082（差65,776） | 順序をソースの注釈の判断に、Regular.hideConts／bindParams、extendHidden／extendCont、Ctx.Depends、Pred.WellFormed へ改名。ビルド687ジョブ、公理は三つだけ |
| 2026-10-31 | L00b.04 | Codex | 新規（01a19100） | 約31分 | 322,468 | 7モジュール。Term.observe、Pred.evalClosed と健全性・完全性、Entails.closed／ground、全入れ子の carrier、externalCheck と checked_typed。正例・負例81定理。ビルド694ジョブ、公理は三つだけ |
| 2026-10-31 | RV-L00b.04 | Opus 5.5（medium） | 新規 | 約11分 | 264,037 | 条件付き可（重なし、中1・軽6）。中1は And/Or が両側の成功を要求し、型付けできる値を受信検査が拒む点（設計者の判断へ） |
| 2026-10-31 | L00b.04 再開1（軽の対応） | Codex | 01a19100 の再開 | 約13分 | 累計747,413（差424,945） | ExternalCarrier.accepted、鍵の縮約の一致、termReady_observation、再帰する data の正例と負例 |
| 2026-10-31 | L00b.04 再開2（強い Kleene の三値） | Codex | 01a19100 の再開 | 約9分 | 累計857,182（差109,769） | evalWith の And／Or を改め、片側で決まる場合の補題8、真理値表と境界29定理。ビルド694ジョブ、公理は三つだけ |
| 2026-10-31 | L00b.05 | Codex | 新規（01a19142） | 約15分 | 244,191 | Certificate.lean（EqProof4・BuiltinLemma2・Certificate6）、external_typed を Outcome.Carrier へ改訂、E_External・step に受信検査を接続。成功と違反の StateTy→Step→StateTy。ビルド697ジョブ、公理は三つだけ |
| 2026-10-31 | RV-L00b.05 | Opus 5.5（medium） | 新規 | 約8分 | 221,750 | 可（重なし、中なし、軽6）。external_typed の改訂は承認の範囲 |
| 2026-10-31 | L00b.05 再開1（軽の対応） | Codex | 01a19142 の再開 | 約10分 | 累計302,055（差57,864） | 引数を持つ宣言の受理・拒否の例、general_val／general_no_exit を本番へ、残りの義務を署名へ |
