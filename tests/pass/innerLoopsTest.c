#include <stdio.h>
#include <stdlib.h>
#include <omp.h>
#include <time.h>

int main(){
	int sum = 0;
    int var = 0;
    int var2 = 0;
    
    //@omp-analysis=true
    for (int i = 0; i < 10; i++) {

        //@omp-analysis=true
        for(int j = 0; j < 10; j++) {
            sum += var + 0 + var2;
        }

        //@omp-analysis=true
        for(int j = 0; j < 10; j++) {

            //@omp-analysis=true
            for(int k = 0; k < 10; k++) {
                sum += var + 1 + var2;
            }
        }
    }

    //@omp-analysis=true
    for(int i = 0; i < 10; i++) {

        //@omp-analysis=true
        for(int j = 0; j < 10; j++) {
            sum += var + 2 + var2;
        }
    }

    printf("sum: %d\n", sum);
}

// loops: 12, 15, 20, 23, 30, 33
// inner loops: 16, 22, 25, 35
// current outer detection: 23, 15, 23, 23, 33, 33