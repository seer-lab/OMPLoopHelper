//#include <stdio.h>
//#include <stdlib.h>
//#include <omp.h>
//#include <time.h>

int main(){
	int sum = 0;
    int var = 0;
    int var2 = 0;
    int a[10];
    
    //@omp-analysis=true
    for (int i = 0; i < 10; i++) {
        var = a[i] * 10;
        a[i] = i + var;
        sum += var + a[i];
    }

    printf("sum: %d\n", sum);
}
