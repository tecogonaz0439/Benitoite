# L20 群 I の結果

2026-11-02。開始版 B_WORK と指定された対象 HEAD は `e485c90cf428d0dc9086594d489e58776ed6ed1d`、指定ブランチは `m014/l20.i1`。ブランチの切替・作成・コミットを含む git の操作は行っていない。基準からの本作業の未コミットの入力を検査する。完全署名は [signatures.md](signatures.md)、全宣言の公理依存と構成子数の検査は [axioms.lean](axioms.lean)、公開署名の印字入力は [signatures.lean](signatures.lean) に置く。

## 単位と完了条件

| 単位 | 判定と証拠 |
|---|---|
| L20.89 | 完了。TypedMeaning の基本値・定数・関数・保持値・場所の case。閉じた変数は空 Γ の lookup から排除する。lambda の CQ 本体に意味の帰納を降ろさない |
| L20.90 | 完了。構成子の全欄は typed_meaning_auxs、List の全要素は typed_each_norm を使う。Map・Set・Dict は既存 ValueShapeMeaning が内部を読まない上側近似であり、その定義どおりに構成する。RootShape を新しい仮定にしない |
| L20.91 | 完了。V_Refine は観測項の閉性・開いた述語と自己モデルの解釈の橋・Entails.sound、V_Sub は valueMeaning_sub、Normal は norm_iff を使う。V29/Vs2/Each2 の全33 case を一度の相互帰納で合成する |
| L20.92 | 完了。任意 closeVal の閉じた型付けから Capture.typed_meaning が意味と元の型への所属を作る。型を閉じる型保存は CloseTyping の入口が供給する。Capture.typed_coverage は meaning_coverage、CaptureOk.typed_variable_coverage は variable_coverage が返す閉じた型付けへ意味を供給する。捕捉を空に限定せず、進行を使わない |
| L20.93 | 完了。inhabits_of_typed と inhabits_of_typed_raw を、意味からの既存系と Inhabits.norm_all_iff で証明。Month・空篩・任意の正の長さの非空 List・unknown に typed_entries を通して、意味・正規形と元の型への所属・部分型による意味の移送を適用した |
| L20.94 | 完了。PatTy の変数・篩・変換を含む全9 case の相互証明。篩の基底へ残す述語から正規形の Annotation を作り、P_Convert の束縛型の二度の norm は冪等性で合わせる。空の Γ/Φ の下で元の有限導出と正規形の部分型を使用し、未証明の prefix の事実を前提に足さない |
| L20.95 | 完了。List の before/rest/after と data の欄、標準エラーの七欄から型付き束縛を得る。構成子の元の型引数から移送先の Ordinary を導く。Ground は同じ入力の Ground を前提に別に証明する。pattern_length_relation と head_rest_close_typed は同じ先頭・残りの list・観測・長さを結ぶ。二要素の成功と空 List の失敗へ適用した |
| L20.96 | 完了。firstAlt が選んだ代替について、同じ selectSlots を値列と正規形の型列へ適用する。照合成功の全入口に δ.map Ty.norm を供給する。代替の Ground も証明する |

閉じない case はない。全76遷移の分担では、この群は照合の入力となる値と束縛を供給する。E_MatchBody・E_MatchGuard・E_GuardT/F 等の実行状態の葉は群 J、全76葉は群 N1、主定理の全合成は L70 の担当に残る。S08 の正規形の束縛列から raw δ の型付けを無条件には結論しない。任意の同じ長さの別 List の標準関数の実契約は L40、Φ から正の長さを合成する規則は L30/L70 の担当であり、O143 全体の完了とはしない。

## 全33 case と帰納

| 判断 | 全場合 | 合成 |
|---|---|---|
| V29 | Var・Const・Lam・DependentLam・Closure・Fun・Prim・Op・ExternalRef・ExternalHandle・PathBases・ScopePattern・Checked・CheckedRequest・CheckedAt・AtError・List・Map・Set・Dict・Raise・LocRef・LocLazy・Bytes・Con・Super・Sub・Normal・Refine | TypedMeaning.typed_meaning_aux |
| Vs2 | nil・cons | 同じ相互帰納の typed_meaning_auxs |
| Each2 | nil・cons | 同じ相互帰納の typed_each_norm |

構造的な部分導出にだけ再帰する。構成子の欄の型の正規化は Ty.subst_norm_images、List の要素は ValueMeaning.norm_iff で合わせる。空 Each に型の形成を要求しない。Map・Set・Dict の内部について、その定義が要求しない意味の性質は主張しない。全33 case の証拠はこの相互証明であり、閉じた単純値の代表による代用ではない。

## Inhabits と捕捉の入口・適用

| 入口・例 | 実際の適用と結論 |
|---|---|
| typed_value_meaning_closed | 閉じた型付けと VarianceValid から空の外側モデルの ValueMeaning |
| inhabits_of_typed | 同じ導出から Inhabits P a.norm v |
| inhabits_of_typed_raw | 同じ導出から Inhabits P a v。二系のうち raw の系である |
| Capture.typed_meaning | 任意 cap/v の closeVal の閉じた型付けから意味を作り、Inhabits.of_subst_values で捕捉元の型へ反映 |
| Capture.typed_coverage | meaning_coverage に閉じた型の意味を渡す。任意の腕の入力もこの閉じた型付けを渡せる |
| CaptureOk.typed_variable_coverage | variable_coverage の含意へ typed_value_meaning_closed を適用。既存の SubstitutionAssumptions とストアの WF を受け、CoreAssumptions は受けない |
| Month | 整数5の V_Refine を有限の整数比較から構成し、型付けの3入口と month_exhaustive に適用。具体の Capture.empty.extend 5 に捕捉の意味と網羅性の2入口を適用し、空の捕捉から構成する Month の変数の網羅性にも適用 |
| 空篩 | 任意 a/v の型付けを仮定して型付けの3入口へ渡し、empty_refinement_exhaustive の空のパターン列から矛盾を導く。値の存在は主張しない |
| 非空 List | 任意 k>0 の観測不能な lambda の列を既存の V_Refine で型付けし、型付けの3入口と非空の照合へ適用。List 自体を保持する具体の捕捉にも Capture.typed_coverage を適用 |
| unknown | 未観測の鍵を持つ Map の大きさの項の自己等号を Entails.eq_refl で導く。整数5へ篩を付けて型付けの3入口へ適用し、同じ述語の三値評価が none であることも証明。unknown を評価成功に変更しない |

## 宣言・写しと変更の範囲

既定 import に追加した7モジュールは、TypedMeaning・TypedCoverage・TypedMeaningExamples・PatternBindingSupport・PatternBindings・PatternBindingsGround・PatternBindingExamples である。手で書いた宣言は80（公開79、非公開の ground_list_iff 1）。完全な一覧と全引数は signatures.md にある。

中心の公開宣言は、意味と所属の3入口、捕捉の3入口、pattern_bindings_typed・patterns_bindings_typed・alternatives_bindings_typed・HasTypeVsQ.select_slots、Ground の3入口、pattern_length_relation・pattern_length_close、head_rest_bindings_typed・head_rest_close_typed・head_rest_two・month_variable_coverage である。内部の補助は、閉じた観測項と述語の解釈の一致、`a.HasSort s` を持つ型と篩の形成、残す述語の正規形、構成子の型引数の Ordinary と欄の移送、有限列の各位置・連結・同じ型の列を扱う。例に使う値・型・述語・捕捉の定義以外に、判断の定義は追加しない。

01-12「篩を読む網羅性と値の意味」と07-04の対応・モジュール表を現在の証明に合わせた。主な10言明、型付けの規則、ValueMeaning、CoreAssumptions、旧 Release、Rust の処理系、plan.md・l20/detail.md・レビューの記録は変更していない。新公理、独立の信頼条件、利用者の書ける形の制限、行の支持・kind の追加条件はない。

## 計画との差と申し送り

- S08 の内部の公開補題は、WellFormed・WellTyped・CoreAssumptions・ストアの WF を受けず VarianceValid のみを受ける形に強めた。結論と全照合成功の量化範囲は変えない。取りまとめは既存の S08 の入力から hPB.variance を渡せる。
- PatternBindings の形成と Ground、適用例を分けて7モジュールへ配置した。すべて既定 import に含む。
- RootShape の追加仮定は使わない。照合成功から実際の値の構文を分け、既存の inv_list・inv_con・con_field_by_type と標準エラーの宣言を使用する。
- L20.94 の計画にある prefix の事実は、Γ/Φ が空の閉じた束縛保存には現れない。Refined と Convert は入力の型を移すだけであり、事実の供給は L20.97〜.99 が受け持つ。RootShape/rootShape_of_typing も本証明では使わず、照合成功の値の構文と既存の逆転を使う。
- L20.90 の計画の「Map/Set/Dict の子を使う」は採らない。ValueShapeMeaning のこれらの形は子の意味を要求しないためである。最外の篩の述語は全て読み、selfUnknown_entries と unknown_not_excluded で受理と網羅性の対照を示す。
- 再開1の処置に対する独立レビューと取り込み・受け入れは取りまとめ・設計者の担当であり、本作業の自己照合を独立レビュー済みとは記さない。Rust/Lean の全比較、段末の全状態の保存・進行の完成も主張しない。

## 初回の検査（再開前の入力）

以下は初回の実行の記録であり、再開1の検査の代用にはしない。現在の入力と結果は末尾に記す。

公理監査は追加7モジュールの自動生成を含む全211宣言と、関連・既存59宣言の計270件を印字した。依存は propext・Classical.choice・Quot.sound の範囲だけである。sorryAx・独自公理・unsafe/partial の新宣言はない。HasTypeVQ/Vs/Each の構成子数29/2/2、PatTy/PatTys の9/2を機械的に照合した。Lean は既定・単独とも -M 12288。最大常駐量は未取得（計画上の非採取）である。

作業末の work は指定基準の dry-run に成功した。仕様節の参照集計の自己検査と集計、仕様例、8 defaultTargets の既定の増分ビルドと sorry 拒否を選択した。--only は指定しない。最終実行の結果と生出力の大きさ・SHA-256、入力のハッシュは下に追記する。

## 作業末の実行結果

| 実行 | 終了 | 外側の時間と中身 |
|---|---:|---|
| `scripts/check.sh --level work --base e485c90cf428d0dc9086594d489e58776ed6ed1d --dry-run` | 0 | 1秒未満。仕様対応集計・仕様例・formal_build の選択を確認 |
| `scripts/check.sh --level work --base e485c90cf428d0dc9086594d489e58776ed6ed1d` | 0 | **7.855秒**。作業末として一度、--only なし。仕様対応集計の自己検査と集計、仕様例7件、既定8 defaultTargets の増分 lake build と sorry 拒否が成功 |
| `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/i/axioms.lean` | 0 | **1.298秒**。270件の依存、全33 case と PatTy/PatTys の件数、追加モジュールの新公理・unsafe/partial なしを確認 |
| `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/i/signatures.lean` | 0 | **0.692秒**。59宣言の完全署名を既定 import から印字。非公開の補助1件と合わせ60宣言を記録 |

仕様例は7 passed・0 failed・0 ignored・0 filtered out、テスト本体3.17秒。仕様対応の自己検査も成功し、初回リリースの受け入れ条件の未記入は none である。未参照の仕様節の情報表示はある。formal_build は既定のターゲットを削らず、sorry の拒否を含めて成功した。clean build や Rust/Lean の全比較は実施していない。Rust の全 lib は変更の対象外であり、自動選択されなかった。

途中は関係するファイルへ `lake env lean -M 12288`、import される成果物の更新へ既定の `lake build` を用いた。名前で対象を絞った lake build は使っていない。初回の失敗は、付録からの抽出範囲と作業ディレクトリの指定、暗黙引数の型の明示、Option の bind の簡約、置換と正規化の等式、相互帰納で等号を消す前の帰納仮説の取得、型族の添字を変数に一般化した構造再帰の指定で修正した。制限や期待値を緩める修正、型付けの規則の変更はない。途中の失敗を含む生出力は下の一つの archive にまとめた。

完了条件の最後の自己照合では、8単位・33 case・PatTy9/PatTys2・二つの所属・捕捉の入口の言明・型付けの3入口を使う4種の適用例・同じ先頭と残りの list の関係・既定 import・公理依存・写しの対応・署名の大きさを照合した。初回の署名は39,523バイトで100 KB以下。全8単位の担当作業を完了した。独立レビュー・受け入れは未実施である。

## 生出力と入力の記録

生出力は `<tmp>` に置く。記録への絶対パスの転記はしない。次表は削除前の出力の大きさとSHA-256であり、再実行の代わりの引用にはしない。

| 出力名（すべて `<tmp>`） | バイト数 | SHA-256 |
|---|---:|---|
| benitoite-i-work-dry.log | 759 | `3660832d362f3fe7fbc332fe74aa3d5a7fb2391f2e45f5c1b595aeb8c1eacd9a` |
| benitoite-i-work-final.log | 5,718 | `88c3e0a09be80a5c3982e6756637f49fc748d32c5a729137e172f246779fae41` |
| benitoite-i-axioms-final.log | 34,667 | `5dfcd9079427513d5265a3d128acda61a9a51b61addcca1677813705a5ac486d` |
| benitoite-i-signatures-final.log | 38,231 | `b57b6ad0949af074c5ec028461b85a9706674ec57e026f44b0d00b32a2f0886c` |
| benitoite-i-intermediate.tar.gz | 72,060 | `dbc9e6fa9eb2a621207f56425a1844e0bc7eaa4e2e3dd07074a308d2b811b4c0` |

途中の archive は37ファイルを含む。署名の初稿もこの中に置く。

時間の記録は、最初の局所検査ログを作った13:33:17 JSTから最後の記録の照合13:52:38 JSTまで、外側1160.3秒である。この前の依頼文・指定範囲の読取は採取していない。能動時間と待ちは厳密に分離していないので、能動時間の実績とはしない。指定見込みはI1＋I2の4時間15分〜10時間10分、上限は20時間20分。4時間を超える作業にはなっていない。

本作業の入力の大きさとSHA-256を固定する。results.md 自身は自己参照を避けて含めない。対象の設定は変更せず、Lean は固定された `leanprover/lean4:v4.34.1`、lakefile の8 defaultTargetsと -M 12288 を使った。基準から既定 import に追加した七つをすべて対象とする。この初回の検査直後に変更したのは結果の記録だけである。その後の再開1による入力の変更は末尾の一覧を正とする。

| 入力 | バイト数 | SHA-256 |
|---|---:|---|
| `formal/Benitoite.lean` | 16,392 | `0e27a697f932a057d302043d0e678f3dd9b04af4dbc783c268395dedfe634bc3` |
| `docs/design/01-spec/01-12-core-calculus.md` | 738,426 | `0b180e9231fe975bbd28cb31c448701419aa701a99e1bfc0477affedf78903ef` |
| `docs/design/07-quality/07-04-formal-semantics.md` | 478,271 | `4855008578cb1899e55ec2c3da549b8caadca170cab1d58d4f54d2c1f745a6ae` |
| `formal/Benitoite/Release/Refinement/TypedMeaningExamples.lean` | 4,693 | `0066f7eb4e43e6e3324d0a2407711a563352132fef19b81ef8c8396be31d481a` |
| `formal/Benitoite/Release/Refinement/TypedMeaning.lean` | 9,813 | `b5c4b753ec6597ac21ce8745a6010682d612e9802e60ed7d73e28ff2b69c6d98` |
| `formal/Benitoite/Release/Refinement/TypedCoverage.lean` | 1,644 | `377157f1894172b9b7310ffa79216c364595e8b3769e4ebb43c5643a2b2244b4` |
| `formal/Benitoite/Release/Refinement/PatternBindingSupport.lean` | 11,002 | `9fa21fd4f4b2902bba15c6019473593797b4c070cf72226e9ef27f2fe3324e7f` |
| `formal/Benitoite/Release/Refinement/PatternBindings.lean` | 10,470 | `137f13e5cb6988fe99dd35f73da9a1b53be898e73b5eb5159521452381fd423b` |
| `formal/Benitoite/Release/Refinement/PatternBindingsGround.lean` | 4,401 | `4974ba9603dac26ccba32bcbce6866c3f12b164860beec1ffd25c5cab5867ebe` |
| `formal/Benitoite/Release/Refinement/PatternBindingExamples.lean` | 3,163 | `ba34c124b3eaf185b2299e73c1544be2f93f99a1d364129421d12a060c17efba` |
| `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/i/signatures.md` | 39,523 | `88a3091cc686cd9f74593acc0dfcb47f15591f7a8879bfdc10697aa784bcc529` |
| `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/i/signatures.lean` | 3,905 | `ea78f3e6d7f42d513caba6ed43410af237301ca67e790cee9ade1052ecb93bf6` |
| `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/i/axioms.lean` | 5,181 | `4359cfec21d5e1d466c4399fc8f0b7e084be1531fb325a5a9ddc87d634ebdad9` |

## 再開1：RV-L20.i の処置

2026-11-02。条件付き可（重0・中2・軽5）の所見を実物と照合して処置した。主な言明・型付けの規則・公理は変更していない。レビューの補助入力は読み取りだけに用い、必要な例のソースを本番のモジュールに配置した。レビューの記録・plan・detail・処理系・旧 Release への変更と、git の操作は行っていない。

| 所見 | 処置 |
|---|---|
| 中1 | cap_month は具体の Capture.empty.extend 5 に Capture.typed_meaning と Capture.typed_coverage を適用。month_variable_coverage は空の捕捉から CaptureOk.extend で整数5を加え、変数の型付けも構成する。dependent_capture_entries は値依存の型 integer{self = x} を捕捉で閉じた型付けも例の中で構成し、Capture.typed_meaning へ渡す。nonempty_capture_coverage は List 自体を保持する具体の捕捉に網羅性の入口を適用 |
| 中2 | reject_top は整数13の Month の型付け、reject_list は13を要素に持つ List[Month] の型付けを否定。selfUnknown_entries は self の Map の大きさの自己等号に型付けの3入口を適用し、selfUnknown_eval は三値評価が none であることを示す。unknown_not_excluded は同じ値を使い、空のパターン列が網羅的でないことを証明 |
| 軽1 | 宣言名を実物の TypedMeaning.typed_meaning_auxs に修正 |
| 軽2 | 「計画との差と申し送り」に、閉じた言明に prefix の事実が現れないことと L20.97〜.99 の担当、RootShape/rootShape_of_typing を使わない証明、Map・Set・Dict の子の意味を要求しない定義との対応を追記 |
| 軽3 | 01-12・07-04 で、閉じた型付けから意味への段、SubstitutionAssumptions とストアの型の WF による変数の閉じた型付けの供給、CoreAssumptions 等を読む close_value_typed による任意の値の閉じた型付けの供給を区別 |
| 軽4 | 意味の移送・未観測の鍵・a.HasSort s を持つ型・CaptureOk・残りの list に用語を統一。Lean の識別子の用語を理由とする改名はしていない |
| 軽5 | 読者のない bridge_bind_o を削除。signature の印字と公理の監査にも反映 |

「型付けの3入口」は typed_value_meaning_closed・inhabits_of_typed・inhabits_of_typed_raw を指す。Month・空篩・非空 List・unknown の4種にはこの3入口と valueMeaning_sub を適用した。捕捉の入口の適用は、Month の2入口・具体の変数の網羅性、値依存の型の意味、非空 List の網羅性である。空篩は値が存在しないことを示すため具体の捕捉の成功例を置かず、unknown は自己述語の所属と網羅性で除かないことの対照に用い、捕捉との組合せを適用済みとは記さない。

self を読む Map の例は、V_Map が要求する鍵の B.sat [] unobservableFunctionType.norm TParam.keyC を入力に持つ。この既存の型付けの条件を新しい信頼条件へ変えていない。unknown を評価成功に変更せず、動的な検査も追加していない。

### 担当の義務の判定

| 義務 | 群 I で閉じた範囲と証拠 | 残る単位・段 |
|---|---|---|
| O039 | .89〜.93 完了。全33 case から意味と所属を構成し、具体の捕捉と値依存の型にも適用。主定理に値の意味を独立に仮定しない | .66〜.68・.74〜.77 の入力の供給は各担当の証明を使用。L40 の canonical forms と L70 の合成 |
| O046 | .92 完了。任意の閉じた型付けから意味と網羅性へ接続し、具体の CaptureOk の変数でも実行 | .97〜.99・.115 の if/Not/guard/match の事実と実行状態の葉。L30 の有限規則、L40 の算術・length・δ の結果 |
| O138 | .92 完了。具体の捕捉の閉じ方と selfUnknown_entries・unknown_not_excluded により、unknown の値を空の網羅性で除けないことを示した | .97〜.99・.115 の真偽・構成子・非空の事実の供給。L30 の証明書、L40 の標準の事実、L70/R10b の静的な合成、R50/V10 |
| O143 | .95 の担当範囲は完了。pattern_length_relation・head_rest_close_typed と二要素の成功・空 List の失敗 | 任意の同じ長さの別 List の標準関数の契約は L40、Φ から正の長さを合成する規則は L30/L70。O143 全体は未完 |
| O167 | .89〜.91 の担当範囲は完了。5の Month の受理と13の拒否、List[Month] の子の13の拒否、self を読む unknown の受理と空の網羅性による除外の拒否を対照 | 非観測・None・循環・不変の制限は他担当の .08/.20〜.24/.30 と .65/.66〜.68、guard の unknown・偽の事実の拒否は .99。この表で他担当の全証拠を再判定しない。L30/L40/L70 と各 R 段・V10、構文の拒否は L70/R60 |

追加は例の21宣言、削除は bridge_bind_o の1宣言、差し引き20宣言増である。既定 import の7モジュール内に手で書いた80宣言（公開79・非公開1）があり、追加分もすべて既定ビルドに含む。month_variable_coverage の例の入力から CaptureOk と変数の型付けの仮定を外した。完全署名と全宣言の公理依存を再検査し、01-12・07-04 を証明した範囲に合わせた。

### 再開1の検査

公理の監査は追加7モジュールの全237宣言と、関連・既存および新しい例を名指しした67件の計304件。全て propext・Classical.choice・Quot.sound の範囲内であり、sorryAx・独自公理・新しい unsafe/partial の宣言はない。HasTypeVQ/Vs/Each の29/2/2、PatTy/PatTys の9/2も再照合した。単独 Lean と既定ビルドはともに -M 12288。最大常駐量は未取得（計画上の非採取）。署名は45,771バイトで100 KB以下である。

最終の work 検査の結果と入力のハッシュを以下に記録する。初回の入力の一覧は再開前の証拠であり、現在の入力との一致は本節の一覧を正とする。

| 実行 | 終了 | 外側の時間と結果 |
|---|---:|---|
| `scripts/check.sh --level work --base e485c90cf428d0dc9086594d489e58776ed6ed1d --dry-run` | 0 | 1秒未満。仕様対応集計・仕様例・formal_build を選択 |
| `scripts/check.sh --level work --base e485c90cf428d0dc9086594d489e58776ed6ed1d` | 0 | **3.785秒**。再開1の作業末として一度、--only なしで実行。仕様対応集計の自己検査、仕様例7件、既定の8 defaultTargets と sorry 拒否が成功 |
| `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/i/axioms.lean` | 0 | **1.234秒**。304件の公理依存と構成子数を確認 |
| `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/i/signatures.lean` | 0 | **0.690秒**。79宣言の完全署名を印字 |

仕様例は7 passed・0 failed・0 ignored・0 filtered out、テスト本体3.14秒。仕様対応の自己検査も成功し、初回リリースの受け入れ条件の未記入は none。既定ビルドは全825 jobs の増分であり、ターゲットの絞り込み・既定 import の除外はない。Rust/Lean の全比較と clean build は実施していない。

局所検査の最初の2回のビルドの失敗は、非空 List の閉じた型付けを捕捉の入口へ渡す際、型の値置換が返す正規形と元の型の差、および暗黙の B/Ψ の推論を明示して修正した。Ty.subst_values_of_wf_zero と V_Normal を使い、言明・型付けの規則・公理は変えていない。3回目以後の既定ビルドは成功し、5回目では追加部分の未使用の simp 引数の警告も除いた。

work 後に、写しの日本語の字間と「各入口」を「型付けから意味と所属への三つの入口」とする明確化を行った。Lean のソースは変えていない。仕様の見出しと fenced block を連結した SHA-256 がこの編集の前後で一致することを確認したので、仕様対応集計と仕様例の入力も変わらない。これ以外の検査後の変更は結果の追記だけである。

### 再開1の生出力と入力

生出力は `<tmp>` に置き、記録に絶対パスを残さない。途中の出力と署名の初稿・再開前の results を一つの archive にまとめた。

| 出力名（全て `<tmp>`） | バイト数 | SHA-256 |
|---|---:|---|
| benitoite-i-r1-dry.log | 759 | `183a17a561724f347e6630119f0dab9ee15aaf112741363810aca124153321b5` |
| benitoite-i-r1-work.log | 5,718 | `1a42dbbf6fab00b5682fe511ef37b67ca289dec4e035a351707141abbcd8d44d` |
| benitoite-i-r1-axioms.log | 38,505 | `d7b770f1ed78b789077bec40419d3562ad73164547d5f916607da3d3ff7551a8` |
| benitoite-i-r1-signatures.log | 44,210 | `03a8066e5f5dda445f3c0bc37c2c5d4ed91262e601701dbefd32dfd001cae3d3` |
| benitoite-i-r1-doc-readers.json | 234 | `d7519cdd204eb879e889a907e61b8b5d0cbf362b1e9f72ce186fe14e9c2abb50` |
| benitoite-i-r1-intermediate.tar.gz | 32,116 | `941ed252c11a2b6eb1bd2b5492ab205ca0840c378e717a1bf83afa30f2c30f5d` |

再開1の記録は、追加する署名の下書きの作成14:05:01 JSTから最後の照合14:12:36 JSTまで外側454.6秒。この前の読取時間は未採取。能動時間と待ちは分離していない。

現在の入力を次に固定する。results.md 自身を除く。型付けの規則・主な言明・設定・交換器・manifest は変更していない。入力の範囲と道具の版・構成は初回と同じである。

| 入力 | バイト数 | SHA-256 |
|---|---:|---|
| `formal/Benitoite.lean` | 16,392 | `0e27a697f932a057d302043d0e678f3dd9b04af4dbc783c268395dedfe634bc3` |
| `formal/Benitoite/Release/Refinement/TypedMeaning.lean` | 9,546 | `da56c70d3ac0d2c2ba3b57fd8a8913a339b7190efcffa9ce5a5eccec4455bca8` |
| `formal/Benitoite/Release/Refinement/TypedCoverage.lean` | 1,639 | `775c40598f4899114754f2e7db1641022fb768ef7577b9668f80b2853fb6ccb6` |
| `formal/Benitoite/Release/Refinement/TypedMeaningExamples.lean` | 11,042 | `d82e841d784fa89ddc343c33730a65404e548ab24e0c5421f6b7fcce8bd37ead` |
| `formal/Benitoite/Release/Refinement/PatternBindingSupport.lean` | 11,002 | `9fa21fd4f4b2902bba15c6019473593797b4c070cf72226e9ef27f2fe3324e7f` |
| `formal/Benitoite/Release/Refinement/PatternBindings.lean` | 10,470 | `137f13e5cb6988fe99dd35f73da9a1b53be898e73b5eb5159521452381fd423b` |
| `formal/Benitoite/Release/Refinement/PatternBindingsGround.lean` | 4,401 | `4974ba9603dac26ccba32bcbce6866c3f12b164860beec1ffd25c5cab5867ebe` |
| `formal/Benitoite/Release/Refinement/PatternBindingExamples.lean` | 3,475 | `adb92e731920aab0479922ef9cd82f4277010b8ecb7b9492b49419d71e2c91b5` |
| `docs/design/01-spec/01-12-core-calculus.md` | 739,495 | `727f042bf7c631881ebcd39dd9dc8642630390c6a73dae8eb08ef830cd43e0b2` |
| `docs/design/07-quality/07-04-formal-semantics.md` | 479,392 | `a3ec3c8bee7592dd4056b5804a92189fb0e881157d127f246dc139158422fdd4` |
| `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/i/signatures.md` | 45,771 | `ffcd4629746ab5a29aa7011ec1b6b115e9ccd59d98142e96e23333cf2ce4427f` |
| `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/i/signatures.lean` | 5,347 | `350a2bb0c78eaaeb63a2c06f700a1e1d96b0522217cc43611da5cf7c3eb014e9` |
| `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/i/axioms.lean` | 5,908 | `57baf0f2672bc912461a7e67f88b4f1ef63d69f8d7e7657a3d92e187714acdf3` |

全7所見の処置、追加した例、5義務の担当範囲、完全署名、既定 import、公理依存、写しの前提と用語を照合した。再開1の担当の修正と検査は完了。処置の独立レビューと取り込み・受け入れは取りまとめ・設計者の担当である。

## 作業末の work

取りまとめが所見の対応の後に実行した。

| 項目 | 値 |
|---|---|
| コマンド | `scripts/check.sh --level work --base e485c90cf428d0dc9086594d489e58776ed6ed1d` |
| 終了状態 | 0 |
| 外側の時間 | 119.61 秒 |
| 最大常駐量 | 1,378,877,440 バイト |
