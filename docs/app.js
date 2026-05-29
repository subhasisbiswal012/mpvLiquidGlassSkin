/* ============================================================
   mpv Liquid Glass — landing page behavior
   ============================================================ */
(function () {
  "use strict";

  const REPO = "subhasisbiswal012/mpvLiquidGlassSkin";
  const RELEASES_PAGE = `https://github.com/${REPO}/releases/latest`;
  const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ---------- Theme toggle (persisted) ---------- */
  const root = document.documentElement;
  const themeToggle = document.getElementById("theme-toggle");

  const applyTheme = (theme) => {
    root.setAttribute("data-theme", theme);
    if (themeToggle) {
      const toLight = theme === "dark";
      themeToggle.setAttribute("aria-label", toLight ? "Switch to light theme" : "Switch to dark theme");
      themeToggle.setAttribute("aria-pressed", String(theme === "light"));
    }
    const meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute("content", theme === "dark" ? "#0a0d14" : "#f3f5fa");
  };

  // Initial theme: stored > system preference > dark default
  const stored = localStorage.getItem("lg-theme");
  if (stored) {
    applyTheme(stored);
  } else if (window.matchMedia("(prefers-color-scheme: light)").matches) {
    applyTheme("light");
  } else {
    applyTheme("dark");
  }

  if (themeToggle) {
    themeToggle.addEventListener("click", () => {
      const next = root.getAttribute("data-theme") === "dark" ? "light" : "dark";
      applyTheme(next);
      localStorage.setItem("lg-theme", next);
    });
  }

  /* ---------- Sticky header shadow on scroll ---------- */
  const header = document.querySelector(".site-header");
  const onScroll = () => {
    if (header) header.classList.toggle("scrolled", window.scrollY > 8);
  };
  onScroll();
  window.addEventListener("scroll", onScroll, { passive: true });

  /* ---------- Mobile menu ---------- */
  const navToggle = document.getElementById("nav-toggle");
  const mobileMenu = document.getElementById("mobile-menu");
  if (navToggle && mobileMenu) {
    const setMenu = (open) => {
      mobileMenu.hidden = !open;
      navToggle.setAttribute("aria-expanded", String(open));
      navToggle.setAttribute("aria-label", open ? "Close menu" : "Open menu");
    };
    navToggle.addEventListener("click", () => setMenu(mobileMenu.hidden));
    mobileMenu.querySelectorAll("a").forEach((a) => a.addEventListener("click", () => setMenu(false)));
  }

  /* ---------- Dynamic latest-release fetch ---------- */
  // Updates every download button + the hero version pill with the real
  // latest version, and points the link straight at the release asset (zip).
  const downloadLinks = ["download-btn", "download-btn-2", "download-btn-3"]
    .map((id) => document.getElementById(id))
    .filter(Boolean);
  const downloadLabels = ["download-label", "download-label-2", "download-label-3"]
    .map((id) => document.getElementById(id))
    .filter(Boolean);
  const versionPill = document.getElementById("release-version");

  fetch(`https://api.github.com/repos/${REPO}/releases/latest`, {
    headers: { Accept: "application/vnd.github+json" },
  })
    .then((res) => (res.ok ? res.json() : Promise.reject(new Error(`HTTP ${res.status}`))))
    .then((data) => {
      const tag = data.tag_name || data.name;
      if (!tag) return;

      // Prefer a .zip asset; fall back to the releases page.
      const zip = (data.assets || []).find((a) => /\.zip$/i.test(a.name));
      const href = zip ? zip.browser_download_url : RELEASES_PAGE;

      downloadLinks.forEach((a) => (a.href = href));
      downloadLabels.forEach((el) => (el.textContent = `Download ${tag}`));
      if (versionPill) versionPill.textContent = `${tag} · latest`;
    })
    .catch(() => {
      // Network/API failure — links already point at the releases page,
      // so the page stays fully functional. Just mark the pill gracefully.
      if (versionPill) versionPill.textContent = "latest release";
    });

  /* ---------- Scroll reveal ---------- */
  const revealEls = Array.from(document.querySelectorAll(".reveal"));
  if (prefersReducedMotion || !("IntersectionObserver" in window)) {
    revealEls.forEach((el) => el.classList.add("in"));
  } else {
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("in");
            io.unobserve(entry.target);
          }
        });
      },
      { rootMargin: "0px 0px -10% 0px", threshold: 0.08 }
    );
    // Stagger siblings within the same grid for a sequenced entrance.
    revealEls.forEach((el, i) => {
      el.style.transitionDelay = `${Math.min((i % 6) * 60, 300)}ms`;
      io.observe(el);
    });
  }

  /* ---------- Copy-to-clipboard ---------- */
  const fallbackCopy = (text) => {
    const ta = document.createElement("textarea");
    ta.value = text;
    ta.setAttribute("readonly", "");
    ta.style.position = "fixed";
    ta.style.opacity = "0";
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand("copy"); } catch (_) {}
    document.body.removeChild(ta);
  };

  document.querySelectorAll(".copy-btn").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const target = document.getElementById(btn.dataset.copyTarget);
      if (!target) return;
      const text = target.textContent.trim();
      try {
        if (navigator.clipboard && window.isSecureContext) {
          await navigator.clipboard.writeText(text);
        } else {
          fallbackCopy(text);
        }
      } catch (_) {
        fallbackCopy(text);
      }
      btn.classList.add("copied");
      const labelSpan = btn.querySelector("span");
      const original = labelSpan ? labelSpan.textContent : null;
      if (labelSpan) labelSpan.textContent = "Copied";
      setTimeout(() => {
        btn.classList.remove("copied");
        if (labelSpan && original !== null) labelSpan.textContent = original;
      }, 1600);
    });
  });

  /* ---------- Gallery lightbox ---------- */
  const lightbox = document.getElementById("lightbox");
  const lightboxImg = document.getElementById("lightbox-img");
  const closeBtn = lightbox ? lightbox.querySelector(".lightbox__close") : null;
  let lastFocused = null;

  const openLightbox = (src, alt) => {
    if (!lightbox || !lightboxImg) return;
    lastFocused = document.activeElement;
    lightboxImg.src = src;
    lightboxImg.alt = alt || "";
    lightbox.hidden = false;
    document.body.style.overflow = "hidden";
    if (closeBtn) closeBtn.focus();
  };
  const closeLightbox = () => {
    if (!lightbox) return;
    lightbox.hidden = true;
    lightboxImg.src = "";
    document.body.style.overflow = "";
    if (lastFocused && typeof lastFocused.focus === "function") lastFocused.focus();
  };

  document.querySelectorAll(".shot").forEach((shot) => {
    shot.addEventListener("click", () => {
      const img = shot.querySelector("img");
      openLightbox(shot.dataset.full, img ? img.alt : "");
    });
  });

  if (lightbox) {
    lightbox.addEventListener("click", (e) => {
      if (e.target === lightbox || e.target === closeBtn || (closeBtn && closeBtn.contains(e.target))) {
        closeLightbox();
      }
    });
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && !lightbox.hidden) closeLightbox();
    });
  }
})();
