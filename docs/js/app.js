// The page: picks the language, draws the cards, filters them, opens the preview and reads it aloud.
// No library, no network request: the catalogue is in data.js and the words in i18n.js.
(function () {
  'use strict';

  var DATA = window.WVA;
  var WORDS = window.WVA_I18N;
  var LANGS = ['en', 'fr', 'de'];
  var SPEECH_LANG = { en: 'en-US', fr: 'fr-FR', de: 'de-DE' };
  var GROUPS = ['active', 'merged', 'tool', 'retired'];
  var state = { lang: 'en', filter: 'all', previewId: null, speaking: false };

  function $(id) { return document.getElementById(id); }

  function el(tag, className, text) {
    var node = document.createElement(tag);
    if (className) { node.className = className; }
    if (text !== undefined && text !== null) { node.textContent = text; }
    return node;
  }

  function icon(name, className) {
    var svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('class', className || 'icon');
    svg.setAttribute('aria-hidden', 'true');
    svg.setAttribute('focusable', 'false');
    var use = document.createElementNS('http://www.w3.org/2000/svg', 'use');
    use.setAttribute('href', '#i-' + name);
    svg.appendChild(use);
    return svg;
  }

  // ------------------------------------------------------------- words

  function T(key, vars) {
    var table = WORDS[state.lang] || WORDS.en;
    var text = table[key];
    if (text === undefined) { text = WORDS.en[key]; }
    if (text === undefined) { return key; }
    if (vars) {
      Object.keys(vars).forEach(function (name) {
        text = text.split('{' + name + '}').join(vars[name]);
      });
    }
    return text;
  }

  function pick(map) {
    if (map === null || map === undefined) { return ''; }
    return map[state.lang] !== undefined ? map[state.lang] : map.en;
  }

  function number(value, digits) {
    try {
      return value.toLocaleString(state.lang, { maximumFractionDigits: digits || 0, minimumFractionDigits: digits || 0 });
    } catch (e) {
      return String(value);
    }
  }

  function size(bytes) {
    return number(bytes / 1024, bytes < 10240 ? 1 : 0) + ' ' + (state.lang === 'en' ? 'KB' : state.lang === 'fr' ? 'Ko' : 'KB');
  }

  function store(key, value) {
    try {
      if (value === undefined) { return window.localStorage.getItem(key); }
      window.localStorage.setItem(key, value);
    } catch (e) { /* private window, blocked storage: the page works without it */ }
    return null;
  }

  // ---------------------------------------------------------- language

  function detectLanguage() {
    var asked = null;
    try { asked = new URLSearchParams(window.location.search).get('lang'); } catch (e) { asked = null; }
    if (asked && LANGS.indexOf(asked.slice(0, 2).toLowerCase()) >= 0) { return asked.slice(0, 2).toLowerCase(); }
    var saved = store('wva-lang');
    if (saved && LANGS.indexOf(saved) >= 0) { return saved; }
    var preferred = (navigator.languages && navigator.languages.length) ? navigator.languages : [navigator.language || 'en'];
    for (var i = 0; i < preferred.length; i += 1) {
      var code = String(preferred[i] || '').slice(0, 2).toLowerCase();
      if (LANGS.indexOf(code) >= 0) { return code; }
    }
    return 'en';
  }

  function applyStatic() {
    var nodes = document.querySelectorAll('[data-i18n]');
    for (var i = 0; i < nodes.length; i += 1) {
      nodes[i].textContent = T(nodes[i].getAttribute('data-i18n'));
    }
    document.documentElement.lang = state.lang;
    document.title = T('html.title');
    var description = document.querySelector('meta[name="description"]');
    if (description) { description.setAttribute('content', T('html.description')); }
    var locale = document.querySelector('meta[property="og:locale"]');
    if (locale) { locale.setAttribute('content', { en: 'en_US', fr: 'fr_FR', de: 'de_DE' }[state.lang]); }
    var buttons = document.querySelectorAll('.lang-btn');
    for (var j = 0; j < buttons.length; j += 1) {
      buttons[j].setAttribute('aria-pressed', buttons[j].getAttribute('data-lang') === state.lang ? 'true' : 'false');
    }
    $('download-all').setAttribute('aria-label', T('hero.all') + ' (' + size(DATA.all.bytes) + ')');
    $('all-note').textContent = T('hero.allnote', { n: DATA.all.count, size: size(DATA.all.bytes) });
    var tests = 0;
    DATA.addons.forEach(function (addon) { tests += addon.tests || 0; });
    $('stat-addons').textContent = String(DATA.addons.length);
    $('stat-tests').textContent = number(tests);
    $('wowvision-link').setAttribute('href', DATA.wowvision);
    $('repo-link').setAttribute('href', DATA.repoUrl);
  }

  function setLanguage(lang, byUser) {
    state.lang = lang;
    if (byUser) { store('wva-lang', lang); }
    applyStatic();
    renderFilters();
    renderGrid();
    renderUpstream();
    if (state.previewId) { renderPreview(state.previewId); }
    if (byUser) {
      $('announce').textContent = '';
      window.setTimeout(function () { $('announce').textContent = T('lang.changed'); }, 50);
      try {
        var url = new URL(window.location.href);
        url.searchParams.set('lang', lang);
        window.history.replaceState(null, '', url.toString());
      } catch (e) { /* an old browser: the language is kept anyway */ }
    }
  }

  // ----------------------------------------------------------- filters

  function addonsOf(filter) {
    return DATA.addons.filter(function (addon) { return filter === 'all' || addon.group === filter; });
  }

  function renderFilters() {
    var box = $('filter-buttons');
    box.textContent = '';
    ['all'].concat(GROUPS).forEach(function (filter) {
      var count = addonsOf(filter).length;
      if (count === 0) { return; }
      var label = filter === 'all' ? T('filter.all') : T('group.' + filter);
      var button = el('button', 'chip' + (filter === 'all' ? '' : ' chip-' + filter), label + ' (' + count + ')');
      button.type = 'button';
      button.setAttribute('aria-pressed', state.filter === filter ? 'true' : 'false');
      button.addEventListener('click', function () {
        state.filter = filter;
        renderFilters();
        renderGrid();
      });
      box.appendChild(button);
    });
    $('filter-help').textContent = state.filter === 'all' ? '' : T('group.' + state.filter + '.help');
  }

  // ------------------------------------------------------------- cards

  function badge(group) {
    return el('span', 'badge badge-' + group, T('group.' + group));
  }

  function needs(addon) {
    var parts = [];
    if (addon.requires.length) {
      parts.push(T('card.needs') + ' ' + addon.requires.map(function (name) { return T('needs.' + name); }).join(', '));
    }
    if (addon.optional.length) {
      parts.push(T('card.optional') + ' ' + addon.optional.map(function (name) { return T('needs.' + name); }).join(', '));
    }
    return parts;
  }

  function showToast(name) {
    var toast = $('toast');
    toast.textContent = T('toast.accepted', { name: name }) + ' ' + T('toast.how');
    toast.classList.add('is-on');
    window.clearTimeout(showToast.timer);
    showToast.timer = window.setTimeout(function () { toast.classList.remove('is-on'); }, 9000);
  }

  function card(addon) {
    var title = pick(addon.title);
    var item = el('li', 'card card-' + addon.group + (addon.featured ? ' card-featured' : ''));
    var article = el('article', 'card-inner');
    article.setAttribute('aria-labelledby', 'card-' + addon.id);

    var top = el('div', 'card-top');
    var frame = el('span', 'frame frame-' + (addon.featured ? 'featured' : addon.group));
    frame.setAttribute('aria-hidden', 'true');
    frame.appendChild(icon(addon.icon, 'icon icon-lg'));
    top.appendChild(frame);
    var heading = el('div', 'card-heading');
    var h3 = el('h3', 'card-title', title);
    h3.id = 'card-' + addon.id;
    heading.appendChild(h3);
    var badges = el('p', 'badges');
    badges.appendChild(badge(addon.group));
    if (addon.featured) { badges.appendChild(el('span', 'badge badge-featured', T('card.featured'))); }
    heading.appendChild(badges);
    top.appendChild(heading);
    article.appendChild(top);

    article.appendChild(el('p', 'tagline', pick(addon.tagline)));

    var meta = el('ul', 'meta');
    meta.setAttribute('role', 'list');
    meta.appendChild(el('li', null, T('card.version') + ' ' + addon.version));
    meta.appendChild(el('li', null, T('card.size') + ' ' + size(addon.zip.bytes)));
    if (addon.tests) { meta.appendChild(el('li', null, T('card.tests', { n: number(addon.tests) }))); }
    needs(addon).forEach(function (line) { meta.appendChild(el('li', 'meta-needs', line)); });
    article.appendChild(meta);

    var actions = el('div', 'actions');
    var download = el('a', 'btn btn-gold');
    download.href = addon.zip.file;
    download.setAttribute('download', '');
    download.setAttribute('aria-label', T('card.downloadFor', { name: title }) + ' (' + size(addon.zip.bytes) + ')');
    download.appendChild(icon('download'));
    download.appendChild(el('span', null, T('card.download')));
    download.addEventListener('click', function () { showToast(title); });
    actions.appendChild(download);

    var preview = el('button', 'btn btn-ghost');
    preview.type = 'button';
    preview.setAttribute('aria-label', T('card.previewFor', { name: title }));
    preview.setAttribute('aria-haspopup', 'dialog');
    preview.setAttribute('data-preview', addon.id);
    preview.appendChild(icon('eye'));
    preview.appendChild(el('span', null, T('card.preview')));
    preview.addEventListener('click', function () { openPreview(addon.id, preview); });
    actions.appendChild(preview);

    var source = el('a', 'btn btn-quiet');
    source.href = addon.links.source;
    source.setAttribute('aria-label', T('card.source') + ': ' + title);
    source.appendChild(icon('code'));
    source.appendChild(el('span', null, T('card.source')));
    actions.appendChild(source);

    article.appendChild(actions);
    item.appendChild(article);
    return item;
  }

  function renderGrid() {
    var grid = $('grid');
    grid.textContent = '';
    var shown = addonsOf(state.filter);
    shown.forEach(function (addon) { grid.appendChild(card(addon)); });
    $('count').textContent = shown.length === 1 ? T('count.one') : T('count', { n: shown.length });
  }

  function renderUpstream() {
    var list = $('pr-list');
    list.textContent = '';
    DATA.upstream.forEach(function (item) {
      var row = el('li', 'pr pr-' + item.state);
      var link = el('a', 'link', item.repo + '#' + item.number);
      link.href = item.url;
      row.appendChild(link);
      row.appendChild(el('span', 'pr-what', ' ' + pick(item.what)));
      row.appendChild(el('span', 'badge badge-' + (item.state === 'merged' ? 'merged' : 'draft'), T('upstream.' + item.state)));
      list.appendChild(row);
    });
  }

  // ----------------------------------------------------------- preview

  function findAddon(id) {
    for (var i = 0; i < DATA.addons.length; i += 1) {
      if (DATA.addons[i].id === id) { return DATA.addons[i]; }
    }
    return null;
  }

  function section(title) {
    var box = el('section', 'pv-section');
    box.appendChild(el('h3', 'pv-h', title));
    return box;
  }

  function keysTable(addon) {
    var box = section(T('dialog.keys'));
    if (!addon.keys.length) {
      box.appendChild(el('p', 'pv-p', T('dialog.keysNone')));
      return box;
    }
    var table = el('table', 'keys');
    var body = el('tbody');
    addon.keys.forEach(function (row) {
      var tr = el('tr');
      var th = el('th');
      th.scope = 'row';
      pick(row.keys).split('+').forEach(function (part, index) {
        if (index > 0) { th.appendChild(document.createTextNode('+')); }
        th.appendChild(el('kbd', null, part));
      });
      tr.appendChild(th);
      tr.appendChild(el('td', null, pick(row.does)));
      body.appendChild(tr);
    });
    table.appendChild(body);
    box.appendChild(table);
    return box;
  }

  function commands(addon) {
    var box = section(T('dialog.commands'));
    var list = (addon.commands[state.lang] && addon.commands[state.lang].length) ? addon.commands[state.lang] : addon.commands.en;
    if (!list || !list.length) {
      box.appendChild(el('p', 'pv-p', T('dialog.commandsNone')));
      return box;
    }
    var ul = el('ul', 'cmds');
    ul.setAttribute('role', 'list');
    list.forEach(function (command) {
      var li = el('li');
      li.appendChild(el('code', null, command));
      ul.appendChild(li);
    });
    box.appendChild(ul);
    return box;
  }

  function hearing(addon) {
    var box = section(T('dialog.hear'));
    box.appendChild(el('p', 'pv-p pv-help', T('dialog.hearHelp')));
    var lines = addon.preview[state.lang] || addon.preview.en;
    var list = el('ol', 'screen');
    list.id = 'screen-lines';
    lines.forEach(function (line, index) {
      var li = el('li', 'screen-line');
      li.setAttribute('data-index', String(index));
      li.textContent = line;
      list.appendChild(li);
    });
    box.appendChild(list);
    if ('speechSynthesis' in window && 'SpeechSynthesisUtterance' in window) {
      var bar = el('p', 'pv-actions');
      var listen = el('button', 'btn btn-gold');
      listen.type = 'button';
      listen.id = 'listen';
      listen.appendChild(icon('speaker'));
      listen.appendChild(el('span', null, T('dialog.listen')));
      listen.addEventListener('click', function () { toggleSpeech(lines); });
      bar.appendChild(listen);
      box.appendChild(bar);
    } else {
      box.appendChild(el('p', 'pv-p pv-help', T('dialog.noVoice')));
    }
    return box;
  }

  function technical(addon) {
    var box = el('details', 'pv-tech');
    box.appendChild(el('summary', null, T('dialog.technical')));
    var dl = el('dl');
    function row(name, value, code) {
      dl.appendChild(el('dt', null, name));
      var dd = el('dd');
      dd.appendChild(code ? el('code', null, value) : document.createTextNode(value));
      dl.appendChild(dd);
    }
    row(T('card.version'), addon.version);
    row(T('dialog.interface'), addon.interface, true);
    row(T('dialog.files'), String(addon.files));
    row(T('card.size'), size(addon.zip.bytes));
    row(T('dialog.checksum'), addon.zip.sha256, true);
    box.appendChild(dl);
    return box;
  }

  function renderPreview(id) {
    var addon = findAddon(id);
    if (!addon) { return; }
    stopSpeech();
    var title = pick(addon.title);
    $('preview-title').textContent = title;
    var iconBox = $('preview-icon');
    iconBox.textContent = '';
    iconBox.className = 'preview-icon frame frame-' + (addon.featured ? 'featured' : addon.group);
    iconBox.appendChild(icon(addon.icon, 'icon icon-lg'));
    var badges = $('preview-badge');
    badges.textContent = '';
    badges.appendChild(badge(addon.group));
    if (addon.featured) { badges.appendChild(el('span', 'badge badge-featured', T('card.featured'))); }

    var body = $('preview-body');
    body.textContent = '';
    var does = section(T('dialog.does'));
    does.appendChild(el('p', 'pv-p', pick(addon.description)));
    if (addon.note) { does.appendChild(el('p', 'pv-p pv-help', pick(addon.note))); }
    body.appendChild(does);
    body.appendChild(hearing(addon));
    body.appendChild(keysTable(addon));
    body.appendChild(commands(addon));

    var stateBox = section(T('dialog.state'));
    stateBox.appendChild(el('p', 'pv-p', pick(addon.status)));
    body.appendChild(stateBox);

    var req = section(T('dialog.requirements'));
    needs(addon).forEach(function (line) { req.appendChild(el('p', 'pv-p', line)); });
    body.appendChild(req);
    body.appendChild(technical(addon));

    var actions = el('p', 'pv-actions pv-final');
    var download = el('a', 'btn btn-gold');
    download.href = addon.zip.file;
    download.setAttribute('download', '');
    download.appendChild(icon('download'));
    download.appendChild(el('span', null, T('card.downloadFor', { name: title })));
    download.addEventListener('click', function () { showToast(title); });
    actions.appendChild(download);
    var source = el('a', 'btn btn-quiet');
    source.href = addon.links.readme;
    source.appendChild(icon('code'));
    source.appendChild(el('span', null, T('card.source')));
    actions.appendChild(source);
    body.appendChild(actions);
  }

  var opener = null;

  function openPreview(id, from) {
    opener = from || null;
    state.previewId = id;
    renderPreview(id);
    var dialog = $('preview');
    document.documentElement.classList.add('modal-open');
    if (typeof dialog.showModal === 'function') {
      if (!dialog.open) { dialog.showModal(); }
    } else {
      dialog.setAttribute('open', '');
    }
    $('preview-body').scrollTop = 0;
    $('preview-close').focus();
  }

  function closePreview() {
    var dialog = $('preview');
    var id = state.previewId;
    stopSpeech();
    state.previewId = null;
    document.documentElement.classList.remove('modal-open');
    if (typeof dialog.close === 'function') {
      if (dialog.open) { dialog.close(); }
    } else {
      dialog.removeAttribute('open');
    }
    // the cards are drawn again when the language changes: the button that opened the preview may be a new one
    var back = (opener && document.contains(opener)) ? opener : (id ? document.querySelector('[data-preview="' + id + '"]') : null);
    if (back) { back.focus(); }
    opener = null;
  }

  // ------------------------------------------------------------ speech

  function voiceFor(lang) {
    var voices = window.speechSynthesis.getVoices ? window.speechSynthesis.getVoices() : [];
    var want = SPEECH_LANG[lang].toLowerCase();
    var best = null;
    for (var i = 0; i < voices.length; i += 1) {
      var code = String(voices[i].lang || '').toLowerCase().replace('_', '-');
      if (code === want) { return voices[i]; }
      if (!best && code.slice(0, 2) === want.slice(0, 2)) { best = voices[i]; }
    }
    return best;
  }

  function markSpeaking(index) {
    var nodes = document.querySelectorAll('#screen-lines .screen-line');
    for (var i = 0; i < nodes.length; i += 1) {
      if (i === index) { nodes[i].classList.add('is-speaking'); } else { nodes[i].classList.remove('is-speaking'); }
    }
  }

  function setListenButton(on) {
    var button = $('listen');
    if (!button) { return; }
    button.textContent = '';
    button.appendChild(icon(on ? 'stop' : 'speaker'));
    button.appendChild(el('span', null, on ? T('dialog.stop') : T('dialog.listen')));
    button.setAttribute('aria-pressed', on ? 'true' : 'false');
  }

  function stopSpeech() {
    state.speaking = false;
    if ('speechSynthesis' in window) {
      try { window.speechSynthesis.cancel(); } catch (e) { /* nothing to stop */ }
    }
    markSpeaking(-1);
    setListenButton(false);
  }

  function toggleSpeech(lines) {
    if (state.speaking) { stopSpeech(); return; }
    state.speaking = true;
    setListenButton(true);
    var synth = window.speechSynthesis;
    try { synth.cancel(); } catch (e) { /* nothing to cancel */ }
    var voice = voiceFor(state.lang);
    lines.forEach(function (line, index) {
      var utterance = new window.SpeechSynthesisUtterance(line);
      utterance.lang = SPEECH_LANG[state.lang];
      if (voice) { utterance.voice = voice; }
      utterance.onstart = function () { if (state.speaking) { markSpeaking(index); } };
      utterance.onend = function () { if (index === lines.length - 1) { stopSpeech(); } };
      utterance.onerror = function () { if (index === lines.length - 1) { stopSpeech(); } };
      synth.speak(utterance);
    });
  }

  // -------------------------------------------------------------- start

  function start() {
    var dialog = $('preview');
    $('preview-close').addEventListener('click', closePreview);
    dialog.addEventListener('cancel', function (event) { event.preventDefault(); closePreview(); });
    dialog.addEventListener('click', function (event) { if (event.target === dialog) { closePreview(); } });
    $('download-all').addEventListener('click', function () { showToast(T('toast.all')); });

    var buttons = document.querySelectorAll('.lang-btn');
    for (var i = 0; i < buttons.length; i += 1) {
      buttons[i].addEventListener('click', function (event) {
        setLanguage(event.currentTarget.getAttribute('data-lang'), true);
      });
    }
    if ('speechSynthesis' in window && window.speechSynthesis.addEventListener) {
      window.speechSynthesis.addEventListener('voiceschanged', function () { /* voices are looked up when listening */ });
    }
    setLanguage(detectLanguage(), false);
  }

  window.WVA_APP = { setLanguage: setLanguage, state: state, T: T };
  if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', start); } else { start(); }
})();
