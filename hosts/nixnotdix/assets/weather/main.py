import argparse
import os
import sys

import requests
from requests.adapters import HTTPAdapter

URL = "https://api.openweathermap.org/data/2.5/weather"
IP_LOOKUP_URL = "https://ipapi.co/json"
DEFAULT_CITY = "london"
TIMEOUT_SECONDS = 10

# Get your API key at https://openweathermap.org/api and export OPENWEATHER_API_KEY.
API_KEY = os.environ.get("OPENWEATHER_API_KEY")
HEADER = {"User-agent": "Mozilla/5.0"}


def get_city() -> str:
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
    s.mount("https://", HTTPAdapter(max_retries=5))

    try:
        r = s.get(
            f"{URL}?q={city}&lang={lang}&units={unit}&appid={api_key}",
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
        print("E: set OPENWEATHER_API_KEY")
        sys.exit(1)
    city = " ".join(args.city) if args.city else get_city()
    lang = args.lang
    unit = args.unit

    weather = get_weather(city, lang, unit, api_key)
    if weather:
        temp = weather["temp"]
        desc = weather["desc"]
        if args.verbose:
            print(f"{temp}, {desc}")
        else:
            print(f"{temp}")


if __name__ == "__main__":
    main()
