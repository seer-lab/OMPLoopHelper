import sys
import os
import subprocess

import os
dirname = os.path.abspath(os.path.dirname(__file__))

# configuration
ifdefExeLocation = dirname + '/bin/ifdef.x'
omplhExeLocation = dirname + '/bin/OMPLoopHelper.x'

# development config
ifdefTxlLocation = dirname + '/C18/ifdef.txl'
omplhTxlLocation = dirname + '/OMPLoopHelper.txl'
tempFile1 = dirname + '/omplhtmp1.tmp'
tempFile2 = dirname + '/omplhtmp2.tmp'


# check if txl is installed
txlCommandOutput = subprocess.run(['txl'], stderr=subprocess.PIPE)
txlInstalled = 'TXL' in str(txlCommandOutput.stderr)

# get command line arguments
arguments = sys.argv
verbose = '-v' in arguments
help = '-h' in arguments
dev = '-i' in arguments
compile = '-c' in arguments
debug = '-db' in arguments

# handle command line args
if(help):
    print(
        'Usage: python3 OMPLoopHelper.py <c-code-filepath> [-v] [-h] [-i] [-db]')
    print('Usage Flags:')
    print('-v:  verbose output')
    print('-h:  print this help message')
    print('Development Flags:')
    print('-i:  run with TXL interpreter instead of executables (requires TXL installation)')
    print('-db: debug mode (print debug info in TXL program)')
    print('\nTo mark loops for analysis, add this comment (//@omp-analysis=true)\none line above the loop in the c code file. Example:')
    print('//@omp-analysis=true')
    print('for(...')
    exit()

if((compile or dev) and not txlInstalled):
    print('Error: TXL is not installed. -c flag requires TXL installation.')
    exit()

# get filepath of c-code file from command line arguments
fileIndex = arguments.index(list(s for s in arguments if '.c' in s)[0])
fileName = ''
if(len(arguments) > fileIndex):
    fileName = arguments[fileIndex]
else:
    print('Error: No c-code file path given. Use -h for help.')
    exit()

# build commands
ifdefInterpreted = ['txl', ifdefTxlLocation, fileName, '-q', '-o', tempFile1]
omplhInterpreted = ['txl', omplhTxlLocation, tempFile2, '-q']
ifdefExecutable = [ifdefExeLocation, fileName, '-o', tempFile1]
omplhExecutable = [omplhExeLocation, tempFile2]

ifdefCommand = ifdefExecutable if(not dev) else ifdefInterpreted
omplhCommand = omplhExecutable if(not dev) else omplhInterpreted

if(verbose):
    omplhCommand.append('-')
    omplhCommand.append('v')
if(debug):
    omplhCommand.append('-')
    omplhCommand.append('db')


# TXL program order:
# 1. Comment all preprocessing statements
# 2. Uncomment the analysis flag (//@omp-analysis=true) in the file
# 3. Run OMPLoopHelper.txl
def runPipeline(p):
    # step 1
    subprocess.run(ifdefCommand, stderr=subprocess.PIPE)

    # step 2
    f = open(tempFile1, 'r')
    fn = f.read().replace('//@omp-analysis=true', '@omp-analysis=true')
    f.close()
    # write fn to file
    f = open(tempFile2, 'w')
    f.write(fn)
    f.close()

    # step 3
    finalOutput = subprocess.run(omplhCommand, capture_output=True)

    if(p):
        print(finalOutput.stderr.decode('ascii'))

    # delete temporary files
    os.remove(tempFile1)
    os.remove(tempFile2)

    return finalOutput.stderr.decode('ascii')


# run program
runPipeline(True)
