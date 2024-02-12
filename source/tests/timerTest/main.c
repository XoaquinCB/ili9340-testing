#include <avr/io.h>
#include <stdint.h>

int main() {

    DDRB |= (1 << PB3) | (1 << PB4); // Set PB3 and PB4 as outputs
    PORTB &= ~(1 << PB4); // Set PB4 low

    TCCR0A = (1 << COM0A0) // OC1A toggle on compare match
           | (1 << WGM01) | (1 << WGM00); // Fast PWM mode, TOP = OCR0A
    TCCR0B = (1 << WGM02);                // ...
    TCNT0 = 0;
    OCR0A = 0;
    OCR0B = 0;

    // OC0A is low

    TCCR0B = (1 << WGM02) | (1 << CS00); // enable clock (1/8 prescaler)
    asm("nop");
    TCCR0B = (1 << WGM02); // disable clock

    // OC0A is high

    #define io_TCCR0B 0x25
    #define io_PORTB 0x05

    while (1) {
        asm(
            "ldi 25, 0x08" "\n"
            "ldi 24, 0x09" "\n"
            "out 0x25, 24" "\n"
            "out 0x05, 4"  "\n"
            "nop"          "\n"
            "out 0x05, 0"  "\n"
            "nop"          "\n"
            "out 0x05, 4"  "\n"
            "out 0x25, 25" "\n"
            "nop"          "\n"
            "nop"          "\n"
            "nop"          "\n"
            "nop"          "\n"
            "nop"          "\n"
            "nop"          "\n"
            "nop"          "\n"
            "nop"          "\n"
            "out 0x25, 24" "\n"
            "out 0x05, 0"  "\n"
            "nop"          "\n"
            "out 0x05, 4"  "\n"
            "nop"          "\n"
            "out 0x05, 0"  "\n"
            "out 0x25, 25" "\n"
            "nop"          "\n"
            "nop"          "\n"
            "nop"          "\n"
            "nop"          "\n"
            "nop"          "\n"
            "nop"          "\n"
        );
    }

    // OC0A is low

    while (1);
}

void set_oc0a_high() {
    TCCR0B = (1 << WGM02) | (1 << CS00); // enable clock (1/8 prescaler)
    asm("nop");
    TCCR0B = (1 << WGM02); // disable clock

    // Give time for the pin's output to propogate to PINB:
    asm("nop");
    asm("nop");

    // If PINB3 is low, enable the timer for one clock cycle to toggle it to high:
    if (~PINB & (1 << PB3)) {
        TCCR0B = (1 << WGM02) | (1 << CS00); // enable clock (1/8 prescaler)
        TCCR0B = (1 << WGM02); // disable clock
    }
}
