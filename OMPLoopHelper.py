import sys
import os
import subprocess
import re
import time
import datetime
import shutil
import argparse
import json
import logging

# configuration
ifdefExeLocation = './bin/ifdef.x'
omplhExeLocation = './bin/OMPLoopHelper.x'

# development config
ifdefTxlLocation = './C18/ifdef.txl'
omplhTxlLocation = './OMPLoopHelper.txl'
tempFile1 = './omplhtmp1.tmp'
tempFile2 = './omplhtmp2.tmp'


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
fileIndex = arguments.index('OMPLoopHelper.py') + 1
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
    f = open('./omplhtmp1.tmp', 'r')
    fn = f.read().replace('//@omp-analysis=true', '@omp-analysis=true')
    f.close()
    # write fn to file
    f = open('./omplhtmp2.tmp', 'w')
    f.write(fn)
    f.close()

    # step 3
    finalOutput = subprocess.run(omplhCommand, capture_output=True)

    if(p):
        print(finalOutput.stderr.decode('ascii'))

    # delete temporary files
    os.remove('./omplhtmp1.tmp')
    os.remove('./omplhtmp2.tmp')

    return finalOutput.stderr.decode('ascii')


# run program
runPipeline(True)
