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