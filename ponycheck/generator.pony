use "collections"
use "itertools"

trait box GenObj[T]
  fun generate(rnd: Randomness): T^

  fun shrink(t: T): (T^, Seq[T]) =>
    (consume t, Array[T](0))

  fun iter(rnd: Randomness): Iterator[T^]^ =>
    let gen: GenObj[T] = this
    object is Iterator[T^]
      fun ref has_next(): Bool => true
      fun ref next(): T^ => gen.generate(rnd)
    end

class box Generator[T] is GenObj[T]
  let _gen: GenObj[T]

  new create(gen: GenObj[T]) =>
    _gen = gen

  fun generate(rnd: Randomness): T^ =>
    _gen.generate(rnd)

  fun shrink(t: T): (T^, Seq[T]) =>
    _gen.shrink(consume t)

  fun filter(predicate: {(T): (T^, Bool)} box): Generator[T] =>
    Generator[T](
      object is GenObj[T]
        fun generate(rnd: Randomness): T^ =>
          (var t, var matches) = predicate(_gen.generate(rnd))
          while not matches do
            (t, matches) = predicate(_gen.generate(rnd))
          end
          consume t
      end)

  fun map[U](fn: {(T): U^} box): Generator[U] =>
    Generator[U](
      object is GenObj[U]
        fun generate(rnd: Randomness): U^ =>
          fn(_gen.generate(rnd))
      end)

  fun flat_map[U](fn: {(T): Generator[U]} box): Generator[U] =>
    """
    For each value of this generator create a generator that is then combined.
    """
    Generator[U](
      object is GenObj[U]
        fun generate(rnd: Randomness): U^ =>
          fn(_gen.generate(rnd)).generate(rnd)
      end)

type WeightedGenerator[T] is (USize, Generator[T] box)

primitive Generators
  fun unit[T](t: T): Generator[box->T] =>
    Generator[box->T](
      object is GenObj[box->T]
        let _t: T = consume t
        fun generate(rnd: Randomness): this->T => _t
      end)

  fun repeatedly[T](f: {(): T^} box): Generator[T] =>
    Generator[T](
      object is GenObj[T]
        fun generate(rnd: Randomness): T^ =>
          f()
      end)

  fun seq_of[T, S: Seq[T] ref = Array[T]](
    gen: Generator[T],
    min: USize = 0,
    max: USize = 100)
    : Generator[Seq[T]]
  =>
    """
    Create a list from the given Generator with an optional minimum and
    maximum size, defaults are 0 and 100 respectively.
    """
    Generator[Seq[T]](
      object is GenObj[Seq[T]]
        fun generate(rnd: Randomness): Seq[T]^ =>
          Iter[T^](gen.iter(rnd))
            .take(rnd.usize(min, max))
            .collect[S](S(rnd.usize(0, max)))
      end)

  fun one_of[T](xs: ReadSeq[T]): Generator[box->T] ? =>
    """
    Generate a random value from the given ReadSeq. An error will be thrown
    if the given ReadSeq is empty.
    """
    Generator[box->T](
      let err: box->T = xs(0)?
      object is GenObj[box->T]
        fun generate(rnd: Randomness): box->T =>
          let idx = rnd.usize(0, xs.size() - 1)
          try
            xs(idx)?
          else
            err // will never occur
          end
      end)

  fun frequency[T](
    weighted_generators: ReadSeq[WeightedGenerator[T]])
    : Generator[T] ?
  =>
    let filtered =
      Iter[WeightedGenerator[T]](weighted_generators.values())
        .filter(
          {(weightedGen: WeightedGenerator[T]): Bool =>
            weightedGen._1 > 0
          })
        .collect(Array[WeightedGenerator[T]])

    // nasty hack to avoid handling the theoretical error case where we have
    // no generator and thus would have to change the type signature
    let err = filtered(0)?._2

    Generator[T](
      object is GenObj[T]
        fun generate(rnd: Randomness): T^ =>
          let weight_sum: USize =
          try
            Iter[WeightedGenerator[T]](filtered.values())
              .fold[USize](
                {(acc: USize, weightedGen: WeightedGenerator[T]): USize =>
                  weightedGen._1 + acc
                },
                0)?
          else
            0
          end
          let desired_sum = rnd.usize(0, weight_sum)
          var running_sum: USize = 0
          var chosen: (Generator[T] box| None) = None
          for weighted_gen in filtered.values() do
            let new_sum = running_sum + weighted_gen._1
            if (running_sum < desired_sum) and (desired_sum <= new_sum) then
              // we just crossed or reached the desired sum
              chosen = weighted_gen._2
              break
            else
              // update running sum
              running_sum = new_sum
            end
          end
          match chosen
          | let x: Generator[T] box => x.generate(rnd)
          | None => err.generate(rnd)
          end
      end)

  fun zip2[T1, T2](
    gen1: Generator[T1],
    gen2: Generator[T2])
    : Generator[(T1, T2)]
  =>
    Generator[(T1, T2)](
      object is GenObj[(T1, T2)]
        fun generate(rnd: Randomness): (T1^, T2^) =>
          (gen1.generate(rnd), gen2.generate(rnd))
        end)

  fun bool(): Generator[Bool] =>
    Generator[Bool](
      object is GenObj[Bool]
        fun generate(rnd: Randomness): Bool =>
          rnd.bool()
        end)

  fun u8(
    min: U8 = U8.min_value(),
    max: U8 = U8.max_value())
    : Generator[U8]
  =>
    """
    create a generator for U8 values
    """
    Generator[U8](
      object is GenObj[U8]
        fun generate(rnd: Randomness): U8^ =>
          rnd.u8(min, max)
      end)

  fun u16(
    min: U16 = U16.min_value(),
    max: U16 = U16.max_value())
    : Generator[U16]
  =>
    """
    create a generator for U16 values
    """
    Generator[U16](
      object is GenObj[U16]
        fun generate(rnd: Randomness): U16^ =>
          rnd.u16(min  max)
      end)

  fun u32(
    min: U32 = U32.min_value(),
    max: U32 = U32.max_value())
    : Generator[U32]
  =>
    """
    create a generator for U32 values
    """
    Generator[U32](
      object is GenObj[U32]
        fun generate(rnd: Randomness): U32^ =>
          rnd.u32(min, max)
      end)

  fun u64(
    min: U64 = U64.min_value(),
    max: U64 = U64.max_value())
    : Generator[U64]
  =>
    """
    create a generator for U64 values
    """
    Generator[U64](
      object is GenObj[U64]
        fun generate(rnd: Randomness): U64^ =>
          rnd.u64(min, max)
      end)

  fun u128(
    min: U128 = U128.min_value(),
    max: U128 = U128.max_value())
    : Generator[U128]
  =>
    """
    create a generator for U128 values
    """
    Generator[U128](
      object is GenObj[U128]
        fun generate(rnd: Randomness): U128^ =>
          rnd.u128(min, max)
      end)

  fun usize(
    min: USize = USize.min_value(),
    max: USize = USize.max_value())
    : Generator[USize]
  =>
    """
    create a generator for USize values
    """
    Generator[USize](
      object is GenObj[USize]
        fun generate(rnd: Randomness): USize^ =>
          rnd.usize(min, max)
      end)

  fun ulong(
    min: ULong = ULong.min_value(),
    max: ULong = ULong.max_value())
    : Generator[ULong]
  =>
    """
    create a generator for ULong values
    """
    Generator[ULong](
      object is GenObj[ULong]
        fun generate(rnd: Randomness): ULong^ =>
          rnd.ulong(min, max)
      end)

  fun i8(
    min: I8 = I8.min_value(),
    max: I8 = I8.max_value())
    : Generator[I8]
  =>
    """
    create a generator for I8 values
    """
    Generator[I8](
      object is GenObj[I8]
        fun generate(rnd: Randomness): I8^ =>
          rnd.i8(min, max)
      end)

  fun i16(
    min: I16 = I16.min_value(),
    max: I16 = I16.max_value())
    : Generator[I16]
  =>
    """
    create a generator for I16 values
    """
    Generator[I16](
      object is GenObj[I16]
        fun generate(rnd: Randomness): I16^ =>
          rnd.i16(min, max)
      end)

  fun i32(
    min: I32 = I32.min_value(),
    max: I32 = I32.max_value())
    : Generator[I32]
  =>
    """
    create a generator for I32 values
    """
    Generator[I32](
      object is GenObj[I32]
        fun generate(rnd: Randomness): I32^ =>
          rnd.i32(min, max)
      end)

  fun i64(
    min: I64 = I64.min_value(),
    max: I64 = I64.max_value())
    : Generator[I64]
  =>
    """
    create a generator for I64 values
    """
    Generator[I64](
      object is GenObj[I64]
        fun generate(rnd: Randomness): I64^ =>
          rnd.i64(min, max)
        end)

// TODO: add i128 fun

  fun ilong(
    min: ILong = ILong.min_value(),
    max: ILong = ILong.max_value())
    : Generator[ILong]
    =>
    """
    create a generator for ILong values
    """
    Generator[ILong](
      object is GenObj[ILong]
        fun generate(rnd: Randomness): ILong^ =>
          rnd.ilong(min, max)
      end)

  fun isize(
    min: ISize = ISize.min_value(),
    max: ISize = ISize.max_value())
    : Generator[ISize]
  =>
    """
    create a generator for ISize values
    """
    Generator[ISize](
      object is GenObj[ISize]
        fun generate(rnd: Randomness): ISize^ =>
          rnd.isize(min, max)
      end)
