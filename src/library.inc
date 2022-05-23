#include "lib1funcs.inc"

.macro _BSWAP r1_arg1, r1_arg2, r2_arg1, r2_arg2
    push XH
    push XL
    _MOVW XH, XL, \r1_arg2, \r2_arg1
    mov \r1_arg1, \r2_arg2
    _MOVW \r1_arg2, \r2_arg1, XH, XL
    pop XL
    pop XH
.endm

.macro _XCHG r_arg1, r_arg2
    mov r0, \r_arg1
    mov \r_arg1, \r_arg2
    mov \r_arg2, r0
.endm