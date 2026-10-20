import gleam/float
import gleam/list
import svg_path/ellipse.{
  type EllipsePoint, type EndpointArcData, EllipsePoint, EndpointArcData,
}
import svg_path/internal/ellipse_precision

// Exact binary64 input expectations from the independent 80-digit Decimal oracle.
fn fixtures() -> List(#(EndpointArcData, EllipsePoint)) {
  [
    #(
      EndpointArcData(
        EllipsePoint(-555.8531980329952, -415.6402357317238),
        EllipsePoint(1000.0, 500.0),
        0.0,
        False,
        False,
        EllipsePoint(555.8531980329952, 415.6402357317238),
      ),
      EllipsePoint(5.317918070671085e-06, -1.7779689695200282e-06),
    ),
    #(
      EndpointArcData(
        EllipsePoint(-555.8531980329952, -415.6402357317238),
        EllipsePoint(1000.0, 500.0),
        0.0,
        False,
        True,
        EllipsePoint(555.8531980329952, 415.6402357317238),
      ),
      EllipsePoint(-5.317918070671085e-06, 1.7779689695200282e-06),
    ),
    #(
      EndpointArcData(
        EllipsePoint(-555.8531980329952, -415.6402357317238),
        EllipsePoint(1000.0, 500.0),
        0.0,
        True,
        False,
        EllipsePoint(555.8531980329952, 415.6402357317238),
      ),
      EllipsePoint(-5.317918070671085e-06, 1.7779689695200282e-06),
    ),
    #(
      EndpointArcData(
        EllipsePoint(-555.8531980329952, -415.6402357317238),
        EllipsePoint(1000.0, 500.0),
        0.0,
        True,
        True,
        EllipsePoint(555.8531980329952, 415.6402357317238),
      ),
      EllipsePoint(5.317918070671085e-06, -1.7779689695200282e-06),
    ),
    #(
      EndpointArcData(
        EllipsePoint(9444.146801967005, 9584.359764268276),
        EllipsePoint(1000.0, 500.0),
        0.0,
        False,
        False,
        EllipsePoint(10_555.853198032995, 10_415.640235731724),
      ),
      EllipsePoint(10_000.0, 10_000.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(9444.146801967005, 9584.359764268276),
        EllipsePoint(1000.0, 500.0),
        0.0,
        False,
        True,
        EllipsePoint(10_555.853198032995, 10_415.640235731724),
      ),
      EllipsePoint(10_000.0, 10_000.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(9444.146801967005, 9584.359764268276),
        EllipsePoint(1000.0, 500.0),
        0.0,
        True,
        False,
        EllipsePoint(10_555.853198032995, 10_415.640235731724),
      ),
      EllipsePoint(10_000.0, 10_000.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(9444.146801967005, 9584.359764268276),
        EllipsePoint(1000.0, 500.0),
        0.0,
        True,
        True,
        EllipsePoint(10_555.853198032995, 10_415.640235731724),
      ),
      EllipsePoint(10_000.0, 10_000.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(-410.0436126239721, -559.9944812843364),
        EllipsePoint(1000.0, 500.0),
        17.0,
        False,
        False,
        EllipsePoint(410.0436126239721, 559.9944812843364),
      ),
      EllipsePoint(1.2473151978992095e-05, -3.2370465442523316e-07),
    ),
    #(
      EndpointArcData(
        EllipsePoint(-410.0436126239721, -559.9944812843364),
        EllipsePoint(1000.0, 500.0),
        17.0,
        False,
        True,
        EllipsePoint(410.0436126239721, 559.9944812843364),
      ),
      EllipsePoint(-1.2473151978992095e-05, 3.2370465442523316e-07),
    ),
    #(
      EndpointArcData(
        EllipsePoint(-410.0436126239721, -559.9944812843364),
        EllipsePoint(1000.0, 500.0),
        17.0,
        True,
        False,
        EllipsePoint(410.0436126239721, 559.9944812843364),
      ),
      EllipsePoint(-1.2473151978992095e-05, 3.2370465442523316e-07),
    ),
    #(
      EndpointArcData(
        EllipsePoint(-410.0436126239721, -559.9944812843364),
        EllipsePoint(1000.0, 500.0),
        17.0,
        True,
        True,
        EllipsePoint(410.0436126239721, 559.9944812843364),
      ),
      EllipsePoint(1.2473151978992095e-05, -3.2370465442523316e-07),
    ),
    #(
      EndpointArcData(
        EllipsePoint(9589.956387376029, 9440.005518715663),
        EllipsePoint(1000.0, 500.0),
        17.0,
        False,
        False,
        EllipsePoint(10_410.043612623971, 10_559.994481284337),
      ),
      EllipsePoint(10_000.0, 10_000.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(9589.956387376029, 9440.005518715663),
        EllipsePoint(1000.0, 500.0),
        17.0,
        False,
        True,
        EllipsePoint(10_410.043612623971, 10_559.994481284337),
      ),
      EllipsePoint(10_000.0, 10_000.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(9589.956387376029, 9440.005518715663),
        EllipsePoint(1000.0, 500.0),
        17.0,
        True,
        False,
        EllipsePoint(10_410.043612623971, 10_559.994481284337),
      ),
      EllipsePoint(10_000.0, 10_000.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(9589.956387376029, 9440.005518715663),
        EllipsePoint(1000.0, 500.0),
        17.0,
        True,
        True,
        EllipsePoint(10_410.043612623971, 10_559.994481284337),
      ),
      EllipsePoint(10_000.0, 10_000.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(-193.78556423268984, -666.4658569031494),
        EllipsePoint(1000.0, 500.0),
        37.0,
        False,
        False,
        EllipsePoint(193.78556423268984, 666.4658569031494),
      ),
      EllipsePoint(0.0, 0.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(-193.78556423268984, -666.4658569031494),
        EllipsePoint(1000.0, 500.0),
        37.0,
        False,
        True,
        EllipsePoint(193.78556423268984, 666.4658569031494),
      ),
      EllipsePoint(0.0, 0.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(-193.78556423268984, -666.4658569031494),
        EllipsePoint(1000.0, 500.0),
        37.0,
        True,
        False,
        EllipsePoint(193.78556423268984, 666.4658569031494),
      ),
      EllipsePoint(0.0, 0.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(-193.78556423268984, -666.4658569031494),
        EllipsePoint(1000.0, 500.0),
        37.0,
        True,
        True,
        EllipsePoint(193.78556423268984, 666.4658569031494),
      ),
      EllipsePoint(0.0, 0.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(9806.21443576731, 9333.534143096851),
        EllipsePoint(1000.0, 500.0),
        37.0,
        False,
        False,
        EllipsePoint(10_193.78556423269, 10_666.465856903149),
      ),
      EllipsePoint(10_000.000037273861, 10_000.000012481345),
    ),
    #(
      EndpointArcData(
        EllipsePoint(9806.21443576731, 9333.534143096851),
        EllipsePoint(1000.0, 500.0),
        37.0,
        False,
        True,
        EllipsePoint(10_193.78556423269, 10_666.465856903149),
      ),
      EllipsePoint(9999.999962726139, 9999.999987518655),
    ),
    #(
      EndpointArcData(
        EllipsePoint(9806.21443576731, 9333.534143096851),
        EllipsePoint(1000.0, 500.0),
        37.0,
        True,
        False,
        EllipsePoint(10_193.78556423269, 10_666.465856903149),
      ),
      EllipsePoint(9999.999962726139, 9999.999987518655),
    ),
    #(
      EndpointArcData(
        EllipsePoint(9806.21443576731, 9333.534143096851),
        EllipsePoint(1000.0, 500.0),
        37.0,
        True,
        True,
        EllipsePoint(10_193.78556423269, 10_666.465856903149),
      ),
      EllipsePoint(10_000.000037273861, 10_000.000012481345),
    ),
    #(
      EndpointArcData(
        EllipsePoint(234.96298711535286, -653.0865011684606),
        EllipsePoint(1000.0, 500.0),
        73.0,
        False,
        False,
        EllipsePoint(-234.96298711535286, 653.0865011684606),
      ),
      EllipsePoint(5.455061947049972e-06, 7.651495722330372e-06),
    ),
    #(
      EndpointArcData(
        EllipsePoint(234.96298711535286, -653.0865011684606),
        EllipsePoint(1000.0, 500.0),
        73.0,
        False,
        True,
        EllipsePoint(-234.96298711535286, 653.0865011684606),
      ),
      EllipsePoint(-5.455061947049972e-06, -7.651495722330372e-06),
    ),
    #(
      EndpointArcData(
        EllipsePoint(234.96298711535286, -653.0865011684606),
        EllipsePoint(1000.0, 500.0),
        73.0,
        True,
        False,
        EllipsePoint(-234.96298711535286, 653.0865011684606),
      ),
      EllipsePoint(-5.455061947049972e-06, -7.651495722330372e-06),
    ),
    #(
      EndpointArcData(
        EllipsePoint(234.96298711535286, -653.0865011684606),
        EllipsePoint(1000.0, 500.0),
        73.0,
        True,
        True,
        EllipsePoint(-234.96298711535286, 653.0865011684606),
      ),
      EllipsePoint(5.455061947049972e-06, 7.651495722330372e-06),
    ),
    #(
      EndpointArcData(
        EllipsePoint(10_234.962987115354, 9346.91349883154),
        EllipsePoint(1000.0, 500.0),
        73.0,
        False,
        False,
        EllipsePoint(9765.037012884646, 10_653.08650116846),
      ),
      EllipsePoint(10_000.0, 10_000.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(10_234.962987115354, 9346.91349883154),
        EllipsePoint(1000.0, 500.0),
        73.0,
        False,
        True,
        EllipsePoint(9765.037012884646, 10_653.08650116846),
      ),
      EllipsePoint(10_000.0, 10_000.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(10_234.962987115354, 9346.91349883154),
        EllipsePoint(1000.0, 500.0),
        73.0,
        True,
        False,
        EllipsePoint(9765.037012884646, 10_653.08650116846),
      ),
      EllipsePoint(10_000.0, 10_000.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(10_234.962987115354, 9346.91349883154),
        EllipsePoint(1000.0, 500.0),
        73.0,
        True,
        True,
        EllipsePoint(9765.037012884646, 10_653.08650116846),
      ),
      EllipsePoint(10_000.0, 10_000.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(-555.8531980329952, -1662.5609429268952),
        EllipsePoint(1000.0, 2000.0),
        0.0,
        False,
        False,
        EllipsePoint(555.8531980329952, 1662.5609429268952),
      ),
      EllipsePoint(5.317918070671085e-06, -7.111875878080113e-06),
    ),
    #(
      EndpointArcData(
        EllipsePoint(-555.8531980329952, -1662.5609429268952),
        EllipsePoint(1000.0, 2000.0),
        0.0,
        False,
        True,
        EllipsePoint(555.8531980329952, 1662.5609429268952),
      ),
      EllipsePoint(-5.317918070671085e-06, 7.111875878080113e-06),
    ),
    #(
      EndpointArcData(
        EllipsePoint(-555.8531980329952, -1662.5609429268952),
        EllipsePoint(1000.0, 2000.0),
        0.0,
        True,
        False,
        EllipsePoint(555.8531980329952, 1662.5609429268952),
      ),
      EllipsePoint(-5.317918070671085e-06, 7.111875878080113e-06),
    ),
    #(
      EndpointArcData(
        EllipsePoint(-555.8531980329952, -1662.5609429268952),
        EllipsePoint(1000.0, 2000.0),
        0.0,
        True,
        True,
        EllipsePoint(555.8531980329952, 1662.5609429268952),
      ),
      EllipsePoint(5.317918070671085e-06, -7.111875878080113e-06),
    ),
    #(
      EndpointArcData(
        EllipsePoint(9444.146801967005, 8337.439057073105),
        EllipsePoint(1000.0, 2000.0),
        0.0,
        False,
        False,
        EllipsePoint(10_555.853198032995, 11_662.560942926895),
      ),
      EllipsePoint(10_000.0, 10_000.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(9444.146801967005, 8337.439057073105),
        EllipsePoint(1000.0, 2000.0),
        0.0,
        False,
        True,
        EllipsePoint(10_555.853198032995, 11_662.560942926895),
      ),
      EllipsePoint(10_000.0, 10_000.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(9444.146801967005, 8337.439057073105),
        EllipsePoint(1000.0, 2000.0),
        0.0,
        True,
        False,
        EllipsePoint(10_555.853198032995, 11_662.560942926895),
      ),
      EllipsePoint(10_000.0, 10_000.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(9444.146801967005, 8337.439057073105),
        EllipsePoint(1000.0, 2000.0),
        0.0,
        True,
        True,
        EllipsePoint(10_555.853198032995, 11_662.560942926895),
      ),
      EllipsePoint(10_000.0, 10_000.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(-45.47927980723932, -1752.4306838838704),
        EllipsePoint(1000.0, 2000.0),
        17.0,
        False,
        False,
        EllipsePoint(45.47927980723932, 1752.4306838838704),
      ),
      EllipsePoint(1.4572536383992564e-05, -1.0670418483914659e-05),
    ),
    #(
      EndpointArcData(
        EllipsePoint(-45.47927980723932, -1752.4306838838704),
        EllipsePoint(1000.0, 2000.0),
        17.0,
        False,
        True,
        EllipsePoint(45.47927980723932, 1752.4306838838704),
      ),
      EllipsePoint(-1.4572536383992564e-05, 1.0670418483914659e-05),
    ),
    #(
      EndpointArcData(
        EllipsePoint(-45.47927980723932, -1752.4306838838704),
        EllipsePoint(1000.0, 2000.0),
        17.0,
        True,
        False,
        EllipsePoint(45.47927980723932, 1752.4306838838704),
      ),
      EllipsePoint(-1.4572536383992564e-05, 1.0670418483914659e-05),
    ),
    #(
      EndpointArcData(
        EllipsePoint(-45.47927980723932, -1752.4306838838704),
        EllipsePoint(1000.0, 2000.0),
        17.0,
        True,
        True,
        EllipsePoint(45.47927980723932, 1752.4306838838704),
      ),
      EllipsePoint(1.4572536383992564e-05, -1.0670418483914659e-05),
    ),
    #(
      EndpointArcData(
        EllipsePoint(9954.520720192762, 8247.569316116129),
        EllipsePoint(1000.0, 2000.0),
        17.0,
        False,
        False,
        EllipsePoint(10_045.479279807238, 11_752.430683883871),
      ),
      EllipsePoint(10_000.000031753678, 9999.99997674907),
    ),
    #(
      EndpointArcData(
        EllipsePoint(9954.520720192762, 8247.569316116129),
        EllipsePoint(1000.0, 2000.0),
        17.0,
        False,
        True,
        EllipsePoint(10_045.479279807238, 11_752.430683883871),
      ),
      EllipsePoint(9999.999968246322, 10_000.00002325093),
    ),
    #(
      EndpointArcData(
        EllipsePoint(9954.520720192762, 8247.569316116129),
        EllipsePoint(1000.0, 2000.0),
        17.0,
        True,
        False,
        EllipsePoint(10_045.479279807238, 11_752.430683883871),
      ),
      EllipsePoint(9999.999968246322, 10_000.00002325093),
    ),
    #(
      EndpointArcData(
        EllipsePoint(9954.520720192762, 8247.569316116129),
        EllipsePoint(1000.0, 2000.0),
        17.0,
        True,
        True,
        EllipsePoint(10_045.479279807238, 11_752.430683883871),
      ),
      EllipsePoint(10_000.000031753678, 9999.99997674907),
    ),
    #(
      EndpointArcData(
        EllipsePoint(556.6300500367406, -1662.3010118824961),
        EllipsePoint(1000.0, 2000.0),
        37.0,
        False,
        False,
        EllipsePoint(-556.6300500367406, 1662.3010118824961),
      ),
      EllipsePoint(1.4302654965240597e-05, -4.1587247625010856e-06),
    ),
    #(
      EndpointArcData(
        EllipsePoint(556.6300500367406, -1662.3010118824961),
        EllipsePoint(1000.0, 2000.0),
        37.0,
        False,
        True,
        EllipsePoint(-556.6300500367406, 1662.3010118824961),
      ),
      EllipsePoint(-1.4302654965240597e-05, 4.1587247625010856e-06),
    ),
    #(
      EndpointArcData(
        EllipsePoint(556.6300500367406, -1662.3010118824961),
        EllipsePoint(1000.0, 2000.0),
        37.0,
        True,
        False,
        EllipsePoint(-556.6300500367406, 1662.3010118824961),
      ),
      EllipsePoint(-1.4302654965240597e-05, 4.1587247625010856e-06),
    ),
    #(
      EndpointArcData(
        EllipsePoint(556.6300500367406, -1662.3010118824961),
        EllipsePoint(1000.0, 2000.0),
        37.0,
        True,
        True,
        EllipsePoint(-556.6300500367406, 1662.3010118824961),
      ),
      EllipsePoint(1.4302654965240597e-05, -4.1587247625010856e-06),
    ),
    #(
      EndpointArcData(
        EllipsePoint(10_556.63005003674, 8337.698988117505),
        EllipsePoint(1000.0, 2000.0),
        37.0,
        False,
        False,
        EllipsePoint(9443.36994996326, 11_662.301011882495),
      ),
      EllipsePoint(10_000.000047651361, 9999.999986144607),
    ),
    #(
      EndpointArcData(
        EllipsePoint(10_556.63005003674, 8337.698988117505),
        EllipsePoint(1000.0, 2000.0),
        37.0,
        False,
        True,
        EllipsePoint(9443.36994996326, 11_662.301011882495),
      ),
      EllipsePoint(9999.999952348639, 10_000.000013855393),
    ),
    #(
      EndpointArcData(
        EllipsePoint(10_556.63005003674, 8337.698988117505),
        EllipsePoint(1000.0, 2000.0),
        37.0,
        True,
        False,
        EllipsePoint(9443.36994996326, 11_662.301011882495),
      ),
      EllipsePoint(9999.999952348639, 10_000.000013855393),
    ),
    #(
      EndpointArcData(
        EllipsePoint(10_556.63005003674, 8337.698988117505),
        EllipsePoint(1000.0, 2000.0),
        37.0,
        True,
        True,
        EllipsePoint(9443.36994996326, 11_662.301011882495),
      ),
      EllipsePoint(10_000.000047651361, 9999.999986144607),
    ),
    #(
      EndpointArcData(
        EllipsePoint(1427.399189714887, -1017.6508339851933),
        EllipsePoint(1000.0, 2000.0),
        73.0,
        False,
        False,
        EllipsePoint(-1427.399189714887, 1017.6508339851933),
      ),
      EllipsePoint(0.0, 0.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(1427.399189714887, -1017.6508339851933),
        EllipsePoint(1000.0, 2000.0),
        73.0,
        False,
        True,
        EllipsePoint(-1427.399189714887, 1017.6508339851933),
      ),
      EllipsePoint(0.0, 0.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(1427.399189714887, -1017.6508339851933),
        EllipsePoint(1000.0, 2000.0),
        73.0,
        True,
        False,
        EllipsePoint(-1427.399189714887, 1017.6508339851933),
      ),
      EllipsePoint(0.0, 0.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(1427.399189714887, -1017.6508339851933),
        EllipsePoint(1000.0, 2000.0),
        73.0,
        True,
        True,
        EllipsePoint(-1427.399189714887, 1017.6508339851933),
      ),
      EllipsePoint(0.0, 0.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(11_427.399189714888, 8982.349166014807),
        EllipsePoint(1000.0, 2000.0),
        73.0,
        False,
        False,
        EllipsePoint(8572.600810285112, 11_017.650833985193),
      ),
      EllipsePoint(10_000.0, 10_000.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(11_427.399189714888, 8982.349166014807),
        EllipsePoint(1000.0, 2000.0),
        73.0,
        False,
        True,
        EllipsePoint(8572.600810285112, 11_017.650833985193),
      ),
      EllipsePoint(10_000.0, 10_000.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(11_427.399189714888, 8982.349166014807),
        EllipsePoint(1000.0, 2000.0),
        73.0,
        True,
        False,
        EllipsePoint(8572.600810285112, 11_017.650833985193),
      ),
      EllipsePoint(10_000.0, 10_000.0),
    ),
    #(
      EndpointArcData(
        EllipsePoint(11_427.399189714888, 8982.349166014807),
        EllipsePoint(1000.0, 2000.0),
        73.0,
        True,
        True,
        EllipsePoint(8572.600810285112, 11_017.650833985193),
      ),
      EllipsePoint(10_000.0, 10_000.0),
    ),
  ]
}

pub fn unequal_near_semicircle_centers_test() {
  list.each(fixtures(), fn(fixture) {
    let #(input, expected) = fixture
    let assert Ok(actual) = ellipse.endpoint_to_center(input)
    close(actual.center, expected, 0.000000000004)
    assert actual.x_axis_rotation == input.x_axis_rotation
  })
}

pub fn precise_arc_reconstruction_and_flags_test() {
  list.each(fixtures(), fn(fixture) {
    let input = fixture.0
    let assert Ok(actual) = ellipse.endpoint_to_center(input)
    close(ellipse.arc_point(actual, 0.0), input.start, 0.00000000004)
    close(ellipse.arc_point(actual, 1.0), input.end, 0.00000000004)
    assert { actual.delta_angle >. 0.0 } == input.sweep
    case
      float.absolute_value(actual.delta_angle -. 180.0) <. 0.000000000001
      || float.absolute_value(actual.delta_angle +. 180.0) <. 0.000000000001
    {
      True -> Nil
      False -> assert_large(actual.delta_angle, input.large_arc)
    }
  })
}

fn assert_large(delta: Float, large: Bool) {
  assert { float.absolute_value(delta) >. 180.0 } == large
}

fn close(a: EllipsePoint, b: EllipsePoint, tolerance: Float) {
  assert float.absolute_value(a.x -. b.x) <=. tolerance
  assert float.absolute_value(a.y -. b.y) <=. tolerance
}

pub fn conditioning_dispatch_boundary_test() {
  list.each(
    [
      #(
        EndpointArcData(
          EllipsePoint(475.8133449794716, 368.55083793673515),
          EllipsePoint(1000.0, 10.0),
          37.0,
          False,
          True,
          EllipsePoint(-475.8133449794716, -368.55083793673515),
        ),
        True,
      ),
      #(
        EndpointArcData(
          EllipsePoint(475.8357358433453, 368.5681812326511),
          EllipsePoint(1000.0, 10.0),
          37.0,
          False,
          True,
          EllipsePoint(-475.8357358433453, -368.5681812326511),
        ),
        True,
      ),
      #(
        EndpointArcData(
          EllipsePoint(475.8131188467516, 368.55066278106887),
          EllipsePoint(1000.0, 10.0),
          37.0,
          False,
          True,
          EllipsePoint(-475.8131188467516, -368.55066278106887),
        ),
        False,
      ),
      #(
        EndpointArcData(
          EllipsePoint(475.83596205131823, 368.56835644660606),
          EllipsePoint(1000.0, 10.0),
          37.0,
          False,
          True,
          EllipsePoint(-475.83596205131823, -368.56835644660606),
        ),
        False,
      ),
      #(
        EndpointArcData(
          EllipsePoint(240.31541309034463, 681.090630169822),
          EllipsePoint(1000.0, 500.0),
          37.0,
          False,
          True,
          EllipsePoint(-240.31541309034463, -681.090630169822),
        ),
        True,
      ),
      #(
        EndpointArcData(
          EllipsePoint(240.3154348788183, 681.0906919216883),
          EllipsePoint(1000.0, 500.0),
          37.0,
          False,
          True,
          EllipsePoint(-240.3154348788183, -681.0906919216883),
        ),
        True,
      ),
      #(
        EndpointArcData(
          EllipsePoint(240.31541287025917, 681.0906295460661),
          EllipsePoint(1000.0, 500.0),
          37.0,
          False,
          True,
          EllipsePoint(-240.31541287025917, -681.0906295460661),
        ),
        False,
      ),
      #(
        EndpointArcData(
          EllipsePoint(240.31543509890406, 681.0906925454449),
          EllipsePoint(1000.0, 500.0),
          37.0,
          False,
          True,
          EllipsePoint(-240.31543509890406, -681.0906925454449),
        ),
        False,
      ),
      #(
        EndpointArcData(
          EllipsePoint(-480.63082479722175, 1637.8185989467925),
          EllipsePoint(1000.0, 2000.0),
          37.0,
          False,
          True,
          EllipsePoint(480.63082479722175, -1637.8185989467925),
        ),
        True,
      ),
      #(
        EndpointArcData(
          EllipsePoint(-480.6308711411048, 1637.8187568702335),
          EllipsePoint(1000.0, 2000.0),
          37.0,
          False,
          True,
          EllipsePoint(480.6308711411048, -1637.8187568702335),
        ),
        True,
      ),
      #(
        EndpointArcData(
          EllipsePoint(-480.6308243291018, 1637.818597351607),
          EllipsePoint(1000.0, 2000.0),
          37.0,
          False,
          True,
          EllipsePoint(480.6308243291018, -1637.818597351607),
        ),
        False,
      ),
      #(
        EndpointArcData(
          EllipsePoint(-480.63087160922515, 1637.8187584654206),
          EllipsePoint(1000.0, 2000.0),
          37.0,
          False,
          True,
          EllipsePoint(480.63087160922515, -1637.8187584654206),
        ),
        False,
      ),
      #(
        EndpointArcData(
          EllipsePoint(-47_581.32840760917, 64_142.53181459204),
          EllipsePoint(1000.0, 100_000.0),
          37.0,
          False,
          True,
          EllipsePoint(47_581.32840760917, -64_142.53181459204),
        ),
        True,
      ),
      #(
        EndpointArcData(
          EllipsePoint(-47_583.57967668443, 64_145.5666625695),
          EllipsePoint(1000.0, 100_000.0),
          37.0,
          False,
          True,
          EllipsePoint(47_583.57967668443, -64_145.5666625695),
        ),
        True,
      ),
      #(
        EndpointArcData(
          EllipsePoint(-47_581.30567132078, 64_142.501164689),
          EllipsePoint(1000.0, 100_000.0),
          37.0,
          False,
          True,
          EllipsePoint(47_581.30567132078, -64_142.501164689),
        ),
        False,
      ),
      #(
        EndpointArcData(
          EllipsePoint(-47_583.602420580224, 64_145.59732272776),
          EllipsePoint(1000.0, 100_000.0),
          37.0,
          False,
          True,
          EllipsePoint(47_583.602420580224, -64_145.59732272776),
        ),
        False,
      ),
    ],
    fn(pair) {
      let #(a, expected) = pair
      let actual =
        ellipse_precision.convert(
          a.start.x,
          a.start.y,
          a.end.x,
          a.end.y,
          a.radius.x,
          a.radius.y,
          a.x_axis_rotation,
          a.large_arc,
          a.sweep,
        )
      assert case actual {
          Ok(_) -> True
          Error(_) -> False
        }
        == expected
    },
  )
}

pub fn precision_range_guard_test() {
  assert ellipse_precision.convert(
      1.0e200,
      0.0,
      0.0,
      1.0e200,
      1.0e200,
      2.0e200,
      37.0,
      False,
      True,
    )
    == Error(Nil)
  assert ellipse_precision.convert(
      1.0,
      0.0,
      0.0,
      1.0,
      1.0e-40,
      1.0,
      37.0,
      False,
      True,
    )
    == Error(Nil)
}
