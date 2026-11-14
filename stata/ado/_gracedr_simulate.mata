mata:
real scalar gd_quantile7(real colvector values, real scalar p)
{
    real colvector sorted
    real scalar n, h, low

    sorted = sort(values, 1)
    n = rows(sorted)
    h = (n - 1) * p + 1
    low = floor(h)
    if (low >= n) {
        return(sorted[n])
    }
    return(sorted[low] + (h - low) * (sorted[low + 1] - sorted[low]))
}

real rowvector gd_summary_column(real colvector values)
{
    real colvector kept
    real rowvector result
    real scalar n, spread

    kept = select(values, values :< .)
    n = rows(kept)
    if (n == 0) {
        return((., ., ., ., .))
    }
    spread = (n > 1) ? sqrt(variance(kept)) : .
    result = (mean(kept), spread, gd_quantile7(kept, 0.95))
    result = (result, gd_quantile7(kept, 0.99), max(kept))
    return(result)
}

real colvector gd_distinct_seeds(real scalar count)
{
    real colvector seeds, ranks, sorted, repeated
    real scalar again

    seeds = runiformint(count, 1, 1, 2147483647)
    if (count < 2) {
        return(seeds)
    }
    again = 1
    while (again == 1) {
        ranks = order(seeds, 1)
        sorted = seeds[ranks]
        repeated = ranks[selectindex(sorted[2::count] :== sorted[1::(count - 1)]) :+ 1]
        if (rows(repeated) == 0) {
            again = 0
        }
        else {
            seeds[repeated] = runiformint(rows(repeated), 1, 1, 2147483647)
        }
    }
    return(seeds)
}

void gd_simulate()
{
    struct gd_design scalar D
    pointer(real rowvector) rowvector begin, finish
    pointer(real matrix) rowvector T, B, S
    string rowvector methods, point_names, names, arms
    string colvector point_labels, metric_labels
    real rowvector n, x, probs, points, cuts
    real matrix X, P, summary
    real colvector sim_seeds, arm_column, values, draws
    real scalar nsims, seed, m, j, i, v, per_trial, nm, offset, phase, arm, step, row
    string scalar state, method
    external real colvector gd_sim_values, gd_sim_sims
    external string colvector gd_sim_methods, gd_sim_points, gd_sim_metrics
    external string colvector gd_sum_methods, gd_sum_points, gd_sum_metrics
    external real matrix gd_sum_stats

    D = gd_load_design()
    names = tokens(st_local("d_varnames"))
    arms = tokens(st_local("d_arms"))
    methods = tokens(st_local("methods"))
    nm = cols(methods)
    nsims = strtoreal(st_local("nsims"))
    seed = strtoreal(st_local("seed"))
    begin = J(1, D.nvars, NULL)
    finish = J(1, D.nvars, NULL)
    gd_stream_arrays(D.iscat, D.nlev, begin, finish)
    point_names = gd_point_names(D.runin, gd_numbers(st_local("d_forcedat")))
    points = gd_point_sizes(D.runin, gd_numbers(st_local("d_forcedat")), D.N)
    gd_metric_labels(point_names, names, arms, point_labels, metric_labels)
    per_trial = rows(metric_labels)
    rseed(seed)
    if (sum(methods :== "minimization") > 0) {
        X = gd_stream(D.iscat, D.nlev, begin, finish, 1000)
        for (v = 1; v <= D.nvars; v++) {
            if (D.iscat[v] == 0) {
                D.cuts[v] = &((gd_quantile7(X[., v], 1 / 3), gd_quantile7(X[., v], 2 / 3)))
            }
        }
    }
    rseed(seed)
    sim_seeds = gd_distinct_seeds(nsims)
    gd_sim_values = J(nsims * nm * per_trial, 1, .)
    gd_sim_sims = J(nsims * nm * per_trial, 1, .)
    gd_sim_methods = J(nsims * nm * per_trial, 1, "")
    gd_sim_points = J(nsims * nm * per_trial, 1, "")
    gd_sim_metrics = J(nsims * nm * per_trial, 1, "")
    S = J(1, nm, NULL)
    for (m = 1; m <= nm; m++) {
        S[m] = &(J(nsims, per_trial, .))
    }
    step = max((1, ceil(nsims / 10)))
    for (j = 1; j <= nsims; j++) {
        rseed(sim_seeds[j])
        X = gd_stream(D.iscat, D.nlev, begin, finish, D.N)
        state = rseed()
        for (m = 1; m <= nm; m++) {
            method = methods[m]
            rseed(state)
            gd_state_init(D, n, T, B)
            P = J(D.N, D.K, .)
            arm_column = J(D.N, 1, .)
            for (i = 1; i <= D.N; i++) {
                x = X[i, .]
                probs = gd_probs(D, method, n, T, B, x, phase)
                arm = gd_draw(probs)
                P[i, .] = probs
                arm_column[i] = arm
                gd_update(D, n, T, B, x, arm)
            }
            values = gd_trial_metrics(D.K, D.iscat, D.nlev, D.r, points, X, arm_column, P)
            offset = ((j - 1) * nm + (m - 1)) * per_trial
            gd_sim_values[(offset + 1)::(offset + per_trial)] = values
            gd_sim_sims[(offset + 1)::(offset + per_trial)] = J(per_trial, 1, j)
            gd_sim_methods[(offset + 1)::(offset + per_trial)] = J(per_trial, 1, method)
            gd_sim_points[(offset + 1)::(offset + per_trial)] = point_labels
            gd_sim_metrics[(offset + 1)::(offset + per_trial)] = metric_labels
            (*S[m])[j, .] = values'
        }
        if (mod(j, step) == 0 | j == nsims) {
            printf("{txt}  simulation %g of %g\n", j, nsims)
            displayflush()
        }
    }
    gd_sum_methods = J(nm * per_trial, 1, "")
    gd_sum_points = J(nm * per_trial, 1, "")
    gd_sum_metrics = J(nm * per_trial, 1, "")
    gd_sum_stats = J(nm * per_trial, 5, .)
    for (m = 1; m <= nm; m++) {
        for (row = 1; row <= per_trial; row++) {
            offset = (m - 1) * per_trial + row
            gd_sum_methods[offset] = methods[m]
            gd_sum_points[offset] = point_labels[row]
            gd_sum_metrics[offset] = metric_labels[row]
            gd_sum_stats[offset, .] = gd_summary_column((*S[m])[., row])
        }
    }
    st_local("result_rows", strofreal(rows(gd_sim_values)))
    st_local("summary_rows", strofreal(rows(gd_sum_stats)))
}

void gd_results_to_data()
{
    external real colvector gd_sim_values, gd_sim_sims
    external string colvector gd_sim_methods, gd_sim_points, gd_sim_metrics

    st_store(., "sim", gd_sim_sims)
    st_sstore(., "method", gd_sim_methods)
    st_sstore(., "point", gd_sim_points)
    st_sstore(., "metric", gd_sim_metrics)
    st_store(., "value", gd_sim_values)
}

void gd_summary_to_data()
{
    external string colvector gd_sum_methods, gd_sum_points, gd_sum_metrics
    external real matrix gd_sum_stats

    st_sstore(., "method", gd_sum_methods)
    st_sstore(., "point", gd_sum_points)
    st_sstore(., "metric", gd_sum_metrics)
    st_store(., "mean", gd_sum_stats[., 1])
    st_store(., "sd", gd_sum_stats[., 2])
    st_store(., "q95", gd_sum_stats[., 3])
    st_store(., "q99", gd_sum_stats[., 4])
    st_store(., "max", gd_sum_stats[., 5])
}

real scalar gd_simulate_version()
{
    return(1)
}
end
