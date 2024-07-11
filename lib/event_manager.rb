require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  phone_number = phone_number.to_s

  if phone_number.length == 10
    phone_number
  elsif phone_number.length == 11 && phone_number[0] == '1'
    phone_number[1..10]
  else
    ''
  end
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('secret.key').strip

  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def find_most_repeated_elements(array)
  counts = array.group_by { |element| element }.to_a
  counts_sorted = counts.sort_by { |element| -element[1].length }

  counts_sorted.select { |element| element[1].length > 1 }.map { |element| element[0] }
end

def find_peak_registration_hours(registration_dates)
  registration_hours = registration_dates.map do |date|
    date.strftime('%H').to_i
  end

  find_most_repeated_elements(registration_hours)
end

def find_peak_registration_days(registration_dates)
  registration_days = registration_dates.map do |date|
    date.strftime('%A')
  end

  find_most_repeated_elements(registration_days)
end

puts 'Event Manager Initialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

registration_dates = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone_number = clean_phone_number(row[:homephone])
  legislators = legislators_by_zipcode(zipcode)
  registration_dates << Time.strptime(row[:regdate].to_s, '%m/%d/%y %H:%M')

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end
