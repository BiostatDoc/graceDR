version 19
clear
set linesize 100

input str22 command str70 purpose
"gracedr setup"      "Create a study folder from a design"
"gracedr codes"      "Check and load a file of treatment codes"
"gracedr randomize"  "Randomize one participant and save the record"
"gracedr status"     "Group sizes, balance tables, and graphs"
"gracedr override"   "Change an assignment with a recorded reason"
"gracedr audit"      "List the append-only audit log"
"gracedr replay"     "Redraw a past assignment and compare it with the record"
"gracedr simulate"   "Simulate trials under up to five allocation methods"
"encsave"            "Save the data in memory to an encrypted zip file"
"encuse"             "Load the data from an encrypted zip file"
end
show_table command purpose, title("Table: commands")

clear
input str14 option str10 default str64 meaning
"n()"            "(required)"  "Total planned enrollment"
"arms()"         "(required)"  "Arm labels, at least two"
"categorical()"  "none"        "Categorical balance variables and their levels"
"continuous()"   "none"        "Continuous balance variables"
"ratio()"        "1 for all"   "Allocation ratio, any positive numbers"
"weights()"      "equal"       "Positive weights of the balance variables"
"pstar()"        "0.30"        "Imbalance probability limit"
"xi()"           "0.65"        "Biased coin probability"
"runin()"        "default"     "Run-in size; 0 removes the run-in"
"runinmethod()"  "tilted"      "Run-in with the tilt, or the plain random allocation rule"
"forcedat()"     "none"        "Enrollment totals at which the target counts are forced"
"sizebound()"    "3"           "Big stick bound"
"codes()"        "none"        "Treatment codes file with columns code and arm"
"seed()"         "random"      "Seed of the random number generator"
"encrypt"        "off"         "Store every dataset as an AES-256 encrypted zip"
end
show_table option default meaning, title("Table: options of gracedr setup")
