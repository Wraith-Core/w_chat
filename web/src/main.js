// the kit first (the board design every Wraith page shares, a byte-identical copy of w_train's), the chat's
// own sheet after it so it wins the ties
import './kit.css';
import './chat.css';
import './app.js';

/* The fonts and textures are injected from here, not from CSS: their path must be relative to the build page
   (nui://w_chat/web/build/) and Vite writes absolute CSS paths that break under nui://.
     EB Garamond    Latin text, labels, figures   (SIL OFL 1.1)
     Lalezar        every Arabic face             (SIL OFL 1.1)
   The torn edge, the grain and the selection band are the game's own art, as w_lib's theme ships it
   (web/public is a byte-identical copy of w_train's, itself a copy of w_lib/nui/theme's). */
try {
  const base = new URL('./', window.location.href).href;
  const FONTS = `${base}fonts/`;
  const AR = 'U+0600-06FF,U+0750-077F,U+0870-088E,U+0890-0891,U+0897-08E1,U+08E3-08FF,U+FB50-FDFF,U+FE70-FE74,U+FE76-FEFC,U+200C-200E,U+2010-2011,U+0660-0669';
  // one Arabic face server-wide (owner, 2026-10-22): the Arabic faces of the kit's role names (Amiri, Tajawal,
  // Noto Sans Arabic) draw Lalezar's file at their own weights, so every stack keeps working.
  const style = document.createElement('style');
  style.textContent = `
    @font-face { font-family: "EB Garamond"; font-style: normal; font-weight: 400 800; src: url("${FONTS}EBGaramond-latin.woff2") format("woff2"); font-display: swap; }
    @font-face { font-family: "Amiri"; font-weight: 400; src: url("${FONTS}Lalezar-400-arabic.woff2") format("woff2"); unicode-range: ${AR}; font-display: swap; }
    @font-face { font-family: "Amiri"; font-weight: 700; src: url("${FONTS}Lalezar-400-arabic.woff2") format("woff2"); unicode-range: ${AR}; font-display: swap; }
    @font-face { font-family: "Lalezar"; font-weight: 100 900; src: url("${FONTS}Lalezar-400-arabic.woff2") format("woff2"); unicode-range: ${AR}; font-display: swap; }
    @font-face { font-family: "Noto Sans Arabic"; src: url("${FONTS}Lalezar-400-arabic.woff2") format("woff2"); font-weight: 100 900; font-display: swap; }
    @font-face { font-family: "Tajawal"; font-weight: 400; src: url("${FONTS}Lalezar-400-arabic.woff2") format("woff2"); unicode-range: ${AR}; font-display: swap; }
    @font-face { font-family: "Tajawal"; font-weight: 700; src: url("${FONTS}Lalezar-400-arabic.woff2") format("woff2"); unicode-range: ${AR}; font-display: swap; }
    @font-face { font-family: "RDR Catalogue"; font-weight: 100 900; src: url("${FONTS}RDRCatalogueBold-Bold.woff2") format("woff2"); font-display: swap; }
    @font-face { font-family: "EB Garamond"; font-style: normal; font-weight: 400 800; src: url("${FONTS}RDRCatalogueBold-Bold.woff2") format("woff2"); unicode-range: U+0030-0039; font-display: swap; }
    @font-face { font-family: "Amiri"; font-weight: 400; src: url("${FONTS}RDRCatalogueBold-Bold.woff2") format("woff2"); unicode-range: U+0030-0039; font-display: swap; }
    @font-face { font-family: "Amiri"; font-weight: 700; src: url("${FONTS}RDRCatalogueBold-Bold.woff2") format("woff2"); unicode-range: U+0030-0039; font-display: swap; }
    @font-face { font-family: "Lalezar"; font-weight: 100 900; src: url("${FONTS}RDRCatalogueBold-Bold.woff2") format("woff2"); unicode-range: U+0030-0039; font-display: swap; }
    @font-face { font-family: "Noto Sans Arabic"; font-weight: 100 900; src: url("${FONTS}RDRCatalogueBold-Bold.woff2") format("woff2"); unicode-range: U+0030-0039; font-display: swap; }
    @font-face { font-family: "Tajawal"; font-weight: 400; src: url("${FONTS}RDRCatalogueBold-Bold.woff2") format("woff2"); unicode-range: U+0030-0039; font-display: swap; }
    @font-face { font-family: "Tajawal"; font-weight: 700; src: url("${FONTS}RDRCatalogueBold-Bold.woff2") format("woff2"); unicode-range: U+0030-0039; font-display: swap; }
  `;
  document.head.appendChild(style);
  const root = document.documentElement.style;
  root.setProperty('--tex-tear', `url("${base}tex/tear.png")`);
  root.setProperty('--tex-grain', `url("${base}tex/grain.png")`);
  root.setProperty('--tex-band', `url("${base}tex/band.png")`);
  root.setProperty('--tex-band-sm', `url("${base}tex/band-sm.png")`);
} catch {
  /* a fallback face is enough: the chat is never dropped for a font */
}
