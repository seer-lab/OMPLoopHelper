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
include "C18/c-comments.grm"


%_____________ Define/redefine necessary patterns _____________

define inner_tag
    _ | '!INNER
end define

% define comment_for for easier parsing of for loops preceded by annotation
% attr stringlit - inner loop indicator - "INNER" if true
define comment_for
    [comment] [NL]
    [attr srclinenumber] [attr inner_tag] [for_statement]
end redefine

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


%_____________ Debug and Verbose Methods: print/message only if flags are given _____________

% print if - db flag is given
function printdb
    match [stringlit]
        s [stringlit]
    import TXLargs [repeat stringlit]
    deconstruct * TXLargs
        "db"
        moreOptions [repeat stringlit]
    construct m [stringlit]
        s [print]
end function

% message if - db flag is given
function messagedb s [stringlit]
    replace [any]
        a [any]
    import TXLargs [repeat stringlit]
    deconstruct * TXLargs
        "db"
        moreOptions [repeat stringlit]
    construct m [stringlit]
        s [print]
    by
        a
end function

% print if - v flag is given
function printv
    match [stringlit]
        s [stringlit]
    import TXLargs [repeat stringlit]
    deconstruct * TXLargs
        "v"
        moreOptions [repeat stringlit]
    construct m [stringlit]
        s [print]
end function

% message if - v flag is given
function messagev s [stringlit]
    replace [any]
        a [any]
    import TXLargs [repeat stringlit]
    deconstruct * TXLargs
        "v"
        moreOptions [repeat stringlit]
    construct m [stringlit]
        s [print]
    by
        a
end function


%_____________ Main: apply functions/rules to entire program _____________

function main
    replace [program]
        p [program]
    
    % 
    construct p_new [program]
        p   [markInnerLoopsInProgram]
            [checkForParallel]

    % replace with empty program to prevent printing entire program
    by
        _
end function


%_____________ Mark Inner Loops _____________

% mark all inner loops with an attribute, so a warning can be given to user
function markInnerLoopsInProgram
    replace [program]
        p [program]
    by
        p [markInnerLoopsInCommentFor] [markInnerLoopsInFor]
end function

rule markInnerLoopsInFor
    replace $ [for_statement]
        'for '( nnd [opt non_null_declaration] el [opt expression_list] ';
            el2 [opt expression_list] soel [opt semi_opt_expression_list] ')
            ss [sub_statement]
    construct ss_new [sub_statement]
        ss [markInnerLoops]
    by
        'for '( nnd el ';
            el2  soel  ')
            ss_new
end rule

rule markInnerLoopsInCommentFor
    replace $ [comment_for]
        c [comment]
        ln [srclinenumber] it [inner_tag]
        'for '( nnd [opt non_null_declaration] el [opt expression_list] ';
            el2 [opt expression_list] soel [opt semi_opt_expression_list] ')
            ss [sub_statement]
    construct ss_new [sub_statement]
        ss [markInnerLoops]
    by
        c
        ln it 'for '( nnd el ';
            el2 soel ')
            ss_new
end rule

rule markInnerLoops
    replace $ [comment_for]
        '//@omp-analysis=true
        ln [srclinenumber] fs [for_statement]
    construct m1 [stringlit]
        _ [+ "Found inner loop on line "] [quote ln] [+ ". Marking with inner-tag attribute."] [printdb]
    by
        '//@omp-analysis=true
        ln '!INNER fs
end rule

function warnIfInnerLoop
    match [comment_for]
        '//@omp-analysis=true
        ln [srclinenumber] it [inner_tag] f [for_statement]
    construct cit [inner_tag]
        '!INNER
    where
        cit [= it]
    construct m [stringlit]
        _ [+ "[INFO] This loop is nested inside another for-loop. Consider this loop's parent loop before parallelizing."] [print]
end function


%_____________ Main parallelizable-check rule _____________

% check if for loop can be parallelized
rule checkForParallel

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


    % match annotated for-loop
    replace $ [comment_for]
        cf [comment_for]
    deconstruct cf
        '//@omp-analysis=true
        ln [srclinenumber] it [attr inner_tag] f [for_statement]


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
    construct m00 [stringlit]
        _ [+ "iterator: "] [quote d] [printdb]
    % TODO: support single-line-block for loops
    deconstruct ss
        '{ b [repeat block_item] '}


    % check if sub scope is compatible for OpenMP pragmas
    where not
        b [subScopeNotCompatible]
    construct m1 [repeat any]
        _ [messagedb "Loop passed pragma compatibility test (step 2)"]


    % run collapse test -
    construct collapseTest [repeat block_item]
        b [canBeCollapsed]
    construct collapseMessage [repeat any]
        _ [printCollapseInfo]


    % check for memory conflict
    construct m2 [repeat block_item]
        b [storeAssignedToElements]
    construct m3 [repeat any]
        _ [printAssignmentInfo] % print assigned to info in db mode
    where
        b [checkTheresNoMemoryConflict]
    construct m4 [repeat any]
        _ [messagedb "Loop passed memory-conflict test (step 4)"]

    construct noParallelizationProblemMessage [repeat any]
        _ [message "[INFO] No parallelization problems found with this loop."]

    % tell user if this loop is an inner loop
    construct m5 [comment_for]
        cf [warnIfInnerLoop]

    % print pragma/parameters suggestion
    construct m6 [repeat any]
        _ [generatePragma f]

    % debug reduction suggestion lists
    import plusReductionIdentifiers
    import subReductionIdentifiers
    import mulReductionIdentifiers
    construct m7 [stringlit]
        _   [+ "plusReductionIdentifiers: "] [quote plusReductionIdentifiers]
            [+ ", subReductionIdentifiers: "] [quote subReductionIdentifiers]
            [+ ", mulReductionIdentifiers: "] [quote mulReductionIdentifiers] [printdb]

    % replace with original comment-for-loop (no replacement yet), print success message
    by
        cf
end rule



%_____________ Generate suggested pragma parameters _____________
function generatePragma fs [for_statement]
    import collapse [number]

    match [repeat any]
        ra [repeat any]

    construct reduction [stringlit]
        _ [+ ""] [addReductionParameter]

    construct m0 [stringlit]
        _ [message "[SUGGESTION] Use these parameters:"] [+ "#pragma omp parallel for"] [addReductionParameter] [addCollapseParameter] [print] [message fs]
    %construct m1 [stringlit]
    %    _ [quote fs] [print]

    construct m2 [stringlit]
        _ [+ "collapse: "] [quote collapse] [printdb]

end function

function addReductionParameter
    replace [stringlit]
        sl [stringlit]
    construct reductionClauses [stringlit]
        _ [addAdditionReduction] [addSubtractionReduction] [addMultiplicationReduction]
    by
        sl [+ reductionClauses]
end function

function addAdditionReduction
    replace [stringlit]
        s [stringlit]
    import plusReductionIdentifiers [list identifier]
    deconstruct plusReductionIdentifiers % at least one id
        id [identifier] ', ids [list identifier]
    by
        s [+ " reduction(+:"] [quote plusReductionIdentifiers] [+ ")"]
end function

function addSubtractionReduction
    replace [stringlit]
        s [stringlit]
    import subReductionIdentifiers [list identifier]
    deconstruct subReductionIdentifiers % at least one id
        id [identifier] ', ids [list identifier]
    by
        s [+ " reduction(-:"] [quote subReductionIdentifiers] [+ ")"]
end function

function addMultiplicationReduction
    replace [stringlit]
        s [stringlit]
    import mulReductionIdentifiers [list identifier]
    deconstruct mulReductionIdentifiers % at least one id
        id [identifier] ', ids [list identifier]
    by
        s [+ " reduction(*:"] [quote mulReductionIdentifiers] [+ ")"]
end function

function addCollapseParameter
    replace [stringlit]
        sl [stringlit]
    import collapse [number]
    where
        collapse [> 0]
    construct collapseParameter [stringlit]
        _ [+ " collapse("] [quote collapse] [+ ")"]
    by
        sl [+ collapseParameter]
end function

%_____________ check if for loop is nested and can be collapsed _____________
function canBeCollapsed
    match $ [repeat block_item]
        b [repeat block_item]
    where
        b [containsForLoop]
    where not
        b [containsNonForLoop]
    import collapse [number]
    export collapse
        collapse [+ 1]
end function

function printCollapseInfo
    match [repeat any]
        ra [repeat any]
    import collapse [number]
    where
        collapse [> 0]
    construct canBeCollapsedMessage [stringlit]
        _ [+ "[SUGGESTION] Use the collapse construct when parallelizing this for loop: collapse("] [quote collapse] [+ ")"] [printv]
end function

rule containsForLoop
    match $ [declaration_or_statement]
        fs [for_statement]
    construct m0 [for_statement]
        fs [checkNestedForLoopForCollapse]
end rule

function checkNestedForLoopForCollapse
    match [for_statement]
        fs [for_statement]
    deconstruct fs
        'for '( nnd [opt non_null_declaration] el1 [opt expression_list] '; el2 [opt expression_list] soel [opt semi_opt_expression_list] ') ss [sub_statement]
    deconstruct ss
    '{ b [repeat block_item] '}
    construct rbi [repeat block_item]
        b [canBeCollapsed]
end function

function containsNonForLoop
    match $ [repeat block_item]
        b [repeat block_item]
    where
        b [checkForNonForLoop]
    construct cantBeCollapsedMessage [repeat any]
        _ [message "[INFO] This for loop cannot use the collapse construct without refactoring."]
end function

rule checkForNonForLoop
    % ignore nested loop's inner scope
    skipping [sub_statement]
    match $ [block_item]
        ln [srclinenumber] ds [declaration_or_statement]
    where not
        ds [isForLoop]
    where not
        ds [containsComment]
end rule

function isForLoop
    match $ [declaration_or_statement]
        fs [for_statement]
end function

function containsComment
    match $ [declaration_or_statement]
        c [comment]
end function


%_____________ check for memory conflict _____________

function checkTheresNoMemoryConflict
    match $ [repeat block_item]
        b [repeat block_item]

    construct b1 [repeat block_item]
        b [checkAssignmentForMemoryConflict]

    % check memory conflict flag
    import loopHasMemoryConflict [number]
    where not
        loopHasMemoryConflict [= 1]

end function

% Check if assignment is the root of a memory conflict
rule checkAssignmentForMemoryConflict
    match $ [block_item]
        ln [srclinenumber] ds [declaration_or_statement]

    % check that this block item is an assignment
    deconstruct ds
        ae [assignment_expression] ';
    construct m0 [stringlit]
        _ [+ "line "] [quote ln] [+ " has an assignment: "] [quote ds] [printdb]

    % import necessary global vars, print debug info
    import assignmentInfo [repeat assignment_info]
    import checkAINum [number]
    export checkAINum
        checkAINum [+ 1]

    % recursively check for memory conflict rooted in this line
    where not
        assignmentInfo [getAssignmentInfo ln ln checkAINum checkAINum]
    construct m2 [stringlit]
        _ [+ "no problem stemming from this line"] [printdb]
end rule

% check, given a repeat assignment_info, if it contains info for a specific assignment
rule assignmentInfoHasLineAndAINum ln [srclinenumber] n [number]
    match $ [assignment_info]
        ailn [srclinenumber]
        it [number]
        id [unary_expression]
        ae [assignment_expression]
        ri [repeat unary_expression]
    where
        ailn [= ln]
    where
        it [= n]
end rule

rule getAssignmentInfo ln [srclinenumber] rootln [srclinenumber] it [number] rootIt [number]
    construct message1 [stringlit]
        _ [+ "       - in getAssignmentInfo it="] [quote it] [printdb]

    % match assignment_info for given assignment (ln/it)
    match [assignment_info]
        ai [assignment_info]
    deconstruct ai
        ailn [srclinenumber]
        aiit [number]
        id [unary_expression]
        ae [assignment_expression]
        ri [repeat unary_expression]

    where
        ailn [= ln]
    where
        aiit [= it]

    % print each referenced var in assignment
    construct message2 [stringlit]
        _ [+ "       - references: "] [quote ri] [printdb]

    % reduction check for assignment operators (+=)
    construct reductionCheckA [assignment_expression]
        ae [checkForReductionAssignOp ailn id]
    % reduction check for other operators (+, *)
    construct reductionCheckB [assignment_info]
        ai [checkForReduction]

    % check referenced variables
    where
        ri [traceBackRefdVars id rootln rootIt ae aiit]

    construct message3 [stringlit]
        _ [+ " passed getAssignmentInfo"] [printdb]
end rule

rule lineAssignsToArray ue [unary_expression] rootln [srclinenumber] rootIt [number]

    % deconstruct ue to match an array reference
    deconstruct ue
        rpido [repeat pre_increment_decrement_operator]
        arrayName [identifier]
        se [subscript_extension]
        rpe [repeat postfix_extension]

    % match assignment_info for array of given ue
    match $ [assignment_info]
        ln      [srclinenumber]
        ind     [number]
        aiue    [unary_expression]
        ae      [assignment_expression]
        rue     [repeat unary_expression]
   
    % where aiue and ue are elements of the same array
    where
        aiue [sameArray ue]

    % debug message
    construct m0 [stringlit]
        _ [+ "found assigned-to array reference on line "] [quote ln] [+ " , line: "] [quote ae] [printdb]

    % check if the array indeces are different
    where not
        aiue [sameArrayIndeces ue]

    % construct warning message
    construct m1 [stringlit]
        _   [+ "[WARNING] This loop may need to be refactored before being parallelized."]
            [+ " Array \""] [quote arrayName] [+ "\" is referenced on line "] [quote rootln]
            [+ " at index "] [quote ue] [+ " and assigned to on line "] [quote ln] [+ " at index "]
            [quote aiue] [print]

    export loopHasMemoryConflict [number]
        1
end rule

% given two unary_expressions (one in scope, one as argument), check if both are
% array references of the same array
function sameArray a1 [unary_expression]
    match [unary_expression]
        a0 [unary_expression]
    deconstruct a0
        rpido0 [repeat pre_increment_decrement_operator]
        arrayName0 [identifier]
        se0 [subscript_extension]
        rpe0 [repeat postfix_extension]
    deconstruct a1
        rpido1 [repeat pre_increment_decrement_operator]
        arrayName1 [identifier]
        se1 [subscript_extension]
        rpe1 [repeat postfix_extension]
    where
        arrayName0 [= arrayName1]
end function

% given two array indeces, as unary_expressions (one in scope, one as argument),
% check if each one references the same element of the array
function sameArrayIndeces a1 [unary_expression]
    match [unary_expression]
        a0 [unary_expression]
    deconstruct a0
        rpido0 [repeat pre_increment_decrement_operator]
        arrayName0 [identifier]
        se0 [subscript_extension]
        rpe0 [repeat postfix_extension]
    deconstruct a1
        rpido1 [repeat pre_increment_decrement_operator]
        arrayName1 [identifier]
        se1 [subscript_extension]
        rpe1 [repeat postfix_extension]
    where
        se0 [= se1]
end function


% idIsAssignedTo?
% match assignment_info where given id is assigned to
% then ... TODO
rule lineAssignsToId id [unary_expression] rootln [srclinenumber] rootIt  [number]

    % only check variables in this method;
    % array elements are handled in lineAssignsToArray
    deconstruct not id
        rpido [repeat pre_increment_decrement_operator]
        arrayName [identifier]
        se [subscript_extension]
        rpe [repeat postfix_extension]

    % match assignment where given id is assigned to
    match $ [assignment_info]
        ai [assignment_info]
    deconstruct ai
        ln   [srclinenumber]
        it   [number]
        aiid [unary_expression]
        ae   [assignment_expression]
        ri   [repeat unary_expression]
    where
        aiid [= id]
    construct m0 [stringlit]
        _ [+ " - found line where id "] [quote id] [+ " is assigned to. tracing:"] [printdb]

    % if there is no later assign ...
    where not
        ai [checkIfAssignAfter rootln aiid it rootIt]

    % ... then recursively go back to check ... TODO
%:/    import assignmentInfo [repeat assignment_info]
%:/    construct m2 [repeat assignment_info]
%:/        assignmentInfo [getAssignmentInfo ln rootln it rootIt]
end rule

% Given an id and an index, check if there is an operation later than the index which assigns to that id
function checkIfAssignAfter rootln [srclinenumber] id [unary_expression] it [number] rootIt [number]
    match $ [assignment_info]
        ln      [srclinenumber]
        aiit    [number]
        aiid    [unary_expression]
        ae      [assignment_expression]
        ri      [repeat unary_expression]
    construct dbm0 [stringlit]
        _ [+ "   ln: "] [quote ln] [+ ", rootln: "] [quote rootln] [printdb]
    where
        aiit [> rootIt] % it or rootIt???
    construct dbm1 [stringlit]
        _ [+ "WARN: assign after root ln: "] [quote id] [+ " on line "] [quote ln] [printdb]

    % Finally, check that the id wasn't assigned to earlier in the loop
    % (this would mean there is no memory conflict with this variable..
    % .. , since it is assigned-to in this iteration *before* being referenced)
    import assignmentInfo [repeat assignment_info]
    where not
        assignmentInfo [isEarlierAssignment rootln id it rootIt]

    construct m0 [stringlit]
        _   [+ "[WARNING] This loop may need to be refactored before being parallelized. Identifier "] [quote id]
            [+ " is referenced on line "] [quote rootln]
            [+ " and assigned to on line "] [quote ln] [print]

    export loopHasMemoryConflict [number]
        1
end function

% Given an assignment index and an id, check if there is an earlier assignment to the id
rule isEarlierAssignment rootln [srclinenumber] id [unary_expression] it [number] rootIt [number]
    match $ [assignment_info]
        ln   [srclinenumber]
        aiit [number]
        aiid [unary_expression]
        ae   [assignment_expression]
        ri   [repeat unary_expression]
    where
        aiit [< rootIt] % it or rootIt???
    where
        aiid [= id]
end rule


%_____________ Reduction Clause Suggestion Detection _____________

% Check for reduction ability in assignments in the form: a += <...>;
function checkForReductionAssignOp ln [srclinenumber] aid [unary_expression]
    match [assignment_expression]
        ae [assignment_expression]
    
    deconstruct ae
        ue [unary_expression] aae [assign_assignment_expression]
    deconstruct aae
        ao [assignment_operator] ae1 [assignment_expression]

    % assignment operator is like +=, -=, etc.
    deconstruct ao
        rao [reduction_assignment_operator]

    % scalar variable only
    deconstruct ue
        id [identifier]
    
    %construct m0 [reduction_assignment_operator]
    %    rao [debug]

    construct m [stringlit]
        _   [+ "[SUGGESTION] Variable \""] [quote aid]
            [+ "\" is assigned to and referenced in the same assignment on line "]
            [quote ln]
            [+ ". Consider using a reduction clause (e.g. \"reduction(+:"]
            [quote aid] [+ ")\")"] [printv]
    construct ao1 [assignment_operator]
        ao [addAOInfo id]
end function

function addAOInfo id [identifier]
    match [assignment_operator]
        ao [assignment_operator]

    construct ao2 [assignment_operator]
        ao  [recordAddReduction id]
            [recordSubReduction id]
            [recordMulReduction id]
end function

function recordAddReduction id [identifier]
    match [assignment_operator]
        '+=
    import plusReductionIdentifiers [list identifier]
    where not
        plusReductionIdentifiers [idInList id]
    export plusReductionIdentifiers
        plusReductionIdentifiers [, id]
end function

function recordSubReduction id [identifier]
    match [assignment_operator]
        '-=
    import subReductionIdentifiers [list identifier]
    where not
        subReductionIdentifiers [idInList id]
    export subReductionIdentifiers
        subReductionIdentifiers [, id]
end function

function recordMulReduction id [identifier]
    match [assignment_operator]
        '*=
    import mulReductionIdentifiers [list identifier]
    where not
        mulReductionIdentifiers [idInList id]
    export mulReductionIdentifiers
        mulReductionIdentifiers [, id]
end function

function idInList id [identifier]
    match [list identifier]
        l [list identifier]
    deconstruct * l
        list_id [identifier]
    where
        list_id [= id]
end function

% Check, for each given var, if
rule traceBackRefdVars rootId [unary_expression] rootln [srclinenumber] rootIt [number] ae [assignment_expression] assignN [number]
    match $ [unary_expression]
        ue [unary_expression]
    where not
        rootId  [assignedToIdIsRefd ue rootln ae]
    import assignmentInfo [repeat assignment_info]
    
    where not
        assignmentInfo  [lineAssignsToId ue rootln rootIt]
                        [lineAssignsToArray ue rootln rootIt]
end rule

% Check if the variable on the left side of assignment is on the right as well
% (or if a special assignment operator is used (+=, *=, etc.))
% If it is, give user a suggestion to use a reduction clause
function assignedToIdIsRefd rid [unary_expression] ln [srclinenumber] ae [assignment_expression]
    match [unary_expression]
        aid [unary_expression]
    where
        aid [= rid]
end function

function checkForReduction
    match [assignment_info]
        ai [assignment_info]
    deconstruct ai
        ailn [srclinenumber]
        aiit [number]
        id [unary_expression]
        ae [assignment_expression]
        ri [repeat unary_expression]

    deconstruct ae
        ce0 [conditional_expression] ao [assignment_operator] ce1 [conditional_expression]

    construct ce2 [conditional_expression]
        ce1 [getReductionOperator id ailn]
end function

function getReductionOperator ue [unary_expression] ln [srclinenumber]
    match [conditional_expression]
        ae [additive_expression]
    % only scalar variables
    deconstruct ue
        id [identifier]
    construct ae1 [additive_expression]
        ae  [getAdditiveOperator ue ln id]
            [getMultiplicativeOperator ue ln id]
end function

function getAdditiveOperator ue [unary_expression] ln [srclinenumber] id [identifier]
    match [additive_expression]
        ae [additive_expression]
    %construct m2 [additive_expression]
    %    ae [debug]
    deconstruct ae
        me [multiplicative_expression] rasme [repeat add_subtract_multiplicative_expression]
    deconstruct not me
        ce [cast_expression] mdce [multipy_divide_cast_expression] rmdce [repeat multipy_divide_cast_expression]
    deconstruct rasme
        asme [add_subtract_multiplicative_expression] rasme2 [repeat add_subtract_multiplicative_expression]
    deconstruct asme
        ao [additive_operator] me1 [multiplicative_expression]
    deconstruct me
        exp_id [identifier]
    where   
        exp_id [= id]
    
    construct m0 [stringlit]
        _   [+ "[SUGGESTION] Variable \""] [quote ue]
            [+ "\" is assigned to and referenced in the same assignment on line "]
            [quote ln]
            [+ ". Consider using a reduction clause (e.g. \"reduction("] [quote ao]
            [+ ":"] [quote ue] [+ ")\")"] [printv]
    
    construct m2 [additive_operator]
        ao  [recordAddOperator id]
            [recordSubOperator id]
end function

function recordAddOperator id [identifier]
    match [additive_operator]
        '+
    import plusReductionIdentifiers [list identifier]
    where not
        plusReductionIdentifiers [idInList id]
    export plusReductionIdentifiers
        plusReductionIdentifiers [, id]
end function

function recordSubOperator id [identifier]
    match [additive_operator]
        '-
    import subReductionIdentifiers [list identifier]
    where not
        subReductionIdentifiers [idInList id]
    export subReductionIdentifiers
        subReductionIdentifiers [, id]
end function

function getMultiplicativeOperator ue [unary_expression] ln [srclinenumber] id [identifier]
    match [additive_expression]
        ae [additive_expression]
    deconstruct ae
        me [multiplicative_expression] rasme [repeat add_subtract_multiplicative_expression]
    deconstruct me
        ce [cast_expression] rmdce [repeat multipy_divide_cast_expression]
    deconstruct rmdce
        mdce [multipy_divide_cast_expression] rmdce1 [repeat multipy_divide_cast_expression]
    deconstruct mdce
        '* ce1 [cast_expression]
    deconstruct ce1
        exp_id [identifier]
    where
        exp_id [= id]

    construct m0 [stringlit]
        _   [+ "[SUGGESTION] Variable \""] [quote ue]
            [+ "\" is assigned to and referenced in the same assignment on line "]
            [quote ln]
            [+ ". Consider using a reduction clause (e.g. \"reduction(*"]
            [+ ":"] [quote ue] [+ ")\")"] [printv]

    import mulReductionIdentifiers [list identifier]
    where not
        mulReductionIdentifiers [idInList id]
    export mulReductionIdentifiers
        mulReductionIdentifiers [, id]
end function


%_____________ Shared variables detection _____________



%_____________ store assigned-to elements in a list _____________

%  store print each assignment expression in scope
rule storeAssignedToElements
    replace $ [block_item]
        ln [srclinenumber] ds [declaration_or_statement]
    deconstruct ds
        ae1 [assignment_expression] ';
    deconstruct ae1
        ce [unary_expression] aae [assign_assignment_expression]

    construct message [assignment_expression]
        ae1 [addAssignmentInfo ln]

    construct ae [assignment_expression]
        ce [addAssignedToElement] aae
    by
        ln ds
end rule

% store info on assignment
function addAssignmentInfo ln [srclinenumber]

    % match important patterns
    match [assignment_expression]
        ae [assignment_expression]
    deconstruct ae
        ue [unary_expression] aae [assign_assignment_expression]

    deconstruct ue
        pe [primary_expression] pte [repeat postfix_extension]
    deconstruct pe
        assignedToID [identifier]

    import assignmentInfoNum [number]

    % add assignment info to list
    construct rid [repeat unary_expression]
        _
    construct ai [assignment_info]
        ln
        assignmentInfoNum
        ue
        ae
        rid
    import assignmentInfo [repeat assignment_info]
    export assignmentInfo
        assignmentInfo [. ai]

    % add all referenced ID's
    construct m [assign_assignment_expression]
        aae [findIDs ai ln assignmentInfoNum]

    export assignmentInfoNum
        assignmentInfoNum [+ 1]
end function

function printAssignmentInfo
    match [repeat any]
        ra [repeat any]
    import assignmentInfo [repeat assignment_info]
    construct message [repeat assignment_info]
        assignmentInfo [printEachAI]
end function

rule printEachAI
    match $ [assignment_info]
        ai [assignment_info]
    construct message [stringlit]
        _ [quote ai] [printdb]
end rule

rule findIDs ai [assignment_info] ln [srclinenumber] it [number]
    match $ [unary_expression]
        ue [unary_expression]
    deconstruct ue
        rpido [repeat pre_increment_decrement_operator]
        id [identifier]
        rpe [repeat postfix_extension]
    import assignmentInfo [repeat assignment_info]
    export assignmentInfo
        assignmentInfo [addRefdID ue ln it]
end rule

rule addRefdID id [unary_expression] ln [srclinenumber] it [number]
    replace $ [assignment_info]
        ai [assignment_info]
    deconstruct ai
        lnr [srclinenumber]
        itr [number]
        idr [unary_expression]
        aer [assignment_expression]
        ridr [repeat unary_expression]
    where
        lnr [= ln]
    where
        itr [= it]
    by
        lnr
        it
        idr
        aer
        ridr [. id]
end rule

% function to add assigned-to element to list
function addAssignedToElement
    import assignedToElements [repeat unary_expression]
    match [unary_expression]
        newEntry [unary_expression]
    construct newAssignedToElements [repeat unary_expression]
        assignedToElements [. newEntry]
    construct none [unary_expression]
        newEntry [addAssignedToIdentifier]
    export assignedToElements
        newAssignedToElements
end function

function addAssignedToIdentifier
    import assignedToIdentifiers [repeat unary_expression]
    match [unary_expression]
        ue [unary_expression]
    deconstruct ue
        pe [primary_expression] pte [repeat postfix_extension]
    deconstruct pe
        newEntry [identifier]
    export assignedToIdentifiers
        assignedToIdentifiers [. ue]
end function


%_____________ check if subscope is compatible with pragmas _____________

% check if sub scope is compatible for pragmas/parallelization
rule subScopeNotCompatible
    match [block_item]
        b [block_item]
    where
        b [isJumpStatement]
end rule

% determine if line violates structured-block condition
function isJumpStatement
    match [block_item]
        ln [srclinenumber] j [jump_statement] s [semi]
    construct message [stringlit]
        _   [+ "[WARNING] This for loop can not be parallelized. A \""]
            [quote j]
            [+ "\" statement on line "]
            [quote ln]
            [+ " makes the block non-structured."]
            [print]
end function
