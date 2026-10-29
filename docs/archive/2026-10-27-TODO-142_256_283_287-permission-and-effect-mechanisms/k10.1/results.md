# K10.1: 必須判定の入力・区間・全書き出し元の版の照合

## 作業と状態

B_WORK と HEAD は `6b333d12343f922f976e589f6a1c4ab8f2a1929e`、ブランチは `m013/k10.1` である。署名と表データ、全書き出し元の版と必須欄、局所受理の入力、符号順、候補、標準 Result の成功腕の交換名をそろえ、通常ソースの F-local の四入口を通した。作業末の W-K は2026-10-29の取りまとめの判断に従う九項目の部分選択で初回成功し、formal_build は同じ HEAD の B-Lean を引用した。全関係定義の全比較は実施しておらず、K10.3 に残る。

`private/`、そこを指すスキルのリンク、`docs/todo/` は読んでいない。公開の `test-audit`・`japanese-tech-writing`・`rtk` を適用した。git の状態を変える操作、本線への書き込み、依存・Lean ソース・scripts の変更、`lake build`、`check-formal.sh`、short は行っていない。新しい CARGO_TARGET_DIR、target 外の一時ビルド、基準版の展開は作っていない。したがって、それらの削除対象はない。F-local の保存入力・報告は証拠として残す。

変更ファイル、未追跡の新規入力、B_WORK の差分の SHA-256、設定・固定版・実行ファイル・各入力と報告の大きさと SHA-256 は [inputs-and-tools.json](inputs-and-tools.json) に保存する。[audit_artifacts.py](audit_artifacts.py) は照合と記録だけを行い、Lean の比較やビルドを呼ばない。

## 13入口と表データ

Rust の標準宣言、`builtins/table.rs` の `parameterize_builtin_signature` と `builtin_range_signature`、交換の型表を、`formal/Benitoite/Release/TargetTable.lean` と照合した。R は `rvar 0`、S は `rvar 1`、Path は `Scope.PathIn`、Req は `Http.RequestIn` を表す。以下の13入口の型引数・効果引数はいずれも0個である。

| 入口 | 引数 → 戻り値 | rkinds | 効果・形 |
|---|---|---|---|
| Scope.checkPathIn | String pattern, String path → Result[Path[R], ScopeError] | [path] | 純粋・untargeted |
| Http.checkRequestIn | String hostPattern, Integer minimumPort, Integer maximumPort, ClientRequest request → Result[Req[R], RequestCheckError] | [endpoint] | 純粋・untargeted |
| Scope.pathInValue | Path[R] path → String | [path] | 純粋・untargeted |
| Http.requestInValue | Req[R] request → ClientRequest | [endpoint] | 純粋・untargeted |
| Scope.widenPathIn | Path[R] path → Path[S] | [path,path] | 純粋・untargeted |
| Http.widenRequestIn | Req[R] request → Req[S] | [endpoint,endpoint] | 純粋・untargeted |
| File.readTextIn | Path[R] path → Result[String, IOError] | [path] | File.Read[R]・single path 0 |
| File.readBytesIn | Path[R] path → Result[Bytes, IOError] | [path] | File.Read[R]・single path 0 |
| File.writeTextIn | Path[R] path, String text → Result[Unit, IOError] | [path] | File.Write[R]・single path 0 |
| File.appendTextIn | Path[R] path, String text → Result[Unit, IOError] | [path] | File.Write[R]・single path 0 |
| File.writeBytesIn | Path[R] path, Bytes content → Result[Unit, IOError] | [path] | File.Write[R]・single path 0 |
| File.appendBytesIn | Path[R] path, Bytes content → Result[Unit, IOError] | [path] | File.Write[R]・single path 0 |
| Http.sendIn | Req[R] request → Result[Response, NetworkError] | [endpoint] | Http.Connect[R]・single endpoint 0 |

| 表・接続 | 照合の結果 |
|---|---|
| effKind | File.Read/Write は path、Http.Connect は endpoint。交換の名前は既存の完全名 IO.File.Read/Write・Network.Http.Connect を保つ |
| valKind | PathIn の番号32は path、RequestIn の番号33は endpoint。他の不透明型と資源に範囲の種類を付けない |
| admitsR | 検査・射影・IO は一範囲。拡大は同種の二範囲で `covers {inner:0,outer:1}`。Any は個数・種類の検査と併せて読む |
| valContent | `33:[]` の内容は実 ClientRequest の `data:N`。名前・内容・五欄と二署名の一致は既存の通常テストが照合する |
| opaque の名前 | 型・valKinds・valContents とも「識別番号:JSON型引数」。PathIn/RequestIn は `32:[]` / `33:[]` |
| primName / prim | 前者は `TypeckOutput.call_ranges`、後者は Core IR の `ValKind::Builtin.ranges`。個数0も明示空列とし、OpRef.prim の節の参照と区別する |
| 署名の rvar | `signature_valid` と書き出しの `range_bound` で番号を rkinds の個数未満に制限する。通常の型・項・候補には許さない。Lean の Version の検査も署名の番号上限を照合する |

ClientRequest は method:String、url:String、headers:List[Pair[String,String]]、body:Bytes、timeoutMilliseconds:Integer の五欄である。`exports_request_content_as_the_same_record_type_in_declarations_and_signatures` は、同じ束縛の内容型が dataDecls・検査の第4引数・射影の戻り値へ現れることを確かめる。合成した不透明要求の成功で代用していない。

io_target は対象なし・旧 Top・単一対象の三形で一致する。対象なしは観測空列、旧 Top は報告された対象の種類一致、単一対象は指定引数の対象と同じ一要素の観測を要求する。七 IO に対象位置0以外の範囲付き値の引数と、戻り値の範囲変数はない。旧 Top の観測の完全性は実装レビューの条件である。shapeAt の Top 定数の互換と、V-Checked だけでは要求保持全体を保証しない限界を保つ。

## scopeAcceptance と limits

`scope.rs::acceptance` は、交換する表層・コアと定数の解析済みの文字列リテラルを集め、本番と同じ `PathPattern::parse`・`HostPattern::parse` でパターンを読む。元の文字列をキーにし、ホスト名の小文字化など解析の結果を値にする。不良な綴りは表に置かず、Lean の側でも解析不能のままになる。局所の値を文字列のリテラルへ定数伝播する処理は加えていない。直接の const 参照の本体も同じ入力の constants にあり、必要なリテラルを回収できる。

通常の全件・乱数・golden、named、typed try、幅付きの数と各 smoke は共通の attach_metadata に接続する。手書きの named 入力も必須欄を持ち、除外入力は規則のない空の表と採用四値を明示する。独立した F-table の専用入力は従来どおり別の明示した上限を保つ。区間の独立形式は別 schema なので scopeAcceptance を付け加えない。

| 上限 | operations | items |
|---|---:|---:|
| body | 16,384 | 512 |
| whole | 65,536 | 2,048 |

値は `DEFAULT_SCOPE_LIMITS` から書き、[r20.5/limits.json](../r20.5/limits.json) の limits との一致を保存した入力に対して照合した。whole は定義ごとである。番号付けの200,000イベントと comment は交換へ載せない。F-local は path の `/data/**` と host の `*.Example.com` → one [example,com] を含み、本番の builtinCheck が欠落によって終了2となる問題を閉じた。

## 符号順・版・範囲の正規形

`Surface::eff` と候補の列は、Lean の Order/Range.lean・Order/Atoms.lean の自然数符号で整列する。文字列の基数1,114,113、Cantor の対、path/name/IP/CIDR/endpoint/range/ix/atom の式を任意精度で計算し、Rust の derive 順や JSON の文字列順に依存しない。型付き Fail は name/rho の後へ従来どおり追加する。

符号順の独立期待値は tree /a と exact /b、/ba と /ab、Unicode・複数要素のパス、v4/v6・exact/CIDR・IPv6全幅、host の exact/one/many、複数名と rho、固定添字と rvar の偶奇を一つの交換境界で照合する。最初は共有交換器の内側に置いたが、lib と統合で同じ契約を重ねないため、最終は scope_tables の統合側だけに置いた。範囲変数のケースは公開の署名書き出しの境界から渡し、私有のフィールドへの差し込みを残さない。長い要素列では符号のビット長が増すため、極端に長い範囲の書き出し費用まで測定したとはしない。処理系本体の性能・保証は変えていない。

範囲は Rust の検査済みの型から正規の形を書き、最大 prefix の CIDR は exact に正規化する。Lean の入口も WF・Canonical と欄の形を検査する。欠落や余分な欄を Top に置き換えない。型表にある固定原子と呼び出しの ranges で具体化した原子を corpus の `candidates` に添えた。この欄は計画の候補の収録条件を満たすために残すが、Lean の交換の入力の必須欄ではない。`desugarDiff` が corpus 全体から原子を集める対象に入るだけで、脱糖の比較結果に影響しない。RV-K10.1 の再現では、欄を除いた入力と空にした入力のどちらも `desugarDiff`・`surfaceCheckAll` は終了0・5定義一致を保ち、`nonTopRanges` だけが18から17になった。署名の rvar のテンプレートは型表だけに残す。surfaceCheck 側は既存の atomsFor と instAtoms で型表・具体化した原子を集める。

| 生産側・読者 | 版と変更 |
|---|---|
| write_exchange・CorpusStream・named・batch2・typed try・width | 既存の corpus15 / sidecar7 を保ち、共通の必須入力と候補を接続。named の2 smoke も共通の整数を保持するシリアライザを使う |
| interval.rs・interval/source.rs・interval/manifest.rs | Surface14→15。元の区間 corpus1・traversalVersion1は維持 |
| interval/prepare-range.py | Surface14→15 |
| check_named.py | namedVersions と width の読者を15/7へ追随 |
| check_batch3.py | 版の検査は corpus14/sidecar6→15/7。ただし、先に呼ぶ `formal/tests/test_batch3_exchange.py::rust_inputs` が corpus15/sidecar7 へ追随するまで通らない（未接続）。同関数は corpus12/13/14 だけを受け付けるため、レビューの batch3 の8構成はすべて終了1となった。K10.2 で `rust_inputs` を更新するときに check_batch3 の経路も合わせて照合する |
| exchange-manifest.json | namedVersions=15/7/7。named-declarations の定義数2→5 |
| routing-manifest.json | 全1,792入力の版14→15だけ変更。分類や古いハッシュ等の再照合は K10.2 |
| formal/tests の interval_source_compare・interval_vm_compare・interval_range_vm・interval_shift_vm | Surface14→15だけ変更 |
| coverage_export.rs | 独立 coverage4は維持。プログラム coverage の sidecar7と一律に変えない |
| 独立した corpus10 と旧版読者 | 固定入力は変えず、明示 Top / 空 ranges の既存の対応を保つ |

さらに、標準 Result.Ok の交換名を既存の必須判定の読者が要求する `Ok` に統一した。解決済みの標準 Result の束縛とタグ0だけを認定し、同じ綴りの利用者構成子は変えない。項・パターン・dataDecls の全呼び出しを同じ生成元へそろえ、旧 corpus10 の名前の対応と区間の range_bindings も追随した。これは Rust の交換名の修正であり、Lean の規則・共通型の変更ではない。routing の古い意味上の対応とハッシュはこの修正でも古くなり、K10.2 で照合する。

## 07-04 と保証の限界

対応表の「未接続」を Rust と Lean の比較全体の未完と明記し、Rust の通常の検査・実行、交換の書き出し、局所照合が存在しないように読める記述を直した。scopeAcceptance、四値、ranges、Surface15、候補と成功腕の交換名を反映した。全比較の行を成功へ変えていない。作業IDを設計書に追加していない。

README の起動前の判断どおり、Lean 読者には valContents の内容型の宣言存在と二署名との一致の検査を加えなかった。読者が Rust の書き手とその通常テストへこの一致を任せることを限界に明記した。対象健全性そのものを新しい仮定に移していない。主定理・Assumptions・保証は変更していない。

## B-Lean と F-local

B-Lean は取りまとめの [b-lean.log](b-lean.log) を引用する。B_WORK の formal で `/usr/bin/time -p lake build`、573 jobs・終了0、real29.31秒である。lakefile の -M12288を維持している。本枝の Lean ソース・設定・固定版には差分がなく、引用する四実行ファイルと設定のハッシュを inputs-and-tools.json に保存した。Rust の交換と Python の読者の変更は、Lean の生成物へ影響しない。2026-10-29に本担当がログと関係状態を確認した。既存の linter の警告はあるが、sorry を使う宣言の警告はない。元ログに最大常駐量はなく、取得不能であり0としない。本枝ではビルドを再実行していない。

E は `docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/k10.1/f-local` に固定した。入力の通常ソースは [named-declarations.bnt](f-local/named-declarations.bnt) で、旧 identity/make と project/readScoped/requestProject の5定義を含む。Rust は実ファイルを include して、同じ bytes を E に保存する。最終 corpus15 / sidecar7 の1入力、5定義、70署名、dataDecls48・構成子103、effKinds3・valKinds2・admitsR70・valContents1である。候補14原子のうち非Top1原子、patterns1件・hosts1件を含む。F-local で13入口すべての実行を検査した意味ではなく、13署名の照合は前掲の表と通常テストが担う。

各コマンドは [run_logged.py](run_logged.py) が `/usr/bin/time -p` で包み、内側のコマンドの終了状態を直後に専用の .exit へ直接保存する。正確な引数・時刻・外側時間・補助RSSは各 .json、生ログは同名の .log にある。下表の E は上記の相対パスを表す。

| 最終の実行 | 終了 | 外側秒 | 補助RSS MiB | 記録 |
|---|---:|---:|---:|---|
| BENITOITE_DESUGAR_DIFF_DIR=E cargo test --test desugar_export export_named_declarations_smoke -- --exact --nocapture | 0 | 3.085668 | 672.15625 | flocal-export-retry2.json/log |
| formal/.lake/build/bin/desugarDiff E/named-declarations-corpus.json E/desugar-report.json | 0 | 0.028423 | 38.1875 | flocal-desugar-retry.json/log |
| formal/.lake/build/bin/builtinCheck E/named-declarations-corpus.json E/named-declarations-builtins.json E/builtin-report.json | 0 | 0.029470 | 38.5625 | flocal-builtins-retry.json/log |
| formal/.lake/build/bin/surfaceCheckAll E/named-declarations-corpus.json E/named-declarations-builtins.json E/named-declarations-stdlib.json E/surface-all-report.json | 0 | 0.030910 | 40.34375 | flocal-surface-all-retry.json/log |
| formal/.lake/build/bin/surfaceCheck E/named-declarations-corpus.json E/named-declarations-builtins.json E/named-declarations-stdlib.json golden named-declarations E/surface-report.json | 0 | 0.029689 | 39.890625 | flocal-surface-retry.json/log |

[desugar-report](f-local/desugar-report.json) は5定義・1プログラム一致、非Top18、不一致・対象外・除外0である。[builtin-report](f-local/builtin-report.json) は1入力を検査し、要約96比較・不一致0、errors・missingPrims・missingConstructors・unconvertible・typeclassExcluded・nonconvergedは空または0である。[surface-all-report](f-local/surface-all-report.json) は5一致、準備失敗・対象外・Q11・lazyRestriction・不一致0、fullyCheckedInputs1・nonTopRanges18である。[surface-report](f-local/surface-report.json) は constructors/records/implNames と result.ok がすべて true である。nonTopRanges は候補を含む JSON 全体の件数である。拒否0の短い局所入力の結果であり、拒否を含む全比較の成功として引用しない。

## 作成時の関門・初回の失敗と修正

追加テストは候補と符号順の2件で、既存の宣言 smoke を拡張した。交換境界で必須欄の欠落・具体化原子の欠落・rvar の漏れ・原子順の退行を捕まえる。旧の Top だけの入力はこれらを検出できない。期待順と候補の要素は独立した規則と手書きの入力から固定し、本番の差し込み口や公開範囲を増やしていない。処理系本体の変更は0行、既存テストの削除は0件で、変更は交換テストとその台本・文書に限る。行数は [line-counts.json](line-counts.json) に保存した。ヒープの確保・根・障壁・保持表現を変えていないため H/H-full は対象外である。

| 初回・試行 | 原因と修正・再確認 |
|---|---|
| atom-order-before.log、101 | 修正前の derive 順が path の独立期待順に反した。符号整列後は成功。最終の署名の行まで atom-order-final の1件・終了0で確認した |
| smoke-before.log、101 | 初稿の widen の戻り値を射影すると unknownSource。必要な通常例は同じ成功値の直接射影に直した。後に判明した成功腕の交換名の相違とは別の Rust 側の位置・由来の制限であり、規則を変えず記録する |
| smoke-after-scope.log / local-export.log、101 | 交換テストのモジュール間の可視性が不足した。共有ヘルパーのテスト内の可視性だけを直し、lint の免除は追加していない |
| scope-before.json/log、101 | acceptance の2か所の接続だけを一時的に除き、正常な同じソースが limits の Null で失敗することを確認した。直後に必ず接続を復元した。修正版は F-local の書き出しと通常検査で確認する |
| candidates-before.json/log、101 | 候補の接続だけを一時的に除くと、非Top候補の収録を要求する Rust のテスト自身の照合が失敗した。Lean がこの欄を必要とする証拠ではない。直後に接続を復元し、最終入力には非Top候補を残した。RV-K10.1 では欄を除いた入力・空にした入力も `desugarDiff`・`surfaceCheckAll` は終了0・5定義一致で、`nonTopRanges` だけが18から17になった |
| atom-order-after-final.log、101 | 作業中の candidate_atoms 未使用によるコンパイル停止。接続後の通常テストと atom-order-final は成功 |
| F-local 初回 | 書き出し0・2.782565秒、脱糖0・1.107783秒、本番型表0・1.047093秒。表層全定義1・0.819309秒、表層全体1・0.937299秒。project/requestProject の成功腕を既存読者が認定できず unknownSource になった |
| F-local の修正 | 標準 Result.Ok の交換名を Ok へ一貫させ、関係する Rust の読者も直した。同じ5定義を減らさず、変更で古くなった入力と四入口を再実行した。初回の corpus・型表・報告は f-local-first に保持する |
| flocal-export-retry、101 | 符号順テストを統合側へ移した際、private の range_bound へ触れた。署名の公開書き出しを経由する形に直し、私有フィールドへの差し込みを除いた。retry2 と atom-order-final は成功 |

F-local の初回は各入口を一度ずつ実行した。修正後は古くなった入力と各入口だけを各一度再実行した。途中のコンパイル失敗も消さず、最終0だけを残していない。

## 通常検査と W-K

途中の `cargo test --test desugar_export --test coverage_export` は local-export2.json/log で終了0、外側15.925126秒、desugar_export46成功・既存無視1、coverage_export3成功・既存無視1であった。成功腕の交換名を直した後の `cargo test --test desugar_export` は local-ok-name.json/log で終了0、14.602882秒、46成功・既存無視1であった。これらを作業末の W-K の代わりにはしていない。

指定された W-K に `--dry-run` を付けた実行は終了0であった。[work-dry-run.log](work-dry-run.log) は fmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tally に加え、formal/tests の Python の変更を理由に formal_build を選んだ。この実行は `lake build` を含み、「この枝では lake build を走らせない」という条件と衝突する。scripts は編集範囲外なので変更していない。

B-Lean を引用して九項目を名指しする案を、取りまとめが2026-10-29に採用した。K10.1w で下記の部分選択を一度実行し、終了0であった。元の W-K の自動選択全体の実行とは区別する。dry-run は既存の work-proposed-dry-run.log を使い、追加実行していない。

最大常駐量は macOS の getrusage(RUSAGE_CHILDREN) の補助値で、原単位は bytes、MiB は2^20、GiB は2^30で換算した。time-p 自体はRSSを表示しない。値は各コマンドの子孫の一プロセスの最大であり、同時使用の総和ではない。コンパイルを含む書き出しとビルド済みの Lean の入口を区別する。

## 申し送りと時間

| 担当 | 残る内容 |
|---|---|
| K10.2 | corpus15/sidecar7 の報告・manifest・独立入力と六入口、観測・拒否の理由を接続する。surfaceCheck の拒否時の cover と surfaceCheckAll の拒否文を、同じ出現の鍵で読む |
| K10.2 | `formal/tests/test_batch3_exchange.py::rust_inputs` を corpus15/sidecar7 へ更新するときに、先に同関数を呼ぶ `check_batch3.py` の経路も合わせて照合する。現状は未接続であり、check_batch3 自身の版の検査を15/7へ変えただけでは通らない |
| K10.2 | desugarDiff は `candidates` を含む corpus 全体、surfaceCheck は型表と instAtoms から原子を集める。範囲の群ごとの `nonTopRanges>0` は `candidates` を除いた件数で判定し、旧 Top 群へ一律に非0を要求しない |
| K10.2 | 成功腕の交換名の変更で古くなった意味上の対応と routing のハッシュを再照合する。`check_named.py` の `check_routing` を実行し、`routing-manifest.json` と全 corpus の routing を照合する |
| K10.2 | R40 の26入力は部分集合である。host one/many・IP exact/CIDR/v6/port/mapped、HTTPの検査/射影/拡大と拒否、旧Scope/既知不良の診断除外、同名利用者関数、略記/実位置/番号停止/最後Run/内側超過、Required/coverの独立期待値を固定する |
| K10.2 | 四理由の直接比較と atomicCoverOnly の型付け拒否を分ける。番号付け停止の全規則Top、最後のRunの予算理由、U+0000の精度差の限定を保つ。同じ要求五欄とレコード操作、InvalidTarget/InvalidUrlの分離、保持endpoint一要素とDNS/TLS保証外を照合する |
| K10.3 | 六入口・intervalDiff・独立交換・区間の四書き出し・profile/VM・全関係定義の全比較を閉じる。途中の全体成功を引用しない。初期ε、BA末尾、shapeAt、旧像の同値、要求保持の形式化の限界を保つ |
| 取りまとめ | W-K の実行方法は2026-10-29に決定済みで、K10.1w の実行も終了0である。独立レビュー・採用修正・受け入れを行う。本番コードの変更がないので short の追加は対象外である |

Lean の規則・共通型・主定理・Assumptions・保証の変更を要する停止条件への該当はない。自動検査の選択の衝突は2026-10-29の取りまとめの部分選択と引用の判断により解消した。最初の記録時刻は2026-10-29 11:11:41 UTCであり、K10.1w の実績は末尾に追記した。分担の時間は重なるので外側の所要へ単純に加算しない。能動時間5時間の停止条件には達していない。

## W-K 実行前の記録

2026-10-29 11:35:31 UTC。必須入力と候補の接続を復元した最終ソースで `cargo test --test desugar_export export_named_declarations_smoke -- --exact --nocapture` を再確認し、1成功・終了0、外側2.720945秒、補助最大常駐量705,314,816 bytes = 672.640625 MiB = 0.656875610 GiBであった（scope-candidates-restored.json/log）。符号順の統合側一件も最終の署名のケースまで終了0である。差分の空白、更新した2文書の相対リンク、7 Python読者の構文、記録の絶対パスの残りの確認は成功した。新しいキャッシュディレクトリは作っていない。

提案した部分選択の dry-run も終了0、外側0.020715秒であり、実行する九項目と対象五統合を [work-proposed-dry-run.log](work-proposed-dry-run.log) に保存した。formal_build を含まないことを確認した。この11:35:31 UTC時点では判断前のため実検査は未実施であり、W-K の結果は未取得であった。その後の取りまとめの判断と K10.1w の結果を以下に記す。

最初の時計からこの確認までの外側は23分50秒、主担当の能動時間は約20分という概算である。検査・照合は各計時JSONのとおりであり、検査中の記録作成と重なる。設計者の判断待ちの間にも記録と局所確認を進めたため、その全区間を待ち時間として引かない。30秒の明示的な待ちを含む。分担の厳密な能動時間の合算は未採取である。見込みの上端の2倍には達していない。

## K10.1w: W-K の実行結果

取りまとめの2026-10-29の判断に従い、B_WORK・HEAD `6b333d12343f922f976e589f6a1c4ab8f2a1929e`、ブランチ `m013/k10.1` の未コミット差分に対し、以下を一度実行した。外側を `/usr/bin/time -p` で包み、内側の sh が check.sh の直後の `$?` を [work-check.exit](work-check.exit) に直接保存した。check.sh と time の終了状態はともに0である。

```sh
/usr/bin/time -p scripts/check.sh --level work --base 6b333d12343f922f976e589f6a1c4ab8f2a1929e --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally,python_syntax,policy_selftest --test desugar_export --test coverage_export --test golden --test verify --test random_programs
```

正確な実行器は既存の `run_logged.py work-check scripts/check.sh ...` である。同実行器の time は終了状態を保存する sh を含み、sh から上記の check.sh を同じ引数で呼ぶ。生ログは [work-check.log](work-check.log)、引数・開始/終了・終了状態・補助RSSは [work-check.json](work-check.json) に残した。

| 検査 | 成功 | 失敗 | 既存の無視 | ログのテスト時間 |
|---|---:|---:|---:|---:|
| lib_default（既定lib全件） | 1,392 | 0 | 22 | 81.16秒 |
| coverage_export | 3 | 0 | 1 | 1.11秒 |
| desugar_export | 46 | 0 | 1 | 11.79秒 |
| golden | 2 | 0 | 0 | 58.58秒 |
| random_programs | 7 | 0 | 0 | 48.18秒 |
| verify | 3 | 0 | 0 | 68.30秒 |
| 上記の合計 | 1,453 | 0 | 24 | 各ターゲットの時間。外側時間とは異なる |
| policy_selftest（シェル構文を含む検査方針の自己検査） | 30 | 0 | 0 | 26.022秒 |

fmt・lint_default（lib/tests/examples、gc-mark-sweep）・source_rules の二検査・skill_generated・spec_tally の自己検査と集計・python_syntax もすべて成功した。仕様集計は未参照節を表示する既定の動作で終了0、初回リリース版の完了条件の未記入は none である。九項目をすべて実行したことと末尾の `selected checks passed` を生ログで確認した。

random_differential は既定300件・60秒予算のまま成功した。件数・種を上書きする環境変数は未設定であり、手動実行扱いによる予算検査の省略もない。random_programs 全体が48.18秒であり、random_differential 自体の正確な秒数は成功時の出力にないが、60秒未満のアサートも通っている。単独での再実行は不要と判断した。verify の一件には60秒超の通知があるが成功しており、乱数テストの予算超過とは別である。

外側の time-p は real **338.19秒**、user 1154.66秒、sys 40.58秒である。実行器の単調時計は338.196776208秒で、開始は2026-10-29 11:37:50.630481 UTC、終了は11:43:28.827791 UTCである。補助最大常駐量は getrusage(RUSAGE_CHILDREN) の **4,041,064,448 bytes = 3,853.859375 MiB = 3.7635345458984375 GiB** であり、一括実行中の子プロセス一つの最大値として記録する。同時使用量の総和ではない。

W-K の初回失敗はなく、修正・再実行もない。K10.1 の途中の失敗と修正は前掲の表と各ログに保持した。K10.1w では処理系・テスト・台本・設計書を変更せず、記録だけを追加・更新した。新しい CARGO_TARGET_DIR、target 外の一時ビルド、基準版の展開は作っておらず、削除対象はない。git の状態を変える操作は行っていない。

### formal_build の引用

| 欄 | 引用の内容 |
|---|---|
| 基準・対象HEAD | ともに `6b333d12343f922f976e589f6a1c4ab8f2a1929e`。HEADだけで同一とせず、下記の入力の差分も確認した |
| 元の記録 | 取りまとめによる [b-lean.log](b-lean.log)。formal で `/usr/bin/time -p lake build`、573ジョブ、終了0、real29.31秒、user43.41秒、sys15.56秒。最大常駐量は元ログにないため取得不能 |
| Lean の入力 | B_WORK から `.lean`・lakefile・manifest・lean-toolchain に差分なし。未追跡の Lean 入力もない。`-M 12288` を維持し、設定・固定版・四交換実行ファイルの SHA-256 は既存の inputs-and-tools.json と一致した |
| 未コミット差分 | 全一覧と内容の SHA-256、未追跡のソース入力2件の SHA-256 を [work-input-state.json](work-input-state.json) に保存した。追跡ファイルの差分全体の SHA-256 は `f7923eeed159e1f2d42c69db9e1837d4ab4485e1c5749857aa82f4636ba8048d` で、既存の inputs-and-tools.json と一致した |
| formal 配下の変更 | `tests/interval_source_compare.py`・`tests/interval_vm_compare.py`・`tests/interval_range_vm.py`・`tests/interval_shift_vm.py` の4本だけ。Surface版の読者の追随であり、lake build が検査・生成する Lean の入力ではない |
| 関係状態が一致する理由 | Rust の交換テストと Python の読者の変更は formal_build の入力を変えない。Lean ソース・設定・固定版が B-Lean 時点と同じであるため、formal_build の結果を引用できる |
| Python 台本の確認 | 今回の python_syntax・policy_selftest の成功に加え、変更した7読者の直接の構文確認 [python-readers.json](python-readers.json) と、K10.1で実行済みの前掲 F-local の局所交換テストの記録を用いる。python_syntax 自体の対象は tools 配下であり、formal/tests の4本を直接読むと記録しない。今回、局所交換テストは再実行していない |
| 判断者・日付 | 取りまとめ、2026-10-29。K10.1w の担当が同日に差分・元ログ・ハッシュを再確認した |
| 適用の限界 | 引用するのは formal_build である。Rust/Lean 全比較の成功や Python 読者の全経路の成功として引用しない。lake build・check-formal.sh・short は実行していない |

### 時間と受け渡し

K10.1w の開始は2026-10-29 11:37:19 UTCである。検査待ちは約5分38秒で、依頼の10〜30分の見込みと1時間の停止条件を超えていない。最終の状態確認と記録を含む終了時刻・所要時間は以下に追記する。K10.1 の以前の約20分の能動時間は概算のまま保ち、今回の検査の外側時間を能動時間に加算しない。

| 残る手順 | 担当・見込み |
|---|---|
| 独立レビュー・必要な採用修正と古くなった検査の再実行 | 取りまとめ。レビューは計画の枝あたり10〜20分、修正・再実行の時間は指摘次第で不明 |
| 受け入れ | 設計者・取りまとめ、時期不明 |

最終確認は2026-10-29 11:45:29 UTC、K10.1w の外側の所要は490.75秒（約8.2分）である。能動時間は読解・照合・記録を含め約3分の概算で、検査中の照合と重なる。検査待ちとの単純な加算はしない。実行時からの差分全体・未追跡ソース入力・各内容の一致、全九項目の実行、終了状態、件数、相対リンク、手元の絶対パスが記録に残らないことを [work-final-check.json](work-final-check.json) に保存した。修正で古くなった検査はなく、追加の検査実行は行っていない。

## K10.1b: RV-K10.1 への対応

2026-10-29。[RV-K10.1「対応（取りまとめ）」](../reviews/RV-K10.1.md#対応取りまとめ)の中1・中2の案(b)・軽1・軽3を反映した。レビューの記録と [rv-probes](rv-probes/) は変更していない。軽2の README への記録は取りまとめの担当であり、今回の編集には含めない。

| 指摘 | 対応 |
|---|---|
| 中1 | 版の表と K10.2 への申し送りに、`check_batch3.py` は `formal/tests/test_batch3_exchange.py::rust_inputs` が corpus15/sidecar7 へ追随するまで通らない未接続の経路であることを明記した。K10.2 で同関数を更新するときに check_batch3 の経路も合わせて照合する。本体と台本は変更していない |
| 中2 | `candidates` は残し、07-04 に Lean の交換の入力の必須欄でなく、corpus からの原子の収集対象に入るだけで脱糖の比較結果に影響しないことを記した。既存の理由はそのまま成り立つ。前掲の候補と初回失敗の記述を、Rust の収録条件の照合と Lean の比較の区別が分かるように直した。K10.2 の群ごとの `nonTopRanges>0` は `candidates` を除いた件数で判定する |
| 軽1 | 07-04 の二か所を、区間の corpus の Surface 15 と埋め込みの表層の範囲の欄、通常の各入力の `scopeAcceptance` に分けた |
| 軽3 | K10.2 への申し送りに、`check_named.py` の `check_routing` を実行して全 corpus の routing と manifest を照合することを名指しで加えた |

中2の根拠はレビューの保存済みの再現である。`candidates` を除いた入力の [脱糖報告](rv-probes/nocand/named-declarations-dd.json)・[表層全定義報告](rv-probes/nocand/named-declarations-sa.json) と、欄を空にした入力の [脱糖報告](rv-probes/nocand/empty-dd.json)・[表層全定義報告](rv-probes/nocand/empty-sa.json) は、いずれも5定義一致・不一致0・`nonTopRanges=17` である。両入口の終了0はレビュー記録を引用する。欄を持つ最終の F-local の5定義一致・`nonTopRanges=18` と区別した。今回は交換の入口を再実行していない。

### W-K の引用と変更範囲の確認

今回変更したファイルは次の2件だけである。Rust・台本・入力・期待値・manifest・生成元と生成物・設定・固定版・交換器は変更していない。

- `docs/design/07-quality/07-04-formal-semantics.md`
- `docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/k10.1/results.md`

| 欄 | 引用と確認の内容 |
|---|---|
| 基準・対象HEAD | B_WORK・HEAD はともに `6b333d12343f922f976e589f6a1c4ab8f2a1929e`、ブランチは `m013/k10.1`。K10.1 の未コミット差分を保ち、git の状態を変える操作は行っていない |
| 元の結果・実行 | 本書「K10.1w: W-K の実行結果」と [work-check.log](work-check.log)・[work-check.json](work-check.json)・[work-check.exit](work-check.exit)。同節の正確なコマンド、九項目の部分選択と五つの統合ターゲットをそのまま引用する。check.sh 自身の終了0、外側338.19秒、Rust 1,453成功・失敗0・既存無視24、policy_selftest 30成功・失敗0。補助最大常駐量4,041,064,448 bytes。環境・構成・適用の限界も同節を引き継ぐ |
| 入力と道具の一致 | [work-input-state.json](work-input-state.json) の22件のうち、07-04 以外の21件は現在の SHA-256 と一致した。[inputs-and-tools.json](inputs-and-tools.json) の121件も07-04 以外の120件が一致し、欠落は0件である。署名・交換器・manifest・F-local の入力と報告・設定・固定版・交換実行ファイルを含む元の一覧を保持する |
| 別状態の差分 | K10.1w 時点の差分一覧とハッシュは work-input-state.json に保持した。今回の追跡ファイルの `git diff --binary HEAD` の SHA-256 は `1dad32d19d7a45eb42edf98014044914c06c561d6fcf941c45f108bebf5b4ca8`、更新後の07-04の SHA-256 は `9b8fa84c36fba913adb4eb6fe62800935b8784bae56271f785a7079a24834f24` である。未追跡ソース入力 `atom_order.rs` は `abce6c347472d1e8ec321aaeb8b317536cfd98ba79e475352e050264cc3be58b`、`named-declarations.bnt` は `c814f989e479884072469f0138a4874a4bcdf409c70bd7ca932ea8a9d4fda393` のままである |
| 関係状態が一致する理由 | 07-04 の変更は説明の三か所だけで、見出し・コード例・仕様の節・生成入力は変えていない。もう一件は結果記録である。Rust・台本・入力を変えておらず、九項目の部分選択と五つの統合ターゲットの結果は古くならない。K10.1b の依頼で指定された引用の条件を満たすため、W-K の再実行は行わない |
| 今回の確認 | 開始時のファイル一覧・内容との照合、今回の差分の読解、空白・相対リンクの確認、保存済みの再現報告の件数照合を行った。レビュー記録と rv-probes の内容を保持した。新しいテスト・ビルド・測定は実行していない |
| 判断者・日付 | K10.1b 担当、2026-10-29。依頼の引用条件に従う。Rust/Lean の全比較の成功や、check_batch3 と全 corpus の routing の照合済みを意味しない。後二件は上記の K10.2 の申し送りに残す |

`private/`・そこを指すスキル・`docs/todo/` は読んでいない。`lake build`・`check-formal.sh`・short は実行していない。Lean の規則・交換の共通型・主定理・Assumptions・保証の変更を要する停止条件への該当はない。一時のビルドや基準版の展開、新しい CARGO_TARGET_DIR は作っていない。

K10.1b の最初の時計は2026-10-29 12:05:14 UTC、最終確認は2026-10-29 12:08:50 UTC、その間の外側の所要は216.82秒（約3.6分）である。能動時間も約4分の概算であり、新しい検査・測定・回答待ちはない。1時間の停止条件には達していない。差分の照合用に作った一時の控えは作業末に削除した。
