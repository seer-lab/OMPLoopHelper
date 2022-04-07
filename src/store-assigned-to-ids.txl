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