require 'gepub'
require 'erb'
require 'pry'

@manga = ARGV[0]
@chapter = ARGV[1]

@erb_file = 'epub_template/page.html.erb'

def generate_book(manga, chapter)
  images = Dir.glob("mangas/#{manga}/#{chapter}/*.jpg")

  base_path = "tmp/#{manga}/"
  image_path = base_path + 'img'
  text_path = base_path + 'text'

  FileUtils.mkdir_p(image_path)
  FileUtils.mkdir_p(text_path)

  images.each do |image|
    FileUtils.cp image, image_path
    page = image.split('/').last.split('.').first
    html_file = text_path + "/page_#{page}.xhtml"
    @title = @manga
    @image = image.split('/').last
    @page = page
    @text = "hello world"
    renderer = ERB.new(File.read(@erb_file))
    result = renderer.result()

    File.open(html_file, 'w') { |f| f.write(result) }
  end
end

generate_book(@manga, @chapter)

book = GEPUB::Book.new
book.set_primary_identifier('http:/example.jp/bookid_in_url', 'BookID', 'URL')
book.language = 'en'

book.add_title('test', nil, GEPUB::TITLE_TYPE::MAIN) {
  |title|
  title.lang = 'en'
  title.file_as = 'GEPUB Sample Book'
  title.display_seq = 1
  title.add_alternates('en' => 'GEPUB Sample Book (Japanese)')
}

files = Dir.glob("tmp/mahou-tsukai-no-yome/text/*.xhtml")
images = Dir.glob("tmp/mahou-tsukai-no-yome/img/*.jpg")
prefix = 'tmp/mahou-tsukai-no-yome/'
# within ordered block, add_item will be added to spine.
book.ordered {
  images.each do |image|
    puts "adding image: #{image}"
    book.add_item(image.gsub(prefix, '')).add_content(StringIO.new(File.open(image).read))
  end
  files.each do |file|
    puts "adding file: #{file}"
    book.add_item(file.gsub(prefix, '')).add_content(StringIO.new(File.open(file).read))
  end
}

epubname = File.join(File.dirname(__FILE__), 'example_test.epub')

book.generate_epub(epubname)
