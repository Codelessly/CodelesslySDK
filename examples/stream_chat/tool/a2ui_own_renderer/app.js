import {MessageProcessor} from '@a2ui/web_core/v1_0';
import {basicCatalog, injectBasicCatalogStyles} from '@a2ui/web_core/catalogs/basic/v1';
import {A2uiSurface} from '@a2ui/lit';
void A2uiSurface;
injectBasicCatalogStyles();
window.renderA2ui = async (messages) => {
  const errors = [];
  const host = document.getElementById('host');
  host.innerHTML = '';
  const processor = new MessageProcessor([basicCatalog]);
  let surface = null;
  processor.onSurfaceCreated((s) => { surface = surface ?? s; });
  for (const m of messages) {
    try { processor.processMessages([m]); } catch (e) { errors.push(String(e && e.message || e).slice(0, 300)); }
  }
  if (!surface) return {errors, surface: false};
  const el = document.createElement('a2ui-surface');
  el.surface = surface;
  host.appendChild(el);
  await new Promise((r) => setTimeout(r, 400));
  return {errors, surface: true, height: host.getBoundingClientRect().height, text: host.innerText.length,
          elements: host.querySelectorAll('*').length};
};
