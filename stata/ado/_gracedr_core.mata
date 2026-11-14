mata:
struct gd_design {
    real scalar K, nvars, N, runin, sizebound, pstar, xi, rar, phigh
    real rowvector r, ratio, weights, iscat, nlev
    real matrix ck
    pointer(real rowvector) rowvector cuts
}

real rowvector gd_numbers(string scalar text)
{
    string rowvector pieces
    real rowvector out
    real scalar i

    pieces = tokens(text)
    out = J(1, cols(pieces), .)
    for (i = 1; i <= cols(pieces); i++) {
        out[i] = strtoreal(pieces[i])
    }
    return(out)
}

real rowvector gd_arm_targets(real scalar n, real rowvector r)
{
    real rowvector exact, base, fractions
    real scalar remainder, i, best, bestfrac, k
    real rowvector taken

    exact = n :* r
    base = floor(round(exact, 1e-10))
    fractions = round(exact - base, 1e-10)
    remainder = n - sum(base)
    taken = J(1, cols(r), 0)
    for (k = 1; k <= remainder; k++) {
        best = 0
        bestfrac = -1
        for (i = 1; i <= cols(r); i++) {
            if (taken[i] == 0 & fractions[i] > bestfrac) {
                best = i
                bestfrac = fractions[i]
            }
        }
        taken[best] = 1
        base[best] = base[best] + 1
    }
    return(base)
}

real matrix gd_checkpoints(
    real scalar N,
    real scalar runin,
    real rowvector forced,
    real rowvector r
)
{
    real matrix candidates, table
    real scalar i, row, count

    candidates = (N, 1)
    if (runin > 0) {
        candidates = candidates \ (runin, 2)
    }
    for (i = 1; i <= cols(forced); i++) {
        candidates = candidates \ (forced[i], 3)
    }
    candidates = sort(candidates, (1, 2))
    table = J(0, 1 + cols(r), .)
    count = 0
    for (row = 1; row <= rows(candidates); row++) {
        if (row == 1) {
            count = 1
        }
        else if (candidates[row, 1] != candidates[row - 1, 1]) {
            count = 1
        }
        else {
            count = 0
        }
        if (count == 1) {
            table = table \ (candidates[row, 1], gd_arm_targets(candidates[row, 1], r))
        }
    }
    return(table)
}

real scalar gd_unique_extreme(real rowvector values, string scalar which)
{
    real scalar target, hits, found, i

    target = (which == "min") ? min(values) : max(values)
    hits = 0
    found = 0
    for (i = 1; i <= cols(values); i++) {
        if (abs(values[i] - target) < 1e-12) {
            hits = hits + 1
            found = i
        }
    }
    return(hits == 1 ? found : 0)
}

real scalar gd_vote_cat(real matrix tab, real scalar level, real scalar pstar)
{
    real colvector sums
    real rowvector totals
    real matrix kept, expected
    real scalar chi, df

    if (level >= .) {
        return(0)
    }
    sums = rowsum(tab)
    if (sums[level] == 0) {
        return(0)
    }
    kept = select(tab, sums :> 0)
    if (rows(kept) < 2) {
        return(0)
    }
    totals = colsum(kept)
    if (min(totals) == 0) {
        return(0)
    }
    expected = (rowsum(kept) * totals) / sum(kept)
    chi = sum((kept - expected):^2 :/ expected)
    df = (rows(kept) - 1) * (cols(kept) - 1)
    if (chi2tail(df, chi) >= pstar) {
        return(0)
    }
    return(gd_unique_extreme(tab[level, .] :/ totals, "min"))
}

real scalar gd_welch_p(real rowvector n, real rowvector m, real rowvector v)
{
    real scalar se, t, df, k, h, numerator, f, df2, weighted
    real rowvector w

    k = cols(n)
    if (k == 2) {
        se = sqrt(sum(v :/ n))
        t = (m[1] - m[2]) / se
        df = se^4 / sum((v :/ n):^2 :/ (n :- 1))
        return(2 * ttail(df, abs(t)))
    }
    w = n :/ v
    weighted = sum(w :* m) / sum(w)
    numerator = sum(w :* (m :- weighted):^2) / (k - 1)
    h = sum((1 :- w :/ sum(w)):^2 :/ (n :- 1))
    f = numerator / (1 + 2 * (k - 2) / (k^2 - 1) * h)
    df2 = (k^2 - 1) / (3 * h)
    return(Ftail(k - 1, df2, f))
}

real scalar gd_vote_cont(real matrix s, real scalar x, real scalar pstar)
{
    real rowvector n, m, v

    n = s[., 1]'
    if (x >= . | min(n) < 2) {
        return(0)
    }
    m = s[., 2]' :/ n
    v = (s[., 3]' - n :* m:^2) :/ (n :- 1)
    if (min(v) <= 0) {
        return(0)
    }
    if (gd_welch_p(n, m, v) >= pstar) {
        return(0)
    }
    if (x > max(m)) {
        return(gd_unique_extreme(m, "min"))
    }
    if (x < min(m)) {
        return(gd_unique_extreme(m, "max"))
    }
    return(0)
}

real scalar gd_vote_size(real rowvector n, real rowvector r)
{
    real rowvector deficit

    deficit = n - r * sum(n)
    if (min(deficit) > -1 + 1e-9) {
        return(0)
    }
    return(gd_unique_extreme(deficit, "min"))
}

real scalar gd_tally(real rowvector votes, real rowvector weights, real scalar K)
{
    real rowvector scores
    real scalar a

    if (max(votes) == 0) {
        return(0)
    }
    scores = J(1, K, 0)
    for (a = 1; a <= cols(votes); a++) {
        if (votes[a] > 0) {
            scores[votes[a]] = scores[votes[a]] + weights[a]
        }
    }
    return(gd_unique_extreme(scores, "max"))
}

real rowvector gd_tilt(real rowvector b, real scalar winner, real scalar xi)
{
    real scalar odds, pw
    real rowvector out

    if (winner == 0) {
        return(b)
    }
    if (b[winner] <= 0 | b[winner] >= 1) {
        return(b)
    }
    odds = b[winner] / (1 - b[winner]) * xi / (1 - xi)
    pw = odds / (1 + odds)
    out = b :* (1 - pw) / (1 - b[winner])
    out[winner] = pw
    return(out)
}

void gd_state_init(
    struct gd_design scalar D,
    real rowvector n,
    pointer(real matrix) rowvector T,
    pointer(real matrix) rowvector B
)
{
    real scalar v

    n = J(1, D.K, 0)
    T = J(1, D.nvars, NULL)
    B = J(1, D.nvars, NULL)
    for (v = 1; v <= D.nvars; v++) {
        if (D.iscat[v] == 1) {
            T[v] = &(J(D.nlev[v], D.K, 0))
        }
        else {
            T[v] = &(J(D.K, 3, 0))
            B[v] = &(J(cols(*D.cuts[v]) + 1, D.K, 0))
        }
    }
}

real scalar gd_bin(real rowvector cuts, real scalar x)
{
    return(1 + sum(cuts :<= x))
}

void gd_update(
    struct gd_design scalar D,
    real rowvector n,
    pointer(real matrix) rowvector T,
    pointer(real matrix) rowvector B,
    real rowvector x,
    real scalar arm
)
{
    real scalar v, bin

    n[arm] = n[arm] + 1
    for (v = 1; v <= D.nvars; v++) {
        if (x[v] < .) {
            if (D.iscat[v] == 1) {
                (*T[v])[x[v], arm] = (*T[v])[x[v], arm] + 1
            }
            else {
                (*T[v])[arm, .] = (*T[v])[arm, .] + (1, x[v], x[v]^2)
                bin = gd_bin(*D.cuts[v], x[v])
                (*B[v])[bin, arm] = (*B[v])[bin, arm] + 1
            }
        }
    }
}

real rowvector gd_votes(
    struct gd_design scalar D,
    pointer(real matrix) rowvector T,
    real rowvector x
)
{
    real rowvector votes
    real scalar v

    votes = J(1, D.nvars, 0)
    for (v = 1; v <= D.nvars; v++) {
        if (D.iscat[v] == 1) {
            votes[v] = gd_vote_cat(*T[v], x[v], D.pstar)
        }
        else {
            votes[v] = gd_vote_cont(*T[v], x[v], D.pstar)
        }
    }
    return(votes)
}

real rowvector gd_quota(struct gd_design scalar D, real rowvector n)
{
    real scalar i, row, remaining

    i = sum(n) + 1
    row = 1
    while (D.ck[row, 1] < i) {
        row = row + 1
    }
    remaining = D.ck[row, 1] - (i - 1)
    return(colmax((D.ck[row, 2..(D.K + 1)] - n \ J(1, D.K, 0))) / remaining)
}

real rowvector gd_bound(
    struct gd_design scalar D,
    real rowvector b,
    real rowvector n,
    real scalar bound
)
{
    real rowvector imbalance, forced, allowed, behind, blocked

    imbalance = n - D.r * sum(n)
    behind = imbalance :<= -D.sizebound + 1e-9
    bound = 0
    if (sum(behind) > 0) {
        forced = behind :* (-imbalance)
        bound = 1
        return(forced / sum(forced))
    }
    blocked = imbalance :>= D.sizebound - 1e-9
    allowed = (1 :- blocked) :* b
    if (sum(blocked :& (b :> 0)) == 0 | sum(allowed) == 0) {
        return(b)
    }
    bound = 1
    return(allowed / sum(allowed))
}

real rowvector gd_mmsb(
    struct gd_design scalar D,
    real rowvector n,
    pointer(real matrix) rowvector T,
    real rowvector x,
    real scalar phase
)
{
    real rowvector b, votes, weights
    real scalar in_run_in, bound, winner
    real rowvector bounded

    in_run_in = (sum(n) + 1) <= D.runin
    b = gd_quota(D, n)
    if (max(b) >= 1 - 1e-12) {
        phase = in_run_in ? 2 : 1
        return(b)
    }
    if (in_run_in) {
        phase = 2
        if (D.rar == 1) {
            return(b)
        }
        winner = gd_tally(gd_votes(D, T, x), D.weights, D.K)
        return(gd_tilt(b, winner, D.xi))
    }
    bounded = gd_bound(D, b, n, bound)
    if (bound == 1) {
        phase = 3
        return(bounded)
    }
    votes = (gd_votes(D, T, x), gd_vote_size(n, D.r))
    weights = (D.weights, 1)
    winner = gd_tally(votes, weights, D.K)
    phase = winner == 0 ? 5 : 4
    return(gd_tilt(b, winner, D.xi))
}

real rowvector gd_blocks(struct gd_design scalar D, real rowvector n)
{
    real rowvector quota, left
    real scalar completed

    quota = 2 * D.ratio
    completed = floor(sum(n) / (2 * sum(D.ratio)))
    left = quota - (n - completed * quota)
    return(left / sum(left))
}

real rowvector gd_minimization(
    struct gd_design scalar D,
    pointer(real matrix) rowvector T,
    pointer(real matrix) rowvector B,
    real rowvector x
)
{
    real rowvector counts, imbalance, scaled, probs, best
    real matrix tables
    real scalar v, used, c, a, best_count, rest

    tables = J(0, D.K, .)
    used = 0
    for (v = 1; v <= D.nvars; v++) {
        if (x[v] < .) {
            if (D.iscat[v] == 1) {
                counts = (*T[v])[x[v], .]
            }
            else {
                counts = (*B[v])[gd_bin(*D.cuts[v], x[v]), .]
            }
            tables = tables \ counts
            used = used + 1
            if (used == 1) {
                imbalance = D.weights[v]
            }
            else {
                imbalance = imbalance, D.weights[v]
            }
        }
    }
    if (used == 0) {
        return(D.r)
    }
    probs = J(1, D.K, 0)
    for (c = 1; c <= D.K; c++) {
        for (v = 1; v <= used; v++) {
            scaled = tables[v, .]
            scaled[c] = scaled[c] + 1
            scaled = scaled :/ D.r
            probs[c] = probs[c] + imbalance[v] * (max(scaled) - min(scaled))
        }
    }
    best = abs(probs :- min(probs)) :< 1e-9
    best_count = sum(best)
    if (best_count == D.K) {
        return(D.r)
    }
    rest = sum(D.r :* (1 :- best))
    return(best :* (D.phigh / best_count) :+ (1 :- best) :* ((1 - D.phigh) :* D.r / rest))
}

real rowvector gd_msb(
    struct gd_design scalar D,
    pointer(real matrix) rowvector T,
    real rowvector x
)
{
    real scalar winner

    winner = gd_tally(gd_votes(D, T, x), D.weights, D.K)
    return(gd_tilt(D.r, winner, D.xi))
}

real rowvector gd_probs(
    struct gd_design scalar D,
    string scalar method,
    real rowvector n,
    pointer(real matrix) rowvector T,
    pointer(real matrix) rowvector B,
    real rowvector x,
    real scalar phase
)
{
    phase = 0
    if (method == "mmsb") {
        return(gd_mmsb(D, n, T, x, phase))
    }
    if (method == "srs") {
        return(D.r)
    }
    if (method == "blocks") {
        return(gd_blocks(D, n))
    }
    if (method == "minimization") {
        return(gd_minimization(D, T, B, x))
    }
    return(gd_msb(D, T, x))
}

real scalar gd_draw(real rowvector probs)
{
    real scalar u, total, running, a

    u = runiform(1, 1)
    total = sum(probs)
    running = 0
    for (a = 1; a <= cols(probs); a++) {
        running = running + probs[a] / total
        if (u < running) {
            return(a)
        }
    }
    return(cols(probs))
}

struct gd_design scalar gd_load_design()
{
    struct gd_design scalar D
    real scalar v, level_count
    real rowvector forced
    string rowvector names, types

    D.N = strtoreal(st_local("d_n"))
    D.K = cols(tokens(st_local("d_arms")))
    D.ratio = gd_numbers(st_local("d_ratio"))
    D.r = D.ratio / sum(D.ratio)
    D.weights = gd_numbers(st_local("d_weights"))
    D.pstar = strtoreal(st_local("d_pstar"))
    D.xi = strtoreal(st_local("d_xi"))
    D.runin = strtoreal(st_local("d_runin"))
    D.rar = (st_local("d_runinmethod") == "rar")
    D.sizebound = strtoreal(st_local("d_sizebound"))
    D.phigh = strtoreal(st_local("d_phigh"))
    if (D.phigh >= .) {
        D.phigh = 0.8
    }
    D.nvars = strtoreal(st_local("d_nvars"))
    names = tokens(st_local("d_varnames"))
    types = tokens(st_local("d_vartypes"))
    forced = gd_numbers(st_local("d_forcedat"))
    D.ck = gd_checkpoints(D.N, D.runin, forced, D.r)
    D.iscat = J(1, D.nvars, 0)
    D.nlev = J(1, D.nvars, 0)
    D.cuts = J(1, D.nvars, NULL)
    for (v = 1; v <= D.nvars; v++) {
        D.iscat[v] = (types[v] == "categorical")
        if (D.iscat[v] == 1) {
            D.nlev[v] = cols(tokens(st_local("d_levels" + strofreal(v))))
        }
        else {
            D.cuts[v] = &(gd_numbers(st_local("d_cuts" + strofreal(v))))
        }
    }
    return(D)
}

void gd_probs_from_data()
{
    struct gd_design scalar D
    real rowvector n, x, probs
    pointer(real matrix) rowvector T, B
    string rowvector names, arms, levels
    string colvector armcol, text
    real rowvector index
    real scalar v, i, phase, level_pos
    string scalar method, label

    D = gd_load_design()
    names = tokens(st_local("d_varnames"))
    arms = tokens(st_local("d_arms"))
    gd_state_init(D, n, T, B)
    armcol = st_sdata(., "arm")
    for (i = 1; i <= rows(armcol); i++) {
        x = J(1, D.nvars, .)
        for (v = 1; v <= D.nvars; v++) {
            if (D.iscat[v] == 1) {
                levels = tokens(st_local("d_levels" + strofreal(v)))
                label = st_sdata(i, names[v])
                if (label != "") {
                    level_pos = selectindex(levels :== label)
                    x[v] = cols(level_pos) == 0 ? . : level_pos[1]
                }
            }
            else {
                x[v] = st_data(i, names[v])
            }
        }
        index = selectindex(arms :== armcol[i])
        gd_update(D, n, T, B, x, index[1])
    }
    x = J(1, D.nvars, .)
    for (v = 1; v <= D.nvars; v++) {
        if (D.iscat[v] == 1) {
            levels = tokens(st_local("d_levels" + strofreal(v)))
            label = st_local("cleaned" + strofreal(v))
            if (label != "") {
                level_pos = selectindex(levels :== label)
                x[v] = cols(level_pos) == 0 ? . : level_pos[1]
            }
        }
        else {
            x[v] = strtoreal(st_local("number" + strofreal(v)))
        }
    }
    method = st_local("method")
    probs = gd_probs(D, method, n, T, B, x, phase)
    text = J(cols(probs), 1, "")
    for (i = 1; i <= cols(probs); i++) {
        text[i] = strofreal(probs[i], "%21.17g")
    }
    st_local("core_probs", invtokens(text'))
    st_local("core_phase", strofreal(phase))
}
real scalar gd_core_version()
{
    return(1)
}
end
