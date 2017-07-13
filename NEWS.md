## RData v0.1.0 Release Notes

Switched from `DataFrames` to `DataTables`, dropped Julia v0.4 support

##### Changes
* using `NullableArrays.jl` and `CategoricalArrays.jl`
instead of `DataArrays.jl` ([#19], see [JuliaStats/DataFrames.jl#1008])
* Julia v0.4 not supported (`DataTables.jl` requires v0.5)
* R logical vectors converted to `Vector{Bool}` (instead of `Vector{Int32}`)

## RData v0.0.4 Release Notes

Now the recommended way to load `.RData`/`.rda` files is by `FileIO.load()`.

##### Changes
* FileIO.jl integration ([#6], [#15])
* Enable precompilation ([#9])
* Fix numeric NA detection ([#10])

## RData v0.0.1 Release Notes

Initial release based on `DataFrames.read_rda()` ([JuliaStats/DataFrames.jl#1031]).

[#6]: https://github.com/JuliaStats/RData.jl/issues/6
[#9]: https://github.com/JuliaStats/RData.jl/issues/9
[#10]: https://github.com/JuliaStats/RData.jl/issues/10
[#15]: https://github.com/JuliaStats/RData.jl/issues/15
[#19]: https://github.com/JuliaStats/RData.jl/issues/19

[JuliaStats/DataFrames.jl#1008]: https://github.com/JuliaStats/DataFrames.jl/pull/1008
[JuliaStats/DataFrames.jl#1031]: https://github.com/JuliaStats/DataFrames.jl/pull/1031
