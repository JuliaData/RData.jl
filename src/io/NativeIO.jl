"""
Native binary RData format IO stream wrapper.

TODO write readers
"""
struct NativeIO{T<:IO} <: RDAIO
    sub::T               # underlying IO stream
    (::Type{NativeIO})(io::T) where {T<:IO} = new{T}(io)
end
