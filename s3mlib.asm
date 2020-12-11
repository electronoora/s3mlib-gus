; S3M player library core functions
;
; (c) 1997 Firehawk/Dawn 
;
.386p
.model flat,syscall
_TEXT           segment use32 dword public 'CODE'
assume          cs:_TEXT, ds:_TEXT

; include player code
include         s3mcore.asm

; make the interface functions and variables visible publicly
public s3m_initialize, s3m_startplaying, s3m_stopplaying, s3m_loadmodule
public _s3m_sd_type, _s3m_sd_iobase, _s3m_sd_irq, _s3m_sd_dma


;#### S3M_INITIALIZE
;#### in:  -
;#### out: -
s3m_initialize:
        pushad
        ; do some misc. initialization
        popad
        ret


;#### S3M_STARTPLAYING
;#### in:  -
;#### out: -
s3m_startplaying:
        pushad
        call    s3m_sd_init
        call    s3m_sd_startplaying
        popad
        ret


;#### S3M_STOPPLAYING
;#### in:  -
;#### out: -
s3m_stopplaying:
        pushad
        call    s3m_sd_stopplaying
        call    s3m_sd_uninit
        popad
        ret


;#### S3M_LOADMODULE
;#### in:  es:esi=far pointer to module
;#### out: CF=1 on error
s3m_loadmodule:
        pushad
        call    s3m_loader
        popad
        ret


_TEXT           ends
end
