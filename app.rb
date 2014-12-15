require 'rubygems'
require 'bundler/setup'

require 'zendesk_api'
require 'restforce'
require 'byebug'

week_ago = (Date.today - 7).to_s
query    = "created>#{week_ago} type:ticket"
issue_info = []

sf_client = Restforce.new :username => ENV['SF_USERNAME'],
  :password       => ENV['SF_PASSWORD'],
  :client_id      => ENV['SF_CONSUMER_KEY'],
  :client_secret  => ENV['SF_CONSUMER_SECRET']

zd_client = ZendeskAPI::Client.new do |config|
  config.url = "https://github.zendesk.com/api/v2"
  config.username = ENV['ZD_EMAIL']
  config.token    = ENV['ZD_TOKEN']
end

ids = []
zd_client.search(:query => query).all { |t| ids << t.id }

ids.each_slice(100) do |page|
  full_tickets = zd_client.tickets.show_many(ids: page, include: :organizations).to_enum
  full_tickets.each do |t|
    issue_info << { name: t.organization.name,
                    subject: t.subject,
                    priority: t.priority == "urgent" ? "**#{t.priority}**" : t.priority,
                    url: "https://enterprise.github.com/tickets/#{t.id}"
    }
  end
end

issue_info.sort_by! { |x| x[:name] }

result = ["Account | Subject | Priority | Owner ", "---|---|---|---|---" ]

domains  = issue_info.map { |i| i[:name] }

all_opportunities = sf_client.query("SELECT a.Name, a.Owner.Name, o.Owner.Name,
                               a.Domain__c FROM Opportunity o, o.Account a
                               WHERE a.Domain__c IN ('#{ domains.join("','") }')")

issue_info.each do |i|
  domain_opportunities = all_opportunities.find_all { |o| o.Account.Domain__c == i[:name] }
  owners = domain_opportunities.inject([]) do |col, o|
    if o.Account.Owner.Name != "Mr Hubot"
      col << "**#{o.Account.Owner.Name}**"
    else
      col << o.Owner.Name if o.Owner.Name != "Mr Hubot"
    end
    col
  end
  i[:owner] = owners.uniq.join(', ')
  name = domain_opportunities.first ? domain_opportunities.first.Account.Name : i[:name]
  result << "#{name} | [#{i[:subject][0...49]}](#{i[:url]}) | #{i[:priority]} | #{i[:owner]} "
end

print result.join("\n")
