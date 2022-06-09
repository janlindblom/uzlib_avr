
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

.macro _SBIW r_arg1, i_arg2
#if defined (__AVR_TINY__)
    subi \r_arg1,   lo8(\i_arg2)
    sbci \r_arg1+1, hi8(\i_arg2)
#else
    sbiw \r_arg1, \i_arg2
#endif
.endm

.macro _ADIW r_arg1, i_arg2
#if defined (__AVR_TINY__)
    push r24
    push r25
    ldi r24, lo8(\i_arg2)
    ldi r25, hi8(\i_arg2)
    add \r_arg1, r24
    adc \r_arg1+1, r25
    pop r25
    pop r24
#else
    adiw \r_arg1, \i_arg2
#endif
.endm