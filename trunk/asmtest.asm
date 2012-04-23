; S3M player library assembler example
;
; (c) 1997 Firehawk/Dawn <jh@paranoia.tuug.org>
;
.386p

_STAK   segment dword stack use32 'STACK'
        db 1000h dup(?)
_STAK   ends

_TEXT           segment use32 dword public 'CODE'
assume          cs:_TEXT, ds:_TEXT

include         s3mlib.inc
include         music.inc

entrypoint:
        jmp     _main
        db      'WATCOM'
_main:
        ; enable interrupts
        mov     ax, 0901h
        int     31h

        ; GUS configuration
        mov     ds:[_s3m_sd_type], 1
        mov     ds:[_s3m_sd_iobase], 240h
        mov     ds:[_s3m_sd_irq], 11
        mov     ds:[_s3m_sd_dma], 1

        ; SB configuration
;        mov     ds:[_s3m_sd_type], 2
;        mov     ds:[_s3m_sd_iobase], 220h
;        mov     ds:[_s3m_sd_irq], 5
;        mov     ds:[_s3m_sd_dma], 1

        ; feed module to the player
        push    ds
        pop     es
        lea     esi, music
        call    s3m_loadmodule

        call    s3m_startplaying

        mov     ah, 9
        mov     edx, offset playmsg
        int     21h
@@play:
        in      al, 60h
        cmp     al, 1
        jnz     @@play
        call    s3m_stopplaying


        mov     ah, 4ch
        int     21h

playmsg         db      13,10,'Playing, press ESC to stop...$'

_TEXT           ends

end             _main
