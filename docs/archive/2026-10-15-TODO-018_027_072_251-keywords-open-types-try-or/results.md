# TODO-250 第 1 弾の実装の結果

2026-10-16、M9 の文書化を完了した。開始時の HEAD は `03177eff`（Z10 の取り込み後）で、作業ツリーに変更はなかった。準備 → A → D → B2 → 移行・0.0.6 の整合を終え、実装・検査・移行を一つの版としてレビューできる状態にした。タグ・公開は行っていない。

本書は各作業・レビューの記録と、M9 の依頼に添えられたオーケストレータの検査・測定の申し送りを集約したものである。M9 では cargo・check.sh（dry-run を含む）・lake・gc-stress の検査、性能測定、LLM を呼ぶ評価を実行していない。以下の既存の結果を M9 による再実行の結果とは扱わない。

M9 の文書の確認では、`git diff --check` が成功した。README.md と本書のローカルリンク64件（見出しへのリンクを含む）、末尾の空白・改行、引用した6コミットの存在も読み取りで確認した。変更はこの2ファイルだけである。

## 段ごとの実装

| 段 | 実装した内容と確認先 |
|---|---|
| 準備 P1・P2 | 入力・四失敗型・裸の try の検査の基準、型と依存の変更範囲、診断と形式化の六入口を固定した。[P1](p1/results.md)・[P2](p2/results.md) に基準と確認表を残した |
| 段 1 A1〜A4 | die を予約し、キーワードを35語にした。名前は E0216、単独の die の式は E0201 で拒否する。fn・pub・impl などの識別子と短い lambda は維持した。return 直後の物理改行で文を終え、値は同じ物理行で書き始める規則と整形・診断を接続し、wit-transfer の6ファイル・24箇所を移行した。[A4](a4/results.md) |
| 段 2 D1〜D9 | Lean の Coverage view・将来の形・本体ごとの宣言表と健全性を先行して変更した。Rust の所属判定・型表・属性・網羅性・束縛・到達可能性へ接続し、四つの標準の失敗型に @extensible を付けた。入れ子と外部パッケージ、record の生成 API、診断・文書・交換出力を揃えた。[D9](d9/results.md) |
| 段 3 B1〜B14 | Lean の die の型・エフェクト・脱糖と checker を先行して変更した。裸の try と or return を同じ返却に保ち、or die と任意の純粋な String の説明を実装した。Show の辞書、内部依存、IR・バイトコード・liveness、VM/Direct/Request と参照インタプリタへ接続した。終了情報を呼び出し単位で保持し、CLI・test runner・解放・flush の報告を揃えた。[B12](b12/results.md)・[B14](b14/results.md) |
| 移行 M1〜M5 | source-migrate の共通部分と try-actions-migrate を作り、確認済み manifest に基づく適用へ分けた。文書・Skill・実行例・現行 tools・再利用する標準ライブラリの手本を明示形へ直し、裸の try の検査を保持した。生成物の再現性、全候補の分類、診断の旧→新を照合した。[M3](m3/review.md)・[M4](m4/review.md)・[M5](m5/results.md)。旧移行器の未達は後述する |
| 版・翻訳 M6〜M8 | E0908 を変更ごとの複数の案内にし、版と通常入力80ファイル・固定ハッシュ3組を同時に0.0.6へ揃えた。英語版と日本語訳6組を照合し、移行手順を CHANGELOG にまとめた。[M6a](m6a/review.md)・[M7](m7/results.md)・[M8](m8/results.md) |
| M9 | 本書を追加し、README.md の状態を完了へ更新した。処理系・テスト・formal/・docs/todo/ の変更はない |

## Q/R の主な決定と実装の対応

[decisions.md](decisions.md) の設計者の回答と R の推す案は区別して読む。Q6・Q12 の回答は当初の提案を修正している。主な決定と、実装・レビューで補った判断は次のとおりである。

| 問い・補足 | 最終の内容 |
|---|---|
| Q1〜Q5・R13 | 既存の長い語と lambda を保ち、die 一語を予約した。R13 の回答 B により、普通の return と or return の後で同じ物理改行の規則を使う。値を書き始めた後の複数行は維持する |
| Q6・R1 | 裸の try は失敗を囲む関数から返す固定した省略として残す。手本では入口・一回限りの処理を die、再利用を return とし、戻り値・uses・出力の契約を確認して移行した |
| Q7〜Q11・R3・R4・R18・R55・R56・R70 | die は任意の戻り値の関数内で使え、Process.Exit を足す。失敗側だけで説明→Show→既存の exit を評価し、原因・任意の説明・位置を所有した文字列等で結果へ残す。既定は終了状態1。ハンドラで処理した呼び出しの情報を後の終了へ混ぜず、CLI と test runner で重複描画しない |
| Q12〜Q15・R2・R9・R34 | IOErrorKind・NetworkErrorKind・Json.ParseError・Csv.ParseError の四型へ属性を付けた。既存の外部の照合6件は包括的な分岐を持ち、追加が必要な照合は各型0件だった。外部では将来の形を変数か _ で覆う。record の .. は将来の形を覆わず、record の欄・構成子追加の互換性は約束しない。WIT の構造照合は厳密なままである |
| Q16・Q17・R8・R10・R12・R50 | 範囲パターンの TODO-191 の規則を維持し、D/B2 は既存の Lean のモデルを直接変更した。D は corpus 9、B2 は corpus 10、型表3・網羅性3へ接続した。定義・言明のレビューを経て Rust の意味変更へ進めた |
| Q18・R75〜R80 | 元の UTF-8 バイト位置・ハッシュ・承認済み manifest による移行を採用した。記法・歴史資料・検査・生成断片を分類し、未解析の実行用 fence も保留する。旧 named-arguments-migrate の基準依存による失敗は TODO-253 として残した |
| Q19・Q20・R17・R81・R82 | 全段を0.0.6へまとめ、宣言版より後から現在以下の全変更を E0908 で版順に案内する。0.0.5 の案内も CHANGELOG の該当節を指す。通常入力と固定ハッシュを同時に更新し、旧・未来・不正な版の検査を保った。fuzz/Cargo.lock の再解決は別作業に残した |
| R71（Z7） | IOError・NetworkError の Show を Trait へ移し、prelude からの Trait の import を除いた。Json/Csv の Show は各モジュールに置き、四型とも message をそのまま返す。表示の契約を保ちながら全入力の読み込み・型検査の退行を修正した |

型・受け渡しの変更は [design.md「変更する型と受け渡し」](design.md#変更する型と受け渡し) と P2、その後の R の補足で追跡できる。診断の対応は [m5/diagnostics.md](m5/diagnostics.md)、版の期待値と維持先は [m6a/review.md](m6a/review.md) に集約している。M9 による型・シグネチャ・診断の仕様変更や追加の設計判断はなく、新しい R は追加していない。

## 検査と測定の記録

次の段末・公開前の検査はオーケストレータが実行し、すべて成功した（2026-10-16）。各コミットは実行時点を示す。

| 実行時点 | 検査 | 結果 |
|---|---|---|
| 段 2、`d1ad4b0e` | `scripts/check.sh --only rust,default_lib,spec_examples,skill,spec_coverage,formal` | 成功、34分 |
| 段 3、`ee1b8243` | `scripts/check.sh --only rust,default_lib,spec_examples,reference_examples,skill,spec_coverage,formal` | 成功、36分 |
| 同上 | `bash scripts/check-formal.sh` | 成功、14分。六入口と破損入力の拒否を照合 |
| M5、`bd9be1d0` | `scripts/check.sh --only rust,spec_examples,reference_examples,skill,spec_coverage,skill_eval,python` | 成功、35分。skill_eval は自己検査であり、LLM を呼ぶ評価ではない |
| M9 の前倒し、`e1330805` | `scripts/check.sh --only licenses,formal` と `bash scripts/check-formal.sh` | 成功、14分 |
| Z10 後、`03177eff` | `scripts/check.sh --full` | 成功、65分、all checks passed。最終の版・訳・レビュー修正を含むツリーで確認済み |

共通の関門 K の lib・関連統合テスト・Clippy・fmt、および両構成の all-targets の個別の実績は各作業の results.md にある。特に [M7](m7/results.md) は既定の全ターゲット2,590件と gc-mark-sweep,heap-verify の2,604件の成功を記録し、[G8 の Z10 対応](reviews/G8-report.md#対応) は lib 1,194件、関連5統合テスト計27件、Clippy・fmt・gen_skill の成功を記録する。既存の ignore 件数は各記録で区別しており、新たな ignore で通したものではない。M9 では依頼の明示的な指定に従い、これらを再実行しなかった。

形式化の六入口の件数と対象外理由は [M7 の記録](m7/results.md) で次のとおり照合済みであり、前倒しの最終 check-formal も成功している。

| 入口 | 記録した結果 |
|---|---|
| desugarDiff | 全1,741入力中、golden 352件と乱択1,000件が対象内、既存の静的エラー389件、範囲外0件。73,753定義が一致 |
| builtinCheck | 対象内1,352入力、72,600比較が一致。不一致・非収束・誤り0件 |
| coverageDiff | 通常10,020件、view付き10,028件が一致。不一致・燃料切れ0件 |
| coverageProgramDiff | 対象内1,352入力、match 16,417件・bind 6,036件の計22,453件が一致 |
| surfaceCheck | 全1,741入力の成功・除外・既知の拒否が manifest と一致 |
| surfaceCheckAll | 51,652件一致。既存の対象外19件と Q11 の1件を理由ごとに維持 |

独立した正負の交換入力と、契約・hole/pipe・名前付き呼び出し・外部型の view 欠落の破損入力の拒否も成功している。新しい axiom・sorry・admit・native_decide や定理の弱化はない。型保存の証明の範囲と、評価順・実際の終了・解放・報告を Rust の実行で確認する範囲は、01-12 と07-04に記録した。

短い性能測定はオーケストレータが gate.py で `v0.0.5` と `4836bbba` を比較した。各10回の中央値は fib が1.917→1.912秒、loop が1.018→0.989秒だった。この二入力の結果を全ワークロードの性能保証とは扱わない。G5b の重大指摘となった B10-3 の起動時の退行は R71・Z7 で修正し、check の時間が戻ったこともオーケストレータが実測した。Z7 の lib は77.21秒、random_programs は50.18秒で成功し、60秒の制限・入力数・coverage を保った。

## レビューと移行の照合

| レビュー | 確認した範囲と対応 |
|---|---|
| [G1](reviews/G1-report.md) | P/A、基準・字句・名前・return の改行。重大なし、指摘を対応欄で処置 |
| [G2](reviews/G2-report.md) | D の先行する Lean の定義・言明と交換形式。重大なし。拡張に対する健全性等を補足し、G2 の設計者の合意を decisions.md に記録 |
| [G3a](reviews/G3a-report.md)・[G3b](reviews/G3b-report.md) | D の Rust 接続、四型・入れ子・束縛・診断・文書と段末検査。重大なし、Z3・Z4等で対応 |
| [G4](reviews/G4-report.md) | B2 の先行する Lean の規則と型・効果・脱糖・checker。重大なし、対応後に閉じ、設計者の合意を記録 |
| [G5a](reviews/G5a-report.md)・[G5b](reviews/G5b-report.md) | return・終了情報・VM/IO・Show・die の型と脱糖。G5b の重大1件は起動時の性能退行であり、Z7・R71で解消。他の指摘も各対応欄へ記録 |
| [G6](reviews/G6-report.md) | die の本番接続、ハンドラ・タスク・解放・CLI/test runner・文書。重大なし、Z8で対応。E0502 にも die 専用の補足を広げる軽指摘は今回採らず、対応欄に理由を記録 |
| [G7](reviews/G7-report.md) | 移行器・全サンプル・裸の検査・生成物。重大なし、Z9で分類と文書を修正。旧移行器の未達を R75・TODO-253へ明記 |
| [G8](reviews/G8-report.md) | E0908・0.0.6・固定ハッシュ・英日・公開前の整合。重大なし、中1件・軽3件を Z10で対応。最終の全体検査はその後の `03177eff` で成功 |

未解消の重大指摘はない。G5b の重大1件を初めから「重大なし」だったとは扱わない。レビュー時点の未接続・未実行という記述は、各報告の対応欄と本書の最終の検査結果で更新する。

移行の照合は、[M5 の確認表](m5/review.md) で P1 の646候補・166ファイルを追跡した。golden の入力等254ファイルと Rust の復号済み断片163件が一致し、変更のある5断片は個別の理由へ対応付けた。裸の try の成功・失敗・戻り先・型・解放・整形の検査を保持し、既存の assert の削除、期待値の緩和、ignore の追加はない。Skill 59ファイルと bundle の計60ファイルは生成の二度目までハッシュが一致した。

[M8 の照合](m8/review.md) は英日6組の184コードブロック、見出し103組とローカルリンク183件を確認した。全追跡2,995入力・3,850候補のうち、移行が必要な候補・未分類・未確認の現行サンプルは0件だった。生成 Skill は英語の生成元から作り直し、日本語訳を配布ディレクトリへ加えていない。Z10 の文言修正は G8 の対応欄にある。

通常の検査は独立した tests・formal/tests の入力を読み、この改造の作業用 manifest・audit の出力を読まない（M5・M8の確認）。M9 の読み取り検索でも scripts/check.sh・scripts/check-formal.sh・crates/benitoite/tests・formal/tests・新しい二つの移行器から、この改造ディレクトリへの参照はなかった。移行器が歴史資料を分類するためのパス文字列や自己検査の一時入力は、保管済みの実ファイルへの依存とは区別する。旧移行器の BASE 依存はこの確認の例外であり、次節の残件である。

## 計画との差・残件と後の作業

- **docs/todo の TODO-253（R75）**: 旧 named-arguments-migrate は、0.0.5の保管時に除かれた N1 の基準データに依存し、inventory が通らず、自己検査は8件中6件が失敗する。M1「旧 CLI とテストの結果を保つ」と M1・M5の旧移行器の自己検査には未達が残る。オーケストレータが受け入れ、道具の README と R75 に明記した。全体検査の成功を、この未達の解消とは数えない。assert の緩和や欠けたデータの仮置きはしていない。
- **fuzz/Cargo.lock（R81）**: benitoite の項目が0.0.1のままの、今回より前からある依存の控えである。版の数字だけを書き換えず、fuzz の依存の再解決を別作業へ残した。
- **docs/todo の TODO-249**: 型付きの失敗を値のまま捕捉する仕組みと or の後の拡張は後の改造である。今回の die は既存の Process.Exit を使う失敗終了であり、その捕捉を実装したものではない。
- **docs/todo の TODO-028**: 後の性能対策として残す。今回の短い測定と Z7 の退行修正で、この項目全体を解消したとは扱わない。
- TODO-027 のリソースの追加規則・IO の分類の見直し、TODO-072 の正式リリース条件全体、TODO-191 の範囲パターンも今回の範囲外のままである。
- M9 の検査は今回の依頼に従って再実行せず、上記のオーケストレータの実施済みの結果を引用した。新たな設計上のずれはなく、decisions.md の変更はない。docs/todo/ にも触れていない。

後の取り込み・公開の判断では、本書と `v0.0.5..03177eff` の差分、M9 の README.md・results.md の差分をレビューできる。仕様と実装の対応は design.md の型変更表・docs/design・formal/・各作業記録、利用者への案内は CHANGELOG の0.0.6節・英語リファレンス・Skill・日本語訳、移行と版の確認は M5・M6a・M7・M8の確認表、指摘の処置は reviews/ の対応欄を参照する。

コミット、タグ・公開、docs/todo の更新、改造ディレクトリの保管は後の指示に従う。G8 が挙げた100 KBを超える機械の出力14ファイルの保管時の扱いも、オーケストレータへ引き継ぐ。通常の検査へこれらの出力を依存させていない。
