#include <avr/io.h>

#define CONTROL_PORT PORTB
#define CONTROL_PORT_CSX 0
#define CONTROL_PORT_D_CX 4
#define CONTROL_PORT_VSYNC 6
#define DATA_PORT PORTD

#define TILE_WIDTH 6
; #define TILE_WIDTH 8

#define IO(io_reg) _SFR_IO_ADDR(io_reg)

.global writeScreenNoInterrupts

.section .text

;############################################## Write all tiles to screen ##############################################
;### void writeScreenNoInterrupts(void)
;###
;### C-callable
;###############

writeScreenNoInterrupts:

    ; Total execution time (TILE_WIDTH = 6) = 45 + 40*(33 + 4*64*28 + 3) - 1 + 16 = 288220 CPU cycles
    ; Total execution time (TILE_WIDTH = 8) = 45 + 30*(33 + 4*80*28 + 3) - 1 + 16 = 269940 CPU cycles
    ;
    ; Code size (TILE_WIDTH = 6) = 198 bytes
    ; Code size (TILE_WIDTH = 8) = 204 bytes
    ;
    ; - There are two dimensions allowed for tiles: 6x8 pixels and 8x8 pixels.
    ; - The original Uzebox pixels aren't square, but instead have an aspect ratio of 4:3, which could be achieved because it uses the analogue NTSC display format.
    ; - For this version, we're using an LCD screen with discreet square pixels, so we can't have 4:3 pixels.
    ; - For the 6x8 tile mode (grid size 40x28) TILE_WIDTH = 6:
    ;     - With a pixel aspect ratio of 4:3, a 6x8 tile would be displayed as a perfect square.
    ;     - To emulate this, we can insert a duplicate pixel after every 3 horizontal pixels, resulting in a tile's displayed resolution being 8x8 pixels (a perfect square).
    ;     - This will result in a little bit of distortion since we're not stretching every pixel evenly.
    ;         - The first 2 pixels aren't stretched, and the 3rd is streched to an aspect ratio of 2:1).
    ;         - Seems like a resonable compromise.
    ;     - With a grid size of 40x28, this results in a screen resolution of 320x224 pixels.
    ;         - The LCD has a resolution of 320x240 pixels, so there will be a black border of 8 pixels along the top and bottom of the screen.
    ;     - Note that TILE_WIDTH=6 is a bit confusing because it refers to the width in terms of original Uzebox pixels, but on the LCD it will be 8 pixels wide.
    ; - For the 8x8 tile mode (grid size 30x28) TILE_WIDTH = 8:
    ;     - Inserting a duplicate pixel after every 3 horizontal pixels would be difficult because 3 doesn't divide evenly into a tile width of 8.
    ;     - Instead, we can insert a duplicate pixel after every 4 horizontal pixels, resulting in a tile's displayed resolution being 10x8 pixels.
    ;         - This results in a tile's aspect ratio being 3.75:3 (instead of the original Uzebox's 4:3), which is close enough.
    ;     - With a grid size of 30x28, this results in a screen resolution of 300x224 pixels.
    ;         - The LCD has a resolution of 320x240 pixels, so there will be a black border of 8 pixels along the top and bottom, and 10 pixels down the left and right.
    ;     - Note that TILE_WIDTH=8 is a bit confusing because it refers to the width in terms of original Uzebox pixels, but on the LCD it will be 10 pixels wide.

    ; In the following code, each instruction has a comment starting with a set of brackets. The value inside the brackets
    ; indicates the state of TIMER0's OC0A output (high or low) in each CPU cycle. OC0A is connected to the LCD's WR signal,
    ; so writing to the DATA_PORT must be synchronised with it. OC0A should already be high, with the timer disabled, before
    ; entering this function. When the function returns, OC0A will be left high, with the timer disabled. The timer is set
    ; at the maximum frequency, toggling OC0A every CPU cycle when enabled. Enabling the timer and then disabling it again
    ; one CPU cycle later will toggle OC0A once. Adding an odd number of extra CPU cycles in between enabling and disabling
    ; will toggle OC0A an even number of times, leaving it in its original state after.

    ;##################################################### Set up ######################################################

        ; Push call-save registers that will be modified, so they can be restored later:
        push r14                                       ; (H-H)
        push r15                                       ; (H-H)
        push r16                                       ; (H-H)
        push r17                                       ; (H-H)

        ; Save SREG (to restore it later) and disable interrupts:
        in r0, IO(SREG)                                ; (H)
        cli                                            ; (H)

        ; TODO: Should VSYNC be generated after sending the data instead of before? This is not how the datasheet says to
        ;       do it but, if it works, it would ensure the scan line doesn't overtake the memory writing.
        ; Generate a negative pulse on VSYNC signal:
        cbi IO(CONTROL_PORT), CONTROL_PORT_VSYNC       ; (H-H)
        sbi IO(CONTROL_PORT), CONTROL_PORT_VSYNC       ; (H-H)

        ; Pull CSX line low:
        cbi IO(CONTROL_PORT), CONTROL_PORT_CSX         ; (H-H)

    ;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    ;############################################### Initialise variables ##############################################

        ldi r18, (1 << WGM02) | (1 << CS00)            ; (H) TCCR0B value to enable timer
        ldi r19, (1 << WGM02)                          ; (H) TCCR0B value to disable timer
        movw r14, r18                                  ; (H) move values to r14 and r15

        #if TILE_WIDTH == 6
            ldi r18, 0                                 ; (H) start-page low byte
            ldi r19, 0                                 ; (H) start-page high byte
            ldi r24, 7                                 ; (H) end-page low byte
            ldi r25, 0                                 ; (H) end-page high byte
            ldi r22, 40                                ; (H) columns remaining
        #elif TILE_WIDTH == 8
            ldi r18, 10                                ; (H) start-page low byte
            ldi r19, 0                                 ; (H) start-page high byte
            ldi r24, 19                                ; (H) end-page low byte
            ldi r25, 0                                 ; (H) end-page high byte
            ldi r22, 30                                ; (H) columns remaining
        #else
            #error "TILE_WIDTH must be 6 or 8"
        #endif

        ldi XL, lo8(vram)                              ; (H) Load VRAM address into X register (low byte)
        ldi XH, hi8(vram)                              ; (H) Load VRAM address into X register (high byte)
        ld ZL, X+                                      ; (H) Read first tile pointer from VRAM into Z register (low byte)
        ld ZH, X+                                      ; (H) Read first tile pointer from VRAM into Z register (high byte)

    ;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    ;####################################### Write CASET command and parameters ########################################

        ; Set data/command signal low (command):
        cbi IO(CONTROL_PORT), CONTROL_PORT_D_CX        ; (H-H)

        ; Write CASET command code to LCD:
        ldi r23, 0x2A                                  ; (H) Put CASET command code into register
        out IO(TCCR0B), r14                            ; (H) Enable timer
        out IO(DATA_PORT), r23                         ; (L) Write command code to data port
        out IO(TCCR0B), r15                            ; (H) Disable timer

        ; Set data/command signal high (data)
        sbi IO(CONTROL_PORT), CONTROL_PORT_D_CX        ; (H-H)

        ; Write CASET parameters (start-page and end-page):
        out IO(TCCR0B), r14                            ; (H) Enable timer
        out IO(DATA_PORT), r1                          ; (L) Write start-column high byte (zero) to data port
        ldi r23, 7                                     ; (H) Put start-column low byte into a register
        out IO(DATA_PORT), r23                         ; (L) Write start-column low byte to data port
        nop                                            ; (H) Synchronisation delay
        out IO(DATA_PORT), r1                          ; (L) Write end-column high byte (zero) to data port
        ldi r23, 230                                   ; (H) Put end-column low byte into a register
        out IO(DATA_PORT), r23                         ; (L) Write end-column low byte to data port
        out IO(TCCR0B), r15                            ; (H) Disable timer

    ;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    ;################################################ Write tile column ################################################

    write_tile_column:

        ;##################################### Write PASET command and parameters ######################################

            ; Set data/command signal low (command):
            cbi IO(CONTROL_PORT), CONTROL_PORT_D_CX    ; (H-H)

            ; Write PASET command code to LCD:
            ldi r23, 0x2B                              ; (H) Put PASET command code into register
            out IO(TCCR0B), r14                        ; (H) Enable timer
            out IO(DATA_PORT), r23                     ; (L) Write command code to data port
            out IO(TCCR0B), r15                        ; (H) Disable timer

            ; Set data/command signal high (data)
            sbi IO(CONTROL_PORT), CONTROL_PORT_D_CX    ; (H-H)

            ; Write PASET parameters (start-page and end-page):
            out IO(TCCR0B), r14                        ; (H) Enable timer
            out IO(DATA_PORT), r19                     ; (L) Write start-page high byte to data port
            nop                                        ; (H) Synchronisation delay
            out IO(DATA_PORT), r18                     ; (L) Write start-page low byte to data port
            #if TILE_WIDTH == 6
                subi r18, -8                           ; (H) Add 8 to start-page low byte
            #elif TILE_WIDTH == 8
                subi r18, -10                          ; (H) Add 10 to start-page low byte
            #else
                #error "TILE_WIDTH must be 6 or 8"
            #endif
            out IO(DATA_PORT), r25                     ; (L) Write end-page high byte to data port
            sbci r19, 0xFF                             ; (H) Propogate carry to start-page high byte
            out IO(DATA_PORT), r24                     ; (L) Write end-page low byte to data port
            out IO(TCCR0B), r15                        ; (H) Disable timer
            #if TILE_WIDTH == 6
                adiw r24, 8                            ; (H-H) Add 8 to end-page
            #elif TILE_WIDTH == 8
                adiw r24, 10                           ; (H-H) Add 10 to end-page
            #else
                #error "TILE_WIDTH must be 6 or 8"
            #endif

        ;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

        ;############################################# Write RAMWR command #############################################

            ; Set data/command signal low (command)
            cbi IO(CONTROL_PORT), CONTROL_PORT_D_CX    ; (H-H)

            ; Write RAMWR command code to LCD
            ldi r23, 0x2C                              ; (H) Put RAMWR command code into register
            out IO(TCCR0B), r14                        ; (H) Enable timer
            out IO(DATA_PORT), r23                     ; (L) Write command code to LCD
            out IO(TCCR0B), r15                        ; (H) Disable timer

            ; Set data/command signal high (data)
            sbi IO(CONTROL_PORT), CONTROL_PORT_D_CX    ; (H-H)

        ;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

        ;############################# Write all tiles in the column (as RAMWR parameters) #############################

            ; Initialise loop variables
            ldi r16, 14                                ; (H) iterations of 4/5-pixel write loop
            ldi r17, 28                                ; (H) tiles remaining in column

            ; Read first pixel from FLASH
            lpm r23, Z+                                ; (H-H-H)

            ; Enable timer:
            out IO(TCCR0B), r14 ; (H)

        write_tile:

            ; Write the first 56 or 70 (out of 64 or 80) pixels of the tile by looping 14 times, writing 4 or 5 pixels each loop:
            #if TILE_WIDTH == 8
                out IO(DATA_PORT), r23                 ; (L) Write pixel to data port
                lpm r23, Z+                            ; (H-L-H) Read next pixel from FLASH
            #endif
            out IO(DATA_PORT), r23                     ; (L) Write pixel to data port
            lpm r23, Z+                                ; (H-L-H) Read next pixel from FLASH
            out IO(DATA_PORT), r23                     ; (L) Write pixel to data port
            lpm r23, Z+                                ; (H-L-H) Read next pixel from FLASH
            out IO(DATA_PORT), r23                     ; (L) Write pixel to data port
            lpm r23, Z+                                ; (H-L-H) Read next pixel from FLASH
            nop                                        ; (L) Synchronisation delay
            dec r16                                    ; (H) Decrement 4/5-pixel counter
            brne write_tile                            ; (L-H / L) If counter hasn't reached zero, execute the loop again to write the next 4 or 5 pixels
            ldi r16, 14                                ; (H) Reset inner loop counter for next tile

            ; Write the next 4 or 5 pixels of the tile and start preparing for the next tile:
            #if TILE_WIDTH == 8
                out IO(DATA_PORT), r23                 ; (L) Write byte to data port
                lpm r23, Z+                            ; (H-L-H) Read next byte from FLASH
            #endif
            out IO(DATA_PORT), r23                     ; (L) Write byte to data port
            lpm r23, Z+                                ; (H-L-H) Read next byte from FLASH
            out IO(DATA_PORT), r23                     ; (L) Write byte to data port
            lpm r23, Z+                                ; (H-L-H) Read next byte from FLASH
            out IO(DATA_PORT), r23                     ; (L) Write pixel to data port
            lpm r23, Z+                                ; (H-L-H) Read next pixel from FLASH
            ld r20, X+                                 ; (L-H) Read next tile pointer into register pair r21:r20 (low byte)
            ld r21, X+                                 ; (L-H) Read next tile pointer into register pair r21:r20 (high byte)

            ; Write the final 4 or 5 pixels of the tile and finish preparing for the next tile:
            #if TILE_WIDTH == 8
                out IO(DATA_PORT), r23                 ; (L) Write byte to data port
                lpm r23, Z+                            ; (H-L-H) Read next byte from FLASH
            #endif
            out IO(DATA_PORT), r23                     ; (L) Write byte to data port
            lpm r23, Z+                                ; (H-L-H) Read next byte from FLASH
            out IO(DATA_PORT), r23                     ; (L) Write byte to data port
            lpm r23, Z+                                ; (H-L-H) Read next byte from FLASH
            out IO(DATA_PORT), r23                     ; (L) Write byte to data port
            movw ZL, r20                               ; (H) Quick move tile pointer from register pair r21:r20 to Z register
            lpm r23, Z+                                ; (L-H-L) Read next byte from FLASH
            dec r17                                    ; (H) Decrement tile counter
            brne write_tile                            ; (L-H / L) If tile counter hasn't reached zero, execute the loop again to write the next tile

            ; Disable timer
            out IO(TCCR0B), r15                        ; (H)

        ;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    ;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    ;############################## Write next column until all columns have been written ##############################

        ; Decrement column counter
        dec r22                                        ; (H)

        ; If column counter hasn't reached zero, execute the column loop again to write the next column:
        brne write_tile_column                         ; (H-H / H)

    ;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    ;#################################################### Finish up ####################################################

        ; Pull CSX line high:
        sbi IO(CONTROL_PORT), CONTROL_PORT_CSX         ; (H-H)

        ; Restore global interrupt flag (and others, but they don't matter):
        out IO(SREG), r0                               ; (H)

        ; Restore call-save registers that have been modified:
        pop r17                                        ; (H-H)
        pop r16                                        ; (H-H)
        pop r15                                        ; (H-H)
        pop r14                                        ; (H-H)

        ; Return from the function:
        ret                                            ; (H-H-H-H-H)

    ;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
