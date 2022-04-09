
include "../C18/c.grm"
include "../C18/bom.grm"
include "../C18/c-comments.grm"

#pragma -comments

define comment_for
    [comment] [NL]
    [for_statement]
end redefine

define annotation_for
    '@omp-analysis=true [NL]
    [for_statement]
end define

redefine for_statement
    ...
    | [comment_for]
    | [annotation_for]
end redefine

function main
    replace [program]
        p [program]
    by
        p [uncomment_annotations]
end function

rule uncomment_annotations
    replace [for_statement]
        '//@omp-analysis=true
        fs [for_statement]
    by
        '@omp-analysis=true
        fs
end rule