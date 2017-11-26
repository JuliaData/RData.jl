"""
Native binary RData format IO stream wrapper.

TODO write readers
"""
struct NativeIO{T<:IO} <: RDAIO
    sub::T               # underlying IO stream

    NativeIO(io::T) where {T<:IO} = new{T}(io)
end
