;******************************************************************************
;                             IR REMOTE DECODER
;                 Copyright (c) 1997 by Weeder Technologies
;                           Model  : WTIRD
;                           Author : Terry J. Weeder
;                           Date   : November 19, 1997
;                           Version: 1.0
;******************************************************************************

;watchdog disabled

list	P=16C54

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

cs	equ	3h		;eeprom chip select pin
clk	equ	2h		;eeprom clock pin
d	equ	1h		;eeprom data pin
ir	equ	0h		;infrared data input 
en	equ	5h		;output enable pin
cd	equ	6h		;carrier detect pin
pgm	equ	7h		;programming trigger
led	equ	7h		;LED output
nm	equ	7h		;no-match indicator in status register
sb	equ	6h		;start-bit-checked indicator in status reg

count	equ	7h
count2	equ	8h
match	equ	9h		;used to find IR data match in eeprom
addrs1	equ	0Ah		;low byte of eeprom address
addrs2	equ	0Bh		;high byte of eeprom address
eeprom1	equ	0Ch		;used to send instructions to eeprom
eeprom2	equ	0Dh		;used to send instructions to eeprom
mem_reg	equ	0Eh		;data in/out of eeprom
com_reg	equ	0Fh		;data in/out of com port
output	equ	0Fh		;decoded binary output

	org	1FF
	goto	start
	org	0

de_bnc	movlw	0x10		;50us delay
	movwf	count
db1	decfsz	count
	goto	db1
	retlw	0x00

pause	movlw	0x08		;522ms delay
	movwf	count
p1	movlw	0x01
	movwf	rtcc
p2	movf	rtcc,w
	btfss	status,z
	goto	p2
	decfsz	count
	goto	p1
	retlw	0x00

delay	movlw	0x67		;delay 1/2 bit @ 1200 baud 4MHz clock
	movwf	count
d1	nop
	decfsz	count
	goto	d1
	retlw	0x00

com_r	movlw	b'00111111'	;turn on LED
	tris	port_b
	btfsc	port_b,en	;wait for start bit
	goto	com_r
com_r2	call	delay		;delay 1/2 bit
	movlw	0x08		;8 data bits
	movwf	count2
cr1	call	delay		;delay 1 bit
	call	delay
	bcf	status,c		;get data bit
	rrf	com_reg
	btfsc	port_b,en
	bsf	com_reg,MSB
	decfsz	count2
	goto	cr1		;get next data bit
	movlw	b'10111111'	;turn off LED
	tris	port_b
	call	delay		;wait for stop bit
	call	delay
	retlw	0x00

com_t	movwf	com_reg
	movlw	b'00011111'	;LED on, enable pin = start bit
	tris	port_b
	movlw	0x08		;8 data bits
	movwf	count2
	call	delay		;delay 1 bit
	call	delay
ct1	movlw	b'00011111'	;initialize bit as low
	tris	port_b
	movlw	b'00111111'	;ready to set high
	rrf	com_reg		;read data bit
	btfsc	status,c
	tris	port_b		;set high if required
	call	delay		;delay 1 bit
	call	delay
	decfsz	count2
	goto	ct1
	movlw	b'10111111'	;LED off, enable pin = stop bit
	tris	port_b
	call	delay		;pause for stop bit
	retlw	0x00

measure	btfss	port_a,ir	;wait for high on IR pin
	goto	measure
	call	de_bnc		;verify high after 50us
	btfss	port_a,ir
	goto	measure
	movlw	b'00001111'	;get "low" pulse time
	andwf	rtcc,w		;strip off high nibble for data compression
	movwf	ind
	clrf	rtcc		;reset rtcc
ms1	movlw	0x4E		;return if longer then 20ms
	xorwf	rtcc,w
	btfsc	status,z
	goto	ms2
	btfsc	port_a,ir	;wait for low on IR pin
	goto	ms1
	call	de_bnc		;verify low after 50us
	btfsc	port_a,ir
	goto	ms1
	movlw	b'00001111'	;get "high" pulse time
	andwf	rtcc		;strip off high nibble for data compression
	swapf	rtcc,w		;place in upper half of register
	addwf	ind
	clrf	rtcc		;reset rtcc
	retlw	0x00
ms2	movlw	0xFF		;test if at last register
	xorwf	fsr,w
	btfsc	status,z
	retlw	0x00
	incf	fsr		;move to last register
	goto	ms2

end_ir	movlw	0x23		;100ms timer (test for end of IR data)
	movwf	count
	clrf	count2
end1	btfss	port_b,en	;test if outputs enabled
	goto	end2
	movlw	b'10100000'	;set for output if true
	tris	port_b
	goto	end3
end2	movlw	b'10111111'	;set for input if false
	tris	port_b
	nop
end3	btfss	port_a,ir	;restart timer if IR present
	goto	end_ir
	decfsz	count2
	goto	end1
	decfsz	count
	goto	end1		;end timer
	retlw	0x00

opcode	movlw	0x0C		;93LC66, 512x8 (12 bits SB/opcode/address)
	movwf	count
	movlw	b'11110001'	;change to output
	tris	port_a
	bsf	port_a,cs	;select chip
oc1	bcf	port_a,d
	rlf	eeprom1		;get next bit
	rlf	eeprom2
	btfsc	eeprom2,4
	bsf	port_a,d
	bsf	port_a,clk	;toggle clock pin
	bcf	port_a,clk
	decfsz	count
	goto	oc1
	retlw	0x00

read	movlw	b'00001100'	;load start bit and opcode (read)
	movwf	eeprom2
	movf	addrs2,w		;load address
	addwf	eeprom2
	movf	addrs1,w
	movwf	eeprom1
	call	opcode		;send opcode/address to eeprom
	movlw	b'11110011'	;change to input
	tris	port_a
	movlw	0x08		;8 data bits to read from eeprom
	movwf	count
rd1	bsf	port_a,clk	;toggle clock pin
	bcf	port_a,clk
	bcf	status,c
	rlf	mem_reg
	btfsc	port_a,d		;get next data bit
	bsf	mem_reg,LSB
	decfsz	count
	goto	rd1
	bcf	port_a,cs	;deselect chip
	incfsz	addrs1
	retlw	0x00
	incf	addrs2
	retlw	0x00

write	movwf	mem_reg		;load data byte
	movlw	b'00001001'	;load start bit and opcode (write enable)
	movwf	eeprom2
	movlw	b'10000000'
	movwf	eeprom1
	call	opcode		;send to eeprom
	bcf	port_a,cs	;deselect chip
	movlw	b'00001010'	;load start bit and opcode (write)
	movwf	eeprom2
	movf	addrs2,w		;load address
	addwf	eeprom2
	movf	addrs1,w
	movwf	eeprom1
	call	opcode		;send opcode/address to eeprom
	movlw	0x08		;8 data bits
	movwf	count
wt1	bcf	port_a,d
	rlf	mem_reg		;output next data bit
	btfsc	status,c
	bsf	port_a,d
	bsf	port_a,clk	;toggle clock pin
	bcf	port_a,clk
	decfsz	count
	goto	wt1
	bcf	port_a,cs	;deselect chip
	movlw	b'11110011'	;change to input
	tris	port_a
	bsf	port_a,cs	;select chip
wt2	btfss	port_a,d		;test for ready condition
	goto	wt2
	bcf	port_a,cs	;deselect chip
	movlw	b'00001000'	;load start bit and opcode (write disable)
	movwf	eeprom2
	clrf	eeprom1
	call	opcode		;send to eeprom
	bcf	port_a,cs	;deselect chip
	incfsz	addrs1
	retlw	0x00
	incf	addrs2
	retlw	0x00

;******************************************************************************
;                                   START
;******************************************************************************

start	movlw	b'00000111'	;rtcc = internal, prescaler = 1/256
	option
	clrf	port_a
	clrf	port_b
	call	pause		;delay 522ms

run	movlw	b'11110001'
	tris	port_a
	btfss	port_b,en	;test if outputs enabled
	goto	rn1
	movlw	b'10100000'	;set for output if true
	tris	port_b
	bcf	status,sb	;used to detect start bit
	goto	rn2
rn1	movlw	b'10111111'	;set for input if false
	tris	port_b
	btfss	status,sb	;check if possible start bit
	goto	clone
rn2	btfss	port_b,pgm	;test if request to program
	goto	program
	btfsc	port_a,ir	;test if IR present
	goto	run
	call	de_bnc		;verify IR carrier after 50us
	btfsc	port_a,ir
	goto	run
	clrf	rtcc		;reset rtcc
	goto	get_ir

get_ir	movlw	0x10		;clear 16 data registers
	movwf	fsr
ir1	clrf	ind
	incf	fsr
	btfsc	fsr,4		;test if done
	goto	ir1
	movlw	0x02		;two passes
	movwf	count2
ir2	movlw	0x10		;set to first data register
	movwf	fsr
ir3	call	measure		;measure pulse length
	incf	fsr
	btfsc	fsr,4		;test if done
	goto	ir3
	decfsz	count2
	goto	ir2
	clrf	addrs1		;set to first memory location
	clrf	addrs2
	clrf	output		;set to first binary value
	movlw	0x20		;32 IR sample strings
	movwf	count2
ir4	bcf	status,nm	;reset no-match bit
	movlw	0x10		;set to first data register
	movwf	fsr
ir5	call	read		;read pulse length in eeprom
	movlw	b'00001111'	;test if match in low nibble
	andwf	mem_reg,w
	movwf	match
	movlw	b'00001111'	;test if equal
	andwf	ind,w
	xorwf	match,w
	btfsc	status,z
	goto	ir6
	incf	match		;test if 1 more
	movlw	b'00001111'
	andwf	match		;fix if carry into high nibble
	andwf	ind,w
	xorwf	match,w
	btfsc	status,z
	goto	ir6
	decf	match		;test if 1 less
	decf	match
	movlw	b'00001111'
	andwf	match		;fix if carry into high nibble
	andwf	ind,w
	xorwf	match,w
	btfss	status,z
	bsf	status,nm	;set no-match bit
ir6	movlw	b'11110000'	;test if match in high nibble
	andwf	mem_reg,w
	movwf	match
	swapf	match
	swapf	ind
	movlw	b'00001111'	;test if equal
	andwf	ind,w
	xorwf	match,w
	btfsc	status,z
	goto	ir7
	incf	match		;test if 1 more
	movlw	b'00001111'
	andwf	match		;fix if carry into high nibble
	andwf	ind,w
	xorwf	match,w
	btfsc	status,z
	goto	ir7
	decf	match		;test if 1 less
	decf	match
	movlw	b'00001111'
	andwf	match		;fix if carry into high nibble
	andwf	ind,w
	xorwf	match,w
	btfss	status,z
	bsf	status,nm	;set no-match bit
ir7	swapf	ind		;set back to original
	btfsc	status,nm	;test if no match
	goto	nomatch
	incf	fsr
	btfsc	fsr,4		;test if done
	goto	ir5
	movf	output,w		;place binary number on port
	iorlw	b'01000000'	;CD high
	movwf	port_b
	call	end_ir		;wait until button released
	clrf	port_b		;CD low, clear port
	clrf	rtcc		;delay 3ms (ignor glitch)
ir8	movlw	0x0C
	xorwf	rtcc,w
	btfss	status,z
	goto	ir8		;end delay
	goto	run

	incf	addrs1		;set eeprom address for next pin
	btfsc	status,z
	incf	addrs2
nomatch	incf	fsr
	btfsc	fsr,4		;test if done
	goto	nomatch-3
	incf	output		;set to next binary value
	decfsz	count2
	goto	ir4
	call	end_ir		;wait until button released
	goto	run

clone	bsf	status,sb	;mark as done
	call	com_r		;get first byte
	movlw	b'01010101'	;test if clone request
	xorwf	com_reg
	btfss	status,z
	goto	run		;abort if not
	call	com_t		;send acknowledgement byte
	clrf	addrs1		;set to first eeprom address
	clrf	addrs2
cl1	call	read		;get byte from eeprom
	movf	mem_reg,w
	call	com_t		;transmit byte to slave
	call	com_r		;wait for slave to respond
	movf	com_reg,w	;check for error
	xorwf	mem_reg,w
	btfss	status,z
	goto	error
	btfss	addrs2,1		;test if done
	goto	cl1
	goto	run

copy	call	com_r		;get byte from host
	movf	com_reg,w	;write byte to eeprom
	call	write
	movf	com_reg,w	;transmit byte back to host
	call	com_t
	btfss	addrs2,1		;test if done
	goto	copy
	goto	run

program	clrf	port_b
	movlw	b'00111111'	;turn on LED
	tris	port_b
	call	pause		;ignor any glitches
	call	pause
	clrf	addrs1		;set to first eeprom address
	clrf	addrs2
	movlw	b'01010101'	;send clone request
	call	com_t
	call	com_r2		;get byte from com port
	movlw	b'00111111'	;turn LED back on
	tris	port_b
	movlw	b'01010101'	;test if acknowledgement byte
	xorwf	com_reg
	btfsc	status,z
	goto	copy		;copy host if true
pr1	movlw	0x80		;wait 10 seconds for IR carrier
	movwf	count2
	clrf	rtcc
pr2	btfss	port_a,ir
	goto	pr3
	movlw	0xFF
	xorwf	rtcc,w
	btfss	status,z
	goto	pr2
	clrf	rtcc
	decfsz	count2
	goto	pr2
	goto	end_prog		;end if no IR carrier
pr3	call	de_bnc		;verify IR carrier after 50us
	btfsc	port_a,ir
	goto	pr2
	clrf	rtcc		;reset rtcc
	movlw	0x10		;clear 16 data registers
	movwf	fsr		;set to first data register
pr4	clrf	ind
	incf	fsr
	btfsc	fsr,4		;test if done
	goto	pr4
	movlw	0x02		;two passes
	movwf	count2
pr5	movlw	0x10		;set to first data register
	movwf	fsr
pr6	call	measure		;measure pulse length
	incf	fsr
	btfsc	fsr,4		;test if done
	goto	pr6
	decfsz	count2
	goto	pr5
	movlw	0x10		;write data to eeprom
	movwf	fsr
pr7	movf	ind,w
	call	write
	incf	fsr
	btfsc	fsr,4		;test if done
	goto	pr7
	call	pause
	movlw	b'10111111'	;turn off LED
	tris	port_b
	call	pause
	movlw	b'00111111'	;turn on LED
	tris	port_b
pr8	movlw	0x9C		;200ms timer (test for end of IR data)
	movwf	count
	clrf	count2
pr9	btfss	port_a,ir	;restart timer if IR present
	goto	pr8
	decfsz	count2
	goto	pr9
	decfsz	count
	goto	pr9		;end timer
	btfss	addrs2,1		;test if done
	goto	pr1		;program next button
	movlw	b'10111111'	;turn off LED
	tris	port_b
	goto	run

end_prog	movlw	0xFF		;fill remaining eeprom with "FF"
	call	write
	btfss	addrs2,1		;test if done
	goto	end_prog
	movlw	b'10111111'	;turn off LED
	tris	port_b
	goto	run

error	movlw	b'00111111'	;turn on LED
	tris	port_b
	call	pause
	movlw	b'10111111'	;turn off LED
	tris	port_b
	call	pause
	goto	error		;loop until reset

	end
	