%_____________ Generate suggested pragma parameters _____________
function generatePragma fs [for_statement]
    import collapse [number]

    match [repeat any]
        ra [repeat any]

    construct reduction [stringlit]
        _ [+ ""] [addReductionParameter]

    construct m0 [stringlit]
        _ [message "[SUGGESTION] Use these parameters:"] [+ "#pragma omp parallel for"] [addReductionParameter] [addCollapseParameter] [print] [message fs]
    %construct m1 [stringlit]
    %    _ [quote fs] [print]

    construct m2 [stringlit]
        _ [+ "collapse: "] [quote collapse] [printdb]

end function

function addReductionParameter
    replace [stringlit]
        sl [stringlit]
    construct reductionClauses [stringlit]
        _ [addAdditionReduction] [addSubtractionReduction] [addMultiplicationReduction]
    by
        sl [+ reductionClauses]
end function

function addAdditionReduction
    replace [stringlit]
        s [stringlit]
    import plusReductionIdentifiers [list identifier]
    deconstruct plusReductionIdentifiers % at least one id
        id [identifier] ', ids [list identifier]
    by
        s [+ " reduction(+:"] [quote plusReductionIdentifiers] [+ ")"]
end function

function addSubtractionReduction
    replace [stringlit]
        s [stringlit]
    import subReductionIdentifiers [list identifier]
    deconstruct subReductionIdentifiers % at least one id
        id [identifier] ', ids [list identifier]
    by
        s [+ " reduction(-:"] [quote subReductionIdentifiers] [+ ")"]
end function

function addMultiplicationReduction
    replace [stringlit]
        s [stringlit]
    import mulReductionIdentifiers [list identifier]
    deconstruct mulReductionIdentifiers % at least one id
        id [identifier] ', ids [list identifier]
    by
        s [+ " reduction(*:"] [quote mulReductionIdentifiers] [+ ")"]
end function

function addCollapseParameter
    replace [stringlit]
        sl [stringlit]
    import collapse [number]
    where
        collapse [> 0]
    construct collapseParameter [stringlit]
        _ [+ " collapse("] [quote collapse] [+ ")"]
    by
        sl [+ collapseParameter]
end function
