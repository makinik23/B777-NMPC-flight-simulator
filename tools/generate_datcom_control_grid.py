#!/usr/bin/env python3
"""Generate Digital DATCOM control-effectiveness input decks."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


MACH_CASES = (
    ("m030", 0.30, "2.35575E6"),
    ("m050", 0.50, "3.92625E6"),
    ("m060", 0.60, "4.7115E6"),
    ("m070", 0.70, "5.49675E6"),
    ("m080", 0.80, "6.2820E6"),
)


@dataclass(frozen=True)
class ControlCase:
    control_id: str
    title: str
    namelist: str


BASE_GEOMETRY = """DIM M
PART
 $FLTCON NMACH=1.0, MACH(1)={mach:.2f},
    NALPHA=3.0, ALSCHD(1)=-2.0,0.0,2.0,
    RNNUB(1)={reynolds},
    STMACH=0.80, TSMACH=1.20$
 $OPTINS SREF=436.80, CBARR=7.0739, BLREF=64.80$
 $SYNTHS XCG=33.26, ZCG=0.0, XW=24.50, ZW=0.0, ALIW=0.0,
    XH=66.21, ZH=0.0, ALIH=0.0, XV=64.91, ZV=0.0, VERTUP=.TRUE.$
 $BODY NX=11.0, BNOSE=1.0, BTAIL=1.0, BLN=14.0, BLA=18.0,
    X(1)=0.0,3.0,8.0,15.0,25.0,35.0,45.0,55.0,65.0,72.0,73.9,
    R(1)=0.0,1.4,2.7,3.1,3.1,3.1,3.1,3.0,2.4,1.0,0.0$
 $WGPLNF CHRDTP=1.748, SSPNE=29.30, SSPN=32.40, CHRDR=11.733,
    SAVSI=34.69, CHSTAT=0.25, SWAFP=0.0, TWISTA=0.0, SSPNDD=0.0,
    DHDADI=6.0, DHDADO=6.0, TYPE=1.0$
 $WGSCHR TOVC=0.105, DELTAY=1.30, XOVC=0.40, CLI=0.0, ALPHAI=0.0,
    CLALPA(1)=0.105, CLMAX(1)=1.45, CMO=-0.04, LERI=0.015, CLAMO=0.095$
 $HTPLNF CHRDTP=2.189, SSPNE=9.00, SSPN=10.675, CHRDR=7.297,
    SAVSI=39.35, CHSTAT=0.25, SWAFP=0.0, TWISTA=0.0, SSPNDD=0.0,
    DHDADI=0.0, DHDADO=0.0, TYPE=1.0$
 $HTSCHR TOVC=0.100, DELTAY=1.30, XOVC=0.40, CLI=0.0, ALPHAI=0.0,
    CLALPA(1)=0.105, CLMAX(1)=1.20, CMO=0.0, LERI=0.010, CLAMO=0.095$
 $VTPLNF CHRDTP=2.590, SSPNE=8.80, SSPN=9.240, CHRDR=8.932,
    SAVSI=50.36, CHSTAT=0.25, SWAFP=0.0, TWISTA=0.0, TYPE=1.0$
 $VTSCHR TOVC=0.100, XOVC=0.40, CLALPA(1)=0.105, LERI=0.010$
"""


CONTROL_CASES = (
    ControlCase(
        "elevator",
        "ELEVATOR CONTROL",
        """ $SYMFLP CHRDFI=1.60, CHRDFO=0.95, SPANFI=2.00, SPANFO=9.40,
    NDELTA=3.0, DELTA(1)=-10.0,0.0,10.0,
    FTYPE=1.0, PHETE=0.0$""",
    ),
    ControlCase(
        "aileron",
        "AILERON CONTROL",
        """ $ASYFLP CHRDFI=1.25, CHRDFO=0.70, SPANFI=20.00, SPANFO=29.00,
    NDELTA=3.0, DELTAL(1)=-10.0,0.0,10.0, DELTAR(1)=10.0,0.0,-10.0,
    STYPE=4.0, PHETE=0.0$""",
    ),
)


def deck_text(case: ControlCase, case_id: str, mach: float, reynolds: str) -> str:
    return (
        BASE_GEOMETRY.format(mach=mach, reynolds=reynolds)
        + case.namelist
        + "\n"
        + f"CASEID B777-LIKE {case.title} M{mach:.2f}, GEOMETRY V0\n"
        + "NEXT CASE\n"
    )


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    output_dir = (
        repo_root / "data" / "aerodynamics" / "raw" / "datcom" / "control_grid"
    )
    output_dir.mkdir(parents=True, exist_ok=True)

    count = 0
    for control_case in CONTROL_CASES:
        for case_id, mach, reynolds in MACH_CASES:
            path = output_dir / f"b777_like_control_{control_case.control_id}_{case_id}.inp"
            path.write_text(deck_text(control_case, case_id, mach, reynolds))
            count += 1

    print(f"Wrote {count} Digital DATCOM control input decks to {output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
