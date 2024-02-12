#include <avr/io.h>

#define IO(io_reg) _SFR_IO_ADDR(io_reg)

.global ledInitialise
.global ledToggle

.section .text

ledInitialise:
    sbi IO(DDRB), 7
    ret

ledToggle:
    sbi IO(PINB), 7
    ret
