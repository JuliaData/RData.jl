module TestRDA
    using Base.Test
    using DataTables
    using RData
    using Compat

    # check for Float64 NA
    @test !RData.isna_float64(reinterpret(UInt64, 1.0))
    @test !RData.isna_float64(reinterpret(UInt64, NaN))
    @test !RData.isna_float64(reinterpret(UInt64, Inf))
    @test !RData.isna_float64(reinterpret(UInt64, -Inf))
    @test RData.isna_float64(reinterpret(UInt64, RData.R_NA_FLOAT64))
    # check that alternative NA is also recognized (#10)
    @test RData.isna_float64(reinterpret(UInt64, RData.R_NA_FLOAT64 | ((Base.significand_mask(Float64) + 1) >> 1)))

    testdir = dirname(@__FILE__)

    df = DataTable(num = NullableArray([1.1, 2.2]))
    @test sexp2julia(load("$testdir/data/minimal.rda",convert=false)["df"]) == df
    @test load("$testdir/data/minimal.rda",convert=true)["df"] == df
    @test load("$testdir/data/minimal_ascii.rda")["df"] == df

    df = DataTable(num = NullableArray([1.1, 2.2]),
                   int = NullableArray(Int32[1, 2]),
                   logi = NullableArray([true, false]),
                   chr = NullableArray(["ab", "c"]),
                   factor = categorical(NullableArray(["ab", "c"]), true),
                   cplx = NullableArray(Complex128[1.1+0.5im, 1.0im]))
    rdf = sexp2julia(load("$testdir/data/types.rda",convert=false)["df"])
    @test eltypes(rdf) == eltypes(df)
    @test rdf == df
    rdf_ascii = sexp2julia(load("$testdir/data/types_ascii.rda",convert=false)["df"])
    @test eltypes(rdf_ascii) == eltypes(df)
    @test rdf_ascii == df

    df[2, :] = Nullable()
    append!(df, df[2, :])
    df[3, :num] = NaN
    df[:, :cplx] = NullableArray([Nullable(), Complex128(1,NaN), NaN])
    @test isequal(sexp2julia(load("$testdir/data/NAs.rda",convert=false)["df"]), df)
    # ASCII format saves NaN as NA
    df[3, :num] = Nullable()
    df[:, :cplx] = NullableArray{Complex128}(3)
    @test sexp2julia(load("$testdir/data/NAs_ascii.rda",convert=false)["df"]) == df

    rda_names = names(sexp2julia(load("$testdir/data/names.rda",convert=false)["df"]))
    expected_names = [:_end, :x!, :x1, :_B_C_, :x, :x_1]
    @test rda_names == expected_names
    rda_names = names(sexp2julia(load("$testdir/data/names_ascii.rda",convert=false)["df"]))
    @test rda_names == [:_end, :x!, :x1, :_B_C_, :x, :x_1]

    rda_envs = load("$testdir/data/envs.rda",convert=false)

    rda_pairlists = load("$testdir/data/pairlists.rda",convert=false)

    rda_closures = load("$testdir/data/closures.rda",convert=false)

    rda_cmpfuns = load("$testdir/data/cmpfun.rda",convert=false)
end
