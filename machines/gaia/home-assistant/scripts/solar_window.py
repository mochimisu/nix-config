#!/usr/bin/env python3
import datetime
import math
from zoneinfo import ZoneInfo


def _normalize_degrees(value: float) -> float:
    return value % 360.0


def _normalize_hours(value: float) -> float:
    return value % 24.0


def _sun_event_utc_hour(day: datetime.date, latitude: float, longitude: float, sunrise: bool) -> float | None:
    # NOAA sunrise/sunset approximation for zenith 90.833 (official sunrise/sunset).
    zenith = 90.833
    day_of_year = day.timetuple().tm_yday
    lng_hour = longitude / 15.0
    base_hour = 6.0 if sunrise else 18.0
    t = day_of_year + ((base_hour - lng_hour) / 24.0)

    mean_anomaly = (0.9856 * t) - 3.289
    true_longitude = _normalize_degrees(
        mean_anomaly
        + (1.916 * math.sin(math.radians(mean_anomaly)))
        + (0.020 * math.sin(math.radians(2.0 * mean_anomaly)))
        + 282.634
    )

    right_ascension = math.degrees(math.atan(0.91764 * math.tan(math.radians(true_longitude))))
    right_ascension = _normalize_degrees(right_ascension)
    l_quadrant = math.floor(true_longitude / 90.0) * 90.0
    ra_quadrant = math.floor(right_ascension / 90.0) * 90.0
    right_ascension = (right_ascension + (l_quadrant - ra_quadrant)) / 15.0

    sin_dec = 0.39782 * math.sin(math.radians(true_longitude))
    cos_dec = math.cos(math.asin(sin_dec))
    cos_hour_angle = (
        math.cos(math.radians(zenith))
        - (sin_dec * math.sin(math.radians(latitude)))
    ) / (cos_dec * math.cos(math.radians(latitude)))

    # No sunrise/no sunset at extreme latitudes for this day.
    if cos_hour_angle > 1.0 or cos_hour_angle < -1.0:
        return None

    if sunrise:
        hour_angle = 360.0 - math.degrees(math.acos(cos_hour_angle))
    else:
        hour_angle = math.degrees(math.acos(cos_hour_angle))
    hour_angle /= 15.0

    local_mean_time = hour_angle + right_ascension - (0.06571 * t) - 6.622
    return _normalize_hours(local_mean_time - lng_hour)


def _utc_hour_to_local_dt(day: datetime.date, utc_hour: float, timezone_name: str) -> datetime.datetime:
    hour = int(utc_hour)
    minute_float = (utc_hour - hour) * 60.0
    minute = int(minute_float)
    second = int(round((minute_float - minute) * 60.0))

    if second >= 60:
        second -= 60
        minute += 1
    if minute >= 60:
        minute -= 60
        hour += 1

    base_utc = datetime.datetime(
        day.year,
        day.month,
        day.day,
        tzinfo=datetime.timezone.utc,
    )
    event_utc = base_utc + datetime.timedelta(hours=hour, minutes=minute, seconds=second)
    return event_utc.astimezone(ZoneInfo(timezone_name))


def solar_events_for_day(
    day: datetime.date,
    *,
    latitude: float,
    longitude: float,
    timezone_name: str,
) -> tuple[datetime.datetime | None, datetime.datetime | None]:
    sunrise_utc_hour = _sun_event_utc_hour(day, latitude, longitude, sunrise=True)
    sunset_utc_hour = _sun_event_utc_hour(day, latitude, longitude, sunrise=False)

    sunrise_local = (
        _utc_hour_to_local_dt(day, sunrise_utc_hour, timezone_name)
        if sunrise_utc_hour is not None
        else None
    )
    sunset_local = (
        _utc_hour_to_local_dt(day, sunset_utc_hour, timezone_name)
        if sunset_utc_hour is not None
        else None
    )
    if sunrise_local is not None:
        if sunrise_local.date() < day:
            sunrise_local += datetime.timedelta(days=1)
        elif sunrise_local.date() > day:
            sunrise_local -= datetime.timedelta(days=1)
    if sunset_local is not None:
        if sunset_local.date() < day:
            sunset_local += datetime.timedelta(days=1)
        elif sunset_local.date() > day:
            sunset_local -= datetime.timedelta(days=1)
    return sunrise_local, sunset_local


def is_now_in_solar_window(
    *,
    latitude: float,
    longitude: float,
    timezone_name: str,
    mode: str = "sunset_to_sunrise",
    now: datetime.datetime | None = None,
) -> bool | None:
    current = now or datetime.datetime.now(ZoneInfo(timezone_name))
    if current.tzinfo is None:
        current = current.replace(tzinfo=ZoneInfo(timezone_name))
    else:
        current = current.astimezone(ZoneInfo(timezone_name))

    sunrise, sunset = solar_events_for_day(
        current.date(),
        latitude=latitude,
        longitude=longitude,
        timezone_name=timezone_name,
    )
    if sunrise is None or sunset is None:
        return None

    if mode == "sunset_to_sunrise":
        return current >= sunset or current < sunrise
    if mode == "sunrise_to_sunset":
        return sunrise <= current < sunset
    return None


def _julian_day(dt_utc: datetime.datetime) -> float:
    year = dt_utc.year
    month = dt_utc.month
    day = dt_utc.day + (
        dt_utc.hour / 24.0
        + dt_utc.minute / 1440.0
        + dt_utc.second / 86400.0
        + dt_utc.microsecond / 86400000000.0
    )
    if month <= 2:
        year -= 1
        month += 12
    a = math.floor(year / 100)
    b = 2 - a + math.floor(a / 4)
    return (
        math.floor(365.25 * (year + 4716))
        + math.floor(30.6001 * (month + 1))
        + day
        + b
        - 1524.5
    )


def _normalize_angle_signed(angle: float) -> float:
    return ((angle + 180.0) % 360.0) - 180.0


def sun_position(
    *,
    latitude: float,
    longitude: float,
    timezone_name: str,
    now: datetime.datetime | None = None,
) -> dict:
    local_tz = ZoneInfo(timezone_name)
    current_local = now or datetime.datetime.now(local_tz)
    if current_local.tzinfo is None:
        current_local = current_local.replace(tzinfo=local_tz)
    else:
        current_local = current_local.astimezone(local_tz)
    dt_utc = current_local.astimezone(datetime.timezone.utc)

    jd = _julian_day(dt_utc)
    t = (jd - 2451545.0) / 36525.0

    l0 = (280.46646 + t * (36000.76983 + t * 0.0003032)) % 360.0
    m = 357.52911 + t * (35999.05029 - 0.0001537 * t)
    e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
    c = (
        math.sin(math.radians(m)) * (1.914602 - t * (0.004817 + 0.000014 * t))
        + math.sin(math.radians(2.0 * m)) * (0.019993 - 0.000101 * t)
        + math.sin(math.radians(3.0 * m)) * 0.000289
    )
    true_long = l0 + c
    omega = 125.04 - 1934.136 * t
    app_long = true_long - 0.00569 - 0.00478 * math.sin(math.radians(omega))

    mean_obliq = 23.0 + (
        26.0 + (
            21.448
            - t * (46.815 + t * (0.00059 - t * 0.001813))
        ) / 60.0
    ) / 60.0
    obliq_corr = mean_obliq + 0.00256 * math.cos(math.radians(omega))

    decl_rad = math.asin(
        math.sin(math.radians(obliq_corr)) * math.sin(math.radians(app_long))
    )
    decl_deg = math.degrees(decl_rad)

    y = math.tan(math.radians(obliq_corr / 2.0)) ** 2
    eq_time = 4.0 * math.degrees(
        y * math.sin(2.0 * math.radians(l0))
        - 2.0 * e * math.sin(math.radians(m))
        + 4.0 * e * y * math.sin(math.radians(m)) * math.cos(2.0 * math.radians(l0))
        - 0.5 * y * y * math.sin(4.0 * math.radians(l0))
        - 1.25 * e * e * math.sin(2.0 * math.radians(m))
    )

    minutes = (
        current_local.hour * 60.0
        + current_local.minute
        + current_local.second / 60.0
        + current_local.microsecond / 60000000.0
    )
    offset_min = current_local.utcoffset().total_seconds() / 60.0
    true_solar_min = (minutes + eq_time + 4.0 * longitude - offset_min) % 1440.0
    hour_angle = true_solar_min / 4.0 - 180.0
    if hour_angle < -180.0:
        hour_angle += 360.0

    lat_rad = math.radians(latitude)
    ha_rad = math.radians(hour_angle)
    cos_zenith = (
        math.sin(lat_rad) * math.sin(decl_rad)
        + math.cos(lat_rad) * math.cos(decl_rad) * math.cos(ha_rad)
    )
    cos_zenith = min(1.0, max(-1.0, cos_zenith))
    zenith = math.degrees(math.acos(cos_zenith))
    elevation = 90.0 - zenith

    azimuth = (
        math.degrees(
            math.atan2(
                math.sin(ha_rad),
                math.cos(ha_rad) * math.sin(lat_rad) - math.tan(decl_rad) * math.cos(lat_rad),
            )
        )
        + 180.0
    ) % 360.0

    return {
        "azimuth_deg": azimuth,
        "elevation_deg": elevation,
        "declination_deg": decl_deg,
        "equation_of_time_min": eq_time,
        "is_daylight": elevation > 0.0,
    }


def facade_sun_position(
    *,
    sun_azimuth_deg: float,
    sun_elevation_deg: float,
    facade_azimuth_deg: float,
) -> dict:
    horizontal_offset = _normalize_angle_signed(sun_azimuth_deg - facade_azimuth_deg)
    # Positive X means sun is to the right when facing outward from facade.
    horizontal_pos = math.tan(math.radians(horizontal_offset))
    # Positive Y means above horizon in facade plane projection.
    vertical_pos = (
        math.tan(math.radians(sun_elevation_deg))
        / max(1e-6, math.cos(math.radians(horizontal_offset)))
    )
    return {
        "horizontal_offset_deg": horizontal_offset,
        "vertical_deg": sun_elevation_deg,
        "window_x": horizontal_pos,
        "window_y": vertical_pos,
        "in_front_of_facade": abs(horizontal_offset) <= 90.0 and sun_elevation_deg > 0.0,
    }
