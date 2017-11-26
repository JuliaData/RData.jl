module TestRDA
    using Base.Test
    using DataFrames
    using RData

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

    testdir = dirname(@__FILE__)
    @testset "Reading minimal RData" begin
        df = DataFrame(num = [1.1, 2.2])
        @test sexp2julia(load("$testdir/data/minimal.rda",convert=false)["df"]) == df
        @test load("$testdir/data/minimal.rda",convert=true)["df"] == df
        @test load("$testdir/data/minimal_ascii.rda")["df"] == df
    end

    @testset "Conversion to Julia types" begin
        df = DataFrame(num = [1.1, 2.2],
                       int = Int32[1, 2],
                       logi = [true, false],
                       chr = ["ab", "c"],
                       factor = categorical(["ab", "c"], true),
                       cplx = [1.1+0.5im, 1.0im])
        rdf = sexp2julia(load("$testdir/data/types.rda",convert=false)["df"])
        @test eltypes(rdf) == eltypes(df)
        @test rdf == df
        rdf_ascii = sexp2julia(load("$testdir/data/types_ascii.rda",convert=false)["df"])
        @test eltypes(rdf_ascii) == eltypes(df)
        @test rdf_ascii == df
    end

    @testset "NAs conversion" begin
        df = DataFrame(num = Union{Float64, Missing}[1.1, 2.2],
                       int = Union{Int32, Missing}[1, 2],
                       logi = Union{Bool, Missing}[true, false],
                       chr = Union{String, Missing}["ab", "c"],
                       factor = categorical(Union{String, Missing}["ab", "c"], true),
                       cplx = Union{Complex128, Missing}[1.1+0.5im, 1.0im])

        df[2, :] = missing
        append!(df, df[2, :])
        df[3, :num] = NaN
        df[:, :cplx] = [missing, Complex128(1,NaN), NaN]
        @test isequal(sexp2julia(load("$testdir/data/NAs.rda",convert=false)["df"]), df)
        # ASCII format saves NaN as NA
        df[3, :num] = missing
        df[:, :cplx] = missing
        @test isequal(sexp2julia(load("$testdir/data/NAs_ascii.rda",convert=false)["df"]), df)
    end

    @testset "Column names conversion" begin
        rda_names = names(sexp2julia(load("$testdir/data/names.rda",convert=false)["df"]))
        expected_names = [:_end, :x!, :x1, :_B_C_, :x, :x_1]
        @test rda_names == expected_names
        rda_names = names(sexp2julia(load("$testdir/data/names_ascii.rda",convert=false)["df"]))
        @test rda_names == [:_end, :x!, :x1, :_B_C_, :x, :x_1]
    end

    @testset "Reading RDA with complex types (environments, closures etc)" begin
        rda_envs = load("$testdir/data/envs.rda",convert=false)
        rda_pairlists = load("$testdir/data/pairlists.rda",convert=false)
        rda_closures = load("$testdir/data/closures.rda",convert=false)
        rda_cmpfuns = load("$testdir/data/cmpfun.rda",convert=false)
    end
end
