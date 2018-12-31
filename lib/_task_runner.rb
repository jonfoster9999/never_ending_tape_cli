require 'pry'
require 'active_support/core_ext/time/conversions'

class TaskRunner
  attr_accessor :tasks_doc, :completed_tasks_doc, :path, :transfer_path

  def initialize(path: nil, transfer_path: nil)
    @path = path
    @tasks = []
    @transfer_path = transfer_path
  end

  def read_tasks
    raw_tasks_doc = File.read(@path)
    @tasks_doc = JSON.parse(raw_tasks_doc)
  end

  def read_completed_tasks
    raw_completed_tasks_doc = File.read(@transfer_path)
    @completed_tasks_doc = JSON.parse(raw_completed_tasks_doc)
  end

  def task_index_is_valid?(i)
    tasks.each_index.to_a.include?(i)
  end

  def tasks
    tasks_doc['tasks']
  end

  def completed_tasks
    completed_tasks_doc['tasks']
  end

  def save_completed_tasks
    File.open(@transfer_path, 'w') do |f|
      f.write(JSON.pretty_generate(completed_tasks_doc))
    end
  end

  def delete_task(i)
    tasks.delete_at(i)
    save
  end

  def edit_task(i, val)
    tasks[i.to_i] = { info: val }
    save
  end

  def save
    File.open(@path, 'w') do |f|
      f.write(JSON.pretty_generate(tasks_doc))
    end
  end

  def add_task(task)
    tasks << task
    save
  end

  def completed_tasks_since(num_of_days)
    read_completed_tasks
    today = Date.today
    completed_tasks.select do |date, task_arr|
      task_date = Date.parse(date)
      (today - task_date).to_i <= num_of_days
    end.sort_by {|k, v| Date.parse(k) }
  end

  def mark_task_complete(i)
    read_completed_tasks
    read_tasks
    completed_task = tasks.delete_at(i)
    date = Date.today.strftime("%a, %d %b %Y")
    completed_tasks[date] ||= []
    completed_tasks[date] << completed_task
    save
    save_completed_tasks
  end
end
