%_____________ check if subscope is compatible with pragmas _____________

% check if sub scope is compatible for pragmas/parallelization
function subScopeNotCompatible
    match [sub_statement]
        ss [sub_statement]
    where
        ss  [jumpStatementInLoop]
            [breakStatementInLoop]
end function

% determine if line violates structured-block condition
rule jumpStatementInLoop
    match $ [block_item]
        ln [srclinenumber] j [jump_statement] s [semi]
    where
        j   [isReturn]
            [isGoto]
    construct message [stringlit]
        _   [+ "[WARNING] This for loop can not be parallelized. A \""]
            [quote j]
            [+ "\" statement on line "]
            [quote ln]
            [+ " makes the block non-structured."]
            [print]
end rule

function isReturn
    match [jump_statement]
        r [return_statement]
end function

function isGoto
    match [jump_statement]
        g [goto_statement]
end function

rule breakStatementInLoop
    skipping [break_sensitive_statements]
    match $ [block_item]
        ln [srclinenumber] j [jump_statement] s [semi]
    deconstruct j
        b [break_statement]
    construct message [stringlit]
        _   [+ "[WARNING] This for loop can not be parallelized. A \""]
            [quote b]
            [+ "\" statement on line "]
            [quote ln]
            [+ " makes the block non-structured."]
            [print]
end rule