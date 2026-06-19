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

SVG transform attributes can be parsed and serialized too.

```gleam
import svg_path/transform/parse
import svg_path/transform/serialize

pub fn tidy_transform_attribute(input: String) -> String {
  let assert Ok(matrix) = parse.attribute(input)

  serialize.transform(matrix)
}
```

Transform serialization prefers readable SVG forms such as
`translate(10 20)scale(2)` when the matrix is clearly a translation and scale.
Use `force_matrix` when you want the raw `matrix(a b c d e f)` form.

```gleam
import svg_path/transform
import svg_path/transform/serialize

pub fn raw_transform_attribute() -> String {
  transform.translate(x: 10.0, y: 20.0)
  |> serialize.transform_with_options(
    options: serialize.default_options() |> serialize.force_matrix,
  )
}
```

Further documentation can be found at <https://hexdocs.pm/svg_path>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```
