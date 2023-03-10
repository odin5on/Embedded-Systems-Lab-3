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
numbers: .db 0b01110111, 0b00010100, 0b10110011, 0b10110110, 0b11010100, 0b11100110, 0b11100111, 0b00110100, 0b11110111, 0b11110110, 0b11110101, 0b11000111, 0b01100011, 0b10010111, 0b11100011, 0b11100001, 0b00001000, 0b00000010, 0b10000000

;array for lock code
code: .db 0x04, 0x0D, 0x02, 0x02, 0x0E


initialize:
	sbi DDRB, 5 ;Yellow LED
	sbi DDRB, 3 ;SRCLK
	sbi DDRB, 4 ;RCLK
	sbi DDRD, 7 ;SER
	cbi DDRB, 2 ; pushbutton count input
	cbi DDRB, 1 ; rpg pin 1
	cbi DDRB, 0 ; rpg pin 2

	;config timer
	ldi R28, 0x00
	out TCCR0A, R28
	ldi R28, 0x04
	out TCCR0B, R28
	ldi R28, 0x00
	out TCNT0, R28

	.def inputcounter = R26
		ldi inputcounter, 0
	.def wrongvalue = R27
		ldi wrongvalue, 0
	.def displayvalue = R21
	.def displaybincode = R16

	ldi R23, 0

	rjmp start

reset:
	; when button is held, it goes through here
	rcall timer_delay_100ms
	inc R23
	cpi R23, 20
	brsh start
	SBIS PINB, 2
		rjmp reset
	rcall check_input
	rjmp mid_loop

start:
	; load dash onto display
	ldi ZH, HIGH(numbers<<1)
	ldi ZL, LOW(numbers<<1)

	ldi inputcounter, 0
	ldi wrongvalue, 0

	ldi displayvalue, 18
	add ZL, R21
	lpm R16, Z
	rcall display

; this loop is the main process of the program
start_loop:
	sbis PINB, 2
		rjmp reset
	
mid_loop:
	rcall check_rpg_inputs
	ldi R23, 0
	rcall display ; call display subroutine

	rjmp start_loop

;checks input value when button is pressed against the correct code
check_input:
		in R22, SREG
		push R22
		push R17

		ldi ZH, HIGH(code<<1)
		ldi ZL, LOW(code<<1)
		add ZL, inputcounter
		lpm R17, Z

		cpse R17, displayvalue
			ldi wrongvalue, 1
		inc inputcounter

		cpi inputcounter, 5
		brne check_input_end

		rcall turn_on_light
		ldi inputcounter, 0

	check_input_end:
		pop R17
		pop R22
		out SREG, R22
		ret

; turns on yellow light on arduino and decimal point on display for 5 seconds if correct code
; turns on "_" on display if for 9 seconds if code is wrong
turn_on_light:
		in R22, SREG
		push R22
		push R17

		cpi wrongvalue, 1
		breq wrong_light

		ldi ZH, HIGH(numbers<<1)
		ldi ZL, LOW(numbers<<1)
		ldi R17, 16
		add ZL, R17
		lpm R16, Z
		rcall display

		sbi PINB, 5
		cbi PINB, 5
		rcall timer_delay_1s
		rcall timer_delay_1s
		rcall timer_delay_1s
		rcall timer_delay_1s
		rcall timer_delay_1s
		sbi PINB, 5
		cbi PINB, 5
		rjmp turn_on_light_end

	wrong_light:
		ldi ZH, HIGH(numbers<<1)
		ldi ZL, LOW(numbers<<1)
		ldi R17, 17
		add ZL, R17
		lpm R16, Z
		rcall display
		rcall timer_delay_1s
		rcall timer_delay_1s
		rcall timer_delay_1s
		rcall timer_delay_1s
		rcall timer_delay_1s
		rcall timer_delay_1s
		rcall timer_delay_1s
		rcall timer_delay_1s
		rcall timer_delay_1s

	turn_on_light_end:
		ldi inputcounter, 0
		ldi wrongvalue, 0
		
		pop R22
		out SREG, R22
		ret


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
		cbi PORTD, 7 ; put code here to set SER to 0	
	
		rjmp end

	set_ser_in_1:
		; put code here to set SER to 1...
		sbi PORTD, 7

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

		cpi displayvalue, 18
		breq set_zero

		ldi R22, 15
		cpse R21, R22
			rjmp inc_digit	
		rjmp end_increment_timer_value

	set_zero:
		ldi displayvalue, 0
		add ZL, displayvalue
		lpm R16, Z
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

		ldi ZH, HIGH(numbers<<1)
		ldi ZL, LOW(numbers<<1)

		cpi displayvalue, 18
		breq set_zero2

		ldi R22, 0
		cpse R21, R22
			rjmp dec_digit
		rjmp end_decrement_timer_value

	set_zero2:
		ldi displayvalue, 0
		add ZL, displayvalue
		lpm R16, Z
		rjmp end_decrement_timer_value

	dec_digit:
		dec R21
		add ZL, R21
		lpm R16, Z

	end_decrement_timer_value:
		pop R22
		out SREG, R22
		ret


;used to debounce rpg
delay_short:
		.equ count2 = 0x2710
		ldi r30, low(count2)
		ldi r31, high(count2)
	d3:
		sbiw r31:r30, 1	
		brne d3
		ret

;looks at input from rpg to tell if it is rotating
check_rpg_inputs:
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
		rcall decrement_timer_value
		rjmp check_inputs_end

	next_check:
		ldi R25, 0x08
		cpse R24, R25
			rjmp check_inputs_end
		rcall increment_timer_value
	check_inputs_end:
		ret

timer_delay_4ms:
		in R22, SREG
		push R22
		push R28
		push R29

		in R28, TCCR0B
		ldi R29, 0
		out TCCR0B, R29

		in R29, TIFR0
		sbr R29, 1<<TOV0
		out TIFR0, R29

		ldi R29, 0x00
		out TCNT0, R29
		out TCCR0B, R28

	wait:
		in R29, TIFR0
		sbrs R29, TOV0
		rjmp wait

		pop R29
		pop R28
		pop R22
		out SREG, R22
		ret

; loops over timer_delay_4ms 25 times
timer_delay_100ms:
		in R22, SREG
		push R22
		push R28
		push R29

		ldi R28, 0x19
	timer_loop:
		rcall timer_delay_4ms
		dec R28
		brne timer_loop

		pop R29
		pop R28
		pop R22
		out SREG, R22
		ret


timer_delay_1s:
		in R22, SREG
		push R22
		push R28
		push R29

		ldi R28, 0xF5
	timer_loop2:
		rcall timer_delay_4ms
		dec R28
		brne timer_loop2

		pop R29
		pop R28
		pop R22
		out SREG, R22
		ret

