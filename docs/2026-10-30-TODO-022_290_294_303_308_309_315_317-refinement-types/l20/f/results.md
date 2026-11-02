# 群 F・G の結果

2026-11-02。対象は L20.71〜.84、基準 B_WORK は `ee5fe230f6decb8bbc8798ee2df280c8fa481504`。指定されたブランチは `m014/l20.f` であり、担当によるブランチ操作・コミットはしていない。署名は [signatures.md](signatures.md)、手書きの宣言の一覧は [declarations.md](declarations.md)、公理依存の検査入力は [axioms.lean](axioms.lean) に置く。生の出力は `<tmp>` に置き、この記録には要約・大きさ・SHA-256 だけを残す。

## 完了条件の照合

| 単位 | 判定 | 証拠と入力の供給 |
|---|---|---|
| .71 | 証明済み | `CloseTyping` の通常値・callable・保持値。元の型付け、CaptureOk、場所の三条件から閉じた値を構成 |
| .72 | 証明済み | `close_lambda`。hideBuilders/hideConts、元の本体と捕捉、toTel と正規化を使う |
| .73 | 証明済み | `close_dependent_lambda` と V_Closure。通常・依存 lambda の code と cap、既存 closure の runtime/contract を保持 |
| .74 | 証明済み | V_Sub の IH、CaptureOk.transport、LeQ.bind、移送先の注釈 |
| .75 | 証明済み | V_Normal の IH と substTyValues_norm_source |
| .76 | 証明済み | V_Refine の観測成功、closeVal_observation、述語の開閉の交換、元の Entails の移送 |
| .77 | 証明済み | V29・Vs2・Each2 の33 case の相互帰納。公開した三入口へ合成 |
| .78 | 一部（記した範囲は証明済み） | `ClosureViewTy` と view_typed による通常値の閉じた型付けと a/e/R の保持。app・meth・ret の個別の入口も公開。各構文の型・行像の取り出しは L20.110〜.115 |
| .79 | 証明済み | S06 の二入口。零引数の foldl_nil と同じ cap/code、結果・効果・R の代入 |
| .80 | 証明済み | TelBodyTy.capture_all と TelArgs の逐次具体化、Capture.openTel、捕捉の延長 |
| .81 | 証明済み | ClosureTy.apply_all と DependentClosureTy.apply_all。任意 Γ/Φ/cap、局所参照、入力なしの結果を含む |
| .82 | 証明済み | let_step・return_step・mark_step。任意の型付き v、K_Sub、R の shift と実引数の置換の消去、markPush |
| .83 | 証明済み | fun_step・method_step・super_step。宣言本体への S02、辞書と引数の順序、QTel の移送、dependent_result_close の使用。一般の値依存と述語・Φ の等式は後続の入口に向けて公開 |
| .84 | 証明済み | dependent_beta_all。任意の元 StateTyE、cap、零・多引数から Semantics.E_Lam の行先と同じ σ/Eb の型付け |

各状態の葉は `StateTyE` と `StateTy` の双方の入口を持つ。規則の lookup・view・個数以外に、行先のコードの型付けを独立の入力として持つ葉はない。新しい公理・独立の信頼条件・型付け規則・ValueMeaning の定義は追加していない。closeVal の33 case に閉じない case はない。.78 の各構文の型・行像の取り出しは後続の単位に残る。全76遷移のうち本作業が受け持つ七つの遷移以外を完了したとは扱わない。

| 義務 | 担当範囲の判定・証拠 | 残る段 |
|---|---|---|
| O008 | 環境を捨てる反例を [boundary.lean](boundary.lean) で再確認した。保管元から必要な34宣言（macro を含む）だけを写し、body_typed の C_If に観測の等号と真偽の条件を加えた。formal で `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/f/boundary.lean` が終了0、1.053秒。生成分を含む44宣言の公理依存も許可された三公理だけである | .78 の型・行像を含む L20.110〜.115、L40 の開始逆転、L70 の主定理。義務全体の閉鎖とはしない |

boundary の environment_counterexample は、同じ Γ と型付き像を持つ二つの捕捉について、Φ が一方では成立し、他方では成立しないことを示す。body_requires_phi は本体の必要な篩が Γ の事実だけからは出ないことを示す。捕捉を捨てると view の値が変わり、空の捕捉で Φ の評価が失敗する二例も含む。保管元の l00b.14b/boundary.lean は変更していない。

## S06 の確定した署名

`ClosureTy.apply_all` は、P.WellFormed、P.WellTyped B、B.CoreAssumptions P、StoreOk、元の `ClosureTy … ss R q a e`、閉じた実引数の `HasTypeVsQ … vs ss` と Ground を受ける。`ν = (Capture.empty.extendMany vs).env` として、結論は次である。

```lean
ClosureTy P B Ψ [] (R.map (substTyValues ν)) (q.apply vs)
  (substTyValues ν a) (substEffValues ν e)
```

ss は閉じた非依存の入力型の列である。a/e/R の実引数への依存を結論から落とさない。中間の `cap.closeRAt vs.length Rs` と元の局所参照を保持し、CaptureLocals.apply_all と捕捉の合成の等式で実際の延長へ合わせる。

`DependentClosureTy.apply_all` は同じプログラム・組み込み・ストアの前提、元の `DependentClosureTy P B Ψ q t`、`HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs t a e` と Ground を受け、`ClosureTy P B Ψ [] (some a) (q.apply vs) a e` を結論する。後続の依存列を一引数ずつ具体化するため、依存する入力を非依存の ss に押し込めない。完全な量化と全引数は signatures の ClosureApply の節に記す。

## closeVal の33 case

以下のすべてが `close_value_aux`・`close_values_aux`・`close_each_aux` の同じ相互帰納に入る。「値置換」は元の導出へ既存の HasTypeVQ.subst を適用し、その構文では closeVal と一致することを示す枝である。

| case | 処理と保持する条件 | 結果 |
|---|---|---|
| V_Var | 捕捉した位置の型付き像 | 閉鎖 |
| V_Const | 値置換。ConstOK を保持 | 閉鎖 |
| V_Lam | 元の本体と cap、hideConts/hideBuilders、toTel | 閉鎖 |
| V_DependentLam | 元の TelBodyTy と cap、実行の依存列 | 閉鎖 |
| V_Closure | 値置換。元の runtime・contract・本体の証拠 | 閉鎖 |
| V_Fun | 値置換。型・行像、署名、許容 | 閉鎖 |
| V_Prim | 値置換。型・行像と範囲・許容 | 閉鎖 |
| V_Op | 値置換。操作の型像と制約 | 閉鎖 |
| V_ExternalRef | 値置換。外部宣言と型像 | 閉鎖 |
| V_ExternalHandle | 値置換。ハンドルの宣言と型像 | 閉鎖 |
| V_PathBases | 値置換。保持した PathEnv | 閉鎖 |
| V_ScopePattern | 値置換。保持したパターン | 閉鎖 |
| V_Checked | 値置換。保持した対象 | 閉鎖 |
| V_CheckedRequest | 値置換。元の閉じた要求と対象の証拠 | 閉鎖 |
| V_CheckedAt | 値置換。元の Witness・snapshot・request | 閉鎖 |
| V_AtError | 値置換。元の error の形 | 閉鎖 |
| V_Map | key/value の Each の IH、長さ、閉じた sat | 閉鎖 |
| V_Set | Each の IH、閉じた sat | 閉鎖 |
| V_Dict | Vs の IH、対象・辞書型の型置換と値置換の交換、制約 | 閉鎖 |
| V_Raise | 値置換。型像と元の value kind を保持 | 閉鎖 |
| V_LocRef | 値置換。同じ場所と格納型 | 閉鎖 |
| V_LocLazy | 値置換。同じ場所と格納型 | 閉鎖 |
| V_Bytes | 値置換。元の全要素の上限 | 閉鎖 |
| V_Con | Vs の IH、宣言の引数への型置換と値置換の交換 | 閉鎖 |
| V_Super | 値の IH、元の類・上位類・対象の宣言照合 | 閉鎖 |
| V_List | Each の IH、移送した要素型の注釈 | 閉鎖 |
| V_Sub | IH、LeQ.bind と注釈 | 閉鎖 |
| V_Normal | IH と正規化の交換 | 閉鎖 |
| V_Refine | IH、観測の一致、述語の開閉と含意の移送 | 閉鎖 |
| Vs.nil | 空列 | 閉鎖 |
| Vs.cons | 値と残りの列の IH | 閉鎖 |
| Each.nil | 空列。要素型の新しい形成前提はない | 閉鎖 |
| Each.cons | 値と残りの Each の IH | 閉鎖 |

## 実行の view の16構文

`ClosureTy.view_typed` は、元の HasTypeCQ、CaptureOk、CaptureLocals と、a/e/R の閉じた結果の等号を保持する。閉じた型付けを直接返すのは readValues の通常値であり、それぞれの型は `∃ t` である。各構文の kind・型像・行像・errorType の注釈は返さない。残す本体のコードは元の導出と同じ捕捉・局所参照に結び付けて保持する。

`readValues_view` と `readValues_resolve` が実行との一致を結び、`view_read_typed`・`view_read_ground`・`view_adequate` を公開する。別の個別の入口として、app_view_typed・method_view_typed は実際に閉じた計算を同じ a/e で型付け、ret_view_typed は実際の戻り値を a で型付ける。条件値が boolean であることなど、他の構文ごとの入力型を取り出す補題はここにはない。

| 構文 | 実行が閉じる物 | `ClosureViewTy` が型付きで保持する物 |
|---|---|---|
| ret | v | v の `∃ t` の型付け、元の return の導出 |
| app | 関数と全引数 | 関数と各引数の `∃ t` の型付け、元の適用の導出 |
| builderLet | kind | 元の構築器の束縛の導出、残す本体のコードと局所参照 |
| builderOp | kind と引数 | 各引数の `∃ t` の型付け、元の構築器の操作の導出と局所参照 |
| letIn | なし | 前後の本体のコードの元の導出と同じ cap |
| ite | 条件値 | 条件値の `∃ t` の型付け、元の分岐の導出と残す本体のコード |
| match | 被検査値 | 被検査値の `∃ t` の型付け、元の照合・腕・guard の導出と cap |
| lazyC | なし | 遅延本体の元の導出と cap |
| escape | v | v の `∃ t` の型付け、元の escape の導出 |
| use | v | v の `∃ t` の型付け、元の use の導出と残す本体のコード |
| handle | なし | 本体・節の元の導出と捕捉 |
| resume | 継続 k と通常引数 v | v の `∃ t` の型付け、元の resume の導出と捕捉の継続の像。k は通常値の型付けに含めない |
| externalCall | 型像と引数 | 各引数の `∃ t` の型付け、元の外部呼出しの導出 |
| issuePathBases | なし | 元の issuePathBases の導出 |
| checkAt | 任意の bases、pattern、input、errorType | bases があればその値と、pattern・input の `∃ t` の型付け、元の checkAt の導出 |
| meth | 辞書、型・行像、全引数 | 辞書と各引数の `∃ t` の型付け、元のメソッド呼出しの導出 |

## 七つの遷移と依存β

| 規則 | ソース側の入力と行先の構成 | 状態の結果 |
|---|---|---|
| E_Let | e_let_post、元の残す本体のコード・捕捉、K_Let | 同じ σ/Eb |
| E_Return | ret_view_typed、K_Let の逆転、任意 v の apply_all | 同じ σ/Eb |
| E_Mark | 任意 v、normal_return_tail、実際の pure ret | 同じ σ/Eb |
| E_Fun | app_view_typed、fun_body_input、type_subst_fun_body、TelBodyTy.capture_all。QTel は Admissible.noFailRows と一致 | 同じ σ/Eb |
| E_Meth | method_view_typed、method_body_input、type_subst_method_body。型像 ss++us、捕捉 vs++ws。部分的な型置換と全置換の合成、辞書文脈を等号で合わせる | 同じ σ/Eb |
| E_Super | 元の上位辞書の型付け、S02、close_value_typed、superStep の再帰。Sub/Normal/Refine の場合も元の導出から扱う | 同じ σ/Eb |
| E_Lam | app_view_typed、inv_closure、TelClosure の引数の逆転、DependentClosureTy.apply_all、K_Sub と markPush | 同じ σ/Eb |

依存βは一引数の代表や pure な呼出し元に限らない。元の StateTyE を逆転し、実際の q.view の引数から型付けと Ground を取り出す。runtime と契約の名前・入力は RuntimeShape によって一致させ、通常 lambda の実行用の終端を結果契約と同一視しない。保存した結果型の部分型と効果の被覆から既存の widen_atoms と K_Sub を合成する。行先のコードは `body.apply vs` そのものであり、その型付けを仮定していない。

O136 の `dependent_result_close` を公開し、上位辞書の本体を閉じる箇所で使用する。値参照を含む一般の結果・効果・戻り先・依存列については、TypeValueExchange の四等式を公開した。群 F・G の葉には読者がなく、最初の読者は値依存の入口を扱う後続の単位である。

`Capture.close_pred_apply_all`・`close_facts_apply_all` は、入力を残した閉じ方と、実引数で捕捉を延長して一度で閉じる方法の一致を、長さの観測を含む任意の述語と Φ について示す。これらも公開済みだが、群 F・G の葉には読者がなく、最初の読者は値依存の入口を扱う後続の単位である。意味の健全性を独立に仮定しない。

L40・L70 へ渡すのは以上の元状態からの入口である。ここでは一般の全76遷移の保存・進行、旧主定理の切替、Rust との接続を結論しない。

## 宣言・公理・検査

手書きの追加宣言は115件である。定理112件、定義2件、判断1件の全名を declarations に記す。新モジュールは11件で、すべて既定の Benitoite import に追加した。既存の補題の公開入口を七件加え、HandlerPreservation の private な補題一件の名前を変えた。旧 Release の主定理と規則は変更していない。

ソース・写し・署名・検査入力の23ファイルの SHA-256 は [inputs.sha256](inputs.sha256) に置く。再開1の boundary.lean を含み、results 自身の検査結果の追記はこの入力の一覧に含めない。以下の表と出力のハッシュは初回実装時の検査である。再開1の最終検査は末尾に記す。

| 検査 | コマンド・内容 | 結果 |
|---|---|---|
| 既定ビルド | formal で `lake build`。追加11モジュールを含む既定の全対象 | 終了0、818 jobs、最後の増分実行2.978秒。既存対象の warning の再表示を含む |
| 公理依存 A-L | formal で `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/f/axioms.lean` | 終了0、2.075秒。16モジュールの全798宣言と明示した48項目、計846回の #print axioms |
| work の選択 | `scripts/check.sh --level work --base ee5fe230f6decb8bbc8798ee2df280c8fa481504 --dry-run` | 終了0。spec_tally・spec_examples・formal_build を選択 |
| work | `scripts/check.sh --level work --base ee5fe230f6decb8bbc8798ee2df280c8fa481504` | 一度実行して終了0、7.837秒。--only は指定していない |
| 仕様とテストの対応 | work に含む spec_tally の自己検査と集計 | 自己検査成功。テストの参照がない節の情報表示は残り、初回リリースの受け入れ条件の未記入は none |
| 仕様例 | work に含む `cargo test -q -p benitoite --test spec_examples` | 7 passed、0 failed、0 ignored、0 filtered out。テスト本体3.18秒 |
| Lean と sorry の拒否 | work に含む既定の formal_build | 成功。対象の除外はない |
| 記録の整合 | 全115宣言と署名、33 case、16構文、七つの遷移、相対リンク、絶対パスを照合 | 一致。signatures は37,106バイトで100 KB以下 |

公理依存は `propext`・`Classical.choice`・`Quot.sound` だけであり、sorryAx・独自公理・未承認の依存はない。検査は新11モジュールの生成宣言も列挙し、公開補題を追加した既存5モジュールも全件列挙する。旧三モデルの assumptions、旧 progress・preservation・step_sound・effect_soundness・effect_soundness_noLamNames、および CaptureOk・ClosureTy・StateTyE・ValueMeaning・CoreAssumptions 等の実際の使用定義も対象とする。既定 import は全追加分を含み、除外・削除していない。

RSS は未取得である。この記録は L20 の部分作業の W-L であり、段末の取りまとめの採取とは区別する。途中は関係する Lean ファイルを `lake env lean -M 12288` で検査し、import する成果物を更新するときは既定の `lake build` を使った。個別対象だけの lake build、sorry、既定 import の除外は使っていない。

生の出力はすべて `<tmp>` に置く。途中の45ログは同じ場所の intermediate-logs.tar.gz にまとめた。初期の失敗は、帰納仮説を文脈の等号の消去より先に取る修正、置換の等式の正規化と書換え位置の修正、option の場合分けを射影より先に行う修正などで解消した。信頼条件や型付け規則を追加する修正はしていない。

| 出力名（すべて `<tmp>`） | バイト数 | SHA-256 |
|---|---:|---|
| build-final-o136-2.log | 42,899 | `304748f01b01283cd356c373e6c412edaedf88d428eaaa1a2b96178e1094cdab` |
| axioms-final.log | 110,028 | `2fa5d3df514344bc9172833f26232577652c9c3a1872519c928ee2e09a174a99` |
| work-dry-run-final.log | 759 | `158144312f62ea483b162a34428c05965ab72c691b55fe3b6a136371749d03d7` |
| work-final.log | 5,718 | `8a9c100914403d255b365c5da66bb89ef9f887dc0b082b800286e57caa1edfc2` |
| intermediate-logs.tar.gz | 93,424 | `1a0964a81924ec499ccbd90f13e3aab6f686774d35852ac7f7e16840dbbd3836` |

## 計画との差と申し送り

S05 が指定した16構文ごとの case 定義の形に対し、実物の ClosureViewTy は構成子一つの判断とした。直接返す閉じた型付けは通常値のものと a/e/R の保持であり、app・meth・ret には個別の入口を置いた。各構文の型・行像の注釈の取り出しは L20.110〜.115 へ送る。元の導出と CaptureOk は残るため、close_app_aux・close_method_aux と同様に C_Sub・C_Normal・C_Eff を通す補題で取り出せる見込みであるが、他の構文の枝では未実行である。この見込みを証明済みの範囲には含めない。

状態の接続に必要な内部補題を、指定の主なモジュールに加え、CaptureApplicationAlgebra・CloseApplication・ClosureCallInputs・CallBodyScope・MethodTypeComposition・MethodClosure・SuperClosure に分けた。公開入口の量化と前提は signatures のとおりであり、新しい型付け規則や信頼条件を置く変更はない。S05・S06 を実装前に固定し、後続の内部入口は使用前に追記したが、整理用の `Val.resolveLocalsList_eq_map` と `Eff.norm_rawSubstV` の二補題は署名の記載が実装後になった。最終の signatures は全115宣言と照合している。

.83 の型置換の合成を進める間に .84 の葉の本体も先に検査し、.83 の完了後に同じ既定ビルドへ合成した。plan・detail・レビュー記録・処理系は変更していない。既存の ImplDecl.dictTys に行支持が欠ける疑いは定義を確認して解消した。dictTys は dictParams から生成した辞書型の列であり、任意の型列ではない。停止条件に当たる新しい行支持・kind の欠けは見つかっていない。

設計書 01-12・07-04 の写しに、任意の closeVal、全引数の適用、view、七つの状態の葉の現在の範囲を反映した。独立レビューと L20 全体の取りまとめの受け入れは、この担当の検査成功と区別する。

## 再開1: RV-L20.f の所見への対応

レビューの記録は変更せず、本体の言明・型付け規則・公理も変えていない。

| 所見 | 処置 |
|---|---|
| 中1 | view の表を実行が閉じる物と ClosureViewTy が型付きで保持する物に分け、.78 を実際の証明範囲へ限定した。case 定義の形との差、型・行像の取り出しの担当単位、未実行の見込みを「計画との差と申し送り」に記した |
| 軽1 | 四つの捕捉と型置換の等式、close_pred_apply_all・close_facts_apply_all を公開済み・当群の葉に読者なし・最初の読者は後続の値依存の入口、と記した。dependent_result_close の上位辞書での使用はそのまま記した |
| 軽2 | 07-04 の「環境を捨てる場合の反例と区別する」を戻した。必要部分を現行 C_If で検査した結果を O008 に記した |
| 軽3 | 全引数の適用、非依存の入力列と依存列、残す本体のコード、構築器の操作へ用語を揃えた。Lean の識別子は変更していない |
| 軽4 | 07-04 に ClosureCallInputs が元の契約・実引数・本体を取り出す役割を追記した |
| 軽5 | Benitoite.lean の import 間の空行を除き、ClosureApply.lean の160字を超える二行を折った。空白を除くと再開前と一致する |

再開1の検査は次のとおりである。すべて終了0であり、言明・規則・公理の変更はない。

| 検査 | 実行内容 | 結果 |
|---|---|---|
| boundary | formal で `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/f/boundary.lean` | 1.053秒。反例と現行 C_If の本体が通り、44宣言の公理依存も許可された三公理だけ |
| 既定ビルド | formal で `lake build` | 818 jobs、7.149秒。既存の warning の再表示を含む |
| 公理依存 | formal で `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/f/axioms.lean` | 2.048秒。16モジュール798宣言と明示した48項目、計846回。propext・Classical.choice・Quot.sound だけ |
| work の選択 | 指定の work と同じ基準へ `--dry-run` を追加 | 0.134秒。spec_tally・spec_examples・formal_build を選択 |
| work | `scripts/check.sh --level work --base ee5fe230f6decb8bbc8798ee2df280c8fa481504` | 再開1で一度実行し、3.728秒。--only は使っていない。spec_tally の自己検査・集計、仕様例7件（0 failed、0 ignored、0 filtered out）、既定 Lean ビルドと sorry の拒否が成功 |

RSS は未取得（部分作業では計画上の非採取）である。import と ClosureApply の再開前後を空白を除いて比較して一致を確認した。signatures の Lean コードブロックも再開前と一致する。保管元の boundary、plan・detail・reviews の計97ファイルは開始時の SHA-256 と一致する。view の16行で実行上の閉じ方と型付きの保持を区別し、後者に kind・型像・行像・errorType を含めていないことを照合した。入力の23ファイルのハッシュを更新し、署名は37,118バイトで100 KB以下を保つ。

生出力は `<tmp>` に置き、ここには大きさと SHA-256 だけを記す。

| 出力名（すべて `<tmp>`） | バイト数 | SHA-256 |
|---|---:|---|
| boundary-r1.log | 4,845 | `6f99f38b92dbb57bc362b807a6a3eb959631c407225da9bc58a5307e1e71af73` |
| build-r1.log | 43,119 | `f18947270c1b77f11b01cf2ffe75f39155b7ed1d06dec49922a45aadfdbeca80` |
| axioms-r1.log | 110,028 | `2fa5d3df514344bc9172833f26232577652c9c3a1872519c928ee2e09a174a99` |
| work-dry-run-r1.log | 759 | `b70794e9763b15e9d1d404d27fed68b6730f3b2719d076a78ab11ca7aeed8fcd` |
| work-r1.log | 5,718 | `c325a9cab18177125d63715167585e9f9e0f9ef885d4401936a7b1b511ae9409` |

## 作業末の work

取りまとめが所見の対応の後に実行した。

| 項目 | 値 |
|---|---|
| コマンド | `scripts/check.sh --level work --base ee5fe230f6decb8bbc8798ee2df280c8fa481504` |
| 終了状態 | 0 |
| 外側の時間 | 118.61 秒 |
| 最大常駐量 | 1,366,999,040 バイト |
