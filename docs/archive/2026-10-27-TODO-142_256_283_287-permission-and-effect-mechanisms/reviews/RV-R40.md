# RV-R40: R40 の段全体（R40.1〜R40.3）の独立レビュー

2026-10-29。対象は本線の `c2debc92..867a3671`（R40.1・R40.2 の取り込み）と、R40.3 の未コミットの差分、r40.1〜r40.3 と r40 の results.md、RV-R40.1・RV-R40.2。作業用のディレクトリは書き換えず、R40.3 の作業ツリーをレビュー用の target でビルドして入力を通した。入力は `r40/rv-probes/` に写した（`chk.py` は `r40.3/handoff.json` の25入力を check と test の両方の報告で照合する台本、`docs2.bnt` は中1 の再現）。

結論: 重大0・中2・軽5。中1 を小さな文書の追補で直すことを条件に、R40 の段を閉じて K10 へ進んでよい。中2 は K10.2 の依頼文で受け持てば足りる。

## 指摘

| 番号 | 重さ | 箇所 | 問題 | 修正案 |
|---|---|---|---|---|
| 中1 | 中 | 06-04「check 例の契約は例の報告に保持する」と `skill/references/inspection.md` の "A `check` example retains its contract in the example report"（R40.2b で加えた文）。実装は `cli/tools/test_runner/docs/prepare.rs` の入口の選択（`require_main` でも `Expectation::Test` でもなければ空） | `benitoite check` の doc 例は、`main() uses File.Read["/data/**"]` と `@test uses File.Read["/data/a"]` を持っていても、`effects` が `{"expanded":[],"bounds":[]}`、`tests` が `[]` になる（`docs2.bnt`）。test 例と run 例は宣言上限を正しく出す。文書の主張は実装と食い違い、空の Effects は純粋な契約とも読める。RV-R40.2 中1 は error 例しか扱わず、R40.2b がこの「保持」を check 例に限ったため誤りが残った。集約は check 例を除くので実行の上限は誤らない | 案 A（推す。意味と互換を変えない）: 06-01・06-04・inspection.md を「check/error 例は入口を選ばず空の Effects を返す。この空は純粋を意味しない」と直し、固定入力に check 例を一件足す。案 B: check 例の main またはテストの契約を報告する（報告の意味が変わるので相談が要る） |
| 中2 | 中 | `r40.3/handoff.md`・`handoff.json`（25入力）と r40/results の「K10 用の25入力」 | 固定した入力は CLI の報告（終了・Effects・コード・理由）の部分集合で、K10.2 が挙げる比較の群に足りない。欠けているもの: host の one/many・IP の exact/CIDR・v6・ポート範囲・mapped の拒否、`Http.checkRequestIn`/`widenRequestIn`/射影、widen の受理と拒否、旧 Scope の IP と E0459〜E0462、同じ綴りの利用者関数、略記と実ソースの位置、番号付けの停止と最後の Run の超過の区別、内側だけの超過。期待値は Lean 側の値（Required の添字、cover、nonTopRanges）を持たない。期待値の独立性は確かめた（`freeze-inputs.py` に手で書いてあり CLI を呼ばない。初稿は初回の実行の前に保存され、訂正で変わった期待値は0件） | K10.2 の依頼文で「25入力は報告側の部分集合。上記の群の独立入力と期待値を、実行の前に K10.2 で固定する」と明記する。r40/results の「K10 用」も「報告側の固定入力」と限定する |
| 軽1 | 軽 | `tools/bench/results/2026-10-29-10101dac-m013-r40-2/results.md` の取りまとめの確かめ | 「検査と実行の経路は変えていない」とあるが、R40.2 は `builtins/funcs/file.rs` の範囲付きの読み書きの入口名を渡す実行経路を変えた。r40/results の S-40 の判定はこの変更を根拠に5対象を実行し直しており、記述が矛盾する | 「実行経路の変更は資源停止の報告の名前の受け渡しだけ」と直す |
| 軽2 | 軽 | 段末の short（計画の M の行は段末を R40.3 とする） | R40.3 は short を取らず、要否と段の退行の判断を取りまとめへ渡した | R40.3 の変更はテスト・埋め込む Skill の文・06-06 だけなので M は対象外と理由を書いて省いてよい。段の判断は r40/results に一文で閉じる。中央値の比は R30.4 後 1.043 → R40.1 後 1.048 → R40.2 後 1.045 で、退行の疑いの族は同じ（Trait の費用、TODO-304、`interval-http`） |
| 軽3 | 軽 | `SKILL.md`・`idioms.md` の狭い引数の案内（R40.3） | "widen the bound checked value in the caller and give the parameter that wider type" は関数の引数には当てはまるが、節の引数には呼び出し元がなく型は操作の宣言で決まる。節を Top にするには保護本体も Top が要るという限定（02-10 と E0519 の help にある）も落ちた | 節の引数は「操作の宣言の引数の型を変える」と分けて書き、Top にする場合の限定を一句足す |
| 軽4 | 軽 | 06-06 の 156 行（R40.3）「名前解決後の実体をこの範囲から保証しない」 | 「名前解決」は言語の名前解決とも読める | 「シンボリックリンクを解決した後のファイルや、DNS で解決した後の接続先」と具体的に書く |
| 軽5 | 軽 | E0519 の純粋な必須判定の表示（unknownSource の入力） | ラベル "`Scope.pathInValue` is not covered by `the annotated scope contract (requiredUpperBound)`" は説明の句を逆引用符で囲む。注記 "scope call: .sample at surface preorder 0" は先頭の点と内部の語が利用者向けの文に出る。02-05 が先行順番号を示すと定める範囲で、誤りではない | 文言の見直しの候補として V10 へ |

## 問題がなかった点

- 全接点: 固定25入力を独自の照合で `check --report=json` と `test --check --report=json` に通し、終了・complete・Effects・コード・理由がすべて期待と一致した（doc-error は test の側）。混在する集約（Top・pathTree・host one と 1..1024・IPv4 CIDR /8）は被覆で間引かず DET-06 の形で並ぶ。名前による照合は run と test で受理し、不足は E0512・終了2、範囲付きの引数は使い方の誤り（終了2）。処理済みの利用者名は bounds・名前集合・集約へ戻らない。run 例と test 例の doc の Effects は正しい。
- Lean との一致: `atomic-cover-only.bnt` が atomicCoverOnly になるのは `atomFailure` の「同名の非 Top の閉じた原子が二つ以上」の条件と一致し、主文も和の被覆を判定しないと書く。Top の効果原子は unknownSource（Lean では由来の超過から budgetExceeded もありうる差は K10.2 への申し送りにある）。
- 診断の案内: E0519 の Top と unknownSource の help、E0513、E0407 の種類別の help、E0401 ScopeResult の向きを確かめた。
- 前段の指摘: RV-R40.1 の中1〜中3・軽1〜軽8 と RV-R40.2 の中1・軽1〜軽3・参考1 は本線で閉じ、参考2 は R40.3 でそろえた。
- 検査の記録: W-40 の記録した差分は今の作業ツリーと一致し、check.sh 自身の終了は0。S-40 は残る5対象を実行（64成功）し、3対象を同じ関係状態の W-40 から引用（100成功）。07-03 の欄はそろい、R30 の古い結果は引用していない。
- 文書と規約: 設計書と Skill に作業の ID はなく、型の範囲を実行時の権限・隔離・情報フロー制御と説明していない。E0521 は「収束を保証しない」だけを残す。由来の追加欄を加えていない。

## 対応（取りまとめ）

| 指摘 | 対応 | 置き場所 |
|---|---|---|
| 中1 | 案 A を採る（報告の意味と互換を変えない。RV-R40.2 中1 と同じ扱い） | R40.3b |
| 中2 | K10.2 の依頼文に入れる。r40/results の「K10 用」の文を限定する | K10.2・R40.3b |
| 軽1 | 取りまとめが記録を訂正した | 取りまとめ |
| 軽2 | R40.3 は出荷のバイナリに埋め込む Skill の文を変えたので、取り込みの後に short を一度取り、段の判断を r40/results に書き足す | 取りまとめ |
| 軽3・軽4 | 採る | R40.3b |
| 軽5 | V10 の文言の見直しへ | V10 |
