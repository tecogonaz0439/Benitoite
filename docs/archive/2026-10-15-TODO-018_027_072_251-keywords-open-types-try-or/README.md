# キーワード・構成子を増やせる型・try の失敗時の処置

## 目的と範囲

TODO-250 が推す順序 (1)(2) の調査、設計者の回答、詳しい設計、実装プランと実装の結果である。TODO-018、TODO-027 の失敗の型の照合、TODO-072 の構成子を増やせる型と互換性、TODO-251 を一つの改造として実装した。互換性を壊す変更の移行と版の上げを一度にまとめ、0.0.6 としてレビューできる状態にした。

TODO-249 は、失敗を型付きの値のまま捕捉する仕組みと、`or` の後の拡張・表示の役割を検討する範囲で含める。実装方式と具体的な新しい構文の確定は後の改造へ残す。TODO-027 のリソースの追加規則と IO の分類の見直し、TODO-072 の正式リリース条件全体は今回の範囲に含めない。TODO-191 は今回の網羅性の変更との関係だけを判断する。TODO-252 は次の互換性変更に伴って必要になる E0908 の修正として取り上げる。

## 状態

完了（2026-10-16）。準備、段 1 A、段 2 D、段 3 B2、移行・版・日本語訳の整合と M9 の結果の文書化を終えた。オーケストレータは `03177eff` で公開前の `scripts/check.sh --full` の成功を確認した。段ごとの実装、Q/R の主な決定、検査と G1〜G8 のレビュー、計画との差と残件は [results.md](results.md) にまとめた。M9 では検査を再実行していない。

旧移行器の自己検査の未達は、R75 と docs/todo の TODO-253 に従う既知の残件である。`fuzz/Cargo.lock` の古い依存の控え、TODO-249 の型付きの失敗の捕捉、TODO-028 の後の性能対策も残る。これらを今回解消したとは扱わない。タグ・公開、docs/todo の更新、改造の保管とコミットは、この完了に含めない。

調査の基準は `5ef09b51f4f5fabb321eab610ba0a709441d16eb`（0.0.5 公開後）である。study と decisions の提案本文は調査時点の記録として残した。そこにある「Kind 二型のみ」「例の書き直しは任意」「18〜28 作業の粗い見込み」は、設計者の回答と design.md・plan.md が更新する。plan.md は枝分け後の実装 48 作業と親の完了確認 4 件、G1〜G8（G3・G5 は前後半）のレビューを定める。実装の実績と最終状態は results.md、現在の仕様は docs/design を読む。

Q6 に従い裸の try の返却の意味と検査を保ち、現行の手本を明示形へ移行した。Q12・R2 に従う @extensible の標準の対象は IOErrorKind・NetworkErrorKind・Json.ParseError・Csv.ParseError の四型であり、新たに包括的な分岐が必要な既存の照合は調査範囲で各 0 件だった。record の構築・更新・getter を保ち、欄や構成子の追加の互換性を約束しない制限も実装と文書へ反映した。

## 文書の一覧

| 文書 | 内容 |
|---|---|
| [results.md](results.md) | 実装の結果、Q/R の主な決定、検査・レビュー、残件とレビュー対象 |
| [todo-items.md](todo-items.md) | 六項目の本文の写しと、関係する TODO-191・252 の補足 |
| [decisions.md](decisions.md) | Q1〜Q20 の提案と設計者の回答、実装・レビューで補足した R1〜R82 と推す案 |
| [design.md](design.md) | 各段の文法・型・網羅性・実行・形式化・移行の詳しい設計、四失敗型と件数 |
| [plan.md](plan.md) | P/A/D/B/M の実装 48 作業と親の完了確認 4 件、共通の関門、G1〜G8、段ごとの検査 |
| [reviews/](reviews/) | G1〜G8 のレビュー報告と指摘への対応 |
| [study/lexical.md](study/lexical.md) | 現在の 34 語、文脈で読む語、綴りと追加候補の衝突 |
| [study/try-and-exit.md](study/try-and-exit.md) | try の型検査・脱糖・コード生成、入口・停止・報告、249 との役割 |
| [study/open-types.md](study/open-types.md) | 網羅性の現在の判定、構成子の追加、指定と互換性の案 |
| [study/formal.md](study/formal.md) | 形式化の内外、Lean の直接修正の候補、検証の範囲 |
| [study/prior-art.md](study/prior-art.md) | 一次資料で確認した他言語の扱いと、その比較からの判断材料 |
| [study/migration-and-size.md](study/migration-and-size.md) | 既存入力の量、前回の教訓、移行手順と改造の規模 |
| [study/inventory.py](study/inventory.py) | 既存のホスト抽出を使う読み取り専用の集計 |
| [study/inventory.json](study/inventory.json) | 基準コミット、候補の位置・入力のハッシュ・分類別の件数 |
| [study/failure-types.py](study/failure-types.py) | Q12 の追加調査。全公開 data/record、失敗型の語と照合の候補を抽出 |
| [study/failure-types.json](study/failure-types.json) | 1,195 入力のハッシュ、22 宣言、163 候補、既存照合 6 件 |

判断は [00-01「目的と設計原則」](../design/00-overview/00-01-goals.md) と現行の実装を根拠にする。前回の改造の記録は、進め方と失敗の調査に用い、現在の言語仕様の根拠にはしない。外部の事実は `study/prior-art.md` に出典と確認日を示す。

## 設計時点の確認（2026-10-15）

`scripts/check.sh --dry-run` は、origin/san_benito との差 15 ファイル（前回の調査分を含む）を文書のみと判定し、処理系の検査を選ばなかった。続けて `scripts/check.sh` が成功した。Rust/Lean のビルドや処理系のテストを通したという意味ではない。

今回の作業ツリーの変更はこのディレクトリ内の 6 ファイルだけである。Q1〜Q20 の回答 20 件、R1〜R8、作業 39 件の必須欄と依存の順、G1〜G8 のまとまり（5・4・5・5・6・4・5・5 作業）、計画に記した cargo test のターゲットの実在、相対リンクを確認した。新診断 E0258・E0259・E0511・E0817 は現行の定義と衝突しない。

追加集計を読み取りで再実行し、保存した JSON と一致した。元入力 1,195 ファイルのハッシュ、22 宣言、163 候補、6 照合を照合し、study の Python の構文も確認した。git diff --check は成功した。処理系・現行設計書・テスト・formal・docs/todo の変更、コミットはない。

## P1 の実装記録

P1 の基準を HEAD `dc375420073cf71f8fcd0a85aa4c29c19078715e` で確定した。上の「状態」「今回の確認」は設計時点の記録である。P1 の入力ハッシュ・四失敗型・裸の検査・前回のレビューと関門の対応は [p1/baseline.md](p1/baseline.md)、全候補の確認表は [p1/migration.md](p1/migration.md)、全追跡入力と Cargo のターゲットは [p1/inputs.json](p1/inputs.json) にある。[p1/inventory.py](p1/inventory.py) は一覧を標準出力へ出す調査用の道具であり、通常の検査からは読まない。実行したコマンド・結果・申し送りは [p1/results.md](p1/results.md) に記す。

## P2 の実装記録

P2 は HEAD `daa50081364b9cbd3962ed473390d7cdf61d18af` で型・依存・診断・形式化を照合した。[p2/types-and-dependencies.md](p2/types-and-dependencies.md) に型変更表の構築・使用箇所と具体的な依存の列、[p2/formal.md](p2/formal.md) に D/B の定義・定理の差分案と六入口、[p2/diagnostics.md](p2/diagnostics.md) に診断の登録先と旧→新の対応案を記す。検索位置と入力ハッシュは [p2/uses.json](p2/uses.json)、読み取り調査の再実行は [p2/inventory.py](p2/inventory.py)、検査結果と申し送りは [p2/results.md](p2/results.md) にある。R19・R20 は今回追加した推す案であり、処理系・テスト・formal の実装は変更していない。

## A1 の実装記録

A1 で die 一語を予約し、名前としての使用を E0216 で拒否した。単独の式と try の処置はまだ受理しない。変更したファイル、KwTry の全 14 箇所の確認、診断の対応、test-audit の関門、検査結果と申し送りは [a1/results.md](a1/results.md) に記す。識別子かどうかを先に判定する入口の接続を R21 に補足し、静的診断の終了状態は現行仕様の 2 を保つ訂正を R22 に記した。

## A2 の実装記録

A2 では formatter が共通の lexer・parser と AST を使うことを確認し、本体の変更を要しなかった。既存の CLI の表へ、予約語を名前にした入力の拒否とファイルの保存、識別子 fn・Boolean or・短い lambda の整形と冪等性の検査を追加した。調査の根拠、test-audit の関門、検査結果と申し送りは [a2/results.md](a2/results.md) に記す。

## A4 の実装記録

A4 では R13 の回答 B に従い、return 直後の物理改行を文末にし、値を同じ物理行で書き始める規則を実装した。E0201 の案内、既存の WIT 入力24箇所の移行、文書と生成物の更新、test-audit の関門、検査と後続への申し送りは [a4/results.md](a4/results.md) に記す。調査時の候補・入力ハッシュ・P1 との差は [a4/return-inputs-before.json](a4/return-inputs-before.json) にある。

## 保管のときに除いたファイル

保管のときに、100 KB を超える機械の出力（JSON）12 件を除いた: `m3/manifest.json`、`m4/final-inventory.json`、`m4/inventory-before.json`、`m4/manifest.json`、`m5/audit.json`、`m5/reconciliation.json`、`m6a/inventory.json`、`m8/audit.json`、`p1/inputs.json`、`p2/uses.json`、`study/failure-types.json`、`study/inventory.json`。除く前のコミット 04cd2090 にある。
