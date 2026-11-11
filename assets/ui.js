function readPreference(name, fallback) {
  try {
    return localStorage.getItem(`tinttube.preview.${name}`) ?? fallback;
  } catch {
    return fallback;
  }
}

function writePreference(name, value) {
  try {
    localStorage.setItem(`tinttube.preview.${name}`, value);
  } catch {
    // The switch still updates when storage is unavailable.
  }
}

function setupSwitches() {
  document.querySelectorAll('[role="switch"]').forEach((toggle) => {
    const name = toggle.getAttribute('aria-label');
    toggle.setAttribute('aria-checked', readPreference(name, toggle.getAttribute('aria-checked')));
    toggle.addEventListener('click', () => {
      const checked = String(toggle.getAttribute('aria-checked') === 'false');
      toggle.setAttribute('aria-checked', checked);
      writePreference(name, checked);
    });
  });
}

function setupShopTabs() {
  const tabs = Array.from(document.querySelectorAll('[role="tab"]'));

  function selectTab(selected) {
    tabs.forEach((tab) => {
      const active = tab === selected;
      tab.setAttribute('aria-selected', String(active));
      tab.tabIndex = active ? 0 : -1;
      document.getElementById(tab.getAttribute('aria-controls')).hidden = !active;
    });
  }

  tabs.forEach((tab, index) => {
    tab.addEventListener('click', () => selectTab(tab));
    tab.addEventListener('keydown', (event) => {
      let next;
      switch (event.key) {
        case 'ArrowLeft':
          next = (index - 1 + tabs.length) % tabs.length;
          break;
        case 'ArrowRight':
          next = (index + 1) % tabs.length;
          break;
        case 'Home':
          next = 0;
          break;
        case 'End':
          next = tabs.length - 1;
          break;
        default:
          return;
      }
      event.preventDefault();
      selectTab(tabs[next]);
      tabs[next].focus();
    });
  });
}

function setupGameplayPreview() {
  const level = new URLSearchParams(window.location.search).get('level');
  if (level && /^(?:[1-9]|1[0-2])$/.test(level)) {
    document.getElementById('level-title').textContent = `Level ${level}`;
  }

  document.body.dataset.glyphs = readPreference('Color-blind Glyphs', 'true') === 'true' ? 'on' : 'off';
  const tubes = Array.from(document.querySelectorAll('.tube-btn'));
  tubes.forEach((tube) => {
    tube.addEventListener('click', () => {
      const select = tube.getAttribute('aria-pressed') === 'false';
      tubes.forEach((other) => other.setAttribute('aria-pressed', String(other === tube && select)));
    });
  });

  const menu = document.getElementById('preview-menu');
  document.querySelectorAll('[data-open-preview]').forEach((button) => {
    button.addEventListener('click', () => menu.showModal());
  });
}

function setupSplash() {
  const bar = document.getElementById('splash-progress');
  const percent = document.getElementById('splash-pct');
  let progress = 60;
  const timer = window.setInterval(() => {
    progress += 10;
    bar.style.width = `${progress}%`;
    bar.setAttribute('aria-valuenow', String(progress));
    percent.textContent = `${progress}%`;
    if (progress === 100) {
      window.clearInterval(timer);
      window.setTimeout(() => window.location.replace('index.html'), 300);
    }
  }, 180);
}

const screenSetup = {
  gameplay: setupGameplayPreview,
  settings: setupSwitches,
  shop: setupShopTabs,
  splash: setupSplash,
};

screenSetup[document.body.dataset.screen]?.();
