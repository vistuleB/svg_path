#!/usr/bin/env python3
"""Generate analytic Arc bbox fixtures for Gleam tests.

This script is intentionally independent of the Gleam implementation. It uses
the SVG endpoint-to-center conversion formulas and analytic ellipse extrema to
produce oracle data for future arc bbox tests.
"""

from __future__ import annotations

import argparse
import math
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


GENERATED_CASES = 100
RANDOM_SEED = 24062027
FULL_TURN = 360.0
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "test" / "svg_path_arc_bbox_fixtures.gleam"


@dataclass(frozen=True)
class Point:
    x: float
    y: float


@dataclass(frozen=True)
class EndpointArc:
    start: Point
    radius: Point
    x_axis_rotation: float
    large_arc: bool
    sweep: bool
    end: Point


@dataclass(frozen=True)
class CenterArc:
    center: Point
    radius: Point
    x_axis_rotation: float
    start_angle: float
    delta_angle: float


@dataclass(frozen=True)
class Case:
    name: str
    arc: CenterArc


HAND_CRAFTED_ENDPOINT_CASES = [
    (
        "endpoint_half_circle_sweep",
        EndpointArc(
            start=Point(0.0, 0.0),
            radius=Point(10.0, 10.0),
            x_axis_rotation=0.0,
            large_arc=False,
            sweep=True,
            end=Point(20.0, 0.0),
        ),
    ),
    (
        "endpoint_half_circle_non_sweep",
        EndpointArc(
            start=Point(0.0, 0.0),
            radius=Point(10.0, 10.0),
            x_axis_rotation=0.0,
            large_arc=False,
            sweep=False,
            end=Point(20.0, 0.0),
        ),
    ),
    (
        "endpoint_large_arc_rotated",
        EndpointArc(
            start=Point(-12.0, 4.0),
            radius=Point(18.0, 9.0),
            x_axis_rotation=35.0,
            large_arc=True,
            sweep=True,
            end=Point(11.0, -7.0),
        ),
    ),
    (
        "endpoint_small_radii_corrected",
        EndpointArc(
            start=Point(0.0, 0.0),
            radius=Point(1.0, 1.0),
            x_axis_rotation=0.0,
            large_arc=False,
            sweep=True,
            end=Point(20.0, 0.0),
        ),
    ),
    (
        "endpoint_negative_radii_corrected",
        EndpointArc(
            start=Point(3.0, -5.0),
            radius=Point(-7.0, -11.0),
            x_axis_rotation=-25.0,
            large_arc=False,
            sweep=False,
            end=Point(14.0, 9.0),
        ),
    ),
]


HAND_CRAFTED_CENTER_CASES = [
    Case(
        "center_quarter_unrotated",
        CenterArc(
            center=Point(0.0, 0.0),
            radius=Point(10.0, 5.0),
            x_axis_rotation=0.0,
            start_angle=0.0,
            delta_angle=90.0,
        ),
    ),
    Case(
        "center_rotated_interior_extrema",
        CenterArc(
            center=Point(2.0, -3.0),
            radius=Point(12.0, 5.0),
            x_axis_rotation=30.0,
            start_angle=math.degrees(-1.2),
            delta_angle=math.degrees(4.4),
        ),
    ),
    Case(
        "center_negative_delta",
        CenterArc(
            center=Point(-4.0, 6.0),
            radius=Point(8.0, 13.0),
            x_axis_rotation=-40.0,
            start_angle=math.degrees(2.5),
            delta_angle=math.degrees(-3.7),
        ),
    ),
    Case(
        "center_nearly_full_turn",
        CenterArc(
            center=Point(1.0, 2.0),
            radius=Point(6.0, 9.0),
            x_axis_rotation=75.0,
            start_angle=math.degrees(-0.5),
            delta_angle=FULL_TURN - math.degrees(0.2),
        ),
    ),
]


def endpoint_to_center(endpoint: EndpointArc) -> CenterArc:
    start = endpoint.start
    end = endpoint.end
    rx = abs(endpoint.radius.x)
    ry = abs(endpoint.radius.y)
    if rx == 0.0 or ry == 0.0 or start == end:
        raise ValueError("Degenerate endpoint arc")

    phi = math.radians(endpoint.x_axis_rotation)
    cos_phi = math.cos(phi)
    sin_phi = math.sin(phi)
    dx = (start.x - end.x) / 2.0
    dy = (start.y - end.y) / 2.0
    x1p = cos_phi * dx + sin_phi * dy
    y1p = -sin_phi * dx + cos_phi * dy

    radii_check = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
    if radii_check > 1.0:
        scale = math.sqrt(radii_check)
        rx *= scale
        ry *= scale

    numerator = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
    denominator = rx * rx * y1p * y1p + ry * ry * x1p * x1p
    factor = 0.0 if denominator == 0.0 else math.sqrt(max(0.0, numerator / denominator))
    if endpoint.large_arc == endpoint.sweep:
        factor = -factor

    cxp = factor * rx * y1p / ry
    cyp = -factor * ry * x1p / rx
    center = Point(
        cos_phi * cxp - sin_phi * cyp + (start.x + end.x) / 2.0,
        sin_phi * cxp + cos_phi * cyp + (start.y + end.y) / 2.0,
    )

    start_angle = vector_angle(1.0, 0.0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    delta_angle = vector_angle(
        (x1p - cxp) / rx,
        (y1p - cyp) / ry,
        (-x1p - cxp) / rx,
        (-y1p - cyp) / ry,
    )
    if not endpoint.sweep and delta_angle > 0.0:
        delta_angle -= FULL_TURN
    elif endpoint.sweep and delta_angle < 0.0:
        delta_angle += FULL_TURN

    return CenterArc(
        center=center,
        radius=Point(rx, ry),
        x_axis_rotation=endpoint.x_axis_rotation,
        start_angle=start_angle,
        delta_angle=delta_angle,
    )


def vector_angle(ux: float, uy: float, vx: float, vy: float) -> float:
    dot = ux * vx + uy * vy
    det = ux * vy - uy * vx
    return math.degrees(math.atan2(det, dot))


def point_at_angle(arc: CenterArc, angle: float) -> Point:
    phi = math.radians(arc.x_axis_rotation)
    angle = math.radians(angle)
    cos_phi = math.cos(phi)
    sin_phi = math.sin(phi)
    cos_angle = math.cos(angle)
    sin_angle = math.sin(angle)
    return Point(
        arc.center.x + arc.radius.x * cos_angle * cos_phi - arc.radius.y * sin_angle * sin_phi,
        arc.center.y + arc.radius.x * cos_angle * sin_phi + arc.radius.y * sin_angle * cos_phi,
    )


def bbox(arc: CenterArc) -> tuple[Point, Point]:
    angles = [arc.start_angle, arc.start_angle + arc.delta_angle]
    for angle in candidate_extrema(arc):
        if angle_on_arc(angle, arc.start_angle, arc.delta_angle):
            angles.append(angle)

    points = [point_at_angle(arc, angle) for angle in angles]
    return (
        Point(min(point.x for point in points), min(point.y for point in points)),
        Point(max(point.x for point in points), max(point.y for point in points)),
    )


def candidate_extrema(arc: CenterArc) -> list[float]:
    phi = math.radians(arc.x_axis_rotation)
    x_angle = math.degrees(
        math.atan2(-arc.radius.y * math.sin(phi), arc.radius.x * math.cos(phi))
    )
    y_angle = math.degrees(
        math.atan2(arc.radius.y * math.cos(phi), arc.radius.x * math.sin(phi))
    )
    return [x_angle, x_angle + 180.0, y_angle, y_angle + 180.0]


def angle_on_arc(angle: float, start: float, delta: float) -> bool:
    if abs(delta) >= FULL_TURN:
        return True
    if delta >= 0.0:
        progress = positive_mod(angle - start, FULL_TURN)
        return progress <= delta
    progress = positive_mod(start - angle, FULL_TURN)
    return progress <= -delta


def positive_mod(value: float, modulus: float) -> float:
    return value % modulus


def generated_center_cases() -> list[Case]:
    rng = random.Random(RANDOM_SEED)
    cases = []
    for index in range(1, GENERATED_CASES + 1):
        radius = Point(rng.uniform(1.0, 40.0), rng.uniform(1.0, 40.0))
        delta = rng.uniform(-FULL_TURN + 0.572957795, FULL_TURN - 0.572957795)
        if abs(delta) < 11.459155903:
            delta = 11.459155903 if delta >= 0.0 else -11.459155903
        cases.append(
            Case(
                f"generated_center_{index:03}",
                CenterArc(
                    center=Point(rng.uniform(-40.0, 40.0), rng.uniform(-40.0, 40.0)),
                    radius=radius,
                    x_axis_rotation=rng.uniform(-180.0, 180.0),
                    start_angle=rng.uniform(-FULL_TURN, FULL_TURN),
                    delta_angle=delta,
                ),
            )
        )
    return cases


def cases() -> list[Case]:
    endpoint_cases = [
        Case(name, endpoint_to_center(endpoint))
        for name, endpoint in HAND_CRAFTED_ENDPOINT_CASES
    ]
    return [*endpoint_cases, *HAND_CRAFTED_CENTER_CASES, *generated_center_cases()]


def gleam_float(value: float) -> str:
    text = f"{value:.9f}"
    text = text.rstrip("0").rstrip(".")
    if text == "-0":
        text = "0"
    if "." not in text:
        text += ".0"
    return text


def gleam_point(point: Point) -> str:
    return f"ellipse.Point({gleam_float(point.x)}, {gleam_float(point.y)})"


def gleam_arc(arc: CenterArc) -> str:
    return (
        "ellipse.center_arc_data(\n"
        f"        center: {gleam_point(arc.center)},\n"
        f"        radius: {gleam_point(arc.radius)},\n"
        f"        x_axis_rotation: {gleam_float(arc.x_axis_rotation)},\n"
        f"        start_angle: {gleam_float(arc.start_angle)},\n"
        f"        delta_angle: {gleam_float(arc.delta_angle)},\n"
        "      )"
    )


def render(cases: Iterable[Case]) -> str:
    rendered_cases = []
    for case in cases:
        minimum, maximum = bbox(case.arc)
        rendered_cases.append(
            "    ArcBBoxFixture(\n"
            f"      name: \"{case.name}\",\n"
            f"      arc: {gleam_arc(case.arc)},\n"
            f"      min: {gleam_point(minimum)},\n"
            f"      max: {gleam_point(maximum)},\n"
            "    )"
        )

    return (
        "//// This file is machine-generated by scripts/generate_arc_bbox_fixtures.py.\n"
        "//// Oracle bboxes are computed from analytic ellipse extrema.\n"
        "\n"
        "import svg_path/ellipse\n"
        "\n"
        "pub type ArcBBoxFixture {\n"
        "  ArcBBoxFixture(\n"
        "    name: String,\n"
        "    arc: ellipse.CenterArcData,\n"
        "    min: ellipse.Point,\n"
        "    max: ellipse.Point,\n"
        "  )\n"
        "}\n"
        "\n"
        "pub fn fixtures() -> List(ArcBBoxFixture) {\n"
        "  [\n"
        + ",\n".join(rendered_cases)
        + ",\n"
        "  ]\n"
        "}\n"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="fail if output is stale")
    parser.add_argument("--write", action="store_true", help="write the generated Gleam fixture")
    args = parser.parse_args()

    output = render(cases())
    if args.check:
        current = OUTPUT.read_text() if OUTPUT.exists() else ""
        if current != output:
            raise SystemExit(f"{OUTPUT} is stale; run {Path(__file__).as_posix()} --write")
        return
    if args.write:
        OUTPUT.write_text(output)
        return
    print(output, end="")


if __name__ == "__main__":
    main()
