require 'CSV'
require 'colorize'
require 'open-uri'
require 'json'
require 'pry'
require_relative './_task_runner.rb'
require_relative './_email_tracker.rb'

EXCLUDED_FILES = []

class NeverEndingTape
  attr_accessor :obj, :excluded_files, :leads, :task_runner

  def initialize
    @all_emails = []
    @obj = {}
    @excluded_files = []
    @task_runner = TaskRunner.new(
      path: './data/tasks/tasks.json',
      transfer_path: './data/tasks/completed_tasks.json'
    )
    @email_tracker = EmailTracker.new
  end

  def check_for_duplicates(arr)
    arr = arr.map(&:downcase)
    arr.select{ |e| arr.count(e) > 1 }.uniq
  end

  def show_title
    puts ""
    puts ""
    puts " ----------------------------------------------------------------------------------".green
    puts "|    _  __                      ____         __ _            ______                |".green
    puts "|   / |/ /___  _  __ ___  ____ / __/___  ___/ /(_)___  ___ _/_  __/___ _ ___  ___  |".green
    puts "|  /    // -_)| |/ // -_)/ __// _/ / _ \\/ _  // // _ \\/ _ `/ / /  / _ `// _ \\/ -_) |".green
    puts "| /_/|_/ \\__/ |___/ \\__//_/  /___//_//_/\\_,_//_//_//_/\\_, / /_/   \\_,_// .__/\\__/  |".green
    puts "|                                                    /___/            /_/          |".green
    puts " ----------------------------------------------------------------------------------".green

    puts " https://neverendingtape.com"
    puts " Let's get some syncs!".green
    puts ""
  end

  def show_same_file_duplicates
    duplicates = []

    obj.each do |filename, email_array|
      dups = check_for_duplicates(email_array)
      duplicates << { filename: filename, duplicates: dups } if dups.size > 0
    end
    puts "************Same File Duplicates*************"
    if duplicates.size > 0
      duplicates.each do |duplicate_obj|
        puts " Duplicates found in " + "#{duplicate_obj[:filename]}:".red
        duplicate_obj[:duplicates].each do |email|
          puts "    - #{email}".red
        end
      end
    else
      puts "All clear, send some emails!".green
    end
    puts "*********************************************"

    puts ""
  end

  def show_cross_file_duplicates
    cross_dup_obj = {}

    puts "************Cross File Duplicates************"

    obj.each do |filename, email_arr|
      obj[filename] = email_arr.uniq
    end

    # cross_dups = obj.values.flatten.map(&:downcase).select{ |e| obj.values.map(&:downcase).count(e) > 1 }.uniq
    flat_array = obj.values.flatten.map(&:downcase)
    cross_dup_emails = flat_array.select{|e| flat_array.count(e) > 1 }.uniq

    cross_dup_emails.each do |email|
      cross_dup_obj[email] = []
      obj.each do |filename, email_arr|
        if email_arr.map(&:downcase).include?(email.downcase)
          cross_dup_obj[email] << filename
        end
      end
    end

    if cross_dup_obj.size > 0
      cross_dup_obj.each do |email, filenames|
        puts " #{email}".red + " appears in: "
        filenames.each do |filename|
          puts "    - #{filename}".red
        end
      end
    else
      puts "All clear, send some emails!".green
    end
    puts "*********************************************"
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

  def show_exlusions
    puts "Excluded: #{excluded_files.join(', ')}".blue
    puts ""
  end

  def build_menu_item(feature)
    icon = feature[:icon] ? feature[:icon].send(feature[:color]) : ' '
    icon + ' ' + feature[:title]
  end

  def show_main_menu
    menu_items = [
      {
        title: 'Check duplicates in CSV files',
        icon:  "\u2192",
        color: :black
      },
      {
        title: 'Find email in CSV files',
        icon:  "\u2192",
        color: :black
      },
      {
        title: 'Hot Leads',
        icon: "\u2668".encode('utf-8'),
        color: :red
      },
      {
        title: 'Archived Leads',
        icon: "\u2668".encode('utf-8'),
        color: :cyan
      },
      {
        title: 'Running Tasks',
        icon: "\u2714",
        color: :green
      },
      {
        title: 'Email Tracker',
        icon:  "\u2709",
        color: :blue
      }
    ]
    puts "************ MAIN MENU ************"
    menu_items.each.with_index(1) do |feature, i|
      puts "#{i}. #{build_menu_item(feature)}"
    end
    puts "***********************************"

    puts ""
    puts 'Choose from the list or type \'exit\''
    input = nil
    while input != 'exit'
      print "> "
      input = gets.strip

      case input

      when '1'
        show_duplicates
        puts ""
        show_main_menu
      when '2'
        find_email
      when '3'
        hot_leads
      when '4'
        archived_leads
      when '5'
        task_main_menu
      when '6'
        email_tracker
      end
    end

    exit_program

  end

  def email_tracker
    menu_items = [
      {
        title: 'Manually enter email',
        icon: nil,
        color: nil
      }
    ]

    puts "********** Email Tracker **********"
    menu_items.each.with_index(1) do |feature, i|
      puts "#{i}. #{build_menu_item(feature)}"
    end
    puts "***********************************"
    # email_tracker.read_sent_emails
    input = gets.strip

    case input

    when '1'
      manually_enter_email
    else
      puts 'invalid entry'.red
    end
    email_tracker
  end

  def manually_enter_email
    puts 'Enter the email address..'
    print '> '
    input = gets.strip
    @email_tracker.manually_enter_email(input)
    email_tracker
  end

  def task_main_menu
    menu_items = ['Task List', 'See completed tasks']
    puts '******* Running Task Menu *******'.green
    menu_items.each.with_index(1) do |menu_item, i|
      puts "#{i}. #{menu_item}"
    end
    puts '*********************************'.green
    puts ''
    input = prompt('Choose from the menu, [b]ack, e[x]it')

    case input

    when '1'
      task_feature
    when '2'
      see_completed_tasks
    when 'b'
      show_main_menu
    when 'x'
      exit_program
    else
      puts "invalid input".red
      task_main_menu
    end
  end

  def see_completed_tasks
    num_of_days = prompt('See completed tasks starting from how many days ago? (blank for 7)')
    if num_of_days == ''
      num_of_days = 7
    end
    num_of_days = num_of_days.to_i
    if num_of_days.positive?
      tasks = task_runner.completed_tasks_since(num_of_days)
      puts ""
      puts "******* Completed tasks from the last " + "#{num_of_days}".blue + " days *******"
      puts ""
      tasks.each do |date, task_arr|
        puts "#{date}: ".blue
        puts "---------------------"
        task_arr.each do |task|
          puts "\u2714".green + " #{task['info']}"
        end
        puts ""
      end
    else
      puts 'invalid input'.red
    end
    puts ''
    task_main_menu
  end

  def valid_choice?(i, arr)
    arr.each_index.to_a.include?(i)
  end

  def task_feature
    task_runner.read_tasks
    puts ''
    puts '******* Running Tasks *******'.green

    task_runner.tasks.each.with_index(1) do |task, i|
      puts "#{i}. #{task['info']}"
    end
    puts '*****************************'.green
    puts ''
    puts '[a]dd, [d]elete, [e]dit, [m]ark complete, [b]ack, e[x]it'
    print '> '
    input = gets.strip

    case input
    when 'x'
      exit_program
    when 'b'
      task_main_menu
    when 'a'
      add_task
    when 'd'
      delete_task
    when 'e'
      edit_task
    when 'm'
      mark_task_complete
    else
      puts 'invalid entry!'.red
    end

    task_feature
  end

  def prompt(phrase)
    puts phrase
    print "> "
    gets.strip
  end

  def add_task
    task = prompt("Enter the task..")
    task_runner.add_task(info: task)
    puts 'Task added!'.green
    puts ''
  end

  def delete_task
    input = prompt('Delete which task?')
    delete_index = regulate_index(input)
    if task_runner.task_index_is_valid?(delete_index)
      task_runner.delete_task(delete_index)
      puts 'Task deleted!'.green
    else
      puts "invalid selection".red
      delete_task
    end
  end

  def edit_task
    input = prompt('Edit which task?')
    edit_index = regulate_index(input)
    if task_runner.task_index_is_valid?(edit_index)
      new_value = prompt('Enter new value..')
      task_runner.edit_task(edit_index, new_value)
    else
      puts "invalid selection".red
      edit_task
    end
  end

  def mark_task_complete
    input = prompt('Complete which task?')
    complete_task = regulate_index(input)
    if task_runner.task_index_is_valid?(complete_task)
      task_runner.mark_task_complete(complete_task)
    else
      puts "invalid selection".red
      mark_task_complete
    end
  end

  def show_duplicates
    read_files
    show_same_file_duplicates
    show_cross_file_duplicates
    show_exlusions
  end

  def find_email
    puts "Enter the email you wish to search for, type 'back' for main menu or 'exit' to quit"
    print "> "
    input = gets.strip

    case input
    when 'back'
      show_main_menu
    when 'exit'
      exit_program
    else
      read_files
      files = obj.keys.select {|k| obj[k].include?(input)}
      if files.any?
        puts ""
        puts "found the email in:".green
        files.each do |file|
          puts " - #{file}".green
        end
        puts ""
      else
        puts ""
        puts "email not found".red
        puts ""
      end
      find_email
    end
  end

  def read_leads
    raw_leads_doc = File.read('./data/leads/leads.json')
    raw_archived_leads_doc = File.read('./data/leads/archived_leads.json')
    @archived_lead_doc = JSON.parse(raw_archived_leads_doc)
    @archived_leads = @archived_lead_doc['leads']
    @lead_doc = JSON.parse(raw_leads_doc)
    @leads = @lead_doc['leads']
  end

  def delete_lead
    puts "Select a lead to delete"
    print "> "
    input = gets.strip
    delete_index = regulate_index(input)
    @lead_doc['leads'].delete_at(delete_index)
    save_leads(@lead_doc)
    hot_leads
  end

  def index_menu(leads)
    if @leads.size == 0
      ''
    elsif @leads.size == 1
      '[1], '
    else
      "[1-#{leads.size}], "
    end
  end

  def archived_leads
    read_leads
    puts ""
    puts "*********** Archived Leads **********".red
    @archived_leads.each.with_index(1) do |lead, i|
      puts "#{i}. #{lead['title']}"
    end
    puts ""
    puts "[u]narchive, [b]ack, e[x]it"
    input = gets.strip
    case input
    when 'b'
      show_main_menu
    when 'x'
      exit_program
    when 'u'
      puts 'which lead?'
      print '> '
      input = gets.strip
      unarchive_index = regulate_index(input)

      unarchive_lead(unarchive_index)
    end
    archived_leads
  end

  def unarchive_lead(i)
    read_leads
    unarchived_lead = @archived_lead_doc['leads'].delete_at(i)
    @lead_doc['leads'] << unarchived_lead
    save_leads(@lead_doc)
    save_archived_lead(@archived_lead_doc)
    puts 'Lead has been unarchived!'
    puts ''
    archived_leads
  end

  def hot_leads
    read_leads
    puts ""
    puts "*********** HOT LEADS **********".red
    @leads.each.with_index(1) do |lead, i|
      puts "#{i}. #{lead['title']}"
    end
    puts ""
    puts "#{index_menu(@leads)}[a]dd, [d]elete, [b]ack, e[x]it"
    print "> "
    input = gets.strip

    case input

    when 'b'
      show_main_menu
    when 'x'
      exit_program
    when 'a'
      add_lead
    when 'd'
      delete_lead
    else
      lead_index = regulate_index(input)
      lead = @leads[lead_index]
      puts ""
      if lead
        show_lead(lead_index)
        info_menu(lead_index)
      else
        puts "invalid selection".red
      end
      puts ""
      hot_leads
    end
    hot_leads
  end

  def regulate_index(input)
    index = input.to_i - 1
    index > -1 ? index : -1000
  end

  def show_lead(lead_index)
    read_leads
    lead = @leads[lead_index]
    puts "****** #{lead['title']} ******".blue
    lead['progress'].each.with_index(1) do |progress, i|
      puts "#{i}.) " + "#{progress['date']}".blue + " - #{progress['info']}".green
    end
  end

  def info_menu(i)
    puts ""
    puts "[a]dd, [d]elete, [e]dit, [b]ack, [m]ain, [r]elist, ar[c]hive, e[x]it"
    print "> "
    input = gets.strip

    case input

    when 'b'
      hot_leads
    when 'm'
      show_main_menu
    when 'x'
      exit_program
    when 'a'
      add_info(i)
    when 'd'
      delete_info(i)
    when 'e'
      edit_info(i)
    when 'r'
      show_lead(i)
    when 'c'
      archive_lead(i)
    else
      puts "invalid info".red
    end

    info_menu(i)
  end

  def archive_lead(i)
    read_leads
    archived_lead = @lead_doc['leads'].delete_at(i)
    @archived_lead_doc['leads'] << archived_lead
    save_leads(@lead_doc)
    save_archived_lead(@archived_lead_doc)
    puts 'Lead has been archived!'
    puts ''
    hot_leads
  end

  def delete_info(i)
    read_leads
    puts "Enter the entry to delete"
    print "> "
    input = gets.strip
    delete_index = regulate_index(input)
    if @lead_doc['leads'][i]['progress'].each_index.to_a.include?(delete_index)
      @lead_doc['leads'][i]['progress'].delete_at(delete_index)
      save_leads(@lead_doc)
    else
      puts "invalid entry!"
    end

    show_lead(i)
  end

  def edit_info(i)
    read_leads
    puts "Enter the entry to edit"
    print "> "
    input = gets.strip
    edit_index = regulate_index(input)
    if @lead_doc['leads'][i]['progress'].each_index.to_a.include?(edit_index)
      puts 'enter date (blank for today)'
      print '> '
      date = gets.strip
      if date == ''
        date = Date.today.strftime("%b %d, %Y")
      end
      puts 'Enter new info'
      print '> '
      editted_info = gets.strip
      @lead_doc['leads'][i]['progress'][edit_index] = { date: date, info: editted_info }
      save_leads(@lead_doc)
    else
      puts "invalid entry!"
    end

    show_lead(i)
  end

  def add_info(i)
    puts ""
    puts 'enter date (blank for today)'
    print '> '
    date = gets.strip
    if date == ''
      date = Date.today.strftime("%b %d, %Y")
    end
    puts 'enter info'
    print '> '
    info = gets.strip
    @lead_doc['leads'][i]['progress'] << { date: date, info: info }
    save_leads(@lead_doc)
    puts ""
    show_lead(i)
  end

  def add_lead
    puts "Enter the name of the new lead"
    print "> "
    name = gets.strip
    @lead_doc['leads'] << { title: name, progress: [], completed: false }
    save_leads(@lead_doc)
    hot_leads
  end

  def save_leads(lead_doc)
    File.open("./data/leads/leads.json","w") do |f|
      f.write(JSON.pretty_generate(lead_doc))
    end
  end

  def save_archived_lead(lead_doc)
    File.open("./data/leads/archived_leads.json","w") do |f|
      f.write(JSON.pretty_generate(lead_doc))
    end
  end

  def call
    read_files
    show_title
    show_main_menu
  end

  def exit_program
    puts ""
    puts "Thank you, see you next time!"
    puts ""
    exit
  end
end
