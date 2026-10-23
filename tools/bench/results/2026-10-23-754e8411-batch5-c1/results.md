# 版どうしの性能比較

候補: `754e8411cc2dd3614792433d7c259d1818ba7673`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013142 | 0.000132 |
| functions-main-0-0 | after | 0.013104 | 0.000754 |
| functions-main-0-1 | before | 0.013137 | 0.000199 |
| functions-main-0-1 | after | 0.013252 | 0.000323 |
| functions-main-1000-0 | before | 0.030643 | 0.000255 |
| functions-main-1000-0 | after | 0.031342 | 0.000835 |
| functions-main-1000-1 | before | 0.030588 | 0.000342 |
| functions-main-1000-1 | after | 0.031303 | 0.000601 |
| functions-args-0-0 | before | 0.013049 | 0.000205 |
| functions-args-0-0 | after | 0.013126 | 0.000140 |
| functions-args-0-1 | before | 0.013107 | 0.000253 |
| functions-args-0-1 | after | 0.013141 | 0.000044 |
| functions-args-1000-0 | before | 0.047603 | 0.000451 |
| functions-args-1000-0 | after | 0.048253 | 0.000458 |
| functions-args-1000-1 | before | 0.047646 | 0.000721 |
| functions-args-1000-1 | after | 0.047783 | 0.000887 |
| functions-modules-0-0 | before | 0.013370 | 0.000377 |
| functions-modules-0-0 | after | 0.013250 | 0.000101 |
| functions-modules-0-1 | before | 0.013170 | 0.000306 |
| functions-modules-0-1 | after | 0.013310 | 0.000073 |
| functions-modules-1000-0 | before | 0.024404 | 0.000233 |
| functions-modules-1000-0 | after | 0.024924 | 0.000522 |
| functions-modules-1000-1 | before | 0.024357 | 0.000098 |
| functions-modules-1000-1 | after | 0.024996 | 0.000515 |
| existing-fib | before | 0.013606 | 0.000563 |
| existing-fib | after | 0.013726 | 0.000220 |
| existing-loop | before | 0.013635 | 0.000374 |
| existing-loop | after | 0.013738 | 0.000141 |
| existing-string | before | 0.013674 | 0.000855 |
| existing-string | after | 0.013848 | 0.000327 |
| higher-0-0 | before | 0.013213 | 0.000874 |
| higher-0-0 | after | 0.013232 | 0.000071 |
| higher-1-0 | before | 0.014277 | 0.000691 |
| higher-1-0 | after | 0.014212 | 0.000487 |
| classes-0 | before | 0.018910 | 0.000299 |
| classes-0 | after | 0.019116 | 0.000592 |
| higher-0-300 | before | 0.026170 | 0.000249 |
| higher-0-300 | after | 0.027067 | 0.000544 |
| higher-1-300 | before | 0.029127 | 0.000306 |
| higher-1-300 | after | 0.029511 | 0.000513 |
| classes-300 | before | 0.037638 | 0.000722 |
| classes-300 | after | 0.038197 | 0.000438 |
| depth-0-8 | before | 0.014645 | 0.000515 |
| depth-0-8 | after | 0.014967 | 0.000318 |
| depth-1-8 | before | 0.014828 | 0.000586 |
| depth-1-8 | after | 0.014939 | 0.000389 |
| f1-nofail-call | before | 0.014133 | 0.001173 |
| f1-nofail-call | after | 0.014200 | 0.000126 |
| f1-join-effects | before | 0.013959 | 0.000723 |
| f1-join-effects | after | 0.014198 | 0.000085 |
| control-16.3 | before | 0.013142 | 0.000419 |
| control-16.3 | after | 0.013115 | 0.000218 |
| property-seven-24-20-1000-all-ok | before | 0.039630 | 0.001031 |
| property-seven-24-20-1000-all-ok | after | 0.040034 | 0.000158 |
| property-seven-24-20-1000-always-error | before | 0.038315 | 0.000673 |
| property-seven-24-20-1000-always-error | after | 0.038314 | 0.000216 |
| property-distinct-24-20-1000-all-ok | before | 0.038845 | 0.000705 |
| property-distinct-24-20-1000-all-ok | after | 0.039211 | 0.000530 |
| property-distinct-24-20-1000-always-error | before | 0.037816 | 0.000923 |
| property-distinct-24-20-1000-always-error | after | 0.038362 | 0.000370 |
| property-zero-24-20-1000-all-ok | before | 0.039027 | 0.001223 |
| property-zero-24-20-1000-all-ok | after | 0.039612 | 0.000374 |
| property-zero-24-20-1000-always-error | before | 0.038108 | 0.000759 |
| property-zero-24-20-1000-always-error | after | 0.038398 | 0.000102 |
| property-max-24-20-1000-all-ok | before | 0.039520 | 0.001183 |
| property-max-24-20-1000-all-ok | after | 0.039835 | 0.000430 |
| property-max-24-20-1000-always-error | before | 0.038363 | 0.000829 |
| property-max-24-20-1000-always-error | after | 0.038082 | 0.000305 |
| order-string-candidates | before | 0.037620 | 0.000959 |
| order-string-candidates | after | 0.038100 | 0.000268 |
| order-string-all-ok | before | 0.039008 | 0.000723 |
| order-string-all-ok | after | 0.038992 | 0.000453 |
| order-string-always-error | before | 0.038124 | 0.000690 |
| order-string-always-error | after | 0.038718 | 0.001167 |
| order-map-candidates | before | 0.038271 | 0.000868 |
| order-map-candidates | after | 0.038652 | 0.000325 |
| order-map-all-ok | before | 0.038832 | 0.000879 |
| order-map-all-ok | after | 0.039065 | 0.000190 |
| order-map-always-error | before | 0.038429 | 0.000755 |
| order-map-always-error | after | 0.038482 | 0.000380 |
| order-record-candidates | before | 0.038639 | 0.000961 |
| order-record-candidates | after | 0.038963 | 0.000213 |
| order-record-all-ok | before | 0.038827 | 0.000882 |
| order-record-all-ok | after | 0.039124 | 0.000408 |
| order-record-always-error | before | 0.038656 | 0.000924 |
| order-record-always-error | after | 0.038938 | 0.000563 |
| build-string-builder-8-0 | before | 0.015852 | 0.000138 |
| build-string-builder-8-0 | after | 0.015920 | 0.000129 |
| build-string-builder-all-8-0 | before | 0.015974 | 0.000112 |
| build-string-builder-all-8-0 | after | 0.016023 | 0.000202 |
| build-string-concatenate-8-0 | before | 0.015974 | 0.000467 |
| build-string-concatenate-8-0 | after | 0.015885 | 0.000226 |
| build-string-join-8-0 | before | 0.015822 | 0.000471 |
| build-string-join-8-0 | after | 0.015845 | 0.000206 |
| build-list-builder-8-0 | before | 0.016099 | 0.000431 |
| build-list-builder-8-0 | after | 0.016143 | 0.000154 |
| build-list-builder-all-8-0 | before | 0.016027 | 0.000362 |
| build-list-builder-all-8-0 | after | 0.016037 | 0.000095 |
| build-list-concatenate-8-0 | before | 0.016101 | 0.000454 |
| build-list-concatenate-8-0 | after | 0.016223 | 0.000103 |
| build-list-fold-8-0 | before | 0.016043 | 0.000425 |
| build-list-fold-8-0 | after | 0.015980 | 0.000114 |
| build-bytes-builder-8-0 | before | 0.016002 | 0.000335 |
| build-bytes-builder-8-0 | after | 0.016197 | 0.000134 |
| build-bytes-builder-all-8-0 | before | 0.015922 | 0.000346 |
| build-bytes-builder-all-8-0 | after | 0.016086 | 0.000296 |
| build-bytes-concatenate-8-0 | before | 0.016480 | 0.000397 |
| build-bytes-concatenate-8-0 | after | 0.016304 | 0.000190 |
| patterns-integer-100 | before | 0.014391 | 0.001283 |
| patterns-integer-100 | after | 0.014411 | 0.000218 |
| codegen-let-100 | before | 0.016898 | 0.000239 |
| codegen-let-100 | after | 0.016873 | 0.000130 |
| bridge-shared-8 | before | 0.004460 | 0.000165 |
| bridge-shared-8 | after | 0.004527 | 0.000528 |
| external-tests-normal-1 | before | 0.018012 | 0.000312 |
| external-tests-normal-1 | after | 0.017961 | 0.000906 |
| runtime-fib-short | before | 0.017922 | 0.000227 |
| runtime-fib-short | after | 0.018106 | 0.000786 |
| runtime-loop-short | before | 0.023547 | 0.000382 |
| runtime-loop-short | after | 0.023801 | 0.000415 |
| runtime-list-short | before | 0.029286 | 0.000291 |
| runtime-list-short | after | 0.029718 | 0.000792 |
| runtime-tree-short | before | 0.018233 | 0.000308 |
| runtime-tree-short | after | 0.018437 | 0.000782 |
| runtime-eval-short | before | 0.022073 | 0.000941 |
| runtime-eval-short | after | 0.022776 | 0.000932 |
| runtime-string-short | before | 0.016717 | 0.000353 |
| runtime-string-short | after | 0.016802 | 0.000925 |
| runtime-println-short | before | 0.017322 | 0.000419 |
| runtime-println-short | after | 0.017212 | 0.000204 |
| runtime-lines-short | before | 0.016643 | 0.000257 |
| runtime-lines-short | after | 0.016801 | 0.000158 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.5334e-05 | 3.74e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 2.875e-06 | 5.42e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 1.8666e-05 | 4.18e-07 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.4708e-05 | 2.91e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 2.875e-06 | 1.25e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.7459e-05 | 2.5e-07 |
| unique_nodes | count | bridge-shared-8 | after | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | after | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | after | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | after | 5 | 7 | 0 |
| runtime_compilations | count | external-tests-normal-1 | before | 5 | 1 | 0 |
| component_keys | count | external-tests-normal-1 | before | 5 | 1 | 0 |
| runtime_compilations | count | external-tests-normal-1 | after | 5 | 1 | 0 |
| component_keys | count | external-tests-normal-1 | after | 5 | 1 | 0 |

## 比較状態と機能

```json
{
  "commits": {
    "before": "a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a",
    "after": "754e8411cc2dd3614792433d7c259d1818ba7673"
  },
  "features": {
    "before": {
      "shrink_steps": true,
      "builders": true
    },
    "after": {
      "shrink_steps": true,
      "builders": true
    }
  },
  "skipped": [],
  "unavailable_probes": {}
}
```

## 目標

| 目標 | 判定 | 値 | 上限 |
|---|---|---:|---:|
| functions-main-0-0 | 判定不能 | None | 0.002 |
| functions-main-0-1 | 判定不能 | None | 0.002 |
| functions-main-1000-0 | 判定不能 | None | 0.0030643208000000755 |
| functions-main-1000-1 | 判定不能 | None | 0.0030588125000008404 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.004760275000001002 |
| functions-args-1000-1 | 判定不能 | None | 0.004764583299999004 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.002440400000000409 |
| functions-modules-1000-1 | 達成 | 0.0006390420000030872 | 0.002435729100000117 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 達成 | 0.0008972090000014532 | 0.0026169749999994 |
| higher-1-300 | 判定不能 | None | 0.00291274170000122 |
| classes-300 | 判定不能 | None | 0.003763783299999091 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 判定不能 | None | 0.002 |
| f1-nofail-call | 判定不能 | None | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.003962991699999918 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.003831462499999816 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.0038845166000001543 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.0037816290999998616 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.0039026542000001998 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.0038108457999996405 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.003952016699999206 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.003836308299999303 |
| order-string-candidates | 判定不能 | None | 0.0037620208000006985 |
| order-string-all-ok | 判定不能 | None | 0.003900762500001065 |
| order-string-always-error | 判定不能 | None | 0.0038123957999999904 |
| order-map-candidates | 判定不能 | None | 0.0038271082999997933 |
| order-map-all-ok | 判定不能 | None | 0.003883187499999963 |
| order-map-always-error | 判定不能 | None | 0.003842899999999361 |
| order-record-candidates | 判定不能 | None | 0.0038638542000001054 |
| order-record-all-ok | 判定不能 | None | 0.003882716700000799 |
| order-record-always-error | 判定不能 | None | 0.0038655542000000766 |
| build-string-builder-8-0 | 判定不能 | None | 0.002 |
| build-string-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-string-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-string-join-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-list-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-list-fold-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-bytes-concatenate-8-0 | 判定不能 | None | 0.002 |
| runtime-fib-short | 判定不能 | None | 0.002 |
| runtime-loop-short | 判定不能 | None | 0.002354741700000318 |
| runtime-list-short | 判定不能 | None | 0.002928625000001262 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.0022073207999994795 |
| runtime-string-short | 判定不能 | None | 0.002 |
| runtime-println-short | 判定不能 | None | 0.002 |
| runtime-lines-short | 判定不能 | None | 0.002 |
| patterns-integer-100 | 判定不能 | None | 0.002 |
| codegen-let-100 | 判定不能 | None | 0.002 |
| bridge-shared-8 | 判定不能 | None | 0.002 |
| external-tests-normal-1 | 判定不能 | None | 0.002 |

時間差が2 ms未満、非正、または両標本集合のIQRの和以下なら比率は判定不能。確保量と整数計数には2 msを適用しない。標本数不足も合格にしない。

## 別実行と未取得

段別時間は補助バイナリのload_parse・resolve・typeck。読み込みとlex/parseは公開loaderの一つの区間に含む。reparseは同じ読み込み済みバイト列の別パスであり、load_parseへ加算しない。
RSSは既存rss.pyの独立実行。alloc-statsは別targetのバイナリ。全標本・照合出力・コマンドはsection JSONに保存する。
Fail正規化の内部訪問節数・縮小器内部の生成/比較回数は未取得。shrinksとshrinkWorkは実出力から検査する。
samplyはprofile.shの別実行で取得する。未取得のプロファイルから原因を断定しない。

## 段ごとの外側時間

```json
{
  "16.2": {
    "verify": 1.836417124999997,
    "cli": 5.303524378000006,
    "warmup": 0.6611276239999881,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 0.9088661249999888,
    "cli": 3.607184960999973,
    "warmup": 0.4286322889999923,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3397960000000069,
    "cli": 9.342360707999987,
    "warmup": 1.3262067479999757,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.36727925000000994,
    "cli": 3.51076158299999,
    "warmup": 0.356005000000053,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.09842779200000962,
    "cli": 0.2779245830000008,
    "warmup": 0.028994290999989403,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.03649091700000895,
    "cli": 0.3277915830000069,
    "warmup": 0.03383924900001034,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.009063791999992077,
    "cli": 0.2002238339999991,
    "warmup": 0.008833500000008598,
    "probe_warmup": 0.007866292000016983,
    "rss": 0,
    "stages": 0.03843016700000135,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.038785458000006656,
    "cli": 0.34019479100000183,
    "warmup": 0.035009333999994396,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.17845833200000527
  },
  "runtime": {
    "verify": 0.3311651249999983,
    "cli": 2.9033998739999873,
    "warmup": 0.3261783340000193,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
