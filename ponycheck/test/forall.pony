use "ponytest"
use ".."

class ForAllTest is UnitTest
  fun name(): String => "ponycheck/for_all"

  fun apply(h: TestHelper) =>
    Ponycheck.for_all[U8](recover Generators.unit[U8](0) end, h)(
      {(u, h) => h.assert_eq[U8](u, 0, u.string() + " == 0") })

class MultipleForAllTest is UnitTest
  fun name(): String => "ponycheck/multiple_for_all"

  fun apply(h: TestHelper) =>
    Ponycheck.for_all[U8](recover Generators.unit[U8](0) end, h)(
      {(u, h) => h.assert_eq[U8](u, 0, u.string() + " == 0") })

    Ponycheck.for_all[U8](recover Generators.unit[U8](1) end, h)(
      {(u, h) => h.assert_eq[U8](u, 1, u.string() + " == 1") })
