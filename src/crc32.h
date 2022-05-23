#ifndef __ASSEMBLER__
#    pragma once
#include <stdint.h>

uint32_t uzlib_crc32(const void *data, uint16_t length, uint32_t crc);
#endif /* ASSEMBLER */
