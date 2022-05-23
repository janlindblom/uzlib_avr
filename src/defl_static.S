/*

Routines in this file are based on:
Zlib (RFC1950 / RFC1951) compression for PuTTY.

PuTTY is copyright 1997-2014 Simon Tatham.

AVR ASM Implementation is Copyright (c) 2022 Jan Lindblom.

Portions copyright Robert de Bath, Joris van Rantwijk, Delian
Delchev, Andreas Schultz, Jeroen Massar, Wez Furlong, Nicolas Barry,
Justin Bradford, Ben Harris, Malcolm Smith, Ahmad Khalifa, Markus
Kuhn, Colin Watson, and CORE SDI S.A.

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation files
(the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software,
and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT.  IN NO EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#include "library.inc"
#include "defl_static.h"

.section .text

;; ----------------------------------------------------------------------
; Zlib compression. We always use the static Huffman tree option.
; Mostly this is because it's hard to scan a block in advance to
; work out better trees; dynamic trees are great when you're
; compressing a large file under no significant time constraint,
; but when you're compressing little bits in real time, things get
; hairier.

; I suppose it's possible that I could compute Huffman trees based
; on the frequencies in the _previous_ block, as a sort of
; heuristic, but I'm not confident that the gain would balance out
; having to transmit the trees.
;

; void outbits(struct uzlib_comp *out, uint32_t bits, int16_t nbits)
.global outbits
.func outbits
outbits:
    push YL                    ; Push Y to the stack
    push YH
; r25:r24 <- struct uzlib_comp *out
; r23:r20 <- uint32_t bits
; r19:r18 <- int16_t nbits
    mov YL, r24                 ; Y <- pointer to struct uzlib_comp *out
    mov YH, r25
    mov r24, r20                ; XH:r24 <- uint32_t bits
    mov r25, r21
    mov XL, r22
    mov XH, r23
    ldd r20, Y+10               ; r21:r20 <- out->noutbits
    ldd r21, Y+11
    add r18, r20                ; r19:r18 <- out->noutbits + nbits
    adc r19, r21
    cpi r18, 0x21               ; assert r19:r18 <= 32
    cpc r19, r1
    brlt while_noutbits
    rcall abort                 ; call remote abort function from stdlib.h
while_noutbits:
    std Y+11, r19               ; out->noutbits += nbits
    std Y+10, r18
    rjmp 2f                     ; bits << out->noutbits
1:
    lsl r24                     ; shift XH:r24
    rol r25
    rol XL
    rol XH
2:
    dec r20                     ; decrement counter (out->noutbits)
    brpl 1b                     ; loop while > 0
    ldd r20, Y+6                ; r23:r20 <- out->outbits
    ldd r21, Y+7
    ldd r22, Y+8
    ldd r23, Y+9
    or r24, r20                 ; XH:r24 <- out->outbits | bits << out->noutbits
    or r25, r21
    or XL, r22
    or XH, r23
    std Y+6, r24                ; out->outbits <- out->outbits | bits << out->noutbits
    std Y+7, r25
    std Y+8, XL
    std Y+9, XH
    cpi r18, 8                  ; while (out->noutbits >= 8)
    cpc r19, r1
    brge start_loop
    pop YH                     ; Restore Y
    pop YL
    ret                         ; Return
start_loop:
    ldd r22, Y+2                ; r23:r22 <- out->outlen
    ldd r23, Y+3
    ldd r24, Y+4                ; r25:r24 <- out->outsize
    ldd r25, Y+5
    cp r22, r24
    cpc r23, r25                ; if (out->outlen >= out->outsize)
    brlt no_realloc
    subi r22, -64               ; r23:r22 <- out->outlen + 64
    sbci r23, -1
    std Y+5, r23                ; out->outsize <- out->outlen + 64
    std Y+4, r22
    ld r24, Y                   ; r25:r24 <- out->outbuf
    ldd r25, Y+1                ; r23:r22 <- out->outsize
    rcall realloc               ; call remote realloc from stdlib.h
    std Y+1, r25                ; out->outbuf <- realloc(out->outbuf, out->outsize)
    st Y, r24
no_realloc:
    ldd r18, Y+6                ; r18 <- out->outbits
    ld ZL, Y                    ; Z <- out->outbuf
    ldd ZH, Y+1
    ldd r24, Y+2                ; r25:r24 <- out->outlen
    ldd r25, Y+3
    mov r21, r25                ; Do the ++ on out->outlen
    mov r20, r24
    subi r20, -1                ; out->outlen + 1
    sbci r21, -1
    std Y+3, r21                ; out->outlen++
    std Y+2, r20
    add ZL, r24                 ; Z <- out->outbuf[out->outlen]
    adc ZH, r25
    st Z, r18                   ; out->outbuf[out->outlen] = (char) (out->outbits & 0xFF)
    ldd r24, Y+6                ; XH:r24 <- out->outbits
    ldd r25, Y+7
    ldd XL, Y+8
    ldd XH, Y+9
    mov r24, r25                ; out->outbits >> 8
    mov r25, XL
    mov XL, XH
    clr XH
    std Y+6, r24                ; out->outbits <- out->outbits >> 8
    std Y+7, r25
    std Y+8, XL
    std Y+9, XH

    ldd r18, Y+10               ; r19:r18 <- out->noutbits
    ldd r19, Y+11
    subi r18, 0x08              ; out->noutbits - 8
    sbc r19, r1
    rjmp while_noutbits
.endfunc

; void zlib_literal(struct uzlib_comp *out, char c)
.global zlib_literal
.func zlib_literal
zlib_literal:
    mov ZL, r22                 ; Z <- r22 <- char c
    mov XH, r25                ; r25:r24 <- struct uzlib_comp *out
    mov XL, r24
    adiw XL, 12
    ld r18, X+                  ; r19:r18 <- out->comp_disabled
    ld r19, X
    mov r20, r22                ; r20 <- char c
    or r18, r19                 ; OR bytes of out->comp_disabled
    brne set_nbits_8            ; We're in an uncompressed block, so just output the byte.
    cpi r22, lo8(-112)          ; is c <= 143 (255-143=112)?
    brsh blocks_9_bits
    subi ZL, lo8(-(0x30))       ; Z <- c + 0x030
    clr ZH                      ; 144 through 255 are 9 bits long starting at 110010000.
    subi ZL, lo8(-(mirrorbytes)); Z <- address of mirrorbytes[0x30 + c]
    sbci ZH, hi8(-(mirrorbytes))
    ld r20, Z                   ; r20 <- mirrorbytes[0x30 + c]
set_nbits_8:
    ldi r18, 0x08
    clr r19
    clr r21
    clr r22
    clr r23
call_outbits:
    rjmp outbits
blocks_9_bits:                  ; 0 through 143 are 8 bits long starting at 00110000.
    clr ZH
    subi ZL, lo8(-(mirrorbytes));Z <- address of mirrorbytes[c]
    sbci ZH, hi8(-(mirrorbytes))
    ld r20, Z                   ; r21:r20 <- mirrorbytes[c]
    clr r21
    lsl r20                     ; r21:r20 <- 2 * mirrorbytes[c]
    rol r21
    subi r20, -1                ; r21:r22 <- 1 + 2 * mirrorbytes[c]
    sbci r21, -1
    mov r0, r21
    lsl r0
    sbc r22, r22
    sbc r23, r23
    ldi r18, 0x09
    clr r19
    rjmp call_outbits
.endfunc

; void zlib_match(struct uzlib_comp *out, int16_t distance, int16_t len)
.global zlib_match
.func zlib_match
zlib_match:
    push r6
    push r7
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    push r16
    push r17
    push YL
    push YH

    mov r16, r20                ; r17:r16 <- int16_t len
    mov r17, r21
    mov r10, r22                ; r11:r10 <- int16_t distance
    mov r11, r23
    mov r12, r24                ; r13:r12 <- struct uzlib_comp *out
    mov r13, r25

    mov ZH, r25
    mov ZL, r24
    ldd r24, Z+12               ; r25:r24 <- out->comp_disabled
    ldd r25, Z+13
    or r24, r25                 ; OR bytes in out->comp_disabled
    brne call_abort
    rjmp exit_function
call_abort:
    rcall abort                 ; out->comp_disabled is set
main_loop:
; We can transmit matches of lengths 3 through 258
; inclusive. So if len exceeds 258, we must transmit in
; several steps, with 258 or less in each step.

; Specifically: if len >= 261, we can transmit 258 and be
; sure of having at least 3 left for the next step. And if
; len <= 258, we can just transmit len. But if len == 259
; or 260, we must transmit len-3.
    cpi r16, 5                  ; Check if len > 260
    ldi ZH, 1
    cpc r17, ZH
    brlt 1f                     ; No, it's not
    ldi YL, 0x02                ; Yes, len > 260
    ldi YH, 0x01                ; Y <- thislen = 258
    rjmp endif_len_size
1:  mov YH, r17                 ; Y <- len
    mov YL, r16
    cpi r16, 3                  ; Check if len <= 258
    ldi r24, 1
    cpc r17, r24
    brlt endif_len_size         ; Yes, len <= 258
    sbiw YL, 3                  ; Y <- thislen = len - 3
endif_len_size:
    sub r16, YL                 ; r17:r16 <- len -= thislen
    sbc r17, YH
; Binary-search to find which length code we're transmitting.
    ldi r20, 0x1d               ; r7:r6 <- j = sizeof(lencodes) / sizeof(*lencodes)
    mov r6, r20
    mov r7, r1
    ldi XL, lo8(-1)             ; X <- i = -1
    ldi XH, lo8(-1)
while_forever:
    mov r25, r7                 ; r25:r24 <- j
    mov r24, r6
    sub r24, XL                 ; Subtract i from j
    sbc r25, XH
    sbiw r24, 2                 ; Subtract 2 from (i - j)
    brlt call_abort             ; Check that j - i >= 2, abort if not
    mov r15, XH                 ; r15:r14 <- j
    mov r14, XL
    add r14, r6
    adc r15, r7                 ; r15:r14 <- j + i
    sbrs r15, 7                 ; sign check
    rjmp 2f
    ldi r24, -1
    sub r14, r24
    sbc r15, r24
2:
    asr r15                     ; r15:r14 <- k = (j + i) / 2
    ror r14
    mov r25, r15                ; r25:r24 <- k
    mov r24, r14
    ldi r22, 0x03               ; r23:r22 <- 0x03
    ldi r23, 0
    rcall __mulhi3              ; call 16-bit multiplication from stdlib
    mov r18, r24                ; r19:r18 <- result of k * 3 (for later)
    mov r19, r25
    subi r24, lo8(-(lencodes))  ; r25:r24 <- l = &lencodes[k]
    sbci r25, hi8(-(lencodes))
    mov ZH, r25                 ; Z <- lencodes[k]
    mov ZL, r24
    ldd r20, Z+1                ; r20 <- lencodes[k].min
    mov r8, r20                 ; r9:r8 <- &lencodes[k].min
    mov r9, r1
    mov r21, r9                 ; r21:r20 <- lencodes[k].min
    subi r20, -2                ; r20 <- r20 + 2
    sbci r21, -1                ; r21 <- r21 + 1
    cp r20, YL                  ; Check if thislen < (lencodes[k].min + 3)
    cpc r21, YH
    brlt 3f                     ; No, thislen >= (lencodes[k].min + 3)
    mov r7, r15                 ; Yes, thislen < (lencodes[k].min + 3)
    mov r6, r14                 ; r7:r6 <- j = k
    rjmp while_forever
3:  ldd r24, Z+2                ; r25:r24 <- lencodes[k].max
    ldi r25, 0
    adiw r24, 3                 ; r25:r24 <- lencodes[k].max + 3
    cp r24, YL                  ; Check if thislen > (lencodes[k].max + 3)
    cpc r25, YH
    brge 4f                     ; No, thislen <= (lencodes[k].max + 3)
    mov XH, r15                 ; Yes thislen > (lencodes[k].max + 3)
    mov XL, r14                 ; X <- i = k
    rjmp while_forever
4:  mov r25, r19                ; r25:r24 <- k * 3 from before
    mov r24, r18
    ldi r22, lo8(-85)
    ldi r23, lo8(-86)
    rcall __mulhi3              ; call 16-bit multiplication from stdlib
    mov r20, r24                ; r21:r20 <- lcode = l - lencodes + 257
    mov r21, r25
; Transmit the length code. 256-279 are seven bits
; starting at 0000000; 280-287 are eight bits starting at
; 11000000.
    cpi r18, 67                 ; Check if lcode <= 279
    cpc r19, r1
    brlt 5f                     ; Yes, lcode <= 279
    ldi r18, 0x08               ; No, lcode > 279
    clr r19
    subi r20, lo8(-(mirrorbytes+169))
    sbci r21, hi8(-(mirrorbytes+169))
    mov ZH, r21                 ; mirrorbytes[0xc0 - 280 + lcode]
    mov ZL, r20
    ld r20, Z
    clr r21
    clr r22
    clr r23
    rjmp transmit_lcode
5:  ldi r18, 0x07               ; lcode <= 279
    clr r19
    lsl r20
    rol r21
    mov ZH, r21
    mov ZL, r20                 ; mirrorbytes[(lcode - 256) * 2]
    subi ZL, lo8(-(mirrorbytes+2))
    sbci ZH, hi8(-(mirrorbytes+2))
    ld r20, Z
    clr r21
    clr r22
    clr r23
transmit_lcode:
    mov r24, r12
    mov r25, r13
    rcall outbits
; Transmit the extra bits.
    ldi r22, 0x03               ; r23:r22 <- 0x03
    clr r23
    mov r24, r14                ; r25:r24 <- k
    mov r25, r15
    rcall __mulhi3              ; call 16-bit multiplication from stdlib
    mov ZH, r25
    mov ZL, r24
    subi ZL, lo8(-(lencodes))
    sbci ZH, hi8(-(lencodes))
    ld r18, Z
    tst r18                     ; Check if l->extrabits
    breq 6f                     ; l->extrabits is not true
    clr r19                     ; l->extrabits is true
    ldi ZH, 0x03
    add r8, ZH                  ; r9:r8 <- lencodes[k].min + 3
    adc r9, r1
    mov r20, YL                 ; r21:r20 <- thislen
    mov r21, YH
    sub r20, r8                 ; r21:r20 <- thislen - (lencodes[k].min + 3)
    sbc r21, r9
    mov r0, r21
    lsl r0
    sbc r22, r22
    sbc r23, r23
    mov r24, r12
    mov r25, r13
    rcall outbits
6:                              ; l->extrabits is not true
    ldi r18, 0x1e               ; r19:r18 <- j = sizeof(distcodes) / sizeof(*distcodes)
    clr r19
    ldi XL, lo8(-1)             ; X <- i = -1
    ldi XH, lo8(-1)
find_distcode_extrabits:
    mov r24, r18                ; r25:r24 <- j = sizeof(distcodes) / sizeof(*distcodes)
    mov r25, r19
    sub r24, XL                 ; r25:r24 += 1
    sbc r25, XH
    sbiw r24, 2                 ; r25:r24 -= 2
    brge 7f                     ; Check if j - i >= 2
    rjmp call_abort             ; Call abort if not
7:  mov YH, XH                  ; Y <- i
    mov YL, XL
    add YL, r18                 ; Y += j
    adc YH, r19
    sbrc YH, 7
    adiw YL, 1
    asr YH                      ; Y <- k = (j + i) / 2
    ror YL
    ldi r22, 0x06               ; Check if distance < distcodes[k].min
    clr r23
    mov r24, YL
    mov r25, YH
    rcall __mulhi3              ; call 16-bit multiplication from stdlib
    mov ZH, r25
    mov ZL, r24
    subi ZL, lo8(-(distcodes))
    sbci ZH, hi8(-(distcodes))
    ldd r14, Z+2                ; d = &distcodes[k];
    ldd r15, Z+3
    cp r10, r14
    cpc r11, r15
    brsh 8f                     ; Match found?
    mov r19, YH
    mov r18, YL
    rjmp find_distcode_extrabits
8:
    ldd r24, Z+4
    ldd r25, Z+5
    cp r24, r10
    cpc r25, r11
    brsh 9f                     ; Match found!
    mov XH, YH
    mov XL, YL
    rjmp find_distcode_extrabits
; Transmit the distance code. Five bits starting at 00000.
9:  ld ZL, Z
    clr ZH
    ldi r24, 0x03               ; r24 <- initialise counter
10:
    lsl ZL                      ; Z <- d->code * 8
    rol ZH
    dec r24                     ; decrement counter
    brne 10b
    subi ZL, lo8(-(mirrorbytes));mirrorbytes[d->code * 8]
    sbci ZH, hi8(-(mirrorbytes))
    ldi r18, 0x05               ; r19:r18 <- 0x05
    clr r19
    ld r20, Z                   ; r23:r20 <- mirrorbytes[d->code * 8]
    clr r21
    clr r22
    clr r23
    mov r24, r12                ; r25:r24 <- out
    mov r25, r13
    rcall outbits
    ldi r22, 0x06               ; Check if d->extrabits
    clr r23
    mov r24, YL
    mov r25, YH
    rcall __mulhi3              ; call 16-bit multiplication from stdlib
    mov ZH, r25
    mov ZL, r24
    subi ZL, lo8(-(distcodes))
    sbci ZH, hi8(-(distcodes))
    ldd r18, Z+1                ; r19:r18 <- d->extrabits
    tst r18
    breq exit_function
    clr r19
    mov r21, r11
    mov r20, r10
    sub r20, r14                ; distance - d->min
    sbc r21, r15
    clr r22
    clr r23
    mov r24, r12                ; r25:r24 <- out
    mov r25, r13
    rcall outbits
exit_function:
    cp r1, r16
    cpc r1, r17
    brge 11f
    rjmp main_loop
11: pop YH
    pop YL
    pop r17
    pop r16
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop r7
    pop r6
    ret
.endfunc

; void zlib_start_block(struct uzlib_comp *out)
.global zlib_start_block
.func zlib_start_block
zlib_start_block:
    ; r25:r24 <- struct uzlib_comp *out
    push YL                     ; Stash away Y
    push YH
    mov YH, r24                 ; Y <- struct uzlib_comp *out
    mov YL, r25
    ldi r18, 0x01               ; r19:r18 <- 0x01
    clr r19
    ldi r20, 0x01               ; r23:r20 <- 0x01
    clr r21
    clr r22
    clr r23
    rcall outbits
    ldi r18, 0x02               ; r19:r18 <- 0x02
    clr r19
    ldi r20, 0x01               ; r23:r20 <- 0x01
    clr r21
    clr r22
    clr r23
    mov r24, YH
    mov r25, YL
    pop YH
    pop YL
    rjmp outbits
.endfunc

; void zlib_finish_block(struct uzlib_comp *out)
.global zlib_finish_block
.func zlib_finish_block
zlib_finish_block:
    push YL                     ; Stash away Y
    push YH
    mov YH, r24                 ; Y <- struct uzlib_comp *out
    mov YL, r25
    ldi r18, 0x07               ; r19:r18 <- 0x07
    clr r19
    clr r20                     ; r23:r20 <- 0x00
    clr r21
    clr r22
    clr r23
    ; r25:r24 <- struct uzlib_comp *out
    rcall outbits               ; call outbits
    ldi r18, 0x07               ; r19:r18 <- 0x07
    clr r19
    clr r20                     ; r23:r20 <- 0x00
    clr r21
    clr r22
    clr r23
    mov r24, YH                 ; r25:r24 <- struct uzlib_comp *out
    mov r25, YL
    pop YH                      ; Restore Y
    pop YL
    rjmp outbits                ; Jump to outbits
.endfunc

.section .data
distcodes:
    .byte   0
    .byte   0
    .word   1
    .word   1
    .byte   1
    .byte   0
    .word   2
    .word   2
    .byte   2
    .byte   0
    .word   3
    .word   3
    .byte   3
    .byte   0
    .word   4
    .word   4
    .byte   4
    .byte   1
    .word   5
    .word   6
    .byte   5
    .byte   1
    .word   7
    .word   8
    .byte   6
    .byte   2
    .word   9
    .word   12
    .byte   7
    .byte   2
    .word   13
    .word   16
    .byte   8
    .byte   3
    .word   17
    .word   24
    .byte   9
    .byte   3
    .word   25
    .word   32
    .byte   10
    .byte   4
    .word   33
    .word   48
    .byte   11
    .byte   4
    .word   49
    .word   64
    .byte   12
    .byte   5
    .word   65
    .word   96
    .byte   13
    .byte   5
    .word   97
    .word   128
    .byte   14
    .byte   6
    .word   129
    .word   192
    .byte   15
    .byte   6
    .word   193
    .word   256
    .byte   16
    .byte   7
    .word   257
    .word   384
    .byte   17
    .byte   7
    .word   385
    .word   512
    .byte   18
    .byte   8
    .word   513
    .word   768
    .byte   19
    .byte   8
    .word   769
    .word   1024
    .byte   20
    .byte   9
    .word   1025
    .word   1536
    .byte   21
    .byte   9
    .word   1537
    .word   2048
    .byte   22
    .byte   10
    .word   2049
    .word   3072
    .byte   23
    .byte   10
    .word   3073
    .word   4096
    .byte   24
    .byte   11
    .word   4097
    .word   6144
    .byte   25
    .byte   11
    .word   6145
    .word   8192
    .byte   26
    .byte   12
    .word   8193
    .word   12288
    .byte   27
    .byte   12
    .word   12289
    .word   16384
    .byte   28
    .byte   13
    .word   16385
    .word   24576
    .byte   29
    .byte   13
    .word   24577
    .word   32768
lencodes:
    .byte   0
    .byte   0
    .byte   0
    .byte   0
    .byte   1
    .byte   1
    .byte   0
    .byte   2
    .byte   2
    .byte   0
    .byte   3
    .byte   3
    .byte   0
    .byte   4
    .byte   4
    .byte   0
    .byte   5
    .byte   5
    .byte   0
    .byte   6
    .byte   6
    .byte   0
    .byte   7
    .byte   7
    .byte   1
    .byte   8
    .byte   9
    .byte   1
    .byte   10
    .byte   11
    .byte   1
    .byte   12
    .byte   13
    .byte   1
    .byte   14
    .byte   15
    .byte   2
    .byte   16
    .byte   19
    .byte   2
    .byte   20
    .byte   23
    .byte   2
    .byte   24
    .byte   27
    .byte   2
    .byte   28
    .byte   31
    .byte   3
    .byte   32
    .byte   39
    .byte   3
    .byte   40
    .byte   47
    .byte   3
    .byte   48
    .byte   55
    .byte   3
    .byte   56
    .byte   63
    .byte   4
    .byte   64
    .byte   79
    .byte   4
    .byte   80
    .byte   95
    .byte   4
    .byte   96
    .byte   111
    .byte   4
    .byte   112
    .byte   127
    .byte   5
    .byte   -128
    .byte   -97
    .byte   5
    .byte   -96
    .byte   -65
    .byte   5
    .byte   -64
    .byte   -33
    .byte   5
    .byte   -32
    .byte   -2
    .byte   0
    .byte   -1
    .byte   -1
mirrorbytes:
    .string ""
    .ascii  "\200@\300 \240`\340\020\220P\3200\260p\360\b\210H\310(\250h\350"
    .ascii  "\030\230X\3308\270x\370\004\204D\304$\244d\344\024\224T\3244"
    .ascii  "\264t\364\f\214L\314,\254l\354\034\234\\\334<\274|\374\002\202"
    .ascii  "B\302\"\242b\342\022\222R\3222\262r\362\n\212J\312*\252j\352"
    .ascii  "\032\232Z\332:\272z\372\006\206F\306&\246f\346\026\226V\3266"
    .ascii  "\266v\366\016\216N\316.\256n\356\036\236^\336>\276~\376\001\201"
    .ascii  "A\301!\241a\341\021\221Q\3211\261q\361\t\211I\311)\251i\351\031"
    .ascii  "\231Y\3319\271y\371\005\205E\305%\245e\345\025\225U\3255\265"
    .ascii  "u\365\r\215M\315-\255m\355\035\235]\335=\275}\375\003\203C\303"
    .ascii  "#\243c\343\023\223S\3233\263s\363\013\213K\313+\253k\353\033"
    .ascii  "\233[\333;\273{\373\007\207G\307'\247g\347\027\227W\3277\267"
    .ascii  "w\367\017\217O\317/\257o\357\037\237_\337?\277\177\377"