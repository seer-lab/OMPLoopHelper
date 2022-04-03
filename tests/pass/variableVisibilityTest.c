#include <omp.h>
#include <stdio.h>


void main(){

    int i;
    int x = 0;
    int y;
    int z;

    //@omp-analysis=true
    for (i = 0; i < 10; i++){
        x += i;
        y = x + i;
        z = y + i;
        int a = x + i + x;
        int b = a + i;
        int c = b + i;
    }
}