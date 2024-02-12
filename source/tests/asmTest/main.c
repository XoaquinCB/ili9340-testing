#include "led.h"
#include <util/delay.h>

int main() {
    ledInitialise();

    while (1) {
        ledToggle();
        _delay_ms(500);
    }
}