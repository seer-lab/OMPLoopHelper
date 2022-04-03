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
        var2 = i + var;
        var3 = var2 + var;
        var2 = var3 + var;
        sum += var + var3;
    }

    printf("sum: %d\n", sum);
}