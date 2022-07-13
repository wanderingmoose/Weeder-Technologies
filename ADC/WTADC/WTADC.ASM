;******************************************************************************
;                            RS-232 ANALOG INPUT
;                  Copyright (c) 1997 by Weeder Technologies
;                           Model  : WTADC
;                           Author : Terry J. Weeder
;                           Date   : February 11, 1997
;                           Version: 1.0
;******************************************************************************

;watchdog disabled

list	P=16C54

include	"ascii.equ"

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

dtr	equ	0h		;com dtr
cr	equ	1h		;com receive data
ct	equ	2h		;com transmit data
led	equ	3h		;red LED
eoc	equ	4h		;end of conversion on ADC
do	equ	5h		;data output on ADC
di	equ	6h		;data input on ADC
clk	equ	7h		;sclk on ADC
o	equ	7h		;overflow bit used in conversion subroutine
neg	equ	6h		;negative conversion result bit indicator
alm	equ	7h		;active indicator in alarm setpoint
dif	equ	6h		;differential indicator in alarm setpoint
trp	equ	5h		;trip indicator in alarm setpoint

count	equ	7h
inst2	equ	8h		;used to send ADC instruction
cal1	equ	7h		;used in binary to decimal conversion
cal2	equ	8h		;used in binary to decimal conversion
com_reg	equ	9h		;data to/from com port
data1	equ	9h		;ADC conversion result (low byte)
data2	equ	0Ah		;ADC conversion result (high byte)
inst	equ	0Bh		;store ADC instruction for 2nd transmission
num1	equ	0Bh		;data in ascii-decimal format
num2	equ	0Ch		;data in ascii-decimal format
num3	equ	0Dh		;data in ascii-decimal format
num4	equ	0Eh		;data in ascii-decimal format
mult1	equ	0Dh		;low byte in multiply routine
mult2	equ	0Eh		;high byte in multiply routine
alrm1	equ	0Dh		;alarm setpoint (low byte)
alrm2	equ	0Eh		;alarm setpoint (high byte)
pin	equ	0Fh		;ADC pin number

	org	1FF
	goto	start
	org	0

header	movlw	0x0A		;loop for 10 bits
	movwf	count
	clrf	rtcc
hdr1	call	delay
	btfsc	port_b,cr	;restart loop if com port busy
	goto	header
	decfsz	count
	goto	hdr1		;end loop
	movlw	_A		;send header character
	goto	com_t

addrs	incf	port_a,w		;read address from S1
	andlw	b'00001111'	;strip off high nibble
	iorlw	0x40		;convert to ascii character
	goto	com_t		;send address

footer	movlw	_cr		;send carriage return
	call	com_t
	goto	run

delay	movlw	0x67		;delay 1 bit @ 1200 baud (4MHz clk)
	subwf	rtcc,w
	btfss	status,c
	goto	delay
	clrf	rtcc
	retlw	0x00

com_t	movwf	com_reg
	bsf	port_b,led	;turn on LED
	movlw	0x08		;8 data bits
	movwf	count
	clrf	rtcc
	bcf	port_b,ct	;start bit
	call	delay		;delay 1 bit
ct1	bcf	port_b,ct
	rrf	com_reg		;transmit data bit
	btfsc	status,c
	bsf	port_b,ct
	call	delay		;delay 1 bit
	decfsz	count
	goto	ct1
	bsf	port_b,ct	;stop bit
	call	delay		;delay 1 bit
	bcf	port_b,led	;turn off LED
	retlw	0x00

com_r	btfss	port_b,dtr	;abort if com port not active
	goto	run
	bsf	port_b,led	;turn on LED
	btfss	port_b,cr	;look for start bit
	goto	com_r		;loop until start bit received
	clrf	rtcc
cr1	movlw	0x22		;delay 1/3 bit
	subwf	rtcc,w
	btfss	status,c
	goto	cr1
	clrf	rtcc
	btfss	port_b,cr	;verify start bit
	goto	run		;abort if no start bit
	movlw	0x08		;8 data bits
	movwf	count
cr2	call	delay		;delay 1 bit
	bcf	status,c		;get data bit
	rrf	com_reg
	btfsc	port_b,cr
	bsf	com_reg,MSB
	decfsz	count
	goto	cr2		;get next data bit
	comf	com_reg		;correct for inverted RS-232 data
cr3	btfsc	port_b,cr	;wait for stop bit
	goto	cr3
	bcf	port_b,led	;turn off LED
	movlw	_cr		;test for carriage return
	xorwf	com_reg,w
	btfsc	status,z
	goto	run		;abort if true
	retlw	0x00

mux_s	addwf	pc		;multiplexer addressing - single ended
	retlw	b'10000000'
	retlw	b'11000000'
	retlw	b'10010000'
	retlw	b'11010000'
	retlw	b'10100000'
	retlw	b'11100000'
	retlw	b'10110000'
	retlw	b'11110000'

mux_d	addwf	pc		;multiplexer addressing - differential
	retlw	b'00000000'
	retlw	b'00010000'
	retlw	b'00100000'
	retlw	b'00110000'

verify	movlw	_1		;test if pin = 1 thru 8
	subwf	com_reg,w
	btfss	status,c
	goto	ver1
	movlw	_9
	subwf	com_reg,w
	btfss	status,c
	retlw	0x00		;return if true
ver1	movlw	_A		;test if pin = A thru D
	subwf	com_reg,w
	btfss	status,c
	goto	discard		;abort if false
	movlw	_E
	subwf	com_reg,w
	btfss	status,c
	retlw	0x00		;return if true
	goto	discard		;abort if false

adc	movwf	inst		;load instruction
	call	conv		;perform ADC conversion twice
	call	conv
	goto	cnvrt		;convert data to ascii-decimal

conv	movf	inst,w		;load instruction byte
	movwf	inst2
	clrf	data1
	movlw	0x0D		;13 bit format
	movwf	count
cv0	btfss	port_b,eoc	;wait for end of last conversion
	goto	cv0
cv1	bcf	status,c		;shift in data from ADC
	rlf	data1
	rlf	data2
	btfsc	port_b,do
	bsf	data1,LSB
	bcf	port_b,di	;read instruction bit
	rlf	inst2
	btfsc	status,c
	bsf	port_b,di
	bsf	port_b,clk	;toggle clock pin
	bcf	port_b,clk
	decfsz	count
	goto	cv1
	btfss	data2,4		;complement sign bit
	goto	cv2
	bcf	data2,4
	retlw	0x00
cv2	bsf	data2,4
	retlw	0x00

mult	movlw	0x09		;multiply by 10 (convert decimal to binary)
	movwf	count
	movf	ind,w		;get and store high byte
	andlw	b'00001111'	;strip off config data
	movwf	mult2
	incf	fsr		;move fsr to low byte
	movf	ind,w		;get and store low byte
	movwf	mult1
m1	movf	mult1,w		;add low byte
	addwf	ind
	decf	fsr		;move fsr to high byte
	btfsc	status,c		;test if carry to high byte
	incf	ind		;increment if true
	movf	mult2,w		;add high byte
	addwf	ind
	incf	fsr		;move fsr back to low byte
	decfsz	count
	goto	m1
	retlw	0x00

mult_neg	movlw	0x09		;multiply by -10 (convert decimal to binary)
	movwf	count
	comf	ind,w		;get and store high byte
	andlw	b'00001111'	;strip off config data
	movwf	mult2
	incf	fsr		;move fsr to low byte
	comf	ind,w		;get and store low byte
	movwf	mult1
	incf	mult1
mn1	movf	mult1,w		;subtract low byte
	subwf	ind
	decf	fsr		;move fsr to high byte
	btfss	status,c		;test if carry to high byte
	decf	ind		;decrement if true
	movf	mult2,w		;subtract high byte
	subwf	ind
	incf	fsr		;move fsr back to low byte
	decfsz	count
	goto	mn1
	retlw	0x00

subtrct	bcf	status,o		;clear overflow bit
	movf	cal1,w		;subtract low byte
	subwf	data1
	btfsc	status,c		;test if overflow
	goto	sub1
	movlw	0x01		;borrow from high byte if true
	subwf	data2
	btfss	status,c		;test if overflow
	bsf	status,o		;set overflow bit if true
sub1	movf	cal2,w		;subtract high byte
	subwf	data2
	btfss	status,c		;test if overflow
	bsf	status,o		;set overflow bit if true
	retlw	0x00

add	movf	cal1,w		;add low byte
	addwf	data1
	btfsc	status,c		;test if overflow
	incf	data2		;increment high byte if true
	movf	cal2,w		;add high byte
	addwf	data2
	retlw	0x00

cnvrt	bcf	status,neg	;convert binary to ascii-decimal routine
	btfsc	data2,4		;test if conversion result negative
	goto	cnv0
	bsf	status,neg	;set negative indicator
	comf	data1		;convert two's complement to absolute
	comf	data2
	incfsz	data1
	goto	cnv0
	incf	data2
	btfsc	data2,4		;test if overflow
	goto	cnv0
	decf	data1		;decrement if true
	decf	data2
cnv0	movlw	b'00001111'	;strip off unused bits
	andwf	data2
	movlw	0x30		;initialize number registers
	movwf	num1
	movwf	num2
	movwf	num3
	movwf	num4
	movlw	0xE8		;subtract 1000 from data
	movwf	cal1
	movlw	0x03
	movwf	cal2
cnv1	call	subtrct
	btfsc	status,o		;test if overflow
	goto	cnv2
	incf	num4		;increment 1000s register if false
	goto	cnv1		;repeat
cnv2	call	add		;add 1000 back to data if overflow
	movlw	0x64		;subtract 100 from data
	movwf	cal1
	clrf	cal2
cnv3	call	subtrct
	btfsc	status,o		;test if overflow
	goto	cnv4
	incf	num3		;increment 100s register if false
	goto	cnv3		;repeat
cnv4	call	add		;add 100 back to data if overflow
	movlw	0x0A		;subtract 10 from data
	movwf	cal1
	clrf	cal2
cnv5	call	subtrct
	btfsc	status,o		;test if overflow
	goto	cnv6
	incf	num2		;increment 10s register if false
	goto	cnv5		;repeat
cnv6	call	add		;add 10 back to data if overflow
	movf	data1,w		;place remainder in 1s register
	addwf	num1
	retlw	0x00

;******************************************************************************
;                                   START
;******************************************************************************

start	movlw	b'00000010'	;rtcc = internal, prescaler = 1/8
	option
	movlw	b'00000100'	;set stop bit, sclk low, LED off
	movwf	port_b
	movlw	b'11111111'
	tris	port_a
	movlw	b'00110011'
	tris	port_b
	movlw	0x10		;clear alarm setpoints
	movwf	fsr
st1	clrf	ind
	incf	fsr
	btfsc	fsr,4		;test if done
	goto	st1
	movlw	0x10		;set fsr to first alarm setpoint
	movwf	fsr
	movlw	b'00001000'	;perform auto-calibrate
	movwf	inst
	call	conv
	movlw	b'11001110'	;set acquisition time to 34 CCLK cycles
	movwf	inst
	call	conv
auto_z	movlw	b'00001001'	;perform auto-zero
	movwf	inst
	call	conv

run	movlw	b'11111111'
	tris	port_a
	movlw	b'00110011'
	tris	port_b
	bcf	port_b,led	;assure LED is off
	btfsc	port_b,cr	;look for start bit
	goto	rec		;get string from com port
	incf	fsr		;move to next alarm setpoint
	incf	fsr
	btfsc	fsr,4		;test if beyond last setpoint
	goto	rn1
	movlw	0x10		;set fsr to first alarm setpoint if true
	movwf	fsr
rn1	btfsc	ind,alm		;test if active alarm setpoint
	goto	alarm
	goto	run

rec	call	com_r		;get first character
	movlw	_A		;test for header character
	xorwf	com_reg,w
	btfss	status,z
	goto	discard
	call	com_r		;get address from com port
	incf	port_a,w		;read address from S1
	andlw	b'00001111'	;strip off high nibble
	iorlw	0x40		;convert to ascii character
	xorwf	com_reg,w	;test if matching address
	btfss	status,z
	goto	discard
	call	com_r		;get command character
	movlw	_Z		;test if "zero" operation
	xorwf	com_reg,w
	btfsc	status,z
	goto	auto_z
	movlw	_S		;test if "single-ended conv" operation
	xorwf	com_reg,w
	btfsc	status,z
	goto	single
	movlw	_D		;test if "differential conv" operation
	xorwf	com_reg,w
	btfsc	status,z
	goto	differ
	movlw	_R		;test if "read" operation
	xorwf	com_reg,w
	btfsc	status,z
	goto	read
	movlw	_A		;test if "alarm setpoint" operation
	xorwf	com_reg,w
	btfsc	status,z
	goto	setpoint
	goto	discard

single	clrf	pin
	call	header		;send header to com port
	call	addrs		;send address to com port
s1	movf	pin,w		;get multiplexer/mode data pattern
	call	mux_s
	call	adc		;perform ADC conversion, convert to ascii
	btfss	status,neg	;test if result is negative
	goto	s2
	movlw	_hyphen		;send negative sign if true
	call	com_t
s2	movf	num4,w		;send conversion result
	call	com_t
	movf	num3,w
	call	com_t
	movf	num2,w
	call	com_t
	movf	num1,w
	call	com_t
	incf	pin
	movlw	0x08		;test if 8 conversions sent
	xorwf	pin,w
	btfsc	status,z
	goto	footer		;send carriage return
	movlw	_space		;send space to com port
	call	com_t
	goto	s1

differ	clrf	pin
	call	header		;send header to com port
	call	addrs		;send address to com port
d1	movf	pin,w		;get multiplexer/mode data pattern
	call	mux_d
	call	adc		;perform ADC conversion, convert to ascii
	btfss	status,neg	;test if result is negative
	goto	d2
	movlw	_hyphen		;send negative sign if true
	call	com_t
d2	movf	num4,w		;send conversion result
	call	com_t
	movf	num3,w
	call	com_t
	movf	num2,w
	call	com_t
	movf	num1,w
	call	com_t
	incf	pin
	movlw	0x04		;test if 4 conversions sent
	xorwf	pin,w
	btfsc	status,z
	goto	footer		;send carriage return
	movlw	_space		;send space to com port
	call	com_t
	goto	d1

read	call	com_r		;get pin #
	call	verify		;test if valid pin #
	decf	com_reg,w	;fix pin # for lookup table
	andlw	b'00001111'	;strip off high nibble
	btfss	com_reg,6	;test if single or differential
	goto	rd1
	call	mux_d		;get multiplexer data pattern (diff)
	goto	rd2
rd1	call	mux_s		;get multiplexer data pattern (single)
rd2	call	adc		;perform ADC conversion, convert to ascii
	call	header		;send header to com port
	call	addrs		;send address to com port
	btfss	status,neg	;test if result is negative
	goto	rd3
	movlw	_hyphen		;send negative sign if true
	call	com_t
rd3	movf	num4,w		;send conversion result
	call	com_t
	movf	num3,w
	call	com_t
	movf	num2,w
	call	com_t
	movf	num1,w
	call	com_t
	goto	footer		;send carriage return

setpoint	call	com_r		;get pin #
	call	verify		;test if pin # in range
	decf	com_reg,w	;fix pin # for fsr
	movwf	fsr
	bcf	status,c
	rlf	fsr		;fsr x 2 (allow for two bytes in data)
	btfss	com_reg,6	;test if differential
	goto	sp1
	bcf	status,c
	rlf	fsr		;fsr x 2 (every other pin)
	bsf	fsr,4		;final adjustment to fsr
	bsf	ind,dif		;set differential indicator
	goto	sp2
sp1	bsf	fsr,4		;final adjustment to fsr
	bcf	ind,dif		;clear differential indicator
sp2	bsf	ind,alm		;set alarm active
	bsf	ind,4		;initialize sign as positive
	movlw	b'11110000'	;clear high byte
	andwf	ind
	incf	fsr		;move to low byte
	clrf	ind		;clear low byte
	call	com_r		;get first digit
	movlw	_hyphen		;test if negative sign sent
	xorwf	com_reg,w
	btfsc	status,z
	goto	sp4
sp3	movlw	b'00001111'	;strip off high nibble
	andwf	com_reg,w
	addwf	ind		;add to register (if positive)
	decf	fsr		;return fsr back to high byte
	btfsc	status,c		;test if carryout to high byte
	incf	ind		;increment high byte if true
	call	com_r		;get additional digit if sent
	call	mult		;x10 if additional digit received
	goto	sp3		;loop until last digit received
sp4	call	com_r		;get first digit
sp5	movlw	b'00001111'	;strip off high nibble
	andwf	com_reg,w
	subwf	ind		;subtract from register (if negative)
	decf	fsr		;return fsr back to high byte
	btfss	status,c		;test if carryout to high byte
	decf	ind		;decrement high byte if true
	call	com_r		;get additional digit if sent
	call	mult_neg		;xneg10 if additional digit received
	goto	sp5		;loop until last digit received

alarm	rrf	fsr,w		;divide by 2 (allow for two bytes in data)
	andlw	b'00000111'	;strip off unused bits
	movwf	pin
	btfss	ind,dif		;test if differential
	goto	alm1
	bcf	status,c
	rrf	pin		;divide by 2 (every other pin)
	movf	pin,w
	bsf	pin,6		;change to ascii character (@-C)
	call	mux_d		;get multiplexer data pattern (diff)
	goto	alm2
alm1	movf	pin,w
	bsf	pin,4		;change to ascii character (0-7)
	bsf	pin,5
	call	mux_s		;get multiplexer data pattern (single)
alm2	movwf	inst
	incf	pin		;fix pin # to A-D or 1-8
	call	conv		;perform ADC conversion
	btfsc	port_b,cr	;check for start bit
	goto	run		;abort if true
	call	conv		;perform 2nd ADC conversion
	btfss	ind,trp		;test if alarm already tripped
	goto	alm3
	movlw	0x0A		;add 10mV to result for hysteresis
	addwf	data1
	btfsc	status,c
	incf	data2
alm3	movf	ind,w		;get setpoint (high byte)
	andlw	b'00011111'	;strip off configuration bits
	movwf	alrm2
	incf	fsr		;move to low byte
	movf	ind,w		;get setpoint (low byte)
	movwf	alrm1
	decf	fsr		;move back to high byte for config
	movf	data1,w		;test if conv result higher then setpoint
	subwf	alrm1,w
	btfss	status,c
	incf	data2
	movf	data2,w
	subwf	alrm2,w
	btfsc	status,c
	goto	alm4
	btfsc	ind,trp		;test if alarm formerly tripped
	goto	run		;abort if true
	bsf	ind,trp		;set trip indicator
	goto	alm5
alm4	btfss	ind,trp		;test if alarm formerly tripped
	goto	run		;abort if not
	bcf	ind,trp		;clear trip indicator
alm5	call	header		;send header to com port
	call	addrs		;send address to com port
	movf	pin,w		;send pin number
	call	com_t
	btfss	ind,trp		;test if pin "high" or "low"
	goto	alm6
	movlw	_H		;send "high" indicator
	goto	alm7
alm6	movlw	_L		;send "low" indicator
alm7	call	com_t
	goto	footer		;send carriage return

discard	call	com_r		;get next character
	goto	discard		;loop until carriage return detected

	end
