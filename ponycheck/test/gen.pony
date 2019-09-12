use "ponytest"
use ".."
use "collections"
use "itertools"
use "random"
use "time"

class GenRndTest is UnitTest
  fun name(): String => "Gen/random_behaviour"

  fun apply(h: TestHelper) ? =>
    let gen = Generators.u32()
    let rnd1 = Randomness(0)
    let rnd2 = Randomness(0)
    let rnd3 = Randomness(1)
    var same: U32 = 0
    for x in Range(0, 100) do
      let g1 = gen.generate_value(rnd1)?
      let g2 = gen.generate_value(rnd2)?
      let g3 = gen.generate_value(rnd3)?
      h.assert_eq[U32](g1, g2)
      if g1 == g3 then
        same = same + 1
      end
    end
    h.assert_ne[U32](same, 100)


class GenFilterTest is UnitTest
  fun name(): String => "Gen/filter"

  fun apply(h: TestHelper) ? =>
    """
    ensure that filter condition is met for all generated results
    """
    let gen = Generators.u32().filter({
      (u: U32^): (U32^, Bool) =>
        (u, (u%2) == 0)
    })
    let rnd = Randomness(Time.millis())
    for x in Range(0, 100) do
      let v = gen.generate_value(rnd)?
      h.assert_true((v%2) == 0)
    end

class GenUnionTest is UnitTest
  fun name(): String => "Gen/union"

  fun apply(h: TestHelper) ? =>
    """
    assert that a unioned Generator
    produces shrinks of the same type than the generated value.
    """
    let gen = Generators.ascii().union[U8](Generators.u8())
    let rnd = Randomness(Time.millis())
    for x in Range(0, 100) do
      let gs = gen.generate(rnd)?
      match gs
      | (let vs: String, let shrink_iter: Iterator[String^]) =>
        h.assert_true(true)
      | (let vs: U8, let shrink_iter: Iterator[U8^]) =>
        h.assert_true(true)
      | (let vs: U8, let shrink_iter: Iterator[String^]) =>
        h.fail("u8 value, string shrink iter")
      | (let vs: String, let shrink_iter: Iterator[U8^]) =>
        h.fail("string value, u8 shrink iter")
      else
        h.fail("invalid type generated")
      end
    end

class GenFrequencyTest is UnitTest
  fun name(): String => "Gen/frequency"

  fun apply(h: TestHelper) ? =>
    """
    ensure that Generators.frequency(...) generators actually return values
    from different with given frequency
    """
    let gen = Generators.frequency[U8]([
      as WeightedGenerator[U8]:
      (1, Generators.unit[U8](0))
      (0, Generators.unit[U8](42))
      (2, Generators.unit[U8](1))
    ])
    let rnd: Randomness ref = Randomness(Time.millis())

    let generated = Array[U8](100)
    for i in Range(0, 100) do
      generated.push(gen.generate_value(rnd)?)
    end
    h.assert_false(generated.contains(U8(42)), "frequency generated value with 0 weight")
    h.assert_true(generated.contains(U8(0)), "frequency did not generate value with weight of 1")
    h.assert_true(generated.contains(U8(1)), "frequency did not generate value with weight of 2")

    let empty_gen = Generators.frequency[U8](Array[WeightedGenerator[U8]](0))

    h.assert_error({() ? =>
      empty_gen.generate_value(Randomness(Time.millis()))?
    })

class GenFrequencySafeTest is UnitTest
  fun name(): String => "Gen/frequency_safe"

  fun apply(h: TestHelper) =>
    h.assert_error({() ? =>
      Generators.frequency_safe[U8](Array[WeightedGenerator[U8]](0))?
    })

class GenOneOfTest is UnitTest
  fun name(): String => "Gen/one_of"

  fun apply(h: TestHelper) =>
    let gen = Generators.one_of[U8]([as U8: 0; 1])
    let rnd = Randomness(Time.millis())
    h.assert_true(
      Iter[U8^](gen.value_iter(rnd))
        .take(100)
        .all({(u: U8): Bool => (u == 0) or (u == 1) }),
      "one_of generator generated illegal values")
    let empty_gen = Generators.one_of[U8](Array[U8](0))

    h.assert_error({() ? =>
      empty_gen.generate_value(Randomness(Time.millis()))?
    })


class GenOneOfSafeTest is UnitTest
  fun name(): String => "Gen/one_of_safe"

  fun apply(h: TestHelper) =>
    h.assert_error({() ? =>
      Generators.one_of_safe[U8](Array[U8](0))?
    })

class SeqOfTest is UnitTest
  fun name(): String => "Gen/seq_of"

  fun apply(h: TestHelper) ? =>
    let seq_gen =
      Generators.seq_of[U8, Array[U8]](
        Generators.u8(),
        0,
        10)
    let rnd = Randomness(Time.millis())
    h.assert_true(
      Iter[Array[U8]^](seq_gen.value_iter(rnd))
        .take(100)
        .all({
          (a: Array[U8]): Bool =>
            (a.size() >= 0) and (a.size() <= 10) }),
      "Seqs generated with Generators.seq_of are out of bounds")

    match seq_gen.generate(rnd)?
    | (let gen_sample: Array[U8], let shrinks: Iter[Array[U8]^]) =>
      let max_size = gen_sample.size()
      h.assert_true(
        Iter[Array[U8]^](shrinks)
          .all({(a: Array[U8]): Bool =>
            if not (a.size() < max_size) then
              h.log(a.size().string() + " >= " + max_size.string())
              false
            else
              true
            end
          }),
        "shrinking of Generators.seq_of produces too big Seqs")
    else
      h.fail("Generators.seq_of did not produce any shrinks")
    end

class IsoSeqOfTest is UnitTest
  let min: USize = 0
  let max: USize = 200
  fun name(): String => "Gen/iso_seq_of"

  fun apply(h: TestHelper) ? =>
    let seq_gen = Generators.iso_seq_of[String, Array[String] iso](
      Generators.ascii(),
      min,
      max
    )
    let rnd = Randomness(Time.millis())
    h.assert_true(
      Iter[Array[String] iso^](seq_gen.value_iter(rnd))
        .take(100)
        .all({
          (a: Array[String] iso): Bool =>
            (a.size() >= min) and (a.size() <= max) }),
      "Seqs generated with Generators.iso_seq_of are out of bounds")

    match seq_gen.generate(rnd)?
    | (let gen_sample: Array[String] iso, let shrinks: Iter[Array[String] iso^]) =>
      let max_size = gen_sample.size()
      h.assert_true(
        Iter[Array[String] iso^](shrinks)
          .all({(a: Array[String] iso): Bool =>
            if not (a.size() < max_size) then
              h.log(a.size().string() + " >= " + max_size.string())
              false
            else
              true
            end
          }),
        "shrinking of Generators.iso_seq_of produces too big Seqs")
    else
      h.fail("Generators.iso_seq_of did not produce any shrinks")
    end

class SetOfTest is UnitTest
  fun name(): String => "Gen/set_of"

  fun apply(h: TestHelper) ? =>
    """
    this mainly tests that a source generator with a smaller range
    than max is terminating and generating sane sets
    """
    let set_gen =
      Generators.set_of[U8](
        Generators.u8(),
        1024)
    let rnd = Randomness(Time.millis())
    for i in Range(0, 100) do
      let sample: Set[U8] = set_gen.generate_value(rnd)?
      h.assert_true(sample.size() <= 256, "something about U8 is not right")
    end

class SetOfMaxTest is UnitTest
  fun name(): String => "Gen/set_of_max"

  fun apply(h: TestHelper) ? =>
    """
    """
    let rnd = Randomness(Time.millis())
    for size in Range[USize](1, U8.max_value().usize()) do
      let set_gen =
        Generators.set_of[U8](
          Generators.u8(),
          size)
      let sample: Set[U8] = set_gen.generate_value(rnd)?
      h.assert_true(sample.size() <= size, "generated set is too big.")
    end


class SetOfEmptyTest is UnitTest
  fun name(): String => "Gen/set_of_empty"

  fun apply(h: TestHelper) ? =>
    """
    """
    let set_gen =
      Generators.set_of[U8](
        Generators.u8(),
        0)
    let rnd = Randomness(Time.millis())
    for i in Range(0, 100) do
      let sample: Set[U8] = set_gen.generate_value(rnd)?
      h.assert_true(sample.size() == 0, "non-empty set created.")
    end

class SetIsOfIdentityTest is UnitTest
  fun name(): String => "Gen/set_is_of_identity"
  fun apply(h: TestHelper) ? =>
    """
    """
    let set_is_gen_same =
      Generators.set_is_of[String](
        Generators.unit[String]("the highlander"),
        100)
    let rnd = Randomness(Time.millis())
    let sample: SetIs[String] = set_is_gen_same.generate_value(rnd)?
    h.assert_true(sample.size() <= 1,
        "invalid SetIs instances generated: size " + sample.size().string())

class MapOfEmptyTest is UnitTest
  fun name(): String => "Gen/map_of_empty"

  fun apply(h: TestHelper) ? =>
    """
    """
    let map_gen =
      Generators.map_of[String, I64](
        Generators.zip2[String, I64](
          Generators.u8().map[String]({(u: U8): String^ =>
            let s = u.string()
            consume s }),
          Generators.i64(-10, 10)
          ),
        0)
    let rnd = Randomness(Time.millis())
    let sample = map_gen.generate_value(rnd)?
    h.assert_eq[USize](sample.size(), 0, "non-empty map created")

class MapOfMaxTest is UnitTest
  fun name(): String => "Gen/map_of_max"

  fun apply(h: TestHelper) ? =>
    let rnd = Randomness(Time.millis())

    for size in Range(1, U8.max_value().usize()) do
      let map_gen =
        Generators.map_of[String, I64](
          Generators.zip2[String, I64](
            Generators.u16().map[String^]({(u: U16): String^ =>
              u.string()
            }),
            Generators.i64(-10, 10)
            ),
        size)
      let sample = map_gen.generate_value(rnd)?
      h.assert_true(sample.size() <= size, "generated map is too big.")
    end

class MapOfIdentityTest is UnitTest
  fun name(): String => "Gen/map_of_identity"

  fun apply(h: TestHelper) ? =>
    let rnd = Randomness(Time.millis())
    let map_gen =
      Generators.map_of[String, I64](
        Generators.zip2[String, I64](
          Generators.repeatedly[String]({(): String^ =>
            let s = recover String.create(14) end
            s.add("the highlander")
            consume s }),
          Generators.i64(-10, 10)
          ),
      100)
    let sample = map_gen.generate_value(rnd)?
    h.assert_true(sample.size() <= 1)

class MapIsOfEmptyTest is UnitTest
  fun name(): String => "Gen/map_is_of_empty"

  fun apply(h: TestHelper) ? =>
    """
    """
    let map_is_gen =
      Generators.map_is_of[String, I64](
        Generators.zip2[String, I64](
          Generators.u8().map[String]({(u: U8): String^ =>
            let s = u.string()
            consume s }),
          Generators.i64(-10, 10)
          ),
        0)
    let rnd = Randomness(Time.millis())
    let sample = map_is_gen.generate_value(rnd)?
    h.assert_eq[USize](sample.size(), 0, "non-empty map created")

class MapIsOfMaxTest is UnitTest
  fun name(): String => "Gen/map_is_of_max"

  fun apply(h: TestHelper) ? =>
    let rnd = Randomness(Time.millis())

    for size in Range(1, U8.max_value().usize()) do
      let map_is_gen =
        Generators.map_is_of[String, I64](
          Generators.zip2[String, I64](
            Generators.u16().map[String]({(u: U16): String^ =>
              let s = u.string()
              consume s }),
            Generators.i64(-10, 10)
            ),
        size)
      let sample = map_is_gen.generate_value(rnd)?
      h.assert_true(sample.size() <= size, "generated map is too big.")
    end

class MapIsOfIdentityTest is UnitTest
  fun name(): String => "Gen/map_is_of_identity"

  fun apply(h: TestHelper) ? =>
    let rnd = Randomness(Time.millis())
    let map_gen =
      Generators.map_is_of[String, I64](
        Generators.zip2[String, I64](
          Generators.unit[String]("the highlander"),
          Generators.i64(-10, 10)
          ),
      100)
    let sample = map_gen.generate_value(rnd)?
    h.assert_true(sample.size() <= 1)

class ASCIIRangeTest is UnitTest
  fun name(): String => "Gen/ascii_range"
  fun apply(h: TestHelper) ? =>
    let rnd = Randomness(Time.millis())
    let ascii_gen = Generators.ascii( where min=1, max=1, range=ASCIIAll)

    for i in Range[USize](0, 100) do
      let sample = ascii_gen.generate_value(rnd)?
      h.assert_true(ASCIIAll().contains(sample), "\"" + sample + "\" not valid ascii")
    end

class UTF32CodePointStringTest is UnitTest
  fun name(): String => "Gen/utf32_codepoint_string"
  fun apply(h: TestHelper) ? =>
    let rnd = Randomness(Time.millis())
    let string_gen = Generators.utf32_codepoint_string(
      Generators.u32(),
      50,
      100)

    for i in Range[USize](0, 100) do
      let sample = string_gen.generate_value(rnd)?
      for cp in sample.runes() do
        h.assert_true((cp <= 0xD7FF ) or (cp >= 0xE000), "\"" + sample + "\" invalid utf32")
      end
    end

