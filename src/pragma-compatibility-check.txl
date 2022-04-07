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