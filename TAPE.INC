
 ; Tape.inc : Misc routines for tape program.
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

BLACK		equ	0
BLUE		equ	1
RED		equ	4
YELLOW		equ	6

cr		equ	0dh
lf		equ	0ah

READ_LPT	MACRO

		in	al,dx		; read printer-1 status port
;		and	al,10h		; the value may be used...
		and	al,80h		; reads busy pin
		ENDM

BEEP_IT		MACRO			; bleed bit read to beeper
		pushf
;		shr	al,3
		shr	al,6		; modified for busy pin
		out	61h,al


		popf
		ENDM

PRINT_STRING	MACRO
		mov	ah,9
		int	21h
		ENDM

BREAK_KEY_CODE  equ     1               ; keyboard scan key code of ESC

TEST_BREAK	MACRO
local		no_space, no_sound, leave, nokey, test_1, test_2


		in	al,60h		; read keyb port
					; test for 'ESC' key
		or	al,al
		js	nokey
		cmp	al,BREAK_KEY_CODE
		jnz	no_space
		jmp	leave_prog
no_space:	cmp	al,31		; test for 'S' key
		jnz	no_sound
		mov	byte ptr ds:[speaker_on],2
no_sound:	cmp	al,49		; test for 'N' key
		jnz	leave
		mov	byte ptr ds:[speaker_on],0
leave:          cmp	al,25		; test for 'P' key
		jnz	test_1

		xor	dx,dx
		; 'disable' SB address (do not use it anymore)
		mov	word ptr ds:[sb_base_addr],dx
		; and activate Printer
		mov	dx,word ptr ds:[printer_port]

test_1:		cmp	al,2		; test for '1' key
		jnz	test_2
		mov	byte ptr ds:[SpecCRC],0
test_2:		cmp	al,3		; test for '2' key
		jnz	nokey
		mov	byte ptr ds:[SpecCRC],1
nokey:
		ENDM

COLOUR_BORDER	MACRO	reg
		local	wait_retrace

		push	dx
		mov	dx,03DAh
wait_retrace:	in	al,dx		; read VGA Input Status register
		test	al,8		; if set it's vertical retrace
		jnz	wait_retrace 	; so wait till it ends
		mov	dx,03C0h	; Attribute controller registers
		mov	al,11h		; Overscan colour
		out	dx,al		; Give address to controller
		mov	al,reg
		out	dx,al		; Output colour
		mov	al,20h		; Tells controller to change only
		out	dx,al		; the border colour
		pop	dx
		ENDM


RTC2DOSCLK	MACRO
		mov	ah,2
		int	1ah

		mov	al,ch
		call	bcd_2_dec
		mov	ch,al

		mov	al,cl
		call	bcd_2_dec
		mov	cl,al

		mov	al,dh
		call	bcd_2_dec
                mov     dh,al

		mov	dl,0
		mov	ah,2dh
		int	21h
		ENDM

; EOF: Tape.inc
