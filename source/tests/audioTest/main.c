#include <stdint.h>
#include <avr/io.h>
#include <avr/interrupt.h>

#define AUDIO_BUFFER_SIZE 32

// 491 Hz sine wave:
uint8_t audioBuffer[AUDIO_BUFFER_SIZE] = {
    128, 152, 176, 198, 218, 234, 245, 253,
    255, 253, 245, 234, 218, 198, 176, 152,
    127, 103,  79,  57,  37,  21,  10,   2,
      0,   2,  10,  21,  37,  57,  79, 103,
};

uint8_t audioBufferIndex = 0;

int main() {
    // Enable pullup on PD0:
    PORTD |= (1 << PD1) | (1 << PD0);

    // Set up TIMER2 for PWM:
    TCCR2A = (1 << COM2A1) // Non-inverting PWM on OC2A
           | (1 << WGM21) | (1 << WGM20); // Fast PWM mode, TOP = 0xFF
    TCCR2B = (1 << CS20); // Enable clock, no prescaling
    TIMSK2 = 0; // Disable all TIMER2 interrupts
    OCR2A = 128; // Set PWM to 50%

    // Set PD7 (OC2A) as output:
    DDRD |= (1 << PD7);

    // Set up TIMER1 for 15.72kHz interrupts:
    TCCR1A = 0;
    TCCR1B = (1 << WGM12) // CTC mode, TOP = OCR1A
           | (1 << CS10); // Enable clock, no prescaling
    TCCR1C = 0;
    TCNT1 = 0; // Reset counter to 0
    OCR1A = 762; // Set TOP for ~15.7kHz overflows
    TIMSK1 = (1 << OCIE1A); // Enable output compare A match interrupt

    // sei();
    // cli();

    while (1) {
        __builtin_avr_delay_cycles(30);
        sei();

        if (~PIND & (1 << PD0)) {
            OCR1A = 767;
        } else {
            OCR1A = 762;
        }

        if (~PIND & (1 << PD1)) {
            cli();
        }
    }
}

ISR(TIMER1_COMPA_vect) {
    OCR2A = audioBuffer[audioBufferIndex];
    audioBufferIndex = (audioBufferIndex + 1) % AUDIO_BUFFER_SIZE;
}
