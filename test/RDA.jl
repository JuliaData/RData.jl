module TestRDA
    using Base.Test
    using DataFrames
    using RData
    using Compat

    testdir = dirname(@__FILE__)

    df = DataFrame(num = [1.1, 2.2])
    @test isequal(sexp2julia(load("$testdir/data/minimal.rda",convert=false)["df"]), df)
    @test isequal(load("$testdir/data/minimal.rda",convert=true)["df"], df)
    @test isequal(load("$testdir/data/minimal_ascii.rda")["df"], df)

    df[:int] = Int32[1, 2]
    df[:logi] = [true, false]
    df[:chr] = ["ab", "c"]
    df[:factor] = pool(df[:chr])
    df[:cplx] = Complex128[1.1+0.5im, 1.0im]
    @test isequal(sexp2julia(load("$testdir/data/types.rda",convert=false)["df"]), df)
    @test isequal(sexp2julia(load("$testdir/data/types_ascii.rda",convert=false)["df"]), df)

    df[2, :] = NA
    append!(df, df[2, :])
    df[3, :num] = NaN
    df[:, :cplx] = @data [NA, @compat(Complex128(1,NaN)), NaN]
    @test isequal(sexp2julia(load("$testdir/data/NAs.rda",convert=false)["df"]), df)
    # ASCII format saves NaN as NA
    df[3, :num] = NA
    df[:, :cplx] = @data [NA, NA, NA]
    @test isequal(sexp2julia(load("$testdir/data/NAs_ascii.rda",convert=false)["df"]), df)

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
