*! version 1.0.0  15nov2026
program define _gracedr_zip_folder, rclass
    version 19
    local backslash = char(92)
    quietly findfile _gracedr_zip_folder.ado
    local ado_file = subinstr(`"`r(fn)'"', "`backslash'", "/", .)
    local trim = strlen("_gracedr_zip_folder.ado") + 1
    local ado_folder = substr("`ado_file'", 1, strlen("`ado_file'") - `trim')
    local sibling "`ado_folder'/../python"
    capture confirm file "`sibling'/gracedr_zip.py"
    if _rc == 0 {
        _gracedr_home, path("`sibling'")
        return local folder `"`r(path)'"'
        exit
    }
    capture quietly findfile gracedr_zip.py
    local module_found = _rc == 0
    if `module_found' == 0 {
        display as error "gracedr: cannot find gracedr_zip.py, reinstall the gracedr package"
        exit 601
    }
    local module_file = subinstr(`"`r(fn)'"', "`backslash'", "/", .)
    local trim = strlen("gracedr_zip.py") + 1
    local module_folder = substr("`module_file'", 1, strlen("`module_file'") - `trim')
    _gracedr_home, path("`module_folder'")
    return local folder `"`r(path)'"'
end
