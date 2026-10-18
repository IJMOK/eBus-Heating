// eBus-Heating failsafe for a Shelly 1 Gen4 across the boiler's room-stat terminals.
// Docs: docs/04-shelly-failsafe.md
//
// Modes (published retained on CFG.modeTopic, posted to the HA webhook whose URL is
// in KVS CFG.webhookKey, and kept in KVS "fs_mode"):
//   ha     HA heartbeat is fresh: do nothing, HA switches the relay.
//   local  Heartbeat stale: thermostat on the BLU H&T (day/night bands).
//   timed  Heartbeat and BLU stale: fixed schedule.
//   warm   No clock either: relay ON (fail warm).
//
// The heartbeat is any changing value written to KVS key CFG.hbKey (HA writes the
// time every minute while it is in live control). Staleness is measured with the
// Shelly's uptime, so it works without a clock.

let CFG = {
  hbKey: "hb",
  hbStaleMin: 15,                 // no heartbeat change for this long -> failsafe
  tempSensor: "bthomesensor:203", // BLU H&T temperature component (see Components)
  tempStaleMin: 30,               // no new BLU reading for this long -> timed
  dayOn: 19.5, dayOff: 20.5,      // local thermostat during schedule periods
  nightOn: 15.5, nightOff: 16.5,  // and outside them (setback)
  // Fixed schedule in minutes after midnight, local time: [start, end)
  weekday: [[300, 420], [960, 1350]], // 05:00-07:00, 16:00-22:30
  weekend: [[540, 1350]],             // 09:00-22:30
  modeTopic: "heating/failsafe/mode",
  webhookKey: "fs_webhook",       // KVS key with the HA webhook URL (optional; works without Node-RED)
  checkSec: 60,
};

let lastHb = null;
let hbChangedAt = 0;      // uptime (s) when the heartbeat last changed
let lastTempTs = null;
let tempChangedAt = -1e9; // uptime (s) when a new BLU reading last arrived
let mode = "";
let want = null;          // relay state the failsafe wants
let webhookUrl = null;
let posted = true;        // false until the current mode has reached HA

function sys() { return Shelly.getComponentStatus("sys"); }

// Local minute of day and weekend flag, or null if the clock isn't set
function localTime() {
  let s = sys();
  if (!s.unixtime) return null;
  let t = s.unixtime + (s.utc_offset || 0);
  let dow = (Math.floor(t / 86400) + 4) % 7; // 1970-01-01 was a Thursday
  return { min: Math.floor((t % 86400) / 60), weekend: dow === 0 || dow === 6 };
}

function inSchedule(lt) {
  let p = lt.weekend ? CFG.weekend : CFG.weekday;
  for (let i = 0; i < p.length; i++) {
    if (lt.min >= p[i][0] && lt.min < p[i][1]) return true;
  }
  return false;
}

function report(m) {
  if (m === mode) return;
  mode = m;
  print("failsafe mode: " + m);
  Shelly.call("KVS.Set", { key: "fs_mode", value: m });
  if (MQTT.isConnected()) MQTT.publish(CFG.modeTopic, m, 1, true);
  posted = false;
  postMode();
}

// Post the mode straight to HA; retried every check until it gets through.
function postMode() {
  if (posted || !webhookUrl || mode === "") return;
  Shelly.call("HTTP.POST", { url: webhookUrl, body: JSON.stringify({ mode: mode }),
                            content_type: "application/json", timeout: 10 }, function (res, err) {
    if (err === 0 && res && res.code >= 200 && res.code < 300) posted = true;
  });
}

function decide() {
  let up = sys().uptime;
  if (up - hbChangedAt < CFG.hbStaleMin * 60) {
    want = null;
    report("ha");
    return;
  }
  let lt = localTime();
  let t = Shelly.getComponentStatus(CFG.tempSensor);
  let tempOk = t !== null && typeof t.value === "number" && up - tempChangedAt < CFG.tempStaleMin * 60;
  let out = Shelly.getComponentStatus("switch:0").output;
  if (tempOk) {
    let day = lt === null ? true : inSchedule(lt);
    let on = day ? CFG.dayOn : CFG.nightOn;
    let off = day ? CFG.dayOff : CFG.nightOff;
    if (t.value < on) want = true;
    else if (t.value > off) want = false;
    else if (want === null) want = out;
    report("local");
  } else if (lt !== null) {
    want = inSchedule(lt);
    report("timed");
  } else {
    want = true;
    report("warm");
  }
  if (out !== want) Shelly.call("Switch.Set", { id: 0, on: want });
}

function check() {
  Shelly.call("KVS.Get", { key: CFG.hbKey }, function (res, err) {
    let up = sys().uptime;
    let v = (err === 0 && res) ? res.value : null;
    if (v !== null && v !== lastHb) { lastHb = v; hbChangedAt = up; }
    let t = Shelly.getComponentStatus(CFG.tempSensor);
    if (t !== null && t.last_updated_ts && t.last_updated_ts !== lastTempTs) {
      lastTempTs = t.last_updated_ts;
      tempChangedAt = up;
    }
    decide();
    postMode();
  });
}

// A mode change while MQTT is down is never published: re-send it on every (re)connect.
MQTT.setConnectHandler(function () {
  if (mode !== "") MQTT.publish(CFG.modeTopic, mode, 1, true);
});

Shelly.call("KVS.Get", { key: CFG.webhookKey }, function (res, err) {
  if (err === 0 && res && res.value) { webhookUrl = res.value; postMode(); }
});

// After boot, give HA one full stale period to send a heartbeat before taking over.
hbChangedAt = sys().uptime;
Timer.set(CFG.checkSec * 1000, true, check);
check();
