module TestRDA
using Test
using DataFrames
using CategoricalArrays
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
                       factor = categorical(["ab", "c"], compress=true),
                       cplx = [1.1+0.5im, 1.0im])
        rdf = sexp2julia(load(joinpath(rdata_path, "types.rda"), convert=false)["df"])
        @test eltype.(eachcol(rdf)) == eltype.(eachcol(df))
        @test rdf == df
        rdf_ascii = sexp2julia(load(joinpath(rdata_path, "types_ascii.rda"), convert=false)["df"])
        @test eltype.(eachcol(rdf_ascii)) == eltype.(eachcol(df))
        @test rdf_ascii == df
    end

    @testset "NAs conversion" begin
        df = DataFrame(num = Union{Float64, Missing}[1.1, 2.2],
                       int = Union{Int32, Missing}[1, 2],
                       logi = Union{Bool, Missing}[true, false],
                       chr = Union{String, Missing}["ab", "c"],
                       factor = categorical(Union{String, Missing}["ab", "c"], compress=true),
                       cplx = Union{ComplexF64, Missing}[1.1+0.5im, 1.0im])

        df[2, :] .= Ref(missing)
        push!(df, df[2, :]) # add another row
        df[3, :num] = NaN
        df[!, :cplx] = [missing, ComplexF64(1, NaN), NaN]
        @test isequal(sexp2julia(load(joinpath(rdata_path, "NAs.rda"), convert=false)["df"]), df)
        @test isequal(sexp2julia(load(joinpath(rdata_path, "NAs_ascii.rda"), convert=false)["df"]), df)
    end

    @testset "Column names conversion" begin
        rda_names = names(sexp2julia(load(joinpath(rdata_path, "names.rda"), convert=false)["df"]))
        expected_names = ["_end", "x!", "x1", "_B_C_", "x", "x_1"]
        @test rda_names == expected_names
        rda_names = names(sexp2julia(load(joinpath(rdata_path, "names_ascii.rda"), convert=false)["df"]))
        @test rda_names == expected_names
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

    @testset "List of vectors (#82)" begin
        f = load(joinpath(rdata_path, "list_of_vec.rda"))
        listofvec = f["listofvec"]
        @test listofvec isa Vector{Vector{Union{Float64, Missing}}}
        @test length(listofvec) == 3
        @test isequal(listofvec, [[1., 2., missing], [3., 4.], [5., 6., missing]])
        @test listofvec[1] isa Vector{Union{Float64, Missing}}
        @test listofvec[2] isa Vector{Union{Float64, Missing}}

        listofvec2 = f["listofvec2"]
        @test listofvec2 isa Vector{Any}
        @test length(listofvec2) == 3
        @test isequal(listofvec2, [[1, 2, missing], [3., 4.], [5., 6., missing]])
        @test listofvec2[1] isa Vector{Union{Int32, Missing}}
        @test listofvec2[2] isa Vector{Float64}

        listofvec3 = f["listofvec3"]
        @test listofvec3 isa Vector{Any}
        @test length(listofvec3) == 2
        @test isequal(listofvec3, [[1, 2], [3., 4.]])
        @test listofvec3[1] isa Vector{Int32}
        @test listofvec3[2] isa Vector{Float64}

        listofvec4 = f["listofvec4"]
        @test listofvec4 isa Vector{Vector{Float64}}
        @test length(listofvec4) == 2
        @test isequal(listofvec4, [[1., 2.], [3., 4., 5.]])
        @test listofvec4[1] isa Vector{Float64}
        @test listofvec4[2] isa Vector{Float64}

        namedlistofvec = f["namedlistofvec"]
        @test namedlistofvec isa DictoVec
        @test length(namedlistofvec) == 3
        @test namedlistofvec.name2index == Dict("A"=>1, "B"=>3)
        @test isequal(values(namedlistofvec), [[1., 2., missing], [3., 4.], [5., 6., missing]])

        testdf = f["testdf"]
        @test testdf isa DataFrame
        @test nrow(testdf) == 3
        @test eltype(testdf[!, "listascol"]) === Vector{Union{Float64, Missing}}
        @test isequal(testdf[!, "listascol"], [[1., 2., missing], [3., 4.], [5., 6., missing, 7.]])
        @test testdf[!, "listascol2"] isa Vector{Any}
        @test isequal(testdf[!, "listascol2"], [[1., 2.], [3, 4], [5., 6., 7.]])
    end # list of vectors
end # for ver in ...

@testset "Loading AltRep-containing RData files (version=3)" begin
    altrep_rda = load(joinpath("data_v3", "altrep.rda"), convert=false)
    load(joinpath("data_v3", "altrep_ascii.rda"), convert=false)
    @test length(altrep_rda) == 4
    # test AltRep objects are recognized
    @test isa(altrep_rda["longseq"], RData.RAltRep)
    # TODO test that longseq is converted into Julia UnitRange
    @test isa(altrep_rda["wrapvec"], RData.RAltRep)
    @test sexp2julia(altrep_rda["wrapvec"]) == [1.0, 2.5, 3.0]
    @test isa(altrep_rda["nonnilpairlist"], RData.RAltRep)
    @test isa(altrep_rda["factoraltrep"], RData.RAltRep)
    @test isequal(sexp2julia(altrep_rda["factoraltrep"]),
                  compress(categorical(repeat(["A", "B", missing, "C"], inner=5000))))

    # test that AltRep-based column names are converted correctly
    altrep_names_rda = load(joinpath("data_v3", "altrep_names.rda"), convert=false)
    @test isa(altrep_names_rda["altrepnames_df"].attr["names"], RData.RAltRep)
    @test sexp2julia(altrep_names_rda["altrepnames_df"]) isa DataFrame
    wide_df = sexp2julia(altrep_names_rda["altrepnames_df"])
    @test names(wide_df) == ["a", "b", "c"]

    # test automatic conversion
    altrep_conv_rda = load(joinpath("data_v3", "altrep.rda"), convert=true)
    @test altrep_conv_rda["wrapvec"] == [1.0, 2.5, 3.0]
    @test isequal(altrep_conv_rda["factoraltrep"],
                  compress(categorical(repeat(["A", "B", missing, "C"], inner=5000))))
    @test isa(altrep_conv_rda["nonnilpairlist"], Matrix{Int32})
    @test size(altrep_conv_rda["nonnilpairlist"]) == (0, 10)
end

@testset "Duplicate levels in factor (version=3)" begin
    dup_cat = sexp2julia(load(joinpath("data_v3", "dup_levels.rda"), convert=false)["dup_levels"])
    @test dup_cat[1] == "Paced"
    @test dup_cat[2] == "Inferior"
    @test dup_cat[end] == "Anterior"
    @test levels(dup_cat) ==
        ["Inferior", "Anterior", "LBBB", "Missing", "NoSTUp", "OtherSTUp", "Paced"]
end

end # module TestRDA
