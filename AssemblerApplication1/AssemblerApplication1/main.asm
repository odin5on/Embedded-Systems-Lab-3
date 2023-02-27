;
; AssemblerApplication1.asm
;
; Created: 2/27/2023 11:35:57 AM
; Author : dbodn
;

;pin13 is SER(14 on register) SER is the bit you want to load next
;pin12 is RCLK (12 on Register) RCLK (storage clock) loads the bits
;pin11 is SRCLK(11 on Register) SRCLK (shift register clock)  pulses to latch all 8 loaded bits
;pin10 goes to pushbutton

.include "m328Pdef.inc"
.cseg
.org 0

rjmp initialize
;array for lookup table of numbers
; need ABCDEF for lookup table
numbers: .db 0b01110111, 0b00010100, 0b10110011, 0b10110110, 0b11010100, 0b11100110, 0b11100111, 0b00110100, 0b11110111, 0b11110110, 0b10000000, 0b00000000

;Psuedocode for rest of project:
;incrementing numbers with button A:
;when the pushbutton opens then closes, increment R16 by correct amount to reach next num (may need to rework hardware connections for this)
;counting down with Button B:
; when b is pressed, run subroutine that decrements r16 by an amount with a simuular delay_long function after it to simulate every second 

initialize:
	sbi DDRB, 3 ;SRCLK
	sbi DDRB, 4 ;RCLK
	sbi DDRB, 5 ;SER
	cbi DDRB, 2 ; pushbutton count input
	cbi DDRB, 1 ; rpg pin 1
	cbi DDRB, 0 ; rpg pin 2


	ldi R23, 0

	rjmp start

reset:
	; when button a is pressed, the process comes here to reset the displays to zeros
	rcall delay_long
	inc R23
	cpi R23, 10
	brsh start
	SBIS PINB, 2
		rjmp reset
	rjmp mid_loop

start:
	; load zeros onto display
	ldi ZH, HIGH(numbers<<1)
	ldi ZL, LOW(numbers<<1)

	ldi R21, 0

	add ZL, R21
	lpm R16, Z
	rcall display

; this loop is the main process of the program
start_loop:
	sbis PINB, 2
		rjmp reset
	
mid_loop:
	rcall check_inputs
	ldi R23, 0
	rcall display ; call display subroutine

	rjmp start_loop


display: 
	; backup used registers on stack
	push R16

	push R17
	in R17, SREG
	push R17
	; done backing up registers

	ldi R17, 8 ; loop --> test all 8 bits
	
loop: ; this loop loads in the right digit
	rol R16 ; rotate left trough Carry
	BRCS set_ser_in_1 ; branch if Carry is set
	cbi PORTB, 5 ; put code here to set SER to 0	
	
	rjmp end

set_ser_in_1:
	; put code here to set SER to 1...
	sbi PORTB, 5

end:
	; put code here to generate SRCLK pulse...
	sbi PORTB, 3
	nop
	cbi PORTB, 3
	dec R17
	brne loop

	; put code here to generate RCLK pulse
	sbi PORTB, 4
	nop
	cbi PORTB, 4

	pop R17
	out SREG, R17
	pop R17
	pop R16

	ret  ; end of display function

increment_timer_value:
	in R22, SREG
	push R22

	ldi ZH, HIGH(numbers<<1)
	ldi ZL, LOW(numbers<<1)

	ldi R22, 9 ;change to 16 in future
	cpse R21, R22
		rjmp inc_digit	
	rjmp end_increment_timer_value

	inc_digit:
		inc R21
		add ZL, R21
		lpm R16, Z

	end_increment_timer_value:
		pop R22
		out SREG, R22
		ret
	

decrement_timer_value:
	in R22, SREG
	push R22


decrement_timer_wo_stack_stuff:
	rcall delay_long ; 100ms delay, called 10 times
	rcall delay_long
	rcall delay_long
	rcall delay_long
	rcall delay_long
	rcall delay_long
	rcall delay_long
	rcall delay_long
	rcall delay_long
	rcall delay_long

	ldi ZH, HIGH(numbers<<1)
	ldi ZL, LOW(numbers<<1)

	ldi R22, 0

	cpse R20, R22
		rjmp decrement_ones

	cpse R21, R22
		rjmp decrement_tens

	rjmp decrement_return

	decrement_tens:
		dec R21
		ldi R20, 9
		rjmp decrement_end

	decrement_ones:
		dec R20
		
	decrement_end:
		add ZL, R20
		lpm R16, Z
		ldi ZL, LOW(numbers<<1)
		add ZL, R21
		rcall display
		rjmp decrement_timer_wo_stack_stuff

	decrement_return:


		ldi ZL, LOW(numbers<<1)
		lpm R16, Z
		rcall display

		pop R22
		out SREG, R22
		ret ; end of decrement_timer_value function
		

delay_long: ; this method is taken from lab 1 but changed to be 100ms long
	;100 ms long
	.equ count = 0x065a ; assign a 16-bit value to symbol "count"
	ldi r30, low(count)   ; r31:r30  <-- load a 16-bit value into counter register for outer loop
	ldi r31, high(count);
d1:
	ldi   r29, 0xf5     ; r29 <-- load a 8-bit value into counter register for inner loop og ff
d2:
	nop ; no operation
	dec   r29            ; r29 <-- r29 - 1
	brne  d2 ; branch to d2 if result is not "0"
	sbiw r31:r30, 1 ; r31:r30 <-- r31:r30 - 1
	brne d1 ; branch to d1 if result is not "0"	
	nop
	ret ; return	


delay_short:
	.equ count2 = 0x2710
	ldi r30, low(count2)
	ldi r31, high(count2)
d3:
	sbiw r31:r30, 1	
	brne d3
	ret

check_inputs:
	in R24, PINB
	andi R24, 0x03
	lsl R24
	lsl R24
	mov R25, R24
	rcall delay_short
	in r24, PINB
	andi R24, 0x03
	or R24, R25
	andi R24, 0x0F
	ldi R25, 0x04
	cpse R24, R25
		rjmp next_check
	rcall increment_timer_value
	rjmp check_inputs_end
next_check:
	ldi R25, 0x08
	cpse R24, R25
		rjmp check_inputs_end
	rcall increment_timer_value
check_inputs_end:
	ret

