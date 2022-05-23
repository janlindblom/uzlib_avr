;;
;; tinfzlib  -  tiny zlib uncompress
;;
;; Copyright (c) 2003 by Joergen Ibsen / Jibz
;; All Rights Reserved
;;
;; http://www.ibsensoftware.com/
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

.equ    TINF_OK, 0
.equ    TINF_DATA_ERROR, (-3)

.section .bss
sourceLen:      .ds.w 1

.section .text

.global tinf_zlib_uncompress
.func tinf_zlib_uncompress
;tinf_zlib_uncompress(void *dest, uint16_t *destLen, const void *source, uint16_t sourceLen)
tinf_zlib_uncompress:           ; r25:r24 = 16 bit dest address, r23:r22 = 16 bit destLen address, r21:r20 = uint16_t source, r19:r18 = uint16_t sourceLen
    _MOVW ZH, ZL, r25, r24       ; Z = dest
    _MOVW YH, YL, r23, r22       ; Y = destLen
    _MOVW XH, XL, r21, r20       ; X = source
    sts sourceLen, r19
    sts sourceLen+8, r18

    ; -- get header bytes --
    ld r17, X+                  ; first byte of header = flg
    ld r16, X                   ; second byte of header = cmf

    ; -- check format --
    ; check method is deflate
    ; if ((cmf & 0x0f) != 8) return TINF_DATA_ERROR;
    ldi r18, 0x0f
    and r18, r16
    cpi r18, 8
    brne return_error

    ; check window size is valid
    ; if ((cmf >> 4) > 7) return TINF_DATA_ERROR;
    lsr r16
    lsr r16
    lsr r16
    lsr r16
    cp r16, r18                 ; r18 = 8 from above
    brsh return_error

    ; check there is no preset dictionary
    ; if (flg & 0x20) return TINF_DATA_ERROR;
    cpi r17, 0x20
    brne return_error

    ; check checksum
    ; if ((256*cmf + flg) % 31) return TINF_DATA_ERROR;
    ldi r23, 0x01
    ldi r22, 0x00               ; r23:r22 = 256
    ldi r25, 0
    mov r24, r16                ; r25:r24 = cmf
    _XCALL umul_8_8_16          ; r25:r24 = 256*cmf
    adc r25, r1                 ; r25 += CARRY
    add r24, r17                ; r24 += flg
    ldi r23, 0x00
    ldi r22, 0x1f               ; r23:r22 = 31
    _XCALL udiv_16_16_16        ; r25:r24 / r23:r22
    and r24, r23                ; Check remainder in r24:r23
    brne return_error

    ; -- get adler32 checksum --
    ldi r25, 0
    ldi r24, 0
    lds r23, sourceLen
    lds r22, sourceLen+8
    mov r0, r25
    mov r25, r22
    mov r22, r0
    mov r0, r24
    mov r24, r23
    mov r23, r0

    ; -- inflate --

    ; res = tinf_uncompress(dst, destLen, src + 2, sourceLen - 6);

    _XCALL tinf_uncompress


    ret

return_error:
    ldi r25, hi8(-3)
    ldi r24, lo8(-3)
    ret
.endfunc
