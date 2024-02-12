#pragma once

#include <stdint.h>

void InitialiseVideoMode();
void ClearVram();
void SetTile(uint8_t x, uint8_t y, uint16_t tileId);
void SetFont(uint8_t x, uint8_t y, uint8_t tileId);
void SetFontTable(const uint8_t *data);
void SetTileTable(const uint8_t *data);
