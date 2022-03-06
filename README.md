# openmp-analysis

This program checks 4 steps to analyze each marked for loop for OpenMP parallelization compatibility:
 1. match for loop
 2. check that loop is pragma-compatible (structured block)
 3. check for collapse pragma compatibility
 4. check for memory conflict with recursive method

## Usage instructions:
 1. Have c code, with at least one for loop
 2. Before the for loop you want to test, add this comment: //@omp-analysis=true
 3. Run: txl isParallelizable.txl [c code filepath] -comment
    - without full program output: txl isParallelizable.txl [c code filepath] -comment -q -o /dev/null
    - with debugging messages: txl isParallelizable.txl [c code filepath] -comment -q -o /dev/null - -db

## Tests:
 - Run command: python3 runTests.py
 - Include program output: python3 runTests.py -v