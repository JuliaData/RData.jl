module TestRDS
    using Base.Test
    using DataFrames
    using RData

    testdir = dirname(@__FILE__)

    @testset "RDS: Reading minimal rds" begin
        df = DataFrame(num = [1.1, 2.2])
        @test isequal(sexp2julia(readRDS("$testdir/data/minimal.rds",convert=false))["df"], df)
        @test isequal(readRDS("$testdir/data/minimal.rds",convert=true)["df"], df)
        @test isequal(readRDS("$testdir/data/minimal_ascii.rds")["df"], df)
    end

    @testset "RDS: Conversion to Julia types" begin
        df = DataFrame(num = [1.1, 2.2],
                       int = Int32[1, 2],
                       logi = [true, false],
                       chr = ["ab", "c"],
                       factor = pool(["ab", "c"]),
                       cplx = Complex128[1.1+0.5im, 1.0im])
        rdf = sexp2julia(readRDS("$testdir/data/types.rds",convert=false))["df"]
        @test eltypes(rdf) == eltypes(df)
        @test isequal(rdf, df)
        rdf_ascii = sexp2julia(readRDS("$testdir/data/types_ascii.rds",convert=false))["df"]
        @test eltypes(rdf_ascii) == eltypes(df)
        @test isequal(rdf_ascii, df)
    end


    @testset "RDS: NAs conversion" begin
        df = DataFrame(num = [1.1, 2.2],
                       int = Int32[1, 2],
                       logi = [true, false],
                       chr = ["ab", "c"],
                       factor = pool(["ab", "c"]),
                       cplx = Complex128[1.1+0.5im, 1.0im])

        df[2, :] = NA
        append!(df, df[2, :])
        df[3, :num] = NaN
        df[:, :cplx] = @data [NA, Complex128(1,NaN), NaN]
        @test isequal(sexp2julia(readRDS("$testdir/data/NAs.rds",convert=false))["df"], df)
        # ASCII format saves NaN as NA
        df[3, :num] = NA
        df[:, :cplx] = @data [NA, NA, NA]
        @test isequal(sexp2julia(readRDS("$testdir/data/NAs_ascii.rds",convert=false))["df"], df)
    end

    @testset "RDS: Column names conversion" begin
        rds_names = names(sexp2julia(readRDS("$testdir/data/names.rds",convert=false))["df"])
        expected_names = [:_end, :x!, :x1, :_B_C_, :x, :x_1]
        @test rds_names == expected_names
        rds_names = names(sexp2julia(readRDS("$testdir/data/names_ascii.rds",convert=false))["df"])
        @test rds_names == [:_end, :x!, :x1, :_B_C_, :x, :x_1]
    end

    @testset "RDS: Reading RDA with complex types (environments, closures etc)" begin
        rds_envs = readRDS("$testdir/data/envs.rds",convert=false)
        rds_pairlists = readRDS("$testdir/data/pairlists.rds",convert=false)
        rds_closures = readRDS("$testdir/data/closures.rds",convert=false)
        rds_cmpfuns = readRDS("$testdir/data/cmpfun.rds",convert=false)
    end
end

