.pragma library

// Parsing and formatting for `tailscale status --json`. No QML, no process
// launching - the panel does that. Everything here is a pure function over the
// decoded JSON so scripts/test-tailscale.js can exercise it under node.
//
// The shape is validated rather than trusted. This is local output, not
// network data, but it comes from a binary that updates independently of this
// shell: a field that changes type across a tailscale release should make a
// widget go blank, not take the whole bar down with a TypeError.

// ------------------------------------------------------------- validation

function _str(v, max) {
  if (typeof v !== "string") return "";
  var limit = max || 128;
  var s = v.replace(/[\u0000-\u001f\u007f]/g, "").trim();
  return s.length > limit ? s.slice(0, limit) : s;
}

function _bool(v) { return v === true; }

function _ips(v) {
  if (!Array.isArray(v)) return [];
  var out = [];
  for (var i = 0; i < v.length; i++) {
    var s = _str(v[i], 64);
    if (s !== "") out.push(s);
  }
  return out;
}

// The first IPv4, which is what anyone actually wants to copy or ssh to.
function ipv4Of(ips) {
  for (var i = 0; i < ips.length; i++) {
    if (ips[i].indexOf(":") === -1) return ips[i];
  }
  return ips.length > 0 ? ips[0] : "";
}

// "apollo.tailnet.ts.net." -> "apollo". The trailing dot is part of the DNS
// name and never wanted on screen.
function shortName(dnsName, hostName) {
  var d = _str(dnsName, 256);
  if (d !== "") {
    var trimmed = d.replace(/\.$/, "");
    var dot = trimmed.indexOf(".");
    return dot > 0 ? trimmed.slice(0, dot) : trimmed;
  }
  return _str(hostName, 64);
}

// ------------------------------------------------------------------ state

// BackendState values that matter to the UI. Anything unrecognised is treated
// as "unknown" rather than assumed to be running.
var STATES = ["NoState", "NeedsLogin", "NeedsMachineAuth", "Stopped", "Starting", "Running"];

function emptyStatus() {
  return {
    ok: false,
    state: "unknown",
    running: false,
    needsLogin: false,
    self: { name: "", ip: "", os: "", online: false, exitNode: false },
    peers: [],
    tailnet: "",
    exitNodeName: "",
    authUrl: ""
  };
}

function _node(raw) {
  var o = raw || {};
  var ips = _ips(o.TailscaleIPs);
  return {
    name: shortName(o.DNSName, o.HostName),
    dnsName: _str(o.DNSName, 256).replace(/\.$/, ""),
    ip: ipv4Of(ips),
    ips: ips,
    os: _str(o.OS, 24),
    online: _bool(o.Online),
    // The node is currently acting as this machine's exit node.
    exitNode: _bool(o.ExitNode),
    // The node is *available* to be chosen as one.
    offersExit: _bool(o.ExitNodeOption),
    lastSeen: _str(o.LastSeen, 40),
    user: typeof o.UserID === "number" ? o.UserID : -1
  };
}

function parseStatus(text) {
  var raw;
  try { raw = JSON.parse(text); } catch (e) { return emptyStatus(); }
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return emptyStatus();

  var out = emptyStatus();
  var state = _str(raw.BackendState, 32);
  out.state = STATES.indexOf(state) !== -1 ? state : "unknown";
  out.running = out.state === "Running";
  out.needsLogin = out.state === "NeedsLogin" || out.state === "NeedsMachineAuth";
  out.authUrl = _str(raw.AuthURL, 512);

  out.self = _node(raw.Self);
  if (out.self.ip === "") out.self.ip = ipv4Of(_ips(raw.TailscaleIPs));

  out.tailnet = raw.CurrentTailnet ? _str(raw.CurrentTailnet.Name, 128) : "";

  var peers = [];
  var peerMap = raw.Peer;
  if (peerMap && typeof peerMap === "object") {
    for (var key in peerMap) {
      var n = _node(peerMap[key]);
      if (n.name === "" && n.ip === "") continue;   // nothing to show
      peers.push(n);
      if (n.exitNode) out.exitNodeName = n.name;
    }
  }
  out.peers = sortPeers(peers);

  // A status with a recognised state is usable even with no peers; a solo
  // tailnet is a real situation, not a parse failure.
  out.ok = out.state !== "unknown";
  return out;
}

// Online first, then alphabetically. Sorting by name alone buries the machines
// you can actually reach under the ones you cannot.
function sortPeers(peers) {
  return peers.slice().sort(function (a, b) {
    if (a.online !== b.online) return a.online ? -1 : 1;
    return a.name.localeCompare(b.name);
  });
}

function exitNodeCandidates(status) {
  return status.peers.filter(function (p) { return p.offersExit; });
}

function onlineCount(status) {
  var n = 0;
  for (var i = 0; i < status.peers.length; i++) if (status.peers[i].online) n++;
  return n;
}

// ------------------------------------------------------------- formatting

// "3m", "2h", "4d" - a compact age for a last-seen timestamp. Returns "" when
// the timestamp is missing or unparseable, which renders as nothing rather
// than as "NaN" or a fake zero.
function relativeAge(iso, nowMs) {
  if (!iso) return "";
  var t = Date.parse(iso);
  if (isNaN(t)) return "";
  var now = nowMs === undefined ? Date.now() : nowMs;
  var secs = Math.floor((now - t) / 1000);
  if (secs < 0) return "";
  if (secs < 60) return secs + "s";
  var mins = Math.floor(secs / 60);
  if (mins < 60) return mins + "m";
  var hours = Math.floor(mins / 60);
  if (hours < 24) return hours + "h";
  return Math.floor(hours / 24) + "d";
}

var OS_LABEL = {
  linux: "Linux", macOS: "macOS", windows: "Windows",
  iOS: "iOS", android: "Android", freebsd: "FreeBSD", openbsd: "OpenBSD"
};
function osLabel(os) { return OS_LABEL[os] || (os || ""); }

function statusText(status) {
  if (!status.ok) return "TAILSCALE UNAVAILABLE";
  if (status.needsLogin) return "SIGN IN REQUIRED";
  if (status.state === "Stopped") return "DISCONNECTED";
  if (status.state === "Starting") return "CONNECTING\u2026";
  if (status.running) {
    if (status.exitNodeName !== "") return "EXIT NODE: " + status.exitNodeName.toUpperCase();
    return "CONNECTED";
  }
  return "UNKNOWN STATE";
}

// ------------------------------------------------------------- safety net
//
// Values that get passed to `tailscale set --exit-node=<x>`. They go in as an
// argv entry rather than being pasted into a command string, but validating
// them as well means a peer name that is somehow hostile cannot become a
// different flag - a leading dash would be read as one.
function validNodeTarget(s) {
  return typeof s === "string" && /^[A-Za-z0-9][A-Za-z0-9._:-]{0,253}$/.test(s);
}
