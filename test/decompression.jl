module TestCompression
using DataFrames, RData, Test

rdata_path = joinpath(dirname(@__FILE__), "data_v3")
df = DataFrame(num = [1.1, 2.2])

function test_missing_compressor(filename::AbstractString, codec::Symbol)
    @test_throws CapturedException load(joinpath(rdata_path, filename))
    caught = nothing
    try
        load(joinpath(rdata_path, filename))
    catch ex
        caught = ex
    end

    @test caught isa CapturedException
    @test caught.ex isa CodecMissingError
    @test caught.ex.formatName == codec
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

end
