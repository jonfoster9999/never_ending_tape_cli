require 'faraday'
require 'faraday_middleware'
require 'json'

class EmailTracker
  attr_accessor :sent_emails_path, :sent_emails_doc, :connection

  def initialize(sent_emails_path: nil)
    @sent_emails_path = sent_emails_path
    @connection = Faraday.new 'http://localhost:3000' do |conn|
      conn.request  :url_encoded
      conn.response :json, :content_type => /\bjson$/
      conn.adapter Faraday.default_adapter
    end
  end

  def read_sent_emails
    @sent_emails = connection.get('/sent_emails').env.body
      .map {|obj| obj.merge(date: Date.parse(obj["created_at"]))}
      .inject({}) do |obj, email|
        obj[email[:date].to_s] ||= []
        obj[email[:date].to_s] << email["email"]
        obj
      end

      binding.pry

  end

  def manually_enter_email(email)
    email = {
      :email => {
        :email => email,
        :email_type => "sent-via-csv",
        :manual_follow_up => false,
        :user_id => 3
      }
    }
    res = connection.post('/manually_entered_emails_cli', email)

  end

  def sent_emails
    sent_emails_doc['sent_emails']
  end

  def add_emails_by_filename(filename)

  end
end
