include_guard()

#[[[ Defines a unit test for the CMakeTest framework.
#
# Unit testing in CMakeTest works by `include()`ing each unit test, determining which ones
# need to be ran, and then executing them sequentially in-process. This macro defines which functions
# are to be interpretted as actual unit tests. It does so by setting a variable in the calling scope
# that is to be used as the function identifier. For example:
#
# .. code-block:: cmake
#
#    ct_add_test(NAME this_test)
#    function(${this_test})
#        message(STATUS "This code will run in a unit test")
#    endfunction()
#
# This helps tests avoid name collisions and also allows the testing framework to keep track of them.
#
# Print length of pass/fail lines can be adjusted with the `PRINT_LENGTH` option.
#
# Priority for print length is as follows (first most important):
#  1. Current execution unit's PRINT_LENGTH option
#  2. Parent's PRINT_LENGTH option
#  3. Length set by ct_set_print_length()
#  4. Built-in default of 80.
#
# :param **kwargs: See below
#
# :Keyword Arguments:
#    * *NAME* (``pointer``) -- Required argument specifying the name variable of the section. Will set a variable with specified name containing the generated function ID to use.
#    * *EXPECTFAIL* (``option``) -- Option indicating whether the section is expected to fail or not, if specified will cause test failure when no exceptions were caught and success upon catching any exceptions.
#    * *PRINT_LENGTH* (``int``) -- Optional argument specifying the desired print length of pass/fail output lines.
#
#]]
macro(ct_add_test)
    cpp_get_global(_at_exec_unit_instance "CT_CURRENT_EXECUTION_UNIT_INSTANCE")
    cpp_get_global(_at_exec_expectfail "CT_EXEC_EXPECTFAIL") #Unset in main interpreter, TRUE in subprocess

    if(NOT ("${_at_exec_unit_instance}" STREQUAL "") AND NOT _at_exec_expectfail)
        CTExecutionUnit(GET "${_at_exec_unit_instance}" _at_exec_unit_friendly_name friendly_name)
        ct_exit("ct_add_test() encountered while executing a CMakeTest test or section named \"${_at_exec_unit_friendly_name}\"")
    endif()



    set(_at_options EXPECTFAIL)
    set(_at_one_value_args NAME PRINT_LENGTH)
    set(_at_multi_value_args "")
    cmake_parse_arguments(CT_ADD_TEST "${_at_options}" "${_at_one_value_args}"
                          "${_at_multi_value_args}" ${ARGN} )


    set(_at_print_length_forced "NO")

    #Default to ${CT_PRINT_LENGTH}, if PRINT_LENGTH option set to valid number then override
    set(_at_print_length "${CT_PRINT_LENGTH}")
    if(CT_ADD_TEST_PRINT_LENGTH GREATER 0)
        set(_at_print_length_forced "YES")
        set(_at_print_length "${CT_ADD_TEST_PRINT_LENGTH}")
    endif()

    set(_at_old_id "${${CT_ADD_TEST_NAME}}")

    if(_at_old_id STREQUAL "")
        cpp_unique_id("${CT_ADD_TEST_NAME}")
    endif()

    if(NOT (_at_exec_expectfail AND ("${_at_old_id}" STREQUAL "")))
        CTExecutionUnit(CTOR test_instance "${${CT_ADD_TEST_NAME}}" "${CT_ADD_TEST_NAME}" "${CT_ADD_TEST_EXPECTFAIL}")
        CTExecutionUnit(SET "${test_instance}" print_length "${_at_print_length}")
        CTExecutionUnit(SET "${test_instance}" print_length_forced "${_at_print_length_forced}")
        CTExecutionUnit(SET "${test_instance}" test_file "${CMAKE_CURRENT_LIST_FILE}")

        cpp_append_global("CMAKETEST_TEST_INSTANCES" "${test_instance}")

        message("Test w/ friendly name \"${CT_ADD_TEST_NAME}\" has ID \"${${CT_ADD_TEST_NAME}}\" and file \"${CMAKE_CURRENT_LIST_FILE}\"")
    endif()
endmacro()




