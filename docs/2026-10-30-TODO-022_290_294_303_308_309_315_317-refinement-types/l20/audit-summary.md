# L20 段末の公理監査

2026-11-03。既定の `Benitoite` と `Lean` をimportした環境で、Refinement/Sharedの全宣言を検査する。改造に大きな生の対象一覧は置かず、[axioms.lean](axioms.lean) と [audit-inventory.lean](audit-inventory.lean) が同じ対象を再生成する。

## 対象の生成と再実行

両台本は次の手順を持つ。

1. 既定環境のモジュール名のうち `Benitoite.Release.Refinement.` 又は `Benitoite.Shared.` で始まるものを選ぶ。
2. 各モジュールが所有する全定数を列挙する。private・生成宣言も含み、unsafe/partialの属性では除外しない。
3. 旧主定理の `Benitoite.Release.progress`・`Benitoite.Release.preservation`・`Benitoite.Release.step_sound`・`Benitoite.Release.effect_soundness`・`Benitoite.Release.effect_soundness_noLamNames` の5名と、旧三モデルの `Benitoite.Release.Model.assumptions`・`Benitoite.Release.ModelTargets.assumptions`・`Benitoite.Release.ModelHttp.assumptions` の3名を加える。
4. 全名を `Name.toString` のUTF-8の昇順へ並べる。これは `LC_ALL=C` の並べ替えと同じ順序である。各名の後に改行を一つ置く。重複・対象の欠け・独自公理の宣言があればLean側で失敗させる。
5. `axioms.lean` は並べた全名へ `#print axioms` を適用する。`audit-inventory.lean` はモジュール別件数・属性と同じ全名を印字する。`L20_AUDIT_TARGETS` を指定すれば、同じ一覧をその出力先へ保存する。保存先は<tmp>とする。

formal/で次を実行する。環境変数を省略しても、A-Lは自分で対象を列挙して検査する。

```sh
l20_targets=$(mktemp)
l20_axioms=$(mktemp)
L20_AUDIT_TARGETS="$l20_targets" lake env lean -M 12288 \
  ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/axioms.lean > "$l20_axioms"
shasum -a 256 "$l20_targets" "$l20_axioms"
python3 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/s/validate.py \
  --targets "$l20_targets" --axioms "$l20_axioms"
```

[validate.py](s/validate.py) は、一覧の大きさ・SHA-256・昇順・一意性・対象と出力の集合の一致・許可公理の集合を検査する。一覧を指定しなければinventoryを再実行して一時ディレクトリに生成する。二つの台本が作る一覧も今回バイト単位で照合した。[audit-modules.txt](audit-modules.txt) と [audit-flags.txt](audit-flags.txt) は小さい入力確認の記録として改造内に残す。

## 再開2の結果

具体例を足す前に、一覧を外した台本を再実行した。対象23,444件、一覧1,603,426 bytes、SHA-256 `6077c0a825fa1da3cc1ba44c58b7abce7a60fa6abbf81ca954ca5421b101322a` で、外した一覧とバイト単位で一致した。公理の生出力も2,598,531 bytes、SHA-256 `cb80f41a364957e78e3c35aa79be473ffed172e6d0230fa63a1e728702cfbda2` で再開1と一致し、件数・結果が変わらないことを確認した。

その後、既定ビルドの具体例と名前の修正を反映して、再度A-Lを実行した。対象の増加は一つの新規モジュールと既存の例の追加によるものである。定義・規則・前提・公理の変更ではない。

| 項目 | 件数 |
|---|---:|
| 対象モジュール | 315 |
| そのモジュールの全定数 | 23,543 |
| 追加する旧主定理・三モデル | 8 |
| 重複を除いた対象と出力 | **23,551** |
| 公理への依存なし | 8,929 |
| 許可された三公理の部分集合への依存 | 14,622 |
| sorryAx・独自公理・許可外の依存・対象の欠け・重複出力 | **各0** |

| 依存する公理の集合 | 件数 |
|---|---:|
| none | 8,929 |
| propext | 5,497 |
| Classical.choice + Quot.sound + propext | 8,124 |
| Quot.sound + propext | 989 |
| Classical.choice | 1 |
| Classical.choice + propext | 2 |
| Quot.sound | 9 |

十の移送は `Benitoite.Release.Refinement.HasTypeVQ` と `HasTypeCQ` のそれぞれの `shift_values`・`shift_types`・`subst`・`subst_under_none`・`narrow` であり、列挙に含まれる。Sの全125手書き宣言も含む。

段全体でisUnsafe又はisPartialの属性が立つ生成定数は282個で、再開1から増えていない。これらも全て検査し、許可三公理以外の依存は0件である。Sの新規六モジュールに該当は0個である。

| 生の記録（保存先は<tmp>） | 大きさ | SHA-256 |
|---|---:|---|
| 最終の対象一覧 | 1,617,922 bytes | `ed04f28e84cb2a687ae69753372c6852d5329515ffac9aae98b864818965b069` |
| 最終のA-L生出力 | 2,617,243 bytes | `5c175df61ad6d6829bcf53368e40ff8d0fd4d19a4cea1a25bc9e6007b32e7fb5` |

最終のA-Lは終了0、外側17.577秒。[audit-summary.json](audit-summary.json) に再開1との比較と最終の件数・大きさ・SHA-256を置く。対象の一覧と生出力の全名は一対一で、出力の重複と欠けは0件である。初回の台本の型検査で返った診断も [Sの検査記録](s/checks-resume2.jsonl) に保存し、成功へ読み替えていない。

監査は宣言の公理依存を調べる。型付け・意味・全体合成・実表・独立レビュー・設計者の受け入れの代わりにはしない。本体・計測器の最大常駐量は未取得であり、正式な段末の採取は取りまとめが担当する。
