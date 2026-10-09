/* Attrition Tree Explorer: node menu (right-click / long-press / tap),
   view controls, PNG export, first-run tip. No numbers are computed here. */
(function () {
  "use strict";
  var state = { sel: "1", openedAt: 0 };
  var ACTIONS = [
    { key: "importance", label: "Variable importance", icon: "fa-chart-bar", hint: "Rank all predictors at this node" },
    { key: "auto", label: "Auto-split", icon: "fa-bolt", hint: "Apply the best eligible split" },
    { key: "custom", label: "Custom split\u2026", icon: "fa-sliders", hint: "Pick a variable and cut" },
    { key: "grow", label: "Grow this branch", icon: "fa-sitemap", hint: "Keep splitting under the rules" },
    { key: "prune", label: "Remove split", icon: "fa-scissors", hint: "Collapse everything below", needsSplit: true }
  ];

  function coarse() {
    return (window.matchMedia && window.matchMedia("(pointer: coarse)").matches) || window.innerWidth < 768;
  }
  function net() {
    var el = document.getElementById("graphtree");
    return el && el.chart ? el.chart : null;
  }
  function send(name, val) {
    if (window.Shiny && Shiny.setInputValue) Shiny.setInputValue(name, val, { priority: "event" });
  }
  function nonce() { return Date.now() + Math.random(); }

  var menu, backdrop;
  function ensureMenu() {
    if (menu) return;
    backdrop = document.createElement("div");
    backdrop.id = "menu-backdrop";
    backdrop.addEventListener("click", function () { if (Date.now() - state.openedAt > 450) hide(); });
    menu = document.createElement("div");
    menu.id = "node-menu";
    menu.setAttribute("role", "menu");
    menu.addEventListener("contextmenu", function (e) { e.preventDefault(); });
    document.body.appendChild(backdrop);
    document.body.appendChild(menu);
  }
  function hide() {
    if (!menu) return;
    menu.style.display = "none";
    menu.classList.remove("sheet");
    backdrop.style.display = "none";
  }
  function escapeHtml(s) {
    return String(s == null ? "" : s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }
  function show(network, id, x, y, sheet) {
    ensureMenu();
    // Touch sheets get a short guard against the ghost click that follows a tap.
    state.openedAt = sheet ? Date.now() : 0;
    var d = (network && network.body.data.nodes.get(id)) || {};
    var html = '<div class="menu-head">' +
      (sheet ? '<div class="grabber"></div>' : "") +
      '<div class="menu-title">' + escapeHtml(d.menuTitle || ("Node " + id)) + "</div>" +
      '<div class="menu-sub">' + escapeHtml(d.menuSub || "") + "</div>" +
      (d.menuLift ? '<div class="menu-sub">' + escapeHtml(d.menuLift) + "</div>" : "") +
      (d.menuFlag ? '<div class="menu-flag ' + (d.tooSmall ? "small" : "cleared") + '">' + escapeHtml(d.menuFlag) +
        (d.menuFlagWhy ? " \u00b7 " + escapeHtml(d.menuFlagWhy) : "") + "</div>" : "") +
      (d.menuImpact ? '<div class="menu-impact">' + escapeHtml(d.menuImpact) + "</div>" : "") + "</div>";
    ACTIONS.forEach(function (a) {
      var disabled = a.needsSplit && d.isLeaf;
      html += '<button type="button" role="menuitem" class="item" data-action="' + a.key + '"' +
        (disabled ? " disabled" : "") + '><i class="fas ' + a.icon + '" aria-hidden="true"></i>' +
        '<span><span class="lbl">' + a.label + '</span><span class="hint">' + a.hint + "</span></span></button>";
    });
    if (sheet) html += '<button type="button" class="item cancel" data-action="cancel"><span class="lbl">Cancel</span></button>';
    menu.innerHTML = html;
    Array.prototype.forEach.call(menu.querySelectorAll("button.item"), function (b) {
      b.addEventListener("click", function () {
        // Ignore the ghost click a touch tap fires right after the sheet opens.
        if (Date.now() - state.openedAt < 450) return;
        var act = b.getAttribute("data-action");
        hide();
        if (act !== "cancel") send("node_action", { id: String(id), action: act, nonce: nonce() });
      });
    });
    if (sheet) {
      menu.classList.add("sheet");
      menu.style.left = "";
      menu.style.top = "";
      backdrop.style.display = "block";
      menu.style.display = "block";
    } else {
      menu.classList.remove("sheet");
      menu.style.display = "block";
      var w = menu.offsetWidth, h = menu.offsetHeight;
      var left = Math.min(x, window.innerWidth - w - 8);
      var top = Math.min(y, window.innerHeight - h - 8);
      menu.style.left = Math.max(8, left) + "px";
      menu.style.top = Math.max(8, top) + "px";
    }
    var first = menu.querySelector("button.item:not([disabled])");
    if (first) first.focus({ preventScroll: true });
  }
  function select(network, id) {
    state.sel = String(id);
    try { network.selectNodes([id]); } catch (e) { /* node may be gone */ }
    send("tree_click", { id: String(id), nonce: nonce() });
  }

  window.HRTree = {
    onClick: function (network, p) {
      hide();
      if (p.nodes && p.nodes.length) {
        var id = p.nodes[0];
        select(network, id);
        if (coarse()) show(network, id, 0, 0, true);
      } else {
        try { network.selectNodes([state.sel]); } catch (e) { /* ignore */ }
      }
    },
    onContext: function (network, p) {
      if (p.event && p.event.preventDefault) p.event.preventDefault();
      var id = network.getNodeAt(p.pointer.DOM);
      if (id === undefined || id === null) return;
      select(network, id);
      var r = network.body.container.getBoundingClientRect();
      show(network, id, r.left + p.pointer.DOM.x + 4, r.top + p.pointer.DOM.y + 4, coarse());
    },
    onRelease: function () {
      // After a long-press the finger lifts with the sheet already open: restart
      // the ghost-click guard from the release.
      if (menu && menu.classList.contains("sheet") && menu.style.display === "block") state.openedAt = Date.now();
    },
    onHold: function (network, p) {
      if (p.nodes && p.nodes.length) {
        var id = p.nodes[0];
        select(network, id);
        show(network, id, 0, 0, true);
      }
    },
    ready: function (network, sel) {
      state.sel = String(sel);
      try { network.selectNodes([sel]); } catch (e) { /* ignore */ }
      // Too-small groups get a dashed outline (per-node shapeProperties are set here).
      try {
        var ds = network.body.data.nodes, upd = [];
        ds.forEach(function (n) { if (n.tooSmall) upd.push({ id: n.id, shapeProperties: { borderDashes: [5, 4], borderRadius: 6 } }); });
        if (upd.length) ds.update(upd);
      } catch (e) { /* cosmetic only */ }
      try { network.fit({ maxZoomLevel: 1.35 }); } catch (e) { network.fit(); }
    },
    openMenuFor: function (id) {
      var n = net();
      if (!n) return;
      var pos = n.canvasToDOM(n.getPositions([id])[id] || { x: 0, y: 0 });
      var r = n.body.container.getBoundingClientRect();
      show(n, id, r.left + pos.x, r.top + pos.y, coarse());
    },
    zoom: function (f) {
      var n = net();
      if (n) n.moveTo({ scale: n.getScale() * f, animation: { duration: 200, easingFunction: "easeInOutQuad" } });
    },
    fit: function () {
      var n = net();
      if (n) n.fit({ maxZoomLevel: 1.35, animation: { duration: 250, easingFunction: "easeInOutQuad" } });
    },
    pickVar: function (v) { send("imp_pick", { variable: String(v), nonce: nonce() }); },
    jump: function (id) { send("jump_node", { id: String(id), nonce: nonce() }); },
    exportPng: function () {
      var el = document.getElementById("tree");
      var c = el && el.querySelector("canvas");
      if (!c) return;
      var dpr = window.devicePixelRatio || 1;
      var FONT = "px system-ui, -apple-system, Segoe UI, Roboto, sans-serif";
      var t = document.querySelector(".takeaway h2");
      var subs = Array.prototype.map.call(document.querySelectorAll(".takeaway p"), function (p) { return p.textContent.trim(); });
      var meas = document.createElement("canvas").getContext("2d");
      var maxW = c.width - 32 * dpr;
      function wrap(text, font) {
        meas.font = font;
        var words = String(text || "").split(/\s+/), lines = [], line = "";
        words.forEach(function (w) {
          var tryLine = line ? line + " " + w : w;
          if (line && meas.measureText(tryLine).width > maxW) { lines.push(line); line = w; } else { line = tryLine; }
        });
        if (line) lines.push(line);
        return lines;
      }
      var titleFont = "600 " + Math.round(20 * dpr) + FONT, subFont = Math.round(13 * dpr) + FONT;
      var titleLines = wrap(t ? t.textContent.trim() : "Attrition tree", titleFont);
      var subLines = [];
      subs.forEach(function (s) { subLines = subLines.concat(wrap(s, subFont)); });
      var tl = 26 * dpr, sl = 18 * dpr;
      var head = Math.round(16 * dpr + titleLines.length * tl + subLines.length * sl + 10 * dpr), foot = Math.round(28 * dpr);
      var out = document.createElement("canvas");
      out.width = c.width;
      out.height = c.height + head + foot;
      var ctx = out.getContext("2d");
      ctx.fillStyle = "#ffffff";
      ctx.fillRect(0, 0, out.width, out.height);
      var yy = 8 * dpr;
      ctx.fillStyle = "#1F2937";
      ctx.font = titleFont;
      titleLines.forEach(function (l) { yy += tl; ctx.fillText(l, 16 * dpr, yy); });
      ctx.fillStyle = "#4B5563";
      ctx.font = subFont;
      subLines.forEach(function (l) { yy += sl; ctx.fillText(l, 16 * dpr, yy); });
      ctx.drawImage(c, 0, head);
      ctx.fillStyle = "#6B7280";
      ctx.font = Math.round(11 * dpr) + FONT;
      ctx.fillText("Fictional IBM HR teaching data \u00b7 in-sample \u00b7 deeper splits exploratory", 16 * dpr, out.height - 10 * dpr);
      var a = document.createElement("a");
      a.download = "attrition_tree.png";
      a.href = out.toDataURL("image/png");
      document.body.appendChild(a);
      a.click();
      a.remove();
    },
    dismissTip: function () {
      try { localStorage.setItem("hrTreeTipDismissed", "1"); } catch (e) { /* private mode */ }
      var tip = document.getElementById("first-tip");
      if (tip) tip.classList.add("d-none");
    }
  };

  function initTip() {
    var tip = document.getElementById("first-tip");
    if (!tip) return;
    var dismissed = false;
    try { dismissed = localStorage.getItem("hrTreeTipDismissed") === "1"; } catch (e) { /* ignore */ }
    if (dismissed) return;
    var txt = tip.querySelector(".tip-text");
    if (txt) {
      txt.textContent = coarse()
        ? "Tap any box to see its numbers and actions. Pinch to zoom, drag to pan."
        : "Click a box to see its numbers. Right-click a box for variable importance, auto-split, custom split or prune. Scroll to zoom, drag to pan.";
    }
    tip.classList.remove("d-none");
  }

  document.addEventListener("keydown", function (e) { if (e.key === "Escape") hide(); });
  // bslib fires synthetic window resize events when cards re-render; only a real
  // viewport change should close the menu.
  var vp = { w: window.innerWidth, h: window.innerHeight };
  window.addEventListener("resize", function () {
    var w = window.innerWidth, h = window.innerHeight;
    if (Math.abs(w - vp.w) > 40 || Math.abs(h - vp.h) > 160) hide();
    vp = { w: w, h: h };
  });
  document.addEventListener("scroll", function () { if (menu && !menu.classList.contains("sheet")) hide(); }, true);
  document.addEventListener("click", function (e) {
    if (Date.now() - state.openedAt < 450) return;
    if (menu && menu.style.display === "block" && !menu.contains(e.target) && !e.target.closest("#tree")) hide();
  });
  document.addEventListener("DOMContentLoaded", initTip);

  $(document).on("shiny:connected", function () {
    Shiny.addCustomMessageHandler("hr-select", function (msg) {
      state.sel = String(msg.id);
      var n = net();
      if (n) { try { n.selectNodes([msg.id]); } catch (e) { /* not drawn yet */ } }
    });
    Shiny.addCustomMessageHandler("hr-undo", function (msg) {
      var b = document.getElementById("undo");
      if (b) b.disabled = !msg.enabled;
    });
    Shiny.addCustomMessageHandler("hr-menu", function (msg) { HRTree.openMenuFor(String(msg.id)); });
  });
})();
