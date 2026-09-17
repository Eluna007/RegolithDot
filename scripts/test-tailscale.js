#!/usr/bin/env node
// Tests for the Tailscale widget's parsing layer.
//
// `tailscale status --json` comes from a binary that updates independently of
// this shell. A field that changes type across a release should make a widget
// go blank, not take the bar down with a TypeError - so every shape below is
// something a real or broken tailscale could plausibly emit.
"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");

const SRC = path.join(__dirname, "..", "config", "quickshell", "apollo", "panels", "tailscale");
const TMP = fs.mkdtempSync(path.join(os.tmpdir(), "apollo-ts-"));
process.on("exit", () => fs.rmSync(TMP, { recursive: true, force: true }));

let src = fs.readFileSync(path.join(SRC, "Tailscale.js"), "utf8").replace(/^\.pragma library\s*$/m, "");
const names = new Set((src.match(/^function (\w+)/gm) || []).map(s => s.slice(9)));
for (const decl of src.match(/^var [^;]+;/gm) || []) {
    for (const part of decl.slice(4, -1).split(",")) {
        const m = part.match(/^\s*(\w+)\s*=/);
        if (m) names.add(m[1]);
    }
}
src += `\nmodule.exports = {${[...names].join(",")}};\n`;
fs.writeFileSync(path.join(TMP, "Tailscale.js"), src);
const T = require(path.join(TMP, "Tailscale.js"));

let failures = 0;
function ok(label, cond, detail) {
    if (cond) console.log("  ok   " + label);
    else { console.log("  FAIL " + label + (detail ? ": " + detail : "")); failures++; }
}

function status(over) {
    return JSON.stringify(Object.assign({
        BackendState: "Running",
        TailscaleIPs: ["100.64.0.1"],
        CurrentTailnet: { Name: "example.ts.net" },
        Self: {
            DNSName: "apollo.example.ts.net.", HostName: "apollo", OS: "linux",
            TailscaleIPs: ["100.64.0.1", "fd7a::1"], Online: true
        },
        Peer: {}
    }, over));
}

console.log("states:");
for (const [state, running, login] of [
    ["Running", true, false], ["Stopped", false, false],
    ["NeedsLogin", false, true], ["NeedsMachineAuth", false, true],
    ["Starting", false, false], ["NoState", false, false]
]) {
    const s = T.parseStatus(status({ BackendState: state }));
    ok(`${state} parses`, s.ok && s.state === state && s.running === running && s.needsLogin === login,
       JSON.stringify([s.state, s.running, s.needsLogin]));
}
{
    // An unrecognised state must not be assumed to be running - that would show
    // "connected" for a tailscale that is not.
    const s = T.parseStatus(status({ BackendState: "SomethingNew" }));
    ok("an unknown state is not treated as running", s.state === "unknown" && !s.running);
    ok("and the widget knows it is unusable", !s.ok);
}

console.log("identity:");
{
    const s = T.parseStatus(status({}));
    ok("short name drops the tailnet suffix", s.self.name === "apollo", s.self.name);
    ok("and the trailing dot", s.self.dnsName === "apollo.example.ts.net", s.self.dnsName);
    ok("prefers IPv4 for display", s.self.ip === "100.64.0.1", s.self.ip);
    ok("keeps both addresses", s.self.ips.length === 2);
    ok("reads the tailnet", s.tailnet === "example.ts.net");
}
{
    // Older tailscale, or a node with no DNSName: fall back to HostName.
    const s = T.parseStatus(status({ Self: { HostName: "bare", OS: "linux", TailscaleIPs: ["100.64.0.9"] } }));
    ok("falls back to the hostname", s.self.name === "bare", s.self.name);
}
{
    // IPv6-only node: do not render an empty address.
    const s = T.parseStatus(status({ Self: { HostName: "v6", TailscaleIPs: ["fd7a::9"] } }));
    ok("an IPv6-only node still shows an address", s.self.ip === "fd7a::9", s.self.ip);
}

console.log("peers:");
{
    const s = T.parseStatus(status({ Peer: {
        a: { DNSName: "zeta.example.ts.net.", OS: "linux", TailscaleIPs: ["100.64.0.4"], Online: false },
        b: { DNSName: "alpha.example.ts.net.", OS: "macOS", TailscaleIPs: ["100.64.0.2"], Online: true },
        c: { DNSName: "beta.example.ts.net.", OS: "android", TailscaleIPs: ["100.64.0.3"], Online: true,
             ExitNodeOption: true }
    }}));
    ok("all peers parse", s.peers.length === 3);
    ok("online first, then alphabetical",
       s.peers.map(p => p.name).join(",") === "alpha,beta,zeta",
       s.peers.map(p => p.name + (p.online ? "+" : "-")).join(","));
    ok("exit-node candidates are found",
       T.exitNodeCandidates(s).map(p => p.name).join(",") === "beta");
    ok("online count", T.onlineCount(s) === 2);
    ok("os labels are readable", T.osLabel("macOS") === "macOS" && T.osLabel("linux") === "Linux");
}
{
    // An active exit node should be named in the status line.
    const s = T.parseStatus(status({ Peer: {
        a: { DNSName: "gateway.example.ts.net.", TailscaleIPs: ["100.64.0.7"], Online: true,
             ExitNodeOption: true, ExitNode: true }
    }}));
    ok("an active exit node is identified", s.exitNodeName === "gateway", s.exitNodeName);
    ok("and named in the status line",
       T.statusText(s) === "EXIT NODE: GATEWAY", T.statusText(s));
}
{
    const s = T.parseStatus(status({ Peer: { junk: { Online: true } } }));
    ok("a peer with no name and no address is skipped", s.peers.length === 0);
}
{
    // A solo tailnet is a real situation, not a parse failure.
    const s = T.parseStatus(status({ Peer: {} }));
    ok("no peers is still a valid status", s.ok && s.peers.length === 0);
}

console.log("malformed input never throws:");
for (const [label, body] of [
    ["not json", "tailscale: command not found"],
    ["empty", ""],
    ["a JSON array", "[1,2,3]"],
    ["null", "null"],
    ["a bare string", JSON.stringify("hello")],
    ["Peer as an array", status({ Peer: [] })],
    ["Peer as a string", status({ Peer: "nope" })],
    ["IPs as a string", status({ Self: { HostName: "x", TailscaleIPs: "100.64.0.1" } })],
    ["Online as a string", status({ Self: { HostName: "x", TailscaleIPs: ["100.64.0.1"], Online: "yes" } })],
    ["BackendState as a number", status({ BackendState: 7 })]
]) {
    let threw = false, s = null;
    try { s = T.parseStatus(body); } catch (e) { threw = true; }
    ok(`${label} is handled`, !threw && s !== null, threw ? "threw" : "");
}
{
    // "Online": "yes" is truthy in JS but is not a boolean - it must not be
    // read as online, or a dead peer shows as reachable.
    const s = T.parseStatus(status({ Self: { HostName: "x", TailscaleIPs: ["100.64.0.1"], Online: "yes" } }));
    ok("a non-boolean Online is not truthy", s.self.online === false);
}
{
    const dirty = "a" + String.fromCharCode(0) + "b" + String.fromCharCode(31) + "c";
    const s = T.parseStatus(status({ Self: { HostName: dirty, TailscaleIPs: ["100.64.0.1"] } }));
    ok("control characters are stripped from names", s.self.name === "abc", JSON.stringify(s.self.name));
}
{
    const long = "x".repeat(500);
    const s = T.parseStatus(status({ Self: { HostName: long, TailscaleIPs: ["100.64.0.1"] } }));
    ok("an absurd name is clamped", s.self.name.length <= 128, String(s.self.name.length));
}

console.log("relative age:");
const now = Date.parse("2026-01-01T12:00:00Z");
ok("seconds", T.relativeAge("2026-01-01T11:59:30Z", now) === "30s", T.relativeAge("2026-01-01T11:59:30Z", now));
ok("minutes", T.relativeAge("2026-01-01T11:30:00Z", now) === "30m", T.relativeAge("2026-01-01T11:30:00Z", now));
ok("hours", T.relativeAge("2026-01-01T09:00:00Z", now) === "3h", T.relativeAge("2026-01-01T09:00:00Z", now));
ok("days", T.relativeAge("2025-12-28T12:00:00Z", now) === "4d", T.relativeAge("2025-12-28T12:00:00Z", now));
ok("missing timestamp is blank, not zero", T.relativeAge("", now) === "");
ok("unparseable timestamp is blank", T.relativeAge("whenever", now) === "");
ok("a future timestamp is blank, not negative", T.relativeAge("2026-01-02T12:00:00Z", now) === "");

console.log("node targets - these become a tailscale set argument:");
ok("accepts a short name", T.validNodeTarget("gateway"));
ok("accepts a dns name", T.validNodeTarget("gateway.example.ts.net"));
ok("accepts an IPv4", T.validNodeTarget("100.64.0.7"));
ok("accepts an IPv6", T.validNodeTarget("fd7a::1"));
ok("rejects a leading dash (would read as a flag)", !T.validNodeTarget("--reset"));
ok("rejects a space", !T.validNodeTarget("a b"));
ok("rejects a semicolon", !T.validNodeTarget("a;reboot"));
ok("rejects a slash", !T.validNodeTarget("../x"));
ok("rejects empty", !T.validNodeTarget(""));
ok("rejects a non-string", !T.validNodeTarget(null));

if (failures > 0) {
    console.log(`\n${failures} failure(s)`);
    process.exit(1);
}
console.log("\nok - tailscale: states, peers, and every malformed shape handled");
