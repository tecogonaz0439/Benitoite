# 実装と公開前の最終結果

## 基準と状態

2026-10-17。実装・移行・文書の更新と公開前の全体検査を完了した。最終の処理系の基準は、Z7 を取り込んだ `san_benito` の `265505bbd2f80381a697f39192b3168165ce1a20` である。F2 はこのコミットから文書だけを更新した。**0.0.7 は未公開・タグなし**であり、タグ・push・保管・docs/todo の閉鎖は行っていない。

[設計](design.md)・[判断](decisions.md)・[計画](plan.md) を、[F1 の契約表](f1/contracts.md)・[入力表](f1/inputs.md) と各作業の結果へ対応させた。外部へ伝える契約と出力例は [harness-response.md](harness-response.md) にまとめる。例の採取元は `b2b7fe383b192efadc77d8bf3556e84f2ba413b2` からの作業ツリーのままとし、最終検査の基準へ数字だけを置換していない。Z7 後の E0908 の help は現在の版を案内する文言であり、変更前の採取記録は過去の実出力として保持する。

## 全作業とレビューの処置

計画の35作業は次のとおりである。作業ごとの型・契約・変更ファイル・個別検査は各結果に記す。

| まとまり | 作業の結果 | 実装・照合した内容 |
|---|---|---|
| 準備・版 | [P1](p1/results.md)・[P2](p2/results.md)・[V1a](v1a/results.md)・[V1b](v1b/results.md)・[V2](v2/results.md) | 入力と契約の基準、ビルド情報、形式の問い合わせ |
| main | [C1a](c1a/results.md)・[C1b](c1b/results.md)・[C2a](c2a/results.md)・[C2b](c2b/results.md)・[C3](c3/results.md) | 一回の検査から非実行の main 報告、ソースのハッシュ、失敗報告 |
| test | [T1a](t1a/results.md)・[T1b](t1b/results.md)・[T1c](t1c/results.md)・[T2a](t2a/results.md)・[T2b](t2b/results.md)・[T3](t3/results.md) | 通常実行と同じ対象選択、非実行の検査と部分結果 |
| 上限 | [A1](a1/results.md)・[A2a](a2a/results.md)・[A2b](a2b/results.md)・[A3](a3/results.md)・[A4](a4/results.md) | 正規名の包含、E0512、run の同じ成果物、test 全体の開始条件 |
| 環境・Skill | [E1](e1/results.md)・[S1](s1/results.md)・[S2](s2/results.md) | 明示したローダ変数の拒否と継承、全62文書の取得とハッシュ |
| 文書 | [D1](d1/results.md)・[D2a](d2a/results.md)・[D2b](d2b/results.md)・[D3](d3/results.md) | 現行設計・英語リファレンス・生成物・外部への回答の照合 |
| 移行・完了 | [M1](m1/results.md)・[M2a](m2a/results.md)・[M2b](m2b/results.md)・[M3a](m3a/results.md)・[M3b](m3b/results.md)・[F1](f1/results.md)・[F2](f2/results.md) | E0908、0.0.7 の一度の更新、固定ハッシュ、七組の訳、最終照合 |

六機能を実装し、全九 formats の版1を公開 CLI へ接続した。通常入力・英語正・生成物・七組の日本語訳を0.0.7へ揃え、正の固定ハッシュと意図した不一致・旧版・未来版の入力を照合した。未分類と通常入力の旧版の取り残しはない。詳細は F1 の確認表に記す。

| レビュー | 主な指摘 | 処置 |
|---|---|---|
| [G1](reviews/G1.md) | 監視登録、HEAD の reflog、ビルドの独立検査 | [Z1](z1/results.md) で修正 |
| [G2](reviews/G2.md) | main:null と shell、診断・正規名の共通化、CLI の対照 | [Z2](z2/results.md) で修正 |
| [G3](reviews/G3.md) | 入口ごとのソース解放、状態、公開解析入口、重複した確認 | [Z3](z3/results.md) で修正。暫定の上限の扱いは A1 で解消 |
| [G4](reviews/G4.md) | run/test の説明、fmt の拒否、中断の読み口、契約抽出 | [Z4](z4/results.md) で修正。決定的な入力がない内部エラーの経路は未実測と記録 |
| [G5](reviews/G5.md) | 回答の提供状態、Skill の文書範囲、引数の対照 | [Z5](z5/results.md) で処置。既存の制御文字の表示は R27 に従い保持 |
| [G6](reviews/G6.md) | 外部契約の説明、Skill の手順と参照文書、検査範囲 | [Z6](z6/results.md) で修正。R29 の LLM 評価は設計者の判断待ち |
| [G7](reviews/G7.md) | E0908 の help、上限付きの説明、移行案内、訳 | [Z7](z7/results.md) で軽微な L1〜L4 を修正 |

G1〜G7 の指摘に対する未処置の実装修正はない。G7 は M1〜F1 のレビューであり、F2 の完了記録の確認まで実施済みとはしない。F2 はオーケストレータの最終確認へ渡す。

## 最終検査

以下はオーケストレータが Z7 取り込み後の基準コミットで行った結果である。申し送りに加え、生の出力の終了文と両構成の件数を F2 で確認した。F2 自身の個別検査とは区別する。

| コマンド・構成 | 結果 |
|---|---|
| `scripts/check.sh --full` | 終了状態0、68分、`all checks passed` |
| `cargo test --workspace --all-targets`（既定構成） | 2631 passed、0 failed、49 ignored |
| `cargo test --workspace --no-default-features --features gc-mark-sweep,heap-verify --all-targets` | 2645 passed、0 failed、49 ignored |

全体で87分であった。full は format、lint（mark-sweep と既定）、テスト（mark-sweep）、gc-stress、仮置きの許可と unsafe_code の場所、既定構成の lib テスト、長いテスト、release の測ったスタックのテスト、licenses、spec_examples、reference_examples、生成した Skill、spec coverage、skill-eval の自己検査、Python の道具を含む。初回リリース版の受け入れ条件の未記入はない。既存の ignore を変更して成功させたものではない。

G1〜G6 の各レビュー段と Z6 後の段末検査はすべて通った（各36〜57分）。G7 の段（M1〜F1）は設計者の指摘により段末を省き、Z7 後の公開前 full に一本化した。F1 の空欄もこの分担と実績で埋めた。省いた --only や段末の dry-run の実績は作らない。検査の方針の見直しは別の項目にした。この計画との差は R31 に記録した。

F2 では指定された既定構成の lib・関係する8統合テスト・clippy・fmt と、文書のリンク・JSON・表・差分を確認した。最終結果は [f2/results.md](f2/results.md) に記す。F2 は処理系・テスト・生成物を変えず、check.sh・全体の cargo test・gc-stress を再実行しない。

## 形式化の判定

R4 の判定を維持する。改造前の `f31dacd3bddadfb692abd0b2ea31002128f64c4f` からの差分で pipeline.rs・syntax/・resolve/・desugar/・formal/・07-04・01-12 に変更はない。types/ の変更はエフェクトの正規名の表示の共通化、typeck/pattern_ext.rs の変更はテスト内の language 宣言を0.0.7にした一行だけである。型の受理規則・推論・脱糖・コア計算への写しを変えていないため、07-04「01-12 との対応」の表の追加、Lean の定義・証明の変更、lake build は不要と判断した。

## 保証の限界と残件

| 項目 | 実装の性質と限界 |
|---|---|
| メモリと開始時間 | 上限付き test は全入口のコンパイル済みプログラム・ソース・テスト一覧・AssertTable 等を全体準備完了まで保持する。入口数に応じてメモリと開始前の時間が増える。上限なし test は逐次準備・実行を保つ。非実行の報告は入口ごとに SourceTable を解放するが、出力のソース情報は大きくなり得る |
| commit と dirty | 存在する HEAD/ref/packed-refs/logs/HEAD のみ監視する。登録したファイルが変わらない更新は検知できず、由来 git の古い commit が残る場合がある。明示入力の変更か clean build が必要となる。dirty は未指定なら null/notCollected であり、clean の証明ではない |
| 同じエフェクト集合内の変更 | 上限は宣言上限との包含だけを確かめる。同じ File.Write の書込先・内容や、同じ Process.Run の起動先・shell 参照の変更は拒まない。検査後のソースを固定せず、複数入口の同時点のスナップショットも保証しない |
| 環境の継承 | DYLD_/LD_ の明示設定を大小無視で InvalidInput とするが、親の継承と shell の継承を変えない。LD_RUN_PATH・同値の再設定・空値も拒む。Process.Run を許すと env やシェルで再設定できる。PATH・孫プロセス・操作の対象の隔離は保証しない |
| shell と権限 | shell の式の参照はプログラム全体を調べ、到達性は解析しない。静的な照合は実行時の権限制御や OS のサンドボックスを提供しない |

最終の全体検査に未解消の失敗や、既知の基準の失敗として除外した項目はない。ただし、次を検査成功に含めない。

- **未実施の評価**: LLM を呼ぶ skill-eval は設計者の了承がなく未実施である。R29 で Skill の手順を変えた効果を評価するかは設計者が判断する。自己検査は実施済みだが、生成・修正の成功率の評価とは区別する。ハーネス側の接続確認は提供後の分担であり、今回行っていない。
- **既知の限界と未実測の経路**: 使い方の誤りの一部で制御文字を生のまま表示する既存の挙動は R27 に従い保持した。標準ソース内の誤りと、上限付き test の対象確定後の内部エラーの専用入力は、test-audit に合う決定的な入力がなく追加していない。後者の終了状態3・filesNotRun=N を専用試験で実測したとはしない（G3・Z4 の記録参照）。
- **範囲外の後の作業**: 旧移行器の基準データと fuzz の古い lock は既存の別件である。公開、タグ、push、保管、docs/todo の閉鎖も別の明示指示へ委ねる。
