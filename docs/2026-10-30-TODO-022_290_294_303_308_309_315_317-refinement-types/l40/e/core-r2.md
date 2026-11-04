# 再開2: 通常のcore本体

開始（UTC）: `2026-11-03T20:25:07+00:00`。基準は `548d3fd94a5f1a171c9bc749b3408f8a9f3c08f8`。取りまとめの開始合図後に唯一のwriterとして着手した。安全な19契約、既存型規則、精密mapFromとgetter9の停止記録を変更しない。

対象は通常の公開27行と、その元本体が呼ぶ非公開helper、自動getterである。元の公開署名とラベルを維持する。自動getterのラベルはRustの宣言作成（typeck/decls.rs）の `value`、実本体はir/desugar/decls.rsの一欄だけを束縛する一腕matchに従う。通常のnominal入力と通常結果の型付けを示し、精密な欄等値の証明とは区別する。

| 作業・検査・受け入れ | 見込み |
|---|---|
| 通常getter12本と公開射影12本 | 15〜30分 |
| List5本とhelper5本 | 30〜50分 |
| Map/Set4本 | 20〜35分 |
| Range検査3本とNonEmptyList残り3本 | 25〜45分 |
| 既定ビルド、写し、公理監査 | 10〜15分 |
| 取りまとめの全体照合・群末work・独立レビュー・受け入れ | 所要不明、取りまとめの担当 |

## 通常getterと公開射影

開始（UTC）: `2026-11-03T20:25:07+00:00`。

終了（UTC）: `2026-11-03T20:31:01.710294+00:00`。通常getter12本と公開射影12本（Range10本・NonEmptyList.head/tail）の同じ有限表へのlookupと `Def.WellTyped` を接続した。公開射影は元のgetterへのfnRefを一度呼ぶ。単独Lean `r2-core-getter08` と既定ビルド `r2-core-getter-default` は終了0。既定ビルドは17.22秒、開始から約6分である。途中の名前解決・パターン・型引数証明の失敗をchecksに保持し、成功に書き換えない。

通常27行のうち12行を接続した。精密safe19と正常篩の未完は閉じていない。この群の短い実績から、残りはList5＋helper5を25〜40分、Map/Set4を15〜25分、Range検査3とNonEmptyList残り3を20〜35分、写し・既定ビルド・公理監査を5〜10分と積み上げる。合計65〜110分を見込む。全体照合・群末work・独立レビュー・受け入れは取りまとめが行い、所要不明である。

## Listのfoldと走査

通常getterの終了後に着手した。開始時の時刻の追記を漏らしたため、正確な開始時刻は未取得である。最初の単独Lean検査の開始（UTC）は `2026-11-03T20:32:38.807576+00:00` である。五公開関数と五非公開helperの実本体を対象にする。foldはcallback結果を加算より先に束縛し、any/allは短絡する条件分岐を保つ。

五公開本体と五helperの単独Lean `r2-core-list09` は終了0。既定ビルド `r2-core-list-default` はUTC `2026-11-03T20:37:59.021285+00:00` に終了0、19.83秒だった。その後、同じ最終P/Bで収集するため、構成子・get・加算・helperのlookupと空制約のsatだけを持つ `Inputs` から型付ける形に一般化した。新しいTyped前提は含めない。一般化後の単独Lean `r2-core-list-general01` はUTC `2026-11-03T20:38:36.394521+00:00` に終了0。通常coreは17/27行を接続した。精密safe19と正常篩の閉鎖は0である。

## 残る通常本体と同じ有限表への収集

開始（UTC）: `2026-11-03T20:39:34+00:00`。Map/Setのfold/forEach、Rangeの検査三本、NonEmptyListのfromList/toList/mapを実装する。Pairの二射影とList.map/mapFromを同じ有限表の補助宣言として含め、既存の元本体の型付けを適用する。NonEmptyListはfirst/restのnominal表現を使う。

最終単独Lean `r2-core-program13` はUTC `2026-11-03T20:59:07.007908+00:00` に終了0、105.57秒だった。`StandardOrdinaryCoreProgram` の `all_lookup_typed` は同じP/Bの全lookupから実定義の `Def.WellTyped` を導き、`declarations_typed` は公開27本をその表へ接続する。既定内の読者は公開27本・全48定義の件数と両入口の適用例を検査する。

| 通常契約の対象 | 公開引数ラベル | 型引数・callbackの条件 |
|---|---|---|
| List.fold | xs, initial, f | T,A,E。fのacc,valueと効果Eを保持 |
| List.forEach | xs,f | T,E。fのvalueと効果Eを保持 |
| List.any/all/find | xs,p | T,E。pのvalueと効果Eを保持。any/allの短絡、findの元要素を保持 |
| Map.fold | m,initial,f | K:key,V,A,E。fのacc,key,valueと効果Eを保持 |
| Map.forEach | m,f | K:key,V,E。fのkey,valueと効果Eを保持 |
| Set.fold | s,initial,f | T:key,A,E。fのacc,valueと効果Eを保持 |
| Set.forEach | s,f | T:key,E。fのvalueと効果Eを保持 |
| Range.checkInteger | minimum,maximum,value | 元のIntegerとResult[CheckedInteger,RangeError] |
| Range.minimum/maximum/value | value | 元のnominal CheckedIntegerとInteger |
| Range.checkLength | minimum,maximum,values | T。元のResult[CheckedLength[T],LengthError]と早期return |
| Range.lengthMinimum/lengthMaximum/checkedLength/lengthValues | value | T。元のnominal CheckedLength[T]とInteger又はList[T] |
| Range.checkIndex | index,values | T。元のResult[CheckedIndex[T],IndexError] |
| Range.indexValue/indexValues/get | value | T。元のnominal CheckedIndex[T]とInteger/List[T]/T |
| NonEmptyList.fromList | values | T。元のResult[NonEmptyList[T],EmptyListError] |
| NonEmptyList.toList/head/tail | value | T。first/restのnominal表現と元のList[T]/T/List[T] |
| NonEmptyList.map | value,f | T,U,E。fのvalueと効果E、firstのcallback後にrestのList.mapを評価 |

最終Pには公開27本のほか、Listの非公開helper5本、自動getter12本、Pair.first/second、List.map/mapFromを登録した。非公開helper5本のモデル名は、既存のList.mapFromと同じ `List.foldFrom` 等である。元.bnt内の私有名は `foldFrom` 等、Rustのstdlib私有IR表示名もprefixなしであり、モデル名との対応をRustの実ID/ABIの一致とは数えない。自動getterは全て元のvalueラベルと、一欄だけを束縛して返す一腕matchを持つ。Pairの二射影は元のpラベルを保持する。

通常core27/27の静的本体の接続と、精密safe19及び正常篩の未完を分ける。固定の安全19契約、精密mapFromの停止記録、精密getter9の停止記録、FirstReturn・主な十言明・既存型規則は変更していない。正常返却の長さ・同じ欄の等号・callbackの動的な保存を、この通常型付けから結論しない。構成子/組込み/helperのlookupとsatから本体を構成し、独立のTyped前提・主定理前提・新しい公理を加えていない。

取りまとめから追加で依頼されたFloatMathの原引数ラベルの不一致は、signatureとinstantiatedの二箇所だけを `if single then "n" else "x"` へ直した。Float32のnとFloatのxを保つ。最終既定ビルドに含める。

### 最終既定ビルドの入力の識別

元標準ソース・getter/脱糖の照合箇所・本番Leanと二つの写しを、最終既定ビルドの実行中に識別した。この後、本番Leanと写しを変更しない。

| 入力 | bytes | SHA-256 |
|---|---:|---|
| `crates/benitoite/src/prelude/stdlib/List.bnt` | 6240 | `940ec3e00387a468b6392d3b8caace0f840d0d0d13caa23327acc76eb02ba3df` |
| `crates/benitoite/src/prelude/stdlib/Map.bnt` | 2951 | `bf99714990eb36d988e1de12b579bf7da9648f058e8357141e94de454ee41788` |
| `crates/benitoite/src/prelude/stdlib/Set.bnt` | 2396 | `6ccd252a7d3ba9f66be75bcf204cd0ed15c0b9a30e68919c9ee2c1305ddf6db7` |
| `crates/benitoite/src/prelude/stdlib/Range.bnt` | 9759 | `3aa344e1c98b494a05eeb45e4a35e0d4f77ffe90d2b51f7f97d01c97d3b6b43f` |
| `crates/benitoite/src/prelude/stdlib/NonEmptyList.bnt` | 3270 | `05679444789bf49f7c86f5b830290e6026822601c40902c950c5b7671117aa54` |
| `crates/benitoite/src/typeck/decls.rs` | 62571 | `14e416fdd98b85b98a712915d4d260f87290f655fa85c5445746c0377e25ae2f` |
| `crates/benitoite/src/ir/desugar/decls.rs` | 16528 | `7c0f3bbf7f055d6bab8d2b01dfae1129d11ba3ae431369a5c248c55078564635` |
| `crates/benitoite/src/ir/desugar/exprs.rs` | 52278 | `6be536c8e048968822d70f49b735ee8f2f011ecc1c28180e802be1164f0583db` |
| `crates/benitoite/src/ir/desugar.rs` | 13720 | `998f38ef05e685dbe7a2e2f4f83e3fa8eada41a9b62e9d819b19075d664b33d2` |
| `formal/Benitoite/Release/Refinement/StandardOrdinaryCoreBodies.lean` | 21012 | `19dc21ec51d446413fc24cd6fdb4ac9242454955224d8fba9f83f012961af539` |
| `formal/Benitoite/Release/Refinement/StandardOrdinaryListBodies.lean` | 28471 | `fcc43e40f793fa1d058ab093caa4002b313031746cef15d07987c0c1acdab968` |
| `formal/Benitoite/Release/Refinement/StandardOrdinaryCoreProgram.lean` | 72473 | `a9402492048c50963db405313a472683a361cd45cbcfcd887036e93ba94ff81c` |
| `formal/Benitoite/Release/Refinement/StandardFloatMathResponse.lean` | 9569 | `f088ed68e912db6cad0af14373bc22e4b8557e0dc5854be38844c7656a2b7ea9` |
| `formal/Benitoite.lean` | 24868 | `41841006edce5b0c48529b1657a7590c9fabff7ff165599d42145427a7696de7` |
| `docs/design/01-spec/01-12-core-calculus.md` | 855794 | `0144237160786de58150b250d138f6e4f69a1609941e62da61830150aa1a8349` |
| `docs/design/07-quality/07-04-formal-semantics.md` | 558199 | `1df7dd5dac58247b2ee83b3f8ae0066da5e9b4c7b1f3cfe30578d397f5b207b4` |


終了（UTC）: `2026-11-03T21:01:16.829774+00:00`。最終既定ビルド `r2-core-final-default` はformal/から対象・optionなしの `lake build` を実行し、1013ジョブ・終了0、113.29秒だった。新しい最終Programの検査は112秒、rootの検査は652msと出力された。既存成果物の再生を含むビルドであり、clean buildの所要とは数えない。生出力43,839 bytes・SHA-256 `2353f06b89fea04cadbeed79d93b034867358f478783456796dc93ca431f941e`。既存のリンク探索警告を保持する。FloatMathの原ラベル修正も同じビルドで成功した。

最初の開始時刻から最終既定ビルドの終了までの外側の時間は約36分10秒である。能動時間・モデル待ち・計算待ちは分離していない。時刻の記録のずれは、List群の正確な開始時刻を開始時に追記しなかった一点である。同群の最初のLean開始時刻を別に示し、推定時刻で埋めていない。実装と検査の失敗は削除せずchecksへ保持した。

| 完了条件 | 判定 |
|---|---|
| 通常core27本の元公開署名・ラベル・実本体 | 接続済み。List5、Map2、Set2、Range13、NonEmptyList5 |
| 全48定義の同じP/BへのlookupとDef.WellTyped | `StandardOrdinaryCoreProgram.all_lookup_typed`。公開27・helper5・getter12・Pair2・List.map/mapFrom2 |
| 公開入口と既定内の読者 | `StandardOrdinaryCoreProgram.declarations_typed`。公開27/全48の件数と適用例を既定内で検査 |
| key制約・効果・短絡・callbackの一度の評価 | 元の署名とCompに保持。CheckedLengthの途中のreturnはC_Escape、NonEmptyListはfirst/restのnominal表現 |
| 固定safe19・精密mapFrom・精密getter9 | 変更なし。今回の通常型付けで精密契約を閉じない |
| 主な十言明・型規則・FirstReturn・CallRun | 主な十言明/既存型規則/FirstReturnを変更せず、CallRunを追加しない |
| 本番importと01-12/07-04 | 新三モジュールを既定importへ追加し、同じ変更で両写しへ現在の性質を反映 |
| git・Rust・.bnt・共有results/obligations/sources | 編集・操作なし。共有plan/detail/reviews/A〜Dも変更なし |
| 公理監査・全体verify・群末work・独立レビュー・受け入れ | この区切りでは未実施。取りまとめが次の区切り及び群末に行う |

新しい本番モジュールは `StandardOrdinaryCoreBodies`・`StandardOrdinaryListBodies`・`StandardOrdinaryCoreProgram` の三本である。取りまとめはこの三本をmodules一覧と公理監査の対象へ加える。最終既定ビルドの後、本番Leanと二つの写しを変更していない。全公理監査の結果が出る前に、新しい公理依存がないと監査済みの形では報告しない。

| 残る検査・受け入れ | 見込みと担当 |
|---|---|
| 新三モジュールを含むprivate/生成宣言の全公理監査 | 取りまとめ。次の純粋APIの区切りとまとめて実行。所要不明 |
| 全体verifyと通常328行の分類・sourcesへの集約 | 取りまとめ。所要不明 |
| 群末のwork一度、独立レビュー、設計者の受け入れ | 取りまとめ/独立担当/設計者。所要不明 |
| 精密safe19及び正常篩の未完 | 今回の通常27本とは区別して保持。所要不明 |

`checks-r2-core.json` に台本で記録した検査は35件、終了0は15件、終了1は20件である。単独Leanは全てformal/から固定Leanに `-M 12288` を指定し、既定ビルドは全てformal/から対象・optionなしで実行した。RSSは計画上の非採取である。
