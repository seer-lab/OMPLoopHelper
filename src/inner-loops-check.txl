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