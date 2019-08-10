module TestCompression
using DataFrames, RData, Test

rdata_path = joinpath(dirname(@__FILE__), "data_v3")
df = DataFrame(num = [1.1, 2.2])

@testset "Loading compressed RData files" begin
    @testset "When the optional compression codecs are not loaded" begin
        @test_warn "Error encountered while loading" begin
            @test_throws CodecMissingError load(joinpath(rdata_path, "compressed_bzip2.rda"))
        end
        @test_warn "Error encountered while loading" begin
            @test_throws CodecMissingError load(joinpath(rdata_path, "compressed_xz.rda"))
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
