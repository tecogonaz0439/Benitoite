# 版どうしの性能比較

候補: `2b7dabea796965deefcf05315118a95c9f1f4b33`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013030 | 0.000320 |
| functions-main-0-0 | after | 0.013184 | 0.000172 |
| functions-main-0-1 | before | 0.013456 | 0.000300 |
| functions-main-0-1 | after | 0.013465 | 0.000193 |
| functions-main-1000-0 | before | 0.030809 | 0.000730 |
| functions-main-1000-0 | after | 0.031466 | 0.000371 |
| functions-main-1000-1 | before | 0.030663 | 0.000186 |
| functions-main-1000-1 | after | 0.031498 | 0.000536 |
| functions-args-0-0 | before | 0.012952 | 0.000598 |
| functions-args-0-0 | after | 0.013367 | 0.000107 |
| functions-args-0-1 | before | 0.013349 | 0.000246 |
| functions-args-0-1 | after | 0.013176 | 0.000113 |
| functions-args-1000-0 | before | 0.047745 | 0.000334 |
| functions-args-1000-0 | after | 0.048213 | 0.000334 |
| functions-args-1000-1 | before | 0.048271 | 0.001248 |
| functions-args-1000-1 | after | 0.048157 | 0.000607 |
| functions-modules-0-0 | before | 0.013117 | 0.000115 |
| functions-modules-0-0 | after | 0.013227 | 0.000174 |
| functions-modules-0-1 | before | 0.013093 | 0.000219 |
| functions-modules-0-1 | after | 0.013204 | 0.000127 |
| functions-modules-1000-0 | before | 0.024271 | 0.000266 |
| functions-modules-1000-0 | after | 0.025192 | 0.000479 |
| functions-modules-1000-1 | before | 0.024211 | 0.000256 |
| functions-modules-1000-1 | after | 0.025219 | 0.000647 |
| existing-fib | before | 0.013617 | 0.000444 |
| existing-fib | after | 0.013764 | 0.000137 |
| existing-loop | before | 0.013599 | 0.000663 |
| existing-loop | after | 0.013699 | 0.000147 |
| existing-string | before | 0.013663 | 0.000546 |
| existing-string | after | 0.013773 | 0.000073 |
| higher-0-0 | before | 0.013241 | 0.000494 |
| higher-0-0 | after | 0.013277 | 0.000092 |
| higher-1-0 | before | 0.014288 | 0.000788 |
| higher-1-0 | after | 0.014263 | 0.000912 |
| classes-0 | before | 0.019067 | 0.000224 |
| classes-0 | after | 0.019277 | 0.000664 |
| higher-0-300 | before | 0.026009 | 0.000452 |
| higher-0-300 | after | 0.027346 | 0.000663 |
| higher-1-300 | before | 0.029215 | 0.000108 |
| higher-1-300 | after | 0.030586 | 0.000486 |
| classes-300 | before | 0.037773 | 0.000668 |
| classes-300 | after | 0.038432 | 0.000493 |
| depth-0-8 | before | 0.014602 | 0.001014 |
| depth-0-8 | after | 0.014728 | 0.000050 |
| depth-1-8 | before | 0.014848 | 0.000763 |
| depth-1-8 | after | 0.014901 | 0.000158 |
| f1-nofail-call | before | 0.014224 | 0.000588 |
| f1-nofail-call | after | 0.014329 | 0.000062 |
| f1-join-effects | before | 0.014131 | 0.000713 |
| f1-join-effects | after | 0.014260 | 0.000168 |
| control-16.3 | before | 0.013026 | 0.000152 |
| control-16.3 | after | 0.013137 | 0.000217 |
| property-seven-24-20-1000-all-ok | before | 0.039656 | 0.000830 |
| property-seven-24-20-1000-all-ok | after | 0.040242 | 0.000382 |
| property-seven-24-20-1000-always-error | before | 0.038105 | 0.001006 |
| property-seven-24-20-1000-always-error | after | 0.038804 | 0.000331 |
| property-distinct-24-20-1000-all-ok | before | 0.038883 | 0.000905 |
| property-distinct-24-20-1000-all-ok | after | 0.039309 | 0.000574 |
| property-distinct-24-20-1000-always-error | before | 0.038099 | 0.001280 |
| property-distinct-24-20-1000-always-error | after | 0.038617 | 0.000212 |
| property-zero-24-20-1000-all-ok | before | 0.039243 | 0.000684 |
| property-zero-24-20-1000-all-ok | after | 0.039782 | 0.000347 |
| property-zero-24-20-1000-always-error | before | 0.038405 | 0.000873 |
| property-zero-24-20-1000-always-error | after | 0.038554 | 0.000459 |
| property-max-24-20-1000-all-ok | before | 0.039706 | 0.000968 |
| property-max-24-20-1000-all-ok | after | 0.040110 | 0.000265 |
| property-max-24-20-1000-always-error | before | 0.038204 | 0.000963 |
| property-max-24-20-1000-always-error | after | 0.038578 | 0.000429 |
| order-string-candidates | before | 0.037742 | 0.001080 |
| order-string-candidates | after | 0.038310 | 0.000623 |
| order-string-all-ok | before | 0.038594 | 0.000951 |
| order-string-all-ok | after | 0.039023 | 0.000416 |
| order-string-always-error | before | 0.037899 | 0.001762 |
| order-string-always-error | after | 0.038563 | 0.000538 |
| order-map-candidates | before | 0.038221 | 0.001053 |
| order-map-candidates | after | 0.038777 | 0.000162 |
| order-map-all-ok | before | 0.038527 | 0.000843 |
| order-map-all-ok | after | 0.039016 | 0.000511 |
| order-map-always-error | before | 0.038458 | 0.001337 |
| order-map-always-error | after | 0.038596 | 0.000253 |
| order-record-candidates | before | 0.038824 | 0.000841 |
| order-record-candidates | after | 0.039225 | 0.000521 |
| order-record-all-ok | before | 0.038590 | 0.000622 |
| order-record-all-ok | after | 0.039404 | 0.000256 |
| order-record-always-error | before | 0.039208 | 0.000771 |
| order-record-always-error | after | 0.039545 | 0.001447 |
| build-string-builder-8-0 | before | 0.016220 | 0.000166 |
| build-string-builder-8-0 | after | 0.016539 | 0.000173 |
| build-string-builder-all-8-0 | before | 0.016259 | 0.000243 |
| build-string-builder-all-8-0 | after | 0.016502 | 0.000474 |
| build-string-concatenate-8-0 | before | 0.016081 | 0.000618 |
| build-string-concatenate-8-0 | after | 0.016310 | 0.000328 |
| build-string-join-8-0 | before | 0.015835 | 0.000619 |
| build-string-join-8-0 | after | 0.015840 | 0.000116 |
| build-list-builder-8-0 | before | 0.015996 | 0.000457 |
| build-list-builder-8-0 | after | 0.016201 | 0.000158 |
| build-list-builder-all-8-0 | before | 0.015854 | 0.000497 |
| build-list-builder-all-8-0 | after | 0.016027 | 0.000502 |
| build-list-concatenate-8-0 | before | 0.016115 | 0.000395 |
| build-list-concatenate-8-0 | after | 0.016257 | 0.000266 |
| build-list-fold-8-0 | before | 0.016004 | 0.000146 |
| build-list-fold-8-0 | after | 0.016038 | 0.000139 |
| build-bytes-builder-8-0 | before | 0.015937 | 0.000270 |
| build-bytes-builder-8-0 | after | 0.016105 | 0.000101 |
| build-bytes-builder-all-8-0 | before | 0.016063 | 0.000318 |
| build-bytes-builder-all-8-0 | after | 0.016393 | 0.000227 |
| build-bytes-concatenate-8-0 | before | 0.016177 | 0.000261 |
| build-bytes-concatenate-8-0 | after | 0.016304 | 0.000132 |
| patterns-integer-100 | before | 0.014340 | 0.001007 |
| patterns-integer-100 | after | 0.014582 | 0.000273 |
| codegen-let-100 | before | 0.016798 | 0.000059 |
| codegen-let-100 | after | 0.017192 | 0.000191 |
| bridge-shared-8 | before | 0.004356 | 0.000160 |
| bridge-shared-8 | after | 0.004349 | 0.000373 |
| external-tests-normal-1 | before | 0.017893 | 0.000099 |
| external-tests-normal-1 | after | 0.018196 | 0.001002 |
| runtime-fib-short | before | 0.017876 | 0.000233 |
| runtime-fib-short | after | 0.018194 | 0.000461 |
| runtime-loop-short | before | 0.023523 | 0.000250 |
| runtime-loop-short | after | 0.024051 | 0.001060 |
| runtime-list-short | before | 0.029099 | 0.000377 |
| runtime-list-short | after | 0.029889 | 0.000492 |
| runtime-tree-short | before | 0.018257 | 0.000430 |
| runtime-tree-short | after | 0.018658 | 0.000344 |
| runtime-eval-short | before | 0.022194 | 0.000147 |
| runtime-eval-short | after | 0.022191 | 0.000988 |
| runtime-string-short | before | 0.016765 | 0.000221 |
| runtime-string-short | after | 0.016885 | 0.000175 |
| runtime-println-short | before | 0.016984 | 0.000242 |
| runtime-println-short | after | 0.017132 | 0.000153 |
| runtime-lines-short | before | 0.016714 | 0.000371 |
| runtime-lines-short | after | 0.016698 | 0.000761 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.5458e-05 | 1.001e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.083e-06 | 3.32e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 1.8624e-05 | 1.334e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.4167e-05 | 4.58e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 2.792e-06 | 1.26e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.7083e-05 | 5.83e-07 |
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
    "after": "2b7dabea796965deefcf05315118a95c9f1f4b33"
  },
  "features": {
    "before": {
      "shrink_steps": true,
      "builders": true,
      "timing_probe": true
    },
    "after": {
      "shrink_steps": true,
      "builders": true,
      "timing_probe": true
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
| functions-main-1000-0 | 判定不能 | None | 0.0030809167000001025 |
| functions-main-1000-1 | 達成 | 0.0008350409999877684 | 0.003066337500000316 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.004774525000000552 |
| functions-args-1000-1 | 判定不能 | None | 0.00482714580000021 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 達成 | 0.0009212089999834916 | 0.0024271250000012404 |
| functions-modules-1000-1 | 達成 | 0.0010075839999927894 | 0.0024211125000007886 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 達成 | 0.0013374590000125863 | 0.0026008790999995316 |
| higher-1-300 | 達成 | 0.0013715409999974781 | 0.002921495900000082 |
| classes-300 | 判定不能 | None | 0.003777295800000502 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 判定不能 | None | 0.002 |
| f1-nofail-call | 判定不能 | None | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.003965600000000791 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.0038104500000002875 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.0038883249999997816 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.003809854200000018 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.003924320799998782 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.003840533400000368 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.003970562499999631 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.003820420899999988 |
| order-string-candidates | 判定不能 | None | 0.0037741542000006238 |
| order-string-all-ok | 判定不能 | None | 0.0038593790999996713 |
| order-string-always-error | 判定不能 | None | 0.0037899040999988644 |
| order-map-candidates | 判定不能 | None | 0.0038221250000006536 |
| order-map-all-ok | 判定不能 | None | 0.0038526874999988085 |
| order-map-always-error | 判定不能 | None | 0.0038458250000005024 |
| order-record-candidates | 判定不能 | None | 0.0038823750000005933 |
| order-record-all-ok | 判定不能 | None | 0.003859016699999529 |
| order-record-always-error | 判定不能 | None | 0.003920804099999487 |
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
| runtime-loop-short | 判定不能 | None | 0.0023522999999997297 |
| runtime-list-short | 判定不能 | None | 0.0029099208000005206 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.0022193874999999253 |
| runtime-string-short | 判定不能 | None | 0.002 |
| runtime-println-short | 判定不能 | None | 0.002 |
| runtime-lines-short | 判定不能 | None | 0.002 |
| patterns-integer-100 | 判定不能 | None | 0.002 |
| codegen-let-100 | 達成 | 0.0003935419999976375 | 0.002 |
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
    "verify": 1.8314984169999917,
    "cli": 5.327147169,
    "warmup": 0.6646894970000119,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 0.9072502920000005,
    "cli": 3.623905417000003,
    "warmup": 0.42923729100003527,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3574087499999905,
    "cli": 9.374078458,
    "warmup": 1.3311856669999997,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.37680816600000355,
    "cli": 3.5375004179999934,
    "warmup": 0.3590010849999885,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.09991883300000381,
    "cli": 0.2791736670000091,
    "warmup": 0.029240707999989013,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.03605141699999592,
    "cli": 0.3291702920000006,
    "warmup": 0.03448887500000808,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.009178083999998421,
    "cli": 0.19921870799998942,
    "warmup": 0.008881083999995099,
    "probe_warmup": 0.007775917000003574,
    "rss": 0,
    "stages": 0.0382316269999734,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04102262499999654,
    "cli": 0.3404657499999928,
    "warmup": 0.035787208000002124,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.17861662599997885
  },
  "runtime": {
    "verify": 0.34059304200000895,
    "cli": 2.9061448340000027,
    "warmup": 0.3280690000000135,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
