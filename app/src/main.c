#include "xparameters.h"


#include <xil_io.h>
#include <xil_printf.h>
#include <xil_types.h>
#include <xstatus.h>
#include <stdlib.h>

#include "xaxidma.h"
#include "xinterrupt_wrap.h"
#include "xtmrctr.h"

#include <xil_cache.h>

#include "xil_util.h"

typedef struct ProcessingParams {
    
    u16 ImgW;
    u16 ImgH;
    u16 FilterRadius;
    u16 FilterCoeffsScale;
    u16 FilterControl;
    _Bool Border;
    s16* FilterCoeffs;
}ProcessingParams;

XTmrCtr TimerInstance;

static int DmaConfigure(XAxiDma_Config* AxiDmaConfigPtr, XAxiDma* AxiDmaPtr);
static int DmaStartTransfers(XAxiDma* AxiDmaPtr, u8* TxBuffer, u32 TxSize, u8* RxBuffer, u32 RxSize);
static int DmaWaitTransfers(volatile u32* TxFlag, volatile u32* RxFlag, u32 Timeout);

static int AccConfigure(UINTPTR BaseAddress, ProcessingParams Params);

static void ImageFIlterSW(u8* DataBuffer, u8* ResultBuffer, ProcessingParams Params);
static int  ImageFIlterHW(u8* DataBuffer, u16* ResultBuffer, ProcessingParams Params);

static int CheckData(u16* ResultBuffer, u8* ReferentBuffer, ProcessingParams Params);

static void TxIntrHandler(void *Callback);
static void RxIntrHandler(void *Callback);

#define DMA_TRANSFER_TIMEOUT 1000000

#define REG_CTRL    0x0
#define REG_RADIUS    0x4
#define REG_IMG_W   0x8
#define REG_IMG_H   0xC
#define REG_COEFF_SCALE 0x10
#define REG_COEFF_W0 0x14

static XAxiDma AxiDma;

volatile u32 TxDone;
volatile u32 RxDone;

int main(void)
{
    int Status;

    u8 *DataBuffer;
    u8 *ReferentBuffer;
    u16 *ResultBuffer;

    ProcessingParams Params;

    u32 StartTime, StopTime, SwTicks, HwTicks;
    u32 SwTime, HwTime;
   

   // Inicijalizacija AXI Timer-a
    Status = XTmrCtr_Initialize(&TimerInstance, XPAR_AXI_TIMER_0_BASEADDR);
    if (Status != XST_SUCCESS) return XST_FAILURE;

    // Postavljanje opcija 
    XTmrCtr_SetOptions(&TimerInstance, 0, XTC_AUTO_RELOAD_OPTION);
   

    xil_printf("\r\n--- Entering main() --- \r\n");
    
    xil_printf("\r\n--- First processing --- \r\n");
    
    //Image: lena_128.bin
    //Filter: Box 3x3
    //Mode: 0
    
    // Define processing parameters
    Params.ImgH = 128;Params.ImgW = 128;
    Params.FilterControl = 0x0000;
    Params.FilterRadius = 1;
    s16 Coeffs[] = {
        3641, 3641, 3641,
        3641, 3641, 3641,
        3641, 3641, 3641
    };
    Params.FilterCoeffs = Coeffs;
    Params.FilterCoeffsScale = 4096;
   
    Params.Border = FALSE; // Bez bonusa
   
   
    // Racunanje ulaznih i izlaznih dimenzija
    u32 ImgSizeIn = Params.ImgH * Params.ImgW;
    
    u32 OutW = Params.ImgW - 2 * Params.FilterRadius;
    u32 OutH = Params.ImgH - 2 * Params.FilterRadius;
    u32 ImgSizeOut = OutW * OutH;
    
    // Input and output buffer allocation  
    DataBuffer = (u8*) malloc(ImgSizeIn);
    if (DataBuffer == NULL) {
        xil_printf("ERROR: Cannot allocate Data buffer\r\n");
        return XST_FAILURE;
    }
    xil_printf("\r\n Data buffer address: %x \r\n", DataBuffer);
    
    // Alokacija HW izlaza (16-bitni podaci)
    ResultBuffer = (u16*) malloc(ImgSizeOut * sizeof(u16));
    if (ResultBuffer == NULL) {
        xil_printf("ERROR: Cannot allocate Result buffer\r\n");
        return XST_FAILURE;
    }
    xil_printf("\r\n Result buffer address: %x \r\n", ResultBuffer);

    // Alokacija SW izlaza (8-bitni podaci)
    ReferentBuffer = (u8*) malloc(ImgSizeOut * sizeof(u8));
    if (ReferentBuffer == NULL) {
        xil_printf("ERROR: Cannot allocate Referent buffer\r\n");
        return XST_FAILURE;
    }
    xil_printf("\r\n Referent buffer address: %x \r\n\n", ReferentBuffer);

    // Use mwr function in debug console to write image from bin file to Data buffer
    //    connect
    //    target
    //    target 2 //select target        
    //    mwr -size b -bin -file "C:/Users/grija/PycharmProjects/pythonProject2/lena_128.bin" 0x110F08 16384
    //                            full_path_to_file        data_buff_addr   transfer_size_bytes
   
    xil_printf("INFO: Current parameter setting ROI = (%d, %d)\r\n",
                                    Params.ImgH, Params.ImgW);
   
   
   
    xil_printf("\r\nStart processing \r\n");
   
    // Software processing - Generate referent data
    xil_printf("  Software processing started...\r\n");

    XTmrCtr_Reset(&TimerInstance, 0);
    XTmrCtr_Start(&TimerInstance, 0);
    StartTime = XTmrCtr_GetValue(&TimerInstance, 0); // Opciono, obično je 0 nakon reseta

    ImageFIlterSW(DataBuffer, ReferentBuffer, Params);

    XTmrCtr_Stop(&TimerInstance, 0);
    StopTime = XTmrCtr_GetValue(&TimerInstance, 0);
    
    SwTicks = StopTime - StartTime;
    // Konverzija u sekunde (XPAR_TMRCTR_0_CLOCK_FREQ_HZ je tipično 100MHz)
    SwTime = SwTicks / 50;

    xil_printf("  SW Ticks: %u | Time: %u us\r\n", SwTicks, SwTime);
   
    // Hardware processing
    xil_printf("  Hardware processing started...\r\n");

    XTmrCtr_Reset(&TimerInstance, 0);
    XTmrCtr_Start(&TimerInstance, 0);

    // Merimo i konfiguraciju i sam prenos
    Status = ImageFIlterHW(DataBuffer, ResultBuffer, Params);

    XTmrCtr_Stop(&TimerInstance, 0);
    HwTicks = XTmrCtr_GetValue(&TimerInstance, 0);
    
    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: HW failed\r\n");
    } else {
        HwTime = HwTicks / 50;
        xil_printf("  HW Ticks: %u | Time: %u us\r\n", HwTicks, HwTime);
        
        // Izračunaj ubrzanje 
        xil_printf("  SPEEDUP: %u x\r\n", SwTime / HwTime);
    }

    //Check data
    Status = CheckData(ResultBuffer, ReferentBuffer, Params);
    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: Data check failed\r\n");
        return XST_FAILURE;
    }

    xil_printf("Data check OK\r\n\n");
   
    xil_printf("\r\nSuccessfully ran image accelerator test\r\n");

    // Use mrd function in debug console to read image from Result buffer to bin file
    //   HW0: mrd -size b -bin -file "C:/Users/grija/PycharmProjects/pythonProject2/lena128filtHW0.bin" 0x114F10             31752
    //   HW1: mrd -size b -bin -file "C:/Users/grija/PycharmProjects/pythonProject2/lena128filtHW1.bin" 0x114F10             31752
    //   SW: mrd -size b -bin -file "C:/Users/grija/PycharmProjects/pythonProject2/lena128filtSW.bin" 0x11CB20             15876
    //                               full_path_to_file                 result_buff_addr   transfer_size_bytes
   

    free(DataBuffer);
    free(ResultBuffer);
    free(ReferentBuffer);

    xil_printf("\r\n--- Second processing --- \r\n");
    
    //Image: lena_512.bin
    //Filter: Log filter 7x7
    //Mode: 1
    
    // Define processing parameters
    Params.ImgH = 512;Params.ImgW = 512;
    Params.FilterControl = 0x0001;
    Params.FilterRadius = 3;
    Params.FilterCoeffsScale = 4096;
    s16 CoeffsLoG7x7[] = {
          10,    86,   281,   406,   281,    86,    10,
          86,   573,  1284,  1412,  1284,   573,    86,
         281,  1284,     0, -3163,     0,  1284,   281,
         406,  1412, -3163,-10430, -3163,  1412,   406,
         281,  1284,     0, -3163,     0,  1284,   281,
          86,   573,  1284,  1412,  1284,   573,    86,
          10,    86,   281,   406,   281,    86,    10
    };
    Params.FilterCoeffs = CoeffsLoG7x7;
   
    Params.Border = FALSE; // Bez bonusa
   
   
    // Racunanje ulaznih i izlaznih dimenzija
    ImgSizeIn = Params.ImgH * Params.ImgW;
    
    OutW = Params.ImgW - 2 * Params.FilterRadius;
    OutH = Params.ImgH - 2 * Params.FilterRadius;
    ImgSizeOut = OutW * OutH;
    
    // Input and output buffer allocation  
    DataBuffer = (u8*) malloc(ImgSizeIn);
    if (DataBuffer == NULL) {
        xil_printf("ERROR: Cannot allocate Data buffer\r\n");
        return XST_FAILURE;
    }
    xil_printf("\r\n Data buffer address: %x \r\n", DataBuffer);
    
    // Alokacija HW izlaza (16-bitni podaci)
    ResultBuffer = (u16*) malloc(ImgSizeOut * sizeof(u16));
    if (ResultBuffer == NULL) {
        xil_printf("ERROR: Cannot allocate Result buffer\r\n");
        return XST_FAILURE;
    }
    xil_printf("\r\n Result buffer address: %x \r\n", ResultBuffer);

    // Alokacija SW izlaza (8-bitni podaci)
    ReferentBuffer = (u8*) malloc(ImgSizeOut * sizeof(u8));
    if (ReferentBuffer == NULL) {
        xil_printf("ERROR: Cannot allocate Referent buffer\r\n");
        return XST_FAILURE;
    }
    xil_printf("\r\n Referent buffer address: %x \r\n\n", ReferentBuffer);

    // Use mwr function in debug console to write image from bin file to Data buffer
    //    connect
    //    target
    //    target 2 //select target        
    //    mwr -size b -bin -file "C:/Users/grija/PycharmProjects/pythonProject2/lena_512.bin" 0x110F08 262144
    //                            full_path_to_file        data_buff_addr   transfer_size_bytes
   
    xil_printf("INFO: Current parameter setting ROI = (%d, %d)\r\n",
                                    Params.ImgH, Params.ImgW);
   
   
   
    xil_printf("\r\nStart processing \r\n");
   
    // Software processing - Generate referent data
    xil_printf("  Software processing started...\r\n");

    XTmrCtr_Reset(&TimerInstance, 0);
    XTmrCtr_Start(&TimerInstance, 0);
    StartTime = XTmrCtr_GetValue(&TimerInstance, 0); // Opciono, obično je 0 nakon reseta

    ImageFIlterSW(DataBuffer, ReferentBuffer, Params);

    XTmrCtr_Stop(&TimerInstance, 0);
    StopTime = XTmrCtr_GetValue(&TimerInstance, 0);
    
    SwTicks = StopTime - StartTime;
    // Konverzija u sekunde (XPAR_TMRCTR_0_CLOCK_FREQ_HZ je tipično 100MHz)
    SwTime = SwTicks / 50;

    xil_printf("  SW Ticks: %u | Time: %u us\r\n", SwTicks, SwTime);
   
    // Hardware processing
    xil_printf("  Hardware processing started...\r\n");

    XTmrCtr_Reset(&TimerInstance, 0);
    XTmrCtr_Start(&TimerInstance, 0);

    // Merimo i konfiguraciju i sam prenos
    Status = ImageFIlterHW(DataBuffer, ResultBuffer, Params);

    XTmrCtr_Stop(&TimerInstance, 0);
    HwTicks = XTmrCtr_GetValue(&TimerInstance, 0);
    
    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: HW failed\r\n");
    } else {
        HwTime = HwTicks / 50;
        xil_printf("  HW Ticks: %u | Time: %u us\r\n", HwTicks, HwTime);
        
        // Izračunaj ubrzanje 
        xil_printf("  SPEEDUP: %u x\r\n", SwTime / HwTime);
    }

    //Check data
    Status = CheckData(ResultBuffer, ReferentBuffer, Params);
    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: Data check failed\r\n");
        return XST_FAILURE;
    }

    xil_printf("Data check OK\r\n\n");
   
    xil_printf("\r\nSuccessfully ran image accelerator test\r\n");

    // Use mrd function in debug console to read image from Result buffer to bin file
    //   HW0: mrd -size b -bin -file "C:/Users/grija/PycharmProjects/pythonProject2/lena512LoGfiltHW0.bin" 0x114F10             512072
    //   HW1: mrd -size b -bin -file "C:/Users/grija/PycharmProjects/pythonProject2/lena512LoGfiltHW1.bin" 0x114F10             512072
    //   SW: mrd -size b -bin -file "C:/Users/grija/PycharmProjects/pythonProject2/lena512LoGfiltSW.bin" 0x11CB20             256036
    //                               full_path_to_file                 result_buff_addr   transfer_size_bytes
   

    free(DataBuffer);
    free(ResultBuffer);
    free(ReferentBuffer);
    
    xil_printf("\r\n--- Third processing --- \r\n");
    
    //Image: lena_128.bin
    //Filter: Gauss 5x5
    //Mode: 1
    
    // Define processing parameters
    Params.ImgH = 128;Params.ImgW = 128;
    Params.FilterControl = 0x0001;
    Params.FilterRadius = 2;
    Params.FilterCoeffsScale = 4096;
    s16 CoeffsGauss5x5[] = {
          98,   436,   718,   436,   98,
         436,  1953,  3221,  1953,  436,
         718,  3221,  5312,  3221,  718,
         436,  1953,  3221,  1953,  436,
          98,   436,   718,   436,   98
    };
    Params.FilterCoeffs = CoeffsGauss5x5;
   
    Params.Border = FALSE; // Bez bonusa
   
   
    // Racunanje ulaznih i izlaznih dimenzija
    ImgSizeIn = Params.ImgH * Params.ImgW;
    
    OutW = Params.ImgW - 2 * Params.FilterRadius;
    OutH = Params.ImgH - 2 * Params.FilterRadius;
    ImgSizeOut = OutW * OutH;
    
    // Input and output buffer allocation  
    DataBuffer = (u8*) malloc(ImgSizeIn);
    if (DataBuffer == NULL) {
        xil_printf("ERROR: Cannot allocate Data buffer\r\n");
        return XST_FAILURE;
    }
    xil_printf("\r\n Data buffer address: %x \r\n", DataBuffer);
    
    // Alokacija HW izlaza (16-bitni podaci)
    ResultBuffer = (u16*) malloc(ImgSizeOut * sizeof(u16));
    if (ResultBuffer == NULL) {
        xil_printf("ERROR: Cannot allocate Result buffer\r\n");
        return XST_FAILURE;
    }
    xil_printf("\r\n Result buffer address: %x \r\n", ResultBuffer);

    // Alokacija SW izlaza (8-bitni podaci)
    ReferentBuffer = (u8*) malloc(ImgSizeOut * sizeof(u8));
    if (ReferentBuffer == NULL) {
        xil_printf("ERROR: Cannot allocate Referent buffer\r\n");
        return XST_FAILURE;
    }
    xil_printf("\r\n Referent buffer address: %x \r\n\n", ReferentBuffer);

    // Use mwr function in debug console to write image from bin file to Data buffer
    //    connect
    //    target
    //    target 2 //select target        
    //    mwr -size b -bin -file "C:/Users/grija/PycharmProjects/pythonProject2/lena_512.bin" 0x110F08 262144
    //                            full_path_to_file        data_buff_addr   transfer_size_bytes
   
    xil_printf("INFO: Current parameter setting ROI = (%d, %d)\r\n",
                                    Params.ImgH, Params.ImgW);
   
   
   
    xil_printf("\r\nStart processing \r\n");
   
    // Software processing - Generate referent data
    xil_printf("  Software processing started...\r\n");

    XTmrCtr_Reset(&TimerInstance, 0);
    XTmrCtr_Start(&TimerInstance, 0);
    StartTime = XTmrCtr_GetValue(&TimerInstance, 0); // Opciono, obično je 0 nakon reseta

    ImageFIlterSW(DataBuffer, ReferentBuffer, Params);

    XTmrCtr_Stop(&TimerInstance, 0);
    StopTime = XTmrCtr_GetValue(&TimerInstance, 0);
    
    SwTicks = StopTime - StartTime;
    // Konverzija u sekunde (XPAR_TMRCTR_0_CLOCK_FREQ_HZ je tipično 100MHz)
    SwTime = SwTicks / 50;

    xil_printf("  SW Ticks: %u | Time: %u us\r\n", SwTicks, SwTime);
   
    // Hardware processing
    xil_printf("  Hardware processing started...\r\n");

    XTmrCtr_Reset(&TimerInstance, 0);
    XTmrCtr_Start(&TimerInstance, 0);

    // Merimo i konfiguraciju i sam prenos
    Status = ImageFIlterHW(DataBuffer, ResultBuffer, Params);

    XTmrCtr_Stop(&TimerInstance, 0);
    HwTicks = XTmrCtr_GetValue(&TimerInstance, 0);
    
    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: HW failed\r\n");
    } else {
        HwTime = HwTicks / 50;
        xil_printf("  HW Ticks: %u | Time: %u us\r\n", HwTicks, HwTime);
        
        // Izračunaj ubrzanje 
        xil_printf("  SPEEDUP: %u x\r\n", SwTime / HwTime);
    }

    //Check data
    Status = CheckData(ResultBuffer, ReferentBuffer, Params);
    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: Data check failed\r\n");
        return XST_FAILURE;
    }

    xil_printf("Data check OK\r\n\n");
   
    xil_printf("\r\nSuccessfully ran image accelerator test\r\n");

    // Use mrd function in debug console to read image from Result buffer to bin file
    //   HW0: mrd -size b -bin -file "C:/Users/grija/PycharmProjects/pythonProject2/lena512GaussHW0.bin" 0x114F10             516128
    //   HW1: mrd -size b -bin -file "C:/Users/grija/PycharmProjects/pythonProject2/lena512GaussHW1.bin" 0x114F10             516128
    //   SW: mrd -size b -bin -file "C:/Users/grija/PycharmProjects/pythonProject2/lena512GaussSW.bin" 0x11CB20             258064
    //                               full_path_to_file                 result_buff_addr   transfer_size_bytes
   

    free(DataBuffer);
    free(ResultBuffer);
    free(ReferentBuffer);
    
            xil_printf("\r\n--- Fourth processing --- \r\n");
    
    //Image: lena_512.bin
    //Filter: Sharp Box 9x9
    //Mode: 0
    
    // Define processing parameters
    Params.ImgH = 512;Params.ImgW = 512;
    Params.FilterControl = 0x0000;
    Params.FilterRadius = 4;
    Params.FilterCoeffsScale = 8192; // Faktor skaliranja 2
    
    // Matrica 9x9 (81 element)
    // Svi elementi su -202, osim centralnog koji je 32566
    s16 CoeffsSharpBox9x9[81];
    for(int i = 0; i < 81; i++) {
        CoeffsSharpBox9x9[i] = -202;
    }
    CoeffsSharpBox9x9[40] = 32566; // Centralni element (indeks 40)
    
    Params.FilterCoeffs = CoeffsSharpBox9x9;
   
    Params.Border = FALSE; // Bez bonusa
   
   
    // Racunanje ulaznih i izlaznih dimenzija
    ImgSizeIn = Params.ImgH * Params.ImgW;
    
    OutW = Params.ImgW - 2 * Params.FilterRadius;
    OutH = Params.ImgH - 2 * Params.FilterRadius;
    ImgSizeOut = OutW * OutH;
    
    // Input and output buffer allocation  
    DataBuffer = (u8*) malloc(ImgSizeIn);
    if (DataBuffer == NULL) {
        xil_printf("ERROR: Cannot allocate Data buffer\r\n");
        return XST_FAILURE;
    }
    xil_printf("\r\n Data buffer address: %x \r\n", DataBuffer);
    
    // Alokacija HW izlaza (16-bitni podaci)
    ResultBuffer = (u16*) malloc(ImgSizeOut * sizeof(u16));
    if (ResultBuffer == NULL) {
        xil_printf("ERROR: Cannot allocate Result buffer\r\n");
        return XST_FAILURE;
    }
    xil_printf("\r\n Result buffer address: %x \r\n", ResultBuffer);

    // Alokacija SW izlaza (8-bitni podaci)
    ReferentBuffer = (u8*) malloc(ImgSizeOut * sizeof(u8));
    if (ReferentBuffer == NULL) {
        xil_printf("ERROR: Cannot allocate Referent buffer\r\n");
        return XST_FAILURE;
    }
    xil_printf("\r\n Referent buffer address: %x \r\n\n", ReferentBuffer);

    // Use mwr function in debug console to write image from bin file to Data buffer
    //    connect
    //    target
    //    target 2 //select target        
    //    mwr -size b -bin -file "C:/Users/grija/PycharmProjects/pythonProject2/lena_512.bin" 0x110F08 262144
    //                            full_path_to_file        data_buff_addr   transfer_size_bytes
   
    xil_printf("INFO: Current parameter setting ROI = (%d, %d)\r\n",
                                    Params.ImgH, Params.ImgW);
   
   
   
    xil_printf("\r\nStart processing \r\n");
   
    // Software processing - Generate referent data
    xil_printf("  Software processing started...\r\n");

    XTmrCtr_Reset(&TimerInstance, 0);
    XTmrCtr_Start(&TimerInstance, 0);
    StartTime = XTmrCtr_GetValue(&TimerInstance, 0); // Opciono, obično je 0 nakon reseta

    ImageFIlterSW(DataBuffer, ReferentBuffer, Params);

    XTmrCtr_Stop(&TimerInstance, 0);
    StopTime = XTmrCtr_GetValue(&TimerInstance, 0);
    
    SwTicks = StopTime - StartTime;
    // Konverzija u sekunde (XPAR_TMRCTR_0_CLOCK_FREQ_HZ je tipično 100MHz)
    SwTime = SwTicks / 50;

    xil_printf("  SW Ticks: %u | Time: %u us\r\n", SwTicks, SwTime);
   
    // Hardware processing
    xil_printf("  Hardware processing started...\r\n");

    XTmrCtr_Reset(&TimerInstance, 0);
    XTmrCtr_Start(&TimerInstance, 0);

    // Merimo i konfiguraciju i sam prenos
    Status = ImageFIlterHW(DataBuffer, ResultBuffer, Params);

    XTmrCtr_Stop(&TimerInstance, 0);
    HwTicks = XTmrCtr_GetValue(&TimerInstance, 0);
    
    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: HW failed\r\n");
    } else {
        HwTime = HwTicks / 50;
        xil_printf("  HW Ticks: %u | Time: %u us\r\n", HwTicks, HwTime);
        
        // Izračunaj ubrzanje 
        xil_printf("  SPEEDUP: %u x\r\n", SwTime / HwTime);
    }

    //Check data
    Status = CheckData(ResultBuffer, ReferentBuffer, Params);
    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: Data check failed\r\n");
        return XST_FAILURE;
    }

    xil_printf("Data check OK\r\n\n");
   
    xil_printf("\r\nSuccessfully ran image accelerator test\r\n");

    // Use mrd function in debug console to read image from Result buffer to bin file
    //   HW0: mrd -size b -bin -file "C:/Users/grija/PycharmProjects/pythonProject2/lena512SharpBoxHW0.bin" 0x114F10             508032
    //   HW1: mrd -size b -bin -file "C:/Users/grija/PycharmProjects/pythonProject2/lena512SharpBoxHW1.bin" 0x114F10             508032
    //   SW: mrd -size b -bin -file "C:/Users/grija/PycharmProjects/pythonProject2/lena512SharpBoxSW.bin" 0x11CB20             254016
    //                               full_path_to_file                 result_buff_addr   transfer_size_bytes
   

    free(DataBuffer);
    free(ResultBuffer);
    free(ReferentBuffer);
    
    xil_printf("\r\n--- Fifth processing --- \r\n");
    
    //Image: lena_128.bin
    //Filter: SharpGauss
    //Mode: 0
    
    // Define processing parameters
    Params.ImgH = 128;Params.ImgW = 128;
    Params.FilterControl = 0x0000;
    Params.FilterRadius = 2;
    Params.FilterCoeffsScale = 8192; // Faktor skaliranja 2
    s16 CoeffsSharpGauss5x5[] = {
         -49,  -218,  -359,  -218,   -49,
        -218,  -977, -1611,  -977,  -218,
        -359, -1611, 30112, -1611,  -359,
        -218,  -977, -1611,  -977,  -218,
         -49,  -218,  -359,  -218,   -49
    };
    Params.FilterCoeffs = CoeffsSharpGauss5x5;
   
    Params.Border = FALSE; // Bez bonusa
   
   
    // Racunanje ulaznih i izlaznih dimenzija
    ImgSizeIn = Params.ImgH * Params.ImgW;
    
    OutW = Params.ImgW - 2 * Params.FilterRadius;
    OutH = Params.ImgH - 2 * Params.FilterRadius;
    ImgSizeOut = OutW * OutH;
    
    // Input and output buffer allocation  
    DataBuffer = (u8*) malloc(ImgSizeIn);
    if (DataBuffer == NULL) {
        xil_printf("ERROR: Cannot allocate Data buffer\r\n");
        return XST_FAILURE;
    }
    xil_printf("\r\n Data buffer address: %x \r\n", DataBuffer);
    
    // Alokacija HW izlaza (16-bitni podaci)
    ResultBuffer = (u16*) malloc(ImgSizeOut * sizeof(u16));
    if (ResultBuffer == NULL) {
        xil_printf("ERROR: Cannot allocate Result buffer\r\n");
        return XST_FAILURE;
    }
    xil_printf("\r\n Result buffer address: %x \r\n", ResultBuffer);

    // Alokacija SW izlaza (8-bitni podaci)
    ReferentBuffer = (u8*) malloc(ImgSizeOut * sizeof(u8));
    if (ReferentBuffer == NULL) {
        xil_printf("ERROR: Cannot allocate Referent buffer\r\n");
        return XST_FAILURE;
    }
    xil_printf("\r\n Referent buffer address: %x \r\n\n", ReferentBuffer);

    // Use mwr function in debug console to write image from bin file to Data buffer
    //    connect
    //    target
    //    target 2 //select target        
    //    mwr -size b -bin -file "C:/Users/grija/PycharmProjects/pythonProject2/lena_128.bin" 0x110F08 16384
    //                            full_path_to_file        data_buff_addr   transfer_size_bytes
   
    xil_printf("INFO: Current parameter setting ROI = (%d, %d)\r\n",
                                    Params.ImgH, Params.ImgW);
   
   
   
    xil_printf("\r\nStart processing \r\n");
   
    // Software processing - Generate referent data
    xil_printf("  Software processing started...\r\n");

    XTmrCtr_Reset(&TimerInstance, 0);
    XTmrCtr_Start(&TimerInstance, 0);
    StartTime = XTmrCtr_GetValue(&TimerInstance, 0); // Opciono, obično je 0 nakon reseta

    ImageFIlterSW(DataBuffer, ReferentBuffer, Params);

    XTmrCtr_Stop(&TimerInstance, 0);
    StopTime = XTmrCtr_GetValue(&TimerInstance, 0);
    
    SwTicks = StopTime - StartTime;
    // Konverzija u sekunde (XPAR_TMRCTR_0_CLOCK_FREQ_HZ je tipično 100MHz)
    SwTime = SwTicks / 50;

    xil_printf("  SW Ticks: %u | Time: %u us\r\n", SwTicks, SwTime);
   
    // Hardware processing
    xil_printf("  Hardware processing started...\r\n");

    XTmrCtr_Reset(&TimerInstance, 0);
    XTmrCtr_Start(&TimerInstance, 0);

    // Merimo i konfiguraciju i sam prenos
    Status = ImageFIlterHW(DataBuffer, ResultBuffer, Params);

    XTmrCtr_Stop(&TimerInstance, 0);
    HwTicks = XTmrCtr_GetValue(&TimerInstance, 0);
    
    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: HW failed\r\n");
    } else {
        HwTime = HwTicks / 50;
        xil_printf("  HW Ticks: %u | Time: %u us\r\n", HwTicks, HwTime);
        
        // Izračunaj ubrzanje 
        xil_printf("  SPEEDUP: %u x\r\n", SwTime / HwTime);
    }

    //Check data
    Status = CheckData(ResultBuffer, ReferentBuffer, Params);
    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: Data check failed\r\n");
        return XST_FAILURE;
    }

    xil_printf("Data check OK\r\n\n");
   
    xil_printf("\r\nSuccessfully ran image accelerator test\r\n");

    // Use mrd function in debug console to read image from Result buffer to bin file
    //   HW0: mrd -size b -bin -file "C:/Users/grija/PycharmProjects/pythonProject2/lena128SharpGaussHW0.bin" 0x114F10             30752
    //   HW1: mrd -size b -bin -file "C:/Users/grija/PycharmProjects/pythonProject2/lena128SharpGaussHW1.bin" 0x114F10             30752
    //   SW: mrd -size b -bin -file "C:/Users/grija/PycharmProjects/pythonProject2/lena128SharpGaussSW.bin" 0x11CB20             15376
    //                               full_path_to_file                 result_buff_addr   transfer_size_bytes
   

    free(DataBuffer);
    free(ResultBuffer);
    free(ReferentBuffer);
    
    xil_printf("\r\n--- Exiting main() --- \r\n");

    return XST_SUCCESS;
}

static void ImageFIlterSW(u8* DataBuffer, u8* ResultBuffer, ProcessingParams Params)
{
    int i, j, ky, kx;
    int height = Params.ImgH;
    int width = Params.ImgW;
    int radius = Params.FilterRadius;
    int kernelDim = 2 * radius + 1;
    
    // Dimenzije nove, smanjene izlazne slike
    int out_width = width - 2 * radius;
    //int out_height = height - 2 * radius;
    
    // Konverzija fixed-point skale u float (12 razlomljenih bita)
    float scale = (float)Params.FilterCoeffsScale / 4096.0f;

    // Petlje idu samo kroz validne piksele (preskacemo ivice)
    for (i = radius; i < height - radius; i++) {
        for (j = radius; j < width - radius; j++) {
            
            float sum = 0.0f;
            
            // Konvolucija
            for (ky = -radius; ky <= radius; ky++) {
                for (kx = -radius; kx <= radius; kx++) {
                    
                    int y_in = i + ky;
                    int x_in = j + kx;
                    
                    u8 pixelVal = DataBuffer[y_in * width + x_in];
                    
                    int k_idx = (ky + radius) * kernelDim + (kx + radius);
                    
                    float float_coeff = (float)Params.FilterCoeffs[k_idx] / 32768.0f;
                    
                    sum += (float)pixelVal * float_coeff;
                }
            }

            // Skaliranje i Saturacija
            sum = sum * scale;
            if (sum < 0.0f) sum = 0.0f;
            if (sum > 255.0f) sum = 255.0f;

            // Racunanje indeksa za tesno pakovanje u izlazni bafer
            int out_i = i - radius;
            int out_j = j - radius;
            ResultBuffer[out_i * out_width + out_j] = (u8)sum;
        }
    }
}

static int ImageFIlterHW(u8* DataBuffer, u16* ResultBuffer, ProcessingParams Params)
{
    int Status;
    int ImageSizeIn = Params.ImgH * Params.ImgW;
    
    int OutW = Params.ImgW - 2 * Params.FilterRadius;
    int OutH = Params.ImgH - 2 * Params.FilterRadius;
    int ImageSizeOut = OutW * OutH * sizeof(u16);

    TxDone = 0;
    RxDone = 0;

    XAxiDma_Config *AxiDmaConfigPtr;
    AxiDmaConfigPtr = XAxiDma_LookupConfig(XPAR_XAXIDMA_0_BASEADDR);
    if (!AxiDmaConfigPtr) {
        xil_printf("  HW CONFIG ERROR: No config found for %d\r\n", XPAR_XAXIDMA_0_BASEADDR);

        return XST_FAILURE;
    }

    Status = DmaConfigure(AxiDmaConfigPtr, &AxiDma);
    if (Status != XST_SUCCESS)
    {
        xil_printf("  HW CONFIG ERROR: DMA configuration failed\r\n");
        return XST_FAILURE;        
    }
   
    //DODATO
    Status = AccConfigure(XPAR_ACC_IMAGE_FILTER_AXI4LITE_WRAPPER_0_BASEADDR, Params);

    Status = DmaStartTransfers(&AxiDma, DataBuffer, ImageSizeIn, (u8*)ResultBuffer, ImageSizeOut);
    if (Status != XST_SUCCESS)
    {
        xil_printf("  HW CONFIG ERROR: Starting DMA transfers failed\r\n");
        return XST_FAILURE;        
    }

    Status = DmaWaitTransfers(&TxDone, &RxDone, DMA_TRANSFER_TIMEOUT);
    if (Status != XST_SUCCESS)
    {
        xil_printf("  HW PROC ERROR: Completing DMA transfers failed\r\n");
        return XST_FAILURE;        
    }

    /* Disable TX and RX interrupts */
    XDisconnectInterruptCntrl(AxiDmaConfigPtr->IntrId[0], AxiDmaConfigPtr->IntrParent);
    XDisconnectInterruptCntrl(AxiDmaConfigPtr->IntrId[1], AxiDmaConfigPtr->IntrParent);

    /* DODATO: Resetuj DMA hardver pre izlaska iz funkcije */
    XAxiDma_Reset(&AxiDma);
    
    /* Opciono: Sačekaj kratko da se reset završi */
    int ResetTimeout = 10000;
    while (ResetTimeout > 0) {
        if (XAxiDma_ResetIsDone(&AxiDma)) {
            break;
        }
        ResetTimeout--;
    }

    return XST_SUCCESS;
}

static int CheckData(u16* ResultBuffer, u8* ReferentBuffer, ProcessingParams Params)
{
    int RowIndex = 0;
    int ColIndex = 0;

    // Dimenzije bez ivica
    int OutW = Params.ImgW - 2 * Params.FilterRadius;
    int OutH = Params.ImgH - 2 * Params.FilterRadius;

    // Invalidate cache da bismo ucitavali sveze podatke iz RAM-a koje je upisao DMA
    Xil_DCacheInvalidateRange((UINTPTR)ResultBuffer, OutW * OutH * sizeof(u16));

    // Čitanje MODE bita iz kontrolnog registra (bit 0)
    int mode = Params.FilterControl & 0x01;
    int error_count = 0;

    for (RowIndex = 0; RowIndex < OutH; RowIndex++)
    {
        for (ColIndex = 0; ColIndex < OutW; ColIndex++)
        {
            int linear_idx = RowIndex * OutW + ColIndex;
            u8 sw_pixel = ReferentBuffer[linear_idx];
            u8 hw_pixel = 0;

            if (mode == 0) {
                // Tvoj HW dizajn: 16-bitna reč se čita, gornjih 8 bita su nule
                // Donjih 8 bita se uzima kao stvarna vrednost piksela
                hw_pixel = (u8)(ResultBuffer[linear_idx] & 0xFF);
            } else {
                // Mode 1: 16-bitni označeni podatak (9 bita ceo deo, 7 bita razlomljeni)
                s16 raw_hw_val = (s16)ResultBuffer[linear_idx];
                
                // Šiftovanje za 7 mesta udesno da bi se dobio celobrojni deo
                int integer_val = raw_hw_val >> 7;
                
                // Saturacija na opseg uint8 (isto sto radi i SW)
                if (integer_val < 0) integer_val = 0;
                if (integer_val > 255) integer_val = 255;
                
                hw_pixel = (u8)integer_val;
            }

            // Upoređivanje uz toleranciju +/- 1 zbog float vs fixed-point matematike
            if (abs((int)hw_pixel - (int)sw_pixel) > 1) {
                if (error_count < 10) { 
                    xil_printf("DATA CHECK ERROR: HW Row: %d Col: %d | HW Val: %d, SW Exp: %d\r\n",
                                RowIndex, ColIndex, hw_pixel, sw_pixel);
                }
                error_count++;
            }
        }
    }
    
    if (error_count > 0) {
        xil_printf("TOTAL ERRORS: %d\r\n", error_count);
        return XST_FAILURE;
    }

    return XST_SUCCESS;
}

static int DmaConfigure(XAxiDma_Config* AxiDmaConfigPtr, XAxiDma* AxiDmaPtr)
{
    int Status;
   
    /* DMA configuration */

    Status = XAxiDma_CfgInitialize(AxiDmaPtr, AxiDmaConfigPtr);
    if (Status != XST_SUCCESS) {
        xil_printf("    ERROR: DMA initialization failed %d\r\n", Status);
        return XST_FAILURE;
    }

    if (XAxiDma_HasSg(AxiDmaPtr)) {
        xil_printf("    ERROR: DMA configure in SG mode \r\n");
        return XST_FAILURE;
    }

    /* Configure DMA interrupts */
    Status = XSetupInterruptSystem(AxiDmaPtr, &TxIntrHandler,
                                  AxiDmaConfigPtr->IntrId[0], AxiDmaConfigPtr->IntrParent,
                                  XINTERRUPT_DEFAULT_PRIORITY);
    if (Status != XST_SUCCESS) {
        xil_printf("    ERROR: Cannot configure DMA TX interrupt\r\n");
        return XST_FAILURE;
    }

    Status = XSetupInterruptSystem(AxiDmaPtr, &RxIntrHandler,
                                   AxiDmaConfigPtr->IntrId[1], AxiDmaConfigPtr->IntrParent,
                                   XINTERRUPT_DEFAULT_PRIORITY);
    if (Status != XST_SUCCESS) {
        xil_printf("    ERROR: Cannot configure DMA RX interrupt\r\n");
        return XST_FAILURE;
    }

    XAxiDma_IntrEnable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);
    XAxiDma_IntrEnable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);

    return XST_SUCCESS;
}

static int DmaStartTransfers(XAxiDma* AxiDmaPtr, u8* TxBuffer, u32 TxSize, u8* RxBuffer, u32 RxSize)
{
    int Status;

    /* Flush TX buffer before DMA transfer to make sure that DDR and Cache are in sync */
    Xil_DCacheFlushRange((UINTPTR)TxBuffer, TxSize);
    Xil_DCacheFlushRange((UINTPTR)RxBuffer, RxSize);

    /* Start DMA tranfers */
    Status = XAxiDma_SimpleTransfer(AxiDmaPtr, (UINTPTR) RxBuffer,
                                    RxSize, XAXIDMA_DEVICE_TO_DMA);
    if (Status != XST_SUCCESS) {
        xil_printf("    ERROR: Starting RX DMA failed %d\r\n", Status);
        return XST_FAILURE;
    }

    Status = XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR) TxBuffer,
                                    TxSize, XAXIDMA_DMA_TO_DEVICE);
    if (Status != XST_SUCCESS) {
        xil_printf("    ERROR: Starting TX DMA failed %d\r\n", Status);
        return XST_FAILURE;
    }

    return XST_SUCCESS;
}

static int DmaWaitTransfers(volatile u32* TxFlag, volatile u32* RxFlag, u32 Timeout)
{
    int Status;
    /* Wait for TX done or timeout */
    Status = Xil_WaitForEventSet(Timeout, 1, TxFlag);
    if (Status != XST_SUCCESS) {
        xil_printf("    ERROR: Transmit failed %d\r\n", Status);
        return XST_FAILURE;
    }
    xil_printf("    Transmit done\r\n");

    /* Wait for RX done or timeout */
    Status = Xil_WaitForEventSet(Timeout, 1, RxFlag);
    if (Status != XST_SUCCESS) {
        xil_printf("    ERROR: Receive failed %d\r\n", Status);
        return XST_FAILURE;
    }
    xil_printf("Receive done\r\n");

    return XST_SUCCESS;
}

static int AccConfigure(UINTPTR BaseAddress, ProcessingParams Params)
{
    u16 ReadValue;
   
    Xil_Out16(BaseAddress + REG_CTRL, Params.FilterControl);

    ReadValue = Xil_In16(BaseAddress + REG_CTRL);
    if(ReadValue != Params.FilterControl)
        return XST_FAILURE;

    Xil_Out16(BaseAddress + REG_RADIUS, Params.FilterRadius);

    ReadValue = Xil_In16(BaseAddress + REG_RADIUS);
    if(ReadValue != Params.FilterRadius)
        return XST_FAILURE;

    Xil_Out16(BaseAddress + REG_IMG_H, Params.ImgH);

    ReadValue = Xil_In16(BaseAddress + REG_IMG_H);
    if(ReadValue != Params.ImgH)
        return XST_FAILURE;

    Xil_Out16(BaseAddress + REG_IMG_W, Params.ImgW);

    ReadValue = Xil_In16(BaseAddress + REG_IMG_W);
    if(ReadValue != Params.ImgW)
        return XST_FAILURE;

    Xil_Out16(BaseAddress + REG_COEFF_SCALE, Params.FilterCoeffsScale);

    ReadValue = Xil_In16(BaseAddress + REG_COEFF_SCALE);
    if(ReadValue != Params.FilterCoeffsScale)
        return XST_FAILURE;

    for (int i = 0; i < 81; i++){
        s16 coeff;
        
        if (i < (2*Params.FilterRadius + 1)*(2*Params.FilterRadius + 1)) coeff = Params.FilterCoeffs[i];
        else coeff = 0x0000;
        
        Xil_Out16(BaseAddress + REG_COEFF_W0 + (i*4), coeff);

        ReadValue = Xil_In16(BaseAddress + REG_COEFF_W0 + (i * 4));
        if(ReadValue != (u16)coeff)
            return XST_FAILURE;
    }


    return XST_SUCCESS;
}


static void TxIntrHandler(void *Callback)
{
    u32 IrqStatus;
    XAxiDma *AxiDmaInst = (XAxiDma *)Callback;

    /* Read pending interrupts */
    IrqStatus = XAxiDma_IntrGetIrq(AxiDmaInst, XAXIDMA_DMA_TO_DEVICE);

    /* Acknowledge pending interrupts */
    XAxiDma_IntrAckIrq(AxiDmaInst, IrqStatus, XAXIDMA_DMA_TO_DEVICE);

    /* Set TX done only if transmit chain is completed */
    if ((IrqStatus & XAXIDMA_IRQ_IOC_MASK))
    {
        TxDone = 1;
    }

    return;
}

static void RxIntrHandler(void *Callback)
{
    u32 IrqStatus;
    XAxiDma *AxiDmaInst = (XAxiDma *)Callback;

    /* Read pending interrupts */
    IrqStatus = XAxiDma_IntrGetIrq(AxiDmaInst, XAXIDMA_DEVICE_TO_DMA);

    /* Acknowledge pending interrupts */
    XAxiDma_IntrAckIrq(AxiDmaInst, IrqStatus, XAXIDMA_DEVICE_TO_DMA);

    /* Set RX done only if receive chain is completed */
    if ((IrqStatus & XAXIDMA_IRQ_IOC_MASK))
    {
        RxDone = 1;
    }

    return;
}