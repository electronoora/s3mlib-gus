; S3M player library Ultrasound functions
;
; (c) 1997 Firehawk/Dawn <jh@paranoia.tuug.org>
;
; A few snippets borrowed from USMP by FreddyV/Useless and some from
; MXMP by Niklas Beisert. Thanks!
;

;#### GUS_LOADSAMPLE
;#### in:  ebp=samplenumber, es:esi=ptr. to sample (set smp_* vars first!)
;#### out: -
gus_loadsample:
        push    ebp
        push    ebx
        push    ecx

        mov     ecx, ds:[smp_length+ebp*4]
        mov     ebx, ds:[gusheaptop]
        mov     ds:[gus_sbegin+ebp*4], ebx
        push    esi
@@loadsample_pokeloop:
        mov     al, es:[esi]
        inc     esi
        xor     al, 80h
        call    gus_poke
        inc     ebx
        dec     ecx
        jnz     @@loadsample_pokeloop
        inc     ebx
        mov     ds:[gusheaptop], ebx
        pop     esi

        ; fix loopend & loopbeg plus remove some clicking
        test    ds:[smp_flags+ebp], 1
        jnz     @@loadsample_looping
        mov     ebx, ds:[gus_sbegin+ebp*4]
        mov     ds:[gus_slbeg+ebp*4], ebx

        mov     ebx, ds:[smp_length+ebp*4]
        add     ebx, ds:[gus_sbegin+ebp*4]
        mov     ds:[gus_slend+ebp*4], ebx
        xor     al, al
        call    gus_poke
        jmp     @@loadsample_nextsample
@@loadsample_looping:
        mov     ebx, ds:[smp_loopbeg+ebp*4]
        mov     al, es:[esi+ebx]
        xor     al, 80h
        mov     ebx, ds:[gus_sbegin+ebp*4]
        mov     ds:[gus_slbeg+ebp*4], ebx
        mov     ds:[gus_slend+ebp*4], ebx
        mov     ebx, ds:[smp_loopbeg+ebp*4]
        add     ds:[gus_slbeg+ebp*4], ebx
        mov     ebx, ds:[smp_loopend+ebp*4]
        add     ds:[gus_slend+ebp*4], ebx
        mov     ebx, ds:[gus_slend+ebp*4]
        call    gus_poke
@@loadsample_nextsample:
        pop     ecx
        pop     ebx
        pop     ebp
        ret

;#### GUS_INIT
;#### in:  eax=channels used
;#### out: -
gus_init:
        pushad
        cli

        ;release allocated gus dram
        mov     ds:[gusheaptop], 0

        ;reset gf1
        mov     al, 0
        mov     bl, 4ch
        call    gus_write
        call    gus_delay
        call    gus_delay
        mov     al, 1
        mov     bl, 4ch
        call    gus_write
        call    gus_delay
        call    gus_delay

        ;disable line out
        mov     dx, _s3m_sd_iobase
        in      al, dx
        or      al, 2
        out     dx, al

        ;set gf1 active voices (hardcoded to 16...)
        mov     gf1voices, 16
        mov     gf1freq, 38587
        mov     bl, 0eh
        mov     al, (16-1) OR 0ch
        call    gus_write

        ;clear voices
        mov     ebp, 0
@@chloop:
        ;vol to zero
        mov     ax, 1500h
        mov     bl, 9
        call    gus_voice_writew
        ;ramp off
        mov     al, 2
        mov     bl, 0dh
        call    gus_voice_write
        ;stop voice
        mov     al, 2
        mov     bl, 0
        call    gus_voice_write
        ;done
        inc     ebp
        cmp     ebp, 16
        jnz     @@chloop

        ;put gf1 to run mode and enable dacs
        mov     al, 3
        mov     bl, 04ch
        call    gus_write
        call    gus_delay
        call    gus_delay

        ;enable line out
        mov     dx, _s3m_sd_iobase
        in      al, dx
        and     al, 0ffh XOR 2
        out     dx, al

        sti
        popad
        ret

;#### GUS_STARTPLAYING
;#### in:  -
;#### out: -
gus_startplaying:
        cli
        ;save pm-int8
        mov     ax, 204h
        mov     bl, 8
        int     31h
        mov     dword ptr [old_pmint8], edx
        mov     word ptr [old_pmint8+4], cx
        ;hook pm-handler to int8
        mov     ax, 205h
        mov     bl, 8
        mov     cx, cs
        mov     edx, offset gus_pmhandler
        int     31h

        mov     al, [tempo]
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

;#### GUS_STOPPLAYING
;#### in:  -
;#### out: -
gus_stopplaying:
        cli
        ;restore pm-handler
        mov     ax, 205h
        mov     bl, 8
        mov     cx, word ptr [old_pmint8+4]
        mov     edx, dword ptr [old_pmint8]
        int     31h
        sti
        ret

gus_pmhandler:
        cli
        pushad
        push    ds
        push    es
        push    fs
        push    gs
        mov     ds, cs:[codedatasel]
        call    gus_playerint
        mov     al, 20h
        out     20h, al
        pop     gs
        pop     fs
        pop     es
        pop     ds
        popad
        sti
        iretd

gus_playerint:
        ; advance one frame
        call    s3m_trackframe

        ; check player flags
        test    ds:[plr_flags], PLR_NEWBPM
        jz      @@player_dochannels
        xor     edx, edx
        mov     eax, ds:[pctimermagic]
        movzx   ebx, ds:[tempo]
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

        ; check channel flags (except volume)
@@player_dochannels:
        xor     ebp, ebp
@@player_loop:
        test    ds:[chn_flags+ebp], CHN_TRIGSAMPLE
        jz      @@player_noteoff
        xor     ebx, ebx
        call    gus_setvolume ;vol to zero
        mov     bx, 3
        call    gus_setvmode
        movzx   esi, byte ptr ds:[chn_sample+ebp]
        mov     ebx, ds:[gus_sbegin+esi*4]
        test    ds:[chn_flags+ebp], CHN_USEOFFSET
        jz      @@player_nooffset
        add     ebx, ds:[chn_offset+ebp*4]
@@player_nooffset:
        call    gus_setpos
        mov     ebx, ds:[gus_slbeg+esi*4]
        call    gus_setloopbeg
        mov     ebx, ds:[gus_slend+esi*4]
        call    gus_setloopend
        mov     bl, ds:[smp_flags+esi]
        and     bl, 1
        shl     bl, 3
        call    gus_setvmode
        or      ds:[chn_flags+ebp], CHN_NEWVOLUME

@@player_noteoff:
        test    ds:[chn_flags+ebp], CHN_NOTEOFF
        jz      @@player_pitch
        mov     bx, 3
        call    gus_setvmode

@@player_pitch:
        test    ds:[chn_flags+ebp], CHN_NEWPITCH
        jz      @@player_panning
        movzx   ebx, ds:[chn_period+ebp*2]
        call    gus_setpitch

@@player_panning:
        test    ds:[chn_flags+ebp], CHN_NEWPANNING
        jz      @@player_arpeggio

@@player_arpeggio:
        test    ds:[chn_flags+ebp], CHN_PITCHEFFECT
        jz      @@player_nextchannel
        movzx   ebx, ds:[chn_fxperiod+ebp*2]
        call    gus_setpitch

@@player_nextchannel:
        inc     ebp
        movzx   eax, ds:[highestchannel]
        cmp     ebp, eax
        jnz     @@player_loop

        ; set volume
        xor     ebp, ebp
@@player_volume:
        test    ds:[chn_flags+ebp], CHN_NEWVOLUME
        jz      @@player_volume_loop
        movzx   eax, ds:[chn_volume+ebp]
        movzx   ebx, byte ptr ds:[globalvol]
        imul    ebx
        shr     eax, 6
        mov     ebx, eax
        call    gus_setvolume
@@player_volume_loop:
        inc     ebp
        movzx   eax, ds:[highestchannel]
        cmp     ebp, eax
        jnz     @@player_volume

        ret

;ebp=channel, ebx=s3mperiod
gus_setpitch:
        push    eax edx ebp
        cmp     bx, 0
        jz      @@gus_setfreq_out
        ;freq_hz   = 14317056 / s3mperiod
        mov     eax, 14317056
        xor     edx, edx
        div     ebx     ;eax=hz
        ;freq_gus  = (((hz << 9)+(divisortab[voices] >> 1)) / divisor) << 1
        shl     eax, 9
        movzx   ebx, gf1freq
        shr     ebx, 1
        add     eax, ebx
        xor     edx, edx
        movzx   ebx, gf1freq
        div     ebx
        shl     eax, 1          ;eax=gusfreq
        movzx   ebp, [chn_mapping+ebp]
        mov     ebx, 1
        call    gus_voice_writew
@@gus_setfreq_out:
        pop     ebp edx eax
        ret

;ebp=channel, bl=panning 0-15
gus_setpan:
        push    eax edx ebp
        movzx   ebp, [chn_mapping+ebp]
        mov     al, 0ch
        xchg    al, bl
        call    gus_voice_write
        pop     ebp edx eax
        ret

;ebx=offset, al=byte
gus_poke:
        push    ebx
        push    ax
        push    ebx
        mov     ax, 43h
        xchg    eax, ebx
        call    gus_writew
        mov     bx, 44h
        pop     eax
        shr     eax, 16
        call    gus_write
        pop     ax
        mov     dx, _s3m_sd_iobase
        add     dx, 107h
        out     dx, al
        pop     ebx
        ret

;ebp=channel, ebx=offset in DRAM
gus_setpos:
        push    eax edx ebp
        movzx   ebp, [chn_mapping+ebp]
        mov     eax, 0ah
        xchg    eax, ebx
        push    eax     ;address
        shr     eax, 7
        and     eax, 01fffh
        call    gus_voice_writew
        pop     eax
        and     eax, 7fh
        shl     eax, 9
        mov     bl, 0bh
        call    gus_voice_writew
        pop     ebp edx eax
        ret

;ebp=channel, ebx=offset in DRAM
gus_setloopbeg:
        push    eax edx ebp
        movzx   ebp, [chn_mapping+ebp]
        mov     eax, 02h
        xchg    eax, ebx
        push    eax     ;address
        shr     eax, 7
        and     eax, 01fffh
        call    gus_voice_writew
        pop     eax
        and     eax, 7fh
        shl     eax, 9
        mov     bl, 03h
        call    gus_voice_writew
        pop     ebp edx eax
        ret

;ebp=channel, ebx=offset in DRAM
gus_setloopend:
        push    eax edx ebp
        movzx   ebp, [chn_mapping+ebp]
        mov     eax, 04h
        xchg    eax, ebx
        push    eax     ;address
        shr     eax, 7
        and     eax, 01fffh
        call    gus_voice_writew
        pop     eax
        and     eax, 7fh
        shl     eax, 9
        mov     bl, 05h
        call    gus_voice_writew
        pop     ebp edx eax
        ret

;ebp=channel, bl=mode
gus_setvmode:
        push    eax edx ebp
        movzx   ebp, [chn_mapping+ebp]
        mov     al, 0
        xchg    al, bl
        call    gus_voice_write
        pop     ebp edx eax
        ret

;ebp=channel, bl=volume
gus_setvolume:
        push    ecx edx
        and     ebx, 0ffh
        mov     cx, [gus_volumes+ebx*2]
        shl     cx, 4

        mov     al, [chn_mapping+ebp]
        mov     dx, _s3m_sd_iobase
        add     dx, 102h
        out     dx, al
        inc     dx              ;3x3h
        mov     al, 89h
        out     dx, al
        inc     dx
        in      ax, dx ;current volume
        mov     bx, ax

        ;swap values so, that bx is smaller
        mov     bl, 0
        cmp     bh, ch
        jz      @@dontramp
        cmp     bh, ch
        jb      @@dontflip
        xchg    bh, ch
        mov     bl, 40h
@@dontflip:
        ;set ramp parameters
        dec     dx
        mov     al, 6
        out     dx, al
        add     dx, 2
        mov     al, 63 ;rate
        out     dx, al
        sub     dx, 2
        mov     al, 7
        out     dx, al
        add     dx, 2
        mov     al, bh ;rampstart
        out     dx, al
        sub     dx, 2
        mov     al, 8
        out     dx, al
        add     dx, 2
        mov     al, ch ;rampend
        out     dx, al
        sub     dx, 2
        mov     al, 0dh
        out     dx, al
        add     dx, 2
        mov     al, bl ;ramp control
        out     dx, al
        call    gus_delay
        out     dx, al
        ;wait for the ramp to end...
@@waitramp:
        sub     dx, 2
        mov     al, 8dh
        out     dx, al
        add     dx, 2
        in      al, dx
        test    al, 1
        jz      @@waitramp
@@dontramp:
        pop     edx ecx
        ret

;gus register access delay
gus_delay:
        push    ax cx dx
        mov     dx, 300h
        mov     cx, 7
@@dlp:  in      al, dx
        loop    @@dlp
        pop     dx cx ax
        ret

;write al to voice register bl of voice bp
gus_voice_write:
        push    ebp
        xchg    ax, bp
        mov     dx, _s3m_sd_iobase
        add     dx, 102h
        out     dx, al
        inc     dx
        xchg    al, bl
        out     dx, al
        xchg    ax, bp
        add     dx, 2
        out     dx, al
        call    gus_delay
        out     dx, al
        pop     ebp
        ret

;write ax to voice register bl of voice bp
gus_voice_writew:
        push    ebp
        xchg    ax, bp
        mov     dx, _s3m_sd_iobase
        add     dx, 102h
        out     dx, al
        inc     dx
        xchg    al, bl
        out     dx, al
        xchg    ax, bp
        inc     dx
        out     dx, ax
        call    gus_delay
        out     dx, ax
        pop     ebp
        ret

;write al to gus register bl
gus_write:
        push    edx
        mov     dx, _s3m_sd_iobase
        add     dx, 103h
        xchg    al, bl
        out     dx, al
        add     dx, 2
        xchg    al, bl
        out     dx, al
        pop     edx
        ret

;write ax to gus register bl
gus_writew:
        push    edx
        mov     dx, _s3m_sd_iobase
        add     dx, 103h
        xchg    al, bl
        out     dx, al
        inc     dx
        xchg    al, bl
        out     dx, ax
        pop     edx
        ret

gus_sbegin      dd      100 dup (?)
gus_slbeg       dd      100 dup (?)
gus_slend       dd      100 dup (?)
gusheaptop      dd      0
gf1voices       db      16
gf1freq         dw      38587
gus_volumes     dw      0150h,08f1h,09f1h,0ab5h,0af1h,0b97h,0bb5h,0bd3h
                dw      0bf1h,0c88h,0c97h,0ca6h,0cb5h,0cc4h,0cd3h,0ce2h
                dw      0cf1h,0d80h,0d88h,0d8fh,0d97h,0d9eh,0da6h,0dadh
                dw      0db5h,0dbch,0dc4h,0dcbh,0dd3h,0ddah,0de2h,0de9h
                dw      0df1h,0df8h,0e80h,0e84h,0e88h,0e8bh,0e8fh,0e93h
                dw      0e97h,0e9ah,0e9eh,0ea2h,0ea6h,0ea9h,0eadh,0eb1h
                dw      0eb5h,0eb8h,0ebch,0ec0h,0ec4h,0ec7h,0ecbh,0ecfh
                dw      0ed3h,0ed6h,0edah,0edeh,0ee2h,0ee5h,0ee9h,0eedh
                dw      0ef0h
gf1_freqtab     dw      44100,41160,38587,36317,34300,32494,30870,29400
                dw      28063,26843,25725,24696,23746,22866,22050,21289
                dw      20580,19916,19293
old_pmint8      dd      0
pctimermagic    dd      2d8426h

