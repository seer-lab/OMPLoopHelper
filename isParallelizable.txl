% isParallelizable
% This program checks 4 steps to analyze each marked for loop for OpenMP parallelization compatibility
% 1. match for loop
% 2. check that loop is pragma-compatible (structured block)
% 3. check for collapse pragma compatibility
% 4. check for memory conflict with recursive method

% Usage instructions:
% 1. have c code, with at least one for loop
% 2. before the for loop you want to test, add this comment: //@omp-analysis=true
% 3. run                          : txl isParallelizable.txl [c code filepath] -comment
%   - without full program output : txl isParallelizable.txl [c code filepath] -comment -q -o /dev/null
%   - with debugging messages     : txl isParallelizable.txl [c code filepath] -comment -q -o /dev/null - -db 


%_____________ Include grammar definitions _____________
include "C18/c.grm"
include "C18/c-comments.grm"


%_____________ Define/redefine necessary patterns _____________

% define comment_for for easier parsing of for loops preceded by annotation
define comment_for
    [comment] [NL]
    [attr srclinenumber] [for_statement]
end redefine

redefine for_statement
    ...
    | [comment_for]
end redefine

redefine block_item
    [attr srclinenumber] [declaration_or_statement]
end redefine

define assignment_info
    [srclinenumber] [NL]            % line number
    [number] [NL]                   % index
    [identifier] [NL]               % assigned-to identifier
    [assignment_expression] [NL]    % assignment expression
    [repeat identifier] [NL]        % referenced identifiers
end define


%_____________ Debugging methods: print/message only if "-db" flag is given _____________
function printdb
    match [stringlit]
        s [stringlit]
    import TXLargs [repeat stringlit]
    deconstruct * TXLargs
        "-db"
        moreOptions [repeat stringlit]
    construct m1 [stringlit]
        s [print]
end function

function messagedb s [stringlit]
    replace [stringlit]
        s0 [stringlit]
    import TXLargs [repeat stringlit]
    deconstruct * TXLargs
        "-db"
        moreOptions [repeat stringlit]
    construct m1 [stringlit]
        s [print]
    by
        s0
end function


%_____________ Main: apply functions/rules to entire program _____________

function main
    replace [program]
        p [program]
    by
        p [checkForParallel]
end function


%_____________ Main parallelizable-check rule _____________

% check if for loop can be parallelized
rule checkForParallel

    % global vars used to check if referenced elements are assigned to
    export assignedToElements [repeat unary_expression]
        _
    export assignedToIdentifiers [repeat identifier]
        _
    export printedIdentifiers [repeat identifier]
        _
    export assignmentInfo [repeat assignment_info]
        _
    export assignmentInfoNum [number]
        1
    export checkAINum [number]
        0
    export loopHasMemoryConflict [number]
        0
    

    % match annotated for-loop
    replace $ [comment_for]
        cf [comment_for]
    deconstruct cf
        '//@omp-analysis=true
        ln [srclinenumber] f [for_statement]


    %
    construct m0 [stringlit]
        _ [+ "Analyzing for loop on line "] [quote ln] [+ ": "] [message ""] [print] [message f] [message ""]
    deconstruct f
        'for '( nnd [opt non_null_declaration] el1 [opt expression_list] '; el2 [opt expression_list] soel [opt semi_opt_expression_list] ') ss [sub_statement]
    % this deconstruction of substatement only works with 
    % block surrounded by { and }, not a single line for loop (TODO: support single-line-block for loops)
    deconstruct ss 
        '{ b [repeat block_item] '}
    where not
        b [subScopeNotCompatible]
    construct m1 [repeat any]
        _   [messagedb "Loop passed pragma compatibility test (step 2)"]
    

    % run collapse test - 
    construct collapseTest [repeat block_item]
        b [canBeCollapsed]

    
    % check for memory conflict
    construct m2 [repeat block_item]
        b [storeAssignedToElements]
    construct m3 [repeat any]
        _ [printAssignmentInfo] % print assigned to info in db mode
    where
        b [checkTheresNoMemoryConflict] %[isReferencedIdentifierAssignedTo]
    construct m4 [repeat any]
        _ [messagedb "Loop passed memory-conflic test (step 4)"]

%    where not
%        ss [referencedThenLaterAssigned]

    % print success message
    by
        cf [message "[INFO] No parallelization problems found with this loop."]
end rule


%_____________ check if for loop is nested and can be collapsed _____________
function canBeCollapsed
    match $ [repeat block_item]
        b [repeat block_item]
    where
        b [containsForLoop]
    where not
        b [containsNonForLoop]
    construct canBeCollapsedMessage [repeat any]
        _ [message "[SUGGESTION] Use the collapse construct when parallelizing this for loop."]
end function

rule containsForLoop
    match $ [declaration_or_statement]
        fs [for_statement]
end rule

function isForLoop
    match $ [declaration_or_statement]
        fs [for_statement]
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
    % ignore nested-loop inner-scope
    skipping [sub_statement]
    match $ [block_item]
        ln [srclinenumber] ds [declaration_or_statement]
    where not
        ds [isForLoop]
    where not
        ds [containsComment]
end rule

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

    construct m [stringlit]
        _ [+ "pass checkTheresNoMemoryConflict"] [printdb]

end function

% Check if assignment is the root of a memory conflict
rule checkAssignmentForMemoryConflict
    match $ [block_item]
        ln [srclinenumber] ds [declaration_or_statement]

    % import necessary global vars, print debug info
    import assignmentInfo [repeat assignment_info]
    import checkAINum [number]
    export checkAINum
        checkAINum [+ 1]

    % check that this block item is an assignment
    % TODO: simplify
    where
        assignmentInfo [assignmentInfoHasLineAndAINum ln checkAINum] 
    construct m0 [stringlit]
        _ [+ "line "] [quote ln] [+ " has an assignment: "] [quote ds] [printdb]


    % recursively check for memory conflict rooted in this line
    where not
        assignmentInfo [getAssignmentInfo ln ln checkAINum checkAINum]
    construct m1 [stringlit]
        _ [+ "no problem stemming from this line"] [printdb]
end rule

% check, given a repeat assignment_info, if it contains info for a specific assignment
rule assignmentInfoHasLineAndAINum ln [srclinenumber] n [number]
    match $ [assignment_info]
        ailn [srclinenumber]
        it [number]
        id [identifier]
        ae [assignment_expression]
        ri [repeat identifier]
    where
        ailn [= ln]
    where
        it [= n]
end rule

% 
rule getAssignmentInfo ln [srclinenumber] rootln [srclinenumber] it [number] rootIt [number]
    construct message1 [stringlit]
        _ [+ "       - in  getAssignmentInfo it="] [quote it] [printdb]

    % match assignment_info for given assignment (ln/it)
    match [assignment_info]
        ai [assignment_info]
    deconstruct ai
        ailn [srclinenumber]
        aiit [number]
        id [identifier]
        ae [assignment_expression]
        ri [repeat identifier]
    where
        ailn [= ln]
    where
        aiit [= it]

    % print each referenced var in assignment
    construct message2 [stringlit]
        _ [+ "       - references: "] [quote ri] [printdb]

    % check referenced variables
    where
        ri [traceBackRefdVarsNew rootln rootIt]
    
    construct message3 [stringlit]
        _ [+ " passed getAssignmentInfo"] [printdb]
end rule

% Check, for each given var, if 
rule traceBackRefdVarsNew rootln [srclinenumber] rootIt [number]
    match $ [identifier]
        id [identifier]
    import assignmentInfo [repeat assignment_info]
    where not
        assignmentInfo [lineAssignsToId id rootln rootIt]
end rule

% idIsAssignedTo?
% match assignment_info where given id is assigned to
% then ... TODO
rule lineAssignsToId id [identifier] rootln [srclinenumber] rootIt  [number]

    % match assignment where given id is assigned to
    match $ [assignment_info]
        ai [assignment_info]
    deconstruct ai
        ln   [srclinenumber]
        it   [number]
        aiid [identifier]
        ae   [assignment_expression]
        ri   [repeat identifier]
    where
        aiid [= id]
    construct m0 [stringlit]
        _ [+ " - found line where id "] [quote id] [+ " is assigned to. tracing:"] [printdb]

    % if there is no later assign ...
    where not
        ai [checkIfAssignAfter rootln aiid it rootIt]
    
    % ... then recursively go back to check ... TODO
    import assignmentInfo [repeat assignment_info]
    construct m2 [repeat assignment_info]
        assignmentInfo [getAssignmentInfo ln rootln it rootIt]
end rule

% Given an id and an index, check if there is an operation later than the index which assigns to that id
function checkIfAssignAfter rootln [srclinenumber] id [identifier] it [number] rootIt [number]
    match $ [assignment_info]
        ln   [srclinenumber]
        aiit   [number]
        aiid [identifier]
        ae   [assignment_expression]
        ri   [repeat identifier]
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
rule isEarlierAssignment rootln [srclinenumber] id [identifier] it [number] rootIt [number]
    match $ [assignment_info]
        ln   [srclinenumber]
        aiit [number]
        aiid [identifier]
        ae   [assignment_expression]
        ri   [repeat identifier]
    where
        aiit [< rootIt] % it or rootIt???
    where
        aiid [= id]
end rule


%_____________ Check referenced (Old memory-conflict detection) _____________

% check block for referenced elements which are assigned to
function isReferencedIdentifierAssignedTo
    skipping [subscript_extension]
    match $ [repeat block_item]
        b [repeat block_item]
    where
        b   [isAssignedTo]
            [isAssignedTo_AssignmentReference]
end function

% subrule: check for referenced elements which are assigned to in block
rule isAssignedTo
    match $ [block_item]
        ln [srclinenumber] ds [declaration_or_statement]
    deconstruct not ds % assignment expressions are checked in other subrule
        ce [conditional_expression] aae [assign_assignment_expression] ';
    where all
        ds [identifierIsAssignedTo]
end rule

% subrule: check assignment expressions for referenced elements which are assigned to
rule isAssignedTo_AssignmentReference
    skipping [subscript_extension]
    match $ [assignment_expression]
        ae [assignment_expression]
    deconstruct ae
        ce [conditional_expression] aae [assign_assignment_expression]
    where
        aae [identifierIsAssignedTo] %[elementIsAssignedTo]
    %construct message [stringlit]
    %    _ [+ "    on line: "] [quote ae] [print] [message ""] [message ""]
end rule

% check if element is in list of unary expressions
rule elementIsAssignedTo
    import assignedToElements [repeat unary_expression]
    match $ [unary_expression]
        e [unary_expression]
    where
        assignedToElements [isInRepeat e]
end rule

rule isInRepeat e [unary_expression]
    skipping [unary_expression] % so expressions like a[i] don't match i
    match * [unary_expression]
        e1 [unary_expression]
    where
        e1 [= e]
end rule

rule identifierIsAssignedTo
    import assignedToIdentifiers [repeat identifier]
    import printedIdentifiers [repeat identifier]
    match $ [identifier]
        id [identifier]
    where
        assignedToIdentifiers [isInRepeatID id]
    % don't match if this id has already been caught
    where not
        printedIdentifiers [isInRepeatID id]
    export printedIdentifiers
        printedIdentifiers [. id]
    %construct message [stringlit]
    %    _ [quote printedIdentifiers] [print]
    construct message [stringlit]
        _   [+ "[WARNING] This loop may need to be refactored before being parallelized. A location is written to and read in different iterations: "] 
            [quote id]
            [print]
end rule

rule isInRepeatID id [identifier]
    match * [identifier]
        id1 [identifier]
    where
        id1 [= id]
end rule
    


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
    %construct assignedToIds [repeat identifier]
    deconstruct ue
        pe [primary_expression] pte [repeat postfix_extension]
    deconstruct pe
        assignedToID [identifier]

    import assignmentInfoNum [number]

    % add assignment info to list
    construct rid [repeat identifier]
        _
    construct ai [assignment_info]
        ln
        assignmentInfoNum
        assignedToID
        ae
        rid
    import assignmentInfo [repeat assignment_info]
    export assignmentInfoNum
        assignmentInfoNum [+ 1]
    export assignmentInfo
        assignmentInfo [. ai]

    % add all referenced ID's
    construct m [assign_assignment_expression]
        aae [findIDs ai ln]

    import assignmentInfo
    %construct m1 [stringlit]
    %    _ [quote assignmentInfo] [printdb]
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
    %construct message [stringlit]
    %    _ [quote ai] [printdb]
end rule

rule findIDs ai [assignment_info] ln [srclinenumber]
    match $ [identifier]
        id [identifier]
    import assignmentInfo [repeat assignment_info]
    export assignmentInfo
        assignmentInfo [addRefdID id ln]
end rule

rule addRefdID id [identifier] ln [srclinenumber]
    replace $ [assignment_info]
        ai [assignment_info]
    deconstruct ai
        lnr [srclinenumber]
        it [number]
        idr [identifier]
        aer [assignment_expression]
        ridr [repeat identifier]
    where
        lnr [= ln]
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
    %construct message1 [stringlit]
    %    _ [+ "    found assigned-to element: "] [quote newEntry] [print]
    construct newAssignedToElements [repeat unary_expression]
        assignedToElements [. newEntry]
    construct none [unary_expression]
        newEntry [addAssignedToIdentifier]
    export assignedToElements
        newAssignedToElements
end function

function addAssignedToIdentifier
    import assignedToIdentifiers [repeat identifier]
    match [unary_expression]
        pe [primary_expression] pte [repeat postfix_extension]
    deconstruct pe
        newEntry [identifier]
    %construct message1 [stringlit]
    %    _ [+ "    found assigned-to identifier: "] [quote newEntry] [print]
    export assignedToIdentifiers
        assignedToIdentifiers [. newEntry]
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
