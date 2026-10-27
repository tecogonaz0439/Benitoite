# Z01 の候補の検査（取りまとめ）

担当: 取りまとめ（Claude Code）。2026-10-27。Z01a（訳と CHANGELOG の下書き）・Z01b（版上げと実 CLI の照合）・Z01K（K2 の1回目の失敗の修正）の後、本体の作業ツリーで行った。

## 候補

| 項目 | 値 |
|---|---|
| release の検査の HEAD | `6db695e16bc21eedda2002630f3474632f8b64a1`（Z01b の取り込み）、作業ツリーの差分なし |
| K2 の HEAD（最終の関係状態） | `44a2c9611eceb42e227817c21398369413ff86af`（Z01K の取り込み）、作業ツリーの差分なし |
| 版 | `benitoite 0.0.12`（`crates/benitoite/Cargo.toml`）、`language "0.0.12"` を受理し `0.0.11` は E0908 |
| 二 lock の SHA-256 | `Cargo.lock` `56231868e475eec4710ffcf2bda766a377facebddee5d6b646f4df3824161fc5`、`fuzz/Cargo.lock` `b4a6253aa895fae5f2ddaa391630f8b57be24b2615af9b1452ed19d14e872a5d` |
| ツールチェーン | rustc・cargo 1.98.1、Lean v4.34.1、elan 4.2.4、aarch64-apple-darwin |

6db695e1 と 44a2c961 の差は、`crates/benitoite/tests/desugar_export/` の固定の manifest 二つ（テストの期待の JSON）と記録だけである。release の二単位（最適化したビルドの深い再帰のテストと勧告の照合）は、どちらもこの二つを読まないので、release の結果は最終の候補にも当てはまる。

## release

```sh
scripts/check.sh --level release --base 706d7ca3d16fc27d67e2ded0f7b1fee371aeb8a8 --dry-run
/usr/bin/time -l scripts/check.sh --level release --base 706d7ca3d16fc27d67e2ded0f7b1fee371aeb8a8
```

dry-run は終了0（`release_stack` と `advisories` の二単位）。本実行は 11:40:41 に始め、終了0（`selected checks passed`）、外側の時間 142 秒、最大常駐量 4.56GB。出力は [release.log](release.log)。

| 単位 | 結果 |
|---|---|
| release_stack（最適化したビルドでの深い再帰のテスト） | 10 件成功、失敗0（要求は成功10件） |
| advisories | 二対象とも照合済み・検出0件。記録は [advisories/](advisories/report.json) と [security-advisories.md](../security-advisories.md#公開候補の再照合取りまとめ2026-10-27) |

release の手動の照合（版・実 CLI・同梱 Skill と producer・ライセンス・生成参照・移行案内・ソース配布の対象と除外）は [Z01b の結果](../z01b/results.md)にある。照合は 0.0.12 の未コミットの候補で行い、取り込み 6db695e1 はその内容と同じである。`--version=json` の commit と Skill の producer は、履歴の集約とタグの後に作り直して照合する。

## K2

```sh
/usr/bin/time -l scripts/check-formal.sh
```

| 回 | HEAD | 時間 | 終了 | 内容 |
|---|---|---|---|---|
| 1回目 | 6db695e1 | 11:43:03〜12:20:39（2,256 秒） | 1 | 脱糖・組み込み・網羅性・表層の検査・区間の比較は成功。最後の `per-program final Rust exports` で、G01R が加えたゴールデン `testdata/warnings/skill-local-intervals.bnt` が固定の routing の manifest にないため停止した（[k2-run1.log](k2-run1.log)）。Z01K で manifest に登録した |
| 2回目 | 44a2c961 | 12:37:48〜13:25:18（2,849 秒） | 0 | 全段が成功（[k2.log](k2.log)） |

2回目の主な件数: 脱糖の書き出しは 1,792 入力（1,373 を書き出し、419 は検査の誤りで除外）。golden の program は 373 一致・不一致0、golden の関数は 1,075 一致、random は 1,000 一致。組み込みの照合は要約の比較 142,186・不一致0。網羅性は 22,483 一致・不一致0。表層の検査は 51,742 一致・不一致0（対象外19）。区間の比較は5系統（base・flow・width・range・domain）で一致し、区間の manifest は全入力・報告・ハッシュ・件数が一致した。要約の報告は [k2/](k2/desugar-report.json)、生の報告（区間の比較の 594MB を含む）はリポジトリの外の `work/m012/records/k2-run2-20261027.zip`（57.8MB、SHA-256 `910d592e15f1755110d8ea8893ff4a478c981192eaa2a3ef87ccac06c4573958`）に置いた。

最大常駐量は 1回目 17.9GB、2回目 18.1GB だった（機械のメモリは 32GB）。`time -l` が示すのは最も大きい一つの子のプロセスの値であり、どのプロセスかは確かめていない。Lean の見張り（14GB を超えた lean を止める）は止めていないので、lean 以外のプロセスか、見張りの間隔の間の値と見込む。K1（X05a）の最大常駐量は取得できていないので比べられない。メモリの少ない機械で K2 を動かす前に調べる項目として docs/todo に回す。

## 判断

release・K2 は終了0であり、手動の照合と全体レビューを終えた。設計者は外出中で「push 前まで遂行」と指示したので、取りまとめが受け入れ、保管・集約・タグ・アーカイブまで進める。push はしない。
