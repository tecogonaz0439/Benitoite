# P3: 現行の処理系へ接続するための読み取り調査

## 結論と調査の境界

U1 は、`PathIn` と `RequestIn` の実行時の保持表現を残し、型の等号・値の部分型・所属を分ける形で進められる。現在の `check` の成功枝は動的条件と静的添字の両方を実行時に検査しており、`widen` は同じ値を返す。読み取った公開ソースの入口に、所属しない狭い標準対象型を注釈だけで構築できる箇所は見つからなかった。ただし、これは全プログラムの不変条件の証明ではない。型の保存、全 delta の契約、表層からコアへの対応、信頼する Rust の内部構築の条件が残る。

処理系の変更は `flow_inner` の再帰化だけでは足りない。現行の呼出しは型の等号で関数の形を合わせ、引数へ Flow を出す。値に依存する契約には、名前付き引数の対応表を使う同時代入、各引数の一度の評価、期待型からの遅延した認定が必要になる。さらに、独立したコア検査器は現在も最外の関数効果だけを広げるので、同じ変更で直す必要がある。

本担当は本番の Rust・Lean・設計書・TODO を変更せず、ビルドとテストを実行していない。「確認」はソース分岐を読んだこと、「既存の期待」は既存テストが記述する期待、「提案」は採った規則から必要になる本番の変更を意味する。既存テストの成功を今回再確認したとは書かない。本番へ渡す入力と期待は [runtime-cases.md](runtime-cases.md) にまとめる。

開始の割当は 2026-10-30 06:35 UTC。上限は処理系調査3時間。最初の時計取得は06:37:47 UTCであった。初期読解には private の運用指示、orchestration、P-common、rtk、japanese-tech-writing、00-01を含む。受け入れ入力の設計には test-audit の作成時の関門を使う。終了時刻と所要は末尾へ追記する。

## 型推論と表層の変更点

パスの`typeck/`・`builtins/`・`external/`・`ir/`・`runtime/`・`vm/`・`types/`・`prelude/`・`refinterp/`・`bytecode/`は`crates/benitoite/src/`を根とする。`tests/`は`crates/benitoite/`、`tools/`はリポジトリの根を基準とする。同じ行で続けて示すファイル名だけの表記と`:行`は、直前の同じファイルまたは同じディレクトリを指す。

| 接点 | 現行の根拠と確認した動作 | 本番で必要な変更・破れる場合 |
|---|---|---|
| 推論型 | `typeck/infer.rs:25–50`。`ITy` は Var/Con/Fn/Param/App/Rigid/Error、関数は独立な `params`・`ret`・`effect` | 篩の前の型と述語、論理上の値変数の番号とsort、依存する引数列を保持する。型変数・行変数・範囲変数へ値の番号を流用しない。既存の剛な節型変数の範囲も保つ |
| 制約の種類 | `typeck/infer.rs:216–257`。Equal、Flow、Try、EffSub は別の構成子。Flowには from/to/reason がある | Flowへ利用可能な不変の事実とソース位置を結ぶ。構造の未解決と、反証・unknownを区別する。Equalを含意へ置換しない |
| 等号 | `typeck/solve.rs:748–776`。Conは構成子・添字の等号の後に全引数を再帰比較。Fnは名前の契約・個数・全引数・結果を等号比較。`:818–834`は効果を双方向のStructuralで照合 | 篩の平坦化、true、別名、束縛名と決めた正規化の後の構造を比べる。相互被覆・相互含意で等号を成功させない。Reference、Set、Mapの鍵、Fail、辞書の不変位置ではこの等号を使う |
| FlowとF3 | `typeck/solve.rs:854–922`。Fn/Fnも引数と結果へ`equal`、最外の効果だけCover。他の型はequalへ戻る。Fn/Varは引数と結果を共有する形を作る（`:872–889`） | 引数を逆方向、結果を同方向に再帰比較し、依存する後続の型を渡し先の値で比較する。Fn/Varの現在の共有だけで部分型の上下の制約を表したことにしない。不変位置の関数へF3を侵入させない |
| 名前付き引数 | `typeck/calls.rs:193–220`はソースの順に式を検査。`:491–529`で宣言位置を選び、`:559–567`で`source_to_param`を保存。`:594–632`はcalleeとのEqualと各引数のFlowを生成 | 論理上の値はソース順に一度束縛し、対応表で宣言順へ並べて、後続の引数・結果・効果へ同時代入する。名前順に式を再評価すると副作用の順と依存する契約が変わる。位置対応と代入を別々に推測しない |
| 脱糖の順序 | `ir/desugar/exprs.rs:353–376`は各引数を順にevalし、`planned_arguments`へ保存した値を渡す。`:379–429`は対応表の個数・名前・重複・欠落を検査。`:1327–1355`は保存した値の参照だけを宣言順へ並べる | この既存の順序を保ち、作った一時束縛を依存する型の値変数と対応させる。部分適用では固定値の捕捉と将来の引数を同じ時点の自由変数にしない |
| 注釈したラムダ | `typeck/generate.rs:684–713`は自身の引数注釈をlocalsへ登録して本体を検査し、関数型を作る。注釈なしはfresh型 | 自身の注釈で本体を検査することを保ち、関数全体を期待するcallback型へFlowする。期待型が狭いことを理由に、広い注釈の本体を狭い入力として再検査すると不健全。無注釈だけ期待型の入力契約を使えるようにする |
| try | `typeck/effects/special.rs:12–99`は構造が未定のTryを待ち、決まる限り解き直す。`:117–149`はResult/Optionの先頭の型引数と結果をunify。`:190–221`はor return側の構造・失敗型を照合 | 成功値への期待型・必要な篩をResult/Optionの中へ伝え、構造が決まる前にcheckの成功型を広く固定しない。or returnの失敗型の等号と正常結果の共変を分ける |
| mapError | `prelude/stdlib/Result.bnt:27–31`。通常の多相関数で、Ok(x)は同じx、Errorだけfで変換する | 独自の名前認定を追加せず、通常の型変数TとResultの変性を通して成功値の条件を維持する。未定Tを先にInteger/Topへ固定してから期待を当てる順序を避ける |
| パイプ | `typeck/generate.rs:1358–1368`は呼出しへの先頭挿入と、通常の関数適用の二形。`typeck/calls.rs:164–170`は挿入する左辺を一度検査 | 両形で同じ期待型と依存する代入を扱う。局所範囲規則のPipeLeftのTop化を値の部分型の規則へ流用しない |
| return・枝の合流 | `typeck/generate.rs:1388–1393`はmatch各腕からfresh結果へFlow、`:1413–1424`はreturnから宣言結果へFlow | 各枝を満たす上界を証明する。期待がある枝へ期待を渡す。最小上界が見つからない比較不能な候補と、そもそも入力制約がない場合を区別する。Φ内の枝ローカルを外へ自由に残さない |
| 定数 | `typeck/consts.rs:29–86`。定数の宣言型と値は現状Equal、純粋な効果で検査した後に評価対象へ入れる | 定数の評価値から篩の所属を示す。宣言だけで篩を真と仮定しない。実行できる定数値の集合と数学上の端点の集合を混同しない |
| Scopeの遅延 | `typeck/scoped_calls.rs:141–180`は対象型を一時型変数にし潜在効果も保留。`:375–503`はcheckの成功型を先に決める。`:504–531`で入力型の添字をIOへ具体化 | checkの結果の所属とIOの添字の選択を分ける。U1では通常の型制約・合流による入力型Rを、当該IOへ渡すための拡大の前に保存する。周囲の許容効果や返却型から狭いRを逆算しない |
| 未解決Flowの確定 | `typeck/solve.rs:1578–1588`はhandler節の生成前、`:1611–1621`は最終の停滞時に、残ったFlowを`equal(to, from)`で確定する。`:1816–1817`は通常のFlowが未解決ならdeferredへ戻す | F3と篩の導入後もここで等号へ強制すると、正しい部分型を等号で拒否したり、期待と実際を共有して拡大前のRを失ったりする。handler前の依存する契約の確定と、最後の注釈要求・上界選択を新しい規則として定める。最後にequalへ戻すだけの実装は不可 |
| 狭い引数・戻り値 | `typeck/scoped_calls.rs:255–266`は由来不明の射影・拡大にTopを要求。`:390–402`は先にTop要求を解き、狭い注釈は後のunknownSourceで拒否 | 構築・引渡しを検査済みの`PathIn[R]`/`RequestIn[R]`から所属を導く規則へ替える。Topから狭いRへのFlowは拒否する。注釈の検査と、検査済み契約を本体で仮定することを分ける |
| 節引数の型 | `typeck/effects/handle.rs:234–253`は選んだ操作の範囲で署名を具体化、`:309–347`で剛な型変数を代入、`:376–385`で各節引数をlocalsへ登録 | その具体化した型から所属を与える。節名や保護本体全体の許容効果から任意の狭い添字を与えない。操作の実引数から節の型へ渡せることをコア保存と結ぶ |
| 局所範囲の記録 | `typeck/scope/lower.rs:266–299`は文とbind位置をRecord、`:398–425`は節を別の本体にし、try/pipe/list/補間等の内側を辿らない。`typeck/scope/local.rs:589–599`と`:641–643`は入口・節の引数のfactをNoneにする | TODO-308の位置制限の根拠である。型の契約へ移した射影の認定を、この旧記録の存在に依存させない。既存の動的パターン解析を残すなら、その精度上のTopと値の既知の型を同一視しない |
| 旧局所受理 | `typeck/scope/accept.rs:137–143`はPipeLeftをTop、`:165–177`は全状態で同一の範囲だけ非Top、`:181–195`はTop以外のunknownSourceを拒否 | 型の所属による新規則へ置換する範囲を明記する。探索上限超過を契約のTop化へ変換して受理しない。旧ScopeAcceptの接続定理だけでは新しい型契約からの射影を証明できない |
| コアの独立検査 | `ir/check.rs:201–209`は最外Fn効果だけを広げる。`:241–269`は構造等号・部分型・効果被覆・構造包含を分ける | 篩、F3、変性、値代入とΦをコア型へ接続する。表層だけが受理してコアで失敗する変更を完了としない。保護本体の構造包含をCoverへ一括変更しない |

## 3.2 の構築経路の全行照合

点検する不変条件は、PathIn[R]なら同じ保持パスpが有効な対象でRへ属すること、RequestIn[R]なら同じ要求全体qと解析済みendpoint eを保持し、qの送信対象とeが一致しeがRへ属することである。Topの値にも有効な保持対象を求める。射影・部分型・格納・再開は保持値を差し替えない。

| 3.2の行 | 読んだ根拠・分岐 | 確認できたこと | 破れる経路／追加条件／未確認 |
|---|---|---|---|
| checkPathInのOk | `builtins/funcs/scope.rs:68–119`、`:122–132`。`builtins/checked_scope.rs:105–126` | 文字列形式、動的patternの所属、静的rangeの所属の後だけOk。成功は入力の同じStringを一欄に保存。異常な値の形はInternal、通常の不適合はResult.Error | 全ヒープ確保とGCの一般証明は未実施。TopもPath::parseを通るので、対象なしのTop定数と同じ意味にはしない |
| checkRequestInのOk | `builtins/funcs/http_client/checked_request.rs:26–91`、`:94–116`、`:205–295`、`:298–308` | ASCII/percent/絶対http(s)/userinfo/port/hostを検査。hostを正規化し、動的host/portと静的rangeを照合後、`[request, normalizedHost, port]`を保持 | この純粋checkはHostヘッダと要求の他欄の送信適格性までは認定しない。実送信前に別途検査する。DNSの実体やTLSの副次通信まで所属へ含めない |
| widen・射影・再包装 | `builtins/funcs/scope.rs:136–165`、`builtins/funcs/http_client/checked_request.rs:134–170`、`:312–334`。送信は`builtins/funcs/http_client.rs:40–63`、`:115–123`、`:153–167`、`:314–334` | widenはdestination.covers(source)を検査して同じValueを返す。Path射影は欄0、Request射影とsendInは同じ要求欄0。sendInはURIと保持endpointの一致、Host一致、resolver側一致、proxyなし・redirect0を設定 | 射影/widen自体は保持対象がsourceへ属することを再検査しない。生Rustから偽の一欄/三欄RECORDと偽のsourceを渡すと、形が合う限りこの前提を破れる。言語ソースの反例ではなく信頼境界の反例候補。暗黙の部分型も値を再包装しない条件が要る |
| 利用者の構築・定数・関数・ADT | `types/builtin.rs:285–295`は標準型をarity0のOpaqueにする。`typeck/solve.rs:748–776`と`:896–920`、`typeck/generate.rs:1413–1424`、`typeck/consts.rs:29–86` | 型の等号で注釈・引渡し・宣言結果を検査する。標準対象型は利用者recordの構成子ではない | 全モジュールの不透明性の機械証明、全定数形の列挙は未実施。U1では全入口のFlowとADTの変性を保存の証明へ接続する。opaque一般の所有モジュールの構築権と、標準対象型に構成子がないことを区別する |
| JSON parse・Codec decode・derive decode | `builtins/funcs/json.rs:27–79`、`:323–380`はJson.Valueタグへ変換。`prelude/stdlib/Json/Codec.bnt:54–59`は通常の型付きdecode/decodeMissing呼出し。`tools/derive/derive.py:657–673`、`:904–918`、`:950–967`、`:723–725` | parseは対象型を作らない。opaque対象のJSON生成を拒否。未対応のopaque欄は明示のcustom変換が必要。customの純粋・単相・型署名を照合し、生成本体も通常の型検査を受ける | record全体の篩と欄間条件は、欄ごとのdecodeだけでは示せない。最終recordを一度構築して全体条件をcheckするか、検査済みcustom結果を使う生成規則が必要。Propertyのgen/shrinkにも同じ全体条件が必要。新しい生成物は未実行 |
| 利用者・模擬handlerの節へ渡す値 | `typeck/effects/handle.rs:234–253,376–385`、`vm/dispatch/handlers.rs:619–642`。既存の本番入力は`tests/scoped_calls/file_io.rs:225–269`、`tests/scoped_calls/http_io.rs:202–238` | ソースhandlerは具体化した型の内側。VMは捕えた操作引数を同じ値のまま節のslotへコピー。節で再度所属を検査しない。既存テストは狭い節射影をunknownSource、Top節射影を受理とする | 新規則は操作引数→節引数の型保存に依存する。手組みRust handler表は次節の信頼する内部構築。節名だけで所属を導く規則は拒否 |
| 外部関数の引数・結果 | `external/types.rs:47–99`は全展開ノードでvalidate、`:125–148`はscalarの有限表、`:170–194`は非Top添字と未対応builtinを拒否。`:251–279`でrecord/variantを再帰構成。`external/convert.rs:532–588,684–696` | 外部handleはExternalHandleで、PathIn/RequestInではない。標準対象型を内包するrecord/List/Option/Resultも、子で未対応となり直接の受信構築はできない | 篩ABIを追加するなら、全入れ子の結果とrecord全体の条件を受信後に検査する。型を剥がしてWITへ渡した後に、受信値へ篩を無条件に戻すのは不健全。今回そのABIを実装・実行していない |
| ストア・Reference・Lazy・閉包・継続・GC | `builtins/funcs/reference.rs:8–38`、`prelude/stdlib/Reference.bnt:5–17`、`vm/dispatch/cell.rs:129–160,208–215`、`vm/unwind.rs:227–252`、`vm/dispatch/lazy.rs:57–63,213–230`、`vm/dispatch.rs:1194–1205`、`vm/handler.rs:24–46,71–75`、`runtime/heap/core/mark_sweep.rs:109–132` | Referenceは同じ保存値を返し、set/updateは返った値を保存。updateは版変更時に再試行。Lazy成功は同じ値をslotへ保存しforceで読む。閉包・継続・handler・GCは各欄の値を辿る | 実行時Valueは篩の証拠を持たず、Referenceの不変性・格納時とcallback結果の検査が必要。セル共変を認める反例は次節。GCが型の所属を示すわけではない。全タスク/資源解放/取消/継続の遷移の保存は未証明 |
| builtin delta・参照インタプリタ | `builtins/table.rs:804–835,893–928`、`refinterp/convert.rs:207–288,393–431,612–626` | 範囲位置は下表の13項目。参照インタプリタは実物のscoped builtinを呼び、Ctorの全欄を双方向変換する。Resource/opaque根は別に扱う | Ctor変換は型による認定器ではない。偽のCtorをRustで直接与えれば所属の前提はない。VM内の同一オブジェクトと、参照インタプリタでの構造の保持を混同しない。全deltaの篩付き署名の健全性は未証明 |
| Leanの抽象定数とdelta | P1 `main-theorems.md`の`CoreAssumptions`四欄と標準対象の葉の報告を入力に使う | P1は対象なしの裸opaqueを標準対象値から除く必要を示す。Rust成功値には実対象があるという上の分岐と整合する | 本担当はLeanを実行・証明していない。`Const.opaque`の全種類とRust出力の対応はLean担当の報告へ結ぶ。`delta_typed`等の前提追加・結論弱化を本担当は決めない |

## 範囲位置のある builtin 全項目

`builtins/table.rs:804–835`の列挙は、File6・Http IO1・Scope3・Http純粋3の計13項目である。このうち標準対象値を新しく作る成功入口はcheckPathIn/checkRequestInの2項目。widen2は同じ値、射影2は既存欄、IO7は消費側である。その他のbuiltinはこの表では範囲位置なしとなる（`:835`）。

| 項目 | 範囲位置・関係 | 実装の根拠と本番への条件 |
|---|---|---|
| File.readTextIn / readBytesIn | PathInの引数0、効果へ同じ範囲 | `builtins/table.rs:804–806,815–816,898–902`。消費するパスの射影を保つ |
| File.writeTextIn / appendTextIn | 同上 | `builtins/table.rs:807–808,815–816`。値の部分型の後に周囲の効果から狭めない |
| File.writeBytesIn / appendBytesIn | 同上 | `builtins/table.rs:809–810,815–816`。同上 |
| Http.sendIn | RequestInの引数0、効果へ同じ範囲 | `builtins/table.rs:818–819,903–906`と`builtins/funcs/http_client.rs:40–63`。保持要求とendpointを使う |
| Scope.checkPathIn | Resultの戻り型引数0 | `builtins/table.rs:821`と`builtins/funcs/scope.rs:68–119`。Okで所属を確立 |
| Scope.pathInValue | 引数0 | `builtins/table.rs:822`と`builtins/funcs/scope.rs:155–165`。型契約から所属を使う |
| Scope.widenPathIn | 引数0・戻り、destinationがsourceを被覆 | `builtins/table.rs:823–826,922–924`と`builtins/funcs/scope.rs:139–149` |
| Http.checkRequestIn | Resultの戻り型引数0 | `builtins/table.rs:827–829`と`builtins/funcs/http_client/checked_request.rs:205–295` |
| Http.requestInValue | 引数0 | `builtins/table.rs:830`と`builtins/funcs/http_client/checked_request.rs:134–146` |
| Http.widenRequestIn | 引数0・戻り、destinationがsourceを被覆 | `builtins/table.rs:831–834,922–924`と`builtins/funcs/http_client/checked_request.rs:323–334` |

Fileの消費側の実装も6項目を読んだ。`builtins/funcs/file.rs:1320–1328`の`retained_path`は一欄RECORDから同じStringを読み、readTextIn/readBytesIn（`:1334–1344`）、writeTextIn/appendTextIn（`:1350–1360`）、writeBytesIn/appendBytesIn（`:1366–1376`）はいずれもそれを既存の実処理へ渡す。IOの時点で静的な所属を再検査する実装ではないため、U1の保存された型の不変条件が必要になる。

型制約の前後関係は、本番では次のように置き換える必要がある。これは本番コードの変更ではなく、読み取りから得た要件である。

| 現在 | 本番で満たす関係 |
|---|---|
| `Flow(from,to)`を保留し、停滞時に`Equal(to,from)`へ戻す | 通常の型構造を解いた後も部分型の向きを保ち、必要なら上下の制約を集める。解けない入力の比較不能性は注釈要求、含意探索の上限はunknownとする |
| checkの成功型と使用先を等号で共有し、最後にIOの入力型から添字を読む | checkの導入時の所属を示し、IOへ渡す元の式の型・合流を確定した時点のRを保存する。その後の`PathIn[R] <: PathIn[S]`でRを書き換えない |

単純な正しいケースは、PathIn["/data/a"]をFile.Read["/data/**"]の本体でreadTextInへ渡す場合である。IOの添字は`/data/a`、周囲へ照合する効果の上限は`/data/**`になる。明示してPathIn["/data/**"]へ保存した値を渡す場合だけ、当該IOの入力契約も`/data/**`となる。入力の型を狭くする証拠を周囲の許容効果から作らない。

## 内部の値・テスト表と信頼境界

| 内部入口 | 根拠 | 扱い |
|---|---|---|
| Rustからraw builtinへ直接渡す | `builtins/table.rs:20–64`は宣言のrawを呼ぶ。`tests/runtime_builtins.rs:1911–1978,1986–2023`は実際のcheckを通した値をwidenしsame_objectを検査 | 任意のraw入力の所属を主張しない。既存の同一性テストはcheck経由なので健全性の前提に沿う。否定fixtureは不良入力であることを明示する |
| 手組みhandler表 | `vm/dispatch/handlers/tests.rs:26–50`は任意名・arityのOpInfoとClauseDescを構築。`bytecode/program.rs:135–145,266–273`は節と操作に値型を持たない | source checkerを通らない表は信頼する内部構築である。現在読んだVM handler fixtureはTest操作で、狭い標準対象型の値の不変条件を証明するテストではない |
| bytecode verify | `bytecode/verify.rs:1–2,23–33,207–225`。範囲署名のadmissionと節の操作番号を確認 | 値の種類と所属は保証しない。verify成功をPathInの不変条件の根拠へ使わない。生bytecodeの一般の安全性を本改造で新たに保証する提案ではない |
| ソースの模擬handler | `tests/scoped_calls/file_io.rs:225–269`、`tests/scoped_calls/http_io.rs:202–238` | 本番checkerを通るため、新規則の対象。狭い節引数がbindで直るという案は既存の拒否期待と違う |
| 参照インタプリタのtest override | `refinterp/convert.rs:188–204`はcfg(test)で宣言を差し替える | overrideが新しい狭い結果署名を名乗るなら、応答の所属はfixtureの責任。元のdeltaの証明を差し替え先へ無条件に引き継がない |

上表は、検索した標準対象名・範囲位置・handler/参照変換の入口を分類したものである。全Rustの`Value`構築を型別に証明した一覧ではない。標準名を含まない任意のRECORD構築からも、形だけ同じ偽の値は作れるので、単純な名前検索の0件を不在証明にしない。

## TODO-308の反例と追加条件

docs/todo の TODO-308の訂正は、由来不明の値へ狭い注釈を信用して与える案と、呼出し側で引渡しを検査した狭い関数契約とを分けている。本番では次の条件を受け入れ条件へ置く。

| 反例・失敗する案 | なぜ破れるか | 必要な条件・本番で確かめる入力 |
|---|---|---|
| Top値へ`PathIn["/data/**"]`と注釈し、その注釈自体を所属の証拠にする | 元の保持対象は`/outside`でもよい。期待を仮定して同じ期待を証明している | Top→狭い範囲は独立のcheck/証明がなければ拒否。狭い関数の呼出し引数・戻り値も同じ方向で検査する |
| `Scope.pathInValue`を狭い関数引数から使うことまで拒否する | 呼出し側でR所属を確かめ、保存で保つなら、本体はR所属を仮定できる。A5の反例とは前提が違う | 引数・結果・節の型の不変条件と表層/コアの接続。既存`tests/scoped_calls.rs:191–194`、file/httpの節の拒否期待を新規則へ更新する |
| Reference[T]を共変にする | Reference[狭い値]をReference[広い値]へ渡し、広い値を書いた後、元の別名から狭い値として読む | Referenceの内側は構造等号。set/updateの結果を同じTとして検査する。実行時は`builtins/funcs/reference.rs:27–29`と`vm/unwind.rs:251`で値をそのまま保存するため、静的な不変性が要る |
| RequestInから射影したClientRequestのURLを更新し、元のRequestInへ戻す | endpointと要求の一致が失われる | 元のRequestInは不変。更新後の要求はcheckRequestInを通して新しい値を作る。`builtins/funcs/http_client/checked_request.rs:282–289`の保持とsendInの一致検査を残す |
| IOの許容効果が狭いから、入力のTopを狭いRとして認定する | 対象が広い入力へ狭い効果だけ付く | 入力の拡大前の型からRを先に確定し、その効果を周囲へ照合する。制約なしのTopと、比較不能で注釈が要る場合を別診断にする |
| raw Value/手組み表の形を標準対象型の証拠とする | 一欄RECORDとStringだけなら任意のパスで作れる。射影はrangeへ所属を再検査しない | 型を通したsource/コア/署名を信頼範囲とし、raw fixtureは契約を満たす値を用意する。不良rawがsourceで構築できるという結論へ進まない |
| callbackの注釈を期待する狭い入力へ読み替える | 広い入力を受けると宣言した本体が、その全入力で結果契約を守ることを検査しなくなる | 注釈ラムダは自身の型で本体を検査し、その後に全体を反変/共変で照合する |

新規則では、通常の値の注釈が所属を新規導入するわけではない。一方、実行時checkの結果を要求する狭い添字へ具体化する設計は、成功枝でその静的範囲も検査するdeltaを使うため、単なる注釈信用とは異なる。動的patternに対してどの範囲を選ぶかは、U1のcheck導入規則と通常の期待型に従って明記する。旧unknownSourceの判定を機械的に残すだけではこの区別が消える。

## P1・P2・RV-P2との接続と未確認

P1の小モデルは本番の進行・保存を示したものではない（P1 `main-theorems.md`）。本調査のストア・節引数・raw構築の条件を、新しい外部の仮定として主定理へ足すのでなく、言語の型付けと保存から導く必要がある。delta/ioの正常な応答の契約と、実行時errorの許容を分ける。

P2のRustの`operations`は全仕事量を数えない（RV-P2 M1）。本番のステップ数は探索の走査・複製・正規化・係数の計算・証明書処理まで版付きの単位で数え、上限超過をunknownとして拒否する。P2の564や85,628をそのまま本番の100,000へ比較して、余裕を確定したとはしない。標準の各幅の上下限、長さの非負性、経路条件、関係のない不等号（Benitoiteでは`<>`）によるOrを加えた入力で測り直す。

P2の純化した整数モデルは、ソースの値で実現できるとは限らない（RV-P2 M6/L4）。負の長さはその例である。診断は証明不成立・検証済みソース反例・実現性未確認の候補モデル・unknownを区別する。Phiのmeasureは可視な不変の欄の連鎖と保存した値を参照し、Referenceの現在値・ファイルの存在・DNSを同じ不変のmeasureにしない。

未実施は、新構文の解析/実行、全本番deltaの篩付き契約証明、全Rust fixtureの型付き所属の照合、全標準measureと機械値の意味保存、全ストア/継続/GCの状態保存、CLI/package/関数別上限の実行確認である。P3の代表例の読解を、これらを閉じた結果へ拡大しない。

## 本番の見込みへの影響（暫定）

第10.1節の「Scopeの統合・TODO-308・F3」の棚卸しはLean32〜80・処理系24〜64時間である。上端へ係数を掛ける算式では処理系は9.6〜22.4時間だが、F3の再帰、named引数の値代入、遅延した期待型、コア検査の変更を含む。現在の遅延処理と値の保持を再利用できることは分かったが、本番の型とsolverを実装してはいない。この時点で同じ行を下げる実測の根拠はない。

「derive/Codec/Property・診断・文書の追加接続」の処理系上端120時間も、record全体の篩・外部ABIの入れ子・生成後の通常型検査を含むため維持する。P2の線形整数行の中心112→70の削減は、RV-P2 M1〜M6と本調査の期待型・機械値・measure接続が残る間は確定しない。P3の読解所要から本番の実装全体へ一律の倍率を掛けない。

上の本番の時間は全て見込み（実測ではない）である。

## 作業の終了と自己点検

2026-10-30 06:57 UTCに本担当の調査を終了した。割当開始06:35 UTCから約22分、最初の時計06:37:47 UTCから約19分である。開始を秒単位で測っていないため、精密な能動時間の測定とはしない。処理系調査3時間の上限内であり、Lean担当の時間はこの値に含めない。1時間に到達していないためprogress.mdは作らず、書込先2文書の制限を守った。

型推論・U1の構築経路・builtin範囲表・Fileの6消費分岐・Httpの保持/送信・外部型対応・JSON/Codec/derive・ストア/継続/GC・手組みhandler表を読み、現行の主張へ根拠行を付けた。runtime-casesは具体のコードと変種・既存テストの期待をIDに結び、新構文と全入力の未実行を明記した。行参照の簡易点検では、ファイル名を省略した箇所をディレクトリ付きへ直し、直接書いた95箇所が存在するファイルと範囲内の開始行を指すことを確認した。この検査は参照の形式の点検であり、コードの正しさを検査するテストではない。

自己点検では、P2/RVが説明用に使った`!=`をBenitoiteソースへ写すと別の字句エラーになることを`crates/benitoite/src/syntax/lexer.rs:671`で確認し、入力を既存の`<>`へ直した。また、部分適用の固定引数は生成ラムダの呼出しごとに評価することを`ir/desugar/exprs.rs:450–469,486–488`と01-02の431行で確認し、N7の期待を出力2回へ固定した。

実行したのは読み取り・検索・時計取得・2文書への保存と参照形式の点検だけである。Rust/Leanのビルド、既存/新規テスト、LLMの構文測定、外部IO、git操作は0件。本番のソースとテストの行数の増減はともに0である。capacity通知後の保存・継続では新しい拒否は起きなかった。未確認分は前節とruntime-cases末尾に残し、型の不変条件を全経路で証明済みとは扱わない。
