#
# Implements
#   procedureWithGrowthPattern() which allows a general
#     thresholding procedure to be run with a growth pattern where a
#     subset of locations must finish before the next subset begins
#     (eg as in the HFA I, II and III), the locations can be modelled as
#     a regular cartesian grid, and related locations must be adjacent
#     in the grid.
#
#     The procedure is controlled by a growth pattern matrix, and
#     requires a matrix of guesses for the first subset of locations,
#     and functions to start, step, test-for-stop, and get-final-threshold
#     for the procedure. See comments and Zest242.r for an example.
#
#   procedureWithGeneralGrowthPattern which is as for procedureWithGrowthPattern(),
#     but allows for a general graph describing relationships between
#     locations (not just a cartesian grid). The relationships are
#     defined as an adjacency list of edges. This works on location numbers
#     only, the physical location of the location numbers in the VF
#     is left to the caller. Assumes minimum location number is 1.
#
# Author: Andrew Turpin
# Date: Mon 27 May 2013 18:23:57 EST
#
# Modified Wed 28 Sep 2016: added procedureWithGeneralGrowthPattern()
#

####################################################################
# Use startFun, stepFun and stopFun to run all locations with number
# 1 in the growthPattern, then number 2 (using the ones to set prior),
# then number 3, using the 1s and 2s, and so on until locations
# max(growthPattern) are done.
# After each location finishes, use finalFun to get threshold and num pres.
# Within each subset of locations with the same growth pattern number,
# locations are presented in random order.
#
# INPUTS:
#   gp  - growth pattern matrix (min(gp) == 1)
#   ops - matrix same size as gp giving start values for gp==1
#   startFun - function(guess, rw, cl) that creates a state for
#              location (rw, cl) in gp using guess as start guess
#   stepFun  - function(state) returns a new state after one presentation
#   stopFun  - function(state) returns TRUE if location finished
#   finalFun - function(state) returns c(final threshold, number presentations)
#
# RETURNS: list of two matrices, each with same dimensions as gp
#           t is final threshold at each location
#           n is number of presentations at each location
####################################################################
procedureWithGrowthPattern <- function(gp, ops, startFun, stepFun, stopFun, finalFun) {

    ####################################################################
    # Average all immediate 9 neighbours that have num less than "wave"
    #
    # INPUTS
    #   gp   - growth Pattern matrix
    #   wave - integer wave number
    #   rw   - row of location
    #   cl   - column of location
    #   currT - matrix of current thresholds (if wave == 1 then these should
    #                               have starting guesses for the 1 locations)
    #
    # RETURNS: start guess for location (rw, cl) which is average of
    #          neighbours that are less than "wave" in "gp"
    ####################################################################
    makeGuess <- function(gp, wave, rw, cl, currT) {
        if (wave == 1)
            return(currT[rw, cl])

        n <- summ <- 0
        for (ii in -1:1)
        for (jj in -1:1)
        if (ii != 0 || jj != 0) {
            trow <- rw + ii
            tcol <- cl + jj
            if (all(c(trow, tcol)) > 0 &&
                trow <= nrow(gp)       &&
                tcol <= ncol(gp)       &&
                !is.na(gp[trow, tcol]) &&
                gp[trow, tcol] < wave) {
                    summ <- summ + currT[trow, tcol]
                    n <- n + 1
            }
        }

        if (n == 0)
            warning(paste("Could not find neighbour for", rw, cl))

        return(summ / n)
    }

        # set up answers
    currentThresholds <- ops  # cheat and start them at ops
    currentNumPres    <- matrix(NA, nrow(gp), ncol(gp))

        # Give each (row, col) a unique number map[row, col]
    map <- gp
    numLoc <- 1
    for (i in seq_len(nrow(map)))
        for (j in seq_len(ncol(map)))
            if (!is.na(gp[i, j])) {
                map[i, j] <- numLoc
                numLoc <- numLoc + 1
            }

    states <- vector("list", numLoc - 1)  # indexed by map[row,col]

        # Now loop finishing 1s, start rest, etc
    wave <- 1
    while (wave <= max(gp, na.rm = TRUE)) {
            # Create a state for each "wave" location
            # and step it until done
        locs <- which(gp == wave, arr.ind = TRUE)
        locsToGo <- seq_len(nrow(locs))
        while (length(locsToGo) > 0) {
            i <- locsToGo[runif(1, min = 1, max = length(locsToGo))]
            rw <- locs[i, 1]
            cl <- locs[i, 2]
            index <- map[rw, cl]

            if (is.null(states[[index]]))
                states[[index]] <- startFun(makeGuess(gp, wave, rw, cl, currentThresholds), rw, cl)

            states[[index]] <- stepFun(states[[index]])

            if (stopFun(states[[index]])) {
                    # fill in currentThresholds and remove from locs
                currentThresholds[rw,cl] <- finalFun(states[[index]])[1]
                currentNumPres[rw,cl]    <- finalFun(states[[index]])[2]
                locsToGo <- locsToGo[-which(locsToGo == i)]
            }
        }
        wave <- wave + 1
    }

    return(list(t = currentThresholds, n = currentNumPres))
}# procedureWithGrowthPattern()



####################################################################
# Use startFun, stepFun and stopFun to run all locations in starters,
# and as soon as one finishes, say i, open up locations parents[[i]]
# for presentations too using the threshold at i as the prior.
# After each location finishes, use finalFun to get threshold and num pres.
# Within each subset of locations with the same growth pattern number,
# locations are presented in random order.
#
# INPUTS:
#   starters - vector of location numbers to commence thresholding
#   children - list of vectors of children. children[[i]] is a vector of
#              location numbers to commence when i is complete.
#              Use children[[i]]=NA when location i has no children.
#   startFun - function(guess, location_number) that creates a state for
#              location location_number using guess as start guess.
#              guess=NA is used for starter locations.
#   stepFun  - function(state) returns a new state after one presentation
#   stopFun  - function(state) returns TRUE if location finished
#   finalFun - function(state) returns c(final threshold, number presentations)
#   waitForAllParents - If true, a location will not begin until all of
#                       its parents are complete, and averages them.
#                       If FALSE, a location will begin when any one of
#                       its parents completes.
#   geometricAv - If TRUE, and waitForAllParents is TRUE, then use
#                 geometric averaging for start guesses, else
#                 aritmetic averaging.
#
# RETURNS: a list with two elements:
#           mt, a vector of measured locations for each location
#           np, a vector of number of presentations at each location
####################################################################
procedureWithGeneralGrowthPattern <- function(starters, children,
    startFun, stepFun, stopFun, finalFun,
    waitForAllParents = FALSE, geometricAv = TRUE) {

    ######################################################
    # Set up parent graph and get maximum location number
    ######################################################
    max_loc_num <- max(unlist(children), na.rm = TRUE)
    parents <- vector('list', max_loc_num)
    for (i in seq_len(length(children))) {
        for (j in seq_len(length(children[[i]]))) {
            kid <- children[[i]][[j]]
            if (!is.null(kid))
                parents[[kid]] <- c(parents[[kid]], i)
        }
    }

    ##################################################
    # Return a list with loc_num and guess vectors
    # for kids to open up assuming loc just finished.
    # mt[i]=NA shows that location i is not finished.
    ##################################################
    newLocs <- function(mt, parent) {
        loc_num <- guess <- NULL
        for (kid in children[[parent]]) {
            if (is.na(mt[kid]))
                if (!waitForAllParents) {
                    loc_num <- c(loc_num, kid)
                    guess   <- c(guess, mt[parent])
                } else {
                    toAverage <- mt[parents[[kid]]]
                    if (all(!is.na(toAverage))) {
                        loc_num <- c(loc_num, kid)
                        if (geometricAv)
                            guess <- c(guess, prod(toAverage)^(1/length(toAverage)))
                        else
                            guess <- c(guess, mean(toAverage))
                    }
                }
        }
        return(list(loc_num = loc_num, guess = guess))
    }

    ###############################################
    # Now loop finishing 1s, start rest, etc
    ###############################################
    mt <- rep(NA, max_loc_num)
    np <- rep(0,  max_loc_num)

    states <- vector("list", max_loc_num)
    for (i in seq_len(length(starters))) {
        loc <- starters[[i]]
        states[[loc]] <- startFun(guess = NA, loc)
    }

    current <- starters
    while (length(current) > 0) {
        loc <- current[runif(1, min = 1, max = length(current))]

        states[[loc]] <- stepFun(states[[loc]])

        if (stopFun(states[[loc]])) {
                # fill in mt & np, remove from locs
            temp <- finalFun(states[[loc]])
            mt[loc] <- temp[1]
            np[loc] <- temp[2]
            current <- current[-which(current == loc)]

                # open up children (if possible)
            n <- newLocs(mt, loc)
            if (length(n$loc_num) > 0) {
                for (j in seq_len(length(n$loc_num))) {
                    current <- c(current, n$loc_num[j])
                    states[[n$loc_num[j]]] <- startFun(guess = n$guess[j], n$loc_num[j])
                }
            }
        }
    }

    return(list(mt = mt, np = np))
}