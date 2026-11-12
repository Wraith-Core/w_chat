(() => {
  const RES = 'w_chat';

  // 1.2.0: the board kit's textures and faces are set by main.js; the store theme's frame textures are gone.

  // Elements
  const rootEl = document.getElementById('chat-root');
  const messagesWrap = document.getElementById('chat-messages-wrap');
  const messagesEl = document.getElementById('chat-messages');
  const inputWrapper = document.getElementById('chat-input-wrapper');
  const inputEl = document.getElementById('chat-input');
  const submitBtn = document.getElementById('chat-submit-btn');
  const submitLabel = document.getElementById('chat-submit-label');
  const suggestionsTitle = document.getElementById('suggestions-title');
  const suggestionsHint = document.getElementById('suggestions-hint');
  const channelName = document.getElementById('channel-name');
  // the badge's word takes its own direction, so an Arabic channel name in an English chat is
  // never tracked or upper-cased (the theme's label role reads --w-label-track per dir)
  const setChannelName = (text) => {
    channelName.textContent = text;
    channelName.dir = /[؀-ۿ]/.test(text) ? 'rtl' : 'ltr';
  };
  const suggestionsBox = document.getElementById('suggestions-box');
  const suggestionsList = document.getElementById('suggestions-list');

  // State
  let isOpen = false;
  let fadeTimeout = 8500;
  let fadeTimer = null;
  let history = [];
  let historyIndex = -1;
  let suggestions = [];
  let filteredSuggestions = [];
  let selectedSuggestionIndex = -1;
  // 1.2.0: every word comes from the locales through SET_LOCALE (client/main.lua)
  let defaultChannelName = '';
  let channelWords = {};
  // notebook: the chat's own commands in plain words (say.<command>), the keys row's words
  let helpWords = {};
  let keyWords = {};
  const keysEl = document.getElementById('chat-keys');

  // Post to Lua
  const post = (action, data = {}) => {
    return fetch(`https://${RES}/${action}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data)
    }).catch(() => {});
  };

  // ── Color Codes (^0 - ^9) & HTML Escaping ────────────────────────────────
  const escapeHtml = (str) => {
    if (!str) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  };

  // Black and white like Red Dead: a sender's colour codes keep their place in the line but not their
  // hue. The warm, loud codes (^1 red, ^2 green, ^3 yellow, ^8 dark red; ~r~ ~g~ ~y~ ~o~ ~e~ ...,
  // ~COLOR_RED~ ...) become paper in a heavier weight, the cool and grey ones (^4 ^5 ^6 ^9; ~b~ ~c~
  // ~p~ ~m~ ~u~ ~l~, ~COLOR_BLUE~ ...) dim paper. ^0 / ^7 / ^r, ~s~ ~w~ ~q~ and ~COLOR_WHITE~ go back
  // to the line's own paper; ~n~ breaks the line; ~h~ is the heavier weight. Spans never nest.
  const CODE_RE = /\^([0-9r])|~(COLOR_[A-Z0-9_]+|[a-zA-Z])~/g;
  const CARET_TONE = { 1: 'tone-hi', 2: 'tone-hi', 3: 'tone-hi', 8: 'tone-hi', 4: 'tone-dim', 5: 'tone-dim', 6: 'tone-dim', 9: 'tone-dim' };
  const TILDE_DIM = new Set(['b', 'c', 'p', 'm', 'u', 'l']);
  const toneOf = (caret, tilde) => {
    if (caret !== undefined) return CARET_TONE[caret] || null;
    if (tilde === 'n') return 'br';
    if (/^COLOR_/.test(tilde)) {
      if (/WHITE|DEFAULT|^COLOR_PURE/.test(tilde)) return null;
      return /BLUE|PURPLE|GREY|GRAY|BLACK|PINK|CYAN|TEAL/.test(tilde) ? 'tone-dim' : 'tone-hi';
    }
    const k = tilde.toLowerCase();
    if (k === 's' || k === 'w' || k === 'q') return null;
    return TILDE_DIM.has(k) ? 'tone-dim' : 'tone-hi';
  };
  const formatMessageText = (raw) => {
    const safe = escapeHtml(raw);
    let out = '';
    let last = 0;
    let open = false;
    let m;
    CODE_RE.lastIndex = 0;
    while ((m = CODE_RE.exec(safe))) {
      out += safe.slice(last, m.index);
      last = CODE_RE.lastIndex;
      const tone = toneOf(m[1], m[2]);
      if (tone === 'br') { out += '<br>'; continue; }
      if (open) { out += '</span>'; open = false; }
      if (tone) { out += `<span class="${tone}">`; open = true; }
    }
    out += safe.slice(last);
    if (open) out += '</span>';
    return out;
  };

  // a line another script sent in red (chat:addMessage with color {255, 0, 0}) is an error. The Lua
  // side already says so with tone = 'error'; a payload forwarded raw is read here the same way.
  const isRed = (c) => {
    let rgb = null;
    if (Array.isArray(c)) rgb = c;
    else if (c && typeof c === 'object') rgb = [c.r, c.g, c.b];
    else if (typeof c === 'string') {
      const h = c.match(/^#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})/i);
      const r = c.match(/rgba?\(\s*(\d+)[\s,]+(\d+)[\s,]+(\d+)/i);
      if (h) rgb = [parseInt(h[1], 16), parseInt(h[2], 16), parseInt(h[3], 16)];
      else if (r) rgb = [r[1], r[2], r[3]];
    }
    if (!rgb) return false;
    const [r, g, b] = rgb.map(Number);
    return r >= 150 && g <= 90 && b <= 90;
  };

  // ── Wake & Fade Timer ────────────────────────────────────────────────────
  const wakeChat = () => {
    messagesWrap.classList.remove('is-idle');
    if (fadeTimer) {
      clearTimeout(fadeTimer);
      fadeTimer = null;
    }
    if (!isOpen) {
      fadeTimer = setTimeout(() => {
        if (!isOpen) {
          messagesWrap.classList.add('is-idle');
        }
      }, fadeTimeout);
    }
  };

  // ── Append Message ───────────────────────────────────────────────────────
  const addMessage = (data) => {
    const card = document.createElement('div');
    card.className = 'chat-message';
    if (data.channel) card.dataset.channel = String(data.channel);
    // the one red is a mark, never a colour of the line: an error takes the ribbon (style.css)
    if (data.tone === 'error' || (String(data.channel || 'system') === 'system' && isRed(data.color))) card.dataset.tone = 'error';

    const meta = document.createElement('div');
    meta.className = 'chat-message-meta';

    // Badge: the channel's word (1.2.0: no Font Awesome glyph; the payload's icon is still accepted and unused)
    const badge = document.createElement('span');
    badge.className = 'chat-badge';
    badge.textContent = data.tag || 'OOC';
    badge.dir = /[؀-ۿ]/.test(badge.textContent) ? 'rtl' : 'ltr';
    meta.appendChild(badge);

    // Rank Badge (Staff / VIP)
    if (data.rank && data.rank.label) {
      const rankBadge = document.createElement('span');
      rankBadge.className = 'chat-badge chat-rank-badge';
      // owner 2026-11-12: one look for every rank; a VIP tier's own colours (payload bgColor/color) are not drawn
      rankBadge.textContent = data.rank.label;
      meta.appendChild(rankBadge);
    }

    // Sender Name
    if (data.sender) {
      const sender = document.createElement('span');
      sender.className = 'chat-sender';
      sender.textContent = data.sender + (data.id ? ` [${data.id}]` : '');
      // owner 2026-11-12: every name in the one ink; a store-bought colour (payload nameColor) is not drawn
      meta.appendChild(sender);
    }

    // Time
    const time = document.createElement('span');
    time.className = 'chat-time';
    time.textContent = data.time || '';
    meta.appendChild(time);

    card.appendChild(meta);

    // Body
    const body = document.createElement('div');
    body.className = 'chat-body';
    body.dir = 'auto';
    body.innerHTML = formatMessageText(data.message || '');
    card.appendChild(body);

    messagesEl.appendChild(card);

    // Cap at 100 messages
    while (messagesEl.children.length > 100) {
      messagesEl.removeChild(messagesEl.firstChild);
    }

    // Auto scroll
    messagesEl.scrollTop = messagesEl.scrollHeight;

    wakeChat();
  };

  // ── Open / Close Chat ────────────────────────────────────────────────────
  const openChat = () => {
    isOpen = true;
    inputWrapper.style.display = 'flex';
    inputEl.value = '';
    historyIndex = -1;
    wakeChat();
    updateChannelIndicator('');
    closeSuggestions();
    setTimeout(() => {
      inputEl.focus();
    }, 20);
  };

  const closeChat = (shouldPost = true) => {
    isOpen = false;
    inputWrapper.style.display = 'none';
    closeSuggestions();
    wakeChat();
    if (shouldPost) {
      post('closeChat');
    }
  };

  // ── Channel Badge Detection on Typing ────────────────────────────────────
  // the channel the line will go to: its glyph and its name. The badge's colours are the
  // theme's (style.css); a channel is told by its word and glyph, not by a hue.
  // 1.2.0: the channel's word is the locale's tag (SET_LOCALE channels.<key>), the command itself when missing
  const CHANNELS = [
    [['/local', '/l'], 'local'],
    [['/me'], 'me'],
    [['/do'], 'do'],
    [['/w', '/whisper'], 'whisper'],
    [['/s', '/shout'], 'shout'],
    [['/try'], 'try'],
    [['/roll'], 'roll'],
    [['/pm'], 'pm'],
    [['/police'], 'police'],
    [['/medic'], 'medic'],
    [['/ann', '/announce'], 'admin'],
  ];

  const updateChannelIndicator = (val) => {
    // 1.1.11 (owner): the line runs the way its first letter reads - a /command or English left to right,
    // Arabic right to left; empty keeps the placeholder on the language's side
    inputEl.dir = val.trim() === '' ? document.documentElement.dir || 'rtl' : 'auto';
    const trimmed = val.trimStart();
    const words = trimmed.split(' ');
    const cmd = words[0].toLowerCase();
    const hit = CHANNELS.find(([cmds]) => cmds.includes(cmd));
    setChannelName(hit ? (channelWords[hit[1]] || cmd) : defaultChannelName);
  };

  // ── Suggestions Autocomplete ─────────────────────────────────────────────
  const updateSuggestions = (text) => {
    if (!text.startsWith('/')) {
      closeSuggestions();
      return;
    }

    const typedCmd = text.split(' ')[0].toLowerCase();
    filteredSuggestions = suggestions.filter((s) => s.name.toLowerCase().startsWith(typedCmd));

    if (filteredSuggestions.length === 0) {
      closeSuggestions();
      return;
    }

    selectedSuggestionIndex = 0;
    renderSuggestions();
    suggestionsBox.style.display = 'flex';
    renderKeys();
  };

  const closeSuggestions = () => {
    suggestionsBox.style.display = 'none';
    filteredSuggestions = [];
    selectedSuggestionIndex = -1;
    renderKeys();
  };

  // 1.2.0: the kit's row (wf-row): the cursor is the paper band (is-here). The arrows and the mouse move the
  // same cursor, so Tab / Enter always take the row that shows the band; a click takes the clicked row.
  const markCursor = () => {
    Array.prototype.forEach.call(suggestionsList.children, (el, i) => {
      el.classList.toggle('is-here', i === selectedSuggestionIndex);
    });
    // keep the cursor row inside the list (the list only: the page itself never scrolls)
    const here = suggestionsList.children[selectedSuggestionIndex];
    if (here) {
      const top = here.offsetTop - suggestionsList.offsetTop;
      const bottom = top + here.offsetHeight;
      if (top < suggestionsList.scrollTop) suggestionsList.scrollTop = top;
      else if (bottom > suggestionsList.scrollTop + suggestionsList.clientHeight) suggestionsList.scrollTop = bottom - suggestionsList.clientHeight;
    }
  };

  const renderSuggestions = () => {
    suggestionsList.innerHTML = '';
    filteredSuggestions.forEach((sug, idx) => {
      const item = document.createElement('div');
      item.className = 'wf-row suggestion-item' + (idx === selectedSuggestionIndex ? ' is-here' : '');

      const main = document.createElement('div');
      main.className = 'wf-row-main';

      // the command and its parameters read left to right as one unit, on the language's side
      const top = document.createElement('div');
      top.className = 'wf-row-name suggestion-top';

      const cmdSpan = document.createElement('bdi');
      cmdSpan.className = 'suggestion-cmd';
      cmdSpan.dir = 'ltr';
      cmdSpan.textContent = sug.name;
      top.appendChild(cmdSpan);

      if (sug.params && sug.params.length > 0) {
        const paramsSpan = document.createElement('span');
        paramsSpan.className = 'suggestion-params';
        sug.params.forEach((p) => {
          const tag = document.createElement('bdi');
          tag.className = 'suggestion-param-tag';
          tag.textContent = `<${p.name || ''}>`;
          paramsSpan.appendChild(tag);
        });
        top.appendChild(paramsSpan);
      }

      // notebook: what the command does, on the same line after a dash - the chat's own commands in the
      // player's language (say.<command>), any other resource's command with the help text it sent
      const said = helpWords[String(sug.name || '').replace(/^\//, '').toLowerCase()] || sug.help;
      if (said) {
        const help = document.createElement('span');
        help.className = 'suggestion-help';
        help.dir = 'auto';
        help.textContent = said;
        top.appendChild(document.createTextNode(' '));
        const dash = document.createElement('span');
        dash.className = 'suggestion-dash';
        dash.textContent = '—';
        top.appendChild(dash);
        top.appendChild(help);
      }

      main.appendChild(top);
      item.appendChild(main);

      item.addEventListener('mouseenter', () => {
        if (selectedSuggestionIndex !== idx) {
          selectedSuggestionIndex = idx;
          markCursor();
        }
      });
      item.addEventListener('click', () => {
        applySuggestion(sug);
      });

      suggestionsList.appendChild(item);
    });
    markCursor();
  };

  // the hint under the list's title: the locale's line with {tab} / {enter} drawn as key caps
  const setHint = (text) => {
    suggestionsHint.innerHTML = '';
    String(text || '').split(/(\{tab\}|\{enter\})/).forEach((part) => {
      if (part === '{tab}' || part === '{enter}') {
        const k = document.createElement('kbd');
        k.className = 'chat-key';
        k.textContent = part === '{tab}' ? 'Tab' : 'Enter';
        suggestionsHint.appendChild(k);
      } else if (part) {
        suggestionsHint.appendChild(document.createTextNode(part));
      }
    });
  };

  // notebook: the keys row under the line. With the commands list open the keys pick a command instead.
  const renderKeys = () => {
    if (!keysEl) return;
    keysEl.innerHTML = '';
    const listOpen = filteredSuggestions.length > 0;
    const parts = listOpen
      ? [[['Tab', 'Enter'], keyWords.pick], [['Esc'], keyWords.close]]
      : [[['Enter'], keyWords.send], [['Esc'], keyWords.close], [['↑'], keyWords.last]];
    parts.forEach(([caps, word]) => {
      if (!word) return;
      const part = document.createElement('span');
      caps.forEach((cap) => {
        const k = document.createElement('kbd');
        k.className = 'chat-key';
        k.textContent = cap;
        part.appendChild(k);
      });
      part.appendChild(document.createTextNode(word));
      keysEl.appendChild(part);
    });
    // the list's own hint ('Pick with Tab or Enter') says the same as the keys row: shown only without the row
    suggestionsHint.style.display = keysEl.childElementCount > 0 ? 'none' : '';
  };

  const applySuggestion = (sug) => {
    inputEl.value = sug.name + ' ';
    inputEl.focus();
    updateChannelIndicator(inputEl.value);
    closeSuggestions();
  };

  // ── Submit Message ───────────────────────────────────────────────────────
  const submitMessage = () => {
    const raw = inputEl.value.trim();
    if (raw.length > 0) {
      history.unshift(raw);
      if (history.length > 30) history.pop();
      post('chatResult', { message: raw });
    } else {
      closeChat(true);
    }
  };

  // ── Key Handlers ─────────────────────────────────────────────────────────
  inputEl.addEventListener('input', () => {
    const val = inputEl.value;
    updateChannelIndicator(val);
    updateSuggestions(val);
  });

  inputEl.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      if (filteredSuggestions.length > 0 && selectedSuggestionIndex >= 0 && inputEl.value.trim().split(' ').length === 1) {
        applySuggestion(filteredSuggestions[selectedSuggestionIndex]);
      } else {
        submitMessage();
      }
    } else if (e.key === 'Escape') {
      e.preventDefault();
      closeChat(true);
    } else if (e.key === 'Tab') {
      e.preventDefault();
      if (filteredSuggestions.length > 0 && selectedSuggestionIndex >= 0) {
        applySuggestion(filteredSuggestions[selectedSuggestionIndex]);
      }
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      if (filteredSuggestions.length > 0) {
        selectedSuggestionIndex = (selectedSuggestionIndex - 1 + filteredSuggestions.length) % filteredSuggestions.length;
        renderSuggestions();
      } else if (history.length > 0) {
        if (historyIndex < history.length - 1) {
          historyIndex++;
          inputEl.value = history[historyIndex];
          updateChannelIndicator(inputEl.value);
        }
      }
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      if (filteredSuggestions.length > 0) {
        selectedSuggestionIndex = (selectedSuggestionIndex + 1) % filteredSuggestions.length;
        renderSuggestions();
      } else if (historyIndex > 0) {
        historyIndex--;
        inputEl.value = history[historyIndex];
        updateChannelIndicator(inputEl.value);
      } else if (historyIndex === 0) {
        historyIndex = -1;
        inputEl.value = '';
        updateChannelIndicator('');
      }
    }
  });

  submitBtn.addEventListener('click', submitMessage);

  // ── NUI Messages Listener ────────────────────────────────────────────────
  window.addEventListener('message', (event) => {
    const msg = event.data || {};

    switch (msg.action) {
      case 'OPEN_CHAT':
        openChat();
        break;

      case 'CLOSE_CHAT':
        closeChat(false);
        break;

      case 'ADD_MESSAGE':
        if (msg.data) addMessage(msg.data);
        break;

      case 'CLEAR_CHAT':
        messagesEl.innerHTML = '';
        break;

      case 'ADD_SUGGESTION':
        if (msg.data && msg.data.name) {
          // Remove old with same name if exists
          suggestions = suggestions.filter((s) => s.name.toLowerCase() !== msg.data.name.toLowerCase());
          suggestions.push(msg.data);
        }
        break;

      case 'REMOVE_SUGGESTION':
        if (msg.data && msg.data.name) {
          suggestions = suggestions.filter((s) => s.name.toLowerCase() !== msg.data.name.toLowerCase());
        }
        break;

      case 'SET_LOCALE':
        if (msg.data) {
          if (msg.data.isRTL !== undefined) {
            document.documentElement.dir = msg.data.isRTL ? 'rtl' : 'ltr';
            document.documentElement.lang = msg.data.locale || (msg.data.isRTL ? 'ar' : 'en');
            rootEl.classList.toggle('is-rtl', !!msg.data.isRTL);
            if (inputEl.value.trim() === '') inputEl.dir = msg.data.isRTL ? 'rtl' : 'ltr';
          }
          if (msg.data.placeholder) inputEl.placeholder = msg.data.placeholder;
          // 1.2.0: the words that were written into the page now come from the locales
          if (msg.data.send) { submitLabel.textContent = msg.data.send; submitBtn.title = msg.data.send; }
          if (msg.data.suggestionsTitle) suggestionsTitle.textContent = msg.data.suggestionsTitle;
          if (msg.data.suggestionsHint) setHint(msg.data.suggestionsHint);
          if (msg.data.channels && typeof msg.data.channels === 'object') channelWords = msg.data.channels;
          if (msg.data.channelGeneral) {
            defaultChannelName = msg.data.channelGeneral;
            setChannelName(defaultChannelName);
          }
          if (msg.data.fadeTimeout) fadeTimeout = msg.data.fadeTimeout;
          if (msg.data.helps && typeof msg.data.helps === 'object') helpWords = msg.data.helps;
          if (msg.data.keys && typeof msg.data.keys === 'object') { keyWords = msg.data.keys; renderKeys(); }
        }
        break;
    }
  });
})();
