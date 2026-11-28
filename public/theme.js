// Light/dark switch. Dark is the default; a visitor's choice is remembered in this browser only.
(function(){
  var KEY = 'home-calc-theme', root = document.documentElement;
  function saved(){ try { return localStorage.getItem(KEY) === 'light' ? 'light' : 'dark'; } catch(e){ return 'dark'; } }
  function apply(t){
    root.setAttribute('data-theme', t);
    var m = document.querySelector('meta[name="theme-color"]');
    if (m) m.setAttribute('content', t === 'light' ? '#f5f4f1' : '#16181b');
    var ic = document.querySelector('link[rel="icon"][data-light]');
    if (ic) ic.setAttribute('href', ic.getAttribute(t === 'light' ? 'data-light' : 'data-dark'));
    var b = document.getElementById('themeBtn');
    if (b){
      b.textContent = t === 'light' ? '☾ Dark' : '☀ Light';
      b.setAttribute('aria-label', t === 'light' ? 'Switch to dark mode' : 'Switch to light mode');
    }
  }
  apply(saved());
  document.addEventListener('DOMContentLoaded', function(){
    apply(root.getAttribute('data-theme'));
    var b = document.getElementById('themeBtn');
    if (!b) return;
    b.addEventListener('click', function(){
      var t = root.getAttribute('data-theme') === 'light' ? 'dark' : 'light';
      apply(t);
      try { localStorage.setItem(KEY, t); } catch(e){}
    });
  });
})();
