# RESERVED_WORDS, identifier, makeidentifier were originally part of DataFrames v0.20
const RESERVED_WORDS = Set(["local", "global", "export", "let",
    "for", "struct", "while", "const", "continue", "import",
    "function", "if", "else", "try", "begin", "break", "catch",
    "return", "using", "baremodule", "macro", "finally",
    "module", "elseif", "end", "quote", "do"])

function identifier(s::AbstractString)
    s = Unicode.normalize(s)
    if !Base.isidentifier(s)
        s = makeidentifier(s)
    end
    Symbol(in(s, RESERVED_WORDS) ? "_"*s : s)
end

function makeidentifier(s::AbstractString)
    (iresult = iterate(s)) === nothing && return "x"

    res = IOBuffer(zeros(UInt8, sizeof(s)+1), write=true)

    (c, i) = iresult
    under = if Base.is_id_start_char(c)
        write(res, c)
        c == '_'
    elseif Base.is_id_char(c)
        write(res, 'x', c)
        false
    else
        write(res, '_')
        true
    end

    while (iresult = iterate(s, i)) !== nothing
        (c, i) = iresult
        if c != '_' && Base.is_id_char(c)
            write(res, c)
            under = false
        elseif !under
            write(res, '_')
            under = true
        end
    end

    return String(take!(res))
end
