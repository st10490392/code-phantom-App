// Loading screen + service worker registration. External file because the
// host's Content-Security-Policy forbids inline script.
(function () {
  function hide() {
    var splash = document.getElementById('cp-splash');
    if (!splash) return;
    splash.classList.add('cp-hidden');
    setTimeout(function () { splash.remove(); }, 250);
  }
  window.addEventListener('flutter-first-frame', hide, { once: true });

  // Offline page + installability only; see cp_sw.js for what it does NOT do.
  if ('serviceWorker' in navigator && window.isSecureContext) {
    window.addEventListener('load', function () {
      navigator.serviceWorker.register('cp_sw.js', { scope: './' }).catch(function () {});
    });
  }
})();
