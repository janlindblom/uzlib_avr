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

#define A32_BASE 65521
#define A32_NMAX 5552

.global uzlib_adler32
; uint32_t uzlib_adler32(const void *data, uint16_t length, uint32_t prev_sum)
.func uzlib_adler32
uzlib_adler32:
; r25:r24 = const void *data
; r23:r22 = uint16_t length
; r21:r18 = uint32_t prev_sum
    push r12
    push r13
    push r14                    ; Push registers we'll be using
    push r15
    push r16
    push r17
    push YL
    push YH

    _MOVW XH, XL, r25, r24      ; X <- pointer to data
    _MOVW r13, r12, r23, r22    ; r13:r12 <- length
    _MOVW r15, r14, r19, r18    ; r15:r14 <- s1 = prev_sum & 0xffff
    _MOVW r19, r18, r21, r20    ; r19:r18 <- s2 = prev_sum >> 16
loop_while:
    _MOVW ZH, ZL, r13, r12      ; Z <- length
    or ZL, ZH
    brne loop_for               ; Jump to loop code

    _MOVW r21, r20, r19, r18    ; r21;r20 <- s2
    clr r19                     ; r21:r18 <- s2 << 16
    clr r18

    _MOVW r25, r24, r15, r14    ; r25:r24 <- s1
    clr XH                      ; XH:XL <- 0x00
    clr XL                      ; XH:r24 <- uint32_t s1
    _MOVW r15, r14, r19, r18
    _MOVW r17, r16, r21, r20    ; r17:r14 <- s2 << 16
    or r14, r24                 ; r17:r14 <- ((uint32_t)s2 << 16) | s1
    or r15, r25
    or r16, XL
    or r17, XH
    _MOVW r25, r24, r17, r16
    _MOVW r23, r22, r15, r14    ; r25:r22 <- result

    pop YH                      ; Restore registers and return
    pop YL
    pop r17
    pop r16
    pop r15
    pop r14
    ret

loop_for:
    _MOVW r23, r22, r13, r12    ; <- r23:r22 = length
    ; See if length < A32_NMAX (5552 = 0x15B0)
    cpi r22, -79                ; -79=0xb0
    ldi r16, 21                 ; 21=0x15
    cpc r23, r16
    brlo .L3
    ldi r22, lo8(-80)
    ldi r23, lo8(21)
.L3:
    _MOVW r21, r20, r23, r22
    ldi ZL, 4
1:
    asr r21
    ror r20
    dec ZL
    brne 1b
    _MOVW r17, r16, r21, r20

    movw ZL, XL
.L4:
    cp r16, r1
    cpc r17, r1
    brne .L5
    ldi r25, 4
1:
    lsl r20
    rol r21
    dec r25
    brne 1b
    add r20, XL
    adc r21, XH

    movw XL, r22
    andi XL, 15
    clr XH
    add XL, r20
    adc XH, r21
.L6:
    cp r20, XL
    cpc r21, XH
    breq .+2
    rjmp .L7

    ldi r20, lo8(1)
    ldi r21, 0
    ldi ZH, -15
    cp r14, ZH
    ldi ZH, -1
    cpc r15, ZH
    brsh .L8
    ldi r21, 0
    ldi r20, 0
.L8:
    ldi r16, lo8(-15)
    mulsu r16,r20
    movw r24, r0
    mul r16, r21
    add r25, r0
    clr r1
    sub r14, r24
    sbc r15, r25

    ldi r20,lo8(1)
    ldi r21,0
    cpi r18,-15
    ldi r17,-1
    cpc r19,r17
    brsh .L9
    ldi r21,0
    ldi r20,0
.L9:
    ldi r16,lo8(-15)
    mulsu r16,r20
    movw r24,r0
    mul r16,r21
    add r25,r0
    clr r1
    sub r18,r24
    sbc r19,r25

    ldd r24,Y+1
    ldd r25,Y+2
    sub r24,r22
    sbc r25,r23
    std Y+2,r25
    std Y+1,r24
    rjmp loop_while
.L5:
    ld r24,Z

    add r24,r14
    mov r25,r15
    adc r25,r1

    ldd r14,Z+1

    add r14,r24
    mov r15,r25
    adc r15,r1

    add r24,r14
    adc r25,r15
    add r18,r24
    adc r19,r25

    ldd r24,Z+2

    add r24,r14
    mov r25,r15
    adc r25,r1

    add r18,r24
    adc r19,r25

    ldd r14,Z+3

    add r14,r24
    mov r15,r25
    adc r15,r1

    add r18,r14
    adc r19,r15

    ldd r24,Z+4

    add r24,r14
    mov r25,r15
    adc r25,r1

    add r18,r24
    adc r19,r25

    ldd r14,Z+5

    add r14,r24
    mov r15,r25
    adc r15,r1

    add r18,r14
    adc r19,r15

    ldd r24,Z+6

    add r24,r14
    mov r25,r15
    adc r25,r1

    add r18,r24
    adc r19,r25

    ldd r14,Z+7

    add r14,r24
    mov r15,r25
    adc r15,r1

    add r18,r14
    adc r19,r15
.LM40:
    ldd r24,Z+8
.LM41:
    add r24,r14
    mov r25,r15
    adc r25,r1
.LM42:
    add r18,r24
    adc r19,r25
.LM43:
    ldd r14,Z+9
.LM44:
    add r14,r24
    mov r15,r25
    adc r15,r1
.LM45:
    add r18,r14
    adc r19,r15
.LM46:
    ldd r24,Z+10
.LM47:
    add r24,r14
    mov r25,r15
    adc r25,r1
.LM48:
    add r18,r24
    adc r19,r25
.LM49:
    ldd r14,Z+11
.LM50:
    add r14,r24
    mov r15,r25
    adc r15,r1
.LM51:
    add r18,r14
    adc r19,r15
.LM52:
    ldd r24,Z+12
.LM53:
    add r24,r14
    mov r25,r15
    adc r25,r1
.LM54:
    add r18,r24
    adc r19,r25
.LM55:
    ldd r14,Z+13
.LM56:
    add r14,r24
    mov r15,r25
    adc r15,r1
.LM57:
    add r18,r14
    adc r19,r15
.LM58:
    ldd r24,Z+14
.LM59:
    add r24,r14
    mov r25,r15
    adc r25,r1
.LM60:
    add r18,r24
    adc r19,r25
.LM61:
    ldd r14,Z+15
.LM62:
    add r14,r24
    mov r15,r25
    adc r15,r1
.LM63:
    add r18,r14
    adc r19,r15
.LM64:
    subi r16,1
    sbc r17,r1
.LM65:
    adiw ZL,16
    rjmp .L4
.L7:
.LM66:
    movw ZL,r20
    ld r24,Z+
    movw r20,ZL
.LM67:
    add r14,r24
    adc r15,r1
.LM68:
    add r18,r14
    adc r19,r15
    rjmp .L6
.endfunc