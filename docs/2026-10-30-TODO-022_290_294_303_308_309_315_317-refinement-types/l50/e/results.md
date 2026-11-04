# L50 群 E の結果

担当の実装と自己点検の記録である。独立レビューと受け入れは取りまとめ・設計者が行う。

- 指定ブランチ: `m014/l50.e`。git の操作は行わない。
- B_WORK: `7ece2393f5585203556d07d4851b6b946abb0e92`。
- 範囲: L50.21〜.25。
- 最大常駐量: 未取得（計画上の非採取）。

## 単位の時刻

日本時間。外側の時間と待ちは厳密には分離せず、能動時間へ換算しない。

| 単位 | 開始 | 終了 | 判定 |
|---|---|---|---|
| L50.21 | 2026-11-04T20:44:09+09:00 | 2026-11-04T20:46:35+09:00 | 局所検査成功。16行を定義 |
| L50.22 | 2026-11-04T20:46:35+09:00 | 2026-11-04T20:49:19+09:00 | 局所検査成功。同じ有限Pの形成と全16行 |
| L50.23 | 2026-11-04T20:49:19+09:00 | 2026-11-04T20:53:15+09:00 | 局所検査成功。全IO・効果登録・発行八欄と三形 |
| L50.24 | 2026-11-04T20:53:15+09:00 | 2026-11-04T20:59:31+09:00 | 局所検査成功。全 BuiltinArgs の δ 契約 |
| L50.25 | 2026-11-04T20:59:31+09:00 | 2026-11-04T21:22:22+09:00 | 担当分完了。全 BuiltinArgs と同じ δ、群末の検査・監査・照合成功 |

## 完了条件の照合

L50.21〜.25 の担当分は完了した。群末の検査の結果は後段に示す。全場合・全入力は [coverage.md](coverage.md)、原署名・実名・効果・対象位置・valKind/valContent の16行は [signatures.md](signatures.md) に示す。具体例から全体の閉鎖を推測していない。

| 単位 | 全称の証拠と判定 |
|---|---|
| L50.21 | ScopeSignatures.entries の全16行と TargetTable.valKind。13 API を実名の PrimSig とし、ref2・発行1を同じ lookup へ入れた。拡大は戻り側の被覆を検査する |
| L50.22 | 同じ ScopeDeclarations.program から program_hasHttp/program_wellFormed を証明。全構成子の arity・欄の形成を量化する。entries_scoped は全16行、sig_scoped/sourceTelRows は成功した任意の lookup を扱う |
| L50.23 | io_op は全16行から7 IO の ShapeOk を構成し、他の9行を kind で排除する。effect_ops は同じ effects の全登録を量化。発行の八欄と全引数での IO 応答の排除、三形の同じ表での適用例、全範囲の single_inst の読者を置いた |
| L50.24 | ScopeDelta.run_safe は任意 r/ws/Ψ、response は全 BuiltinArgs。makePath と parseAtInput を固定し、正常・形式失敗・動的不所属・静的不所属を同じ Result へ写す。relative/home と解析失敗は同じ理由text.PATHのInvalidTarget（再開1で統一）、based/secrets は内部 staticIndex の Error |
| L50.25 | RequestDelta.run_safe は型付きの全 ws・任意 r/Ψ、response は全 BuiltinArgs。固定 reqTarget と parseHostPattern、makeEndpoint の順、同じ req/endpoint、全失敗 payload の型・Ground・AdequateResult・非 exit を証明。contracts.lean で元の F07 の全称の適用も照合する |

[義務33行・申し送り31行](obligations.md)を一行ずつ判定した。群Eの未完を他群へ付け替えていない。義務全体の閉鎖は0行である。残る純粋4行、7 IO、三モデル75条件、外部応答、全到達の主定理を今回の完了へ繰り上げない。

## 同じ宣言と二つのチェック

同じ P は ScopeDeclarations.program である。Result/Pair の arity は2、ScopeError/ClientRequest/RequestCheckError は0。全13構成子を lookup し、Pair の構成子名は Pair.Pair である。P.WellFormed は全構成子の欄に SourceScoped・Annotation・kind を供給する。全16署名の kinds/declared/sourceTelRows はこの P で同時に成立する。任意 P への入口は HasHttp の有限 lookup・全 arity を明示する。

パスの成功は同じ checked target、要求の成功は同じ checkedRequest target req を返す。二つの δ は同じ Result.Ok/Error の型引数0/1を使う。静的拒否の内部 At は、パスでは元 pattern/target と解析済みのパス、要求では元 host/lo/hi と同じ req、解析済みの条件・端点、解決結果を保存する。公開形の選択は行っていない。

処理系との内部の三分岐の対応は次のとおりである。表の「任意」は、δ の全域性のための引数と、通常のソースから作れる BuiltinArgs を区別する。

| 分岐 | 処理系と Lean の対応・到達性 |
|---|---|
| 静的な不所属 | 処理系は OutsideScope、Lean は内部 At staticIndex。通常のソースでは検査器が結果の範囲を既知の条件又は Top にするので到達しない。Lean の run は任意の r を許し、動的条件が成功しても不適合な静的上限を渡せば到達する |
| 引数の形の不一致 | 処理系は Stop::Internal、Lean は型付き Error（パスの内部説明は invalid arguments、要求は固定の InvalidUrl）。通常の型付きソースから到達しない。Lean の run は任意の r と値列に定義され、不正な値列で到達するが、型付き BuiltinArgs ではこの形の不一致は排除される |
| groundVal = false | 処理系で不正な要求値の入力に対応するのは Stop::Internal、Lean は型付き InvalidUrl。通常のソースの閉じた要求値から到達しない。Lean の run は任意の r と未閉鎖の要求値で到達する。この枝は公開エラーの選択を表さない |

効果表は State が空、File.Read が読取り2行、File.Write が書込み・追記4行、Http.Connect が sendIn、Process.Environment が内部の発行1行である。全7 IO の対象位置は0、rkinds と効果の範囲変数は同じ0、引数型は opaque。ret は読取り String/Bytes・書込み追記 Unit・送信 Http.Response であり、Result の Error 側は IOError/NetworkError。対象なし・Top の読者は共通16行の件数と分ける。

## 在庫と後続への受け渡し

群Bの ShapeOk 5目的は群Cで一般の形を閉じており、今回新たに5件を移植したとは数えない。今回の全7実 IO の ShapeOk から各目的を適用でき、single_inst の読者を共通表へ置いた。27目的は26完了・残件1（allows_bind_comp、L50.30）のままである。

| 受け手 | 渡す証拠 |
|---|---|
| 群F | ScopeDelta.response/RequestDelta.response、Result の構築と Scope の六 payload の型付け。RequestDelta.delta はパスの δ も同じ表に接続する。残る射影・拡大4行は未実装 |
| 群G | 全7実 IO の署名・効果登録・io_op・全範囲の single_inst。IO 応答の存在は今回の証明に含めない |
| 群H〜J | 同じ有限 P の HasHttp/WellFormed、全16 Scoped・行支持、効果登録と発行八欄。各モデルの部分表と25条件は既存担当が構成する |
| 群K/L | 任意 Ψ・全 BuiltinArgs の二つの δ の型/Ground/AdequateResult/非 exit、既定 import と今回の全宣言の監査、義務と申し送りの一行表 |

## 追加・変更した宣言

新設は ScopeSignatures・ScopeSignatureFormation・ScopeDelta・RequestDelta の4モジュールであり、すべて既定 import に入れた。既存の変更は TargetTable、ScopeDeclarations、AtInput の3モジュールである。01-12 と 07-04 は実定義と前提を写した。

| 場所 | 主な追加宣言 |
|---|---|
| ScopeSignatures | 16署名、entries/effects/effKind/admitsR/builtins、lookup_mem、io_op、pathBases_shape/pathBases_no_io、effect_ops/opEff_io、unscopedIO/unscopedIO_shape |
| ScopeSignatureFormation | entries_scoped、sig_scoped、sourceTelRows |
| ScopeDelta | Result の同じ宣言の構築と型付け、ScopeError の六 payload、固定 parsePattern、run/delta、run_safe/response、run_absolute/input_errors |
| RequestDelta | 固定 parseHostPattern、RequestCheckError の二構成子の型付け、run/delta、run_safe/response、run_endpoint |
| 既存3モジュール | TargetTable.valKind、ScopeDeclarations.program/program_arity/program_hasHttp/program_wellFormed と private lookup、parseAtInput_host_loopback |

private・生成宣言を含む件数と公理依存は群末の監査に示す。宣言名の接頭辞で対象を絞らない。

## 検査例の作成時の関門

test-audit を適用した。守る契約は、同じ P の全 arity と欄の形成、全実名の対象位置と効果登録、relative/home と形式不正の分岐と同じ失敗値、同じ req/endpoint とポート条件の拒否である。群Cの一行の写しは共通16行の lookup を読んでいないため、今回は同じ表と全称の応答契約に適用した。一般補題の証明を複製せず、その前提を実際の表から供給する。テスト用の差し込み口、Rust のテストファイル、実行時の追加フラグは置いていない。

## 署名の差と計画からのずれ

主な十言明、F01〜F10 の固定型、前段の実署名、型付け規則、新公理、独立の信頼条件、精密な外部状態、提供範囲の変更は0件である。承認済みの NamesWF と F06.current の前提除去を継承する。

| 項目 | 実装と差の扱い |
|---|---|
| 配置 | P の証拠を ScopeDeclarations、署名を ScopeSignatures、形成を ScopeSignatureFormation へ分けた。循環 import を作らない内部の配置である |
| PathBases の内部名 | 群Aの資料は内部の pathBases 発行を指し、文字列名を指定していなかった。既存の OperationStateExamples の内部名 Example.pathBases を用いた。公開名は選択していない |
| ScopeError の型 | 群Aの有限宣言と AtContracts.atErrorType と同じ data Scope.ScopeError [] を使う。旧表の opaqueTop による略記は有限宣言の payload の型に置き換える。detail 第4節の具体化である |
| 発行の IO 応答 | 同じ lookup の kind で IO 関係を io/exit に限り、pathBases_no_io を全引数で証明。応答関係の定義に型付けを含めていない |
| 単位の境界 | 群末の .25 で .23 の発行の IO 排除と読者を最終照合した。局所証明と群末の既定ビルド・監査・work を区別する |
| 時刻の書式 | .23 の開始/終了の間の表の区切りを記録の照合で補った。時刻は当該時点で記録した値である |

U02 に依存する公開形は選択していない。四時間の途中報告と十五時間の上限には達していない。外側の時間を能動時間の係数へ換算せず、後続の旧見込みを一律に縮めない。

## 途中の局所検査

formal/ から固定 Lean の lake env lean -M 12288 を使った。依存する変更モジュールの olean を単独 Lean の -o で更新した箇所がある。成功の最終の根拠は群末の既定ビルド・監査・work とする。

最初の編集入力は作業ディレクトリを取り違え、書込み前に FileNotFoundError となった。局所 Lean では、Eff.singleAt の旧名前空間、有限 lookup の対の型、arity のデータ名の展開、Annotation の構築、Ordinary の引数、型付き応答の Ψ、match/if の分岐、String の短い字句の補助入力を修正した。ホスト条件の区切りは文字列の要素列の splitOn を使う。長い具体列や大きな範囲の評価は行っていない。結果の長い追記の編集入力一回は JavaScript の構文エラーで書込み前に停止したため、apply_patch で追記した。失敗の試行は成功の証拠に数えない。

## 群末の検査・監査・照合

すべて成功した。既定ビルドは全本番入力の最後の変更後に実行した。検査の入口の実行回数は run.py で一回に制限し、途中の局所検査と区別した。work 内の既定ビルドはその入口の選択による実行である。

| 検査 | 中身 | 結果・外側の所要 | 記録 |
|---|---|---|---|
| 既定ビルド | formal/ から固定 Lean の lake build、対象指定なし | 1,277ジョブ成功、385.341秒 | [build-check.json](build-check.json) |
| 群末の公理監査と F07 の実型照合 | lake env lean -M 12288、同じ16行の表・同じ δ に元の F07Pure/F07Ground を全称で適用、全変更モジュールの宣言を固定点まで列挙 | 521宣言、2周、11.379秒。新公理0、private・生成宣言を含む | [audit-summary.json](audit-summary.json)、[contracts.lean](contracts.lean)、[actual-signatures.md](actual-signatures.md) |
| work の選択確認 | scripts/check.sh --level work --base 7ece2393f5585203556d07d4851b6b946abb0e92 --dry-run | 一回、0.124秒。spec_tally・spec_examples・formal_build を選択 | [dry-run-check.json](dry-run-check.json) |
| 作業末の work | scripts/check.sh --level work --base 7ece2393f5585203556d07d4851b6b946abb0e92 | 一回、9.461秒。仕様対応の集計と自己検査、仕様のコード例7件、Lean既定ビルドと sorry の検査が成功 | [work-check.json](work-check.json) |
| 記録の照合 | verify.py。開始時の入力と全入力を比較、全追加・変更モジュールの既定 import、全監査宣言の一覧と依存、実行回数・原出力ハッシュ、33義務・31申し送り・16行、リンク・容量を照合 | 成功 | [verification.json](verification.json) |

新設4モジュールの宣言は284件（RequestDelta 90、ScopeDelta 96、ScopeSignatures 71、ScopeSignatureFormation 27）である。521件には既存3モジュール全体と検査台本の2宣言も含むため、この数を新規宣言数とは数えない。許可した依存は propext・Quot.sound・Classical.choice だけであり、各宣言の実依存は [declarations-part-01.json](declarations-part-01.json) と [declarations-part-02.json](declarations-part-02.json) に一回分を保存した。

対象一覧は [audit.py](audit.py) と [audit-tail.lean](audit-tail.lean) で Lean の環境から再生成する。[modules.json](modules.json) と [new-modules.json](new-modules.json) は対象のモジュール名であり、開始時の一時一覧がなくても監査を再実行できる。実署名は24件である。原出力・監査入力・対象名一覧は `<tmp>` に置き、その大きさと SHA-256 を JSON に残した。原ビルド出力は71,268 bytes、監査原出力は216,030 bytes、work 原出力は5,847 bytesである。宣言の写しは75,667 bytesと27,568 bytesであり、一ファイル100 KB以下を満たす。群の記録全体も数 MB以内である。

## 所要と取りまとめへの確認

| 単位 | 外側の所要 | 含むもの |
|---|---:|---|
| L50.21 | 2分26秒 | 実装・局所検査 |
| L50.22 | 2分44秒 | 実装・局所検査 |
| L50.23 | 3分56秒 | 実装・局所検査 |
| L50.24 | 6分16秒 | 実装・局所検査 |
| L50.25 | 22分51秒 | 実装・局所検査、文書の写し、群末のビルド・監査・work・記録の照合 |
| 合計 | 38分13秒 | 単位の開始後の外側の時間。開始前の資料読解を含めない |

既存の証明と小さい有限表を再利用できたため、単位の開始後の所要は見込みを下回った。独立レビューと受け入れを含めておらず、この実績から後続の工数を一律には外挿しない。

新しい設計判断を求める点はない。PathBases は上記の既存内部名を使い、U02 の公開形は選ばなかった。二つの δ の静的拒否・形式失敗の選択、同じ宣言による ScopeError の data 型の具体化、全称の契約と在庫の境界を、取りまとめの独立レビューへ渡す。レビューの実施と受け入れの判定は未実施であり、担当の自己点検と区別する。

## 再開1

開始: 2026-11-04T21:37:03+09:00。RV-L50.e の中1〜3・軽1〜3を処置する。情報1〜5は変更しない。git の操作は行わない。

初期調査では、射影形の拒否を固定の URL 解析の入口に加え、群 E の局所の証明を追随させる方針とした。開始から約5分の初期調査・局所検査を根拠に、担当分の外側の所要を45〜75分と見積もる。内訳は具体例と局所検査15〜25分、写しと記録5〜10分、既定ビルド・公理監査・work・verify10〜20分、完了条件の照合5分、既に行った読解と試行である。独立レビュー・受け入れの所要は不明であり、取りまとめ・設計者が受け持つ。累計3時間を超える見込みが生じたら止める。

### 処置と根の修正

| 所見 | 処置・証拠 |
|---|---|
| 中1 | ScopeDelta.text に PATH_PATTERN・PATH・ENDPOINT_PATTERN・MAPPED_TARGET を処理系と同じ字句で定義した。パス対象の二枝と input_errors は同じ PATH の値を返し、ホスト条件の失敗は ENDPOINT_PATTERN を返す。01-12・07-04・coverage・O166 の理由の区別も統一した |
| 中2 | RequestDelta.text.INVALID_URL の固定説明を InvalidUrl の欄へ置いた。parseUrlShape は URL の形だけを検査し、角括弧を除いたホストの綴りと実効ポートを返す。δ はこの段を Val.reqTarget より前に固定して使い、形は正しくホストが不正なら Scope(InvalidTarget(host, INVALID_HOST))、OutsideScope の第2欄は同じ元のホストにする |
| 中3 | 根の parseUrlTarget で射影形を拒否した。数値の上位96ビットが 0xffff かを isIPv4MappedHost で判定する。urlHostMapped は同じ IPv6 解析で理由 MAPPED_TARGET を選ぶ。URL を読む要求の reqTarget と At の endpoint 入力も拒否する。IP のパターン・CIDR の値の代数には変更がなく、射影形の /96 のパターンは受理する |
| 軽1 | parsePattern は tree かつ stem = "/" を拒否する。parseHostPattern は prefix の長さ4以上と、長さ2以上かつ "0" 始まりを拒否する。/**・通常の /8 は受理する対照を置いた |
| 軽2 | 「同じ宣言と二つのチェック」に静的不所属・引数形の不一致・groundVal=false の処理系との対応と到達性を一行ずつ加えた。任意 r の内部入力と通常ソースから作る型付き入力を区別した。既定内に静的な不所属、不正な値列、未閉鎖の要求の具体例を置いた |
| 軽3 | 07-04 の篩の対応表の空行を除き、ScopeDelta・RequestDelta の行を PreparationTargets・PathBasesTargets・AtTargets・ScopeLegacyContracts の直後へ移した。01-12 と 07-04 の該当する二重の空行を一つにした |
| 情報1〜5 | 処置なし |

中3は根の修正を採用した。理由は、parseUrlTarget_kind と HTTPS ループバックの既存の言明を局所で追随でき、二つの δ の run_safe/response の全称の契約の形も保てたためである。δ だけで射影形を拒否する代案は使わない。Http.sendIn と At の endpoint 入力に今回の射影形の受理差を残さず、H05 に根の修正を記録した。前群の固定した F03〜F05 の署名、主な十言明、型付け規則、新公理、独立の信頼条件、提供範囲の変更はない。要求の局所の等式 run_endpoint には、前置する URL の形の検査の成功を示す前提を加えた。response の BuiltinArgs の前提は変えていない。規則の字面は変えていないが、`parseUrlTarget` の修正により、V_CheckedRequest と At の保持の前提（`req.reqTarget = some target`）で型付く値の集合は、IPv4 射影形の IPv6 の端点を持つ保持値の分だけ狭まった。これは処理系で作れない値であり、処理系と揃う方向の変更である（RV-L50.e 再レビューの軽R1。取りまとめが追記）。

処理系の関門は crates/benitoite/tests/runtime_builtins.rs の scope_path_in_checks_dynamic_inputs_and_preserves_the_same_ok と http_request_in_checks_endpoints_and_retains_the_same_request を読んで照合した。初期状態での食い違いは RV-L50.e の具体例と検査結果を根拠とし、修正後は本番の既定 import の ScopeDelta・RequestDelta 内の小さい適用例で確かめる。Rust の処理系とそのテストは変更していない。下表は関門の入力と、理由・内部の枝・境界を区別するための補助例である。

| 入力（主な引数） | 処理系の期待と Lean の具体例 |
|---|---|
| pattern=/data/*, target=relative | InvalidPattern(/data/*, PATH_PATTERN)。対象の不正よりパターンの不正が先 |
| pattern=/data/**, target=/data/../else・relative・~/file | いずれも元の対象と PATH を持つ InvalidTarget。relative/home の場合分けは値の区別ではない |
| pattern=//** と /** | 前者は拒否、後者は根の木として受理 |
| pattern=bad..pattern, lo=hi=-1, url=ftp://example.com/ | 固定説明 INVALID_URL の InvalidUrl。ホスト条件・ポート範囲へ進まない |
| url=http://127.1/・https://example.com./ | Scope(InvalidTarget)。第1欄は127.1・example.com.、理由はINVALID_HOST |
| pattern=bad..pattern, url=http://example.com/ | Scope(InvalidPattern(bad..pattern, ENDPOINT_PATTERN)) |
| pattern=other.example, url=https://example.com/ | Scope(OutsideScope(other.example, example.com))。第2欄にURL全体を入れない |
| pattern=127.0.0.1, url=http://[::1]/ | Scope(OutsideScope(127.0.0.1, ::1))。角括弧を除いた綴り |
| pattern=::/0, url=http://[::ffff:127.0.0.1]:18081/・http://[::FfFf:7F00:0001]:18081/ | Scope(InvalidTarget)。元の綴りを保ち、理由はMAPPED_TARGET。reqTargetとAtのendpoint入力もnone |
| url=http://[::ffff:0.0.0.0]:18081/・http://[::ffff:255.255.255.255]:18081/ | 射影形の両端を拒否 |
| url=http://[::fffe:ffff:ffff]/・http://[::1:0:0:0]/ | 射影形の前後の通常IPv6を受理 |
| hostPattern=10.0.0.0/08・10.0.0.0/0008・10.0.0.0/8 | 前置の0・四桁を拒否し、通常の/8を受理 |
| hostPattern=::ffff:0.0.0.0/96 | 射影形のIPパターンは受理。対象の拒否と区別 |

### 局所検査と記録の方針

単独の Lean は formal/ で lake env lean -M 12288 を使った。名前を含む具体例の全計算を cbv で一括展開する試みは、ScopeDelta の一例と RequestDelta の三例で既存の200万 heartbeat の上限に達した。数値を大きな列へ展開せず、文字列の解析結果を小さな等式に分け、既存の全分岐の等式又は具体 δ へ渡して直した。成功した局所の検査と、後述の群末の既定ビルド・公理監査・work・verify は区別する。

記録の run.py は既存の --record-prefix を使い、再開1の build/work を resume1- の別記録として各一度実行する。verify.py に同じ prefix の指定を加え、再開前の最終入力のハッシュを照合して、この再開で本番の変更が AtInput・ScopeDelta・RequestDelta と二つの写しの五ファイルだけであることも確かめる。全変更モジュールの監査を再生成し、宣言の写しは群末の一回分だけを保管する。

### 群末の検査

| 検査 | 実行と中身 | 結果・外側の所要 | 記録 |
|---|---|---|---|
| 既定ビルド | formal/ で対象指定なしの lake build を一度 | 終了0、1,277ジョブ成功、380.455秒 | [resume1-build-check.json](resume1-build-check.json) |
| 公理監査と契約の照合 | lake env lean -M 12288。全変更モジュールの全宣言を固定点まで列挙し、F07 を同じ表・同じ δ へ適用 | 終了0、572宣言、2周、11.695秒、新公理0 | [audit-summary.json](audit-summary.json)、[contracts.lean](contracts.lean)、[actual-signatures.md](actual-signatures.md) |
| 作業末の検査 | scripts/check.sh --level work --base 7ece2393f5585203556d07d4851b6b946abb0e92 を --only なしで一度。仕様対応の集計と自己検査、仕様のコード例7件、既定の Lean ビルドと sorry の検査 | 終了0、4.302秒、全選択検査成功 | [resume1-work-check.json](resume1-work-check.json) |
| 記録の照合 | verify.py --record-prefix resume1-。初回前と再開前の入力ハッシュ、全追加・変更モジュールの既定 import、監査の全一覧・依存・ハッシュ、実行回数、33義務・31申し送り・16署名、リンクと容量 | 終了0、0.138秒、全項目一致 | [verification.json](verification.json) |

監査の572件は変更モジュール全体と台本の2宣言を含む。うち共通表を含む新設4モジュールは300件であり、再開1で新しく足した宣言の件数とは区別する。全宣言の依存は propext・Quot.sound・Classical.choice の範囲内である。対象は [audit.py](audit.py) と [audit-tail.lean](audit-tail.lean) から再生成でき、private・生成宣言も含む。前群の固定署名と型付け規則のファイルは再開前と同じハッシュである。

今回の既定ビルドには、変更していない既存モジュールの警告が147行あった。変更した AtInput・ScopeDelta・RequestDelta に警告はない。警告の抑制や関係しないソースの編集はしていない。Rust の関門の期待はソースと照合し、同じ入力の Lean の具体例を既定ビルドで検査した。Rust の関門テスト自体の追加実行はしていない。

原出力はビルド71,270 bytes、公理監査233,403 bytes、work 5,847 bytesであり、大きさと SHA-256 を各 JSON に保存した。宣言の写しは [declarations-part-01.json](declarations-part-01.json) と [declarations-part-02.json](declarations-part-02.json) の再開1の一回分である。初回の521宣言の記録は前段の実行時の値であり、監査の JSON・実署名・宣言の写しは今回の結果に更新した。最大常駐量は計画に従い未取得である。

### 終了と判定

終了: 2026-11-04T22:02:08+09:00。再開1の外側の所要は25分5秒（読解・局所の試行・既定ビルド・監査・work・verify・記録を含む）。能動時間と待ちは分離していない。開始から約5分時点の45〜75分の見込みを下回った。根の修正と全称契約が局所の追随で閉じ、前群の追加の修正が要らなかったためである。3時間の停止条件には達していない。

中1〜3・軽1〜3の担当分は処置済みであり、群末の四検査はそれぞれ一度で成功した。verify は全7変更モジュールの既定 import と全572監査宣言を照合し、義務33行・申し送り31行・16署名を確認した。再開前からの本番の変更は3 Lean と2写しだけであり、git の操作は行っていない。R50 へ今回の食い違いを未処置として送らない。新たに取りまとめへ判断を求める点はない。再開1に対する独立レビューと受け入れの判定は未実施であり、取りまとめ・設計者が行う。

## 群 E の作業末の work の検査（取りまとめ）

- 基準: `7ece2393f5585203556d07d4851b6b946abb0e92`。作業木は再開1の後の状態。
- 前処理: `formal/.lake/build/lib/lean/Benitoite/Release/Refinement` と `formal/.lake/build/ir/Benitoite/Release/Refinement` を消し、篩の部分を再ビルドさせた。
- コマンド: `/usr/bin/time -l scripts/check.sh --level work --base 7ece2393f5585203556d07d4851b6b946abb0e92`。
- 結果: 終了0。外側 447.05秒、最大常駐量 2,968,502,272 バイト。仕様例7件が通り、形式化のビルドに sorry はない。
