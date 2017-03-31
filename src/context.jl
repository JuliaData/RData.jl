"""
    RDA (R data archive) reading context.

* Stores flags that define how R objects are read and converted into Julia objects.
* Maintains the list of R objects that could be referenced later in the RDA stream.
"""
type RDAContext{T<:RDAIO}
    io::T                      # RDA input stream

    # RDA format properties
    fmtver::Int32             # format version
    Rver::VersionNumber        # R version used to write the file
    Rmin::VersionNumber        # minimal R version to read the file

    kwdict::Dict{Symbol,Any}   # options defining RDA deserialization behaviour

    # intermediate data
    ref_tab::Vector{RSEXPREC}  # SEXP array for references
end
function RDAContext{T<:RDAIO}(io::T, kwoptions::Vector{Any}=Any[])
  fmtver = readint32(io)
  rver = readint32(io)
  rminver = readint32(io)
  kwdict = Dict{Symbol,Any}(kwoptions)
  RDAContext(io,
      fmtver,
      VersionNumber(div(rver,65536), div(rver%65536, 256), rver%256),
      VersionNumber(div(rminver,65536), div(rminver%65536, 256), rminver%256),
      kwdict,
      RSEXPREC[])
end

"""
    Registers R object, so that it could be referenced later
    (by its index in the reference table).
"""
function registerref(ctx::RDAContext, obj::RSEXPREC)
    push!(ctx.ref_tab, obj)
    obj
end
