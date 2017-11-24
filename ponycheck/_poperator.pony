class ref _Poperator[T] is Iterator[T^]
  """
  iterate over a `Seq` descructively by `pop`ing its elements

  once `has_next()` returns `false`, the `Seq` is empty.

  Nominee for the annual pony class-naming awards
  """

  let _seq: Seq[T]

  new create(seq: Seq[T]) =>
    _seq = seq

  new empty() =>
    _seq = Array[T](0)

  fun ref has_next(): Bool =>
    _seq.size() > 0

  fun ref next(): T^ ? =>
    _seq.pop()?

