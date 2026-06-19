# svg_path

[![Package Version](https://img.shields.io/hexpm/v/svg_path)](https://hex.pm/packages/svg_path)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/svg_path/)

```sh
gleam add svg_path@1
```

```gleam
import svg_path/parse
import svg_path/serialize

pub fn tidy_path_data(input: String) -> String {
  let assert Ok(path) = parse.path(input)

  serialize.path(path)
}
```

Path serialization can also use relative commands, remove extra whitespace, and
omit repeated command letters.

```gleam
import svg_path/parse
import svg_path/serialize

pub fn compact_path_data(input: String) -> String {
  let assert Ok(path) = parse.path(input)
  let options =
    serialize.relative_decimal_options(2)
    |> serialize.minimize_whitespace
    |> serialize.repeat_commands(False)

  serialize.path_with_options(path, options:)
}
```

```gleam
import svg_path/parse
import svg_path/serialize
import svg_path/transform

pub fn move_path_data(input: String) -> String {
  let assert Ok(path) = parse.path(input)
  let matrix = transform.translate(x: 10.0, y: 20.0)
  let assert Ok(path) = transform.path(path, by: matrix)

  serialize.path(path)
}
```

Use `chain(first:, then:)` when thinking in transform application order. Use
`multiply(left:, right:)` when thinking in matrix multiplication order.

```gleam
import svg_path/transform

pub fn scale_then_move() -> transform.Matrix {
  let scale = transform.scale(factor: 2.0)
  let move = transform.translate(x: 10.0, y: 20.0)

  // These are the same matrix. Applying scale, then move, is move * scale.
  transform.chain(first: scale, then: move)
  // transform.multiply(left: move, right: scale)
}
```

SVG transform attributes can be parsed and serialized too.

```gleam
import svg_path/transform/parse
import svg_path/transform/serialize

pub fn tidy_transform_attribute(input: String) -> String {
  let assert Ok(matrix) = parse.attribute(input)

  serialize.to_string(matrix)
}
```

Transform serialization prefers readable SVG forms such as
`translate(10 20)scale(2)`, `rotate(30)`, and
`translate(10 20)rotate(30)scale(2 3)` when the matrix can be represented
clearly. Use `force_matrix` when you want the raw `matrix(a b c d e f)` form.

```gleam
import svg_path/transform
import svg_path/transform/serialize

pub fn raw_transform_attribute() -> String {
  transform.translate(x: 10.0, y: 20.0)
  |> serialize.to_string_with_options(
    options: serialize.default_options() |> serialize.force_matrix,
  )
}
```

Transform matrices can be inspected as SVG's six matrix values, or converted to
and from `matrix_gleam`'s `mat3f` type.

```gleam
import svg_path/transform

pub fn inspect_transform() -> #(Float, Float, Float, Float, Float, Float) {
  transform.rotate(degrees: 30.0)
  |> transform.to_tuple
}
```

Further documentation can be found at <https://hexdocs.pm/svg_path>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```
