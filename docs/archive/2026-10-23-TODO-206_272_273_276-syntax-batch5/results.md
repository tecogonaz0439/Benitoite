# 第5弾の段・改造・公開候補の結果

2026-10-23開始、2026-10-24に検査を完了したG1実装担当Codexによる集約である。開始版B0は `a9c4132e6451904698cf344db1794c4d03affcd6`、G1の基準とHEADは `baca0076e5f08abace9cc22136ed2f690f208684` である。G1の変更は未コミットであり、検査入力の差分とハッシュは [input-state.json](g1/input-state.json)、実行・初回の失敗と修正・件数は [G1の結果](g1/results.md) に残す。

## 証拠の扱い

各作業の表は元のresults.mdの実行履歴を照合した記録である。途中の失敗・中断・未接続を、当該作業時点の全面的な成功へ書き換えない。G1の回帰の証拠はG1で実行するchangeと必要な局所検査とし、過去のworkの成功で最終状態の検査を省かない。

[decisions.mdのD42](decisions.md#d42-全比較-k1-を受け入れの証拠に数えない)に従い、F5のK1とk1-summary.jsonは参考の記録としてのみ扱う。K1は受け入れの証拠に数えず、別の状態への引用もしない。全比較の唯一の受け入れ証拠は、Z1が最終候補で実行するK2である。G1のformal_buildと局所の32定義の照合はK2の代わりにならない。版・訳・CHANGELOG・実候補のCLIと同梱物・配布の照合、release_stackとK2はZ1に残る。

## 作業ごとの照合

各リンク先に基準の完全なID・コマンド・構成・件数・時間・失敗と修正がある。追加修正のW2R・A2R・A6R・C2R・F1R・F3R・F5Rも含めた。

| 作業 | 元の記録の検査と接続の状態 | 後続での処理 |
|---|---|---|
| [F0](f0/results.md) | scratch94入力・15対照、本番4888ファイルの一致。文書だけのworkは対象なしで終了0 | F1・F2で本番へ接続 |
| [L1](l1/results.md) | work終了0（67.336秒）、コメント後のformal_buildも成功 | データ・妥当性・符号化をL2a以降へ |
| [L2a](l2a/results.md) | work終了0（67.14秒）。型付け・脱糖・型保存等を接続 | 表層検査の一時拒否はL2bで解除 |
| [L2b](l2b/results.md) | work終了0（43.36秒）、健全性・計算可能性・有限支持も接続 | 交換はL3へ |
| [L3](l3/results.md) | work終了0（10.582秒）、独立交換8件・第4弾15件成功 | RV-Iの申し送りはF5で処理 |
| [W1](w1/results.md) | work終了0（123.896秒）、依存と未接続の幅本体 | W2へ接続。shortはW2後 |
| [W2](w2/results.md) | 登録表の件数を修正してwork成功。heap/stress/doc・Miri・到達可能性比較も成功 | RV-IIのH1・M1等をW2Rで修正 |
| [W2R](w2r/results.md) | work終了0（770.417秒）、局所heap/stress終了0（641.514秒） | 専用確保経路とMiri対象の検査を追加。shortはA1後に含む |
| [A1](a1/results.md) | work終了0（503.48秒）、全統合40ターゲット・全examples | 元ASTと位置を保持し、A2・A4〜A6へ一時防御を引き継ぐ |
| [A2](a2/results.md) | lintと旧期待を修正し、未完了分の続行終了0（102.31秒） | 合併済みScheme・NoFail・元位置をA3以降へ |
| [A3](a3/results.md) | Skill例の引数名を修正し、失敗・未実施分の続行終了0（16.04秒） | 入口・許可・報告とW0501を接続 |
| [A2R](a2r/results.md) | 中断前のlib完了は不明として再実行。続行終了0（200.02秒） | 二重編集と元位置等を修正。RV-A36が確認、shortはA4後に含む |
| [A4](a4/results.md) | work終了0（117.22秒）、package_command16件成功 | 構文集計とLogの識別を接続 |
| [A5](a5/results.md) | derive47件終了0（71.54秒）。旧版期待を修正しwork続行終了0（20.92秒） | 同梱例を新previewで再確認。共有入力の変更後の自己検査はG1で再実行 |
| [A6](a6/results.md) | fmtの末尾空行を修正してwork終了0（120.43秒）、try-actions9件成功 | 整形・inventory・標準ソースの最後の防御を解除 |
| [C1](c1/results.md) | 派生診断の旧期待を修正し、局所と未実施分が成功（続行85.411秒） | 値全体の原因をC2へ |
| [A6R](a6r/results.md) | work終了0（216.56秒）、関連9統合146件・try-actions10件成功 | 文書・E0329等を修正、shortはC2後。互換性の案内はZ1へ |
| [C2](c2/results.md) | lintと独立したE0601の期待を修正し、指定3統合と残りのworkが成功（最終61.880秒） | named_argumentsの退行とRV-Cの問題をC2Rで修正 |
| [F1](f1/results.md) | 全統合のnamed_argumentsで2件失敗、基準版でも再現。残る17統合等の続行は終了0（210.332秒） | work全体の成功とはしない。退行はC2R、probeのAPI差はF1Rへ |
| [F1R](f1r/results.md) | 比較道具37件・work終了0（7.962秒）、F1後のshort終了0（35.037秒） | 新旧parse APIと欠測時の継続を修正、処理系本体の変更なし |
| [C2R](c2r/results.md) | work終了0（535.859秒）、全統合40ターゲット369件、named_arguments22件成功 | 脱出・反変・長い連鎖は修正前後を確認。shortで費用増加も再確認 |
| [F2](f2/results.md) | lint修正後work終了0（532.744秒）、全統合40ターゲット370件・全examples | 書式AST・解析・整形を接続。残る防御はF4bまで保持 |
| [F3](f3/results.md) | lint修正後work終了0（145.308秒）、局所heap/stress/doc終了0（673.563秒） | 14頭と算法を提供。交換出力の14頭はF5で検査 |
| [F4a](f4a/results.md) | work終了0（185.96秒）、型受理表294組と回復の対照 | 型検査後の防御をF4bへ |
| [F3R](f3r/results.md) | work終了0（523.206秒）、全統合40ターゲット376件 | 不正UTF-8・重複診断・無効な編集等を修正、shortはF4b後に含む |
| [F4b](f4b/results.md) | work終了0（196.26秒）、局所heap/stress/doc終了0（671.29秒）、最後の型受理テストとfmt/lintも追試成功 | 全実行経路・定数を接続し、一時防御を解除 |
| [F5](f5/results.md) | lint修正後work終了0（115.767秒）、局所32定義・六入口 | 交換14/6・頭の名前と登録・保持件数を接続。K1は参考記録 |
| [F5R](f5r/results.md) | work終了0（256.82秒）、局所交換終了0（2.18秒） | 空集合書式のE0468欠落を修正。最後のshort後、全比較はK2へ |

C2で入ったnamed_argumentsの退行は、C2のworkが統合テストを関連3ターゲットに絞ったため見落とされ、F1の全統合で見つかり、C2Rで導入版を特定して修正した。

## レビューと追加修正の対応

これは既存のレビューと対応記録の照合であり、G1による新しい独立レビューの受け入れ宣言ではない。

| レビュー | 処理した作業と判断 | 残る担当・制限 |
|---|---|---|
| [RV-I](reviews/RV-I.md) | M1・L4〜L6はF5、L1〜L3はF3R・F5で対応。RV-F5が頭の同一性・登録、14頭、String保持を確認 | 最終の全比較はZ1のK2 |
| [RV-II](reviews/RV-II.md) | H1・M1・L1〜L5をW2Rで処理。専用の空白追加経路で健全性を直し、Miri対象の検査を追加 | 幅の表のバイナリサイズへの影響は未測定で今回の測定範囲外 |
| [RV-A12](reviews/RV-A12.md) | M1・M2・L1〜L7をA2RとA3で処理。E0812は認められた一関数一件の案を維持 | 後のA4〜A6で古くなった文書はA6Rで修正 |
| [RV-A36](reviews/RV-A36.md) | 中1〜3・軽1〜7・10をA6Rで処理。軽8は正規名を共有する既存APIを維持する理由を記録 | 版リンクと移行案内はZ1。軽9のProperty生成のpreview拒否は取りまとめが後の課題へ |
| [RV-C](reviews/RV-C.md) | P1〜P5・E1・C-1〜C-4・T-1〜T-2をC2Rで処理。脱出・依存方向・長い連鎖は修正前後を確認 | C2R後と最後のshortで費用を再確認済み |
| [RV-F13](reviews/RV-F13.md) | M1・L1・L3・L4・L6・L9はF3R、L2はF4b、L7はF5で処理 | L5の固定埋め文字領域は後の課題。L8は任意のため省略。L10は未再現で接続済み、L11は指定入力で懸念経路を再現せず変更なし |
| [RV-F4](reviews/RV-F4.md) | M1の交換三条件はF5、L1〜L7はF5Rで処理 | L6は代案どおり到達不能をコメントで説明しUnavailableを維持 |
| [RV-F5](reviews/RV-F5.md) | M1はD42でK1を証拠から除外。L1〜L4はG1で修正 | Z1のK2を全比較の唯一の証拠にする |
| [RV-G1](reviews/RV-G1.md) | 重・中なし。L1・L4・L5は取りまとめが文書を修正。L2はdocs/todoのTODO-281へ。L3（集計JSONの単位ごとの終了状態）は任意のため省略 | — |
| [RV-Z1](reviews/RV-Z1.md) | M1・L1〜L4は[Z1R](z1r/results.md)で文書を修正。L5の計画変更は取りまとめが2026-10-24に承認したことをZ1の結果へ追記 | L6は取りまとめが後の改造の課題として登録する。委任範囲の受け入れは取りまとめが判断 |

## 性能のshortの集約

比較元はD41のW1 `a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a` である。依存の記録が異なるB0とは比較しておらず、B0→W1の実行ファイルの変化は測っていない。各作業のresults.mdの末尾とF1Rの「shortの記録」を、manifest・result-manifest・alerts・全9節の標本と突き合わせた。[short-audit.json](g1/short-audit.json)に比較する完全ID・件数・ファイルのSHA-256を保存した。

全15回とも66点、両状態の各点5標本、一回につきCLI660標本（15回の計9900標本）、skippedは空である。「達成」は道具のしきい値内の判定であり、性能が同一または改善したという断定ではない。「判定不能」を達成に数えない。

| 取り込み後 | 達成 / 判定不能 / 退行の疑い | 外側の時間（ビルド込み） | 元の記録 |
|---|---:|---:|---|
| W2 | 1 / 65 / 0 | 183秒 | [測定](../../../tools/bench/results/2026-10-23-849079b6-batch5-w2/results.md) |
| A1（W2Rを含む） | 0 / 66 / 0 | 107秒 | [測定](../../../tools/bench/results/2026-10-23-4a4bb1ad-batch5-a1/results.md) |
| A2 | 0 / 66 / 0 | 107秒 | [測定](../../../tools/bench/results/2026-10-23-508a9b62-batch5-a2/results.md) |
| A3 | 0 / 66 / 0 | 107秒 | [測定](../../../tools/bench/results/2026-10-23-fe4af8d1-batch5-a3/results.md) |
| A4（A2Rを含む） | 0 / 66 / 0 | 107秒 | [測定](../../../tools/bench/results/2026-10-23-e63fc57f-batch5-a4/results.md) |
| A6 | 0 / 66 / 0 | 108秒 | [測定](../../../tools/bench/results/2026-10-23-81bf92d4-batch5-a6/results.md) |
| C1 | 2 / 64 / 0 | 107秒 | [測定](../../../tools/bench/results/2026-10-23-754e8411-batch5-c1/results.md) |
| C2（A6Rを含む） | 19 / 47 / 0 | 108秒 | [測定](../../../tools/bench/results/2026-10-23-121f42e6-batch5-c2/results.md) |
| F1（F1Rの道具で測定） | 10 / 56 / 0 | 35.037秒 | [測定](../../../tools/bench/results/2026-10-23-52fc6f0a-batch5-f1/results.md) |
| C2R | 5 / 61 / 0 | 110秒 | [測定](../../../tools/bench/results/2026-10-23-c4b3f026-batch5-c2r/results.md) |
| F2 | 6 / 60 / 0 | 108秒 | [測定](../../../tools/bench/results/2026-10-23-2b7dabea-batch5-f2/results.md) |
| F3 | 6 / 60 / 0 | 109秒 | [測定](../../../tools/bench/results/2026-10-23-f4dda59f-batch5-f3/results.md) |
| F4a | 3 / 63 / 0 | 108秒 | [測定](../../../tools/bench/results/2026-10-23-78c34404-batch5-f4a/results.md) |
| F4b（F3Rを含む） | 6 / 60 / 0 | 108秒 | [測定](../../../tools/bench/results/2026-10-23-05fd5111-batch5-f4b/results.md) |
| F5R（G1前の最後） | 3 / 63 / 0 | 108秒 | [測定](../../../tools/bench/results/2026-10-23-678aba50-batch5-f5r/results.md) |

W2のresults.mdの「65点すべてが判定不能」は転記が不正確であり、元のresult-manifest.jsonの66点（達成1・判定不能65）を上表に採った。元の記録は書き換えていない。

C2後の型検査の費用増加の疑いは、RV-Cが成功経路の複製・推移的探索と診断後の全表再構築を調べ、C2Rが遅延構築・保留集合の削除・更新の集約等で修正した。higher-0-300のW1比はC2後+8.4%からC2R後+4.5%となり、最後のF5R後も判定に退行の疑いはない。測定のぶれがあるため、増減すべての原因をこの修正へ帰属させない。長い連鎖のテストは、別の形の費用増大を修正前後で確認している。

A5とF1Rは道具だけであり、それぞれ独立した処理系のshortの対象ではない。F1Rは未完了だったF1後の測定を担当した。F5はsrcを変えず、G1も処理系本体を変えずexampleの同じ分岐を列挙し直すだけなのでshortを追加しない。W2R・A2R・A6R・F3Rには独立したshortがなく、上表にそれぞれを含む次の比較を明示した。

## 段の接続検査

### stage S-A（段 III、ファイル単位の宣言）

次は取りまとめが既に保存した当時の実行記録であり、G1の最終状態への引用とは区別する。

- 基準: `cd10914f77db41f6ba03d1321c40bdd8900ae381`。対象: `7ae3d7b610f615f8545c6d716f3e966aac0fc40d`。
- コマンド: `scripts/check.sh --level stage --base cd10914f77db41f6ba03d1321c40bdd8900ae381 --only tests_related --test checked_args --test test_command --test package_command --test fmt_command --test property_library`（dry-run後）。
- 終了0、外側33秒。checked_args10件・fmt_command20件・package_command16件・property_library15件（ignore2件）・test_command52件成功。
- 当時はA5のderive自己検査47件を使用した。後に共有の解析器・型検査器等が変わったため、G1では自己検査も再実行し、47件成功した。

| 段 | 計画の引用と、その後の変更 | G1での扱い |
|---|---|---|
| S-W | W2のworkの引用予定だが、後にW2Rが確保経路を変更した | 旧結果を最終状態へ引用せず、全件・heap/stress・Miriで確認 |
| S-A | 当時のstage成功後にA6R・F1等が共有入力を変更した | 全統合・移行自己検査・derive自己検査で再確認 |
| S-C | C2のworkの引用予定だが、退行をF1で発見しC2Rで修正した | C2の成功を引用せず、全統合・特殊構成・長い連鎖で確認 |
| S-F | F5はsrcを変えないが、後のF5Rが回復の診断とテストを変更した | 旧workの引用で省かず、全統合・heap/stressで確認。全比較はK2 |

## G1の改造全体の検査

初回changeはexampleの列挙型matchのlintで停止した。残るバリアントを明示し、修正後workでfmt・lint_default等が成功した後、失敗したlint_heapと未実施分を続行して終了0となった。続行の外側は4785.634秒（約79分46秒）である。[G1の結果](g1/results.md)と[check-summary.json](g1/check-summary.json)に初回の失敗・修正・コマンド・構成・件数・時間を保存した。

| 検査 | 成功と範囲 |
|---|---|
| 既定・heap-verifyのworkspace all-targets | 各2918件・2932件成功。各構成の全統合40ターゲットは378件成功 |
| gc-stressのlib/tests | 1653件成功、全統合40ターゲット375件。call_allocationsの3件は既存cfgによる対象外で、他の二構成で成功 |
| 文書テスト | 34件成功・既存のignore1件、compile_failを含む |
| 長い対象 | heap-verify・gc-stressで各29件成功。形式化の全件書き出し2件はK2へ残す |
| Miriと到達可能性比較 | 通常確保59件・個別確保52件成功。20000列の比較51件成功 |
| 生成物・道具・規約・依存 | Skill生成物、仕様集計、fmt、二構成lint、ソース規約、Python構文、ライセンス、移行自己検査6/10件、比較道具37件、derive47件が成功 |
| 形式化 | 既定lake buildとsorry拒否が成功。局所の独立交換8件・Rust32定義の六入口照合も成功。全比較の証拠はK2だけとする |

検査入力のハッシュは最終確認でも一致した。psはsandboxの制限で拒否されたが、検査コマンド自体に環境による未実施はない。G1担当の未解決の不具合・未実施検査はない。独立レビューと候補の受け入れは取りまとめへ渡す。K1の参考記録を使って全比較の受け入れを完了扱いにしない。

## Z1と取りまとめへの申し送り

この表はG1時点の申し送りである。各項目のZ1での処理は [Z1の結果](z1/results.md#申し送りの全項目への対応) に記録する。

| 対象 | 残る作業 | 担当と時期 |
|---|---|---|
| 全比較 | D42どおりK2を最終候補で実行。交換14/6、六入口・独立入力・組み込み表・全定義・routing/exchange manifestを照合。変更したcheck-formal入口も実際に通す | Z1 |
| 0.0.11と移行 | 一度だけ版を上げ、languageの旧版案内・BREAKING_CHANGESのsummary/help・CHANGELOG・package updateの案内をそろえる | Z1 |
| derive | inventory2→3、必須fileUses/importInsertLimit、生成器3.1.0、旧manifestのapply拒否と新previewによる再確認を案内。記録・manifest/receipt版3と意味ハッシュ算法版3は維持 | Z1。詳細は[A6Rの互換性表](a6r/results.md#z1-への互換性変更と移行の申し送り) |
| try-actions | 版欄なしの旧inventoryを拒否、inventory/manifest版2へ。unknown_effective_contract・unmapped_contract_boundaryで以前の候補が保留になる場合を説明 | Z1。nullを空集合とせず候補を再生成して確認 |
| package | 裸のLog・Benitoite.Log、ファイルの宣言と外部公開の直下の関数の集計で、旧ソースでも記録が変わり得ることを案内 | Z1 |
| Skill・文書・同梱物 | Skill本体とinspection.mdのCLI仕様リンクをv0.0.11へ。英語・日本語訳・生成参照・第三者表示と配布物を照合 | Z1 |
| 一時防御 | 検査・実行はA2、packageはA4、deriveはA5、整形・try-actions・共通補助・診断pendingはA6で解除。書式の型・定数・脱糖とE0262のpendingはF4bで解除 | Z1で候補と照合。package.bntの禁止と契約不明の保留は維持 |
| 後の課題・任意項目 | RV-A36軽9のProperty生成preview拒否、RV-F13 L5の埋め文字固定領域、RV-II L2の幅表のサイズ。RV-F13 L8の並べ替え編集案は省略 | docs/todoを扱える取りまとめ。G1は登録・更新しない |
| 受け入れ | G1の独立レビュー、Z1のrelease_stack成功10件、実CLI・版・同梱物・生成物・移行案内・配布の手動照合 | 取りまとめ。候補の終了0だけで受け入れを完了扱いにしない |

TODO-206はファイル単位の宣言の部分だけであり、ログの出力先等を完了にはしない。性能の増減をCHANGELOG・リリース文書へ写さない。コミット・取り込み・docs/todoの更新と文書の保管は取りまとめの担当であり、履歴の集約・タグ・push等は設計者の指示に従う。

## Z1の候補の照合（2026-10-24）

Z1のB_WORKとHEADは `e0ed5eb2888349dbb0d251843627c527d7ffc0b0` である。G1の上記記録は当時の状態として保ち、Z1の版・翻訳・互換性案内・検査入力の変更と検査結果は [z1/results.md](z1/results.md) に記録する。候補は0.0.11であり、未リリースである。

work Z1は、版境界に伴う成功入力と三つの固定ハッシュの更新漏れを修正し、失敗した検査と未実行の対象の続行で成功をそろえた。lib1,271件、関連統合152件が成功し、build_infoのignored対象も実候補で5件成功した。releaseはB0を基準にdry-run後に実行し、最適化したビルドでの深い再帰release_stackの成功10件を確認した。

実CLIの51呼び出しと、Skillの全同梱物の追加確認2呼び出しは、期待する出力・終了状態と一致した。[全53コマンドの表](z1/manual-cli-table.md)と[観察記録](z1/manual-cli-observations.json)に残す。第三者表示はrustcのhostに合わせて再生成し、bundled-licensesの表示の本文113,432バイトと一致した。Skillの73ファイルは両ライセンスを含めて元の本文と一致した。英語・日本語・生成参照・移行案内・ソース配布の対象と除外も照合した。

K2は最後の関係状態で全体を一度実行し、終了0、外側1,012.736秒（約16分53秒）で完了した。1,790入力・73,840定義の脱糖、組み込み表の要約比較141,998件、表層検査51,729件、プログラム内の網羅性22,482件が一致し、不一致と準備失敗は0件である。既存の検査エラー419入力の除外、表層の対象外19件・Q11分類1件も理由とともにmanifestに一致した。独立した通常10,020件・view付き10,028件、局所32定義の六入口、変異の拒否、全入力のrouting/exchange manifestも成功した。[k2-summary.json](z1/k2-summary.json)と[k2-stages.log](z1/k2-stages.log)へ永続の要約を保存した。F5のK1は参考記録のままとし、今回の成功へ引用していない。

K2前後の入力状態は [input-state.json](z1/input-state.json) と [input-state-final.json](z1/input-state-final.json) に保存した。HEADはB_WORKのまま、関係する4,449ファイルと未コミット差分のハッシュは一致した。K2開始後の変更は結果と記録の文書だけであり、候補と同じ生成物・標準ソース・テスト入力で照合したことをZ1担当が2026-10-24に確認した。Z1の実装担当に未完了検査や設計者の判断を要する停止事項はない。独立レビューと委任範囲の受け入れを取りまとめへ渡す。

Z1はGitの変更操作、private/docs/todoの読み書き、改造文書の保管、履歴の集約・タグ・タグ後のアーカイブ・pushを行わない。受け入れは取りまとめへ渡す。CHANGELOGの見出しは既存の版と同じ日付なしとし、本文は未リリースの候補とした。集約とタグの際に公開状態の表示とcommit依存のビルド情報・Skill producerを再照合する必要がある。

## 委任の範囲での受け入れ（2026-10-24）

設計者は2026-10-23に「版の上げ（0.0.11）とreleaseの検査まで」を、2026-10-24に「問題がなければpushの手前まで」を取りまとめに委任した。取りまとめ（Claude Code）は2026-10-24に、次の証拠をそろえたことを確かめ、委任の範囲で改造を受け入れた。

| 証拠 | 結果 |
|---|---|
| 改造全体の回帰（G1のchange） | 既定・heap-verifyの全ターゲット、gc-stress、長い対象、文書テスト、Miri、到達可能性の比較、二構成のlint、規約・生成物・自己検査が成功（[g1/results.md](g1/results.md)） |
| 候補の検査（Z1） | work Z1、build_infoのignored 5件、release_stack 10件、実CLIの53呼び出し、第三者表示、Skillの73ファイルが一致（[z1/results.md](z1/results.md)） |
| 全比較K2（D42で唯一の証拠） | 1,790入力・73,840定義ほかで不一致0、終了0。K2の後の変更は文書だけで、K2の入力4,449ファイルのSHA-256がZ1R・Z2の後も一致（[z1/k2-summary.json](z1/k2-summary.json)、[z1r/results.md](z1r/results.md)、[z2/results.md](z2/results.md)） |
| レビュー | RV-G1は重・中なし（軽はG1の後に処理、L2はdocs/todoへ）。RV-Z1の中M1と軽L1〜L5はZ1Rで処理し、L6はdocs/todoへ |
| 公開の表示 | Z2で0.0.11の候補の表示をリリースの表示へ切り替えた。性能の増減はCHANGELOGとリリースの文書に書いていない |

この後、取りまとめがgit-workflowの「ソースだけのリリース」の手順3〜7（docs/todoの項目を閉じる、本ディレクトリの保管、控えのブランチ `backup/before-v0.0.11`、履歴の集約、軽量タグ `v0.0.11`、集約後のビルド情報とSkillのproducerの照合、tar.gzとzip）を行う。公開済みの `origin/san_benito` は v0.0.10 のタグの後の a0d652c0 を含むので、集約の範囲は a0d652c0 より後とし、早送りのpushを保つ。集約のメッセージは、設計者の「pushの手前まで」の指示を承認として扱う。pushは設計者の指示を待つ。

2026-10-24に本ディレクトリを `docs/archive/` へ移した。Markdownの外を指す相対リンク105件と、案内として書いた根からのパス2件を保管先に合わせて直した。JSONの記録（ハッシュとともに保存した入力の一覧など）と、過去に実行したコマンドの写しの中のパスは当時のまま残した。移す前から切れていた4件（コードの断片がリンクの形に見えるもの3件と、修正案の中に引いたリンクの文字列1件）もそのまま残した。
