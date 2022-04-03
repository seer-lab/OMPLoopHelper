#include <stdio.h>
#include <stdlib.h>
#include <omp.h>
#include <time.h>

int main(){

    clock_t begin = clock();

	int sum = 0;
	int a[20] = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 };
    
    //@omp-analysis=true
    for (int i = 0; i < sizeof(a)/ sizeof(int); i++) {
        sum += a[i];
    }

    clock_t end = clock();
    double time_spent = (double)(end - begin) / CLOCKS_PER_SEC;
    printf("time spent: %f\n", time_spent);
}