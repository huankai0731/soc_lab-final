#ifndef __MERGE_H__
#define __MERGE_H__

//counter_fir
#define N 11

int taps[N] = {0,-10,-9,23,56,63,56,23,-9,-10,0};
int inputbuffer[N];
int inputsignal[N] = {1,2,3,4,5,6,7,8,9,10,11};
int outputsignal[N];


//counter_mm
#define SIZE 4
	int A[SIZE*SIZE] = {0, 1, 2, 3,
			0, 1, 2, 3,
			0, 1, 2, 3,
			0, 1, 2, 3,
	};
	int B[SIZE*SIZE] = {1, 2, 3, 4,
		5, 6, 7, 8,
		9, 10, 11, 12,
		13, 14, 15, 16,
	};
	int result[SIZE*SIZE];

//counter_qs
#define QSIZE 10
int C[QSIZE] = {893, 40, 3233, 4267, 2669, 2541, 9073, 6023, 5681, 4622};


#endif

