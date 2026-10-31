# L00b.03: 文脈の実装結果

2026-10-31。指定ブランチは `m014/l00b.03`、B_WORK は `5016f55febc6973855c37dc22fda24a6317e2b28` である。git の照合・切替・作成・コミット・その他の操作を行っていない。共通依頼文と起動依頼を受け、[完全署名](signatures.md)を先に置いてから実装した。L00b.04 は始めていない。

## 閉じた定義と補題

本番へ4モジュールを追加し、`formal/Benitoite.lean` の既定 import へその4モジュールを追加した。既存の定義・主な定理・信頼条件・型付け・遷移は変更していない。[変更一覧](source-changes.json)に変更前後の SHA-256 を記録した。

| 本番ファイル | 定義と閉じた補題 |
|---|---|
| [Context/WF.lean](../../../formal/Benitoite/Release/Refinement/Context/WF.lean) | `Ctx.outer`、lookup と長さ、None の参照の拒否、`Ctx.Ordered`、`refined_outer`、`no_dependency_cycle`、some/None による Ordered と WF の保存、`Ctx.Sorted`・`Ctx.Regular` と拡張の保存 |
| [Context/Facts.lean](../../../formal/Benitoite/Release/Refinement/Context/Facts.lean) | `Pred.Sorted.map`、`Pred.Valid`、`FactsWF`、`Ty.assume_valid`、`Ctx.Regular.facts`、Φ の移動、Γ/facts/Φ の含意の移動、捕捉を値・None で延長する構文の交換と facts の再構成 |
| [Context/Declarations.lean](../../../formal/Benitoite/Release/Refinement/Context/Declarations.lean) | 宣言順の `BinderTypes.Annotations` と WF/Sorted/extendMany、`FactsWF.extendMany`、`Tel.inputs/context` と各注釈の抽出・一引数の具体化、固定した宣言の `TypeArgsKindedAt`・`SignatureInstanceAt`、ユーザー/組込み操作の宣言の正則性と `ClauseSig.wf` |
| [Context/Capture.lean](../../../formal/Benitoite/Release/Refinement/Context/Capture.lean) | 注釈の shift と捕捉の延長の交換、`CaptureWF/CaptureSorted/CaptureDeclared` の移動、`CaptureOk.extend`・`extendNone`・`extendTel` |

[宣言数](declaration-counts.json)は公開定義18・公開定理69、非公開の補助定理8である。[完全な公開型](public-api.md)に87名の型を出力した。本番の新規4モジュールは901行、既定入口は空行と import の5行を追加した。生成された宣言・射影・帰納原理・非公開の証明を含む247宣言を公理依存の照合対象にした。

`Ctx.outer Γ i` は0〜iの項目を None にし、残りの番号と注釈を保つ。Ordered はその文脈で各注釈の References を検査する。篩の self と Tel の内部の束縛は既存の References が扱い、外側の参照だけが厳密に大きい番号を要求される。`refined_outer` が述語の自由変数へこの条件を返し、`no_dependency_cycle` はその参照関係の任意の非空の有限の連鎖の自己への復帰を排除する。長さの上限だけで循環を認める形にしていない。

facts と Φ は有限の構文のままである。値の型付き像から `assume_optional` を使って新しい事実の含意を導き、もとの facts と Φ の像を加える。未観測の関数の像を整数0として扱わない。型の像で事実が増える場合に列の等号を要求する変更も加えていない。既存の Transport/SubstOk の移動・置換は前群の全構文への一般化をそのまま利用する。

## 定義を使う入口の確認

[境界入力](boundary.lean)、[成功の出力](boundary.log)、[名前の一覧](boundary-inventory.json)を置いた。54個の名前付き定理と準備の定義・生成された宣言を含む110宣言を型検査し、公理依存も確かめた。54件を独立した54種類の遷移の保存とは数えない。

| 境界 | 正例・負例と実際の入口 |
|---|---|
| 宣言順と Tel の逐次具体化 | `tel_annotation` の最初の入力は捕捉した外側の値へ依存し、次の入力と結果は先行する入力へ依存する。`open_contract_annotation` は元の注釈と実引数の型付けから後続の注釈を作る。後続の Annotation を前提に取らない |
| 依存βの引数列・閉包・呼出し | `arguments_typed` が逐次具体化の実結果から TelArgs を構成する。`body_typed`・`beta_closure_typed`・`beta_call_typed` が本体・閉包・呼出しを型付け、`beta_step` が実際の `E_Lam` を示す。`beta_capture` がその遷移先の捕捉を構成する。先の状態や CaptureOk は仮定していない |
| 空でない facts/Φ | 最初に7という値の型付けから `equalSeven` の捕捉を作り、その facts から `pathFact` を Φ に足す。`extended_facts/extended_phi` と `beta_capture` が2入力の拡張の後にも再構成する |
| None の位置 | `none_capture`・`none_regular`・`none_phi` で、入力を二つ加えた後に None を挟む。`none_keeps_number` が隣の入力の番号と型注釈の移動を照合する。`none_not_readable`・`none_annotation_rejected` は None の読取りを拒む |
| 循環と後方参照 | `self_cycle_bounded` は長さの WF を満たす。一方で `self_cycle_rejected`・`backward_rejected`・`two_cycle_rejected` は Ordered が自己・後方・相互循環を拒む。初回の `future_input_rejected` は範囲外の番号を拒む例であり、順序の負例ではなかった。レビュー対応で `out_of_scope_input_rejected` に改名した |
| 整数以外の構文 | `function_snapshot_reference/ordered` は sort のない関数の snapshot も参照として扱う。`text_phi_after_none` は String の比較を None の下へ移す |
| 捕捉とソースの WF の相違 | `capture_wf_loose` と `source_wf_rejects_duplicate` は重複 Fail を持つ継続で両者を区別する。`loose_capture` が閉じた像の行を正規化して ImageOk を構成し、`loose_capture_extended` がそのまま some/None を延長する。Ctx.WF の成立を追加の前提にしていない |
| ユーザー操作・組込み操作 | `user_table_regular/user_clause_signature` は依存する2入力のユーザー操作を、`builtin_table_regular/target_clause_signature` は型パラメータ・範囲変数・依存入力を持つ組込み操作を照合する。後者の範囲の具体化は任意の S について番号の WF を保つ |
| 呼出し元の kind | `constructor_kind_fixed` と `value_kind_conflict` で同じ宣言の kind 列を使う。`fixed_signature.forget` を実際の `fixed_function_typed` の V_Fun へ渡す。組込みの制約 sat は既存の入力として明示し、kind の結論をそこへ仮定していない |

`test-audit` の作成時の関門を適用した。守る契約は、公開する文脈の判断と既存の型付け・E_Lam が実際に接続すること、None と宣言順を保つことである。現実的な退行は、全入力を一度に束縛する、None を詰める、継続のソース行へ Ctx.WF を要求する、kind の K を前提ごとに選び直す、又は捕捉の延長後の事実を前提としてしまう変更である。前群の境界入力は今回の新しい判断・補題の入口を検査していなかったため、本群にその接続を置いた。本番へ検査だけの差し込み口は増やしていない。Rust のテストは追加・変更していない。

## 場合の数の予定と実際

| 族 | 予定 | 実際と確認 |
|---|---|---|
| outer の定義 | 空列・先頭・残りの3枝 | 3枝。lookup はリストと番号の0/succを全て処理 |
| 文脈の拡張 | some と None、lookup の0/succ | Ordered・WF・Regular と facts/Φ の双方に接続 |
| Pred.Sorted.map | 署名の初稿は16 | 実際の Pred は14構成子であり、全14場合を閉じた。初稿の件数の誤記を署名末尾に記録 |
| Ty.assume_valid | 全 Ty と最外の篩 | 全21場合。refined は先頭と既存の事実の2枝 |
| 捕捉の移動 | CaptureWF/Sorted/Declared の全 Ty | 21×3＝63場合。ソースの継続の行を読まない既存の境界を保つ |
| CaptureOk | 既存の8欄、値/None/Tel の延長 | 全8欄を再構成。像は ordinary/contLoc/contVar の3枝で、閉じた宛先の contVar は lookup 不可能として排除 |
| 依存入力列・Tel | nil/cons、done/param | 各2場合。extendMany と liftMany、宣言順と捕捉の延長を一致させた |
| 型引数の kind | 固定した D の一つの判断 | forget/shift/subst と実際の V_Fun に接続 |
| 操作の署名 | ユーザー/組込み、範囲の位置 | user/prim の2枝。instTarget の補題は全21型を扱い、opaque/scoped の各 fixed/rvar を分けた |
| 既存の構成子 | 変更0 | ソース71、型付け三族各71、TypedFacts56、Step76を増減していない。ソース71とStep76等の機械の確認は [構成子一覧](case-inventory.txt)にある |

## 補助の契約で決めたこと

| 論点 | 採った案と理由 | 捨てた案 |
|---|---|---|
| 参照順序と既存 WF | 同じ長さの outer と Ordered を追加し、既存 Ctx.WF を保つ。一般の構文の References を再利用できる | 長さだけで順序も検査したとする案、Fin への切替 |
| Regular と CaptureWF | Regular はソースの WF・Sorted・Declared・Ordered。捕捉は従来の緩い三判断を移す | CaptureOk に Regular/Ctx.WF を追加する案 |
| self の読み方 | sort/参照は `some a :: Γ`、宣言照合は `Γ.extend a` を使う。両者に必要な像を別に作る | 宣言型の番号の移動を省く案 |
| facts の延長 | 型付き値の assume_optional と構文の交換から導く。CaptureOk の全欄まで再構成する | 結論の facts や CaptureOk を前提に取る案、全値の意味上の所属を外へ仮定する案 |
| Tel の具体化 | 元の param の Annotation と実引数から後続の Annotation を返す。宣言順の拡張を保つ | 全入力を同じ外側の文脈で検査する案、後続の注釈を未証明の前提として残す案 |
| 宣言した kind | D の kind 列に固定した SignatureInstanceAt を作り、forget から既存の入口へ渡す | 既存 TypeArgsKinded の存在する K を任意の D の列へ同定する案 |
| 操作の宣言の正則性 | Program/組込みの表から供給する局所の構文の判断を置く。TargetWF は対象の最上位の範囲変数を具体化する | CoreAssumptions へ新しい欄を足す案、最上位以外の未具体化の範囲変数まで無条件に認める案 |
| facts の整形式の表 B | Ctx.Regular.facts は任意の B を明示引数に受け、V_Var で既存 SubstOk.openValue へ接続する。B の性質は仮定しない | この補助のためだけに特別な組込み表を本番へ追加する案 |

主な定理の前提と結論、新公理、提供範囲、利用者の書ける形、精密な外部状態は変更していない。Program.WellTyped は現行 Refinement に未定義であり、本群で主な定理の前提として新設していない。今回の宣言の正則性を、全本体の導出と合わせて最終の Program.WellTyped へまとめるのは L20/L70 である。存在する K の長さの一致だけで宣言との一貫性を検査済みとはしていない。

## 検査・公理依存・入力の照合

[検査台本](validate.py)、[コマンド・終了・外側の時間](commands.json)、[集計](validation.json)、[最終入力](inputs-final.json)、[公理依存の集計](axioms-summary.json)を置いた。既定ビルドは既存 lakefile の moreLeanArgs から、個別検査は明示的に `-M 12288` を読む。

| 検査 | 結果・外側の時間 |
|---|---|
| `cd formal && lake build` | 終了0、687 jobs、sorryなし、0.913秒。局所ビルドの生成物を再利用した増分ビルド |
| 入口の正例・負例 | 終了0、名前付き定理54、生成宣言を含む110宣言、1.028秒。境界入力の警告0 |
| 完全な公開署名 | 終了0、87名、0.657秒 |
| 本番113モジュールと既存の7確認対象 | 終了0、12,435宣言、10.600秒。新規4モジュールの247宣言を含み、非公開・生成宣言も対象 |
| 旧主定理5宣言の追加照合 | 終了0。step_sound・progress・preservation・effect_soundness・effect_soundness_noLamNames。時間は commands の old-main-axioms 行に記録 |
| 公理依存の許可一覧 | 上記の計12,440宣言と境界入力は propext・Quot.sound・Classical.choice だけ。sorryAx・独自公理・許可外の依存0 |
| 前群の API の照合 | 閉包と共有層の両方が前群の生出力とバイト単位で一致。終了0、各0.712秒・0.639秒 |
| 入力・固定対象 | formal の441入力が検査の前後で一致。開始時の7,730固定対象の変更0。旧 import は保ち、既定入口への追加だけ |
| メモリ | Lean ごとの設定は12,288 MiB。RSS・CPU時間は未取得（計画上の非採取） |

既存の simp 等の警告とリンク時の `-L` の警告は再表示される。今回の新規本番4ファイルと最終の境界入力に警告はない。初期の snapshot は lean-toolchain を拡張子で拾わなかったため、前群の `02c-inputs-final.json` の同一ハッシュと照合し、その出どころを validation に記録した。版の出力は [lean-version.log](lean-version.log) にある。

公理依存の生出力1,263,524 byte、全対象名736,395 byte、開始時入力のハッシュ一覧1,116,947 byteは `<tmp>` に置き、[large-records.md](large-records.md)へ大きさと SHA-256 を記録した。改造内の各ファイルは100 KB以下である。保存する文書・台本へ手元の絶対パスは書いていない。

途中の局所検査では、Lean の相互帰納型に通常の induction を使えない点、暗黙引数の型・selfの異なる二つの文脈の推論、式の展開の範囲、公開名の重複等を直した。境界の初回は [boundary-first.log](boundary-first.log)、追加の初回は [boundary-extra-first.log](boundary-extra-first.log) に終了1の記録を残した。いずれも証明・準備の修正後に上の最終検査が終了0であり、契約や拒否の期待を緩めていない。検査台本の初回は lean-toolchain の snapshot の欠落でビルド前に止まり、上のハッシュの照合を追加してから実行した。旧主定理の明示的な A-L が本番モジュールの照合と別に必要と分かったので、ビルドを重ねず5宣言だけ追加した。

作業末の work、Rust の検査、Rust/Lean の全比較は実行していない。work は起動依頼どおり取りまとめが行う。自己点検を独立レビューや受け入れ済みとは扱わない。

## 義務の判定・残りと送り先

| 義務・出どころ | 本群の判定と証拠 | 残る担当・時期 |
|---|---|---|
| L00b.03 | Γ の None/lookup/外側参照、Φ/facts、宣言順/extend の定義と代表補題、実際の入口の正例・負例を実装した | 群末の独立レビューと受け入れは取りまとめ・設計者 |
| O029 | 本群の文脈の規約・拡張・facts の含意の部分は完了。既存 Transport の全構文への接続を再利用した | L20 が一般の型/行/範囲/値の相互置換と全状態へ組み込む |
| O039 | 意味上のΓや全値の所属を新たに仮定せず、型付きの値から facts と捕捉の延長を構成した | L20/L40 が全 canonical/ground と全状態へ接続する |
| O053 | outer/Ordered、宣言順の入力列、some/None/Tel による保存、循環・後方参照の負例を完了 | L20 がソースの文脈の形成で Regular の保存を閉じる（末尾のレビュー対応で更新） |
| RV-values 軽2・RV-handlers 軽1 | 固定した宣言の kind の入力を実際の V_Fun へ、ユーザー/組込みの宣言表の正則性を OpSig.WF と ClauseSig.wf へ接続した | L20/L70 が全本体の導出と最終の Program.WellTyped、D29 の埋め込みへまとめる。L50 は実表の条件の充足を照合する |
| 前群第31節 | CaptureWF と Ctx.WF を区別したまま延長できることを証明した | normConts・builderBody_image_norm・CaptureOk.normConts、緩い捕捉条件からの結果の正則性、範囲外変数の行の E_Handle→E_Op、型置換の型付けは L20 の既定の義務のまま |
| 閉じた篩の評価と外部境界 | 評価の規則・external_typed・E_External は変更していない | L00b.04/.05 が D19 の閉じた評価と全入れ子の受信後の篩検査を置く。L60 が三モデルを照合する |
| 全状態と主定理 | 代表の入口と E_Lam だけを確認した | .14a/.14b、L20/L40/L70 の全状態の保存・進行・主定理は既定の担当を保つ |

L00b.04 は `Pred.Valid`・`FactsWF` と文脈の拡張の補題を利用できる。閉じた値の facts の再構成は `CaptureOk.extend/extendNone/extendTel` から得られる。閉じた述語を true と認める規則の代わりにはならない。CaptureOk から Ctx.WF を無条件に取り出さず、ソースの継続の行の正規化は上の L20 の義務と区別する。数値・近似の読取りは Shared を直接使う。

## 計画からのずれと外側の時間

補助の契約の委任の範囲で、参照順序を別判断に分けたこと、facts の補題だけにせず CaptureOk の一般の延長まで閉じたこと、宣言した kind の入口を既存の存在量化した補助へ忘れる向きで接続したことを署名の決定の記録へ加えた。提供範囲と後続の作業順は変えていない。Pred の件数の誤記を16から14へ訂正した。

開始は **2026-10-31 16:14:55 JST**、本番の最終ビルドは **16:37:39.692 JST**、追加の照合と文書を含む終了・外側の時間は [delivery.json](delivery.json) に記録する。能動時間と待ちを分離しておらず、この時間を能動時間とは呼ばない。見込み1〜3時間の上端の2倍と6時間の停止条件には到達していない。

[レビュー依頼](../reviews/RV-L00b.03-request.md)に新規ファイルの全一覧を置いた。文書のリンク、入力の不変、新規ファイルの列挙、100 KB の上限の最終確認は [final-check.json](final-check.json) に記録する。


## レビューの所見の対応（RV-L00b.03、2026-10-31）

群末レビューは条件付き可（重なし、中2・軽6）であった。plan の先頭の取りまとめの判断に従って修正した。本節と [署名の末尾](signatures.md)が初回の状態を更新する。レビューの記録・rv-*・plan・処理系・設計書は変更していない。再レビューは置かないという取りまとめの判断を受け、作業末の work と受け入れは取りまとめへ残した。

| 所見 | 直した箇所・対応 | 判定・残り |
|---|---|---|
| 中1・案(b) | 参照順序をソースの注釈の判断とし、CaptureOk に欄を加えないと signatures に確定した。l00b.02/signatures の CaptureOk の「外側参照順」と Capture の説明を訂正した。レビューの regular_hide・regular_bindParams を本番の `Ctx.Regular.hideConts`・`Ctx.Regular.bindParams` へ移した | 今回の指定分を完了。O053 の残りは HasTypeCQ の文脈の形成で Regular が保たれること。shiftE・OpSig.context・failureContext・Narrows は L20 に列挙した |
| 中2 | レビューの二補題を `CaptureOk.extendHidden`・`extendCont` として本番へ移した。`opfail_target_capture` はエラー値の次に継続場所を加えた `cap.extendMany [seven, .loc 0]` と `failureContext initial scalar` の捕捉を作る。`opfail_step` はその実際の E_OpFail を示す。`opfail_hidden_location` は None の位置に場所の実値が残り、論理からは読めないことを照合する。`cont_location_capture` は重複Failのソース行から正準の継続場所の像を作り extendCont を使う | 完了。遷移が使わない `CaptureOk.extendNone` と専用補助3件は削除した。既存の Capture.extendNone の構文や Ctx.extendNone は変更していない。前の none_capture・loose_capture_extended も実値の残る形に改めた |
| 軽1 | `Ctx.without` と `Ctx.Depends` を定義した。Depends は注釈iについてjを隠すと References が成立しなくなる関係であり、大小を定義に含めない。`Ctx.Ordered.depends_lt` が Ordered から外向きの順序を導き、`no_dependency_cycle` を Ordered とその依存関係の非空の閉包を読む言明へ差し替えた。`self_cycle_dependency` と `ordered_dependency_points_outward` で実際の辺を確認した | 完了。全構文の References と self・Tel の内部束縛の規約を再利用し、最外の篩だけの依存の定義にしていない |
| 軽2 | 元の範囲外の例を `out_of_scope_input_rejected` に改名し、説明を訂正した。長さの WF を通る自己・後方・相互循環の負例は保ち、Depends の実際の辺と Ordered の接続の境界を追加した | 完了。番号の範囲外と参照順序の拒否を区別した |
| 軽3 | `Pred.Valid` を `Pred.WellFormed` へ、`Ty.assume_valid` を `Ty.assume_wellFormed` へ改名し、利用箇所と現行署名を追随した。旧名の別名は残さない。wf 欄は CaptureOk の三つ組へ渡すために保った | 完了。命題が真であるという意味を持たず、構文の WF・Sorted・Declared だけを表す |
| 軽4 | signatures の L20 の義務に、初回の依存βは hideConts Γ = Γ の場合であることを明記した。rv-03-hide の CaptureOk.hide・beta_target/full_target が示す、元の捕捉を hideConts Γ の本体へ移す・R を任意へ変える向きと、hideBuilders Ψ の捕捉を元の Ψ へ戻す向きを列挙した | 指定どおり L20 へ登録。一般の E_Lam の保存を今回完成したとは数えない |
| 軽5 | TypeArgsKindedAt の型の shift と置換、型の束縛を越える D の延長、通常節と Fail 節の D の与え方を signatures に一行で登録した | L20/L70。kind を持たない List TParam から K を選び直して済ませない |
| 軽6 | 今回の hideConts・bindParams の保存と、残る shiftE・OpSig.context・failureContext・Narrows の保存を分けて signatures に登録した。`hidden_cont_regular` は継続を実際に隠す正例、`nondependent_params_regular` は外側に依存する非依存入力列の正例である | 本番への二補題の移植は完了。残りは L20。Narrows.here の先に必要な Sorted/Declared/参照順序も供給する |

今回の本番の変更は既存の Context の4ファイルだけであり、新規の本番ファイルはない。宣言は公開定義20・公開定理70・非公開補助11となった。[修正版の宣言数](r2-declaration-counts.json)と[公開型](r2-public-api.log)に記録した。削除した公開名が環境に残らないことも A-L の入力で検査した。主な定理の前提と結論・新しい公理・提供範囲・利用者の書ける形・精密な外部状態は変更していない。

テストの作成時の関門は、None の位置の捕捉を実行の形と照合する契約と、Ordered が実際の依存関係を制約する契約について適用した。前の捕捉の正例は Capture.extendNone の形であり、E_OpFail が残す実値の差を検出できなかった。今回は実際の値と場所の順・E_OpFail の遷移・その先の捕捉を検査する。既存の範囲外の拒否の期待は保ち、順序の負例という説明だけを訂正した。境界入力は名前付き定理63となった。

### レビュー対応後のビルドと公理依存

[検査台本](r2-validate.py)、[コマンド・終了・外側の時間](r2-commands.json)、[検査の集計](r2-validation.json)、[公理依存の集計](r2-axioms-summary.json)、[構成子一覧](r2-case-inventory.txt)を置いた。初回の検査の入力と出力は当時の記録として保ち、今回の記録を r2 で分けた。

| 検査 | 結果 |
|---|---|
| 既定 `cd formal && lake build` | 終了0、687 jobs、sorryなし。外側0.801秒。局所ビルドを再利用した増分ビルド |
| 修正後の境界入力 | 終了0、名前付き定理63、生成宣言を含む件数は r2-axioms-summary に記録。外側1.071秒、警告0 |
| 修正後の公開署名 | 終了0、90名、外側0.675秒 |
| 変更した宣言・新しい宣言の公理依存 | Context 4モジュールの生成・非公開を含む266宣言を全件対象とした。既存を含む113モジュールとモデル・限定同値7件・旧主定理5件の計12,459宣言を照合。終了0、外側10.450秒 |
| 許可公理 | 本番と境界入力の依存は propext・Quot.sound・Classical.choice だけ。sorryAx・独自公理・許可外0件 |
| メモリ | 既定の lakefile と全個別プロセスで `-M 12288`。RSS・CPU時間は未取得（計画上の非採取） |
| 入力の照合 | formal の441入力が検査の前後で一致。plan・レビューの記録・rv-*・処理系・設計書等の固定対象の変更0 |

局所の初回では、移植先の補題名が関数名を隠す箇所、Lean の暗黙引数の推論、使える戦術の範囲を直した。境界の追加時の初回は残った証明の目標があり終了1だったが、式の展開と引数を明示して閉じた。拒否の期待や補題の前提を緩めていない。上の記録はその後の成功である。

100 KBを超える開始時のハッシュ一覧、公理依存の生出力と全対象名は `<tmp>` に保存し、[large-records.md](large-records.md)に大きさと SHA-256 を追記した。レビューの補助入力の原文は凍結したままであり、Pred.Valid を参照する当時のファイルを改名後のAPIに書き換えてはいない。移した本番と現在の境界入力は Pred.WellFormed を使う。

### レビュー対応の外側の時間

開始は **2026-10-31 16:57:48 JST** である。文書と固定対象の最終確認を含む終了・外側の時間は [r2-delivery.json](r2-delivery.json) に記録する。能動時間と待ちは分離していない。最終の入力・記録・リンクの照合は [r2-final-check.json](r2-final-check.json) に残す。git と work は行わず、L00b.04 は始めていない。

## 作業末の work

取りまとめが sandbox の外で実行した。基準は `5016f55febc6973855c37dc22fda24a6317e2b28`。Refinement の生成物を消してから `/usr/bin/time -l scripts/check.sh --level work --base 5016f55febc6973855c37dc22fda24a6317e2b28` を実行した。選ばれたのは `formal_build` だけで、終了0、外側の時間 57.92 秒、最大常駐量 1154760704 B である。
