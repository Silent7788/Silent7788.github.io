/* global hexo */
'use strict';

/**
 * 把 _posts 里的每一篇文章汇总成时间轴数据，输出到 /timeline.json
 * 你只需要正常写文章，时间轴会自动更新。
 */
hexo.extend.generator.register('memoir_timeline', function (locals) {
  const posts = locals.posts.sort('date').toArray();

  const items = posts.map(function (post) {
    const raw = String(post.excerpt || post.content || '');
    const text = raw
      .replace(/<[^>]*>/g, ' ')
      .replace(/&nbsp;/g, ' ')
      .replace(/&[a-z#0-9]+;/gi, ' ')
      .replace(/\s+/g, ' ')
      .trim();

    return {
      date: post.date.format('YYYY-MM-DD'),
      title: post.title || '无标题',
      url: '/' + post.path,
      cover: post.cover || '',
      tags: post.tags && post.tags.length
        ? post.tags.toArray().map(function (t) { return t.name; })
        : [],
      excerpt: text.length > 110 ? text.slice(0, 110) + '…' : text
    };
  });

  return {
    path: 'timeline.json',
    data: JSON.stringify(items)
  };
});
