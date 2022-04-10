%_____________ check if for loop is nested and can be collapsed _____________
function canBeCollapsed
    match $ [sub_statement]
        ss [sub_statement]
    where
        ss [containsForLoop]
    %construct m [stringlit]
    %    _ [+ " * contains for loop"] [print]
    %where not
    %    b [containsDoubleForLoop]
    
    %where
    %    ss [containsOneForLoop]
    where not
        ss [containsNonForLoop]

    %construct m0 [stringlit]
    %    _ [+ " * doesn't contain non-for-loop"] [print]
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
    match $ [for_statement]
        fs [for_statement]
    construct m0 [for_statement]
        fs [checkNestedForLoopForCollapse]
end rule

%rule containsDoubleForLoop
%    match $ [repeat block_item]
%        fs0 [comment_for]
%        fs1 [comment_for]
%end rule

function checkNestedForLoopForCollapse
    match [for_statement]
        fs [for_statement]
    deconstruct fs
        'for '( nnd [opt non_null_declaration] el1 [opt expression_list] '; el2 [opt expression_list] soel [opt semi_opt_expression_list] ') ss [sub_statement]
    construct rbi [sub_statement]
        ss [canBeCollapsed]
end function

function containsNonForLoop
    match $ [sub_statement]
        ss [sub_statement]
    where all
        ss  [checkForNonForLoop]
            [checkForNonForLoopSingleLine]
    construct cantBeCollapsedMessage [repeat any]
        _ [messagev "[INFO] This for loop cannot use the collapse construct without refactoring."]
end function

rule checkForNonForLoop
    % ignore nested loop's inner scope
    skipping [sub_statement]
    match $ [block_item]
        ln [srclinenumber] ds [declaration_or_statement]
    where not
        ds [isForLoop]
    %where not
    %    ds [containsComment]
end rule

rule checkForNonForLoopSingleLine
    match $ [sub_statement]
        ss [sub_statement]
    where not
        ss [isForLoop]
end rule

function isForLoop
    match $ [for_statement]
        fs [for_statement]
end function

%function containsComment
%    match $ [declaration_or_statement]
%        c [comment]
%end function