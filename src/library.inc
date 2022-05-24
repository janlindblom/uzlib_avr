
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

.macro _MOVW dh, dl, sh, sl
#if !defined (__AVR_HAVE_MOVW__)
    mov \dl, \sl
    mov \dh, \sh
#else
    movw \dl, \sl
#endif
.endm

#if defined (__AVR_HAVE_JMP_CALL__)
#define _XCALL call
#define _XJMP  jmp
#else
#define _XCALL rcall
#define _XJMP  rjmp
#endif

.macro _WSUBI r_arg1, i_arg2
#if defined (__AVR_TINY__)
    subi \r_arg1,   lo8(\i_arg2)
    sbci \r_arg1+1, hi8(\i_arg2)
#else
    sbiw \r_arg1, \i_arg2
#endif
.endm
