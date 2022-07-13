;******************************************************************************
;                        RS-232 DIGITAL INPUT/OUTPUT
;                  Copyright (c) 1996 by Weeder Technologies
;                           Model  : WTDIO
;                           Author : Terry J. Weeder
;                           Date   : November 12, 1996
;                           Version: 1.0
;******************************************************************************

;watchdog disabled

list    P=16C55

include "ascii.equ"

ind     equ     0h
rtcc    equ     1h
pc      equ     2h
status  equ     3h
fsr     equ     4h
port_a  equ     5h
port_b  equ     6h
port_c  equ     7h
c       equ     0h
dc      equ     1h
z       equ     2h
pd      equ     3h
to      equ     4h
MSB     equ     7h
LSB     equ     0h

ct      equ     0h              ;com transmit data
cr      equ     1h              ;com receive data
dtr     equ     2h              ;com dtr
led     equ     3h              ;red LED
mx      equ     7h              ;matrix enable pin in status register

count   equ     8h
count2  equ     9h
com_reg equ     0Ah             ;data to/from com port
temp1   equ     0Bh             ;temporary register
temp2   equ     0Ch             ;temporary register
pin_dir1        equ     0Dh             ;direction of port_b pins
pin_dir2        equ     0Eh             ;direction of port_c pins
config1 equ     0Fh             ;button and/or switch configuration
config2 equ     10h             ;button and/or switch configuration
butt1   equ     11h             ;pins set up for button on port_b
butt2   equ     12h             ;pins set up for button on port_c
sw1     equ     13h             ;pins set up for switch on port_b
sw2     equ     14h             ;pins set up for switch on port_c
old_sw1 equ     15h             ;last state of switches on port_b
old_sw2 equ     16h             ;last state of switches on port_c
command equ     17h             ;operation from com port
pin     equ     18h             ;pin number from com port
pin2    equ     19h             ;second pin used in matrix routine
state   equ     1Ah             ;state of pin
pause   equ     1Bh             ;delay used in debnc

        org     1FF
        goto    start
        org     0

header  movlw   0x0A            ;loop for 8.3ms (10 bits)
        movwf   count
        clrf    rtcc
hdr1    call    delay
        btfsc   port_a,cr       ;restart loop if com port busy
        goto    header
        decfsz  count
        goto    hdr1            ;end loop
        movlw   _D              ;send header character
        goto    com_t

addrs   swapf   port_c,w                ;read address from S1
        andlw   b'00001111'     ;strip off high nibble
        iorlw   b'01000000'     ;convert to ascii character
        movwf   temp1           ;fix address
        incf    temp1,w
        goto    com_t           ;send address

footer  movlw   _cr             ;send carriage return
        goto    com_t

delay   movlw   0x67            ;delay 1 bit
        xorwf   rtcc,w
        btfss   status,z
        goto    delay
        clrf    rtcc
        retlw   0x00

debnc   movlw   b'00000111'     ;rtcc = internal, prescaler = 1/256
        option
        clrf    rtcc
db1     movf    pause,w         ;get delay value (65ms or 32ms)
        xorwf   rtcc,w
        btfss   status,z
        goto    db1
        movlw   b'00000010'     ;rtcc = internal, prescaler = 1/8
        option
        retlw   0x00

pin_read        movwf   count           ;read state of pins
        movf    port_b,w
        movwf   temp1
        movf    port_c,w
        movwf   temp2
pr1     rrf     temp2
        rrf     temp1
        decfsz  count
        goto    pr1
        retlw   0x00

pin_hi  clrf    temp1           ;set pin high
        clrf    temp2
        movf    pin,w           ;get pin #
        movwf   count
        bsf     status,c
ph1     rlf     temp1
        rlf     temp2
        decfsz  count
        goto    ph1
        movf    temp1,w         ;output high to port_b
        iorwf   port_b
        comf    temp1,w         ;set pin for output
        andwf   pin_dir1
        movf    temp2,w         ;output high to port_c
        iorwf   port_c
        comf    temp2,w         ;set pin for output
        andwf   pin_dir2
        goto    clear           ;clear former pin assignment

pin_lo  clrf    temp1           ;set pin low
        clrf    temp2
        movf    pin,w           ;get pin #
        movwf   count
        bsf     status,c
pl1     rlf     temp1
        rlf     temp2
        decfsz  count
        goto    pl1
        comf    temp1,w         ;output low to port_b
        andwf   port_b
        andwf   pin_dir1                ;set pin for output
        comf    temp2,w         ;output low to port_c
        andwf   port_c
        andwf   pin_dir2                ;set pin for output
        goto    clear           ;clear former pin assignment

pin_in  clrf    temp1           ;set pin for input
        clrf    temp2
        movf    pin,w           ;get pin #
        movwf   count
        bsf     status,c
pi1     rlf     temp1
        rlf     temp2
        decfsz  count
        goto    pi1
        movf    temp1,w         ;update pin direction
        iorwf   pin_dir1
        movf    temp2,w         ;update pin direction
        iorwf   pin_dir2
        goto    clear           ;clear former pin assignment

clear   comf    temp1,w         ;clear pin assignment on port_b
        andwf   butt1           ;disable for button
        andwf   sw1             ;disable for switch
        comf    temp2,w         ;clear pin assignment on port_c
        andwf   butt2           ;disable for button
        andwf   sw2             ;disable for switch
        retlw   0x00

com_t   movwf   com_reg
        bsf     port_a,led      ;turn on LED
        movlw   0x08            ;8 data bits
        movwf   count
        clrf    rtcc
        bcf     port_a,ct       ;start bit
        call    delay           ;delay 1 bit
ct1     bcf     port_a,ct
        rrf     com_reg         ;transmit data bit
        btfsc   status,c
        bsf     port_a,ct
        call    delay           ;delay 1 bit
        decfsz  count
        goto    ct1
        bsf     port_a,ct       ;stop bit
        call    delay           ;delay 1 bit
        bcf     port_a,led      ;turn off LED
        retlw   0x00

com_r   btfss   port_a,dtr      ;abort if com port not active
        goto    run
        bsf     port_a,led      ;turn on LED
        btfss   port_a,cr       ;look for start bit
        goto    com_r           ;loop until start bit received
        clrf    rtcc
cr1     movlw   0x33            ;delay 1/2 bit
        xorwf   rtcc,w
        btfss   status,z
        goto    cr1
        clrf    rtcc
        btfss   port_a,cr       ;verify start bit
        goto    run             ;abort if no start bit
        movlw   0x08            ;8 data bits
        movwf   count
cr2     call    delay           ;delay 1 bit
        bcf     status,c                ;get data bit
        rrf     com_reg
        btfsc   port_a,cr
        bsf     com_reg,MSB
        decfsz  count
        goto    cr2             ;get next data bit
        comf    com_reg         ;correct for inverted RS-232 data
cr3     btfsc   port_a,cr       ;wait for stop bit
        goto    cr3
        bcf     port_a,led      ;turn off LED
        movlw   _cr             ;test for carriage return
        xorwf   com_reg,w
        btfsc   status,z
        goto    run
        retlw   0x00

;******************************************************************************
;                                   START
;******************************************************************************

start   movlw   b'00000010'     ;rtcc = internal, prescaler = 1/8
        option
        bsf     port_a,ct       ;assure stop bit on com port
        clrf    butt1           ;disable all buttons
        clrf    butt2
        clrf    sw1             ;disable all switches
        clrf    sw2
        movlw   b'11111111'
        movwf   pin_dir1                ;initialize port_b for input
        movwf   pin_dir2                ;initialize port_c for input

run     bcf     port_a,led      ;assure led is off
        movlw   b'11110110'     ;set direction of port_a
        tris    port_a
        movf    pin_dir1,w      ;set direction of port_b
        tris    port_b
        movf    pin_dir2,w      ;set direction of port_c
        tris    port_c
        btfsc   port_a,cr       ;look for start bit
        goto    rec             ;get string from com port

b1      movf    butt1,w         ;read button configuration
        movwf   config1
        movf    butt2,w
        movwf   config2
        clrf    pin
b2      btfsc   port_a,cr       ;look for start bit
        goto    rec             ;get string from com port
        incf    pin
        movlw   0x0D            ;exit loop if beyond pin 12
        xorwf   pin,w
        btfsc   status,z
        goto    s1
        rrf     config2         ;test if pin set for button
        rrf     config1
        btfss   status,c
        goto    b2              ;test next pin if not
        movf    pin,w           ;get pin #
        call    pin_read                ;read state of pin
        btfsc   status,c                ;test if button pressed
        goto    b2              ;look for next pin set for button
        call    debnc
        movf    pin,w           ;test if button still pressed
        call    pin_read
        btfsc   status,c
        goto    b2              ;look for next pin set for button
        movlw   _L              ;set state of pin
        movwf   state
        goto    xmit

s1      movf    sw1,w           ;read switch configuration
        movwf   config1
        movf    sw2,w
        movwf   config2
        clrf    pin
s2      btfsc   port_a,cr       ;look for start bit
        goto    rec             ;get string from com port
        incf    pin
        movlw   0x0D            ;exit loop if beyond pin 12
        xorwf   pin,w
        btfsc   status,z
        goto    m1
        rrf     config2         ;test if pin set for switch
        rrf     config1
        btfss   status,c
        goto    s2              ;test next pin if not
        movf    old_sw1,w       ;get last state of switch
        movwf   temp1
        movf    old_sw2,w
        movwf   temp2
        movf    pin,w           ;get pin #
        movwf   count
s3      rrf     temp2
        rrf     temp1
        decfsz  count
        goto    s3
        btfss   status,c                ;read last state of switch
        goto    s5
        movf    pin,w           ;get pin #
        call    pin_read                ;read state of pin
        btfsc   status,c                ;test if change of state
        goto    s2              ;look for next pin set for switch
        call    debnc
        movf    pin,w           ;test if still change of state
        call    pin_read
        btfsc   status,c
        goto    s2              ;look for next pin set for switch
        movf    pin,w           ;set last state to low
        movwf   count
        movlw   b'11111111'
        movwf   temp1
        movwf   temp2
s4      rlf     temp1
        rlf     temp2
        decfsz  count
        goto    s4
        movf    temp1,w         ;save last state
        andwf   old_sw1
        movf    temp2,w
        andwf   old_sw2
        movlw   _L              ;set state of pin
        movwf   state
        goto    xmit
s5      movf    pin,w           ;get pin #
        call    pin_read                ;read state of pin
        btfss   status,c                ;test if change of state
        goto    s2              ;look for next switch
        call    debnc
        movf    pin,w           ;test if still change of state
        call    pin_read
        btfss   status,c
        goto    s2              ;look for next pin set for switch
        movf    pin,w           ;set last state to high
        movwf   count
        clrf    temp1
        clrf    temp2
s6      rlf     temp1
        rlf     temp2
        decfsz  count
        goto    s6
        movf    temp1,w         ;save last state
        iorwf   old_sw1
        movf    temp2,w
        iorwf   old_sw2
        movlw   _H              ;set state of pin
        movwf   state
        goto    xmit

m1      btfss   status,mx       ;test if matrix enabled
        goto    repeat          ;skip if not
        movlw   0x04            ;start row at pin #4
        movwf   pin
m2      btfsc   port_a,cr       ;look for start bit
        goto    rec             ;get string from com port
        movlw   b'00001111'     ;set row pins high
        movwf   port_b
        call    pin_lo          ;set row pin low
        movlw   0x08            ;start column at pin #8
        movwf   pin2
m3      movf    pin2,w          ;test if button pressed
        call    pin_read
        btfss   status,c
        goto    m4              ;send to com port if true
        decf    pin2            ;set for next column
        movlw   0x04            ;test if all columns checked
        xorwf   pin2,w
        btfss   status,z
        goto    m3
        decfsz  pin             ;set for next row
        goto    m2
        goto    repeat          ;exit loop if no button pressed
m4      call    debnc
        movf    pin2,w          ;test if button still pressed
        call    pin_read
        btfsc   status,c
        goto    repeat
        call    header          ;send header to com port
        call    addrs           ;send address to com port
        movlw   _M              ;send event indicator
        call    com_t
        movlw   0x40            ;send row #
        iorwf   pin,w
        call    com_t
        movlw   0x40            ;send column #
        iorwf   pin2,w
        call    com_t
        call    footer          ;send carriage return
        call    debnc
        call    debnc
        call    debnc
        call    debnc
        movlw   0x7F            ;set debnc to 32ms
        movwf   pause
        goto    run

repeat  movlw   0xFF            ;set debnc back to 65ms
        movwf   pause
        goto    run

xmit    call    header          ;send header to com port
        call    addrs           ;send address to com port
        movlw   0x40            ;convert pin number to ascii and
        addwf   pin,w           ;send pin number
        call    com_t
        movf    state,w         ;send state of pin
        call    com_t
        call    footer          ;send carriage return
        call    debnc           ;delay before repeat
        call    debnc
        call    debnc
        call    debnc
        movlw   0x7F            ;set debnc to 32ms
        movwf   pause
        goto    run

rec     call    com_r           ;get first character
        movlw   _D              ;test for header character
        xorwf   com_reg,w
        btfss   status,z
        goto    discard
        call    com_r           ;get address from com port
        decf    com_reg         ;fix address
        swapf   port_c,w                ;read address from S1
        andlw   b'00001111'     ;strip off high nibble
        iorlw   0x40            ;convert to ascii character
        xorwf   com_reg,w       ;test if matching address
        btfss   status,z
        goto    discard
        call    com_r           ;get command character
        movf    com_reg,w
        movwf   command
        movlw   _M              ;test if "matrix" operation
        xorwf   command,w
        btfsc   status,z
        goto    matrix
        movlw   _R              ;test if "read" operation
        xorwf   command,w
        btfsc   status,z
        goto    read
        movlw   _W              ;test if "write" operation
        xorwf   command,w
        btfsc   status,z
        goto    write
        call    com_r           ;get pin number
        movlw   _A              ;abort if pin number < range
        subwf   com_reg,w
        btfss   status,c
        goto    discard
        movlw   _I              ;test if pin number on port_b
        subwf   com_reg,w
        btfss   status,c
        bcf     status,mx       ;disable matrix if true
        movlw   _M              ;abort if pin number > range
        subwf   com_reg,w
        btfsc   status,c
        goto    discard
        movlw   b'00001111'     ;strip off high nibble
        andwf   com_reg,w
        movwf   pin             ;store in register
        movlw   _H              ;test if "high" operation
        xorwf   command,w
        btfsc   status,z
        goto    high
        movlw   _L              ;test if "low" operation
        xorwf   command,w
        btfsc   status,z
        goto    low
        movlw   _T              ;test if "toggle" operation
        xorwf   command,w
        btfsc   status,z
        goto    toggle
        movlw   _B              ;test if "button" operation
        xorwf   command,w
        btfsc   status,z
        goto    button
        movlw   _S              ;test if "switch" operation
        xorwf   command,w
        btfsc   status,z
        goto    switch
        goto    discard

high    call    pin_hi          ;set pin high
        goto    discard         ;discard carriage return

low     call    pin_lo          ;set pin low
        goto    discard         ;discard carriage return

toggle  movf    pin,w           ;get pin #
        call    pin_read                ;read current state of pin
        btfss   status,c
        goto    t2
        call    pin_lo          ;set pin low
        goto    discard         ;discard carriage return
t2      call    pin_hi          ;set pin high
        goto    discard         ;discard carriage return

button  call    pin_in          ;set pin for input
        movf    temp1,w         ;set pin for button on port_b
        iorwf   butt1
        movf    temp2,w         ;set pin for button on port_c
        iorwf   butt2
        goto    discard         ;discard carriage return

switch  call    pin_in          ;set pin for input
        movf    temp1,w         ;set pin for switch on port_b
        iorwf   sw1
        movf    temp2,w         ;set pin for switch on port_c
        iorwf   sw2
        goto    discard         ;discard carriage return

matrix  bsf     status,mx       ;enable matrix
        clrf    butt1           ;disable buttons on port_b
        clrf    sw1             ;disable switches on port_b
        movlw   b'11110000'     ;set pin direction of port_b
        movwf   pin_dir1
        goto    discard         ;discard carriage return

read    call    com_r           ;get pin # to read
        movlw   _P              ;test if "port"
        xorwf   com_reg,w
        btfsc   status,z
        goto    rd2
        movlw   b'00001111'     ;strip off high nibble
        andwf   com_reg,w
        movwf   pin
        call    pin_read                ;read state of pin
        btfsc   status,c
        goto    rd1
        movlw   _L
        movwf   state
        goto    xmit
rd1     movlw   _H
        movwf   state
        goto    xmit
rd2     call    header          ;send header to com port
        call    addrs           ;send address to com port
        movf    port_b,w                ;read byte from port_b
        call    com_t           ;send byte to com port
        call    footer          ;send carriage return
        goto    run

write   bcf     status,mx       ;disable matrix
        clrf    butt1           ;disable buttons on port_b
        clrf    sw1             ;disable switches on port_b
        clrf    pin_dir1                ;set pins for output
        call    com_r           ;get format from com port
        movlw   0x24            ;test if ascii format
        xorwf   com_reg,w
        btfsc   status,z
        goto    wt1
        movlw   _h              ;test if hex format
        xorwf   com_reg,w
        btfsc   status,z
        goto    wt2
        movlw   _b              ;test if binary format
        xorwf   com_reg,w
        btfsc   status,z
        goto    wt3
        goto    discard
wt1     call    com_r           ;get byte from com port
        movf    com_reg,w
        movwf   port_b          ;output byte to port b
        goto    discard         ;discard carriage return
wt2     call    com_r           ;get first character
        clrw
        btfsc   com_reg,6       ;test if > 9
        movlw   0x09            ;add 9 if true
        addwf   com_reg
        swapf   com_reg,w       ;store in register
        andlw   b'11110000'     ;strip off low nibble
        movwf   temp1
        call    com_r           ;get second character
        clrw
        btfsc   com_reg,6       ;test if > 9
        movlw   0x09            ;add 9 if true
        addwf   com_reg,w
        andlw   b'00001111'     ;strip off high nibble
        addwf   temp1,w         ;combine with first character
        movwf   port_b          ;send to port b
        goto    discard         ;discard carriage return
wt3     movlw   0x08            ;receive 8 characters
        movwf   count2
wt4     call    com_r           ;get character from com port
        bcf     status,c                ;initialize carry bit
        btfsc   com_reg,0       ;read logic level
        bsf     status,c
        rlf     temp1           ;rotate into register
        decfsz  count2
        goto    wt4
        movf    temp1,w         ;send to port b
        movwf   port_b
        goto    discard         ;discard carriage return

discard call    com_r           ;get next character
        goto    discard         ;loop until carriage return detected

        end
