module RData

using DataAPI, DataFrames, CategoricalArrays, FileIO, TimeZones, Unicode

export
    sexp2julia,
    DictoVec,
    RDataException,
    UnsupportedROBJ,
    CodecMissingError,
    load # reexport FileIO.load()

include("config.jl")
include("sxtypes.jl")

"""
Abstract RDA format IO stream wrapper.
"""
abstract type RDAIO end

include("errors.jl")

include("io/XDRIO.jl")
include("io/ASCIIIO.jl")
include("io/NativeIO.jl")
include("io/utils.jl")

include("DictoVec.jl")
include("identifier.jl")
include("convert.jl")

include("context.jl")
include("readers.jl")

include("decompression.jl")

function __init__()
    define_optional_decompressor_streams()
end

##############################################################################
##
## FileIO integration.
## supported `kwoptions`:
## convert::Bool (true by default) for converting R objects into Julia equivalents,
##               otherwise load() returns R internal representation (ROBJ-derived objects)
## metadata::Bool (true by default) for importing R attributes into metadata
##                (only has an effect for data frames currently)
## TODO option for disabling names checking (e.g. column names)
##
##############################################################################

function fileio_load(s::Stream{F}; kwoptions...) where {F<:Union{format"RData", format"RDataSingle"}}
    input = stream(s)
    io = decompress(input)
    try
        # Anonymous compressed inputs need their decoded header to distinguish RDA from RDS.
        input_format = if io !== input && filename(s) === nothing
            seekstart(io)
            read(io, UInt8) == UInt8('R') ? format"RData" : format"RDataSingle"
        else
            F
        end
        return read_rdata(Stream{input_format}(io); kwoptions...)
    finally
        io === input || close(io)
    end
end

function read_rdata(s::Stream{format"RData"}; kwoptions...)
    io = stream(s)
    @assert FileIO.detect_rdata(io)
    ctx = RDAContext(rdaio(io, chomp(readline(io))); kwoptions...)
    @assert ctx.fmtver == 2 || ctx.fmtver == 3  # supported format versions
    @debug "written by R version $(ctx.Rver)"
    @debug "minimal R version: $(ctx.Rmin)"

    convert2julia = get(ctx.kwdict, :convert, true)
    metadata = get(ctx.kwdict, :metadata, true)

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
        setindex!(res, (convert2julia ? sexp2julia(obj, metadata=metadata) : obj), obj_name)
        fl = readuint32(ctx.io)
        readattrs(ctx, fl)
    end

    return res
end

function read_rdata(s::Stream{format"RDataSingle"}; kwoptions...)
    io = stream(s)
    @assert FileIO.detect_rdata_single(io)
    ctx = RDAContext(rdaio(io, chomp(readline(io))); kwoptions...)
    @assert ctx.fmtver == 2 || ctx.fmtver == 3  # supported format versions
    convert2julia = get(ctx.kwdict, :convert, true)
    metadata = get(ctx.kwdict, :metadata, true)
    return convert2julia ? sexp2julia(readitem(ctx), metadata=metadata) : readitem(ctx)
end

function fileio_load(f::Union{File{format"RData"}, File{format"RDataSingle"}};
                     kwoptions...)
    io = open(filename(f), "r")
    try
        return fileio_load(Stream(f, io); kwoptions...)
    finally
        close(io)
    end
end

end # module
