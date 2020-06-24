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

@testset "Internals" begin
    @testset "sxtype()" begin
        v = RData.RVector{Int, RData.INTSXP}([1, 2], RData.emptyhash)
        @test RData.sxtype(typeof(v)) == RData.INTSXP
        @test RData.sxtype(v) == RData.INTSXP
        s = RData.RSymbol("abc")
        @test RData.sxtype(typeof(s)) == RData.SYMSXP
        @test RData.sxtype(s) == RData.SYMSXP
    end

    @testset "addattr()" begin
        v = RData.RVector{Int, RData.INTSXP}([1, 2, 3], RData.emptyhash)
        v2 = RData.addattr(v)
        @test v2 isa RData.RVector{Int, RData.INTSXP}
        @test v2.data === v.data
        @test v2.attr !== RData.emptyhash
    end
end

end

end # TestBasic
