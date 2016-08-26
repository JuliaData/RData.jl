"""
    XDR (machine-independent binary) RData format IO stream wrapper.
"""
type XDRIO{T<:IO} <: RDAIO
    sub::T             # underlying IO stream
    buf::Vector{UInt8} # buffer for strings

    XDRIO(io::T) = new(io, Array(UInt8, 1024))
    @compat (::Type{XDRIO}){T <: IO}(io::T) = new{T}(io, Array(UInt8, 1024))
end

readint32(io::XDRIO) = ntoh(read(io.sub, Int32))
readuint32(io::XDRIO) = ntoh(read(io.sub, UInt32))
readfloat64(io::XDRIO) = ntoh(read(io.sub, Float64))

readintorNA(io::XDRIO) = readint32(io)
readintorNA(io::XDRIO, n::RVecLength) = map!(ntoh, read(io.sub, Int32, n))

# this method have Win32 ABI issues, see JuliaStats/RData.jl#5
# R's NA is silently converted to NaN when the value is loaded in the register(?)
#readfloatorNA(io::XDRIO) = readfloat64(io)

readfloatorNA(io::XDRIO, n::RVecLength) = reinterpret(Float64, map!(ntoh, read(io.sub, UInt64, n)))

readuint8(io::XDRIO, n::RVecLength) = readbytes(io.sub, n)

function readnchars(io::XDRIO, n::Int32)  # a single character string
    readbytes!(io.sub, io.buf, n)
    convert(RString, unsafe_string(pointer(io.buf), n))
end
