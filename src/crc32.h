#ifdef __ASSEMBLER__

#    ifdef SPM_PAGESIZE // Recent devices have "movw".
.macro _MOVW dh, dl, sh, sl
    movw \dl, \sl
.endm
#    else // Earlier devices do not have "movw".
.macro _MOVW dh, dl, sh, sl
    mov \dl, \sl
    mov \dh, \sh
.endm
#    endif

#else /* !ASSEMBLER */
#    pragma once
#include <inttypes.h>

uint32_t tinf_crc32(const void *data, uint16_t length, uint32_t crc);
#endif /* ASSEMBLER */
