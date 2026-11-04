# 内部エラーの20等号と全失敗

保存形の九欄と、生産箇所の元入力を分ける。20は九つのsave等号＋九つのfromCheck等号＋準備失敗の元入力二等号であり、20種類の構造体の欄があるという意味ではない。全準備失敗の残る解析・解決・起点の等号も prepare_reader の結論に含む。

| 番号 | 生産箇所 | 保存欄 | 判定・全称の実証拠 |
|---|---|---|---|
| 1 | save | originalPattern | 一致：`Benitoite.Release.Refinement.AtError.save_exact`。全入力・全snapshot・全失敗を量化する |
| 2 | save | originalTarget | 一致：`Benitoite.Release.Refinement.AtError.save_exact`。全入力・全snapshot・全失敗を量化する |
| 3 | save | failure | 一致：`Benitoite.Release.Refinement.AtError.save_exact`。全入力・全snapshot・全失敗を量化する |
| 4 | save | parsedPattern | 一致：`Benitoite.Release.Refinement.AtError.save_exact`。全入力・全snapshot・全失敗を量化する |
| 5 | save | parsedTarget | 一致：`Benitoite.Release.Refinement.AtError.save_exact`。全入力・全snapshot・全失敗を量化する |
| 6 | save | resolvedPatterns | 一致：`Benitoite.Release.Refinement.AtError.save_exact`。全入力・全snapshot・全失敗を量化する |
| 7 | save | resolvedTarget | 一致：`Benitoite.Release.Refinement.AtError.save_exact`。全入力・全snapshot・全失敗を量化する |
| 8 | save | patternBase | 一致：`Benitoite.Release.Refinement.AtError.save_exact`。全入力・全snapshot・全失敗を量化する |
| 9 | save | targetBase | 一致：`Benitoite.Release.Refinement.AtError.save_exact`。全入力・全snapshot・全失敗を量化する |
| 10 | fromCheck | originalPattern | 一致：`Benitoite.Release.Refinement.AtErrorReaders.check_reader`。全入力・全snapshot・全失敗を量化する |
| 11 | fromCheck | originalTarget | 一致：`Benitoite.Release.Refinement.AtErrorReaders.check_reader`。全入力・全snapshot・全失敗を量化する |
| 12 | fromCheck | failure | 一致：`Benitoite.Release.Refinement.AtErrorReaders.check_reader`。全入力・全snapshot・全失敗を量化する |
| 13 | fromCheck | parsedPattern | 一致：`Benitoite.Release.Refinement.AtErrorReaders.check_reader`。全入力・全snapshot・全失敗を量化する |
| 14 | fromCheck | parsedTarget | 一致：`Benitoite.Release.Refinement.AtErrorReaders.check_reader`。全入力・全snapshot・全失敗を量化する |
| 15 | fromCheck | resolvedPatterns | 一致：`Benitoite.Release.Refinement.AtErrorReaders.check_reader`。全入力・全snapshot・全失敗を量化する |
| 16 | fromCheck | resolvedTarget | 一致：`Benitoite.Release.Refinement.AtErrorReaders.check_reader`。全入力・全snapshot・全失敗を量化する |
| 17 | fromCheck | patternBase | 一致：`Benitoite.Release.Refinement.AtErrorReaders.check_reader`。全入力・全snapshot・全失敗を量化する |
| 18 | fromCheck | targetBase | 一致：`Benitoite.Release.Refinement.AtErrorReaders.check_reader`。全入力・全snapshot・全失敗を量化する |
| 19 | AtPrepareの全失敗 | originalPattern | 一致：`Benitoite.Release.Refinement.AtErrorReaders.prepare_reader`。全入力・全snapshot・全失敗を量化する |
| 20 | AtPrepareの全失敗 | originalTarget | 一致：`Benitoite.Release.Refinement.AtErrorReaders.prepare_reader`。全入力・全snapshot・全失敗を量化する |

## 全失敗形

7構成子のunboundを全5起点へ展開した11形を列挙する。各行の保存と観測の言明は全入力を量化する。到達しない形を実際の失敗存在とは数えない。

| 失敗形 | 保存と既存読者 | 到達性の区別 |
|---|---|---|
| outsideScope | `Benitoite.Release.Refinement.AtError.save_exact`、`Benitoite.Release.Refinement.AtErrorReaders.check_reader`、`Benitoite.Release.Refinement.AtErrorReaders.observed` | 保持する構成子であり、現行checkAtは返さない。旧OutsideScopeを消さない。 |
| unbound root | `Benitoite.Release.Refinement.AtError.save_exact`、`Benitoite.Release.Refinement.AtErrorReaders.check_reader`、`Benitoite.Release.Refinement.AtErrorReaders.observed` | 任意の起点の保存を扱う。準備成功後のtarget解決は成功し、snapshotなしのbasedは準備で拒否する。 |
| unbound cwd | `Benitoite.Release.Refinement.AtError.save_exact`、`Benitoite.Release.Refinement.AtErrorReaders.check_reader`、`Benitoite.Release.Refinement.AtErrorReaders.observed` | 任意の起点の保存を扱う。準備成功後のtarget解決は成功し、snapshotなしのbasedは準備で拒否する。 |
| unbound home | `Benitoite.Release.Refinement.AtError.save_exact`、`Benitoite.Release.Refinement.AtErrorReaders.check_reader`、`Benitoite.Release.Refinement.AtErrorReaders.observed` | 任意の起点の保存を扱う。準備成功後のtarget解決は成功し、snapshotなしのbasedは準備で拒否する。 |
| unbound work | `Benitoite.Release.Refinement.AtError.save_exact`、`Benitoite.Release.Refinement.AtErrorReaders.check_reader`、`Benitoite.Release.Refinement.AtErrorReaders.observed` | 任意の起点の保存を扱う。準備成功後のtarget解決は成功し、snapshotなしのbasedは準備で拒否する。 |
| unbound tmp | `Benitoite.Release.Refinement.AtError.save_exact`、`Benitoite.Release.Refinement.AtErrorReaders.check_reader`、`Benitoite.Release.Refinement.AtErrorReaders.observed` | 任意の起点の保存を扱う。準備成功後のtarget解決は成功し、snapshotなしのbasedは準備で拒否する。 |
| secretsUnbound | `Benitoite.Release.Refinement.AtError.save_exact`、`Benitoite.Release.Refinement.AtErrorReaders.check_reader`、`Benitoite.Release.Refinement.AtErrorReaders.observed` | 全記録を扱う。checkAtの実枝の存在は別である。 |
| invalidPattern | `Benitoite.Release.Refinement.AtError.save_exact`、`Benitoite.Release.Refinement.AtErrorReaders.check_reader`、`Benitoite.Release.Refinement.AtErrorReaders.observed` | 解析失敗とbound形成の拒否を保存する。形成された準備成功後のcheckAtからは排除する。 |
| invalidTarget | `Benitoite.Release.Refinement.AtError.save_exact`、`Benitoite.Release.Refinement.AtErrorReaders.check_reader`、`Benitoite.Release.Refinement.AtErrorReaders.observed` | 全記録を扱う。checkAtの実枝の存在は別である。 |
| dynamicCondition | `Benitoite.Release.Refinement.AtError.save_exact`、`Benitoite.Release.Refinement.AtErrorReaders.check_reader`、`Benitoite.Release.Refinement.AtErrorReaders.observed` | 全記録を扱う。checkAtの実枝の存在は別である。 |
| staticIndex | `Benitoite.Release.Refinement.AtError.save_exact`、`Benitoite.Release.Refinement.AtErrorReaders.check_reader`、`Benitoite.Release.Refinement.AtErrorReaders.observed` | 型付き閉じた添字の準備失敗では排除し、checkAtのbound不所属は保存する。 |

`Benitoite.Release.Refinement.AtPrepare.error_saved` は準備の全失敗を量化する。前群の15終端と成功4経路、準備成功後のcheckAt8葉は [群Dの全場合](../d/cases.md) を継承し、保存欄の表との直積へ再加算しない。全失敗形と観測は `AtErrorReaders.observed/prepare_reader/check_reader`、実行への入口 `ScopedTargetInputs.at_prepare/at_error` が保存欄を読む。`at_steps` は既存の `StateTyE.at_step` を直接使い、これらの入口を経由しない。

内部の全診断は `Benitoite.Release.Refinement.AtTargets.adequate_atError` で任意ws・全有効σに適格である。元入力の九欄は切詰めも文字列化もせず持ち、`Benitoite.Release.Refinement.Detail.originals_unobserved` が元入力を変えても暫定の項観測と照合の項観測が同じことを示す。変数パターンが束縛した生のエラー値の構造等号は主張しない。

`Benitoite.Release.Refinement.Detail.match_pattern_typed`、`Benitoite.Release.Refinement.HasTypeVQ.data_observation`、`Benitoite.Release.Refinement.HasTypeVQ.observation_declared`、`Benitoite.Release.Refinement.Exhaustive.atError` の同じ読者を使う。網羅性には同じPの `Program.StandardErrorComplete` が別に要る。

U02確定後・L70前に渡す未実装の受け口は、Detailの九欄から公開形への変換、ResultShape.Declared、Program.StandardErrorComplete、同じP.cons/Term/照合/網羅性である。公開の名前・完全署名・観測形は選択していない。公開の七Stringは現行の暫定の七String観測と同じだと仮定せず、元入力を生Valとして取り出す入口の有無も再点検する。引用・エスケープ・4096バイト上限・secretsの表示はR30/R60の表示と保存値を分けて照合する。
