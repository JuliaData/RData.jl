module TestRDS
    using Base.Test
    using DataFrames
    using RData
    using Compat

    # think this is redundant for rds vs rda
    # check for Float64 NA
    # @test !RData.isna_float64(reinterpret(UInt64, 1.0))
    # @test !RData.isna_float64(reinterpret(UInt64, NaN))
    # @test !RData.isna_float64(reinterpret(UInt64, Inf))
    # @test !RData.isna_float64(reinterpret(UInt64, -Inf))
    # @test RData.isna_float64(reinterpret(UInt64, RData.R_NA_FLOAT64))
    # # check that alternative NA is also recognized (#10)
    # @test RData.isna_float64(reinterpret(UInt64, RData.R_NA_FLOAT64 | ((Base.significand_mask(Float64) + 1) >> 1)))

    testdir = dirname(@__FILE__)

    df = DataFrame(num = [1.1, 2.2])
    @test isequal(sexp2julia(readRDS("$testdir/data/minimal.rds",convert=false))["df"], df)
    @test isequal(readRDS("$testdir/data/minimal.rds",convert=true)["df"], df)
    @test isequal(readRDS("$testdir/data/minimal_ascii.rds")["df"], df)

    df[:int] = Int32[1, 2]
    df[:logi] = [true, false]
    df[:chr] = ["ab", "c"]
    df[:factor] = pool(df[:chr])
    df[:cplx] = Complex128[1.1+0.5im, 1.0im]
    @test isequal(sexp2julia(readRDS("$testdir/data/types.rds",convert=false))["df"], df)
    @test isequal(sexp2julia(readRDS("$testdir/data/types_ascii.rds",convert=false))["df"], df)

    df[2, :] = NA
    append!(df, df[2, :])
    df[3, :num] = NaN
    df[:, :cplx] = @data [NA, @compat(Complex128(1,NaN)), NaN]
    @test isequal(sexp2julia(readRDS("$testdir/data/NAs.rds",convert=false))["df"], df)
    # ASCII format saves NaN as NA
    df[3, :num] = NA
    df[:, :cplx] = @data [NA, NA, NA]
    @test isequal(sexp2julia(readRDS("$testdir/data/NAs_ascii.rds",convert=false))["df"], df)

    rds_names = names(sexp2julia(readRDS("$testdir/data/names.rds",convert=false))["df"])
    expected_names = [:_end, :x!, :x1, :_B_C_, :x, :x_1]
    @test rds_names == expected_names
    rds_names = names(sexp2julia(readRDS("$testdir/data/names_ascii.rds",convert=false))["df"])
    @test rds_names == [:_end, :x!, :x1, :_B_C_, :x, :x_1]

    rds_envs = readRDS("$testdir/data/envs.rds",convert=false)

    rds_pairlists = readRDS("$testdir/data/pairlists.rds",convert=false)

    rds_closures = readRDS("$testdir/data/closures.rds",convert=false)

    rds_cmpfuns = readRDS("$testdir/data/cmpfun.rds",convert=false)
end

