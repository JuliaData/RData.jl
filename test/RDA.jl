module TestRDA
    using Test
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
        min_rda = load("$testdir/data/minimal.rda", convert=false)
        rdf = min_rda["minimal"]
        @test rdf isa RData.RList
        @testset "class() and inherits()" begin
            # not SEXP
            @test_throws MethodError RData.class(5)
            @test_throws MethodError RData.inherits(5, "number")
            @test_throws MethodError RData.inherits(5, "number")
            @test_throws MethodError RData.inherits(5, ["number"])

            rnotobj = RData.RBuiltin("test") # not a ROBJ
            @inferred RData.class(rnotobj)
            @inferred RData.inherits(rnotobj, "dummy")
            @test RData.class(rnotobj) === RData.emptystrvec
            @test !RData.inherits(rnotobj, "dummy")

            @inferred RData.class(rdf)
            @inferred RData.inherits(rdf, "data.frame")
            @inferred RData.inherits(rdf, ["data.frame"])
            @test RData.class(rdf) == ["data.frame"]
            @test RData.inherits(rdf, "data.frame")
            @test RData.inherits(rdf, ["data.frame"])

            rnumvec = rdf.data[1]
            @test rnumvec isa RData.RNumericVector
            @test RData.class(rnumvec) != ["data.frame"]
            @test !RData.inherits(rnumvec, "data.frame")
            @test !RData.inherits(rnumvec, ["data.frame"])
        end
        @test sexp2julia(min_rda["minimal"]) == df
        @test load("$testdir/data/minimal.rda", convert=true)["minimal"] == df
        @test load("$testdir/data/minimal_ascii.rda")["minimal"] == df
    end

    @testset "Conversion to Julia types" begin
        df = DataFrame(num = [1.1, 2.2],
                       int = Int32[1, 2],
                       logi = [true, false],
                       chr = ["ab", "c"],
                       factor = categorical(["ab", "c"], true),
                       cplx = [1.1+0.5im, 1.0im])
        rdf = sexp2julia(load("$testdir/data/types.rda",convert=false)["types.df"])
        @test eltypes(rdf) == eltypes(df)
        @test rdf == df
        rdf_ascii = sexp2julia(load("$testdir/data/types_ascii.rda",convert=false)["types.df"])
        @test eltypes(rdf_ascii) == eltypes(df)
        @test rdf_ascii == df
    end

    @testset "NAs conversion" begin
        df = DataFrame(num = Union{Float64, Missing}[1.1, 2.2, missing],
                       int = Union{Int32, Missing}[1, 2, missing], ## R int NaN is NA
                       logi = Union{Bool, Missing}[true, false, missing], ##R logical NaN is NA
                       chr = Union{String, Missing}["ab", "c", missing],
                       factor = categorical(Union{String, Missing}["ab", "c", missing], true),
                       cplx = Union{ComplexF64, Missing}[1.1+0.5im, 1.0im, missing])

        ## ComplexF64(1,NaN), NaN]
        @test isequal(sexp2julia(load("$testdir/data/NAs.rda",convert=false)["df.with.na"]), df)
        @test isequal(sexp2julia(load("$testdir/data/NAs_ascii.rda",convert=false)["df.with.na"]), df)
    end

    @testset "NaNs conversion" begin
        df = DataFrame(num = Union{Float64, Missing}[1.1, 2.2, NaN],
                       int = Union{Int32, Missing}[1, 2, missing], ## R int NaN is NA
                       logi = Union{Bool, Missing}[true, false, missing], ##R logical NaN is NA
                       chr = Union{String, Missing}["ab", "c", "NaN"],
                       factor = categorical(Union{String, Missing}["ab", "c", "NaN"], true),
                       cplx = Union{ComplexF64, Missing}[1.1+0.5im, 1.0im, ComplexF64(NaN,NaN)])

        @test isequal(sexp2julia(load("$testdir/data/NaNs.rda",convert=false)["df.with.nan"]), df)
        @test isequal(sexp2julia(load("$testdir/data/NaNs_ascii.rda",convert=false)["df.with.nan"]), df)
    end

    @testset "Column names conversion" begin
        rda_names = names(sexp2julia(load("$testdir/data/names.rda",convert=false)["df.with.new.names"]))
        expected_names = [:_end, :x!, :x1, :_B_C_, :x, :x_1]
        @test rda_names == expected_names
        rda_names = names(sexp2julia(load("$testdir/data/names_ascii.rda",convert=false)["df.with.new.names"]))
        @test rda_names == [:_end, :x!, :x1, :_B_C_, :x, :x_1]
    end

    @testset "Reading RDA with complex types (environments, closures etc)" begin
        rda_envs = load("$testdir/data/envs.rda",convert=false)
        rda_pairlists = load("$testdir/data/pairlists.rda",convert=false)
        rda_closures = load("$testdir/data/closures.rda",convert=false)
        rda_cmpfuns = load("$testdir/data/cmpfun.rda",convert=false)
    end

    @testset "Proper handling of factor and ordered" begin
        f = load("$testdir/data/ord.rda")
        @test !isordered(f["x"])
        @test levels(f["x"]) == ["a", "b", "c"]
        @test isordered(f["y"])
        @test levels(f["y"]) == ["b", "a", "c"]
        @test f["x"] == f["y"] == ["a", "b", "c"]
    end
end
