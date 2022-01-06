// test: fail
// source: http://www.sqrlab.ca/exercises/csci4060u-w19/loop_ex4.c
// (changed from source)

#include <stdio.h>
#include <omp.h>

#define NUM_THREADS 12

int main(){
    int i = 0;
    int j = 0;
    double result[NUM_THREADS][NUM_THREADS];

    omp_set_num_threads(NUM_THREADS);
    //#pragma omp parallel for collapse(2) private(i, j)

    //@omp-analysis=true
    for (i = 0; i < NUM_THREADS; i++){
        //@omp-analysis=false
        
        // this operation means the collapse argument cannot be used
        result[i][j] += 1;
    }
}