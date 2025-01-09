
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
#' @param seed Random number seed to use. (Note 1..8 was used to generate 'standard' datasets).
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

    if (seed <= 12)
        warning(sprintf("Are you sure you want seed value %s in generate_synthetic_data().
Seeds 1 to 12 were used to generate the data in the standard distribution.", seed))

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
        result[i, paste0("oct.", 1:768)] <- add_oct_noise(d[i, paste0("oct.", 1:768)])

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

    mt <- unlist(res$th)
    z <- is.na(mt)
    return(mt[!z])
}

# OCT noise (see datasheet.md)

#' @param d A vector of 768 values
#' @param winSize The size of the sliding window in pixels (should be odd, > 1)
#'
#' @return Vector of 768 values which is RNFLT.x from rr smoothed with a sliding mean
#'
sliding_mean <- function(d, winSize = 61) {
    stopifnot(winSize > 1)
    stopifnot(winSize %% 2 == 1)   # should be odd
    stopifnot(length(d) >= (winSize - 1) / 2)

    winSize <- floor(winSize / 2)

    n <- length(d)
    d <- as.numeric(c(tail(d, winSize), d, head(d, winSize)))

    sapply(winSize + seq_len(n), function(i) mean(d[-winSize:winSize + i]))
}

#         | Temporal |  TS  |   TI   |  Nasal  |    NS   |    NI    |
#         | -45:45   | 46:85| 86:125 | 126:235 | 236:275 | 276: 315 |
si <- list()
si$B.within  <- sqrt(6 * c(15, 17, 15, 17, 21, 15) / 100) * 2.2   # B = baseline
si$B.between <- sqrt(6 * c(10, 20, 14, 25, 28,  3) / 100) * 2.7
si$F.within  <- sqrt(6 * c(26, 13,  9, 24, 15, 13) / 100) * 0.79  # F = follow up
si$F.between <- sqrt(6 * c(12, 21, 16, 18, 25,  8) / 100) * 2.5

                                #  T            TS     NS      N        NI       TI
oct_sector_indices <- list(c(1:96, 671:768), 97:181, 182:266, 267:500, 501:585, 586:670)

#' Given a vector of 768 elements, add some noise to it and return.
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

    noise <- rnorm(768)   # N(0, 1) noise
    for (sector in 1:6) {
        ii <- oct_sector_indices[[sector]]
        noise[ii]  <- noise[ii] * total[sector] * sqrt(length(ii))  # now N(0, 4.9 or 3.29) noise spread over sectors
    }

    res <- oct + sliding_mean(noise, 151)   # 150 pixels ~ 70 degrees

    z <- res < 40
    noise[z] <- pmax(30, rnorm(sum(z), 40, ifelse(visit > 1, 2, 5))) - oct[z]  # we will add the oct back...

    res <- oct + sliding_mean(noise, 151)   # 150 pixels ~ 70 degrees

    return(round(res))
}

# Test sector-mean stats of OCT noise roughly match Schrems-Hoesl et al. 2018
test <- function() {
    get_sector_means <- function(d) {
        t(apply(d, 1, function(rr) unlist(lapply(oct_sector_indices, function(ii) mean(rr[ii])))))
    }

    get_sector_sds <- function(d) {
        t(apply(d, 1, function(rr) unlist(lapply(oct_sector_indices, function(ii) sd(rr[ii])))))
    }

    get_pixel_sds <- function(d) t(apply(d, 2, function(rr) sd))

    for (visit in 1:2) {
        noise <- t(sapply(1:5000, function(i) add_oct_noise(rep(0, 768), visit)))
        ms <- get_sector_means(noise)
        ssds <- sapply(1:5000, function(i) {
            rr <- sample(seq_len(nrow(ms)), 50 * 6, replace = TRUE)
            sd(ms[rr, ])
        })
        m <- mean(ssds)
        s <- diff(quantile(ssds, p = c(0.025, 0.975)))
        tm <- ifelse(visit == 1, 2.2 + 2.7, 0.79 + 2.5)
        ts <- ifelse(visit == 1, 0.3 + 0.4, 0.1 + 0.3)
        cat(sprintf("%6s Visit= %1.0f m_sd = %4.2f ~ %4.2f , sd_cr = %6.3f ~ %6.3f\n",
            abs(m - tm) < 0.05 && abs(s - ts) < 0.05,
            visit, m, tm, s, ts))
    }
}

    # plot true and generated OCT noise for checking by eye
test2 <- function() {
    d <- read.csv("true.csv")

    pdf("noisy_oct.pdf", width = 16, height = 9)
    options(error = dev.off)

    for (pat in seq(1, nrow(d) / 10)) {
        cat(pat, " ")
        i_rows <- (pat - 1) * 10 + 1:10

        matplot(1:768 / 768 * 360, sapply(i_rows, function(i_row) {
            add_oct_noise(d[i_row, paste0("oct.", 1:768)])
        }), type = "l", las = 1, ylab = "microns", ylim = c(20, 220),
        xlab = "TSNIT (degrees)")
        title(paste("Patient", pat))

        lines(1:768 / 768 * 360, d[i_rows[[1]], paste0("oct.", 1:768)], lwd = 3)
        abline(h = 40, lty = 2)
        abline(h = seq(10, 300, by = 10), col = grey(0.8))
    }
    cat("\n")

    dev.off()
    options(error = NULL)
}

    # test the sliding mean function
test3 <- function() {
    library(testthat)
    test_that("sliding_mean", {
        expect_error(sliding_mean(1:10, 1), label = "winSize <= 1")
        expect_error(sliding_mean(1:10, 2), label = "winSize should be odd")
        expect_error(sliding_mean(1:5, 13), label = "length(d) > winSize / 2")
        expect_equal(sliding_mean(1:3, 3), c(2, 2, 2))
    })
}

    # Test VF noise generation
test4 <- function() {
    xys <- tryCatch(read.csv("xys.csv"))

    a <- sapply(0:40, function(mt) add_vf_noise(rep(mt, 100), 0.00, 0.00, FALSE, xys))

    d <- read.csv("true.csv")
    mt <- add_vf_noise(ys <- unlist(d[1, paste0("vf.", 1:52)]), 0.00, 0.00, FALSE, xys)

    plot(ys + runif(length(ys), -0.1, 0.1), mt, las = 1, xlab = "input", ylab = "output", pch = 19, col = grey(0.5, 0.5))
    abline(0, 1)
    title("true input jittered a little for plot")

    print(table(round(mt)))
    print(table(round(mt - ys)))
}
