# RV-K10.2: 独立入力・読者・manifest の接続の独立レビュー

2026-10-29。対象は K10.2 の未コミットの差分（基準 `c3ca4504`）と `k10.2/` の記録。作業用のディレクトリは書き換えず（git の状態は開始時と同じ25行）、退行させた入力の実験は保存された書き出しをリポジトリの外へ写して行った。変え方の台本を `k10.2/rv-probes/` に写した。

結論: 重大0・中2・軽8。中1 は 07-04 と results の文言の修正、中2 は K10.3 の起動依頼への反映が要る。この二つを済ませれば、取り込んで K10.3（全比較）へ進んでよい。

## 指摘

| 番号 | 重さ | 箇所 | 問題 | 修正案 |
|---|---|---|---|---|
| 中1 | 中 | `formal/tests/test_range_rejections.py::run_rejections`、07-04 の新しい段落（必須判定は同じ宣言と表層の先行順番号を鍵として E0519 と `surfaceCheck` の `result.cover` を直接照合し…）、results の「拒否理由の対応」の表 | 対象の3件（required-not-covered・required-unknown・request-widen-rejected）は、Rust の側が実ソースの診断、Lean の側が同じ形を手で書いた交換（`fn:901`）である。`range_sources.rs` は受理したプログラムしか書き出さない（`if let Some(p) = checked.program`）ので、拒否した実ソースは Lean へ渡っていない。両者はそれぞれ同じ手書きの期待と照合しているだけで、`.sample` と `fn:901` の対応は手で決めたものである。同じ実ソースを両側へ渡す直接比較は予算の2件（受理したソースを書き出して上限を差し替える方式）だけである | 07-04 と results を「必須判定の三拒否は、Rust の実ソースの診断と、同じ形の手書き交換の Lean の報告を、それぞれ同じ手書きの鍵・添字・理由と照合する。同一入力の直接比較は予算の2件である」と限定する。できれば、契約だけを受理する形に変えた実ソースを Rust で書き出し、手書き交換と契約以外が一致することを機械で照合する |
| 中2 | 中 | results の「全 corpus の routing と K10.3 の見込み」 | 8.20 GiB は `readers-routing.py` を実行した Python 自身の最大常駐量で（Lean を起動しない）、原因は大きな JSON の読み込みである。lakefile の `-M 12288` は `lake build` の Lean の処理にしか効かず、check_named.py の Python にも比較の実行ファイルにも上限はかからない。全比較では実行ファイルが 343 MB の `named-programs-corpus.json` と 968 MB の `interval-manifest.json` を読み、この規模の最大常駐量は未実測である | K10.3 の起動依頼に、各段の最大常駐量を記録すること、check_named（routing を含む）に 8〜9 GiB を見込むこと、Lean の実行ファイルを全 corpus で動かした常駐量は未実測で `-M` で抑えられないこと、16 GB の別機で走らせず起動前に空きメモリを確かめることを書く |
| 軽1 | 軽 | `test_range_rejections.py`・`test_range_budget_sources.py`・`test_range_known_differences.py` | 検査を `assert` で書いており、`PYTHONOPTIMIZE=1` で消える（`python3 -B -c "assert False"` が成功することを確かめた） | `require()` に置き換えるか、check-formal.sh での起動を `-I` にする |
| 軽2 | 軽 | 補助期待 firstStopPreorder と `formal_interval.py::range_counts` | 期待6・実測4の扱いは正しい（`ScopeMetrics.stops` は最初に各 Run が止まった文の先行順番号で、`typeck/scope/local.rs:148`・`:459`。4 が正しく、6 は拒否される射影の鍵との取り違え。Lean は停止の位置を持たない）。ただし `auxiliaryExpectedMismatchCount == len(auxiliaryExpectedMismatches)` は何も縛らず、inner の 13 がずれても通る | 不一致の集合を `{last-run-exceeded: 6→4}` に固定するか、定義に基づく訂正値を別の欄に置き（理由・判断者・日付、初稿は残す）、それとの一致を要求する |
| 軽3 | 軽 | `range-sources/expected.json` | 範囲の12群の `nonTopRangesMinimum` は一律に1で、results の 3/12/10/8 は観測値であり手で数えた期待ではない。request-retained が 12→1 になる部分的な退行を通す。Top の互換群のうち old-ip と user-spelling は 0 を固定していない | 手で数えた件数を期待に加え、old-ip と user-spelling に `nonTopRanges: 0` を加える。新しい手書きの期待として、追加の日付と理由を記録する |
| 軽4 | 軽 | Top の効果原子の入力 | effect-top は超過していないので Rust は unknownSource を返す。README の DET-05 の比較方法が求める、Lean の `atomFailure` が budgetExceeded になりうる側（由来が超過の Top 原子）の入力がない | 由来が超過の Top 原子の入力を1件加えて Rust の理由を記録するか、未検査として K10.3 へ申し送る |
| 軽5 | 軽 | `scripts/check/test_policy.py` | 新しい4つの呼び出しと `check_named.py::check_remaining_batch3` の4群が policy で固定されていない（`set -e` で失敗は伝播する） | K10.3 か後の作業で test_policy.py に加える |
| 軽6 | 軽 | 07-04・01-12 | 07-04 の398行の後に空行が二つある。新しい段落が `test_range_known_differences.py` を挙げていない。01-12 に足した「処理系との比較では…」は 07-04 と重なる | 空行を直し、台本を挙げる。01-12 は 07-04 への参照だけにしてもよい（任意） |
| 軽7 | 軽 | `k10.2/` の量、`exchange-manifest.json` | `k10.2/` は 3,027 ファイル・約57MB ある。参考: `exchange-manifest.json` の routing の期待値に、以前から手元の絶対パスを含む NoMainFile の場所が入っている（読者は場所の差を吸収するようになった） | コミットの前に生の記録を選別する。manifest も正規化してよい |
| 軽8 | 軽 | widen の初稿 | path-widen と request-retained の初稿は widen の結果を射影しており、`widenRule_sound` により unknownSource で拒否されるべき形である。入力の訂正は正しい | 初稿の形を拒否の群に1件加えるとよい（任意） |

## 問題がなかった点

- 独立入力と期待値: 初稿の `independent/expected.json` と今の29件は `sha256` 以外の差が0件、`report-expected.json` は初稿とバイト単位で一致、変わった入力は記録した3件だけ。RV-R40 中2 が挙げた欠けていた群はすべてそろった。
- 拒否理由の照合: 型付けの失敗を cover の理由へ変換せず、失敗を無視する catch-all もない。effect-top の Lean の原子の理由は null と記録し、作り出していない。`atomFailure` と `Required.ofIndex`（`ScopeAccept.lean` の61行と259行）は 07-04 の記述と一致する。
- 読者と全比較の接続: `test_range_exchange.py` は check-formal.sh から呼ばれる。batch3 の8経路はすべて通る。routing は1,792入力すべてで一致し、NoMainFile の正規化は相対の場所の完全な一致を要求する。旧版の互換の分岐と版14の意図した拒否の入力は残っている。
- 退行させた入力: host-one の範囲を全部 Top にした書き出しと、非 Top を `candidates` へ移しただけの書き出しの二通りで、どちらも `test_range_sources.py` が `host-one: all-Top range comparison` で失敗した。
- 既知の差と観測: k3 は R10.5 の宣言の同一性で対応付け、39件の消失と3件の追加を番号の差と分けて記録した。E0711 と U+0000 の除外は名指しした入力に限る。観測の文は DNS/TLS の副次的な通信を含めず、旧 Top の完全な観測を証明したとも書いていない。
- 検査の記録: check.sh 自身の終了1をそのまま記録した。作業末の検査の後に変えたのは check_named.py と check-formal.sh だけで、古くなるのは policy_selftest だけであり、やり直した範囲で足りる。formal_build の B-Lean からの引用は README の判断どおり。Rust の件数 1,462 は各ターゲットの件数と整合する。
- K10.3 の見込み: 30〜45分の根拠は実測と未実測を分けて書いており妥当である。Lean の六入口を全 corpus で動かす時間は未実測なので、見込みの2倍（90分）を見張りの目安にするとよい。
- 設計書と申し送り: 追加部分に作業の ID はなく、K10.3 への申し送りは計画の K10.3 の節と食い違わない。`k10.2/*.md` に切れた相対リンク・絶対パス・work/ の参照はない。

## 対応（取りまとめ）

| 指摘 | 対応 | 置き場所 |
|---|---|---|
| 中1 | 文言を限定する。機械の照合（契約だけを受理する形の実ソースの書き出しと手書き交換の一致）は、小さく済めば行い、済まなければ K10.3 へ申し送る | K10.2b |
| 中2 | K10.3 の起動依頼に書く | K10.3 |
| 軽1〜軽4・軽6・軽8 | 採る（軽4 は入力を加えられなければ K10.3 へ申し送る） | K10.2b |
| 軽5 | K10.3 で行う | K10.3 |
| 軽7 | 生の記録を選別し、大きなものは大きさと SHA-256 だけを残す。`exchange-manifest.json` の手元の場所を正規化する | K10.2b・取りまとめ |
