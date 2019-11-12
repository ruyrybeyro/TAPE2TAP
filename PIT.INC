
 ; Pit.inc : Primitives for timing. Indepent from the speed of the
 ;			computer.
 ;
 ; Copyright 1995 Rui Fernando Ferreira Ribeiro.
 ;
 ; This program is free software; you can redistribute it and/or modify
 ; it under the terms of the GNU General Public License as published by
 ; the Free Software Foundation; either version 2 of the License, or
 ; (at your option) any later version.
 ;
 ; This program is distributed in the hope that it will be useful,
 ; but WITHOUT ANY WARRANTY; without even the implied warranty of
 ; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 ; GNU General Public License for more details.
 ;
 ; You should have received a copy of the GNU General Public License
 ; along with this program; if not, write to the Free Software
 ; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 ;

                                        ; some equates
                                        ; *************
LOW_IMP		equ	1200
HI_IMP		equ	2600

LOW_SYNC	equ	1200
HI_SYNC		equ	1800

TRANSITION      equ     800

WAIT_VAL        equ     300
NIMP            equ     50
BAD_HI		equ	4000
BAD_LOW         equ     5

READ_PIT	MACRO			; read PIT (8253) counter 0
		xor	al,al		; ask to read counter
		out	43h,al		; PIT control port
		in	al,40h		; read LSB of counter
		mov	ah,al
		in	al,40h		; read MSB of counter
		xchg	ah,al
		ENDM

INIT_COUNT	MACRO
		READ_PIT
		mov	bp,ax		; save counter in BP
		ENDM

GIVE_COUNT	MACRO			; return time elapsed since INIT_COUNT
local           end_cnt
		READ_PIT
		sub	ax,bp		; find difference
                jns     end_cnt		; if difference negative
		neg	ax		; correct value
end_cnt:
		ENDM

		; Initialize the 8253/4 timer
INIT_PIT	MACRO
		mov	al,36h		; select 0|load_2_bytes|mode3|binary
		out	43h,al
		xor	al,al
		out	40h,al		; set timer 0 ch 0 freq to 18.2Hz
		out	40h,al		
		ENDM

; EOF: Pit.inc
