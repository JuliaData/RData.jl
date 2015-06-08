type ASCIIIO{T<:IO} <: RDAIO #  ASCII RData format IO stream wrapper
    sub::T              # underlying IO stream

    ASCIIIO( io::T ) = new( io )
end
ASCIIIO{T <: IO}(io::T) = ASCIIIO{T}(io)

readint32(io::ASCIIIO) = parse(Int32, readline(io.sub))
readuint32(io::ASCIIIO) = parse(UInt32, readline(io.sub))
readfloat64(io::ASCIIIO) = parse(Float64, readline(io.sub))

function readintorNA(io::ASCIIIO)
    str = chomp(readline(io.sub));
    str == R_NA_STRING ? R_NA_INT32 : parse(Int32, str)
end
readintorNA(io::ASCIIIO, n::RVecLength) = Int32[readintorNA(io) for i in 1:n]

function readfloatorNA(io::ASCIIIO)
    str = chomp(readline(io.sub));
    str == R_NA_STRING ? R_NA_FLOAT64 : parse(Float64, str)
end
readfloatorNA(io::ASCIIIO, n::RVecLength) = Float64[readfloatorNA(io) for i in 1:n]

readuint8(io::ASCIIIO, n::RVecLength) = UInt8[hex2bytes(chomp(readline(io.sub)))[1] for i in 1:n] # FIXME optimize for speed

function readnchars(io::ASCIIIO, n::Int32)  # reads N bytes-sized string
    if (n==-1) return "" end
    str = unescape_string(chomp(readline(io.sub)))
    length(str) == n || error("Character string length mismatch")
    convert(RString, str)
end
