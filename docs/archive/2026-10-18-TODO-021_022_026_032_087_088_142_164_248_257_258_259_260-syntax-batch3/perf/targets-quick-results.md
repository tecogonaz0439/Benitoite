# 版どうしの性能比較

候補: `50f3d4b94ed257c7494263d1aa35ca0c9f3ea389`。quick=True。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | old | 0.011154 | 0.000104 |
| functions-main-0-0 | map | 0.009644 | 0.000074 |
| functions-main-0-0 | solve | 0.010424 | 0.000309 |
| functions-main-0-0 | final | 0.009874 | 0.000219 |
| functions-main-0-1 | old | 0.011106 | 0.000018 |
| functions-main-0-1 | map | 0.009973 | 0.000369 |
| functions-main-0-1 | solve | 0.010562 | 0.000245 |
| functions-main-0-1 | final | 0.009970 | 0.000104 |
| functions-main-10-0 | old | 0.011100 | 0.000382 |
| functions-main-10-0 | map | 0.009863 | 0.000185 |
| functions-main-10-0 | solve | 0.010491 | 0.000523 |
| functions-main-10-0 | final | 0.010199 | 0.000172 |
| functions-main-10-1 | old | 0.013063 | 0.002011 |
| functions-main-10-1 | map | 0.009768 | 0.000322 |
| functions-main-10-1 | solve | 0.010223 | 0.000111 |
| functions-main-10-1 | final | 0.009925 | 0.000063 |
| functions-main-100-0 | old | 0.013074 | 0.000412 |
| functions-main-100-0 | map | 0.009859 | 0.000188 |
| functions-main-100-0 | solve | 0.010276 | 0.000173 |
| functions-main-100-0 | final | 0.010193 | 0.000115 |
| functions-main-100-1 | old | 0.012271 | 0.000080 |
| functions-main-100-1 | map | 0.010023 | 0.000127 |
| functions-main-100-1 | solve | 0.010835 | 0.000418 |
| functions-main-100-1 | final | 0.010322 | 0.000044 |
| functions-args-0-0 | old | 0.010960 | 0.000017 |
| functions-args-0-0 | map | 0.009469 | 0.000099 |
| functions-args-0-0 | solve | 0.009747 | 0.000062 |
| functions-args-0-0 | final | 0.010604 | 0.000213 |
| functions-args-0-1 | old | 0.011189 | 0.000095 |
| functions-args-0-1 | map | 0.009529 | 0.000012 |
| functions-args-0-1 | solve | 0.009720 | 0.000057 |
| functions-args-0-1 | final | 0.010402 | 0.000334 |
| functions-args-10-0 | old | 0.011562 | 0.000047 |
| functions-args-10-0 | map | 0.010049 | 0.000235 |
| functions-args-10-0 | solve | 0.009895 | 0.000007 |
| functions-args-10-0 | final | 0.009978 | 0.000174 |
| functions-args-10-1 | old | 0.011092 | 0.000012 |
| functions-args-10-1 | map | 0.009579 | 0.000005 |
| functions-args-10-1 | solve | 0.010399 | 0.000516 |
| functions-args-10-1 | final | 0.010075 | 0.000209 |
| functions-args-100-0 | old | 0.013558 | 0.000140 |
| functions-args-100-0 | map | 0.011046 | 0.000023 |
| functions-args-100-0 | solve | 0.011757 | 0.000043 |
| functions-args-100-0 | final | 0.011913 | 0.000115 |
| functions-args-100-1 | old | 0.014450 | 0.000034 |
| functions-args-100-1 | map | 0.011352 | 0.000160 |
| functions-args-100-1 | solve | 0.011743 | 0.000340 |
| functions-args-100-1 | final | 0.012534 | 0.000033 |
| functions-modules-0-0 | old | 0.011513 | 0.000069 |
| functions-modules-0-0 | map | 0.010129 | 0.000215 |
| functions-modules-0-0 | solve | 0.010737 | 0.000429 |
| functions-modules-0-0 | final | 0.010815 | 0.000062 |
| functions-modules-0-1 | old | 0.012488 | 0.000181 |
| functions-modules-0-1 | map | 0.010269 | 0.000100 |
| functions-modules-0-1 | solve | 0.011132 | 0.000181 |
| functions-modules-0-1 | final | 0.011566 | 0.000069 |
| functions-modules-10-0 | old | 0.011855 | 0.000237 |
| functions-modules-10-0 | map | 0.010559 | 0.000213 |
| functions-modules-10-0 | solve | 0.010595 | 0.000165 |
| functions-modules-10-0 | final | 0.010930 | 0.000066 |
| functions-modules-10-1 | old | 0.014065 | 0.002165 |
| functions-modules-10-1 | map | 0.010785 | 0.000405 |
| functions-modules-10-1 | solve | 0.012136 | 0.000047 |
| functions-modules-10-1 | final | 0.012801 | 0.000780 |
| functions-modules-100-0 | old | 0.013351 | 0.000074 |
| functions-modules-100-0 | map | 0.010747 | 0.000186 |
| functions-modules-100-0 | solve | 0.011014 | 0.000007 |
| functions-modules-100-0 | final | 0.011097 | 0.000063 |
| functions-modules-100-1 | old | 0.012854 | 0.000167 |
| functions-modules-100-1 | map | 0.010027 | 0.000186 |
| functions-modules-100-1 | solve | 0.011194 | 0.000358 |
| functions-modules-100-1 | final | 0.011951 | 0.000337 |
| existing-fib | old | 0.011986 | 0.000077 |
| existing-fib | map | 0.010350 | 0.000020 |
| existing-fib | solve | 0.010678 | 0.000037 |
| existing-fib | final | 0.010623 | 0.000202 |
| existing-loop | old | 0.012602 | 0.000154 |
| existing-loop | map | 0.010671 | 0.000107 |
| existing-loop | solve | 0.010910 | 0.000036 |
| existing-loop | final | 0.010683 | 0.000055 |
| existing-string | old | 0.012263 | 0.000210 |
| existing-string | map | 0.010603 | 0.000212 |
| existing-string | solve | 0.011044 | 0.000328 |
| existing-string | final | 0.010927 | 0.000386 |
| higher-0-0 | old | 0.011565 | 0.000442 |
| higher-0-0 | map | 0.009933 | 0.000137 |
| higher-0-0 | solve | 0.010308 | 0.000229 |
| higher-0-0 | final | 0.009954 | 0.000121 |
| higher-1-0 | old | 0.013103 | 0.000333 |
| higher-1-0 | map | 0.010746 | 0.000353 |
| higher-1-0 | solve | 0.010964 | 0.000107 |
| higher-1-0 | final | 0.010788 | 0.000098 |
| classes-0 | old | 0.018667 | 0.000084 |
| classes-0 | map | 0.014969 | 0.000004 |
| classes-0 | solve | 0.015525 | 0.000023 |
| classes-0 | final | 0.016303 | 0.000160 |
| higher-0-32 | old | 0.012960 | 0.000150 |
| higher-0-32 | map | 0.010872 | 0.000116 |
| higher-0-32 | solve | 0.011450 | 0.000075 |
| higher-0-32 | final | 0.010952 | 0.000015 |
| higher-1-32 | old | 0.014857 | 0.000332 |
| higher-1-32 | map | 0.011364 | 0.000012 |
| higher-1-32 | solve | 0.012322 | 0.000171 |
| higher-1-32 | final | 0.012536 | 0.000413 |
| classes-32 | old | 0.022246 | 0.001330 |
| classes-32 | map | 0.016234 | 0.000289 |
| classes-32 | solve | 0.016710 | 0.000277 |
| classes-32 | final | 0.017790 | 0.000183 |
| depth-0-2 | old | 0.013457 | 0.000052 |
| depth-0-2 | map | 0.010523 | 0.000039 |
| depth-0-2 | solve | 0.011154 | 0.000150 |
| depth-0-2 | final | 0.010810 | 0.000073 |
| depth-1-2 | old | 0.013281 | 0.000097 |
| depth-1-2 | map | 0.010902 | 0.000016 |
| depth-1-2 | solve | 0.011797 | 0.000207 |
| depth-1-2 | final | 0.011511 | 0.000266 |
| f1-nofail-call | old | 0.013116 | 0.000161 |
| f1-nofail-call | map | 0.010207 | 0.000133 |
| f1-nofail-call | solve | 0.011318 | 0.000434 |
| f1-nofail-call | final | 0.011110 | 0.000183 |
| f1-join-effects | old | 0.012944 | 0.000082 |
| f1-join-effects | map | 0.010990 | 0.000152 |
| f1-join-effects | solve | 0.011035 | 0.000317 |
| f1-join-effects | final | 0.011157 | 0.000212 |
| control-16.3 | old | 0.011083 | 0.000103 |
| control-16.3 | map | 0.010060 | 0.000531 |
| control-16.3 | solve | 0.010057 | 0.000386 |
| control-16.3 | final | 0.009782 | 0.000015 |
| property-seven-24-0-0-all-ok | old | 0.036019 | 0.000146 |
| property-seven-24-0-0-all-ok | map | 0.029051 | 0.000643 |
| property-seven-24-0-0-all-ok | solve | 0.030639 | 0.000281 |
| property-seven-24-0-0-all-ok | final | 0.034564 | 0.000179 |
| property-seven-24-0-0-always-error | old | 0.034933 | 0.000366 |
| property-seven-24-0-0-always-error | map | 0.028897 | 0.000263 |
| property-seven-24-0-0-always-error | solve | 0.030036 | 0.000612 |
| property-seven-24-0-0-always-error | final | 0.034160 | 0.000183 |
| property-seven-24-1-1-all-ok | old | 0.037326 | 0.000191 |
| property-seven-24-1-1-all-ok | map | 0.030440 | 0.000111 |
| property-seven-24-1-1-all-ok | solve | 0.031811 | 0.000422 |
| property-seven-24-1-1-all-ok | final | 0.034463 | 0.000163 |
| property-seven-24-1-1-always-error | old | 0.037174 | 0.000366 |
| property-seven-24-1-1-always-error | map | 0.030922 | 0.000179 |
| property-seven-24-1-1-always-error | solve | 0.031359 | 0.000052 |
| property-seven-24-1-1-always-error | final | 0.034200 | 0.000099 |
| property-seven-24-20-1000-all-ok | old | 0.037410 | 0.000107 |
| property-seven-24-20-1000-all-ok | map | 0.031532 | 0.001015 |
| property-seven-24-20-1000-all-ok | solve | 0.031909 | 0.000047 |
| property-seven-24-20-1000-all-ok | final | 0.035909 | 0.000054 |
| property-seven-24-20-1000-always-error | old | 0.039938 | 0.003353 |
| property-seven-24-20-1000-always-error | map | 0.033702 | 0.003662 |
| property-seven-24-20-1000-always-error | solve | 0.037658 | 0.000169 |
| property-seven-24-20-1000-always-error | final | 0.040751 | 0.001633 |
| candidates-seven-24 | old | 0.039470 | 0.000635 |
| candidates-seven-24 | map | 0.031089 | 0.000684 |
| candidates-seven-24 | solve | 0.032654 | 0.000067 |
| candidates-seven-24 | final | 0.036029 | 0.000034 |
| property-distinct-24-0-0-all-ok | old | 0.039349 | 0.000426 |
| property-distinct-24-0-0-all-ok | map | 0.030605 | 0.001812 |
| property-distinct-24-0-0-all-ok | solve | 0.034587 | 0.004343 |
| property-distinct-24-0-0-all-ok | final | 0.038561 | 0.000393 |
| property-distinct-24-0-0-always-error | old | 0.035326 | 0.000095 |
| property-distinct-24-0-0-always-error | map | 0.029245 | 0.000445 |
| property-distinct-24-0-0-always-error | solve | 0.030098 | 0.000009 |
| property-distinct-24-0-0-always-error | final | 0.034187 | 0.000496 |
| property-distinct-24-1-1-all-ok | old | 0.038526 | 0.000405 |
| property-distinct-24-1-1-all-ok | map | 0.032422 | 0.000092 |
| property-distinct-24-1-1-all-ok | solve | 0.032969 | 0.000486 |
| property-distinct-24-1-1-all-ok | final | 0.034453 | 0.000548 |
| property-distinct-24-1-1-always-error | old | 0.038492 | 0.000056 |
| property-distinct-24-1-1-always-error | map | 0.032221 | 0.000002 |
| property-distinct-24-1-1-always-error | solve | 0.033010 | 0.000578 |
| property-distinct-24-1-1-always-error | final | 0.033930 | 0.000109 |
| property-distinct-24-20-1000-all-ok | old | 0.039081 | 0.000246 |
| property-distinct-24-20-1000-all-ok | map | 0.032762 | 0.000428 |
| property-distinct-24-20-1000-all-ok | solve | 0.033801 | 0.000031 |
| property-distinct-24-20-1000-all-ok | final | 0.035096 | 0.000062 |
| property-distinct-24-20-1000-always-error | old | 0.038372 | 0.000168 |
| property-distinct-24-20-1000-always-error | map | 0.031886 | 0.000061 |
| property-distinct-24-20-1000-always-error | solve | 0.033227 | 0.000324 |
| property-distinct-24-20-1000-always-error | final | 0.034789 | 0.000460 |
| candidates-distinct-24 | old | 0.041808 | 0.003068 |
| candidates-distinct-24 | map | 0.033448 | 0.001620 |
| candidates-distinct-24 | solve | 0.035417 | 0.002070 |
| candidates-distinct-24 | final | 0.035400 | 0.001800 |
| property-zero-24-0-0-all-ok | old | 0.037639 | 0.000021 |
| property-zero-24-0-0-all-ok | map | 0.029703 | 0.000033 |
| property-zero-24-0-0-all-ok | solve | 0.031595 | 0.000023 |
| property-zero-24-0-0-all-ok | final | 0.035336 | 0.000140 |
| property-zero-24-0-0-always-error | old | 0.039438 | 0.002698 |
| property-zero-24-0-0-always-error | map | 0.032870 | 0.002354 |
| property-zero-24-0-0-always-error | solve | 0.032671 | 0.001143 |
| property-zero-24-0-0-always-error | final | 0.038271 | 0.000591 |
| property-zero-24-1-1-all-ok | old | 0.035960 | 0.000178 |
| property-zero-24-1-1-all-ok | map | 0.029232 | 0.000185 |
| property-zero-24-1-1-all-ok | solve | 0.030623 | 0.000514 |
| property-zero-24-1-1-all-ok | final | 0.034725 | 0.000133 |
| property-zero-24-1-1-always-error | old | 0.036014 | 0.000070 |
| property-zero-24-1-1-always-error | map | 0.029118 | 0.000328 |
| property-zero-24-1-1-always-error | solve | 0.030217 | 0.000145 |
| property-zero-24-1-1-always-error | final | 0.033886 | 0.000491 |
| property-zero-24-20-1000-all-ok | old | 0.036990 | 0.000100 |
| property-zero-24-20-1000-all-ok | map | 0.029491 | 0.000201 |
| property-zero-24-20-1000-all-ok | solve | 0.030410 | 0.000036 |
| property-zero-24-20-1000-all-ok | final | 0.035111 | 0.000207 |
| property-zero-24-20-1000-always-error | old | 0.035912 | 0.000084 |
| property-zero-24-20-1000-always-error | map | 0.029504 | 0.000629 |
| property-zero-24-20-1000-always-error | solve | 0.030479 | 0.000059 |
| property-zero-24-20-1000-always-error | final | 0.034276 | 0.000247 |
| candidates-zero-24 | old | 0.036312 | 0.000677 |
| candidates-zero-24 | map | 0.029026 | 0.000077 |
| candidates-zero-24 | solve | 0.030297 | 0.000253 |
| candidates-zero-24 | final | 0.034305 | 0.000433 |
| property-max-24-0-0-all-ok | old | 0.035600 | 0.000117 |
| property-max-24-0-0-all-ok | map | 0.029261 | 0.000077 |
| property-max-24-0-0-all-ok | solve | 0.030118 | 0.000134 |
| property-max-24-0-0-all-ok | final | 0.034631 | 0.000150 |
| property-max-24-0-0-always-error | old | 0.036051 | 0.000997 |
| property-max-24-0-0-always-error | map | 0.029081 | 0.000184 |
| property-max-24-0-0-always-error | solve | 0.030457 | 0.000136 |
| property-max-24-0-0-always-error | final | 0.034533 | 0.000121 |
| property-max-24-1-1-all-ok | old | 0.493762 | 0.025056 |
| property-max-24-1-1-all-ok | map | 0.481017 | 0.011855 |
| property-max-24-1-1-all-ok | solve | 0.474022 | 0.004646 |
| property-max-24-1-1-all-ok | final | 0.035829 | 0.000112 |
| property-max-24-1-1-always-error | old | 0.464575 | 0.004469 |
| property-max-24-1-1-always-error | map | 0.474949 | 0.001453 |
| property-max-24-1-1-always-error | solve | 0.467085 | 0.003251 |
| property-max-24-1-1-always-error | final | 0.036560 | 0.000511 |
| property-max-24-20-1000-all-ok | old | 0.479767 | 0.004771 |
| property-max-24-20-1000-all-ok | map | 0.472734 | 0.003050 |
| property-max-24-20-1000-all-ok | solve | 0.457196 | 0.001353 |
| property-max-24-20-1000-all-ok | final | 0.038202 | 0.000340 |
| property-max-24-20-1000-always-error | old | 0.458337 | 0.000318 |
| property-max-24-20-1000-always-error | map | 0.462797 | 0.001405 |
| property-max-24-20-1000-always-error | solve | 0.454017 | 0.000419 |
| property-max-24-20-1000-always-error | final | 0.034469 | 0.000512 |
| candidates-max-24 | old | 0.482974 | 0.012843 |
| candidates-max-24 | map | 0.492204 | 0.003492 |
| candidates-max-24 | solve | 0.498689 | 0.000016 |
| candidates-max-24 | final | 0.039965 | 0.000191 |
| order-string-candidates | old | 0.037390 | 0.000602 |
| order-string-candidates | map | 0.034850 | 0.002802 |
| order-string-candidates | solve | 0.033186 | 0.001160 |
| order-string-candidates | final | 0.034844 | 0.000285 |
| order-string-all-ok | old | 0.040986 | 0.004598 |
| order-string-all-ok | map | 0.031416 | 0.002252 |
| order-string-all-ok | solve | 0.032313 | 0.001085 |
| order-string-all-ok | final | 0.041491 | 0.000234 |
| order-string-always-error | old | 0.038133 | 0.000429 |
| order-string-always-error | map | 0.031005 | 0.000682 |
| order-string-always-error | solve | 0.036353 | 0.001989 |
| order-string-always-error | final | 0.036259 | 0.001346 |
| order-map-candidates | old | 0.043431 | 0.001226 |
| order-map-candidates | map | 0.032258 | 0.000945 |
| order-map-candidates | solve | 0.033054 | 0.001740 |
| order-map-candidates | final | 0.040364 | 0.002753 |
| order-map-all-ok | old | 0.040350 | 0.001661 |
| order-map-all-ok | map | 0.031862 | 0.001396 |
| order-map-all-ok | solve | 0.034173 | 0.001909 |
| order-map-all-ok | final | 0.037606 | 0.001187 |
| order-map-always-error | old | 0.037555 | 0.000239 |
| order-map-always-error | map | 0.030962 | 0.001554 |
| order-map-always-error | solve | 0.032853 | 0.000800 |
| order-map-always-error | final | 0.039889 | 0.002385 |
| order-record-candidates | old | 0.035559 | 0.000232 |
| order-record-candidates | map | 0.028989 | 0.000066 |
| order-record-candidates | solve | 0.030662 | 0.000091 |
| order-record-candidates | final | 0.035179 | 0.000128 |
| order-record-all-ok | old | 0.036141 | 0.000500 |
| order-record-all-ok | map | 0.029435 | 0.000322 |
| order-record-all-ok | solve | 0.030613 | 0.000316 |
| order-record-all-ok | final | 0.034826 | 0.000314 |
| order-record-always-error | old | 0.039529 | 0.002895 |
| order-record-always-error | map | 0.030346 | 0.001236 |
| order-record-always-error | solve | 0.032961 | 0.000170 |
| order-record-always-error | final | 0.040029 | 0.002592 |
| control-16.4 | old | 0.013792 | 0.000152 |
| control-16.4 | map | 0.012224 | 0.000162 |
| control-16.4 | solve | 0.012272 | 0.000053 |
| control-16.4 | final | 0.012142 | 0.000077 |
| build-string-builder-0-0 | final | 0.012901 | 0.000135 |
| build-string-builder-all-0-0 | final | 0.012904 | 0.000342 |
| build-string-concatenate-0-0 | final | 0.012979 | 0.000256 |
| build-string-join-0-0 | final | 0.012453 | 0.000107 |
| build-string-builder-4-0 | final | 0.012960 | 0.000205 |
| build-string-builder-all-4-0 | final | 0.013117 | 0.000312 |
| build-string-concatenate-4-0 | final | 0.013940 | 0.000381 |
| build-string-join-4-0 | final | 0.013906 | 0.000277 |
| build-list-builder-0-0 | final | 0.013498 | 0.000699 |
| build-list-builder-all-0-0 | final | 0.012896 | 0.000174 |
| build-list-concatenate-0-0 | final | 0.013502 | 0.000235 |
| build-list-fold-0-0 | final | 0.013182 | 0.000206 |
| build-list-builder-4-0 | final | 0.012976 | 0.000226 |
| build-list-builder-all-4-0 | final | 0.013425 | 0.000100 |
| build-list-concatenate-4-0 | final | 0.012984 | 0.000108 |
| build-list-fold-4-0 | final | 0.012965 | 0.000287 |
| build-bytes-builder-0-0 | final | 0.012854 | 0.000022 |
| build-bytes-builder-all-0-0 | final | 0.012781 | 0.000302 |
| build-bytes-concatenate-0-0 | final | 0.012735 | 0.000134 |
| build-bytes-builder-4-0 | final | 0.012529 | 0.000121 |
| build-bytes-builder-all-4-0 | final | 0.012736 | 0.000004 |
| build-bytes-concatenate-4-0 | final | 0.013359 | 0.000311 |
| control-16.5 | final | 0.012550 | 0.000216 |

## 比較状態と機能

```json
{
  "commits": {
    "old": "6b0568a3ddcc46b0a0e64504139ce286a27fd86a",
    "map": "f0e6c71d29cbc8704093dcf5c355469ad50c4381",
    "solve": "c4310604f3982f7daab323920615945c2ba3ffef",
    "final": "50f3d4b94ed257c7494263d1aa35ca0c9f3ea389"
  },
  "features": {
    "old": {
      "shrink_steps": false,
      "builders": false
    },
    "map": {
      "shrink_steps": false,
      "builders": false
    },
    "solve": {
      "shrink_steps": false,
      "builders": false
    },
    "final": {
      "shrink_steps": true,
      "builders": true
    }
  },
  "skipped": [
    {
      "case": "build-string-builder-0-0",
      "state": "old",
      "reason": "missing features: builders"
    },
    {
      "case": "build-string-builder-0-0",
      "state": "map",
      "reason": "missing features: builders"
    },
    {
      "case": "build-string-builder-0-0",
      "state": "solve",
      "reason": "missing features: builders"
    },
    {
      "case": "build-string-builder-all-0-0",
      "state": "old",
      "reason": "missing features: builders"
    },
    {
      "case": "build-string-builder-all-0-0",
      "state": "map",
      "reason": "missing features: builders"
    },
    {
      "case": "build-string-builder-all-0-0",
      "state": "solve",
      "reason": "missing features: builders"
    },
    {
      "case": "build-string-concatenate-0-0",
      "state": "old",
      "reason": "missing features: builders"
    },
    {
      "case": "build-string-concatenate-0-0",
      "state": "map",
      "reason": "missing features: builders"
    },
    {
      "case": "build-string-concatenate-0-0",
      "state": "solve",
      "reason": "missing features: builders"
    },
    {
      "case": "build-string-join-0-0",
      "state": "old",
      "reason": "missing features: builders"
    },
    {
      "case": "build-string-join-0-0",
      "state": "map",
      "reason": "missing features: builders"
    },
    {
      "case": "build-string-join-0-0",
      "state": "solve",
      "reason": "missing features: builders"
    },
    {
      "case": "build-string-builder-4-0",
      "state": "old",
      "reason": "missing features: builders"
    },
    {
      "case": "build-string-builder-4-0",
      "state": "map",
      "reason": "missing features: builders"
    },
    {
      "case": "build-string-builder-4-0",
      "state": "solve",
      "reason": "missing features: builders"
    },
    {
      "case": "build-string-builder-all-4-0",
      "state": "old",
      "reason": "missing features: builders"
    },
    {
      "case": "build-string-builder-all-4-0",
      "state": "map",
      "reason": "missing features: builders"
    },
    {
      "case": "build-string-builder-all-4-0",
      "state": "solve",
      "reason": "missing features: builders"
    },
    {
      "case": "build-string-concatenate-4-0",
      "state": "old",
      "reason": "missing features: builders"
    },
    {
      "case": "build-string-concatenate-4-0",
      "state": "map",
      "reason": "missing features: builders"
    },
    {
      "case": "build-string-concatenate-4-0",
      "state": "solve",
      "reason": "missing features: builders"
    },
    {
      "case": "build-string-join-4-0",
      "state": "old",
      "reason": "missing features: builders"
    },
    {
      "case": "build-string-join-4-0",
      "state": "map",
      "reason": "missing features: builders"
    },
    {
      "case": "build-string-join-4-0",
      "state": "solve",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-builder-0-0",
      "state": "old",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-builder-0-0",
      "state": "map",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-builder-0-0",
      "state": "solve",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-builder-all-0-0",
      "state": "old",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-builder-all-0-0",
      "state": "map",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-builder-all-0-0",
      "state": "solve",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-concatenate-0-0",
      "state": "old",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-concatenate-0-0",
      "state": "map",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-concatenate-0-0",
      "state": "solve",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-fold-0-0",
      "state": "old",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-fold-0-0",
      "state": "map",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-fold-0-0",
      "state": "solve",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-builder-4-0",
      "state": "old",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-builder-4-0",
      "state": "map",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-builder-4-0",
      "state": "solve",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-builder-all-4-0",
      "state": "old",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-builder-all-4-0",
      "state": "map",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-builder-all-4-0",
      "state": "solve",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-concatenate-4-0",
      "state": "old",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-concatenate-4-0",
      "state": "map",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-concatenate-4-0",
      "state": "solve",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-fold-4-0",
      "state": "old",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-fold-4-0",
      "state": "map",
      "reason": "missing features: builders"
    },
    {
      "case": "build-list-fold-4-0",
      "state": "solve",
      "reason": "missing features: builders"
    },
    {
      "case": "build-bytes-builder-0-0",
      "state": "old",
      "reason": "missing features: builders"
    },
    {
      "case": "build-bytes-builder-0-0",
      "state": "map",
      "reason": "missing features: builders"
    },
    {
      "case": "build-bytes-builder-0-0",
      "state": "solve",
      "reason": "missing features: builders"
    },
    {
      "case": "build-bytes-builder-all-0-0",
      "state": "old",
      "reason": "missing features: builders"
    },
    {
      "case": "build-bytes-builder-all-0-0",
      "state": "map",
      "reason": "missing features: builders"
    },
    {
      "case": "build-bytes-builder-all-0-0",
      "state": "solve",
      "reason": "missing features: builders"
    },
    {
      "case": "build-bytes-concatenate-0-0",
      "state": "old",
      "reason": "missing features: builders"
    },
    {
      "case": "build-bytes-concatenate-0-0",
      "state": "map",
      "reason": "missing features: builders"
    },
    {
      "case": "build-bytes-concatenate-0-0",
      "state": "solve",
      "reason": "missing features: builders"
    },
    {
      "case": "build-bytes-builder-4-0",
      "state": "old",
      "reason": "missing features: builders"
    },
    {
      "case": "build-bytes-builder-4-0",
      "state": "map",
      "reason": "missing features: builders"
    },
    {
      "case": "build-bytes-builder-4-0",
      "state": "solve",
      "reason": "missing features: builders"
    },
    {
      "case": "build-bytes-builder-all-4-0",
      "state": "old",
      "reason": "missing features: builders"
    },
    {
      "case": "build-bytes-builder-all-4-0",
      "state": "map",
      "reason": "missing features: builders"
    },
    {
      "case": "build-bytes-builder-all-4-0",
      "state": "solve",
      "reason": "missing features: builders"
    },
    {
      "case": "build-bytes-concatenate-4-0",
      "state": "old",
      "reason": "missing features: builders"
    },
    {
      "case": "build-bytes-concatenate-4-0",
      "state": "map",
      "reason": "missing features: builders"
    },
    {
      "case": "build-bytes-concatenate-4-0",
      "state": "solve",
      "reason": "missing features: builders"
    },
    {
      "case": "control-16.5",
      "state": "old",
      "reason": "missing features: builders"
    },
    {
      "case": "control-16.5",
      "state": "map",
      "reason": "missing features: builders"
    },
    {
      "case": "control-16.5",
      "state": "solve",
      "reason": "missing features: builders"
    }
  ],
  "unavailable_probes": {}
}
```

## 目標

| 目標 | 判定 | 値 | 上限 |
|---|---|---:|---:|
| R17 map/old I(10000) | 判定不能 | None | 0.25 |
| R17 map I(10000)/I(5000) | 判定不能 | None | 2.5 |
| R17 map I(20000)/I(10000) | 判定不能 | None | 2.5 |
| R17 final/old I(10000) | 判定不能 | None | 0.25 |
| R17 final I(10000)/I(5000) | 判定不能 | None | 2.5 |
| R17 final I(20000)/I(10000) | 判定不能 | None | 2.5 |
| small control-16.3 solve-map | 判定不能 | None | None |
| small control-16.3 final-old | 判定不能 | None | None |
| small control-16.3 final-map | 判定不能 | None | None |
| small control-16.3 final-solve | 判定不能 | None | None |
| small functions-main-0-0 map-old | 判定不能 | None | None |
| small functions-main-0-0 solve-old | 判定不能 | None | None |
| small functions-main-0-0 final-old | 判定不能 | None | None |
| small functions-main-10-0 map-old | 判定不能 | None | None |
| small functions-main-10-0 solve-old | 判定不能 | None | None |
| small functions-main-10-0 final-old | 判定不能 | None | None |
| small functions-main-100-0 map-old | 判定不能 | None | None |
| small functions-main-100-0 solve-old | 判定不能 | None | None |
| small functions-main-100-0 final-old | 判定不能 | None | None |
| small functions-main-1000-0 map-old | 判定不能 | None | None |
| small functions-main-1000-0 solve-old | 判定不能 | None | None |
| small functions-main-1000-0 final-old | 判定不能 | None | None |
| small functions-args-0-0 map-old | 判定不能 | None | None |
| small functions-args-0-0 solve-old | 判定不能 | None | None |
| small functions-args-0-0 final-old | 判定不能 | None | None |
| small functions-args-10-0 map-old | 判定不能 | None | None |
| small functions-args-10-0 solve-old | 判定不能 | None | None |
| small functions-args-10-0 final-old | 判定不能 | None | None |
| small functions-args-100-0 map-old | 判定不能 | None | None |
| small functions-args-100-0 solve-old | 判定不能 | None | None |
| small functions-args-100-0 final-old | 判定不能 | None | None |
| small functions-args-1000-0 map-old | 判定不能 | None | None |
| small functions-args-1000-0 solve-old | 判定不能 | None | None |
| small functions-args-1000-0 final-old | 判定不能 | None | None |
| small functions-modules-0-0 map-old | 判定不能 | None | None |
| small functions-modules-0-0 solve-old | 判定不能 | None | None |
| small functions-modules-0-0 final-old | 判定不能 | None | None |
| small functions-modules-10-0 map-old | 判定不能 | None | None |
| small functions-modules-10-0 solve-old | 判定不能 | None | None |
| small functions-modules-10-0 final-old | 判定不能 | None | None |
| small functions-modules-100-0 map-old | 判定不能 | None | None |
| small functions-modules-100-0 solve-old | 判定不能 | None | None |
| small functions-modules-100-0 final-old | 判定不能 | None | None |
| small functions-modules-1000-0 map-old | 判定不能 | None | None |
| small functions-modules-1000-0 solve-old | 判定不能 | None | None |
| small functions-modules-1000-0 final-old | 判定不能 | None | None |
| small higher-0-0 solve-map | 判定不能 | None | None |
| small higher-0-0 final-old | 判定不能 | None | None |
| small higher-0-0 final-map | 判定不能 | None | None |
| small higher-0-0 final-solve | 判定不能 | None | None |
| small higher-1-0 solve-map | 判定不能 | None | None |
| small higher-1-0 final-old | 判定不能 | None | None |
| small higher-1-0 final-map | 判定不能 | None | None |
| small higher-1-0 final-solve | 判定不能 | None | None |
| small classes-0 solve-map | 判定不能 | None | None |
| small classes-0 final-old | 判定不能 | None | None |
| small classes-0 final-map | 判定不能 | None | None |
| small classes-0 final-solve | 判定不能 | None | None |
| small higher-0-100 solve-map | 判定不能 | None | None |
| small higher-0-100 final-old | 判定不能 | None | None |
| small higher-0-100 final-map | 判定不能 | None | None |
| small higher-0-100 final-solve | 判定不能 | None | None |
| small higher-1-100 solve-map | 判定不能 | None | None |
| small higher-1-100 final-old | 判定不能 | None | None |
| small higher-1-100 final-map | 判定不能 | None | None |
| small higher-1-100 final-solve | 判定不能 | None | None |
| small classes-100 solve-map | 判定不能 | None | None |
| small classes-100 final-old | 判定不能 | None | None |
| small classes-100 final-map | 判定不能 | None | None |
| small classes-100 final-solve | 判定不能 | None | None |
| small higher-0-300 solve-map | 判定不能 | None | None |
| small higher-0-300 final-old | 判定不能 | None | None |
| small higher-0-300 final-map | 判定不能 | None | None |
| small higher-0-300 final-solve | 判定不能 | None | None |
| small higher-1-300 solve-map | 判定不能 | None | None |
| small higher-1-300 final-old | 判定不能 | None | None |
| small higher-1-300 final-map | 判定不能 | None | None |
| small higher-1-300 final-solve | 判定不能 | None | None |
| small classes-300 solve-map | 判定不能 | None | None |
| small classes-300 final-old | 判定不能 | None | None |
| small classes-300 final-map | 判定不能 | None | None |
| small classes-300 final-solve | 判定不能 | None | None |
| small depth-0-8 solve-map | 判定不能 | None | None |
| small depth-0-8 final-old | 判定不能 | None | None |
| small depth-0-8 final-map | 判定不能 | None | None |
| small depth-0-8 final-solve | 判定不能 | None | None |
| small depth-1-8 solve-map | 判定不能 | None | None |
| small depth-1-8 final-old | 判定不能 | None | None |
| small depth-1-8 final-map | 判定不能 | None | None |
| small depth-1-8 final-solve | 判定不能 | None | None |
| small depth-0-16 solve-map | 判定不能 | None | None |
| small depth-0-16 final-old | 判定不能 | None | None |
| small depth-0-16 final-map | 判定不能 | None | None |
| small depth-0-16 final-solve | 判定不能 | None | None |
| small depth-1-16 solve-map | 判定不能 | None | None |
| small depth-1-16 final-old | 判定不能 | None | None |
| small depth-1-16 final-map | 判定不能 | None | None |
| small depth-1-16 final-solve | 判定不能 | None | None |
| small depth-0-32 solve-map | 判定不能 | None | None |
| small depth-0-32 final-old | 判定不能 | None | None |
| small depth-0-32 final-map | 判定不能 | None | None |
| small depth-0-32 final-solve | 判定不能 | None | None |
| small depth-1-32 solve-map | 判定不能 | None | None |
| small depth-1-32 final-old | 判定不能 | None | None |
| small depth-1-32 final-map | 判定不能 | None | None |
| small depth-1-32 final-solve | 判定不能 | None | None |
| small depth-0-64 solve-map | 判定不能 | None | None |
| small depth-0-64 final-old | 判定不能 | None | None |
| small depth-0-64 final-map | 判定不能 | None | None |
| small depth-0-64 final-solve | 判定不能 | None | None |
| small depth-1-64 solve-map | 判定不能 | None | None |
| small depth-1-64 final-old | 判定不能 | None | None |
| small depth-1-64 final-map | 判定不能 | None | None |
| small depth-1-64 final-solve | 判定不能 | None | None |
| R17 existing-fib map-old | 判定不能 | None | None |
| R17 existing-fib solve-old | 判定不能 | None | None |
| R17 existing-fib final-old | 判定不能 | None | None |
| R17 existing-loop map-old | 判定不能 | None | None |
| R17 existing-loop solve-old | 判定不能 | None | None |
| R17 existing-loop final-old | 判定不能 | None | None |
| R17 existing-string map-old | 判定不能 | None | None |
| R17 existing-string solve-old | 判定不能 | None | None |
| R17 existing-string final-old | 判定不能 | None | None |
| R19 higher-0 typeck(900) solve/map | 判定不能 | None | 0.75 |
| R19 higher-0 typeck(1800) solve/map | 判定不能 | None | 0.75 |
| R19 higher-0 I(900)/I(450) | 判定不能 | None | 2.5 |
| R19 higher-0 I(1800)/I(900) | 判定不能 | None | 2.5 |
| R19 higher-1 typeck(900) solve/map | 判定不能 | None | 0.75 |
| R19 higher-1 typeck(1800) solve/map | 判定不能 | None | 0.75 |
| R19 higher-1 I(900)/I(450) | 判定不能 | None | 2.5 |
| R19 higher-1 I(1800)/I(900) | 判定不能 | None | 2.5 |
| R19 classes typeck(900) solve/map | 判定不能 | None | 0.75 |
| R19 classes typeck(1800) solve/map | 判定不能 | None | 0.75 |
| R22 seven/all-ok final/old n=88 | 判定不能 | None | 0.5 |
| R22 seven/all-ok final 256/88 | 判定不能 | None | 4 |
| R22 seven/always-error final/old n=88 | 判定不能 | None | 0.5 |
| R22 seven/always-error final 256/88 | 判定不能 | None | 4 |
| R22 distinct/all-ok final/old n=88 | 判定不能 | None | 0.5 |
| R22 distinct/all-ok final 256/88 | 判定不能 | None | 4 |
| R22 distinct/always-error final/old n=88 | 判定不能 | None | 0.5 |
| R22 distinct/always-error final 256/88 | 判定不能 | None | 4 |
| R22 zero/all-ok final/old n=88 | 判定不能 | None | 0.5 |
| R22 zero/all-ok final 256/88 | 判定不能 | None | 4 |
| R22 zero/always-error final/old n=88 | 判定不能 | None | 0.5 |
| R22 zero/always-error final 256/88 | 判定不能 | None | 4 |
| R22 max/all-ok final/old n=88 | 判定不能 | None | 0.5 |
| R22 max/all-ok final 256/88 | 判定不能 | None | 4 |
| R22 max/always-error final/old n=88 | 判定不能 | None | 0.5 |
| R22 max/always-error final 256/88 | 判定不能 | None | 4 |
| R22 shrinks budget | 達成 | — | — |
| R22 shrinkWork budget | 達成 | — | — |
| R19 small higher-0-0 solve-map | 判定不能 | None | None |
| R19 small higher-0-0 final-map | 判定不能 | None | None |
| R19 small higher-0-100 solve-map | 判定不能 | None | None |
| R19 small higher-0-100 final-map | 判定不能 | None | None |
| R19 small higher-0-300 solve-map | 判定不能 | None | None |
| R19 small higher-0-300 final-map | 判定不能 | None | None |
| R19 small higher-1-0 solve-map | 判定不能 | None | None |
| R19 small higher-1-0 final-map | 判定不能 | None | None |
| R19 small higher-1-100 solve-map | 判定不能 | None | None |
| R19 small higher-1-100 final-map | 判定不能 | None | None |
| R19 small higher-1-300 solve-map | 判定不能 | None | None |
| R19 small higher-1-300 final-map | 判定不能 | None | None |
| R19 small classes-0 solve-map | 判定不能 | None | None |
| R19 small classes-0 final-map | 判定不能 | None | None |
| R19 small classes-100 solve-map | 判定不能 | None | None |
| R19 small classes-100 final-map | 判定不能 | None | None |
| R19 small classes-300 solve-map | 判定不能 | None | None |
| R19 small classes-300 final-map | 判定不能 | None | None |

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
    "verify": 0.9315235420000001,
    "cli": 3.652714459999995,
    "warmup": 0.9332433340000179,
    "probe_warmup": 1.3689051720000016,
    "rss": 2.4528261739999877,
    "stages": 2.007575337000004,
    "alloc": 0
  },
  "16.3": {
    "verify": 0.5694985419999998,
    "cli": 2.0346059160000074,
    "warmup": 0.5531750789999919,
    "probe_warmup": 0.6022824550000081,
    "rss": 1.3658152910000076,
    "stages": 1.1997644189999725,
    "alloc": 0
  },
  "16.4": {
    "verify": 11.371064582999999,
    "cli": 27.600092080999985,
    "warmup": 11.700934246999925,
    "probe_warmup": 0,
    "rss": 14.718551497999954,
    "stages": 0,
    "alloc": 0
  },
  "16.5": {
    "verify": 0.289045290999999,
    "cli": 1.1974178349999534,
    "warmup": 0.30805483199993944,
    "probe_warmup": 0,
    "rss": 0.7292751270000366,
    "stages": 0,
    "alloc": 0
  }
}
```
