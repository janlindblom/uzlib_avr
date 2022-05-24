/*
 * genlz77  -  Generic LZ77 compressor
 *
 * Copyright (c) 2014 by Paul Sokolovsky
 * Copyright (c) 2022 Jan Lindblom
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

#include "library.inc"
#include "genlz77.h"

; This is hash function from liblzf
; static inline int16_t HASH(struct uzlib_comp *data, const uint8_t *p)
.global HASH
.func HASH
HASH:
    push r21
    push r20
    push r19
    push r18
    _MOVW ZH, ZL, r25, r24      ; pointer to data
    _MOVW XH, XL, r23, r22      ; pointer to p
;; PART ONE: (p[0] << 16) | (p[1] << 8) | p[2]
; first component: p[0] << 16
    ld r24, X+                  ; load p[0] into r25:r24 and increment Z
    clr r25
    ldi r22, 0x10               ; initialise counter
    rjmp 2f                     ; p[0] << 16
1:  lsl r24
    rol r25
2:  dec r22
    brpl 1b                     ; Keep shifting if r22 > 0
    ; r25:r24 <- p[0] << 16
; second component: p[1] << 8
    ld r23, X+                  ; load p[1] into r23:r22 and increment Z
    clr r22                     ; p[1] << 8 (by swapping the two bytes)
; OR first two components
    or r24, r22                 ; r25:r24 <- (p[0] << 16) | (p[1] << 8)
    or r25, r23
; OR with the third component
    ld r22, X                   ; Load p[3] into r23:r22
    clr r23
    or r24, r22                 ; r25:r24 <- (p[0] << 16) | (p[1] << 8) | p[2]
    or r25, r23
    ; r25:r24 <- (p[0] << 16) | (p[1] << 8) | p[2]
;; PART TWO: Calculate 24 - HASH_BITS
    ldd r20, Z+16               ; Load HASH_BITS into r21:r20
    ldd r21, Z+17
    ldi r18, 0x18               ; Load 24 into r19:r18
    clr r19
    sub r18, r20                ; (24 - HASH_BITS)
    sbc r19, r21
    _MOVW r21, r20, r25, r24
    ; r21:r20 <- ((p[0] << 16) | (p[1] << 8) | p[2])
    ; r19:r18 <- (24 - HASH_BITS)
;; PART THREE: Calculate (PART ONE) >> (PART TWO)
    mov r0, r18                 ; r0 <- (24 - HASH_BITS)
    rjmp 2f                     ; ((p[0] << 16) | (p[1] << 8) | p[2]) >> (24 - HASH_BITS)
1:  asr r25                     ; r25:r24 has ((p[0] << 16) | (p[1] << 8) | p[2])
    ror r24
2:  dec r0
    brpl 1b                     ; Keep shifting if r0 > 0
    ; r25:r24 <- ((p[0] << 16) | (p[1] << 8) | p[2]) >> (24 - HASH_BITS)
;; PART FOUR: Calculate (PART THREE) - (PART ONE)
    sub r24, r20                ; (PART THREE) - (PART ONE)
    sbc r25, r21
    ; r25:r24 <- (((p[0] << 16) | (p[1] << 8) | p[2]) >> (24 - HASH_BITS)) - ((p[0] << 16) | (p[1] << 8) | p[2])
    _MOVW r19, r18, r25, r24
    ; r19:r18 <- (((p[0] << 16) | (p[1] << 8) | p[2]) >> (24 - HASH_BITS)) - ((p[0] << 16) | (p[1] << 8) | p[2])
;; PART FIVE: Calculate ((1<<HASH_BITS) - 1)
    ldd r20, Z+16               ; Load HASH_BITS into r25:r24
    ldd r21, Z+17
    ldi r24, 0x01               ; r21:r20 <- 1
    clr r25
    rjmp 2f                     ; Start shifting
1:  lsl r24
    rol r25
2:  dec r20                     ; decrement counter
    brpl 1b                     ; Keep shifting if r18 > 0
    ; r21:r20 <- (1<<HASH_BITS)
    sbiw r24, 1
    ; r21:r20 <- ((1<<HASH_BITS) - 1)
;; PART SIX: Calculate hash as (PART FOUR) & (PART FIVE)
    and r24, r18
    and r25, r19
;; Done, result is in r25:r24.
    pop r18
    pop r19
    pop r20
    pop r21
    ret
.endfunc
