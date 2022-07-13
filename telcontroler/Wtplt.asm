;******************************************************************************
;                            PHONE LINE TRANSPONDER
;                  Copyright (c) 1997 by Weeder Technologies
;                           Model  : WTPLT
;                           Author : Terry J. Weeder
;                           Date   : November 12, 1997
;                           Version: 1.0
;******************************************************************************

;watchdog disabled

list	P=16C55

ind	equ	0h
rtcc	equ	1h
pc	equ	2h
status	equ	3h
fsr	equ	4h
port_a	equ	5h
port_b	equ	6h
port_c	equ	7h
c	equ	0h
dc	equ	1h
z	equ	2h
pd	equ	3h
to	equ	4h
MSB	equ	7h
LSB	equ	0h

di	equ	2h		;eeprom data input
do	equ	2h		;eeprom data output
clk	equ	1h		;eeprom clock input
cs	equ	0h		;eeprom chip select
pw	equ	3h		;pulse-width-modulation output
dv	equ	4h		;MC145436 data valid pin
rd	equ	5h		;ring detect pin
hs	equ	6h		;hook switch pin
mic	equ	7h		;turn mic on/off

count	equ	8h
count2	equ	9h
count3	equ	0Ah
count4	equ	0Bh
tone1	equ	0Ch		;angular position of tone 1
tone2	equ	0Dh		;angular position of tone 2
pwm_hi	equ	0Eh		;high duty cycle
pwm_lo	equ	0Fh		;low duty cycle
temp	equ	10h		;temporary register used in subs
angle1	equ	11h		;angle jump for tone 1
angle2	equ	12h		;angle jump for tone 2
num	equ	13h		;received dtmf tones
mem_reg	equ	14h		;used to read/write eeprom
addrs	equ	15h		;address of eeprom
type	equ	16h		;toggle/momentary config

	org	1FF
	goto	start
	org	0

beep	movlw	0x08
	movwf	tone2
	movlw	0x1B		;set for 1100 Hz tone
	movwf	angle1
	clrf	angle2
	goto	beep2		;send tone

pause1	movlw	0x04		;pause 1 sec
	movwf	count3
	clrf	count2
	clrf	count
ps1	decfsz	count
	goto	ps1
	decfsz	count2
	goto	ps1
	decfsz	count3
	goto	ps1
	retlw	0x00

pause2	movlw	0x09		;pause 2 sec
	movwf	count3
	clrf	count2
	clrf	count
ps2	decfsz	count
	goto	ps2
	decfsz	count2
	goto	ps2
	decfsz	count3
	goto	ps2
	retlw	0x00

toggle	clrf	temp		;toggle state of pin
	movf	num,w		;get pin number
	movwf	count
	bsf	status,c
tg1	rlf	temp
	decfsz	count
	goto	tg1
	movf	temp,w		;output new state to port_c
	xorwf	port_c
	retlw	0x00

dtmf	movlw	0x52		;time-out period = 30 sec
	movwf	count3
	clrf	count2
	clrf	count
dt1	btfsc	port_b,dv	;wait for valid dtmf tone
	goto	dt2
	decfsz	count
	goto	dt1
	decfsz	count2
	goto	dt1
	decfsz	count3
	goto	dt1
	goto	run		;abort if no tone within time-out period
dt2	movf	port_b,w		;read tone
	andlw	b'00001111'	;strip off unused bits
	movwf	num
dt3	btfsc	port_b,4		;wait for end of tone
	goto	dt3
	retlw	0x00

pair	addwf	pc		;get row and col of tone pair
	nop
	retlw	0x00
	retlw	0x01
	retlw	0x02
	retlw	0x10
	retlw	0x11
	retlw	0x12
	retlw	0x20
	retlw	0x21
	retlw	0x22
	retlw	0x31

row	swapf	temp,w		;get row address
	andlw	b'00001111'	;strip off col address
	addwf	pc
	retlw	0x11
	retlw	0x13
	retlw	0x15
	retlw	0x17

col	movf	temp,w		;get col address
	andlw	b'00001111'	;strip off row address
	addwf	pc
	retlw	0x1E
	retlw	0x21
	retlw	0x24

sine	movwf	temp		;pattern for generating sine wave
	rrf	temp
	rrf	temp,w
	andlw	b'00011111'
	addwf	pc
	retlw	0x08
	retlw	0x09
	retlw	0x0B
	retlw	0x0C
	retlw	0x0D
	retlw	0x0E
	retlw	0x0F
	retlw	0x0F
	retlw	0x0F
	retlw	0x0F
	retlw	0x0F
	retlw	0x0E
	retlw	0x0D
	retlw	0x0C
	retlw	0x0B
	retlw	0x09
	retlw	0x08
	retlw	0x07
	retlw	0x05
	retlw	0x04
	retlw	0x03
	retlw	0x02
	retlw	0x01
	retlw	0x01
	retlw	0x01
	retlw	0x01
	retlw	0x01
	retlw	0x02
	retlw	0x03
	retlw	0x04
	retlw	0x05
	retlw	0x07

;pwm factor = 40.647 @ 3.58 MHz clk

pwm	call	pair		;get tone pair
	movwf	temp
	call	row		;get and load low tone
	movwf	angle1
	call	col		;get and load high tone
	movwf	angle2
beep2	movlw	0x04		;set duration of tone for 98 ms
	movwf	count2
	clrf	count
	movlw	b'11110100'
	tris	port_a
pw1	movf	angle1,w		;add angle of tone1
	addwf	tone1
	rrf	tone1,w		;use most significant bits
	call	sine		;get pwm "high" value
	bcf	port_a,pw	;set pin low
	movwf	pwm_hi
	movf	angle2,w		;add angle of tone2
	addwf	tone2
	rrf	tone2,w		;use most significant bits
	call	sine		;get pwm "high" value
	addwf	pwm_hi		;calculate average "high" value
	rrf	pwm_hi
	movf	pwm_hi,w		;set pwm "low" value
	iorlw	b'11110000'
	movwf	pwm_lo
pw2	incfsz	pwm_lo
	goto	pw2
	bsf	port_a,pw	;set pin high
pw3	decfsz	pwm_hi
	goto	pw3
	nop
	decfsz	count
	goto	pw4
	decfsz	count2
pw4	goto	pw1
	movlw	0x74		;pause 100 ms
	movwf	count2
	clrf	count
pw5	decfsz	count
	goto	pw5
	decfsz	count2
	goto	pw5		;end pause
	retlw	0x00

clock	bsf	port_a,clk	;clk high
	bcf	port_a,clk	;clk low
	retlw	0x00

read	movlw	b'11110000'	;93LC46, 128x8
	tris	port_a
	bsf	port_a,cs	;select chip
	bsf	port_a,di	;start bit
	call	clock		;toggle clock pin
	call	clock		;toggle clock pin
	bcf	port_a,di
	call	clock		;toggle clock pin
	rlf	addrs		;setup address for 7 bits
	movlw	0x07		;7 address bits
	movwf	count
rd1	bcf	port_a,di
	rlf	addrs		;get next address bit
	btfsc	status,c
	bsf	port_a,di
	call	clock		;toggle clock pin
	decfsz	count
	goto	rd1
	rlf	addrs		;set back to original
	movlw	b'11110100'	;change to input
	tris	port_a
	movlw	0x08		;8 data bits
	movwf	count
rd2	call	clock		;toggle clock pin
	bcf	status,c
	rlf	mem_reg
	btfsc	port_a,do	;get next data bit
	bsf	mem_reg,LSB
	decfsz	count
	goto	rd2
	bcf	port_a,cs	;deselect chip
	incf	addrs
	retlw	0x00

write	movwf	mem_reg		;93LC46, 128x8
	movlw	b'11110000'
	tris	port_a
	bsf	port_a,cs	;select chip
	bsf	port_a,di	;start bit
	call	clock		;toggle clock pin
	bcf	port_a,di	;write enable
	call	clock		;toggle clock pin
	call	clock		;toggle clock pin
	bsf	port_a,di
	movlw	0x07
	movwf	count
wt1	call	clock		;toggle clock pin
	decfsz	count
	goto	wt1
	bcf	port_a,cs	;deselect chip
	bsf	port_a,cs	;select chip
	bsf	port_a,di	;start bit
	call	clock		;toggle clock pin
	bcf	port_a,di	;opcode
	call	clock		;toggle clock pin
	bsf	port_a,di
	call	clock		;toggle clock pin
	rlf	addrs		;setup address for 7 bits
	movlw	0x07		;7 address bits
	movwf	count
wt2	bcf	port_a,di
	rlf	addrs		;get next address bit
	btfsc	status,c
	bsf	port_a,di
	call	clock		;toggle clock pin
	decfsz	count
	goto	wt2
	rlf	addrs		;set back to original
	movlw	0x08		;8 data bits
	movwf	count
wt3	bcf	port_a,di
	rlf	mem_reg		;output next data bit
	btfsc	status,c
	bsf	port_a,di
	call	clock		;toggle clock pin
	decfsz	count
	goto	wt3
	bcf	port_a,cs	;deselect chip
	movlw	b'11110100'	;change to input
	tris	port_a
	bsf	port_a,cs	;select chip
wt4	btfss	port_a,do	;test for ready condition
	goto	wt4
	bcf	port_a,cs	;deselect chip
	movlw	b'11110000'	;change to output
	tris	port_a
	bsf	port_a,cs	;select chip
	bsf	port_a,di	;start bit
	call	clock		;toggle clock pin
	bcf	port_a,di	;write disable
	movlw	0x09
	movwf	count
wt5	call	clock		;toggle clock pin
	decfsz	count
	goto	wt5
	bcf	port_a,cs	;deselect chip
	incfsz	addrs
	retlw	0x00
	goto	error		;error if out of memory

;******************************************************************************
;                                    START
;******************************************************************************

start	clrf	port_a
	movlw	b'11110100'
	tris	port_a
	clrf	port_c
	movlw	b'01110000'	;toggle/momentary config (1=mom, 0=tog)
	movwf	type
	
run	movlw	b'00111111'
	tris	port_b
	movlw	b'10000000'
	tris	port_c
	bsf	port_a,pw	;set Q1 for high impedance
	bcf	port_b,mic	;turn off mic
	bcf	port_b,hs	;place phone on hook
	btfss	port_b,rd	;check for ring-detect
	goto	ring
	btfsc	port_b,dv	;check for dtmf tone
	goto	unlock
	btfsc	port_c,7		;check for dialout trigger
	goto	dialout
	bcf	status,6		;reset dialout indicator if false
	goto	run
	
ring	movlw	0x04		;verify ring pulse for 5.7 ms
	movwf	count2
	clrf	count
rg1	btfsc	port_b,rd	;check if ring pulse dropout
	goto	run		;abort if true
	decfsz	count
	goto	rg1
	decfsz	count2
	goto	rg1		;end delay
	bsf	port_b,hs	;answer telephone
	call	pause2
	call	beep		;send acknowledgment beeps
	call	beep
unlock	call	dtmf		;listen for "#" character
	movlw	b'00001100'
	xorwf	num,w
	btfss	status,z
	goto	run		;hang up and abort if not "#" character
ul1	bcf	status,7		;clear "wrong password" flag
	clrf	addrs		;set eeprom address to password
ul2	call	read		;test if complete password entered
	movlw	0xFF
	xorwf	mem_reg,w
	btfsc	status,z
	goto	ul3
	call	dtmf		;get dtmf tone
	movf	mem_reg,w	;test if correct digit in password
	xorwf	num,w
	btfss	status,z
	bsf	status,7		;set flag if not
	goto	ul2		;get next digit
ul3	btfss	status,7		;check if correct password
	goto	main
	call	beep		;send error beeps and
	call	beep
	call	beep
	call	beep
	goto	run		;hang up and abort if wrong password

main	btfss	port_b,mic	;test if mic is on
	goto	mn1
	movlw	b'11111100'	;set pwm pin for high impedence if true
	tris	port_a
	goto	mn2
mn1	movlw	b'11110100'
	tris	port_a
mn2	movlw	0x05		;5 minutes before disconnect
	movwf	count4
	clrf	count2
	clrf	count
mn3	movlw	0xA3
	movwf	count3
mn4	btfsc	port_b,dv	;watch for dtmf tone
	goto	mn5
	decfsz	count
	goto	mn4
	decfsz	count2
	goto	mn4
	decfsz	count3
	goto	mn4
	decfsz	count4
	goto	mn3		;end delay
	goto	run		;hang up if no tone received
mn5	movf	port_b,w		;read tone
	andlw	b'00001111'	;strip off unused bits
	movwf	num
	movlw	b'00001011'	;test if "*"
	xorwf	num,w
	btfsc	status,z
	goto	program		;goto program if true
	movlw	b'00001010'	;test if "0"
	xorwf	num,w
	btfsc	status,z
	goto	run		;hang up if true
	movlw	b'00001100'	;test if "#"
	xorwf	num,w
	btfsc	status,z
	goto	read_pin		;read pin if true
	movlw	b'00001001'	;test if "9"
	xorwf	num,w
	btfss	status,z
	goto	action
	movlw	b'10000000'	;toggle state of mic if true
	xorwf	port_b
	call	dtmf		;discard "9"
	goto	main

dialout	btfsc	status,6		;test if already done
	goto	run		;abort if true
	bsf	status,6
	movlw	0x09		;set eeprom address to number
	movwf	addrs
do1	bcf	port_b,hs	;place phone back on-hook if off
	call	pause2
	call	pause2
	bsf	port_b,hs	;take phone off-hook
do2	call	pause2
do3	call	read		;get telephone number to be dialed
	movlw	b'00001011'	;test if "*"
	xorwf	mem_reg,w
	btfsc	status,z
	goto	do2		;delay 2 seconds if true
	movlw	b'00001100'	;test if "#"
	xorwf	mem_reg,w
	btfsc	status,z
	goto	do4		;end if true
	movlw	b'00001101'	;test if invalid number
	subwf	mem_reg,w
	btfsc	status,c
	goto	run		;abort if true
	movf	mem_reg,w
	call	pwm		;dial digit
	goto	do3		;get next digit of number
do4	movlw	0x1F		;wait 60 seconds for answer
	movwf	count4
	clrf	count2
	clrf	count
do5	movlw	0x05
	movwf	count3
do6	btfsc	port_b,dv	;test if dtmf tone present
	goto	unlock		;get password if true
	decfsz	count
	goto	do6
	decfsz	count2
	goto	do6
	decfsz	count3
	goto	do6
	call	beep		;send beep
	decfsz	count4
	goto	do5
	call	read		;get next digit
	movlw	b'00001100'	;test for second "#"
	xorwf	mem_reg,w
	btfsc	status,z
	goto	run		;hang up and reset if true
	decf	addrs		;set address back and
	goto	do1		;dial next number if false

action	call	toggle		;toggle state of pin
act1	btfsc	port_b,dv	;wait for end of tone
	goto	act1
	movf	temp,w		;test if set for momentary
	andwf	type,w
	btfss	status,z
	call	toggle		;return to original state if true
	goto	main

read_pin	call	dtmf		;discard "#" character
	call	dtmf		;get pin number
	call	pause1
	movlw	0x09		;test if > 8
	subwf	num,w
	btfsc	status,c
	goto	error		;error if true
	movf	num,w		;read state of pins
	movwf	count
	movf	port_c,w
	movwf	temp
rp1	rrf	temp
	decfsz	count
	goto	rp1
	btfsc	status,c		;test if high
	call	beep		;send two beeps if true
	call	beep
	goto	main

program	call	dtmf		;discard "*" character
	call	dtmf		;get next character
	movlw	b'00001100'	;test if "#"
	xorwf	num,w
	btfsc	status,z
	goto	password
	movlw	b'00001011'	;test if "*"
	xorwf	num,w
	btfsc	status,z
	goto	number
	goto	error

number	bcf	status,6		;reset dialout indicator
	movlw	0x09		;set epprom address to number
	movwf	addrs
nm1	call	dtmf		;get number to be dialed
	movf	num,w		;store digit in eeprom
	call	write
	movlw	b'00001100'	;test if "#"
	xorwf	num,w
	btfss	status,z
	goto	nm1		;get next digit
	call	dtmf		;get next number
	movf	num,w		;store number in eeprom
	call	write
	movlw	b'00001100'	;test for second "#"
	xorwf	num,w
	btfss	status,z
	goto	nm1		;get next digit
	goto	ack

password	movlw	0x17		;set fsr for password entry
	movwf	fsr
pwd1	call	dtmf		;get digit in new password
	movf	num,w		;store in ram
	movwf	ind
	movlw	b'00001100'	;test if "#"
	xorwf	num,w
	btfsc	status,z
	goto	pwd2		;write new password to eeprom if true
	incf	fsr		;move to next ram address
	btfsc	fsr,4		;test if more then 8 digits entered
	goto	pwd1		;get next digit if false
	goto	error		;error if true
pwd2	movlw	0xFF		;end of password character
	movwf	ind
	clrf	addrs		;set eeprom address to password
	movlw	0x17		;set ram address to new password
	movwf	fsr
pwd3	movf	ind,w		;write new password to eeprom
	call	write
	incf	ind,w		;test for end of password character
	btfsc	status,z
	goto	ack		;end if true
	incf	fsr		;move to next password character
	goto	pwd3

ack	call	pause1		;send acknowledgment beeps
	call	beep
	call	beep
	goto	main

error	call	beep		;send error beeps
	call	beep
	call	beep
	call	beep
	goto	main

	end
	