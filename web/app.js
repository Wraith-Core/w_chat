(() => {
  const RES = 'w_chat';

  // ── Asset Bridge (matching w_creators) ──────────────────────────────────
  const ABS_BASE = new URL('.', document.baseURI).href;
  const tex = (p) => `url("${ABS_BASE}${p}")`;
  const UI_TEXTURES = [
    'crafting_highlight_t', 'crafting_highlight_b', 'crafting_highlight_l',
    'crafting_highlight_r', 'crafting_highlight_tl', 'crafting_highlight_tr',
    'crafting_highlight_bl', 'crafting_highlight_br', 'crafting_outline',
    'divider_line', 'list_item_h_line_narrow', 'selection_box_bg_1a',
    'selection_box_bg_1c', 'help_text_bg', 'toast_bg'
  ];
  for (const n of UI_TEXTURES) {
    document.documentElement.style.setProperty(`--tex-${n}`, tex(`tex/ui/${n}.png`));
  }

  // Elements
  const messagesWrap = document.getElementById('chat-messages-wrap');
  const messagesEl = document.getElementById('chat-messages');
  const inputWrapper = document.getElementById('chat-input-wrapper');
  const inputEl = document.getElementById('chat-input');
  const submitBtn = document.getElementById('chat-submit-btn');
  const channelBadge = document.getElementById('channel-badge');
  const channelIcon = document.getElementById('channel-icon');
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
  let defaultChannelName = 'عام';

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

  // a configured badge colour: '#rgb' / '#rrggbb' / '#rrggbbaa' only (it goes into a style property)
  const isColour = (v) => typeof v === 'string' && /^#(?:[0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(v);

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

    // Badge
    const badge = document.createElement('span');
    badge.className = 'chat-badge';

    const icon = document.createElement('i');
    icon.className = `fa-solid ${data.icon || 'fa-comment'}`;
    badge.appendChild(icon);

    const tagText = document.createTextNode(` ${data.tag || 'OOC'}`);
    badge.appendChild(tagText);
    meta.appendChild(badge);

    // Rank Badge (Staff / VIP)
    if (data.rank && data.rank.label) {
      const rankBadge = document.createElement('span');
      rankBadge.className = 'chat-badge chat-rank-badge';
      // 1.1.2: a VIP tier (w_vip) wears its own band and ink; the staff ranks keep the paper band
      if (data.rank.tier && isColour(data.rank.bgColor) && isColour(data.rank.color)) {
        rankBadge.dataset.tier = String(data.rank.tier);
        rankBadge.style.setProperty('--rank-band', data.rank.bgColor);
        rankBadge.style.setProperty('--rank-ink', data.rank.color);
      }

      const rIcon = document.createElement('i');
      rIcon.className = `fa-solid ${data.rank.icon || 'fa-shield-halved'}`;
      rankBadge.appendChild(rIcon);

      const rText = document.createTextNode(` ${data.rank.label}`);
      rankBadge.appendChild(rText);
      meta.appendChild(rankBadge);
    }

    // Sender Name
    if (data.sender) {
      const sender = document.createElement('span');
      sender.className = 'chat-sender';
      sender.textContent = data.sender + (data.id ? ` [${data.id}]` : '');
      // 1.1.3: a name colour bought in the server store
      if (isColour(data.nameColor)) {
        sender.style.color = data.nameColor;
        sender.classList.add('chat-sender-store');
      }
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
  const CHANNELS = [
    [['/local', '/l'], 'fa-location-dot', 'محلي | Local'],
    [['/me'], 'fa-user', 'فعل | ME'],
    [['/do'], 'fa-eye', 'بيئة | DO'],
    [['/w', '/whisper'], 'fa-comment-dots', 'همس'],
    [['/s', '/shout'], 'fa-bullhorn', 'صراخ'],
    [['/try'], 'fa-dice', 'قرعة'],
    [['/roll'], 'fa-dice-d20', 'نرد'],
    [['/pm'], 'fa-paper-plane', 'خاص'],
    [['/police'], 'fa-shield-halved', 'الشرطة'],
    [['/medic'], 'fa-staff-snake', 'الإسعاف'],
    [['/ann', '/announce'], 'fa-crown', 'الإدارة'],
  ];

  const updateChannelIndicator = (val) => {
    const trimmed = val.trimStart();
    const words = trimmed.split(' ');
    const cmd = words[0].toLowerCase();
    const hit = CHANNELS.find(([cmds]) => cmds.includes(cmd));
    channelIcon.className = 'fa-solid ' + (hit ? hit[1] : 'fa-comments');
    setChannelName(hit ? hit[2] : defaultChannelName);
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
  };

  const closeSuggestions = () => {
    suggestionsBox.style.display = 'none';
    filteredSuggestions = [];
    selectedSuggestionIndex = -1;
  };

  const renderSuggestions = () => {
    suggestionsList.innerHTML = '';
    filteredSuggestions.forEach((sug, idx) => {
      const item = document.createElement('div');
      item.className = 'suggestion-item' + (idx === selectedSuggestionIndex ? ' is-selected' : '');

      const top = document.createElement('div');
      top.className = 'suggestion-top';

      const cmdSpan = document.createElement('span');
      cmdSpan.className = 'suggestion-cmd';
      cmdSpan.textContent = sug.name;
      top.appendChild(cmdSpan);

      if (sug.params && sug.params.length > 0) {
        const paramsSpan = document.createElement('span');
        paramsSpan.className = 'suggestion-params';
        sug.params.forEach((p) => {
          const tag = document.createElement('span');
          tag.className = 'suggestion-param-tag';
          tag.textContent = `<${p.name || ''}>`;
          paramsSpan.appendChild(tag);
        });
        top.appendChild(paramsSpan);
      }

      item.appendChild(top);

      if (sug.help) {
        const help = document.createElement('span');
        help.className = 'suggestion-help';
        help.textContent = sug.help;
        item.appendChild(help);
      }

      item.addEventListener('click', () => {
        applySuggestion(sug);
      });

      suggestionsList.appendChild(item);
    });
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
          }
          if (msg.data.placeholder) inputEl.placeholder = msg.data.placeholder;
          if (msg.data.channelGeneral) {
            defaultChannelName = msg.data.channelGeneral;
            setChannelName(defaultChannelName);
          }
          if (msg.data.fadeTimeout) fadeTimeout = msg.data.fadeTimeout;
        }
        break;
    }
  });
})();
