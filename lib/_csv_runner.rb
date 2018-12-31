class CSVRunner
  attr_accessor :obj, :all_emails, :excluded_files

  EXCLUDED_FILES = ['_google_import_spreadsheet.csv']

  def initialize
    @obj = {}
    @all_emails = []
    @excluded_files = []
  end

  def read_files
    obj.clear
    @excluded_files.clear
    puts 'reading files...'
    filenames = Dir.entries('./csv/').select {|filename| /^.*\.(csv)$/ =~ filename }
    filenames.each do |filename|
      unless EXCLUDED_FILES.include?(filename)
        obj[filename] = []
        CSV.foreach('./csv/' + filename, :headers => true, :quote_char => '|') do |row|
          obj[filename] << row[0].gsub("\"", "")
        end
        @all_emails << obj[filename]
      else
        @excluded_files << filename
      end
    end
  end
end
