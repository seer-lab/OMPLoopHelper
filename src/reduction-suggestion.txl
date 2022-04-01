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

% TODO: test
rule idInList id [identifier]
    match [identifier]
        id
    %match [list identifier]
    %    l [list identifier]
    %deconstruct * l
    %    id
    %construct m [stringlit]
    %    _ [+ "here, id= "] [quote id] [+ "| list= "] [quote l] [print]
    %where
    %    list_id [= id]
    %construct m1 [stringlit]
    %    _ [+ "here1, id= "] [quote id] [print]
end rule

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