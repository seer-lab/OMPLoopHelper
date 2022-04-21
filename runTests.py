# run command:          python3 runTests.py
# or, for more output:  python3 runTests.py -v

import subprocess
import sys

# if user gives "-v" as argument, show test output
verbose = False
if(len(sys.argv) > 1 and sys.argv[1] == "-v"):
    verbose = True

failDir = 'tests/fail/'
passDir = 'tests/pass/'
txlCommand = ['txl', 'OMPLoopHelper.txl', '-q', '-o', '/dev/null']
pythonCommand = ['python3', 'OMPLoopHelper.py']

greenColorCode = '\x1b[1;32m'
redColorCode = '\x1b[1;31m'
underlineCode = '\x1b[4m'
endCode = '\x1b[0m'

successString = '[INFO] No parallelization problems found with this loop.'
failString = '[WARNING]'

# use ls to get each filename in tests/fail
result = subprocess.run(['ls', failDir], stdout=subprocess.PIPE)
failFiles = str(result.stdout).split('b\'')[1].split('\\n')[:-1]

# use ls to get each filename in tests/pass
result = subprocess.run(['ls', passDir], stdout=subprocess.PIPE)
passFiles = str(result.stdout).split('b\'')[1].split('\\n')[:-1]

failTests = []
passTests = []

# run tests
for i in failFiles:
    fname = failDir + i
    result = subprocess.run(pythonCommand + [fname], capture_output=True, text=True)
    lines = str(result.stdout).split('\n')

    if len(lines) > 2:
        testPass = False
        for line in lines:
            if(line[:len(failString)] == failString):
                testPass = True
                break

        if(testPass):
            failTests.append(greenColorCode + 'Pass' + endCode)
        else:
            failTests.append(redColorCode + 'Fail' + endCode)
    else:
        print('Error: program output for file "' + fname + '" is empty')
        failTests.append(redColorCode + 'No Output' + endCode)

    if verbose:
        print(fname + ': ')
        print(result.stdout)

for i in passFiles:
    fname = passDir + i
    result = subprocess.run(pythonCommand + [fname], capture_output=True, text=True)
    lines = str(result.stdout).split('\n')

    if len(lines) > 2:
        testPass = False
        for line in lines:
            if(line[:len(successString)] == successString):
                testPass = True
                break

        if(testPass):
            passTests.append(greenColorCode + 'Pass' + endCode)
        else:
            passTests.append(redColorCode + 'Fail' + endCode)
    else:
        print(redColorCode + 'Error: program output for file "' + fname + '" is empty' + endCode)
        passTests.append(redColorCode + 'No Output' + endCode)

    if verbose:
        print(fname + ': ')
        print(result.stdout)


# print test results
print('\n' + underlineCode + 'Fail tests:' + endCode)
for i in range(len(failTests)):
    print((str(i) + '. ' + failFiles[i] + '\t' + failTests[i]).expandtabs(50))

print('\n' + underlineCode + 'Pass tests:' + endCode)
for i in range(len(passTests)):
    print((str(i) + '. ' + passFiles[i] + '\t' + passTests[i]).expandtabs(50))