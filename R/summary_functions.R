#' Provide percent coverage of package
#'
#' Print the total percent coverage
#' @param x the coverage object returned from \code{\link{package_coverage}}
#' @param ... additional arguments passed to \code{\link{tally_coverage}}
#' @export
percent_coverage <- function(x, ...) {
  res <- tally_coverage(x, ...)

  (sum(res$value > 0) / length(res$value)) * 100
}

#' Tally coverage by line or expression
#'
#' @inheritParams percent_coverage
#' @param by whether to tally coverage by line or expression
#' @export
tally_coverage <- function(x, by = c("line", "expression")) {
  df <- as.data.frame(x)

  by <- match.arg(by)

  switch(by,
         "line" = {

           # aggregate drops all NA's in grouping variables using
           # complete.cases, so we have to temporary convert the NA's to
           # regular characters and then back
           na2char <- function(x) {
             x[is.na(x)] <- "NA_character_"
             x
           }
           char2na <- function(x) {
             x[x == "NA_character_"] <- NA_character_
             x
           }

           df$functions <- na2char(df$functions)
           res <- aggregate(value ~ filename + functions + first_line,
                                    data = df, FUN = sum, na.action = na.pass)
           res$functions <- char2na(res$functions)
           res
         },

         "expression" = df
         )
}

#' Provide locations of zero coverage
#'
#' When examining the test coverage of a package, it is useful to know if there are
#' any locations where there is \bold{0} test coverage.
#'
#' @param x a coverage object returned \code{\link{package_coverage}}
#' @param ... additional arguments passed to
#' \code{\link{tally_coverage}}
#' @details if used within Rstudio this function outputs the results using the
#' Marker API.
#' @export
zero_coverage <- function(x, ...) {
  if (getOption("covr.rstudio_source_markers", TRUE) &&
      rstudioapi::hasFun("sourceMarkers")) {
    markers(x)
    invisible(x)
  } else {

    coverage_data <- tally_coverage(x, ...)

    coverage_data[coverage_data$value == 0,

                  # need to use %in% rather than explicit indexing because
                  # tally_coverage returns a df without the columns if
                  # by = "line"
                  colnames(coverage_data) %in%
                    c("filename",
                      "functions",
                      "first_line",
                      "last_line",
                      "first_column",
                      "last_column",
                      "value")]
  }
}

#' Print a coverage object
#'
#' @param x the coverage object to be printed
#' @param group whether to group coverage by filename or function
#' @param by whether to count coverage by line or expression
#' @param ... additional arguments ignored
#' @export
print.coverage <- function(x, group = c("filename", "functions"), by = "line", ...) {

  group <- match.arg(group)

  type <- attr(x, "type")

  if (is.null(type) || type == "none") {
    type <- NULL
  }

  df <- tally_coverage(as.data.frame(x), by = by)

  if (!NROW(df)) {
    return(invisible())
  }

  percents <- tapply(df$value, df[[group]], FUN = function(x) (sum(x > 0) / length(x)) * 100)

  overall_percentage <- percent_coverage(df, by = by)

  message(crayon::bold(
      paste(collapse = " ",
        c(attr(x, "package")$package, to_title(type), "Coverage: "))),
    format_percentage(overall_percentage))

  by_coverage <- percents[order(percents,
      names(percents))]

  for (i in seq_along(by_coverage)) {
    message(crayon::bold(paste0(names(by_coverage)[i], ": ")),
      format_percentage(by_coverage[i]))
  }
  invisible(x)
}

#' @export
print.coverages <- function(x, ...) {
  for(i in seq_along(x)) {
    # Add a blank line between consecutive coverage items
    if (i != 1) {
      message()
    }
    print(x[[i]], ...)
  }
  invisible(x)
}

format_percentage <- function(x) {
  color <- if (x >= 90) crayon::green
    else if (x >= 75) crayon::yellow
    else crayon::red

  color(sprintf("%02.2f%%", x))
}

markers <- function(x, ...) UseMethod("markers")

markers.coverages <- function(x, ...) {
  mrks <- unlist(lapply(unname(x), markers), recursive = FALSE)

  mrks <- mrks[order(
    vapply(mrks, `[[`, character(1), "file"),
    vapply(mrks, `[[`, integer(1), "line"),
    vapply(mrks, `[[`, character(1), "message")
    )]

  # request source markers
  rstudioapi::callFun("sourceMarkers",
                      name = "covr",
                      markers = mrks,
                      basePath = NULL,
                      autoSelect = "first")
  invisible()
}
markers.coverage <- function(x, ...) {

  # generate the markers
  markers <- lapply(unname(x), function(xx) {
    filename <- getSrcFilename(xx$srcref, full.names = TRUE)

    list(
      type = "warning",
      file = filename,
      line = xx$srcref[1],
      column = xx$srcref[2],
      message = sprintf("No %s Coverage!", to_title(attr(x, "type")))
    )
  })

}
