# openmp-analysis

## Usage instructions:
 1. Have c code, with at least one for loop
 2. Before the for loop you want to test, add this comment: ```//@omp-analysis=true```
 3. Run: ```txl isParallelizable.txl [c code filepath] -comment```