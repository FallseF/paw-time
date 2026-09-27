(() => {
  'use strict';
  document.documentElement.classList.add('js');
  const language = document.documentElement.lang;
  const japanese = language === 'ja';
  const heroVideo = document.querySelector('[data-hero-video]');
  const pauseButton = document.querySelector('[data-video-pause]');
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  let userPaused = false;
  let inView = true;

  function updatePauseLabel() {
    if (!heroVideo || !pauseButton) return;
    const paused = heroVideo.paused;
    pauseButton.textContent = paused ? '▶' : 'Ⅱ';
    pauseButton.setAttribute('aria-label', paused
      ? (japanese ? '映像を再生' : 'Play background video')
      : (japanese ? '映像を一時停止' : 'Pause background video'));
  }
  function syncHero() {
    if (!heroVideo) return;
    if (reducedMotion.matches || userPaused || !inView || document.hidden || dialog?.open) {
      heroVideo.pause();
    } else {
      heroVideo.play().catch(updatePauseLabel);
    }
    updatePauseLabel();
  }
  pauseButton?.addEventListener('click', () => {
    if (heroVideo.paused) {
      userPaused = false;
      heroVideo.play().catch(updatePauseLabel);
    } else {
      userPaused = true;
      heroVideo.pause();
    }
  });
  heroVideo?.addEventListener('play', updatePauseLabel);
  heroVideo?.addEventListener('pause', updatePauseLabel);
  reducedMotion.addEventListener('change', syncHero);
  document.addEventListener('visibilitychange', syncHero);

  const dialog = document.querySelector('[data-video-dialog]');
  const trailer = dialog?.querySelector('video');
  const inlineTrailer = document.querySelector('[data-inline-trailer]');
  let opener = null;
  if (dialog && typeof dialog.showModal === 'function') {
    if (inlineTrailer) {
      inlineTrailer.controls = false;
      inlineTrailer.tabIndex = -1;
      inlineTrailer.setAttribute('aria-hidden', 'true');
    }
    document.querySelectorAll('[data-open-trailer]').forEach(trigger => {
      trigger.addEventListener('click', event => {
        event.preventDefault();
        opener = trigger;
        dialog.showModal();
        document.body.classList.add('modal-open');
        heroVideo?.pause();
        inlineTrailer?.pause();
        // Loading is deferred until the visitor explicitly opens the trailer.
        if (!trailer.getAttribute('src')) trailer.src = trailer.dataset.src;
        trailer.play().catch(() => { /* Native video controls remain available. */ });
      });
    });
    dialog.querySelector('[data-close-dialog]')?.addEventListener('click', () => dialog.close());
    dialog.addEventListener('click', event => {
      if (event.target !== dialog) return;
      const box = dialog.getBoundingClientRect();
      if (event.clientX < box.left || event.clientX > box.right || event.clientY < box.top || event.clientY > box.bottom) dialog.close();
    });
    dialog.addEventListener('close', () => {
      trailer.pause();
      document.body.classList.remove('modal-open');
      opener?.focus({preventScroll:true});
      syncHero();
    });
  } else {
    document.querySelectorAll('.trailer-trigger').forEach(trigger => trigger.hidden = true);
  }

  const filters = document.querySelector('[data-filters]');
  const cards = [...document.querySelectorAll('[data-character-group]')];
  const status = document.querySelector('[data-filter-status]');
  if (filters) {
    filters.hidden = false;
    filters.addEventListener('click', event => {
      const button = event.target.closest('button[data-group]');
      if (!button) return;
      const group = button.dataset.group;
      let visible = 0;
      cards.forEach(card => {
        card.hidden = group !== 'all' && card.dataset.characterGroup !== group;
        if (!card.hidden) visible++;
      });
      filters.querySelectorAll('button').forEach(item => item.setAttribute('aria-pressed', String(item === button)));
      if (status) status.textContent = japanese ? `${visible}体を表示` : `${visible} companions`;
    });
  }

  if (heroVideo && 'IntersectionObserver' in window) {
    new IntersectionObserver(entries => {
      inView = entries[0].isIntersecting;
      syncHero();
    }, {threshold:0.05}).observe(heroVideo);
  }
  syncHero();
})();
