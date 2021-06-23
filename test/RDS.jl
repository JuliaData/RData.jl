module TestRDS
using Test
using Dates
using DataFrames
using CategoricalArrays
using RData
using TimeZones

@testset "Loading RDS files (version=$ver)" for ver in (2, 3)
    rdata_path = joinpath(dirname(@__FILE__), "data_v$ver")

    @testset "loading/converting basic R types" begin
        df = DataFrame(num = [1.1, 2.2],
                       int = Int32[1, 2],
                       logi = [true, false],
                       chr = ["ab", "c"],
                       factor = categorical(["ab", "c"], compress=true),
                       cplx = ComplexF64[1.1+0.5im, 1.0im])
        rdf = sexp2julia(load(joinpath(rdata_path, "types.rds"), convert=false))
        @test rdf isa DataFrame
        @test eltype.(eachcol(rdf)) == eltype.(eachcol(df))
        @test isequal(rdf, df)

        rdf_ascii = sexp2julia(load(joinpath(rdata_path, "types_ascii.rds"), convert=false))
        @test rdf_ascii isa DataFrame
        @test eltype.(eachcol(rdf_ascii)) == eltype.(eachcol(df))
        @test isequal(rdf_ascii, df)

        rdf_decomp = sexp2julia(load(joinpath(rdata_path, "types_decomp.rds"), convert=false))
        @test rdf_decomp isa DataFrame
        @test eltype.(eachcol(rdf_decomp)) == eltype.(eachcol(df))
        @test isequal(rdf_decomp, df)

        rdf = load(joinpath(rdata_path, "types.rds"))
        @test rdf isa DataFrame
        @test eltype.(eachcol(rdf)) == eltype.(eachcol(df))
        @test isequal(rdf, df)

        rdf_ascii = load(joinpath(rdata_path, "types_ascii.rds"))
        @test rdf_ascii isa DataFrame
        @test eltype.(eachcol(rdf_ascii)) == eltype.(eachcol(df))
        @test isequal(rdf_ascii, df)

        rdf_decomp = load(joinpath(rdata_path, "types_decomp.rds"))
        @test rdf_decomp isa DataFrame
        @test eltype.(eachcol(rdf_decomp)) == eltype.(eachcol(df))
        @test isequal(rdf_decomp, df)
    end

    @testset "Date conversion" begin
        numdates = load(joinpath(rdata_path, "numdates.rds"))
        @test numdates == Date("2017-01-01") + Dates.Day.(1:4)

        numdates_ascii = load(joinpath(rdata_path, "numdates_ascii.rds"))
        @test numdates_ascii == Date("2017-01-01") + Dates.Day.(1:4)

        intdates = load(joinpath(rdata_path, "intdates.rds"))
        @test intdates == Date("2017-01-01") + Dates.Day.(1:4)

        intdates_ascii = load(joinpath(rdata_path, "intdates_ascii.rds"))
        @test intdates_ascii == Date("2017-01-01") + Dates.Day.(1:4)
    end

    @testset "DateTime conversion" begin
        datetimes = load(joinpath(rdata_path, "datetimes.rds"))
        testdts = map(i -> ZonedDateTime(DateTime("2017-01-01T13:23") + Dates.Second(i),
                                 TimeZone("UTC")), 1:4)
        @test datetimes[1] == testdts
        @test datetimes[2] == testdts[1]
        @test datetimes[3] isa DictoVec
        @test datetimes[3].data == testdts
        @test [datetimes[3].index2name[i] for i in 1:length(datetimes[3])] == ["A", "B", "C", "D"]
        @test datetimes[4] isa DictoVec
        @test datetimes[4].data == [testdts[1]]
        @test datetimes[4].index2name[1] == "A"
    end

    @testset "Date and DateTime in a DataFrame" begin
        rdfs = load(joinpath(rdata_path, "datedfs.rds"))
        df = DataFrame(date=map(i -> Date("2017-01-01") + Dates.Day(i), 1:4),
                       datetime=map(i -> ZonedDateTime(DateTime("2017-01-01T13:23") + Dates.Second(i), tz"UTC"), 1:4))
        @test length(rdfs) == 2
        @test rdfs[1] isa DataFrame
        @test rdfs[2] isa DataFrame
        @test eltype.(eachcol(df)) == eltype.(eachcol(rdfs[1]))
        @test eltype.(eachcol(df)) == eltype.(eachcol(rdfs[2]))
        @test isequal(df[1:1, :], rdfs[1])
        @test isequal(df, rdfs[2])
    end

    @testset "NA Date and DateTime conversion" begin
        dates = load(joinpath(rdata_path, "datesNA.rds"))

        testdates = [Date("2017-01-01") + Dates.Day.(1:4); missing]
        @test all(dates[1] .=== testdates)

        testdts = [map(i -> ZonedDateTime(DateTime("2017-01-01T13:23") + Dates.Second(i), tz"UTC"), 1:4);
                   missing]
        @test all(dates[2] .=== testdts)
    end

    @testset "DateTime timezones" begin
        # tz"CST" is not supported by TimeZones.jl
        datetimes = @test_logs (:warn, "Could not determine the timezone of 'CST', treating as 'UTC'") begin
            load(joinpath(rdata_path, "datetimes_tz.rds"))
        end
        # assumes generate_rda.R was generated on system set to PST!
        @test datetimes[1] == ZonedDateTime(DateTime("2017-01-01T21:23"), tz"UTC")
        # should be tz"CST", but gets substituted to tz"UTC"
        # FIXME update the test when CST is supported
        @test datetimes[2] == ZonedDateTime(DateTime("2017-01-01T13:23"), tz"UTC")
        @test datetimes[3] == ZonedDateTime(DateTime("2017-01-01T13:23"), tz"America/Chicago")
    end

end # for ver in ...

end # module TestRDS
