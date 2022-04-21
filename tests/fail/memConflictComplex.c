#include <stdio.h>
#include <stdlib.h>
#include <omp.h>
#include <time.h>

int main(){
	int sum = 0;
    int var = 0;
    int var2 = 0;
    int var3 = 0;
    
    //@omp-analysis=true
    for (int i = 0; i < 10; i++) {
        var = i * 10;
        var2 = var3 + var;
        var3 = i + var;
        sum += var + var2;
    }

    printf("sum: %d\n", sum);
}