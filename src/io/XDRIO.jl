"""
    XDR (machine-independent binary) RData format IO stream wrapper.
"""
type XDRIO{T<:IO} <: RDAIO
    sub::T             # underlying IO stream
    buf::Vector{UInt8} # buffer for strings
    @compat (::Type{XDRIO}){T <: IO}(io::T) = new{T}(io, Array{UInt8}(1024))
end

readint32(io::XDRIO) = ntoh(read(io.sub, Int32))
readuint32(io::XDRIO) = ntoh(read(io.sub, UInt32))
readfloat64(io::XDRIO) = reinterpret(Float64, ntoh(read(io.sub, Int64)))

readintorNA(io::XDRIO) = readint32(io)
readintorNA(io::XDRIO, n::RVecLength) = [readint32(io) for _ in 1:n]

# this method have Win32 ABI issues, see JuliaStats/RData.jl#5
# R's NA is silently converted to NaN when the value is loaded in the register(?)
#readfloatorNA(io::XDRIO) = readfloat64(io)

readfloatorNA(io::XDRIO, n::RVecLength) = [readfloat64(io) for _ in 1:n]

readuint8(io::XDRIO, n::RVecLength) = readbytes(io.sub, n)

function readnchars(io::XDRIO, n::Int32)  # a single character string
    readbytes!(io.sub, io.buf, n)
    convert(RString, unsafe_string(pointer(io.buf), n))
end
