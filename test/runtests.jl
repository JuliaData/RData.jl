using RData
using Test

generate_data_rscript = joinpath(dirname(@__FILE__),"generate_rda.R")
run(Cmd(["Rscript","--default-packages=methods,compiler",generate_data_rscript]))
include("RDA.jl")
include("RDS.jl")
