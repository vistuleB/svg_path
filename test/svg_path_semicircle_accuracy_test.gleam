import gleam/float
import gleam/list
import svg_path/ellipse.{EllipsePoint, EndpointArcData}

fn near(actual: Float, expected: Float, tolerance: Float) {
  assert float.absolute_value(actual -. expected) <=. tolerance
}

pub fn near_semicircle_exact_svg_centers_test() {
  // Expected centers use 80-digit Decimal arithmetic on exact binary64 inputs.
  // Includes circles, non-circular ellipses, translations and three scales.
  let fixtures = [
    #(
      EllipsePoint(-555.8531980329952, -831.2804714634476),
      EllipsePoint(555.8531980329952, 831.2804714634476),
      EllipsePoint(1000.0, 1000.0),
      True,
      EllipsePoint(-5.317918070671085e-06, 3.5559379390400564e-06),
      1.0026589590353357e-18,
    ),
    #(
      EllipsePoint(-555.8531980329952, -1662.5609429268952),
      EllipsePoint(555.8531980329952, 1662.5609429268952),
      EllipsePoint(1000.0, 2000.0),
      True,
      EllipsePoint(-5.317918070671085e-06, 7.111875878080113e-06),
      1.00355593793904e-18,
    ),
    #(
      EllipsePoint(-555.8531980329952, -415.6402357317238),
      EllipsePoint(555.8531980329952, 415.6402357317238),
      EllipsePoint(1000.0, 500.0),
      True,
      EllipsePoint(-5.317918070671085e-06, 1.7779689695200282e-06),
      1.0026589590353357e-18,
    ),
    #(
      EllipsePoint(-0.5558531980329953, -0.8312804714634476),
      EllipsePoint(0.5558531980329953, 0.8312804714634476),
      EllipsePoint(1.0, 1.0),
      True,
      EllipsePoint(0.0, 0.0),
      1.0000000000000001e-21,
    ),
    #(
      EllipsePoint(-0.5558531980329953, -1.6625609429268953),
      EllipsePoint(0.5558531980329953, 1.6625609429268953),
      EllipsePoint(1.0, 2.0),
      True,
      EllipsePoint(0.0, 0.0),
      1.0000000000000001e-21,
    ),
    #(
      EllipsePoint(-0.5558531980329953, -0.4156402357317238),
      EllipsePoint(0.5558531980329953, 0.4156402357317238),
      EllipsePoint(1.0, 0.5),
      True,
      EllipsePoint(0.0, 0.0),
      1.0000000000000001e-21,
    ),
    #(
      EllipsePoint(-569_193.6747857871, -851_231.2027785704),
      EllipsePoint(569_193.6747857871, 851_231.2027785704),
      EllipsePoint(1_024_000.0, 1_024_000.0),
      True,
      EllipsePoint(-0.005445548104367191, 0.0036412804495770178),
      1.0267227740521838e-15,
    ),
    #(
      EllipsePoint(-569_193.6747857871, -1_702_462.4055571407),
      EllipsePoint(569_193.6747857871, 1_702_462.4055571407),
      EllipsePoint(1_024_000.0, 2_048_000.0),
      True,
      EllipsePoint(-0.005445548104367191, 0.0072825608991540355),
      1.027641280449577e-15,
    ),
    #(
      EllipsePoint(-569_193.6747857871, -425_615.6013892852),
      EllipsePoint(569_193.6747857871, 425_615.6013892852),
      EllipsePoint(1_024_000.0, 512_000.0),
      True,
      EllipsePoint(-0.005445548104367191, 0.0018206402247885089),
      1.0267227740521838e-15,
    ),
    #(
      EllipsePoint(10_529.317836279792, -19_151.576386351677),
      EllipsePoint(9470.682163720208, -20_848.423613648323),
      EllipsePoint(999.9999999999999, 999.9999999999999),
      False,
      EllipsePoint(9999.999987873407, -19_999.999992434416),
      1.000000099621721e-11,
    ),
    #(
      EllipsePoint(10_529.317836279792, -38_303.15277270335),
      EllipsePoint(9470.682163720208, -41_696.84722729665),
      EllipsePoint(999.9999999999999, 1999.9999999999998),
      False,
      EllipsePoint(9999.999987873407, -39_999.99998486883),
      2.0000000992434418e-11,
    ),
    #(
      EllipsePoint(10_529.317836279792, -9575.788193175838),
      EllipsePoint(9470.682163720208, -10_424.211806824162),
      EllipsePoint(999.9999999999999, 499.99999999999994),
      False,
      EllipsePoint(9999.999987873407, -9999.999996217208),
      5.000000998108604e-12,
    ),
    #(
      EllipsePoint(10.529317836279791, -19.151576386351678),
      EllipsePoint(9.470682163720209, -20.848423613648325),
      EllipsePoint(0.9999999999999999, 0.9999999999999999),
      False,
      EllipsePoint(9.999999987931044, -19.999999992470375),
      1.0000000996235188e-14,
    ),
    #(
      EllipsePoint(10.529317836279791, -38.303152772703356),
      EllipsePoint(9.470682163720209, -41.69684722729665),
      EllipsePoint(0.9999999999999999, 1.9999999999999998),
      False,
      EllipsePoint(9.999999987931044, -39.99999998494075),
      2.0000000992470376e-14,
    ),
    #(
      EllipsePoint(10.529317836279791, -9.575788193175839),
      EllipsePoint(9.470682163720209, -10.424211806824163),
      EllipsePoint(0.9999999999999999, 0.49999999999999994),
      False,
      EllipsePoint(9.999999987931044, -9.999999996235188),
      5.000000998117594e-15,
    ),
    #(
      EllipsePoint(10_782_021.464350507, -19_611_214.219624117),
      EllipsePoint(9_697_978.535649493, -21_348_785.780375883),
      EllipsePoint(1_023_999.9999999999, 1_023_999.9999999999),
      False,
      EllipsePoint(10_239_999.987582369, -20_479_999.99225284),
      1.0240001020126422e-08,
    ),
    #(
      EllipsePoint(10_782_021.464350507, -39_222_428.439248234),
      EllipsePoint(9_697_978.535649493, -42_697_571.560751766),
      EllipsePoint(1_023_999.9999999999, 2_047_999.9999999998),
      False,
      EllipsePoint(10_239_999.987582369, -40_959_999.98450568),
      2.0480001016252844e-08,
    ),
    #(
      EllipsePoint(10_782_021.464350507, -9_805_607.109812059),
      EllipsePoint(9_697_978.535649493, -10_674_392.890187941),
      EllipsePoint(1_023_999.9999999999, 511_999.99999999994),
      False,
      EllipsePoint(10_239_999.987582369, -10_239_999.99612642),
      5.120001022063211e-09,
    ),
    #(
      EllipsePoint(10_529.317836279792, -19_151.576386351677),
      EllipsePoint(9470.682163720208, -20_848.423613648323),
      EllipsePoint(999.9999999999999, 999.9999999999999),
      True,
      EllipsePoint(10_000.000012126593, -20_000.000007565584),
      1.0000001003782794e-11,
    ),
    #(
      EllipsePoint(10_529.317836279792, -38_303.15277270335),
      EllipsePoint(9470.682163720208, -41_696.84722729665),
      EllipsePoint(999.9999999999999, 1999.9999999999998),
      True,
      EllipsePoint(10_000.000012126593, -40_000.00001513117),
      2.0000001007565587e-11,
    ),
    #(
      EllipsePoint(10_529.317836279792, -9575.788193175838),
      EllipsePoint(9470.682163720208, -10_424.211806824162),
      EllipsePoint(999.9999999999999, 499.99999999999994),
      True,
      EllipsePoint(10_000.000012126593, -10_000.000003782792),
      5.000001006063296e-12,
    ),
    #(
      EllipsePoint(10.529317836279791, -19.151576386351678),
      EllipsePoint(9.470682163720209, -20.848423613648325),
      EllipsePoint(0.9999999999999999, 0.9999999999999999),
      True,
      EllipsePoint(10.000000012068956, -20.00000000752963),
      1.0000001003764815e-14,
    ),
    #(
      EllipsePoint(10.529317836279791, -38.303152772703356),
      EllipsePoint(9.470682163720209, -41.69684722729665),
      EllipsePoint(0.9999999999999999, 1.9999999999999998),
      True,
      EllipsePoint(10.000000012068956, -40.00000001505926),
      2.000000100752963e-14,
    ),
    #(
      EllipsePoint(10.529317836279791, -9.575788193175839),
      EllipsePoint(9.470682163720209, -10.424211806824163),
      EllipsePoint(0.9999999999999999, 0.49999999999999994),
      True,
      EllipsePoint(10.000000012068956, -10.000000003764814),
      5.000001006034478e-15,
    ),
    #(
      EllipsePoint(10_782_021.464350507, -19_611_214.219624117),
      EllipsePoint(9_697_978.535649493, -21_348_785.780375883),
      EllipsePoint(1_023_999.9999999999, 1_023_999.9999999999),
      True,
      EllipsePoint(10_240_000.012417631, -20_480_000.00774716),
      1.0240001027873581e-08,
    ),
    #(
      EllipsePoint(10_782_021.464350507, -39_222_428.439248234),
      EllipsePoint(9_697_978.535649493, -42_697_571.560751766),
      EllipsePoint(1_023_999.9999999999, 2_047_999.9999999998),
      True,
      EllipsePoint(10_240_000.012417631, -40_960_000.01549432),
      2.048000103174716e-08,
    ),
    #(
      EllipsePoint(10_782_021.464350507, -9_805_607.109812059),
      EllipsePoint(9_697_978.535649493, -10_674_392.890187941),
      EllipsePoint(1_023_999.9999999999, 511_999.99999999994),
      True,
      EllipsePoint(10_240_000.012417631, -10_240_000.00387358),
      5.1200010302088155e-09,
    ),
  ]
  list.each(fixtures, fn(f) {
    let assert Ok(arc) =
      ellipse.endpoint_to_center(EndpointArcData(f.0, f.2, 0.0, False, f.3, f.1))
    near(arc.center.x, f.4.x, f.5)
    near(arc.center.y, f.4.y, f.5)
  })
}

pub fn near_semicircle_flags_select_opposite_centers_test() {
  list.each([False, True], fn(large) {
    list.each([False, True], fn(sweep) {
      let assert Ok(arc) =
        ellipse.endpoint_to_center(EndpointArcData(
          EllipsePoint(-555.8531980329952, -831.2804714634476),
          EllipsePoint(1000.0, 1000.0),
          0.0,
          large,
          sweep,
          EllipsePoint(555.8531980329952, 831.2804714634476),
        ))
      let sign = case large == sweep {
        True -> -1.0
        False -> 1.0
      }
      near(
        arc.center.x,
        sign *. -0.0000053179180706710844,
        0.000000000000000001,
      )
      near(arc.center.y, sign *. 0.0000035559379390400563, 0.000000000000000001)
      assert { arc.delta_angle >. 0.0 } == sweep
      assert { float.absolute_value(arc.delta_angle) >. 180.0 } == large
    })
  })
}

pub fn exact_semicircle_and_enlarged_radii_keep_midpoint_test() {
  list.each([0.5, 1.0], fn(radius) {
    let assert Ok(arc) =
      ellipse.endpoint_to_center(EndpointArcData(
        EllipsePoint(-1.0, 0.0),
        EllipsePoint(radius, radius *. 2.0),
        0.0,
        False,
        True,
        EllipsePoint(1.0, 0.0),
      ))
    assert arc.center == EllipsePoint(0.0, 0.0)
    assert arc.radius == EllipsePoint(1.0, 2.0)
  })
  list.each([#(10.0, 5.0, 30.0), #(5.0, 10.0, 120.0)], fn(axes) {
    let assert Ok(arc) =
      ellipse.endpoint_to_center(EndpointArcData(
        EllipsePoint(0.0, 0.0),
        EllipsePoint(axes.0, axes.1),
        axes.2,
        False,
        True,
        EllipsePoint(20.0, 0.0),
      ))
    assert arc.center == EllipsePoint(10.0, 0.0)
  })
}

pub fn near_semicircle_bounds_and_quadrant_rotations_test() {
  list.each([0.0, 90.0, 180.0, 270.0], fn(rotation) {
    let assert Ok(arc) =
      ellipse.endpoint_to_center(EndpointArcData(
        EllipsePoint(-555.8531980329952, -831.2804714634476),
        EllipsePoint(1000.0, 1000.0),
        rotation,
        False,
        True,
        EllipsePoint(555.8531980329952, 831.2804714634476),
      ))
    near(arc.center.x, -0.0000053179180706710844, 0.000000000000000001)
    near(arc.center.y, 0.0000035559379390400563, 0.000000000000000001)
    let box = ellipse.arc_bounding_box(arc)
    near(box.max.x, 999.9999946820819, 0.000000000002)
    near(box.min.y, -999.9999964440621, 0.000000000002)
    near(box.min.x, -555.8531980329952, 0.000000000002)
    near(box.max.y, 831.2804714634476, 0.000000000002)
  })
}
