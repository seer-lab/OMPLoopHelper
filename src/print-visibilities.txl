%_____________ Print visibility of variables in given loop _____________

function printVariableVisibilities iterator [declarator] ss [sub_statement]
    deconstruct iterator
        i [identifier]
    match $ [for_statement]
        fs [for_statement]

    construct pl [list identifier]
        i
    construct sl [list identifier]
        _
    export private_identifiers [list identifier]
        pl
    export shared_identifiers [list identifier]
        sl

    construct p1 [sub_statement]
        ss [buildPrivateList] [buildSharedList]
    
    construct m0 [stringlit]
        _ [+ "[INFO] Default OpenMP variable visibilities: "] [print]
    construct m1 [stringlit]
        _ [+ "       - Private variables: "] [quote private_identifiers] [print]
    construct m2 [stringlit]
        _ [+ "       - Shared variables: "] [quote shared_identifiers] [print]
    construct m [stringlit]
        _ [+ "       - iterator: "] [quote iterator] [printdb]
end function

rule buildPrivateList
    match $ [declarator]
        d [declarator]
    deconstruct d
        id [identifier]
    %construct m [stringlit]
    %    _ [+ "private: "] [quote id] [print]
    import private_identifiers [list identifier]
    where not
        private_identifiers [findId id]
    export private_identifiers
        private_identifiers [, id]
end rule

rule buildSharedList
    match $ [identifier]
        id [identifier]
    import private_identifiers [list identifier]
    import shared_identifiers [list identifier]
    where not
        private_identifiers [findId id]
    where not
        shared_identifiers [findId id]
    export shared_identifiers
        shared_identifiers [, id]
end rule

rule findId id [identifier]
    match $ [identifier]
        i [identifier]
    where
        i [= id]
end rule