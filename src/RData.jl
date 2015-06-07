module RData

using Compat, DataFrames, DataFrames.identifier, GZip
import DataArrays.data, Base.convert

include("RDA.jl")

export read_rda

end # module
