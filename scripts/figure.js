/* global hexo */
'use strict';

/**
 * 图注标签
 * 用法：{% figure /images/2025/xxx.jpg 那天下着雨 %}
 * 会渲染成 <figure><img><figcaption>说明</figcaption></figure>
 */
hexo.extend.tag.register('figure', function (args) {
  if (!args || !args.length) return '';

  const src = args[0];
  const caption = args.slice(1).join(' ');

  const esc = (s) =>
    String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');

  let html = '<figure class="fig"><img src="' + esc(src) + '"';
  if (caption) html += ' alt="' + esc(caption) + '"';
  html += ' loading="lazy" decoding="async">';
  if (caption) html += '<figcaption>' + esc(caption) + '</figcaption>';
  html += '</figure>';

  return html;
});
