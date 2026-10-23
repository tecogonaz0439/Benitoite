# 版どうしの性能比較

候補: `508a9b629f46908c2c4d2c4ac9a31b728a8a5734`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013095 | 0.000195 |
| functions-main-0-0 | after | 0.013186 | 0.000651 |
| functions-main-0-1 | before | 0.013157 | 0.000244 |
| functions-main-0-1 | after | 0.013207 | 0.000248 |
| functions-main-1000-0 | before | 0.030885 | 0.000172 |
| functions-main-1000-0 | after | 0.031225 | 0.000627 |
| functions-main-1000-1 | before | 0.030850 | 0.000237 |
| functions-main-1000-1 | after | 0.031250 | 0.000483 |
| functions-args-0-0 | before | 0.013150 | 0.000254 |
| functions-args-0-0 | after | 0.013042 | 0.000165 |
| functions-args-0-1 | before | 0.013062 | 0.000308 |
| functions-args-0-1 | after | 0.013027 | 0.000248 |
| functions-args-1000-0 | before | 0.047425 | 0.000394 |
| functions-args-1000-0 | after | 0.047642 | 0.000364 |
| functions-args-1000-1 | before | 0.047585 | 0.000824 |
| functions-args-1000-1 | after | 0.047652 | 0.000353 |
| functions-modules-0-0 | before | 0.013165 | 0.000522 |
| functions-modules-0-0 | after | 0.013035 | 0.000057 |
| functions-modules-0-1 | before | 0.012977 | 0.000234 |
| functions-modules-0-1 | after | 0.013085 | 0.000129 |
| functions-modules-1000-0 | before | 0.024396 | 0.000281 |
| functions-modules-1000-0 | after | 0.024601 | 0.002080 |
| functions-modules-1000-1 | before | 0.024294 | 0.000296 |
| functions-modules-1000-1 | after | 0.025387 | 0.000890 |
| existing-fib | before | 0.013599 | 0.000692 |
| existing-fib | after | 0.013764 | 0.000227 |
| existing-loop | before | 0.013718 | 0.000424 |
| existing-loop | after | 0.013534 | 0.000276 |
| existing-string | before | 0.013725 | 0.000843 |
| existing-string | after | 0.013731 | 0.000167 |
| higher-0-0 | before | 0.013170 | 0.000176 |
| higher-0-0 | after | 0.013097 | 0.000209 |
| higher-1-0 | before | 0.014050 | 0.000635 |
| higher-1-0 | after | 0.013953 | 0.000159 |
| classes-0 | before | 0.018954 | 0.000201 |
| classes-0 | after | 0.019041 | 0.000848 |
| higher-0-300 | before | 0.026301 | 0.000097 |
| higher-0-300 | after | 0.026852 | 0.000467 |
| higher-1-300 | before | 0.029036 | 0.000190 |
| higher-1-300 | after | 0.029759 | 0.000972 |
| classes-300 | before | 0.037913 | 0.000696 |
| classes-300 | after | 0.037857 | 0.000433 |
| depth-0-8 | before | 0.014532 | 0.000603 |
| depth-0-8 | after | 0.014314 | 0.000318 |
| depth-1-8 | before | 0.014680 | 0.000724 |
| depth-1-8 | after | 0.014730 | 0.000116 |
| f1-nofail-call | before | 0.014057 | 0.000642 |
| f1-nofail-call | after | 0.014063 | 0.000257 |
| f1-join-effects | before | 0.014074 | 0.000636 |
| f1-join-effects | after | 0.014038 | 0.000207 |
| control-16.3 | before | 0.012942 | 0.000402 |
| control-16.3 | after | 0.013114 | 0.000102 |
| property-seven-24-20-1000-all-ok | before | 0.039792 | 0.001013 |
| property-seven-24-20-1000-all-ok | after | 0.040088 | 0.000383 |
| property-seven-24-20-1000-always-error | before | 0.038245 | 0.001149 |
| property-seven-24-20-1000-always-error | after | 0.038421 | 0.000301 |
| property-distinct-24-20-1000-all-ok | before | 0.038506 | 0.001597 |
| property-distinct-24-20-1000-all-ok | after | 0.039024 | 0.000530 |
| property-distinct-24-20-1000-always-error | before | 0.038278 | 0.000817 |
| property-distinct-24-20-1000-always-error | after | 0.038359 | 0.000368 |
| property-zero-24-20-1000-all-ok | before | 0.039202 | 0.000702 |
| property-zero-24-20-1000-all-ok | after | 0.039318 | 0.000162 |
| property-zero-24-20-1000-always-error | before | 0.038323 | 0.001004 |
| property-zero-24-20-1000-always-error | after | 0.037986 | 0.000340 |
| property-max-24-20-1000-all-ok | before | 0.039501 | 0.000895 |
| property-max-24-20-1000-all-ok | after | 0.040091 | 0.000630 |
| property-max-24-20-1000-always-error | before | 0.037971 | 0.001017 |
| property-max-24-20-1000-always-error | after | 0.038233 | 0.000304 |
| order-string-candidates | before | 0.037704 | 0.000634 |
| order-string-candidates | after | 0.038260 | 0.000274 |
| order-string-all-ok | before | 0.038591 | 0.001315 |
| order-string-all-ok | after | 0.038699 | 0.000193 |
| order-string-always-error | before | 0.037496 | 0.001202 |
| order-string-always-error | after | 0.037945 | 0.000617 |
| order-map-candidates | before | 0.038304 | 0.000607 |
| order-map-candidates | after | 0.038267 | 0.000239 |
| order-map-all-ok | before | 0.038263 | 0.000987 |
| order-map-all-ok | after | 0.038680 | 0.000187 |
| order-map-always-error | before | 0.038134 | 0.001046 |
| order-map-always-error | after | 0.038322 | 0.000633 |
| order-record-candidates | before | 0.038420 | 0.001126 |
| order-record-candidates | after | 0.039051 | 0.000256 |
| order-record-all-ok | before | 0.038933 | 0.000570 |
| order-record-all-ok | after | 0.039234 | 0.000403 |
| order-record-always-error | before | 0.038809 | 0.000906 |
| order-record-always-error | after | 0.038860 | 0.000216 |
| build-string-builder-8-0 | before | 0.015945 | 0.000191 |
| build-string-builder-8-0 | after | 0.015738 | 0.000105 |
| build-string-builder-all-8-0 | before | 0.016005 | 0.000191 |
| build-string-builder-all-8-0 | after | 0.015768 | 0.000244 |
| build-string-concatenate-8-0 | before | 0.015643 | 0.000305 |
| build-string-concatenate-8-0 | after | 0.015812 | 0.000228 |
| build-string-join-8-0 | before | 0.015889 | 0.000603 |
| build-string-join-8-0 | after | 0.015805 | 0.000171 |
| build-list-builder-8-0 | before | 0.015856 | 0.000420 |
| build-list-builder-8-0 | after | 0.015926 | 0.000216 |
| build-list-builder-all-8-0 | before | 0.015858 | 0.000306 |
| build-list-builder-all-8-0 | after | 0.015976 | 0.000166 |
| build-list-concatenate-8-0 | before | 0.016075 | 0.000506 |
| build-list-concatenate-8-0 | after | 0.016007 | 0.000210 |
| build-list-fold-8-0 | before | 0.016095 | 0.000300 |
| build-list-fold-8-0 | after | 0.015874 | 0.000333 |
| build-bytes-builder-8-0 | before | 0.016055 | 0.000399 |
| build-bytes-builder-8-0 | after | 0.015936 | 0.000121 |
| build-bytes-builder-all-8-0 | before | 0.016082 | 0.000172 |
| build-bytes-builder-all-8-0 | after | 0.016146 | 0.000121 |
| build-bytes-concatenate-8-0 | before | 0.016346 | 0.000503 |
| build-bytes-concatenate-8-0 | after | 0.016141 | 0.000571 |
| patterns-integer-100 | before | 0.014229 | 0.000708 |
| patterns-integer-100 | after | 0.014331 | 0.000319 |
| codegen-let-100 | before | 0.016801 | 0.000429 |
| codegen-let-100 | after | 0.016776 | 0.000241 |
| bridge-shared-8 | before | 0.004257 | 0.000136 |
| bridge-shared-8 | after | 0.004353 | 0.000532 |
| external-tests-normal-1 | before | 0.017875 | 0.000254 |
| external-tests-normal-1 | after | 0.017830 | 0.000231 |
| runtime-fib-short | before | 0.017872 | 0.000193 |
| runtime-fib-short | after | 0.017864 | 0.001559 |
| runtime-loop-short | before | 0.023496 | 0.000284 |
| runtime-loop-short | after | 0.023805 | 0.000735 |
| runtime-list-short | before | 0.029176 | 0.000282 |
| runtime-list-short | after | 0.029694 | 0.000618 |
| runtime-tree-short | before | 0.018361 | 0.000432 |
| runtime-tree-short | after | 0.018457 | 0.001042 |
| runtime-eval-short | before | 0.021911 | 0.000254 |
| runtime-eval-short | after | 0.022252 | 0.000728 |
| runtime-string-short | before | 0.016755 | 0.000313 |
| runtime-string-short | after | 0.016751 | 0.000264 |
| runtime-println-short | before | 0.016939 | 0.000447 |
| runtime-println-short | after | 0.016984 | 0.000146 |
| runtime-lines-short | before | 0.016587 | 0.000301 |
| runtime-lines-short | after | 0.016466 | 0.000167 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.55e-05 | 3.75e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3e-06 | 2.92e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 1.8709e-05 | 7.51e-07 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.2333e-05 | 3.33e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 2.875e-06 | 2.08e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.5208e-05 | 6.23e-07 |
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
    "after": "508a9b629f46908c2c4d2c4ac9a31b728a8a5734"
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
| functions-main-1000-0 | 判定不能 | None | 0.003088487499999815 |
| functions-main-1000-1 | 判定不能 | None | 0.0030850250000000303 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.0047424583000008624 |
| functions-args-1000-1 | 判定不能 | None | 0.004758537499999705 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.0024396041000002812 |
| functions-modules-1000-1 | 判定不能 | None | 0.0024293874999997914 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.0026300667000001 |
| higher-1-300 | 判定不能 | None | 0.002903554200000258 |
| classes-300 | 判定不能 | None | 0.003791341699999862 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 判定不能 | None | 0.002 |
| f1-nofail-call | 判定不能 | None | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.003979195799999502 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.003824474999998984 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.0038505541999995785 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.003827837500000442 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.003920241699999849 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.003832316700000149 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.003950066699999866 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.00379705419999965 |
| order-string-candidates | 判定不能 | None | 0.0037704459000011074 |
| order-string-all-ok | 判定不能 | None | 0.0038591332999999397 |
| order-string-always-error | 判定不能 | None | 0.003749608300000773 |
| order-map-candidates | 判定不能 | None | 0.0038303749999997194 |
| order-map-all-ok | 判定不能 | None | 0.003826341599999239 |
| order-map-always-error | 判定不能 | None | 0.003813354199999708 |
| order-record-candidates | 判定不能 | None | 0.003841958299999249 |
| order-record-all-ok | 判定不能 | None | 0.003893250000000137 |
| order-record-always-error | 判定不能 | None | 0.0038808917000011434 |
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
| runtime-loop-short | 判定不能 | None | 0.002349558299999899 |
| runtime-list-short | 判定不能 | None | 0.002917620799999554 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.002191129199999864 |
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
    "verify": 2.151211625000002,
    "cli": 5.282335167999975,
    "warmup": 0.6564734199999975,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 0.9106651249999942,
    "cli": 3.576748875000021,
    "warmup": 0.427287249999992,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.338332292000004,
    "cli": 9.309801211000021,
    "warmup": 1.3231295830000107,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.3636900829999945,
    "cli": 3.494312166000043,
    "warmup": 0.35613708300002145,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.09757679199999814,
    "cli": 0.2749708329999976,
    "warmup": 0.029312165999996864,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.035711165999998684,
    "cli": 0.32724712499999953,
    "warmup": 0.03422816699999487,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.00889491700000633,
    "cli": 0.19782233399999427,
    "warmup": 0.008679457999988927,
    "probe_warmup": 0.007833749000013768,
    "rss": 0,
    "stages": 0.03798254299999826,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04090120800000818,
    "cli": 0.33613516600000537,
    "warmup": 0.03525483300001042,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.17738604099999122
  },
  "runtime": {
    "verify": 0.3347016249999939,
    "cli": 2.8893377080000135,
    "warmup": 0.32775287300000855,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
