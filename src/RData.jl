module RData

using Compat, DataFrames, GZip
import DataArrays: data
import DataFrames: identifier
import Compat: UTF8String, unsafe_string

export
    # read_rda,
    sexp2julia,
    DictoVec

include("config.jl")
include("sxtypes.jl")

"""
Abstract RDA format IO stream wrapper.
"""
abstract RDAIO

##############################################################################
##
## Utilities for reading a single data element.
## The read<type>orNA functions are needed because the ASCII format
## stores the NA as the string 'NA'.  Perhaps it would be easier to
## wrap the conversion in a try/catch block.
##
##############################################################################
include("io/XDRIO.jl")
include("io/ASCIIIO.jl")
include("io/NativeIO.jl")
include("io/utils.jl")

include("DictoVec.jl")
include("convert.jl")

include("context.jl")
include("readers.jl")

function read_rda(io::IO, kwoptions::Vector{Any})
    header = chomp(readline(io))
    @assert header[1] == 'R' # readable header (or RDX2)
    @assert header[2] == 'D'
    @assert header[4] == '2'
    ctx = RDAContext(rdaio(io, chomp(readline(io))), kwoptions)
    @assert ctx.fmtver == 2    # format version
#    println("Written by R version $(ctx.Rver)")
#    println("Minimal R version: $(ctx.Rmin)")

    convert2julia = get(ctx.kwdict,:convert,true)

    # top level read -- must be a paired list of objects
    # we read it here to be able to convert to julia objects inplace
    fl = readuint32(ctx.io)
    sxtype(fl) == LISTSXP || error( "Top level R object is not a paired list")
    !hasattr(fl) || error( "Top level R paired list should have no attributes" )

    res = Dict{RString,Any}()
    while sxtype(fl) != NILVALUE_SXP
        hastag(fl) || error( "Top level list element has no name")
        tag = readitem(ctx)
        obj_name = convert(RString, isa(tag, RSymbol) ? tag.displayname : "\0")
        obj = readitem(ctx)
        setindex!( res, (convert2julia ? sexp2julia(obj) : obj), obj_name )
        fl = readuint32(ctx.io)
        readattrs(ctx, fl)
    end

    return res
end

read_rda(io::IO; kwoptions...) = read_rda(io, kwoptions)

read_rda(fnm::AbstractString; kwoptions...) = gzopen(fnm) do io read_rda(io, kwoptions) end


end # module
