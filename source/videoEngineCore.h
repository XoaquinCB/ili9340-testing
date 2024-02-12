#pragma once

#include <stdint.h>
#include <stdbool.h>

typedef void (*VsyncCallBackFunc)();

void FadeIn(uint8_t speed, bool blocking);
void FadeOut(uint8_t speed, bool blocking);

void DrawMap(uint8_t x, uint8_t y, const VRAM_PTR_TYPE *map);
void Print(uint16_t x, uint16_t y, const uint8_t *string);
void PrintRam(uint16_t x, uint16_t y, const uint8_t *string);
void PrintBinaryByte(uint8_t x, uint8_t y, uint8_t byte);
void PrintHexByte(uint8_t x, uint8_t y, uint8_t value);
void PrintHexInt(uint8_t x, uint8_t y, uint16_t value);
void PrintHexLong(char x,char y, uint32_t value);
void PrintLong(uint8_t x,uint8_t y, uint32_t value);
void PrintByte(uint8_t x, uint8_t y, uint8_t value, bool zeropad);
void PrintChar(uint8_t x, uint8_t y, char c);
void PrintInt(uint8_t x, uint8_t y, uint16_t value, bool zeropad);

void Fill(int x,int y,int width,int height,int tile);
void FontFill(int x,int y,int width,int height,int tile);

void WaitVsync(uint16_t count);
void ClearVsyncFlag();
uint8_t GetVsyncFlag();
void ClearVsyncCounter();
uint16_t GetVsyncCounter();
void SetVsyncCounter(uint16_t count);

void SetUserPreVsyncCallback(VsyncCallBackFunc callback);
void SetUserPostVsyncCallback(VSyncCallBackFunc callback);

void SetLedOn();
void SetLedOff();
void ToggleLed();