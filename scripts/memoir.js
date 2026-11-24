/* global hexo */
'use strict';

/**
 * 汇总两类内容，输出到 /timeline.json：
 *   1. _posts 里的文章          -> type: "post"
 *   2. source/_data/shuoshuo.yml -> type: "shuoshuo"（QQ空间说说索引）
 */

function pad2(n) {
  return n < 10 ? '0' + n : '' + n;
}

// YAML 里的 date 会被解析成 Date（UTC 零点），统一按 UTC 取年月日，避免时区偏移
function toYmd(value) {
  if (value instanceof Date) {
    return value.getUTCFullYear() + '-' + pad2(value.getUTCMonth() + 1) + '-' + pad2(value.getUTCDate());
  }
  const s = String(value || '').trim();
  const m = s.match(/^(\d{4})-(\d{1,2})(?:-(\d{1,2}))?/);
  if (!m) return '';
  return m[1] + '-' + pad2(Number(m[2])) + '-' + pad2(Number(m[3] || 1));
}

hexo.extend.generator.register('memoir_timeline', function (locals) {
  const items = [];

  // ---------- 文章 ----------
  locals.posts.sort('date').toArray().forEach(function (post) {
    const raw = String(post.excerpt || post.content || '');
    const text = raw
      .replace(/<[^>]*>/g, ' ')
      .replace(/&nbsp;/g, ' ')
      .replace(/&[a-z#0-9]+;/gi, ' ')
      .replace(/\s+/g, ' ')
      .trim();

    items.push({
      type: 'post',
      date: post.date.format('YYYY-MM-DD'),
      title: post.title || '无标题',
      url: '/' + post.path,
      cover: post.cover || '',
      tags: post.tags && post.tags.length
        ? post.tags.toArray().map(function (t) { return t.name; })
        : [],
      excerpt: text.length > 110 ? text.slice(0, 110) + '…' : text
    });
  });

  // ---------- 说说 ----------
  let shuo = [];
  try {
    const data = hexo.locals.get('data');
    if (data && data.shuoshuo) shuo = data.shuoshuo;
  } catch (e) {
    shuo = [];
  }
  if (!Array.isArray(shuo)) shuo = [];

  shuo.forEach(function (s) {
    if (!s) return;
    const date = toYmd(s.date);
    if (!date) return;

    const text = String(s.text || '').trim();
    const link = String(s.link || '').trim();

    items.push({
      type: 'shuoshuo',
      date: date,
      title: text ? (text.length > 40 ? text.slice(0, 40) + '…' : text) : '说说',
      url: link,
      cover: s.cover || '',
      tags: Array.isArray(s.tags) ? s.tags : [],
      excerpt: text,
      images: Number(s.images || 0),
      link: link
    });
  });

  // 按日期排序（同一天：说说排在文章后面）
  items.sort(function (a, b) {
    if (a.date === b.date) {
      return (a.type === 'shuoshuo' ? 1 : 0) - (b.type === 'shuoshuo' ? 1 : 0);
    }
    return a.date < b.date ? -1 : 1;
  });

  return {
    path: 'timeline.json',
    data: JSON.stringify(items)
  };
});
