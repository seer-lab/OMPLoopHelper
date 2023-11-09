#OMPLoopHelper

See the web front-end at https://omploophelper-online-production.up.railway.app/

This program performs 5 steps to analyze each marked for loop for OpenMP parallelization compatibility:
 1. match for loop
 2. check that loop is pragma-compatible (structured block)
 3. check for collapse pragma compatibility
 4. check for memory conflict with recursive method
 5. generate suggested omp pragma parameters

## Usage Instructions:
1. Have c code, with at least one for loop
2. Add this comment immediately before the loop(s) you want to be analyzed: ```//@omp-analysis=true```
3. Run compiled program: ```./OMPLoopHelper.x <c code filepath>```


## Development/Interpreter Instructions:
- Run program with interpreter: ```txl OMPLoopHelper.txl <c code filepath> -comment -q```
- Compile program: ```txlc OMPLoopHelper.txl -comment -q```

## Command line arguments

| **Argument**             | Flag   | Info                                                                                                                                           |
|--------------------------|--------|------------------------------------------------------------------------------------------------------------------------------------------------|
| Verbose                  | - v    | Gives more information on suggested pragma parameters                                                                                          |
| Debug (development)      | - db   | For development purposes. Use to show TXL program debugging messages. You can add new debug messages with [printdb] and [messagedb] functions. |
| Both (verbose and debug) | - v db |                                                                                                                                                |

## Tests:
 - Run automated tests: ```python3 runTests.py```
 - Include individual test output: ```python3 runTests.py -v```
