(function () {
  'use strict';

  var header = document.querySelector('.header');
  var toggle = document.querySelector('.menu-toggle');
  var nav = document.getElementById('menu');

  /* ---------- Menu mobile ---------- */
  function setMenu(open) {
    toggle.setAttribute('aria-expanded', String(open));
    toggle.setAttribute('aria-label', open ? 'Fechar menu' : 'Abrir menu');
    nav.classList.toggle('is-open', open);
  }
  toggle.addEventListener('click', function () {
    setMenu(toggle.getAttribute('aria-expanded') !== 'true');
  });
  nav.addEventListener('click', function (e) {
    if (e.target.closest('a')) setMenu(false);
  });
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && nav.classList.contains('is-open')) { setMenu(false); toggle.focus(); }
  });

  /* ---------- Header ao rolar ---------- */
  function onScroll() { header.classList.toggle('is-scrolled', window.scrollY > 24); }
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  /* ---------- Link ativo no menu ---------- */
  var links = Array.prototype.slice.call(document.querySelectorAll('.nav__list a'));
  if ('IntersectionObserver' in window) {
    var byId = {};
    links.forEach(function (a) { byId[a.getAttribute('href').slice(1)] = a; });
    var spy = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        links.forEach(function (a) { a.classList.remove('is-active'); a.removeAttribute('aria-current'); });
        var link = byId[entry.target.id];
        if (link) { link.classList.add('is-active'); link.setAttribute('aria-current', 'true'); }
      });
    }, { rootMargin: '-45% 0px -50% 0px' });
    Object.keys(byId).forEach(function (id) {
      var el = document.getElementById(id);
      if (el) spy.observe(el);
    });
  }

  /* ---------- Animação de entrada ---------- */
  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if ('IntersectionObserver' in window && !reduce) {
    var targets = document.querySelectorAll('.section__head, .curso, .ead__item, .prof, .dep, .numeros li, .sobre__content, .sobre__media, .dep__destaque, .faq details');
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) { entry.target.classList.add('is-visible'); io.unobserve(entry.target); }
      });
    }, { rootMargin: '0px 0px -8% 0px' });
    Array.prototype.forEach.call(targets, function (el) { el.classList.add('reveal'); io.observe(el); });
  }

  /* ---------- Galeria: pontos do carrossel (mobile) ---------- */
  var track = document.querySelector('[data-galeria-track]');
  var dotsWrap = document.querySelector('[data-galeria-dots]');
  if (track && dotsWrap) {
    var items = track.children;
    for (var i = 0; i < items.length; i++) dotsWrap.appendChild(document.createElement('span'));
    var dots = dotsWrap.children;
    var updateDots = function () {
      var center = track.scrollLeft + track.clientWidth / 2;
      var best = 0, bestDist = Infinity;
      for (var j = 0; j < items.length; j++) {
        var d = Math.abs(items[j].offsetLeft + items[j].offsetWidth / 2 - center);
        if (d < bestDist) { bestDist = d; best = j; }
      }
      for (var k = 0; k < dots.length; k++) dots[k].classList.toggle('is-active', k === best);
    };
    track.addEventListener('scroll', updateDots, { passive: true });
    updateDots();
  }

  /* ---------- Lightbox ---------- */
  var dialog = document.querySelector('.lightbox');
  var buttons = Array.prototype.slice.call(document.querySelectorAll('[data-lightbox]'));
  if (dialog && buttons.length && typeof dialog.showModal === 'function') {
    var lbImg = dialog.querySelector('.lightbox__img');
    var lbCap = dialog.querySelector('.lightbox__caption');
    var current = 0, opener = null;

    var show = function (index) {
      current = (index + buttons.length) % buttons.length;
      var img = buttons[current].querySelector('img');
      lbImg.src = img.getAttribute('data-full') || img.currentSrc || img.src;
      lbImg.alt = img.alt;
      lbCap.textContent = img.alt + ' (' + (current + 1) + '/' + buttons.length + ')';
    };

    buttons.forEach(function (btn, index) {
      btn.addEventListener('click', function () {
        opener = btn;
        show(index);
        dialog.showModal();
      });
    });

    dialog.querySelector('[data-lb-close]').addEventListener('click', function () { dialog.close(); });
    dialog.querySelector('[data-lb-prev]').addEventListener('click', function () { show(current - 1); });
    dialog.querySelector('[data-lb-next]').addEventListener('click', function () { show(current + 1); });
    dialog.addEventListener('click', function (e) { if (e.target === dialog) dialog.close(); });
    dialog.addEventListener('keydown', function (e) {
      if (e.key === 'ArrowLeft') show(current - 1);
      if (e.key === 'ArrowRight') show(current + 1);
    });
    dialog.addEventListener('close', function () { if (opener) opener.focus(); });

    // swipe no lightbox
    var startX = null;
    dialog.addEventListener('touchstart', function (e) { startX = e.touches[0].clientX; }, { passive: true });
    dialog.addEventListener('touchend', function (e) {
      if (startX === null) return;
      var dx = e.changedTouches[0].clientX - startX;
      if (Math.abs(dx) > 50) show(current + (dx < 0 ? 1 : -1));
      startX = null;
    });
  }

  /* ---------- Ano no rodapé ---------- */
  var ano = document.querySelector('[data-ano]');
  if (ano) ano.textContent = new Date().getFullYear();
})();
