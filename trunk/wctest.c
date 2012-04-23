/*
 * S3M player library Watcom C example
 *
 * (c) 1997 Firehawk/Dawn <jh@paranoia.tuug.org>
 *
*/

#include <stdlib.h>
#include <stdio.h>
#include "s3mlib.h"

void main(void)
{
    FILE *f;
    unsigned char *buf;
    unsigned long fs;

    /* GUS configuration */
    s3m_sd_type=1;
    s3m_sd_iobase=0x240;
    s3m_sd_irq=11;
    s3m_sd_dma=1;

    /* SB configuration */
/*
    s3m_sd_type=2;
    s3m_sd_iobase=0x220;
    s3m_sd_irq=5;
    s3m_sd_dma=1;
*/

    printf("\nLoading module...");
    fflush(stdout);

    /* load module and feed it to the player */
    f=fopen("strike.s3m", "rb");
    fseek(f, 0, SEEK_END);
    fs=ftell(f);
    fseek(f, 0, SEEK_SET);
    buf=(unsigned char*)malloc(fs);
    fread(buf, 1, fs, f);
    fclose(f);
    s3m_loadmodule(buf);
    free(buf);

    printf("\nPlaying, press any key to stop...");
    fflush(stdout);
    s3m_startplaying();

    while(!kbhit());

    s3m_stopplaying();
}
