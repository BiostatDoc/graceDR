version 19

capture program drop remove_folder
program define remove_folder
    args folder
    mata: st_local("found", strofreal(direxists(st_local("folder"))))
    if `found' == 1 {
        local files : dir "`folder'" files "*"
        foreach file of local files {
            quietly erase "`folder'/`file'"
        }
        quietly rmdir "`folder'"
    }
end

capture program drop show_table
program define show_table
    syntax varlist, TITLE(string)
    display
    display as text "`title'"
    list `varlist', noobs separator(0) abbreviate(30)
end

capture program drop use_study_participants
program define use_study_participants
    args study
    capture confirm file "`study'/participants.dta"
    if _rc == 0 {
        use "`study'/participants.dta", clear
    }
    else {
        encuse using "`study'/participants", clear
    }
end
