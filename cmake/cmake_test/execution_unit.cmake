# Copyright 2023 CMakePP
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#[[[ @module
#
# The execution_unit module houses
# the class that makes up the core of CMakeTest.
# It includes cmakepp_lang to define the class
# and its attrbutes and methods.
#
# .. attention::
#    This module is intended for internal
#    use only.
#]]


include_guard()

include(cmakepp_lang/cmakepp_lang)
include(cmake_test/detail_/utilities/print_result)

#[[[
#
# CTExecutionUnit represents the basic atomic unit of tests.
# Units can be either tests or test sections.
# The unit stores and tracks all state information
# related to the unit, such as the test ID, its friendly
# name, the file that contains it, etc.
#
# This class also contains useful instance methods
# for generating or modifying required information.
#
# An execution unit must be linked to an accompanying
# function that will be executed when this unit is tested.
#
#
#]]
cpp_class(CTExecutionUnit)

    #[[[
    # Stores the unique ID of the unit.
    # This value is autogenerated and
    # is used to name the function
    # this unit is linked to.
    #]]
    cpp_attr(CTExecutionUnit test_id)

    #[[[
    # The "friendly name" of the execution unit.
    # This is equivalent to the NAME parameter
    # when calling ct_add_test() or ct_add_section().
    # Dereferencing the value of this field
    # will yield the ID of this unit while in the
    # scope of the unit.
    #]]
    cpp_attr(CTExecutionUnit friendly_name)

    #[[[
    # The full path that points to the file containing
    # this unit's declaration. This value is propagated
    # down from the root test to all sections and subsections.
    #]]
    cpp_attr(CTExecutionUnit test_file)

    #[[[
    # A boolean describing whether this unit is intended
    # to fail or not. Directly related to the parameter
    # of the same name in ct_add_test() and ct_add_section().
    #]]
    cpp_attr(CTExecutionUnit expect_fail)

    #[[[
    # A reference pointing to the parent execution unit
    # of this unit. This will be empty for the root test
    # and filled for all subsections.
    #]]
    cpp_attr(CTExecutionUnit parent)

    #[[[
    # A map between IDs and references to unit instances
    # used to represent the subsections of this unit.
    #]]
    cpp_attr(CTExecutionUnit children)

    #[[[
    # The length to use for printing in the context of this
    # unit and any subsections that do not override it.
    # This value can be set by the parameter of the same name
    # in ct_add_test() and ct_add_section(). It can also be set
    # via an overriding cache variable.
    #]]
    cpp_attr(CTExecutionUnit print_length "${CT_PRINT_LENGTH}")

    #[[[
    # Describes whether the print length was forced via the call
    # to ct_add_test() or ct_add_section() that constructed
    # this unit.
    #]]
    cpp_attr(CTExecutionUnit print_length_forced FALSE)

    #[[[
    # A boolean describing whether or not this unit
    # should loop over and execute all of its subsections.
    #]]
    cpp_attr(CTExecutionUnit execute_sections FALSE)

    #[[[
    # A map linking section friendly names to Ids so the
    # id isn't lost between the first and second invocation passes.
    #]]
    cpp_attr(CTExecutionUnit section_names_to_ids)

    #[[[
    # A list containing messages representing any exceptions
    # that occurred during the execution of this unit.
    #]]
    cpp_attr(CTExecutionUnit exceptions)

    #[[[
    # Whether this unit has been executed already or not.
    # Useful for determining whether to re-execute
    # after a failed test is detected.
    #]]
    cpp_attr(CTExecutionUnit has_executed FALSE)

    #[[[
    # Whether the pass/fail status of this unit has been
    # printed yet. This ensures that parent units of
    # a failed unit are not printed multiple times.
    #]]
    cpp_attr(CTExecutionUnit has_printed FALSE)

    #[[[
    # Stores how many sections deep this execution unit is.
    # This is used to determine how many tabs to place in front
    # of the pass/fail print line.
    #]]
    cpp_attr(CTExecutionUnit section_depth 0)

    #[[[
    # The value CMAKEPP_LANG_DEBUG_MODE should be set to while
    # running this unit, i.e. what the test code itself will see.
    # Should only be propagated from the test itself.
    #]]
    cpp_attr(CTExecutionUnit debug_mode FALSE)

    #[[[
    # Construct an execution unit with the given ID,
    # friendly name, and expectfail status. The ID
    # is the final function containing
    # the user-defined test code. Since :obj:`~cmake_test/add_test.ct_add_test`
    # and its section counterpart are always called before
    # the test function is defined, the function :code:`${test_id}`
    # will not be a valid function until later in the execution.
    # Thus, the type of test_id is defined here as :code:`desc`.
    #
    # The friendly_name is the user-defined name passed as the :code:`NAME`
    # argument to :obj:`~cmake_test/add_test.ct_add_test` and
    # :obj:`~cmake_test/add_section.ct_add_section`. This name
    # is both a user-identifiable string denoting the unit,
    # and a pointer to the test_id
    #
    # :param test_id: The autogenerated unique ID for the unit,
    #                 typed as str since it may or may not be defined as a function.
    # :param friendly_name: The name given to the test or section by the user
    # :param expect_fail: Whether this unit is expected to fail.
    #
    #]]
    cpp_constructor(CTOR CTExecutionUnit str str bool)
    function("${CTOR}" self test_id friendly_name expect_fail)
        # Name could be a description, a type, or a function because it
        # isn't considered invalid to do so, such as using
        # a test name of "set"
        #
        # ID could be a desc or a function as well,
        # depending on whether the section/test function has
        # been initialized or not yet

        CTExecutionUnit(SET "${self}" test_id "${test_id}")
        CTExecutionUnit(SET "${self}" friendly_name "${friendly_name}")
        CTExecutionUnit(SET "${self}" expect_fail "${expect_fail}")
        cpp_map(CTOR section_names_map)
        CTExecutionUnit(SET "${self}" section_names_to_ids "${section_names_map}")
        cpp_map(CTOR children_map)
        CTExecutionUnit(SET "${self}" children "${children_map}")
    endfunction()

    #[[[
    # Add a new subsection to this unit.
    # The key must point to the ID of the subsection
    # and the value must be a dereferenced pointer
    # pointing to the subsection. We take a function
    # pointer for the key because the ID is used to define
    # the section's function.
    #
    # :param key: Pointer to the ID of the subsection
    # :param child: Reference to the new subsection.
    #]]
    cpp_member(append_child CTExecutionUnit desc CTExecutionUnit)
    function("${append_child}" self key child)
            # key is a pointer to a function because the ID
            # could be either a desc or a fxn depending on whether
            # the function was defined yet. Currently, the
            # type system infers all pointers as desc, which
            # are convertible to all pointer types,
            # really it's a hack to allow
            cpp_get_global(_as_curr_instance "CT_CURRENT_EXECUTION_UNIT_INSTANCE")
            CTExecutionUnit(GET "${_as_curr_instance}" parent_name test_id)
            CTExecutionUnit(GET "${self}" test_id test_id)
            CTExecutionUnit(GET "${self}" children children)
            cpp_map(SET "${children}" "${key}" "${child}")
    endfunction()

    #[[[
    # Construct the list of all parents of this unit
    # from the root down to the immediate parent of this unit.
    # The returned list contains pointers to each of the
    # parents, ordered with the root as the last element.
    #
    # :param ret: A return variable that will be set to the
    #             constructed list.
    #]]
    cpp_member(get_parent_list CTExecutionUnit list*)
    function("${get_parent_list}" self ret)

        CTExecutionUnit(GET "${self}" next_parent parent)
        while(NOT next_parent STREQUAL "")
            CTExecutionUnit(GET "${next_parent}" parent_id test_id)
            list(APPEND ret_list "${next_parent}")
            CTExecutionUnit(GET "${next_parent}" next_parent parent)
        endwhile()
        set("${ret}" "${ret_list}" PARENT_SCOPE)

    endfunction()


    #[[[
    # Get a human-readable representation of this
    # unit.
    #]]
    cpp_member(to_string CTExecutionUnit desc*)
    function("${to_string}" self ret)
        CTExecutionUnit(GET "${self}" name friendly_name)
        CTExecutionUnit(GET "${self}" id test_id)
        CTExecutionUnit(GET "${self}" expect_fail expect_fail)
        CTExecutionUnit(GET "${self}" print_length print_length)
        CTExecutionUnit(GET "${self}" parent parent)
        #CTExecutionUnit(GET "${parent}" parent_map children)
        CTExecutionUnit(GET "${self}" children children)
        cpp_map(KEYS "${children}" children_keys)
        if(NOT parent STREQUAL "")
            #CTExecutionUnit(to_string "${parent}" parent_string)
        endif()

        foreach(child_key IN LISTS children_keys)
            cpp_map(GET "${children}" child "${child_key}")
            CTExecutionUnit(to_string "${child}" child_string)
                set(children_repr "${children_repr}\n\
                    ${child_string}\n")

        endforeach()

        set("${ret}" "Name: $test_id, EXPECTFAIL:  ${expect_fail}, Print length: ${print_length}\n\
        Parent:\n\
            ${parent}\n\
        Children:\n\
            ${children_repr}" PARENT_SCOPE)
        #cpp_return("${ret}")
    endfunction()


    #[[[
    # Executes the test or section that this unit represents.
    # This function handles printing the pass/failure state
    # as well as executing subsections. However, if this unit
    # has already been executed, this function does nothing.
    #
    #]]
    cpp_member(execute CTExecutionUnit)
    function("${execute}" self)
        CTExecutionUnit(GET "${self}" _ex_expect_fail expect_fail)
        cpp_get_global(_ex_exec_expectfail "CT_EXEC_EXPECTFAIL")
        CTExecutionUnit(GET "${self}" _self_has_executed has_executed)
        if (_self_has_executed)
            return()
        endif()
        #Test has not yet been executed

        cpp_get_global(old_instance "CT_CURRENT_EXECUTION_UNIT_INSTANCE")
        cpp_set_global("CT_CURRENT_EXECUTION_UNIT_INSTANCE" "${self}")

        if(_ex_expect_fail AND NOT _ex_exec_expectfail) #If this section expects to fail

            #We're in main interpreter so we need to configure and execute the subprocess
            ct_expectfail_subprocess("${self}")

        else()
            CTExecutionUnit(GET "${self}" id test_id)
            CTExecutionUnit(GET "${self}" debug_mode debug_mode)
            # Defer setting the debug mode to as late as possible
            # Disable in case test does not want debug mode
            cpp_get_global(ct_debug_mode "CT_DEBUG_MODE")
            cpp_get_global(test_debug_mode "CT_CURR_TEST_DEBUG_MODE")
            set(CMAKEPP_LANG_DEBUG_MODE "${debug_mode}")
            cpp_call_fxn("${id}")
            # Reset the debug mode back to what it should be in case test modified it
            set(CMAKEPP_LANG_DEBUG_MODE "${ct_debug_mode}")
        endif()
        cpp_set_global("CT_CURRENT_EXECUTION_UNIT_INSTANCE" "${old_instance}")

        CTExecutionUnit(print_pass_or_fail "${self}")

        CTExecutionUnit(exec_sections "${self}")

        CTExecutionUnit(SET "${self}" has_executed TRUE)

    endfunction()


    #[[[
    # Executes all subsections of this unit.
    # If this unit has no subsections, this
    # function does nothing.
    #
    #]]
    cpp_member(exec_sections CTExecutionUnit)
    function("${exec_sections}" self)
        CTExecutionUnit(GET "${self}" _es_expect_fail expect_fail)
        cpp_get_global(_es_exec_expectfail "CT_EXEC_EXPECTFAIL")

        # Get whether this section has subsections, only run again if subsections detected
        CTExecutionUnit(GET "${self}" _es_children_map children)
        cpp_map(KEYS "${_es_children_map}" _es_has_subsections)

        #If in main interpreter and not expecting to fail OR in subprocess
        if((NOT _es_has_subsections STREQUAL "") AND ((NOT _es_expect_fail AND NOT _es_exec_expectfail) OR (_es_exec_expectfail)))
            cpp_get_global(old_instance "CT_CURRENT_EXECUTION_UNIT_INSTANCE")
            cpp_set_global("CT_CURRENT_EXECUTION_UNIT_INSTANCE" "${self}")
            CTExecutionUnit(SET "${self}" execute_sections TRUE)
            CTExecutionUnit(GET "${self}" id test_id)
            CTExecutionUnit(GET "${self}" debug_mode debug_mode)
            # Defer setting the debug mode to as late as possible
            cpp_get_global(_es_ct_debug_mode "CT_DEBUG_MODE")
            cpp_get_global(test_debug_mode "CT_CURR_TEST_DEBUG_MODE")
            set(CMAKEPP_LANG_DEBUG_MODE "${debug_mode}")
            cpp_call_fxn("${id}")
            # Reset the debug mode back to what it should be in case test modified it
            set(CMAKEPP_LANG_DEBUG_MODE "${_es_ct_debug_mode}")
            cpp_set_global("CT_CURRENT_EXECUTION_UNIT_INSTANCE" "${old_instance}")

        endif()

    endfunction()


    #[[[
    # Determines whether the unit passed or failed
    # and prints it, obeying the section depth,
    # print length, and whether colors are enabled.
    #
    #]]
    cpp_member(print_pass_or_fail CTExecutionUnit)
    function("${print_pass_or_fail}" self)
        CTExecutionUnit(GET "${self}" _ppof_expect_fail expect_fail)
        CTExecutionUnit(GET "${self}" _ppof_friendly_name friendly_name)
        CTExecutionUnit(GET "${self}" _ppof_exceptions exceptions)
        CTExecutionUnit(GET "${self}" _ppof_has_printed has_printed)
        CTExecutionUnit(GET "${self}" _ppof_print_length print_length)
        CTExecutionUnit(GET "${self}" _ppof_section_depth section_depth)

        cpp_get_global(_ppof_exec_expectfail "CT_EXEC_EXPECTFAIL")

        set(_ppof_test_fail "FALSE")

        if(_ppof_expect_fail AND _ppof_exec_expectfail)
            if(NOT "${_as_exceptions}" STREQUAL "")
                foreach(_as_exc IN LISTS _as_exceptions)
                    message("${CT_BoldRed}Test named \"${_as_friendly_name}\" raised exception:")
                    message("${_as_exc}${CT_ColorReset}")
                endforeach()
                set(_as_section_fail "TRUE")
            endif()
        else()
            if(NOT ("${_ppof_exceptions}" STREQUAL ""))

                foreach(_ppof_exc IN LISTS _ppof_exceptions)
                    message("${CT_BoldRed}Test named \"${_ppof_friendly_name}\" raised exception:")
                    message("${_ppof_exc}${CT_ColorReset}")
                endforeach()

                #At least one test failed, so we will inform the caller that not all tests passed.
                cpp_set_global(CMAKETEST_TESTS_DID_PASS "FALSE")
                set(_ppof_test_fail "TRUE")
            endif()
        endif()


        if(_ppof_test_fail)
            if(NOT _ppof_has_printed)
                _ct_print_fail("${_ppof_friendly_name}" "${_ppof_section_depth}" "${_ppof_print_length}")
            endif()
        elseif(NOT _ppof_has_printed)
            _ct_print_pass("${_ppof_friendly_name}" "${_ppof_section_depth}" "${_ppof_print_length}")
        endif()

        CTExecutionUnit(SET "${self}" has_printed TRUE)

    endfunction()

cpp_end_class()
