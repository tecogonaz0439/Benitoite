# 版どうしの性能比較

候補: `fe4af8d1f5ba1b2ed9cb6650b601f80393959c68`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013035 | 0.000128 |
| functions-main-0-0 | after | 0.013292 | 0.000833 |
| functions-main-0-1 | before | 0.013123 | 0.000389 |
| functions-main-0-1 | after | 0.013604 | 0.000218 |
| functions-main-1000-0 | before | 0.030639 | 0.000284 |
| functions-main-1000-0 | after | 0.031031 | 0.000240 |
| functions-main-1000-1 | before | 0.030732 | 0.000231 |
| functions-main-1000-1 | after | 0.031070 | 0.000351 |
| functions-args-0-0 | before | 0.013053 | 0.000118 |
| functions-args-0-0 | after | 0.013022 | 0.000245 |
| functions-args-0-1 | before | 0.013179 | 0.000200 |
| functions-args-0-1 | after | 0.013168 | 0.000129 |
| functions-args-1000-0 | before | 0.047424 | 0.000414 |
| functions-args-1000-0 | after | 0.047555 | 0.000531 |
| functions-args-1000-1 | before | 0.047416 | 0.000554 |
| functions-args-1000-1 | after | 0.047361 | 0.000368 |
| functions-modules-0-0 | before | 0.013490 | 0.000723 |
| functions-modules-0-0 | after | 0.013152 | 0.000077 |
| functions-modules-0-1 | before | 0.013283 | 0.000773 |
| functions-modules-0-1 | after | 0.013152 | 0.000236 |
| functions-modules-1000-0 | before | 0.024292 | 0.000305 |
| functions-modules-1000-0 | after | 0.024740 | 0.001175 |
| functions-modules-1000-1 | before | 0.024383 | 0.000241 |
| functions-modules-1000-1 | after | 0.025010 | 0.000509 |
| existing-fib | before | 0.013593 | 0.000884 |
| existing-fib | after | 0.013710 | 0.000150 |
| existing-loop | before | 0.013660 | 0.000760 |
| existing-loop | after | 0.013784 | 0.000199 |
| existing-string | before | 0.013652 | 0.000563 |
| existing-string | after | 0.013622 | 0.000209 |
| higher-0-0 | before | 0.013052 | 0.001064 |
| higher-0-0 | after | 0.013157 | 0.000100 |
| higher-1-0 | before | 0.014173 | 0.000791 |
| higher-1-0 | after | 0.013995 | 0.000185 |
| classes-0 | before | 0.019079 | 0.000321 |
| classes-0 | after | 0.019159 | 0.000605 |
| higher-0-300 | before | 0.026425 | 0.000302 |
| higher-0-300 | after | 0.026937 | 0.000679 |
| higher-1-300 | before | 0.029095 | 0.000346 |
| higher-1-300 | after | 0.029518 | 0.000517 |
| classes-300 | before | 0.037807 | 0.000774 |
| classes-300 | after | 0.037876 | 0.000669 |
| depth-0-8 | before | 0.014584 | 0.000572 |
| depth-0-8 | after | 0.014582 | 0.000107 |
| depth-1-8 | before | 0.014816 | 0.000779 |
| depth-1-8 | after | 0.014860 | 0.000162 |
| f1-nofail-call | before | 0.014192 | 0.001193 |
| f1-nofail-call | after | 0.014147 | 0.000141 |
| f1-join-effects | before | 0.014017 | 0.000668 |
| f1-join-effects | after | 0.014148 | 0.000260 |
| control-16.3 | before | 0.013053 | 0.000456 |
| control-16.3 | after | 0.013003 | 0.000086 |
| property-seven-24-20-1000-all-ok | before | 0.039728 | 0.001358 |
| property-seven-24-20-1000-all-ok | after | 0.040110 | 0.000230 |
| property-seven-24-20-1000-always-error | before | 0.038328 | 0.000949 |
| property-seven-24-20-1000-always-error | after | 0.038151 | 0.000361 |
| property-distinct-24-20-1000-all-ok | before | 0.038612 | 0.000632 |
| property-distinct-24-20-1000-all-ok | after | 0.039104 | 0.000110 |
| property-distinct-24-20-1000-always-error | before | 0.038585 | 0.000635 |
| property-distinct-24-20-1000-always-error | after | 0.038349 | 0.000261 |
| property-zero-24-20-1000-all-ok | before | 0.039195 | 0.000828 |
| property-zero-24-20-1000-all-ok | after | 0.039266 | 0.000497 |
| property-zero-24-20-1000-always-error | before | 0.038399 | 0.000966 |
| property-zero-24-20-1000-always-error | after | 0.038113 | 0.000469 |
| property-max-24-20-1000-all-ok | before | 0.039791 | 0.001780 |
| property-max-24-20-1000-all-ok | after | 0.040016 | 0.000363 |
| property-max-24-20-1000-always-error | before | 0.038202 | 0.000703 |
| property-max-24-20-1000-always-error | after | 0.038194 | 0.000321 |
| order-string-candidates | before | 0.038070 | 0.000803 |
| order-string-candidates | after | 0.038053 | 0.000499 |
| order-string-all-ok | before | 0.038634 | 0.001505 |
| order-string-all-ok | after | 0.038759 | 0.000319 |
| order-string-always-error | before | 0.037982 | 0.000794 |
| order-string-always-error | after | 0.037943 | 0.000252 |
| order-map-candidates | before | 0.038012 | 0.000807 |
| order-map-candidates | after | 0.038454 | 0.000192 |
| order-map-all-ok | before | 0.038634 | 0.001091 |
| order-map-all-ok | after | 0.038693 | 0.000092 |
| order-map-always-error | before | 0.038226 | 0.000952 |
| order-map-always-error | after | 0.038550 | 0.000336 |
| order-record-candidates | before | 0.038712 | 0.001011 |
| order-record-candidates | after | 0.038986 | 0.000456 |
| order-record-all-ok | before | 0.038660 | 0.000651 |
| order-record-all-ok | after | 0.039093 | 0.000292 |
| order-record-always-error | before | 0.038769 | 0.000519 |
| order-record-always-error | after | 0.039025 | 0.000159 |
| build-string-builder-8-0 | before | 0.015897 | 0.000745 |
| build-string-builder-8-0 | after | 0.016354 | 0.001072 |
| build-string-builder-all-8-0 | before | 0.015993 | 0.000216 |
| build-string-builder-all-8-0 | after | 0.015939 | 0.000165 |
| build-string-concatenate-8-0 | before | 0.015805 | 0.000539 |
| build-string-concatenate-8-0 | after | 0.015809 | 0.000228 |
| build-string-join-8-0 | before | 0.015814 | 0.000814 |
| build-string-join-8-0 | after | 0.015788 | 0.000156 |
| build-list-builder-8-0 | before | 0.016004 | 0.000516 |
| build-list-builder-8-0 | after | 0.016043 | 0.000223 |
| build-list-builder-all-8-0 | before | 0.015744 | 0.000253 |
| build-list-builder-all-8-0 | after | 0.015723 | 0.000150 |
| build-list-concatenate-8-0 | before | 0.015876 | 0.000503 |
| build-list-concatenate-8-0 | after | 0.016047 | 0.000173 |
| build-list-fold-8-0 | before | 0.015870 | 0.000337 |
| build-list-fold-8-0 | after | 0.015999 | 0.000233 |
| build-bytes-builder-8-0 | before | 0.015794 | 0.000330 |
| build-bytes-builder-8-0 | after | 0.016128 | 0.000260 |
| build-bytes-builder-all-8-0 | before | 0.016124 | 0.000263 |
| build-bytes-builder-all-8-0 | after | 0.016128 | 0.000548 |
| build-bytes-concatenate-8-0 | before | 0.016155 | 0.000342 |
| build-bytes-concatenate-8-0 | after | 0.016236 | 0.000188 |
| patterns-integer-100 | before | 0.014273 | 0.000769 |
| patterns-integer-100 | after | 0.014410 | 0.000167 |
| codegen-let-100 | before | 0.016700 | 0.000286 |
| codegen-let-100 | after | 0.016698 | 0.000207 |
| bridge-shared-8 | before | 0.004353 | 0.000167 |
| bridge-shared-8 | after | 0.004397 | 0.000344 |
| external-tests-normal-1 | before | 0.017850 | 0.000310 |
| external-tests-normal-1 | after | 0.017790 | 0.000151 |
| runtime-fib-short | before | 0.017922 | 0.000504 |
| runtime-fib-short | after | 0.018163 | 0.000612 |
| runtime-loop-short | before | 0.023391 | 0.000293 |
| runtime-loop-short | after | 0.023626 | 0.000664 |
| runtime-list-short | before | 0.029013 | 0.000158 |
| runtime-list-short | after | 0.029455 | 0.000706 |
| runtime-tree-short | before | 0.018140 | 0.000165 |
| runtime-tree-short | after | 0.018385 | 0.000809 |
| runtime-eval-short | before | 0.022098 | 0.000196 |
| runtime-eval-short | after | 0.021857 | 0.000451 |
| runtime-string-short | before | 0.016742 | 0.000306 |
| runtime-string-short | after | 0.016707 | 0.000178 |
| runtime-println-short | before | 0.017102 | 0.000209 |
| runtime-println-short | after | 0.017088 | 0.000131 |
| runtime-lines-short | before | 0.016530 | 0.000361 |
| runtime-lines-short | after | 0.016564 | 0.000150 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.5375e-05 | 9.17e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 2.875e-06 | 2.5e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 1.8459e-05 | 8.76e-07 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.3916e-05 | 1.417e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.459e-06 | 7.5e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.6666e-05 | 2.168e-06 |
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
    "after": "fe4af8d1f5ba1b2ed9cb6650b601f80393959c68"
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
| functions-main-1000-0 | 判定不能 | None | 0.003063908299999696 |
| functions-main-1000-1 | 判定不能 | None | 0.003073241699999585 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.004742412500000626 |
| functions-args-1000-1 | 判定不能 | None | 0.004741616600000498 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.002429179099999601 |
| functions-modules-1000-1 | 判定不能 | None | 0.0024383458000002637 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.0026425291999998993 |
| higher-1-300 | 判定不能 | None | 0.0029094541000006303 |
| classes-300 | 判定不能 | None | 0.003780733399999292 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 判定不能 | None | 0.002 |
| f1-nofail-call | 判定不能 | None | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.003972820899998908 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.0038327999999992813 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.0038611583000005114 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.003858499999999765 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.00391948339999999 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.0038398540999992296 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.003979112500000781 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.0038202000000012505 |
| order-string-candidates | 判定不能 | None | 0.0038070374999989555 |
| order-string-all-ok | 判定不能 | None | 0.0038633916000009095 |
| order-string-always-error | 判定不能 | None | 0.003798204199999589 |
| order-map-candidates | 判定不能 | None | 0.0038012209000001466 |
| order-map-all-ok | 判定不能 | None | 0.003863362499998857 |
| order-map-always-error | 判定不能 | None | 0.0038225582999999123 |
| order-record-candidates | 判定不能 | None | 0.0038712208000006854 |
| order-record-all-ok | 判定不能 | None | 0.0038659958000010876 |
| order-record-always-error | 判定不能 | None | 0.0038768833000006 |
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
| runtime-loop-short | 判定不能 | None | 0.00233913330000064 |
| runtime-list-short | 判定不能 | None | 0.0029012750000006805 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.0022097582999990096 |
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
    "verify": 1.8131637080000047,
    "cli": 5.286023164000014,
    "warmup": 0.6613492069999864,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 0.8989085410000115,
    "cli": 3.5944913349999865,
    "warmup": 0.427788167999978,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3527122499999962,
    "cli": 9.325250293000039,
    "warmup": 1.326369043000014,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.36035141700000395,
    "cli": 3.498362833000016,
    "warmup": 0.35339845800002934,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.09833125000000109,
    "cli": 0.275879333000006,
    "warmup": 0.02880733399999258,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.03649866699998938,
    "cli": 0.3257088330000073,
    "warmup": 0.03427079200000094,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.009077791999999363,
    "cli": 0.19832350000000076,
    "warmup": 0.008594125000001895,
    "probe_warmup": 0.007872833000007518,
    "rss": 0,
    "stages": 0.038075750000004405,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.03848787500000128,
    "cli": 0.3376464579999947,
    "warmup": 0.03523862599999461,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.17778162300000133
  },
  "runtime": {
    "verify": 0.3317138329999949,
    "cli": 2.8817092070000143,
    "warmup": 0.3249161229999942,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
