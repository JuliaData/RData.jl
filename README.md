# RData.jl

[![CI](https://github.com/JuliaData/RData.jl/workflows/CI/badge.svg)](https://github.com/JuliaData/RData.jl/actions?query=workflow%3ACI+branch%3Amain)
[![codecov](https://codecov.io/gh/JuliaData/RData.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaData/RData.jl)
[![deps](https://juliahub.com/docs/RData/deps.svg)](https://juliahub.com/ui/Packages/RData/idMMA?t=2)
[![version](https://juliahub.com/docs/RData/version.svg)](https://juliahub.com/ui/Packages/RData/idMMA)
[![pkgeval](https://juliahub.com/docs/RData/pkgeval.svg)](https://juliahub.com/ui/Packages/RData/idMMA)

Read R data files (.rda, .RData) and optionally convert the contents into Julia equivalents.

Can read any R data archive, although not all R types could be converted into Julia.

For running R code from Julia see [RCall.jl](https://github.com/JuliaInterop/RCall.jl).

## Installation

From Julia REPL:
```julia
Pkg.add("RData")
```

### Compression formats

R data files could be compressed by either *Gzip* (the default), *Bzip2* or *Xz* methods. `RData.jl` supports *Gzip*-compressed files out-of-the-box. To read *Bzip2* or *Xz*-compressed files [CodecBzip2.jl](https://github.com/bicycle1885/CodecBzip2.jl) or [CodecXz.jl](https://github.com/bicycle1885/CodecXz.jl) must be installed.

For example, to load a file compressed by *Bzip2* you must first install the required codec:

```julia
Pkg.add("CodecBzip2")
```

Then ensure *CodecBzip2* is loaded before calling *RData.load*:

```julia
using RData
import CodecBzip2

load('some_bzip2_compressed.rda')
```

## Usage

To read R objects from "example.rda" file:
```julia
using RData

objs = load("path_to/example.rda")
```

The result is a dictionary (`Dict{String, Any}`) of all R objects stored in "example.rda".

Unless the `convert=false` keyword option is specified, `load()` will try to automatically
convert R objects into Julia equivalents:

| R object     | Julia object           |  |
|--------------|------------------------|--|
| named vector, list | `DictoVec` | `DictoVec` allows indexing both by element index and by its name, just as R vectors and lists |
| vector    | `Vector{T}` | `T` is the appropriate Julia type. If R vector contains `NA` values, they are converted to [`missing`](https://github.com/JuliaData/Missings.jl), and the elements type of the resulting `Vector` is `Union{T, Missing}`.
| factor     | `CategoricalArray` | [CategoricalArrays.jl](https://github.com/JuliaData/CategoricalArrays.jl) |
| `Date`     | `Dates.Date` | |
| `POSIXct` date time | `ZonedDateTime` | [TimeZones.jl](https://github.com/JuliaTime/TimeZones.jl) |
| data frame | `DataFrame` | [DataFrames.jl](https://github.com/JuliaData/DataFrames.jl) |
| `compact_xxxseq` | `UnitRange`/`StepRange` | |

If conversion to the Julia type is not supported (e.g. R closure or language expression), `load()` will return the internal RData representation of the object (`RSEXPREC` subtype).
