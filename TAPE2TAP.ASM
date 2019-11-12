
 ; Tape2Tap.asm : DOS Spectrum tape sampler.
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


		name    tape2tap
		page    55,132
		title   'TAPE2TAP'

; **** Rui Fernando ****
;
; v1.00 95/08/23        .  original version
; v1.01 95/10/06        .  source better structured
;                       .  false block detection reduced
;                       .  colours added to make border stripes like real
;                         Spectrum
; v1.10 95/10/17        . added SB support
; v1.11 95/10/29        .  better noise immunity
; v1.12 95/12/27        . input pin modified to busy pin
; v1.13 96/06/06        .  Line-In Input modified, the volume was not properly
;                       . adjusted for SB Pro 16 and better cards
; v1.20 96/10/03	. created WINSTUB for Windows'95 setup
;			. created option to switch in runtime the inputing
;			device to the printer port

INCLUDE         TAPE.INC
INCLUDE         PIT.INC
INCLUDE         SB.INC

		.model  tiny
		.code
		org     0100h           ; tiny model
					; resident part of program
begin_code:
		; release memory (DOS gives .COM all the memory)
		;
		push    ds
		pop     es              ; es = segment of memory
		mov     bx,4096         ; reserve only 64k (4096 para)
		mov     ah,4ah          ; realloc
		int     21h

		xor     ax,ax
		mov     ds,ax
		mov     ax,word ptr ds:[0408h]
		push    cs
		pop     ds
		inc     ax
		mov     word ptr ds:[printer_port],ax

		call    ReadCmdLine

		INIT_PIT

		lea     dx,copyright
		PRINT_STRING

		mov     ax,1600h        ; see if in Windows
		int     2fh
		cmp     ax,1600h
		jz      not_windows

		lea     dx,w_error
		PRINT_STRING

		mov     ax,4c01h
		int     21h


not_windows:    lea     dx,messg_begin
		PRINT_STRING

		mov     ah,48h          ; allocate a memory DOS block
		mov     bx,4096         ; 64K
		int     21h             ; return data segment in AX
		jnc     enough_memory

					; Print unsuficient memory
					; message
not_enough:     lea     dx,error_mem
		PRINT_STRING

		mov     ax,4c02h        ; leave
		int     21h

enough_memory:  cmp     bx,4096         ; we want a 64K block.
		jnz     not_enough

		mov     es,ax
		cmp     byte ptr ds:[sb_on],0
		jnz     sb_is_enabled
		jmp     no_sblaster

sb_is_enabled:  call    ResetDSP        ; tests for the presence of a SB card
		or      dx,dx
		jnz     sb_is_present
		jmp     no_sblaster

sb_is_present:  cmp     byte ptr ds:[speaker_on],2
		jz      dont_disable

		mov     byte ptr ds:[speaker_on],0

dont_disable:   SAVE_MIXER
		INIT_MIXER

no_sblaster:    cli
		in      al,61h          ; keeps old 61h port contents
		mov     byte ptr ds:[copy_p61h],al

begin:          cli
		mov     si,2

		; clean table used by error detection logic
;               lea     di,berr_tab
;               mov     cx,8
;@@loop_clean:  mov     word ptr ds:[di],0
;               inc     di
;               loop    @@loop_clean

		; WARNING: don't modify dx in the main input routine!           
		; It must always yeld the printer port status address
		; or the SoundBlaster port address

		mov     dx,word ptr ds:[sb_base_addr]
		or      dx,dx
		jnz     no_imp

		mov     dx,word ptr ds:[printer_port]   ; LPT port


; try to find
no_imp:         mov     byte ptr ds:[colour],RED
		mov     bh,0            ; init counter of impulse blocks

imp_again:      call    ReadVal
		jnz     no_imp

imp_low:        call    ReadCycle
another_imp:    cmp     ax,LOW_IMP
		jc      no_imp
		cmp     ax,HI_IMP
		jnc     no_imp
		cmp     cx,LOW_IMP
		jc      no_imp
		cmp     cx,HI_IMP
		jnc     no_imp
		inc     bh              ; has read one more impulse
		cmp     bh,NIMP         ; read enough
		jz      wait_sync
		jmp     short imp_again



wait_sync:      call    ReadCycle
		cmp     ax,HI_SYNC
		jnc     no_sync
		cmp     ax,LOW_SYNC
		jc      prep_l8bits
no_sync:        mov     bh,NIMP-1
		jmp     short another_imp


;       The routine as found as impulse folowed by a syncronishm pulse.
; Now its time to load the data.

prep_l8bits:    mov     bl,0            ; load CRC-tape with 0
		mov     byte ptr ds:[colour],YELLOW
l8bits:         mov     bh,1            ; init reg with end-of-loop bit mark

		mov     word ptr ds:[bit_num],0

lbits:          call    ReadCycle
		cmp     ax,BAD_HI
		jnc     end_load

		; detect error logic (1)
;               cmp     cx,TRANSITION
;               cmc
;               rcl     byte ptr ds:[low_val],1
		; end of error logic (1)

		; signal means a 0 or 1? (the actual data bit is 0 or 1?)
		cmp     ax,TRANSITION
		cmc
		rcl     bh,1            ; insert bit in register

		; detect error logic (2)
;               pushf
;               xor     byte ptr ds:[low_val],1
;               test    byte ptr ds:[low_val],1
;               jz      no_biterr
;               lea     di, berr_tab
;               add     di, word ptr ds:[bit_num]
;               cmp     di,1
;               jz      no_biterr
;               cmp     di,0
;               jnz     another_bit
;               mov     word ptr ds:[di],si
;               jmp     short no_biterr
;another_bit:    mov    word ptr ds:[di],1
;no_biterr:     popf
		; end of error logic (2)

		jc      byte_read       ; jump if end mark found

		inc     word ptr cs:[bit_num]

		jmp     short lbits

						; now a byte was read
byte_read:      mov     byte ptr es:[si],bh     ; keep it
		xor     bl,bh                   ; update Spectrum CRC
		inc     si                      ; increment pointer
		jmp     l8bits                  ; load next byte

end_load:       ; as this is a pure read from tape with no help from a
		; emulator, we have no chances to know when we're 
		; finished. We only arrive here after a error in the
		; main routine. [error == end of data]


		mov     al,byte ptr ds:[copy_p61h]
		out     61h,al                  ; restore value

		mov     ah,0
		call    Border

		sti

		cmp     si,1                    ; null body?
		ja      sa_block                ; 
		jmp     leave_this              ; go away...

sa_block:       dec     si
		dec     si
		mov     word ptr es:[0],si      ; len of block in .TAP file
		inc     si
		inc     si

		cmp     byte ptr ds:[SpecCRC],0
		jz      ok_2_load

		; error correction logic here...
;               or      bl,bl
;               jz      all_korret

;               mov     byte ptr ds:[CRC_block],bl
;               lea     di,bit_val
;               lea     dx,berr_tab
;               mov     cx,8

;@@loop_bits:    mov    bx,dx
;               mov     ax,word ptr ds:[bx]
;               mov     bx,ax
;               cmp     bx,1
;               jbe     @@no_good
;
;                mov    al, byte ptr ds:[di]
;               test    [CRC_block],al
;               jz      @@no_good

;               xor     byte ptr es:[bx],al
;               xor     byte ptr es:[si-1],al
;               xor     byte ptr ds:[CRC_block],al

;@@no_good:      inc    di
;               inc     dx
;               inc     dx
;               loop    @@loop_bits
;               mov     bl, byte ptr ds:[CRC_block]
		; end of error correction logic

all_korret:     cmp     bl,0
		jz      ok_2_load
		lea     dx,tape_error
		PRINT_STRING

		jmp     leave_this

		; try to open file      (.TAP file)
ok_2_load:      mov     ax,3d01h
		mov     dx,offset file
		int     21h
		jnc     file_open2

		; if it doesn't exist create it
		mov     ah,3ch
		xor     cx,cx
		int     21h
		jc      leave_prog

file_open2:     ; copy file handle to bx
		mov     bx,ax

		; seek to end of file
		mov     ax,4202h
		xor     cx,cx
		xor     dx,dx
		int     21h

		push    ds
		push    es
		pop     ds

		mov     dx,0                    ; beginning of block in DS
		mov     cx,si                   ; len of block (+2 for len)
		mov     ah,40h                  ; write it
		int     21h

		pop     ds

			       ; close file
		mov     ah,3eh
		int     21h

		cmp     si,21                   ; not a header block
		jnz     exit
		cmp     byte ptr es:[2],0
		jne     exit
		cmp     byte ptr es:[3],0
		jnz     no_basic
		lea     dx,b_program
		jmp     all_ok
no_basic:       cmp     byte ptr es:[3],3
		jnz     exit
		lea     dx,b_code

all_ok:         PRINT_STRING

		mov     bh,0
		mov     di,4
another_char:   mov     al,byte ptr es:[di]
		cmp     al,32
		jnc     char_ok
		mov     al,'?'
char_ok:        mov     ah,0eh
		int     10h
		inc     di
		cmp     di,14
		jnz     another_char            

exit:           lea     dx,messg_good
		PRINT_STRING

leave_this:     jmp     begin

leave_prog:     
		mov     al,byte ptr ds:[copy_p61h]
		out     61h,al                  ; restore value

		mov     ah,0
		call    Border
		sti

		cmp     word ptr ds:[sb_base_addr],0
		jz      no_sb_present

		RESTORE_MIXER
no_sb_present:
		RTC2DOSCLK

		mov     ax,4c00h
		int     21h

bcd_2_dec       proc    near
		mov     dl,al
		shr     al,4
		mul     byte ptr ds:[value_10]
		and     dl,0fh
		add     al,dl
		ret
bcd_2_dec       endp

InitRead        proc    near

@@wait_v:       READ_PIT
		call    GiveCount

		cmp     byte ptr ds:[colour],YELLOW
		jne     @@leave_r
		cmp     ax,WAIT_VAL
		jc      @@wait_v
;               cmp     ax,cx
;               jc      @@wait_v

@@leave_r:      ret
InitRead        endp

GiveCount       proc    near
		sub     ax,bp           ; find difference
		jns     @@end_cnt       ; if difference negative
		neg     ax              ; correct value
@@end_cnt:
		ret
GiveCount       endp

ReadVal         proc    near
		TEST_BREAK
		cmp     word ptr ds:[sb_base_addr],0
		jnz     @@use_sb

		READ_LPT
		jmp     short @@sound

@@use_sb:       READ_SB

@@sound:        pushf
		cmp     byte ptr ds:[speaker_on],0
		jz      @@leave

		pushf
		popf
@@noisy:        BEEP_IT

@@leave:        popf
		ret
ReadVal         endp

Border          proc    near            ; ah = border colour
		COLOUR_BORDER   ah
		ret
Border          endp

n_zeros         dw      0
n_ones          dw      0
l_zero          dw      0
l_one           dw      0

SampleVal       proc    near    ; Read (or try) to read a pulse from the tape
		READ_PIT
		mov     word ptr ds:[init_sampl],ax

		xor     ax,ax
		mov     word ptr ds:[n_zeros],ax
		mov     word ptr ds:[n_ones],ax
@@loop:         call    ReadVal
		jz      @@is_zero
		READ_PIT
		mov     word ptr ds:[l_one],ax
		cmp     word ptr ds:[n_zeros],0
		jnz     @@dec_czeros
		cmp     word ptr ds:[n_ones],0ffffh
		jz      short @@end
		inc     word ptr ds:[n_ones]
		jmp     short @@end
@@dec_czeros:   dec     word ptr ds:[n_zeros]
		jmp     short @@end

@@is_zero:      READ_PIT
		mov     word ptr ds:[l_zero],ax
		cmp     word ptr ds:[n_ones],0
		jnz     @@dec_cones
		cmp     word ptr ds:[n_zeros],0ffffh
		jz      short @@end
		inc     word ptr ds:[n_zeros]
		jmp     short @@end
@@dec_cones:    dec     word ptr ds:[n_ones]

@@end:          READ_PIT
		sub     ax,word ptr ds:[init_sampl]
		jns     @@sign_ok
		neg     ax
@@sign_ok:      cmp     ax,100
		jb      @@loop

		mov     ax,word ptr ds:[n_zeros]
		cmp     ax,word ptr ds:[n_ones]
		ret
SampleVal       endp


ReadCycle       proc    near            ; try to read a bit from the tape.
		mov     ah,BLUE
		call    Border
		mov     bp,word ptr ds:[l_one]
		xor     cx,cx
		call    InitRead
@@low_part:     ;call   ReadVal
		call    SampleVal
		jae     @@low_part
		mov     ax,word ptr ds:[l_zero]
		call    GiveCount
		mov     cx,ax

		cmp     ax,BAD_HI
		jnc     @@leave_read

		mov     ah,byte ptr ds:[colour]
		call    Border
		mov     bp,word ptr ds:[l_zero]
		call    InitRead

@@hi_part:      ;call   ReadVal
		call    SampleVal
		jbe     @@hi_part
		mov     ax,word ptr ds:[l_one]
		call    GiveCount
@@leave_read:   ret
ReadCycle       endp

; * SB prog part
ResetDSP        proc    near
		RESET_DSP
		ret
ResetDSP        endp

; get arguments from  command line
ReadCmdLine     proc    near
		mov     ah,51h         
		int     21h
		mov     es,bx   ; DS=PSP
		mov     bx,080h ; PSP:80 = line arguments
@@another_ch:   inc     bx
		mov     ah,byte ptr es:[bx]
		cmp     ah,0dh  ; end of line?
		jz      @@exit  ; jump if yes
		cmp     ah,'d'  ; disable soundblaster detection (and use)?
		jnz     @@another_ch
		mov     byte ptr ds:[sb_on],0
@@exit:         ret
ReadCmdLine     endp

; DATA part
input_s         db      0
line_vol        db      0
cd_vol          db      0
mic_vol         db      0
master_vol      db      0

sb_on           db      1       ; SB detection is ON by default
speaker_on      db      1       ; speaker is on by default

init_sampl      dw      0

SpecCRC         db      1       ; if CRC is active==1
CRC_block       db      0       ; the actual CRC value
low_val         db      0
bit_num         dw      0
berr_tab        dw      8 dup (0)
bit_val         db      01h, 02h, 04h, 08h, 10h, 20h, 40h, 80h

file            db 'w1.tap', 0  ; name of the file created in current dir
value_10        db      10
copy_p61h       db      0
colour          db      0       ; actual color of border
printer_port    dw      0379h
b_program       db      0dh, 0ah, 'Program : $'
b_code          db      0dh, 0ah, 'Bytes   : $'
w_error         db      0dh, 0ah, 'This program cannot be run under Windows.'
		db      0dh, 0ah
		db      'It must run outside a multitasking environment.'
		db	0dh, 0ah
                db      'If you''re running Windows''95 please run '
		db	'TapeStub instead.'
		db      0dh, 0ah, '$'
copyright       db      0dh, 0ah
		db      'Tape2Tap v1.20 --- reads ZX Spectrum''s tapes in the Pc.'
		db      0dh, 0ah
		db      'Copyright December 1995-September 1996'
		db      ', Rui Fernando Ferreira Ribeiro.'
		db      0dh, 0ah
		db      0dh, 0ah
		db      '$'

messg_begin     db      0dh, 0ah
		db      'You can press at any time:'
		db      0dh, 0ah, 0dh, 0ah
		db      ' - ESC exit program.', 0dh, 0ah
		db      ' - S   turn speaker on.', 0dh, 0ah
		db      ' - N   turn speaker off.', 0dh, 0ah
		db      ' - 1   disable block CRC.', 0dh, 0ah
		db      ' - 2   enable  block CRC.', 0dh, 0ah
		db	' - P   use printer port for input data.', 0dh, 0ah
		db      0dh, 0ah
		db      '$'

error_mem       db      0dh, 0ah
		db      ' Not enough free memory to run the program.'
		db      0dh, 0ah, '$'

tape_error      db      0dh, 0ah
		db      ' Tape loading error! Rewind and try again this block.'
		db      0dh, 0ah, '$'

messg_good      db      0dh, 0ah
		db      ' Tape block load sucefully.'
		db      0dh, 0ah, '$'

;* SB data part

sb_base_addr    dw      0

sb_not_found    db      0dh, 0ah
		db      ' SoundBlaster not found.'
		db      0dh, 0ah
		db      ' Using printer port to digitise data.'
		db      0dh, 0ah, 0dh, 0ah, '$'

sb_found        db      0dh, 0ah
		db      ' SoundBlaster found at port 2'
port_sb         db      '00.', 0dh, 0ah
		db      'Using it to digitise data.'
		db      0dh, 0ah, 0dh, 0ah, '$'

stackseg  segment para STACK 'STACK'    ; Definition of stack segment

		db 512 dup ('S')        ; The stack comprises 256 words

stackseg  ends                          ; End of stack segment

		end     begin_code

; EOF: Tape2Tap.asm
