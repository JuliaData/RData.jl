"""
XDR (machine-independent binary) RData format IO stream wrapper.
"""
struct XDRIO{T<:IO} <: RDAIO
    sub::T             # underlying IO stream
    buf::Vector{UInt8} # buffer for strings

    XDRIO(io::T) where {T <: IO} = new{T}(io, Vector{UInt8}(1024))
end

readint32(io::XDRIO) = ntoh(read(io.sub, Int32))
readuint32(io::XDRIO) = ntoh(read(io.sub, UInt32))
readfloat64(io::XDRIO) = ntoh(read(io.sub, Float64))

readintorNA(io::XDRIO) = readint32(io)
function readintorNA(io::XDRIO, n::RVecLength)
    v = read(io.sub, Int32, n)
    map!(ntoh, v, v)
end

# this method have Win32 ABI issues, see JuliaStats/RData.jl#5
# R's NA is silently converted to NaN when the value is loaded in the register(?)
#readfloatorNA(io::XDRIO) = readfloat64(io)
function readfloatorNA(io::XDRIO, n::RVecLength)
    v = read(io.sub, Float64, n)
    map!(ntoh, v, v)
end

readuint8(io::XDRIO, n::RVecLength) = read(io.sub, UInt8, n)

function readnchars(io::XDRIO, n::Int32)  # a single character string
    readbytes!(io.sub, io.buf, n)
    convert(RString, unsafe_string(pointer(io.buf), n))
end
