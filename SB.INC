
 ; Sb.inc : Primitives to deal with SoundBlaster.
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

; the next equates are the displacement from the SB base address
RESET           equ     6
MIXER           equ     4
WRITE           equ     0ch
READ            equ     0ah
DATA_AVAIL      equ     0eh
READY           equ     0aah

FIRST_PORT      equ     0200h   ; first SB base port address to scan


DSP_WRITE       MACRO   byte
local           poll_wait

		add     dx,WRITE
poll_wait:      in      al,dx
		or      al,al
		js      poll_wait
		mov     al,byte
		out     dx,al
		sub     dx,WRITE
		ENDM

DSP_READ        MACRO
local           poll_wait

		add     dx,DATA_AVAIL
poll_wait:      in      al,dx           ; poll until a byte is ready
		or      al,al
		jns     poll_wait
		sub     dx,DATA_AVAIL-READ
		in      al,dx
		sub     dx,READ
		ENDM

READ_SB         MACRO
		local   val_ok

		DSP_WRITE       020h    ; send read command
		DSP_READ
		cmp     al,0e0h
		ja      val_ok
		xor     al,al
val_ok:         test    al,080h
		ENDM

READ_MIXER      MACRO   reg
		add     dx,MIXER
		mov     al,reg
		out     dx,al
		inc     dx
		in      al,dx
		sub     dx,MIXER+1
		ENDM


WRITE_MIXER     MACRO   reg, val
		add     dx,MIXER
		mov     al,reg
		out     dx,al
		inc     dx
		mov     al,val
		out     dx,al
		sub     dx,MIXER+1
		ENDM

INIT_MIXER      MACRO
		; Input Source
		; Line-in, filter HighPass (lowFilter)
		WRITE_MIXER 00ch, 7
		; Line-in volume
		WRITE_MIXER 02Eh, 0ffh
		; CD volume
		WRITE_MIXER 028h, 0
		; MIC volume
		WRITE_MIXER 0ah, 0
		; MASTER volume
		WRITE_MIXER 022h, 0FFh
		ENDM

SAVE_MIXER      MACRO
		READ_MIXER      00ch
		mov     byte ptr ds:[input_s],al
		READ_MIXER      02Eh
		mov     byte ptr ds:[line_vol],al
		READ_MIXER      028h
		mov     byte ptr ds:[cd_vol],al
		READ_MIXER      0ah
		mov     byte ptr ds:[mic_vol],al
		READ_MIXER      022h
		mov     byte ptr ds:[master_vol],al
		ENDM

RESTORE_MIXER   MACRO
		mov     al,byte ptr ds:[input_s]
		WRITE_MIXER     00ch,al
		mov     al,byte ptr ds:[line_vol]
		WRITE_MIXER     02Eh,al
		mov     al,byte ptr ds:[cd_vol]
		WRITE_MIXER     028h,al
		mov     al,byte ptr ds:[mic_vol]
		WRITE_MIXER     0ah,al
		mov     al,byte ptr ds:[master_vol]
		WRITE_MIXER     022h,al
		ENDM

RESET_DSP       MACRO
		local   @@scanForDSP, @@wait, @@is_dsp, @@found_DSP, @@exit

		mov     dx,FIRST_PORT           ; first port to scan

@@scanForDSP:   add     dx,RESET                ; translate to RESET port
		mov     al,1
		out     dx,al
		INIT_COUNT
@@wait:         GIVE_COUNT
		cmp     ax,30
		jc      @@wait
		xor     al,al
		out     dx,al

		mov     cx,100
		add     dx,READ-RESET           ; now port is read
@@is_dsp:       in      al,dx
		cmp     al,READY
		jz      @@found_DSP
		loop    @@is_dsp

		sub     dx,READ
		add     dx,0010h                ; next base address
						; to scan
		cmp     dx,02A0h
		jnz     @@scanForDSP
		lea     dx,sb_not_found
		jmp     short @@exit

@@found_DSP:    sub     dx,READ
		mov     word ptr ds:[sb_base_addr],dx

		mov     ax,dx
		and     ax,0f0h
		shr     ax,4
		add     al,'0'
		mov     byte ptr ds:[port_sb],al

		lea     dx,sb_found
@@exit:         PRINT_STRING
		mov     dx,word ptr ds:[sb_base_addr]
		ENDM

; EOF: Sb.inc
