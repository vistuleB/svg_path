#!/usr/bin/env python3
"""Generate dense-sampling Bezier bbox fixtures for Gleam tests.

This script is intentionally independent of the Gleam implementation. It uses
direct Bernstein evaluation and dense sampling to produce oracle data that can
be wired into bbox tests once the bbox API exists.
"""

from __future__ import annotations

import argparse
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


SAMPLES = 200_000
GENERATED_CASES_PER_KIND = 50
RANDOM_SEED = 24062026
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "test" / "svg_path_bezier_bbox_fixtures.gleam"


@dataclass(frozen=True)
class Point:
    x: float
    y: float


@dataclass(frozen=True)
class Case:
    name: str
    kind: str
    points: tuple[Point, ...]


HAND_CRAFTED_CASES = [
    Case(
        "linear_diagonal",
        "linear",
        (Point(1.0, 2.0), Point(5.0, -3.0)),
    ),
    Case(
        "quadratic_symmetric_peak",
        "quadratic",
        (Point(0.0, 0.0), Point(10.0, 10.0), Point(20.0, 0.0)),
    ),
    Case(
        "quadratic_interior_x_extremum",
        "quadratic",
        (Point(0.0, 0.0), Point(10.0, 2.0), Point(0.0, 4.0)),
    ),
    Case(
        "quadratic_mixed_extrema",
        "quadratic",
        (Point(-3.0, 5.0), Point(12.0, -8.0), Point(6.0, 7.0)),
    ),
    Case(
        "cubic_arch",
        "cubic",
        (Point(0.0, 0.0), Point(0.0, 30.0), Point(30.0, 30.0), Point(30.0, 0.0)),
    ),
    Case(
        "cubic_s_curve",
        "cubic",
        (Point(0.0, 0.0), Point(20.0, 40.0), Point(-10.0, -30.0), Point(30.0, 10.0)),
    ),
    Case(
        "cubic_loopish",
        "cubic",
        (Point(5.0, 1.0), Point(40.0, 20.0), Point(-30.0, 25.0), Point(10.0, -15.0)),
    ),
]


def generated_cases() -> list[Case]:
    rng = random.Random(RANDOM_SEED)
    cases: list[Case] = []

    for index in range(1, GENERATED_CASES_PER_KIND + 1):
        cases.append(Case(f"generated_linear_{index:03}", "linear", random_points(rng, 2)))
        cases.append(
            Case(
                f"generated_quadratic_{index:03}",
                "quadratic",
                random_points(rng, 3),
            )
        )
        cases.append(Case(f"generated_cubic_{index:03}", "cubic", random_points(rng, 4)))

    return cases


def random_points(rng: random.Random, count: int) -> tuple[Point, ...]:
    return tuple(
        Point(round(rng.uniform(-50.0, 50.0), 3), round(rng.uniform(-50.0, 50.0), 3))
        for _ in range(count)
    )


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def evaluate(case: Case, t: float) -> Point:
    points = case.points
    if case.kind == "linear":
        start, end = points
        return Point(lerp(start.x, end.x, t), lerp(start.y, end.y, t))
    if case.kind == "quadratic":
        start, control, end = points
        one_minus = 1.0 - t
        return Point(
            one_minus * one_minus * start.x
            + 2.0 * one_minus * t * control.x
            + t * t * end.x,
            one_minus * one_minus * start.y
            + 2.0 * one_minus * t * control.y
            + t * t * end.y,
        )
    if case.kind == "cubic":
        start, control1, control2, end = points
        one_minus = 1.0 - t
        return Point(
            one_minus * one_minus * one_minus * start.x
            + 3.0 * one_minus * one_minus * t * control1.x
            + 3.0 * one_minus * t * t * control2.x
            + t * t * t * end.x,
            one_minus * one_minus * one_minus * start.y
            + 3.0 * one_minus * one_minus * t * control1.y
            + 3.0 * one_minus * t * t * control2.y
            + t * t * t * end.y,
        )
    raise ValueError(f"Unknown case kind: {case.kind}")


def dense_bbox(case: Case) -> tuple[Point, Point]:
    sampled = [evaluate(case, index / SAMPLES) for index in range(SAMPLES + 1)]
    return (
        Point(min(point.x for point in sampled), min(point.y for point in sampled)),
        Point(max(point.x for point in sampled), max(point.y for point in sampled)),
    )


def gleam_float(value: float) -> str:
    text = f"{value:.6f}"
    text = text.rstrip("0").rstrip(".")
    if text == "-0":
        text = "0"
    if "." not in text:
        text += ".0"
    return text


def gleam_point(point: Point) -> str:
    return f"bezier.Point({gleam_float(point.x)}, {gleam_float(point.y)})"


def gleam_curve(case: Case) -> str:
    points = ",\n      ".join(gleam_point(point) for point in case.points)
    if case.kind == "linear":
        start, end = case.points
        return (
            "bezier.LinearBezierData(\n"
            f"        start: {gleam_point(start)},\n"
            f"        end: {gleam_point(end)},\n"
            "      )"
        )
    if case.kind == "quadratic":
        start, control, end = case.points
        return (
            "bezier.QuadraticBezierData(\n"
            f"        start: {gleam_point(start)},\n"
            f"        control: {gleam_point(control)},\n"
            f"        end: {gleam_point(end)},\n"
            "      )"
        )
    if case.kind == "cubic":
        start, control1, control2, end = case.points
        return (
            "bezier.CubicBezierData(\n"
            f"        start: {gleam_point(start)},\n"
            f"        control1: {gleam_point(control1)},\n"
            f"        control2: {gleam_point(control2)},\n"
            f"        end: {gleam_point(end)},\n"
            "      )"
        )
    raise ValueError(f"Unknown case kind: {case.kind}: {points}")


def render(cases: Iterable[Case]) -> str:
    rendered_cases = []
    for case in cases:
        minimum, maximum = dense_bbox(case)
        rendered_cases.append(
            "    BezierBBoxFixture(\n"
            f"      name: \"{case.name}\",\n"
            f"      curve: {gleam_curve(case)},\n"
            f"      min: {gleam_point(minimum)},\n"
            f"      max: {gleam_point(maximum)},\n"
            "    )"
        )

    return (
        "//// This file is machine-generated by scripts/generate_bezier_bbox_fixtures.py.\n"
        f"//// Oracle bboxes are computed by direct Bernstein evaluation over {SAMPLES} samples.\n"
        "\n"
        "import svg_path/bezier\n"
        "\n"
        "pub type BezierBBoxFixture {\n"
        "  BezierBBoxFixture(\n"
        "    name: String,\n"
        "    curve: bezier.BezierData,\n"
        "    min: bezier.Point,\n"
        "    max: bezier.Point,\n"
        "  )\n"
        "}\n"
        "\n"
        "pub fn fixtures() -> List(BezierBBoxFixture) {\n"
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

    output = render([*HAND_CRAFTED_CASES, *generated_cases()])
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
