#' Generate resamples
#' @param x a data frame that can be coerced into a \code{\link[dplyr]{tbl_df}}
#' @param reps the number of resamples to generate
#' @param type currently either \code{bootstrap} or \code{permute}
#' @param ... currently ignored
#' @importFrom dplyr group_by
#' @export
#' @examples 
#' 
#' # bootstrap for one numerical variable
#' if (require(dplyr)) {
#'   mtcars %>%
#'     select(mpg) %>%
#'     generate(reps = 100, type = "bootstrap") %>%
#'     calculate(stat = "mean")
#'     
#'  # permutation test for equal means
#'   mtcars %>% 
#'     select(mpg, am) %>%
#'     hypothesize(null = "equal means") %>%
#'     generate(reps = 100, type = "permute") %>%
#'     calculate(stat = "diff in means")
#'  
#'  # simulate draws from a single categorical variable
#'  mtcars %>% 
#'    select(am) %>%
#'    mutate(am = factor(am)) %>%
#'    hypothesize(null = "point", p1 = 0.25, p2 = 0.75) %>%
#'    generate(reps = 100, type = "simulate") %>%
#'    calculate(stat = "prop")
#'    
#'  # goodness-of-fit for one categorical variable
#'  mtcars %>%
#'    select(cyl) %>%
#'    hypothesize(null = "point", p1 = .25, p2 = .25, p3 = .50) %>%
#'    generate(reps = 100, type = "simulate") %>%
#'    calculate(stat = "chisq")
#' }
#' 

generate <- function(x, reps = 1, type = "bootstrap", ...) {
  if (type == "bootstrap") {
    return(bootstrap(x, reps, ...))
  }
  if (type == "permute") {
    return(permute(x, reps, ...))
  }
  if (type == "simulate") {
    return(simulate(x, reps, ...))
  }
  x
}

bootstrap <- function(x, reps = 1, ...) {
  rep_sample_n(x, size = nrow(x), replace = TRUE, reps = reps)
}

#' @importFrom dplyr bind_rows mutate_ group_by

permute <- function(x, reps = 1, ...) {
  df_out <- replicate(reps, permute_once(x), simplify = FALSE) %>%
    dplyr::bind_rows() %>%
    dplyr::mutate_(replicate = ~rep(1:reps, each = nrow(x))) %>%
    dplyr::group_by(replicate)
  attr(df_out, "null") <- attr(x, "null")
  return(df_out)
}

permute_once <- function(x, ...) {
  dots <- list(...)

  if (attr(x, "null") == "equal means") {
    ## need to look for name of variable to permute...ugh
    ## by default, use the first column
    # y <- x[, 1]
    ## Hopefully this fixes that
    num_cols <- sapply(x, is.numeric)
    num_name <- names(num_cols[num_cols == TRUE])
    y <- x[[num_name]]

    y_prime <- y[ sample.int(length(y)) ]
    x[[num_name]] <- y_prime
    return(x)
  }

  if (attr(x, "null") == "independence") {
    ## by default, permute the first column of the two selected
    # Since dealing with tibble potentially, we need to force a
    # vector here
    y <- x[[1]]

    y_prime <- y[ sample.int(length(y)) ]
    x[[1]] <- y_prime
    return(x)
  }

}

#' @importFrom dplyr pull

simulate <- function(x, reps = 1, ...) {
  # error
  if (ncol(x) > 1 | class(dplyr::pull(x, 1)) != "factor") {
    stop("Simulation can only be performed for a single categorical variable.")
  }
  
  rep_sample_n(x, size = nrow(x), reps = reps, replace = TRUE, prob = unlist(attr(x, "params")))
}

#' @importFrom dplyr as_tibble pull

# Modified oilabs::rep_sample_n() with attr added
rep_sample_n <- function(tbl, size, replace = FALSE, reps = 1, prob = NULL) {
  # attr(tbl, "ci") <- TRUE
  n <- nrow(tbl)
  
  # assign non-uniform probabilities
  # there should be a better way!!
  # prob needs to be nrow(tbl) -- not just number of factor levels
  if (!is.null(prob)) {
    df_lkup <- data_frame(vals = levels(dplyr::pull(tbl, 1)))
    names(df_lkup) <- names(tbl)
    df_lkup$probs = prob
    tbl_wgt <- inner_join(tbl, df_lkup)
    prob <- tbl_wgt$probs
  }
  
  i <- unlist(replicate(reps, sample.int(n, size, replace = replace, prob = prob),
                        simplify = FALSE))
  rep_tbl <- cbind(replicate = rep(1:reps, rep(size, reps)),
                   tbl[i, ])
  rep_tbl <- dplyr::as_tibble(rep_tbl)
  names(rep_tbl)[-1] <- names(tbl)
  #  attr(rep_tbl, "ci") <- attr(tbl, "ci")
  dplyr::group_by(rep_tbl, replicate)
}