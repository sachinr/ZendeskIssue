require 'zendesk_api'
require 'byebug'

week_ago = (Date.today - 7).to_s
query    = "created>#{week_ago} type:ticket"
issue_info = []

client = ZendeskAPI::Client.new do |config|
  config.url = "https://github.zendesk.com/api/v2"
  config.username = ENV['ZD_EMAIL']
  config.token    = ENV['ZD_TOKEN']
end

ids = []
client.search(:query => query).all { |t| ids << t.id }

ids.each_slice(100) do |page|
  full_tickets = client.tickets.show_many(ids: page, include: :organizations).to_enum
  full_tickets.each do |t|
    issue_info << { name: t.organization.name,
                    subject: t.subject,
                    priority: t.priority,
                    urls: "https://enterprise.github.com/tickets/#{t.id})"
    }
  end
end

issue_info.sort_by { |x| x[:name] }
