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
                       factor = pool(["ab", "c"]),
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

    @testset "Test Date conversion" begin
        dates = load("$testdir/data/dates.rds")
        @test dates[1] == Date("2017-01-01") + Dates.Day.(1:4)
        @test dates[2] == Date("2017-01-02")
        @test dates[3] isa DictoVec
        @test dates[3].data == Date("2017-01-01") + Dates.Day.(1:4)
        @test [dates[3].index2name[i] for i in 1:length(dates[3])] == ["A", "B", "C", "D"]
        @test dates[4] isa DictoVec
        @test dates[4].data == [Date("2017-01-02")]
        @test dates[4].index2name[1] == "A"
    end

    @testset "Test DateTime conversion" begin
        datetimes = load("$testdir/data/datetimes.rds")
        @test datetimes[1] == DateTime("2017-01-01T13:23") + Dates.Second.(1:4)
        @test datetimes[2] == DateTime("2017-01-01T13:23:01")
        @test datetimes[3] isa DictoVec
        @test datetimes[3].data == DateTime("2017-01-01T13:23") + Dates.Second.(1:4)
        @test [datetimes[3].index2name[i] for i in 1:length(datetimes[3])] == ["A", "B", "C", "D"]
        @test datetimes[4] isa DictoVec
        @test datetimes[4].data == [DateTime("2017-01-01T13:23:01")]
        @test datetimes[4].index2name[1] == "A"
    end

    @testset "Test NA Date and DateTime conversion" begin
        dates = load("$testdir/data/datesNA.rds")
        testdates = RData.DataArray([Date("2017-01-01") + Dates.Day.(1:4); Date()],
                                    BitArray([false, false, false, false, true]))
        @test dates[1][1:4] == testdates[1:4]
        @test RData.isna(dates[1][5])

        testdts = RData.DataArray([DateTime("2017-01-01T13:23") + Dates.Second.(1:4); Date()],
                                  BitArray([false, false, false, false, true]))
        @test dates[2][1:4] == testdts[1:4]
        @test RData.isna(dates[2][5])
    end
end

