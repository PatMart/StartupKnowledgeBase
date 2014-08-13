require 'csv'
require 'uri'

class Article

  attr_reader :opts, :published_at, :category, :subcategory, :title, :author, :essential, :summary, :url, :added_at

  def initialize opts={}
    @opts = opts
    @published_at = @opts['published_at']
    @category     = @opts['category']
    @subcategory  = @opts['subcategory']
    @title        = @opts['title']
    @author       = @opts['author']
    @essential    = @opts['essential']
    @summary      = @opts['summary']
    @url          = @opts['url']
    @added_at     = @opts['added_at']
  end

  class << self
    def process csv_string
      hashes      = csv_to_arr_of_hashes csv_string
      hashes.map{|hash| new hash }
    end

    private

    def csv_to_arr_of_hashes csv_string
      csv = CSV.parse csv_string
      heads = csv.shift
      csv.map{|row| h = Hash[heads.zip(row)]; h if h && h.any? }.compact
    end
  end

  def business?; @category=='Business' end
  def development?; @category=='Development' end
  def personal?; @category=='Personal' end

  def essential?; @essential=='TRUE' end

  def host
    URI.parse(url).host.sub(/www\./,'')
  end

  private

  def date_with_current_time date_string
    if date_string.present?
      n = Time.now
      t = Time.parse date_string
      t.change hour: n.hour, min: n.min, sec: n.sec
    end
  end

end

def normalize_category cat
  cat.sub(/&/,'and').gsub(/,/,'').gsub(/ /,'_').downcase
end

def github_format_category cat
  cat.gsub(/,/,'').gsub(/ /,'-').gsub(/[&:]/,'').downcase
end

def article_to_markdown article
  markdown = ''
  markdown += "[#{article.title}](#{article.url})<br/>\n"
  markdown += "#{article.author || '?'} - #{article.host}\n\n"
  markdown += "> #{article.summary}\n"
  markdown += "\n"
  markdown
end

def articles_to_markdown articles
  markdown = ''
  articles.each do |a|
    markdown += article_to_markdown a
  end
  markdown
end

def category_to_markdown cat, articles, opts={}
  cat = "#{opts[:section]}: #{cat}" if opts[:section]
  markdown = ''
  markdown += "## #{cat}\n"
  markdown += "\n"

  essential_articles = articles.select{|a| a.essential? }
  general_articles = articles.select{|a| !a.essential? }

  [[essential_articles,'Essential'],[general_articles,'General']].each do |arts,type|
    if arts.any?
      markdown += "### #{type}\n"
      markdown += "\n"
      arts = arts.sort{|a,b| a.published_at.to_s <=> b.published_at.to_s }
      markdown += articles_to_markdown arts
    end
  end
  markdown
end

def contents_to_markdown categories, opts={}
  markdown = ""
  categories.each do |cat|
    markdown += "- [#{cat}](#user-content-#{github_format_category cat})\n"
  end
  markdown += "\n"
  markdown
end

def section_to_readme section, articles
  markdown = ""

  markdown += "# #{section} Articles\n\n"
  categories = articles.map(&:subcategory).uniq.sort
  markdown += contents_to_markdown categories

  categories.each do |cat|
    cat_articles = articles.select{|a| a.subcategory==cat }
    markdown += category_to_markdown cat, cat_articles
  end
  markdown
end

def sections_to_readme articles
  markdown = ""

  markdown += "# Articles\n\n"
  categories = articles.map{|a| "#{a.category}: #{a.subcategory}" }.uniq.sort
  markdown += contents_to_markdown categories

  %w(Business Development Personal).each do |section|
    section_articles = articles.select{|a| a.category==section }
    categories = section_articles.map(&:subcategory).uniq.sort
    categories.each do |cat|
      cat_articles = articles.select{|a| a.subcategory==cat }
      markdown += category_to_markdown cat, cat_articles, section: section
    end
  end
  markdown
end

articles = Article.process(File.read('articles.csv'))

readme_base = File.read("README_BASE.md")

# Generate top README
File.open("README.md", 'w') do |f|
  f.puts readme_base
  f.puts sections_to_readme articles
end

=begin
%w(Business Development Personal).each do |section|
  section_articles = articles.select{|a| a.category==section }
  # Generate category README's
  File.open("#{section.downcase}/README.md", 'w') do |f|
    f.puts section_to_readme section, section_articles
  end

  # Generate subcategory README's
  categories = section_articles.map(&:subcategory).uniq.sort
  categories.each do |cat|
    cat_articles = section_articles.select{|a| a.subcategory==cat }
    norm_cat = normalize_category cat
    File.open("#{section.downcase}/#{norm_cat}/README.md", 'w') do |f|
      f.puts category_to_markdown(cat, cat_articles)
    end
  end
end
=end

