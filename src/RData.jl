__precompile__()

module RData

using DataFrames, DataArrays, CodecZlib, FileIO
import DataFrames: identifier
import FileIO: load

export
    sexp2julia,
    DictoVec,
    load, # export FileIO.load()
    readRDS

include("config.jl")
include("sxtypes.jl")

"""
Abstract RDA format IO stream wrapper.
"""
abstract type RDAIO end

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
## FileIO integration.
## supported `kwoptions`:
## convert::Bool (true by default) for converting R objects into Julia equivalents,
##               otherwise load() returns R internal representation (ROBJ-derived objects)
## TODO option for disabling names checking (e.g. column names)
##
##############################################################################

function decompress(io)
    # check GZip magic number
    gzipped = read(io, UInt8) == 0x1F && read(io, UInt8) == 0x8B
    seekstart(io)
    if gzipped
        io = GzipDecompressorStream(io)
    end
    return io
end

function load(f::File{format"RData"}; kwoptions...)
    io = open(filename(f), "r")
    try
        io = decompress(io)
        return load(Stream(f, io), kwoptions)
    catch
        rethrow()
    finally
        close(io)
    end
end

function load(s::Stream{format"RData"}, kwoptions::Vector{Any})
    io = stream(s)
    @assert FileIO.detect_rdata(io)
    ctx = RDAContext(rdaio(io, chomp(readline(io))), kwoptions)
    @assert ctx.fmtver == 2    # format version
#    println("Written by R version $(ctx.Rver)")
#    println("Minimal R version: $(ctx.Rmin)")

    convert2julia = get(ctx.kwdict,:convert,true)

    # top level read -- must be a paired list of objects
    # we read it here to be able to convert to julia objects inplace
    fl = readuint32(ctx.io)
    sxtype(fl) == LISTSXP || error("Top level R object is not a paired list")
    !hasattr(fl) || error("Top level R paired list should have no attributes")

    res = Dict{RString,Any}()
    while sxtype(fl) != NILVALUE_SXP
        hastag(fl) || error("Top level list element has no name")
        tag = readitem(ctx)
        obj_name = convert(RString, isa(tag, RSymbol) ? tag.displayname : "\0")
        obj = readitem(ctx)
        setindex!(res, (convert2julia ? sexp2julia(obj) : obj), obj_name)
        fl = readuint32(ctx.io)
        readattrs(ctx, fl)
    end

    return res
end

load(s::Stream{format"RData"}; kwoptions...) = load(s, kwoptions)


function load(f::File{format"RDataSingle"}; kwoptions...)
    io = open(filename(f), "r")
    try
        io = decompress(io)
        return load(Stream(f, io), kwoptions)
    catch
        rethrow()
    finally
        close(io)
    end
end

function load(s::Stream{format"RDataSingle"}, kwoptions::Vector{Any})
    io = stream(s)
    @assert FileIO.detect_rdata_single(io)
    ctx = RDAContext(rdaio(io, chomp(readline(io))), kwoptions)
    @assert ctx.fmtver == 2    # format version
    convert2julia = get(ctx.kwdict,:convert,true)
    return convert2julia ? sexp2julia(readitem(ctx)) : readitem(ctx)
end

load(s::Stream{format"RDataSingle"}; kwoptions...) = load(s, kwoptions)

end # module
