"""
RDA (R data archive) reading context.

* Stores flags that define how R objects are read and converted into Julia objects.
* Maintains the list of R objects that could be referenced later in the RDA stream.
"""
struct RDAContext{T<:RDAIO}
    io::T                      # RDA input stream

    # RDA format properties
    fmtver::UInt32             # format version
    Rver::VersionNumber        # R version used to write the file
    Rmin::VersionNumber        # minimal R version to read the file

    kwdict::Dict{Symbol,Any}   # options defining RDA deserialization behaviour

    # intermediate data
    ref_tab::Vector{RSEXPREC}  # SEXP array for references
end

int2ver(v::Integer) = VersionNumber(v >> 16, (v >> 8) & 0xff, v & 0xff)

function RDAContext(io::RDAIO; kwoptions...)
    fmtver = readuint32(io)
    rver = int2ver(readint32(io))
    rminver = int2ver(readint32(io))
    kwdict = Dict{Symbol,Any}(kwoptions)
    RDAContext(io, fmtver, rver, rminver, kwdict, RSEXPREC[])
end

"""
Register R object, so that it could be referenced later
(by its index in the reference table).
"""
function registerref!(ctx::RDAContext, obj::RSEXPREC)
    push!(ctx.ref_tab, obj)
    obj
end
