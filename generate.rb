#!/usr/bin/env ruby

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

  def essential?; @essential=='TRUE' end

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

def article_to_markdown article, opts={}
  markdown = ''
  markdown += "**[#{article.title}](#{article.url})**"
  markdown += "<br/>\n"
  markdown += "#{article.author || '?'} - #{article.host}"
  markdown += " - #{article.published_date}" if article.published_date
  markdown += "\n\n"
  markdown += "> #{article.summary}\n"
  markdown += "\n"
  markdown
end

def articles_to_markdown articles, opts={}
  markdown = ''
  articles.each do |a|
    markdown += article_to_markdown a, opts
  end
  markdown
end

def category_to_markdown cat, articles, opts={}
  cat = "#{opts[:section]}: #{cat}" if opts[:section]
  markdown = ''
  markdown += "### #{cat}\n"
  markdown += "\n"
  articles = articles.sort{|a,b| b.published_at.to_s <=> a.published_at.to_s }
  markdown += articles_to_markdown articles
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

  markdown += "## The Collection\n\n"

  %w(Business Development Personal).each do |section|
    section_articles = articles.select{|a| a.category==section }
    categories = section_articles.map(&:subcategory).uniq.sort
    categories.each do |cat|
      cat_articles = section_articles.select{|a| a.subcategory==cat }
      markdown += category_to_markdown cat, cat_articles, section: section
    end
  end
  markdown
end

def markdown_inline_link text, anchor_text=nil
  anchor_text ||= text
  "[#{text}](##{github_format_category anchor_text})"
end

def toc_to_markdown articles
  markdown = ""
  markdown += "* #{markdown_inline_link 'About'}\n"
  markdown += "  * #{markdown_inline_link 'Motivation'}\n"
  markdown += "  * #{markdown_inline_link 'Goals'}\n"
  markdown += "  * #{markdown_inline_link 'Concepts & Definitions'}\n"
  markdown += "  * #{markdown_inline_link 'Structure'}\n"
  markdown += "  * #{markdown_inline_link 'Criteria'}\n"
  markdown += "* #{markdown_inline_link 'The Collection'}\n"
  categories = articles.map{|a| [a.category, a.subcategory] }.uniq.sort.group_by{|x| x[0] }
  categories.each do |cat, sets|
    markdown += "  * #{markdown_inline_link(cat)}\n"
    sets.each do |pair|
      markdown += "    * #{markdown_inline_link(pair[1], pair.join(': '))}\n"
    end
  end
  markdown += "\n"
  markdown
end

def readme articles
  markdown = ""
  markdown += "# Startup Knowledge Database\n\n"
  markdown += "A curated collection of insightful articles related to startups, as a resource for startup founders and team members.\n\n"
  markdown += "The ultimate goal of the project is to contain every fundamentally valuable insight or resource on a given topic, across a wide array of topics related to startups.\n\n"
  markdown += "A related project is the [StartupFAQ](https://github.com/bnjs/StartupFAQ): a broad array of questions answered with insights distilled from several of the most important startup articles in this collection.\n\n"
  markdown += "## Table of Contents\n\n"
  markdown += toc_to_markdown articles
  markdown += File.read("README_BASE.md")
  markdown += sections_to_readme articles
  markdown
end

articles = Article.process(File.read('articles.csv'))


# Generate top README
File.open("README.md", 'w') do |f|
  f.puts readme articles
end

