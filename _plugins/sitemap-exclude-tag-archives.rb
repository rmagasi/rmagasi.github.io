#!/usr/bin/env ruby
#
# Keep tag archive pages out of sitemap.xml.
#
# _includes/head.html marks every tag archive as "noindex, follow", so listing
# them in the sitemap asks search engines to crawl pages they are then told
# not to index. jekyll-archives builds these pages without front matter, so a
# `sitemap: false` default in _config.yml cannot reach them. Category archives
# stay in the sitemap, they are indexable.

Jekyll::Hooks.register :site, :pre_render do |site|
  (site.config['archives'] || []).each do |archive|
    archive.data['sitemap'] = false if archive.type == 'tag'
  end
end
