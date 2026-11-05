// DashCast — Interactive Website Scripts
(function () {
  'use strict';

  // 1. Theme Management (Dark / Light)
  const root = document.documentElement;
  const themeBtn = document.getElementById('themeToggleBtn');
  const storedTheme = localStorage.getItem('dashcast_theme') || (window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark');

  function applyTheme(theme) {
    if (theme === 'light') {
      root.setAttribute('data-theme', 'light');
      if (themeBtn) themeBtn.textContent = '🌙';
    } else {
      root.removeAttribute('data-theme');
      if (themeBtn) themeBtn.textContent = '☀️';
    }
    localStorage.setItem('dashcast_theme', theme);
  }

  applyTheme(storedTheme);

  if (themeBtn) {
    themeBtn.addEventListener('click', () => {
      const current = root.getAttribute('data-theme') === 'light' ? 'light' : 'dark';
      applyTheme(current === 'light' ? 'dark' : 'light');
    });
  }

  // 2. Mobile Nav Toggle
  const mobileToggle = document.getElementById('mobileToggle');
  const mainNav = document.getElementById('mainNav');

  if (mobileToggle && mainNav) {
    mobileToggle.addEventListener('click', () => {
      mainNav.classList.toggle('open');
      mobileToggle.textContent = mainNav.classList.contains('open') ? '✕' : '☰';
    });

    // Close on link click
    mainNav.querySelectorAll('a').forEach(link => {
      link.addEventListener('click', () => {
        mainNav.classList.remove('open');
        if (mobileToggle) mobileToggle.textContent = '☰';
      });
    });
  }

  // 3. Supported Streaming Apps Chips (Benchmarked on CarTV apps array)
  const castAppsContainer = document.getElementById('castApps');
  const primaryApps = [
    'YouTube', 'Plex', 'Jellyfin', 'Emby', 'Infuse', 'VLC',
    'Bilibili', 'Twitch', 'Vimeo', 'Photos Library', 'Local Files'
  ];
  const extendedApps = [
    'Netflix (Mirror)', 'Disney+ (Mirror)', 'Prime Video (Mirror)',
    'Tencent Video', 'iQIYI', 'Douyin / TikTok', 'DailyMotion',
    'M3U8 Live Stream', 'MKV Player', 'HEVC 4K', 'AirPlay DLNA'
  ];

  if (castAppsContainer) {
    castAppsContainer.innerHTML = '';
    primaryApps.forEach(app => {
      const chip = document.createElement('span');
      chip.className = 'app-chip';
      chip.textContent = app;
      castAppsContainer.appendChild(chip);
    });

    const moreChip = document.createElement('span');
    moreChip.className = 'app-chip more-chip';
    moreChip.textContent = `+${extendedApps.length} more sources`;
    castAppsContainer.appendChild(moreChip);

    let expanded = false;
    moreChip.addEventListener('click', () => {
      if (!expanded) {
        castAppsContainer.innerHTML = '';
        [...primaryApps, ...extendedApps].forEach(app => {
          const chip = document.createElement('span');
          chip.className = 'app-chip';
          chip.textContent = app;
          castAppsContainer.appendChild(chip);
        });
        const collapseChip = document.createElement('span');
        collapseChip.className = 'app-chip more-chip';
        collapseChip.textContent = 'Show fewer';
        collapseChip.addEventListener('click', () => location.reload());
        castAppsContainer.appendChild(collapseChip);
        expanded = true;
      }
    });
  }

  // 4. FAQ Accordion Logic
  const faqItems = document.querySelectorAll('.faq-item');
  faqItems.forEach(item => {
    const questionBtn = item.querySelector('.faq-question');
    if (questionBtn) {
      questionBtn.addEventListener('click', () => {
        const isOpen = item.classList.contains('open');
        // Close others
        faqItems.forEach(i => i.classList.remove('open'));
        // Toggle current
        if (!isOpen) {
          item.classList.add('open');
        }
      });
    }
  });

  // 5. Interactive Mockup Playback Button Simulation
  const playBtn = document.getElementById('mockupPlayBtn');
  const statusBadge = document.getElementById('mockupStatusBadge');
  if (playBtn && statusBadge) {
    let isPlaying = true;
    playBtn.addEventListener('click', () => {
      isPlaying = !isPlaying;
      playBtn.textContent = isPlaying ? '⏸' : '▶';
      if (isPlaying) {
        statusBadge.innerHTML = '<span class="stream-pulse"></span> Low-Latency H.264 Live';
      } else {
        statusBadge.innerHTML = '<span>⏸</span> Paused (Parked)';
      }
    });
  }
})();
