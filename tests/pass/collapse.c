// test: pass
// source: http://www.sqrlab.ca/exercises/csci4060u-w19/loop_ex4.c

#include <stdio.h>
#include <omp.h>

#define NUM_THREADS 12

int main(){
    int i = 0;
    int j = 0;
    double result[NUM_THREADS][NUM_THREADS];

    omp_set_num_threads(NUM_THREADS);
    //for perfectly rectuangular nested loops
    //we can parallelize them using a collapse clause
    //if you don't use collapse the below code will
    //only parallelize the outer loop
    #pragma omp parallel for collapse(2) private(i, j)
    //private clause allows us to specify local copies of variables
    //for each thread
    //@omp-analysis=true
    for (i = 0; i < NUM_THREADS; i++){
        for (j = 0; j < NUM_THREADS; j++){
            result[i][j] = i * j;
            printf("Index [%d,%d] = %f \n", i, j, result[i][j]);
        }
    }

    /* Sequential  version:

  int i =0;
  int j=0;
double result[NUM_THREADS][NUM_THREADS];

for (i=0;i< NUM_THREADS; i++) {
    for (j=0; j< NUM_THREADS; j++) {
      result[i][j] = i * j;
      printf("Index [%d,%d] = %f \n", i, j, result[i][j]);

  }
}*/
}