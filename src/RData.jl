module RData

using Compat, DataFrames, GZip, FileIO
import DataArrays: data
import DataFrames: identifier
import Compat: UTF8String, unsafe_string
import FileIO: load

export
    sexp2julia,
    DictoVec,
    load # export FileIO.load()

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

##############################################################################
##
## FileIO integration
##
##############################################################################

# test for RD?2 magic sequence at the beginning of R data input stream
function detect_rdata(io)
    read(io, UInt8) == UInt8('R') &&
    read(io, UInt8) == UInt8('D') &&
    (fmt = read(io, UInt8); fmt == UInt8('A') || fmt == UInt8('B') || fmt == UInt8('X')) &&
    read(io, UInt8) == UInt8('2') &&
    read(io, UInt8) == 0x0A
end

add_format(format"RData", detect_rdata, [".rdata", ".rda"], [:RData])

function load(f::File{format"RData"}; kwoptions...)
    gzopen(filename(f)) do s
        load(Stream(f, s), kwoptions)
    end
end

function load(s::Stream{format"RData"}, kwoptions::Vector{Any})
    io = stream(s)
    @assert detect_rdata(io)
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

load(s::Stream{format"RData"}; kwoptions...) = load(s, kwoptions)

end # module
