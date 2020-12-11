; S3M player core functions
;
; (c) 1997 Firehawk/Dawn 
;

; include player device interface
include         s3mdev.asm

public  _s3m_synchroval, _s3m_synchrocount, _s3m_loopcount

;#### DPMI_MALLOC
;#### in:  ecx=bytes to allocate
;#### out: ax=descriptor, ebx=handle, CF=1 if failure
dpmi_malloc:
        push    edx
        mov     ds:[tempsize], ecx
        ; descriptor
        xor     ax, ax
        mov     cx, 1
        int     31h
        jc      @@malloc_failed
        mov     ds:[tempsel], ax
        ; memory block
        mov     ax, 501h
        mov     bx, word ptr [tempsize+2]
        mov     cx, word ptr [tempsize]
        int     31h
        jc      @@malloc_failed
        mov     word ptr [temphandle+2], si
        mov     word ptr [temphandle], di
        ; base
        mov     ax, 7
        mov     dx, cx
        mov     cx, bx
        mov     bx, ds:[tempsel]
        int     31h
        jc      @@malloc_failed
        ; limit
        dec     ds:[tempsize]
        mov     ax, 8
        mov     bx, ds:[tempsel]
        mov     cx, word ptr [tempsize+2]
        mov     dx, word ptr [tempsize]
        int     31h
        jc      @@malloc_failed
        ; return values to caller
        mov     ax, ds:[tempsel]
        mov     ebx, ds:[temphandle]
        pop     edx
        clc
        ret
@@malloc_failed:
        pop     edx
        stc
        ret


;#### DPMI_FREE
;#### in:  ax=descriptor, ebx=handle
;#### out: -
dpmi_free:
        push    ebx
        ; descriptor
        mov     bx, ax
        mov     ax, 1
        int     31h
        jc      @@free_failed
        ; block
        pop     esi
        mov     edi, esi
        shr     esi, 16
        and     edi, 0ffffh
        mov     ax, 502h
        int     31h
        jc      @@free_failed
        clc
        ret
@@free_failed:
        stc
        ret


;#### S3M_LOADER
;#### in:  es:esi=far pointer to module
;#### out: CF=1 on error
s3m_loader:
        ; store code dataselector for furher use (interrupt)
        mov     ds:[codedatasel], ds

        ; intialize some variables
        mov     _s3m_synchroval, 0
        mov     _s3m_synchrocount, 0
        mov     _s3m_loopcount, 0
        mov     ds:[frame], -1
        mov     ds:[row], 0
        mov     ds:[pattern], 0
        mov     ds:[order], 0
        mov     ds:[speed], 6
        mov     ds:[tempo], 07dh
        mov     ds:[globalvol], 64

        ; initialize order list
        xor     ebp, ebp
@@initialize_orders:
        mov     ds:[orderlist+ebp], 255
        inc     ebp
        cmp     ebp, 255
        jnz     @@initialize_orders

        ; initialize channels
        xor     ebp, ebp
@@initialize_channels:
        mov     ds:[chn_mapping+ebp], 255
        mov     ds:[chn_sample+ebp], 0
        mov     ds:[chn_panning+ebp], 7
        mov     ds:[chn_flags+ebp], 0
        mov     ds:[chn_volume+ebp], 0
        mov     ds:[chn_period+ebp], 0
        inc     ebp
        cmp     ebp, 32
        jnz     @@initialize_channels

        mov     ds:[moduleoffset], esi
        cmp     es:[esi+s3m.hdr_songtag], 'MRCS'
        jnz     @@loader_failure
        cmp     es:[esi+s3m.hdr_songtype], 16
        jnz     @@loader_failure

        mov     al, es:[esi+s3m.hdr_globalvol]
        mov     ds:[globalvol], al
        mov     al, es:[esi+s3m.hdr_initspeed]
        mov     ds:[speed], al
        mov     al, es:[esi+s3m.hdr_inittempo]
        mov     ds:[tempo], al
        mov     ax, es:[esi+s3m.hdr_insnum]
        mov     ds:[insnum], ax
        mov     ax, es:[esi+s3m.hdr_patnum]
        mov     ds:[patnum], ax
        mov     ax, es:[esi+s3m.hdr_flags]
        mov     ds:[s3mflags], ax

        mov     ds:[highestchannel], 0
        mov     cx, 32
        xor     ebx, ebx
@@loader_remaploop:
        mov     ds:[chn_mapping+ebx], 255
        mov     al, es:[esi+s3m.hdr_chanset+ebx]
        cmp     al, 16
        jae     @@loader_noremap
        mov     ds:[highestchannel], bl
        mov     ds:[chn_mapping+ebx], bl
        cmp     al, 7
        ja      @@loader_panright
        mov     ds:[chn_panning+ebx], 03h
        jmp     @@loader_noremap
@@loader_panright:
        mov     ds:[chn_panning+ebx], 0ch
@@loader_noremap:
        inc     ebx
        dec     cx
        jnz     @@loader_remaploop
        inc     ds:[highestchannel]

        xor     ebx, ebx
        mov     cx, es:[esi+s3m.hdr_ordnum]
        mov     ebp, 60h
@@loader_orderloop:
        mov     al, es:[esi+ebp]
        inc     ebp
        mov     ds:[orderlist+ebx], al
        inc     ebx
        dec     cx
        jnz     @@loader_orderloop
        mov     al, ds:[orderlist]
        mov     ds:[pattern], al

        cmp     es:[esi+s3m.hdr_defpanning], 0fch
        jnz     @@loader_nodefpan
        movzx   ebx, es:[esi+s3m.hdr_insnum]
        movzx   ecx, es:[esi+s3m.hdr_patnum]
        add     ebx, ecx
        shl     ebx, 1
        movzx   ecx, es:[esi+s3m.hdr_ordnum]
        add     ebx, ecx
        add     ebx, 060h
        add     ebx, esi
        mov     ecx, 32
        xor     ebp, ebp
@@loader_defpanloop:
        mov     al, es:[ebx+ebp]
        and     al, 0fh
        mov     ds:[chn_panning+ebp], al
        inc     ebp
        dec     ecx
        jnz     @@loader_defpanloop
@@loader_nodefpan:

        test    es:[esi+s3m.hdr_mastervol], 128
        jnz     @@loader_usestereo
        mov     ecx, 32
        xor     ebp, ebp
@@loader_panmonoloop:
        mov     ds:[chn_panning+ebp], 07h
        inc     ebp
        dec     ecx
        jnz     @@loader_panmonoloop
@@loader_usestereo:

        movzx   ebp, es:[esi+s3m.hdr_ordnum]
        add     ebp, 60h
        add     ebp, esi
        xor     ebx, ebx
@@loader_getinstruments:
        movzx   edi, word ptr es:[ebp+ebx*2]
        shl     edi, 4
        mov     al, es:[esi+edi.ins_type]
        cmp     al, 1
        jnz     @@loader_nosample
        movzx   eax, byte ptr es:[esi+edi.ins_memseg]
        shl     eax, 16
        mov     ax, word ptr es:[esi+edi.ins_memseg+1]
        shl     eax, 4
        mov     ds:[smp_mempos+ebx*4], eax ;temp ptr. to sample
        mov     eax, es:[esi+edi.ins_length]
        mov     ds:[smp_length+ebx*4], eax
        mov     eax, es:[esi+edi.ins_loopbeg]
        mov     ds:[smp_loopbeg+ebx*4], eax
        mov     eax, es:[esi+edi.ins_loopend]
        mov     ds:[smp_loopend+ebx*4], eax
        mov     al, es:[esi+edi.ins_volume]
        mov     ds:[smp_volume+ebx], al
        mov     al, es:[esi+edi.ins_flags]
        mov     ds:[smp_flags+ebx], al
        mov     eax, es:[esi+edi.ins_c2spd]
        mov     ds:[smp_c2spd+ebx*4], eax
        mov     al, es:[esi+edi.ins_type]
        mov     ds:[smp_type+ebx], al
@@loader_nosample:
        inc     ebx
        movzx   eax, es:[esi+s3m.hdr_insnum]
        cmp     ebx, eax
        jnz     @@loader_getinstruments

        ;swap module offset register
        mov     edx, esi

        ;allocate memory for pattern
        movzx   ecx, es:[edx+s3m.hdr_patnum]
        imul    ecx, ecx, 64*32*5
        call    dpmi_malloc
        jc      @@loader_failure
        mov     ds:[pattsel], ax
        mov     ds:[patthandle], ebx

        ;clear pattern
        push    gs
        movzx   ecx, es:[edx+s3m.hdr_patnum]
        imul    ecx, ecx, 64*32
        mov     gs, ds:[pattsel]
        xor     ebx, ebx
@@loader_inipatt:
        mov     byte ptr gs:[ebx], 255
        mov     dword ptr gs:[ebx+1], 00ffff00h
        add     ebx, 5
        dec     ecx
        jnz     @@loader_inipatt
        pop     gs

        push    gs
        movzx   ebp, es:[edx+s3m.hdr_insnum]
        shl     ebp, 1
        movzx   eax, es:[edx+s3m.hdr_ordnum]
        add     ebp, eax
        add     ebp, 60h
        add     ebp, edx        ;!!!!!!!!!!!
        xor     ebx, ebx
        mov     gs, ds:[pattsel]
@@loader_getpatterns:
        movzx   esi, word ptr es:[ebp+ebx*2]
        shl     esi, 4
        imul    edi, ebx, 64*32*5
        push    ebp
        push    ebx
        add     esi, 2
        xor     ecx, ecx        ; ecx=row
@@loader_noteloop:
        mov     al, es:[edx+esi]    ; al=noteinfo
        inc     esi
        cmp     al, 0           ; al=0, rowend
        jz      @@loader_rowok
        movzx   ebx, al
        and     ebx, 31
        imul    ebx, ebx, 5     ; ebx=channel*5
        test    al, 32
        jz      @@loader_testvol
        mov     ah, es:[edx+esi]     ;note
        mov     gs:[edi+ebx], ah
        inc     esi
        mov     ah, es:[edx+esi]     ;instr
        mov     gs:[edi+ebx+1], ah
        inc     esi
@@loader_testvol:
        test    al, 64
        jz      @@loader_testfx
        mov     ah, es:[edx+esi]    ;vol
        mov     gs:[edi+ebx+2], ah
        inc     esi
@@loader_testfx:
        test    al, 128
        jz      @@loader_noteok
        mov     ah, es:[edx+esi]    ;fx
        mov     gs:[edi+ebx+3], ah
        inc     esi
        mov     ah, es:[edx+esi]    ;infobyte
        mov     gs:[edi+ebx+4], ah
        inc     esi
@@loader_noteok:
        jmp     @@loader_noteloop
@@loader_rowok:
        add     edi, 32*5
        inc     ecx
        cmp     ecx, 64
        jnz     @@loader_noteloop
        pop     ebx
        pop     ebp
        inc     ebx
        movzx   eax, es:[edx+s3m.hdr_patnum]
        cmp     ebx, eax
        jnz     @@loader_getpatterns
        pop     gs

        xor     ebp, ebp
@@loader_uploadsample:
        cmp     ds:[smp_type+ebp], 1
        jnz     @@loader_skipsample
        mov     esi, ds:[smp_mempos+ebp*4]
        add     esi, edx
        push    edx
        call    s3m_sd_loadsample
        pop     edx
@@loader_skipsample:
        inc     ebp
        movzx   eax, es:[edx+s3m.hdr_insnum]
        cmp     ebp, eax
        jnz     @@loader_uploadsample

        ; send pannings to device??
        ; TODO

        movzx   eax, ds:[orderlist]
        mov     ds:[pattern], al
        imul    eax, eax, 64*32*5
        mov     ds:[rowoffset], eax

        ; done..
        clc
        ret
@@loader_failure:
        stc
        ret


;#### S3M_TRACKFRAME
;#### in:  -
;#### out: -
s3m_trackframe:
        push    ds
        push    es
        mov     es, cs:[pattsel]
        mov     ds, cs:[codedatasel]

        inc     ds:[frame]
        mov     al, ds:[speed]
        cmp     ds:[frame], al
        jb      @@trackframe_patternok
        mov     ds:[frame], 0

        cmp     ds:[plr_pattdelay], 0       ;!!
        jnz     @@trackframe_calcnewrow     ;!!
        inc     ds:[row]

@@trackframe_calcnewrow:
        add     ds:[rowoffset], 32*5
@@trackframe_testpattern:
        cmp     ds:[row], 64
        jb      @@trackframe_patternok
@@trackframe_nextpattern:
        mov     ds:[plr_pattlooprow], 0
        mov     ds:[plr_pattloopnbr], 0
        mov     ds:[row], 0
        inc     ds:[order]
        movzx   ebx, ds:[order]
        mov     al, ds:[orderlist+ebx]
        mov     ds:[pattern], al
        cmp     ds:[pattern], 254
        jz      @@trackframe_nextpattern
        cmp     ds:[pattern], 255
        jnz     @@trackframe_patternok
        mov     ds:[order], -1
        inc     _s3m_loopcount
        jmp     @@trackframe_nextpattern
@@trackframe_patternok:
        cmp     ds:[frame], 0
        jnz     @@trackframe_processfx

        cmp     ds:[plr_pattdelay], 0   ;!!
        jz      @@trackframe_nodelay    ;!!
        dec     ds:[plr_pattdelay]      ;!!
        jmp     @@trackframe_skipupdate ;!!
@@trackframe_nodelay:

        movzx   eax, ds:[pattern]
        imul    eax, eax, 64*32*5
        mov     ds:[rowoffset], eax
        movzx   eax, ds:[row]
        imul    eax, eax, 32*5
        add     ds:[rowoffset], eax
        mov     esi, ds:[rowoffset]

        mov     ds:[plr_flags], 0
        xor     ebp, ebp
@@trackframe_loopchannels:
        push    ebp
        cmp     ds:[chn_mapping+ebp], 255
        jz      @@trackframe_skipchannel

        mov     ds:[chn_flags+ebp], 0

        ; skip the whole thing if the effect is SDx
        cmp     byte ptr es:[esi+3], 19  ;S..
        jnz     @@trackframe_check
        mov     al, es:[esi+4]
        shr     al, 4
        cmp     al, 0dh         ;Dx
        jz      @@trackframe_checkeffect

@@trackframe_check:
        movzx   eax, byte ptr es:[esi+1]
        cmp     al, 0
        jz      @@trackframe_checkvolume
        dec     eax
        mov     ds:[chn_sample+ebp], al
        mov     al, ds:[smp_volume+eax]
        mov     ds:[chn_volume+ebp], al
        or      ds:[chn_flags+ebp], CHN_NEWVOLUME
@@trackframe_checkvolume:
        mov     al, es:[esi+2]
        cmp     al, 255
        jz      @@trackframe_checknote
        mov     ds:[chn_volume+ebp], al
        or      ds:[chn_flags+ebp], CHN_NEWVOLUME
@@trackframe_checknote:
        movzx   eax, byte ptr es:[esi]
        cmp     al, 0ffh
        jz      @@trackframe_checkeffect
        cmp     al, 0feh
        jz      @@trackframe_noteoff
        mov     ah, es:[esi+3]
        cmp     ah, 7 ; tone portamento
        jz      @@trackframe_checkeffect
        cmp     ah, 12 ; porta+volslide
        jz      @@trackframe_checkeffect
        mov     ecx, eax
        and     eax, 0fh ;note
        shr     ecx, 4   ;octave
        and     ecx, 0fh
        imul    ecx, ecx, 12
        add     ecx, eax
        mov     ds:[chn_arpnote+ebp], cl
        mov     al, cl
        movzx   eax, al
        movzx   eax, ds:[periodtab+eax*2]
        imul    eax, eax, 8363
        movzx   ecx, byte ptr ds:[chn_sample+ebp]
        mov     ecx, ds:[smp_c2spd+ecx*4]
        xor     edx, edx
        div     ecx
        mov     ds:[chn_period+ebp*2], ax
        mov     ds:[chn_vibratopos+ebp], 0
        or      ds:[chn_flags+ebp], CHN_NEWPITCH+CHN_TRIGSAMPLE
        jmp     @@trackframe_checkeffect
@@trackframe_noteoff:
        or      ds:[chn_flags+ebp], CHN_NOTEOFF
@@trackframe_checkeffect:
        movzx   eax, byte ptr es:[esi+3]
        cmp     al, 255
        jz      @@trackframe_skipchannel
        cmp     al, 0
        jz      @@trackframe_skipchannel
        dec     eax
        mov     edi, ds:[effect_jump_f0+eax*4]
        mov     bl, es:[esi+4]
        call    edi

@@trackframe_skipchannel:
        add     esi, 5
        pop     ebp
        inc     ebp
        movzx   eax, ds:[highestchannel]
        cmp     ebp, eax
        jb      @@trackframe_loopchannels
@@trackframe_skipupdate:
        pop     es
        pop     ds
        ret

@@trackframe_processfx:
        mov     esi, ds:[rowoffset]
        xor     ebp, ebp
@@trackframe_loopchannelsfx:
        push    ebp
        mov     ds:[chn_flags+ebp], 0   ; clear channel flags
        movzx   eax, byte ptr es:[esi+3]
        cmp     al, 255
        jz      @@trackframe_skipchannelfx
        cmp     al, 0
        jz      @@trackframe_skipchannelfx
        dec     eax
        mov     edi, ds:[effect_jump_fn+eax*4]
        mov     bl, es:[esi+4]
        call    edi
@@trackframe_skipchannelfx:
        add     esi, 5
        pop     ebp
        inc     ebp
        movzx   eax, ds:[highestchannel]
        cmp     ebp, eax
        jb      @@trackframe_loopchannelsfx
        pop     es
        pop     ds
        ret

;#### EFFECT_F0_?
;#### in:  bl=infobyte
;#### out: -
effect_f0_a:
        mov     ds:[speed], bl
        ret

effect_f0_b:
        test    ds:[plr_flags], PLR_PATTJUMP
        jnz     @@effect_f0_b_out
        and     ebx, 0ffh
        mov     ds:[order], bl
        mov     al, ds:[orderlist+ebx]
        mov     ds:[pattern], al
        mov     ds:[row], -1
        or      ds:[plr_flags], PLR_PATTJUMP
        mov     ds:[plr_pattlooprow], 0              ;!!
        mov     ds:[plr_pattloopnbr], 0              ;!!
@@effect_f0_b_out:
        ret

effect_f0_c:
        mov     al, bl
        and     eax, 0fh
        shr     ebx, 4
        and     ebx, 0fh
        imul    ebx, ebx, 10
        add     eax, ebx
        mov     ds:[row], al
        dec     ds:[row]
        cmp     ds:[row], 62
        jna     @@effect_f0_c_order
        mov     ds:[row], -1
@@effect_f0_c_order:
        mov     ds:[plr_pattlooprow], 0              ;!!
        mov     ds:[plr_pattloopnbr], 0              ;!!
        test    ds:[plr_flags], PLR_PATTJUMP+PLR_PATTBREAK
        jnz     @@effect_f0_c_out

        inc     ds:[order]
        movzx   ebx, ds:[order]
        mov     al, ds:[orderlist+ebx]
        mov     ds:[pattern], al
        cmp     ds:[pattern], 254
        jz      @@effect_f0_c_order
        cmp     ds:[pattern], 255
        jnz     @@effect_f0_c_out
        mov     ds:[order], -1
        jmp     @@effect_f0_c_order

@@effect_f0_c_out:
        or      ds:[plr_flags], PLR_PATTBREAK
        ret

effect_f0_d:
        cmp     bl, 0
        jz      @@effect_f0_d_fine
        mov     ds:[chn_volslide+ebp], bl
@@effect_f0_d_fine:
        mov     al, ds:[chn_volslide+ebp]
        mov     bl, al
        and     bl, 0fh
        cmp     bl, 0fh
        jz      @@effect_f0_d_fine_up
        mov     bl, al
        shr     bl, 4
        cmp     bl, 0fh
        jnz     @@effect_f0_d_checkold
@@effect_f0_d_fine_down:
        and     al, 0fh
        sub     ds:[chn_volume+ebp], al
        cmp     ds:[chn_volume+ebp], 0
        jge     @@effect_f0_d_fine_ok
        mov     ds:[chn_volume+ebp], 0
        jmp     @@effect_f0_d_fine_ok
@@effect_f0_d_fine_up:
        shr     al, 4
        add     ds:[chn_volume+ebp], al
        cmp     ds:[chn_volume+ebp], 63
        jle     @@effect_f0_d_fine_ok
        mov     ds:[chn_volume+ebp], 63
        jmp     @@effect_f0_d_fine_ok
@@effect_f0_d_checkold:
        test    ds:[s3mflags], 64
        jz      @@effect_f0_d_out
        call    effect_fn_d
@@effect_f0_d_fine_ok:
        or      ds:[chn_flags+ebp], CHN_NEWVOLUME
@@effect_f0_d_out:
        ret

effect_f0_e:
        cmp     bl, 0
        jz      @@effect_f0_e_fineslide
        mov     ds:[chn_portaspeed+ebp], bl
@@effect_f0_e_fineslide:
        mov     al, ds:[chn_portaspeed+ebp]
        mov     bl, al
        and     bx, 0fh
        test    bl, 0e0h
        jz      @@effect_f0_e_extrafine
@@effect_f0_e_fine:
        test    al, 0f0h
        jnz     @@effect_f0_e_out
        shl     bl, 2
@@effect_f0_e_extrafine:
        add     ds:[chn_period+ebp*2], bx
        cmp     word ptr ds:[chn_period+ebp*2], 27392
        jle     @@effect_f0_e_fine_ok
        ;too large period, stop voice
        mov     ds:[chn_period+ebp*2], 27392
        or      ds:[chn_flags+ebp], CHN_NOTEOFF
@@effect_f0_e_fine_ok:
        or      ds:[chn_flags+ebp], CHN_NEWPITCH
@@effect_f0_e_out:
        ret

effect_f0_f:
        cmp     bl, 0
        jz      @@effect_f0_f_fineslide
        mov     ds:[chn_portaspeed+ebp], bl
@@effect_f0_f_fineslide:
        mov     al, ds:[chn_portaspeed+ebp]
        mov     bl, al
        and     bx, 0fh
        test    bl, 0e0h
        jz      @@effect_f0_f_extrafine
@@effect_f0_f_fine:
        test    al, 0f0h
        jnz     @@effect_f0_f_out
        shl     bl, 2
@@effect_f0_f_extrafine:
        sub     ds:[chn_period+ebp*2], bx
        cmp     word ptr ds:[chn_period+ebp*2], 56
        jge     @@effect_f0_f_fine_ok
        ; period too small, stop voice
        mov     ds:[chn_period+ebp*2], 56
        or      ds:[chn_flags+ebp], CHN_NOTEOFF
@@effect_f0_f_fine_ok:
        or      ds:[chn_flags+ebp], CHN_NEWPITCH
@@effect_f0_f_out:
        ret

effect_f0_g:
        mov     al, es:[esi]
        cmp     al, 254
        jae     @@effect_f0_g_speed
        mov     cl, al
        and     eax, 0fh ;note
        shr     cl, 4
        and     ecx, 0fh ;octave
        imul    ecx, ecx, 12
        add     eax, ecx
        movzx   eax, al
        movzx   eax, ds:[periodtab+eax*2]
        imul    eax, eax, 8363
        movzx   ecx, byte ptr ds:[chn_sample+ebp]
        mov     ecx, ds:[smp_c2spd+ecx*4]
        xor     edx, edx
        div     ecx
        mov     ds:[chn_portaperiod+ebp*2], ax
@@effect_f0_g_speed:
        mov     al, bl
        cmp     al, 0
        jz      @@effect_f0_g_out
        mov     ds:[chn_portaspeed+ebp], al
@@effect_f0_g_out:
        ret

effect_f0_h:
;        and     ds:[chn_flags+ebp], not chn_newfreq
        mov     al, bl
        and     al, 0fh ;depth
        shr     bl, 4   ;speed
        cmp     al, 0
        jz      @@effect_f0_h_chkspeed
        mov     ds:[chn_vibratodep+ebp], al
@@effect_f0_h_chkspeed:
        cmp     bl, 0
        jz      @@effect_f0_h_out
        mov     ds:[chn_vibratospd+ebp], bl
@@effect_f0_h_out:
        ret

effect_f0_i:
        ;tremor
        ret

effect_f0_j:
        mov     al, bl
        cmp     al, 0
        jz      @@effect_f0_j_playarp
        mov     ds:[chn_arpchord+ebp], al
@@effect_f0_j_playarp:
        mov     al, ds:[chn_arpnote+ebp]
        movzx   eax, al
        shl     eax, 1
        movzx   eax, ds:[periodtab+eax]
        imul    eax, eax, 8363
        movzx   ecx, ds:[chn_sample+ebp]
        mov     ecx, ds:[smp_c2spd+ecx*4]
        xor     edx, edx
        div     ecx
        movzx   ebx, ax
        mov     ds:[chn_fxperiod+ebp*2], bx
        or      ds:[chn_flags+ebp], CHN_PITCHEFFECT
        ret

effect_f0_k:
        call    effect_f0_d
        ret

effect_f0_l:
        push    bx
        mov     al, es:[esi]
        cmp     al, 254
        jae     @@effect_f0_l_d
        mov     cl, al
        and     eax, 0fh ;note
        shr     cl, 4
        and     ecx, 0fh ;octave
        imul    ecx, ecx, 12
        add     eax, ecx
        movzx   eax, al
        movzx   eax, ds:[periodtab+eax*2]
        imul    eax, eax, 8363
        movzx   ecx, byte ptr ds:[chn_sample+ebp]
        mov     ecx, ds:[smp_c2spd+ecx*4]
        xor     edx, edx
        div     ecx
        mov     ds:[chn_portaperiod+ebp*2], ax
@@effect_f0_l_d:
        pop     bx
        call    effect_f0_d
        ret

effect_f0_m:
        ; not used
        ret

effect_f0_n:
        ; not used
        ret

effect_f0_o:
        or      ds:[chn_flags+ebp], CHN_USEOFFSET
        cmp     bl, 0
        jz      @@effect_f0_o_out
        and     ebx, 0ffh
        shl     ebx, 8
        movzx   eax, ds:[chn_sample+ebp]
;        cmp     ebx, ds:[smp_loopend+eax*4]
        cmp     ebx, ds:[smp_length+eax*4]
        jbe     @@effect_f0_o_ok
        mov     ebx, ds:[smp_loopend+eax*4]
@@effect_f0_o_ok:
        mov     ds:[chn_offset+ebp*4], ebx
@@effect_f0_o_out:
        ret

effect_f0_p:
        ; not used
        ret

effect_f0_q:
        ;store retrig parameters if bl!=0
        cmp     bl, 0
        jz      @@effect_f0_q_oldparam
        mov     ds:[chn_retrdelay+ebp], bl
        mov     ds:[chn_retrvolchg+ebp], bl
        and     ds:[chn_retrdelay+ebp], 0fh
        shr     ds:[chn_retrvolchg+ebp], 4

        ; run retrig right away if necessary
@@effect_f0_q_oldparam:
        call    effect_fn_q
        ret

effect_f0_r:
        ; tremolo
        ret

effect_f0_s:
        ; special commands S0x-SFx
        movzx   eax, bl
        shr     eax, 4
        mov     edi, ds:[effect_jump_s0+eax*4]
        and     bl, 0fh
        call    edi
        ret

effect_f0_t:
        cmp     bl, 0
        jz      @@effect_f0_t_out
        mov     ds:[tempo], bl
        or      ds:[plr_flags], PLR_NEWBPM
@@effect_f0_t_out:
        ret

effect_f0_u:
        ; fine vibrato
        ret

effect_f0_v:
        ; set global volume
        mov     ds:[globalvol], bl
        ret

effect_f0_w:
        ; used for synchronizing to music
        mov     _s3m_synchroval, bl
        inc     _s3m_synchrocount
        ret

effect_f0_x:
        ; not used
        ret

effect_f0_y:
        ; not used
        ret

effect_f0_z:
        ; not used
        ret


;#### EFFECT_FN_?
;#### in:  bl=infobyte
;#### out: -
effect_fn_a:
        ; nothing here
        ret

effect_fn_b:
        ; nothing here
        ret

effect_fn_c:
        ; nothing here
        ret

effect_fn_d:
        mov     al, ds:[chn_volslide+ebp]
        mov     bl, al
        and     bl, 0fh
        cmp     bl, 0
        jz      @@effect_fn_d_slide_up
        mov     bl, al
        shr     bl, 4
        cmp     bl, 0
        jnz     @@effect_fn_d_out
@@effect_fn_d_slide_down:
        and     al, 0fh
        sub     ds:[chn_volume+ebp], al
        cmp     ds:[chn_volume+ebp], 0
        jge     @@effect_fn_d_ok
        mov     ds:[chn_volume+ebp], 0
        jmp     @@effect_fn_d_ok
@@effect_fn_d_slide_up:
        shr     al, 4
        add     ds:[chn_volume+ebp], al
        cmp     ds:[chn_volume+ebp], 63
        jle     @@effect_fn_d_ok
        mov     ds:[chn_volume+ebp], 63
@@effect_fn_d_ok:
        mov     bl, ds:[chn_volume+ebp]
        or      ds:[chn_flags+ebp], CHN_NEWVOLUME
@@effect_fn_d_out:
        ret

effect_fn_e:
        movzx   ax, byte ptr ds:[chn_portaspeed+ebp]
        cmp     ax, 0e0h
        jae     @@effect_fn_e_out
        shl     ax, 2
        add     ds:[chn_period+ebp*2], ax
        cmp     word ptr ds:[chn_period+ebp*2], 27392
        jle     @@effect_fn_e_ok
        ;too large period, stop voice
        mov     ds:[chn_period+ebp*2], 27392
        or      ds:[chn_flags+ebp], CHN_NOTEOFF
@@effect_fn_e_ok:
        or      ds:[chn_flags+ebp], CHN_NEWPITCH
@@effect_fn_e_out:
        ret

effect_fn_f:
        movzx   ax, byte ptr ds:[chn_portaspeed+ebp]
        cmp     ax, 0e0h
        jae     @@effect_fn_f_out
        shl     ax, 2
        sub     ds:[chn_period+ebp*2], ax
        cmp     word ptr ds:[chn_period+ebp*2], 56
        jge     @@effect_fn_f_ok
        ;too small period, stop voice
        mov     ds:[chn_period+ebp*2], 56
        or      ds:[chn_flags+ebp], CHN_NOTEOFF
@@effect_fn_f_ok:
        or      ds:[chn_flags+ebp], CHN_NEWPITCH
@@effect_fn_f_out:
        ret

effect_fn_g:
        movzx   bx, byte ptr ds:[chn_portaspeed+ebp]
        shl     bx, 2
        mov     ax, word ptr ds:[chn_portaperiod+ebp*2]
        cmp     word ptr ds:[chn_period+ebp*2], ax
        jb      @@effect_f0_g_incperiod
        sub     word ptr ds:[chn_period+ebp*2], bx
        cmp     word ptr ds:[chn_period+ebp*2], ax
        jnl     @@effect_f0_g_ok
        mov     word ptr ds:[chn_period+ebp*2], ax
        jmp     @@effect_f0_g_ok
@@effect_f0_g_incperiod:
        add     word ptr ds:[chn_period+ebp*2], bx
        cmp     word ptr ds:[chn_period+ebp*2], ax
        jng     @@effect_f0_g_ok
        mov     word ptr ds:[chn_period+ebp*2], ax
@@effect_f0_g_ok:
        or      ds:[chn_flags+ebp], CHN_NEWPITCH
        ret

effect_fn_h:
        mov     al, ds:[chn_vibratopos+ebp]
        and     eax, 31  ;quotient of divide by 32
        movzx   ebx, ds:[vibratotab+eax] ;sine
        movzx   eax, ds:[chn_vibratodep+ebp] ;depth
        imul    ebx, eax
        shr     ebx, 7
        shl     ebx, 2 ;bx=delta
        and     ebx, 0ffffh
        cmp     ds:[chn_vibratopos+ebp], 32
        jb      @@effect_fn_h_addfreq
        neg     bx
@@effect_fn_h_addfreq:
        add     bx, ds:[chn_period+ebp*2]
        mov     ds:[chn_fxperiod+ebp*2], bx
        or      ds:[chn_flags+ebp], CHN_PITCHEFFECT

@@player_fx_Hxy_incpos:
        mov     al, ds:[chn_vibratospd+ebp]
        add     ds:[chn_vibratopos+ebp], al
        cmp     ds:[chn_vibratopos+ebp], 64
        jb      @@effect_fn_h_out
        sub     ds:[chn_vibratopos+ebp], 64
@@effect_fn_h_out:
        ret

effect_fn_i:
        ; tremor
        ret

effect_fn_j:
        movzx   ax, byte ptr ds:[frame]
        mov     bl, 3
        div     bl      ;ah=frame mod 3
        cmp     ah, 0
        jz      @@effect_fn_j_firsttone
        cmp     ah, 1
        jz      @@effect_fn_j_secondtone
@@effect_fn_j_thirdtone:
        mov     al, ds:[chn_arpchord+ebp]
        and     al, 0fh
        add     al, ds:[chn_arpnote+ebp]
        jmp     @@effect_fn_j_playtone
@@effect_fn_j_secondtone:
        mov     al, ds:[chn_arpchord+ebp]
        shr     al, 4
        add     al, ds:[chn_arpnote+ebp]
        jmp     @@effect_fn_j_playtone
@@effect_fn_j_firsttone:
        mov     al, ds:[chn_arpnote+ebp]
@@effect_fn_j_playtone:
        movzx   eax, al
        shl     eax, 1
        movzx   eax, ds:[periodtab+eax]
        imul    eax, eax, 8363
        movzx   ecx, ds:[chn_sample+ebp]
        mov     ecx, ds:[smp_c2spd+ecx*4]
        xor     edx, edx
        div     ecx
        movzx   ebx, ax
        mov     ds:[chn_fxperiod+ebp*2], bx
        or      ds:[chn_flags+ebp], CHN_PITCHEFFECT
        ret

effect_fn_k:
        call    effect_fn_d
        call    effect_fn_h
        ret

effect_fn_l:
        call    effect_fn_d
        call    effect_fn_g
        ret

effect_fn_m:
        ; not used
        ret

effect_fn_n:
        ; not used
        ret

effect_fn_o:
        ; nothing here
        ret

effect_fn_p:
        ; not used
        ret

effect_fn_q:
        mov     bl, ds:[chn_retrdelay+ebp]
        cmp     bl, 0
        jz      @@effect_fn_q_out
        mov     al, ds:[frame]
        div     bl     ;ah=modulo
        cmp     ah, 0
        jnz     @@effect_fn_q_out
        or      ds:[chn_flags+ebp], CHN_TRIGSAMPLE
        ; alter volume
        movzx   eax, byte ptr ds:[chn_retrvolchg+ebp]
        mov     edi, ds:[retrig_voljump+eax*4]
        call    edi
        or      ds:[chn_flags+ebp], CHN_NEWVOLUME
@@effect_fn_q_out:
        ret

effect_fn_r:
        ; tremolo
        ret

effect_fn_s:
        ; special commands S0x-SFx
        movzx   eax, bl
        shr     eax, 4
        mov     edi, ds:[effect_jump_sn+eax*4]
        and     bl, 0fh
        call    edi
        ret

effect_fn_t:
        ; nothing here
        ret

effect_fn_u:
        ; fine vibrato
        ret

effect_fn_v:
        ; set global volume
        ret

effect_fn_w:
        ; not used
        ret

effect_fn_x:
        ; not used
        ret

effect_fn_y:
        ; not used
        ret

effect_fn_z:
        ; not used
        ret


;#### EFFECT_S0_?
;#### in:  bl=infobyte
;#### out: -
effect_s0_0:
        ; set filter (not used)
        ret

effect_s0_1:
        ; set glissando control
        ret

effect_s0_2:
        ; set finetune
        ret

effect_s0_3:
        ; set vibrato waveform
        ret

effect_s0_4:
        ; set tremolo waveform
        ret

effect_s0_5:
        ; not used
        ret

effect_s0_6:
        ; not used
        ret

effect_s0_7:
        ; not used
        ret

effect_s0_8:
        ; set channel pan position
        ret

effect_s0_9:
        ; not used
        ret

effect_s0_a:
        ; stereo control (not used)
        ret

effect_s0_b:
        cmp     bl, 0
        jnz     @@effect_s0_b_doloop
        mov     al, ds:[row]
        mov     ds:[plr_pattlooprow], al
        ret
@@effect_s0_b_doloop:
        cmp     ds:[plr_pattloopnbr], 0
        jnz     @@effect_s0_b_dec
        mov     ds:[plr_pattloopnbr], bl
        jmp     @@effect_s0_b_testjump
@@effect_s0_b_dec:
        dec     ds:[plr_pattloopnbr]
@@effect_s0_b_testjump:
        cmp     ds:[plr_pattloopnbr], 0
        jz      @@effect_s0_b_out
        mov     al, ds:[plr_pattlooprow]
        mov     ds:[row], al
        dec     ds:[row]
@@effect_s0_b_out:
        ret

effect_s0_c:
        ; note cut
        ret

effect_s0_d:
        call    effect_sn_d
        ret

effect_s0_e:
        ; patterndelay
        cmp     bl, 0
        jz      @@effect_s0_e_out
        mov     ds:[plr_pattdelay], bl
@@effect_s0_e_out:
        ret

effect_s0_f:
        ; funkrepeat (not used)
        ret


;#### EFFECT_SN_?
;#### in:  bl=infobyte
;#### out: -
effect_sn_0:
        ; set filter (not used)
        ret

effect_sn_1:
        ; set glissando control
        ret

effect_sn_2:
        ; set finetune
        ret

effect_sn_3:
        ; set vibrato waveform
        ret

effect_sn_4:
        ; set tremolo waveform
        ret

effect_sn_5:
        ; not used
        ret

effect_sn_6:
        ; not used
        ret

effect_sn_7:
        ; not used
        ret

effect_sn_8:
        ; set channel pan position
        ret

effect_sn_9:
        ; not used
        ret

effect_sn_a:
        ; stereo control (not used)
        ret

effect_sn_b:
        ; nothing here (pattern loop)
        ret

effect_sn_c:
        cmp     bl, ds:[frame]
        jnz     @@effect_sn_c_out
        mov     ds:[chn_volume+ebp], 0
        or      ds:[chn_flags+ebp], CHN_NEWVOLUME
@@effect_sn_c_out:
        ret

effect_sn_d:
        cmp     bl, ds:[frame]
        jnz     @@effect_sn_d_out
        movzx   eax, byte ptr es:[esi+1]
        cmp     al, 0
        jz      @@effect_sn_d_checkvolume
        dec     eax
        mov     ds:[chn_sample+ebp], al
        mov     al, ds:[smp_volume+eax]
        mov     ds:[chn_volume+ebp], al
        or      ds:[chn_flags+ebp], CHN_NEWVOLUME
@@effect_sn_d_checkvolume:
        mov     al, es:[esi+2]
        cmp     al, 255
        jz      @@effect_sn_d_checknote
        mov     ds:[chn_volume+ebp], al
        or      ds:[chn_flags+ebp], CHN_NEWVOLUME
@@effect_sn_d_checknote:
        movzx   eax, byte ptr es:[esi]
        cmp     al, 0ffh
        jz      @@effect_sn_d_out
        cmp     al, 0feh
        jz      @@effect_sn_d_noteoff
        mov     ah, es:[esi+3]
        cmp     ah, 7 ; tone portamento
        jz      @@effect_sn_d_out
        cmp     ah, 12 ; porta+volslide
        jz      @@effect_sn_d_out
        mov     ecx, eax
        and     eax, 0fh ;nuotti
        shr     ecx, 4   ;oktaavi
        and     ecx, 0fh
        imul    ecx, ecx, 12
        add     ecx, eax
        mov     ds:[chn_arpnote+ebp], cl
        mov     al, cl
        movzx   eax, al
        movzx   eax, ds:[periodtab+eax*2]
        imul    eax, eax, 8363
        movzx   ecx, byte ptr ds:[chn_sample+ebp]
        mov     ecx, ds:[smp_c2spd+ecx*4]
        xor     edx, edx
        div     ecx
        mov     ds:[chn_period+ebp*2], ax
        mov     ds:[chn_vibratopos+ebp], 0
        or      ds:[chn_flags+ebp], CHN_NEWPITCH+CHN_TRIGSAMPLE
        jmp     @@effect_sn_d_out
@@effect_sn_d_noteoff:
        or      ds:[chn_flags+ebp], CHN_NOTEOFF
@@effect_sn_d_out:
        ret

effect_sn_e:
        ; patterndelay
        ret

effect_sn_f:
        ; funkrepeat (not used)
        ret


;#### RETRIG_VOLJUMP_?
;#### in:  -
;#### out: -
retrig_voljump_0:
        jmp     retrig_voljump_out_s
retrig_voljump_1:
        sub     ds:[chn_volume+ebp], 1
        jmp     retrig_voljump_out_s
retrig_voljump_2:
        sub     ds:[chn_volume+ebp], 2
        jmp     retrig_voljump_out_s
retrig_voljump_3:
        sub     ds:[chn_volume+ebp], 4
        jmp     retrig_voljump_out_s
retrig_voljump_4:
        sub     ds:[chn_volume+ebp], 8
        jmp     retrig_voljump_out_s
retrig_voljump_5:
        sub     ds:[chn_volume+ebp], 16
        jmp     retrig_voljump_out_s
retrig_voljump_6:
        movzx   ax, byte ptr ds:[chn_volume+ebp]
        shl     ax, 1
        mov     cl, 3
        div     cl
        mov     ds:[chn_volume+ebp], al
        jmp     retrig_voljump_out_s
retrig_voljump_7:
        shr     ds:[chn_volume+ebp], 1
        jmp     retrig_voljump_out_s
retrig_voljump_8:
        jmp     retrig_voljump_out_a
retrig_voljump_9:
        add     ds:[chn_volume+ebp], 1
        jmp     retrig_voljump_out_a
retrig_voljump_a:
        add     ds:[chn_volume+ebp], 2
        jmp     retrig_voljump_out_a
retrig_voljump_b:
        add     ds:[chn_volume+ebp], 4
        jmp     retrig_voljump_out_a
retrig_voljump_c:
        add     ds:[chn_volume+ebp], 8
        jmp     retrig_voljump_out_a
retrig_voljump_d:
        add     ds:[chn_volume+ebp], 16
        jmp     retrig_voljump_out_a
retrig_voljump_e:
        movzx   ax, byte ptr ds:[chn_volume+ebp]
        mov     cx, ax
        add     ax, ax
        add     ax, cx
        shr     ax, 1
        mov     ds:[chn_volume+ebp], al
        jmp     retrig_voljump_out_a
retrig_voljump_f:
        shl     ds:[chn_volume+ebp], 1
        jmp     retrig_voljump_out_a
retrig_voljump_out_s:
        ;volume decreased
        cmp     ds:[chn_volume+ebp], 64
        jna     retrig_voljump_out
        mov     ds:[chn_volume+ebp], 0
        jmp     retrig_voljump_out
retrig_voljump_out_a:
        ;volume increased
        cmp     ds:[chn_volume+ebp], 64
        jna     retrig_voljump_out
        mov     ds:[chn_volume+ebp], 64
retrig_voljump_out:
        ret


effect_jump_f0  label   dword
                dd      offset effect_f0_a
                dd      offset effect_f0_b
                dd      offset effect_f0_c
                dd      offset effect_f0_d
                dd      offset effect_f0_e
                dd      offset effect_f0_f
                dd      offset effect_f0_g
                dd      offset effect_f0_h
                dd      offset effect_f0_i
                dd      offset effect_f0_j
                dd      offset effect_f0_k
                dd      offset effect_f0_l
                dd      offset effect_f0_m
                dd      offset effect_f0_n
                dd      offset effect_f0_o
                dd      offset effect_f0_p
                dd      offset effect_f0_q
                dd      offset effect_f0_r
                dd      offset effect_f0_s
                dd      offset effect_f0_t
                dd      offset effect_f0_u
                dd      offset effect_f0_v
                dd      offset effect_f0_w
                dd      offset effect_f0_x
                dd      offset effect_f0_y
                dd      offset effect_f0_z

effect_jump_fn  label   dword
                dd      offset effect_fn_a
                dd      offset effect_fn_b
                dd      offset effect_fn_c
                dd      offset effect_fn_d
                dd      offset effect_fn_e
                dd      offset effect_fn_f
                dd      offset effect_fn_g
                dd      offset effect_fn_h
                dd      offset effect_fn_i
                dd      offset effect_fn_j
                dd      offset effect_fn_k
                dd      offset effect_fn_l
                dd      offset effect_fn_m
                dd      offset effect_fn_n
                dd      offset effect_fn_o
                dd      offset effect_fn_p
                dd      offset effect_fn_q
                dd      offset effect_fn_r
                dd      offset effect_fn_s
                dd      offset effect_fn_t
                dd      offset effect_fn_u
                dd      offset effect_fn_v
                dd      offset effect_fn_w
                dd      offset effect_fn_x
                dd      offset effect_fn_y
                dd      offset effect_fn_z

effect_jump_s0  label   dword
                dd      offset effect_s0_0
                dd      offset effect_s0_1
                dd      offset effect_s0_2
                dd      offset effect_s0_3
                dd      offset effect_s0_4
                dd      offset effect_s0_5
                dd      offset effect_s0_6
                dd      offset effect_s0_7
                dd      offset effect_s0_8
                dd      offset effect_s0_9
                dd      offset effect_s0_a
                dd      offset effect_s0_b
                dd      offset effect_s0_c
                dd      offset effect_s0_d
                dd      offset effect_s0_e
                dd      offset effect_s0_f

effect_jump_sn  label   dword
                dd      offset effect_sn_0
                dd      offset effect_sn_1
                dd      offset effect_sn_2
                dd      offset effect_sn_3
                dd      offset effect_sn_4
                dd      offset effect_sn_5
                dd      offset effect_sn_6
                dd      offset effect_sn_7
                dd      offset effect_sn_8
                dd      offset effect_sn_9
                dd      offset effect_sn_a
                dd      offset effect_sn_b
                dd      offset effect_sn_c
                dd      offset effect_sn_d
                dd      offset effect_sn_e
                dd      offset effect_sn_f

retrig_voljump  label   dword
                dd      offset retrig_voljump_0
                dd      offset retrig_voljump_1
                dd      offset retrig_voljump_2
                dd      offset retrig_voljump_3
                dd      offset retrig_voljump_4
                dd      offset retrig_voljump_5
                dd      offset retrig_voljump_6
                dd      offset retrig_voljump_7
                dd      offset retrig_voljump_8
                dd      offset retrig_voljump_9
                dd      offset retrig_voljump_a
                dd      offset retrig_voljump_b
                dd      offset retrig_voljump_c
                dd      offset retrig_voljump_d
                dd      offset retrig_voljump_e
                dd      offset retrig_voljump_f


s3m             equ     0

; temporary DPMI variables
temphandle      dd      0
tempsize        dd      0
tempsel         dw      0
textsel         dw      0


; channel flags
CHN_NEWPITCH    equ     1
CHN_NEWPANNING  equ     2
CHN_NEWVOLUME   equ     4
CHN_NEWSTATUS   equ     8
CHN_NOTEOFF     equ     16
CHN_TRIGSAMPLE  equ     32
CHN_PITCHEFFECT equ     64
CHN_USEOFFSET   equ     128
; player flags
PLR_NEWBPM      equ     1
PLR_PATTJUMP    equ     2
PLR_PATTBREAK   equ     4

; some tables
periodtab       dw 27392,25856,24384,23040,21696,20480,19328,18240,17216,16256,15360,14496
                dw 13696,12928,12192,11520,10848,10240, 9664, 9120, 8608, 8128, 7680, 7248
                dw  6848, 6464, 6096, 5760, 5424, 5120, 4832, 4560, 4304, 4064, 3840, 3624
                dw  3424, 3232, 3048, 2880, 2712, 2560, 2416, 2280, 2152, 2032, 1920, 1812
c4periods       dw  1712, 1616, 1524, 1440, 1356, 1280, 1208, 1140, 1076, 1016,  960,  906
                dw   856,  808,  762,  720,  678,  640,  604,  570,  538,  508,  480,  453
                dw   428,  404,  381,  360,  339,  320,  302,  285,  269,  254,  240,  226
                dw   214,  202,  190,  180,  170,  160,  151,  143,  135,  127,  120,  113
                dw   107,  101,   95,   90,   85,   80,   75,   71,   67,   63,   60,   56
vibratotab      db     0,   24,   49,   74,   97,  120,  141,  161
                db   180,  197,  212,  224,  235,  244,  250,  253
                db   255,  253,  250,  244,  235,  224,  212,  197
                db   180,  161,  141,  120,   97,   74,   49,   24

codedatasel     dw      0
pattsel         dw      0
patthandle      dd      0
moduleoffset    dd      0

s3mflags        dw      0
frame           db      0
row             db      0
rowoffset       dd      0
pattern         db      0
order           db      0
globalvol       db      0
speed           db      0
tempo           db      0
orderlist       db      255 dup (0)
insnum          dw      0
patnum          dw      0
highestchannel  db      0
memoffset       dd      0

plr_flags       db      0
plr_pattlooprow db      0
plr_pattloopnbr db      0
plr_pattdelay   db      0

chn_mapping     db      32 dup (0)
chn_panning     db      32 dup (0)
chn_flags       db      32 dup (0)
chn_period      dw      32 dup (0)
chn_sample      db      32 dup (0)
chn_volume      db      32 dup (0)
chn_vibratopos  db      32 dup (0)
chn_offset      dd      32 dup (0)
chn_volslide    db      32 dup (0)
chn_portaspeed  db      32 dup (0)
chn_portaperiod dw      32 dup (0)
chn_arpchord    db      32 dup (0)
chn_arpnote     db      32 dup (0)
chn_fxperiod    dw      32 dup (0)
chn_vibratospd  db      32 dup (0)
chn_vibratodep  db      32 dup (0)
chn_retrdelay   db      32 dup (0)
chn_retrvolchg  db      32 dup (0)

smp_type        db      100 dup (0)
smp_length      dd      100 dup (0)
smp_loopbeg     dd      100 dup (0)
smp_loopend     dd      100 dup (0)
smp_volume      db      100 dup (0)
smp_flags       db      100 dup (0)
smp_c2spd       dd      100 dup (8363)
smp_mempos      dd      100 dup (0)

s3m_header      struc
        hdr_songname    db      28 dup (?)
                        db      ?
        hdr_songtype    db      ?
                        dw      ?
        hdr_ordnum      dw      ?
        hdr_insnum      dw      ?
        hdr_patnum      dw      ?
        hdr_flags       dw      ?
        hdr_cwtv        dw      ?
        hdr_ffi         dw      ?
        hdr_songtag     dd      ?
        hdr_globalvol   db      ?
        hdr_initspeed   db      ?
        hdr_inittempo   db      ?
        hdr_mastervol   db      ?
        hdr_ultraclick  db      ?
        hdr_defpanning  db      ?
                        dd      2 dup (?)
        hdr_special     dw      ?
        hdr_chanset     db      32 dup (?)
                ends
s3m_insheader   struc
        ins_type        db      ?
        ins_filename    db      12 dup (?)
        ins_memseg      db      3 dup (?)
        ins_length      dd      ?
        ins_loopbeg     dd      ?
        ins_loopend     dd      ?
        ins_volume      db      ?
                        db      ?
        ins_pack        db      ?
        ins_flags       db      ?
        ins_c2spd       dd      ?
                        dd      ?
        ins_guspos      dw      ?
        ins_sb512       dw      ?
        ins_lastused    dd      ?
        ins_name        db      28 dup (?)
                        dd      ?
                ends

_s3m_synchroval         db      0
_s3m_synchrocount       db      0
_s3m_loopcount          db      0

