type XDRIO{T<:IO} <: RDAIO #  XDR(binary) RData format IO stream wrapper
    sub::T             # underlying IO stream
    buf::Vector{UInt8} # buffer for strings

    XDRIO( io::T ) = new( io, Array(UInt8, 1024) )
end
XDRIO{T <: IO}(io::T) = XDRIO{T}(io)

readint32(io::XDRIO) = ntoh(read(io.sub, Int32))
readuint32(io::XDRIO) = ntoh(read(io.sub, UInt32))
readfloat64(io::XDRIO) = ntoh(read(io.sub, Float64))

readintorNA(io::XDRIO) = readint32(io)
readintorNA(io::XDRIO, n::RVecLength) = map!(ntoh, read(io.sub, Int32, n))

readfloatorNA(io::XDRIO) = readfloat64(io)
readfloatorNA(io::XDRIO, n::RVecLength) = map!(ntoh, read(io.sub, Float64, n))

readuint8(io::XDRIO, n::RVecLength) = readbytes(io.sub, n)

function readnchars(io::XDRIO, n::Int32)  # a single character string
    readbytes!(io.sub, io.buf, n)
    bytestring(pointer(io.buf), n)::String
end
