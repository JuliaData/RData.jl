# RData.jl

[![Julia 0.6 Status](http://pkg.julialang.org/badges/RData_0.6.svg)](http://pkg.julialang.org/?pkg=RData&ver=0.6)
[![Julia 0.7 Status](http://pkg.julialang.org/badges/RData_0.7.svg)](http://pkg.julialang.org/?pkg=RData&ver=0.7)
[![Julia 1.0 Status](http://pkg.julialang.org/badges/RData_1.0.svg)](http://pkg.julialang.org/?pkg=RData&ver=1.0)

[![Coverage Status](https://coveralls.io/repos/github/JuliaData/RData.jl/badge.svg?branch=master)](https://coveralls.io/github/JuliaData/RData.jl?branch=master)
[![Build Status](https://travis-ci.org/JuliaData/RData.jl.svg?branch=master)](https://travis-ci.org/JuliaData/RData.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/kc2s5kmvyew4w8in/branch/master?svg=true)](https://ci.appveyor.com/project/alyst/rdata-jl/branch/master)

Read R data files (.rda, .RData) and optionally convert the contents into Julia equivalents.

Can read any R data archive, although not all R types could be converted into Julia.

For running R code from Julia see [RCall.jl](https://github.com/JuliaInterop/RCall.jl).

Installation
------------

From Julia REPL:
```julia
Pkg.add("RData")
```

Usage
-----

To read R objects from "example.rda" file:
```julia
using RData

objs = load("path_to/example.rda")
```

The result is a dictionary (`Dict{String, Any}`) of all R objects stored in "example.rda".

If `convert=true` keyword option is specified, `load()` will try to automatically
convert R objects into Julia equivalents:

| R object     | Julia object           |  |
|--------------|------------------------|--|
| named vector, list | `DictoVec` | `DictoVec` allows indexing both by element index and by its name, just as R vectors and lists |
| vector    | `Vector{T}` | `T` is the appropriate Julia type. If R vector contains `NA` values, they are converted to [`missing`](https://github.com/JuliaData/Missings.jl), and the elements type of the resulting `Vector` is `Union{T, Missing}`.
| factor     | `CategoricalArray` | [CategoricalArrays.jl](https://github.com/JuliaData/CategoricalArrays.jl) |
| `Date`     | `Dates.Date` | |
| `POSIXct` date time | `ZonedDateTime` | [TimeZones.jl](https://github.com/JuliaTime/TimeZones.jl) |
| data frame | `DataFrame` | [DataFrames.jl](https://github.com/JuliaData/DataFrames.jl) |

If conversion to the Julia type is not supported (e.g. R closure or language expression), `load()` will return the internal RData representation of the object (`RSEXPREC` subtype).
