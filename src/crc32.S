;;
;; AVR assembler crc32
;;
;; Copyright (c) 2022 by Jan Lindblom
;; All Rights Reserved
;;
;; This software is provided 'as-is', without any express
;; or implied warranty.  In no event will the authors be
;; held liable for any damages arising from the use of
;; this software.
;;
;; Permission is granted to anyone to use this software
;; for any purpose, including commercial applications,
;; and to alter it and redistribute it freely, subject to
;; the following restrictions:
;;
;; 1. The origin of this software must not be
;;    misrepresented; you must not claim that you
;;    wrote the original software. If you use this
;;    software in a product, an acknowledgment in
;;    the product documentation would be appreciated
;;    but is not required.
;;
;; 2. Altered source versions must be plainly marked
;;    as such, and must not be misrepresented as
;;    being the original software.
;;
;; 3. This notice may not be removed or altered from
;;    any source distribution.
;;

#include "library.inc"
#include "crc32.h"

.section .text

; uint32_t tinf_crc32(const void *data, uint16_t length, uint32_t crc)
.func tinf_crc32
.global tinf_crc32
tinf_crc32:                     ; r25:24 = 16 bit data pointer (address), r23:22 = uint16_t length, r21:18 = uint32_t crc
    _MOVW ZH, ZL, r25, r24      ; Z = pointer to data
    _MOVW XH, XL, r23, r22      ; X = length
    cpi XL, 0                   ; length == 0?
    breq    c_exit              ; exit early if length is 0
    mov r17, r18                ; Check if uint32_t crc is supplied or not
    add r17, r19
    add r17, r20
    add r17, r21
    tst r17                     ; is uint32_t crc == 0?
    brne    no_seed             ; if it is not, then don't load seed
    ldi r21, 0xff               ; Load seed into uint32_t r25:22
    ldi r20, 0xff
    ldi r19, 0xff
    ldi r18, 0xff
no_seed:
    mov r25, r21                ; move seed or initial value into uint32_t r25:22
    mov r24, r20
    mov r23, r19
    mov r22, r18
    ldi r18, 0x20               ; load magic number into uint32_t r21:18
    ldi r19, 0x83
    ldi r20, 0xb8
    ldi r21, 0xed
next_byte:
    ld r16, Z+                  ; get next byte, increment Z
    eor r22, r16                ; XOR data into CRC
    ldi r16, 0x08               ; bit counter
next_bit:
    lsr r25                     ; next LS bit to carry
    ror r24
    ror r23
    ror r22
    brcc no_xor
    eor r25, r21                ; If carry is set, XOR the magic number
    eor r24, r20
    eor r23, r19
    eor r22, r18
no_xor:
    dec r16                     ; count bit
    brne next_bit               ; branch if r16 != 0
    sbiw XL, 1                  ; count byte (decrement X)
    brne next_byte              ; branch if X != 0

    ret                         ; all done, uint32_t result in r25:r22
c_exit:
    clr r25                     ; Bail out, clear result in r25:r22
    clr r24
    clr r23
    clr r22
    ret                         ; return 0
.endfunc
