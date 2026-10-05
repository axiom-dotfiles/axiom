#!/usr/bin/env python3
"""Axiom's calendars: CalDAV accounts and read-only .ics subscriptions.

CalendarManager runs it through scripts/venv_python.sh (icalendar and
recurring-ical-events, from requirements.txt):

  calendar_sync.py discover|sync|save|delete

Each reads one JSON object on stdin (passwords included: never argv, never
printed) and prints one JSON object. Failures are `{"ok": false, "code",
"message"}`, `code` one of auth, network, notFound, notCalendar, conflict,
server, parse, noPassword, readOnly.

discover  {kind, url, username, password}
          -> {ok, calendars: [{href, name, color, components, readOnly}]}
             `kind` "caldav" finds the calendars from any URL on the server
             (the principal and its calendar home, following redirects:
             iCloud moves to a pNN-caldav host); "ics" is one feed.
sync      {stateDir, range: {from, to}, accounts: [Account], only?: {account, calendar}}
          -> {ok, errors: [{calendar, code, message}], changed}
             Account: {id, kind, url, username, password, calendars: [{href}]}
             (the enabled ones). Fetches what changed (getctag, then etags;
             an .ics feed by ETag), keeps raw objects in
             <stateDir>/objects.json and writes the expanded occurrences in
             the range to <stateDir>/events.json, both atomically. `only`
             refetches one calendar whatever its ctag.
save      {…sync's input, account, calendar, href?, etag?, scope, rid?, event}
          -> {ok, href} then syncs the calendar again. No `href`: a new
             event. `scope` "series" edits the whole event, "occurrence"
             only the one at `rid` (a RECURRENCE-ID override).
delete    {…sync's input, account, calendar, href, etag, scope, rid?}
          -> {ok}; "occurrence" adds an EXDATE instead.

events.json: {version, updated, range, events: [Occurrence], errors}
Occurrence: {key, calendar ("<account>|<calendar href>"), href, etag, uid,
  rid ("" | "D:YYYY-MM-DD" | "T:<epoch s>": the original start), recurring,
  repeat (none|daily|weekly|monthly|yearly|custom), allDay, start, end (epoch
  ms; all-day at local midnight), dayStart, dayEnd (all-day, end exclusive),
  title, location, description, alarms ([epoch ms]), reminder (minutes
  before the start of its first relative alarm, -1 for none)}
"""
import base64
import copy
import datetime as dt
import json
import os
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import uuid
import xml.etree.ElementTree as ET
import zoneinfo

D = "DAV:"
C = "urn:ietf:params:xml:ns:caldav"
CS = "http://calendarserver.org/ns/"
A = "http://apple.com/ns/ical/"
NS = {"D": D, "C": C, "CS": CS, "A": A}
TIMEOUT = 30
MULTIGET_BATCH = 50
FREQS = {"DAILY": "daily", "WEEKLY": "weekly", "MONTHLY": "monthly", "YEARLY": "yearly"}


class Failure(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code
        self.message = message


# --- HTTP / WebDAV ---------------------------------------------------------

class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


_opener = urllib.request.build_opener(_NoRedirect)


def normalize_url(url):
    url = (url or "").strip()
    if url.startswith("webcal://") or url.startswith("webcals://"):
        url = "https://" + url.split("://", 1)[1]
    if url and "://" not in url:
        url = "https://" + url
    return url


class Dav:
    def __init__(self, username="", password=""):
        self.auth = None
        if username or password:
            token = base64.b64encode(f"{username}:{password}".encode()).decode()
            self.auth = "Basic " + token

    def request(self, method, url, body=None, headers=None, depth=None):
        """(status, headers, body bytes, final url), following redirects for
        any method (urllib only follows GET's)."""
        for _ in range(6):
            req = urllib.request.Request(url, data=body.encode() if isinstance(body, str) else body, method=method)
            req.add_header("User-Agent", "axiom-calendar")
            if self.auth:
                req.add_header("Authorization", self.auth)
            if depth is not None:
                req.add_header("Depth", str(depth))
            if body is not None and not (headers or {}).get("Content-Type"):
                req.add_header("Content-Type", "application/xml; charset=utf-8")
            for key, value in (headers or {}).items():
                req.add_header(key, value)
            try:
                with _opener.open(req, timeout=TIMEOUT) as resp:
                    return resp.status, resp.headers, resp.read(), url
            except urllib.error.HTTPError as err:
                if err.code in (301, 302, 303, 307, 308) and err.headers.get("Location"):
                    url = urllib.parse.urljoin(url, err.headers["Location"])
                    continue
                if err.code == 401:
                    raise Failure("auth", "The server refused the username or password") from None
                return err.code, err.headers, err.read(), url
            except (urllib.error.URLError, OSError) as err:
                reason = getattr(err, "reason", err)
                raise Failure("network", f"Could not reach {urllib.parse.urlparse(url).netloc}: {reason}") from None
        raise Failure("network", "Too many redirects")

    def propfind(self, url, props, depth):
        body = ('<?xml version="1.0" encoding="utf-8"?><D:propfind xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav" '
                'xmlns:CS="http://calendarserver.org/ns/" xmlns:A="http://apple.com/ns/ical/"><D:prop>'
                + "".join(f"<{p}/>" for p in props) + "</D:prop></D:propfind>")
        status, _, data, final = self.request("PROPFIND", url, body, depth=depth)
        if status == 404:
            raise Failure("notFound", f"Nothing at {url}")
        if status >= 400:
            raise Failure("server", f"PROPFIND {url}: HTTP {status}")
        return parse_multistatus(data, final), final

    def report(self, url, body, depth=1):
        status, _, data, final = self.request("REPORT", url, body, depth=depth)
        if status >= 400:
            raise Failure("server", f"REPORT {url}: HTTP {status}")
        return parse_multistatus(data, final)


def parse_multistatus(data, base):
    """{absolute href: {"{ns}name": Element}} from a 207 body (200 propstats only)."""
    try:
        root = ET.fromstring(data)
    except ET.ParseError as err:
        raise Failure("parse", f"The server's reply isn't XML: {err}") from None
    out = {}
    for response in root.findall("D:response", NS):
        href_el = response.find("D:href", NS)
        if href_el is None or not href_el.text:
            continue
        href = urllib.parse.urljoin(base, href_el.text.strip())
        props = out.setdefault(href, {})
        for propstat in response.findall("D:propstat", NS):
            status = propstat.findtext("D:status", "", NS)
            if status and " 200 " not in status + " ":
                continue
            prop = propstat.find("D:prop", NS)
            for child in list(prop) if prop is not None else []:
                props[child.tag] = child
    return out


def _href_of(el):
    href = el.find("D:href", NS) if el is not None else None
    return href.text.strip() if href is not None and href.text else None


def _text(props, tag):
    el = props.get(tag)
    return (el.text or "").strip() if el is not None else ""


def _is_calendar(props):
    rt = props.get(f"{{{D}}}resourcetype")
    return rt is not None and rt.find("C:calendar", NS) is not None


CAL_PROPS = ["D:resourcetype", "D:displayname", "A:calendar-color", "C:supported-calendar-component-set",
             "CS:getctag", "D:sync-token", "D:current-user-privilege-set"]


def calendar_info(href, props):
    comps_el = props.get(f"{{{C}}}supported-calendar-component-set")
    comps = [c.get("name") for c in comps_el.findall("C:comp", NS)] if comps_el is not None else ["VEVENT", "VTODO"]
    privs = props.get(f"{{{D}}}current-user-privilege-set")
    read_only = False
    if privs is not None:
        names = {child.tag for p in privs.findall("D:privilege", NS) for child in p}
        read_only = not names & {f"{{{D}}}{n}" for n in ("write", "write-content", "all", "bind")}
    color = _text(props, f"{{{A}}}calendar-color")
    if len(color) == 9 and color.startswith("#"):
        color = color[:7]
    name = _text(props, f"{{{D}}}displayname") or urllib.parse.unquote(href.rstrip("/").rsplit("/", 1)[-1])
    return {"href": href, "name": name, "color": color, "components": comps, "readOnly": read_only}


def discover_caldav(dav, url):
    candidates = [url, urllib.parse.urljoin(url, "/.well-known/caldav")]
    last = None
    for candidate in candidates:
        try:
            found, final = dav.propfind(candidate, ["D:current-user-principal", "D:resourcetype", "C:calendar-home-set"] + CAL_PROPS, 0)
        except Failure as err:
            if err.code == "auth":
                raise
            last = err
            continue
        props = next(iter(found.values()), {})
        if _is_calendar(props):
            return [calendar_info(final, props)]
        home = _href_of(props.get(f"{{{C}}}calendar-home-set"))
        principal = _href_of(props.get(f"{{{D}}}current-user-principal"))
        if not home and principal:
            principal = urllib.parse.urljoin(final, principal)
            found, pfinal = dav.propfind(principal, ["C:calendar-home-set"], 0)
            pprops = next(iter(found.values()), {})
            home = _href_of(pprops.get(f"{{{C}}}calendar-home-set"))
            if home:
                home = urllib.parse.urljoin(pfinal, home)
        elif home:
            home = urllib.parse.urljoin(final, home)
        listing, hfinal = dav.propfind(home or final, CAL_PROPS, 1)
        calendars = [calendar_info(href, props) for href, props in listing.items() if _is_calendar(props)]
        if calendars:
            return sorted(calendars, key=lambda c: c["name"].lower())
        last = Failure("notCalendar", "No calendars found at that address")
    raise last or Failure("notCalendar", "No calendars found at that address")


def fetch_feed(dav, url, etag=None):
    """(status, etag, text) of an .ics feed; status 304 keeps the cached copy."""
    headers = {"Accept": "text/calendar"}
    if etag:
        headers["If-None-Match"] = etag
    status, resp_headers, data, _ = dav.request("GET", url, headers=headers)
    if status == 304:
        return 304, etag, None
    if status == 404:
        raise Failure("notFound", f"Nothing at {url}")
    if status >= 400:
        raise Failure("server", f"GET {url}: HTTP {status}")
    return status, resp_headers.get("ETag") or "", data.decode("utf-8", "replace")


def discover_feed(dav, url):
    import icalendar
    _, _, text = fetch_feed(dav, url)
    try:
        cal = icalendar.Calendar.from_ical(text)
    except ValueError as err:
        raise Failure("parse", f"Not an iCalendar feed: {err}") from None
    name = str(cal.get("X-WR-CALNAME") or urllib.parse.urlparse(url).netloc)
    color = str(cal.get("X-APPLE-CALENDAR-COLOR") or "")[:7]
    return [{"href": url, "name": name, "color": color, "components": ["VEVENT"], "readOnly": True}]


# --- Sync -------------------------------------------------------------------

def sync_caldav(dav, cal_url, cached, force):
    """The calendar's {ctag, objects: {href: {etag, ics}}}, reusing `cached`."""
    found, _ = dav.propfind(cal_url, ["CS:getctag", "D:sync-token"], 0)
    props = next(iter(found.values()), {})
    ctag = _text(props, f"{{{CS}}}getctag") or _text(props, f"{{{D}}}sync-token")
    if ctag and cached and cached.get("ctag") == ctag and not force:
        return cached
    listing, _ = dav.propfind(cal_url, ["D:getetag", "D:resourcetype"], 1)
    old = (cached or {}).get("objects", {})
    objects, wanted = {}, []
    base = cal_url.rstrip("/")
    for href, p in listing.items():
        if href.rstrip("/") == base:
            continue
        rt = p.get(f"{{{D}}}resourcetype")
        if rt is not None and rt.find("D:collection", NS) is not None:
            continue
        etag = _text(p, f"{{{D}}}getetag")
        if href in old and etag and old[href].get("etag") == etag:
            objects[href] = old[href]
        else:
            wanted.append(href)
    for i in range(0, len(wanted), MULTIGET_BATCH):
        hrefs = "".join(f"<D:href>{_xml_escape(urllib.parse.urlparse(h).path)}</D:href>" for h in wanted[i:i + MULTIGET_BATCH])
        body = ('<?xml version="1.0" encoding="utf-8"?><C:calendar-multiget xmlns:D="DAV:" '
                'xmlns:C="urn:ietf:params:xml:ns:caldav"><D:prop><D:getetag/><C:calendar-data/></D:prop>'
                + hrefs + "</C:calendar-multiget>")
        for href, p in dav.report(cal_url, body).items():
            data = _text(p, f"{{{C}}}calendar-data")
            if data:
                objects[href] = {"etag": _text(p, f"{{{D}}}getetag"), "ics": data}
    return {"ctag": ctag, "objects": objects}


def sync_feed(dav, url, cached, force):
    etag = None if force else (cached or {}).get("ctag")
    status, new_etag, text = fetch_feed(dav, url, etag)
    if status == 304 and cached:
        return cached
    return {"ctag": new_etag, "objects": {url: {"etag": new_etag, "ics": text}}}


def _xml_escape(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def calendar_id(account_id, href):
    return f"{account_id}|{href}"


def run_sync(req):
    state_dir = req["stateDir"]
    objects_path = os.path.join(state_dir, "objects.json")
    store = read_json(objects_path, {"version": 1, "calendars": {}})
    only = req.get("only") or {}
    errors, changed = [], False
    calendars = {}
    for account in req.get("accounts", []):
        kind = account.get("kind", "caldav")
        dav = Dav(account.get("username", ""), account.get("password", "")) if kind == "caldav" else Dav()
        for cal in account.get("calendars", []):
            cid = calendar_id(account["id"], cal["href"])
            cached = store["calendars"].get(cid)
            if only and (only.get("account") != account["id"] or only.get("calendar") != cal["href"]):
                if cached:
                    calendars[cid] = cached
                continue
            try:
                if kind == "caldav" and not account.get("password"):
                    raise Failure("noPassword", "No password saved for this account")
                force = bool(only)
                fresh = sync_caldav(dav, cal["href"], cached, force) if kind == "caldav" else sync_feed(dav, cal["href"], cached, force)
                if fresh is not cached:
                    changed = True
                calendars[cid] = fresh
            except Failure as err:
                errors.append({"calendar": cid, "code": err.code, "message": err.message})
                if cached:
                    calendars[cid] = cached
    if set(calendars) != set(store["calendars"]):
        changed = True
    store["calendars"] = calendars
    write_json(objects_path, store)
    rng = req["range"]
    events = expand_all(calendars, rng["from"], rng["to"])
    write_json(os.path.join(state_dir, "events.json"), {
        "version": 1,
        "updated": int(dt.datetime.now().timestamp() * 1000),
        "range": rng,
        "events": events,
        "errors": errors,
    })
    return {"ok": True, "errors": errors, "changed": changed, "count": len(events)}


# --- Expansion ---------------------------------------------------------------

def to_ms(value):
    """Epoch ms of a date (local midnight) or datetime (naive = local)."""
    if isinstance(value, dt.datetime):
        return int(value.timestamp() * 1000)
    return int(dt.datetime.combine(value, dt.time()).timestamp() * 1000)


def rid_of(value):
    if value is None:
        return ""
    if isinstance(value, dt.datetime):
        return f"T:{int(value.timestamp())}"
    return f"D:{value.isoformat()}"


def repeat_of(master):
    rrule = master.get("RRULE") if master is not None else None
    if not rrule:
        return "custom" if master is not None and master.get("RDATE") else "none"
    keys = set(rrule.keys()) - {"WKST"}
    freq = (rrule.get("FREQ") or [""])[0]
    if keys == {"FREQ"} and freq in FREQS:
        return FREQS[freq]
    return "custom"


def reminder_of(component):
    for alarm in component.walk("VALARM"):
        trigger = alarm.get("TRIGGER")
        if trigger is None or str(alarm.get("ACTION", "")).upper() == "NONE":
            continue
        if isinstance(trigger.dt, dt.timedelta) and trigger.params.get("RELATED", "START") == "START":
            return max(0, int(-trigger.dt.total_seconds() // 60))
    return -1


def alarms_of(component, start, end):
    out = []
    for alarm in component.walk("VALARM"):
        trigger = alarm.get("TRIGGER")
        if trigger is None or str(alarm.get("ACTION", "")).upper() == "NONE":
            continue
        value = trigger.dt
        if isinstance(value, dt.timedelta):
            base = end if trigger.params.get("RELATED", "START") == "END" else start
            out.append(base + int(value.total_seconds() * 1000))
        elif isinstance(value, dt.datetime):
            out.append(to_ms(value))
    return sorted(set(out))


def end_of(component, start):
    end = component.get("DTEND")
    if end is not None:
        return end.dt
    duration = component.get("DURATION")
    if duration is not None:
        return start + duration.dt
    return start + dt.timedelta(days=1) if not isinstance(start, dt.datetime) else start


def expand_object(cid, href, obj, start, end):
    import icalendar
    import recurring_ical_events
    cal = icalendar.Calendar.from_ical(obj["ics"])
    masters, recurring = {}, set()
    for ev in cal.walk("VEVENT"):
        uid = str(ev.get("UID", ""))
        if ev.get("RECURRENCE-ID") is not None:
            recurring.add(uid)
        else:
            masters[uid] = ev
            if ev.get("RRULE") or ev.get("RDATE"):
                recurring.add(uid)
    out = []
    for ev in recurring_ical_events.of(cal, components=["VEVENT"]).between(start, end):
        uid = str(ev.get("UID", ""))
        s = ev.get("DTSTART").dt
        e = end_of(ev, s)
        all_day = not isinstance(s, dt.datetime)
        is_rec = uid in recurring
        rid = rid_of(ev.get("RECURRENCE-ID").dt) if is_rec and ev.get("RECURRENCE-ID") is not None else ""
        start_ms, end_ms = to_ms(s), to_ms(e)
        occ = {
            "key": f"{cid}|{uid}|{rid}",
            "calendar": cid,
            "href": href,
            "etag": obj.get("etag", ""),
            "uid": uid,
            "rid": rid,
            "recurring": is_rec,
            "repeat": repeat_of(masters.get(uid)) if is_rec else "none",
            "allDay": all_day,
            "start": start_ms,
            "end": max(end_ms, start_ms),
            "dayStart": s.isoformat() if all_day else "",
            "dayEnd": (e if e > s else s + dt.timedelta(days=1)).isoformat() if all_day else "",
            "title": str(ev.get("SUMMARY", "")),
            "location": str(ev.get("LOCATION", "")),
            "description": str(ev.get("DESCRIPTION", "")),
            "alarms": alarms_of(ev, start_ms, end_ms),
            "reminder": reminder_of(ev),
        }
        out.append(occ)
    return out


def expand_all(calendars, from_ms, to_ms_):
    start = dt.datetime.fromtimestamp(from_ms / 1000)
    end = dt.datetime.fromtimestamp(to_ms_ / 1000)
    events = []
    for cid, cal in calendars.items():
        for href, obj in cal.get("objects", {}).items():
            try:
                events.extend(expand_object(cid, href, obj, start, end))
            except Exception as err:  # one broken object never hides the rest
                print(f"calendar_sync: skipping {href}: {err}", file=sys.stderr)
    events.sort(key=lambda e: (e["start"], not e["allDay"], e["title"].lower()))
    return events


# --- Writing ---------------------------------------------------------------

def local_zone():
    name = os.environ.get("TZ", "").lstrip(":")
    if not name:
        real = os.path.realpath("/etc/localtime")
        if "zoneinfo/" in real:
            name = real.split("zoneinfo/", 1)[1]
    try:
        return zoneinfo.ZoneInfo(name) if name else dt.timezone.utc
    except (zoneinfo.ZoneInfoNotFoundError, ValueError):
        return dt.timezone.utc


def _local_dt(ms, tz):
    return dt.datetime.fromtimestamp(ms / 1000, tz)


def _date(iso):
    return dt.date.fromisoformat(iso)


def _set(component, name, value):
    component.pop(name, None)
    if value not in (None, ""):
        component.add(name, value)


def _touch(component):
    _set(component, "DTSTAMP", dt.datetime.now(dt.timezone.utc))
    _set(component, "LAST-MODIFIED", dt.datetime.now(dt.timezone.utc))
    component["SEQUENCE"] = int(component.get("SEQUENCE", 0)) + 1


def _set_times(component, event, tz):
    if event.get("allDay"):
        start = _date(event["dayStart"])
        end = _date(event["dayEnd"]) if event.get("dayEnd") else start + dt.timedelta(days=1)
        if end <= start:
            end = start + dt.timedelta(days=1)
    else:
        start = _local_dt(event["start"], tz)
        end = _local_dt(max(event["end"], event["start"]), tz)
    component.pop("DURATION", None)
    _set(component, "DTSTART", start)
    _set(component, "DTEND", end)


def _set_text(component, event):
    _set(component, "SUMMARY", event.get("title", ""))
    _set(component, "LOCATION", event.get("location", ""))
    _set(component, "DESCRIPTION", event.get("description", ""))


def _set_reminder(component, minutes, title):
    import icalendar
    component.subcomponents = [c for c in component.subcomponents if c.name != "VALARM"]
    if minutes is not None and minutes >= 0:
        alarm = icalendar.Alarm()
        alarm.add("ACTION", "DISPLAY")
        alarm.add("DESCRIPTION", title or "Reminder")
        alarm.add("TRIGGER", dt.timedelta(minutes=-minutes))
        component.add_component(alarm)


def rid_value(rid, like, tz):
    """The RECURRENCE-ID/EXDATE value for `rid`, typed like the master's DTSTART."""
    kind, _, raw = rid.partition(":")
    if kind == "D":
        return _date(raw)
    moment = dt.datetime.fromtimestamp(int(raw), dt.timezone.utc)
    if isinstance(like, dt.datetime):
        if like.tzinfo is None:
            return moment.astimezone().replace(tzinfo=None)
        return moment.astimezone(like.tzinfo)
    return moment.astimezone(tz).date()


def _same_rid(component, rid):
    value = component.get("RECURRENCE-ID")
    return value is not None and rid_of(value.dt) == rid


def _master(cal):
    return next((ev for ev in cal.walk("VEVENT") if ev.get("RECURRENCE-ID") is None), None)


def _shift_series(cal, master, event, tz):
    """Moves a recurring series by how far its edited occurrence moved, along
    with its overrides' RECURRENCE-IDs and its EXDATEs, so they keep matching."""
    old_start = master.get("DTSTART").dt
    old_all_day = not isinstance(old_start, dt.datetime)
    orig = event.get("origStart")
    if event.get("allDay"):
        orig_day = dt.datetime.fromtimestamp(orig / 1000).date() if orig is not None else _date(event["dayStart"])
        delta = _date(event["dayStart"]) - orig_day
        length = (_date(event["dayEnd"]) - _date(event["dayStart"])) if event.get("dayEnd") else dt.timedelta(days=1)
        base_day = old_start if old_all_day else old_start.date()
        new_start, new_end = base_day + delta, base_day + delta + max(length, dt.timedelta(days=1))
    else:
        new_local = _local_dt(event["start"], tz)
        length = dt.timedelta(milliseconds=max(0, event["end"] - event["start"]))
        if old_all_day:
            new_start = dt.datetime.combine(old_start, new_local.time(), tz)
            delta = None
        else:
            orig_local = _local_dt(orig if orig is not None else event["start"], tz)
            delta = new_local.replace(tzinfo=None) - orig_local.replace(tzinfo=None)
            new_start = old_start + delta
        new_end = new_start + length
    master.pop("DURATION", None)
    _set(master, "DTSTART", new_start)
    _set(master, "DTEND", new_end)
    same_kind = old_all_day == bool(event.get("allDay"))
    if same_kind and delta:
        for ev in cal.walk("VEVENT"):
            if ev is not master and ev.get("RECURRENCE-ID") is not None:
                ev["RECURRENCE-ID"].dt = ev["RECURRENCE-ID"].dt + delta
        exdates = master.get("EXDATE")
        if exdates is not None:
            for group in exdates if isinstance(exdates, list) else [exdates]:
                for d in group.dts:
                    d.dt = d.dt + delta
    elif not same_kind:
        # A series turned all-day (or back): old overrides and exceptions
        # no longer name occurrences
        master.pop("EXDATE", None)
        cal.subcomponents = [c for c in cal.subcomponents if not (c.name == "VEVENT" and c.get("RECURRENCE-ID") is not None)]


def build_new(event, tz):
    import icalendar
    cal = icalendar.Calendar()
    cal.add("PRODID", "-//axiom//calendar//EN")
    cal.add("VERSION", "2.0")
    ev = icalendar.Event()
    ev.add("UID", str(uuid.uuid4()))
    _set_text(ev, event)
    _set_times(ev, event, tz)
    if event.get("repeat") in ("daily", "weekly", "monthly", "yearly"):
        ev.add("RRULE", {"FREQ": event["repeat"].upper()})
    _set_reminder(ev, event.get("reminder", -1), event.get("title"))
    _touch(ev)
    cal.add_component(ev)
    return cal, str(ev["UID"])


def apply_series(cal, event, tz):
    master = _master(cal)
    if master is None:
        raise Failure("parse", "The event has no main entry")
    recurring = master.get("RRULE") is not None or master.get("RDATE") is not None
    _set_text(master, event)
    if recurring and event.get("repeat") != "none":
        _shift_series(cal, master, event, tz)
    else:
        _set_times(master, event, tz)
    if event.get("repeatChanged"):
        master.pop("RRULE", None)
        if event.get("repeat") in ("daily", "weekly", "monthly", "yearly"):
            master.add("RRULE", {"FREQ": event["repeat"].upper()})
        else:
            master.pop("RDATE", None)
            master.pop("EXDATE", None)
            cal.subcomponents = [c for c in cal.subcomponents if not (c.name == "VEVENT" and c.get("RECURRENCE-ID") is not None)]
    if event.get("reminderChanged"):
        _set_reminder(master, event.get("reminder", -1), event.get("title"))
    _touch(master)


def apply_occurrence(cal, event, rid, tz):
    import icalendar
    master = _master(cal)
    override = next((ev for ev in cal.walk("VEVENT") if _same_rid(ev, rid)), None)
    if override is None:
        if master is None:
            raise Failure("parse", "The event has no main entry")
        override = icalendar.Event()
        for key, value in master.items():
            if key not in ("RRULE", "RDATE", "EXDATE", "RECURRENCE-ID", "DTSTART", "DTEND", "DURATION"):
                override[key] = copy.deepcopy(value)
        for sub in master.subcomponents:
            override.add_component(copy.deepcopy(sub))
        override.add("RECURRENCE-ID", rid_value(rid, master.get("DTSTART").dt, tz))
        cal.add_component(override)
    _set_text(override, event)
    _set_times(override, event, tz)
    if event.get("reminderChanged"):
        _set_reminder(override, event.get("reminder", -1), event.get("title"))
    _touch(override)


def exclude_occurrence(cal, rid, tz):
    master = _master(cal)
    cal.subcomponents = [c for c in cal.subcomponents if not (c.name == "VEVENT" and _same_rid(c, rid))]
    if master is not None:
        master.add("EXDATE", rid_value(rid, master.get("DTSTART").dt, tz))
        _touch(master)
    return master is not None or any(c.name == "VEVENT" for c in cal.subcomponents)


def _find_account(req):
    account = next((a for a in req.get("accounts", []) if a["id"] == req["account"]), None)
    if account is None:
        raise Failure("notFound", "Unknown account")
    if account.get("kind", "caldav") != "caldav":
        raise Failure("readOnly", "Subscriptions are read-only")
    if not account.get("password"):
        raise Failure("noPassword", "No password saved for this account")
    return account, Dav(account.get("username", ""), account.get("password", ""))


def _cached_object(req):
    store = read_json(os.path.join(req["stateDir"], "objects.json"), {"calendars": {}})
    cal = store["calendars"].get(calendar_id(req["account"], req["calendar"]), {})
    obj = cal.get("objects", {}).get(req["href"])
    if obj is None:
        raise Failure("conflict", "The event changed on the server")
    return obj


def _put(dav, href, cal, etag):
    headers = {"Content-Type": "text/calendar; charset=utf-8"}
    if etag:
        headers["If-Match"] = etag
    else:
        headers["If-None-Match"] = "*"
    cal.add_missing_timezones()
    status, _, data, _ = dav.request("PUT", href, cal.to_ical(), headers=headers)
    _check_write(status, data, "PUT")


def _check_write(status, data, method):
    if status == 412:
        raise Failure("conflict", "The event changed on the server")
    if status == 403:
        raise Failure("readOnly", "The server doesn't allow changes to this calendar")
    if status >= 400:
        raise Failure("server", f"{method}: HTTP {status} {data[:200].decode('utf-8', 'replace')}")


def _resync(req, result):
    req = dict(req, only={"account": req["account"], "calendar": req["calendar"]})
    sync = run_sync(req)
    result["errors"] = sync["errors"]
    return result


def run_save(req):
    import icalendar
    _, dav = _find_account(req)
    tz = local_zone()
    event = req["event"]
    if not req.get("href"):
        cal, uid = build_new(event, tz)
        href = req["calendar"].rstrip("/") + "/" + uid + ".ics"
        _put(dav, href, cal, None)
        return _resync(req, {"ok": True, "href": href})
    obj = _cached_object(req)
    cal = icalendar.Calendar.from_ical(obj["ics"])
    if req.get("scope") == "occurrence" and req.get("rid"):
        apply_occurrence(cal, event, req["rid"], tz)
    else:
        apply_series(cal, event, tz)
    _put(dav, req["href"], cal, req.get("etag") or obj.get("etag"))
    return _resync(req, {"ok": True, "href": req["href"]})


def run_delete(req):
    import icalendar
    _, dav = _find_account(req)
    etag = req.get("etag")
    if req.get("scope") == "occurrence" and req.get("rid"):
        obj = _cached_object(req)
        cal = icalendar.Calendar.from_ical(obj["ics"])
        if exclude_occurrence(cal, req["rid"], local_zone()):
            _put(dav, req["href"], cal, etag or obj.get("etag"))
            return _resync(req, {"ok": True})
    headers = {"If-Match": etag} if etag else {}
    status, _, data, _ = dav.request("DELETE", req["href"], headers=headers)
    if status != 404:
        _check_write(status, data, "DELETE")
    return _resync(req, {"ok": True})


def run_discover(req):
    url = normalize_url(req.get("url"))
    if not url:
        raise Failure("notFound", "No address")
    if req.get("kind") == "ics":
        return {"ok": True, "calendars": discover_feed(Dav(), url)}
    if not req.get("password"):
        raise Failure("noPassword", "No password saved for this account")
    return {"ok": True, "calendars": discover_caldav(Dav(req.get("username", ""), req["password"]), url)}


# --- Files ------------------------------------------------------------------

def read_json(path, default):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def write_json(path, data):
    """Atomically (a temp file renamed over it), mode 600: events are private."""
    directory = os.path.dirname(path)
    os.makedirs(directory, mode=0o700, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".tmp-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(data, f, separators=(",", ":"))
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


COMMANDS = {"discover": run_discover, "sync": run_sync, "save": run_save, "delete": run_delete}


def main(argv):
    if len(argv) != 2 or argv[1] not in COMMANDS:
        print(f"usage: {argv[0]} {'|'.join(COMMANDS)} < request.json", file=sys.stderr)
        return 2
    try:
        req = json.load(sys.stdin)
        result = COMMANDS[argv[1]](req)
    except Failure as err:
        result = {"ok": False, "code": err.code, "message": err.message}
    except (ValueError, KeyError) as err:
        result = {"ok": False, "code": "parse", "message": f"{type(err).__name__}: {err}"}
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
