TIMER1_COMPA_vect:

    ; Save registers that will be modified by ISR:
    push r24
    in r24, IO(SREG)
    push r24
    push r25
    push r30
    push r31

    ; Load audioBufferIndex and increment by one:
    lds r30, audioBufferIndex
    mov r24, r30 ; copy audioBufferIndex to r24

    ; Load sample in audioBuffer at audioBufferIndex:
    ldi r30, 0x00
    subi r30, lo8(audioBuffer)
    sbci r31, hi8(audioBuffer)
    ld r25, Z

    ; Store sample to OCR2A:
    sts OCR2A, r25

    subi r24, -1
    sts audioBufferIndex, r24

    ; if audioBufferIndex == AUDIO_BUFFER_SIZE - 1:
    cpi r24, AUDIO_BUFFER_SIZE - 1
    brne noFrame

        ldi r24, 0
        sts audioBufferIndex, r24

        ; Save call-used registers (might be modified by the following function):
        push r0
        push r1
        push r18
        push r19
      	push r20
      	push r21
      	push r22
      	push r23
      	push r26
      	push r27

        ; Set zero-register to zero, ready for the following function:
        clr r1

        ; Call function to handle the next frame:
        call handleNextFrame

        ; Restore call-used registers:
        pop r27
        pop r26
        pop r23
        pop r22
        pop r21
        pop r20
        pop r19
        pop r18
        pop r1
        pop r0

        rjmp finish

noFrame:

finish:

    ; Restore registers that were modified by ISR:
    pop r31
    pop r30
    pop r25
    pop r24
    out IO(SREG), r24
    pop r24

    ; Return from interrupt:
    reti
