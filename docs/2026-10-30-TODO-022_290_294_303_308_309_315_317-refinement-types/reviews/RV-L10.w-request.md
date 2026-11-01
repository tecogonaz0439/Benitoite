# RV-L10.w 修正後のレビュー依頼

2026-11-01。L10 群W（L10.21〜L10.23）の RV-L10.w の中1・中2・軽1〜5を処置した。修正後の定義・言明・仮定と境界を独立にレビューしてほしい。[results](../l10/w/results.md) に所見ごとの処置と境界の実際の範囲を記録した。担当の自己点検を独立レビュー済みとは扱っていない。

指定ブランチは `m014/l10.w`、B_WORK は `d3a22dfb5dff5525888e4332e4bb978a4961074c`。git の操作、work、L10.24 への着手はしていない。レビュー原本 RV-L10.w.md、plan/detail、rv-w-* は変更していない。中1は plan の最新の取りまとめの判断を適用した。

## 所見ごとの修正箇所

| 所見 | 確認してほしい内容 |
|---|---|
| 中1 | ProgramTyping の ImplDecl.WellTyped は代入前の QTel ms.tel を使う。新しい ImplDecl.WellTyped.method_body が、同じ NamesWF の下で C_Meth が読む代入前の Qsig、正しい C・辞書文脈・値移動後の列の本体を返す。01-12 の既存の文と新節をそろえ、呼出し側の NoFail は増やしていない |
| 中2 | boundary の L10WDictionary/L10WCall は rv-w-t1/t4 の正例を本番の現行条件へ移した。L10WRows は NoFail の行条件を実際に読み、Def/Impl の行0の正例と行1の拒否を示す。行1も宣言の上限2の中である。L10WOrder は異なる二制約の順序を sat が読む。L10WConditions はレビューの未検査条件を埋める。初回の一つの program の例だけでこれらの受渡しまで検査したという説明は訂正した |
| 軽1 | ImplDecl.Scoped に、辞書型の value kind を追加した。Ghost のクラスの辞書が Annotation を通っても kind で拒否する。WellTyped の新しい信頼欄にはしていない |
| 軽2 | OpDecl.Scoped が dictParams の辞書型と params の先頭の一致を検査する。対応した先頭の正例と、添字は範囲内でも先頭が異なる負例がある |
| 軽3 | MetadataScoped の定義を変えず、公開境界の行変数を残さないこと、必要なら ne の扱いを見直すことを R10b の義務として results に残した |
| 軽4 | G08 の埋め込みに、宣言の本体がソース構文だけであり実行時専用構文を含まない入力を追加で明示する。旧 WellFormed/VarsIn だけから自動では得られない |
| 軽5 | 07-04 の工程 ID と01-12の未実施の照合の予告を除き、収集の完全性と原ソースとの一致を保証しないという現状を記述した。未実施の義務は改造の results に残した |

## 境界と変異の確認

本番の条件を複製した代替の定義を製品へ置いていない。境界は次の入口を分けている。

- L10WBoundary：同じ非空の program の Program.WellTyped/WellFormed。初回からの例である。
- L10WDictionary：辞書を返す実装全体の WellTyped。自身の型パラメータと、値引数の外側の辞書の位置を使う。
- L10WCall：辞書経由の本体 d.pm(x) の TelBodyTy と C_Meth。handler の下の escape も検査する。
- L10WRows：Admissible.noFailRows によって Q を読む本体。Def/Impl それぞれの正負。
- L10WOrder：異なる制約の C の順序を読む実装の正負。
- L10WConditions：Impl のメソッドの NamesWF、Con の Annotation/kind、Op の NamesWF/辞書添字/先頭、MethSig の NamesWF/kind、Impl の辞書添字/kind・target の範囲/注釈・super の範囲、publicBoundary の範囲、外部関数の正例。

明示的な補題は102本、拒否は50本である。初回の54本・拒否33本との違いも results に記した。範囲を正確に記述し、個別の本体の例を全プログラムの証明に繰り上げていない。

`mutations.py` は本番の一時コピーを実際に Lean に検査させる。無変異の対照は終了0、NoShift/NoValueMove/SwapC/QTrue/NoDict/DefQTrue/PostSubstitutionQ の七つは全て予定した箇所で終了1だった。五つのメソッド変異と旧 Q は、本番の method_body の補助契約で検出される。Def の変異は本番のコピーをコンパイルした後、境界の reject_definition_q の証明内で拒否されることを行番号でも照合する。

NoValueMove は閉じたソース署名では恒等であり、その受理集合の差の反例を主張しない。任意の WellTyped から WellFormed の追加なしで同じ移動後の列の本体を取り出す契約が、変異によって保てなくなる点を検査している。この検出範囲と、辞書・制約・Q を読む具体的な本体の正負を混同していないかも確認してほしい。

## 検査の証拠

| 実体 | 結果 | 証拠 |
|---|---|---|
| formal の既定の lake build | 終了0、753ジョブ、0.804秒 | [build-result](../l10/w/build-result.json)、[出力](../l10/w/build-output.txt) |
| 境界の正負と局所全宣言の公理依存 | 終了0、534宣言、3.787秒、警告0 | [boundary-result](../l10/w/boundary-result.json)、[出力](../l10/w/boundary-output.txt) |
| 全差分の二モジュール＋旧五主定理・三モデル＋主要10補題 | 終了0、112＋18＝130件、0.915秒 | [axioms-result](../l10/w/axioms-result.json)、[出力](../l10/w/axioms-output.txt) |
| 対照と七変異 | 全件予定どおり、12.932秒 | [mutations-result](../l10/w/mutations-result.json)、[大きい生記録](../l10/w/large-records.md) |

本番と境界の公理依存は計664件で、propext・Quot.sound・Classical.choice だけである。sorryAx・独自公理・未承認依存はない。個別の Lean プロセスに -M 12288、既定 build に同じ lakefile の上限を使った。意図的に型検査に失敗する一時コピーの診断は、本番の公理依存の成功に混ぜていない。

今回の開始時から保護する632件と、現行の検査入力517件のハッシュを前後で照合した。主な九ファイルと、22規則・76構成子・304枝は不変である。初回の immutable-inputs.json は初回の記録として保ち、今回の検査には review-immutable-inputs.json を使う。最大常駐量は未取得（計画上の非採取）。work と dry-run、Rust/Lean の全比較は実行していない。01-spec の text ブロックに変更はない。

再実行はリポジトリの根から `python3 docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/w/check.py` で行える。公理依存の列挙には新しい補題と自動生成された宣言も含む。

## 実装担当が追加したファイルの全一覧

本番の新規ファイルは次の二つで、今回の修正もこの二つにある。

- `formal/Benitoite/Release/Refinement/ProgramTyping.lean`
- `formal/Benitoite/Release/Refinement/ProgramWellFormed.lean`

改造の `l10/w/` 以下に実装担当が追加したファイルは次の19件である。初回の16件と今回の3件を含む。

| ファイル | 内容 |
|---|---|
| `signatures.md` | 最新の完全署名・条件と補助契約の判断 |
| `results.md` | 所見ごとの処置、各単位の判定、境界の範囲と送り先 |
| `boundary.lean` | 具体的な入口と一般の本体の条件の境界、公理依存 |
| `axioms.lean` | 全差分・旧主定理/三モデル・主要補題・場合の数の確認 |
| `check.py` | build/境界/公理依存/変異と入力の不変を確認する台本 |
| `mutations.py` | 今回追加。本番の一時コピーへの一変更ずつの変異検査 |
| `mutations-result.json` | 今回追加。対照と各変異の位置・終了・時間・診断・ハッシュ |
| `review-immutable-inputs.json` | 今回追加。レビュー修正の開始時から保護する632件 |
| `check-inputs.json` | 最新の検査入力517件のハッシュ |
| `immutable-inputs.json` | 初回の641件の記録。今回の不変の判定には使わない |
| `source-state.json` | 基準、初回と修正の変更範囲、最新の検査入力の識別 |
| `main-contracts.md` | 主要九ファイルと304枝の不変の確認 |
| `large-records.md` | 100 KB超の生記録の大きさとハッシュ |
| `build-output.txt` | 最終の既定ビルドの出力 |
| `build-result.json` | ビルドのコマンド・時刻・時間・終了・件数・ハッシュ |
| `boundary-output.txt` | 最終の境界と534宣言の公理依存の出力 |
| `boundary-result.json` | 境界の最終の実行結果 |
| `axioms-output.txt` | 130件の完全名・公理依存と規則数 |
| `axioms-result.json` | モジュール別の件数、許可依存、完全性の照合 |

本依頼 `reviews/RV-L10.w-request.md` を含め、実装担当が追加したファイルは合計22件である。取りまとめが置いた rv-w-t1〜t5・rv-w-hk/hk2 の7入力と、RV-L10.w.md は読み取り専用のレビューの証拠として保護している。100 KB超の変異の結合生出力は改造に置かず、large-records に大きさとハッシュを残した。

## 変更した既存の本番・規範

- `formal/Benitoite.lean`：初回に新二モジュールを追加。今回のレビュー修正では不変。
- `docs/design/01-spec/01-12-core-calculus.md`：定義の写し、代入前の Q、辞書 kind と操作の先頭、収集の保証の限界を記述。
- `docs/design/07-quality/07-04-formal-semantics.md`：同じ内容と対応表。工程の ID を除いた。
- `docs/design/00-overview/00-04-glossary.md`：「型注釈」の既存の行で、宣言の適格性に含める辞書の条件を明記。

取り込み前に、修正した定義と補助契約、負例と変異の検出範囲、原ソースの収集の保証の限界を確認してほしい。G08 のソース構文だけという入力、R10b の公開境界の行変数と原ソースの照合、G09 と全主定理・交換の接続は今回の完了へ繰り上げない。
