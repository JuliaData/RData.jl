# R script to generate test .rda and .rds files
sys_tz = Sys.getenv("TZ") # remember System TimeZone

df <- data.frame(num = c(1.1, 2.2))
save(df, file = "data/minimal.rda")
save(df, file = "data/minimal_ascii.rda", ascii = TRUE)

df["int"] <- c(1L, 2L)
df["logi"] <- c(TRUE, FALSE)
df["chr"] <- c("ab", "c")
df["factor"] <- factor(df$chr)
df["cplx"] <- complex( real = c(1.1, 0.0), imaginary = c(0.5, 1.0) )
#utf<-c("Ж", "∰")) R handles it, RData doesn"t.
save(df, file = "data/types.rda")
save(df, file = "data/types_ascii.rda", ascii = TRUE)
saveRDS(df, file = "data/types.rds")
saveRDS(df, file = "data/types_ascii.rds", ascii = TRUE)
saveRDS(df, file = "data/types_decomp.rds", compress = FALSE)

df[2, ] <- NA
df[3, ] <- df[2, ]
df[3, "num"] <- NaN
df[, "cplx"] <- complex( real = c(1.1, 1, NaN), imaginary = c(NA, NaN, 0) )
save(df, file = "data/NAs.rda")
save(df, file = "data/NAs_ascii.rda", ascii = TRUE)

names(df) <- c("end", "!", "1", "%_B*\tC*", NA, "x")
save(df, file = "data/names.rda")
save(df, file = "data/names_ascii.rda", ascii = TRUE)

empty.env <- new.env(parent = emptyenv())
empty_nohash.env <- new.env(parent = emptyenv())
empty_child.env <- new.env(parent = empty.env)
a.env <- new.env(parent = emptyenv())
assign( "a", 43, envir = a.env )
b.env <- new.env(parent = a.env)
assign( "b", 48, envir = b.env )
save(empty.env, empty_nohash.env, empty_child.env, a.env, b.env,
     file = "data/envs.rda")

pl.empty <- pairlist()
pl <- pairlist( u = 1L, x = c(2.0, 3.0), y = "A", NULL, z = TRUE )
save(pl.empty, pl, file = "data/pairlists.rda")

test.fun0 <- function() return(NULL)
test.fun1 <- function(x) return(x + 1)
test.fun2 <- function(x, y) x + y
save(test.fun0, test.fun1, test.fun2, file = "data/closures.rda")

require(compiler)
test.cmpfun0 <- cmpfun( test.fun0 )
test.cmpfun1 <- cmpfun( test.fun1 )
test.cmpfun2 <- cmpfun( test.fun2 )
save(test.cmpfun0, test.cmpfun1, test.cmpfun2, file = "data/cmpfun.rda")

x <- factor(c("a", "b", "c"))
y <- ordered(x, levels=c("b", "a", "c"))
save(x, y, file="data/ord.rda")

dates = as.Date("2017-01-01") + 1:4
datetimes = as.POSIXct("2017-01-01 13:23", tz="UTC") + 1:4
dateNAs = list(c(dates, NA), c(datetimes, NA))
saveRDS(dateNAs, file="data/datesNA.rds")
datelst = list(dates, dates[1])
names(dates) = LETTERS[1:length(dates)]
datelst = c(datelst, list(dates), list(dates[1]))
saveRDS(datelst, file="data/dates.rds")
dtlst = list(datetimes, datetimes[1])
names(datetimes) = LETTERS[1:length(datetimes)]
dtlst = c(dtlst, list(datetimes), list(datetimes[1]))
saveRDS(dtlst, file="data/datetimes.rds")
datedfs = list(data.frame(date=dates[1], datetime=datetimes[1]),
               data.frame(date=dates, datetime=datetimes))
saveRDS(datedfs, file="data/datedfs.rds")

# the first element here is assumed to be in the local timezone but is saved in
# UTC time, without any timezone attribute. When R reads it, it assumes local time.
# So the test associated with this first datapoint is going to assume which timezone
# the data is generated in! (PST/-8)
Sys.setenv(TZ = "America/Los_Angeles")
saveRDS(list(as.POSIXct("2017-01-01 13:23"),
             as.POSIXct("2017-01-01 13:23", tz="CST"),
             as.POSIXct("2017-01-01 13:23", tz="America/Chicago")),
        file="data/datetimes_tz.rds")
Sys.setenv(TZ = sys_tz) # restore timezone
