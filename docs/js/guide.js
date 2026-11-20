// The guide page: every addon in one linear page, in the language of the reader: what it does, its keys, its commands.
// The data is the one of the download page (data.js, built from tools/catalog.json); the few words of this page are here.
(function () {
  'use strict';

  var LANGS = ['fr', 'en', 'de'];
  var DATA = window.WVA;
  var state = { lang: 'en' };

  var GW = {
    en: {
      title: 'WowVision addons: the guide',
      description: 'All the WowVision addons for WoW: Forever in one page: what each one does, its keys and its commands.',
      skip: 'Skip to the guide',
      language: 'Language',
      home: 'WowVision × Forever',
      back: 'Back to the download page',
      repo: 'Source code and issues on GitHub',
      top: 'Back to the top',
      changed: 'Language: English',
      h1: 'The WowVision addons for WoW: Forever, in one page',
      intro: 'Free addons for blind and visually impaired players, made to work with the WowVision screen reader addon. Each one changes none of WowVision\'s files, so a WowVision update does not remove it. Install: copy the folder of each addon into Interface, AddOns, then type /reload in the game. The download page has each addon as a .zip, or all of them in one.',
      basics: 'The basics',
      basics1: 'WowVision\'s menu: /wv or Shift+F1.',
      basics2: 'To see or change any key below: /wv, then Interface, then Bindings. Each key is listed there under the name given here. WowVision refuses two actions on one key: if a key is taken, give the other action another key first.',
      basics3: 'For each addon, "Needs" is what must be installed; "Works with" is the other addon it relies on or completes: without it, the part that concerns it does nothing.',
      glance: 'All the keys at a glance',
      glanceNote: 'In the order of the addons below.',
      active: 'The addons',
      merged: 'Merged into WowVision',
      mergedNote: 'These were proposed to WowVision and accepted: depending on your WowVision version, the extension is no longer needed (it steps aside by itself).',
      tool: 'A tool',
      keys: 'Keys',
      commands: 'Commands',
      needs: 'Needs',
      worksWith: 'Works with',
      state: 'State in the game',
      tests: 'offline tests',
      usefulSetting: 'A useful WowVision setting for combat',
      setting: 'The G key (interact with target): so that it attacks an enemy you targeted in combat and only loots or gathers afterwards, set "Soft Targeting With a Hard Target" to "Only without an attackable hard target" in WowVision\'s Targeting menu (not "Always").',
      german: 'The German texts are a translation by the author, not checked by a native speaker.',
      none: 'No key: it works by itself or by command.',
      nothing: 'nothing else'
    },
    fr: {
      title: 'Addons WowVision : le guide',
      description: 'Tous les addons WowVision pour WoW: Forever sur une page : ce que fait chacun, ses touches et ses commandes.',
      skip: 'Aller au guide',
      language: 'Langue',
      home: 'WowVision × Forever',
      back: 'Retour à la page de téléchargement',
      repo: 'Code source et suggestions sur GitHub',
      top: 'Retour en haut',
      changed: 'Langue : français',
      h1: 'Les addons WowVision pour WoW: Forever, sur une page',
      intro: 'Des addons gratuits pour les joueurs aveugles et malvoyants, faits pour fonctionner avec l\'addon de lecture d\'écran WowVision. Aucun ne modifie un fichier de WowVision : une mise à jour de WowVision ne l\'efface pas. Installer : copier le dossier de chaque addon dans Interface, AddOns, puis taper /reload dans le jeu. La page de téléchargement propose chaque addon en .zip, ou tous en un seul.',
      basics: 'Les bases',
      basics1: 'Le menu de WowVision : /wv ou Maj+F1.',
      basics2: 'Pour voir ou changer une touche ci-dessous : /wv, puis Interface, puis Raccourcis. Chaque touche y est listée sous le nom donné ici. WowVision refuse deux actions sur la même touche : si une touche est prise, donnez d\'abord une autre touche à l\'autre action.',
      basics3: 'Pour chaque addon, « Nécessite » est ce qu\'il faut installer ; « Travaille avec » est l\'autre addon dont il se sert ou qu\'il complète : sans lui, la partie qui le concerne ne fait rien.',
      glance: 'Toutes les touches d\'un coup d\'œil',
      glanceNote: 'Dans l\'ordre des addons ci-dessous.',
      active: 'Les addons',
      merged: 'Intégrés à WowVision',
      mergedNote: 'Ceux-ci ont été proposés à WowVision et acceptés : selon votre version de WowVision, l\'extension n\'est plus nécessaire (elle s\'efface toute seule).',
      tool: 'Un outil',
      keys: 'Touches',
      commands: 'Commandes',
      needs: 'Nécessite',
      worksWith: 'Travaille avec',
      state: 'État en jeu',
      tests: 'tests hors jeu',
      usefulSetting: 'Un réglage de WowVision utile en combat',
      setting: 'La touche G (interagir avec la cible) : pour qu\'elle attaque un ennemi ciblé en combat et ne ramasse ou ne récolte qu\'ensuite, réglez « Ciblage doux avec une cible principale » sur « Seulement sans cible principale attaquable » dans le menu Ciblage de WowVision (et non « Toujours »).',
      german: 'Les textes allemands sont une traduction de l\'auteur, non vérifiée par un germanophone.',
      none: 'Pas de touche : elle agit seule ou par commande.',
      nothing: 'rien d\'autre'
    },
    de: {
      title: 'WowVision-Addons: der Leitfaden',
      description: 'Alle WowVision-Addons für WoW: Forever auf einer Seite: was jedes tut, seine Tasten und seine Befehle.',
      skip: 'Zum Leitfaden springen',
      language: 'Sprache',
      home: 'WowVision × Forever',
      back: 'Zurück zur Download-Seite',
      repo: 'Quellcode und Probleme auf GitHub',
      top: 'Zurück nach oben',
      changed: 'Sprache: Deutsch',
      h1: 'Die WowVision-Addons für WoW: Forever auf einer Seite',
      intro: 'Kostenlose Addons für blinde und sehbehinderte Spieler, gemacht für das Screenreader-Addon WowVision. Keines ändert eine Datei von WowVision, ein Update von WowVision entfernt sie also nicht. Installieren: den Ordner jedes Addons nach Interface, AddOns kopieren, dann im Spiel /reload eingeben. Die Download-Seite bietet jedes Addon als .zip oder alle in einem.',
      basics: 'Die Grundlagen',
      basics1: 'Das Menü von WowVision: /wv oder Umschalt+F1.',
      basics2: 'Um eine der folgenden Tasten zu sehen oder zu ändern: /wv, dann Interface, dann Tastenbelegung. Jede Taste steht dort unter dem hier genannten Namen. WowVision lehnt zwei Aktionen auf einer Taste ab: Ist eine Taste belegt, geben Sie der anderen Aktion zuerst eine andere Taste.',
      basics3: 'Bei jedem Addon ist „Benötigt“ das, was installiert sein muss; „Arbeitet mit“ ist das andere Addon, auf das es sich stützt oder das es ergänzt: ohne dieses tut der betreffende Teil nichts.',
      glance: 'Alle Tasten auf einen Blick',
      glanceNote: 'In der Reihenfolge der Addons unten.',
      active: 'Die Addons',
      merged: 'In WowVision übernommen',
      mergedNote: 'Diese wurden WowVision vorgeschlagen und angenommen: je nach Version von WowVision wird die Erweiterung nicht mehr gebraucht (sie tritt von selbst zurück).',
      tool: 'Ein Werkzeug',
      keys: 'Tasten',
      commands: 'Befehle',
      needs: 'Benötigt',
      worksWith: 'Arbeitet mit',
      state: 'Stand im Spiel',
      tests: 'Tests außerhalb des Spiels',
      usefulSetting: 'Eine nützliche Einstellung von WowVision für den Kampf',
      setting: 'Die Taste G (mit dem Ziel interagieren): Damit sie im Kampf einen anvisierten Gegner angreift und erst danach plündert oder sammelt, stellen Sie im Zielmenü von WowVision „Weiches Zielen mit festem Ziel“ auf „Nur ohne angreifbares festes Ziel“ (nicht „Immer“).',
      german: 'Die deutschen Texte sind eine Übersetzung des Autors, nicht von Muttersprachlern geprüft.',
      none: 'Keine Taste: Es arbeitet von selbst oder per Befehl.',
      nothing: 'nichts weiter'
    }
  };

  function $(id) { return document.getElementById(id); }

  function el(tag, className, text) {
    var node = document.createElement(tag);
    if (className) { node.className = className; }
    if (text !== undefined && text !== null) { node.textContent = text; }
    return node;
  }

  function T(key) {
    var table = GW[state.lang] || GW.en;
    return table[key] !== undefined ? table[key] : GW.en[key];
  }

  function pick(map) {
    if (!map) { return ''; }
    return map[state.lang] !== undefined ? map[state.lang] : map.en;
  }

  function store(key, value) {
    try {
      if (value === undefined) { return window.localStorage.getItem(key); }
      window.localStorage.setItem(key, value);
    } catch (e) { /* storage blocked: the language is just not remembered */ }
    return null;
  }

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

  function list(items) {
    var ul = el('ul', 'guide-list');
    items.forEach(function (node) {
      var li = el('li');
      li.appendChild(node);
      ul.appendChild(li);
    });
    return ul;
  }

  function textNode(text) { return document.createTextNode(text); }

  function keyLine(item, addon) {
    var span = el('span');
    span.appendChild(el('kbd', null, pick(item.keys)));
    span.appendChild(textNode(' : ' + pick(item.does)));
    if (addon) { span.appendChild(textNode(' (' + pick(addon.title) + ')')); }
    return span;
  }

  function nameOf(id) {
    for (var i = 0; i < DATA.addons.length; i += 1) {
      if (DATA.addons[i].id === id) { return pick(DATA.addons[i].title); }
    }
    return id;
  }

  function addonSection(addon, level) {
    var section = el('section', 'guide-addon');
    section.id = addon.id;
    section.setAttribute('aria-labelledby', addon.id + '-title');
    var title = el('h' + level, null);
    title.id = addon.id + '-title';
    title.appendChild(textNode(pick(addon.title)));
    title.appendChild(el('span', 'guide-folder', ' (' + addon.id + ')'));
    section.appendChild(title);
    section.appendChild(el('p', null, pick(addon.tagline)));

    var sub = level + 1;
    section.appendChild(el('h' + sub, 'guide-sub', T('keys')));
    if (addon.keys && addon.keys.length) {
      section.appendChild(list(addon.keys.map(function (item) { return keyLine(item, null); })));
    } else {
      section.appendChild(el('p', null, T('none')));
    }
    var commands = (addon.commands && (addon.commands[state.lang] && addon.commands[state.lang].length ? addon.commands[state.lang] : addon.commands.en)) || [];
    if (commands.length) {
      section.appendChild(el('h' + sub, 'guide-sub', T('commands')));
      section.appendChild(list(commands.map(function (command) { return el('code', null, command); })));
    }
    var line = [];
    line.push(T('needs') + ' : ' + (addon.requires && addon.requires.length ? addon.requires.join(', ') : T('nothing')));
    if (addon.optional && addon.optional.length) { line.push(T('worksWith') + ' : ' + addon.optional.join(', ')); }
    section.appendChild(el('p', 'guide-needs', line.join(' · ')));
    if (addon.note) { section.appendChild(el('p', 'guide-needs', pick(addon.note))); }
    section.appendChild(el('p', 'guide-state', T('state') + ' : ' + pick(addon.status)));
    return section;
  }

  function render() {
    var main = $('guide');
    while (main.firstChild) { main.removeChild(main.firstChild); }
    main.appendChild(el('h1', null, T('h1')));
    main.appendChild(el('p', 'guide-intro', T('intro')));

    main.appendChild(el('h2', null, T('basics')));
    main.appendChild(list([textNode(T('basics1')), textNode(T('basics2')), textNode(T('basics3'))]));

    var shown = DATA.addons.filter(function (addon) { return addon.group !== 'retired'; });

    main.appendChild(el('h2', null, T('glance')));
    main.appendChild(el('p', null, T('glanceNote')));
    var glance = [];
    shown.filter(function (addon) { return addon.group === 'active'; }).forEach(function (addon) {
      (addon.keys || []).forEach(function (item) { glance.push(keyLine(item, addon)); });
    });
    main.appendChild(list(glance));

    var groups = [
      { id: 'active', heading: T('active'), note: null },
      { id: 'merged', heading: T('merged'), note: T('mergedNote') },
      { id: 'tool', heading: T('tool'), note: null }
    ];
    groups.forEach(function (group) {
      var members = shown.filter(function (addon) { return addon.group === group.id; });
      if (!members.length) { return; }
      main.appendChild(el('h2', null, group.heading));
      if (group.note) { main.appendChild(el('p', null, group.note)); }
      members.forEach(function (addon) { main.appendChild(addonSection(addon, 3)); });
    });

    main.appendChild(el('h2', null, T('usefulSetting')));
    main.appendChild(el('p', null, T('setting')));
    main.appendChild(el('p', 'guide-small', T('german')));
  }

  function applyStatic() {
    document.documentElement.lang = state.lang;
    document.title = T('title');
    var description = document.querySelector('meta[name="description"]');
    if (description) { description.setAttribute('content', T('description')); }
    $('skip').textContent = T('skip');
    $('lang-label').textContent = T('language');
    $('home-link').textContent = T('home');
    $('back-link').textContent = T('back');
    $('repo-link').textContent = T('repo');
    $('top-link').textContent = T('top');
    $('repo-link').setAttribute('href', DATA.repoUrl);
    var buttons = document.querySelectorAll('.lang-btn');
    for (var i = 0; i < buttons.length; i += 1) {
      buttons[i].setAttribute('aria-pressed', buttons[i].getAttribute('data-lang') === state.lang ? 'true' : 'false');
    }
  }

  function setLanguage(lang, byUser) {
    state.lang = lang;
    if (byUser) { store('wva-lang', lang); }
    applyStatic();
    render();
    if (byUser) {
      $('announce').textContent = '';
      window.setTimeout(function () { $('announce').textContent = T('changed'); }, 50);
      try {
        var url = new URL(window.location.href);
        url.searchParams.set('lang', lang);
        window.history.replaceState(null, '', url.toString());
      } catch (e) { /* an old browser: the language is kept anyway */ }
    }
  }

  function start() {
    var buttons = document.querySelectorAll('.lang-btn');
    for (var i = 0; i < buttons.length; i += 1) {
      buttons[i].addEventListener('click', function (event) {
        setLanguage(event.currentTarget.getAttribute('data-lang'), true);
      });
    }
    // the links back keep the language
    setLanguage(detectLanguage(), false);
  }

  if (DATA && DATA.addons) { start(); }
}());
