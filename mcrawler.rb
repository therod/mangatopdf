#! /usr/bin/env ruby

require 'nokogiri'
require 'pry'
require 'open-uri'
require 'typhoeus'
require 'rmagick'

module MCrawler
  class Mangareader
    attr_accessor :base_url

    def initialize
      @base_url = 'https://www.mangareader.net'
    end

    def list_mangas
      links = []
      get_page('/alphabetical').css('.series_alpha li a').each do |link|
        links << link.attributes['href'].value
      end
      links
    end

    # Downloads all chapters of a specific manga and creates a folder
    def get_manga(manga, start_chapter: nil)
      if start_chapter
        chapters = chapters(manga).slice((start_chapter-1)..-1)
      else
        chapters = chapters(manga)
      end
      chapters.each do |chapter|
        title = manga.delete('/')
        chapter_title = chapter.split('/').last

        if create_folder(title, chapter_title)
          pages = chapter_images(chapter)
          save_images(pages, "mangas/#{title}/#{chapter_title}")
        end
      end
    end

    def generate_pdf(manga)
      chapters = Dir.glob("mangas/" + manga + "/*").sort
      pdf_pages = []

      chapters.each do |chapter|
        pages = Dir.glob(chapter + "/*").sort
        pdf_pages << pages
      end

      binding.pry
      image_list = Magick::ImageList.new(*pdf_pages.flatten)
      image_list.write(manga + ".pdf")
    end

    # TODO: make this block more readable
    def save_images(pages, path)
      hydra = Typhoeus::Hydra.new
      pages.each do |page|
        request = Typhoeus::Request.new(page[:url], followlocation: true)
        request.on_complete do |response|
          File.open("#{path}/#{page[:page_nr]}.jpg", 'w') do |file|
            file.write(response.body)
          end
        end
        hydra.queue(request)
        request
      end
      hydra.run
    end

    # 1 Base Request and then n Async requests
    def chapter_images(chapter)
      images = []
      # 1 Request
      pages = get_page(chapter).css('#pageMenu option').count

      hydra = Typhoeus::Hydra.new
      pages.times do |i|
        current_page = sprintf '%04d', i + 1
        url = "#{@base_url}#{chapter}/#{current_page}"
        request = Typhoeus::Request.new(url, followlocation: true)
        request.on_complete do |response|
          page = Nokogiri::HTML(response.body)
          images << { page_nr: current_page,
                      url: page.css('#img').first.attributes['src'].value }
        end
        hydra.queue(request)
        request
      end
      hydra.run
      images
    end

    # 1 Request
    def chapters(manga)
      links = []
      get_page(manga).css('#chapterlist a').each do |link|
        links << link.attributes['href'].value
      end
      links
    end

    private

    def get_page(path)
      url = @base_url + path
      Nokogiri::HTML(open(url))
    end

    # TODO: read about guard clauses
    def create_folder(title, chapter)
      if Dir.exist?("mangas/#{title}/#{chapter}")
        return false
      else
        FileUtils.mkdir_p("mangas/#{title}/#{chapter}")
        return true
      end
    end
  end
end

client = MCrawler::Mangareader.new
client.get_manga('/mahou-tsukai-no-yome')

binding.pry
