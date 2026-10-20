# Q2: 0.0.10の仕上げ検査の記録とリリースの手動照合

2026-10-21、Q2（Codex）が実施した。基準と候補のHEADは `e6247c11712466a387e46d16147dcc819e6e797a`、開始時の未コミット差分はない。依頼本文、plan「改造末の全件・形式化・測定・release」、design 14節と決定記録を用いた。notes/Q2.mdとplanのQ2専用行がなかったため、依頼の検査を採る判断を [R221](../decisions.md#r221-q2の取りまとめの補助と文書検査の割り当て) に記した。

手動照合の全コマンド・終了状態・外側時間・stdout/stderr、補助入力の全文とSHA-256、静的照合の一覧は [evidence.json](evidence.json) にある。本記録の `$CLI` は `/Users/tecogonaz/src/Benitoite/target/release/benitoite`、`$I` は `/Users/tecogonaz/src/Benitoite/target/q2-manual`、`$D` は本改造のディレクトリである。表の短縮パスは証拠内のargvで絶対パスへ具体化してある。実行環境はmacOS 27.0.1 arm64、rustc 1.98.1（LLVM 22.1.8）、Cargo 1.98.1、Python 3.9.6である。

## 現HEADのCLI、版と同梱物

| コマンド・対象 | 終了 | 観察と判定 |
|---|---:|---|
| `cargo build --release -p benitoite` | 0 | 43.914秒。既定機能gc-mark-sweepの最適化したCLIを現HEADからビルド |
| `$CLI --version`、`--version=json` | 各0 | テキスト0.0.10/Unicode 17.0.0。JSONのbuild.commitは候補の完全ID、targetはaarch64-apple-darwin。dirty=null/notCollectedはCLIがdirtyを採取しないという意味であり、開始時のcleanは別にgit statusで確認 |
| `crates/benitoite/Cargo.toml`、Cargo.lock、CHANGELOG、README | 読取り | benitoiteの版は全て0.0.10。CHANGELOGの先頭の節も0.0.10。過去の節の0.0.9と将来の配布例0.1.0は対象を区別 |
| `$CLI skill list --format=json`、全73文書の `skill show --format=json <name>` | 全て0 | 名前集合がSkillの全ファイル＋二ライセンスと一致。版置換後の全本文・UTF-8 byteLength・SHA-256が元のファイルと一致し、list/show間も一致。producerは0.0.10と現HEAD。日本語訳を含まない |
| `cargo run -p benitoite --example gen_skill` | 0 | 7.479秒。Skill全ファイルとbundle.rsの再生成前後のハッシュが一致。直後の生成物限定git diffも空、終了0 |
| `$CLI --licenses` | 0 | MITまたはApache-2.0。ソースからの既定ビルドは第三者ライセンス一覧を同梱しないと表示し、設計・導入案内と一致 |

実行ファイルのSHA-256は `8579c645b619d11914061b56ae8d7c72d6628e56eb075d7e0d22b29816793626`、大きさは31422464 bytesである。ビルド後に同実行ファイルを差し替えていない。Git情報を持たない旧版の展開先は、後述の環境変数による来歴表示と区別する。

## 英日・配布一覧・許諾・移行案内とblockの再走査

英語reference/installと日本語reference/installは対象版・翻訳元0.0.10を示す。現在の英日リファレンスの `benitoite` 付きコードブロック40件は順序と本文が全て一致した。日本語Skillの手書き五文書も翻訳元0.0.10である。Skillの版置換印は手書き元に残し、CLIで0.0.10へ展開する。版・意味の確認箇所と各文書のハッシュはevidenceのdocumentAuditに残した。

| 照合対象 | 確認した内容 |
|---|---|
| README、英日install、CHANGELOGと05-01 | 0.0.10はソースのみ。実行ファイルアーカイブとSHA256SUMSは今回提供しない。0.1.0以降の説明は三ターゲット、実行ファイル＋LICENSE-MIT/LICENSE-APACHE＋THIRD_PARTY_LICENSES、別のSHA256SUMSという同じ一覧 |
| 許諾と構成 | Cargo/README/Skillの許諾はMIT OR Apache-2.0、両ライセンス文が追跡されSkillにも同梱。既定のCLIはbundled-licensesなし。deny.tomlのallowとscripts/release/about.tomlのacceptedの七項目が順序も一致。依存ライセンス検査の成功は仕上げchangeにあり、Q2で再実行していない |
| 0.0.9→0.0.10の案内 | blockの改名、全域Integer後のcatch-all除去と穴/ガードの維持、language更新と依存ハッシュの順、Log/SourceLocationのpreludeと独立の許可、警告、純粋な局所構築器と旧Stateの受理、copyの物理費用を英日とCHANGELOGで照合 |
| 生成の版と移行 | inventory=2/config=1を維持、manifest/receipt/record/semantic hash=3、generatorVersion=3.0.0-syntax-batch4、Property.libraryVersion=2.0.0。旧本文のハッシュ確認→新previewのレビュー→そのmanifestの正確なSHA-256でapply→通常check/test＋derive checkの順が英日/道具/生成記録で一致 |
| 旧移行道具 | 現役のtools配下からhistorical-toolsへ移動した案内と復元用リンクが存在。別の道具に旧manifestを流用しない説明も一致 |

予約語blockは、追跡する標準ソース、開発例、derive同梱例、skill-evalの参照入力とbench入力の計118 `.bnt` を単語で再走査し、該当0だった。さらに英日reference/installとSkillのコードフェンスを走査した。7該当は英日・Skill idiomsの `bind text <- block`/`end block` 各2行と、生成grammarの規則1行だけであり、旧識別子・ラベル・ドット後の名前はなかった。負のテストと履歴資料は利用者へ示す成功例と混ぜていない。対象ファイルと全該当行はevidenceにある。

## 実CLIの代表例

設計の例をそのまま使うか、結果を観察するmain/testだけを足して `$I` へ置いた。リポジトリのreferenceや既存テストを書き換えていない。

| 内容・コマンド | 終了 | 出力・診断と判定 |
|---|---:|---|
| design 14.1のgreeting、`check --report=json` / `run $I/builders.bnt` / `test $I/builders.bnt` | 各0 | greetingはStateなしの純粋な署名で受理。観察用mainだけConsole.Writeを宣言。stdoutは`hello!`と`hello`、stderr空、独立期待の@test一件成功 |
| 14.3の全域、`run $I/integer.bnt` | 0 | Integerの両端と0を渡し`-1 1 1`。stderr空 |
| 一点の穴と全域後のcatch-all、`check --diagnostics=json` | 各2 | holeはE0601で反例0、catch-allはE0602で到達不能。独立の期待と一致 |
| 14.2の既定Log、`run $I/log.bnt` | 0 | stdout空。stderr一行 `level=INFO source="log.bnt:3:22" message="done" attr."count"=3`。hereを書いた行と列に一致 |
| `check --report=json $I/log.bnt`、`run --allow-effects=Log` | 各0 | schemaVersion=1、宣言上限のexpandedは[Log]。許可した実行は同じstderr一行 |
| `run --diagnostics=json --allow-effects=` | 2 | E0512、許可外Log。ログ本文は実行しない |
| 完全なLogハンドラ、`run $I/log-captured.bnt` | 0 | 純粋なmain、stdout/stderrとも空。既定出力を重ねない |
| uses Log除去 / IO.Allだけ、`check --diagnostics=json` | 各2 | どちらもLog未宣言のE0501。IO.AllをLogの許可として扱わない |
| Logの@test、`test --check --report=json` / `test --diagnostics=json --allow-effects=Log` | 各0 | 静的報告のexpanded=[Log]。実行JSONのtest.stderrにログ一行を捕捉し、testSummaryは1成功。プロセスのstderrへ重ねない |
| 同じtestの空の許可 | 2 | E0512、0実行・filesNotRun=1 |
| 三つの検査済み型、`test $I/checked.bnt` | 0 | 現英語referenceの例そのまま。一件成功。CheckedLengthは実長2と元[10,20]、CheckedIndexのgetは20、NonEmptyListのhead10/tail[20] |
| 14.4の外部構築、`check --diagnostics=json $I/checked-forged.bnt` | 2 | E0340、CheckedLengthの表現が非公開 |

生成済みの再帰レコードは14.5の `Node[T] { value: T, children: List[Node[T]] }` を用いた。`cargo build -p benitoite --example derive_inventory --bin benitoite`（終了0、2.909秒）で道具の読者とformatterの前提を用意した。道具が使うdebug CLIと、実行の照合に使うrelease CLIを区別し、生成物の実行は後者で行った。

| コマンドと入力 | 終了 | 照合した内容 |
|---|---:|---|
| `python3 -B tools/derive/derive.py preview --root $I/recursive --config $I/recursive/derive.json --out $I/recursive-review` | 0 | Gen/Shrinker＋Show/Orderの差分と版3のmanifestをレビュー。SHA-256 `40cd2a9fa20221decf3d8dc73bc00f86b95fa11612a50415c53331f45e386d4c` |
| 同道具の `apply`（同root/config、上のmanifestとその正確な `--manifest-sha256`） | 0 | 一ファイル適用。生成部分を手で直していない |
| `$CLI check $I/recursive/People.bnt`、同ファイルの `test` | 各0 | size=0で子[]/value7/固定Show、size12の総節点数≤13、同じ乱数からの再現を検査。一件成功 |
| 浅い独立期待を手書き領域へ補った同ファイルの `test` | 0 | 二件成功。縮小候補の全順序を、子の除去→親の値→子の値の具体的な6候補で確認。Showの完全な固定文字列、Orderの最初の欄・子の欄・Equalを確認 |
| 同道具の `check`、二度目の `preview` | 各0 | generated regions and records match、二度目のchanges.diffは0 bytes。追加した手書き領域の観察後のcheckも成功 |

## 通常test・doc・外部準備の共有とWriter中断

既存のresource/x.wasmとLib/Cell.bntを `$I/external` へ複写した。各テストでcellを一つ作り、live=1、10から2増やして12という独立期待を使った。二つの入口と、独立したdoc test/runを同じCLI起動へ入れた。

| コマンド | 終了 | stdoutと統計（stderrの一JSON） |
|---|---:|---|
| `$CLI test --wasm-stats $I/external/First.bnt $I/external/Second.bnt` | 0 | 通常二件成功、calls=6、runtime_compilations normal=1/adapter=0、test_declaration_compilations=2、stateful_instances=2 |
| `$CLI test --doc --wasm-stats $I/external/Docs.bnt $I/external/Second.bnt` | 0 | 通常二件＋doc test一件＋doc run一件＝四件成功。doc runの期待出力は1。calls=11、実行用normal=1/adapter=0、宣言照合=4、stateful_instances=4 |
| 同じ二入口の `test --doc --check --report=json` | 0 | schemaVersion=2の検査報告。実行とは別に静的な準備も成功 |

実行用コンパイルの共有と、各実行のStoreの独立を両方確認した。adapterを含む1/10/50件の大きい組合せは [H2の既存結果](../h2/results.md) と仕上げchangeにある。本手動照合の代表はstatefulの一コンポーネントであり、全経路の追加回帰を実行したものではない。

Writerは依頼が許す既存結果の引用を用いた。仕上げchangeのtest_default_all/test_heap_all/test_stressの各ログで `first_signal_releases_buffered_file_writer` と `second_sigint_terminates_during_file_writer_release` がともに成功した。コマンドと各構成の集計は [改造のresults.md](../results.md#change) とevidenceのorchestratorLogs/writerCitationにある。

[G7の記録](../g7/results.md)と現行テストを読み、第一のテストがdirect/request×SIGINT/SIGTERMの四組で、中断前の空ファイル・中断後の短文全量・終了130・余分な出力なしを要求することを確認した。第二は入れ子のFIFOで解放の目印と外側flushの部分書き込みを観測してから二度目のSIGINTを送り、シグナル終了と本文未完了を要求する。kill成功や固定sleepだけの同期へ読み替えていない。270a717c以後、当該テストとWriterの本体に差分がないため引用できる。判断者はQ2（Codex）、2026-10-21。Q2で中断テストを重ねていない。

## 0.0.9のCLIでの移行前と0.0.10での移行後

`git archive c31e64b03d2810343e1779926bea4ebc958b6164` を `target/q2-old-source` へ展開し、`CARGO_TARGET_DIR=<同ディレクトリ>/target BENITOITE_BUILD_COMMIT=c31e64b03d2810343e1779926bea4ebc958b6164 cargo build --release -p benitoite` をそこで実行した。終了0、76.190秒。版は0.0.9で、commitの来歴は環境変数である。ソースとarchiveのハッシュ・ビルド環境・実行ファイルのハッシュをevidenceに残した。現HEADのビルドディレクトリと混ぜていない。

CHANGELOGの移行表は旧新の断片と手順を示すため、それを実行可能な小さいプログラムへ具体化した。referenceに新しい例を追記したのではない。全文とハッシュはevidenceのmanualInputsにある。

| 移行案内の項目 | 0.0.9で前の形 | 0.0.10で後の形 | 0.0.10で前の形を確認 |
|---|---|---|---|
| 予約語block | `bind block <- 7` とその参照、run終了0 | 名前をtextへ変更、run終了0 | check終了2、E0216（回復に伴うE0214も併記） |
| Integer全域 | 二つの区間＋`case _ -> 0`、run終了0 | catch-allだけを除去、run終了0 | check終了2、E0602 |
| language | `language "0.0.9"`、run終了0 | `language "0.0.10"`、run終了0 | check終了2、E0908と0.0.10の案内 |
| 局所構築器 | greetingとmainに`uses State`、run終了0 | 同じ旧State付きのままrun終了0。Stateを外した純粋な版もrun終了0 | 古いState宣言は拒否しない。公開契約を純粋へ変える判断は自動化しない |

旧版の専用ディレクトリは照合後に削除し、不在を確認した。空き容量は開始約42 GiB、旧版ビルド後約41 GiBで、30GBを下回らなかった。空き容量の正確な採取はevidenceのdf出力にある。

## 失敗した補助手順・計画との差と申し送り

手動の外部doc入力を初めにimportの前へ `///` で置き、文書コメントが宣言に付かないため終了2となった。モジュール用の `//!` へ補助入力だけを直し、docを実行し直して四件成功を確認した。ライセンス一覧の補助Pythonは3.9でtomllibを読めず終了1だったため、同じ配列リテラルを標準のastで読む形へ直して一致を確認した。いずれも処理系・計画の保存例・既存テストの不整合ではなく、初回の出力も証拠へ残した。

仕上げ検査の要約と引用理由をD/results.mdへ追記した。targets本測定を行わないこと、shortの65/66点の退行の疑い、Q1の主因と未確認の範囲、性能対策をdocs/todoのTODO-275へ回す設計者の判断、CHANGELOGへ性能の増減を書かない方針もそこへ記した。Q2は処理系・formal・テスト・道具の本体・docs/todoに触れていない。

CHANGELOGの0.0.10の移行表は、現在の改造ディレクトリ `docs/2026-10-19-TODO-022_032_087_168_191_192_200_206_222_226_227_229_246_248_253-syntax-batch4/historical-tools/named-arguments-migrate/README.md` へリンクしている。現在は存在するが、保管時の移動で切れるため、オーケストレータが実際のarchive先へ付け替える。依頼に従い今は直していない。

手動照合の範囲で処理系と文書の不一致は見つからず、新たな仕様判断について設計者へ相談する必要はない。元検査の未採取の来歴（当時のdirtyや完全なMiri版）をQ2が補ったとは扱わず、その限界はD/results.mdとevidenceへ明記した。RV5と最終の受け入れ・保管・公開判断はオーケストレータと設計者へ渡す。コミット・タグ・push・公開操作は行っていない。

## 作業末の検査

作業末の検査は、依頼どおり `git diff --check` と、開始HEADに対してreferenceの例と処理系・テスト・道具の本体が未変更であることの確認だけとした。各一度のコマンド・終了状態・外側時間はevidenceのfinal validationに保存した。Rustを変更していないため、lib全件・clippy・fmt・check.shの本実行・gc-stress・形式化・性能の測定はQ2で追加していない。
