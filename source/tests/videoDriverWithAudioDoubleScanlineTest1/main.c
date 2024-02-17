#include "writeScreen.h"
#include "tileMap.h"
#include "lcd.h"
#include <stdint.h>
#include <avr/io.h>
#include <avr/interrupt.h>
#include <stdlib.h>
#include <util/delay.h>
#include <stdbool.h>

#if TILE_WIDTH == 6
    #define GRID_WIDTH 40
    #define GRID_HEIGHT 28
#elif TILE_WIDTH == 8
    #define GRID_WIDTH 30
    #define GRID_HEIGHT 28
#else
    #error "Invalid TILE_WIDTH"
#endif

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

volatile uint8_t* nextAudioSamplePtr = &audioBuffer[0];

const uint8_t* vram[GRID_WIDTH * GRID_HEIGHT];

volatile bool vsync = false;

void setTile(uint16_t x, uint16_t y, const uint8_t* tile);
void mixAudio();

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

    // // Write a tile into every grid position:
    // for (uint16_t i = 0; i < GRID_WIDTH * GRID_HEIGHT; i++) {
    //     vram[i] = &tileMap[i % 8][0];
    //     // vram[i] = &tileMap[8 + i % 3][0];
    // }

    for (uint16_t x = 0; x < GRID_WIDTH; x++) {
        for (uint16_t y = 0; y < GRID_HEIGHT; y++) {
            setTile(x, y, &tileMap[y % 8][0]);
        }
    }

    writeScreen();

    sei();

    while (1) {
        // while (vsync == false);
        // vsync = false;

        // static uint16_t yOffset = 0;
        // yOffset = (yOffset + 1) % 8;

        // for (uint16_t x = 0; x < GRID_WIDTH; x++) {
        //     for (uint16_t y = 0; y < GRID_HEIGHT; y++) {
        //         setTile(x, y, &tileMap[(y + yOffset) % 8][0]);
        //     }
        // }
    }
}

void setTile(uint16_t x, uint16_t y, const uint8_t* tile) {
    vram[y + x * GRID_HEIGHT] = tile;
}

void mixAudio() {}

ISR(TIMER1_OVF_vect) {
    OCR2A = *nextAudioSamplePtr;
    nextAudioSamplePtr++;

    // If we've reached the end of the buffer:
    if (nextAudioSamplePtr == &audioBuffer[AUDIO_BUFFER_SIZE]) {
        // Wrap around to the start of the buffer:
        nextAudioSamplePtr = &audioBuffer[0];

        // Generate thefirst VSync pulse for the LCD:
        PORTA &= ~(1 << 6);
        PORTA |= (1 << 6);

        // Mix the next buffer's worth of audio:
        sei();
        mixAudio(); // this must mix >80% of the buffer before writeScreen() gets called
        return;
    }

    // ~12288 CPU cycles (16 audio samples) after the first VSync, start writing to the screen:
    // (The 15 can be increased to a maximum of about 107 if the audio mixing needs more time,
    // but it may require some changes to the timing of second VSync in the writeScreen() function)
    if (nextAudioSamplePtr == &audioBuffer[15]) {
        sei();
        writeScreen();
        vsync = true;
        return;
    }
}

// This ISR uses 89/768 = ~12% of CPU time (when the screen isn't being updated). However it wastes 40 CPU cycles
// pushing/popping registers every time which only need to be pushed/popped when the function calls (mixAudio() and
// writeScreen()) are executed. Removing the unnecessary pushes/pops results in 48/768 = ~6% of CPU time (when the
// screen isn't being updated). It may be necessary to rewrite this ISR in assembly.
// ISR(TIMER2_OVF_vect) {
//     currentAudioSamplePtr++;

//     // If we've reached the last sample in the buffer, start mixing the next buffer:
//     if (currentAudioSamplePtr == &audioBuffer[AUDIO_BUFFER_SIZE - 1]) {
//         OCR2A = *currentAudioSamplePtr; // output the sample to the PWM channel
//         sei();
//         // mixAudio();
//         return;
//     }

//     // If we've reached past the end of the buffer, wrap around to the start:
//     if (currentAudioSamplePtr == &audioBuffer[AUDIO_BUFFER_SIZE]) {
//         currentAudioSamplePtr = &audioBuffer[0];
//         OCR2A = *currentAudioSamplePtr; // output the sample to the PWM channel

//         // Pulse vsync:
//         PORTA &= ~(1 << 6);
//         PORTA |= (1 << 6);

//         return;
//     }

//     if (currentAudioSamplePtr == &audioBuffer[16]) {
//         OCR2A = *currentAudioSamplePtr; // output the sample to the PWM channel
//         sei();
//         writeScreen();
//         vsync = true;
//         return;
//     }

//     OCR2A = *currentAudioSamplePtr; // output the sample to the PWM channel
// }
