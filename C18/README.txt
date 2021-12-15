Validated TXL Basis Grammar for C18 with Macros and Gnu Extensions
Version 6.4, November 2020

Copyright 1994-2020 James R. Cordy, Andrew J. Malton and Christopher Dahn
Licensed under the MIT open source license, see source for details.

Description:
    Consolidated grammar for C18, ANSI, and K+P C with Gnu extensions
    designed for large scale C analysis tasks.  Validated on a large range 
    of open source C software including Bison, Cook, Gzip, Postgresql, SNNS, 
    Weltab, WGet, Apache HTTPD, the entire Linux 2.6 kernel, and the entire
    FreeBSD 8.0 kernel.

    Handles both preprocessed and unpreprocessed C code with with expanded or
    unexpanded C macro calls.  

    Optionally handles but does not interpret C preprocesor directives, 
    except #ifdefs that violate syntactic boundaries.  #ifdefs can be handled 
    using the separate Antoniol et al. transformation that keeps only the #else parts
    and comments out the optional (#if, #elsif) parts (ifdef.txl).

    Ignores and does not preserve comments. Optionally accepts and preserves
    comments using an added approximate comment grammar (c-comments.grm).

Authors:
    J.R. Cordy, Queen's University
    A.J. Malton, University of Waterloo
    C. Dahn, Drexel University

Example:
    txl program.c c.txl
    txl porogram.c ifdef.txl > program_ifdef.c;  txl program_ifdef.c c.txl

Notes:
    1. The syntax of the C language is not context-free, and there will always be
    cases that cannot be accurately parsed by a context-free grammar. 
    In particular, there is an ambiguity between statements and declarations that
    cannot be resolved without a two-pass parse.

    2. While this grammar handles most unexpanded Gnu/Linux-style macro calls,
    it cannot do so for all cases since macros may hide additional syntax.

Rev. 13.11.20
