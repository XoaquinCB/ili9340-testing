.global writeScreen
.section .text

;############################################### void writeScreen(void) ################################################
;### C-callable
;###############

writeScreen:

    ; Total execution time (TILE_WIDTH = 6) = 18+13+17+289079+30 = 289157 CPU cycles
    ; Total execution time (TILE_WIDTH = 8) = 18+13+17+270569+30 = 270647 CPU cycles
    ;
    ; Code size (TILE_WIDTH = 6) = 20+26+30+226+32 = 334 bytes of FLASH
    ; Code size (TILE_WIDTH = 8) = 20+26+30+254+32 = 362 bytes of FLASH
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

    #include <avr/io.h>

    #define IO(io_reg) _SFR_IO_ADDR(io_reg)

    #define DATA_PORT PORTC
    #define CONTROL_PORT PORTA
    #define CONTROL_PORT_CSX 0
    #define CONTROL_PORT_D_CX 4
    #define CONTROL_PORT_VSYNC 6

    #define reg_sregSave r0
    #define reg_zero r1
    #define reg_timerEnable r12
    #define reg_timerDisable r13
    #define reg_nextTile_l r14
    #define reg_nextTile_h r15
    #define reg_columnsRemaining r16
    #define reg_temporary r17
    #define reg_pixelOuterLoopCounter r18
    #define reg_pixelInnerLoopCounter r19
    #define reg_tilesRemainingInColumn r20
    #define reg_nextPixel r21
    #define reg_startColumn_l r22
    #define reg_startColumn_h r23
    #define reg_endColumn_l r24
    #define reg_endColumn_h r25

    #if TILE_WIDTH == 6
        #define FIRST_SC 0
        #define FIRST_EC 7
        #define COLUMN_COUNT 40
        #define ACTUAL_TILE_WIDTH 8
    #elif TILE_WIDTH == 8
        #define FIRST_SC 10
        #define FIRST_EC 19
        #define COLUMN_COUNT 30
        #define ACTUAL_TILE_WIDTH 10
    #else
        #error "TILE_WIDTH must be 6 or 8"
    #endif

    ;##################################################### Set up ######################################################
    ; 18 CPU cycles
    ; 20 bytes of FLASH

        ; Push call-save registers that will be modified, so they can be restored later:
        push r12                                            ; (H-H)
        push r13                                            ; (H-H)
        push r14                                            ; (H-H)
        push r15                                            ; (H-H)
        push r16                                            ; (H-H)
        push r17                                            ; (H-H)
        push YL                                             ; (H-H)
        push YH                                             ; (H-H)

        ; Save SREG (to restore global interrupts flag later) and disable interrupts:
        in reg_sregSave, IO(SREG)                           ; (H)
        cli                                                 ; (H)

    ;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Set up ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    ;############################################### Initialise variables ##############################################
    ; 13 CPU cycles
    ; 26 bytes of FLASH

        ldi reg_temporary, (1 << WGM02) | (1 << CS00)       ; (H) TCCR0B value to enable timer
        mov reg_timerEnable, reg_temporary                  ; (H) Move to correct register (can't 'ldi' directly to that register)
        ldi reg_temporary, (1 << WGM02)                     ; (H) TCCR0B value to disable timer
        mov reg_timerDisable, reg_temporary                 ; (H) Move to correct register (can't 'ldi' directly to that register)

        ldi reg_startColumn_l, lo8(FIRST_SC)                ; (H) start-column low byte
        ldi reg_startColumn_h, hi8(FIRST_SC)                ; (H) start-column high byte
        ldi reg_endColumn_l, lo8(FIRST_EC)                  ; (H) end-column low byte
        ldi reg_endColumn_h, hi8(FIRST_EC)                  ; (H) end-column high byte
        ldi reg_columnsRemaining, COLUMN_COUNT              ; (H) columns remaining

        lds XL, currentAudioSamplePtr                       ; (H-H) Load address of current audio sample into X register (low byte)
        lds XH, currentAudioSamplePtr+1                     ; (H-H) Load address of current audio sample into X register (high byte)

    ;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Initialise variables ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    ;####################################### Write PASET command and parameters ########################################
    ; 17 CPU cycles
    ; 30 bytes of FLASH

        ; Set data/command signal low (command):
        cbi IO(CONTROL_PORT), CONTROL_PORT_D_CX             ; (H-H)

        ; Write PASET command code to LCD:
        ldi reg_temporary, 0x2B                             ; (H) Put PASET command code into register
        out IO(TCCR0B), reg_timerEnable                     ; (H) Enable timer
        out IO(DATA_PORT), reg_temporary                    ; (L) Write command code to data port
        out IO(TCCR0B), reg_timerDisable                    ; (H) Disable timer

        ; Set data/command signal high (data)
        sbi IO(CONTROL_PORT), CONTROL_PORT_D_CX             ; (H-H)

        ; Write PASET parameters (start-page and end-page):
        out IO(TCCR0B), reg_timerEnable                     ; (H) Enable timer
        out IO(DATA_PORT), reg_zero                         ; (L) Write start-page high byte (zero) to data port
        ldi reg_temporary, 7                                ; (H) Put start-page low byte into a register
        out IO(DATA_PORT), reg_temporary                    ; (L) Write start-page low byte to data port
        nop                                                 ; (H) Synchronisation delay
        out IO(DATA_PORT), reg_zero                         ; (L) Write end-page high byte (zero) to data port
        ldi reg_temporary, 230                              ; (H) Put end-page low byte into a register
        out IO(DATA_PORT), reg_temporary                    ; (L) Write end-page low byte to data port
        out IO(TCCR0B), reg_timerDisable                    ; (H) Disable timer

    ;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Write PASET command and parameters ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    ;###################################### Column loop (executed 40 or 30 times) ######################################
    ; (19+8+7184+16)*40-1 = 289079 CPU cycles (TILE_WIDTH = 6)
    ; (19+8+8976+16)*30-1 = 270569 CPU cycles (TILE_WIDTH = 8)
    ; 32+12+156+26 = 226 bytes of FLASH (TILE_WIDTH = 6)
    ; 32+12+184+26 = 254 bytes of FLASH (TILE_WIDTH = 8)

    tileColumnLoop:

        ;##################################### Write CASET command and parameters ######################################
        ; 19 CPU cycles
        ; 32 bytes of FLASH

            ; Set data/command signal low (command):
            cbi IO(CONTROL_PORT), CONTROL_PORT_D_CX         ; (H-H)

            ; Write CASET command code to LCD:
            ldi reg_temporary, 0x2A                         ; (H) Put CASET command code into register
            out IO(TCCR0B), reg_timerEnable                 ; (H) Enable timer
            out IO(DATA_PORT), reg_temporary                ; (L) Write command code to data port
            out IO(TCCR0B), reg_timerDisable                ; (H) Disable timer

            ; Set data/command signal high (data)
            sbi IO(CONTROL_PORT), CONTROL_PORT_D_CX         ; (H-H)

            ; Write CASET parameters (start-column and end-column):
            out IO(TCCR0B), reg_timerEnable                 ; (H) Enable timer
            out IO(DATA_PORT), reg_startColumn_h            ; (L) Write start-column high byte to data port
            nop                                             ; (H) Synchronisation delay
            out IO(DATA_PORT), reg_startColumn_l            ; (L) Write start-column low byte to data port
            subi reg_startColumn_l, -ACTUAL_TILE_WIDTH      ; (H) Increment start-column low byte
            out IO(DATA_PORT), reg_endColumn_h              ; (L) Write end-column high byte to data port
            sbci reg_startColumn_h, 0xFF                    ; (H) Propogate carry to start-column high byte
            out IO(DATA_PORT), reg_endColumn_l              ; (L) Write end-column low byte to data port
            out IO(TCCR0B), reg_timerDisable                ; (H) Disable timer
            adiw reg_endColumn_l, ACTUAL_TILE_WIDTH         ; (H-H) Increment to end-column

        ;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Write CASET command and parameters ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

        ;############################################# Write RAMWR command #############################################
        ; 8 CPU cycles
        ; 12 bytes of FLASH

            ; Set data/command signal low (command)
            cbi IO(CONTROL_PORT), CONTROL_PORT_D_CX         ; (H-H)

            ; Write RAMWR command code to LCD
            ldi reg_temporary, 0x2C                         ; (H) Put RAMWR command code into register
            out IO(TCCR0B), reg_timerEnable                 ; (H) Enable timer
            out IO(DATA_PORT), reg_temporary                ; (L) Write command code to LCD
            out IO(TCCR0B), reg_timerDisable                ; (H) Disable timer

            ; Set data/command signal high (data)
            sbi IO(CONTROL_PORT), CONTROL_PORT_D_CX         ; (H-H)

        ;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Write RAMWR command ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

        ;############################# Write all tiles in the column (as RAMWR parameters) #############################
        ; 17+7167 = 7184 CPU cycles (TILE_WIDTH = 6)
        ; 17+8959 = 8976 CPU cycles (TILE_WIDTH = 8)
        ; 26+130 = 156 bytes of FLASH (TILE_WIDTH = 6)
        ; 26+158 = 184 bytes of FLASH (TILE_WIDTH = 8)

            ;########################################## Initialise tile loop ###########################################
            ; 17 CPU cycles
            ; 26 bytes of FLASH

                ; Initialise loop variables
                ldi reg_pixelOuterLoopCounter, 2            ; (H) Counter for pixel_outer_loop
                ldi reg_pixelInnerLoopCounter, 3            ; (H) Counter for pixel_inner_loop
                ldi reg_tilesRemainingInColumn, 28          ; (H) Tiles remaining in column

                ; Load first tile pointer in the column into Y register:
                ldi YL, COLUMN_COUNT                        ; (H)
                sub YL, reg_columnsRemaining                ; (H)
                lsl YL                                      ; (H)
                ldi YH, 0                                   ; (H)
                subi YL, lo8(-(vram))                       ; (H)
                sbci YH, hi8(-(vram))                       ; (H)

                ; Load the first tile texture pointer into Z register:
                ldd ZL, Y+0                                 ; (H-H) Read first tile texture pointer from VRAM into Z register (low byte)
                ldd ZH, Y+1                                 ; (H-H) Read first tile texture pointer from VRAM into Z register (high byte)

                ; Read first pixel from FLASH
                lpm reg_nextPixel, Z+                       ; (H-H-H)

                ; Enable timer:
                out IO(TCCR0B), reg_timerEnable             ; (H)

            ;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Initialise tile loop ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

            ;###################################### Tile loop (executed 28 times) ######################################
            ; 16*16*28-1 = 7167 CPU cycles (TILE_WIDTH = 6)
            ; 20*16*28-1 = 8959 CPU cycles (TILE_WIDTH = 8)
            ;  94+36 = 130 bytes of FLASH (TILE_WIDTH = 6)
            ; 114+44 = 158 bytes of FLASH (TILE_WIDTH = 8)

            tileLoop:

                ;################################# Pixel outer loop (executed 2 times) #################################
                ; 16*7*2 = 224 CPU cycles (TILE_WIDTH = 6)
                ; 20*7*2 = 280 CPU cycles (TILE_WIDTH = 8)
                ; 20+72 =  94 bytes of FLASH (TILE_WIDTH = 6)
                ; 24+88 = 114 bytes of FLASH (TILE_WIDTH = 8)

                pixelOuterLoop:

                    ;############################### Pixel inner loop (executed 3 times) ###############################
                    ; 16*3 = 48 CPU cycles (TILE_WIDTH = 6)
                    ; 20*3 = 60 CPU cycles (TILE_WIDTH = 8)
                    ; 20 bytes of FLASH (TILE_WIDTH = 6)
                    ; 24 bytes of FLASH (TILE_WIDTH = 8)

                    pixelInnerLoop:

                        ; Write 4 or 5 pixels, and read TIMER1 interupt flag register, and loop:

                        #if TILE_WIDTH == 8
                            out IO(DATA_PORT), reg_nextPixel; (L) Write pixel to data port
                            lpm reg_nextPixel, Z+           ; (H-L-H) Read next pixel from FLASH
                        #endif
                        out IO(DATA_PORT), reg_nextPixel    ; (L) Write pixel to data port
                        lpm reg_nextPixel, Z+               ; (H-L-H) Read next pixel from FLASH
                        out IO(DATA_PORT), reg_nextPixel    ; (L) Write pixel to data port
                        lpm reg_nextPixel, Z+               ; (H-L-H) Read next pixel from FLASH
                        out IO(DATA_PORT), reg_nextPixel    ; (L) Write pixel to data port
                        lpm reg_nextPixel, Z+               ; (H-L-H) Read next pixel from FLASH

                        in reg_temporary, IO(TIFR1)         ; (L) Read TIMER1 interrupt flag register
                        dec reg_pixelInnerLoopCounter       ; (H) Decrement pixel_inner_loop counter
                        brne pixelInnerLoop                 ; (L-H / L) If counter hasn't reached zero, loop again
                        ldi reg_pixelInnerLoopCounter, 3    ; (H) Reset pixel_inner_loop counter for next time

                    ;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Pixel inner loop (executed 3 times) ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

                    ; Write 4 or 5 pixels, and increment audio sample pointer if TIMER1 has overflown:

                    #if TILE_WIDTH == 8
                        out IO(DATA_PORT), reg_nextPixel    ; (L) Write pixel to data port
                        lpm reg_nextPixel, Z+               ; (H-L-H) Read next pixel from FLASH
                    #endif
                    out IO(DATA_PORT), reg_nextPixel        ; (L) Write pixel to data port
                    lpm reg_nextPixel, Z+                   ; (H-L-H) Read next pixel from FLASH
                    out IO(DATA_PORT), reg_nextPixel        ; (L) Write pixel to data port
                    lpm reg_nextPixel, Z+                   ; (H-L-H) Read next pixel from FLASH
                    out IO(DATA_PORT), reg_nextPixel        ; (L) Write pixel to data port
                    lpm reg_nextPixel, Z+                   ; (H-L-H) Read next pixel from FLASH

                    andi reg_temporary, (1 << TOV1)         ; (H) Mask TOV1 (timer overflow) flag
                    out IO(TIFR1), reg_temporary            ; (L) If the flag was set, clear it
                    add XL, reg_temporary                   ; (H) If the flag was set, add 1 to sample pointer (carry is propogated to high byte later)
                    adc XH, reg_zero                        ; (L) Propogate carry to sample pointer high byte

                    ; Write 4 or 5 pixels, and write the current audio sample to the PWM channel:

                    #if TILE_WIDTH == 8
                        out IO(DATA_PORT), reg_nextPixel    ; (L) Write pixel to data port
                        lpm reg_nextPixel, Z+               ; (H-L-H) Read next pixel from FLASH
                    #endif
                    out IO(DATA_PORT), reg_nextPixel        ; (L) Write pixel to data port
                    lpm reg_nextPixel, Z+                   ; (H-L-H) Read next pixel from FLASH
                    out IO(DATA_PORT), reg_nextPixel        ; (L) Write pixel to data port
                    lpm reg_nextPixel, Z+                   ; (H-L-H) Read next pixel from FLASH
                    out IO(DATA_PORT), reg_nextPixel        ; (L) Write pixel to data port
                    lpm reg_nextPixel, Z+                   ; (H-L-H) Read next pixel from FLASH

                    ld reg_temporary, X                     ; (H-L) Read sample from audio buffer
                    sts OCR2A, reg_temporary                ; (H-L) Store sample to PWM channel

                    ; Write 4 or 5 pixels, and increment tile pointer:

                    #if TILE_WIDTH == 8
                        out IO(DATA_PORT), reg_nextPixel    ; (L) Write pixel to data port
                        lpm reg_nextPixel, Z+               ; (H-L-H) Read next pixel from FLASH
                    #endif
                    out IO(DATA_PORT), reg_nextPixel        ; (L) Write pixel to data port
                    lpm reg_nextPixel, Z+                   ; (H-L-H) Read next pixel from FLASH
                    out IO(DATA_PORT), reg_nextPixel        ; (L) Write pixel to data port
                    lpm reg_nextPixel, Z+                   ; (H-L-H) Read next pixel from FLASH
                    out IO(DATA_PORT), reg_nextPixel        ; (L) Write pixel to data port
                    lpm reg_nextPixel, Z+                   ; (H-L-H) Read next pixel from FLASH

                    adiw YL, COLUMN_COUNT                   ; (L-H) Add 40 to tile pointer. This happens twice per tile so a total of 80 is added.
                    ldd reg_nextTile_l, Y+0                 ; (L-H) Read next tile pointer into register pair r21:r20 (low byte)

                    ; Write 4 or 5 pixels, and loop:

                    #if TILE_WIDTH == 8
                        out IO(DATA_PORT), reg_nextPixel    ; (L) Write pixel to data port
                        lpm reg_nextPixel, Z+               ; (H-L-H) Read next pixel from FLASH
                    #endif
                    out IO(DATA_PORT), reg_nextPixel        ; (L) Write pixel to data port
                    lpm reg_nextPixel, Z+                   ; (H-L-H) Read next pixel from FLASH
                    out IO(DATA_PORT), reg_nextPixel        ; (L) Write pixel to data port
                    lpm reg_nextPixel, Z+                   ; (H-L-H) Read next pixel from FLASH
                    out IO(DATA_PORT), reg_nextPixel        ; (L) Write pixel to data port
                    lpm reg_nextPixel, Z+                   ; (H-L-H) Read next pixel from FLASH

                    nop                                     ; (L) Synchronisation delay
                    dec reg_pixelOuterLoopCounter           ; (H) Decrement pixel_outer_loop counter
                    brne pixelOuterLoop                     ; (L-H / L) If counter hasn't reached zero, loop again
                    ldi reg_pixelOuterLoopCounter, 2        ; (H) Reset pixel_outer_loop counter for next time

                ;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Pixel outer loop (executed 2 times) ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

                ; Write 4 or 5 pixels, read the tile texture pointer, and decrement tile counter:

                #if TILE_WIDTH == 8
                    out IO(DATA_PORT), reg_nextPixel        ; (L) Write pixel to data port
                    lpm reg_nextPixel, Z+                   ; (H-L-H) Read next pixel from FLASH
                #endif
                out IO(DATA_PORT), reg_nextPixel            ; (L) Write pixel to data port
                lpm reg_nextPixel, Z+                       ; (H-L-H) Read next pixel from FLASH
                out IO(DATA_PORT), reg_nextPixel            ; (L) Write pixel to data port
                lpm reg_nextPixel, Z+                       ; (H-L-H) Read next pixel from FLASH
                out IO(DATA_PORT), reg_nextPixel            ; (L) Write pixel to data port
                lpm reg_nextPixel, Z+                       ; (H-L-H) Read next pixel from FLASH

                nop                                         ; (L) Synchronisation delay
                ldd reg_nextTile_h, Y+1                     ; (H-L) Read next tile pointer into register pair r21:r20 (high byte)
                dec reg_tilesRemainingInColumn              ; (H) Decrement tile counter

                ; Write 4 or 5 pixels, move tile texture pointer to Z register, and loop:

                #if TILE_WIDTH == 8
                    out IO(DATA_PORT), reg_nextPixel        ; (L) Write pixel to data port
                    lpm reg_nextPixel, Z+                   ; (H-L-H) Read next pixel from FLASH
                #endif
                out IO(DATA_PORT), reg_nextPixel            ; (L) Write pixel to data port
                lpm reg_nextPixel, Z+                       ; (H-L-H) Read next pixel from FLASH
                out IO(DATA_PORT), reg_nextPixel            ; (L) Write pixel to data port
                lpm reg_nextPixel, Z+                       ; (H-L-H) Read next pixel from FLASH
                out IO(DATA_PORT), reg_nextPixel            ; (L) Write pixel to data port

                movw ZL, reg_nextTile_l                     ; (H) Quick move next tile pointer to Z register
                lpm reg_nextPixel, Z+                       ; (H-L-H) Read next pixel from FLASH
                breq endOfColumn                            ; (H / H-L) If tile counter has reached zero, end the column
                rjmp tileLoop                               ; (L-H) Else, write the next tile

            ;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Tile loop (executed 28 times) ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

        ;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Write all tiles in the column (as RAMWR parameters) ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

        ;################################################ End of column ################################################
        ; 16/15 CPU cycles
        ; 26 bytes of FLASH

        endOfColumn:

            ; Disable timer
            out IO(TCCR0B), reg_timerDisable                    ; (H)

            ; Undo the last Z increment since we need to re-read the same pixel at the start of the next loop:
            sbiw ZL, 1                                          ; (H-H)

            ; Poll timer interrupt (must be done here to ensure the response time is less than 256 CPU cycles):
            in reg_temporary, IO(TIFR1)                         ; (H) Read TIMER1 interrupt flag register
            andi reg_temporary, (1 << TOV1)                     ; (H) Mask TOV1 (timer overflow) flag
            out IO(TIFR1), reg_temporary                        ; (H) If the flag was set, clear it
            add XL, reg_temporary                               ; (H) If the flag was set, add 1 to sample pointer (carry is propogated to high byte later)
            adc XH, reg_zero                                    ; (H) Propogate carry to sample pointer high byte
            ld reg_temporary, X                                 ; (H-H) Read sample from audio buffer
            sts OCR2A, reg_temporary                            ; (H-H) Store sample to PWM channel

            ; Decrement column counter
            dec reg_columnsRemaining                            ; (H)

            ; If column counter hasn't reached zero, execute the column loop again to write the next column:
            breq endOfScreen                                    ; (H / H-H) Skip the jump column counter has reached 0
            rjmp tileColumnLoop                                 ; (H-H) Jump back to start of column loop

        ;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ End of column ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    ;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Column loop (executed 40 or 30 times) ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    ;#################################################### Finish up ####################################################
    ; 30 CPU cycles
    ; 32 bytes of FLASH

    endOfScreen:

        ; Store updated audio sample pointer back:
        sts currentAudioSamplePtr, XL                       ; (H-H)
        sts currentAudioSamplePtr+1, XH                     ; (H-H)

        ; Generate a negative pulse on VSYNC signal:
        cbi IO(CONTROL_PORT), CONTROL_PORT_VSYNC            ; (H-H)
        sbi IO(CONTROL_PORT), CONTROL_PORT_VSYNC            ; (H-H)

        ; Restore global interrupt flag (and others, but they don't matter):
        out IO(SREG), reg_sregSave                          ; (H)

        ; Restore call-save registers that have been modified:
        pop YH                                              ; (H-H)
        pop YL                                              ; (H-H)
        pop r17                                             ; (H-H)
        pop r16                                             ; (H-H)
        pop r15                                             ; (H-H)
        pop r14                                             ; (H-H)
        pop r13                                             ; (H-H)
        pop r12                                             ; (H-H)

        ; Return from the function:
        ret                                                 ; (H-H-H-H-H)

    ;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Finish up ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ void writeScreen(void) ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~