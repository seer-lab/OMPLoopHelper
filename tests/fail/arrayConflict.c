#include <stdio.h>
#include <stdlib.h>
#include <omp.h>
#include <time.h>

int main(){
	int sum = 0;
    int var = 0;
    int var2 = 0;
    int a[10];
    
    //@omp-analysis=true
    for (int i = 0; i < 10; i++) {
        a[i] = i * 10;
        var = i + a[i-1];
        sum += var;
    }

    printf("sum: %d\n", sum);
}