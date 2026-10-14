module TestCompression
using DataFrames, RData, Test
using FileIO: Stream, @format_str
using CodecZlib: GzipCompressor
using TranscodingStreams: transcode

rdata_path = joinpath(dirname(@__FILE__), "data_v3")
df = DataFrame(num = [1.1, 2.2])

function test_missing_compressor(filename::AbstractString, codec::Symbol)
    path = joinpath(rdata_path, filename)
    for input in (path, IOBuffer(read(path)))
        @test_throws CapturedException load(input)
        caught = nothing
        try
            load(input)
        catch ex
            caught = ex
        end

        @test caught isa CapturedException
        @test caught.ex isa CodecMissingError
        @test caught.ex.formatName == codec
        if input isa IO
            @test isopen(input)
        end
    end
end

@testset "Loading compressed RData files" begin
    @testset "When the optional compression codecs are not loaded" begin
        @test_warn "Error encountered while load" begin
            test_missing_compressor("compressed_bzip2.rda", :BZIP2)
        end
        @test_warn "Error encountered while load" begin
            test_missing_compressor("compressed_xz.rda", :XZ)
        end
    end

    @testset "When the optional compression codecs are loaded" begin
        import CodecBzip2, CodecXz

        @test load(joinpath(rdata_path, "compressed_gzip.rda"))["df"] == df
        @test load(joinpath(rdata_path, "compressed_bzip2.rda"))["df"] == df
        @test load(joinpath(rdata_path, "compressed_xz.rda"))["df"] == df
        @test load(joinpath(rdata_path, "compressed_false.rda"))["df"] == df
    end
end

@testset "Loading R data from caller-owned streams" begin
    paths = [joinpath(rdata_path, "compressed_$(codec).rda")
             for codec in ("false", "gzip", "bzip2", "xz")]
    append!(paths, [joinpath(@__DIR__, "data_v$version", name)
                    for version in (2, 3)
                    for name in ("minimal.rda", "types_decomp.rds", "types.rds")])
    for path in paths
        @testset "$(basename(dirname(path)))/$(basename(path))" begin
            bytes = read(path)
            expected = load(path; metadata=false)
            io = IOBuffer(bytes)
            seekend(io)
            @test isequal(load(io; metadata=false), expected)
            @test isopen(io)
            @test 0 < position(io) <= length(bytes)
            seekstart(io)
            @test read(io) == bytes

            input_format = endswith(path, ".rds") ? format"RDataSingle" : format"RData"
            @test isequal(load(Stream{input_format}(io); metadata=false), expected)
            @test isopen(io)
            raw = load(IOBuffer(bytes); convert=false)
            @test (endswith(path, ".rds") ? raw : raw["df"]) isa RData.RList
        end
    end

    @testset "Uncompressed stream position" begin
        bytes = read(joinpath(rdata_path, "compressed_false.rda"))
        io = IOBuffer(vcat(bytes, b"tail"))
        @test load(io)["df"] == df
        @test position(io) == length(bytes)
        @test String(read(io)) == "tail"
    end

    @testset "Borrowed file stream" begin
        path = joinpath(rdata_path, "compressed_gzip.rda")
        open(path) do io
            @test load(io)["df"] == df
            @test isopen(io)
            seekstart(io)
            @test read(io) == read(path)
        end
    end

    @testset "Concatenated compressed members" begin
        bytes = read(joinpath(rdata_path, "compressed_false.rda"))
        split = length(bytes) ÷ 2
        for codec in (GzipCompressor, CodecBzip2.Bzip2Compressor, CodecXz.XzCompressor)
            compressed = vcat(transcode(codec, bytes[1:split]),
                              transcode(codec, bytes[split+1:end]))
            @test load(IOBuffer(compressed))["df"] == df
            mktemp() do path, io
                write(io, compressed)
                close(io)
                @test load(path)["df"] == df
            end
        end
    end

    @testset "Failed conversion leaves the input open" begin
        for codec in ("gzip", "bzip2", "xz")
            io = IOBuffer(read(joinpath(rdata_path, "compressed_$(codec).rda")))
            @test_throws TypeError RData.fileio_load(Stream{format"RData"}(io); convert=:invalid)
            @test isopen(io)
            @test load(io)["df"] == df
        end
    end
end

end
