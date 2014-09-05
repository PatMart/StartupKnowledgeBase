#!/usr/bin/env ruby

require 'csv'
require 'uri'

class Table
  def initialize opts={}
    @opts = opts
    @opts.keys.each do |k|
      instance_variable_set "@#{k}", @opts[k]
    end
  end

  class << self
    def process
      csv_string = File.read(csv_source_file)
      hashes      = csv_to_arr_of_hashes csv_string
      hashes.map{|hash| new hash }
    end

    def csv_source_file; "#{plural}.csv" end
    def collection; eval("$#{plural}") end

    def find(uuid); collection.select{|x| x.uuid==uuid }[0] end

    private

    def csv_to_arr_of_hashes csv_string
      csv = CSV.parse csv_string
      heads = csv.shift
      csv.map{|row| h = Hash[heads.zip(row)]; h if h && h.any? }.compact
    end
  end
end

class Subcategory < Table
  attr_reader :uuid, :subcategory, :category
  def self.plural; 'subcategories' end
end

class ArticleSubcategory < Table
  attr_reader :uuid, :article_uuid, :article, :subcategory_uuid, :subcategory, :microcategory
  def self.plural; 'article_subcategories' end

  def subcategory
    Subcategory.find(subcategory_uuid)
  end

  def article
    Article.find(article_uuid)
  end
end

class Article < Table
  attr_reader :opts, :uuid, :published_at, :title, :author, :summary, :url, :added_at
  def self.plural; 'articles' end

  def published_date
    published_at.to_s.split(' ')[0]
  end

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

def article_to_markdown article_sub, opts={}
  article = article_sub.article
  markdown = ''
  markdown += "*#{article_sub.microcategory.upcase}*<br/>\n" if article_sub.microcategory
  markdown += "**[#{article.title}](#{article.url})**"
  markdown += "<br/>\n"
  markdown += "#{article.author || '?'} - #{article.host}"
  markdown += " - #{article.published_date}" if article.published_date
  markdown += "\n\n"
  markdown += "> #{article.summary}\n"
  markdown += "\n"
  markdown
end

def articles_to_markdown article_subs, opts={}
  markdown = ''
  article_subs.each do |as|
    markdown += article_to_markdown as, opts
  end
  markdown
end

def category_to_markdown subcat, article_subcategories, opts={}
  cat = "#{opts[:section]}: #{subcat.subcategory}" if opts[:section]
  markdown = ''
  markdown += "### #{cat}\n"
  markdown += "\n"
  article_subcategories = article_subcategories.sort_by{|as| [as.microcategory.to_s, as.article.title] }
  markdown += articles_to_markdown article_subcategories
  markdown
end

def sections_to_markdown
  markdown = ""

  markdown += "## The Collection\n\n"

  %w(Business Development Personal).each do |section|
    section_article_subcategories = $article_subcategories.select{|as| as.subcategory.category==section }
    categories = section_article_subcategories.map(&:subcategory).uniq.sort_by(&:subcategory)
    categories.each do |cat|
      cat_article_subcategories = section_article_subcategories.select{|as| as.subcategory_uuid==cat.uuid }
      markdown += category_to_markdown cat, cat_article_subcategories, section: section
    end
  end
  markdown
end

def markdown_inline_link text, anchor_text=nil
  anchor_text ||= text
  "[#{text}](##{github_format_category anchor_text})"
end

def toc_to_markdown
  markdown = ""
  markdown += "* #{markdown_inline_link 'About'}\n"
  markdown += "  * #{markdown_inline_link 'Motivation'}\n"
  markdown += "  * #{markdown_inline_link 'Goals'}\n"
  markdown += "  * #{markdown_inline_link 'Concepts & Definitions'}\n"
  markdown += "  * #{markdown_inline_link 'Structure'}\n"
  markdown += "  * #{markdown_inline_link 'Criteria'}\n"
  markdown += "* **#{markdown_inline_link 'The Collection'}**\n"
  categories = $subcategories.map{|sc| [sc.category, sc.subcategory] }.uniq.sort.group_by{|x| x[0] }
  categories.each do |cat, sets|
    markdown += "  * #{markdown_inline_link(cat)}\n"
    sets.each do |pair|
      subcat = pair[1]
      article_count = $article_subcategories.select{|as| as.subcategory.category==cat && as.subcategory.subcategory==subcat}.size
      if article_count > 0
        markdown += "    * #{markdown_inline_link(subcat, pair.join(': '))} (#{article_count})\n"
      else
        markdown += "    * #{subcat} (#{article_count})\n"
      end
    end
  end
  markdown += "\n"
  markdown
end

def stats
  authors = $articles.map(&:author).uniq
  topics = $article_subcategories.map(&:subcategory_uuid).uniq
  "#{topics.size} topics, #{$articles.size} articles, #{authors.size} authors"
end

def intro
  markdown = ""
  markdown += "# Startup Knowledgebase\n\n"
  markdown += "#{stats}\n\n"
  markdown += "A curated collection of insightful articles related to startups, as a resource for startup founders and team members.\n\n"
  markdown += "The ultimate goal of the project is to contain every fundamentally valuable insight or resource on a given topic, across a wide array of topics related to startups.\n\n"
  markdown += "A related project is the [StartupFAQ](https://github.com/bnjs/StartupFAQ): a broad array of questions answered with insights distilled from several of the most important startup articles in this collection.\n\n"
  markdown
end

def readme
  markdown = ""
  markdown += intro
  markdown += "## Table of Contents\n\n"
  markdown += toc_to_markdown
  markdown += File.read("README_BASE.md")
  markdown += sections_to_markdown
  markdown
end

$subcategories = Subcategory.process
$article_subcategories = ArticleSubcategory.process
$articles = Article.process

# Generate top README
File.open("README.md", 'w') do |f|
  f.puts readme
end

