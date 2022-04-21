%_____________ check for memory conflict _____________

function checkTheresNoMemoryConflict
    match $ [sub_statement]
        ss [sub_statement]

    construct ss1 [sub_statement]
        ss [checkAssignmentForMemoryConflict]

    % check memory conflict flag
    %import loopHasMemoryConflict [number]
    %where not
    %    loopHasMemoryConflict [= 1]

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
    export printLoopInfo [number]
        0
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

function printNoMemoryProblemMessage
    import printLoopInfo [number]
    import loopHasMemoryConflict [number]
    match [repeat any]
        a [repeat any]
    where
        printLoopInfo [= 1]
    where
        loopHasMemoryConflict [= 0]
    construct m [repeat any]
        _ [message "[INFO] No parallelization problems found with this loop."]
end function