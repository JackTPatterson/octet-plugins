// What the Vercel scripts print, worked out from Vercel's JSON. Runs under
// osascript (JavaScript for Automation) on a Mac and Node elsewhere:
//   vercel.js MODE ARGS…
// Every mode returns text for Octet; see each one below.

function read(path) {
  if (typeof require === "function") return require("fs").readFileSync(path, "utf8");
  ObjC.import("Foundation");
  return $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null).js;
}

function parse(text) {
  try { return JSON.parse(text); } catch (e) { return null; }
}

var WORDS = { READY: "Ready", ERROR: "Failed", BUILDING: "Building", QUEUED: "Queued",
              INITIALIZING: "Starting", CANCELED: "Canceled", DELETED: "Deleted" };

function state(d) { return String(d.readyState || d.state || "").toUpperCase(); }
function word(d) { var s = state(d); return WORDS[s] || (s ? s.charAt(0) + s.slice(1).toLowerCase() : "Unknown"); }
function building(d) { var s = state(d); return s === "BUILDING" || s === "QUEUED" || s === "INITIALIZING"; }
function tone(d) {
  var s = state(d);
  return s === "READY" ? "success" : s === "ERROR" ? "danger" : s === "CANCELED" || s === "DELETED" ? "muted" : "normal";
}
function meta(d) { return d.meta || {}; }
function ref(d) {
  var m = meta(d);
  return m.githubCommitRef || m.gitlabCommitRef || m.bitbucketCommitRef || m.branchAlias || (d.gitSource && d.gitSource.ref) || "";
}
function message(d) {
  var m = meta(d);
  return String(m.githubCommitMessage || m.gitlabCommitMessage || m.bitbucketCommitMessage || "").split("\n")[0];
}
function created(d) { return d.created || d.createdAt || 0; }
function age(d) {
  var s = Math.max(0, (Date.now() - created(d)) / 1000);
  if (s < 60) return "just now";
  if (s < 3600) return Math.floor(s / 60) + "m ago";
  if (s < 86400) return Math.floor(s / 3600) + "h ago";
  return Math.floor(s / 86400) + "d ago";
}
function site(d) { return d.url ? "https://" + d.url : ""; }
function production(d) { return d.target === "production"; }
function id(d) { return d.uid || d.id; }
function clip(text, n) { text = String(text || ""); return text.length > n ? text.slice(0, n - 1) + "…" : text; }

// The project's dashboard, from a deployment's inspector link
// (https://vercel.com/<scope>/<project>/<deployment>).
function dashboard(deployments) {
  for (var i = 0; i < deployments.length; i++) {
    var link = deployments[i].inspectorUrl;
    if (link) return link.replace(/\/[^\/]+\/?$/, "");
  }
  return "https://vercel.com/dashboard";
}

// The deployment serving production now: the project's own idea of it,
// which follows rollbacks, else the newest ready production one.
function current(project, deployments) {
  var target = project && project.targets && project.targets.production;
  if (target && target.id) {
    for (var i = 0; i < deployments.length; i++) if (id(deployments[i]) === target.id) return deployments[i];
    return target;
  }
  for (var j = 0; j < deployments.length; j++) {
    if (production(deployments[j]) && state(deployments[j]) === "READY") return deployments[j];
  }
  return null;
}

// The production branch, which a branch's deployments are judged against.
function productionBranch(project) {
  return (project && project.link && project.link.productionBranch) || "main";
}

// The newest deployment of the branch the folder is on.
function ofBranch(deployments, branch) {
  if (!branch) return null;
  for (var i = 0; i < deployments.length; i++) if (ref(deployments[i]) === branch) return deployments[i];
  return null;
}

function load(projectPath, deploymentsPath) {
  var project = parse(read(projectPath)) || {};
  var list = parse(read(deploymentsPath)) || {};
  return { project: project, deployments: list.deployments || [] };
}

// A row's id says which deployment, where it is and what it's for, so
// an action needs no lookup: `<uid>|<host>|<target>`.
function item(d) { return [id(d), d.url || "", production(d) ? "production" : "preview"].join("|"); }

var modes = {
  // The project in .vercel/repo.json (a monorepo) whose directory holds
  // the folder: `id<TAB>orgId<TAB>directory`.
  "repo-project": function (a) {
    var repo = parse(a[0]) || {}, relative = a[1] || "", best = null;
    (repo.projects || []).forEach(function (p) {
      var dir = String(p.directory || ".").replace(/^\.\/?/, "").replace(/\/$/, "");
      var holds = dir === "" || relative === dir || relative.indexOf(dir + "/") === 0;
      if (holds && (!best || dir.length > best.dir.length)) best = { p: p, dir: dir };
    });
    return best ? [best.p.id, best.p.orgId || repo.orgId || "", best.dir].join("\t") : "";
  },

  // The status bar chip: the branch's newest deployment, else what's in
  // production. Click a ready one to open it, anything else for its logs.
  chip: function (a) {
    var data = load(a[0], a[1]), branch = a[2];
    var live = current(data.project, data.deployments);
    var mine = branch !== productionBranch(data.project) ? ofBranch(data.deployments, branch) : null;
    var d = mine || live;
    if (!d) return "Vercel\ntone: muted\nhelp: No deployments yet\nurl: " + dashboard(data.deployments);
    var what = production(d) ? "Production" : "Preview";
    var lines = [word(d) + " · " + age(d), "tone: " + tone(d)];
    var help = [what + (ref(d) ? " of " + ref(d) : "") + ": " + word(d) + ", " + age(d)];
    if (message(d)) help.push(clip(message(d), 90));
    if (d.url) help.push(d.url);
    if (live && mine) help.push("Production: " + word(live) + ", " + age(live));
    help.push(state(d) === "READY" ? "Click to open it" : "Click for its build logs");
    lines.push("help: " + help.join("\\n"));
    var link = state(d) === "READY" && d.url ? site(d) : (d.inspectorUrl || dashboard(data.deployments));
    lines.push("url: " + link);
    return lines.join("\n");
  },

  // The panel: the project, what's in production, the branch's newest
  // deployment, and the rest of the recent ones, each with what can be
  // done to it.
  panel: function (a) {
    var data = load(a[0], a[1]), branch = a[2], deployments = data.deployments, project = data.project;
    var live = current(project, deployments);
    var mine = ofBranch(deployments, branch);
    var rows = [];
    var domains = (project.targets && project.targets.production && project.targets.production.alias) || [];
    var domain = domains.filter(function (h) { return !/\.vercel\.app$/.test(h); })[0] || domains[0];

    rows.push({ id: "project", title: project.name || "Project",
                detail: "Dashboard" + (project.framework ? " · " + project.framework : "")
                        + (project.link && project.link.repo ? " · " + project.link.repo : ""),
                tone: "muted", url: dashboard(deployments) });

    function actions(d, isLive) {
      var list = [{ id: "logs", title: "Build Logs", symbol: "doc.text" }];
      var s = state(d);
      if (s === "READY") list.push({ id: "runtime", title: "Runtime Logs", symbol: "waveform.path.ecg" });
      if (building(d)) list.push({ id: "cancel", title: "Cancel", symbol: "xmark", confirm: "Cancel this build?" });
      if (s === "READY" && !production(d)) {
        list.push({ id: "promote", title: "Promote", symbol: "arrow.up.circle",
                    confirm: "Promote this preview to production? It's built again with production's settings." });
      }
      if (s === "READY" && production(d) && !isLive) {
        list.push({ id: "rollback", title: "Roll Back", symbol: "arrow.uturn.backward",
                    confirm: "Roll production back to this deployment? It serves your domains at once." });
      }
      if (!building(d)) {
        list.push({ id: "redeploy", title: "Redeploy", symbol: "arrow.clockwise",
                    confirm: "Build this " + (production(d) ? "production" : "preview") + " deployment again?" });
      }
      return list;
    }

    function row(d, title, isLive) {
      var detail = [word(d), age(d)];
      if (ref(d) && title.indexOf(ref(d)) < 0) detail.push(ref(d));
      if (message(d)) detail.push(clip(message(d), 60));
      var r = { id: item(d), title: title, detail: detail.join(" · "), tone: tone(d), actions: actions(d, isLive) };
      var link = state(d) === "READY" ? site(d) : d.inspectorUrl;
      if (isLive && domain) link = "https://" + domain;
      if (link) r.url = link;
      return r;
    }

    var shown = {};
    if (live) {
      rows.push(row(live, "Production" + (domain ? " · " + domain : ""), true));
      shown[id(live)] = true;
    }
    if (mine && !shown[id(mine)]) {
      rows.push(row(mine, (production(mine) ? "Production build · " : "Preview · ") + branch, false));
      shown[id(mine)] = true;
    }
    deployments.forEach(function (d) {
      if (shown[id(d)] || rows.length >= 12) return;
      shown[id(d)] = true;
      rows.push(row(d, (production(d) ? "Production" : "Preview") + (ref(d) ? " · " + ref(d) : ""), false));
    });

    var front = mine || live;
    var badge = front ? word(front) : "";
    var panelTone = front ? tone(front) : "muted";
    if (front && state(front) === "READY") panelTone = "normal";
    var actions = [
      { id: "deploy", title: "Deploy Preview", symbol: "paperplane" },
      { id: "deploy-prod", title: "Deploy to Production", symbol: "bolt",
        confirm: "Deploy this folder to production now?" },
      { id: "env", title: "Pull Environment", symbol: "arrow.down.doc" },
      { id: "dev", title: "Run vercel dev", symbol: "play" }
    ];
    return JSON.stringify({ badge: badge, tone: panelTone, message: "No deployments yet. Deploy this folder to see it here.",
                            rows: rows, actions: actions });
  },

  // Deployment addresses for `vercel inspect`, `logs`, `promote` and the
  // like: `host<TAB>label<TAB>detail`.
  "complete-deployments": function (a) {
    var data = load(a[0], a[1]);
    return data.deployments.filter(function (d) { return d.url; }).map(function (d) {
      return [d.url, (production(d) ? "Production" : "Preview") + (ref(d) ? " · " + ref(d) : "") + " · " + word(d),
              age(d) + (message(d) ? " · " + clip(message(d), 50) : "")].join("\t");
    }).join("\n");
  },

  // Teams for `vercel switch`: `slug<TAB>name`.
  "complete-teams": function (a) {
    var teams = (parse(a[0]) || {}).teams || [];
    return teams.map(function (t) { return [t.slug, t.name || t.slug].join("\t"); }).join("\n");
  },

  // Why Vercel said no, from its error body.
  error: function (a) {
    var body = parse(a[0]) || {}, e = body.error || {};
    return e.message || a[1] || "Vercel didn't accept that";
  },

  // The body that builds a deployment again, as `vercel redeploy` sends.
  "redeploy-body": function (a) {
    var d = parse(a[0]) || {};
    var body = { name: d.name, deploymentId: d.id || d.uid, meta: { action: "redeploy" } };
    if (d.target === "production") body.target = "production";
    return JSON.stringify(body);
  }
};

function main(a) {
  var mode = modes[a[0]];
  return mode ? mode(a.slice(1)) : "";
}

// osascript calls run(argv) and prints what it returns; Node runs the file.
function run(argv) { return main(argv); }
if (typeof process !== "undefined" && process.argv && typeof require === "function") {
  var out = main(process.argv.slice(2));
  if (out) console.log(out);
}
