# 版どうしの性能比較

候補: `50f3d4b94ed257c7494263d1aa35ca0c9f3ea389`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.011974 | 0.000575 |
| functions-main-0-0 | after | 0.011473 | 0.000286 |
| functions-main-0-1 | before | 0.012097 | 0.000328 |
| functions-main-0-1 | after | 0.010715 | 0.000458 |
| functions-main-1000-0 | before | 0.025120 | 0.000604 |
| functions-main-1000-0 | after | 0.015830 | 0.000428 |
| functions-main-1000-1 | before | 0.025767 | 0.000498 |
| functions-main-1000-1 | after | 0.016065 | 0.000609 |
| functions-args-0-0 | before | 0.011779 | 0.000411 |
| functions-args-0-0 | after | 0.010686 | 0.000240 |
| functions-args-0-1 | before | 0.011882 | 0.000446 |
| functions-args-0-1 | after | 0.010408 | 0.000288 |
| functions-args-1000-0 | before | 0.055615 | 0.000692 |
| functions-args-1000-0 | after | 0.020419 | 0.000742 |
| functions-args-1000-1 | before | 0.055628 | 0.000527 |
| functions-args-1000-1 | after | 0.020803 | 0.000739 |
| functions-modules-0-0 | before | 0.012395 | 0.000513 |
| functions-modules-0-0 | after | 0.011131 | 0.000403 |
| functions-modules-0-1 | before | 0.011747 | 0.000163 |
| functions-modules-0-1 | after | 0.010412 | 0.000571 |
| functions-modules-1000-0 | before | 0.029007 | 0.000176 |
| functions-modules-1000-0 | after | 0.016271 | 0.000465 |
| functions-modules-1000-1 | before | 0.029288 | 0.000497 |
| functions-modules-1000-1 | after | 0.017036 | 0.000501 |
| existing-fib | before | 0.012247 | 0.000524 |
| existing-fib | after | 0.010863 | 0.000362 |
| existing-loop | before | 0.011987 | 0.000245 |
| existing-loop | after | 0.010771 | 0.000610 |
| existing-string | before | 0.012462 | 0.000554 |
| existing-string | after | 0.011157 | 0.000732 |
| higher-0-0 | before | 0.011683 | 0.000457 |
| higher-0-0 | after | 0.010379 | 0.000703 |
| higher-1-0 | before | 0.013707 | 0.000443 |
| higher-1-0 | after | 0.011260 | 0.000376 |
| classes-0 | before | 0.018940 | 0.000468 |
| classes-0 | after | 0.016084 | 0.000819 |
| higher-0-300 | before | 0.022814 | 0.000497 |
| higher-0-300 | after | 0.020097 | 0.000650 |
| higher-1-300 | before | 0.027060 | 0.000989 |
| higher-1-300 | after | 0.022671 | 0.000514 |
| classes-300 | before | 0.041579 | 0.000875 |
| classes-300 | after | 0.030196 | 0.000719 |
| depth-0-8 | before | 0.014162 | 0.000306 |
| depth-0-8 | after | 0.012535 | 0.000583 |
| depth-1-8 | before | 0.014330 | 0.000537 |
| depth-1-8 | after | 0.011630 | 0.000197 |
| f1-nofail-call | before | 0.013704 | 0.000510 |
| f1-nofail-call | after | 0.011900 | 0.000465 |
| f1-join-effects | before | 0.013259 | 0.000591 |
| f1-join-effects | after | 0.011336 | 0.000578 |
| control-16.3 | before | 0.011527 | 0.000537 |
| control-16.3 | after | 0.010083 | 0.000290 |
| property-seven-24-20-1000-all-ok | before | 0.038121 | 0.000909 |
| property-seven-24-20-1000-all-ok | after | 0.036513 | 0.001099 |
| property-seven-24-20-1000-always-error | before | 0.037067 | 0.000590 |
| property-seven-24-20-1000-always-error | after | 0.034924 | 0.001198 |
| property-distinct-24-20-1000-all-ok | before | 0.038763 | 0.000523 |
| property-distinct-24-20-1000-all-ok | after | 0.035545 | 0.000875 |
| property-distinct-24-20-1000-always-error | before | 0.038978 | 0.000673 |
| property-distinct-24-20-1000-always-error | after | 0.034434 | 0.000876 |
| property-zero-24-20-1000-all-ok | before | 0.036309 | 0.000698 |
| property-zero-24-20-1000-all-ok | after | 0.035045 | 0.000264 |
| property-zero-24-20-1000-always-error | before | 0.035757 | 0.000748 |
| property-zero-24-20-1000-always-error | after | 0.034596 | 0.000843 |
| property-max-24-20-1000-all-ok | before | 0.457981 | 0.001542 |
| property-max-24-20-1000-all-ok | after | 0.035969 | 0.000881 |
| property-max-24-20-1000-always-error | before | 0.456776 | 0.003161 |
| property-max-24-20-1000-always-error | after | 0.034525 | 0.000412 |
| order-string-candidates | before | 0.035599 | 0.000215 |
| order-string-candidates | after | 0.034137 | 0.001008 |
| order-string-all-ok | before | 0.036582 | 0.000844 |
| order-string-all-ok | after | 0.034550 | 0.000476 |
| order-string-always-error | before | 0.035904 | 0.000790 |
| order-string-always-error | after | 0.034640 | 0.000664 |
| order-map-candidates | before | 0.035480 | 0.000288 |
| order-map-candidates | after | 0.034554 | 0.000309 |
| order-map-all-ok | before | 0.036188 | 0.000539 |
| order-map-all-ok | after | 0.034835 | 0.000775 |
| order-map-always-error | before | 0.035693 | 0.000636 |
| order-map-always-error | after | 0.034446 | 0.000586 |
| order-record-candidates | before | 0.035614 | 0.000656 |
| order-record-candidates | after | 0.034656 | 0.000387 |
| order-record-all-ok | before | 0.036012 | 0.000892 |
| order-record-all-ok | after | 0.034964 | 0.000732 |
| order-record-always-error | before | 0.036092 | 0.000540 |
| order-record-always-error | after | 0.035415 | 0.000405 |
| build-string-builder-8-0 | after | 0.012928 | 0.000311 |
| build-string-builder-all-8-0 | after | 0.012845 | 0.000506 |
| build-string-concatenate-8-0 | after | 0.012524 | 0.000418 |
| build-string-join-8-0 | after | 0.012640 | 0.000408 |
| build-list-builder-8-0 | after | 0.013397 | 0.000822 |
| build-list-builder-all-8-0 | after | 0.013467 | 0.000721 |
| build-list-concatenate-8-0 | after | 0.012977 | 0.000367 |
| build-list-fold-8-0 | after | 0.013195 | 0.000539 |
| build-bytes-builder-8-0 | after | 0.013076 | 0.000467 |
| build-bytes-builder-all-8-0 | after | 0.012882 | 0.000224 |
| build-bytes-concatenate-8-0 | after | 0.012881 | 0.000385 |
| runtime-fib-short | before | 0.016525 | 0.000519 |
| runtime-fib-short | after | 0.014577 | 0.000530 |
| runtime-loop-short | before | 0.020836 | 0.000579 |
| runtime-loop-short | after | 0.020351 | 0.000614 |
| runtime-list-short | before | 0.027359 | 0.000305 |
| runtime-list-short | after | 0.026515 | 0.000445 |
| runtime-tree-short | before | 0.015994 | 0.000701 |
| runtime-tree-short | after | 0.015061 | 0.000388 |
| runtime-eval-short | before | 0.019615 | 0.000502 |
| runtime-eval-short | after | 0.018692 | 0.000549 |
| runtime-string-short | before | 0.014910 | 0.000586 |
| runtime-string-short | after | 0.014413 | 0.000631 |
| runtime-println-short | before | 0.015554 | 0.000462 |
| runtime-println-short | after | 0.014580 | 0.000659 |
| runtime-lines-short | before | 0.015047 | 0.000603 |
| runtime-lines-short | after | 0.014753 | 0.000670 |

## 比較状態と機能

```json
{
  "commits": {
    "before": "6b0568a3ddcc46b0a0e64504139ce286a27fd86a",
    "after": "50f3d4b94ed257c7494263d1aa35ca0c9f3ea389"
  },
  "features": {
    "before": {
      "shrink_steps": false,
      "builders": false
    },
    "after": {
      "shrink_steps": true,
      "builders": true
    }
  },
  "skipped": [
    {
      "case": "build-string-builder-8-0",
      "state": "before",
      "reason": "missing features: builders"
    },
    {
      "case": "build-string-builder-all-8-0",
      "state": "before",
      "reason": "missing features: builders"
    },
    {
      "case": "build-string-concatenate-8-0",
      "state": "before",
      "reason": "missing features: builders"
    },
    {
      "case": "build-string-join-8-0",
      "state": "before",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-builder-8-0",
      "state": "before",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-builder-all-8-0",
      "state": "before",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-concatenate-8-0",
      "state": "before",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-fold-8-0",
      "state": "before",
      "reason": "missing features: builders"
    },
    {
      "case": "build-bytes-builder-8-0",
      "state": "before",
      "reason": "missing features: builders"
    },
    {
      "case": "build-bytes-builder-all-8-0",
      "state": "before",
      "reason": "missing features: builders"
    },
    {
      "case": "build-bytes-concatenate-8-0",
      "state": "before",
      "reason": "missing features: builders"
    }
  ],
  "unavailable_probes": {}
}
```

## 目標

| 目標 | 判定 | 値 | 上限 |
|---|---|---:|---:|
| functions-main-0-0 | 判定不能 | None | 0.002 |
| functions-main-0-1 | 達成 | -0.0013813750000082337 | 0.002 |
| functions-main-1000-0 | 達成 | -0.00928912600001297 | 0.0025119542000012988 |
| functions-main-1000-1 | 達成 | -0.009701708999998004 | 0.002576670899999556 |
| functions-args-0-0 | 達成 | -0.0010928749999976617 | 0.002 |
| functions-args-0-1 | 達成 | -0.001474374999986594 | 0.002 |
| functions-args-1000-0 | 達成 | -0.03519599999999912 | 0.0055615083000006395 |
| functions-args-1000-1 | 達成 | -0.034824916000005146 | 0.0055627833000002624 |
| functions-modules-0-0 | 達成 | -0.001263833000010095 | 0.002 |
| functions-modules-0-1 | 達成 | -0.001334875000011948 | 0.002 |
| functions-modules-1000-0 | 達成 | -0.012736541999984752 | 0.0029007166999988955 |
| functions-modules-1000-1 | 達成 | -0.012252083999996444 | 0.002928804200000457 |
| existing-fib | 達成 | -0.0013845410000072889 | 0.002 |
| existing-loop | 達成 | -0.0012160830000027545 | 0.002 |
| existing-string | 達成 | -0.0013051250000017944 | 0.002 |
| higher-0-0 | 達成 | -0.0013040420000010045 | 0.002 |
| higher-1-0 | 達成 | -0.002446790999997006 | 0.002 |
| classes-0 | 達成 | -0.002855458999988514 | 0.002 |
| higher-0-300 | 達成 | -0.0027169580000077076 | 0.0022813541999994412 |
| higher-1-300 | 達成 | -0.004389707999990833 | 0.0027060207999994646 |
| classes-300 | 達成 | -0.011382958999988091 | 0.004157933399999081 |
| depth-0-8 | 達成 | -0.0016268330000031028 | 0.002 |
| depth-1-8 | 達成 | -0.0026999589999832097 | 0.002 |
| f1-nofail-call | 達成 | -0.0018044159999988096 | 0.002 |
| f1-join-effects | 達成 | -0.001923000000005004 | 0.002 |
| control-16.3 | 達成 | -0.0014444159999982276 | 0.002 |
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.0038120708999997534 |
| property-seven-24-20-1000-always-error | 達成 | -0.0021426660000116726 | 0.0037066625000008457 |
| property-distinct-24-20-1000-all-ok | 達成 | -0.0032172500000058335 | 0.0038762500000004254 |
| property-distinct-24-20-1000-always-error | 達成 | -0.004544209000002297 | 0.0038978417000009816 |
| property-zero-24-20-1000-all-ok | 達成 | -0.001264041999988308 | 0.0036309416999998237 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.0035757375000002867 |
| property-max-24-20-1000-all-ok | 達成 | -0.42201279200000386 | 0.04579813750000028 |
| property-max-24-20-1000-always-error | 達成 | -0.4222507910000104 | 0.04567760830000083 |
| order-string-candidates | 達成 | -0.0014623330000063106 | 0.0035599083000008138 |
| order-string-all-ok | 達成 | -0.002032541999994919 | 0.003658212499999536 |
| order-string-always-error | 判定不能 | None | 0.0035903625000003104 |
| order-map-candidates | 達成 | -0.0009258740000035459 | 0.0035479791000000206 |
| order-map-all-ok | 達成 | -0.0013525420000064514 | 0.003618804200000625 |
| order-map-always-error | 達成 | -0.0012471260000097573 | 0.003569304200000545 |
| order-record-candidates | 判定不能 | None | 0.003561358299999995 |
| order-record-all-ok | 判定不能 | None | 0.003601224999999886 |
| order-record-always-error | 判定不能 | None | 0.003609158300000104 |
| build-string-builder-8-0 | 判定不能 | None | None |
| build-string-builder-all-8-0 | 判定不能 | None | None |
| build-string-concatenate-8-0 | 判定不能 | None | None |
| build-string-join-8-0 | 判定不能 | None | None |
| build-list-builder-8-0 | 判定不能 | None | None |
| build-list-builder-all-8-0 | 判定不能 | None | None |
| build-list-concatenate-8-0 | 判定不能 | None | None |
| build-list-fold-8-0 | 判定不能 | None | None |
| build-bytes-builder-8-0 | 判定不能 | None | None |
| build-bytes-builder-all-8-0 | 判定不能 | None | None |
| build-bytes-concatenate-8-0 | 判定不能 | None | None |
| runtime-fib-short | 達成 | -0.0019476260000033108 | 0.002 |
| runtime-loop-short | 判定不能 | None | 0.0020835542000000374 |
| runtime-list-short | 達成 | -0.000844000000000733 | 0.002735920799999292 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.002 |
| runtime-string-short | 判定不能 | None | 0.002 |
| runtime-println-short | 判定不能 | None | 0.002 |
| runtime-lines-short | 判定不能 | None | 0.002 |

差し引きが両標本集合の半幅の和以下なら判定不能。標本数不足も合格にしない。

## 別実行と未取得

段別時間は補助バイナリのload_parse・resolve・typeck。読み込みとlex/parseは公開loaderの一つの区間に含む。reparseは同じ読み込み済みバイト列の別パスであり、load_parseへ加算しない。
RSSは既存rss.pyの独立実行。alloc-statsは別targetのバイナリ。全標本・照合出力・コマンドはsection JSONに保存する。
Fail正規化の内部訪問節数・縮小器内部の生成/比較回数は未取得。shrinksとshrinkWorkは実出力から検査する。
samplyはprofile.shの別実行で取得する。未取得のプロファイルから原因を断定しない。

## 段ごとの外側時間

```json
{
  "16.2": {
    "verify": 0.5469590829999902,
    "cli": 4.400775957999997,
    "warmup": 0.5399273730000118,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0
  },
  "16.3": {
    "verify": 0.3805910829999988,
    "cli": 3.118819250999991,
    "warmup": 0.37834103900003413,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0
  },
  "16.4": {
    "verify": 2.0938143329999974,
    "cli": 12.64103799900002,
    "warmup": 2.06613574699999,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0
  },
  "16.5": {
    "verify": 0.15314329199999577,
    "cli": 1.4163772080000143,
    "warmup": 0.14451379300001577,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0
  },
  "runtime": {
    "verify": 0.2960297919999988,
    "cli": 2.5179333739999947,
    "warmup": 0.28449254300001314,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0
  }
}
```
