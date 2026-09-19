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

  const formatMessageText = (raw) => {
    let safe = escapeHtml(raw);
    // Replace color codes
    safe = safe.replace(/\^([1-9])/g, '<span class="color-$1">');
    safe = safe.replace(/\^0/g, '</span>');
    return safe;
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

    if (data.borderColor) card.style.setProperty('--msg-border', data.borderColor);

    const meta = document.createElement('div');
    meta.className = 'chat-message-meta';

    // Badge
    const badge = document.createElement('span');
    badge.className = 'chat-badge';
    if (data.bgColor) badge.style.setProperty('--badge-bg', data.bgColor);
    if (data.color) badge.style.setProperty('--badge-color', data.color);
    if (data.borderColor) badge.style.setProperty('--badge-border', data.borderColor);

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
      if (data.rank.bgColor) rankBadge.style.setProperty('--badge-bg', data.rank.bgColor);
      if (data.rank.color) rankBadge.style.setProperty('--badge-color', data.rank.color);
      if (data.rank.borderColor) rankBadge.style.setProperty('--badge-border', data.rank.borderColor);

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
      if (data.rank && data.rank.color) {
        sender.style.color = data.rank.color;
      }
      sender.textContent = data.sender + (data.id ? ` [${data.id}]` : '');
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
  const updateChannelIndicator = (val) => {
    const trimmed = val.trimStart();
    const words = trimmed.split(' ');
    const cmd = words[0].toLowerCase();

    if (cmd === '/local' || cmd === '/l') {
      channelBadge.style.color = '#E0E0E0';
      channelBadge.style.background = 'rgba(255, 255, 255, 0.12)';
      channelBadge.style.borderColor = 'rgba(255, 255, 255, 0.35)';
      channelIcon.className = 'fa-solid fa-location-dot';
      channelName.textContent = 'محلي | Local';
    } else if (cmd === '/me') {
      channelBadge.style.color = '#E5A93C';
      channelBadge.style.background = 'rgba(229, 169, 60, 0.15)';
      channelBadge.style.borderColor = 'rgba(229, 169, 60, 0.4)';
      channelIcon.className = 'fa-solid fa-user';
      channelName.textContent = 'فعل | ME';
    } else if (cmd === '/do') {
      channelBadge.style.color = '#9C6ADE';
      channelBadge.style.background = 'rgba(156, 106, 222, 0.15)';
      channelBadge.style.borderColor = 'rgba(156, 106, 222, 0.4)';
      channelIcon.className = 'fa-solid fa-eye';
      channelName.textContent = 'بيئة | DO';
    } else if (cmd === '/w' || cmd === '/whisper') {
      channelBadge.style.color = '#64B5F6';
      channelBadge.style.background = 'rgba(100, 181, 246, 0.15)';
      channelBadge.style.borderColor = 'rgba(100, 181, 246, 0.4)';
      channelIcon.className = 'fa-solid fa-comment-dots';
      channelName.textContent = 'همس';
    } else if (cmd === '/s' || cmd === '/shout') {
      channelBadge.style.color = '#FF7043';
      channelBadge.style.background = 'rgba(255, 112, 67, 0.15)';
      channelBadge.style.borderColor = 'rgba(255, 112, 67, 0.4)';
      channelIcon.className = 'fa-solid fa-bullhorn';
      channelName.textContent = 'صراخ';
    } else if (cmd === '/try') {
      channelBadge.style.color = '#81C784';
      channelBadge.style.background = 'rgba(129, 199, 132, 0.15)';
      channelBadge.style.borderColor = 'rgba(129, 199, 132, 0.4)';
      channelIcon.className = 'fa-solid fa-dice';
      channelName.textContent = 'قرعة';
    } else if (cmd === '/roll') {
      channelBadge.style.color = '#42A5F5';
      channelBadge.style.background = 'rgba(66, 165, 245, 0.15)';
      channelBadge.style.borderColor = 'rgba(66, 165, 245, 0.4)';
      channelIcon.className = 'fa-solid fa-dice-d20';
      channelName.textContent = 'نرد';
    } else if (cmd === '/pm') {
      channelBadge.style.color = '#AB47BC';
      channelBadge.style.background = 'rgba(171, 71, 188, 0.15)';
      channelBadge.style.borderColor = 'rgba(171, 71, 188, 0.4)';
      channelIcon.className = 'fa-solid fa-paper-plane';
      channelName.textContent = 'خاص';
    } else if (cmd === '/police') {
      channelBadge.style.color = '#3884ff';
      channelBadge.style.background = 'rgba(56, 132, 255, 0.15)';
      channelBadge.style.borderColor = 'rgba(56, 132, 255, 0.4)';
      channelIcon.className = 'fa-solid fa-shield-halved';
      channelName.textContent = 'الشرطة';
    } else if (cmd === '/medic') {
      channelBadge.style.color = '#26A69A';
      channelBadge.style.background = 'rgba(38, 166, 154, 0.15)';
      channelBadge.style.borderColor = 'rgba(38, 166, 154, 0.4)';
      channelIcon.className = 'fa-solid fa-staff-snake';
      channelName.textContent = 'الإسعاف';
    } else if (cmd === '/ann' || cmd === '/announce') {
      channelBadge.style.color = '#E53935';
      channelBadge.style.background = 'rgba(229, 57, 53, 0.18)';
      channelBadge.style.borderColor = 'rgba(229, 57, 53, 0.45)';
      channelIcon.className = 'fa-solid fa-crown';
      channelName.textContent = 'الإدارة';
    } else {
      channelBadge.style.color = 'var(--wc-accent)';
      channelBadge.style.background = 'var(--wc-plate)';
      channelBadge.style.borderColor = 'var(--wc-line-strong)';
      channelIcon.className = 'fa-solid fa-comments';
      channelName.textContent = defaultChannelName;
    }
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
            channelName.textContent = defaultChannelName;
          }
          if (msg.data.fadeTimeout) fadeTimeout = msg.data.fadeTimeout;
        }
        break;
    }
  });
})();
