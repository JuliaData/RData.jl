module RData

using Compat, DataFrames, DataFrames.identifier, GZip
import DataArrays.data, Base.convert

include("sxtags.jl")
include("constants.jl")

# abstract RDA format IO stream wrapper
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

typealias Hash Dict{String, Any}
const nullhash = Hash()

include("sxtypes.jl")
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
    return readnamedobjects(ctx, 0x00000200)
end

read_rda(io::IO; kwoptions...) = read_rda(io, kwoptions)

read_rda(fnm::String; kwoptions...) = gzopen(fnm) do io read_rda(io, kwoptions) end

export read_rda

end # module
