module TestBasic
using Test
using RData

@testset "Basic/Utility RData functions" begin

# check for Float64 NA
@testset "Detect R floating-point NAs" begin
    @test !RData.isna_float64(reinterpret(UInt64, 1.0))
    @test !RData.isna(1.0)
    @test !RData.isna(NaN)
    @test !RData.isna(Inf)
    @test !RData.isna(-Inf)
    @test RData.isna_float64(RData.R_NA_FLOAT64)
    # check that alternative NA is also recognized (#10)
    @test RData.isna_float64(reinterpret(UInt64, RData.R_NA_FLOAT64 | ((Base.significand_mask(Float64) + 1) >> 1)))
end

@testset "Unescape R strings" begin
    @test RData.unescape_rstring("\\\"") == "\""
    @test RData.unescape_rstring("\\'") == "'"
end

end

end # TestBasic
