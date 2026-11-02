# L20 群 E の実装結果

2026-11-02。指定ブランチは `m014/l20.e`、B_WORK は **`f5a9edabcab0e785ada937bd35bb793b2f4ddca8`**。担当から git のコマンド、ブランチの作成・切替・コミットを実行していない。基準は起動依頼の指定値であり、work の入口がこの基準から差分を分類した。

**L20.61〜.70 の担当範囲を閉じた。** `.66`・`.67` は A2 の証明を確認して控除し、ほかの既存の証明も再使用した。O003 の成果物は [closure-table.md](closure-table.md)、実装前の完全署名は [signatures.md](signatures.md) に置く。独立レビューと設計者の受け入れは取りまとめの担当であり、この記録は担当の検査結果である。

## 完了条件と控除

| 単位 | 完了した内容 | 既済み分の控除・根拠 |
|---|---|---|
| L20.61 | Q を移す11成分と固定する3成分の完全署名、NoFail と許容条件の単調性 | 型置換の Image=True と区別し、ImageOk も実際に Q を移す |
| L20.62 | 一つの構造的な相互証明で14成分76構成子を再構成 | 固定する3成分の Qempty は保持。全構成子の集合を D の相互判断の棚卸しと機械照合 |
| L20.63 | q_mono の11入口と q_fixed の3入口。C_CheckAt・通常節・失敗節・NoFail の枝へ適用 | QTel を Qempty へ落とす関数本体の経路には使わない |
| L20.64 | normContTy/normConts、像と捕捉の三条件の保存、CaptureOk.normConts | store_extend/shift_values k=0、SubstOk.hide、CaptureOk.hideConts_any は既存の証明を再使用。任意の改名は型付きの値置換で述べる |
| L20.65 | 正則性の6操作を照合し、shiftE/OpSig.context/failureContext と参照順序の保存、拒否の一般定理を証明 | hideConts/bindParams/extendNone の3操作は Context.Declarations/Context.WF の既済み分として控除。通常節の入力条件は閉鎖表に明示 |
| L20.66 | V29/Vs2/Each2 の開いた結果形成 | **単位全体を A2 から控除**。open_value/values/each_annotation を再使用。空 Each への無条件形成は主張しない |
| L20.67 | CQ24/Arms3/TelArgs2 の開いた結果形成 | **単位全体を A2 から控除**。open_comp/arms/telArgs_annotation を再使用 |
| L20.68 | normConts の捕捉を、値・計算の閉じた結果の Annotation へつなぐ2定理 | cap.substOk.annotation、全状態葉が要る効果の供給、handler/Fail/let の逆転・切り出し・包装は A2 の証明を再使用。全状態の保存の完了とはしない |
| L20.69 | local_zero と withReturn の各4入口 | ValueAssumptions を要求しない。withReturn は元の空ストア・戻り先 none の条件を保つ |
| L20.70 | 値・計算等10成分68構成子の subst_congr、型/行/依存列の合同、O003 の閉鎖表と全読者の照合 | D の NormEq と既存の LocalResolveLemmas の解決済みコードの基盤は再使用。Frame/Cell/Cont/State の localRefs の新 Capture への全接続は指定済みの .110〜.116 の担当 |

完全に控除した単位は `.66`・`.67` の2単位であり、残る8単位を今回の作業として扱う。元の配分の2単位の1時間〜2時間30分を差し引くと4時間15分〜7時間20分である。`.64`・`.65`・`.68` の部分的な再使用には、単位の中の比率の根拠がないため追加の分数を割り当てていない。D の NormEq の再使用も新規の証明件数へ足していない。この控除は今回の依頼の5時間15分〜9時間50分の内訳の照合であり、他群の見込みを変更する根拠にはしない。

## 定義・言明・仮定

明示した追加宣言は **95件（定義5・定理90、定理のうち非公開2）**。全95件の完全署名を Lean の環境から印字し、公開定理88件は署名一覧の型を持つことも独立の入力で検査した。署名一覧は20,905バイトで100 KB以下である。[inventory.json](inventory.json) は成分・構成子・宣言数、[inputs.json](inputs.json) はソース・設定・lock と道具の版・SHA-256を記す。

| モジュール | 定義 | 定理 | 内容 |
|---|---:|---:|---|
| ContextTransport | 0 | 19 | Q の移送11・固定3、NoFail/行対応/許容条件5 |
| CaptureTransport | 2 | 13 | 継続型の正規化、捕捉の三条件、像、捕捉と結果の形成 |
| ContextRegularity | 0 | 9 | 型移動による References/Ordered、正則性3操作、前方依存・循環の拒否 |
| LocalTyping | 0 | 13 | 局所の kind と文脈の補助5、local_zero4、withReturn4 |
| SubstAgreement | 3 | 20 | SubstAgree/LocalSubstAgree/ObservationAgree と束縛下への延長、型・行・依存列の合同 |
| SubstCongruence | 0 | 16 | 型列/行列/kind の合同4、非公開の包装2、型付きコードの合同10 |

normContTy は最上位が `.cont` である型だけを正規化する。CaptureOk.normConts は元の捕捉の三条件・捕捉の値の列・像・facts の真から、同じ cap・R・Φ で捕捉を再構成する。任意の NormEq の下で CaptureWF を移す言明は置いていない。D の反例と継続の位置の対応条件を維持した。

SubstAgree は継続を含む全 some の型の位置を読む。型注釈の合同は References から ObservationAgree を供給し、Pred.bind_congr を使う。snapshot の list/set/data の全 some slot と map の key/value の全 some slot も対象である。None の位置の自由な値まで一致を要求せず、元の型付けから合同を証明する。local_zero は L の位置の保存、localRefs は構築器の場所の有効性という別の命題として閉鎖表に記した。

主な10言明、ValueMeaning、Typing の規則と CaptureOk の定義、CoreAssumptions、旧 Release を変更していない。新しい行支持又は kind の欠け、新しい信頼条件、利用者の書ける形の制限は見つかっていない。処理系・plan.md・l20/detail.md・レビューの記録は変更していない。6モジュールを既定 import に含め、既存 import は保持し、01-12 と07-04の写しを現在の定義と証明に合わせた。

## 検査

コマンドの Lean の実行位置は formal/、work はリポジトリの根である。メモリは既定ビルドの lakefile.toml と単独 Lean の両方で `-M 12288`。RSS は未取得（計画上の非採取）であり、メモリ上限を実測値とは扱わない。

| 検査 | コマンド | 終了 | 外側の時間 |
|---|---|---:|---:|
| 選択の確認 | `scripts/check.sh --level work --base f5a9edabcab0e785ada937bd35bb793b2f4ddca8 --dry-run` | 0 | 0.113秒 |
| 作業末の work | `scripts/check.sh --level work --base f5a9edabcab0e785ada937bd35bb793b2f4ddca8` | 0 | 20.552秒 |
| A-L 公理依存 | `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/e/axioms.lean` | 0 | 1.710秒 |
| 完全署名95件 | `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/e/interfaces.lean` | 0 | 0.845秒 |
| 公開定理88件の型の照合 | `lake env lean -M 12288 <tmp>/contracts.lean` | 0 | 0.703秒 |
| 旧・新の読者の全件照合 | `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/e/readers.lean` | 0 | 5.473秒 |

work は --only/--test を付けず、一度だけ実行した。選択したのは仕様の集計と自己検査、仕様例7件、**既定の lake build と sorry 拒否**であり、すべて成功した。既定の8ターゲット（Benitoite/desugarDiff/builtinCheck/coverageDiff/coverageProgramDiff/surfaceCheck/surfaceCheckAll/intervalDiff）を保っている。増分ビルドであり、Lean だけの変更へ Rust の全 lib・clippy・fmt を追加していない。build 単独の時間は work から分離していない。

公理依存は、新規6モジュールと継承する4モジュールの全宣言（private/生成宣言を含む）、旧五主定理・三モデル・十移送を対象に **690件／690固有宣言**を印字した。245件は公理に依存せず、残りは propext・Classical.choice・Quot.sound の部分集合だけである。**sorryAx・独自公理・許可外の依存は0件**である。読者の監査は161対象、1509参照、1142固有読者で、opaque な証明本体も調べた。

局所検査の初回の失敗は、添字の文字列置換の誤り、束縛下の局所写像・型の推論、Option.map と構文の match の包装、相互帰納の関数型の子の下降の指定にあった。At の case の合同を非公開の包装へ分けた後、Lean のカーネルが全相互証明を受理した。監査スクリプトの初回には Nat/Name の型注釈が不足しており、修正後の印字と読者照合は成功した。読者の初版は opaque な証明本体を含まなかったので、allowOpaque を true にした全件を最終の記録とした。本番の証明の型と意味を変える修正ではない。初回の失敗と再確認は生の記録の束へ含めた。

## 計画からのずれと引き渡す範囲

捕捉の正規化を CaptureTransport、合同の前提と型の合同を SubstAgreement、コードの相互合同を SubstCongruence に分けた。既存の CaptureRegularity は A2 の証明をそのまま再使用した。内部の補題の名前と配置の変更であり、型付け規則・主定理の署名・独立の信頼条件を変更していない。

O003 は複数群の義務である。群 E の q_mono・subst_congr・local_zero/withReturn と閉鎖表は完了した。Frame/Cell/Cont/State の localRefs の新 Capture への全拡張は .110〜.116、適格な旧導出の全埋め込みは G10、表層読者の切替は L70 に残る。これらを未証明の定理として仮置きしたり、今回の完了条件へ含めて完了と記録したりしていない。O029 は None・facts・束縛下の移送、O053 は正則性の6操作と O167 の拒否の一般定理を引き渡す。O008/O038/O039 の結果と効果の形成は A2 と今回の接続の範囲であり、状態の全保存又は意味への全接続の完了とはしない。

署名を固定する準備以降、本記録を整理するまでの観測区間は約30.0分である。指定文書の読込みを含む全体の開始時刻は未採取であり、この値を完全な能動時間とは扱わない。能動時間と局所検査の待ちは分離できていない。work と監査の外側の時間は上表に別記した。指定された上限19時間40分へ達していない。他群の見込みをこの観測値の比で短縮していない。

| 残る手順 | 担当・内容 | 見込み |
|---|---|---|
| 群 E の独立レビュー | 取りまとめ。定義・言明・仮定、完全署名、閉鎖表と控除の確認 | 不明 |
| 所見への対応と必要な再検査 | 指摘された実装担当。所見の対象だけを修正・確認 | 所見が未提示のため不明 |
| 受け入れと取り込み | 設計者・取りまとめ | 待ち時間は不明 |

## 生の記録

生の出力と台本は `<tmp>` に置き、改造には要約・大きさ・SHA-256 だけを残す。入力の道具は Lean 4.34.1、Lake 5.0.0-src+5045d00、Cargo 1.98.1、Python 3.9.6 である。work 後の変更は監査用の入力と結果文書だけで、本番ソース・既定 import・設計書の写しは同じである。

| 記録 | バイト | SHA-256 |
|---|---:|---|
| `<tmp>/work-dry.log` | 759 | `3860e004e7cd80540aba0db748aa0bef1e114786b1950e845fde199f568aff60` |
| `<tmp>/work.log` | 5718 | `68ec3e99a2c61484681138e2c417fd2a9b317efc1d38c5282e725dd4a81e7671` |
| `<tmp>/axioms.log` | 82625 | `9249bb9ae8fe375d5f79276c96bff6d3a82df64180587e3ecec8299226bf018e` |
| `<tmp>/interfaces-final.log` | 63182 | `3b4867ddb52a66cf48904ced9c258c2de293da6dd0e4eac6510c480657194890` |
| `<tmp>/contracts.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `<tmp>/readers-complete.log` | 217587 | `1ac18ab40afe0f9606b7afd04dd27aca6201598a6da0f59b432544d3f12be775` |
| `<tmp>/contracts.lean` | 21768 | `30bec38dc74c4fa248848c2b1d711db88d79f4f3f55ffc975f6398412c867a5c` |
| `<tmp>/declarations.json` | 11572 | `265bb428b21947eb18bcfc4a3eb63ae1686fb65cb3d1dbce387afc35c69a8b49` |
| `<tmp>/readers.json` | 350 | `4c9f48e8e649a7d8993834104ca0fbbcc1910c6eada96efe505d6e167752f1aa` |
| `<tmp>/raw-records.tar.gz` | 81765 | `a5d3ff0550f397e4d2f0855de7ec2b1e62d0c15e8db8d2f92c157e7275ad8574` |


## r1: RV-L20.e の所見への対応

2026-11-02。中2件・軽7件の全9所見を処置した。基準と指定ブランチは初回と同じである。初回の件数・時間・inputs.json・inventory.json は初回の記録として残し、**現行の r1 の入力は [r1-inputs.json](r1-inputs.json)、宣言数は [r1-inventory.json](r1-inventory.json)** を正とする。独立レビューの再判定と設計者の受け入れは取りまとめへ引き渡す。

| 所見 | 処置と証拠 |
|---|---|
| 中1 | readers.lean の対象を Benitoite. と _private.Benitoite. へ広げ、StoreTy.WF.hide・preserves_hide・hide_extends を接尾辞へ追加。旧 Surface の withReturn を含め、選んだ対象の直接読者を再照合し、閉鎖表の hide の使用先と読者の表を更新した。O003 全体の移行完了の主張にはしていない |
| 中2 | ContextRegularity の ContextOrderExamples に付録の selfRef/okTy/bwdRef/fwd/back と fwd_dep/fwd_rejected/back_ordered を配置。自己参照を拒否する文脈と、外側への参照を受理する文脈の対照が既定 import で通る |
| 軽1 | hide の欄に SubstOk.hide と CaptureOk.store の ValueAssumptions・元の Ψ.WF、rename の欄に SubstitutionAssumptions・元の Ψ.WF を明記 |
| 軽2 | CaptureOk.hideBuilders_hideConts を追加。hideConts_any と store・preserves_hide により、同じ cap のまま hideBuilders Ψ・hideConts Γ・任意の R' への合成を証明。閉鎖表では閉じた実行データの行を分けた |
| 軽3 | normConts_cont と HasTypeVQ/CQ.normConts を追加。元の Γ の導出から継続の位置の対応を供給して移送し、capture_value/comp_annotation_via_normConts により同じ cap の閉じた結果の Annotation まで合成。結論は cap.closeTy a.norm である |
| 軽4 | 下記「計画との差」に SubstAgree/LocalSubstAgree の前提の範囲を追記 |
| 軽5 | SignatureScoped・OpDecl.Scoped・Tel.annotation_inputs・OpSig.WF・K_Handle の実際の欄を確認。hp/hc の供給範囲と未接続の範囲を閉鎖表の専用節へ明記し、O053 の L70/R10b のソース照合へ引き渡した |
| 軽6 | ContextTransport と LocalTyping の公開22入口の束縛名を Ψ/Q/C/Γ/Φ/R/m/a/e/L 等へ変更し、L の optParam 表記を LocalCtx へ変更。完全署名も同時に更新。構成子の枝の内部だけにある x の番号は局所名として維持した |
| 軽7 | 01-12・07-04 と群 E の記録を、捕捉（cap）又は捕捉の値の列という既存の語に統一。変更の経緯は設計書へ書いていない |

### 計画との差と供給範囲

S04 の「実際に参照する some の型の位置」に対し、SubstAgree は Γ の**全 some の型の位置**、LocalSubstAgree は L の**全 some の位置**で像の一致を要求する。計画の文より強い前提であり、旧 Irrelevant と同じ範囲を採ったずれである。None の位置の差は許す。今回この二定義を変更せず、結果と閉鎖表へ範囲を明示した。

OpSig.regular_context の hp は、宣言の依存列の Annotation から Tel.annotation_inputs で得る引数の Annotation を基礎にできる。ユーザー定義の操作では OpDecl.Scoped の SignatureScoped が元の Annotation を持つ。一方、opSigAt の params との対応、型文脈の前置き、Γ への移送、組み込みの範囲の具体化を合わせた本番の供給は未接続である。hc は sg.ret と t と**開いた e** の Annotation を要る。OpSig.WF は局所の WF だけ、K_Handle の done の Annotation は捕捉で閉じた結果であり、これらだけを hc の供給元と断定しない。条件付き定理は維持し、hp/hc の全供給はレビューの指定どおり O053 の L70/R10b の照合に残す。捕捉の保存に強い Ctx.Regular 又は独立の形成条件を追加していない。

今回の追加は定義5件・定理9件の14宣言で、群 E の合計は **109宣言（定義10・定理99、非公開定理2）** である。追加の定理は hide の合成1、継続の対応1、Γ の導出からの移送2、閉じた結果への合成2、具体の境界3である。公開97定理の署名を計画した型に照合し、全109宣言の完全署名の印字も成功した。主な10言明・型付け規則・ValueMeaning・旧 Release と既定 import の集合は変更していない。git のコマンドを実行していない。

### 境界の作成時の関門

中2の持ち主は Ctx.Ordered の参照順序の契約である。selfRef の外側の var 1 は同じ束縛を参照し、bwdRef の var 2 は外側の整数の束縛を参照する。順序の不等号を逆にする、自己参照を許す、外側への参照を拒否する退行を、この負例と正例の対で検出する。既存の一般定理は Depends を前提にしており、その前提を満たす具体の文脈の存在と受理の対照を検査していなかった。付録の入力を同じ境界へ置き、Rust の別の層へ重複するテストや新しい差し込み口は追加していない。これは既知の型付けの誤りを修正した退行テストではなく、計画が求める拒否と受理の具体の証拠の補充である。 本番の Lean 6ファイルの行数は初回から合計75行増えた。独立した Rust 又は Lean のテストファイルの増減は0であり、具体の境界は本番モジュール内に置いた。

### r1 の検査

Lean の実行位置は formal/、work はリポジトリの根である。メモリは既定 build と単独 Lean の両方で -M 12288。RSS は未取得（計画上の非採取）。

| 検査 | コマンド | 終了 | 外側の時間 |
|---|---|---:|---:|
| 選択の確認 | `scripts/check.sh --level work --base f5a9edabcab0e785ada937bd35bb793b2f4ddca8 --dry-run` | 0 | 0.112秒 |
| 作業末の work | `scripts/check.sh --level work --base f5a9edabcab0e785ada937bd35bb793b2f4ddca8` | 0 | 16.398秒 |
| 公理依存 | `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/e/axioms.lean` | 0 | 1.807秒 |
| 完全署名109件 | `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/e/interfaces.lean` | 0 | 0.954秒 |
| 対象を広げた読者照合 | `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/e/readers.lean` | 0 | 6.608秒 |
| 公開97定理の型の照合 | `lake env lean -M 12288 <tmp>/contracts.lean` | 0 | 0.716秒 |

r1 の work は --only/--test を付けず一度だけ実行した。仕様の集計と自己検査、仕様例7件、既定の8ターゲットの lake build と sorry 拒否がすべて成功した。4つの変更ファイルの局所検査も終了0である。公開定理の型の照合の初回だけ、具体の例の名前空間を入力へ開いていなかったため失敗した。照合用の入力を直した後、97件すべてが成功した。この後に本番の証明を変更していない。

公理依存は **709件／709固有宣言**。うち255件は公理に依存せず、残りは propext・Classical.choice・Quot.sound の部分集合だけである。**sorryAx・独自公理・許可外依存は0件**。読者の監査は **168対象・1600参照・1144固有読者**。StoreTy.WF.hide は67参照、preserves_hide は14参照、hide_extends は5参照を照合し、Surface.HasTypeCQ.withReturn の1参照も含めた。閉鎖表のモジュールの集合はこの出力から更新した。

完全署名のファイルは22,583バイトで100 KB以下である。署名の準備を記録した時点から本節の整理まで約7.1分で、最初の資料の読込みを含む全体の開始時刻と能動時間・待ちの分離は未採取である。

| 残る手順 | 担当・内容 | 見込み |
|---|---|---|
| 所見処置の再レビュー | 取りまとめ。9所見の処置と閉鎖表・供給範囲の確認 | 不明 |
| 受け入れと取り込み | 設計者・取りまとめ | 待ち時間は不明 |

### r1 の生の記録

生の出力と台本は `<tmp>` に置く。下表は r1 の記録であり、初回の同名の記録とは別の保存先である。入力と本番ソースの状態は r1-inputs.json を参照する。

| 記録 | バイト | SHA-256 |
|---|---:|---|
| `<tmp>/work-dry.log` | 759 | `1efd3d90e92877cc602f8b9a0e75e85da8659984d3e0f85bdd294080bd8e53f8` |
| `<tmp>/work.log` | 5718 | `e60f63dc8cb3825ccdd92bd1a001e9ace3c43a1e95b6843ddf844f12af9752ea` |
| `<tmp>/axioms.log` | 84552 | `6e505bc8e7b21bf92f1a7a53b5ed80db4e12c429fd5af9b1ca13647608399cc3` |
| `<tmp>/interfaces.log` | 70325 | `e59811efbaba6034af2f0396090369b4e395c386b1df27be0a4ff174b5cfa50f` |
| `<tmp>/readers.log` | 232583 | `eabe464d3e2d8f6c2dff67dfa5a130068c324cae87a6764a7c0bef4886146a8f` |
| `<tmp>/contracts-final.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `<tmp>/contracts.log` | 334 | `8fad639eb917c945b63d49308f99b3ece25a2f34e1f427381d14007e8460baf0` |
| `<tmp>/contracts-first.lean` | 23385 | `9cbe4f3875c69f843b5f70433106c13378dafb1cf0447fc6f85baf5694af6fbb` |
| `<tmp>/contracts.lean` | 23472 | `28adfd7823d5996f2f799f573b547aae339b0c2cc0719ae93d128c67973aa7ca` |
| `<tmp>/raw-records.tar.gz` | 46468 | `a1cac5363f15a20e39aeaa3b6171eb02d760e5b73f92f6aedf50e9b80eb30a56` |

## 作業末の work

`scripts/check.sh --level work --base f5a9edabcab0e785ada937bd35bb793b2f4ddca8` を、Refinement の生成物を消した状態で実行した。終了0、外側112.17秒、最大常駐量1385938944バイト。
