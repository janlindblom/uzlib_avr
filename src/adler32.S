/*
 * Adler-32 checksum
 *
 * Copyright (c) 2003 by Joergen Ibsen / Jibz
 * All Rights Reserved
 *
 * http://www.ibsensoftware.com/
 *
 * This software is provided 'as-is', without any express
 * or implied warranty.  In no event will the authors be
 * held liable for any damages arising from the use of
 * this software.
 *
 * Permission is granted to anyone to use this software
 * for any purpose, including commercial applications,
 * and to alter it and redistribute it freely, subject to
 * the following restrictions:
 *
 * 1. The origin of this software must not be
 *    misrepresented; you must not claim that you
 *    wrote the original software. If you use this
 *    software in a product, an acknowledgment in
 *    the product documentation would be appreciated
 *    but is not required.
 *
 * 2. Altered source versions must be plainly marked
 *    as such, and must not be misrepresented as
 *    being the original software.
 *
 * 3. This notice may not be removed or altered from
 *    any source distribution.
 */

/*
 * Adler-32 algorithm taken from the zlib source, which is
 * Copyright (C) 1995-1998 Jean-loup Gailly and Mark Adler
 */

#include "library.inc"

.section .text

.global uzlib_adler32
; uint32_t uzlib_adler32(const void *data, uint16_t length, uint32_t prev_sum)
.func uzlib_adler32
uzlib_adler32:
; r25:r24 = const void *data
; r23:r22 = uint16_t length
; r21:r18 = uint32_t prev_sum
    push r4                     ; Push away registers
    push r5
    push r6
    push r7
    push r8
    push r9
    push r11
    push r12
    push r13
    push r14
    push r15
    push r16
    push r17
    push YL
    push YH

    _MOVW r7, r6, r25, r24      ; r7:r6 <- pointer to data
    _MOVW XH, XL, r23, r22      ; X <- length
outer_block:
    _SBIW XL, 0
    breq exit_function          ; Branch if zero
    _MOVW r5, r4, XH, XL        ; r5:r4 <- length
    cpi XL, -79                 ; 255-79 = 176 = 0xb0
    ldi r16, 21                 ; 21 = 0x15
    cpc XH, r16                 ; Compare length against A32_NMAX=5552=0x15b0
    brlo 1f                     ; Branch if lower
    ldi r30, lo8(-80)
    mov r4, r30
    ldi r30, lo8(21)
    mov r5, r30                 ; r5:r4 <- A32_NMAX
1:  _MOVW r25, r24, r5, r4      ; r25:r24 <- k = length or A32_NMAX from above
; Prepare for (i = k / 16; i; --i, buf += 16)
    ldi r23, 4
2:  asr r25
    ror r24
    dec r23
    brne 2b
    _MOVW r15, r14, r7, r6
    ldi r17, 16
    add r14, r17
    adc r15, r1
    _MOVW r9, r8, r25, r24

    _MOVW r17, r16, r7, r6
loop_length:
    cp r8, r1                   ; Check if length == 0
    cpc r9, r1
    brne do_loop_length         ; Loop if not
    ldi r22, 4
3:  lsl r24
    rol r25
    dec r22
    brne 3b
    add r24, r6
    adc r25, r7

    _MOVW r31, r30, r5, r4
    andi r30, 15
    clr r31
    _MOVW r7, r6, r31, r30
    add r6, r24
    adc r7, r25
not_done_yet:
    cp r24, r6
    cpc r25, r7
    brne done_yet

    ldi r30, lo8(1)
    ldi r31, 0
    cpi r18, -15
    ldi r16, -1
    cpc r19, r16
    brsh 4f
    ldi r31, 0
    ldi r30, 0
4:  ldi r16, lo8(-15)
    _MOVW r23, r22, r31, r30
    mulsu r16, r22
    _MOVW r25, r24, r1, r0
    mul r16, r23
    add r25, r0
    clr r1
    sub r18, r24
    sbc r19, r25

    ldi r30, lo8(1)
    ldi r31, 0
    cpi r20, -15
    ldi r17, -1
    cpc r21, r17
    brsh 5f
    ldi r31, 0
    ldi r30, 0
5:  ldi r16, lo8(-15)
    _MOVW r23, r22, r31, r30
    mulsu r16, r22
    _MOVW r25, r24, r1, r0
    mul r16, r23
    add r25, r0
    clr r1
    sub r20, r24
    sbc r21, r25

    sub XL, r4
    sbc XH, r5
    rjmp outer_block
do_loop_length:
    _MOVW r13, r12, r17, r16
loop_additions:
    _MOVW r31, r30, r13, r12
    ld r11, Z+
    _MOVW r13, r12, r31, r30

    add r18, r11
    adc r19, r1

    add r20, r18
    adc r21, r19

    cp r14, r30
    cpc r15, r31
    brne loop_additions

    ldi r31, 1
    sub r8, r31
    sbc r9, r1

    subi r16, -16
    sbci r17, -1
    ldi r22, 16
    add r14, r22
    adc r15, r1
    rjmp loop_length
done_yet:
    _MOVW r31, r30, r25, r24
    ld r16, Z+
    _MOVW r25, r24, r31, r30

    add r18, r16
    adc r19, r1

    add r20, r18
    adc r21, r19
    rjmp not_done_yet

exit_function:
    _MOVW r23, r22, r19, r18    ; r25:r22 <- s1
    clr r25
    clr r24
    clr r19                     ; r21:r18 <- s2 << 16
    clr r18
    or r22, r18                 ; r25:r22 <- ((uint32_t)s2 << 16) | s1
    or r23, r19
    or r24, r20
    or r25, r21
    pop YH                      ; Restore registers
    pop YL
    pop r17
    pop r16
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r9
    pop r8
    pop r7
    pop r6
    pop r5
    pop r4
    ret                         ; return r25:r22 = ((uint32_t)s2 << 16) | s1
.endfunc
