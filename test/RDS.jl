module TestRDS
    using DataFrames, RData, Test, TimeZones

    testdir = dirname(@__FILE__)

    @testset "Loading RDS files" begin
        df = DataFrame(num = [1.1, 2.2],
                       int = Int32[1, 2],
                       logi = [true, false],
                       chr = ["ab", "c"],
                       factor = categorical(["ab", "c"], true),
                       cplx = Complex128[1.1+0.5im, 1.0im])
        rdf = sexp2julia(load("$testdir/data/types.rds", convert=false))
        @test rdf isa DataFrame
        @test eltypes(rdf) == eltypes(df)
        @test isequal(rdf, df)

        rdf_ascii = sexp2julia(load("$testdir/data/types_ascii.rds", convert=false))
        @test rdf_ascii isa DataFrame
        @test eltypes(rdf_ascii) == eltypes(df)
        @test isequal(rdf_ascii, df)

        rdf_decomp = sexp2julia(load("$testdir/data/types_decomp.rds", convert=false))
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
        testdts = ZonedDateTime.(DateTime("2017-01-01T13:23") + Dates.Second.(1:4),
                                 TimeZone("UTC"))
        @test datetimes[1] == testdts
        @test datetimes[2] == testdts[1]
        @test datetimes[3] isa DictoVec
        @test datetimes[3].data == testdts
        @test [datetimes[3].index2name[i] for i in 1:length(datetimes[3])] == ["A", "B", "C", "D"]
        @test datetimes[4] isa DictoVec
        @test datetimes[4].data == [testdts[1]]
        @test datetimes[4].index2name[1] == "A"
    end

    @testset "Test Date and DateTime in a DataFrame" begin
        rdfs = load("$testdir/data/datedfs.rds")
        df = DataFrame(date=Date("2017-01-01") + Dates.Day.(1:4),
                       datetime=ZonedDateTime.(DateTime("2017-01-01T13:23") + Dates.Second.(1:4),
                                               tz"UTC"))
        @test length(rdfs) == 2
        @test rdfs[1] isa DataFrame
        @test rdfs[2] isa DataFrame
        @test eltypes(df) == eltypes(rdfs[1])
        @test eltypes(df) == eltypes(rdfs[2])
        @test isequal(df[1, :], rdfs[1])
        @test isequal(df, rdfs[2])
    end

    @testset "Test NA Date and DateTime conversion" begin
        dates = load("$testdir/data/datesNA.rds")

        testdates = [Date("2017-01-01") + Dates.Day.(1:4); missing]
        @test all(dates[1] .=== testdates)

        testdts = [ZonedDateTime.(DateTime("2017-01-01T13:23") + Dates.Second.(1:4), tz"UTC");
                   missing]
        @test all(dates[2] .=== testdts)
    end

    @testset "Test DateTime timezones" begin
        # tz"CST" is not supported by TimeZones.jl
        datetimes = @test_warn "Could not determine the timezone of 'CST', treating as UTC." begin
            load("$testdir/data/datetimes_tz.rds")
        end
        # assumes generate_rda.R was generated on system set to PST!
        @test datetimes[1] == ZonedDateTime(DateTime("2017-01-01T21:23"), tz"UTC")
        # should be tz"CST", but gets substituted to tz"UTC"
        # FIXME update the test when CST is supported
        @test datetimes[2] == ZonedDateTime(DateTime("2017-01-01T13:23"), tz"UTC")
        @test datetimes[3] == ZonedDateTime(DateTime("2017-01-01T13:23"), tz"America/Chicago")
    end
end
