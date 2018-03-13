module TestRDS
    using Base.Test
    using DataFrames
    using RData

    testdir = dirname(@__FILE__)

    @testset "RDS: Conversion to Julia types" begin
        df = DataFrame(num = [1.1, 2.2],
                       int = Int32[1, 2],
                       logi = [true, false],
                       chr = ["ab", "c"],
                       factor = categorical(["ab", "c"], true),
                       cplx = Complex128[1.1+0.5im, 1.0im])
        rdf = sexp2julia(load("$testdir/data/types.rds",convert=false))
        @test rdf isa DataFrame
        @test eltypes(rdf) == eltypes(df)
        @test isequal(rdf, df)

        rdf_ascii = sexp2julia(load("$testdir/data/types_ascii.rds",convert=false))
        @test rdf_ascii isa DataFrame
        @test eltypes(rdf_ascii) == eltypes(df)
        @test isequal(rdf_ascii, df)

        rdf_decomp = sexp2julia(load("$testdir/data/types_decomp.rds",convert=false))
        @test rdf_decomp isa DataFrame
        @test eltypes(rdf_decomp) == eltypes(df)
        @test isequal(rdf_decomp, df)

        rdf = load("$testdir/data/types.rds")
        @test rdf isa DataFrame
        @test eltypes(rdf) == eltypes(df)
        @test isequal(rdf, df)

        rdf_ascii = load("$testdir/data/types_ascii.rds")
        @test rdf_ascii isa DataFrame
        @test eltypes(rdf_ascii) == eltypes(df)
        @test isequal(rdf_ascii, df)

        rdf_decomp = load("$testdir/data/types_decomp.rds")
        @test rdf_decomp isa DataFrame
        @test eltypes(rdf_decomp) == eltypes(df)
        @test isequal(rdf_decomp, df)
    end
end

