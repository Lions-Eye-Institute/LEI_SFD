#
# Read in true.csv, take first as given and speed it forward.
# Use 40 microns and -1 dB as floors.
#
# Andrew Turpin
# Wed  8 Jan 2025 11:44:36 AWST


scale <- 4   # multiply both VF and RNFL slopes by this

d <- read.csv("../dataset_distro/true.csv")
dd <- d

vcols <- grep("vf", colnames(d))
tcols <- grep("td", colnames(d))
ocols <- grep("oct", colnames(d))

vis1 <- seq(1, nrow(d), 10)

    # slopes[eye 1..202, column]
slopes <- (d[vis1 + 9, ] - d[vis1, ]) / 10 # */visit
slopes <- slopes * scale
slopes[, 1] <- 0   # id
slopes[, 2] <- +1  # visit num

for (i_eye in 1:202) {
    cat(i_eye, " ")
    for (visit in 2:10) {
        rr <- vis1[i_eye] + visit - 1
        d[rr, ] <- d[rr - 1, ] + slopes[i_eye, ]

            # Floor VF at -1 dB
        z <- d[rr, vcols] <= -0.5
        if (any(z)) {
            d[rr, vcols[z]] <- -1
            d[rr, tcols[z]] <- d[rr - 1, tcols[z]] + (d[rr, vcols[z]] - d[rr - 1, vcols[z]])
        }

            # floor OCT at 40 and round
        z <- d[rr, ocols] < 40
        if (any(z))
            d[rr, ocols[z]] <- 40
    }
}

write.csv(d, sprintf("true_scale%s.csv", scale), row.names = FALSE)