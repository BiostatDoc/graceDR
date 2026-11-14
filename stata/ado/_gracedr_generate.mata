mata:
real matrix gd_stream(
    real rowvector iscat,
    real rowvector nlev,
    pointer(real rowvector) rowvector begin,
    pointer(real rowvector) rowvector finish,
    real scalar n
)
{
    real matrix X, values, cumulative
    real colvector u, draws, index
    real rowvector s, e
    real scalar v, levels

    X = J(n, cols(iscat), .)
    if (n == 0) {
        return(X)
    }
    u = (0::(n - 1)) / max((n - 1, 1))
    for (v = 1; v <= cols(iscat); v++) {
        s = *begin[v]
        e = *finish[v]
        values = J(n, 1, 1) * s + u * (e - s)
        if (iscat[v] == 0) {
            X[., v] = values[., 1] + rnormal(n, 1, 0, 1) :* values[., 2]
        }
        else {
            levels = nlev[v]
            cumulative = values * uppertriangle(J(levels, levels, 1))
            draws = runiform(n, 1)
            index = 1 :+ rowsum(draws :> cumulative)
            X[., v] = rowmin((index, J(n, 1, levels)))
        }
    }
    return(X)
}

void gd_stream_arrays(
    real rowvector iscat,
    real rowvector nlev,
    pointer(real rowvector) rowvector begin,
    pointer(real rowvector) rowvector finish
)
{
    real scalar v

    for (v = 1; v <= cols(iscat); v++) {
        begin[v] = &(strtoreal(tokens(st_local("g_start" + strofreal(v)))))
        finish[v] = &(strtoreal(tokens(st_local("g_end" + strofreal(v)))))
    }
}

void gd_stream_to_data()
{
    real rowvector iscat, nlev
    pointer(real rowvector) rowvector begin, finish
    string rowvector names, types, levels
    real matrix X
    real scalar v, n
    string colvector text

    names = tokens(st_local("varnames"))
    types = tokens(st_local("vartypes"))
    iscat = (types :== "categorical")
    nlev = J(1, cols(names), 0)
    for (v = 1; v <= cols(names); v++) {
        if (iscat[v] == 1) {
            nlev[v] = cols(tokens(st_local("levels" + strofreal(v))))
        }
    }
    begin = J(1, cols(names), NULL)
    finish = J(1, cols(names), NULL)
    gd_stream_arrays(iscat, nlev, begin, finish)
    n = strtoreal(st_local("g_count"))
    X = gd_stream(iscat, nlev, begin, finish, n)
    for (v = 1; v <= cols(names); v++) {
        if (iscat[v] == 1) {
            levels = tokens(st_local("levels" + strofreal(v)))
            text = levels'[X[., v]]
            st_sstore(., names[v], text)
        }
        else {
            st_store(., names[v], X[., v])
        }
    }
}
real scalar gd_generate_version()
{
    return(1)
}
end
