; S3M player library sound device interface
;
; (c) 1997 Firehawk/Dawn 
;

;driver configuration
include         s3mconf.asm

;no sound device driver
ifdef   NO_DRIVER
include         s3mnos.asm
endif

;ultrasound device driver
ifdef   GUS_DRIVER
include         s3mgus.asm
endif

;soundblaster device driver
ifdef   SB_DRIVER
include         s3msb.asm
endif

;#### S3M_SD_LOADSAMPLE
;#### in:  ebx=samplenumber, es:esi=ptr. to sample (NOTE! set smp_* vars first)
;#### out: -
s3m_sd_loadsample:
        cmp     ds:[_s3m_sd_type], 0
        jz      @@s3m_sd_load_no
        cmp     ds:[_s3m_sd_type], 1
        jnz     @@s3m_sd_load_sb
ifdef   GUS_DRIVER
        call    gus_loadsample
endif
        jmp     @@s3m_sd_load_no
@@s3m_sd_load_sb:
ifdef   SB_DRIVER
        ;call    sb_loadsample
endif
        jmp     @@s3m_sd_load_out
@@s3m_sd_load_no:
ifdef   NO_DRIVER
        ;call    nos_loadsample
endif
@@s3m_sd_load_out:
        ret

;#### S3M_SD_INIT
;#### in:  ebx=channels used
;#### out: -
s3m_sd_init:
        cmp     ds:[_s3m_sd_type], 0
        jz      @@s3m_sd_init_no
        cmp     ds:[_s3m_sd_type], 1
        jnz     @@s3m_sd_init_sb
ifdef   GUS_DRIVER
        call    gus_init
endif
        jmp     @@s3m_sd_init_out
@@s3m_sd_init_sb:
ifdef   SB_DRIVER
        call    sb_init
endif
        jmp     @@s3m_sd_init_out
@@s3m_sd_init_no:
ifdef   NO_DRIVER
        call    nos_init
endif
@@s3m_sd_init_out:
        ret

;#### S3M_SD_UNINIT
;#### in:  -
;#### out: -
s3m_sd_uninit:
        cmp     ds:[_s3m_sd_type], 0
        jz      @@s3m_sd_uninit_no
        cmp     ds:[_s3m_sd_type], 1
        jnz     @@s3m_sd_uninit_sb
ifdef   GUS_DRIVER
        ;call    gus_uninit
endif
        jmp     @@s3m_sd_uninit_out
@@s3m_sd_uninit_sb:
ifdef   SB_DRIVER
        ;call    sb_uninit
endif
        jmp     @@s3m_sd_uninit_out
@@s3m_sd_uninit_no:
ifdef   NO_DRIVER
        ;call    nos_uninit
endif
@@s3m_sd_uninit_out:
        ret

;#### S3M_SD_STARTPLAYING
;#### in:  -
;#### out: -
s3m_sd_startplaying:
        cmp     ds:[_s3m_sd_type], 0
        jz      @@s3m_sd_start_no
        cmp     ds:[_s3m_sd_type], 1
        jnz     @@s3m_sd_start_sb
ifdef   GUS_DRIVER
        call    gus_startplaying
endif
        jmp     @@s3m_sd_start_out
@@s3m_sd_start_sb:
ifdef   SB_DRIVER
        call    sb_startplaying
endif
        jmp     @@s3m_sd_start_out
@@s3m_sd_start_no:
ifdef   NO_DRIVER
        call    nos_startplaying
endif

@@s3m_sd_start_out:
        ret

;#### S3M_SD_STOPPLAYING
;#### in:  -
;#### out: -
s3m_sd_stopplaying:
        cmp     ds:[_s3m_sd_type], 0
        jz      @@s3m_sd_stop_no
        cmp     ds:[_s3m_sd_type], 1
        jnz     @@s3m_sd_stop_sb
ifdef   GUS_DRIVER
        call    gus_stopplaying
endif
        jmp     @@s3m_sd_stop_out
@@s3m_sd_stop_sb:
ifdef   SB_DRIVER
        call    sb_stopplaying
endif
        jmp     @@s3m_sd_stop_out
@@s3m_sd_stop_no:
ifdef   NO_DRIVER
        call    nos_stopplaying
endif
@@s3m_sd_stop_out:
        call    s3m_sd_init
        ret

; devicen asetukset (kaikille yhteiset)
_s3m_sd_type     db      0
_s3m_sd_iobase   dw      0
_s3m_sd_irq      db      0
_s3m_sd_dma      db      0

