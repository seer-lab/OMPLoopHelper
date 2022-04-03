#include <stdio.h>
#include <omp.h>

int main()
{
    int a = 1;
    int b = 2;
    int c = 3;
    int sum = 0;
    int sum2 = 0;
    int negative_sum = 0;
    int mult = 1;
    
    //@omp-analysis=true
    for (int i = 0; i < 10; i++)
    {
        sum += i;
        sum2 += i;
        negative_sum -= i;
        mult *= i;
    }
}