# 全入口と局所費用の照合

基準は B_WORK `ea42f4f97fe34e1f4768404f5b44aac3ff371155` である。Lean は読み取りだけで照合した。`private/` とその下を指すリンク、`docs/todo/` は読んでいない。

## 13入口の数え方と署名

`formal/Benitoite/Release/TargetTable.lean` の `entries` と Rust の `builtins/table.rs` の `builtin_range_positions`・`builtin_range_signature` を突き合わせた。対象は検査2、射影2、明示拡大2、IO7の13入口である。旧 `Scope.checkHost`・`checkPath`・`checkEndpoint` はこの13項目に含まない。依頼の「四つの検査」は実表の検査2・射影2と区別する。

以下の R は `rvar 0`、S は `rvar 1`、Path は `Scope.PathIn`、Req は `Http.RequestIn` を表す。`ClientRequest` は method・url・headers・body・timeoutMilliseconds の五欄のレコードである。表の型は標準宣言へ登録表の変数を入れた後の署名であり、利用者の範囲変数の構文を意味しない。

| 入口 | 引数 → 戻り値 | 範囲の種類の列 | 効果・形 | 許容・実装 |
|---|---|---|---|---|
| Scope.checkPathIn | String pattern, String path → Result[Path[R], ScopeError] | [path] | 純粋・untargeted | 一範囲。`funcs/scope.rs:125` と `path_in_result` が動的所属と静的範囲の所属を検査し、同じ String を一欄へ保存する |
| Http.checkRequestIn | String hostPattern, Integer minimumPort, Integer maximumPort, ClientRequest request → Result[Req[R], RequestCheckError] | [endpoint] | 純粋・untargeted | 一範囲。`funcs/http_client/checked_request.rs:301` と `check` が URI・動的条件・静的範囲を検査し、同じ要求と正規 endpoint を保存する |
| Scope.pathInValue | Path[R] path → String | [path] | 純粋・untargeted | 一範囲。`funcs/scope.rs:156` が保存した同じ String を返す |
| Http.requestInValue | Req[R] request → ClientRequest | [endpoint] | 純粋・untargeted | 一範囲。`checked_request.rs:315` と `request_value` が保存した同じ五欄のレコードを返す |
| Scope.widenPathIn | Path[R] path → Path[S] | [path,path] | 純粋・untargeted | S Covers R。`funcs/scope.rs:139` が種類・被覆を再照合し同じ値を返す |
| Http.widenRequestIn | Req[R] request → Req[S] | [endpoint,endpoint] | 純粋・untargeted | S Covers R。`checked_request.rs:323` が種類・被覆を再照合し同じ値を返す |
| File.readTextIn | Path[R] path → Result[String, IOError] | [path] | File.Read[R]・single path 0 | 一範囲。`funcs/file.rs:1368` が保持 path を `read_text` へ渡す |
| File.readBytesIn | Path[R] path → Result[Bytes, IOError] | [path] | File.Read[R]・single path 0 | 一範囲。`funcs/file.rs:1376` が保持 path を `read_bytes` へ渡す |
| File.writeTextIn | Path[R] path, String text → Result[Unit, IOError] | [path] | File.Write[R]・single path 0 | 一範囲。`funcs/file.rs:1384` が保持 path と text を `write_text` へ渡す |
| File.appendTextIn | Path[R] path, String text → Result[Unit, IOError] | [path] | File.Write[R]・single path 0 | 一範囲。`funcs/file.rs:1392` が保持 path と text を `append_text` へ渡す |
| File.writeBytesIn | Path[R] path, Bytes content → Result[Unit, IOError] | [path] | File.Write[R]・single path 0 | 一範囲。`funcs/file.rs:1400` が保持 path と content を `write_bytes` へ渡す |
| File.appendBytesIn | Path[R] path, Bytes content → Result[Unit, IOError] | [path] | File.Write[R]・single path 0 | 一範囲。`funcs/file.rs:1408` が保持 path と content を `append_bytes` へ渡す |
| Http.sendIn | Req[R] request → Result[Response, NetworkError] | [endpoint] | Http.Connect[R]・single endpoint 0 | 一範囲。`funcs/http_client.rs:40` が `retained_request` の同じ要求と endpoint を `start_send` へ渡す |

13項目の型引数と効果引数は0個である。七IOの戻り値に範囲変数はない。宣言元は `prelude/stdlib/Scope.bnt`、`IO/File.bnt`、`Network/Http.bnt` であり、`parameterize_builtin_signature` が認定済み項目の指定位置だけを書き換える。`RangeSignature::signature_valid` は番号・種類・対象位置・操作の戻り値の制限を検査する。

| 表のデータ | Lean | Rust と交換 |
|---|---|---|
| effKind | File.Read/Write = path、Http.Connect = endpoint、他は none | `types/builtin.rs::BuiltinEffectId::scope_kind` が標準識別番号4/5/12だけを認定する。`tests/desugar_export/scope.rs::table_data` が書き出す |
| valKind | Scope.PathIn = path、Http.RequestIn = endpoint、他は none | `BuiltinTypeId::value_kind` の番号32/33だけを認定する |
| admitsR | 検査・射影・IOは長さ1、拡大は [R,S] かつ S Covers R | `RangeSignature.kinds` の個数と種類、`RangeAdmission::Any` と `Covers { outer: 1, inner: 0 }`。Top の列も個数と種類を照合する。Rust の Any はこの個数・種類の検査と合わせて読む |
| valContent | Http.RequestIn → clientRequestTy、PathIn → none | `tests/desugar_export/builtins.rs:352` 以降が実 ClientRequest の宣言の束縛から型を作り、`scope.rs::table_data` が33の一行だけを書く。保持実装は `checked_request.rs::check`・`request_value`・`retained_request` |

## 対象位置以外の引数と ShapeOk

実表で readTextIn/readBytesIn/sendIn は引数が一つだけである。writeTextIn/appendTextIn の第二引数は String、writeBytesIn/appendBytesIn の第二引数は Bytes である。七IOには対象位置0以外の PathIn/RequestIn、他の範囲付き値型、範囲変数を持つ callback はない。したがって今回の七IOの意味を合わせるために一般の ShapeOk へ条件を追加する必要はない。一般に二つ以上の範囲付き引数を持つ IO が安全かという命題へ、この実表の確認を広げない。

`Surface/ClauseIxRule.lean::clauseIxIn` は、範囲変数を持つ認定組込み操作なら保護本体の同じ効果に対する `clauseRangeIn`、範囲変数0の項目と利用者操作なら Top を選ぶ。Rust は名前解決済み操作の署名から節の対象位置だけを具体化する。七IOの署名は一変数であり、旧入口は変数0なので、この分岐と一致する。`ModelHttp` の旧互換値を扱う `valueRun` を Rust が要求を持たない RequestIn を作る許可とは読まない。

## io_target の三形と信頼の境界

| 形 | Lean の条件 | Rust の対応と実装レビューの条件 |
|---|---|---|
| 対象なし | `ShapeTargets .untargeted` は obs = [] | File.Read/Write・Http.Connect 以外の認定操作。今回の純粋六入口には IO 応答自体がない |
| 旧 Top | `topTargeted k` は報告された全 t の種類が k | 旧 File 操作と Http.send。ファイル操作では複数パス・資源内のパス、旧 send では追従先もありうる。作用した対象をすべて含める義務は実装レビューの条件であり、この Lean の述語が観測列の完全性を証明するものではない |
| 単一対象 | 指定引数の `Val.target?` が t であり obs = [t] | 六 File は保持した path、sendIn は保持した実効 host/port。sendIn は追従0・proxyなし、URI/Host/Resolver の一致を再照合する。観測の単位はDNSとOSの変換前にプログラムが接続する保持endpointであり、DNSの問い合わせとTLSの証明書検証に伴うOSの副次的な通信を含めない（2026-10-29の設計者の決定）。OS の名前解決・symlink・TLS検証・特殊ファイルの全挙動の確認を意味しない |

`Release/Assumptions.lean::PrimSig.shapeAt` は、単一対象の署名でも対象位置の `Val.target?` が none なら旧 Top の形へ落とす。Top の不透明型の定数を許す形式化上の互換性であり、非Topの検査済み実行値の保証や、要求を持たない RequestIn を Rust が生成できるという保証ではない。Rust は公開の検査入口からしか PathIn/RequestIn を作らず、成功時に動的条件と静的範囲への所属を照合する。検査済みの値の整形式性と同じ要求の保証はこの生成・保存・射影・拡大・送信の実装と、その境界テストのレビューに依存する。`V-Checked` 自体は要求を持たない対象値も許すため、valContent の型付けだけから全 RequestIn が元要求を保持するとは導けない。

## 費用測定の作成時の関門

1. 守る契約は、七IOを含む通常ソースでも、同じ局所解析の計上点と採用四上限で純粋APIの範囲を維持できることである。IOの実行性能と隔離は測らない。
2. 七IOの登録により直接呼び出し・checked 引数の読み取りが計上されない、逆に保持を不必要に増やす退行を、同じ解析入口の metrics と候補の範囲喪失件数で検出する。
3. 既存 six 群は七IOを含まず、IOを含む本体の費用と独立した番号イベントの増分を確認できない。既存の測定一件の入力群へ seven-io と seven-io-dense を追加し、新しい測定用テストの入口は増やさない。
4. 本番の差し込み口・公開範囲・フラグは増やさない。標準モジュールの読み込み・名前解決・型検査は本物を使い、IO自体は実行しない。

計上点は `r20.5/results.md`「計上と Lean の対応」と同じである。直接の呼び出しの同定1、局所引数の読み取り1、checked成功値の再照合1、直接射影の適用1、結果の事実書き込み1、Ok腕の結果読み取り1（由来を写せればさらに1）、別名1である。保持は事実を持つ位置ごとに1とする。受理の問い合わせは再計上しない。本体/全体の操作数と保持数の四上限はそれぞれ 16,384/65,536 と 512/2,048 で据え置く。全体は定義ごとに初期化し、測定 JSON の whole_operations_total は複数定義の合計である。

独立した番号付けの上限は定義ごと200,000イベントであり、上の四値や Lean の stepCost に加えず、交換の limits にも載せない。全体保持2,048は通常ソースでは構文の深さ上限1,000が先行するという R20.5b の未到達の限定を保つ。今回の測定から全プログラムの時間・メモリの保証を導かない。

測定コマンドは `python3 <改造のディレクトリ>/r30.5/measure-cost.py <case>` である。内部で `/usr/bin/time -p cargo test -p benitoite --release --lib typeck::scope::tests::measure_scope_budget -- --exact --ignored --nocapture` を実行し、既存の `BENITOITE_SCOPE_MEASURE_CASE` で局所選択する。入力・SHA-256・計上・候補・番号イベントと個別の時間は `cost-inputs/`、外側の終了・時間・getrusageの補助最大常駐量は `cost-*-outer.json` に保存する。

保持と通信の主な既存検査は、`runtime_builtins` の `scope_path_in_checks_static_membership_and_widen_preserves_the_object`・`http_request_in_projection_and_widen_return_the_original_objects`・`file_in_operations_use_the_retained_path_and_preserve_values_and_errors`、`l32_http_client` の `send_in_returns_redirects_without_connecting_to_location`・`send_in_matches_effective_endpoint_and_explicit_host`・`send_in_ignores_proxy_environment` である。これらの再実行は親が担当する W-R に含め、局所測定と重ねて実行しない。

## 七IO後の再照合の結果

正式の局所測定は9入力すべて終了0である。各コマンドは既存の ignored 測定一件を明示的に選び、1件成功・失敗0・無視0であった。`cost-summary.json` に全候補を集計した。入力の SHA-256 は個々の JSON にあり、入力本文も隣へ保存した。

| 入力 | 定義数 / 反復数 | 本体操作最大 / 全体操作の合計 | 本体 / 全体の保持最大 | 定義ごとの番号イベント | 採用候補の範囲喪失 / 拒否 |
|---|---:|---:|---:|---|---:|
| six-1（対照） | 1 / 1 | 35 / 35 | 4 / 4 | 146 | 0 / 0 |
| dense-100（対照） | 1 / 100 | 3,500 / 3,500 | 4 / 4 | 15,003 | 0 / 0 |
| retained-100（対照） | 1 / 100 | 300 / 300 | 100 / 100 | 1,003 | 0 / 0 |
| seven-io-1 | 1 / 1 | 56 / 56 | 4 / 4 | 198 | 0 / 0 |
| seven-io-10 | 10 / 1 | 56 / 560 | 4 / 4 | 各198 | 0 / 0 |
| seven-io-100 | 100 / 1 | 56 / 5,600 | 4 / 4 | 各198 | 0 / 0 |
| seven-io-dense-1 | 1 / 1 | 56 / 56 | 4 / 4 | 205 | 0 / 0 |
| seven-io-dense-10 | 1 / 10 | 560 / 560 | 4 / 4 | 2,023 | 0 / 0 |
| seven-io-dense-100 | 1 / 100 | 5,600 / 5,600 | 4 / 4 | 20,203 | 0 / 0 |

一組の増分は21操作であり、七つの直接IO呼び出しそれぞれの同定1と、checked引数の読み取り・成功値の再照合2に対応する。IOの結果は Scope の所属の事実を生成しないため、保持最大は4のままである。文字列/Bytesの内容引数はリテラルか other として費用0であり、実行時のバイト処理量を数えていない。最初の wildcard bind の試行は35操作・番号198で終了0だったが、費用を伴う Bind の入口を通らないため、正式入力では結果へ名前を付けた。試行は `cost-seven-io-1-wildcard-trial.log` と同名の外側 JSON、`cost-inputs/seven-io-1-wildcard-trial.*` に残した。失敗を隠す修正ではなく、測る契約に合わせた入力の修正である。

同じ定義に100組置いた入力の5,600操作は、本体上限16,384の約34.18%であり、約2.93倍の余裕がある。保持最大100の対照も本体保持512以下である。小候補は seven-io-dense-100 で391件、中候補は254件の範囲を失い、採用候補は0件だった。すべての正式入力で採用候補の局所停止と独立した番号付けの停止はない。全体四値のうち本番2,048の保持上限への新たな到達確認をしたとはしない。既存の到達条件と構文の深さ上限の限定を保ったまま、採用四値と番号200,000を据え置く判断と整合する。

正式 seven-io-1 はビルド込み60.240847秒、補助最大常駐量4,921,753,600 bytes = 4,693.75 MiBだった。ビルド済みの残り8入力の外側は0.118278〜0.196577秒、補助最大常駐量は最大94,109,696 bytes = 89.75 MiBだった。最大常駐量は新しい Python プロセスごとの `getrusage(RUSAGE_CHILDREN)` であり、コンパイルの子を含む最初の値と入力だけの後続の値を混同しない。sandboxが `ps` を許さないため入力内の瞬間RSSは null であり、実使用0とはしない。

seven-io-dense-100 の型検査は0.088535秒、番号付け・局所解析・候補比較を合わせた測定区間は0.007762秒だった。これらは本測定の入力の値であり、shortの退行原因を示すプロファイルではない。File宣言追加・Scope import・全モジュールの Inputs::collect・signature_at_call の各寄与を分離していない。TODO-304の費用を受け入れる判断と、ハンドラのほぼ二乗の費用をTODO-307へ残す判断は引き継ぎ、原因を新たに断定しない。shortはこの担当で実行していない。

## 差分・停止条件・片付け

本番の実装と表・依存・Leanの変更はない。変更したRustは既存測定の `src/typeck/scope/measure.rs` の入力群38行追加だけである。既存テストの削除と独立したテスト関数の追加は0件であり、新群はgc-stressでも既存と同じ1/2/3の縮小を使う。rustfmtの局所確認は終了0だった。全件W-Rは親が一度実行する。保持表現・安全点・根・障壁を変更しないため、この差分により古くなる H/H-full の証拠はない。

ShapeOkの一般の条件、Leanの規則・主定理・Assumptions、保証・公開契約の変更を必要とする相違は見つからなかった。新しい CARGO_TARGET_DIR と target 外の一時ビルド/基準展開は作っていない。測定の保存入力は恒久の証拠であり一時出力ではない。


## R30.5b: handlers の400反復の補足（RV-R30 軽2）

R30.2 で READ_CLAUSES に readTextIn/readBytesIn を加えた後の4入力について、[RV-R30](../reviews/RV-R30.md) のレビューアが B_WORK の release の `measure_scope_budget` を各一回実行した出力を照合した。ビルドの外側は約82秒で、[ビルドのログ](../r30/rv-probes/build.log)と各生ログは変更していない。[出典ハッシュ付き集計](r30.5b-reviewer-handler-cost.json)を本枝の 9入力の群と分けて保存した。

| 入力と出典 | 型検査秒（R20.5 の参考秒） | 出現数 | 一定義の番号イベント | 再推論 | 採用候補の範囲喪失／拒否 |
|---|---:|---:|---:|---:|---:|
| [handlers-later-400](../r30/rv-probes/handlers-later-400.log) | 1.446863（1.379） | 5,201 | 14,803 | 0 | 0 / 0 |
| [handlers-reinfer-400](../r30/rv-probes/handlers-reinfer-400.log) | 2.431907（2.405） | 10,001 | 34,003 | 1 | 0 / 0 |
| [handlers-chain-400](../r30/rv-probes/handlers-chain-400.log) | 1.703324（1.682） | 7,607 | 27,219 | 2 | 0 / 0 |
| [handlers-sequential-400](../r30/rv-probes/handlers-sequential-400.log) | 0.132973（0.123） | 2,001 | 6,003 | 0 | 0 / 0 |

4入力とも終了0で各1件成功した。局所の本体／全体の操作・保持の四値はいずれも0、局所の停止・番号付けの停止はない。これは入力が局所の範囲規則を持たないためであり、型検査やハンドラの再推論の費用が0である意味ではない。reinfer の出現数は9,201から10,001、chain は6,807から7,607へ増えている。番号イベントは最大34,003で、局所四値と独立した200,000の上限を下回る。採用候補の範囲喪失・拒否の後退は見当たらない。

静かな計算機での測り直しは行っていない。再ビルドを要する場合は既存の60〜82秒と4入力の実行を合わせ約1.5〜2分、ビルド済みなら十数秒と見積もった。ただし本セッションでは他のビルドや検査がない条件を確認できず、同条件の精密な時間比較を増やせないため、レビューアの出力で計上・上限との対応を確認する範囲とした。元測定も静かな計算機という条件を揃えておらず、R20.5 の参考値との小差から速度の改善・退行や原因を断定しない。short、プロファイル、IOの実行時間を測った結果ではない。TODO-304/307 の判断と採用上限は据え置く。
