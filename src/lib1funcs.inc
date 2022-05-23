/*  -*- Mode: Asm -*-  */

/* Modified lib1funcs.S from avr-gcc libgcc. */

/* Copyright (C) 1998-2022 Free Software Foundation, Inc.
   Contributed by Denis Chertykov <chertykov@gmail.com>

This file is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation; either version 3, or (at your option) any
later version.

This file is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

Under Section 7 of GPL version 3, you are granted additional
permissions described in the GCC Runtime Library Exception, version
3.1, as published by the Free Software Foundation.

You should have received a copy of the GNU General Public License and
a copy of the GCC Runtime Library Exception along with this program;
see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see
<http://www.gnu.org/licenses/>.  */

;; pseudo op-code DIV Rd, Rr: R1:R0 <-- Rd / Rr
.macro div r_arg1, r_arg2
    _DIV \r_arg1, \r_arg2
.endm

#if !defined (__AVR_HAVE_MUL__)
;; pseudo op-code MUL Rd, Rr: R1:R0 <-- Rd * Rr
.macro mul r_arg1, r_arg2
    _MULW \r_arg1, \r_arg2
.endm

.macro mulw r_arg1, r_arg2
    _MULWW \r_arg1, \r_arg2
.endm

;; pseudo op-code MULS Rd, Rr: R1:R0 <-- Rd * Rr
.macro muls r_arg1, r_arg2
    _MULS \r_arg1, \r_arg2
.endm
#endif

#if defined (__AVR_HAVE_SPH__)
#define __SP_H__ 0x3e
#endif
#define __SP_L__ 0x3d

#if defined (__AVR_TINY__)
#define __zero_reg__ r17
#define __tmp_reg__ r16
#else
#define __zero_reg__ 1
#define __tmp_reg__ 0
#endif


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

.macro _MULS r_arg1, r_arg2
#if defined (__AVR_HAVE_MUL__)
    mul \r_arg1, \r_arg2
#else
    push r22
    push r24
    mov r22, \r_arg1
    mov r24, \r_arg2
    _XCALL umulqihi3
    _MOVW r1, r0, r25, r24
    pop r24
    pop r22
#endif
.endm

.macro _MULW r_arg1, r_arg2
#if defined (__AVR_HAVE_MUL__)
    mul \r_arg1, \r_arg2
#else
    push r22
    push r24
    mov r22, \r_arg1
    mov r24, \r_arg2
    _XCALL __mulqi3
    mov r0, r24
    pop r24
    pop r22
#endif
.endm

.macro _MULWW r1_arg1, r1_arg2, r2_arg1, r2_arg2
#if defined (__AVR_HAVE_MUL__)
    _MOVW r27, r26, \r1_arg1, \r1_arg2
    _MOVW r19, r18, \r2_arg1, \r2_arg2
    _XCALL __mulhisi3
#else
    _MOVW r25, r24, \r1_arg1, \r1_arg2
    _MOVW r23, r22, \r2_arg1, \r2_arg2
    _XCALL __mulqihi3
#endif
.endm

.macro _DIV r_arg1, r_arg2
    push r22
    push r24
    mov r24, \r_arg1
    mov r22, \r_arg2
    _XCALL udivmodqi4
    _MOVW r1, r0, r25, r24
    pop r24
    pop r22
.endm

.macro do_prologue_saves n_pushed n_frame=0
    ldi r26, lo8(\n_frame)
    ldi r27, hi8(\n_frame)
    ldi r30, lo8(gs(.L_prologue_saves.\@))
    ldi r31, hi8(gs(.L_prologue_saves.\@))
    _XJMP __prologue_saves__ + ((18 - (\n_pushed)) * 2)
.L_prologue_saves.\@:
.endm

.macro do_epilogue_restores n_pushed n_frame=0
    in r28, __SP_L__
#ifdef __AVR_HAVE_SPH__
    in r29, __SP_H__
.if \n_frame > 63
    subi r28, lo8(-\n_frame)
    sbci r29, hi8(-\n_frame)
.elseif \n_frame > 0
    adiw r28, \n_frame
.endif
#else
    clr r29
.if \n_frame > 0
    subi r28, lo8(-\n_frame)
.endif
#endif /* HAVE SPH */
    ldi r30, \n_pushed
    _XJMP __epilogue_restores__ + ((18 - (\n_pushed)) * 2)
.endm

#if !defined (__AVR_HAVE_MUL__)
/*******************************************************
    Multiplication  8 x 8  without MUL
*******************************************************/

.func __mulqi3
__mulqi3:
    clr __tmp_reg__                      ; clear result
__mulqi3_loop:
    sbrc r24, 0
    add __tmp_reg__, r22
    add r22, r22                ; shift multiplicand
    breq __mulqi3_exit          ; while multiplicand != 0
    lsr r24                     ;
    brne __mulqi3_loop          ; exit if multiplier = 0
__mulqi3_exit:
    mov r24, __tmp_reg__                 ; result to return register
    ret
.endfunc

/*******************************************************
    Widening Multiplication  16 = 8 x 8  without MUL
    Multiplication  16 x 16  without MUL
*******************************************************/

;;; R25:R24 = (unsigned int) R22 * (unsigned int) R24
;;; (r25:r24) = (unsigned int) r22 * (unsigned int) r24
;;; Clobbers: r0, R21..R23
.func umulqihi3
umulqihi3:
    clr r23
    clr r25
    _XJMP __mulhi3
.endfunc

;;; R25:R24 = (signed int) R22 * (signed int) R24
;;; (r25:r24) = (signed int) r22  * (signed int) r24
;;; Clobbers: r0, R20..R23
.func __mulqihi3
__mulqihi3:
    ;; Sign-extend r24
    clr r25
    sbrc r24, 7
    com r25
    ;; The multiplication runs twice as fast if r23 is zero, thus:
    ;; Zero-extend r22
    clr r23
#ifdef __AVR_HAVE_JMP_CALL__
    ;; Store  r24 * sign of A
    clr r20
    sbrc r22, 7
    mov r20, r24
    call __mulhi3
#else /* have no CALL */
    ;; Skip sign-extension of A if A >= 0
    ;; Same size as with the first alternative but avoids errata skip
    ;; and is faster if A >= 0
    sbrs r22, 7
    rjmp __mulhi3
    ;; If  A < 0  store B
    mov r20, r24
    rcall __mulhi3
#endif /* HAVE_JMP_CALL */
    ;; 1-extend A after the multiplication
    sub r25, r20
    ret
.endfunc

;;; R25:R24 = R23:R22 * R25:R24
;;; (r25:r24) = (r23:r22) * (r25:r24)
;;; Clobbers: r0, R21..R23
.func __mulhi3
__mulhi3:
    ;; Clear result
    clr __tmp_reg__
    clr r21
    rjmp 3f
1:
    ;; Bit n of A is 1  -->  C += B << n
    add __tmp_reg__, r24
    adc r21, r25
2:
    lsl r24
    rol r25
3:
    ;; If B == 0 we are ready
    _WSUBI r24, 0
    breq 9f

    ;; Carry = n-th bit of A
    lsr r23
    ror r22
    ;; If bit n of A is set, then go add  B * 2^n  to  C
    brcs 1b

    ;; Carry = 0  -->  The ROR above acts like  CP r22, 0
    ;; Thus, it is sufficient to CPC the high part to test A against 0
    cpc r23, __zero_reg__
    ;; Only proceed if A != 0
    brne 2b
9:
    ;; Move Result into place
    mov r24, __tmp_reg__
    mov r25, r21
    ret
.endfunc

/*******************************************************
    Widening Multiplication  32 = 16 x 16  without MUL
*******************************************************/

.func __umulhisi3
__umulhisi3:
    _MOVW r19, r18, r25, r24
    ;; Zero-extend B
    clr r20
    clr r21
    ;; Zero-extend A
    _MOVW r25, r24, r21, r20
    _XJMP __mulsi3
.endfunc

.func __mulhisi3
__mulhisi3:
    _MOVW r19, r18, r25, r24
    ;; Sign-extend B
    lsl r25
    sbc r20, r20
    mov r21, r20
#ifdef __AVR_ERRATA_SKIP_JMP_CALL__
    ;; Sign-extend A
    clr r24
    sbrc r23, 7
    com r24
    mov r25, r24
    _XJMP __mulsi3
#else /*  no __AVR_ERRATA_SKIP_JMP_CALL__ */
    ;; Zero-extend A and __mulsi3 will run at least twice as fast
    ;; compared to a sign-extended A.
    clr r24
    clr r25
    sbrs r23, 7
    _XJMP __mulsi3
    ;; If  A < 0  then perform the  B * 0xffff.... before the
    ;; very multiplication by initializing the high part of the
    ;; result CC with -B.
    _MOVW r31, r30, r25, r24
    sub r30, r18
    sbc r31, r19
    _XJMP __mulsi3_helper
#endif /*  __AVR_ERRATA_SKIP_JMP_CALL__ */
.endfunc


/*******************************************************
    Multiplication  32 x 32  without MUL
*******************************************************/

.func __mulsi3
__mulsi3:
#if defined (__AVR_TINY__)
    in r26, __SP_L__            ; safe to use X, as it is r26/r27
    in r27, __SP_H__
    subi r26, lo8(-3)           ; Add 3 to point past return address
    sbci r27, hi8(-3)
    push r18                    ; save callee saved regs
    push r19
    ld r18, X+                  ; load from caller stack
    ld r19, X+
    ld r20, X+
    ld r21, X
#endif
    ;; Clear result
    clr r30
    clr r31
    ;; FALLTHRU
.endfunc

.func __mulsi3_helper
__mulsi3_helper:
    clr r26
    clr r27
    rjmp 3f

1:  ;; If bit n of A is set, then add  B * 2^n  to the result in CC
    ;; CC += B
    add r26, r18
    adc r27, r19
    adc r30, r20
    adc r31, r21

2:  ;; B <<= 1
    lsl r18
    rol r19
    rol r20
    rol r21

3:  ;; A >>= 1:  Carry = n-th bit of A
    lsr r25
    ror r24
    ror r23
    ror r22

    brcs 1b
    ;; Only continue if  A != 0
    sbci r23, 0
    brne 2b
    _WSUBI r24, 0
    brne 2b

    ;; All bits of A are consumed:  Copy result to return register C
    _MOVW r23, r22, r27, r26
    _MOVW r25, r24, r31, r30
#if defined (__AVR_TINY__)
    pop r19                     ; restore callee saved regs
    pop r18
#endif  /* defined (__AVR_TINY__) */
    ret
.endfunc

#endif /* !defined (__AVR_HAVE_MUL__) */

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#if defined (__AVR_HAVE_MUL__)

/*******************************************************
    Widening Multiplication  32 = 16 x 16  with MUL
*******************************************************/

;;; R25:R22 = (signed long) R27:R26 * (signed long) R19:R18
;;; r25:r22   = (signed long) r27:r26   * (signed long) r19:r18
;;; Clobbers: r0
.func __mulhisi3
__mulhisi3:
    _XCALL __umulhisi3
    ;; Sign-extend B
    tst r19
    brpl 1f
    sub r24, r26
    sbc r25, r27
1:  ;; Sign-extend A
    _XJMP __usmulhisi3_tail
.endfunc

;;; R25:R22 = (signed long) R27:R26 * (unsigned long) R19:R18
;;; r25:r22   = (signed long) r27:r26   * (unsigned long) r19:r18
;;; Clobbers: r0
.func __usmulhisi3
__usmulhisi3:
    _XCALL __umulhisi3
    ;; FALLTHRU
.endfunc

.func __usmulhisi3_tail
__usmulhisi3_tail:
    ;; Sign-extend A
    sbrs r27, 7
    ret
    sub r24, r18
    sbc r25, r19
    ret
.endfunc

;;; R25:R22 = (unsigned long) R27:R26 * (unsigned long) R19:R18
;;; r25:r22   = (unsigned long) r27:r26   * (unsigned long) r19:r18
;;; Clobbers: r0
.func __umulhisi3
__umulhisi3:
    mul r26, r18
    _MOVW r23, r22, __zero_reg__, __tmp_reg__
    mul r27, r19
    _MOVW r25, r24, __zero_reg__, __tmp_reg__
    mul r26, r19
#ifdef __AVR_HAVE_JMP_CALL__
    ;; This function is used by many other routines, often multiple times.
    ;; Therefore, if the flash size is not too limited, avoid the RCALL
    ;; and inverst 6 Bytes to speed things up.
    add r23, __tmp_reg__
    adc r24, __zero_reg__
    clr __zero_reg__
    adc r25, __zero_reg__
#else
    rcall 1f
#endif
    mul r27, r18
1:  add r23, __tmp_reg__
    adc r24, __zero_reg__
    clr __zero_reg__
    adc r25, __zero_reg__
    ret
.endfunc

/*******************************************************
    Widening Multiplication  32 = 16 x 32  with MUL
*******************************************************/

;;; R25:R22 = (signed long) R27:R26 * R21:R18
;;; (r25:r22) = (signed long) r27:r26   * r21:r18
;;; Clobbers: r0
.func __mulshisi3
__mulshisi3:
#ifdef __AVR_ERRATA_SKIP_JMP_CALL__
    ;; Some cores have problem skipping 2-word instruction
    tst r27
    brmi __mulohisi3
#else
    sbrs r27, 7
#endif /* __AVR_HAVE_JMP_CALL__ */
    _XJMP __muluhisi3
    ;; FALLTHRU
.endfunc

;;; R25:R22 = (one-extended long) R27:R26 * R21:R18
;;; (r25:r22) = (one-extended long) r27:r26   * r21:r18
;;; Clobbers: r0
.func __mulohisi3
__mulohisi3:
    _XCALL   __muluhisi3
    ;; One-extend R27:R26 (r27:r26)
    sub r24, r18
    sbc r25, r19
    ret
.endfunc

;;; R25:R22 = (unsigned long) R27:R26 * R21:R18
;;; (r25:r22) = (unsigned long) r27:r26   * r21:r18
;;; Clobbers: r0
.func __muluhisi3
__muluhisi3:
    _XCALL __umulhisi3
    mul r26, r21
    add r25, __tmp_reg__
    mul r27, r20
    add r25, __tmp_reg__
    mul r26, r20
    add r24, __tmp_reg__
    adc r25, __zero_reg__
    clr __zero_reg__
    ret
.endfunc

/*******************************************************
    Multiplication  32 x 32  with MUL
*******************************************************/

;;; R25:R22 = R25:R22 * R21:R18
;;; (r25:r22) = r25:r22   * r21:r18
;;; Clobbers: R26, R27, r0
.func __mulsi3
__mulsi3:
    _MOVW r27, r26, r23, r22
    push r24
    push r25
    _XCALL __muluhisi3
    pop r27
    pop r26
    ;; r27:r26 now contains the high word of A
    mul r26, r18
    add r24, __tmp_reg__
    adc r25, __zero_reg__
    mul r26, r19
    add r25, __tmp_reg__
    mul r27, r18
    add r25, __tmp_reg__
    clr __zero_reg__
    ret
.endfunc

#endif /* __AVR_HAVE_MUL__ */

/*******************************************************
       Multiplication 24 x 24 with MUL
*******************************************************/

;; r24:r22: In: Multiplicand; Out: Product
;; r20:r18: In: Multiplier
#if defined (__AVR_HAVE_MUL__)
;; R24:R22 *= R20:R18
;; Clobbers: r21, r25, r26, r27, r0
.func __mulpsi3
__mulpsi3:
    _MOVW r27, r26, r23, r22
    mov r21, r24
    _XCALL __umulhisi3
    mul r21, r18
    add r24, __tmp_reg__
    mul r26, r24
    add r24, __tmp_reg__
    clr __zero_reg__
    ret
.endfunc
#else /* !HAVE_MUL */
;; R24:R22 *= R20:R18
;; Clobbers: r0, R18, R19, R20, R21
.func __mulpsi3
__mulpsi3:
#if defined (__AVR_TINY__)
    in r26, __SP_L__
    in r27, __SP_H__
    subi r26, lo8(-3)           ; Add 3 to point past return address
    sbci r27, hi8(-3)
    push r18                    ; save callee saved regs
    push r19
    ld r18,X+                   ; load from caller stack
    ld r19,X+
    ld r20,X+
#endif /* defined (__AVR_TINY__) */

    ;; C[] = 0
    clr __tmp_reg__
    clr r21

0:  ;; Shift N-th Bit of B[] into Carry.  N = 24 - Loop
    LSR r20
    ror r19
    ror r18

    ;; If the N-th Bit of B[] was set...
    brcc 1f

    ;; ...then add A[] * 2^N to the Result C[]
#if defined (__AVR_TINY__)
    add r16, r22
    adc r17, r23
#else
    add __tmp_reg__, r22
    adc __zero_reg__, r23
#endif /* defined (__AVR_TINY__) */
    adc r21,r24

1:  ;; Multiply A[] by 2
    LSL r22
    rol r23
    rol r24

    ;; Loop until B[] is 0
    subi r18, 0
    sbci r19, 0
    sbci r20, 0
    brne 0b

    ;; Copy C[] to the return Register A[]
#if defined (__AVR_TINY__)
    _MOVW r23, r22, r17, r16
#else
    _MOVW r23, r22, __zero_reg__, __tmp_reg__
#endif /* defined (__AVR_TINY__) */
    mov r24, r21

    clr __zero_reg__
#if defined (__AVR_TINY__)
    pop r19
    pop r18
#endif /* (__AVR_TINY__) */
    ret
.endfunc

#endif /* HAVE_MUL */

#if defined (__AVR_HAVE_MUL__)

;; r24:r22: In: Multiplicand
;; r25: In: Multiplier
;; r20:r18: Result
;; r20:r18 = r24:r22 * sign_extend (r25)
.func __mulsqipsi3
__mulsqipsi3:
    mul r22, r25
    _MOVW r19, r18, __zero_reg__, __tmp_reg__
    mul r24, r25
    mov r20, __tmp_reg__
    mul r23, r25
    add r19, __tmp_reg__
    adc r20, __zero_reg__
    clr __zero_reg__
    sbrs r25, 7
    ret
    ;; One-extend r25
    sub r19, r22
    sbc r20, r23
    ret
.endfunc

#endif /* HAVE_MUL */


/*******************************************************
   Widening Multiplication 64 = 32 x 32  with  MUL
*******************************************************/

#if defined (__AVR_HAVE_MUL__)

;; Unsigned widening 64 = 32 * 32 Multiplication with MUL

;; R18[8] = R22[4] * R18[4]
;;
;; Ordinary ABI Function, but additionally sets
;; X = R20[2] = B2[2]
;; Z = R22[2] = A0[2]
.func __umulsidi3
__umulsidi3:
    clt
    ;; FALLTHRU
.endfunc
    ;; T = sign (A)
.func __umulsidi3_helper
__umulsidi3_helper:
    push r29
    push r28                    ; Y
    _MOVW r31, r30, r25, r24
    ;; Counting in Words, we have to perform 4 Multiplications
    ;; 0 * 0
    _MOVW r27, r26, r23, r22
    _XCALL __umulhisi3
    push r23
    push r22                    ; C0
    _MOVW r29, r28, r19, r18
    _MOVW r19, r18, r21, r20
    _MOVW r21, r20, r25, r24
    push r27
    push r26                    ; A0
    push r19
    push r18                    ; B2
    ;;
    ;;  18  20  22  24  26  28  30  |  B2, B3, A0, A1, C0, C1, Y
    ;;  B2  C2  --  --  --  B0  A2
    ;; 1 * 1
    _MOVW r27, r26, r31, r30    ; A2
    _XCALL __umulhisi3
    ;; Sign-extend A.  T holds the sign of A
    brtc 0f
    ;; Subtract B from the high part of the result
    sub     r22, r28
    sbc     r23, r29
    sbc     r24, r18
    sbc     r25, r19
0:  _MOVW    r19, r18, r29, r28            ;; B0
    _MOVW    r29, r28, r23, r22
    _MOVW    r31, r30, r25, r24
    ;;
    ;;  18  20  22  24  26  28  30  |  B2, B3, A0, A1, C0, C1, Y
    ;;  B0  C2  --  --  A2  C4  C6
    ;;
    ;; 1 * 0
    _XCALL __muldi3_6
    ;; 0 * 1
    pop r26
    pop r27                     ;; B2
    pop r18
    pop r19                     ;; A0
    _XCALL __muldi3_6

    ;; Move result C into place and save A0 in Z
    _MOVW r23, r22, r29, r28
    _MOVW r25, r24, r31, r30
    _MOVW r31, r30, r19, r18               ; A0
    pop r18
    pop r19

    ;; Epilogue
    pop r28
    pop r29                     ;; Y
    ret
.endfunc

;; Signed widening 64 = 32 * 32 Multiplication
;;
;; R18[8] = R22[4] * R18[4]
;; Ordinary ABI Function
.func __mulsidi3
__mulsidi3:
    bst r25, 7
    sbrs r21, 7                 ; Enhanced core has no skip bug
    _XJMP __umulsidi3_helper

    ;; B needs sign-extension
    push r25
    push r24
    _XCALL __umulsidi3_helper
    ;; A0 survived in Z
    sub r22, r30
    sbc r23, r31
    pop r26
    pop r27
    sbc r24, r26
    sbc r25, r27
    ret
.endfunc

#endif /* HAVE_MUL */

/**********************************************************
    Widening Multiplication 64 = 32 x 32  without  MUL
**********************************************************/
#ifndef __AVR_TINY__ /* if not __AVR_TINY__ */
#if !defined (__AVR_HAVE_MUL__)
#define A0 18
#define A1 A0+1
#define A2 A0+2
#define A3 A0+3
#define A4 A0+4
#define A5 A0+5
#define A6 A0+6
#define A7 A0+7

#define B0 10
#define B1 B0+1
#define B2 B0+2
#define B3 B0+3
#define B4 B0+4
#define B5 B0+5
#define B6 B0+6
#define B7 B0+7

#define AA0 22
#define AA1 AA0+1
#define AA2 AA0+2
#define AA3 AA0+3

#define BB0 18
#define BB1 BB0+1
#define BB2 BB0+2
#define BB3 BB0+3

#define Mask r30

;; Signed / Unsigned widening 64 = 32 * 32 Multiplication without MUL
;;
;; R18[8] = R22[4] * R18[4]
;; Ordinary ABI Function
.func __mulsidi3
__mulsidi3:
    set
    cpse 16, 16
    ;; FALLTHRU
.endfunc

.func __umulsidi3
__umulsidi3:
    clt                         ; skipped
    ;; Save 10 Registers: R10..R17, R28, R29
    do_prologue_saves 10
    ldi r30, 0xff
    bld r30, 7
    ;; Move B into place...
    _MOVW r11, r10, r19, r18
    _MOVW    r13, r12, r21, r20
    ;; ...and extend it
    and r21, r30
    lsl r21
    sbc r14, r14
    mov r15, r14
    _MOVW r17, r16, r15, r14
    ;; Move A into place...
    _MOVW r19, r18, r23, r22
    _MOVW r21, r20, r25, r24
    ;; ...and extend it
    and r25, r30
    lsl r25
    sbc r22, r22
    mov r23, r22
    _MOVW r25, r24, r23, r22
    _XCALL __muldi3
    do_epilogue_restores 10
.endfunc

#endif /* !HAVE_MUL */
#endif /* if not __AVR_TINY__ */

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

/*******************************************************
       Division 8 / 8 => (result + remainder)
*******************************************************/

;(uint8_t, uint8_t) udiv(uint8_t divider, uint8_t divisor)
.func udivmodqi4                ; r24 = uint8_t divider, r22 = uint8_t divisor
udivmodqi4:                     ; r25 = uint8_t remainder, r24 = uint8_t quotient
    sub r25, r25                ; clear remainder and carry
    ldi r23, 9                  ; init loop counter
    rjmp udivmodqi4_ep          ; jump to entry point
udivmodqi4_loop:
    rol r25                     ; shift dividend into remainder
    cp r25, r22                 ; compare remainder & divisor
    brcs udivmodqi4_ep          ; remainder <= divisor
    sub r25, r22                ; restore remainder
udivmodqi4_ep:
    rol r24                     ; shift dividend (with CARRY)
    dec r23                     ; decrement loop counter
    brne udivmodqi4_loop
    com r24                     ; complement result
                                ; because C flag was complemented in loop
    ret
.endfunc

/*******************************************************
       Division 16 / 16 => (result + remainder)
*******************************************************/

;(uint16_t, uint16_t) udiv16(uint16_t divider, uint16_t divisor)
.func udiv_16_16_16                ; r25:r24 = uint16_t divider, r23:r22 = uint16_t divisor
udiv_16_16_16:                     ; r25:r24 = remainder,
    sub r26, r26
    sub r27, r27                ; clear remainder and carry
    ldi r21, 17                 ; init loop counter
    rjmp udiv_16_16_16_ep          ; jump to entry point
udiv_16_16_16_loop:
    rol r26                     ; shift dividend into remainder
    rol r27
    cp r26, r22                 ; compare remainder & divisor
    cpc r27, r23
    brcs udiv_16_16_16_ep          ; remainder < divisor
    sub r26, r22                ; restore remainder
    sbc r27, r23
udiv_16_16_16_ep:
    rol r24                     ; shift dividend (with CARRY)
    rol r25
    dec r21                     ; decrement loop counter
    brne udiv_16_16_16_loop
    com r24
    com r25
; div/mod results to return registers, as for the div() function
    _MOVW r23, r22, r25, r24    ; quotient
    _MOVW r25, r24, r27, r26    ;remainder

    ret
.endfunc