# L70 の末の全比較（F-REG）の結果

L70 の末に、新しい Lean と、新しい版で書き出し直した既存コーパスを、`scripts/check-formal.sh` の全体で比べた（plan の「検査の割り当て」の「check-formal全体 F-REG」の行）。設計者の指示により、群 G・H のレビューと処置、段末のレビューと処置をすべて終えた最後の関係状態で、一度だけ流した。

## 基準と操作

| 項目 | 値 |
|---|---|
| 関係状態 | san_benito `6d160731c`（L70.48 の取り込みの後）。Lean・処理系・入力は、この状態から変えていない |
| 全体の実行 | `scripts/check-formal.sh`（共有ロックの下、`/usr/bin/time -l`）。2026-11-08 12:13:31〜19:44:33、外側の時間 27,062 秒（7時間31分）、最大常駐量 11,966,382,080 バイト。出力は `target/{desugar,coverage,interval}-diff/run-23827`（`target/` の下で追跡しない） |
| 全体の終了 | 1。止まったのは最後の照合の台本 `check_named.py` で、旧 Lean の時代の期待値のままだった（下の「最後の照合の台本」） |
| 台本の更新 | `f9b022951`（ブランチ `m014/l70.freg`）。変えたのは `crates/benitoite/tests/desugar_export/` の台本と manifest、`scripts/check/formal_interval.py`・`test_policy.py` だけで、Lean・`check-formal.sh`・処理系は変えていない |
| 最後の照合の本物の実行 | `f9b022951` で、`check-formal.sh` の batch3 の段（b3・blocks・g2・g3）、`check_named.py`、`formal_interval.py` の manifest と verify を、run-23827 に対して続けて流した。2026-11-09 04:01:48〜10:46:21、外側の時間 24,273 秒（6時間45分）、最大常駐量 15,175,581,696 バイト、終了 0 |
| 生の記録 | 全体の記録 2,108,274 バイト（SHA-256 `9c9242e18660d9c8bbf0d0371efd4f839cc956753e771d3fae468f406a22fe47`）。最後の照合の記録 4,053 バイト（SHA-256 `a4039cc9154bcd8a0bb240b7c899f1d0bd95fe29423c486b68de508525cc46cb`） |

全体の入力と報告の大きさと SHA-256（`target/desugar-diff/run-23827/` の下）:

| ファイル | バイト | SHA-256 |
|---|---:|---|
| `named-programs-corpus.json` | 359,108,129 | `92a06527a82489e0a1baf60cd38f76de8ce717d7cb186d48e1f8d3d05ca864bc` |
| `named-programs-builtins.json` | 103,687,488 | `89335047ff62aad0b08b70b5685df8f88a901103da4e40c7cc379e1b0c50234e` |
| `named-programs-stdlib.json` | 3,877,880 | `fa3f13556da41038c9be8105c93e06e263f1e2f2fed27da114bc0ada5830a887` |
| `named-programs-coverage.json` | 8,173,401 | `c2a28a73b414f0869002cbfc400006d10dbd8bc9df532cf707d2162948e86426` |
| `report.json`（desugarDiff） | 16,975,190 | `18c2df519942e2fc99d0e574c1b1260e22607480c5b54d65a90831ac53b0fe4a` |
| `builtin-report.json` | 524,565 | `ba061d3150f0afddec23433ee80922bdfb69be18f98017a1c5c673acd61d583c` |
| `coverage/report.json` | 398 | `5f139e2ee8d766a9dd1a42c81b3dffdacafabea873102baad50d5c9d9ff9d090` |
| `surface-check/report.json` | 13,337,839 | `f358c5b4c4f7e97cb206a48ff1d3cf4423505b76b3558541807604900935ecf3` |

## 段ごとの結果

| 段 | 結果 | 分類 |
|---|---|---|
| 既定ビルドと7入口のビルド | 通過 | — |
| 交換の検査（幅・名前・拡張・try・batch2〜5・範囲） | 通過 | — |
| 処理系の書き出し | 1,792 入力（書き出し 1,373、範囲外 0、検査の誤りで除外 419）、1,527 秒 | 除外 419 は処理系が型検査で断る入力で、旧と同じ |
| coverageDiff | 10,020 件と view 付き 10,028 件、不一致 0 | — |
| 区間の比較（独立・Rust・評価器・VM） | 通過、1,278 秒 | — |
| desugarDiff（全件） | 不一致 7,070 定義（golden 23 プログラム・70 定義、random 1,000 プログラム・7,000 定義）、終了 1 | 全てが取得関数の結果型の欄の関係の篩の差（`definition.header.ret`、`known_shape` の形 `accessor field refinement`）。後段への義務6（R10b） |
| builtinCheck | 比較 144,932、不一致 0 | — |
| coverageProgramDiff | 一致 22,483、不一致 0 | — |
| surfaceCheckAll（全件） | 一致 51,533・不一致 0・範囲外 8・q11 1・準備の失敗 32、23,940 秒、終了 2 | 下の表 |
| 最後の照合（`check_named.py`・区間の manifest と verify） | 台本の更新の後に終了 0 | — |

surfaceCheckAll の一致以外の内訳:

| 種類 | 件数 | 中身 | 扱い |
|---|---:|---|---|
| 準備の段の分類した拒否 | 32 入力 | 結果型の篩（`List.append`・`List.head`・`List.tail`・`Map.fromList`・`Map.toList`・`Set.fromList`・`Set.toList`）、`Http.sendIn`、`Scope.ScopeError` の data の宣言（At） | 群 G の分類の表の原因。R40・R50・R30 への義務 |
| 範囲外 | 8 定義 | concurrency の入力。標準表にない組込み（`Task.await`・`TaskGroup.spawn` など）を記録し、呼び出しの頭の検査が `call signature is invalid` で断る | 群 G の決定（標準表にない組込みは記録して断らない）。R50 への義務 |
| q11 | 1 定義 | `f04_list_spread`（末尾の照合の置き換え） | 旧と同じ入力 |
| 末尾の照合の件数 | 7,093（期待 7,137） | 差の 44 は、断った 32 入力の定義の注釈の和にちょうど一致する | `classified_all` が照合する |

旧の manifest の範囲外 19 は、上の 8 と network の 11 であった。network の 11 は、今は準備の段の分類した拒否（`Http.sendIn`）になる。

最後の照合が集計した準備の段の分類した拒否は、全体で 39 件である（単独の入口 35・全件の入口 4）。原因の内訳は `refined result` 25・`Http.sendIn` 11・`Scope.ScopeError.At` 6 である。named-programs の 32 入力のほかに、次の 3 件を含む。
- batch3 の k3 の入力 `scope`。
- named の entry の `named-declarations`（At）と `generated-record-property`（結果型の篩）。

範囲の予算の照合では、Lean で比べる 2 ケースが両方とも At で準備の段に断られ、比べたケースは 0 件である。

## 最後の照合の台本

`check_named.py` は今回初めて新しい Lean に対して最後まで流れ、旧 Lean の時代の期待値で止まった。主なものは次の三つである。
- 拒否の理由の文の変化。新しい検査器は NoFail の違反と標準表にない組込みを `call signature is invalid` で断る。
- 分類した準備の拒否を断らずに記録する仕組みが、batch3 の照合と範囲の予算の照合になかった。
- 全件の三入口を上限 60 秒で再実行していた。新しい Lean の surfaceCheckAll は 6.6 時間かかる。

Claude の担当（Opus 5.5）が台本を直し、Claude の別の担当が独立にレビューした（[RV-L70.freg](../../reviews/RV-L70.freg.md)、条件付き可、処置の確認は可）。担当の報告は [scripts-report.md](scripts-report.md)、壊した入力で照合が弱まっていないことを確かめた開発用の台本は [weaken/](weaken/) にある。直した要点は次のとおりである。

- 全件の desugarDiff・builtinCheck・surfaceCheckAll は再実行せず、`check-formal.sh` が同じ入力で書いた報告を読む。報告が入力より古ければ失敗にし、件数を corpus と照らす。
- 脱糖の既知の差は形で分類し、件数を manifest に固定する。R10b で差が減ると件数の食い違いで失敗し、manifest の更新を求める。
- 準備の段の分類した拒否は、入力と原因で固定する（named-programs・batch3・named の entry・範囲の予算）。拒否が別の入力へ移ったり消えたりしたら失敗する。
- 変異の検査の期待は、新しい検査器の一般の理由の文と、壊した箇所を指す経路で固定する。
- `check-formal.sh` の終了状態の決め方は変えていない。

## 計画からのずれと申し送り

- **見込みとのずれ**: 全体は見込み 7〜11 時間の範囲だった。最後の照合の試行は、取りまとめが「数分」と見込んだのに対し 6時間40分かかった（単独の表層の検査 1,792 入力）。見込みの2倍を超えた時点で報告しなかったのは取りまとめの誤りである。
- **最大常駐量**: 最後の照合の実行は 15.2 GB だった。Lean の各プロセスは `-M 12288` の下で動いた。この値は、大きな JSON を何度も読む Python の台本を含むプロセス木全体の値である。
- **全比較の終了状態**: L70 の F-REG は、既知の差のために `check-formal.sh` が 0 で終わらない。全件の desugarDiff は 1 を返し、surfaceCheckAll は 2 を返す。区間の manifest と verify は `check-formal.sh` の中では走らないので、手で流した結果を記録した。
- **R 段への申し送り**（stage-results.md の後段への義務の表に加えて）:
  - R10b: 義務6を閉じたら、`exchange-manifest.json` の脱糖の既知の差の件数を 0 にする。
  - R30: At を揃えたら、次を空にし、範囲の予算の比べるケースを 2 に戻す。
    - `formal_interval.py` の `EXPECTED_BUDGET_REJECTIONS`
    - batch3 の k3 の `preparationRejected`
    - manifest の At の拒否
  - R40・R50: 結果型の篩・`Http.sendIn`・標準表にない組込みの拒否と範囲外を 0 にする。
  - F-CONN: 全ての差が 0 になれば、`check-formal.sh` が終了 0 で manifest と verify まで進む。F-CONN ではこれを確かめる。
- **全比較の時間**: plan の目安（旧約40分・最大約14GiB）は今回の値に改める。全体 7.5 時間と最後の照合 6.7 時間で、どちらも表層の検査が大部分を占める。F-CONN と最後の全比較の見込みはこの値から立てる。検査器の速さは docs/todo の TODO-329 である。
- **段の照合（`l70/verify.py`）との関係**: `verify.py` は L70.48 の関係状態（`6d160731c`）で終了 0 だった。F-REG の変更は `crates/benitoite/tests/desugar_export/` と `scripts/check/` の台本だけで、`formal/` と設計書は `6d160731c` から変えていない。そのため段の公理監査と記録の照合はそのまま有効である。`verify.py` の群 H3 の区間は作業木までを見て、Lean と記録の外の変更を拒むので、F-REG の後の状態では再実行しない。
