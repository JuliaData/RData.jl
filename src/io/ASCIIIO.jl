"""
ASCII RData format IO stream wrapper.
"""
struct ASCIIIO{T<:IO} <: RDAIO
    sub::T              # underlying IO stream

    ASCIIIO(io::T) where {T<:IO} = new{T}(io)
end

readint32(io::ASCIIIO) = parse(Int32, readline(io.sub))
readuint32(io::ASCIIIO) = parse(UInt32, readline(io.sub))
readfloat64(io::ASCIIIO) = parse(Float64, readline(io.sub))

function readintorNA(io::ASCIIIO)
    str = chomp(readline(io.sub));
    str == R_NA_STRING ? R_NA_INT32 : parse(Int32, str)
end
readintorNA(io::ASCIIIO, n::RVecLength) = Int32[readintorNA(io) for i in 1:n]

# this method have Win32 ABI issues, see JuliaData/RData.jl#5
# R's NA is silently converted to NaN when the value is loaded in the register(?)
#function readfloatorNA(io::ASCIIIO)
#    str = chomp(readline(io.sub));
#    str == R_NA_STRING ? R_NA_FLOAT64 : parse(Float64, str)
#end

function readfloatorNA!(io::ASCIIIO, v::AbstractVector{Float64})
    v_uint = reinterpret(UInt64, v) # alias of res for setting NA
    @inbounds for i in eachindex(v)
        str = chomp(readline(io.sub))
        if str != R_NA_STRING
            v[i] = parse(Float64, str)
        else
            v_uint[i] = R_NA_FLOAT64 # see JuliaData/RData.jl#5
        end
    end
    v
end

readfloatorNA(io::ASCIIIO, n::RVecLength) = readfloatorNA!(io, Vector{Float64}(undef, n))

readuint8(io::ASCIIIO, n::RVecLength) = UInt8[hex2bytes(chomp(readline(io.sub)))[1] for i in 1:n] # FIXME optimize for speed

function readnchars(io::ASCIIIO, n::Int32)  # reads N bytes-sized string
    if (n==-1) return "" end
    str = unescape_string(chomp(readline(io.sub)))
    length(str) == n || error("Character string length mismatch")
    convert(RString, str)
end
