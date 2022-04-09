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

# get command line arguments
arguments = sys.argv
print('Number of arguments:', len(sys.argv), 'arguments.')
print('Argument List:', str(sys.argv))

verbose = '-v' in arguments
help = '-h' in arguments
dev = '-d' in arguments

# check if txl is installed
result = subprocess.run(['txl'], stderr=subprocess.PIPE)
if('TXL' not in str(result.stderr)):
    print('Error: txl is not installed')
    exit(1)

# TXL program order:
# 1. Uncomment the analysis flag (//@omp-analysis=true) in the file
# 2. Comment all preprocessing statements
# 3. Run OMPLoopHelper.py

# 1
uncommentAnnotation = subprocess.run(
    ['txl', './src/uncomment-annotation.txl', 'tests/pass/arrayConflict.c', '-q', '-o', './omplhtmp1.tmp'])

# 2
commentPreprocessors = subprocess.run(
    ['txl', './C18/ifdef.txl', './omplhtmp1.tmp', '-q', '-o', './omplhtmp2.tmp'])

# 3
finalOutput = subprocess.run(
    ['txl', './OMPLoopHelper.txl', './omplhtmp2.tmp', '-q'], stderr=subprocess.PIPE)

print(finalOutput.stderr.decode('ascii'))
