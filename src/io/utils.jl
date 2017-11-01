"""
Creates `RDAIO` wrapper for `io` stream depending on its format
specified by `formatcode`.
"""
function rdaio(io::IO, formatcode::AbstractString)
    if formatcode == "X" XDRIO(io)
    elseif formatcode == "A" ASCIIIO(io)
    elseif formatcode == "B" NativeIO(io)
    else throw(ArgumentError("Unrecognized RDA format \"$formatcode\""))
    end
end

if LONG_VECTOR_SUPPORT
    # reads the length of any data vector from a stream
    # from R's serialize.c
    function readlength(io::RDAIO)
        len = convert(RVecLength, readint32(io))
        if (len < -1) error("negative serialized length for vector")
        elseif (len >= 0)
            return len
        else # big vectors, the next 2 ints encode the length
            len1, len2 = convert(RVecLength, readint32(io)), convert(RVecLength, readint32(io))
            # sanity check for now
            if (len1 > 65536) error("invalid upper part of serialized vector length") end
            return (len1 << 32) + len2
        end
    end
else
    # reads the length of any data vector from a stream
    # fails when long (> 2^31-1) vector encountered
    # from R's serialize.c
    function readlength(io::RDAIO)
        len = convert(RVecLength, readint32(io))
        if (len >= 0)
            return len
        elseif (len < -1)
            error("negative serialized length for vector")
        else
            error("negative serialized vector length:\nperhaps long vector from 64-bit version of R?")
        end
    end
end

struct CHARSXProps # RDA CHARSXP properties
    levs::UInt32       # level flags (encoding etc) TODO process
    nchar::Int32       # string length, -1 for NA strings
end

function readcharsxprops(io::RDAIO) # read character string encoding and length
    fl = readuint32(io)
    @assert sxtype(fl) == CHARSXP
    @assert !hasattr(fl)
### watch out for levs in here.  Generally it has the value 0x40 so that fl = 0x00040009 (262153)
### if levs == 0x00 then the next line should be -1 to indicate the NA_STRING
    CHARSXProps(fl >> 12, readint32(io))
end

function readcharacter(io::RDAIO)  # a single character string
    props = readcharsxprops(io)
    props.nchar==-1 ? "" : readnchars(io, props.nchar)
end

function readcharacter(io::RDAIO, n::RVecLength)  # a single character string
    res = fill("", n)
    na = falses(n)
    for i in 1:n
        props = readcharsxprops(io)
        if (props.nchar==-1) na[i] = true
        else res[i] = readnchars(io, props.nchar)
        end
    end
    return res, na
end
