// {{flutter_service_worker_version}} is replaced at build time with a unique
// integer per build. If it differs from the stored version, clear all caches
// to ensure users get the latest code.
(function() {
  var BUILD_ID = {{flutter_service_worker_version}};
  var STORED = localStorage.getItem("_jtk25_build");
  if (STORED && STORED !== BUILD_ID) {
    if ("caches" in window) {
      caches.keys().then(function(names) {
        return Promise.all(names.map(function(n) { return caches.delete(n); }));
      });
    }
  }
  localStorage.setItem("_jtk25_build", BUILD_ID);
})();

_flutter.loader.load();
