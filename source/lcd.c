#include "lcd.h"

#include <stdint.h>
#include <avr/io.h>

#define LCD_DATA_PORT PORTC
#define LCD_CONTROL_PORT PORTA

#define LCD_CONTROL_CS_MASK (1 << 0)
#define LCD_CONTROL_BLC_MASK (1 << 1)
#define LCD_CONTROL_RESET_MASK (1 << 2)
#define LCD_CONTROL_WR_MASK (1 << 3)
#define LCD_CONTROL_RS_MASK (1 << 4)
#define LCD_CONTROL_RD_MASK (1 << 5)
#define LCD_CONTROL_VSYNC_MASK (1 << 6)
#define LCD_CONTROL_FMARK_MASK (1 << 7)

void lcd_Initialize() {

}

void lcd_SendVsync() {

}

void lcd_StartMemoryWrite(uint16_t startX, uint16_t startY, uint16_t endX, uint16_t endY) {

}

void lcd_Write(uint8_t data) {
    LCD_DATA_PORT = data;
    LCD_CONTROL_PORT &= ~LCD_CONTROL_WR_MASK;
    LCD_CONTROL_PORT |= LCD_CONTROL_WR_MASK;
}