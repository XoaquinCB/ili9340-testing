#include "tileMap.h"
#include <stdint.h>
#include <avr/pgmspace.h>

const uint8_t tileMap[TILE_COUNT][TILE_SIZE] PROGMEM = {
    {
          0,   1,   2,   3,   4,   5,
          6,   7,   8,   9,  10,  11,
         12,  13,  14,  15,  16,  17,
         18,  19,  20,  21,  22,  23,
         24,  25,  26,  27,  28,  29,
         30,  31,  32,  33,  34,  35,
         36,  37,  38,  39,  40,  41,
         42,  43,  44,  45,  46,  47,
    },
    {
          0,   2,   4,   6,   8,  10,
         12,  14,  16,  18,  20,  22,
         24,  26,  28,  30,  32,  34,
         46,  48,  40,  42,  44,  46,
         48,  50,  52,  54,  56,  58,
         60,  62,  64,  66,  68,  70,
         72,  74,  76,  78,  80,  82,
         84,  86,  88,  90,  92,  94,
    },
    {
          0,   3,   6,   9,  12,  15,
         18,  21,  24,  27,  30,  33,
         36,  39,  42,  45,  48,  51,
         54,  57,  60,  63,  66,  69,
         72,  75,  78,  81,  84,  87,
         90,  93,  96,  99, 102, 105,
        108, 111, 114, 117, 120, 123,
        126, 129, 132, 135, 138, 141,
    },
    {
          0,   4,   8,  12,  16,  20,
         24,  28,  32,  36,  40,  44,
         48,  52,  56,  60,  64,  68,
         72,  76,  80,  84,  88,  92,
         96, 100, 104, 108, 112, 116,
        120, 124, 128, 132, 126, 140,
        144, 148, 152, 156, 160, 164,
        168, 172, 176, 180, 184, 188,
    },
};