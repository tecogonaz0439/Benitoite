# R20 へ渡す保存幅・計上・有限検査の契約

2026-11-03。U03の決定を実装したLeanの契約である。Rustの探索・メモリの所有・実際の使用数との照合はR20に残る。本紙を渡したことをRust実装レビュー済みと数えない。完全署名は [signatures.md](signatures.md)、論理の既存署名は [A](../a/signatures.md)・[B/C](../b/signatures.md)・[J/K](../j/signatures.md) を正とする。

`proof-steps-v1` の規範は、U03の決定(2)の数え方（実際に行った基本操作を一回ずつ数える粒度）と、StepAccountingの状態遷移の契約である。AccountingWorkの操作列は規範に従う例示であり、Rustの実装が行う操作列そのものを定めない。実装が行う操作の表と全実作業の対応をR20で固定・レビューし、R50で照合する。例示の数をそのままRustの規範の使用数にはしない。

## 固定する値と成功の意味

| 項目 | 実物と契約 |
|---|---|
| 保存幅 | `CoefficientModel.storageBits` と `ProofContract.coefficientBits` は128。`CoefficientRepresented bits n` は0<bitsかつ−2^(bits−1)≤n<2^(bits−1)。保存する係数・定数・分枝のcut等へ適用する。LeanのモデルはIntと幅の引数だけを用い、ホストのポインタ幅に依存しない。32ビット構成でのi128の実装とusizeへの変換の実行照合はR20の受け入れ条件であり、L30では実行していない |
| 成功した部分演算 | `save_some`・`binary_some`・`neg_some`は数学Intの結果と表現可能性を返す。binaryは入力二つと結果を検査し、零除数は成功しない。除算はユークリッド除算（a=b*q+r、0≤r<|b|）であり、正の除数では床、負の除数では3/(−2)=−1・(−3)/(−2)=2となる。言語の零方向の除算や、負の除数での床とは別である。最小値/−1は保存域の外で拒否する。丸めの規則は正の除数だけを使う |
| 正確な一時域 | `temporaryProduct a b : Int`。正規化後に保存する値をsaveで再検査する。`product_then_save`は保存幅bitsと一時幅temporaryBitsを別に量化し、一時積の表現可能性を前提として受け取る。その幅で計算する定義ではない。u64最大値どうしの積は129ビットで表せても128には入らない。これを本番u64の正常乗算に変えない |
| 閉じたDecimal比較 | `decimalAligned c s d t = (c*10^t,d*10^s)` と `decimal_compare`。有効な96ビット係数・scale28の例でも保存幅を超える。保存係数の算術と別の正確な計算にする。一時域の不足を独立のunknown理由にしない。Floatは元のbitsを読む |
| 粒度 | 一byteの読取り・比較、一節点・辺・要素、固定幅算術一演算を一回ずつ。タグの重みは全て1。名前比較・可変長の一時算術は基本操作へ分解する |
| 版 | `StepAccounting.version` と `ProofContract.stepsVersion` は字面 `proof-steps-v1`。出力・設定・証明書の接続をR/Kで照合する。旧P2の使用数との一致は仮定しない |
| 状態 | `StepState`のlimit/used/pending/next、reserved=pending.length、remaining=limit−(used+reserved)。`StepState.Valid`はused+reserved≤limit、予約の一意性と番号の範囲 |
| 生成と破棄 | createは使用数+1と予約数+1を同時に確保。必要な後始末ごとに予約を作る。handle・所有本体・rollback要素・明示スタック要素を別々に扱う。destroyは予約数−1、使用数+1。二度目はmalformed |
| 途中停止と後始末 | `execute`は停止した接頭辞の状態を返す。予約済みのdestroyはremaining=0でも実行でき、`rollback_all`は全予約を一度ずつ使用済みへ移す。予約を初回の実消費として二重に数えない |
| 停止理由 | `ProofStop.malformed / coefficientRepresentation / stepsExhausted`の三種。深さ・枝数・入力長・証明書量による独立unknownを加えない |
| 成功とunknown | `replay_proved`はraw成功からだけEntailsを返す。`stopped_not_proved`は三停止を区別したまま証明済みを否定する。未証明・数値割当候補から実反例を作る入口はない |

## 全実作業との照合を受け持つ読者

`StepAccounting`は操作列に対する契約であり、Leanの数学的な`CertificateKernel.check`へ自動的に計数を挿入する定義ではない。`AccountingWork`が構成する操作列も、対象の処理と基本操作の対応を示す数学の資料である。R20は、予算を確認せずに探索や比較を済ませてから操作列の長さを引く実装にしてはならない。実際の各基本操作の直前に予算と予約を確認し、成功した接頭辞の使用数を保存する。Leanの操作列を構築する際のlist appendや証明の簡約を、Rust実装の未計上のコピーに対応させない。

| 処理・読者 | 基本操作への対応とR20の受け入れ条件 |
|---|---|
| 入力I・証明書Cの読取り | 全byteの読取り、タグ/整数の検証、節点・辺・要素を計上。stepsが先に尽きた場合はstepsExhausted、完了した不正検査はmalformed。未検査の証明書をprovedにしない |
| 名前比較・ハッシュ/鍵の同定 | compareBytesは最初の異なるbyteで止まり、各byteの読取りと比較を別に数える。同じ読取りをelementとreadByteの両方には数えない。ハッシュ計算のbyte走査も数え、同じハッシュだけで同じ項・宣言とみなさない |
| lookup・参照の変換 | lookupは訪れた節点・辺を数え、currentIdは現在の列の長さ未満のFinだけを返す。外の番号からusizeへの変換は対象構成で表せることを検査する。32ビット構成も同じ数学の番号を読む。無検査castなし |
| 正規化・係数merge | 入力二列の要素、実際に行う固定幅の演算・比較、出力要素の生成/予約、辺を計上。例示のreadCoefficient/addCoefficientsは数学Int入力を逐次検証し、失敗後の比較・加算・生成を記録しない。保存済みi128の入力に同じ比較を課さない。mergeの成功はzipWith加算と保存可能性を返す。不一致長はmalformed、表現外は別理由。複数項の正規化途中の正確な積と最終保存を区別する |
| clone・共有prefix | cloneElementsは各要素の読取り・生成/予約・辺を列挙。枝全体の暗黙cloneを避け、共有prefixを保持する。共有handleの生成/破棄と最後の所有本体の破棄を分けて対応させる |
| DNF/FM・整数分枝・捨てる規則 | 候補生成・係数演算・参照・枝への追記・枝の終了を全て計上。Refutationは現在のfacts/todoだけを読み、両枝を検査する。捨てる規則でOrを展開前に無関係な条件を落とせるが、探索順の実装と測定はR20/R70 |
| 一時の正確な算術 | Decimalの桁合わせ・u64の一時積を正確に計算。多word/limbを使う場合はその各基本演算を計上し、「一節点」に可変長の仕事を隠さない。CPU命令やallocatorの時間上限を保証しない |
| 反例候補の実現確認 | 純化した数値割当から元の値を構成し、その確認の全仕事を計上。負のlengthや未観測のsnapshotを実反例としない。実現できない候補は未証明のまま |
| 証明書の書込み | byte・節点・辺・要素の出力と保持/後始末を計上。独立の証明書量上限でunknownにしない |
| 独立検査 | 元のpremise/goal/certificateから鍵・NNFを再計算し、全参照と各有限規則を再検査する。外からの正規形・traceを信用しない。検査器自身の仕事も同じstepsに含める |
| rollback・明示スタック・終了 | 生成時の個別予約を使用済みへ移す。停止した接頭辞のpendingを失わず、全所有本体・共有handleの解放を対応させる。解放のためだけの独立上限なし |

`input_certificate_expansion`はI/C/Pを基本操作列として与えた場合に、使用数増分が三列の長さの和であることを示す。`within_limit`は使用数＋予約数とremainingの等式を示す。`ProofContract.Accepted`はこの計上記録の成功と同じ証明書のraw成功を二条件に分け、`Accepted.sound`が含意・列長・状態の不変条件を返す。Acceptedは上限0・空の操作列も許す二条件の関係であり、それ自体を全実作業の計上の証拠には使えない。checkAccountedは操作列の失敗時に同じ理由で停止し、成功時だけreplayProofを呼び、証明済みの結果からAcceptedを得る。操作列が実作業の全てを含むことは、この手続きからも結論しない。上表をR20の実装レビューで一行ずつ閉じる。

数学の含意の健全性は成功した有限証明書の検査だけを前提とし、使用数・探索順・既定値・設定元を前提へ足さない。stepsのu64既定値、単体/projectの選択・設定元はR20/R70、JSONと診断の理由はR60、公開候補との一致はV10に残る。100,000を決定した既定値として扱わない。R20の詳細化では明示スタックとpipelineのスタック検査、stack_probe、最適化した深い再帰のrelease_stackの割当も固定する。

## raw再生と上層の照合

rawの`CertificateKernel.check`、`linearize`、`normalize`、構造比較、EqProofのraw検査は実行可能である。`Certificate.checkIn`・`EqProof.checkIn`・`PreparedLeaf.checkIn`は、型・宣言のPropをclassicalなdecideで読む非計算的なBoolであり、Rustとの実行比較の対象と同じではない。R50はrawの有限比較と上層の有限表・証明の照合を分ける。

Mの同じ22行は `ProofReplayExamples.rows_checked` が核内で検査し、[replay.lean](replay.lean)が実行時に同じ列を読み、false又は件数不一致なら終了1とする。所要と出力の識別は results.md/verification.json に残す。核内の証明をnative_decideで置き換えない。ソルバの完全性、証明書byte数だけへの線形時間、CPU/OS/allocatorの時間上限はこの契約に含まれない。
