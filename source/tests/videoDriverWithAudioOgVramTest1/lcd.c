#include "lcd.h"
#include <stdint.h>
#include <stdlib.h>
#include <avr/io.h>
#include <util/delay.h>

// #define CONTROL_PORT PORTB
// #define DATA_PORT PORTD
// #define CONTROL_DDR DDRB
// #define DATA_DDR DDRD

#define CONTROL_PORT PORTA
#define DATA_PORT PORTC
#define CONTROL_DDR DDRA
#define DATA_DDR DDRC

#define CONTROL_PORT_CSX   0
#define CONTROL_PORT_BLC   1
#define CONTROL_PORT_RESX  2
#define CONTROL_PORT_WRX   3
#define CONTROL_PORT_D_CX  4
#define CONTROL_PORT_RDX   5
#define CONTROL_PORT_VSYNC 6
#define CONTROL_PORT_TE    7

#define COMMAND_NO_OPERATION								0x00
#define COMMAND_SOFTWARE_RESET								0x01
#define COMMAND_READ_DISPLAY_IDENTIFICATION_INFORMATION		0x04
#define COMMAND_READ_DISPLAY_STATUS							0x09
#define COMMAND_READ_DISPLAY_POWER_MODE						0x0A
#define COMMAND_READ_DISPLAY_MADCTL							0x0B
#define COMMAND_READ_DISPLAY_PIXEL_FORMAT					0x0C
#define COMMAND_READ_DISPLAY_IMAGE_FORMAT					0x0D
#define COMMAND_READ_DISPLAY_SIGNAL_MODE					0x0E
#define COMMAND_READ_DISPLAY_SELF_DIAGNOSTIC_RESULT			0x0F
#define COMMAND_ENTER_SLEEP_MODE							0x10
#define COMMAND_SLEEP_OUT									0x11
#define COMMAND_PARTIAL_MODE_ON								0x12
#define COMMAND_NORMAL_DISPLAY_MODE_ON						0x13
#define COMMAND_DISPLAY_INVERSION_OFF						0x20
#define COMMAND_DISPLAY_INVERSION_ON						0x21
#define COMMAND_GAMMA_SET									0x26
#define COMMAND_DISPLAY_OFF									0x28
#define COMMAND_DISPLAY_ON									0x29
#define COMMAND_COLUMN_ADDRESS_SET							0x2A
#define COMMAND_PAGE_ADDRESS_SET							0x2B
#define COMMAND_MEMORY_WRITE								0x2C
#define COMMAND_COLOR_SET									0x2D
#define COMMAND_MEMORY_READ									0x2E
#define COMMAND_PARTIAL_AREA								0x30
#define COMMAND_VERTICAL_SCROLLING_DEFINITION				0x33
#define COMMAND_TEARING_EFFECT_LINE_OFF						0x34
#define COMMAND_TEARING_EFFECT_LINE_ON						0x35
#define COMMAND_MEMORY_ACCESS_CONTROL						0x36
#define COMMAND_VERTICAL_SCROLLING_START_ADDRESS			0x37
#define COMMAND_IDLE_MODE_OFF								0x38
#define COMMAND_IDLE_MODE_ON								0x39
#define COMMAND_PIXEL_FORMAT_SET							0x3A
#define COMMAND_WRITE_MEMORY_CONTINUE						0x3C
#define COMMAND_READ_MEMORY_CONTINUE						0x3E
#define COMMAND_SET_TEAR_SCANLINE							0x44
#define COMMAND_GET_SCANLINE								0x45
#define COMMAND_WRITE_DISPLAY_BRIGHTNESS					0x51
#define COMMAND_READ_DISPLAY_BRIGHTNESS						0x52
#define COMMAND_WRITE_CTRL_DISPLAY							0x53
#define COMMAND_READ_CTRL_DISPLAY							0x54
#define COMMAND_WRITE_CONTENT_ADAPTIVE_BRIGHTNESS_CONTROL	0x55
#define COMMAND_READ_CONTENT_ADAPTIVE_BRIGHTNESS_CONTROL	0x56
#define COMMAND_WRITE_CABC_MINIMUM_BRIGHTNESS				0x5E
#define COMMAND_READ_CABC_MINIMUM_BRIGHTNESS				0x5F
#define COMMAND_READ_ID1									0xDA
#define COMMAND_READ_ID2									0xDB
#define COMMAND_READ_ID3									0xDC

/* Extended Commands */
#define COMMAND_RGB_INTERFACE_SIGNAL_CONTROL				0xB0
#define COMMAND_FRAME_CONTROL_IN_NORMAL_MODE				0xB1
#define COMMAND_FRAME_CONTROL_IN_IDLE_MODE					0xB2
#define COMMAND_FRAME_CONTROL_IN_PARTIAL_MODE				0xB3
#define COMMAND_DISPLAY_INVERSION_CONTROL					0xB4
#define COMMAND_BLANKING_PORCH_CONTROL						0xB5
#define COMMAND_DISPLAY_FUNCTION_CONTROL					0xB6
#define COMMAND_ENTRY_MODE_SET								0xB7
#define COMMAND_BACKLIGHT_CONTROL_1							0xB8
#define COMMAND_BACKLIGHT_CONTROL_2							0xB9
#define COMMAND_BACKLIGHT_CONTROL_3							0xBA
#define COMMAND_BACKLIGHT_CONTROL_4							0xBB
#define COMMAND_BACKLIGHT_CONTROL_5							0xBC
#define COMMAND_BACKLIGHT_CONTROL_7							0xBE
#define COMMAND_BACKLIGHT_CONTROL_8							0xBF
#define COMMAND_POWER_CONTROL_1								0xC0
#define COMMAND_POWER_CONTROL_2								0xC1
#define COMMAND_POWER_CONTROL3_(FOR_NORMAL_MODE)			0xC2
#define COMMAND_POWER_CONTROL4_(FOR_IDLE_MODE)				0xC3
#define COMMAND_POWER_CONTROL5_(FOR_PARTIAL_MODE)			0xC4
#define COMMAND_VCOM_CONTROL_1								0xC5
#define COMMAND_VCOM_CONTROL_2								0xC7
#define COMMAND_NV_MEMORY_WRITE								0xD0
#define COMMAND_NV_MEMORY_PROTECTION_KEY					0xD1
#define COMMAND_NV_MEMORY_STATUS_READ						0xD2
#define COMMAND_READ_ID4									0xD3
#define COMMAND_POSITIVE_GAMMA_CORRECTION					0xE0
#define COMMAND_NEGATIVE_GAMMA_CORRECTION					0xE1
#define COMMAND_DIGITAL_GAMMA_CONTROL						0xE2
#define COMMAND_DIGITAL_GAMMA_CONTROL2						0xE3
#define COMMAND_INTERFACE_CONTROL							0xF6

/* Undocumented commands */
#define COMMAND_INTERNAL_IC_SETTING							0xCB
#define COMMAND_GAMMA_DISABLE								0xF2

void writeCommand(uint8_t command, uint8_t parameter_count, uint8_t* parameters) {
    CONTROL_PORT &= ~(1 << CONTROL_PORT_D_CX);
    DATA_PORT = command;
    CONTROL_PORT &= ~(1 << CONTROL_PORT_WRX);
    CONTROL_PORT |= (1 << CONTROL_PORT_WRX);
    CONTROL_PORT |= (1 << CONTROL_PORT_D_CX);
    for (uint8_t i = 0; i < parameter_count; i++) {
        DATA_PORT = parameters[i];
        CONTROL_PORT &= ~(1 << CONTROL_PORT_WRX);
        CONTROL_PORT |= (1 << CONTROL_PORT_WRX);
    }
}

void initialiseLcd() {
	/* Disable JTAG in software, so that it does not interfere with Port C  */
	/* It will be re-enabled after a power cycle if the JTAGEN fuse is set. */
	MCUCR |= (1<<JTD);
	MCUCR |= (1<<JTD);

    CONTROL_DDR = 0x7F;
    DATA_DDR = 0xFF;

    CONTROL_PORT = (1 << CONTROL_PORT_CSX)
                 | (1 << CONTROL_PORT_D_CX)
                 | (1 << CONTROL_PORT_RDX)
                 | (1 << CONTROL_PORT_VSYNC)
                 | (1 << CONTROL_PORT_WRX);
    _delay_ms(100);
    CONTROL_PORT |= (1 << CONTROL_PORT_RESX);
    _delay_ms(100);

    // Chip-select:
    CONTROL_PORT &= ~(1 << CONTROL_PORT_CSX);

    writeCommand(COMMAND_DISPLAY_OFF,                  0, NULL);
    writeCommand(COMMAND_SLEEP_OUT,                    0, NULL);
    // _delay_ms(60);
    writeCommand(COMMAND_INTERNAL_IC_SETTING,          1, (uint8_t[]) { 0x01 });
    writeCommand(COMMAND_POWER_CONTROL_1,              2, (uint8_t[]) { 0x26, 0x08 });
    writeCommand(COMMAND_POWER_CONTROL_2,              1, (uint8_t[]) { 0x10 });
    writeCommand(COMMAND_VCOM_CONTROL_1,               2, (uint8_t[]) { 0x35, 0x3E });
    writeCommand(COMMAND_MEMORY_ACCESS_CONTROL,        1, (uint8_t[]) { 0xE8 });
    writeCommand(COMMAND_RGB_INTERFACE_SIGNAL_CONTROL, 1, (uint8_t[]) { 0x4A }); // Set the DE/HSync/VSync/DotClk polarity
    writeCommand(COMMAND_FRAME_CONTROL_IN_NORMAL_MODE, 2, (uint8_t[]) { 0x00, 0x1B }); // 70 Hz
    // writeCommand(COMMAND_FRAME_CONTROL_IN_NORMAL_MODE, 2, (uint8_t[]) { 0x03, 0x1f });
    // writeCommand(COMMAND_DISPLAY_FUNCTION_CONTROL,     4, (uint8_t[]) { 0x0A, 0x82, 0x27, 0x00 });
    writeCommand(COMMAND_DISPLAY_FUNCTION_CONTROL,     4, (uint8_t[]) { 0x02, 0x80, 0x27, 0x00 });
    writeCommand(COMMAND_VCOM_CONTROL_2,               1, (uint8_t[]) { 0xB5 });
    // writeCommand(COMMAND_INTERFACE_CONTROL,            3, (uint8_t[]) { 0x01, 0x00, 0x08 }); // System and VSYNC interface
    writeCommand(COMMAND_INTERFACE_CONTROL,            3, (uint8_t[]) { 0x01, 0x00, 0x00 }); // System interface
    writeCommand(COMMAND_GAMMA_DISABLE,                1, (uint8_t[]) { 0x00 });
    writeCommand(COMMAND_GAMMA_SET,                    1, (uint8_t[]) { 0x01 });
    writeCommand(COMMAND_PIXEL_FORMAT_SET,             1, (uint8_t[]) { 0x55 }); // 0x66 = 18-bit/pixel, 0x55 = 16-bit/pixel
    writeCommand(COMMAND_POSITIVE_GAMMA_CORRECTION,   15, (uint8_t[]) { 0x1F, 0x1A, 0x18, 0x0A, 0x0F, 0x06, 0x45, 0x87, 0x32, 0x0A, 0x07, 0x02, 0x07, 0x05, 0x00 });
    writeCommand(COMMAND_NEGATIVE_GAMMA_CORRECTION,   15, (uint8_t[]) { 0x00, 0x25, 0x27, 0x05, 0x10, 0x09, 0x3A, 0x78, 0x4D, 0x05, 0x18, 0x0D, 0x38, 0x3A, 0x1F });
    writeCommand(COMMAND_COLUMN_ADDRESS_SET,           4, (uint8_t[]) { 0x00, 0x00, 0x01, 0x3F });
    writeCommand(COMMAND_PAGE_ADDRESS_SET,             4, (uint8_t[]) { 0x00, 0x00, 0x00, 0xEF });
    writeCommand(COMMAND_TEARING_EFFECT_LINE_OFF,      0, NULL);
    writeCommand(COMMAND_DISPLAY_INVERSION_CONTROL,    1, (uint8_t[]) { 0x00 });
    writeCommand(COMMAND_ENTRY_MODE_SET,               1, (uint8_t[]) { 0x07 });
    // writeCommand(COMMAND_COLOR_SET,                  128, ...);
    writeCommand(COMMAND_BLANKING_PORCH_CONTROL,       4, (uint8_t[]) {0x02, 0x7F, 0x02, 0x02});
    writeCommand(COMMAND_MEMORY_WRITE,                 0, NULL);
    DATA_PORT = 0x00;
    for (uint32_t i = 0; i < (uint32_t) 320 * 240; i++) {
        CONTROL_PORT &= ~(1 << CONTROL_PORT_WRX);
        CONTROL_PORT |= (1 << CONTROL_PORT_WRX);
        CONTROL_PORT &= ~(1 << CONTROL_PORT_WRX);
        CONTROL_PORT |= (1 << CONTROL_PORT_WRX);
    }
    writeCommand(COMMAND_DISPLAY_ON,                   0, NULL);
    CONTROL_PORT |= (1 << CONTROL_PORT_BLC);

    // Chip-deselect:
    CONTROL_PORT |= (1 << CONTROL_PORT_CSX);

    // Initialise TIMER0:
    TCCR0A = (1 << COM0A0)                // OC1A toggle on compare match
           | (1 << WGM01) | (1 << WGM00); // Fast PWM mode, TOP = OCR0A
    TCCR0B = (1 << WGM02);                // ...
    TCNT0 = 0;
    OCR0A = 0;
    OCR0B = 0;

    // Make sure OC0A is in the HIGH state:
    setOc0aHigh();

    // Switch over to use timer output as WRX signal:
    DDRA &= ~(1 << PA3);
    DDRB |= (1 << PB3);
}

void setOc0aHigh() {
    asm(
        "ldi 25, 0x08" "\n"
        "ldi 24, 0x09" "\n"

        // Clock the timer for one cycle:
        "out 0x25, r24"  "\n" // enable clock
        "nop"            "\n"
        "out 0x25, r25"  "\n" // disable clock

        // Give time for the pin's output to propogate to PINB:
        "nop"            "\n"
        "nop"            "\n"

        // If PINB3 is low, enable the timer for one clock cycle to toggle it to high:
        "sbic 0x03, 3"   "\n" // skip if PINB3 is cleared
        "rjmp .+4"       "\n"
        "out 0x25, 0x09" "\n" // enable clock
        "out 0x25, 0x08" "\n" // disable clock
    );
}
