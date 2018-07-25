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

function RDAContext(io::RDAIO, kwoptions::AbstractDict)
    fmtver = readuint32(io)
    rver = int2ver(readint32(io))
    rminver = int2ver(readint32(io))
    kwdict = Dict{Symbol,Any}(kwoptions)
    RDAContext(io, fmtver, rver, rminver, kwdict, RSEXPREC[])
end

function contextify(io::IO, fname::AbstractString, rdata::Bool=true, kwargs::AbstractDict=Dict{Symbol,Any}())
    sig = read(io, 2)
    seekstart(io)
                # create the appropriate decompressed stream
    st = sig == [0x1f,0x8b] ? GzipDecompressorStream(io) :
         sig == [0x42,0x5a] ? Bzip2DecompressorStream(io) :
         sig == [0xfd,0x37] ? XzDecompressorStream(io) : io
                # for RData format files, check the header
    !rdata || (m = match(r"^RD[A,B,X]2$", readline(st))) ≠ nothing ||
        throw(ArgumentError("File $fname not in .rda format"))
    ch = readline(st)
    ctx = RDAContext(ch == "X" ? XDRIO(st) : ch == "A" ? ASCIIIO(st) :
                     ch == "B" ? NativeIO(st) : error("Unrecognized code $ch"),
                     kwargs)
                     
    @assert ctx.fmtver == 2    # format version

    ctx
end

"""
    registerref!(ctx::RDAContext, obj::RSEXPEC)

Register a reference to `obj` in `ctx`, so that it could be referenced later
(by its index in the reference table).
"""
function registerref!(ctx::RDAContext, obj::RSEXPREC)
    push!(ctx.ref_tab, obj)
    obj
end
