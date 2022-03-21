#include <stdio.h>
#include <omp.h>

int main()
{
    int a = 1;
    int b = 2;
    int c = 3;
    int sum = 0;

    //@omp-analysis=true
    for (int i = 0; i < 10; i++)
    {
        for (int j = 0; j < 10; j++)
        {
            sum = sum + i * j;
        }
    }
}