# P1: 事前点検の指摘の反映

## 範囲と基準

2026-10-18、ブランチmod009/design、開始版は`2a1a2938552ef3f9dc4880da0e16bca46adce36f`である。処理系の基準`6b0568a3ddcc46b0a0e64504139ce286a27fd86a`から開始版までの差がD内の文書だけであること、開始時の作業ツリーに変更がないことを確認した。design.md・plan.md・decisions.md・implementation-request.md・README.mdを直し、本書を追加した。preflight.md、処理系・現行設計書・テスト・formal/・docs/todo/は書き換えず、コミットもしない。

AGENTS.md、00-01、07-03の四水準/結果の保存、07-04の対応とLean先行、docs/todoのTODO-250を読んだ。試作のfindingsと248のLocalBuilder/Escape/Lowering/Regions、164のDictionaries、142のScope、022の区間の定義を読み、正式モデルへ接続済みとは扱わなかった。前回のREADME/decisions/plan/results/reviewsとstudyの構成、全比較の固定件数の更新漏れを参考にした。使用スキルはjapanese-tech-writing・rtk・test-auditである。

## 指摘ごとの対応

点検の22指摘をすべて採った。点検の「約半分」はS3と加算し直すと約6〜7割だったため、その表現だけを精密にし、見積もりを縮めた根拠が不足する指摘は採った。以下の場所はD内の節または作業IDである。コードのパスはリポジトリの根からの相対表記であり、いずれも読み取りで確認した。

| 指摘 | 確認した根拠 | 修正した場所・担当 |
|---|---|---|
| 重1 | formal/Benitoite/Surface/Desugar.leanの.local、Lemmas/Typing.leanのHasTypeQ.desugar、Release/Lemmas/Rename.leanのRenOk/rename、Surface/Typing.leanのE_Local | design 7.2/7.3・14.5/14.7、R108/R116、planのLean範囲とL3〜L6、依頼文。ΓのnoneとΔのsome kindで同じ位置を使い、fillBuildersと既存renameでコア環境へ移す |
| 中1 | Surface/Typing.leanの七判断と公開abbrev | design 14.5、R113/R117、L4/L6。既存名へΔを直接足し、旧新の複製と同値の橋渡しを取り下げた |
| 中2 | Exchange/Version.leanのexchangeJson/current・rejectFields・sidecarVersion、desugar_export/lib.rs/named.rs/check_named.py | design 14.6、R118、L7がVersionと旧版自己検査、B3がRustの版12の出力と版照合。corpus8〜12と他形式2〜4を分離した |
| 中3 | typeck/traits/collect.rs/tests.rs、Trait.bnt、Release/Typing.leanのTy.WF/SatAll、Surface/CheckToolsExamples.lean | design 6.2・14.4、R119、L2/M1の最初の区切りを最小正例へ。規則変更なら段1への戻しを相談する |
| 中4 | resolve/mod.rsのBinding/Ctor/Field、lookup.rsのchecked_name/record_call_name、shadow.rs、skill/generate.rs | design 2.2、R120、K1。使用位置と所有元で判定し、型参照を残す。shadowとgen_skillを触るファイルへ加えた |
| 中5 | typeck/consts.rsのトップレベル予算・warnings・eval・std_call/standard_argument、generate.rsの本体検査、l40-regex.bnt | design 5.1/5.2、R101/R121、K2。Declsの追加検査専用予算、順序、constOrigins、同定の共通化を指定。l40の不正Regexを動的引数の関数へ移す担当もK2 |
| 中6 | prelude/mod.rsのSTDLIB、modules/find/load、resolveの局所束縛、Surface/Typing.leanのlastBind | design 7.1・14.5、R123、B1/B2。docだけの標準ソース＋専用表、import/注釈/修飾操作/gen_skillの経路、最後のbindのUnit/Stateを指定 |
| 中7 | tools/derive/test_derive.pyの同梱例を写してcheckとpreview一致を求める検査 | R114/R124、G1が旧記録のmigration_requiredへ変更、G4が移行後のcheck成功/差分空へ復元。test-auditと過渡期間を両resultsに残す |
| 中8 | desugar_exportの二manifestとcheck_named.py/check_failure.py、前回resultsの全比較1/2回目 | R130、plan「全比較の固定記録の件数を直す担当」。K3/K4/M1/G3/G4/H3が増減を申し送り、V1後にClaudeが項目別に説明・再集計して全比較前に更新 |
| 軽1 | Surface/Typing.leanのlambda/lazy/節/with/arms/通常bind、Taskのコールバック | design 7.2・14.5、R123、L4。lambda/lazy/節だけ空Δ、他の部分式は同じΔと通常束縛数のnoneを渡す |
| 軽2 | 試作Scope.leanとdesignの任意のWordを許すHost/Pathの定義案 | design 14.2、R125、L1。妥当性述語をparser対応の前提にし、ホストの非空と根パスの空列を区別 |
| 軽3 | Accessのowner比較の定義案、名前解決のmoduleと別名解決 | design 14.2、R125、L1/依頼文。二補題は定義の意味を説明する役割とし、所属・保存・失敗を主な作業にした |
| 軽4 | consts.rsの未知入力の扱い、design 3の実行時失敗順と5.2の部分既知の案 | design 5.2、R125、K2/K3。静的拒否⇒未知引数の全具体化でも実行時Errorを明記。先行する未知入力による失敗の種類の違いは許す |
| 軽5 | Cargo.lockのregex1.13.1、regex.rsのcompile_error、Errorの一次資料（リンクはR122） | design 5.2、R122、K2。Syntax/CompiledTooBig以外はUnknownとして実行時へ残す |
| 軽6 | typeck内にbuiltins参照がない現状とregex.rsのヒープ値への接続 | design 3.1・5.2、R122、K2/K3。純粋なchecked_regex/checked_scopeだけの依存を許し、runtime/ヒープから独立させる |
| 軽7 | builtins/table.rsの固定タグと既存Result/Pair、Scopeの宣言案 | design 3.1、R122、K3。Rustは正規化文字列/失敗番号/reason、Scope.bntがopaque record/ScopeErrorを作る |
| 軽8 | diag/codes.rsのE02xxの用途、doc抽出の形式不良の範囲 | design 8.1、R126、H1。doc実行用入力の構文解析の形式不良だからこの帯とする |
| 軽9 | traits/solve.rsのClauseBoundsとbase/mod.rsのNodeMap API | design 12.1、R127、T1。ClauseBoundsを移し、base::NodeMapを保つ。get_mutが現行APIだとする誤りも直した |
| 軽10 | decls.rsのScope.params/effects、Body::newと本体ごとのScope | design 12.1、R127、T1。Scopeも疎な私有表へ替え、宣言/本体の両読者を担当 |
| 軽11 | infer.rsのITy/IEffect/Reason、solve.rsのEffectConstraint | design 12.3、R127、T3。私有の構造キーへ全欄を写してEq/Hashを持たせる。公開型の導出は保つ |
| 軽12 | Property.bntのreduce/tryCandidates、言語の末尾呼び出しとループ不在 | design 11.2、R128、G3/G4。駆動/合成を末尾呼び出しにし、上限付近のスタックの回帰をproperty_libraryへ割り当て |
| 軽13 | parser/types.rsのTypeExpr::Paren、formatter/roles/walk.rs、examples/derive_inventory.rs | R129、M1のfmt_commandで括弧の保持と再検査、G1の入口ファイルを明記 |

## 見込みと確認を要する点

実装プランはC1/C2を含む28作業、残り26、レビュー5回を保つ。P1は準備として別に記録する。L3〜L6はLayoutを使う作業から整列・fill・Δの直接追加へ改め、L4は3〜6から4〜8、L7は2〜4から3〜6、G4は4〜8から6〜10時間へ直した。段別の旧→新はLean20〜40→22〜44、T6〜11→10〜17、K9〜16→12〜20、M/B10〜18→13〜22、G12〜22→18〜30、H6〜13→9〜17、V2〜4→2〜4時間である。残りの能動作業は65〜124→86〜154時間、検査待ち・レビュー・測定を直列に足した枠は約79〜158→100〜188時間とした。いずれも未実測である。

R109はJSON Linesの未知行を無視できる規定がなく、成功の解釈の追加には形式の版を上げる現行規約を確認し、testCheckReportとtestResultsの双方を[1,2]とする推す案へ補った。R112はS3とコードから見積もりを改訂した。両方に「設計者に確認」を残した。公開の主定理の前提・結論、公理、Builtins.Assumptionsの追加を必要とする事実は今回見つかっていないが、証明は未実施であり、必要と分かれば止めて設計者に確認する。

## 文書の照合と検査

検査はplan「各作業のwork」のP1行を使う。処理系/Leanのビルドやテストは実行せず、文書の対応・リンク・集計・変更範囲を読み取りで照合し、文書だけのworkを末尾に一度行う。結果は次のとおりである。執筆全体の時間は計時しておらず、実装の見積もりへ混ぜない。

| コマンド・照合 | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| `scripts/check.sh --level work --base 2a1a2938552ef3f9dc4880da0e16bca46adce36f --dry-run` | 0 | 0.066578秒 | 変更6文書だけ、実行する検査なし |
| `scripts/check.sh --level work --base 2a1a2938552ef3f9dc4880da0e16bca46adce36f` | 0 | 0.062873秒 | 同じ選択で作業末に一度実行、selected checks passed |
| 読み取り用のPythonによる文書照合 | 0 | 未計時 | ローカルリンク190件（見出しも含む）、28作業とwork行、残り26作業の段別/全体の時間、R101〜R130の連番、回答済み68問の不変、22指摘、確認待ちの印を照合 |
| `git diff --check`と変更範囲の照合 | 0 | 未計時 | 差分の空白の誤りなし。書き込みは指定の5文書と本結果だけ、preflight.mdはHEADの内容と一致 |

文書照合の初回は終了1だった。読み取り用の正規表現がコード内の`function[A](...)`等をMarkdownのリンクと誤認したためで、コードブロックとインラインコードを除いて照合し直し、文書のリンクの変更なしに終了0を得た。構文やテストの失敗ではない。

work後の追記は本節の実行結果だけである。文書だけのworkの成功を、Leanの証明・Rustの実装・交換の旧版互換・性能の成功へ転用しない。R109/R112の回答、RV1、設計者の実装開始指示は未了であり、実装・エージェントの起動・本測定は行っていない。
