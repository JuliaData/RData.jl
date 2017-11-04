# RData

[![Julia 0.6 Status](http://pkg.julialang.org/badges/RData_0.6.svg)](http://pkg.julialang.org/?pkg=RData&ver=0.6)

[![Coverage Status](https://coveralls.io/repos/github/JuliaStats/RData.jl/badge.svg)](https://coveralls.io/github/JuliaStats/RData.jl)
[![Build Status](https://travis-ci.org/JuliaStats/RData.jl.svg?branch=master)](https://travis-ci.org/JuliaStats/RData.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/github/JuliaStats/RData.jl?svg=true&branch=master)](https://ci.appveyor.com/project/alyst/rdata-jl/branch/master)

Read R data files (.rda, .RData) and optionally convert the contents into Julia equivalents.

Can read any R data archive, although not all R types could be converted into Julia.

Usage
-----

To read R objects from "example.rda" file:
```julia
using RData

objs = load("path_to/example.rda")
```

The result is a dictionary of all R objects that are stored in "example.rda".

If `convert=true` keyword option is specified, `load()` will try to automatically
convert R objects into Julia equivalents:
 * data frames into `DataFrames.DataFrame`
 * named vectors into `DictoVec` objects that allow indexing both by element indices and by names
 * ...

If the conversion to Julia type is not supported (e.g. R closure or language expression),
the internal RData representation of the object will be provided.
