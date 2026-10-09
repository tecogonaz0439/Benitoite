# 0321. close の関数が解放の失敗を返す口を、状態のサービスに既定の本体付きで加える

- 状態: 採択
- 日付: 2026-10-07
- 関連章: [リソース](../01-spec/01-10-resources.md), [ランタイム](../02-impl/02-09-runtime.md)
- 関連 ADR: [0150](0150-resource-release-as-state.md), [0266](0266-task-and-resource-state-machines.md)
- 関連する未決事項: なし

## 背景

[リソース](../01-spec/01-10-resources.md)は、`File.closeWriter`・`Network.Http.closeListener` などの close の関数が、解放の失敗を `Result[Unit, E]` で返すと定める。一方、実装プランの作業 R25 が置いた状態のサービスの `begin_release`（実装プラン 10-11 の凍結したシグネチャ `fn begin_release(&mut self, resource: ResourceId) -> Result<Option<StateWait>, Stop>`）は、解放の失敗を、リソースの型の規則に従って `Stop`（実行時エラー `ReleaseFailed`）にするか無視する。凍結した戻り値には、失敗の理由を組み込みの関数へ返す道がない。2026-10-07 に、U3 の作業 L12 の事前点検でこの食い違いが見つかった。`closeReader`（R29）は、`File.Reader` の解放が失敗しないので表に出ていなかった。

## 決定

1. 状態のサービス（実装プラン 10-11 の `StateServices`）に、既定の本体を持つ関数を一つ加える。close の関数は、`begin_release` の代わりにこの関数で解放を始める。
   - 形の例: `fn begin_close(&mut self, resource: ResourceId) -> Result<CloseStep, Stop>`。`CloseStep` は、すぐに終わった（失敗の理由があればその文字列を持つ）か、待つ（待つ理由を持つ）かを表す。
   - 既定の本体は `begin_release` に委ね、失敗の理由を返さない（既存の実装を壊さない）。VM の側の実装が上書きし、記録した解放の失敗の理由を返す。
2. close の関数は、返った失敗の理由を `Result.Error` にして返す。失敗の理由を一度取り出したリソースは解放済みであり、後の `with` の解放は失敗なしで終わる（01-10「close が `Result.Error` を返しても解放済み」）。
3. `OsResource::release` は失敗を文字列で返すので、close の関数が返す誤りの種類は `Other`（`IOErrorKind.Other`、ネットワークでは対応する種類）とし、理由の文字列を添える。種類を細かく残すことは、本 ADR の範囲に含めない。

## 検討した代替案

- **`begin_release` の戻り値の型を変える**: 凍結した型の変更で、VM・参照インタプリタ・R29 の `closeReader` を直す必要がある。
- **書き込みのたびに出力を書き出し、解放では閉じるだけにする**: 型を変えないが、解放はほぼ失敗しなくなり、close の関数が失敗を返す場面と `with` の解放の失敗の報告の場面がなくなる。書き込みのバッファの意味もなくなる。
- **close の失敗も実行時エラーにする**: 01-10・03-07 の言語の規則を改めることになる。

## 帰結

- 実装プランの 10-11（または U3 の追加の章 10-16）に関数と型を加え、L12（`closeWriter`）が VM の側の上書きを書く。L30・L31 の `closeListener` も同じ口を使う。参照インタプリタは既定の本体のままでよいが、差分テストに解放の失敗のケースがあれば、参照インタプリタも上書きする。
- R25 の `vm/state.rs` を L12 が変える（00-03 の「ほかの作業のファイル」に当たらないと作業文書に書く）。
