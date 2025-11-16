┌ 1020: sym._diff.compareSameLayouts (int64_t arg1, int64_t arg2, int64_t arg3, int64_t arg4, int64_t arg5, int64_t arg6, int64_t arg7, int64_t arg8, int64_t arg_110h);
│ `- args(x0, x1, x2, x3, x4, x5, x6, x7, sp[0x110..0x110]) vars(33:sp[0x8..0x110])
│           0x10010b410      ff4304d1       sub sp, sp, 0x110
│           0x10010b414      e9230a6d       stp d9, d8, [var_a0h]
│           0x10010b418      fc6f0ba9       stp x28, x27, [var_b0h]
│           0x10010b41c      fa670ca9       stp x26, x25, [var_c0h]
│           0x10010b420      f85f0da9       stp x24, x23, [var_d0h]
│           0x10010b424      f6570ea9       stp x22, x21, [var_e0h]
│           0x10010b428      f44f0fa9       stp x20, x19, [var_f0h]
│           0x10010b42c      fd7b10a9       stp x29, x30, [var_100h]
│           0x10010b430      fd030491       add x29, sp, 0x100
│           0x10010b434      f30307aa       mov x19, x7                ; arg8
│           0x10010b438      fc0306aa       mov x28, x6                ; arg7
│           0x10010b43c      f50304aa       mov x21, x4                ; arg5
│           0x10010b440      e20f03a9       stp x2, x3, [arg_110hx30]  ; arg4
│           0x10010b444      f90300aa       mov x25, x0                ; arg1
│           0x10010b448      a80b40f9       ldr x8, [x29, 0x10]        ; [0x178000:4]=0
│                                                                      ; sp
│           0x10010b44c      e12304a9       stp x1, x8, [arg_110hx40]  ; arg2
│           0x10010b450      08244429       ldp w8, w9, [x0, 0x20]     ; arg1
│           0x10010b454      177d091b       mul w23, w8, w9
│           0x10010b458      0a0040f9       ldr x10, [x0]              ; arg1
│           0x10010b45c      290040f9       ldr x9, [x1]               ; arg2
│           0x10010b460      e92b02a9       stp x9, x10, [arg_110hx20]
│           0x10010b464      eb761e72       ands w11, w23, 0xfffffffc
│           0x10010b468      e50b00f9       str x5, [arg_110hx10]      ; arg6
│       ┌─< 0x10010b46c      a0110054       b.eq 0x10010b6a0
│       │   0x10010b470      f70700f9       str x23, [var_8h]
│       │   0x10010b474      1b008052       mov w27, 0
│       │   0x10010b478      1a008052       mov w26, 0
│       │   0x10010b47c      180080d2       mov x24, 0
│       │   0x10010b480      bf0000f1       cmp x5, 0
│       │   0x10010b484      f7031caa       mov x23, x28
│       │   0x10010b488      841b40fa       ccmp x28, 0, 4, ne
│       │   0x10010b48c      f6079f1a       cset w22, ne
│       │   0x10010b490      690500d1       sub x9, x11, 1
│       │   0x10010b494      29f57e92       and x9, x9, 0xfffffffffffffffc
│       │   0x10010b498      e90300f9       str x9, [sp]
│       │   0x10010b49c      bc100091       add x28, x5, 4
│       │   0x10010b4a0      eb0f00f9       str x11, [arg_110hx18]
│      ┌──< 0x10010b4a4      05000014       b 0x10010b4b8
│      ││   ; CODE XREF from sym._diff.compareSameLayouts @ 0x10010b50c(x)
│     ┌───> 0x10010b4a8      eb0f40f9       ldr x11, [arg_110hx18]
│     ╎││   ; CODE XREFS from sym._diff.compareSameLayouts @ 0x10010b674(x), 0x10010b680(x)
│   ┌┌────> 0x10010b4ac      18130091       add x24, x24, 4
│   ╎╎╎││   0x10010b4b0      1f030beb       cmp x24, x11
│  ┌──────< 0x10010b4b4      820e0054       b.hs 0x10010b684
│  │╎╎╎││   ; CODE XREF from sym._diff.compareSameLayouts @ 0x10010b4a4(x)
│  │╎╎╎└──> 0x10010b4b8      09f77ed3       lsl x9, x24, 2
│  │╎╎╎ │   0x10010b4bc      ea1740f9       ldr x10, [arg_110hx28]
│  │╎╎╎ │   0x10010b4c0      4069e93c       ldr q0, [x10, x9]
│  │╎╎╎ │   0x10010b4c4      ea1340f9       ldr x10, [arg_110hx20]
│  │╎╎╎ │   0x10010b4c8      4169e93c       ldr q1, [x10, x9]
│  │╎╎╎ │   0x10010b4cc      e18302ad       stp q1, q0, [arg_110hx50]
│  │╎╎╎ │   0x10010b4d0      008ca16e       cmeq v0.4s, v0.4s, v1.4s
│  │╎╎╎ │   0x10010b4d4      0058206e       mvn v0.16b, v0.16b
│  │╎╎╎ │   0x10010b4d8      01a8b06e       umaxv s1, v0.4s
│  │╎╎╎ │   0x10010b4dc      2900261e       fmov w9, s1
│  │╎╎╎┌──< 0x10010b4e0      a90a0036       tbz w9, 0, 0x10010b634
│  │╎╎╎││   0x10010b4e4      140080d2       mov x20, 0
│  │╎╎╎││   0x10010b4e8      0828610e       xtn v8.4h, v0.4s
│ ┌───────< 0x10010b4ec      09000014       b 0x10010b510
│ ││╎╎╎││   ; XREFS: CODE 0x10010b520  CODE 0x10010b540  CODE 0x10010b57c  CODE 0x10010b5a4  CODE 0x10010b5bc  CODE 0x10010b5f0  
│ ││╎╎╎││   ; XREFS: CODE 0x10010b60c  CODE 0x10010b618  CODE 0x10010b630  
│ ────────> 0x10010b4f0      282340b9       ldr w8, [x25, 0x20]
│ ││╎╎╎││   0x10010b4f4      69070011       add w9, w27, 1
│ ││╎╎╎││   0x10010b4f8      3f01086b       cmp w9, w8
│ ││╎╎╎││   0x10010b4fc      5a379a1a       cinc w26, w26, hs
│ ││╎╎╎││   0x10010b500      fb279b1a       csinc w27, wzr, w27, hs
│ ││╎╎╎││   0x10010b504      94060091       add x20, x20, 1
│ ││╎╎╎││   0x10010b508      9f1200f1       cmp x20, 4
│ ││╎╎└───< 0x10010b50c      e0fcff54       b.eq 0x10010b4a8
│ ││╎╎ ││   ; CODE XREF from sym._diff.compareSameLayouts @ 0x10010b4ec(x)
│ └───────> 0x10010b510      a80319fc       stur d8, [x29, -0x70]
│  │╎╎ ││   0x10010b514      a8c301d1       sub x8, x29, 0x70
│  │╎╎ ││   0x10010b518      88067fb3       bfi x8, x20, 1, 2
│  │╎╎ ││   0x10010b51c      08014079       ldrh w8, [x8]
│ ────────< 0x10010b520      88fe0736       tbz w8, 0, 0x10010b4f0
│  │╎╎┌───< 0x10010b524      76010034       cbz w22, 0x10010b550
│  │╎╎│││   0x10010b528      8802182a       orr w8, w20, w24
│  │╎╎│││   0x10010b52c      e9031caa       mov x9, x28
│  │╎╎│││   0x10010b530      ea0317aa       mov x10, x23
│  │╎╎│││   ; CODE XREF from sym._diff.compareSameLayouts @ 0x10010b54c(x)
│ ┌───────> 0x10010b534      2bb17f29       ldp w11, w12, [x9, -4]
│ ╎│╎╎│││   0x10010b538      7f01086b       cmp w11, w8
│ ╎│╎╎│││   0x10010b53c      8091487a       ccmp w12, w8, 0, ls
│ ────────< 0x10010b540      82fdff54       b.hs 0x10010b4f0
│ ╎│╎╎│││   0x10010b544      29210091       add x9, x9, 8
│ ╎│╎╎│││   0x10010b548      4a0500f1       subs x10, x10, 1
│ └───────< 0x10010b54c      41ffff54       b.ne 0x10010b534
│  │╎╎│││   ; CODE XREF from sym._diff.compareSameLayouts @ 0x10010b524(x)
│  │╎╎└───> 0x10010b550      e18342ad       ldp q1, q0, [arg_110hx50]
│  │╎╎ ││   0x10010b554      e11f803d       str q1, [arg_110hx70]
│  │╎╎ ││   0x10010b558      e8c30191       add x8, sp, 0x70
│  │╎╎ ││   0x10010b55c      88067eb3       bfi x8, x20, 2, 2
│  │╎╎ ││   0x10010b560      010140b9       ldr w1, [x8]
│  │╎╎ ││   0x10010b564      e8030291       add x8, sp, 0x80
│  │╎╎ ││   0x10010b568      88067eb3       bfi x8, x20, 2, 2
│  │╎╎ ││   0x10010b56c      e023803d       str q0, [arg_110hx80]
│  │╎╎ ││   0x10010b570      000140b9       ldr w0, [x8]
│  │╎╎ ││   0x10010b574      47fdff97       bl sym._color_delta.calculatePixelColorDeltaSimd
│  │╎╎ ││   0x10010b578      1f0013eb       cmp x0, x19
│ ────────< 0x10010b57c      adfbff54       b.le 0x10010b4f0
│  │╎╎ ││   0x10010b580      e82740f9       ldr x8, [arg_110hx48]
│  │╎╎ ││   0x10010b584      08914039       ldrb w8, [x8, 0x24]
│  │╎╎ ││   0x10010b588      1f050071       cmp w8, 1
│  │╎╎┌───< 0x10010b58c      a1010054       b.ne 0x10010b5c0
│  │╎╎│││   0x10010b590      e0031baa       mov x0, x27                ; int64_t arg1
│  │╎╎│││   0x10010b594      e1031aaa       mov x1, x26                ; int64_t arg2
│  │╎╎│││   0x10010b598      e20319aa       mov x2, x25                ; int64_t arg3
│  │╎╎│││   0x10010b59c      e32340f9       ldr x3, [arg_110hx40]
│  │╎╎│││   0x10010b5a0      affdff97       bl sym._antialiasing.detect
│ ────────< 0x10010b5a4      60fa0737       tbnz w0, 0, 0x10010b4f0
│  │╎╎│││   0x10010b5a8      e0031baa       mov x0, x27                ; int64_t arg1
│  │╎╎│││   0x10010b5ac      e1031aaa       mov x1, x26                ; int64_t arg2
│  │╎╎│││   0x10010b5b0      e22340f9       ldr x2, [arg_110hx40]      ; int64_t arg3
│  │╎╎│││   0x10010b5b4      e30319aa       mov x3, x25
│  │╎╎│││   0x10010b5b8      a9fdff97       bl sym._antialiasing.detect
│ ────────< 0x10010b5bc      a0f90737       tbnz w0, 0, 0x10010b4f0
│  │╎╎│││   ; CODE XREF from sym._diff.compareSameLayouts @ 0x10010b58c(x)
│  │╎╎└───> 0x10010b5c0      ea2743a9       ldp x10, x9, [arg_110hx30]
│  │╎╎ ││   0x10010b5c4      280140b9       ldr w8, [x9]
│  │╎╎ ││   0x10010b5c8      08050011       add w8, w8, 1
│  │╎╎ ││   0x10010b5cc      280100b9       str w8, [x9]
│  │╎╎ ││   0x10010b5d0      48c14039       ldrb w8, [x10, 0x30]
│  │╎╎┌───< 0x10010b5d4      e8000034       cbz w8, 0x10010b5f0
│  │╎╎│││   0x10010b5d8      e82740f9       ldr x8, [arg_110hx48]
│  │╎╎│││   0x10010b5dc      082140b9       ldr w8, [x8, 0x20]
│  │╎╎│││   0x10010b5e0      490140f9       ldr x9, [x10]
│  │╎╎│││   0x10010b5e4      4a2140b9       ldr w10, [x10, 0x20]
│  │╎╎│││   0x10010b5e8      4a6d1a1b       madd w10, w10, w26, w27
│  │╎╎│││   0x10010b5ec      28592ab8       str w8, [x9, w10, uxtw 2]
│  │╎╎│││   ; CODE XREF from sym._diff.compareSameLayouts @ 0x10010b5d4(x)
│ ────└───> 0x10010b5f0      15f8ffb4       cbz x21, 0x10010b4f0
│  │╎╎ ││   0x10010b5f4      a82240b9       ldr w8, [x21, 0x20]
│  │╎╎┌───< 0x10010b5f8      c8000034       cbz w8, 0x10010b610
│  │╎╎│││   0x10010b5fc      a90240f9       ldr x9, [x21]
│  │╎╎│││   0x10010b600      0a050051       sub w10, w8, 1
│  │╎╎│││   0x10010b604      29596ab8       ldr w9, [x9, w10, uxtw 2]
│  │╎╎│││   0x10010b608      3f011a6b       cmp w9, w26
│ ────────< 0x10010b60c      22f7ff54       b.hs 0x10010b4f0
│  │╎╎│││   ; CODE XREF from sym._diff.compareSameLayouts @ 0x10010b5f8(x)
│  │╎╎└───> 0x10010b610      a90640f9       ldr x9, [x21, 8]
│  │╎╎ ││   0x10010b614      3f0108eb       cmp x9, x8
│ ────────< 0x10010b618      c9f6ff54       b.ls 0x10010b4f0
│  │╎╎ ││   0x10010b61c      a90240f9       ldr x9, [x21]
│  │╎╎ ││   0x10010b620      3a7928b8       str w26, [x9, x8, lsl 2]
│  │╎╎ ││   0x10010b624      a82240b9       ldr w8, [x21, 0x20]
│  │╎╎ ││   0x10010b628      08050011       add w8, w8, 1
│  │╎╎ ││   0x10010b62c      a82200b9       str w8, [x21, 0x20]
│ ────────< 0x10010b630      b0ffff17       b 0x10010b4f0
│  │╎╎ ││   ; CODE XREF from sym._diff.compareSameLayouts @ 0x10010b4e0(x)
│  │╎╎ └──> 0x10010b634      09011b4b       sub w9, w8, w27
│  │╎╎  │   0x10010b638      3f110071       cmp w9, 4
│  │╎╎ ┌──< 0x10010b63c      69000054       b.ls 0x10010b648
│  │╎╎ ││   0x10010b640      89008052       mov w9, 4
│  │╎╎┌───< 0x10010b644      0e000014       b 0x10010b67c
│  │╎╎│││   ; CODE XREF from sym._diff.compareSameLayouts @ 0x10010b63c(x)
│  │╎╎│└──> 0x10010b648      5a070011       add w26, w26, 1
│  │╎╎│ │   0x10010b64c      3f110071       cmp w9, 4
│  │╎╎│┌──< 0x10010b650      00010054       b.eq 0x10010b670
│  │╎╎│││   0x10010b654      8a008052       mov w10, 4
│  │╎╎│││   0x10010b658      4901094b       sub w9, w10, w9
│  │╎╎│││   ; CODE XREF from sym._diff.compareSameLayouts @ 0x10010b66c(x)
│ ┌───────> 0x10010b65c      2a01086b       subs w10, w9, w8
│ ────────< 0x10010b660      c3000054       b.lo 0x10010b678
│ ╎│╎╎│││   0x10010b664      5a070011       add w26, w26, 1
│ ╎│╎╎│││   0x10010b668      e9030aaa       mov x9, x10
│ └───────< 0x10010b66c      81ffff54       b.ne 0x10010b65c
│  │╎╎│││   ; CODE XREF from sym._diff.compareSameLayouts @ 0x10010b650(x)
│  │╎╎│└──> 0x10010b670      1b008052       mov w27, 0
│  │└─────< 0x10010b674      8effff17       b 0x10010b4ac
│  │ ╎│ │   ; CODE XREF from sym._diff.compareSameLayouts @ 0x10010b660(x)
│ ────────> 0x10010b678      1b008052       mov w27, 0
│  │ ╎│ │   ; CODE XREF from sym._diff.compareSameLayouts @ 0x10010b644(x)
│  │ ╎└───> 0x10010b67c      7b03090b       add w27, w27, w9
│  │ └────< 0x10010b680      8bffff17       b 0x10010b4ac
│  │    │   ; CODE XREF from sym._diff.compareSameLayouts @ 0x10010b4b4(x)
│  └──────> 0x10010b684      e80340f9       ldr x8, [sp]
│       │   0x10010b688      16110091       add x22, x8, 4
│       │   0x10010b68c      fc0317aa       mov x28, x23
│       │   0x10010b690      f70740f9       ldr x23, [var_8h]
│       │   0x10010b694      df0217eb       cmp x22, x23
│      ┌──< 0x10010b698      e3000054       b.lo 0x10010b6b4
│     ┌───< 0x10010b69c      53000014       b 0x10010b7e8
│     │││   ; CODE XREF from sym._diff.compareSameLayouts @ 0x10010b46c(x)
│     ││└─> 0x10010b6a0      160080d2       mov x22, 0
│     ││    0x10010b6a4      1a008052       mov w26, 0
│     ││    0x10010b6a8      1b008052       mov w27, 0
│     ││    0x10010b6ac      df0217eb       cmp x22, x23
│     ││┌─< 0x10010b6b0      c2090054       b.hs 0x10010b7e8
│     │││   ; CODE XREF from sym._diff.compareSameLayouts @ 0x10010b698(x)
│     │└──> 0x10010b6b4      e80b40f9       ldr x8, [arg_110hx10]
│     │ │   0x10010b6b8      1f0100f1       cmp x8, 0
│     │ │   0x10010b6bc      841b40fa       ccmp x28, 0, 4, ne
│     │ │   0x10010b6c0      f4079f1a       cset w20, ne
│     │ │   0x10010b6c4      18110091       add x24, x8, 4
│     │┌──< 0x10010b6c8      09000014       b 0x10010b6ec
│     │││   ; XREFS: CODE 0x10010b6fc  CODE 0x10010b718  CODE 0x10010b730  CODE 0x10010b758  CODE 0x10010b770  CODE 0x10010b7a4  
│     │││   ; XREFS: CODE 0x10010b7c0  CODE 0x10010b7cc  CODE 0x10010b7e4  
│ ┌┌┌┌────> 0x10010b6cc      282340b9       ldr w8, [x25, 0x20]
│ ╎╎╎╎│││   0x10010b6d0      69070011       add w9, w27, 1
│ ╎╎╎╎│││   0x10010b6d4      3f01086b       cmp w9, w8
│ ╎╎╎╎│││   0x10010b6d8      5a379a1a       cinc w26, w26, hs
│ ╎╎╎╎│││   0x10010b6dc      fb279b1a       csinc w27, wzr, w27, hs
│ ╎╎╎╎│││   0x10010b6e0      d6060091       add x22, x22, 1
│ ╎╎╎╎│││   0x10010b6e4      df0217eb       cmp x22, x23
│ ────────< 0x10010b6e8      00080054       b.eq 0x10010b7e8
│ ╎╎╎╎│││   ; CODE XREF from sym._diff.compareSameLayouts @ 0x10010b6c8(x)
│ ╎╎╎╎│└──> 0x10010b6ec      e82742a9       ldp x8, x9, [arg_110hx20]
│ ╎╎╎╎│ │   0x10010b6f0      207976b8       ldr w0, [x9, x22, lsl 2]
│ ╎╎╎╎│ │   0x10010b6f4      017976b8       ldr w1, [x8, x22, lsl 2]
│ ╎╎╎╎│ │   0x10010b6f8      1f00016b       cmp w0, w1
│ ────────< 0x10010b6fc      80feff54       b.eq 0x10010b6cc
│ ╎╎╎╎│ │   0x10010b700      e80318aa       mov x8, x24
│ ╎╎╎╎│ │   0x10010b704      e9031caa       mov x9, x28
│ ╎╎╎╎│┌──< 0x10010b708      14010034       cbz w20, 0x10010b728
│ ╎╎╎╎│││   ; CODE XREF from sym._diff.compareSameLayouts @ 0x10010b724(x)
│ ────────> 0x10010b70c      0aad7f29       ldp w10, w11, [x8, -4]
│ ╎╎╎╎│││   0x10010b710      5f01166b       cmp w10, w22
│ ╎╎╎╎│││   0x10010b714      6091567a       ccmp w11, w22, 0, ls
│ ────────< 0x10010b718      a2fdff54       b.hs 0x10010b6cc
│ ╎╎╎╎│││   0x10010b71c      08210091       add x8, x8, 8
│ ╎╎╎╎│││   0x10010b720      290500f1       subs x9, x9, 1
│ ────────< 0x10010b724      41ffff54       b.ne 0x10010b70c
│ ╎╎╎╎│││   ; CODE XREF from sym._diff.compareSameLayouts @ 0x10010b708(x)
│ ╎╎╎╎│└──> 0x10010b728      dafcff97       bl sym._color_delta.calculatePixelColorDeltaSimd
│ ╎╎╎╎│ │   0x10010b72c      1f0013eb       cmp x0, x19
│ ────────< 0x10010b730      edfcff54       b.le 0x10010b6cc
│ ╎╎╎╎│ │   0x10010b734      e82740f9       ldr x8, [arg_110hx48]
│ ╎╎╎╎│ │   0x10010b738      08914039       ldrb w8, [x8, 0x24]
│ ╎╎╎╎│ │   0x10010b73c      1f050071       cmp w8, 1
│ ╎╎╎╎│┌──< 0x10010b740      a1010054       b.ne 0x10010b774
│ ╎╎╎╎│││   0x10010b744      e0031baa       mov x0, x27                ; int64_t arg1
│ ╎╎╎╎│││   0x10010b748      e1031aaa       mov x1, x26                ; int64_t arg2
│ ╎╎╎╎│││   0x10010b74c      e20319aa       mov x2, x25                ; int64_t arg3
│ ╎╎╎╎│││   0x10010b750      e32340f9       ldr x3, [arg_110hx40]
│ ╎╎╎╎│││   0x10010b754      42fdff97       bl sym._antialiasing.detect
│ ────────< 0x10010b758      a0fb0737       tbnz w0, 0, 0x10010b6cc
│ ╎╎╎╎│││   0x10010b75c      e0031baa       mov x0, x27                ; int64_t arg1
│ ╎╎╎╎│││   0x10010b760      e1031aaa       mov x1, x26                ; int64_t arg2
│ ╎╎╎╎│││   0x10010b764      e22340f9       ldr x2, [arg_110hx40]      ; int64_t arg3
│ ╎╎╎╎│││   0x10010b768      e30319aa       mov x3, x25
│ ╎╎╎╎│││   0x10010b76c      3cfdff97       bl sym._antialiasing.detect
│ ────────< 0x10010b770      e0fa0737       tbnz w0, 0, 0x10010b6cc
│ ╎╎╎╎│││   ; CODE XREF from sym._diff.compareSameLayouts @ 0x10010b740(x)
│ ╎╎╎╎│└──> 0x10010b774      ea2743a9       ldp x10, x9, [arg_110hx30]
│ ╎╎╎╎│ │   0x10010b778      280140b9       ldr w8, [x9]
│ ╎╎╎╎│ │   0x10010b77c      08050011       add w8, w8, 1
│ ╎╎╎╎│ │   0x10010b780      280100b9       str w8, [x9]
│ ╎╎╎╎│ │   0x10010b784      48c14039       ldrb w8, [x10, 0x30]
│ ╎╎╎╎│┌──< 0x10010b788      e8000034       cbz w8, 0x10010b7a4
│ ╎╎╎╎│││   0x10010b78c      e82740f9       ldr x8, [arg_110hx48]
│ ╎╎╎╎│││   0x10010b790      082140b9       ldr w8, [x8, 0x20]
│ ╎╎╎╎│││   0x10010b794      490140f9       ldr x9, [x10]
│ ╎╎╎╎│││   0x10010b798      4a2140b9       ldr w10, [x10, 0x20]
│ ╎╎╎╎│││   0x10010b79c      4a6d1a1b       madd w10, w10, w26, w27
│ ╎╎╎╎│││   0x10010b7a0      28592ab8       str w8, [x9, w10, uxtw 2]
│ │╎╎╎│││   ; CODE XREF from sym._diff.compareSameLayouts @ 0x10010b788(x)
│ └────└──> 0x10010b7a4      55f9ffb4       cbz x21, 0x10010b6cc
│  ╎╎╎│ │   0x10010b7a8      a82240b9       ldr w8, [x21, 0x20]
│  ╎╎╎│┌──< 0x10010b7ac      c8000034       cbz w8, 0x10010b7c4
│  ╎╎╎│││   0x10010b7b0      a90240f9       ldr x9, [x21]
│  ╎╎╎│││   0x10010b7b4      0a050051       sub w10, w8, 1
│  ╎╎╎│││   0x10010b7b8      29596ab8       ldr w9, [x9, w10, uxtw 2]
│  ╎╎╎│││   0x10010b7bc      3f011a6b       cmp w9, w26
│  └──────< 0x10010b7c0      62f8ff54       b.hs 0x10010b6cc
│   ╎╎│││   ; CODE XREF from sym._diff.compareSameLayouts @ 0x10010b7ac(x)
│   ╎╎│└──> 0x10010b7c4      a90640f9       ldr x9, [x21, 8]
│   ╎╎│ │   0x10010b7c8      3f0108eb       cmp x9, x8
│   └─────< 0x10010b7cc      09f8ff54       b.ls 0x10010b6cc
│    ╎│ │   0x10010b7d0      a90240f9       ldr x9, [x21]
│    ╎│ │   0x10010b7d4      3a7928b8       str w26, [x9, x8, lsl 2]
│    ╎│ │   0x10010b7d8      a82240b9       ldr w8, [x21, 0x20]
│    ╎│ │   0x10010b7dc      08050011       add w8, w8, 1
│    ╎│ │   0x10010b7e0      a82200b9       str w8, [x21, 0x20]
│    └────< 0x10010b7e4      baffff17       b 0x10010b6cc
│     │ │   ; CODE XREFS from sym._diff.compareSameLayouts @ 0x10010b69c(x), 0x10010b6b0(x), 0x10010b6e8(x)
│ ────└─└─> 0x10010b7e8      fd7b50a9       ldp x29, x30, [var_100h]
│           0x10010b7ec      f44f4fa9       ldp x20, x19, [var_f0h]
│           0x10010b7f0      f6574ea9       ldp x22, x21, [var_e0h]
│           0x10010b7f4      f85f4da9       ldp x24, x23, [var_d0h]
│           0x10010b7f8      fa674ca9       ldp x26, x25, [var_c0h]
│           0x10010b7fc      fc6f4ba9       ldp x28, x27, [var_b0h]
│           0x10010b800      e9234a6d       ldp d9, d8, [var_a0h]
│           0x10010b804      ff430491       add sp, sp, 0x110          ; 0x178000
└           0x10010b808      c0035fd6       ret

┌ 460: sym._color_delta.calculatePixelColorDeltaSimd (int64_t arg1, int64_t arg2);
│ `- args(x0, x1) vars(2:sp[0x8..0x10])
│           0x10010aa90      fd7bbfa9       stp x29, x30, [sp, -0x10]!
│           0x10010aa94      fd030091       mov x29, sp
│           0x10010aa98      0000271e       fmov s0, w0                ; arg1
│           0x10010aa9c      201c0c4e       mov v0.s[1], w1            ; arg2
│           0x10010aaa0      21e6002f       movi d1, 0x0000ff000000ff
│           0x10010aaa4      021c210e       and v2.8b, v0.8b, v1.8b
│           0x10010aaa8      0304382f       ushr v3.2s, v0.2s, 8
│           0x10010aaac      631c210e       and v3.8b, v3.8b, v1.8b
│           0x10010aab0      0404302f       ushr v4.2s, v0.2s, 0x10
│           0x10010aab4      e437072f       bic v4.2s, 0xff, lsl 8
│           0x10010aab8      0504282f       ushr v5.2s, v0.2s, 0x18
│           0x10010aabc      2664000f       movi v6.2s, 1, lsl 24
│           0x10010aac0      c034a02e       cmhi v0.2s, v6.2s, v0.2s
│           0x10010aac4      06a4200f       sshll v6.2d, v0.2s, 0
│           0x10010aac8      a08ca12e       cmeq v0.2s, v5.2s, v1.2s
│           0x10010aacc      07a4200f       sshll v7.2d, v0.2s, 0
│           0x10010aad0      40542c0f       shl v0.2s, v2.2s, 0xc
│           0x10010aad4      00a4202f       ushll v0.2d, v0.2s, 0
│           0x10010aad8      421c212e       eor v2.8b, v2.8b, v1.8b
│           0x10010aadc      429ca50e       mul v2.2s, v2.2s, v5.2s
│           0x10010aae0      42542c0f       shl v2.2s, v2.2s, 0xc
│           0x10010aae4      28028252       mov w8, 0x1011             ; '\x11\x10'
│           0x10010aae8      0802a272       movk w8, 0x1010, lsl 16    ; '\x10\x10'
│           0x10010aaec      100d040e       dup v16.2s, w8
│           0x10010aaf0      42c0b02e       umull v2.2d, v2.2s, v16.2s
│           0x10010aaf4      42045c6f       ushr v2.2d, v2.2d, 0x24
│           0x10010aaf8      e81f1432       mov w8, 0xff000
│           0x10010aafc      110d084e       dup v17.2d, x8
│           0x10010ab00      2286e26e       sub v2.2d, v17.2d, v2.2d
│           0x10010ab04      401ce76e       bif v0.16b, v2.16b, v7.16b
│           0x10010ab08      201ea66e       bit v0.16b, v17.16b, v6.16b
│           0x10010ab0c      0028a10e       xtn v0.2s, v0.2d
│           0x10010ab10      62542c0f       shl v2.2s, v3.2s, 0xc
│           0x10010ab14      42a4202f       ushll v2.2d, v2.2s, 0
│           0x10010ab18      631c212e       eor v3.8b, v3.8b, v1.8b
│           0x10010ab1c      639ca50e       mul v3.2s, v3.2s, v5.2s
│           0x10010ab20      63542c0f       shl v3.2s, v3.2s, 0xc
│           0x10010ab24      63c0b02e       umull v3.2d, v3.2s, v16.2s
│           0x10010ab28      63045c6f       ushr v3.2d, v3.2d, 0x24
│           0x10010ab2c      2386e36e       sub v3.2d, v17.2d, v3.2d
│           0x10010ab30      621ce76e       bif v2.16b, v3.16b, v7.16b
│           0x10010ab34      221ea66e       bit v2.16b, v17.16b, v6.16b
│           0x10010ab38      4328a10e       xtn v3.2s, v2.2d
│           0x10010ab3c      92542c0f       shl v18.2s, v4.2s, 0xc
│           0x10010ab40      52a6202f       ushll v18.2d, v18.2s, 0
│           0x10010ab44      811c212e       eor v1.8b, v4.8b, v1.8b
│           0x10010ab48      219ca50e       mul v1.2s, v1.2s, v5.2s
│           0x10010ab4c      21542c0f       shl v1.2s, v1.2s, 0xc
│           0x10010ab50      21c0b02e       umull v1.2d, v1.2s, v16.2s
│           0x10010ab54      21045c6f       ushr v1.2d, v1.2d, 0x24
│           0x10010ab58      2186e16e       sub v1.2d, v17.2d, v1.2d
│           0x10010ab5c      411ea76e       bit v1.16b, v18.16b, v7.16b
│           0x10010ab60      211ea66e       bit v1.16b, v17.16b, v6.16b
│           0x10010ab64      08998052       mov w8, 0x4c8
│           0x10010ab68      040d040e       dup v4.2s, w8
│           0x10010ab6c      2528a10e       xtn v5.2s, v1.2d
│           0x10010ab70      492c8152       mov w9, 0x962
│           0x10010ab74      260d040e       dup v6.2s, w9
│           0x10010ab78      63c0a62e       umull v3.2d, v3.2s, v6.2s
│           0x10010ab7c      0380a42e       umlal v3.2d, v0.2s, v4.2s
│           0x10010ab80      893a8052       mov w9, 0x1d4
│           0x10010ab84      240d040e       dup v4.2s, w9
│           0x10010ab88      a380a42e       umlal v3.2d, v5.2s, v4.2s
│           0x10010ab8c      6304746f       ushr v3.2d, v3.2d, 0xc
│           0x10010ab90      29318152       mov w9, 0x989
│           0x10010ab94      240d040e       dup v4.2s, w9
│           0x10010ab98      493c184e       mov x9, v2.d[1]
│           0x10010ab9c      4a8c8092       mov x10, -0x463
│           0x10010aba0      2b7d0a9b       mul x11, x9, x10
│           0x10010aba4      4c00669e       fmov x12, d2
│           0x10010aba8      8a7d0a9b       mul x10, x12, x10
│           0x10010abac      4201679e       fmov d2, x10
│           0x10010abb0      621d184e       mov v2.d[1], x11
│           0x10010abb4      0280a42e       umlal v2.2d, v0.2s, v4.2s
│           0x10010abb8      2a3c184e       mov x10, v1.d[1]
│           0x10010abbc      aba48092       mov x11, -0x526
│           0x10010abc0      4a7d0b9b       mul x10, x10, x11
│           0x10010abc4      2d00669e       fmov x13, d1
│           0x10010abc8      ab7d0b9b       mul x11, x13, x11
│           0x10010abcc      6101679e       fmov d1, x11
│           0x10010abd0      411d184e       mov v1.d[1], x10
│           0x10010abd4      4184e14e       add v1.2d, v2.2d, v1.2d
│           0x10010abd8      2104744f       sshr v1.2d, v1.2d, 0xc
│           0x10010abdc      4a6c8052       mov w10, 0x362
│           0x10010abe0      420d040e       dup v2.2s, w10
│           0x10010abe4      6a0b8192       mov x10, -0x85c
│           0x10010abe8      297d0a9b       mul x9, x9, x10
│           0x10010abec      8a7d0a9b       mul x10, x12, x10
│           0x10010abf0      4401679e       fmov d4, x10
│           0x10010abf4      241d184e       mov v4.d[1], x9
│           0x10010abf8      0480a22e       umlal v4.2d, v0.2s, v2.2s
│           0x10010abfc      499f8052       mov w9, 0x4fa
│           0x10010ac00      200d040e       dup v0.2s, w9
│           0x10010ac04      a480a02e       umlal v4.2d, v5.2s, v0.2s
│           0x10010ac08      8004744f       sshr v0.2d, v4.2d, 0xc
│           0x10010ac0c      6204184e       dup v2.2d, v3.d[1]
│           0x10010ac10      6284e26e       sub v2.2d, v3.2d, v2.2d
│           0x10010ac14      4900669e       fmov x9, d2
│           0x10010ac18      2204184e       dup v2.2d, v1.d[1]
│           0x10010ac1c      2184e26e       sub v1.2d, v1.2d, v2.2d
│           0x10010ac20      2a00669e       fmov x10, d1
│           0x10010ac24      0104184e       dup v1.2d, v0.d[1]
│           0x10010ac28      0084e16e       sub v0.2d, v0.2d, v1.2d
│           0x10010ac2c      0b00669e       fmov x11, d0
│           0x10010ac30      297d099b       mul x9, x9, x9
│           0x10010ac34      ac028152       mov w12, 0x815
│           0x10010ac38      4a7d0a9b       mul x10, x10, x10
│           0x10010ac3c      487d089b       mul x8, x10, x8
│           0x10010ac40      28210c9b       madd x8, x9, x12, x8
│           0x10010ac44      697d0b9b       mul x9, x11, x11
│           0x10010ac48      2a648052       mov w10, 0x321
│           0x10010ac4c      28210a9b       madd x8, x9, x10, x8
│           0x10010ac50      00fd58d3       lsr x0, x8, 0x18
│           0x10010ac54      fd7bc1a8       ldp x29, x30, [sp], 0x10
└           0x10010ac58      c0035fd6       ret

