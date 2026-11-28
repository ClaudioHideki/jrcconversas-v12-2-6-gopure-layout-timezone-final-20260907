/** Preserve HTTP(S) destinations when a channel schema cannot retain link marks. */
export function preservePastedLinkUrls(html) {
  const template = document.createElement('template');
  template.innerHTML = html;
  let changed = false;

  template.content.querySelectorAll('a[href]').forEach(anchor => {
    const href = anchor.getAttribute('href').trim();
    // Leave linked media and non-web links to the existing paste pipeline.
    if (
      !anchor.textContent.trim() ||
      anchor.querySelector('img, video, audio, svg')
    )
      return;
    try {
      if (!['http:', 'https:'].includes(new URL(href).protocol)) return;
    } catch {
      return;
    }
    // Validate with URL, but never reserialize it: query strings, encoding and
    // fragments must remain exactly as provided by the clipboard destination.
    anchor.replaceWith(document.createTextNode(href));
    changed = true;
  });

  return changed ? template.innerHTML : html;
}
