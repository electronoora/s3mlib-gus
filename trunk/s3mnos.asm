; S3M player library 'no sound' functions
;
; (c) 1997 Firehawk/Dawn <jh@paranoia.tuug.org>
;

;#### NOS_LOADSAMPLE
;#### in:  ebp=samplenumber, es:esi=ptr. to sample (set smp_* vars first!)
;#### out: -
nos_loadsample:
        ret

;#### NOS_INIT
;#### in:  eax=channels used
;#### out: -
nos_init:
        ret

;#### NOS_STARTPLAYING
;#### in:  -
;#### out: -
nos_startplaying:
        cli
        ;store pm-int8
        mov     ax, 204h
        mov     bl, 8
        int     31h
        mov     dword ptr ds:[nos_oldint8], edx
        mov     word ptr ds:[nos_oldint8+4], cx
        ;hook pm-handler to int8
        mov     ax, 205h
        mov     bl, 8
        mov     cx, cs
        mov     edx, offset nos_pmhandler
        int     31h

        mov     al, ds:[tempo]
        mov     bl, al
        xor     edx, edx
        mov     eax, pctimermagic
        and     ebx, 0ffh
        div     ebx
        push    ax
        mov     dx, 43h
        mov     al, 36h
        out     dx, al
        mov     dx, 40h
        pop     ax
        out     dx, al
        shr     ax, 8
        out     dx, al

        sti
        ret

;#### NOS_STOPPLAYING
;#### in:  -
;#### out: -
nos_stopplaying:
        cli
        ;restore pm-handler
        mov     ax, 205h
        mov     bl, 8
        mov     cx, word ptr ds:[nos_oldint8+4]
        mov     edx, dword ptr ds:[nos_oldint8]
        int     31h
        sti
        ret

nos_pmhandler:
        cli
        pushad
        push    ds
        push    es
        push    fs
        push    gs
        mov     ds, cs:[codedatasel]
        call    nos_playerint
        mov     al, 20h
        out     20h, al
        pop     gs
        pop     fs
        pop     es
        pop     ds
        popad
        sti
        iretd

nos_playerint:
        ; advance one frame
        call    s3m_trackframe
        ret

nos_oldint8     dd      0
;pctimermagic    dd      2d8426h

