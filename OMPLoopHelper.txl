% isParallelizable.txl

% This program checks 4 steps to analyze each marked for loop for OpenMP parallelization compatibility
% 1. match for loop
% 2. check that loop is pragma-compatible (structured block)
% 3. check for collapse pragma compatibility
% 4. check for memory conflict with recursive method
% 5. generate suggested omp pragma parameters

% Usage Instructions:
% 1. Have c code, with at least one for loop
% 2. Add this comment immediately before the loop(s) you want to be analyzed: //@omp-analysis=true
% 3. Run compiled program: ./OMPLoopHelper.x <c code filepath>

% Development/Interpreter Instructions:
% - Run program with interpreter: txl OMPLoopHelper.txl <c code filepath> -comment -q
% - Compile program to executable: txlc OMPLoopHelper.txl -comment -q

% Command line arguments
% Argument                  | Flag      | Info
% --------------------------|-----------|-----------
% Verbose                   | - v       | Gives more information on suggested pragma parameters
% Debug (development)       | - db      | For development purposes. Use to show TXL program debugging messages. 
%                           |           | You can add new debug messages with [printdb] and [messagedb] functions.
% Both (verbose and debug)  | - v db    |

% Tests:
% - Run automated tests: python3 runTests.py
% - Include individual test output: python3 runTests.py -v


%_____________ Include grammar definitions _____________
% Source: https://www.txl.ca/txl-resources.html
include "C18/c.grm"
include "C18/bom.grm"
include "C18/c-comments.grm"


%_____________ Include project code _____________
include "src/print-methods.txl"
include "src/print-visibilities.txl"
include "src/generate-pragma.txl"
include "src/collapse-check.txl"
include "src/memory-conflict-check.txl"
include "src/inner-loops-check.txl"
include "src/reduction-suggestion.txl"
include "src/store-assigned-to-ids.txl"
include "src/pragma-compatibility-check.txl"


%_____________ Define/redefine necessary patterns _____________

define inner_tag
    _ | '!INNER
end define

define analysis_annotation
    '@omp-analysis=true
    | '//@omp-analysis=true
end define

%tokens
%    comment_annotation "//@omp-analysis=true"
%end tokens

% define comment_for for easier parsing of for loops preceded by annotation
% attr stringlit - inner loop indicator - "INNER" if true
define comment_for
    %[comment] [NL]
    %[attr srclinenumber] [attr inner_tag] [for_statement] |
    [analysis_annotation] [NL]
    [attr srclinenumber] [attr inner_tag] [for_statement]
end define

redefine for_statement
    ...
    | [comment_for]
end redefine

%redefine declaration_or_statement
%    ...
%    | [comment]
%end redefine

%redefine block_item
%    ...
%    | [comment]
%end redefine

redefine block_item
    [attr srclinenumber] [declaration_or_statement]
end redefine

define assignment_info
    [srclinenumber] [NL]            % line number
    [number] [NL]                   % index
    [unary_expression] [NL]         % assigned-to identifier
    [assignment_expression] [NL]    % assignment expression
    [repeat unary_expression] [NL]  % referenced identifiers
end define

% operators that can have reductions
define reduction_operator
    '+ | '- | '* | '& | '| | '^ | '&& | '||
end define

define reduction_assignment_operator
    '+= | '-= | '*= | '&= | '|= | '^=
end define

redefine assignment_operator
    [reduction_assignment_operator]
    | '= | '/= | '<<= | '>>=
end redefine


%_____________ Main: apply functions/rules to entire program _____________

function main

    replace [program]
        p [program]
    
    construct p_new [program]
        p   [markInnerLoopsInProgram]
            [checkForParallel]

    % replace with empty program to avoid printing entire program
    by
        _
end function



%_____________ Main parallelizable-check rule _____________

% check if for loop can be parallelized
rule checkForParallel

    % match annotated for-loop
    replace $ [comment_for]
        cf [comment_for]
    deconstruct cf
        aa [analysis_annotation]
        ln [srclinenumber] it [attr inner_tag] f [for_statement]
    %construct m003 [stringlit]
    %    _ [+ "matched comment_for with //@omp-analysis=true"] [print]
    

    % global vars: used to gather loop information for output
    export assignedToElements [repeat unary_expression]
        _
    export assignedToIdentifiers [repeat unary_expression]
        _
    export assignmentInfo [repeat assignment_info]
        _
    export assignmentInfoNum [number]
        1
    export checkAINum [number]
        0
    export loopHasMemoryConflict [number]
        0
    export sharedIdentifiers [repeat identifier]
        _
    export privateIdentifiers [repeat identifier]
        _
    export defaultIdentifiers [repeat identifier]
        _
    export collapse [number]
        0
    % reduction suggestions
    export plusReductionIdentifiers [list identifier]
        _
    export subReductionIdentifiers [list identifier]
        _
    export mulReductionIdentifiers [list identifier]
        _


    % deconstruct loop, export iterator
    construct m0 [stringlit]
        _ [+ "Analyzing for loop on line "] [quote ln] [+ ": "] [message ""] [print] [message f] [message ""]
    deconstruct f
        'for '( nnd [non_null_declaration] el1 [opt expression_list] '; el2 [opt expression_list] soel [opt semi_opt_expression_list] ') ss [sub_statement]
    deconstruct nnd
        ds  [opt declaration_specifiers]
        d   [declarator]
        oi  [opt initialization]
        ';
    export iterator [declarator]
        d
    construct m1 [stringlit]
        _ [+ "iterator: "] [quote d] [printdb]
    %deconstruct ss
    %    '{ b [repeat block_item] '}


    % tell user if this loop is an inner loop
    construct m7 [comment_for]
        cf [warnIfInnerLoop]


    % check if sub scope is compatible for OpenMP pragmas
    where not
        ss [subScopeNotCompatible]
    construct m3 [repeat any]
        _ [messagedb "Loop passed pragma compatibility test (step 2)"]


    % run collapse test -
    construct collapseTest [sub_statement]
        ss [canBeCollapsed]
    construct collapseMessage [repeat any]
        _ [printCollapseInfo]


    % check for memory conflict
    construct m4 [sub_statement]
        ss [storeAssignedToElements]
    construct m5 [repeat any]
        _ [printAssignmentInfo] % print assigned to info in db mode
    where
        ss [checkTheresNoMemoryConflict]
    construct m6 [repeat any]
        _ [messagedb "Loop passed memory-conflict test (step 4)"]

    construct noParallelizationProblemMessage [repeat any]
        _ [message "[INFO] No parallelization problems found with this loop."]


    % print pragma/parameters suggestion
    construct m8 [repeat any]
        _ [generatePragma f]

    % debug reduction suggestion lists
    import plusReductionIdentifiers
    import subReductionIdentifiers
    import mulReductionIdentifiers
    construct m9 [stringlit]
        _   [+ "plusReductionIdentifiers: "] [quote plusReductionIdentifiers]
            [+ ", subReductionIdentifiers: "] [quote subReductionIdentifiers]
            [+ ", mulReductionIdentifiers: "] [quote mulReductionIdentifiers] [printdb]

    % find and print default visibility of all variables in the loop
    construct m2 [for_statement]
        f [printVariableVisibilities iterator ss]

    % "replace" with original comment-for-loop
    by
        cf
end rule