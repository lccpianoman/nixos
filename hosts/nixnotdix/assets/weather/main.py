"""Waybar weather widget: print the current temperature for a city.

Called by Waybar (via weather.sh) every 30 minutes with an explicit
`-c` city, so the IP-geolocation lookup below only runs for ad-hoc CLI
use without `-c` — and may pick the wrong city (VPN, ISP routing); it
warns on stderr when it falls back. Prints `N/A` and exits non-zero on
any failure so the bar shows something sensible.
"""

import argparse
import os
import sys

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

URL = "https://api.openweathermap.org/data/2.5/weather"
IP_LOOKUP_URL = "https://ipapi.co/json"
DEFAULT_CITY = "london"
TIMEOUT_SECONDS = 10
# Printed on stdout when the lookup fails so Waybar shows something sensible
FALLBACK_OUTPUT = "N/A"

# Get your API key at https://openweathermap.org/api and export OPENWEATHER_API_KEY.
API_KEY = os.environ.get("OPENWEATHER_API_KEY")
HEADER = {"User-Agent": "waybar-weather-widget/1.0"}

RETRIES = Retry(
    total=5,
    backoff_factor=1,
    status_forcelist=(429, 500, 502, 503, 504),
    allowed_methods=("GET",),
)


def get_city() -> str:
    """Guess the city from the machine's public IP; warns and falls back
    to DEFAULT_CITY when the lookup fails or returns nothing."""
    try:
        r = requests.get(IP_LOOKUP_URL, headers=HEADER, timeout=TIMEOUT_SECONDS)
        r.raise_for_status()
        city = r.json().get("city")
        if isinstance(city, str) and city:
            return city
        print(f"E: city lookup returned no city, falling back to {DEFAULT_CITY}", file=sys.stderr)
    except (requests.exceptions.RequestException, ValueError) as exc:
        print(f"E: couldn't get city name ({exc}), falling back to {DEFAULT_CITY}", file=sys.stderr)

    return DEFAULT_CITY


def unit_suffix(unit: str) -> str:
    match unit:
        case "metric":
            unit = "ºC"
        case "imperial":
            unit = "ºF"
        case _:
            unit = " K"

    return unit


def get_weather(city: str, lang: str, unit: str, api_key: str) -> dict[str, str] | None:
    s = requests.Session()
    s.mount("https://", HTTPAdapter(max_retries=RETRIES))

    try:
        r = s.get(
            URL,
            params={"q": city, "lang": lang, "units": unit, "appid": api_key},
            headers=HEADER,
            timeout=TIMEOUT_SECONDS,
        )
        r.raise_for_status()
        data = r.json()
        temp = data["main"]["temp"]
        desc = data["weather"][0]["description"]
    except requests.exceptions.RequestException as exc:
        print(f"E: failed weather API request ({exc})", file=sys.stderr)
        return None
    except (KeyError, IndexError, TypeError, ValueError) as exc:
        print(f"E: invalid weather API response ({exc})", file=sys.stderr)
        return None

    unit = unit_suffix(unit)
    return {
        "temp": f"{int(round(temp))}{unit}",
        "desc": desc.title(),
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Display information about the weather.",
    )
    parser.add_argument(
        "-c",
        metavar="CITY",
        dest="city",
        type=str,
        nargs="+",
        help="city name",
    )
    parser.add_argument(
        "-l",
        metavar="LANG",
        dest="lang",
        type=str,
        default="en",
        help="language (en, es, fr, ja, pt, pt_br, ru, zh_cn)",
    )
    parser.add_argument(
        "-u",
        metavar="standard/metric/imperial",
        choices=("standard", "metric", "imperial"),
        dest="unit",
        type=str,
        default="standard",
        help="unit of temperature (default: kelvin)",
    )
    parser.add_argument(
        "-a",
        metavar="API_KEY",
        dest="api_key",
        type=str,
        help="API Key",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        dest="verbose",
        help="verbose mode",
    )

    args = parser.parse_args()

    api_key = args.api_key if args.api_key else API_KEY
    if not api_key:
        print("E: set OPENWEATHER_API_KEY", file=sys.stderr)
        print(FALLBACK_OUTPUT)
        sys.exit(1)
    city = " ".join(args.city) if args.city else get_city()
    lang = args.lang
    unit = args.unit

    weather = get_weather(city, lang, unit, api_key)
    if weather is None:
        print(FALLBACK_OUTPUT)
        sys.exit(1)

    temp = weather["temp"]
    desc = weather["desc"]
    if args.verbose:
        print(f"{temp}, {desc}")
    else:
        print(f"{temp}")


if __name__ == "__main__":
    main()
