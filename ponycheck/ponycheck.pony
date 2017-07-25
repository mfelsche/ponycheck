
"""
Ponycheck is a library for property based testing
with tight integration into ponytest.

```pony
use "collections"
use "ponycheck"

class ListReverseProperty is Property1[List[USize]]

    fun name(): String => "list/reverse"

    fun gen(): Generator[List[USize]] => Generators.listOf[USize](Generators.uSize())

    fun property(arg1: List[USize], ph: PropertyHelper) =>
        ph.array_eq[Usize](arg1, arg1.reverse().reverse())

```

A property based test in ponytest consists of the following:

* A name (for integration into ponytest mostly)
* One or more generators, depending on how your property is layed out.
  There are tons of them defined on primitive ``Generators``
* Define a property method that asserts a certain property on the samples
  generated by the generator(s) with the help of ``PropertyHelper``
* Optionally, the method ``params()`` can be used to configure how ponycheck executes
  the property


There is a second flavour to ponycheck, we didn't talk about, yet:

```pony
class ListReversePropertyWithinAUnitTest is UnitTest
    fun name(): String => "list/reverse/forall"

    fun apply(h: TestHelper) =>
        let gen = Generators.listOf[USize](Generators.uSize())
        Ponycheck.forAll[List[USize]](gen, h)({(sample: List[USize], ph: PropertyHelper) =>
            ph.array_eq[Usize](arg1, arg1.reverse().reverse())
        })
        // ... possibly more properties, using ``Ponycheck.forAll``
```


The ponycheck machinery will instantiate the provided Generator,
and will execute if for a number of samples.

If the property fails using an assertion method of ``PropertyTestHelper``,
the failed example will be shrunken by the generator
to obtain a smaller and more informative, still failing, sample
for reporting.

"""
use "ponytest"

class ForAll[T]
    let _gen: Generator[T]
    let _helper: TestHelper

    new create(gen': Generator[T], testHelper: TestHelper) =>
        _gen = gen'
        _helper = testHelper

    fun apply(prop: {(T, PropertyHelper) ?} val) ? =>
        """execute"""
        let prop1 = object is Property1[T]
            fun name(): String => ""
            fun gen(): Generator[T] => _gen
            fun property(arg1: T, h: PropertyHelper) ? =>
                prop(consume arg1, h)
        end
        prop1.apply(_helper)

primitive Ponycheck
    fun forAll[T](gen: Generator[T], h: TestHelper): ForAll[T] =>
        """
        convenience method for running 1 to many properties as part of
        one ponytest UnitTest.

        Example:

        class MyTestWithSomeProperties is UnitTest
            fun name(): String => "mytest/withMultipleProperties"

            fun apply(h: TestHelper) =>
                Ponycheck.forAll[U8](Generators.unit[U8](0), h)({(u: U8, h: PropertyHelper): U8^ =>
                    h.assert_eq(u, 0)
                    consume u
                })
        """
        ForAll[T](gen, h)

