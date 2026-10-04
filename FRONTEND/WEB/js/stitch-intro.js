(() => {
  'use strict';

  const video = document.getElementById('rtIntroVideo');
  const button = document.getElementById('rtIntroStart');
  const status = document.getElementById('rtIntroStatus');
  if (!video) return;

  // A hard navigation to Home starts a fresh intro. During this intro session,
  // however, the video is allowed to play exactly once.
  const PLAY_LOCK = 'rt_intro_play_lock';
  const NAV_TOKEN = 'rt_intro_nav_token';
  let navigating = false;

  const finish = () => {
    if (navigating) return;
    navigating = true;
    sessionStorage.setItem(NAV_TOKEN, String(Date.now()));
    sessionStorage.setItem('rt_intro_completed', '1');
    // Prevent any late click/play event from starting the media again.
    video.pause();
    video.removeAttribute('autoplay');
    location.replace('index.html?fromIntro=1');
  };

  const soundOn = () => {
    video.muted = false;
    video.defaultMuted = false;
    video.volume = 1;
  };

  const startOnce = async () => {
    if (navigating || video.ended) return false;
    soundOn();
    try {
      await video.play();
      sessionStorage.setItem(PLAY_LOCK, '1');
      if (status) status.hidden = true;
      if (button) button.textContent = 'ENTER RTCRACKERS →';
      return true;
    } catch (_) {
      if (status) {
        status.hidden = false;
        status.textContent = 'Tap the button to start the video with full sound.';
      }
      if (button) button.textContent = 'START VIDEO WITH SOUND →';
      return false;
    }
  };

  video.addEventListener('ended', finish, { once: true });
  video.addEventListener('error', () => {
    if (status) {
      status.hidden = false;
      status.textContent = 'The introduction video could not be loaded. Please reload the page.';
    }
    if (button) button.textContent = 'RELOAD INTRO →';
  }, { once: true });

  button?.addEventListener('click', async () => {
    if (navigating) return;
    if (video.paused || video.readyState < 2) {
      await startOnce();
      return;
    }
    // While the intro is already playing, the CTA enters the site; it never
    // calls play() a second time.
    finish();
  });

  // Only one initial play attempt.
  if (sessionStorage.getItem(PLAY_LOCK) !== '1') {
    startOnce();
  } else if (!video.ended) {
    // A browser restored this page from bfcache. Do not replay it.
    if (button) button.textContent = 'ENTER RTCRACKERS →';
  }
})();
