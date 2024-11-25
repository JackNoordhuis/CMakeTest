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

include_guard()

include(cmakepp_lang/cmakepp_lang)

#[[[
# This function will find all :code:`*.cmake` files in the specified directory
# as well as recursively through all subdirectories. It will then configure the
# boilerplate template to include() each cmake file and register each
# configured boilerplate with CTest. The configured templates will be executed
# seperately via CTest during the Test phase, and each *.cmake file found in
# the specified directory is assumed to contain CMakeTest tests.
#
# :param test_dir: The directory to search for *.cmake files containing tests.
#                  Subdirectories will be recursively searched.
# :type test_dir: path
#
# **Keyword Arguments**
#
# :keyword CT_DEBUG_MODE_ON: Enables debug mode when the tests are run.
# :type CT_DEBUG_MODE_ON: bool
# :keyword USE_REL_PATH_NAMES: Enables using shorter, relative paths for
#                              test names, but increases the chance of name
#                              collisions.
# :type USE_REL_PATH_NAMES: bool
# :keyword FLAT_PATH_NAMES: When enabled, every *.cmake test source found will
#                           have its build directory name be its cleaned
#                           relative source path name. All build directories
#                           are generated under:
#                           `${CMAKE_CURRENT_BINARY_DIRECTORY}/tests`.
# :type FLAT_PATH_NAMES: bool
# :keyword WITHOUT_SYMLINKS: When enabled, forces CTest to use the real path to
#                            the generated test build directory (will not
#                            create `CMakeTest` directory in build root.)
# :type WITHOUT_SYMLINKS: bool
# :keyword NAMESPACE: The 'main label' for all tests found in the directory.
#                     When no namespace is specified, the top-level test
#                     directory name (from `${test_dir}`) and current project
#                     name (`${PROJECT_NAME}`) are combined, creating a unique
#                     global identifier.  All generated CTest files will be
#                     created in:
#                     `${CMAKE_CURRENT_BINARY_DIR}/test/${NAMESPACE}`.
# :type NAMESPACE: str
# :keyword LABEL: CTest labels for all the tests found in the directory. Run
#                 a group of labeled tests with `ctest -L <label>`.
# :type LABEL: list
# :keyword BINARY_DIR: The root output directory for generated test files.
#                      Defaults to `${CMAKE_CURRENT_BINARY_DIR}` (the callers
#                      binary directory.)
# :type BINARY_DIR: str
# :keyword CMAKE_OPTIONS: List of additional CMake options to be passed to all
#                         test invocations. Options should follow the syntax:
#                         :code:`-D<variable_name>=<value>`
# :type CMAKE_OPTIONS: list
#]]
function(ct_add_dir _ad_test_dir)
    set(_ad_multi_value_args "CMAKE_OPTIONS" "LABEL")
    set(_ad_single_value_args "NAMESPACE" "BINARY_DIR")

    # TODO: This name is potentially misleading because it seems to enable
    #       debug mode for the test projects (see the use of 'ct_debug_mode'
    #       in cmake/cmake_test/templates/test_project_CMakeLists.txt.in).
    #       I propose renaming it to something like "ENABLE_DEBUG_MODE_IN_TESTS".
    set(_ad_options "CT_DEBUG_MODE_ON" "USE_REL_PATH_NAMES" "FLAT_PATH_NAMES" "WITHOUT_SYMLINKS") # TODO: Respect `FLAT_PATH_NAMES` && `WITHOUT_SYMLINKS`
    cmake_parse_arguments(PARSE_ARGV 1 ADD_DIR "${_ad_options}" "${_ad_single_value_args}" "${_ad_multi_value_args}")

    # This variable will be picked up by the template
    # TODO: This variable should be made Config File-specific and may end up
    #       mirroring the rename of CT_DEBUG_MODE_ON above, if that happens
    set(ct_debug_mode "${ADD_DIR_CT_DEBUG_MODE_ON}")

    # We expect to be given relative paths wrt the project, like
    # ``ct_add_dir("test")``. This ensures we have an absolute path
    # to the test directory as well as a CMake-style normalized path.
    get_filename_component(_ad_abs_test_dir "${_ad_test_dir}" REALPATH)
    file(TO_CMAKE_PATH "${_ad_abs_test_dir}" _ad_abs_test_dir)

    # Recurse over the test directory to find all cmake files
    # (assumed to all be test files)
    file(GLOB_RECURSE
        _ad_test_files
        LIST_DIRECTORIES FALSE
        FOLLOW_SYMLINKS "${_ad_abs_test_dir}/*.cmake"
    )

    # Defaults to the base test directory name (`_ad_test_dir`)
    # when no namespace is explicity provied.
    get_filename_component(_ad_dir_namespace "${_ad_abs_test_dir}" NAME)
    if(NOT "${ADD_DIR_NAMESPACE}" STREQUAL "")
        set(_ad_dir_namespace "${ADD_DIR_NAMESPACE}")
    endif()

    # Defaults to the `${CMAKE_CURRENT_BINARY_DIR}` binary
    # directory of the caller.
   set(_ad_binary_dir "${CMAKE_CURRENT_BINARY_DIR}")
    if(NOT "${ADD_DIR_BINARY_DIR}" STREQUAL "")
        set(_ad_binary_dir "${ADD_DIR_BINARY_DIR}")
    endif()

    # Absolute path to build directory for all tests in added path.
    set(_ad_binary_dir "${_ad_binary_dir}/${_ad_dir_namespace}")
    file(MAKE_DIRECTORY "${_ad_binary_dir}")

    # Defaults to on for windows, minimizing path name lengths
    if("${ADD_DIR_WITHOUT_SYMLINKS}" STREQUAL "")
        set(ADD_DIR_WITHOUT_SYMLINKS WIN32)
    endif()

    if(ADD_DIR_WITHOUT_SYMLINKS)
        if(WIN32)
            message(AUTHOR_WARNING "[function] ct_add_dir(): Option "
            "`WITHOUT_SYMLINKS` provided and `WIN32` environment detected."
            "Tests may fail due to Windows legacy path limitations. See: "
            "https://developercommunity.visualstudio.com/t/compiler-cant-find-source-file-in-path/10221576")
        endif()
    else()
        # Absolute path to directory containing symlinks with flattened path
        # (hashed) names. 
        set(_ad_dir_flattened_binary_dir "${CMAKE_BINARY_DIR}/CMakeTest")
        file(MAKE_DIRECTORY "${_ad_dir_flattened_binary_dir}")

        # Limit path lengths on Windows to avoid the old 255 char path length
        # limit. Even with long paths enabled, cl.exe will fail to start in a
        # working directory exceeding the old limit. We work around this by
        # creating symlinks under the builds root binary directory. See:
        # https://developercommunity.visualstudio.com/t/compiler-cant-find-source-file-in-path/10221576
        string(LENGTH "${_ad_dir_flattened_binary_dir}" _ad_dir_flattened_binary_dir_length)
        # single 64 char length segments seem to error as well? (WIN11, VS2022)
        set(_ad_dir_flattened_binary_dir_trim_length 48) 

        if(WIN32) # perform checks to limit path names
            # Limit hash string length based on the predicted path size. Hash
            # is the absolute path to the real build directory. The chance of
            # collisions is, in theory, so small we trim the hash to a minimum
            # of 16 chars before issuing an error.
            #
            # 255 - (48 (hash str length) + 100 chars for sub-build paths)
            if(${_ad_dir_flattened_binary_dir_length} GREATER_EQUAL 107)
                if(${_ad_dir_flattened_binary_dir_length} GREATER 139)
                    message(FATAL_ERROR "Build directory path name is too long \"${ADD_DIR_BINARY_DIR}/CMakeTest\" (${_ad_dir_flattened_binary_dir_length} chars). CMake calls to try_compile will fail with compiler errors as some programs still expect short (255 character) paths.
Specify a binary directory for tests with add_dir(<dir> BINARY_DIR \"A/Shorter/Path\"). Alternatively, move your projects build directory to a shorter path.")
                elseif(${_ad_dir_flattened_binary_dir_length} LESS_EQUAL 123)
                    set(_ad_dir_flattened_binary_dir_trim_length 32)
                else()#(${_ad_dir_flattened_binary_dir_length} LESS_EQUAL 129)
                    set(_ad_dir_flattened_binary_dir_trim_length 16)
                endif()
            endif()
        endif()
    endif()

    # Each test file will get its own directory and "mini-project" in the
    # build directory to facilitate independently running each test case.
    # These directories are created from hashes of the test directory and
    # test file paths to help ensure that each path is unique
    foreach(_ad_test_file ${_ad_test_files})
        # Prefer the relative path for generated test sources
        file(RELATIVE_PATH _ad_test_rel_path "${_ad_abs_test_dir}" "${_ad_test_file}")
        file(TO_CMAKE_PATH "${_ad_test_rel_path}" _ad_test_rel_path)
        string(REPLACE "/" "." _ad_test_name "${_ad_test_rel_path}") # needs leading '.' stripped ???

        get_filename_component(_ad_test_dir_name "${_ad_test_file}" NAME)

        if(NOT "${ADD_DIR_NAMESPACE}" STREQUAL "")
            set(_ad_test_name "${ADD_DIR_NAMESPACE}.${_ad_test_name}")
        endif()

        set(_ad_test_binary_dir "${_ad_binary_dir}")

        # Set the test file path for configuring the test mini-project
        set(_CT_CMAKELISTS_TEMPLATE_TEST_FILE "${_ad_test_file}")

        # Sanitize the full path to the test file to get the mini-project name
        # for configuring the test mini-project
        cpp_sanitize_string(
            _CT_CMAKELISTS_TEMPLATE_PROJECT_NAME "${_ad_test_name}"
        )

        if (ADD_DIR_FLAT_PATH_NAMES)
            set(_ad_test_dest_full_path
                "${_ad_test_binary_dir}/${_ad_test_rel_path}"
            )
        else()
            # Mangle the test directory and test file paths, since path strings
            # commonly have characters that are illegal in file names
            cpp_sanitize_string(_ad_test_dest_prefix "${_ad_abs_test_dir}")
            cpp_sanitize_string(_ad_test_proj_dir "${_ad_test_rel_path}")

            # Get hashes for the prefix directory and test project directory
            string(SHA256 _ad_test_dest_prefix_hash "${_ad_test_dest_prefix}")
            string(SHA256 _ad_test_proj_dir_hash "${_ad_test_proj_dir}")

            # Truncate the hashes to 7 characters
            set(_ad_hash_length 7)
            string(SUBSTRING 
                "${_ad_test_dest_prefix_hash}"
                0
                "${_ad_hash_length}"
                _ad_test_dest_prefix_hash
            )
            string(SUBSTRING 
                "${_ad_test_proj_dir_hash}"
                0
                "${_ad_hash_length}"
                _ad_test_proj_dir_hash
            )

            # Create the test destination path in the build directory
            set(_ad_test_dest_full_path
                "${_ad_test_binary_dir}/${_ad_test_dest_prefix_hash}/${_ad_test_proj_dir_hash}"
            )
        endif()

        # Configure the CMakeLists.txt for test in the build directory
        configure_file(
            "${_CT_TEMPLATES_DIR}/test_CMakeLists.txt.in"
            "${_ad_test_dest_full_path}/src/CMakeLists.txt"
            @ONLY
        )

        if (ADD_DIR_USE_REL_PATH_NAMES)
            # Option 1 - shortest but highest collision likelyhood
            # Prepend the test name to the relative path to test file from the
            # given test directory

            # set(_ad_test_name "${}/${_ad_test_file_rel_path}")


            # Option 2 - longest but least collision likelyhood
            # Get the path from the root of the project, with the project name
            # prepended

            # Generate relative path from project root for the test name
            # file(RELATIVE_PATH
            #     _ad_test_file_rel_path_from_proj_root
            #     "${PROJECT_SOURCE_DIR}"
            #     "${_ad_test_file}"
            # )
            # # Prepend the project name to the relative path
            # set(_ad_test_name "${PROJECT_NAME}/${_ad_test_file_rel_path_from_proj_root}")


            # Option 3 - in-between length and collision likelyhood
            # Prepend the project name and given test directory name to the
            # test file relative path
            get_filename_component(_ad_test_dir_name "${_ad_test_dir}" NAME)
            set(_ad_test_name "${PROJECT_NAME}::${_ad_test_dir_name}/${_ad_test_file_rel_path}")
        else()
            set(_ad_test_name "${_ad_test_file}")
        endif()

        if (NOT ADD_DIR_WITHOUT_SYMLINKS)
            # Symbolic links minimizes the length of directory names, helping
            # to avoid hitting windows 255 char path limitation. See:
            # https://developercommunity.visualstudio.com/t/compiler-cant-find-source-file-in-path/10221576
            string(SHA256 _ad_test_dest_hash "${_ad_test_dest_full_path}/${_ad_test_name}")
            string(SUBSTRING "${_ad_test_dest_hash}" 0 ${_ad_dir_flattened_binary_dir_trim_length} _ad_test_dest_hash)
            file(CREATE_LINK "${_ad_test_dest_full_path}" "${_ad_dir_flattened_binary_dir}/${_ad_test_dest_hash}"
                SYMBOLIC
                RESULT _ad_bin_dir_link_result
            )
            set(_ad_test_dest_full_path "${CMAKE_BINARY_DIR}/CMakeTest/${_ad_test_dest_hash}")
        endif()

        add_test(
            NAME
                "${_ad_test_name}"
            COMMAND
                "${CMAKE_COMMAND}"
                -S "${_ad_test_dest_full_path}/src"
                -B "${_ad_test_dest_full_path}"
                ${ADD_DIR_CMAKE_OPTIONS}
        )

        if (NOT "${ADD_DIR_LABEL}" STREQUAL "")
            set_property(TEST "${_ad_test_name}" PROPERTY LABELS ${ADD_DIR_LABEL})
        endif()
    endforeach()

#
#    file(GLOB_RECURSE _ad_files LIST_DIRECTORIES FALSE FOLLOW_SYMLINKS "${_ad_abs_test_dir}/*.cmake") #Recurse over target dir to find all cmake files
#
#    # This variable will be picked up by the template
#    set(ct_debug_mode "${ADD_DIR_CT_DEBUG_MODE_ON}")
#
#    foreach(_ad_test_file ${_ad_files})
#        #Find rel path so we don't end up with insanely long paths under test folders
#        file(RELATIVE_PATH _ad_rel_path "${_ad_abs_test_dir}" "${_ad_test_file}")
#        string(REPLACE "/" "." _ad_test_name "${_ad_rel_path}")
#        string(REPLACE ":" "_" _ad_test_name "${_ad_test_name}")
#
#        if(NOT "${ADD_DIR_NAMESPACE}" STREQUAL "")
#            set(_ad_test_name "${ADD_DIR_NAMESPACE}.${_ad_test_name}")
#        endif()
#
#        set(_ad_test_binary_dir "${_ad_binary_dir}/${_ad_rel_path}")
#        set(_ad_exec_dir "${_ad_test_binary_dir}") # Source and working directory where CMake configuration will take place.
#
#        if(WIN32)
#            file(MAKE_DIRECTORY "${_ad_test_binary_dir}")
#            string(SHA256 _ad_bin_dir_hash "${_ad_test_binary_dir}")
#            string(SUBSTRING "${_ad_bin_dir_hash}" 0 ${_ad_bin_dir_trim_length} _ad_bin_dir_hash)
#
#            file(CREATE_LINK "${_ad_test_binary_dir}" "${CMAKE_BINARY_DIR}/CMakeTest/${_ad_bin_dir_hash}"
#                SYMBOLIC
#                RESULT _ad_bin_dir_link_result
#            )
#
#            if(NOT ${_ad_bin_dir_link_result} EQUAL 0)
#                message(FATAL_ERROR "Failed to create symbolic link for test build directory.
#From: \"${_ad_binary_dir}\" To: \"${CMAKE_BINARY_DIR}/CMakeTest/${_ad_bin_dir_hash}\"
#Error message: ${_ad_bin_dir_link_result}")
#            endif()
#
#            set(_ad_exec_dir "${CMAKE_BINARY_DIR}/CMakeTest/${_ad_bin_dir_hash}")
#        endif()
#
#        add_test(
#        NAME
#            "${_ad_test_name}"
#        WORKING_DIRECTORY "${_ad_exec_dir}"
#        COMMAND
#            "${CMAKE_COMMAND}"
#               -S "${_ad_exec_dir}"
#               -B "${_ad_exec_dir}/build"
#               -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
#               ${ADD_DIR_CMAKE_OPTIONS}
#        )
#    endforeach()
endfunction()
