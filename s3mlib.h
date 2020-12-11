#ifndef _S3MLIB_H_
#define _S3MLIB_H_

void s3m_initialize(void);
#pragma aux s3m_initialize "*"

void s3m_startplaying(void);
#pragma aux s3m_startplaying "*"

void s3m_stopplaying(void);
#pragma aux s3m_stopplaying "*"

void s3m_loadmodule(void *module);
#pragma aux s3m_loadmodule "*" parm [esi]

extern unsigned char s3m_sd_type;
extern unsigned char s3m_sd_type;
extern unsigned short s3m_sd_iobase;
extern unsigned char s3m_sd_irq;
extern unsigned char s3m_sd_dma;
extern unsigned char s3m_synchroval;
extern unsigned char s3m_synchrocount;
extern unsigned char s3m_loopcount;

#endif
