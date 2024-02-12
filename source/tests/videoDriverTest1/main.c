#include "writeScreenNoInterrupts.h"
#include "tileMap.h"
#include <stdint.h>
#include <avr/io.h>
#include <util/delay.h>

#define GRID_WIDTH 30
#define GRID_HEIGHT 28

void set_oc0a_high();

const uint8_t* vram[GRID_WIDTH * GRID_HEIGHT];

int main() {
    // Write a tile into every grid position:
    for (uint16_t i = 0; i < GRID_WIDTH * GRID_HEIGHT; i++) {
        vram[i] = (const uint8_t*) &tileMap[i % TILE_COUNT];
    }

    // Set video ports as outputs:
    DDRB = 0xFF;
    DDRD = 0xFF;

    // Initialise TIMER0:
    TCCR0A = (1 << COM0A0)                // OC1A toggle on compare match
           | (1 << WGM01) | (1 << WGM00); // Fast PWM mode, TOP = OCR0A
    TCCR0B = (1 << WGM02);                // ...
    TCNT0 = 0;
    OCR0A = 0;
    OCR0B = 0;

    // Make sure OC0A is in the HIGH state:
    set_oc0a_high();

    // Repeatedly call the writeScreenNoInterrupts() function to test its outputs:
    while (1) {
        writeScreenNoInterrupts();
    }
}

void set_oc0a_high() {
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
