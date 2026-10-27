# 作業 L23 の結果

着手: 2026-10-26 07:44:19 JST。終了: 2026-10-26 08:04:03 JST。所要時間は19分44秒である。

基準 B_WORK と HEAD はともに `6e47419f989453b55dc4bc8a121285a1819b3d9f`、ブランチは `mod012/L23` である。L23 の明示構築と局所保存の対応を実装し、指定 work の三単位は成功した。検査本体は終了0、計測器はサンドボックスの制約で終了1となり、最大常駐量は取得できなかった。独立レビューと受け入れは取りまとめへ引き渡す。

## 実装した範囲

| ファイル | 内容 |
|---|---|
| `formal/Benitoite/Interval/Eval.lean` | HttpRecordKind・HttpRecordDecl、解決済みの所有元・構成子・欄数・型引数・対象の Integer64 欄の読み出し、正常なソース順の欄値から宣言順の con を作る httpRecordBuild、対象欄と data の型の保存を追加した |
| `formal/Benitoite/Interval/Environment.lean` | HttpRecordFact と有限な HttpRecordState、その別の Models、局所位置の extend・copy・lookup・forget と対応の証明を追加した |
| `formal/Benitoite/Interval/FixedDomain.lean` | 二つの欄の正常域、型付き表層の明示構築の同定、ソース順の抽象位置からの欄の取得、構築・同じ局所位置からの読出し・既存の bindRange と局所保存の同時の対応を追加した |
| `formal/Benitoite/Interval/HttpRecordExamples.lean`（新設） | 正常域の端、逆順を含む欄の指定、偽の所有元・構成子・内部表現、一般の戻り値・任意の射影の未知、局所位置と別名・shadow・忘却を10個の #guard と1個の証明例で確かめた |
| `formal/Benitoite.lean`、01-12、07-04 | 独立例を既定 import に追加し、定義・補題・入力条件・現在閉じた範囲と A1 の限界を写した |

Response の対象は宣言順の0番の status、正常域は **[200,599]** である。ClientRequest の対象は4番の timeoutMilliseconds、正常域は **[1,max64]** である。2^40+1 と max64 も域内として確かめた。他の欄の成功条件、IO の成功、timeout の実際の丸めは主張しない。構築時には域外の値も保存する。構築時に正常域を課して警告すべき入力を除外する規則にはしていない。

httpRecordBuild は、正常に得た値をソース順で受け取る。positions の同じ位置に欄の宣言順の番号を置き、全欄の置換と値の個数の一致を確認して recordFields で並べる。独立例では Response を `[2,0,1]`、ClientRequest を `[4,1,3,0,2]` の順に指定し、status はソース順の2番目、timeout は最初の値から保存されることを確認した。実交換と同じ `.data owner []` と `.con owner [] constructor fields` を使い、新しい opaque 型や具体値の構成子は増やしていない。

httpRecordAt は、構成にある標準レコード表の解決済み構成子と結果の data 型、空の型引数、全欄の位置と個数を照合する。表へ渡す所有元・構成子・欄順が実交換の標準宣言と一致することは入力の条件であり、表示名の検査や追加ロードで補わない。HttpRecordSource は、明示構築か同じ data 型の局所位置だけを読む。一般の関数の戻り値、アクセサを含む任意の call、型だけを知る値から欄を推測しない。

局所保存は既存の整数の環境とは別の補助記録である。HttpRecordState.Models は、保存した欄と同じ具体位置の対応だけを述べる。空の記録・忘却後の記録は任意の具体環境に対応し、other や未認定の con を除外しない。extend は新位置へ事実または none を置き、copy は参照時の事実を複写し、元の位置を更新しない。`http_record_bind_corresponds` は、既存の bindRange の Models と欄の extend の対応が同じ具体環境の拡張に対して同時に成り立つことを証明した。

この区切りで閉じたのは、正常な欄値を受け取る構築の局所処理と局所保存の対応である。L22 の引き継ぎと同様、表層の EvalPartial・解析・中心定理へ新しい具体規則を接続したとは扱わない。欄式の評価・失敗・return、欄更新、Http.respond/request の W0404 への接続は L24、全 API の独立例と C4 は L25 に引き渡す。

## 中心二命題・既存の言明・参照定義

[差分点検器](contract-check.py)と[記録](contract-check.json)は、既存のファイルを基準と比較した。Eval・Environment・FixedDomain は既存の名前空間の終わりの直前に宣言を追加しただけで、追加前の本文は全バイト一致する。Benitoite.lean は新しい import を除いて一致し、ほかの既存 formal は全バイト一致する。**既存の定理・補題の言明3,463件は、証明本体とともに不変である。**

| 言明が参照する定義・保証 | 差分と向き |
|---|---|
| NormalSoundness・WarningSoundness | 本文・量化・前提・結論とも不変。新しい条件を中心命題へ渡さない |
| EvalPartial・EvalArguments・EvalBlock・EvalStandard・StandardRule・Unmodeled・UnknownAt | 不変。具体評価の導出や未知の集合を変更していない。新しい構築は正常な欄値の並べ替えであり、既存の未知の評価を狭めない |
| ConcreteValue・ConcreteValue.type・RangeNames・RangeRecord・rangePayload・rangeStoredValue | 不変。HTTP の局所処理も既存の con と data を使用し、不都合な具体表現を排除しない |
| AbstractSlot・AbstractEnv・SlotModels・Models・RangeState.Models | 不変。HttpRecordFact.Models と HttpRecordState.Models は別の関係であり、既存の Models に欄の既知性や API の成功を要求しない |
| targetOperationAt・concreteRule・WarningLocated・InSyntacticReach・CallReach・独立入力の保証 | 不変。位置の認定、構文的な到達可能性、未認定 call の保証を弱めない |
| 解析器・予算・発見・独立入力・本体/全体の駆動・EvalClosed | 不変。正常区間・警告列・操作数・保持数・停止位置・分類に変更はない |
| HttpRecordDecl/read/build・HttpRecordFact/State と新しい対応の補題 | 新設。二つの欄についてだけ、構築・保存・読出しの対応を示す。既存の定義の意味は変更しない |
| Builtins.Assumptions・Interval の外の旧主定理・公理・lakefile.toml | 全バイト不変。sorry・admit・native_decide・新しい公理を追加していない。-M 12288 を保持した |

[公理照会](axioms.lean)と[出力](axioms.log)は、中心二命題、正常値・警告・位置・独立入力の公開定理と新しい対応の補題の41宣言を確認した。依存は propext・Classical.choice・Quot.sound の範囲内であり、sorryAx や独自公理はない。中心二命題や既存の公開の定理の意味を弱める必要、言語の規則の変更、公理の追加を要する停止条件には当たらなかった。

## 独立例の作成時の関門

守る契約は、解決済みの同じレコードの欄の保存、ソース順と宣言順の区別、一般の戻り値と射影の未知、局所保存の複写である。ソース順を宣言順と誤認する、status の下限を100にする、2^40超の正の timeout を域外にする、型や表示名だけで構成子や内部表現を認める、shadow が元の事実を書き換える変更で失敗する。

既存の FixedDomainExamples は直接引数と標準 call の位置を検査しており、HTTP の欄の構築と局所保存を検査していない。その契約の持ち主に HttpRecordExamples を一つ追加し、期待する整数・位置・未知の結果を独立に指定した。最後の証明例は、異種の欄値から構築した実際の con に対して既存の束縛の Models と補助記録の対応を構成する。テスト専用の公開範囲・引数・フラグは増やしていない。解析器・評価器を kernel の計算で実行する例はなく、実行可能な表は #guard とした。

削除したテストや緩めた期待値はない。既存の formal 三ファイルと import は335行追加・削除0、新しい独立例は118行・削除0である。Rust の本体・テストは変更していない。

## 検査と途中の修正

実行場所は `<repo>`、固定した Lean は4.34.1、Rust は1.98.1である。記録に手元の絶対パスを残していない。[local-build.py](local-build.py) はローカル import の依存順に一モジュールずつビルドし、Lake の内部で未ビルドの Lean が並行起動しないようにした。[process-control.py](process-control.py) は時間上限時にプロセス群を停止して終了を回収する。Lean を背景に残して別の作業へ進めていない。試行と独立例の単体検査には -M 6144 と300秒の上限、全モジュールのビルドには固定の -M 12288 を使い、既存 Sound は175秒・既存 Examples は25秒を上限とした。上限を増やした再試行、時間上限による停止、メモリ不足、番人による停止はなかった。

| 検査・コマンド | 終了状態・結果 | 外側の時間・記録 |
|---|---|---|
| `lake env lean -M 6144 Benitoite/Interval/Environment.lean` | 修正後0 | 0.655秒。[記録](environment-fixed.json) |
| `lake env lean -M 6144 Benitoite/Interval/FixedDomain.lean` | 最後の補題の修正後0 | 0.506秒。[記録](fixed-domain-complete-fixed.json) |
| `lake env lean -M 6144 Benitoite/Interval/HttpRecordExamples.lean` | 修正後0。10 guards と1証明例 | 0.438秒。[記録](http-examples-fixed.json) |
| 全262モジュールの直列ビルド | 0 | 159.828秒。[全試行のログ](sequential-build.log)・[集計](sequential-build.jsonl) |
| 公理照会41宣言 | 0 | 0.657秒。[記録](axioms.json) |
| `lake --no-build build` | 0、既定354ターゲットが最新 | 0.151秒。[出力](default-up-to-date.log)・[記録](default-up-to-date.json) |
| 同じ基準・指定の dry-run | 0、指定した三単位だけを選択 | 0.010秒。[出力](dry-run.log)・[記録](dry-run.json) |
| 下記の指定 work、一度 | **検査本体0、三単位成功**。仕様例7件成功・失敗0・ignored 0 | 本体78.168秒、計測器を含め78.196秒。[出力](work.log)・[本体の記録](work-check.json)・[計測器の記録](work.json) |
| 最終の差分・固定表・公理・検査状態・パスの点検 | 0 | 2.629秒。[点検器](final-review.py)・[詳細](final-review.json)・[実行記録](final-review-run.json) |

指定 work は [work-check.py](work-check.py) から次のコマンドを実行し、その外側を `/usr/bin/time -l` で包んだ。Cargo は既存の書き込み可能な `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使用した。

```sh
scripts/check.sh --level work --base 6e47419f989453b55dc4bc8a121285a1819b3d9f --only formal_build,spec_examples,spec_tally
```

**最大常駐量（maximum resident set size）は取得不能である。** 検査本体が selected checks passed・終了0となった後、time が `sysctl kern.clockrate: Operation not permitted` を報告して終了1になった。計測器の終了1を検査の失敗や成功に読み替えていない。監視のための ps も環境に拒否された。

work は前段の実績から見込んだ約10秒の2倍を超えたため、実行中に報告した。回収した出力では仕様例自体は3.13秒である。実行中に Rust の `target/debug/.fingerprint` の826ファイルが更新され、Lean の `formal/.lake/build/lib/lean` は更新0件だったことから、Cargo の再ビルドを伴っていたと判断した。各単位の準備時間を分離して計測してはいない。[最終確認](final-review.json)に更新件数と最初・最後のファイルを残した。再実行で速い結果へ置き換えることはしていない。

spec_tally の自己検査は成功し、初回リリース版の未記入の完了条件は none である。Rust のテスト参照がない仕様節の情報表示には、既存の Lean の節と新しい HTTP の節が含まれる。追加した Lean の定義と独立例は既定ビルドで検査した。

途中の失敗と修正は次のとおりであり、ログを保存した。

- Environment の初回ビルドで、存在しない Option.flatten と、具体位置の等号の向きで失敗した。getD none と等号の対称形へ直して成功した。初回の失敗と時間は sequential-build.log に残した。
- FixedDomain の初回の単体検査で、call のラベル型、構文のケース分け、未知の整数幅の矛盾の簡約が一致せず失敗した。Surface の List (Option String) と場合分けに合わせた。構築の表の所属証明では、simp 後の連言を直接分解する形へ直した。各試行は fixed-domain-*.log に残した。
- 局所読出しの橋渡しの補題では、分解前の証拠を残した依存する場合分けで失敗した。取り出した証拠に別名を付け、元の証拠を消してから型の場合分けを行い、言明や仮定を変更せずに成功した。
- 独立例の初回は SlotModels の形のまま Decidable を解決できず失敗した。該当する既知整数の所属を、小さな二端点の比較へ明示して証明した。期待値を変更していない。[初回](http-examples-first.log)と[成功](http-examples-fixed.log)を保存した。

## 固定表・計画との差・申し送り

**A11 の固定表とその関連ファイルは全て基準と全バイト一致し、再生成・再計算していない。** 解析器・予算・EvalPartial・EvalClosed が不変のため、本枝で期待値が変わる形は0件である。先行作業が報告済みの差は、既存の A16〜A18 への引き継ぎに従う。

計画に挙がる Eval・Environment・FixedDomain と写しのほか、独立例を別モジュールに置き、既定 import を一行追加した。言語の規則、中心命題、既存の主定理、検査の割り当ての変更はない。欄の補助記録を既存の AbstractEnv へ組み込むことや予算付きの解析へ接続することは、L23 の局所保存の証明から結論していない。

| 担当・時期 | 残る実装・検査・レビュー・受け入れと引き継ぎ | 見込み |
|---|---|---|
| 取りまとめ、L24へ渡す前 | L23 の定義・言明・参照定義の向き・公理を独立レビューし、局所の対応を受け入れる。既存の全定義と固定表が不変であることを確認する | 不明 |
| L24、L23 の受け入れ後 | 明示した欄更新で非更新欄を保ち、固定域 call と HTTP の表層評価・解析・W0404 を接続する。httpRecordBuild は正常なソース順の欄値だけを受け取るため、異種の型を持つ欄式をソース順で評価し、失敗と return で後続を評価しない接続を別に定義する | 計画の当該枝に従う。証明の反復の内訳は不明 |
| L24 の環境・予算の接続 | HttpRecordState.Models を既存 Models の前提に足さず、内部の補助条件として構成する。None の追加で通常・パターン・専用位置のずれを合わせ、境界・合流・独立入力で忘れる。D16 の欄一項の保持と走査の計上を接続し、既存の公開保証を弱める必要があれば D15 の停止条件へ戻す | 上記に含む |
| L25・C4、A19〜A21、X02・X03 | 全 API・更新・名前付き順の独立例、実交換の標準宣言と欄順の同定、Rust の接続、A1 の信頼の範囲としての VM 比較、各 work と接続の stage、独立レビューと受け入れ | 各計画に従う。今回未測定の範囲は不明 |

最終確認以後の実装・写し・固定表は変更していない。結果の別状態への引用による検査の省略はない。Rust/Lean・実 VM の全比較、stage・change・release、性能測定は本枝で先取りしていない。private/ とそこを指すリンクは読まず、git の変更操作・担当の委任は行っていない。コミット・取り込み・docs/todo の更新・保管・公開は取りまとめへ引き渡す。

## 取りまとめのレビュー（2026-10-26）

中心二命題の本文は基準と同じで、sorry・公理・`decide +kernel` の追加はない。既存の定理・補題の言明3,463件は保たれ、Eval.lean への追加は HTTP レコードの同定と構築の補助で、既存の `.data`・`.con` を使う（型の符号化は L21T と同じ）。status の正常域は [200,599]。固定表は不変。L24 へ進む。
