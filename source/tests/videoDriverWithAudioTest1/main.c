#include "writeScreen.h"
#include "tileMap.h"
#include "lcd.h"
#include <stdint.h>
#include <avr/io.h>
#include <avr/interrupt.h>
#include <stdlib.h>
#include <util/delay.h>

#define GRID_WIDTH 40
#define GRID_HEIGHT 28

#define AUDIO_BUFFER_SIZE 524

uint8_t audioBuffer[AUDIO_BUFFER_SIZE] = {
    128, 158, 186, 212, 232, 246, 254, 254, 247, 234, 214, 189, 161, 131, 100,  71,  46,  25,  10,   2,   0,   7,  20,  39,  63,  91, 121, 152, 181, 207, 228, 244,
    253, 255, 249, 237, 218, 194, 167, 137, 106,  77,  51,  29,  12,   3,   0,   5,  17,  35,  58,  85, 115, 146, 175, 202, 224, 241, 252, 255, 251, 240, 222, 199,
    172, 143, 112,  83,  56,  33,  15,   4,   0,   3,  14,  31,  53,  80, 109, 140, 170, 197, 220, 238, 250, 255, 252, 243, 226, 204, 178, 149, 118,  88,  61,  37,
     18,   6,   0,   2,  11,  27,  48,  74, 103, 134, 164, 192, 216, 235, 248, 255, 253, 245, 230, 209, 184, 155, 124,  94,  66,  41,  21,   8,   1,   1,   9,  23,
     43,  69,  97, 127, 158, 186, 212, 232, 246, 254, 254, 247, 234, 214, 189, 161, 131, 100,  71,  46,  25,  10,   2,   0,   7,  20,  39,  63,  91, 121, 152, 181,
    207, 228, 244, 253, 255, 249, 237, 218, 194, 167, 137, 106,  77,  51,  29,  12,   3,   0,   5,  17,  35,  58,  85, 115, 146, 175, 202, 224, 241, 252, 255, 251,
    240, 222, 199, 172, 143, 112,  83,  56,  33,  15,   4,   0,   3,  14,  31,  53,  80, 109, 140, 170, 197, 220, 238, 250, 255, 252, 243, 226, 204, 178, 149, 118,
     88,  61,  37,  18,   6,   0,   2,  11,  27,  48,  74, 103, 134, 164, 192, 216, 235, 248, 255, 253, 245, 230, 209, 184, 155, 124,  94,  66,  41,  21,   8,   1,
      1,   9,  23,  43,  69,  97, 127, 158, 186, 212, 232, 246, 254, 254, 247, 234, 214, 189, 161, 131, 100,  71,  46,  25,  10,   2,   0,   7,  20,  39,  63,  91,
    121, 152, 181, 207, 228, 244, 253, 255, 249, 237, 218, 194, 167, 137, 106,  77,  51,  29,  12,   3,   0,   5,  17,  35,  58,  85, 115, 146, 175, 202, 224, 241,
    252, 255, 251, 240, 222, 199, 172, 143, 112,  83,  56,  33,  15,   4,   0,   3,  14,  31,  53,  80, 109, 140, 170, 197, 220, 238, 250, 255, 252, 243, 226, 204,
    178, 149, 118,  88,  61,  37,  18,   6,   0,   2,  11,  27,  48,  74, 103, 134, 164, 192, 216, 235, 248, 255, 253, 245, 230, 209, 184, 155, 124,  94,  66,  41,
     21,   8,   1,   1,   9,  23,  43,  69,  97, 128, 158, 186, 212, 232, 246, 254, 254, 247, 234, 214, 189, 161, 131, 100,  71,  46,  25,  10,   2,   0,   7,  20,
     39,  63,  91, 121, 152, 181, 207, 228, 244, 253, 255, 249, 237, 218, 194, 167, 137, 106,  77,  51,  29,  12,   3,   0,   5,  17,  35,  58,  85, 115, 146, 175,
    202, 224, 241, 252, 255, 251, 240, 222, 199, 172, 143, 112,  83,  56,  33,  15,   4,   0,   3,  14,  31,  53,  80, 109, 140, 170, 197, 220, 238, 250, 255, 252,
    243, 226, 204, 178, 149, 118,  88,  61,  37,  18,   6,   0,   2,  11,  27,  48,  74, 103, 134, 164, 192, 216, 235, 248, 255, 253, 245, 230, 209, 184, 155, 124,
     94,  66,  41,  21,   8,   1,   1,   9,  23,  43,  69,  97,
};

uint8_t* currentAudioSamplePtr = &audioBuffer[0];

const uint8_t* vram[GRID_WIDTH * GRID_HEIGHT];

int main() {
    initialiseLcd();

    // Set up TIMER1 for 15.625 kHz interrupts:
    TCCR1A = (1 << WGM11) | (1 << WGM10); // Fast PWM mode (so that TOV1 flag is set at TOP), TOP = OCR1A
    TCCR1B = (1 << WGM13) | (1 << WGM12)  // ^
           | (1 << CS10);                 // Enable clock, no prescaler
    TCCR1C = 0;
    OCR1A = 767; // Set TOP for 15.625 kHz interrupts (3x256 so evenly fits into PWM cycle)
    TIMSK1 = (1 << TOIE1); // Enable overflow interrupt

    // Set up TIMER2 for 8-bit 46.875 kHz PWM:
    TCCR2A = (1 << WGM21) | (1 << WGM20) // Fast PWM mode, TOP = 255
           | (1 << COM2A1);              // OC2A as non-inverting PWM output
    TCCR2B = (1 << CS20);                // Enable clock, no prescaler
    OCR2A = 128;                         // Set duty cycle to 50%
    TIMSK2 = 0;                          // Disable all TIMER2 interrupts

    // Reset both counters so they're pretty much synchronised:
    TCNT1 = 0;
    TCNT2 = 0;

    // Set PWM pin (OC2A / PD7) as output:
    DDRD |= (1 << PD7);

    // Write a tile into every grid position:
    for (uint16_t i = 0; i < GRID_WIDTH * GRID_HEIGHT; i++) {
        vram[i] = &tileMap[i % 8][0];
        // vram[i] = &tileMap[8 + i % 3][0];
    }

    sei();

    while (1);
}

// This ISR uses 89/768 = ~12% of CPU time (when the screen isn't being updated). However it wastes 40 CPU cycles
// pushing/popping registers every time which only need to be pushed/popped when the function calls (mixAudio() and
// writeScreen()) are executed. Removing the unnecessary pushes/pops results in 48/768 = ~6% of CPU time (when the
// screen isn't being updated). It may be necessary to rewrite this IRS in assembly.
ISR(TIMER1_OVF_vect) {
    currentAudioSamplePtr++;
    if (currentAudioSamplePtr == &audioBuffer[AUDIO_BUFFER_SIZE]) {
        currentAudioSamplePtr = &audioBuffer[0];
        sei();
        // mixAudio();
        writeScreen();
    } else {
        OCR2A = *currentAudioSamplePtr;
    }
}