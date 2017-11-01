## RData v0.1.0 Release Notes

Updated to Julia v0.6 (older versions not supported).

##### Changes
* dropped compatibility with Julia versions prior v0.6 [#32]

[#32]: https://github.com/JuliaStats/RData.jl/issues/32

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

[JuliaStats/DataFrames.jl#1031]: https://github.com/JuliaStats/DataFrames.jl/pull/1031
