# R script to generate test .rda and .rds files
if ((as.integer(version$major) < 3) ||
    ((as.integer(version$major) == 3) && (as.integer(substr(version$minor, 1, 1)) < 5))) {
    stop("Script requires R>=3.5 to generate RData version 2 and 3")
}
sys_tz = Sys.getenv("TZ") # remember System TimeZone

for (ver in c(2, 3)) {
message("Generating RData/RDS files (version=", ver, ")...")

df <- data.frame(num = c(1.1, 2.2))
rdata_path <- paste0("data_v", ver)
save(df, file=file.path(rdata_path, "minimal.rda"), version=ver)
save(df, file=file.path(rdata_path, "minimal_ascii.rda"), version=ver, ascii=TRUE)

df["int"] <- c(1L, 2L)
df["logi"] <- c(TRUE, FALSE)
df["chr"] <- c("ab", "c")
df["factor"] <- factor(df$chr)
df["cplx"] <- complex( real = c(1.1, 0.0), imaginary = c(0.5, 1.0) )
#utf<-c("Ж", "∰")) R handles it, RData doesn"t.
save(df, file=file.path(rdata_path, "types.rda"), version=ver)
save(df, file=file.path(rdata_path, "types_ascii.rda"), version=ver, ascii=TRUE)
saveRDS(df, file=file.path(rdata_path, "types.rds"), version=ver)
saveRDS(df, file=file.path(rdata_path, "types_ascii.rds"), version=ver, ascii=TRUE)
saveRDS(df, file=file.path(rdata_path, "types_decomp.rds"), version=ver, compress=FALSE)

df[2, ] <- NA
df[3, ] <- df[2, ]
df[3, "num"] <- NaN
df[, "cplx"] <- complex( real = c(1.1, 1, NaN), imaginary = c(NA, NaN, 0) )
save(df, file=file.path(rdata_path, "NAs.rda"), version=ver)
save(df, file=file.path(rdata_path, "NAs_ascii.rda"), version=ver, ascii=TRUE)

names(df) <- c("end", "!", "1", "%_B*\tC*", NA, "x")
save(df, file=file.path(rdata_path, "names.rda"), version=ver)
save(df, file=file.path(rdata_path, "names_ascii.rda"), version=ver, ascii=TRUE)

empty.env <- new.env(parent = emptyenv())
empty_nohash.env <- new.env(parent = emptyenv())
empty_child.env <- new.env(parent = empty.env)
a.env <- new.env(parent = emptyenv())
assign( "a", 43, envir = a.env )
b.env <- new.env(parent = a.env)
assign( "b", 48, envir = b.env )
save(empty.env, empty_nohash.env, empty_child.env, a.env, b.env,
     file=file.path(rdata_path, "envs.rda"), version=ver)

pl.empty <- pairlist()
pl <- pairlist(u = 1L, x = c(2.0, 3.0), y = "A", NULL, z = TRUE )
save(pl.empty, pl, file=file.path(rdata_path, "pairlists.rda"), version=ver)

test.fun0 <- function() return(NULL)
test.fun1 <- function(x) return(x + 1)
test.fun2 <- function(x, y) x + y
save(test.fun0, test.fun1, test.fun2,
     file=file.path(rdata_path, "closures.rda"), version=ver)

require(compiler)
test.cmpfun0 <- cmpfun(test.fun0)
test.cmpfun1 <- cmpfun(test.fun1)
test.cmpfun2 <- cmpfun(test.fun2)
save(test.cmpfun0, test.cmpfun1, test.cmpfun2,
     file=file.path(rdata_path, "cmpfun.rda"), version=ver)

x <- factor(c("a", "b", "c"))
y <- ordered(x, levels=c("b", "a", "c"))
save(x, y, file=file.path(rdata_path, "ord.rda"), version=ver)

numdates <- as.Date(as.numeric(1:4), origin="2017-01-01")
intdates <- seq.Date(as.Date("2017-01-02"), by="day", length.out=4)
if (typeof(intdates) != "integer") stop("intdates are not integer-backed dates: ", typeof(intdates))
datetimes <- as.POSIXct("2017-01-01 13:23", tz="UTC") + 1:4

dateNAs = list(c(numdates, NA), c(datetimes, NA))
saveRDS(dateNAs, file=file.path(rdata_path, "datesNA.rds"), version=ver)

saveRDS(numdates, file=file.path(rdata_path, "numdates.rds"), version=ver)
saveRDS(intdates, file=file.path(rdata_path, "intdates.rds"), version=ver)
saveRDS(numdates, file=file.path(rdata_path, "numdates_ascii.rds"), version=ver, ascii=TRUE)
saveRDS(intdates, file=file.path(rdata_path, "intdates_ascii.rds"), version=ver, ascii=TRUE)

dtlst = list(datetimes, datetimes[1])
names(datetimes) = LETTERS[1:length(datetimes)]
dtlst = c(dtlst, list(datetimes), list(datetimes[1]))
saveRDS(dtlst, file=file.path(rdata_path, "datetimes.rds"), version=ver)

datedfs = list(data.frame(date=numdates[1], datetime=datetimes[1]),
               data.frame(date=numdates, datetime=datetimes))
saveRDS(datedfs, file=file.path(rdata_path, "datedfs.rds"), version=ver)

# the first element here is assumed to be in the local timezone but is saved in
# UTC time, without any timezone attribute. When R reads it, it assumes local time.
# So the test associated with this first datapoint is going to assume which timezone
# the data is generated in! (PST/-8)
Sys.setenv(TZ = "America/Los_Angeles")
saveRDS(list(as.POSIXct("2017-01-01 13:23"),
             as.POSIXct("2017-01-01 13:23", tz="CST"),
             as.POSIXct("2017-01-01 13:23", tz="America/Chicago")),
        file=file.path(rdata_path, "datetimes_tz.rds"), version=ver)
Sys.setenv(TZ = sys_tz) # restore timezone

# Importing data frame attributes as defined by common packages to metadata

# Column-level attributes used by packages haven, labelled and sjlabelled
# Generating code:
# library(haven)
# v1 <- labelled(c(1, 2, 2, 3, NA, 1), label="V1", labels=c(a=1, b=2, c=3))
# v2 <- labelled_spss(c(1, 2, 2, 3, NA, 1), label="V2", labels=c(a=1, b=2, c=3),
#                     na_values=3)
# v3 <- labelled_spss(c(1, 2, 2, 3, NA, 1), label="V3", labels=c(a=1, b=2, c=3),
#                     na_range=c(3, Inf))
v1 <- structure(c(1, 2, 2, 3, NA, 1), labels=c(a=1, b=2, c=3), label="V1",
                class="numeric")
v2 <- structure(c(1, 2, 2, 3, NA, 1), labels=c(a=1, b=2, c=3), label="V2",
                na_values=3, class="numeric")
v3 <- structure(c(1, 2, 2, 3, NA, 1), labels=c(a=1, b=2, c=3), label="V3",
                na_range=c(3, Inf), class="numeric")

# Column-level attributes used by packages Hmisc, units and labelVector
# (plus `comment` from base R and some custom attributes)
# Generating code:
# library(Hmisc)
# v4 <- c(1, 2, 2, 3, NA, 1)
# label(v4) <- "V4"
# comment(v4) <- "A comment"
# units(v4) <- "m/s^2"
# attr(v4, "custom") <- 1
v4 <- structure(c(1, 2, 2, 3, NA, 1), label="V4", class="numeric",
                comment="A comment", units="m/s^2", custom=1)

# Data frame-level attributes
df <- data.frame(v1, v2, v3, v4)
comment(df) <- "This is a data frame"
attr(df, "collectiontimes") <- c(as.POSIXct("2022-05-25 22:05:00", tz="UTC"),
                                 as.POSIXct("2022-05-26 22:05:00", tz="UTC"))

savedotdotdot <- function(...) {
     dotdotdot <- get("...", environment())
     save(dotdotdot, file=file.path(rdata_path, "dotdotdot.rda"), version=ver)
}
savedotdotdot(1,2,3)

expr <- parse(text="a+b\nx+2")
save(expr, file=file.path(rdata_path, "expr.rda"), version=ver)

} # for (ver in ...)

# generate V3 format AltRep objects
longseq <- 1:1000 # compact_intseq AltRep
wrapvec <- .Internal(wrap_meta(c(1, 2.5, 3), TRUE, TRUE)) # wrap_real AltRep

 # AltRep for factor (long enough vector is represented as AltRep)
factoraltrep <- rep(factor(c("A", "B", NA_character_, "C")), each=5000)

# wrap_real AltRep of a matrix contains non-standard pairlist that doesn't end with NILVALUE_SXP
nonnilpairlist <- .Internal(wrap_meta(matrix(integer(), nrow=0, ncol=10), TRUE, TRUE))

save(longseq, wrapvec, factoraltrep, nonnilpairlist,
     file=file.path("data_v3", "altrep.rda"), version=3)
save(longseq, wrapvec, factoraltrep, nonnilpairlist,
     file=file.path("data_v3", "altrep_ascii.rda"), version=3, ascii=TRUE, compress=TRUE)

# for wide data frame (100 columns or more) R 3.5 *sometimes* uses AltRep to store the column names
altrepnames_list <- as.list(c(1, 2, 3))
names(altrepnames_list) <- .Internal(wrap_meta(c("a", "b", "c"), TRUE, TRUE))
altrepnames_df <- as.data.frame(altrepnames_list)
names(altrepnames_df) <- names(altrepnames_list)
save(altrepnames_list, altrepnames_df, file=file.path("data_v3", "altrep_names.rda"), version=3)

# list of vectors variable and list of vectors column (for #82)
listofvec <- list(c(1, 2, NA), c(3, 4), c(5, 6, NA))
listofvec2 <- list(c(1L, 2L, NA), c(3, 4), c(5, 6, NA))
listofvec3 <- list(c(1L, 2L), c(3, 4))
listofvec4 <- list(c(1, 2), c(3, 4,5))
namedlistofvec <- list(A=c(1, 2, NA), c(3, 4), B=c(5, 6, NA))
testdf <- data.frame(a = c("a", "b", "c"))
testdf$listascol <- list(c(1, 2, NA), c(3, 4), c(5, 6, NA, 7))
testdf$listascol2 <- list(c(1, 2), c(3L, 4L), c(5, 6, 7))
for (rdaver in c(2L, 3L)) {
    save(listofvec, listofvec2, listofvec3, listofvec4, namedlistofvec, testdf,
         file=file.path(paste0("data_v", rdaver), "list_of_vec.rda"), version=rdaver)
}

# compact_xxxseq
intseq1 <- 5L:200L
intseq2 <- seq.int(-2L, 1000L, 2L)
realseq1 <- 110:300
realseq2 <- seq(110.5, 300.5)
realseq3 <- seq(110, 300, by=0.5)
save(intseq1, intseq2, realseq1, realseq2, realseq3, file=file.path("data_v3", "compact_seq.rda"), version=3)

# generate files using each of the supported compression types
df <- data.frame(num = c(1.1, 2.2))
rdata_path <- "data_v3"
save(df, file=file.path(rdata_path, "compressed_gzip.rda"), version=3, compress="gzip")
save(df, file=file.path(rdata_path, "compressed_bzip2.rda"), version=3, compress="bzip2")
save(df, file=file.path(rdata_path, "compressed_xz.rda"), version=3, compress="xz")
save(df, file=file.path(rdata_path, "compressed_false.rda"), version=3, compress=FALSE)
