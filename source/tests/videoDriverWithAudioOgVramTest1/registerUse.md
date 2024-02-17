- TCCR0B value to enable timer:      r12
    - ldi (once):            r16-r31
    - out:                    r0-r31

- TCCR0B value to disable timer:     r13
    - ldi (once):            r16-r31
    - out:                    r0-r31

- next tile pointer low byte:        r14
    - ld:                     r0-r31
    - movw:                   r0,r2...r28, r30

- next tile pointer high byte:       r15
    - ld:                     r0-r31
    - register pair with next tile pointer low byte

- columns remaining:                 r16
    - ldi (once):            r16-r31
    - dec:                    r0-r31

- temporary register:                r17
    - ldi:                   r16-r31
    - out:                    r0-r31
    - ld:                     r0-r31
    - sts:                    r0-r31

- pixel outer loop counter:          r18
    - ldi:                   r16-r31
    - dec:                    r0-r31

- pixel inner loop counter:          r19
    - ldi:                   r16-r31
    - dec:                    r0-r31

- tiles remaining:                   r20
    - ldi (once per column): r16-r31
    - dec:                    r0-r31

- next pixel:                        r21
    - out:                    r0-r31
    - lpm:                    r0-r31

- start-column low byte:             r22
    - ldi (once):            r16-r31
    - out:                    r0-r31
    - subi:                  r16-r31

- start-column high byte:            r23
    - ldi (once):            r16-r31
    - out:                    r0-r31
    - subci:                 r16-r31

- end-column low byte:               r24
    - ldi (once):            r16-r31
    - out:                    r0-r31
    - adiw:                  r24,r26,r28,r30

- end-column high byte:              r25
    - ldi (once):            r16-r31
    - out:                    r0-r31
    - register pair with end-column low byte
