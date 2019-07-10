include(cmake_test/cmake_test)

ct_add_test("name_mangle")
    set(handle "x_test_section")
    include(cmake_test/detail_/test_section/private)

    ct_add_section("Crashes if argument 1 is not a handle")
        _ct_name_mangle(hello result "x")
        ct_assert_fails_as("_nm_target is not a handle to a TestSection")
    ct_end_section()

    ct_add_section("Crashes if argument 2 is empty")
        _ct_name_mangle(${handle} "" "x")
        ct_assert_fails_as("_nm_mangled_name is empty.")
    ct_end_section()

    ct_add_section("Crashes if argument 3 is empty")
        _ct_name_mangle(${handle} result "")
        ct_assert_fails_as("_nm_attribute is empty")
    ct_end_section()

    ct_add_section("Works")
        _ct_name_mangle(${handle} result "x")
        ct_assert_equal(result "x_test_section_x")
    ct_end_section()
ct_end_test()

ct_add_test("add_prop")
    set(handle "x_test_section")
    include(cmake_test/detail_/test_section/private)

    ct_add_section("Crashes if argument 1 is not a handle")
        _ct_add_prop(hello "result" "x")
        ct_assert_fails_as("_ap_target is not a handle to a TestSection")
    ct_end_section()

    ct_add_section("Crashes if argument 2 is empty")
        _ct_add_prop(${handle} "" "x")
        ct_assert_fails_as("_ap_name is empty.")
    ct_end_section()

    ct_add_section("Works with non-null value")
        _ct_add_prop(${handle} "hello" "world")
        get_property(result GLOBAL PROPERTY "x_test_section_hello")
        ct_assert_equal(result "world")
    ct_end_section()

    ct_add_section("Works with null value")
        _ct_add_prop(${handle} "hello" "")
        get_property(result GLOBAL PROPERTY "x_test_section_hello")
        ct_assert_equal(result "x_test_section_NULL")
    ct_end_section()
ct_end_test()

ct_add_test("get_prop")
    set(handle "x_test_section")
    include(cmake_test/detail_/test_section/private)

    ct_add_section("Crashes if argument 1 is not a handle")
        _ct_get_prop(hello result "x")
        ct_assert_fails_as("_gp_target is not a handle to a TestSection")
    ct_end_section()

    ct_add_section("Crashes if argument 2 is empty")
        _ct_get_prop(${handle} "" "x")
        ct_assert_fails_as("_gp_value is empty.")
    ct_end_section()

    ct_add_section("Crashes if argument 3 is empty")
        _ct_get_prop(${handle} result "")
        ct_assert_fails_as("_gp_name is empty.")
    ct_end_section()

    ct_add_section("Crashes if property does not exist")
        _ct_get_prop(${handle} result "world")
        _ct_assert_fails_as("TestSection has no attribute world")
    ct_end_section()

    ct_add_section("Works with non-null value")
        _ct_add_prop(${handle} "hello" "world")
        _ct_get_prop(${handle} result "hello")
        ct_assert_equal(result "world")
    ct_end_section()

    ct_add_section("Works with null value")
        _ct_add_prop(${handle} "hello" "")
        _ct_get_prop(${handle} result "hello")
        ct_assert_equal(result "")
    ct_end_section()
ct_end_test()
