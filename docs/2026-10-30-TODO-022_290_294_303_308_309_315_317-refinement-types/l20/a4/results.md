# L20 A4 r2 の結果

2026-11-02。RV-L20.a4 の中1・軽1〜5を処置した。**関門 (d) の通過を維持する。** valueMeaning_sub の署名と三枝の証明、ValueMeaning、主な10言明は変更していない。B_WORK と対象 HEAD は `d243526e8adc08eaec15abdebd724022b52937b3`、ブランチは `m014/l20.a4` のままである。

| 所見 | 処置 |
|---|---|
| 中1 | detail.md の S07・S07a、A4 と群Hの単位、G09、O005・A を本番の MeaningLe の経路へ合わせた。variance_meaning は、variance_field_mono の Ordinary を S07 の入力から供給できないために認める欄単調性の例外と明記。P.VarianceValid の定義と不変な位置の等号の証明は再使用する |
| 中1：依存と見込み | .85〜.88は済み（群A4）、追加0分。.55〜.60への依存を外した。.89は.27、.90は.89、.91は.90に依存し、.27直後へ前倒しできる。.92のS05への依存は維持。群Hの重複2時間45分〜6時間15分を差し引き、G09は5時間〜13時間25分、合計は95時間〜213時間30分。番号148単位・32群は維持し、独立に見積もるのは144単位・31群 |
| 中1：後続の署名 | S07のtyped_value_meaning_closedと所属の二つの系から不要な B.CoreAssumptions を外した。本番化は後続であり、この群では実装していない |
| 軽1 | MLe・MTelLe・MTelClosure・MTypeArgs・field_inputsを削除。axioms.leanの印字と、署名・判定・結果・07-04の説明を追随。TelLe/TelClosureへ帰納しないことを明記 |
| 軽2 | 01-12・07-04とこの群の記録の列挙に依存関数を明示 |
| 軽3 | valueMeaning_refineを任意の部分型に対する意味の移送のrefineの枝として記述。「V_Subの代表」だけがあるように読める記述を修正 |
| 軽4 | 00-04の変性・多相・ValueMeaningの語を確認し、新しい用語は追加せず、宣言の欄の型、任意の部分型に対する意味の移送という表現へ統一 |
| 軽5 | 最大常駐量は取りまとめがこの群の作業末の検査で採取・追記する、と記録を修正。担当側では未採取であり、その値は取りまとめの実行待ち。レビューの単独検査の参考値を作業末の値に代用しない |

群の表32行と単位の表148行を別々に加算し、双方が95時間〜213時間30分、群Hの4行が0分で一致することを確認した。接続の分類も67単位・45時間45分〜110時間20分へ直した。G09だけから重複を一度控除し、A4自体の見込みや他の作業の範囲を削っていない。計画と本番の差は [gate.md](gate.md)、実際に使うmotiveは [signatures.md](signatures.md) にも反映した。

## r2 の検査

| 実行 | 終了 | 外側の時間と結果 |
|---|---:|---|
| `scripts/check.sh --level work --base d243526e8adc08eaec15abdebd724022b52937b3 --dry-run` | 0 | 1秒未満。spec_tally・spec_examples・formal_buildの選択を確認 |
| `scripts/check.sh --level work --base d243526e8adc08eaec15abdebd724022b52937b3` | 0 | **5.038秒**。r2の作業末として一度、--onlyなしで実行。仕様対応の集計と自己検査、仕様例7件、8 defaultTargetsの既定の増分lake build、sorryの拒否が成功 |
| `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/a4/axioms.lean` | 0 | **0.912秒**。削除後の全宣言と関連・既存の言明、valueMeaning_subの型の照合、Ordinaryを満たさない例への適用を確認 |

公理依存は169宣言。モジュールの全宣言147件（MeaningOrder 98・MeaningTransport 27・MeaningTransportObstruction 22）と関連・既存21件、例への適用1件である。削除した5宣言の読者はなく、残る証明の公理依存はpropext・Classical.choice・Quot.soundだけ。sorryAx・新公理はない。Leanは既定ビルド・単独とも-M 12288。clean buildやRust/Leanの全比較の結果にはしていない。

レビューの記録とplan.md、処理系は変更していない。detail.mdだけは今回の指示で変更を認められた範囲として編集した。最大常駐量の採取と修正の再確認・受け入れは取りまとめ・設計者に残る。今回の修正と担当の検査は完了した。r2の最初の時計読取07:40:07 JSTから記録の照合07:46:33 JSTまでの外側は6分26秒。能動時間と待ちは厳密に分離していない。

生出力は `<tmp>/benitoite-a4-r2-<名前>.log` に置き、下に大きさとハッシュを残す。検査したr2の入力のハッシュも末尾に保存する。以下のr1の実行は履歴として残し、r2の検査の代用には引用しない。

## r1 の実装と実行の記録

2026-11-02。**関門 (d) は通過。案Aで data・trans・refine の三枝と任意の部分型に対する意味の移送を証明した。** 初回の Ordinary 供給経路の不成立を、S07 の不成立とは扱わない。取りまとめが Ordinary の供給を撤回して代案で再開した指示に従った。案Bは実施していない。判定の根拠は [gate.md](gate.md)、完全署名は [signatures.md](signatures.md) にある。

開始版 B_WORK と対象 HEAD はともに `d243526e8adc08eaec15abdebd724022b52937b3`、ブランチは `m014/l20.a4`。切替・作成・コミットは行っていない。基準からの未コミットの変更を検査した。基準と変更した各入力のハッシュを本記録に固定し、検査の引用による代用はしていない。

## 義務行、三枝、供給の結論

| 対象 | 判定と本番の証拠 |
|---|---|
| L20.25 | 完了。Outer を任意の MeaningLe に強め、MOrder・Below を定義。内側は MeaningLe と MeaningArgs の相互帰納、後者の motive は True。使わない元の四成分はr2で削除。Prop の導出から Nat へのサイズ関数はない |
| L20.26 / data | 完了。field_order が欄の構造と VarianceOK から新しい MeaningLe を作り、fields_meaning が各子値の sizeOf の厳密な減少による外側 IH を適用する。data_shape_meaning・order_data で再構成する。元の引数列の導出の IH と混同しない |
| L20.27 / trans | 完了。order_trans が同じ値に対する左右の内側 IH を合成する。中間型の Annotation を足していない |
| L20.27 / refine | 完了。order_refine が元の意味を基底と p の真に分け、基底の内側 IH と既存 valueMeaning_refine を使う。selfModel 上の facts と Entails.sound は同補題へ供給する |
| refined・入れ子の data の下降 | 最初の60分以内に確認。構造側の variance_meaning/variance_meaning_args と、意味側の data_shape_meaning/fields_meaning が局所検査に成功した。再開07:17:00 JST、下降の検査の成功の確認07:21:16 JST |
| Ordinary | 型像の Ordinary を要求しない案Aが成功。既存入力から供給できない事実は反例として保持。再帰的な Ordinary も追加しない |
| Sorted | 構成子の宣言の欄の Sorted [] は VarianceValid が保持するが、証明では取り出さない。構造による欄の比較と意味の移送には Sorted 又は WF の新しい入力を要求しない。構成子の意味が保持する欄の WF は再構成で保つ |
| 元の S07 | valueMeaning_sub を元の署名のまま証明。axioms.lean で完全な型の注記を付けて機械的に照合。型付けの呼出し元へ新しい入力を要求しない |

O005・A と O039 の G09 のうち、欄の意味の単調性と全部分型の意味移送を閉じた。型付けの全33場合から意味を作る typed_value_meaning_closed、inhabits_of_typed/raw、捕捉と腕への全接続は後続の担当へ残る。これらを主定理の独立前提にしていない。全ての網羅性の健全性や Rust/Lean の全比較の完了は主張しない。後続の担当・時期と群H以降の起動は取りまとめが指定する。

## 追加・変更した宣言と写し

`MeaningOrder.lean` に次を追加した。

- 補助の比較：MeaningLe・MeaningArgs、of_le・of_args、MeaningLe.norm・MeaningArgs.norm。
- 極性と環境：PolarRel・PolarArgs・MeaningEnvRel、MeaningEnvRel.eq/param、PolarRel.of_norm_eq、PolarArgs.cons。
- 構成子の宣言の欄の構造：variance_meaning・variance_meaning_args、MeaningArgs.length/get/env、field_order。

`MeaningTransport.lean` に MOrder・Below を追加し、Outer の量化を強めた。fields_meaning・data_shape_meaning・each_meaning・list_shape_meaning・dependentFn_meaning・assumptions_meaning、三枝の order_data/trans/refine、order_step・outer_complete・meaning_order_sound・valueMeaning_field_mono、および名前空間直下の valueMeaning_sub を追加した。r2で使わない MLe・MTelLe・MTelClosure・MTypeArgs・field_inputs を削除した。

MeaningLe は値の意味だけの補助関係であり、型付けの部分型規則として使わない。関数・依存関数・lazy・map の内部を読まない構成子は ValueShapeMeaning の上側近似に一致する。これを意味の仮定として主定理に足さず、全導出に対する健全性を outer_complete で証明した。

MeaningOrder を既定 import に加え、MeaningTransport と MeaningTransportObstruction を引き続き既定に含めた。反例のモジュールは変更せず保持した。axioms.lean の a4_nonordinary_transport は、その反例の元の意味に完成した S07 を適用して先の意味を得る。追加の Ordinary はない。

01-12 と07-04の写しを現在の定義と証明した範囲へ合わせた。ValueMeaning・LeQ・Exhaustive・型付け・主な10言明・旧 Release・処理系・plan.md・レビューの記録は変更していない。l20/detail.md はr2の指示に従って変更した。意味の判断の定義を変える停止条件には該当しない。

## 検査と公理依存

作業末はリポジトリの根、局所 Lean と公理依存は formal/ で実行した。Lean の固定版は `leanprover/lean4:v4.34.1`、Rust の固定版は `1.98.1`。lakefile の moreLeanArgs と単独 Lean はともに `-M 12288`。

| 実行 | 終了 | 外側の時間と中身 |
|---|---:|---|
| `lake env lean -M 12288 -o .lake/build/lib/lean/Benitoite/Release/Refinement/MeaningOrder.olean Benitoite/Release/Refinement/MeaningOrder.lean` | 0 | 最終の局所確認は約0.45秒。構成子の宣言の欄の構造による比較と正規化を確認 |
| `lake env lean -M 12288 Benitoite/Release/Refinement/MeaningTransport.lean` | 0 | 最終の局所確認は約0.27秒。任意の部分型に対する意味の移送と直接の欄の意味の単調性の系を確認 |
| `scripts/check.sh --level work --base d243526e8adc08eaec15abdebd724022b52937b3 --dry-run` | 0 | 1秒未満。spec_tally・spec_examples・formal_build の選択を確認 |
| `scripts/check.sh --level work --base d243526e8adc08eaec15abdebd724022b52937b3` | 0 | **5.547秒**。r1 の作業末として一度実行。`--only` なし。仕様対応集計の自己検査と集計、仕様例7件、既定の全 Lean ビルドと sorry の拒否が成功 |
| `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/a4/axioms.lean` | 0 | **0.925秒**。完全署名と S07 の型を照合。174宣言の公理依存を確認 |

既定の lake build は8 defaultTargets 全体を対象とする増分ビルドであり、名前で対象を絞っていない。clean build ではない。Rust の全 lib は選択されなかった。spec_tally は未参照の仕様節を表示したが、未記入の初回リリース完了条件は none、終了0である。最大常駐量は担当側では未採取。取りまとめがこの群の作業末の検査に計測を付け、機械・OS・原単位・本体と計測器の終了を区別して本記録へ追記する。現時点はその実行待ちである。

公理依存の内訳は、新モジュールの全宣言152件（MeaningOrder 98・MeaningTransport 32・MeaningTransportObstruction 22。自動生成の宣言を含む）、関連定義・主な10言明・旧主定理21件、旧反例への S07 の適用1件の計174件。依存は許可済みの propext・Classical.choice・Quot.sound の範囲だけであり、sorryAx・新公理はない。対象一覧と印字する完全署名は [axioms.lean](axioms.lean) に保存した。

局所検査では初回失敗も記録した。MeaningOrder の最初の2回は補助名・型の推論、負極性の不変な引数の等号の向きを修正し、3回目以後成功した。MeaningTransport の最初の2回は Const.type のための依存した反転と、相互帰納型の直接の induction を、型の等式を保持する反転と専用の再帰補助へ直した。3・4回目は成功。三枝を名前付きに整理した5回目で、motive に導出の引数が現れないための推論不能を検出し、導出を明示した6回目と欄の意味の系を加えた7回目が成功した。制限・期待値・既定 import は緩めていない。

## 完了条件の自己照合、計画との差、時間

| 条件 | 照合結果 |
|---|---|
| 60分以内の完全署名と refined/data の下降の確認 | 完了。署名を本番と signatures.md に保存し、局所 Lean の型検査と最後の完全署名の印字を実施 |
| data/trans/refine の本番の三枝 | 完了。外側と内側の下降を区別し、任意の部分型に対する意味の移送まで閉じた |
| 元の S07 の署名 | 変更なし。完全な型の注記を付けた #check と、Ordinary の供給の反例への適用が成功 |
| ValueMeaning、主な10言明、主定理の仮定 | 変更なし。新しい信頼条件を足していない |
| sorry・新公理・既定 import の除外 | なし。新しい補助を既定に含め、既定ビルドと全宣言の公理依存を確認 |
| 01-12・07-04 の写し | 現在の定義・規則・証明へ更新。変更の経緯は書かない |
| 生出力・絶対パス・一時領域への依存 | 生出力は一時領域だけ。大きさとハッシュを下表に保存。再現する本番のコードと検査台本を残した |
| レビューと受け入れ | RV-L20.a4 は関門の通過に同意した条件付き可。r2で全所見を処置。修正の再確認と設計者の受け入れは取りまとめ・設計者に残る |

計画からのずれは、取りまとめが r1 で承認した Ordinary の供給の撤回、MeaningLe/MeaningArgs の導入と外側 motive の強化である。元の S07 を系として保ち、案Bへの切替はしていない。型付けの全33場合へ作業を広げていない。

r1 の最初の時計読取は07:17:00 JST、最初の下降の局所検査の成功の確認は07:21:16 JST。検査入力と記録の照合時刻は07:28:48 JSTで、そこまでの外側は11分48秒、約12分。能動時間と待ちを厳密には分離していない。当初の2時間30分〜7時間10分、上限14時間20分を超えていない。A4 の実装と指定の検査は完了したため、その残りの実装時間はない。独立レビューと受け入れの待ちは不明。この実績を型付け33場合や後続の全接続の見込みへ比率で掛けない。

## 初回 r0 の記録

初回は、S07 の入力から Ordinary を一律に取り出す命題を反例で否定し、指定経路を不成立として停止した。任意の部分型に対する意味の移送自体を反証したとは記録していない。最初の時計読取07:06:57 JST、反例の最初の成功の確認07:10:43 JST、外側は約10分。反例の局所検査は2回の記法・正規化の修正後に成功した。r0 の作業末は終了0・8.873秒、公理依存は48宣言で終了0・0.833秒だった。r1 の成功の根拠には、異なる状態の r0 の検査を引用せず、上記の r1 の実行を用いる。

## 生出力の識別

一時領域を永続の根拠としてリンクしない。生出力は `<tmp>/benitoite-a4-r1-<名前>.log` に置き、要約は上に記した。

| 名前 | bytes | SHA-256 |
|---|---:|---|
| order-1 | 1985 | 78aa503b669c56cc26887a88db5c76ac6b045c5b588b648e9cab358e3439e067 |
| order-2 | 1094 | 5b2da666bb93bedc8d67af8f95500ecca18b58bf9ef692e7dd9e782c2a74f870 |
| order-3 | 0 | e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 |
| order-4 | 0 | e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 |
| transport-1 | 3805 | 7a483b53d3adff04fff8c1c97d7d3a27ffb2b9dd248fb19553bbce035101895c |
| transport-2 | 244 | 7a2c89931cf360726e252b84a65b0adb493cda2373707b320c019620e838a59c |
| transport-3 | 0 | e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 |
| transport-4 | 0 | e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 |
| transport-5 | 1557 | 372b60f535ba67d787366b5509c53de70b9f3c0769718659ce03644b573a0cff |
| transport-6 | 0 | e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 |
| transport-7 | 0 | e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 |
| dry-run | 759 | dc62b3e51f6ad280a535dfaff5919242eb4fde18effd9a010aa461e98df0c5c6 |
| work | 5718 | c8772ae3a3d7548a8a5aab344c713b1afe87a1a423772b7541320046e73d8704 |
| axioms | 24232 | f51fcdd5c7a057efa7310d2bf100cda9e77d5aff4a607ecdd6abe0810dbc73fe |

## 検査入力の SHA-256

下表は検査した未コミットの実装・写し・検査台本と設定である。作業末の後の変更は本記録・判定・署名の説明だけであり、Lean・仕様の写し・検査設定は変更していない。axioms.lean は最後の単独検査でその最終状態を検査した。

| 入力 | SHA-256 |
|---|---|
| formal/Benitoite/Release/Refinement/MeaningOrder.lean | 7ce85aa4f04dc6101a61f00b57d55a7c68a8981c372588a17a25e536195e707f |
| formal/Benitoite/Release/Refinement/MeaningTransport.lean | 9f5cb76762a72dc45e415cc11a97b19b73d3f2a9b315aceecbbb37fcd12aa330 |
| formal/Benitoite/Release/Refinement/MeaningTransportObstruction.lean | 409c1d37d747fa0f043b4a7810aef242472f5c5d5ec32239721fb6c71f67fe93 |
| formal/Benitoite.lean | de21550264420c7c72c295b10d7c332cdb2c8acd0758aab9ea8a57285c60cc1d |
| docs/design/01-spec/01-12-core-calculus.md | 7d0283b60a3c3c1cdafec4d1b5874860f1c10641317944a6aa04febedd39e556 |
| docs/design/07-quality/07-04-formal-semantics.md | 09738c4bdf1fc4b23fb28352af53652241fb3e1bbe7804a5160ed1d9f17960a0 |
| docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/a4/axioms.lean | 63e0f8ed091540b33818b1b923844c03ce676931b03abf21b33134415662f482 |
| formal/lakefile.toml | 10f2661bff8fce95a9253d976427d0ca44038ec12350c955badbc1cf1efa6e3a |
| formal/lean-toolchain | d5edba4e4b8faad9c1baeadb265716d20d03be4d1a2647dc5e35b0c0325bea7b |
| formal/lake-manifest.json | f4a9b127f95cf577c7da1c2269f85ffd5754f76afccace5dc310d56ef8f41a32 |
| rust-toolchain.toml | 4d7d5425fe623392e565a964fc135c563c316ce125058199eb40b2953ba6ecbb |
| scripts/check.sh | 346759324694465213cdcbb6d9d272c6e55de7697ce2204bd98a22c5b661bf34 |

## r2 の生出力と最終入力

| 出力 | bytes | SHA-256 |
|---|---:|---|
| dry-run | 759 | 1da1e5844de6218edc23e0aea3dff842f5ad4fd6c9a039a920b00d9876d4d1e4 |
| work | 5718 | 024ed0da971b2e00ab52bd505717d7b04414c77b9092abe8c89aff3cc9f9f86e |
| axioms | 23094 | 4f7e57ae11931b729112e61682e48773928d544fd71e76a4e454bbd3cc3dde22 |

検査の後は判定・結果・署名の説明だけを更新し、Lean・仕様の写し・詳細・検査台本は変更していない。

| 入力 | SHA-256 |
|---|---|
| formal/Benitoite/Release/Refinement/MeaningOrder.lean | 7ce85aa4f04dc6101a61f00b57d55a7c68a8981c372588a17a25e536195e707f |
| formal/Benitoite/Release/Refinement/MeaningTransport.lean | eb3d0735437e9bc66e842ca8de6dfe90d503d41f083fc1e0b922d74ec930ebff |
| formal/Benitoite/Release/Refinement/MeaningTransportObstruction.lean | 409c1d37d747fa0f043b4a7810aef242472f5c5d5ec32239721fb6c71f67fe93 |
| formal/Benitoite.lean | de21550264420c7c72c295b10d7c332cdb2c8acd0758aab9ea8a57285c60cc1d |
| docs/design/01-spec/01-12-core-calculus.md | 5cccc6f48603f6e8dd15a041b5546ab16ae907e1eb6ab65a3e10a73bc93a1f32 |
| docs/design/07-quality/07-04-formal-semantics.md | 7131340c28efd14dd01ec3beb0c851e1a32146a4f0f0386bb2765f82f46fc778 |
| docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/detail.md | 9ca3a779f92b02b8dae432f0172cbd18ba3d77493861074ffe57bb68f422e777 |
| docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/a4/axioms.lean | 34904177b934ba7302526605d8e63af469c60ccc625e23ed30b9e848f5fa8908 |
| formal/lakefile.toml | 10f2661bff8fce95a9253d976427d0ca44038ec12350c955badbc1cf1efa6e3a |
| formal/lean-toolchain | d5edba4e4b8faad9c1baeadb265716d20d03be4d1a2647dc5e35b0c0325bea7b |
| formal/lake-manifest.json | f4a9b127f95cf577c7da1c2269f85ffd5754f76afccace5dc310d56ef8f41a32 |
| rust-toolchain.toml | 4d7d5425fe623392e565a964fc135c563c316ce125058199eb40b2953ba6ecbb |
| scripts/check.sh | 346759324694465213cdcbb6d9d272c6e55de7697ce2204bd98a22c5b661bf34 |

## 作業末の work

`scripts/check.sh --level work --base d243526e8adc08eaec15abdebd724022b52937b3` を、Refinement の生成物を消した状態で実行した。終了0、外側101.00秒、最大常駐量1,365,950,464バイト。
