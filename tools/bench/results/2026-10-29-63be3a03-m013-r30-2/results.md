# 版どうしの性能比較

候補: `63be3a0394436c593e2a63be2488a70fb33f14b3`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013937 | 0.000429 |
| functions-main-0-0 | after | 0.014933 | 0.001057 |
| functions-main-0-1 | before | 0.013489 | 0.000271 |
| functions-main-0-1 | after | 0.013624 | 0.000324 |
| functions-main-64-0 | before | 0.014088 | 0.000374 |
| functions-main-64-0 | after | 0.014339 | 0.000107 |
| functions-main-256-0 | before | 0.015271 | 0.000933 |
| functions-main-256-0 | after | 0.015803 | 0.000120 |
| functions-main-1000-0 | before | 0.020765 | 0.000584 |
| functions-main-1000-0 | after | 0.022096 | 0.001196 |
| functions-main-1000-1 | before | 0.020725 | 0.000091 |
| functions-main-1000-1 | after | 0.021930 | 0.001572 |
| functions-args-0-0 | before | 0.013808 | 0.000666 |
| functions-args-0-0 | after | 0.014178 | 0.000219 |
| functions-args-0-1 | before | 0.013359 | 0.000976 |
| functions-args-0-1 | after | 0.013891 | 0.000240 |
| functions-args-1000-0 | before | 0.027069 | 0.000166 |
| functions-args-1000-0 | after | 0.028717 | 0.001564 |
| functions-args-1000-1 | before | 0.027045 | 0.000740 |
| functions-args-1000-1 | after | 0.028430 | 0.000231 |
| functions-modules-0-0 | before | 0.013565 | 0.000729 |
| functions-modules-0-0 | after | 0.013890 | 0.000155 |
| functions-modules-0-1 | before | 0.013623 | 0.001741 |
| functions-modules-0-1 | after | 0.013629 | 0.000375 |
| functions-modules-1000-0 | before | 0.021074 | 0.000330 |
| functions-modules-1000-0 | after | 0.022016 | 0.000361 |
| functions-modules-1000-1 | before | 0.021352 | 0.000718 |
| functions-modules-1000-1 | after | 0.022661 | 0.000318 |
| existing-fib | before | 0.014180 | 0.000503 |
| existing-fib | after | 0.014624 | 0.000439 |
| existing-loop | before | 0.014438 | 0.000497 |
| existing-loop | after | 0.014910 | 0.000995 |
| existing-string | before | 0.014080 | 0.000145 |
| existing-string | after | 0.014441 | 0.000240 |
| higher-0-0 | before | 0.013510 | 0.000239 |
| higher-0-0 | after | 0.013740 | 0.000295 |
| higher-1-0 | before | 0.014253 | 0.000763 |
| higher-1-0 | after | 0.015280 | 0.000694 |
| classes-0 | before | 0.018060 | 0.001451 |
| classes-0 | after | 0.018408 | 0.000264 |
| higher-0-300 | before | 0.028382 | 0.000272 |
| higher-0-300 | after | 0.029277 | 0.000911 |
| higher-1-300 | before | 0.031142 | 0.000561 |
| higher-1-300 | after | 0.032218 | 0.001204 |
| classes-300 | before | 0.037582 | 0.001181 |
| classes-300 | after | 0.038705 | 0.000798 |
| depth-0-8 | before | 0.014927 | 0.000420 |
| depth-0-8 | after | 0.015094 | 0.000317 |
| depth-1-8 | before | 0.014847 | 0.000262 |
| depth-1-8 | after | 0.015682 | 0.000228 |
| f1-nofail-call | before | 0.014064 | 0.000514 |
| f1-nofail-call | after | 0.014500 | 0.000241 |
| f1-join-effects | before | 0.014014 | 0.000449 |
| f1-join-effects | after | 0.014457 | 0.000142 |
| control-16.3 | before | 0.013064 | 0.000207 |
| control-16.3 | after | 0.013369 | 0.000404 |
| interval-bind-64 | before | 0.013442 | 0.000382 |
| interval-bind-64 | after | 0.013730 | 0.000186 |
| interval-bind-256 | before | 0.014022 | 0.001551 |
| interval-bind-256 | after | 0.014649 | 0.000326 |
| interval-add-64 | before | 0.013320 | 0.001705 |
| interval-add-64 | after | 0.013565 | 0.000148 |
| interval-add-256 | before | 0.015004 | 0.000372 |
| interval-add-256 | after | 0.015321 | 0.000271 |
| interval-flow-64 | before | 0.013950 | 0.000361 |
| interval-flow-64 | after | 0.014543 | 0.000594 |
| interval-flow-256 | before | 0.016927 | 0.000400 |
| interval-flow-256 | after | 0.017526 | 0.000166 |
| interval-range-0 | before | 0.018357 | 0.000341 |
| interval-range-0 | after | 0.019164 | 0.000942 |
| interval-range-64 | before | 0.022678 | 0.000154 |
| interval-range-64 | after | 0.023994 | 0.000714 |
| interval-range-256 | before | 0.035383 | 0.000804 |
| interval-range-256 | after | 0.036981 | 0.000341 |
| interval-http-0 | before | 0.019253 | 0.000665 |
| interval-http-0 | after | 0.021535 | 0.000549 |
| interval-http-64 | before | 0.022044 | 0.000225 |
| interval-http-64 | after | 0.024720 | 0.000536 |
| interval-http-256 | before | 0.029796 | 0.000867 |
| interval-http-256 | after | 0.032548 | 0.000630 |
| interval-width-Integer8-64 | before | 0.014171 | 0.000183 |
| interval-width-Integer8-64 | after | 0.014796 | 0.000360 |
| interval-width-Integer8-256 | before | 0.016935 | 0.000833 |
| interval-width-Integer8-256 | after | 0.017403 | 0.000232 |
| interval-width-Integer16-64 | before | 0.014073 | 0.000164 |
| interval-width-Integer16-64 | after | 0.014311 | 0.000407 |
| interval-width-Integer16-256 | before | 0.017375 | 0.000729 |
| interval-width-Integer16-256 | after | 0.018049 | 0.000447 |
| interval-width-Integer32-64 | before | 0.014053 | 0.000260 |
| interval-width-Integer32-64 | after | 0.014575 | 0.000678 |
| interval-width-Integer32-256 | before | 0.016951 | 0.000147 |
| interval-width-Integer32-256 | after | 0.017613 | 0.000736 |
| interval-width-Integer64-64 | before | 0.014183 | 0.000727 |
| interval-width-Integer64-64 | after | 0.014712 | 0.000606 |
| interval-width-Integer64-256 | before | 0.016790 | 0.000431 |
| interval-width-Integer64-256 | after | 0.017514 | 0.000093 |
| interval-width-UnsignedInteger16-64 | before | 0.013893 | 0.000567 |
| interval-width-UnsignedInteger16-64 | after | 0.014368 | 0.000117 |
| interval-width-UnsignedInteger16-256 | before | 0.016493 | 0.000235 |
| interval-width-UnsignedInteger16-256 | after | 0.017297 | 0.000791 |
| interval-width-UnsignedInteger32-64 | before | 0.013794 | 0.000259 |
| interval-width-UnsignedInteger32-64 | after | 0.014249 | 0.000472 |
| interval-width-UnsignedInteger32-256 | before | 0.016578 | 0.000143 |
| interval-width-UnsignedInteger32-256 | after | 0.017106 | 0.000617 |
| interval-width-UnsignedInteger64-64 | before | 0.013985 | 0.000665 |
| interval-width-UnsignedInteger64-64 | after | 0.014390 | 0.000233 |
| interval-width-UnsignedInteger64-256 | before | 0.016394 | 0.000301 |
| interval-width-UnsignedInteger64-256 | after | 0.017119 | 0.000608 |
| property-seven-24-20-1000-all-ok | before | 0.036681 | 0.000351 |
| property-seven-24-20-1000-all-ok | after | 0.038793 | 0.000412 |
| property-seven-24-20-1000-always-error | before | 0.035199 | 0.000793 |
| property-seven-24-20-1000-always-error | after | 0.037215 | 0.000298 |
| property-distinct-24-20-1000-all-ok | before | 0.037165 | 0.000772 |
| property-distinct-24-20-1000-all-ok | after | 0.038255 | 0.000670 |
| property-distinct-24-20-1000-always-error | before | 0.035306 | 0.001505 |
| property-distinct-24-20-1000-always-error | after | 0.037115 | 0.000541 |
| property-zero-24-20-1000-all-ok | before | 0.036642 | 0.000483 |
| property-zero-24-20-1000-all-ok | after | 0.038187 | 0.000215 |
| property-zero-24-20-1000-always-error | before | 0.035750 | 0.000511 |
| property-zero-24-20-1000-always-error | after | 0.037061 | 0.000136 |
| property-max-24-20-1000-all-ok | before | 0.037332 | 0.000544 |
| property-max-24-20-1000-all-ok | after | 0.038411 | 0.000290 |
| property-max-24-20-1000-always-error | before | 0.035931 | 0.001111 |
| property-max-24-20-1000-always-error | after | 0.037252 | 0.000670 |
| order-string-candidates | before | 0.035050 | 0.000722 |
| order-string-candidates | after | 0.036608 | 0.000162 |
| order-string-all-ok | before | 0.035673 | 0.000156 |
| order-string-all-ok | after | 0.037317 | 0.000444 |
| order-string-always-error | before | 0.035141 | 0.000365 |
| order-string-always-error | after | 0.036711 | 0.000440 |
| order-map-candidates | before | 0.035338 | 0.000965 |
| order-map-candidates | after | 0.036908 | 0.001264 |
| order-map-all-ok | before | 0.035812 | 0.000138 |
| order-map-all-ok | after | 0.037357 | 0.000658 |
| order-map-always-error | before | 0.035778 | 0.000278 |
| order-map-always-error | after | 0.037183 | 0.000538 |
| order-record-candidates | before | 0.036300 | 0.001475 |
| order-record-candidates | after | 0.037855 | 0.000505 |
| order-record-all-ok | before | 0.036092 | 0.000567 |
| order-record-all-ok | after | 0.037616 | 0.000569 |
| order-record-always-error | before | 0.036270 | 0.001177 |
| order-record-always-error | after | 0.037325 | 0.000300 |
| build-string-builder-8-0 | before | 0.015865 | 0.000326 |
| build-string-builder-8-0 | after | 0.016463 | 0.000462 |
| build-string-builder-all-8-0 | before | 0.016121 | 0.000302 |
| build-string-builder-all-8-0 | after | 0.016557 | 0.000155 |
| build-string-concatenate-8-0 | before | 0.015941 | 0.000336 |
| build-string-concatenate-8-0 | after | 0.016397 | 0.000446 |
| build-string-join-8-0 | before | 0.015653 | 0.000942 |
| build-string-join-8-0 | after | 0.016019 | 0.000221 |
| build-list-builder-8-0 | before | 0.016059 | 0.000684 |
| build-list-builder-8-0 | after | 0.017111 | 0.000213 |
| build-list-builder-all-8-0 | before | 0.016143 | 0.000364 |
| build-list-builder-all-8-0 | after | 0.016492 | 0.000198 |
| build-list-concatenate-8-0 | before | 0.016223 | 0.000255 |
| build-list-concatenate-8-0 | after | 0.016661 | 0.000720 |
| build-list-fold-8-0 | before | 0.016145 | 0.001122 |
| build-list-fold-8-0 | after | 0.016625 | 0.000224 |
| build-bytes-builder-8-0 | before | 0.016130 | 0.000482 |
| build-bytes-builder-8-0 | after | 0.016691 | 0.000225 |
| build-bytes-builder-all-8-0 | before | 0.016536 | 0.000321 |
| build-bytes-builder-all-8-0 | after | 0.016981 | 0.000218 |
| build-bytes-concatenate-8-0 | before | 0.016359 | 0.000311 |
| build-bytes-concatenate-8-0 | after | 0.017142 | 0.000522 |
| patterns-integer-100 | before | 0.014768 | 0.000550 |
| patterns-integer-100 | after | 0.014915 | 0.001175 |
| codegen-let-100 | before | 0.017010 | 0.000351 |
| codegen-let-100 | after | 0.018583 | 0.001691 |
| bridge-shared-8 | before | 0.004531 | 0.000207 |
| bridge-shared-8 | after | 0.004392 | 0.000362 |
| external-tests-normal-1 | before | 0.017949 | 0.000169 |
| external-tests-normal-1 | after | 0.018477 | 0.000985 |
| runtime-fib-short | before | 0.018459 | 0.000835 |
| runtime-fib-short | after | 0.019030 | 0.000563 |
| runtime-loop-short | before | 0.023972 | 0.000524 |
| runtime-loop-short | after | 0.024310 | 0.000223 |
| runtime-list-short | before | 0.029246 | 0.000337 |
| runtime-list-short | after | 0.029938 | 0.000604 |
| runtime-tree-short | before | 0.018353 | 0.000230 |
| runtime-tree-short | after | 0.019020 | 0.000221 |
| runtime-eval-short | before | 0.022370 | 0.000772 |
| runtime-eval-short | after | 0.022575 | 0.000322 |
| runtime-string-short | before | 0.016925 | 0.000482 |
| runtime-string-short | after | 0.017618 | 0.000032 |
| runtime-println-short | before | 0.017350 | 0.000578 |
| runtime-println-short | after | 0.017979 | 0.001073 |
| runtime-lines-short | before | 0.017543 | 0.000815 |
| runtime-lines-short | after | 0.026765 | 0.000362 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.8333e-05 | 2.209e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.375e-06 | 4.17e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 2.1708e-05 | 2.626e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.5542e-05 | 1.125e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.042e-06 | 6.66e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.85e-05 | 1.749e-06 |
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
    "before": "6124775788579e60530f55fb85570f26ef7fa900",
    "after": "63be3a0394436c593e2a63be2488a70fb33f14b3"
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
| functions-main-64-0 | 判定不能 | None | 0.002 |
| functions-main-256-0 | 判定不能 | None | 0.002 |
| functions-main-1000-0 | 判定不能 | None | 0.0020765374999996314 |
| functions-main-1000-1 | 判定不能 | None | 0.00207246670000103 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.002706929100000366 |
| functions-args-1000-1 | 達成 | 0.001384916000006342 | 0.0027044791999998098 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 達成 | 0.000941625000010049 | 0.0021074499999997444 |
| functions-modules-1000-1 | 達成 | 0.0013095410000119045 | 0.0021351749999993785 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.0028382417000003103 |
| higher-1-300 | 判定不能 | None | 0.0031142333000005354 |
| classes-300 | 判定不能 | None | 0.0037581540999994446 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 達成 | 0.0008348340000026155 | 0.002 |
| f1-nofail-call | 判定不能 | None | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 判定不能 | None | 0.002 |
| interval-bind-64 | 判定不能 | None | 0.002 |
| interval-bind-256 | 判定不能 | None | 0.002 |
| interval-add-64 | 判定不能 | None | 0.002 |
| interval-add-256 | 判定不能 | None | 0.002 |
| interval-flow-64 | 判定不能 | None | 0.002 |
| interval-flow-256 | 達成 | 0.0005994579999963889 | 0.002 |
| interval-range-0 | 判定不能 | None | 0.002 |
| interval-range-64 | 達成 | 0.0013153749999901265 | 0.0022678417000008724 |
| interval-range-256 | 達成 | 0.0015982910000076345 | 0.003538274999999658 |
| interval-http-0 | 退行の疑い | 0.0022816670000054273 | 0.002 |
| interval-http-64 | 退行の疑い | 0.0026760000000081163 | 0.002204424999999333 |
| interval-http-256 | 達成 | 0.002751541999984397 | 0.0029796083000007915 |
| interval-width-Integer8-64 | 達成 | 0.0006247080000036931 | 0.002 |
| interval-width-Integer8-256 | 判定不能 | None | 0.002 |
| interval-width-Integer16-64 | 判定不能 | None | 0.002 |
| interval-width-Integer16-256 | 判定不能 | None | 0.002 |
| interval-width-Integer32-64 | 判定不能 | None | 0.002 |
| interval-width-Integer32-256 | 判定不能 | None | 0.002 |
| interval-width-Integer64-64 | 判定不能 | None | 0.002 |
| interval-width-Integer64-256 | 達成 | 0.0007237499999916963 | 0.002 |
| interval-width-UnsignedInteger16-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger16-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger32-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger32-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger64-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger64-256 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 達成 | 0.00211270799999852 | 0.003668075000000215 |
| property-seven-24-20-1000-always-error | 達成 | 0.002016625000010208 | 0.0035198583999999757 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.0037165375000000724 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.003530562499999235 |
| property-zero-24-20-1000-all-ok | 達成 | 0.0015446670000045515 | 0.003664200000000051 |
| property-zero-24-20-1000-always-error | 達成 | 0.0013115819999995892 | 0.0035749834000000646 |
| property-max-24-20-1000-all-ok | 達成 | 0.0010789159999973208 | 0.0037332208999998786 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.0035930707999995096 |
| order-string-candidates | 達成 | 0.0015574170000007825 | 0.003505024999999762 |
| order-string-all-ok | 達成 | 0.001644583000000921 | 0.003567266700000005 |
| order-string-always-error | 達成 | 0.0015694160000094826 | 0.003514133399998798 |
| order-map-candidates | 判定不能 | None | 0.003533845799999824 |
| order-map-all-ok | 達成 | 0.0015455420000023423 | 0.0035811624999993797 |
| order-map-always-error | 達成 | 0.0014052909999975327 | 0.003577795900000069 |
| order-record-candidates | 判定不能 | None | 0.003629983300000106 |
| order-record-all-ok | 達成 | 0.0015238330000073574 | 0.0036092124999996147 |
| order-record-always-error | 判定不能 | None | 0.0036270125000001487 |
| build-string-builder-8-0 | 判定不能 | None | 0.002 |
| build-string-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-string-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-string-join-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-8-0 | 達成 | 0.001051625000002332 | 0.002 |
| build-list-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-list-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-list-fold-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-bytes-concatenate-8-0 | 判定不能 | None | 0.002 |
| runtime-fib-short | 判定不能 | None | 0.002 |
| runtime-loop-short | 判定不能 | None | 0.00239722920000105 |
| runtime-list-short | 判定不能 | None | 0.002924554199999818 |
| runtime-tree-short | 達成 | 0.0006677499999909742 | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.002236974999999575 |
| runtime-string-short | 達成 | 0.0006929169999949636 | 0.002 |
| runtime-println-short | 判定不能 | None | 0.002 |
| runtime-lines-short | 退行の疑い | 0.009222873999988224 | 0.002 |
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
    "verify": 1.7210317920000051,
    "cli": 5.384777751999977,
    "warmup": 0.6041872059999776,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 3.1076111670000017,
    "cli": 11.874959750000087,
    "warmup": 1.3768792469999909,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.355603875,
    "cli": 9.048921168000021,
    "warmup": 1.2540401650000064,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.38228674999999157,
    "cli": 3.5888801660000524,
    "warmup": 0.36269808299996953,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.10430300000000159,
    "cli": 0.28606912499999737,
    "warmup": 0.030467041999983735,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.0370479590000059,
    "cli": 0.341260291999987,
    "warmup": 0.03702737500000808,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.010135249999990492,
    "cli": 0.19833262499999194,
    "warmup": 0.009206792000000519,
    "probe_warmup": 0.007619499999989898,
    "rss": 0,
    "stages": 0.04197037200000864,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.0426952500000084,
    "cli": 0.3449217080000011,
    "warmup": 0.03607395900000654,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.1810343330000137
  },
  "runtime": {
    "verify": 0.3576615829999952,
    "cli": 3.0271721670000176,
    "warmup": 0.34488675200002206,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```

## 取りまとめの確かめ（2026-10-29）

`interval-http` の二点は既知（TODO-304）。新しい退行の疑い `runtime-lines-short`（+52.6%）は確かな退行である。開始版・R30.1 の取り込み（`a4a6af2b`）・この版の CLI を交互に30回ずつ走らせた中央値は、`run` が 16.14・16.58・25.60 ms、`check` が 13.13・13.37・19.81 ms だった。`File` を import するだけのプログラムの `check`（25回）は、R30.1 の版の 12.57 ms からこの版の 19.21 ms へ伸び、`Scope` を import するだけのプログラム（18.71・18.97 ms）とほぼ同じになった。原因は、R30.2 で `IO/File.bnt` が `File.*In` の署名のために `import Benitoite.Unofficial.Scope` を加えたことである。計時の探査の段別時間（15回）では、`Scope` の費用のほとんどは `Scope.bnt` が `ScopeError` の `Show` の実装のために import する `Benitoite.Trait`（585行）であり、`Trait` を import するだけで型検査が 5.51→9.15 ms、読み込みと解析が 1.76→2.32 ms になる。扱いは設計者に尋ねる。全94入力の after/before の中央値の比は 1.036。
