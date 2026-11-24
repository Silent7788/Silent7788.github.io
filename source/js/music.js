(function () {
  var SRC = "/music/bgm.mp3";
  var KEY = "memoir-bgm-on";

  function ready(fn) {
    if (document.readyState !== "loading") fn();
    else document.addEventListener("DOMContentLoaded", fn);
  }

  ready(function () {
    // 样式
    var css = document.createElement("style");
    css.textContent =
      ".bgm-btn{position:fixed;right:18px;bottom:18px;z-index:9998;" +
      "width:42px;height:42px;border-radius:50%;" +
      "border:1px solid rgba(120,95,70,.28);background:rgba(255,253,249,.94);" +
      "color:#a8542f;font-size:15px;line-height:1;cursor:pointer;" +
      "display:flex;align-items:center;justify-content:center;" +
      "box-shadow:0 8px 20px -10px rgba(70,50,30,.55);" +
      "transition:transform .18s ease,background .18s ease,color .18s ease;" +
      "-webkit-backdrop-filter:blur(6px);backdrop-filter:blur(6px)}" +
      ".bgm-btn:hover{transform:scale(1.08)}" +
      ".bgm-btn.on{background:#a8542f;color:#fff;border-color:#a8542f}" +
      ".bgm-btn:focus-visible{outline:2px solid #a8542f;outline-offset:2px}" +
      "@media(max-width:600px){.bgm-btn{right:14px;bottom:14px;width:38px;height:38px}}";
    document.head.appendChild(css);

    var audio = document.createElement("audio");
    audio.src = SRC;
    audio.loop = true;
    audio.preload = "none";
    audio.volume = 0.35;

    var btn = document.createElement("button");
    btn.type = "button";
    btn.className = "bgm-btn";

    document.body.appendChild(audio);
    document.body.appendChild(btn);

    var on = false;
    try { on = localStorage.getItem(KEY) === "1"; } catch (e) {}

    function paint() {
      btn.classList.toggle("on", on);
      btn.title = on ? "关闭背景音乐" : "播放背景音乐";
      btn.setAttribute("aria-label", btn.title);
      btn.textContent = on ? "❙❙" : "♪";
    }

    function stop() {
      on = false;
      audio.pause();
      try { localStorage.setItem(KEY, "0"); } catch (e) {}
      paint();
    }

    btn.addEventListener("click", function () {
      if (on) { stop(); return; }
      on = true;
      try { localStorage.setItem(KEY, "1"); } catch (e) {}
      var p = audio.play();
      if (p && p.catch) {
        p.catch(function () { stop(); });
      }
      paint();
    });

    audio.addEventListener("error", function () {
      btn.style.display = "none";
    });

    // 上次开着的话，尝试续播；浏览器不允许自动播放时就静默恢复成关闭
    if (on) {
      var p = audio.play();
      if (p && p.then) {
        p.then(paint).catch(function () { on = false; paint(); });
      }
    }
    paint();
  });
})();
