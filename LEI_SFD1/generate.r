
# Generate synthetic data based on true.csv.
#
# Usage: generate_synthetic_data(...)
#
# Distributed under the BSD 3-Clause License
#
# Copyright (c) 2025, Lions Eye Institute
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# Andrew Turpin
# 25 August 2024

if (!file.exists("FT242.r"))
    stop("Could not find FT242.r needed to generate noise.")
if (!require(OPI))
    stopifnot("You should install.packages('OPI')")
source("FT242.r")

#
#' Read in true.csv and generate noisy data to `output_file`
#' @author Andrew Turpin
#' @date 25 August 2024
#'
#' @param seed Random number seed to use. (Note 1..102 is reserved for 'standard' datasets).
#' @param noise Type of noise to add to the data. One of "reliable", "unreliable", "realiable_gve", "unreliable_gve", "custom"
#'              If "custom" is specified, then values from `fpr`, `fnr` and `gve` are used.
#' @param stable If TRUE, use visit 10 field as true for all visits else use true.csv as is.
#' @param output_filename Name of output file
#' @param fpr False positive rate for visual field responses [0,1] if `noise` is "custom"
#' @param fpr False positive rate for visual field responses [0,1] if `noise` is "custom"
#' @param gve TRUE for global visit effect (GVE) noise, FALSE otherwise if `noise` is "custom"
#' @param true_input Filename of the true data from which to generate data
#'
#' @example
#' generate_synthetic_data(Sys.time(), noise = "reliable", stable = FALSE, output_filename = "reliable_1.csv")
generate_synthetic_data <- function(seed,
    noise = "reliable",
    stable = FALSE,
    output_filename = "synthetic.csv",
    fpr = NA, fnr = NA, gve = NA,
    true_input = "true.csv") {

    if (seed <= 102)
        warning(sprintf("Are you sure you want to use seed value %s in generate_synthetic_data()?
Seeds 1 to 102 are reserved to generate the data for standard datasets.", seed))

    set.seed(seed)

    d <- tryCatch(read.csv(true_input))

    if (inherits(d, "try-error"))
        stop(paste("Could not read", true_input, "in generate_synthetic_data()"))

    xys <- tryCatch(read.csv("xys.csv"))

    if (inherits(d, "try-error")) {
        stop("Could not read xys.csv in generate_synthetic_data()")
    }

    if (!require(OPI)) {
        print("Installing OPI package")
        install.packages("OPI")
        stopifnot(require(OPI))
    }

    if (noise == "reliable") {
        fpr <- 0.03 ; fnr <- 0.01 ; gve <- FALSE
    } else if (noise == "reliable_gve") {
        fpr <- 0.03 ; fnr <- 0.01 ; gve <- TRUE
    } else if (noise == "unreliable") {
        fpr <- 0.15 ; fnr <- 0.03 ; gve <- FALSE
    } else if (noise == "unreliable_gve") {
        fpr <- 0.15 ; fnr <- 0.03 ; gve <- TRUE
    } else if (noise == "custom") {
        stopifnot(!is.na(fpr) && fpr >= 0 && fpr <= 1)
        stopifnot(!is.na(fnr) && fnr >= 0 && fnr <= 1)
        stopifnot(!is.na(gve))
    } else {
        stop("Unknown noise type in generate_synthetic_data()")
    }

    if (stable) {
            # Replace visits 1..9 with visit 10
        for (i in seq_len(nrow(d))) {
            visit <- i %% 10   # visit 10 == 0
            if (visit == 0)
                next
            d[i, ] <- d[i + (10 - visit), ]
            d$visit[i] <- visit
        }
    }

        # If gve, choose a random visit for each eye to make TRUE, else FALSE
    d$gve <- FALSE
    if (gve)
        for (i in seq_len(nrow(d) / 10)) {
            gve_visit <- sample(1:10, 1)
            d$gve[(i - 1) * 10 + gve_visit] <- TRUE
        }

    result <- d
    result$gve <- NULL   # don't include gve flag in result: too tempting to use as a feature

    for (i in seq_len(nrow(d))) {
        if ((i - 1) %% 10 == 0)
            cat((i - 1) / 10 + 1, " ")
        result[i, paste0("oct.", c("T", "TS", "NS", "N", "NI", "TI"))] <-
            add_oct_noise(d[i, paste0("oct.", c("T", "TS", "NS", "N", "NI", "TI"))])

        tt <- unlist(d[i, paste0("vf.", 1:52)])
        mt <- add_vf_noise(tt, fpr, fnr, d$gve[[i]], xys)

        delta <- mt - tt
        result[i, paste0("td.", 1:52)] <- round(d[i, paste0("td.", 1:52)] + delta)
        result[i, paste0("vf.", 1:52)] <- mt
    }
    cat("\n")

    write.csv(result, file = output_filename, row.names = FALSE)
}

# VF noise (see datasheet.md)

#' @param vf A 52 element vector of visual field data
#' @param fpr False positive rate for visual field responses [0,1]
#' @param fnr False negative rate for visual field responses [0,1]
#' @param gve True to add GVE noise to VF, FALSE otherwise
#' @param xys A 52 row data.frame with columns 'index', 'x' and 'y'
#'
#' @return A 52 element vector of visual field data with noise added
#
add_vf_noise <- function(vf, fpr, fnr, gve, xys) {
    if (gve)
        vf <- vf + ifelse(runif(1) < 0.5, +2, -2)   # simple criteria shift by +-2 dB

    stopifnot(all(xys[xys$index == "vf.1", c("x", "y")] == c(-9, 21)))
    stopifnot(all(xys[xys$index == "vf.52", c("x", "y")] == c(+9, -21)))

    tt <- matrix(NA, nrow = 8, ncol = 9)
    rs <- 8 - (xys$y + 21) / 6   # assuming right eye
    cs <- (xys$x + 27) / 6  + 1
    for (i in seq_along(vf))
        tt[rs[i], cs[i]] <- vf[i]

    OPI::chooseOPI("SimHenson")
    OPI::opiInitialise(type = "C", cap = 6)

    res <- FT242("right", 25, tt, fpv = fpr, fnv = fnr)

    OPI::opiClose()

    mt <- unlist(t(res$th))   # need row-wise flattening
    z <- is.na(mt)
    return(mt[!z])
}

# OCT noise (see datasheet.md)


#         | Temporal |  TS  |   NS   |  Nasal  |    NI   |    TI    |
#         | -45:45   | 46:85| 86:125 | 126:235 | 236:275 | 276: 315 |
si <- list()
si$B.within  <- sqrt(6 * c(15, 17, 15, 17, 21, 15) / 100) * 2.2   # B = baseline
si$B.between <- sqrt(6 * c(10, 20, 14, 25, 28,  3) / 100) * 2.7
si$F.within  <- sqrt(6 * c(26, 13,  9, 24, 15, 13) / 100) * 0.79  # F = follow up
si$F.between <- sqrt(6 * c(12, 21, 16, 18, 25,  8) / 100) * 2.5

#' Given a vector of 6 elements, add some noise to it and return.
#' Allow for a floor of 40 microns.
#' Choice of smoothing window sizes are arbitrary based on our clinical experience.
#'
#' @param oct A 768 element vector of OCT cpRNFL data
#' @param visit number (1 for baseline, > 1 for other)
#'
#' @return A 768 element vector of OCT cpRNFL data with noise added
#
add_oct_noise <- function(oct, visit = 1) {
    if (visit > 1) {
        total <- si$F.within + si$F.between  # assume each visit is on a different day
    } else {
        total <- si$B.within + si$B.between  # assume each visit is on a different day
    }

    res <- sapply(1:6, \(s) rnorm(1, as.numeric(oct[s]), total[s]))   # N(0, 1) noise

    return(round(res))
}