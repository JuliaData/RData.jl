"""
    Native binary RData format IO stream wrapper.

    TODO write readers
"""
type NativeIO{T<:IO} <: RDAIO
    sub::T               # underlying IO stream

    NativeIO(io::T) = new(io)
end
NativeIO{T <: IO}(io::T) = NativeIO{T}(io)

