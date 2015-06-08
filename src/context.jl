type RDAContext{T <: RDAIO}    # RDA reading context
    io::T                      # R input stream

    # RDA properties
    fmtver::UInt32             # RDA format version
    Rver::VersionNumber        # R version that has written RDA
    Rmin::VersionNumber        # R minimal version to read RDA

    # behaviour
    convertdataframes::Bool    # if R dataframe objects should be automatically converted into DataFrames

    # intermediate data
    ref_tab::Vector{RSEXPREC}  # SEXP array for references

    function RDAContext(io::T, kwoptions::Vector{Any})
        fmtver = readint32(io)
        rver = readint32(io)
        rminver = readint32(io)
        kwdict = Dict{Symbol,Any}(kwoptions)
        new(io,
            fmtver,
            VersionNumber( div(rver,65536), div(rver%65536, 256), rver%256 ),
            VersionNumber( div(rminver,65536), div(rminver%65536, 256), rminver%256 ),
            get(kwdict,:convertdataframes,false),
            RSEXPREC[])
    end
end

RDAContext{T <: RDAIO}(io::T, kwoptions::Vector{Any}) = RDAContext{T}(io, kwoptions)

function registerref(ctx::RDAContext, obj::RSEXPREC)
    push!(ctx.ref_tab, obj)
    obj
end
