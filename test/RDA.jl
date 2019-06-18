module TestRDA
using Test
using DataFrames
using RData

@testset "Loading RData files (version=$ver)" for ver in (2, 3)
    rdata_path = joinpath(dirname(@__FILE__), "data_v$ver")

    @testset "Reading minimal RData" begin
        df = DataFrame(num = [1.1, 2.2])
        min_rda = load(joinpath(rdata_path, "minimal.rda"), convert=false)
        rdf = min_rda["df"]
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
        @test sexp2julia(min_rda["df"]) == df
        @test load(joinpath(rdata_path, "minimal.rda"), convert=true)["df"] == df
        @test load(joinpath(rdata_path, "minimal_ascii.rda"))["df"] == df
    end

    @testset "Conversion to Julia types" begin
        df = DataFrame(num = [1.1, 2.2],
                       int = Int32[1, 2],
                       logi = [true, false],
                       chr = ["ab", "c"],
                       factor = categorical(["ab", "c"], true),
                       cplx = [1.1+0.5im, 1.0im])
        rdf = sexp2julia(load(joinpath(rdata_path, "types.rda"), convert=false)["df"])
        @test eltypes(rdf) == eltypes(df)
        @test rdf == df
        rdf_ascii = sexp2julia(load(joinpath(rdata_path, "types_ascii.rda"), convert=false)["df"])
        @test eltypes(rdf_ascii) == eltypes(df)
        @test rdf_ascii == df
    end

    @testset "NAs conversion" begin
        df = DataFrame(num = Union{Float64, Missing}[1.1, 2.2],
                       int = Union{Int32, Missing}[1, 2],
                       logi = Union{Bool, Missing}[true, false],
                       chr = Union{String, Missing}["ab", "c"],
                       factor = categorical(Union{String, Missing}["ab", "c"], true),
                       cplx = Union{ComplexF64, Missing}[1.1+0.5im, 1.0im])

        df[2, :] = missing
        push!(df, df[2, :]) # add another row
        df[3, :num] = NaN
        df[:, :cplx] = [missing, ComplexF64(1, NaN), NaN]
        @test isequal(sexp2julia(load(joinpath(rdata_path, "NAs.rda"), convert=false)["df"]), df)
        @test isequal(sexp2julia(load(joinpath(rdata_path, "NAs_ascii.rda"), convert=false)["df"]), df)
    end

    @testset "Column names conversion" begin
        rda_names = names(sexp2julia(load(joinpath(rdata_path, "names.rda"), convert=false)["df"]))
        expected_names = [:_end, :x!, :x1, :_B_C_, :x, :x_1]
        @test rda_names == expected_names
        rda_names = names(sexp2julia(load(joinpath(rdata_path, "names_ascii.rda"), convert=false)["df"]))
        @test rda_names == [:_end, :x!, :x1, :_B_C_, :x, :x_1]
    end

    @testset "Reading RDA with complex types (environments, closures etc)" begin
        rda_envs = load(joinpath(rdata_path, "envs.rda"), convert=false)
        rda_pairlists = load(joinpath(rdata_path, "pairlists.rda"), convert=false)
        rda_closures = load(joinpath(rdata_path, "closures.rda"), convert=false)
        rda_cmpfuns = load(joinpath(rdata_path, "cmpfun.rda"), convert=false)
    end

    @testset "Proper handling of factor and ordered" begin
        f = load(joinpath(rdata_path, "ord.rda"))
        @test !isordered(f["x"])
        @test levels(f["x"]) == ["a", "b", "c"]
        @test isordered(f["y"])
        @test levels(f["y"]) == ["b", "a", "c"]
        @test f["x"] == f["y"] == ["a", "b", "c"]
    end

end # for ver in ...

@testset "Loading AltRep-containing RData files (version=3)" begin
    altrep_rda = load(joinpath("data_v3", "altrep.rda"), convert=false)
    load(joinpath("data_v3", "altrep_ascii.rda"), convert=false)
    @test length(altrep_rda) == 2
    # test AltRep objects are recognized
    @test isa(altrep_rda["longseq"], RData.RAltRep)
    # TODO test that longseq is converted into Julia UnitRange
    @test isa(altrep_rda["wrapvec"], RData.RAltRep)
    @test sexp2julia(altrep_rda["wrapvec"]) == [1.0, 2.5, 3.0]

    # test automatic conversion
    altrep_conv_rda = load(joinpath("data_v3", "altrep.rda"), convert=true)
    @test altrep_conv_rda["wrapvec"] == [1.0, 2.5, 3.0]
end

end # module TestRDA
