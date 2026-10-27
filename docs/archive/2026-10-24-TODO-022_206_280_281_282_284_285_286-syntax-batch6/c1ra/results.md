# C1Ra の実装結果

2026-10-24。基準 B_WORK は `114eaa1d4d353964b96c1f50453d50361fca7171`、作業枝は `mod012/C1Ra`。前回の起動は報告を書かずに終了状態101で終わり、その途中変更を引き継いで仕上げた。git の変更操作、private/・そこを指すスキルの読み取りは行っていない。

## 変更と検査前の確認

本体の入口を `analyzeBody limits state fuel definition seed` に固定し、入口の忘却を計上してから `bodyRoot seed.body` を `bodyRootKey definition` から解析する。根の block 式の番号0と訪問・保存を含み、内容は番号1からである。`BudgetBody.lean` に任意の予算と深さでの正常値・警告原因・位置の三つの系を置き、既定 import に接続した。01-12・07-04を同じ定義と言明へ揃えた。

constE 自体は親の中だけで解析し、`embeddedBodies`・`discoverBodies` の別本体から除いた。内側の捕捉境界の列挙は残す。plan の警告の契約を、旧警告との重複と新候補どうしの重複を元NodeId・原因・一次位置で一件にまとめる形にした。キー単位の候補列とまとめた警告の両方を X02 が比べる。所見ごとの対応と後続担当は [RV-C1-response](../reviews/RV-C1-response.md) に記した。

独立例の変更は test-audit の作成時の関門に従う。守る契約は本体入口の番号・予算と捕捉環境の忘却、および constE の列挙の一重化である。根を数えない退行は警告の番号1・操作数9・保存項目5・番号列0〜3で検出する。constE の別本体を再作成する退行は、既存の捕捉境界の例に足した「埋め込み定数内のラムダ一件・局所位置0件」で検出する。manifest の既存例とは、環境を作る列挙の境界が異なるために必要である。shadow の正常評価と、停止後に残る警告の既存例は、本体入口の系へ接続し直した。検査専用の本番入口や差し込み口は追加していない。

## 実行した検査

Lean の局所コマンドは formal/ で実行した。一ファイルの検査にはすべて `-M 12288` を付け、lake のビルドは直列で実行した。時間の「未計測」は、初期の局所ビルドを対話ツールで分割して受け取り、外側全体の時刻を保存していなかったものを表す。最終検査は /usr/bin/time -l で包み、Python でも外側時間と検査本体の終了状態を保存した。

| コマンド・対象 | 終了状態 | 外側時間 |
|---|---|---|
| `lake build Benitoite.Interval.BudgetBody`（初回と修正中の二回） | 各1。証明の適用・Context の推論失敗。下記の修正で解消 | 未計測 |
| `lake build Benitoite.Interval.BudgetBody Benitoite.Interval.BudgetAnalysisExamples Benitoite.Interval.IdentityExamples Benitoite.Interval.Examples` | 0 | 未計測 |
| `lake build Benitoite.Interval.Analyze Benitoite.Interval.BudgetBody Benitoite.Interval.BudgetAnalysisExamples Benitoite.Interval.IdentityExamples Benitoite.Interval.Examples` | 0 | 未計測 |
| `/usr/bin/time -l lake build Benitoite.Interval.BudgetAnalysisExamples Benitoite.Interval.Examples` | lake は0、time は1（sysctl の制限） | time の real 0.97秒 |
| `lake env lean -M 12288 Benitoite/Interval/Analyze.lean`（constE 分岐だけを旧版へ一時的に戻した退行確認。finally で修正版を復元） | 期待どおり1。追加した定数内ラムダの列挙の等式で失敗 | 0.455秒 |
| 同コマンド（修正版） | 0 | 0.454秒 |
| `lake env lean -M 12288 /private/tmp/c1ra-juf0802n/Axioms.lean`（入口の三つの系へ `#print axioms` を実行する一時入力。実行後削除） | 0。三つとも propext・Classical.choice・Quot.sound だけ | 0.286秒 |
| 最初の最終検査の dry-run（下記） | 0。指定の三単位だけを選択 | 未計測（1秒未満） |
| 最初の最終検査（下記） | 1。spec_tally は成功、spec_examples は Cargo キャッシュへの書込み拒否で失敗、formal_build は未着手 | 1.179秒（time の real 1.21秒） |
| 再試行の dry-run（下記） | 0。失敗・未着手の二単位だけを選択 | 未計測（1秒未満） |
| 一時 CARGO_HOME での再試行（下記） | 検査本体は0、time は1（sysctl の制限）。spec_examples は7成功・0失敗・0無視、既定 lake build と sorry 拒否は成功 | 78.648秒（time の real 78.67秒） |

最初の dry-run と本実行の指定は次のとおりである。本実行は `/usr/bin/time -l python3` から subprocess でこのコマンドを起動した。

```sh
scripts/check.sh --level work --base 114eaa1d4d353964b96c1f50453d50361fca7171 --only formal_build,spec_examples,spec_tally --dry-run
scripts/check.sh --level work --base 114eaa1d4d353964b96c1f50453d50361fca7171 --only formal_build,spec_examples,spec_tally
```

spec_tally は、自己検査（実行器の印6種・初回リリースの見出し・ディレクトリのテスト・shebang・ignored fixture・完了条件表・不正入力）と本番集計が成功した。未記入の初回リリース完了条件はなし。テスト参照のない仕様節の一覧は通常の集計出力として表示され、失敗ではない。

再試行では、成功済みの spec_tally を重ねず、次だけを実行した。

```sh
scripts/check.sh --level work --base 114eaa1d4d353964b96c1f50453d50361fca7171 --only formal_build,spec_examples --dry-run
CARGO_HOME=/private/tmp/benitoite-c1ra-cargo-6o0m3fp5 scripts/check.sh --level work --base 114eaa1d4d353964b96c1f50453d50361fca7171 --only formal_build,spec_examples
```

CARGO_HOME の準備は0.626秒。既存の registry/cache・index をコピーし、取得済み registry/src の各クレートは読み取り用リンクで参照した。不足していた crate はこの一時領域へ取得でき、依存の版・検査入力を変えずに仕様例7件が通った。再試行も `/usr/bin/time -l python3` 内から環境を指定して起動した。

最大常駐量（maximum resident set size）はサンドボックスの sysctl 制限で取得できなかった。検査本体の終了状態0と、time 自体の終了状態1を混同していない。Lean の各プロセスの上限は lakefile.toml の `-M 12288` のままである。局所ビルドでは既存の Flow.lean の unnecessarySimpa 警告が表示されたが、この作業では変更していない。

## 失敗と修正

- 引き継いだ `BudgetBody.lean` は、success_bind の暗黙引数・出力を分けた後の中間状態・analyzeBody_property の高階の引数の推論で型不一致となり、最初の局所 `lake build Benitoite.Interval.BudgetBody` は終了1だった。適用する処理・述語と Context を明示し、出力の等式を使って修正した。中心命題・評価関係の変更や公理の追加は必要なかった。
- 最終検査の初回は spec_tally の成功後、spec_examples の Cargo が未取得の `rustls-webpki-0.103.16.crate` を `~/.cargo/registry/cache/` に作れず、`Operation not permitted` で終了1だった。formal_build は未着手。既存のキャッシュと索引を /private/tmp の書き込み可能な CARGO_HOME へコピーし、取得済みのソースは読取用リンクで参照して再試行し、成功した。依存の版・入力・上限は変えていない。
- `/usr/bin/time -l` は、このサンドボックスで `sysctl kern.clockrate: Operation not permitted` となる。子の検査が成功しても外側は終了1となり、最大常駐量（maximum resident set size）を取得できない。Python の subprocess で検査本体の終了状態と外側の経過秒を別に保存して区別した。

## 計画からのずれと申し送り

C1Ra の範囲は完了した。C1Rb・C1Rc の実装は先取りしていない。C1Rb は中1・中5、C1Rc は中3と軽2・軽3を担当し、RV-C1-response の当該行へ追記する。本体をまたぐ駆動順、予算付きの別本体発見、深さの選び方は C1Rc で閉じる。

A07 は元NodeId・原因・一次位置で利用者の警告をまとめ、X02 は候補列・まとめた警告・操作数・最大同時保持・停止位置・停止操作による分類を照合する。A09 は照合値の近似が整数だけの場合に腕を解析する制約を保ち、A11 は Budget*.lean の正確な計上順を写す。L14 は Integer64 を含む一般の負号を具体規則へ接続するときに未知から外す。U01 は定数を展開した木の最大の大きさと消費を測る。

最終差分の空白・競合印と、追加した対応記録の相対リンクも確認した。

中心二命題・評価関係・旧主定理・公理・Builtins.Assumptions の変更はない。判断待ちはない。Rust/VM の全比較・後続作業の実装・C1R 全体の独立レビューと受け入れは取りまとめと各後続担当の範囲である。
