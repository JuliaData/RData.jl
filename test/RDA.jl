module TestRDA
    using Base.Test
    using DataFrames
    using RData
    using Compat

    # R code generating test .rdas
        # df = data.frame(num=c(1.1, 2.2))
        # save(df, file='minimal.rda')
        # save(df, file='minimal_ascii.rda', ascii=TRUE)

        # df['int'] = c(1L, 2L)
        # df['logi'] = c(TRUE, FALSE)
        # df['chr'] = c('ab', 'c')
        # df['factor'] = factor(df$chr)
        # df['cplx'] = complex( real=c(1.1,0.0), imaginary=c(0.5,1.0) )
        # #utf=c('Ж', '∰')) R handles it, read_rda doesn't.
        # save(df, file='types.rda')
        # save(df, file='types_ascii.rda', ascii=TRUE)

        # df[2, ] = NA
        # df[3, ] = df[2, ]
        # df[3,'num'] = NaN
        # df[,'cplx'] = complex( real=c(1.1,1,NaN), imaginary=c(NA,NaN,0) )
        # save(df, file='NAs.rda')
        # save(df, file='NAs_ascii.rda', ascii=TRUE)

        # names(df) = c('end', '!', '1', '%_B*\tC*', NA, 'x')
        # save(df, file='names.rda')
        # save(df, file='names_ascii.rda', ascii=TRUE)

        # empty.env = new.env(parent=emptyenv())
        # empty_nohash.env = new.env(parent=emptyenv())
        # empty_child.env = new.env(parent=empty.env)
        # a.env = new.env(parent=emptyenv())
        # assign( 'a', 43, envir = a.env )
        # b.env = new.env(parent=a.env)
        # assign( 'b', 48, envir = b.env )
        # save(empty.env, empty_nohash.env, empty_child.env, a.env, b.env,
        #      file='envs.rda')

        # pl.empty = pairlist()
        # pl = pairlist( u = 1L, x = c(2.0, 3.0), y = 'A', NULL, z = TRUE )
        # save(pl.empty, pl, file='pairlists.rda')

        # test.fun0 = function() return(NULL)
        # test.fun1 = function(x) return(x+1)
        # test.fun2 = function(x,y) x+y
        # save(test.fun0, test.fun1, test.fun2, file='closures.rda')

        # require(compiler)
        # test.cmpfun0 = cmpfun( test.fun0 )
        # test.cmpfun1 = cmpfun( test.fun1 )
        # test.cmpfun2 = cmpfun( test.fun2 )
        # save(test.cmpfun0, test.cmpfun1, test.cmpfun2, file='cmpfun.rda')

    testdir = dirname(@__FILE__)

    df = DataFrame(num = [1.1, 2.2])
    @test isequal(sexp2julia(read_rda("$testdir/data/minimal.rda",convert=false)["df"]), df)
    @test isequal(read_rda("$testdir/data/minimal.rda",convert=true)["df"], df)
    @test isequal(open(read_rda,"$testdir/data/minimal_ascii.rda")["df"], df)

    df[:int] = Int32[1, 2]
    df[:logi] = [true, false]
    df[:chr] = ["ab", "c"]
    df[:factor] = pool(df[:chr])
    df[:cplx] = Complex128[1.1+0.5im, 1.0im]
    @test isequal(sexp2julia(read_rda("$testdir/data/types.rda",convert=false)["df"]), df)
    @test isequal(sexp2julia(read_rda("$testdir/data/types_ascii.rda",convert=false)["df"]), df)

    df[2, :] = NA
    append!(df, df[2, :])
    df[3, :num] = NaN
    df[:, :cplx] = @data [NA, @compat(Complex128(1,NaN)), NaN]
    @test isequal(sexp2julia(read_rda("$testdir/data/NAs.rda",convert=false)["df"]), df)
    # ASCII format saves NaN as NA
    df[3, :num] = NA
    df[:, :cplx] = @data [NA, NA, NA]
    @test isequal(sexp2julia(read_rda("$testdir/data/NAs_ascii.rda",convert=false)["df"]), df)

    rda_names = names(sexp2julia(read_rda("$testdir/data/names.rda",convert=false)["df"]))
    expected_names = [:_end, :x!, :x1, :_B_C_, :x, :x_1]
    @test rda_names == expected_names
    rda_names = names(sexp2julia(read_rda("$testdir/data/names_ascii.rda",convert=false)["df"]))
    @test rda_names == [:_end, :x!, :x1, :_B_C_, :x, :x_1]

    rda_envs = read_rda("$testdir/data/envs.rda",convert=false)

    rda_pairlists = read_rda("$testdir/data/pairlists.rda",convert=false)

    rda_closures = read_rda("$testdir/data/closures.rda",convert=false)

    rda_cmpfuns = read_rda("$testdir/data/cmpfun.rda",convert=false)
end
