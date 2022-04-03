#include <stdio.h>
#include <stdlib.h>
#include <omp.h>

#define NUM_THREADS 16
#define PAD 8

static long num_steps = 100;
double step;

int main ()
{ 
    double pi = 0.0;
    double sum = 0.0;
    step = 1.0/(double) num_steps;
    

    //#pragma omp parallel for reduction(+: sum)
    //@omp-analysis=true
    for (int i = 0; i < num_steps; i += 1) {
        printf("thread:%d\n", omp_get_thread_num());
        double x = (i + 0.5) * step;
        sum += 4.0/(1.0+x*x);
    }

    pi = sum * step;
    printf("pi = %f\n", pi);
}