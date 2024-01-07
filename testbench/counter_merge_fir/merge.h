#ifndef __MERGE_H__
#define __MERGE_H__

#include <stdint.h>


//counter_fir
#define N 11
#define data_length 64

int y[N];
int final_y;

#define reg_fir_control  (*(volatile uint32_t*)0x30000000)
#define reg_fir_length   (*(volatile uint32_t*)0x30000010)
#define reg_fir_input    (*(volatile uint32_t*)0x30000080)
#define reg_fir_output   (*(volatile uint32_t*)0x30000084)

#define reg_fir_coeff_0  (*(volatile uint32_t*)0x30000020)
#define reg_fir_coeff_1  (*(volatile uint32_t*)0x30000024)
#define reg_fir_coeff_2  (*(volatile uint32_t*)0x30000028)
#define reg_fir_coeff_3  (*(volatile uint32_t*)0x3000002c)
#define reg_fir_coeff_4  (*(volatile uint32_t*)0x30000030)
#define reg_fir_coeff_5  (*(volatile uint32_t*)0x30000034)
#define reg_fir_coeff_6  (*(volatile uint32_t*)0x30000038)
#define reg_fir_coeff_7  (*(volatile uint32_t*)0x3000003c)
#define reg_fir_coeff_8  (*(volatile uint32_t*)0x30000040)
#define reg_fir_coeff_9  (*(volatile uint32_t*)0x30000044)
#define reg_fir_coeff_10 (*(volatile uint32_t*)0x30000048)

	int x[data_length] = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63};

//counter_mm
#define SIZE 4
	int A[SIZE*SIZE] = {0, 1, 2, 3,
	                    1, 0, 2, 3,
		            3, 1, 0, 2,
		            3, 2, 1, 0,
	};
	int B[SIZE*SIZE] = {1, 2, 3, 4,
		            5, 6, 7, 8,
		            9, 10, 11, 12,
		            13, 14, 15, 16,
	};
	int result[SIZE*SIZE];


#define reg_mm_input    (*(volatile uint32_t*)0x30000180)
#define reg_mm_output    (*(volatile uint32_t*)0x30000184)


//counter_qs
#define QSIZE 10
int C[QSIZE] = {893, 40, 3233, 4267, 2669, 2541, 9073, 6023, 5681, 4622};
int qs[QSIZE];
#define reg_qs_input    (*(volatile uint32_t*)0x30000280)
#define reg_qs_output    (*(volatile uint32_t*)0x30000284)

#endif

