#[[
MIT License

CMake build script for the Accelerate LAPACKE project
Copyright (c) 2024 Tim Kaune

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

# Macro to parse the symbol names from the .tbd files
# Provides the `${_LIB_NAME}_SYMBOLS` list variable.
macro (parse_tbd_symbols _LIB_NAME _TBD_PATH)
    file(READ "${_TBD_PATH}" _TBD_CONTENT)
    # First, match all symbol arrays in the .tbd file
    string(REGEX MATCHALL "symbols:[\r\n\t ]+\\[[\r\n\t ][^]]*[\r\n\t ]\\]" _TBD_SYMBOL_ARRAY_MATCHES "${_TBD_CONTENT}")

    set("${_LIB_NAME}_SYMBOLS" "")

    foreach (_SYMBOL_ARRAY_MATCH IN LISTS _TBD_SYMBOL_ARRAY_MATCHES)
        # Extract the array contents from the symbol array match
        string(REGEX MATCH "\\[[\r\n\t ]([^]]*)[\r\n\t ]\\]" _DUMMY_MATCH "${_SYMBOL_ARRAY_MATCH}")
        # Replace commas and white space with semi colons
        string(REGEX REPLACE ",[\r\n\t ]*" ";" _SYMBOLS_IN_ARRAY "${CMAKE_MATCH_1}")
        # Remove single quotes around the symbols containing $ signs
        string(REPLACE "'" "" _SYMBOLS_IN_ARRAY "${_SYMBOLS_IN_ARRAY}")
        list(APPEND "${_LIB_NAME}_SYMBOLS" ${_SYMBOLS_IN_ARRAY})
    endforeach ()
endmacro ()

# Macro to filter the full list for $NEWLAPACK symbols
# Provides the `${_LIB_NAME}_NEWLAPACK_SYMBOLS` list variable.
macro (filter_new_lapack_symbols _LIB_NAME)
    set("${_LIB_NAME}_NEWLAPACK_SYMBOLS" ${${_LIB_NAME}_SYMBOLS})
    list(FILTER "${_LIB_NAME}_NEWLAPACK_SYMBOLS" INCLUDE REGEX "\\$NEWLAPACK$")
endmacro ()

# Macro to filter the full list for $NEWLAPACK$ILP64 symbols
# Provides the `${_LIB_NAME}_NEWLAPACK_ILP64_SYMBOLS` list variable.
macro (filter_new_lapack_ilp64_symbols _LIB_NAME)
    set("${_LIB_NAME}_NEWLAPACK_ILP64_SYMBOLS" ${${_LIB_NAME}_SYMBOLS})
    list(FILTER "${_LIB_NAME}_NEWLAPACK_ILP64_SYMBOLS" INCLUDE REGEX "\\$NEWLAPACK\\$ILP64$")
endmacro ()

# Macro to build the aliases from the filtered symbol lists
# For a symbols list variable ending in `_SYMBOLS`, provides the corresponding
# `_ALIASES` string variable.
macro (build_aliases _SYMBOL_LIST_VAR_NAME)
    string(REPLACE "_SYMBOLS" "_ALIASES" _ALIASES_VAR_NAME "${_SYMBOL_LIST_VAR_NAME}")
    # Transform the symbols `_<symbol>$NEWLAPACK($ILP64)` to aliases
    # `_<symbol>$NEWLAPACK($ILP64)    _<symbol>_`
    list(TRANSFORM ${_SYMBOL_LIST_VAR_NAME} REPLACE "^([^\\$]+)\\$.+$" "\\0\t\\1_" OUTPUT_VARIABLE ${_ALIASES_VAR_NAME})
    # Join the list with line breaks
    list(JOIN ${_ALIASES_VAR_NAME} "\n" ${_ALIASES_VAR_NAME})
endmacro ()
