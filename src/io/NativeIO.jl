type NativeIO{T<:IO} <: RDAIO # native binary RData format IO stream wrapper (TODO)
    sub::T               # underlying IO stream

    NativeIO(io::T) = new(io)
end
NativeIO{T <: IO}(io::T) = NativeIO{T}(io)

