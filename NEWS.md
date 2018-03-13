## RData v0.4.0 Release Notes
##### Changes
* add support for rds files (single object data files from R) [#22], [#33]

[#22]: https://github.com/JuliaStats/RData.jl/issues/22
[#33]: https://github.com/JuliaStats/RData.jl/issues/33

## RData v0.3.0 Release Notes

Updated to DataFrames v0.11, switched from [DataArrays](https://github.com/JuliaData/DataArrays.jl) to [Missings](https://github.com/JuliaData/Missings.jl) and [CategoricalArrays](https://github.com/JuliaData/CategoricalArrays.jl).

##### Changes
* updated to DataFrames v0.11 [#28]
* switched from `DataVector` to `Vector{Union{T, Missing}}` for NAs [#28]
* R factors converted into `CategoricalVector` (instead of `PooledDataArray`) [#28]

[#28]: https://github.com/JuliaData/RData.jl/issues/28

## RData v0.2.0 Release Notes

Updated to Julia v0.6 (older versions not supported).

##### Changes
* R logical vectors are converted to `DataVector{Bool}` (instead of `DataVector{Int32}`) [#32]
* dropped compatibility with Julia versions prior v0.6 [#32]
* use CodecZlib for gzipped RData files (instead of outdated GZip) [#31]

[#31]: https://github.com/JuliaData/RData.jl/issues/31
[#32]: https://github.com/JuliaData/RData.jl/issues/32

## RData v0.1.0 Release Notes

Support Julia v0.6

##### Changes
* suppress warnings on Julia v0.6 [#26]

[#26]: https://github.com/JuliaData/RData.jl/issues/26

## RData v0.0.4 Release Notes

Now the recommended way to load `.RData`/`.rda` files is by `FileIO.load()`.

##### Changes
* FileIO.jl integration ([#6], [#15])
* Enable precompilation ([#9])
* Fix numeric NA detection ([#10])

## RData v0.0.1 Release Notes

Initial release based on `DataFrames.read_rda()` ([JuliaData/DataFrames.jl#1031]).

[#6]: https://github.com/JuliaData/RData.jl/issues/6
[#9]: https://github.com/JuliaData/RData.jl/issues/9
[#10]: https://github.com/JuliaData/RData.jl/issues/10
[#15]: https://github.com/JuliaData/RData.jl/issues/15

[JuliaData/DataFrames.jl#1031]: https://github.com/JuliaData/DataFrames.jl/pull/1031
