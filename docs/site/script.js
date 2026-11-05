// DashCast — Official Website Interactive Engine
// Zero external libraries, 100% native ES6, lightweight and high-performance.
(function () {
  'use strict';

  // =========================================================================
  // 1. Theme Management (OLED Dark default + Light Mode)
  // =========================================================================
  const root = document.documentElement;
  const themeBtn = document.getElementById('themeToggleBtn');
  const metaThemeColor = document.querySelector('meta[name="theme-color"]:not([media])') ||
                         document.querySelector('meta[name="theme-color"]');

  const storedTheme = localStorage.getItem('dashcast_theme') ||
                      (window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark');

  function applyTheme(theme) {
    if (theme === 'light') {
      root.setAttribute('data-theme', 'light');
      if (themeBtn) {
        themeBtn.textContent = '🌙';
        themeBtn.setAttribute('aria-label', 'Switch to dark theme');
      }
      if (metaThemeColor) metaThemeColor.setAttribute('content', '#F5F5F7');
    } else {
      root.removeAttribute('data-theme');
      if (themeBtn) {
        themeBtn.textContent = '☀️';
        themeBtn.setAttribute('aria-label', 'Switch to light theme');
      }
      if (metaThemeColor) metaThemeColor.setAttribute('content', '#0C0D10');
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

  // =========================================================================
  // 2. Mobile Navigation Drawer
  // =========================================================================
  const mobileToggle = document.getElementById('mobileToggle');
  const mainNav = document.getElementById('mainNav');

  if (mobileToggle && mainNav) {
    mobileToggle.addEventListener('click', () => {
      const isOpen = mainNav.classList.toggle('open');
      mobileToggle.textContent = isOpen ? '✕' : '☰';
      mobileToggle.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
    });

    // Close mobile nav on anchor click
    mainNav.querySelectorAll('a').forEach(link => {
      link.addEventListener('click', () => {
        mainNav.classList.remove('open');
        mobileToggle.textContent = '☰';
        mobileToggle.setAttribute('aria-expanded', 'false');
      });
    });

    // Close on outside click
    document.addEventListener('click', (e) => {
      if (!mainNav.contains(e.target) && !mobileToggle.contains(e.target) && mainNav.classList.contains('open')) {
        mainNav.classList.remove('open');
        mobileToggle.textContent = '☰';
        mobileToggle.setAttribute('aria-expanded', 'false');
      }
    });
  }

  // =========================================================================
  // 3. CarPlay Status Clock (Live on-device time)
  // =========================================================================
  const carplayClock = document.getElementById('carplayClock');
  function updateClock() {
    if (!carplayClock) return;
    const now = new Date();
    let hours = now.getHours();
    const minutes = String(now.getMinutes()).padStart(2, '0');
    carplayClock.textContent = `${hours}:${minutes}`;
  }
  updateClock();
  setInterval(updateClock, 30000);

  // =========================================================================
  // 4. Cockpit Interactive Display Simulation
  // =========================================================================
  const channels = [
    {
      vehicle: 'Porsche 911 GT3',
      vehicleImg: 'assets/cars/porsche-911.webp',
      channelTag: 'Stream #1: Track Lap in 4K HDR',
      title: 'Porsche 911 GT3 RS Nürburgring Onboard',
      source: 'Hardware Decoded · Apple VideoToolbox · M3U8 Master',
      sourceLabel: 'Source: M3U Playlist (HLS Direct)',
      quality: '4K60 HDR · Stereo',
      speed: '0 MPH',
      gear: 'P · PARKED',
      badge: 'Low-Latency H.264 Live (60 FPS)'
    },
    {
      vehicle: 'Toyota Supra GR',
      vehicleImg: 'assets/cars/toyota-supra.webp',
      channelTag: 'Stream #2: Jellyfin Private Library',
      title: 'Sci-Fi Feature: Cyberpunk Highway 2049',
      source: 'Direct Stream · HEVC 1080p · Keychain Authenticated',
      sourceLabel: 'Source: Jellyfin Server (Home LAN)',
      quality: '1080p60 · 5.1 Surround',
      speed: '0 MPH',
      gear: 'P · CHARGING',
      badge: 'Direct Stream Active (Zero Transcode)'
    },
    {
      vehicle: 'BMW M4 Competition',
      vehicleImg: 'assets/cars/bmw-m4.webp',
      channelTag: 'Stream #3: iPhone Broadcast Mirror',
      title: 'Grand Prix Qualifying Practice Live',
      source: 'H.264 Broadcast Extension · Ultra-Low Latency',
      sourceLabel: 'Source: iPhone Screen Mirroring',
      quality: '1080p60 · Stereo',
      speed: '0 MPH',
      gear: 'P · PARKED',
      badge: 'Broadcast Extension Active'
    },
    {
      vehicle: 'Mercedes-AMG GT',
      vehicleImg: 'assets/cars/mercedes-amg.webp',
      channelTag: 'Stream #4: Local Camera Roll & Files',
      title: 'Alpine Pass Road Trip 4K Footage',
      source: 'Local Storage · Zero Cellular Data · iOS Photos',
      sourceLabel: 'Source: Local Device Files (Offline)',
      quality: '4K30 · Stereo',
      speed: '0 MPH',
      gear: 'P · PARKED',
      badge: 'Offline Playback (Zero Data Used)'
    }
  ];

  let currentChannelIdx = 0;
  let isPlaying = true;

  const vehicleTabs = document.querySelectorAll('.vehicle-tab-btn');
  const vehicleImg = document.getElementById('carVehicleImg');
  const videoChannelTag = document.getElementById('videoChannelTag');
  const videoTitleText = document.getElementById('videoTitleText');
  const videoSourceText = document.getElementById('videoSourceText');
  const videoQualityTag = document.getElementById('videoQualityTag');
  const currentSourceLabel = document.getElementById('currentSourceLabel');
  const telSpeed = document.getElementById('telSpeed');
  const telGear = document.getElementById('telGear');
  const mockupStatusBadge = document.getElementById('mockupStatusBadge');
  const mockupStatusText = document.getElementById('mockupStatusText');
  const playBtn = document.getElementById('mockupPlayBtn');
  const prevBtn = document.getElementById('mockupPrevBtn');
  const nextBtn = document.getElementById('mockupNextBtn');
  const carVideoPreview = document.getElementById('carVideoPreview');

  function renderChannel(idx) {
    currentChannelIdx = (idx + channels.length) % channels.length;
    const ch = channels[currentChannelIdx];

    // Update vehicle tabs
    vehicleTabs.forEach((tab, i) => {
      const active = i === currentChannelIdx;
      tab.classList.toggle('active', active);
      tab.setAttribute('aria-selected', active ? 'true' : 'false');
    });

    // Fade transition
    if (carVideoPreview) {
      carVideoPreview.style.opacity = '0.7';
      setTimeout(() => {
        if (vehicleImg) {
          vehicleImg.src = ch.vehicleImg;
          vehicleImg.alt = ch.vehicle;
        }
        if (videoChannelTag) videoChannelTag.textContent = ch.channelTag;
        if (videoTitleText) videoTitleText.textContent = ch.title;
        if (videoSourceText) videoSourceText.textContent = ch.source;
        if (videoQualityTag) videoQualityTag.textContent = ch.quality;
        if (currentSourceLabel) currentSourceLabel.textContent = ch.sourceLabel;
        if (telSpeed) telSpeed.innerHTML = `${ch.speed} <small>MPH</small>`;
        if (telGear) telGear.textContent = ch.gear;

        if (isPlaying) {
          mockupStatusBadge.innerHTML = `<span class="stream-pulse"></span><span>${ch.badge}</span>`;
        } else {
          mockupStatusBadge.innerHTML = `<span>⏸</span><span>Paused (Parked)</span>`;
        }

        carVideoPreview.style.opacity = '1';
      }, 120);
    }
  }

  // Tab click listeners
  vehicleTabs.forEach(tab => {
    tab.addEventListener('click', () => {
      const chIdx = parseInt(tab.getAttribute('data-channel'), 10) || 0;
      renderChannel(chIdx);
    });
  });

  // Prev / Next button listeners
  if (prevBtn) {
    prevBtn.addEventListener('click', () => renderChannel(currentChannelIdx - 1));
  }
  if (nextBtn) {
    nextBtn.addEventListener('click', () => renderChannel(currentChannelIdx + 1));
  }

  // Play / Pause button
  if (playBtn) {
    playBtn.addEventListener('click', () => {
      isPlaying = !isPlaying;
      playBtn.textContent = isPlaying ? '⏸' : '▶';
      playBtn.setAttribute('aria-label', isPlaying ? 'Pause video' : 'Play video');

      const ch = channels[currentChannelIdx];
      if (isPlaying) {
        mockupStatusBadge.innerHTML = `<span class="stream-pulse"></span><span>${ch.badge}</span>`;
      } else {
        mockupStatusBadge.innerHTML = `<span>⏸</span><span>Paused (Parked)</span>`;
      }
    });
  }

  // =========================================================================
  // 5. Supported Streaming Protocols & Chips
  // Strictly compliant with Decision D5 (zero unauthorized DRM mentions).
  // =========================================================================
  const castAppsContainer = document.getElementById('castApps');
  const primaryApps = [
    'YouTube (Direct / Web)',
    'Jellyfin Server',
    'Emby Server',
    'Plex Media',
    'Infuse',
    'VLC Media Player',
    'Twitch',
    'Bilibili',
    'M3U / M3U8 HLS',
    'Local Camera Roll',
    'iOS Files App'
  ];

  const extendedApps = [
    'RTSP Security & Dashcam Feeds',
    'RTMP Live Feeds',
    'HEVC & H.264 4K Direct',
    'MKV & MP4 Local Player',
    'AirPlay Hand-off',
    'DLNA Local Network',
    'Web Video HLS Feeds',
    'GoPro Telemetry MP4'
  ];

  let chipsExpanded = false;

  function renderChips() {
    if (!castAppsContainer) return;
    castAppsContainer.innerHTML = '';

    const list = chipsExpanded ? [...primaryApps, ...extendedApps] : primaryApps;
    list.forEach(item => {
      const chip = document.createElement('span');
      chip.className = 'app-chip';
      chip.textContent = item;
      castAppsContainer.appendChild(chip);
    });

    const toggleBtn = document.createElement('button');
    toggleBtn.className = 'app-chip more-chip';
    toggleBtn.type = 'button';
    if (!chipsExpanded) {
      toggleBtn.textContent = `+${extendedApps.length} more media sources`;
      toggleBtn.setAttribute('aria-label', `Show ${extendedApps.length} more media sources`);
    } else {
      toggleBtn.textContent = 'Show fewer sources ▲';
      toggleBtn.setAttribute('aria-label', 'Collapse media sources');
    }

    toggleBtn.addEventListener('click', () => {
      chipsExpanded = !chipsExpanded;
      renderChips();
    });

    castAppsContainer.appendChild(toggleBtn);
  }

  renderChips();

  // =========================================================================
  // 6. FAQ Accordion Logic with Keyboard Accessibility
  // =========================================================================
  const faqItems = document.querySelectorAll('.faq-item');
  faqItems.forEach(item => {
    const questionBtn = item.querySelector('.faq-question');
    if (questionBtn) {
      const toggleFaq = () => {
        const isOpen = item.classList.contains('open');
        // Close others
        faqItems.forEach(i => {
          i.classList.remove('open');
          const btn = i.querySelector('.faq-question');
          if (btn) btn.setAttribute('aria-expanded', 'false');
        });
        // Toggle current
        if (!isOpen) {
          item.classList.add('open');
          questionBtn.setAttribute('aria-expanded', 'true');
        }
      };

      questionBtn.addEventListener('click', toggleFaq);
      questionBtn.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          toggleFaq();
        }
      });
    }
  });

  // =========================================================================
  // 7. Smooth Scrolling with Offset for Anchor Links
  // =========================================================================
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
      const targetId = this.getAttribute('href');
      if (targetId === '#' || targetId === '#top') {
        e.preventDefault();
        window.scrollTo({ top: 0, behavior: 'smooth' });
        return;
      }
      const targetEl = document.querySelector(targetId);
      if (targetEl) {
        e.preventDefault();
        const headerOffset = 80;
        const elementPosition = targetEl.getBoundingClientRect().top;
        const offsetPosition = elementPosition + window.pageYOffset - headerOffset;
        window.scrollTo({
          top: offsetPosition,
          behavior: 'smooth'
        });
      }
    });
  });

})();
