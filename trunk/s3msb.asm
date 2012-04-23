; S3M player library Sound Blaster functions
;
; (c) 1997 Firehawk/Dawn <jh@paranoia.tuug.org>
;

;#### SB_LOADSAMPLE
;#### in:  ebp=samplenumber, es:esi=ptr. to sample (set smp_* vars first!)
;#### out: -
sb_loadsample:
        ;move samples from memory to allocated pseudo-DRAM
        ret

;#### SB_INIT
;#### in:  eax=channels used
;#### out: -
sb_init:
        mov     dx, [_s3m_sd_iobase]
        mov     al, 1
        add     dx, 6
        out     dx, al
        mov     cx, 40
@@reset_dsp:
        in      al, dx
        loop    @@reset_dsp
        mov     al, 0
        out     dx, al
        add     dx, 8
        mov     cx, 100
@@reset_checkport:
        in      al, dx
        and     al, 80h
        jz      @@reset_notready
        sub     dx, 4
        in      al, dx
        add     dx, 4
        cmp     al, 0AAh
        je      @@reset_ok
@@reset_notready:
        loop    @@reset_checkport
@@reset_failed:
        stc
        ret
@@reset_ok:
        ; get dsp revision
        mov     al, 0e1h
        call    sb_writedsp
        call    sb_readdsp
        mov     bl, al
        call    sb_readdsp
        cmp     bl, 2                   ;>2.0?
        jb      @@reset_failed          ;ei..

        ; initialize some more sb stuff...

        ; alloc 1mb of memory to mimic the DRAM that's on
        ; GUS boards.

        clc
        ret

;#### SB_STARTPLAYING
;#### in:  -
;#### out: -
sb_startplaying:
        ;hook irq
        ;start dma
        ret

;#### SB_STOPPLAYING
;#### in:  -
;#### out: -
sb_stopplaying:
        ;setop dma
        ;restore irq
        ret

;!! TODO: dma-irq handler. mixes dataa to a buffer and calls trackframe

;in: al=dsp command
sb_writedsp:
        push    ax
        mov     dx, [_s3m_sd_iobase]
        add     dx, 0ch
@@write_wait:
        in      al, dx
        and     al, 80h
        jnz     @@write_wait
        pop     ax
        out     dx, al
        ret

;out: al=byte from dsp
sb_readdsp:
        mov     dx, [_s3m_sd_iobase]
        add     dx, 0eh
@@read_wait:
        in      al, dx
        and     al, 80h
        jz      @@read_wait
        sub     dx, 4
        in      al, dx
        ret

sb_enableirq:
        mov     cl, [_s3m_sd_irq]
        mov     ah, 1
        shl     ah, cl
        not     ah
        in      al, 21h
        mov     [oldsbirq], al
        and     al, ah
        out     21h, al
        ret
oldsbirq        db      0

sb_ackirq:
        mov     dx, [_s3m_sd_iobase]
        add     dx, 0eh
        in      al, dx
        ret
