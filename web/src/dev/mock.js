// dev only (dev.html, `npm run dev` -> http://localhost:5225/dev.html?lang=ar|en&open=1): the messages client/main.lua
// sends, so the page can be looked at in a browser. Never part of the build (index.html does not load it).
import arLoc from '../../../locales/ar.json';
import enLoc from '../../../locales/en.json';

const q = new URLSearchParams(location.search);
const ar = (q.get('lang') || 'ar') === 'ar';
const send = (action, data) => window.postMessage({ action, data }, '*');
setTimeout(() => {
  const loc = ar ? arLoc : enLoc;
  const t = loc.tags || {};
  send('SET_LOCALE', { locale: ar ? 'ar' : 'en', isRTL: ar, fadeTimeout: 600000, placeholder: loc.ui.placeholder, channelGeneral: loc.ui.channel_general,
    send: loc.ui.send, suggestionsTitle: loc.ui.suggestions_title, suggestionsHint: loc.ui.suggestions_hint,
    channels: { local: t.local, me: t.me, do: t.do, whisper: t.whisper, shout: t.shout, try: t.try, roll: t.roll, pm: t.pm, police: t.police, medic: t.medic, admin: t.admin } });
  send('ADD_MESSAGE', { channel: 'system', tag: t.system, sender: t.system, message: ar ? 'مرحبًا بكم في ريد ريفر' : 'Welcome to Red River', time: '21:04' });
  send('ADD_MESSAGE', { channel: 'ooc', tag: t.ooc, sender: ar ? 'سالم' : 'Salem', id: 7, rank: { label: ar ? 'مشرف' : 'Moderator' }, message: ar ? 'في فالنتاين جنب البنك' : 'In Valentine, next to the bank', time: '21:05' });
  send('ADD_MESSAGE', { channel: 'ooc', tag: t.ooc, sender: ar ? 'نورة' : 'Noura', id: 31, rank: { label: ar ? 'ذهبي' : 'Gold', tier: 'gold', bgColor: '#C9A227', color: '#111111' }, nameColor: '#E8B84A', message: ar ? 'شكرًا' : 'Thanks', time: '21:06' });
  send('ADD_MESSAGE', { channel: 'system', tone: 'error', tag: t.system, sender: t.system, message: loc.messages ? loc.messages.no_permission : '', time: '21:07' });
  const c = loc.commands || {};
  send('ADD_SUGGESTION', { name: '/me', help: c.help_me });
  send('ADD_SUGGESTION', { name: '/medic', help: c.help_medic });
  send('ADD_SUGGESTION', { name: '/pm', help: c.help_pm, params: [{ name: 'id' }, { name: ar ? 'النص' : 'text' }] });
  if (q.get('open') === '1') send('OPEN_CHAT');
}, 300);
