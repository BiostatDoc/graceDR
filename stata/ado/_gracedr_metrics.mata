mata:
real scalar gd_scaled(real scalar difference, real scalar spread)
{
    if (spread >= . | difference >= .) {
        return(0)
    }
    if (spread == 0) {
        return(0)
    }
    return(difference / spread)
}

real scalar gd_smd_binary(real scalar p1, real scalar p2)
{
    return(gd_scaled(p1 - p2, sqrt((p1 * (1 - p1) + p2 * (1 - p2)) / 2)))
}

real scalar gd_smd_cont(real scalar m1, real scalar m2, real scalar s1, real scalar s2)
{
    return(gd_scaled(m1 - m2, sqrt((s1^2 + s2^2) / 2)))
}

real scalar gd_smd_var(
    real colvector x,
    real colvector arm,
    real scalar K,
    real scalar iscat,
    real scalar nlev,
    real scalar k
)
{
    real colvector xs, as
    real rowvector counts, means, sds, props
    real scalar a, b, level, largest, count, found
    real colvector piece

    xs = x[1::k]
    as = arm[1::k]
    counts = J(1, K, 0)
    for (a = 1; a <= K; a++) {
        counts[a] = sum((xs :< .) :& (as :== a))
    }
    if (min(counts) == 0) {
        return(.)
    }
    largest = 0
    if (iscat == 1) {
        for (level = 1; level <= nlev; level++) {
            props = J(1, K, 0)
            for (a = 1; a <= K; a++) {
                props[a] = sum((xs :== level) :& (as :== a)) / counts[a]
            }
            for (a = 1; a < K; a++) {
                for (b = a + 1; b <= K; b++) {
                    largest = max((largest, abs(gd_smd_binary(props[a], props[b]))))
                }
            }
        }
        return(largest)
    }
    means = J(1, K, .)
    sds = J(1, K, .)
    for (a = 1; a <= K; a++) {
        piece = select(xs, (xs :< .) :& (as :== a))
        means[a] = mean(piece)
        sds[a] = counts[a] > 1 ? sqrt(variance(piece)) : .
    }
    for (a = 1; a < K; a++) {
        for (b = a + 1; b <= K; b++) {
            largest = max((largest, abs(gd_smd_cont(means[a], means[b], sds[a], sds[b]))))
        }
    }
    return(largest)
}

real colvector gd_trial_metrics(
    real scalar K,
    real rowvector iscat,
    real rowvector nlev,
    real rowvector r,
    real rowvector points,
    real matrix X,
    real colvector arm,
    real matrix P
)
{
    real colvector out, forced, deficit
    real rowvector smd, counts, targets, before, guessed
    real scalar p, v, a, i, k, largest, run, longest, guess_total, anyvalue
    real scalar total

    out = J(0, 1, .)
    for (p = 1; p <= cols(points); p++) {
        k = points[p]
        smd = J(1, cols(iscat), .)
        for (v = 1; v <= cols(iscat); v++) {
            smd[v] = gd_smd_var(X[., v], arm, K, iscat[v], nlev[v], k)
        }
        anyvalue = sum(smd :< .)
        largest = anyvalue == 0 ? . : max(select(smd, smd :< .))
        counts = J(1, K, 0)
        for (a = 1; a <= K; a++) {
            counts[a] = sum(arm[1::k] :== a)
        }
        targets = gd_arm_targets(k, r)
        out = out \ largest \ smd' \ abs(counts - targets)'
    }
    total = rows(arm)
    forced = J(total, 1, 0)
    for (i = 1; i <= total; i++) {
        forced[i] = max(P[i, .]) >= 1 - 1e-12
    }
    longest = 0
    run = 0
    for (i = 1; i <= total; i++) {
        if (forced[i] == 1) {
            if (i > 1) {
                if (forced[i - 1] == 1 & arm[i] == arm[i - 1]) {
                    run = run + 1
                }
                else {
                    run = 1
                }
            }
            else {
                run = 1
            }
            longest = max((longest, run))
        }
        else {
            run = 0
        }
    }
    guess_total = 0
    before = J(1, K, 0)
    for (i = 1; i <= total; i++) {
        deficit = (before - (i - 1) * r)'
        guessed = (abs(deficit :- min(deficit)) :< 1e-9)'
        guess_total = guess_total + sum(guessed :* P[i, .]) / sum(guessed)
        before[arm[i]] = before[arm[i]] + 1
    }
    out = out \ (100 * mean(forced)) \ longest \ (100 * guess_total / total)
    return(out)
}

void gd_metric_labels(
    string rowvector pointnames,
    string rowvector varnames,
    string rowvector arms,
    string colvector points,
    string colvector metrics
)
{
    real scalar p, v, a

    points = J(0, 1, "")
    metrics = J(0, 1, "")
    for (p = 1; p <= cols(pointnames); p++) {
        points = points \ J(1 + cols(varnames) + cols(arms), 1, pointnames[p])
        metrics = metrics \ "smd_max"
        for (v = 1; v <= cols(varnames); v++) {
            metrics = metrics \ ("smd_" + varnames[v])
        }
        for (a = 1; a <= cols(arms); a++) {
            metrics = metrics \ ("size_dev_" + arms[a])
        }
    }
    points = points \ J(3, 1, "all")
    metrics = metrics \ "pct_deterministic" \ "longest_forced_run" \ "correct_guess"
}

string rowvector gd_point_names(real scalar runin, real rowvector forced)
{
    string rowvector names
    real scalar i

    names = J(1, 0, "")
    if (runin > 0) {
        names = names, "run-in"
    }
    for (i = 1; i <= cols(forced); i++) {
        names = names, ("n=" + strofreal(forced[i]))
    }
    return(names, "end")
}

real rowvector gd_point_sizes(real scalar runin, real rowvector forced, real scalar N)
{
    real rowvector sizes

    sizes = J(1, 0, .)
    if (runin > 0) {
        sizes = sizes, runin
    }
    return(sizes, forced, N)
}

void gd_metrics_from_data()
{
    real rowvector iscat, nlev, r, forced, points, ratio
    string rowvector names, types, levels, arms, point_names
    real matrix X, P
    real colvector arm, values
    string colvector arm_text, text, point_labels, metric_labels
    real scalar v, i, K, n, runin, N, a
    external real colvector gd_out_values
    external string colvector gd_out_points, gd_out_metrics

    names = tokens(st_local("d_varnames"))
    types = tokens(st_local("d_vartypes"))
    arms = tokens(st_local("d_arms"))
    K = cols(arms)
    ratio = strtoreal(tokens(st_local("d_ratio")))
    r = ratio / sum(ratio)
    runin = strtoreal(st_local("d_runin"))
    N = strtoreal(st_local("d_n"))
    forced = strtoreal(tokens(st_local("d_forcedat")))
    iscat = (types :== "categorical")
    nlev = J(1, cols(names), 0)
    n = st_nobs()
    X = J(n, cols(names), .)
    for (v = 1; v <= cols(names); v++) {
        if (iscat[v] == 1) {
            levels = tokens(st_local("d_levels" + strofreal(v)))
            nlev[v] = cols(levels)
            text = st_sdata(., names[v])
            for (i = 1; i <= n; i++) {
                for (a = 1; a <= cols(levels); a++) {
                    if (text[i] == levels[a]) {
                        X[i, v] = a
                    }
                }
            }
        }
        else {
            X[., v] = st_data(., names[v])
        }
    }
    arm_text = st_sdata(., "arm")
    arm = J(n, 1, .)
    P = J(n, K, .)
    for (i = 1; i <= n; i++) {
        for (a = 1; a <= K; a++) {
            if (arm_text[i] == arms[a]) {
                arm[i] = a
            }
        }
    }
    for (a = 1; a <= K; a++) {
        P[., a] = st_data(., "prob" + strofreal(a))
    }
    point_names = gd_point_names(runin, forced)
    points = gd_point_sizes(runin, forced, N)
    gd_out_values = gd_trial_metrics(K, iscat, nlev, r, points, X, arm, P)
    gd_metric_labels(point_names, names, arms, point_labels, metric_labels)
    gd_out_points = point_labels
    gd_out_metrics = metric_labels
    st_local("metric_rows", strofreal(rows(gd_out_values)))
}

void gd_metrics_to_data()
{
    external real colvector gd_out_values
    external string colvector gd_out_points, gd_out_metrics

    st_sstore(., "point", gd_out_points)
    st_sstore(., "metric", gd_out_metrics)
    st_store(., "value", gd_out_values)
}
real scalar gd_metrics_version()
{
    return(1)
}
end
